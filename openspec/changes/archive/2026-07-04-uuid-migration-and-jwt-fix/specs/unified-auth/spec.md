## MODIFIED Requirements

### Requirement: Unified Login Endpoint
The system SHALL provide a single authentication endpoint at `/api/auth/login` to handle login requests for all user roles (user, creator, admin), utilizing a valid JWT configuration to successfully issue tokens.

#### Scenario: Successful Unified Login
- **WHEN** any user (regardless of role) submits valid credentials to `/api/auth/login`
- **THEN** the system authenticates the user using a properly configured symmetric JWT algorithm (HS256) and returns a successful authentication response containing the access token.
