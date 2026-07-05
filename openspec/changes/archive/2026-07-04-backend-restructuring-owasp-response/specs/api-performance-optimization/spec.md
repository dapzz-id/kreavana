## ADDED Requirements

### Requirement: Server Request Time Optimization
The system SHALL ensure that all API routes respond in under 300ms.

#### Scenario: Normal API usage
- **WHEN** a client makes a request to any API endpoint
- **THEN** the server must process the request and respond within 300 milliseconds

### Requirement: Data Minimization
The system SHALL only return data strictly necessary for the requested context, avoiding large payloads and excessive eager loading.

#### Scenario: Requesting data with heavy relations
- **WHEN** a client requests an endpoint that previously returned extensive relational data
- **THEN** the system must omit unnecessary data to improve performance
- **AND** the system must provide separate endpoints for clients to fetch that relational data if needed

### Requirement: Frontend Adjustment for New Routes
The frontend applications SHALL be updated to consume data from the newly split endpoints if they previously relied on monolithic data payloads.

#### Scenario: Fetching supplementary data
- **WHEN** the frontend requires data that was removed from a primary API route
- **THEN** the frontend must make a separate, subsequent request to the newly created specific route to fetch that data
