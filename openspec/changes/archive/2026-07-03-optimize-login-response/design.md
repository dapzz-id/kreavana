## Context

The backend currently responds to authentication requests (like `/api/auth/login`) with a bloated JSON object containing multiple token types (access, refresh, session) and a large `user` object containing potentially sensitive or unnecessary fields for the immediate login state. This negatively affects response sizes and times. 

## Goals / Non-Goals

**Goals:**
- Optimize the auth response payload to only include `access_token` and a minimal `user` object (`name`, `username`, `email`).
- Reduce response times for login endpoints.
- Require clients to fetch full user details on-demand via a separate authenticated request to `/api/auth/me` or similar endpoints.
- Resolve Git merge conflicts in Flutter frontend files (`dashboard_screen.dart`, `direct_message_screen.dart`, `profile_screen.dart`) resulting from the latest pull.
- Verify if the microservice architecture has been consistently applied across all endpoints, especially those recently pulled. If not, refactor them into microservices following OWASP security standards.

**Non-Goals:**
- Changing the underlying authentication mechanism (e.g., JWT).
- Altering the user schema in the database.
- Modifying how tokens are generated.

## Decisions

- **Modify `respondWithToken` or similar helper methods:** Update the method that generates the token array to exclude `refresh_token` and `session_token` if they are not actively used by the frontend. If they are used, we will need to reconsider, but the goal is to only send `access_token`.
- **Return explicit User Resource:** Instead of returning the full `$user` model, return an array or a specific API Resource class containing only `name`, `username`, and `email` for the `user` field in the response.

## Risks / Trade-offs

- **Risk:** Frontend relies on the omitted fields (like `role`, `avatar_url`, `id`) immediately after login.
  - **Mitigation:** Communicate to frontend developers that they need to call the `/api/auth/me` endpoint to retrieve complete profile information after storing the `access_token`. Alternatively, we can include `role` and `id` if they are deemed strictly essential for routing right after login, but we'll try to stick to `name`, `username`, and `email` as requested.
