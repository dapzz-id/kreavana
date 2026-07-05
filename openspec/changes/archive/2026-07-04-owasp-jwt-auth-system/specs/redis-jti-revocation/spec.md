## ADDED Requirements

### Requirement: JTI stored in Redis on token issuance
The system SHALL store each JWT's `jti` claim in Redis with a TTL equal to the token's expiry time when a new access token is issued (login or refresh).

#### Scenario: JTI is stored on login
- **WHEN** a user logs in successfully
- **THEN** the `jti` of the issued JWT is stored in Redis as `jti:{jti_value}` with TTL matching token expiry

#### Scenario: JTI is validated on every protected request
- **WHEN** a request with a valid (signature + expiry) JWT arrives at a protected endpoint
- **THEN** the system looks up `jti:{jti_value}` in Redis
- **AND** if the key does not exist, the system returns HTTP 401

### Requirement: JTI is deleted from Redis on logout
The system SHALL delete the JTI from Redis immediately when a user logs out, effectively revoking the token before its natural expiry.

#### Scenario: Token is revoked on logout
- **WHEN** a user calls `POST /auth/logout` with a valid access token
- **THEN** the `jti` is deleted from Redis
- **AND** any subsequent request with that same access token returns HTTP 401 even if the token has not expired

### Requirement: Refresh token rotation invalidates old JTI
The system SHALL delete the old JTI from Redis and store a new JTI when a token refresh occurs.

#### Scenario: Old token is invalidated after refresh
- **WHEN** a user refreshes their token via `POST /auth/refresh`
- **THEN** the old access token's JTI is deleted from Redis
- **AND** a new access token with a new JTI is issued and stored in Redis
