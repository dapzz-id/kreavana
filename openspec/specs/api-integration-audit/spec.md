## Purpose
Defines the expectations for frontend API integration, specifically handling data parsing and displaying data using English sub-roles properly without serialization errors.

## Requirements

### Requirement: Frontend API compatibility with English Sub Roles
The frontend MUST correctly consume the API data containing the newly structured English sub roles (e.g., `institution`, `photographer`, etc.) through typed API models that match the latest backend response contracts.

#### Scenario: User visits Creator application page
- **WHEN** user navigates to the Creator Application form
- **THEN** the dropdown correctly lists the English category slugs and names from the dedicated backend endpoint
- **AND** submitting the application successfully saves with the English category slug.

#### Scenario: User views Profile and Opportunities
- **WHEN** user views their profile and opportunities
- **THEN** the sub roles correctly parse and display the correct information without relying on monolithic auth or profile payloads.

### Requirement: Frontend consumes secure auth contract
The Flutter frontend MUST consume the latest backend auth contract where login and refresh responses return an access token in JSON while refresh tokens are managed only by secure cookies.

#### Scenario: Login consumes minimal auth response
- **WHEN** the Flutter client receives a successful login response
- **THEN** it parses the `access_token` and token metadata from JSON, stores sensitive client-held auth state securely, and does not expect a `refresh_token` or full user profile in the response body.

#### Scenario: Refresh consumes cookie-backed response
- **WHEN** the Flutter client refreshes authentication through `/api/auth/refresh`
- **THEN** it sends the refresh cookie through the configured HTTP client, parses the new `access_token`, and does not read or store a refresh token from JSON.

### Requirement: Frontend uses typed backend DTOs
The Flutter frontend SHALL define typed DTOs or model factories for updated backend responses and MUST avoid direct screen-level parsing of raw response maps for auth, profile, role, permission, creator application, and other changed API contracts.

#### Scenario: Repository parses response
- **WHEN** a screen needs data from a changed backend endpoint
- **THEN** it calls a repository method that returns typed data parsed from the backend response contract.

#### Scenario: Unexpected response shape is handled safely
- **WHEN** the backend returns an unexpected or invalid response shape
- **THEN** the frontend maps it to a safe generic error state without exposing sensitive backend details.

### Requirement: Frontend consumes granular route contracts
The Flutter frontend SHALL load data from the latest granular backend endpoints instead of relying on legacy monolithic responses for user profile, role metadata, permissions, history, creator application state, and other heavy resources.

#### Scenario: Profile screen composes granular resources
- **WHEN** the profile screen requires identity, role metadata, permissions, and history
- **THEN** the frontend calls the dedicated resource endpoints and composes the result client-side.

#### Scenario: Legacy auth payload assumption is removed
- **WHEN** a screen needs user profile or permission details after login
- **THEN** it fetches those details from dedicated authenticated endpoints rather than reading them from the login response.

### Requirement: Frontend pooled API composition
The Flutter frontend MUST use a bounded request pool for screens that need multiple independent backend resources, with no more than 5 concurrent API calls by default.

#### Scenario: Screen fetches five resources
- **WHEN** a screen needs five independent resources
- **THEN** the frontend requests them through a bounded pool with a maximum concurrency of 5 and combines the typed results.

#### Scenario: Pooled call handles refresh once
- **WHEN** one or more pooled API calls receives a 401 response
- **THEN** the frontend performs a single-flight refresh and retries each failed original request at most once.

### Requirement: Frontend generic error mapping
The Flutter frontend MUST map backend generic authentication and authorization errors to generic user-facing states that do not reveal whether accounts, roles, permissions, or resources exist.

#### Scenario: Login failure remains generic
- **WHEN** login fails because of an unknown account or invalid password
- **THEN** the frontend shows the same generic authentication failure state.

#### Scenario: Forbidden resource remains generic
- **WHEN** a granular protected route returns a forbidden response
- **THEN** the frontend shows a generic access-denied state without exposing protected resource existence.
