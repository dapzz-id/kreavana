## Why

Authentication currently needs a stronger token lifecycle that can support Flutter clients, Laravel microservices, high-throughput Redis-backed validation, and OWASP-aligned protections against token theft, CSRF, replay, and user enumeration. This change standardizes short-lived stateless access tokens with stateful rotating refresh tokens so compromised credentials can be revoked in real time without adding load to the primary database.

## What Changes

- Add a secure token architecture using short-lived JWT access tokens and Redis-backed rotating refresh tokens.
- Require access tokens to be returned in JSON and used as `Authorization: Bearer <token>` credentials with a maximum lifetime of 5 minutes.
- Require refresh tokens to be issued only through `Set-Cookie` with `HttpOnly`, `Secure`, `SameSite=Strict`, and `Path=/api/auth/refresh`.
- Add refresh token rotation that revokes the previous refresh token in Redis on every successful `/api/auth/refresh`.
- Add Redis-backed `jti` validation middleware for real-time access token revocation on every protected request.
- Add Redis-backed rate limiting for authentication endpoints.
- Standardize JWT signing to RS256 in production and HS256 only for development environments where asymmetric keys are not ready.
- Restrict JWT payloads to minimal authorization claims: `sub`, `role`, `permissions`, and `jti`, with no PII or sensitive data.
- Add Flutter client requirements for `flutter_secure_storage` and `dio` interceptors that retry once after a 401-triggered refresh.
- Align Flutter frontend API consumption with the latest backend contracts, including cookie-based refresh, minimal auth payloads, granular route composition, typed response parsing, and migration away from legacy monolithic responses.
- Require generic authentication error responses, HTTPS-only communication, and XSS/CSRF mitigations through cookie attributes.
- Enforce enterprise microservice-style route granularity across API routes so endpoints remain OWASP-aligned, bounded, independently authorized, and optimized for sub-250ms responses.
- Require lightweight route responses to stay below 300 bytes by splitting heavy or multi-resource data into granular endpoints that clients fetch in parallel pools when needed.
- **BREAKING**: Authentication responses MUST NOT expose refresh tokens, session tokens, or PII-heavy user payloads in JSON.

## Capabilities

### New Capabilities
- `secure-token-lifecycle`: Defines secure access token issuance, Redis-backed refresh token storage and rotation, revocation, signing algorithms, JWT claim limits, auth rate limiting, and Flutter token handling expectations.

### Modified Capabilities
- `unified-auth`: Align login and refresh responses with the secure token contract and cookie-only refresh token delivery.
- `auth-response-optimization`: Remove PII-bearing user objects from authentication responses where they conflict with the minimal token architecture.
- `role-based-auth`: Align role and permission JWT claims with the minimal `sub`, `role`, `permissions`, and `jti` payload contract.
- `role-middleware`: Extend protected request validation to require Redis-backed `jti` checks before role or permission authorization.
- `rest-api-granularity`: Require bounded microservice-style routes, response-time and response-size budgets, route splitting for heavy data, and pooled client fetches for composed screens.
- `api-integration-audit`: Align frontend API clients, DTOs, parsers, repositories, and screen data loading with the latest backend auth and route contracts.

## Impact

- Backend Laravel auth controllers, refresh endpoint, logout/revocation flow, middleware stack, route middleware registration, JWT signing configuration, and Redis integration using `phpredis`.
- Redis key design and TTL management for refresh tokens, revoked access token JTIs, and authentication rate limits.
- Flutter authentication client storage, API client interceptors, 401 retry behavior, cookie support, typed DTO parsing, repository methods, pooled API composition, and HTTPS configuration.
- API contract changes for login, refresh, logout, protected route authorization, route granularity, response budgets, and error responses.
