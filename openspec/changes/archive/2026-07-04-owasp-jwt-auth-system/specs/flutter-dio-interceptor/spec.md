## ADDED Requirements

### Requirement: Dio HTTP client with automatic token refresh interceptor
The Flutter frontend SHALL use `dio` as the HTTP client with an `InterceptorsWrapper` that automatically handles 401 responses by calling `/auth/refresh` and retrying the original request.

#### Scenario: Expired access token is refreshed transparently
- **WHEN** the Flutter app makes an API call and receives HTTP 401
- **THEN** the Dio interceptor automatically calls `POST /auth/refresh`
- **AND** if refresh succeeds, the original request is retried with the new access token
- **AND** the user does not see any error or forced logout

#### Scenario: Refresh also fails (session expired)
- **WHEN** the Dio interceptor calls `/auth/refresh` and also receives 401 or failure
- **THEN** all stored tokens are cleared from `flutter_secure_storage`
- **AND** the user is redirected to the login screen

#### Scenario: Concurrent 401 responses do not cause multiple refresh calls
- **WHEN** multiple API calls return 401 simultaneously
- **THEN** only one refresh request is made to `/auth/refresh`
- **AND** all pending requests are retried after the single refresh completes

### Requirement: Access token stored in flutter_secure_storage
The Flutter app SHALL store the access token exclusively in `flutter_secure_storage`, which uses OS-level encryption (iOS Keychain / Android Keystore). The use of `SharedPreferences` for token storage is explicitly prohibited.

#### Scenario: Token survives app restart securely
- **WHEN** the user closes and reopens the app
- **THEN** the access token is retrieved from `flutter_secure_storage`
- **AND** the token is not accessible from external processes or unrooted device inspection
