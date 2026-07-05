## MODIFIED Requirements

### Requirement: Granular Resource Routing
The system SHALL implement modular microservice-style REST API routes, ensuring that each logical operation or resource (e.g., getting a role, fetching profile history, updating a specific field) has its own dedicated endpoint (GET, POST, PUT, PATCH, DELETE). Each route MUST own a bounded response shape, apply route-specific authorization, and avoid returning unrelated heavy data.

#### Scenario: Fetching user roles
- **WHEN** a client needs to retrieve available roles or the current user's role
- **THEN** the client MUST call a specific endpoint (e.g. `/api/roles`) rather than extracting this from a monolithic `/api/auth/me` response.

#### Scenario: Heavy profile data is split
- **WHEN** a screen needs profile identity, role metadata, permissions detail, and profile history
- **THEN** the backend exposes separate bounded endpoints for those resources instead of returning all data from one monolithic profile endpoint.

## ADDED Requirements

### Requirement: Enterprise route performance budget
The system SHALL design and monitor API routes so each normal JSON route targets p95 application response time below 250ms. Routes that cannot meet this target because of heavy processing MUST be split, cached, paginated, queued, or explicitly classified as asynchronous/heavy endpoints.

#### Scenario: Normal route meets latency budget
- **WHEN** a normal protected JSON route is exercised under expected production-like load
- **THEN** the measured application p95 response time is below 250ms.

#### Scenario: Heavy route exceeds latency budget
- **WHEN** a route requires expensive aggregation or large downstream reads that exceed the 250ms p95 target
- **THEN** the route is split into bounded resource endpoints, backed by cache, paginated, or converted to an asynchronous flow.

### Requirement: Lightweight response size budget
The system SHALL keep lightweight JSON response bodies below 300 bytes by default. If required data would exceed 300 bytes, the route MUST return a smaller summary, page, identifier list, or be split into dedicated resource endpoints with explicit limits.

#### Scenario: Auth response stays lightweight
- **WHEN** a user logs in, refreshes a token, or calls another lightweight auth endpoint
- **THEN** the JSON response body is below 300 bytes and excludes heavy user profile data.

#### Scenario: Oversized response is split
- **WHEN** a planned route response would exceed 300 bytes because it includes multiple resources or heavy nested data
- **THEN** the backend exposes separate granular routes so the client can request only the required resource slices.

### Requirement: Pooled client composition
Clients SHALL compose screens that need multiple independent resources by calling granular routes through bounded request pools rather than relying on monolithic backend responses. The default pool concurrency MUST be no more than 5 simultaneous route calls unless a route-specific limit is documented.

#### Scenario: Client composes screen from route pool
- **WHEN** a Flutter screen needs five independent resources to render
- **THEN** the client fetches those resources through a bounded pool of up to 5 concurrent API calls and combines the results client-side.

#### Scenario: Pool respects auth refresh behavior
- **WHEN** one or more pooled requests receives a 401 response
- **THEN** the client uses the single-flight refresh flow and retries each original request at most once after refresh succeeds.

### Requirement: OWASP-aligned route boundaries
Every API route SHALL enforce authentication, authorization, input validation, output minimization, rate limiting where abuse-sensitive, and generic security-safe error responses according to the route's risk profile.

#### Scenario: Protected route applies security controls
- **WHEN** a protected route receives a request
- **THEN** the system validates the access token, checks Redis `jti` state, applies route-specific authorization, validates input, and returns only the minimum authorized response fields.

#### Scenario: Unauthorized route response is generic
- **WHEN** a caller lacks permission for a granular route
- **THEN** the system returns a generic unauthorized or forbidden response without revealing unrelated resource existence or sensitive details.
