## ADDED Requirements

### Requirement: English Database Naming Convention
The system SHALL use English naming conventions for all database tables and columns to ensure consistency and maintainability. Any legacy Indonesian terms MUST be translated.

#### Scenario: Translating table names
- **WHEN** a legacy table like `user_pihak` or `pihak_category` is encountered
- **THEN** it MUST be renamed to an English equivalent such as `user_sub_roles` and `sub_role_categories`.
