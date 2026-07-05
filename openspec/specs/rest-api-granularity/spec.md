## ADDED Requirements

### Requirement: Granular Resource Routing
The system SHALL implement modular REST API routes, ensuring that each logical operation or resource (e.g., getting a role, fetching profile history, updating a specific field) has its own dedicated endpoint (GET, POST, PUT, PATCH, DELETE).

#### Scenario: Fetching user roles
- **WHEN** a client needs to retrieve available roles or the current user's role
- **THEN** the client MUST call a specific endpoint (e.g. `/api/roles`) rather than extracting this from a monolithic `/api/auth/me` response.

### Requirement: UUID Primary Keys
The system SHALL use UUIDs (Universally Unique Identifiers) as the primary key (`uid`) for the `users` entity and all corresponding foreign keys across the database.

#### Scenario: User creation
- **WHEN** a new user is created
- **THEN** the system assigns a UUID as their primary identifier.
