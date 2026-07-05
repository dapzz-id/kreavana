## ADDED Requirements

### Requirement: Short-lived JWT access tokens
The system SHALL issue stateless JWT access tokens in authentication JSON responses and clients MUST send them on protected requests as `Authorization: Bearer <token>`. Access tokens MUST expire in no more than 5 minutes.

#### Scenario: Login returns short-lived access token
- **WHEN** a user authenticates with valid credentials
- **THEN** the response JSON contains an `access_token` with an expiration no greater than 5 minutes and does not contain a `refresh_token`.

#### Scenario: Protected request uses bearer token
- **WHEN** a client calls a protected endpoint with `Authorization: Bearer <access_token>`
- **THEN** the system validates the access token before running protected business logic.

### Requirement: Minimal JWT authorization claims
Access token JWT payloads MUST contain only minimal authorization data: `sub`, `role`, `permissions`, and `jti`, plus standard registered claims required for validation such as expiry. JWT payloads MUST NOT contain PII or sensitive data.

#### Scenario: JWT contains only allowed custom claims
- **WHEN** the system issues an access token
- **THEN** the token custom claims contain `sub`, `role`, `permissions`, and `jti` and do not contain email, name, username, phone, profile, address, or other PII fields.

### Requirement: Environment-gated JWT signing algorithm
The system MUST use RS256 for production access tokens and MUST allow HS256 only in development environments where asymmetric signing keys are not ready.

#### Scenario: Production requires RS256
- **WHEN** the application runs in production
- **THEN** access token signing uses RS256 and startup validation fails if RS256 keys are unavailable.

#### Scenario: Development may use HS256
- **WHEN** the application runs in a development environment without asymmetric keys
- **THEN** access token signing MAY use HS256 without enabling HS256 in production.

### Requirement: Refresh token secure cookie delivery
The system SHALL issue refresh tokens only through the `Set-Cookie` header using `HttpOnly`, `Secure`, `SameSite=Strict`, and `Path=/api/auth/refresh`.

#### Scenario: Login sets refresh cookie
- **WHEN** a user logs in successfully
- **THEN** the response includes a refresh token cookie with `HttpOnly`, `Secure`, `SameSite=Strict`, and `Path=/api/auth/refresh`.

#### Scenario: Refresh token is omitted from JSON
- **WHEN** a user logs in or refreshes tokens successfully
- **THEN** the response body does not include the refresh token value.

### Requirement: Redis-backed refresh token storage
Refresh tokens MUST be stored in Redis rather than the primary database. The system MUST store only a cryptographic hash of the refresh token and MUST apply a Redis TTL matching the token validity window.

#### Scenario: Refresh token persisted in Redis
- **WHEN** the system issues a refresh token
- **THEN** Redis contains a hashed refresh token entry with an expiration and the primary database does not store the raw refresh token.

### Requirement: Refresh token rotation
The system SHALL rotate refresh tokens on every successful `/api/auth/refresh` call by invalidating the previous refresh token in Redis, issuing a new refresh token, and sending the new token through `Set-Cookie`.

#### Scenario: Successful refresh rotates token
- **WHEN** a client calls `/api/auth/refresh` with a valid refresh token cookie
- **THEN** the system invalidates the old Redis refresh token, issues a new access token, stores a new hashed refresh token in Redis, and sends the new refresh token cookie.

#### Scenario: Reused refresh token is rejected
- **WHEN** a client calls `/api/auth/refresh` with a refresh token that was already rotated or revoked
- **THEN** the system returns a generic unauthorized response and does not issue new tokens.

### Requirement: Redis-backed access token revocation
The system SHALL validate each access token `jti` against Redis on every protected request to support real-time revocation.

#### Scenario: Revoked access token is rejected
- **WHEN** a protected request uses a JWT with a valid signature and unexpired `exp` but a revoked `jti` in Redis
- **THEN** the system returns a generic unauthorized response before reaching the route handler.

#### Scenario: Unknown access token state is rejected when allow-listing is enabled
- **WHEN** the deployment uses access token allow-listing and a protected request uses a JWT whose `jti` is absent from Redis
- **THEN** the system returns a generic unauthorized response before reaching the route handler.

### Requirement: Redis-backed authentication rate limiting
Authentication endpoints MUST apply Redis-backed rate limiting to login, registration where present, refresh, password reset where present, and other credential-sensitive endpoints.

#### Scenario: Rate limit exceeded
- **WHEN** a client exceeds the configured authentication rate limit for an endpoint
- **THEN** the system returns a generic rate-limit response without confirming whether an account exists.

### Requirement: Generic authentication errors
Authentication and token endpoints MUST return generic error messages that do not reveal whether a user, email, username, token family, or credential factor exists.

#### Scenario: Invalid login response is generic
- **WHEN** login is attempted with an unknown account or a wrong password
- **THEN** the system returns the same generic authentication failure response for both cases.

### Requirement: HTTPS-only authentication transport
Clients and services MUST use HTTPS for all authentication and authenticated API communication.

#### Scenario: Insecure auth request is rejected outside development
- **WHEN** an authentication request is received over plain HTTP outside a development environment
- **THEN** the system rejects the request or redirects according to deployment policy before processing credentials.

### Requirement: Flutter secure token handling
Flutter clients MUST use `flutter_secure_storage` for sensitive client-held auth data and MUST use `dio` interceptors to attach access tokens, refresh after 401 responses, and retry the original request at most once.

#### Scenario: Client refreshes once after unauthorized response
- **WHEN** a Flutter API request receives a 401 response and a refresh cookie is available
- **THEN** the `dio` interceptor calls `/api/auth/refresh`, stores the new access token securely, and retries the original request no more than once.

#### Scenario: Refresh failure clears local auth state
- **WHEN** the refresh request fails with an unauthorized response
- **THEN** the Flutter client clears sensitive local auth state and treats the user as signed out.
