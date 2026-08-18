# API Contract & Mobile Client Implementation Guide

This document outlines the strict requirements for integrating the mobile client (Flutter) with the hardened Laravel JWT Authentication system.

## 1. Transport & Storage

*   **X-Client-Type Preference**: The mobile client MUST send the HTTP header `X-Client-Type: mobile` on authentication requests (login, refresh).
*   **JSON Payload**: By sending this header, the backend will return the long-lived refresh token inside the JSON payload (`data.refresh_token`) instead of an `HttpOnly` cookie.
*   **Secure Storage**: The Flutter client MUST store the refresh token using platform-secure storage (e.g., `flutter_secure_storage` which uses Android Keystore / iOS Keychain). Do NOT store the refresh token in plaintext SharedPreferences.

## 2. Token Lifecycle & Concurrency

*   **Access JWT TTL**: 10 minutes.
*   **Refresh Token TTL**: 30 days.
*   **Single-Flight Refresh Mechanism**: The Flutter client MUST implement a single-flight refresh lock (e.g., using a boolean flag or a Mutex/Completer in Dart).
    *   If multiple API requests fail with `401 Unauthorized` simultaneously, only **ONE** refresh request may be sent to the backend.
    *   All other pending requests MUST wait for the result of that single refresh request.
*   **No Infinite Loops**: A single API request MUST NEVER perform unlimited refresh/retry loops. A maximum of ONE refresh attempt is allowed per failed request.

## 3. Refresh Outcomes

**If Refresh Succeeds:**
1.  Replace the old access token with the new access token in memory/storage.
2.  Replace the rotated refresh token with the new refresh token in Secure Storage.
3.  Retry the original pending request(s) exactly once using the new access token.
4.  *Never* retry a request using the old access token after a successful token refresh.

**If Refresh Fails (Authentication/Session-Revoked):**
1.  Do NOT retry the refresh indefinitely.
2.  Clear all local authentication credentials (access token, refresh token, user data).
3.  Transition the application to the unauthenticated/login state immediately.

## 4. Session Revocation & Reuse Detection

*   **Reuse Detection**: If the mobile client (or a malicious actor) attempts to use an old/rotated refresh token, the backend will detect this as a reuse attempt.
*   **Consequence**: The server will instantly revoke the **entire session (token family)**. The mobile client MUST treat this as a permanently invalid session and require a fresh login.
*   **Concurrency Safe**: The server uses Database Transactions and Row Locking (`lockForUpdate`). If the client fails to implement a single-flight lock and sends two refresh requests concurrently, the server will serialize them. The first will succeed, and the second will be treated as a "reuse" attempt, which will immediately revoke the session. It is CRITICAL that the client implements the single-flight mechanism to avoid accidentally locking the user out.

## 5. Security Trade-off Documentation

**Stateless JWT vs. Instant Revocation:**
Revoking a server-side session (e.g., via manual logout or reuse detection) prevents any future token refreshes. However, it does NOT instantly invalidate an already-issued stateless Access JWT. The access token remains valid until its maximum 10-minute expiry.
This is an intentional security/performance trade-off to avoid querying the database/Redis on every single API request. Do NOT attempt to solve this 10-minute window by adding unnecessary client-side tokens or pinging the server manually.

## 6. Phase 2: Job Contracts (API Documentation)

### 6.1 Endpoints

- `GET /api/contracts`
  - Retrieve contracts belonging to the authenticated user (whether acting as client or creator).
  - Query Params: `limit` (default: 50).
- `GET /api/contracts/{id}`
  - Retrieve a specific contract's details.
  - Authorization: **DENIED** with 403 Forbidden if the user is not the designated `client_id`, `creator_id`, or an Admin (IDOR protection).
- `POST /api/contracts`
  - Create a new Job Contract. 

### 6.2 Request Fields (POST /api/contracts)

| Field | Type | Rules | Description |
|---|---|---|---|
| `partner_id` | UUID | required | The ID of the other user in the contract. |
| `my_role` | string | required | Either `client` or `creator`. Determines ownership resolution. |
| `opportunity_id` | UUID | optional | Reference to an existing opportunity. |
| `title` | string | required | Max 200 chars. |
| `description` | string | optional | |
| `terms` | string | optional | |
| `agreed_price` | numeric | required, min 0 | The agreed transaction amount. |
| `deadline` | date | optional | Format: YYYY-MM-DD. |

