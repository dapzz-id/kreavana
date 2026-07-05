# Staging Verification Runbook — `add-secure-token-auth`

This checklist must be run against the **staging environment** before promoting the `add-secure-token-auth` changes to production. Each item maps to a security or performance invariant defined in the design and specs.

---

## Pre-flight

| # | Check | Command / How to verify |
|---|-------|------------------------|
| P1 | Staging server reachable via HTTPS | `curl -I https://<staging-host>/api/health` → `HTTP/2 200` |
| P2 | No HTTP fallback (HTTP must redirect or refuse) | `curl -I http://<staging-host>/api/health` → `301`/`308` or connection refused |
| P3 | Correct TLS certificate (not self-signed) | `curl -v https://<staging-host>/api/health 2>&1 \| grep "SSL certificate"` |
| P4 | `.env` has `APP_ENV=staging` (or `production`) — not `local` | SSH to server, `grep APP_ENV .env` |
| P5 | `APP_DEBUG=false` on staging | `grep APP_DEBUG .env` |

---

## 1. RS256 Production Config

| # | Check | Command / How to verify |
|---|-------|------------------------|
| 1.1 | `JWT_ALGO=RS256` in staging `.env` | `grep JWT_ALGO .env` → `RS256` |
| 1.2 | Private key path set and file readable by web user | `grep JWT_PRIVATE_KEY .env`; `ls -la <path>` |
| 1.3 | Public key path set and file readable | `grep JWT_PUBLIC_KEY .env`; `ls -la <path>` |
| 1.4 | Login returns a valid RS256-signed JWT | Login via API, decode the `access_token` header at [jwt.io](https://jwt.io) → `alg: RS256` |
| 1.5 | JWT payload contains only `sub`, `role`, `permissions`, `jti`, `iat`, `exp` — no PII | Decode token, confirm no `email`, `name`, `phone` fields |
| 1.6 | Access token TTL ≤ 5 minutes | Decode `exp - iat` → ≤ 300 seconds |

```bash
# Quick JWT decode without jwt.io (bash)
TOKEN="<paste access_token here>"
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool
```

---

## 2. Redis Connectivity

| # | Check | Command / How to verify |
|---|-------|------------------------|
| 2.1 | Laravel can reach Redis | `php artisan tinker --execute="echo Redis::ping();"` → `PONG` |
| 2.2 | Redis driver is `phpredis` | `grep REDIS_CLIENT .env` → `phpredis`; `php -m \| grep redis` |
| 2.3 | JTI is written to Redis on login | Login, copy `jti` from decoded token; `redis-cli GET "jti:<jti>"` → non-empty value |
| 2.4 | JTI is deleted from Redis on logout | Logout via API; `redis-cli GET "jti:<jti>"` → `(nil)` |
| 2.5 | Refresh token hash stored in Redis | After login, `redis-cli KEYS "refresh:*"` → at least one key |
| 2.6 | Old refresh key deleted after rotation | Refresh once, note old key; refresh again; old key should be `(nil)` |
| 2.7 | Rate limit keys appear in Redis | Hit `/api/auth/login` 6+ times; `redis-cli KEYS "rate:auth-login:*"` → key(s) present |

---

## 3. Cookie Attributes

| # | Check | Command / How to verify |
|---|-------|------------------------|
| 3.1 | `Set-Cookie` header present on login response | `curl -v -X POST https://<host>/api/auth/login -d '{"email":"...","password":"..."}' -H 'Content-Type: application/json' 2>&1 \| grep -i set-cookie` |
| 3.2 | Cookie name is `refresh_token` | Output above → `refresh_token=<value>` |
| 3.3 | `HttpOnly` flag set | Cookie line includes `HttpOnly` |
| 3.4 | `Secure` flag set | Cookie line includes `Secure` |
| 3.5 | `SameSite=Strict` set | Cookie line includes `SameSite=Strict` |
| 3.6 | `Path=/api/auth/refresh` set | Cookie line includes `Path=/api/auth/refresh` |
| 3.7 | Cookie not present in login JSON body | Decode login response JSON → no `refresh_token` field in `data` |
| 3.8 | Refresh cookie sent back correctly on `/api/auth/refresh` | Pass cookie header to refresh endpoint; new cookie returned |

```bash
# Full login+cookie check in one command
curl -si -X POST https://<host>/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@test.com","password":"secret"}' \
  | grep -iE '(set-cookie|access_token)'
```

---

## 4. Route Latency (p95 < 250ms application time)

Test with a valid access token. Measure **application response time** via `X-Response-Time-Ms` header (instrumented by `ApiPerformanceBudget` middleware).

| # | Endpoint | Expected `X-Response-Time-Ms` |
|---|----------|-------------------------------|
| 4.1 | `GET /api/profile/identity` | < 250ms |
| 4.2 | `GET /api/profile/permissions` | < 250ms |
| 4.3 | `GET /api/dashboard/stats` | < 250ms |
| 4.4 | `GET /api/notifications` | < 250ms |
| 4.5 | `POST /api/auth/login` | < 250ms |
| 4.6 | `POST /api/auth/refresh` | < 250ms |

```bash
# Latency check via curl (repeat 10x and take max)
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "%{time_total}\n" \
    -H "Authorization: Bearer <token>" \
    https://<host>/api/profile/identity
done
```

Or check the `X-Response-Time-Ms` response header directly:
```bash
curl -si -H "Authorization: Bearer <token>" \
  https://<host>/api/profile/identity \
  | grep -i x-response-time
```

---

## 5. Response Size (lightweight endpoints < 300 bytes)

| # | Endpoint | Expected size |
|---|----------|--------------|
| 5.1 | `POST /api/auth/login` (body only) | < 300 bytes |
| 5.2 | `POST /api/auth/refresh` | < 300 bytes |
| 5.3 | `POST /api/auth/logout` | < 300 bytes |
| 5.4 | `GET /api/profile/identity` | < 300 bytes |
| 5.5 | `GET /api/profile/permissions` | < 300 bytes |

```bash
# Check response size in bytes
curl -s -o /tmp/resp.json \
  -H "Authorization: Bearer <token>" \
  https://<host>/api/profile/identity \
  && wc -c /tmp/resp.json
```

Or check the `X-Response-Bytes` header (set by `ApiPerformanceBudget` middleware):
```bash
curl -si -H "Authorization: Bearer <token>" \
  https://<host>/api/profile/identity \
  | grep -i x-response-bytes
```

---

## 6. Security / Auth Flow

| # | Check | Expected |
|---|-------|----------|
| 6.1 | Access a protected route with no token | `401 Unauthorized` with generic message |
| 6.2 | Access a protected route with expired token (wait 5 min or forge `exp`) | `401 Unauthorized` with generic message |
| 6.3 | Access a protected route with a valid token after logout (revoked JTI) | `401 Unauthorized` — proves JTI revocation works |
| 6.4 | Reuse an old refresh cookie after rotation | `401 Unauthorized` — proves refresh token reuse detection |
| 6.5 | Access a creator-only route as a `user` role | `403 Forbidden` with generic message |
| 6.6 | Access an admin-only route as a `creator` role | `403 Forbidden` with generic message |
| 6.7 | Hit `/api/auth/login` 6+ times rapidly | `429 Too Many Requests` with generic message |
| 6.8 | `auth/login` response body contains no `refresh_token` field | Inspect JSON body — must be absent |

---

## 7. Frontend API Compatibility

Run the Flutter app connected to the staging backend URL and verify:

| # | Screen / Flow | Expected behavior |
|---|---------------|------------------|
| 7.1 | Login as `user` | Success; profile loads via `profile/identity` |
| 7.2 | Login as `creator` | Success; application status loads via `profile/application` |
| 7.3 | Login as `admin` | Success; admin dashboard loads |
| 7.4 | Navigate to Profile screen | Displays name, follower counts, role badge — no crash |
| 7.5 | Navigate to Dashboard screen | Stats load; wallet balance displayed |
| 7.6 | Wait for access token to expire (~5 min), then navigate | Token silently refreshed; no logout |
| 7.7 | Force-clear refresh cookie (clear app storage), then navigate | App signs out and shows login screen |
| 7.8 | Creator application submission | Submits to `POST /api/profile/apply-creator` |
| 7.9 | Wallet top-up | Submits to `POST /api/wallet/topup`; balance updates |
| 7.10 | Profile update (name/phone) | Submits to `PUT /api/profile`; screen updates |

**No screen should call `/api/auth/me` or `GET /api/profile` (monolithic).** Monitor with:
```bash
# On staging server — watch for legacy endpoint hits
tail -f storage/logs/laravel.log | grep -E '(auth/me|GET /api/profile[^/])'
```

---

## 8. Rollback Behavior

If a critical issue is found post-deploy, the rollback procedure is:

| Step | Action |
|------|--------|
| 1 | `git revert <merge-commit>` or deploy previous release tag |
| 2 | Run `php artisan migrate:rollback` if new migrations were applied |
| 3 | Flush Redis auth state: `redis-cli FLUSHDB` (caution: logs out all active sessions) |
| 4 | Swap `.env` back to previous `JWT_ALGO`, `JWT_SECRET`, and key paths |
| 5 | Restart PHP-FPM / Octane: `php artisan octane:restart` or `sudo systemctl restart php8.x-fpm` |
| 6 | Verify health endpoint responds: `curl https://<host>/api/health` |
| 7 | Confirm login works with old Flutter app build (if not yet force-updated) |

> [!CAUTION]
> `FLUSHDB` clears **all** Redis data in the selected database. If Redis is shared with queue workers or cache, use targeted key deletion instead:
> ```bash
> redis-cli --scan --pattern "jti:*" | xargs redis-cli DEL
> redis-cli --scan --pattern "refresh:*" | xargs redis-cli DEL
> redis-cli --scan --pattern "rate:*" | xargs redis-cli DEL
> ```

---

## Sign-off

All checks above must pass (or have an accepted exception with justification) before this change is promoted to production.

| Verifier | Date | Notes |
|----------|------|-------|
| | | |
