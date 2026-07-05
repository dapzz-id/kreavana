## ADDED Requirements

### Requirement: Unified Login Endpoint
The system SHALL provide a single authentication endpoint at `/api/auth/login` to handle login requests for all user roles (user, creator, admin).

#### Scenario: Successful Unified Login
- **WHEN** any user (regardless of role) submits valid credentials to `/api/auth/login`
- **THEN** the system authenticates the user, determines their role internally, and returns a successful authentication response.

### Requirement: Role Identification in Login Response
The system SHALL include the authenticated user's base `role` and `uid` in the minimal login response payload, allowing the client to determine the user's access level without requiring a separate profile fetch for routing purposes.

#### Scenario: Role Returned in Payload
- **WHEN** a user logs in successfully
- **THEN** the response payload MUST contain the `role` and `uid` fields alongside the `access_token`.
