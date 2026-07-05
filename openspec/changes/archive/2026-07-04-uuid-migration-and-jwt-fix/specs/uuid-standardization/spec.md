## ADDED Requirements

### Requirement: Database UUID Standardization
The system SHALL use UUIDs for all primary keys in the database schema instead of auto-incrementing integers, and all foreign key relationships SHALL reference these UUIDs accordingly.

#### Scenario: User registration with UUID
- **WHEN** a new entity is created in any database table
- **THEN** it is assigned a valid UUID string as its primary key instead of an integer.
