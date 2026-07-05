## ADDED Requirements

### Requirement: Refresh token stored securely, not in response JSON body
The system SHALL issue the refresh token via `HttpOnly; Secure; SameSite=Strict` cookie for web clients. For mobile (Flutter) clients, the refresh token MAY be returned in the response body but MUST be stored in `flutter_secure_storage` (Keychain/Keystore-backed encrypted storage), never in `SharedPreferences`.

#### Scenario: Refresh token is not accessible via JavaScript (web)
- **WHEN** a login response is received on a web client
- **THEN** the refresh token is set in a cookie with `HttpOnly; Secure; SameSite=Strict` flags
- **AND** the token is NOT present in the response JSON body for web context

#### Scenario: Refresh token rotation on use
- **WHEN** a client calls `POST /auth/refresh` with a valid refresh token
- **THEN** the old refresh token is immediately invalidated
- **AND** a new refresh token is issued and stored
- **AND** if the old refresh token is used again, the system returns HTTP 401

### Requirement: Refresh token rotation is enforced
The system SHALL implement strict refresh token rotation. Each refresh token can only be used once.

#### Scenario: Replay attack on refresh token is blocked
- **WHEN** an attacker replays a previously-used refresh token
- **THEN** the system returns HTTP 401 with a generic error
- **AND** the associated session is terminated (all tokens for that session are revoked)
