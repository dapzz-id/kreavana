## ADDED Requirements

### Requirement: Service Layer Implementation
The system SHALL encapsulate all business logic within dedicated Service classes, removing it from Controllers.

#### Scenario: Processing business logic
- **WHEN** a controller receives a valid request
- **THEN** it delegates the business operations to the appropriate Service class

### Requirement: Repository Pattern Implementation
The system SHALL abstract database interactions using the Repository pattern.

#### Scenario: Fetching data
- **WHEN** a Service needs to fetch or persist data
- **THEN** it calls the corresponding Repository class instead of using Eloquent models directly

### Requirement: Form Request Validation
The system SHALL use Form Request classes for all input validation.

#### Scenario: Validating input
- **WHEN** an endpoint receives input data
- **THEN** the payload is validated through a Form Request before reaching the Controller's main logic
