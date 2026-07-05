## MODIFIED Requirements

### Requirement: Minimal Authentication Payload
The system SHALL return a minimal JSON payload upon successful user authentication. The payload MUST only include the `access_token` and a minimal user object. It MUST NOT include `refresh_token`, `session_token`, or an extensive user profile unless explicitly specified by an architecture override. Frontend HARUS menyesuaikan state management untuk tidak mengekspektasi data penuh saat login.

#### Scenario: Successful Login
- **WHEN** user logs in with valid credentials
- **THEN** system returns a response containing only the `access_token` and a `user` object containing only `name`, `username`, and `email` properties. Frontend menggunakan `access_token` tersebut untuk memulai sesi tanpa *crash* akibat kehilangan field data lainnya.
