## Context

The backend is a Laravel API serving Flutter clients and role-aware microservice-style domains. Existing auth specs already define unified login, role/permission JWT claims, role middleware, and minimal auth responses, but they do not yet define a complete OWASP-aligned lifecycle for short-lived access tokens, stateful refresh tokens, real-time revocation, Redis-backed rate limiting, or mobile retry behavior.

The target architecture separates authorization from session continuity. Access tokens remain stateless JWTs for fast service-to-service validation, while refresh tokens are treated as stateful session secrets stored in Redis so they can be rotated, revoked, and expired without using the primary database.

The same security model must apply to route design. API routes should follow enterprise microservice boundaries: each endpoint owns one bounded resource or action, performs its own authorization, avoids over-fetching, and returns only the data required for that operation. Screens that need multiple small resources should compose them client-side through parallel pooled requests instead of relying on large monolithic responses.

The Flutter frontend must be migrated at the same time as the backend contract. The app should stop depending on legacy auth response shapes, embedded refresh tokens, or monolithic `/me` style payloads, and instead consume typed, minimal, route-specific responses through a central API layer.

## Goals / Non-Goals

**Goals:**

- Issue access tokens as short-lived JWTs with a maximum 5 minute TTL.
- Send refresh tokens only in secure `Set-Cookie` headers scoped to `/api/auth/refresh`.
- Rotate refresh tokens on every refresh and invalidate the old token in Redis.
- Validate access token `jti` values through Redis middleware on every protected request.
- Use `phpredis` as the Laravel Redis client for auth storage, revocation, and rate limiting.
- Keep JWT payloads minimal: `sub`, `role`, `permissions`, and `jti`, with standard registered claims as needed for expiry and issuer validation.
- Use RS256 in production, with HS256 allowed only for development until asymmetric keys are provisioned.
- Provide Flutter guidance using `flutter_secure_storage` for sensitive client state and `dio` interceptors for one-time 401 refresh retries.
- Return generic auth errors to reduce user enumeration risk.
- Keep protected API route response time under 250ms at the application p95 target, excluding external network transit and intentionally asynchronous jobs.
- Keep lightweight JSON response bodies under 300 bytes by default; heavy, list, profile, history, or analytics data must be split into granular endpoints or paginated resource slices.
- Support client-side pooled fetching for composed views, with a default concurrency cap of 5 requests per pool to balance latency and backend load.
- Update Flutter repositories, DTOs, parsing, and screen loaders so all API consumption matches the latest backend route contracts.
- Centralize frontend API contract handling so auth, refresh, profile, role, permission, creator application, and other resource calls do not parse ad hoc response maps in screens.

**Non-Goals:**

- Replacing existing role and permission semantics.
- Adding social login, MFA, passwordless login, or OAuth provider support.
- Moving refresh tokens into the primary database.
- Allowing browser-readable refresh tokens for debugging or mobile convenience.
- Forcing large file downloads, media streams, or explicitly paginated collection pages into the 300 byte lightweight response budget.
- Rebuilding unrelated UI flows that do not consume changed backend contracts.

## Decisions

### Access tokens are stateless JWTs with Redis `jti` validation

Access tokens will be signed JWTs and included in JSON responses. Clients send them on protected requests using `Authorization: Bearer <token>`. The backend will validate signature, issuer/audience where configured, expiry, and then check the token `jti` in Redis before authorizing the request.

Redis stores allowed or revoked access-token JTIs with a TTL no longer than the token expiry. An allow-list model gives strongest real-time revocation guarantees but adds one Redis read per protected request; a deny-list model is cheaper for normal traffic but cannot detect tokens minted outside the issuer unless signing keys are protected. The implementation SHOULD use an allow-list when practical for this ecosystem, and MUST at minimum reject revoked JTIs in Redis.

Alternative considered: purely stateless JWT validation. It was rejected because logout, compromised token response, and role downgrade revocation would not take effect until token expiry.

### Refresh tokens are stateful Redis secrets delivered only through cookies

Refresh tokens will be opaque, high-entropy secrets, not JWTs. Only a hash of the refresh token is stored in Redis, keyed by token family/session and user id metadata. The raw token is delivered with `Set-Cookie` using `HttpOnly`, `Secure`, `SameSite=Strict`, and `Path=/api/auth/refresh`, preventing JavaScript access and limiting cross-site submission.

Alternative considered: returning refresh tokens in JSON for mobile storage. It was rejected because the requested security model prioritizes XSS mitigation through `HttpOnly` and a single browser/mobile-compatible cookie contract.

### Refresh rotation invalidates the previous token atomically

The refresh endpoint will read the cookie, validate the hashed token in Redis, revoke or delete the old Redis entry, create a new refresh token, store only its hash with a fresh TTL, and send the replacement cookie in the same response. This operation must be atomic enough to prevent double-use race conditions, using Redis transactions or Lua where needed.

Token reuse after rotation is treated as suspicious: the backend must return a generic unauthorized response and revoke the token family/session when token-family metadata is available.

### Redis is the auth state and rate-limit backend

Laravel must use `phpredis` for Redis access. Redis will hold refresh token hashes, access-token JTI revocation or allow-list state, token family/session metadata, and authentication rate-limit counters. Auth endpoints should use Redis-backed rate limiters keyed by endpoint, IP, and stable user identifier when available.

Alternative considered: database-backed refresh sessions. It was rejected for high-throughput auth flows and because refresh token lifecycle data is ephemeral.

