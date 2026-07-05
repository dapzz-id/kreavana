## ADDED Requirements

### Requirement: JWT must be signed with RS256 algorithm
The system SHALL use the RS256 (RSA + SHA-256 asymmetric) algorithm for all JWT signing operations. Use of `none` algorithm or symmetric algorithms (HS256/HS384/HS512) is explicitly forbidden.

#### Scenario: Login generates RS256-signed JWT
- **WHEN** a user successfully authenticates via `POST /auth/login`
- **THEN** the response contains an `access_token` signed with RS256
- **AND** the JWT header contains `"alg": "RS256"`
- **AND** the JWT payload contains only: `sub`, `role`, `permissions`, `jti`, `iat`, `exp`

#### Scenario: Algorithm `none` is rejected
- **WHEN** a request arrives with a JWT using `alg: none`
- **THEN** the system returns HTTP 401 with a generic error message

### Requirement: JWT payload must be minimal and contain no PII
The system SHALL restrict JWT payload to non-sensitive claims only: `sub` (user UUID), `role`, `permissions` (array of strings), `jti` (UUID), `iat`, `exp`. No email, name, phone, or other PII is permitted in the payload.

#### Scenario: JWT payload does not contain PII
- **WHEN** a JWT is issued after login
- **THEN** decoding the payload reveals only: `sub`, `role`, `permissions`, `jti`, `iat`, `exp`
- **AND** no fields such as `email`, `name`, `phone`, or `username` are present
