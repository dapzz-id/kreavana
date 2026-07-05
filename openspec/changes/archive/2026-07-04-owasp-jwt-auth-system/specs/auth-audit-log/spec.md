## ADDED Requirements

### Requirement: Authentication events are logged for auditing
The system SHALL log all authentication events (login, logout, token refresh) to an `auth_logs` table. Each log entry MUST include: `user_id`, `action`, `ip_address`, `user_agent`, `created_at`. No sensitive data (passwords, tokens, PII beyond user_id) may be logged.

#### Scenario: Login is logged
- **WHEN** a user successfully logs in
- **THEN** an entry is created in `auth_logs` with `action = 'login'`, `user_id`, `ip_address`, and `user_agent`

#### Scenario: Logout is logged
- **WHEN** a user calls `POST /auth/logout`
- **THEN** an entry is created in `auth_logs` with `action = 'logout'`, `user_id`, `ip_address`, and `user_agent`

#### Scenario: Token refresh is logged
- **WHEN** a user's token is refreshed via `POST /auth/refresh`
- **THEN** an entry is created in `auth_logs` with `action = 'refresh'`, `user_id`, `ip_address`, and `user_agent`

#### Scenario: Failed login is logged without sensitive data
- **WHEN** a login attempt fails
- **THEN** an entry is created with `action = 'login_failed'`, `ip_address`, `user_agent`
- **AND** no password attempt, email, or other PII beyond a hashed identifier is stored
