## MODIFIED Requirements

### Requirement: Minimal Authentication Payload
The system SHALL return a minimal JSON payload upon successful user authentication. The payload MUST only include the `access_token` and a minimal user object containing `uid`, `name`, `username`, `email`, and `role`. It MUST NOT include `refresh_token`, `session_token`, or an extensive user profile unless explicitly specified by an architecture override.

#### Scenario: Successful Login
- **WHEN** user logs in with valid credentials
- **THEN** system returns a response containing only the `access_token` and a `user` object containing only `uid`, `name`, `username`, `email`, and `role` properties.

## ADDED Requirements

### Requirement: Generic Authentication Error Messages
The system SHALL return generic error messages for any authentication failures (such as invalid username or invalid password). It MUST NOT disclose whether an account exists or which specific part of the credential was incorrect.

#### Scenario: Failed login due to invalid credentials
- **WHEN** a user attempts to log in with an incorrect email or password
- **THEN** the system returns a 401 Unauthorized status with a generic message like "Unauthorized", rather than "Username/Email atau password salah".