### 6.3 Immutable / Protected Financial Fields

Clients **CANNOT** manipulate the following fields through API payloads (Mass Assignment Protection is actively enforced):
- `client_id` (determined by `my_role` + `partner_id` + authenticated user)
- `creator_id` (determined by `my_role` + `partner_id` + authenticated user)
- `contract_status` (starts as `draft`)
- `work_status` (starts as `scheduled`)
- `escrow_amount` (forced to `0.00` on creation, managed by backend later)
- All timestamp tracking fields (`completed_at`, `started_at`, etc.)

### 6.4 Legacy Compatibility (Chat Contracts)

- Existing Flutter clients creating contracts by embedding JSON in chat messages (`type: 'contract'`) will continue functioning for legacy reads.
- **Migration Path**: All new contracts should utilize the `POST /api/contracts` endpoint to ensure financial integrity and proper state tracking.
- Client-side modification of contract status or escrow states in Flutter memory is deprecated and will be fully superseded by the backend state machine in Phase 3.

## 7. Phase 3: Contract & Work State Machine

### 7.1 State Transition Endpoint

- `POST /api/contracts/{id}/transitions`
  - Purpose: Trigger a state transition on a Job Contract.
  - Authorization: Only authorized participants (Client/Creator) can transition, and only for specific valid actions.
  - Payload:
    ```json
    {
        "transition": "submit_work",
        "metadata": { "reason": "Optional cancellation or dispute reason" }
    }
    ```

### 7.2 Valid Transitions (Actions)

1. `approve`: 
   - Actor: Client or Creator. 
   - Rule: Requires both parties to approve before `contract_status` reaches `approved`. Sets `client_approved_at` or `creator_approved_at`.
2. `pay_escrow`: 
   - *Currently deferred in Phase 3 pending proper Escrow system integration.* (Returns 400 Error).
3. `submit_work`: 
   - Actor: Creator. 
   - Rule: Requires `work_status` to be `in_progress` or `revision`. Changes `work_status` to `review` and sets `submitted_at`.
4. `request_revision`: 
   - Actor: Client. 
   - Rule: Requires `work_status` to be `review`. Changes `work_status` to `revision`.
5. `approve_work`: 
   - Actor: Client. 
   - Rule: Requires `work_status` to be `review`. Changes `work_status` to `completed` and sets `completed_at`. *Note: `contract_status` remains unaffected pending future Escrow release logic.*
6. `request_cancellation`: 
   - Actor: Client or Creator. 
   - Rule: Changes `contract_status` to `cancel_requested`.
7. `confirm_cancellation`: 
   - Actor: The partner who did NOT initiate the request. 
   - Rule: Changes `contract_status` and `work_status` to `cancelled` and sets `cancelled_at`. *Note: Wallet refund logic is deferred pending future Escrow integration.*
8. `raise_dispute`: 
   - Actor: Client or Creator. 
   - Rule: Changes `contract_status` to `disputed`.

### 7.3 Audit Trail & Idempotency

- The backend automatically tracks a complete, append-only history of every successful state transition in the `job_status_histories` table.
- Flutter MUST NOT supply `from_status` or `to_status`. The server derives these values and sets all relevant timestamps (e.g., `completed_at`).
- All race-sensitive transitions use pessimistic locking (`lockForUpdate()`) to ensure absolute idempotency.

## 8. Phase 4: Creator Capacity & Calendar

### 8.1 Creator Capacity Management

- `PUT /api/profile`
  - Field `max_work_capacity` (integer, nullable). Set to 0 to pause all bookings. Set to `null` for unlimited capacity.

### 8.2 Calendar Availability Schedule

- `GET /api/profile/calendar`
  - Get a list of daily capacity overrides.
- `POST /api/profile/calendar`
  - Set a capacity override for a specific date.
  - Fields: `date` (YYYY-MM-DD), `max_capacity` (int), `is_unavailable` (bool), `notes` (string).
