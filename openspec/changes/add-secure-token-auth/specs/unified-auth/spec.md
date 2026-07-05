## MODIFIED Requirements

### Requirement: Unified Login Endpoint
The system SHALL provide a single authentication endpoint at `/api/auth/login` to handle login requests for all user roles (user, creator, admin) and SHALL issue tokens according to the secure token lifecycle contract.

#### Scenario: Successful Unified Login
- **WHEN** any user (regardless of role) submits valid credentials to `/api/auth/login`
- **THEN** the system authenticates the user, determines their role internally, returns a successful authentication response containing an access token, and sends the refresh token only via secure cookie.

### Requirement: Role Identification in Login Response
The system SHALL expose the authenticated user's base `role` through the access token `role` claim for client routing and authorization decisions. The login response body MUST NOT include PII or a user object solely for route identification.

#### Scenario: Role Returned in Token Claims
- **WHEN** a user logs in successfully
- **THEN** the access token contains the authenticated user's `role` claim and the response payload does not include refresh token data or PII-bearing user fields.
