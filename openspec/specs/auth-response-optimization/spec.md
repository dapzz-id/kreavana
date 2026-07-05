## Purpose
Optimizes authentication responses by minimizing payload size and fetching full profile data independently.

## Requirements

### Requirement: Minimal Authentication Payload
The system SHALL return a minimal JSON payload upon successful user authentication. The payload MUST include the `access_token` and MAY include non-sensitive token metadata such as token type and expiration. It MUST NOT include `refresh_token`, `session_token`, PII-bearing user fields, or an extensive user profile unless explicitly specified by an architecture override.

#### Scenario: Successful Login
- **WHEN** user logs in with valid credentials
- **THEN** system returns a response containing the `access_token` and no `refresh_token`, `session_token`, or PII-bearing user object.

### Requirement: Independent Profile Fetching
Clients MUST use the `/api/auth/me` (or equivalent) endpoint authenticated with the `access_token` to fetch complete profile details, roles, or permissions if needed after the initial login.

#### Scenario: Fetching user profile after login
- **WHEN** client requires full user details (e.g. `permissions`, `history`) and provides a valid `access_token` to the profile endpoint
- **THEN** system returns the complete user profile associated with the token according to authorization rules and never from the login response.
