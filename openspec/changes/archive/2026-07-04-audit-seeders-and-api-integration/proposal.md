## Why

We have recently made several database schema changes, refactored migrations, and updated the `sub_role` mappings to English. We need to audit the backend seeders to ensure they correctly reflect these changes and populate the database without errors. Furthermore, we must verify that the frontend correctly consumes the updated backend APIs and doesn't encounter any errors due to the recent refactoring.

## What Changes

- Audit all backend seeders (e.g., `UserSeeder`, `RemainingTablesSeeder`, `OpportunityLocationSeeder`) to ensure data consistency with the latest migrations (especially English roles and UUID usage).
- Run the frontend application and test API integration points (e.g., fetching profile, login, creator application, opportunities) to identify any mapping or parsing errors.
- Fix any identified issues in the seeders or frontend models/services.

## Capabilities

### New Capabilities
- `api-integration-audit`: Audit of the frontend API integration to ensure compatibility with recent backend changes.

### Modified Capabilities
- `database-seeding`: Update the database seeding logic to align with the latest consolidated migrations and English role definitions.

## Impact

- **Backend**: Modifications to seeder files to ensure correct test data generation.
- **Frontend**: Potential updates to API service files, data models, or UI components to handle updated backend responses correctly.
