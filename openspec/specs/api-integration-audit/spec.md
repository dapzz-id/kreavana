## Purpose
Defines the expectations for frontend API integration, specifically handling data parsing and displaying data using English sub-roles properly without serialization errors.

## ADDED Requirements

### Requirement: Frontend API compatibility with English Sub Roles
The frontend MUST correctly consume the API data containing the newly structured English sub roles (e.g. `institution`, `photographer`, etc.).

#### Scenario: User visits Creator application page
- **WHEN** user navigates to the Creator Application form
- **THEN** the dropdown correctly lists the English category slugs and names
- **AND** submitting the application successfully saves with the English category slug.

#### Scenario: User views Profile and Opportunities
- **WHEN** user views their profile and opportunities
- **THEN** the sub roles correctly parse and display the correct information.
