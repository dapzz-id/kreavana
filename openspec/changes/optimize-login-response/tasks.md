## 1. Analysis

- [ ] 1.1 Locate `respondWithToken` or similar token response methods in `app/Http/Controllers/API/Auth/UserAuthController.php` (and others if applicable, like `CreatorAuthController`, `AdminAuthController`).
- [ ] 1.2 Identify where the `$user` object is fetched and returned alongside the token.

## 2. Implementation

- [ ] 2.1 Modify the response payload to ONLY include `access_token` and the minimal `user` data (`name`, `username`, `email`).
- [ ] 2.2 Remove `refresh_token`, `session_token`, and other unused token details from the default login response.
- [ ] 2.3 Ensure that `/api/auth/me` or the profile endpoint returns the full user object including `role` and `permissions` so the frontend can retrieve them.

## 3. Testing & Verification

- [ ] 3.1 Test login via `/api/auth/user/login` (and other related endpoints) to verify the response size is reduced and only contains the access token and minimal user data.
- [ ] 3.2 Test the `/api/auth/me` endpoint to verify it correctly returns the full user profile data.
- [ ] 3.3 Verify no breaking changes occur in the backend testing suite due to missing fields in the auth response.