### JWT signing uses environment-specific algorithms

Production must use RS256 with private keys available only to the issuer and public keys available to validators. Development may use HS256 when asymmetric keys are not ready. The configured algorithm must be environment-gated so HS256 cannot be enabled accidentally in production.

### Flutter handles access-token retries, not refresh-token storage

Flutter stores sensitive non-cookie client auth state using `flutter_secure_storage`, such as the current access token if the app cannot keep it only in memory. The `dio` client adds the bearer token to requests, detects a 401, calls `/api/auth/refresh` with cookie support, updates the access token from the refresh response, and retries the original request once. Concurrent 401 responses should share one refresh operation to avoid rotation races.

### Frontend API consumption follows backend contracts

Flutter API access must be centralized behind typed clients/repositories. Login and refresh parsers should expect `access_token` and token metadata only, with refresh state carried by secure cookies. Profile, role, permission, creator application, history, and other heavier data must be loaded through dedicated resource calls. Screens should not assume that login, refresh, or `/me` responses contain complete user or permission graphs.

Response parsing should use explicit DTOs or model factories with schema validation/fallbacks for expected nullable fields. Generic backend auth errors should map to generic frontend states. Any endpoint split on the backend must have a corresponding repository method and, when a screen needs multiple independent resources, a pooled fetch coordinator capped at 5 concurrent requests.

### Routes are granular, bounded, and composed through request pools

Backend routes must be organized around bounded business capabilities rather than screen-shaped payloads. Auth routes should return token state only, `/me` should return only the profile shape required by that route, and heavier data such as role lists, permissions detail, profile history, creator application state, metrics, or feed-like collections should live behind dedicated endpoints with their own authorization and rate limits.

The target performance budget is p95 under 250ms per route and under 300 bytes for lightweight JSON responses. If a response cannot stay within the size budget without losing required data, the route must be split into smaller resource endpoints, paginated, summarized, or converted to an explicit heavy endpoint with documented limits. Flutter clients should fetch up to 5 independent routes in a pool for composed screens, then render from the combined result.

Alternative considered: one large endpoint per screen. It was rejected because it increases over-fetching, cache invalidation complexity, authorization blast radius, payload size, and the impact of slow downstream dependencies.

## Risks / Trade-offs

- Redis outage -> Auth refresh, revocation checks, and rate limiting may fail. Mitigation: fail closed for refresh and revocation-protected routes, expose health checks, and tune Redis availability before rollout.
- One Redis read per protected request -> Higher latency and Redis load. Mitigation: keep keys small, use `phpredis`, set tight TTLs, and monitor p95/p99 middleware latency.
- Mobile cookie handling complexity -> Flutter clients may need a cookie jar and platform-specific HTTPS settings. Mitigation: centralize `dio` auth client setup and cover it with integration tests.
- Refresh rotation races -> Parallel 401 retries can invalidate each other. Mitigation: single-flight refresh in Flutter and atomic rotation in Redis.
- RS256 key misconfiguration -> Production login outage or accidental HS256 fallback. Mitigation: startup validation must reject production configs without RS256 keys.
- Generic errors reduce UX specificity -> Users get less precise login feedback. Mitigation: keep user-facing messages generic while logging reason codes internally.
- Route over-splitting -> Too many round trips can hurt mobile performance. Mitigation: use pooled requests with a concurrency cap of 5, cache stable reference data, and keep endpoints bounded by resource ownership.
- Strict 300 byte target -> Some legitimate payloads will exceed it. Mitigation: classify heavy endpoints explicitly, paginate or summarize responses, and keep default auth/profile/bootstrap responses tiny.
- Frontend/backend contract drift -> Screens may break when auth or profile payloads become smaller. Mitigation: update typed DTOs, repositories, contract tests, and remove direct screen-level JSON parsing.

## Migration Plan

1. Add Redis configuration verification for `phpredis` and auth-specific key prefixes.
2. Add token issuer service for RS256/HS256 access tokens and opaque refresh tokens.
3. Add Redis-backed refresh token repository with hashed token storage, rotation, revocation, and TTLs.
4. Add protected-route middleware for access-token signature validation and Redis `jti` checks.
5. Update login, refresh, logout, and `/me` responses to the new token contract.
6. Audit existing API routes for monolithic payloads, missing authorization boundaries, payload size, and p95 latency.
7. Split heavy or multi-resource routes into granular endpoints and add explicit pagination or summary contracts where response bodies exceed the lightweight budget.
8. Update auth rate limiting to use Redis counters and generic error responses.
9. Update Flutter API client storage, cookie support, `dio` interceptors, typed DTOs, repositories, screen data loaders, and pooled request composition.
10. Audit frontend screens for legacy response assumptions and migrate them to the latest granular backend endpoints.
11. Deploy behind HTTPS-only configuration and validate cookie attributes, route timings, response sizes, and frontend contract compatibility in staging.
12. Roll back by disabling new clients and restoring previous auth routes only if legacy refresh tokens have not been invalidated; otherwise require re-login.

## Open Questions

- What exact refresh token idle and absolute TTLs should be used per platform?
- Should access-token `jti` state be implemented as an allow-list for every issued token or as a deny-list for revoked tokens only?
- Which service owns RS256 key rotation and public key distribution for microservices?
- Which endpoints must be classified as explicit heavy endpoints because their business payload cannot fit the default 300 byte budget?
- Which Flutter screens still parse raw response maps directly instead of using repository DTOs?
