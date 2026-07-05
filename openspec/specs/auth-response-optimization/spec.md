## MODIFIED Requirements

### Requirement: Minimal Authentication Payload
The system SHALL return a minimal JSON payload upon successful user authentication. The payload MUST only include the `access_token` and a minimal user object containing `uid`, `name`, `username`, `email`, and `role`. It MUST NOT include `refresh_token`, `session_token`, or an extensive user profile unless explicitly specified by an architecture override.

#### Scenario: Successful Login
- **WHEN** user logs in with valid credentials
- **THEN** system returns a response containing only the `access_token` and a `user` object containing only `uid`, `name`, `username`, `email`, and `role` properties.

### Requirement: Independent Profile Fetching
Clients MUST use the `/api/auth/me` (or equivalent) endpoint authenticated with the `access_token` to fetch complete profile details, roles, or permissions if needed after the initial login.

#### Scenario: Fetching user profile after login
- **WHEN** client requires full user details (e.g. `permissions`, `history`) and provides a valid `access_token` to the profile endpoint
- **THEN** system returns the complete user profile associated with the token.