- `DELETE /api/profile/calendar/{date}`
  - Remove an override for a specific date.

### 8.3 Availability Checking (Public)

- `GET /api/creators/{id}/availability`
  - Used to fetch a creator's current or future capacity status.
  - **No query params**: Returns global current active job count and status.
  - **`?date=YYYY-MM-DD`**: Returns effective capacity for that specific date.
  - **`?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`**: Returns a date range availability array and a global `available` boolean. 
    - **IMPORTANT**: Non-working/unavailable calendar overrides inside the requested range DO NOT cause the entire range to be unavailable. They are simply excluded from the working-day calculation.
    - The range is `available = false` ONLY if there are zero working dates in the range (`error = CREATOR_NO_WORKING_DATES`), or if one or more valid working dates are at full capacity (`error = CREATOR_CAPACITY_FULL`).

### 8.4 Booking Process Integration & Phase 4 Business Rules

The booking and capacity engine differentiates between the **booking range** (the continuous date range selected by the client) and the **working dates** (dates within the range where the creator accepts work).

- **Booking Range**: Inclusive range from `scheduled_start_date` to `scheduled_end_date`.
- **Working Dates**: Dates inside the range that are NOT explicitly overridden as `is_unavailable = true` by the creator.
- **Non-Working Dates**: Dates (e.g. holidays, weekends) where the creator has `is_unavailable = true`. These do NOT invalidate a multi-day booking; they are simply excluded from the working-day list.
- **Capacity-consuming Dates**: Capacity is ONLY checked and consumed on Working Dates.
- **Global Unavailable Semantics**: If `users.max_work_capacity = 0`, the creator is globally paused and cannot accept *any* new capacity-consuming bookings. This is a global block (`CREATOR_UNAVAILABLE`), different from a date-specific non-working day.
- **Draft Behavior**: Contracts in `draft` status DO NOT consume capacity. Multiple overlapping drafts can safely co-exist.
- **Approval Behavior**: When transitioning a contract to `approved`, the system locks the creator's row, recalculates working dates, validates capacity across all working dates, and consumes 1 slot per working date.
- **Capacity Conflict Behavior**: A booking is rejected during approval ONLY if:
  1. There are **Zero Working Dates** in the entire requested range (`409 Conflict`, `error = CREATOR_NO_WORKING_DATES`).
  2. At least **one Working Date is Full** (`409 Conflict`, `error = CREATOR_CAPACITY_FULL`). The conflict array will list ONLY the full working dates, not the non-working dates.
- **Timezone**: Date evaluations are performed in the application's default timezone (UTC or as configured in Laravel) converted to standard `Y-m-d` representation.
- **Concurrency**: The approval transaction uses `lockForUpdate()` on the creator's user record, guaranteeing that concurrent approvals for the same date cannot exceed the `max_work_capacity`.

#### Booking Examples

