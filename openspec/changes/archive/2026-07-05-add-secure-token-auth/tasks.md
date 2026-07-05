## 1. Backend Configuration

- [x] 1.1 Verify Laravel Redis configuration uses `phpredis` and add auth-specific Redis key prefixes for refresh tokens, access token `jti` state, token families, and rate limits.
- [x] 1.2 Add JWT configuration for access token TTL, issuer/audience where applicable, production RS256 keys, and development-only HS256 fallback.
- [x] 1.3 Add startup or health validation that rejects production auth boot when RS256 keys are missing or HS256 is configured.
- [x] 1.4 Define refresh token cookie settings with `HttpOnly`, `Secure`, `SameSite=Strict`, and `Path=/api/auth/refresh`.

## 2. Token Services

- [x] 2.1 Implement an access token issuer that signs JWTs with minimal claims: `sub`, `role`, `permissions`, and `jti`, plus required registered claims.
- [x] 2.2 Ensure access tokens expire in 5 minutes or less and authentication JSON responses include the access token without embedding refresh tokens.
- [x] 2.3 Implement opaque refresh token generation using cryptographically secure randomness.
- [x] 2.4 Implement Redis refresh token storage that persists only token hashes with TTL and session/family metadata.
- [x] 2.5 Implement atomic refresh token rotation that invalidates the previous token and stores a replacement token in Redis.
- [x] 2.6 Implement refresh token reuse handling that returns a generic unauthorized response and revokes the token family/session when possible.

## 3. Auth Endpoints

- [x] 3.1 Update unified and role-specific login endpoints to return access tokens in JSON and set refresh tokens only through secure cookies.
- [x] 3.2 Update `/api/auth/refresh` to read the refresh cookie, rotate the refresh token, issue updated access token claims, and set a replacement cookie.
- [x] 3.3 Update logout and explicit revocation flows to revoke refresh token state and access token `jti` state in Redis.
- [x] 3.4 Update `/api/auth/me` or equivalent profile endpoint so complete user data is fetched only after access-token authentication.
- [x] 3.5 Replace account-specific authentication failure messages with generic responses that prevent user enumeration.

## 4. Middleware And Rate Limiting

- [x] 4.1 Implement access-token validation middleware that verifies JWT signature, expiry, algorithm policy, and Redis `jti` state before route authorization.
- [x] 4.2 Update `RoleMiddleware` to require successful `jti` validation before role checks.
- [x] 4.3 Update `PermissionMiddleware` to require successful `jti` validation before permission checks.
- [x] 4.4 Add Redis-backed rate limiting to login, registration where present, refresh, password reset where present, and other credential-sensitive endpoints.
- [x] 4.5 Enforce HTTPS-only processing for authentication and authenticated API traffic outside development.
- [x] 4.6 Audit protected routes for OWASP controls: authentication, Redis `jti` validation, route-specific authorization, input validation, output minimization, generic errors, and abuse-sensitive rate limits.

## 5. Route Granularity And Performance

- [x] 5.1 Audit existing API routes for monolithic payloads, missing bounded resource ownership, p95 response time above 250ms, or lightweight JSON responses above 300 bytes.
- [x] 5.2 Split heavy auth/profile/bootstrap routes into granular resource endpoints when the response includes unrelated or oversized data.
- [x] 5.3 Add response-shape guards or tests for lightweight endpoints so auth and other small JSON responses remain below 300 bytes.
- [x] 5.4 Add latency instrumentation or tests for normal JSON routes with a target p95 application response time below 250ms.
- [x] 5.5 Classify unavoidable heavy endpoints explicitly and add pagination, summary responses, caching, or asynchronous processing.

## 6. Flutter Client

- [x] 6.1 Add or verify `flutter_secure_storage` usage for sensitive client-held auth state.
- [x] 6.2 Configure `dio` to attach `Authorization: Bearer <token>` to protected API requests.
- [x] 6.3 Configure cookie support for the refresh-token cookie so `/api/auth/refresh` can send and receive secure cookies.
- [x] 6.4 Implement a single-flight `dio` 401 interceptor that refreshes tokens, stores the new access token securely, and retries the original request at most once.
- [x] 6.5 Clear sensitive auth state and route to signed-out behavior when refresh fails with an unauthorized response.
- [x] 6.6 Implement pooled route composition for screens that need multiple independent resources, with default concurrency capped at 5 simultaneous requests.
- [x] 6.7 Update Flutter auth DTOs/parsers so login and refresh consume `access_token` JSON only and never expect `refresh_token` or full profile data in response bodies.
- [x] 6.8 Update Flutter repositories for profile, roles, permissions, creator application, history, and other changed resources to call the latest granular backend endpoints.
- [x] 6.9 Remove direct screen-level parsing of raw API maps for changed contracts and route all parsing through typed DTOs or model factories.
- [x] 6.10 Map generic backend auth/authorization errors to generic frontend states without exposing account, role, permission, or resource existence.

## 7. Tests And Verification

- [x] 7.1 Add backend tests proving login omits refresh tokens from JSON and sets the refresh cookie with required attributes.
- [x] 7.2 Add backend tests proving JWT claims are minimal and do not include PII fields.
- [x] 7.3 Add backend tests proving refresh rotation invalidates the old token and rejects reuse.
- [x] 7.4 Add backend tests proving revoked or missing `jti` state blocks protected requests before role or permission authorization.
- [x] 7.5 Add backend tests proving Redis-backed auth rate limiting returns generic responses.
- [x] 7.6 Add backend tests proving lightweight route responses stay below 300 bytes or are split/classified as heavy.
- [x] 7.7 Add backend performance checks or instrumentation proving normal JSON routes target p95 application response time below 250ms.
- [x] 7.8 Add Flutter tests for 401 refresh retry, single retry limit, secure storage update, refresh failure cleanup, and pooled route composition capped at 5 concurrent requests.
- [x] 7.9 Add Flutter contract tests for updated auth, profile, roles, permissions, creator application, and sub-role API response parsing.
- [x] 7.10 Add frontend regression tests proving screens no longer depend on legacy monolithic auth or `/me` payloads for heavy data.
- [x] 7.11 Add staging verification for HTTPS, RS256 production config, Redis connectivity, cookie attributes, route latency, response size, frontend API compatibility, and rollback behavior.
