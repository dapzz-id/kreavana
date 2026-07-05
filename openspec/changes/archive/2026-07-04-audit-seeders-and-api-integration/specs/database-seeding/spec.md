## ADDED Requirements

### Requirement: Consistent Seeding with English Enums and UUIDs
The seeders MUST correctly utilize UUIDs for relational mapping (e.g. `user_id` inside `dashboard_stats` or `user_sub_roles`) and English sub role slugs.

#### Scenario: Running db:seed
- **WHEN** user executes `php artisan db:seed`
- **THEN** all seeders run without failure
- **AND** the data successfully aligns with the `CreatorSubRole` enum constraints.
