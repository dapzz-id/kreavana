## MODIFIED Requirements

### Requirement: Define standard creator sub-roles
The backend SHALL enforce a definitive set of 11 sub-roles for users with the `creator` role. The available sub-roles MUST be exactly: Institusi, Pemerintah, MC, Penyanyi, Wedding Organizer, Event Organizer, Komunitas, Makeup Artist, Fotografer, Editor, Videografer. The previous `lainnya` catch-all is removed.

#### Scenario: Sub-roles are available in the system
- **WHEN** the system initializes or migrates
- **THEN** the `sub_role_categories` table contains exactly the 11 defined entries and the backend enum mirrors them

#### Scenario: Invalid sub-role is rejected
- **WHEN** a creator application submits a `sub_role_category` not in the defined 11
- **THEN** the system returns a 422 validation error

## ADDED Requirements

### Requirement: Opportunity and dashboard tables use sub_role_slug
The `opportunities` and `dashboard_stats` tables SHALL use the column name `sub_role_slug` (not `pihak_slug`) for consistency with the rest of the schema.

#### Scenario: Querying opportunities by sub_role_slug
- **WHEN** a client filters opportunities by creator type
- **THEN** the filter parameter is `sub_role_slug` and matches the `sub_role_slug` column in the database
