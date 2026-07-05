## ADDED Requirements

### Requirement: Rate limiting on authentication endpoints
The system SHALL apply rate limiting to `/auth/login` and `/auth/refresh` endpoints to prevent brute-force and credential-stuffing attacks.

#### Scenario: Login is rate limited per IP
- **WHEN** a single IP sends more than 5 login requests within 1 minute
- **THEN** the system returns HTTP 429 (Too Many Requests) for subsequent requests until the window resets
- **AND** the response includes a `Retry-After` header

#### Scenario: Refresh is rate limited per IP
- **WHEN** a single IP sends more than 10 refresh requests within 1 minute
- **THEN** the system returns HTTP 429 for subsequent requests until the window resets

### Requirement: Generic error messages to prevent user enumeration
The system SHALL return identical, generic error responses for all authentication failures regardless of the actual reason (wrong password, non-existent user, locked account, etc.).

#### Scenario: Invalid credentials return generic message
- **WHEN** a user submits a login with either a wrong password or a non-existent email
- **THEN** both cases return HTTP 401 with the same generic message (e.g., "Invalid credentials")
- **AND** the response does NOT distinguish between "user not found" and "wrong password"
