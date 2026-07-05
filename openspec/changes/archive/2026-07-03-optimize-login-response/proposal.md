## Why

The current API response for authentication (specifically `/api/auth/login`) returns an excessive amount of data (e.g., 1.7KB, multiple tokens, and a large user object). This slows down the response time (up to 1.47s) and sends unnecessary information to the frontend at login time. This change optimizes the auth response to only return the essential tokens and basic user information, leaving the rest to be fetched by request as needed.

## What Changes

- Modify the login/auth endpoints to only return the `access_token` for frontend usage.
- Reduce the `user` object in the auth response to only contain essential details: `name`, `username`, and `email`.
- Remove `refresh_token`, `session_token`, and other non-essential tokens from the default login response unless explicitly required by the architecture.
- Ensure the frontend can fetch any remaining user data by making a separate request using the provided `access_token`.
- **BREAKING**: The frontend will no longer receive full user objects or multiple token types upon login and must adjust to the new minimal response format.

## Capabilities

### New Capabilities
- `auth-response-optimization`: Optimize the authentication payload structure across the auth microservice.

### Modified Capabilities

## Impact

- **Affected Code**: Auth controllers and response formatting resources in the backend.
- **APIs**: Changes the payload format of `/api/auth/login` and potentially other auth routes.
- **Systems**: The frontend application will need to update how it parses the login response and handle fetching additional user details using the access token.