- **1 Day Booking**: Start = Aug 20, End = Aug 20. If Aug 20 is working and has capacity, it's allowed.
- **3 Days with 1 Holiday**: Start = Aug 20, End = Aug 22. Aug 21 is a non-working holiday. The booking is ALLOWED. Working dates: [Aug 20, Aug 22].
- **7 Days with Weekends**: Start = Aug 1, End = Aug 7. Aug 6 and 7 are non-working weekends. Booking is ALLOWED. Working dates: [Aug 1, 2, 3, 4, 5].
- **14 Days with Holidays**: Start = Aug 1, End = Aug 14. Aug 6, 7 are weekends, Aug 10 is a holiday. Booking is ALLOWED. Working dates are the remaining 11 days.
- **30 Days with Weekends/Holidays**: Start = Aug 1, End = Aug 30. Booking is ALLOWED as long as every non-excluded working day has sufficient capacity remaining.

 # #   9 .   P h a s e   5 :   P r o d u c t   C a t a l o g   &   C r e a t o r   S e r v i c e   O f f e r i n g 
 T h e   c a t a l o g   i s   a   c r e a t o r   o f f e r i n g / p a c k a g e   c a t a l o g   u s e d   p r i m a r i l y   a s   a   s e l e c t i o n   s o u r c e   f o r   J o b C o n t r a c t s .   I t   s a f e l y   r e u s e s   t h e   e x i s t i n g   \ m a r k e t p l a c e _ i t e m s \   a r c h i t e c t u r e . 
 
 # # #   9 . 1   C a t a l o g   L i f e c y c l e 
 -   * * d r a f t * * :   H i d d e n   f r o m   p u b l i c   c a t a l o g .   C a n n o t   b e   s e l e c t e d   f o r   n e w   J o b C o n t r a c t s . 
 -   * * p u b l i s h e d * * :   V i s i b l e   i n   p u b l i c   c a t a l o g   a c c o r d i n g   t o   e x i s t i n g   v i s i b i l i t y   r u l e s .   C a n   b e   s e l e c t e d   f o r   n e w   J o b C o n t r a c t s . 
 -   * * a r c h i v e d * * :   H i d d e n   f r o m   p u b l i c   c a t a l o g .   C a n n o t   b e   s e l e c t e d   f o r   n e w   J o b C o n t r a c t s ,   b u t   h i s t o r i c a l   J o b C o n t r a c t s   r e t a i n   t h e i r   r e f e r e n c e . 
 
 # # #   9 . 2   D e l i v e r y   T y p e 
 -   * * d i g i t a l _ d o w n l o a d * * :   A   d i g i t a l   p r o d u c t   t h a t   i s   p u r c h a s e d   i n s t a n t l y   t h r o u g h   t h e   m a r k e t p l a c e . 
 -   * * s e r v i c e * * :   A   s e r v i c e   o f f e r i n g   o r   p a c k a g e   ( e . g . ,   W e d d i n g   O r g a n i z e r   P a k e t   G o l d )   t h a t   a   c l i e n t   c a n   s e l e c t   t o   i n i t i a t e   a   J o b C o n t r a c t . 
 
 # # #   9 . 3   J o b C o n t r a c t   I n t e g r a t i o n   &   H i s t o r i c a l   I n t e g r i t y 
 -   * * S n a p s h o t t i n g * * :   W h e n   a   c l i e n t   p r o p o s e s   a   J o b C o n t r a c t   f r o m   a   p u b l i s h e d   s e r v i c e   c a t a l o g   i t e m ,   t h e   a u t h o r i t a t i v e   \ 	 i t l e \ ,   \ d e s c r i p t i o n \ ,   a n d   \ p r i c e \   a r e   s n a p p e d   f r o m   t h e   c a t a l o g   i t e m   i n t o   t h e   J o b C o n t r a c t .   
 -   * * H i s t o r i c a l   I n t e g r i t y * * :   T h e   \ J o b C o n t r a c t \   i s   t h e   h i s t o r i c a l   r e c o r d .   I f   t h e   c r e a t o r   l a t e r   c h a n g e s   t h e   c a t a l o g   i t e m ' s   p r i c e   o r   t i t l e ,   e x i s t i n g   J o b C o n t r a c t s   r e m a i n   u n t o u c h e d . 
 -   * * P h a s e   4   C a p a c i t y   R e l a t i o n s h i p * * :   S e l e c t i n g   a   c a t a l o g   i t e m   d o e s   N O T   c o n s u m e   c a p a c i t y .   T h e   c a p a c i t y   e n g i n e   s t r i c t l y   f o l l o w s   P h a s e   4 ' s   s c h e d u l e d   s t a r t   a n d   e n d   d a t e s .   C a p a c i t y   i s   o n l y   c o n s u m e d   u p o n   d u a l   a p p r o v a l   o f   t h e   J o b C o n t r a c t . 
 -   * * M a r k e t p l a c e   P u r c h a s e   C o m p a t i b i l i t y * * :   D i g i t a l   d o w n l o a d   i t e m s   c o n t i n u e   t o   u s e   t h e   \ M a r k e t p l a c e P u r c h a s e \   f l o w .   S e r v i c e   i t e m s   r o u t e   e n t i r e l y   t h r o u g h   t h e   \ J o b C o n t r a c t \   f l o w .   
  
 