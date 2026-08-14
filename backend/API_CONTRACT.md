# API Contract & Mobile Client Implementation Guide

This document outlines the strict requirements for integrating the mobile client (Flutter) with the hardened Laravel JWT Authentication system.

## 1. Transport & Storage

*   **X-Client-Type Preference**: The mobile client MUST send the HTTP header `X-Client-Type: mobile` on authentication requests (login, refresh).
*   **JSON Payload**: By sending this header, the backend will return the long-lived refresh token inside the JSON payload (`data.refresh_token`) instead of an `HttpOnly` cookie.
*   **Secure Storage**: The Flutter client MUST store the refresh token using platform-secure storage (e.g., `flutter_secure_storage` which uses Android Keystore / iOS Keychain). Do NOT store the refresh token in plaintext SharedPreferences.

## 2. Token Lifecycle & Concurrency

*   **Access JWT TTL**: 10 minutes.
*   **Refresh Token TTL**: 30 days.
*   **Single-Flight Refresh Mechanism**: The Flutter client MUST implement a single-flight refresh lock (e.g., using a boolean flag or a Mutex/Completer in Dart).
    *   If multiple API requests fail with `401 Unauthorized` simultaneously, only **ONE** refresh request may be sent to the backend.
    *   All other pending requests MUST wait for the result of that single refresh request.
*   **No Infinite Loops**: A single API request MUST NEVER perform unlimited refresh/retry loops. A maximum of ONE refresh attempt is allowed per failed request.

## 3. Refresh Outcomes

**If Refresh Succeeds:**
1.  Replace the old access token with the new access token in memory/storage.
2.  Replace the rotated refresh token with the new refresh token in Secure Storage.
3.  Retry the original pending request(s) exactly once using the new access token.
4.  *Never* retry a request using the old access token after a successful token refresh.

**If Refresh Fails (Authentication/Session-Revoked):**
1.  Do NOT retry the refresh indefinitely.
2.  Clear all local authentication credentials (access token, refresh token, user data).
3.  Transition the application to the unauthenticated/login state immediately.

## 4. Session Revocation & Reuse Detection

*   **Reuse Detection**: If the mobile client (or a malicious actor) attempts to use an old/rotated refresh token, the backend will detect this as a reuse attempt.
*   **Consequence**: The server will instantly revoke the **entire session (token family)**. The mobile client MUST treat this as a permanently invalid session and require a fresh login.
*   **Concurrency Safe**: The server uses Database Transactions and Row Locking (`lockForUpdate`). If the client fails to implement a single-flight lock and sends two refresh requests concurrently, the server will serialize them. The first will succeed, and the second will be treated as a "reuse" attempt, which will immediately revoke the session. It is CRITICAL that the client implements the single-flight mechanism to avoid accidentally locking the user out.

## 5. Security Trade-off Documentation

**Stateless JWT vs. Instant Revocation:**
Revoking a server-side session (e.g., via manual logout or reuse detection) prevents any future token refreshes. However, it does NOT instantly invalidate an already-issued stateless Access JWT. The access token remains valid until its maximum 10-minute expiry.
This is an intentional security/performance trade-off to avoid querying the database/Redis on every single API request. Do NOT attempt to solve this 10-minute window by adding unnecessary client-side tokens or pinging the server manually.
