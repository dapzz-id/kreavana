## Why

The system currently distinguishes between two main roles: `user` and `creator`. However, creators can be of various types (e.g., Institutions, Government, MC, Singer, Wedding Organizer, Event Organizer, Community). We need to properly categorize creators using the `sub_role` field to reflect their specific profession or entity type. This allows the platform to offer targeted opportunities, better searchability, and tailored experiences for each creator type.

## What Changes

- Redefine and populate the dynamic `sub_role` category data in the database.
- Create a migration/seeder for the comprehensive list of creator sub-roles (Institusi, Pemerintah, MC, Penyanyi, Wedding Organizer, Event Organizer, Komunitas, dll).
- Update the backend enum `App\Enums\CreatorSubRole` to include all the specified sub-roles.
- Ensure the `sub_role` is treated dynamically in the database (`sub_role_categories` table) while keeping the enum aligned with the core predefined types used for system logic.

## Capabilities

### New Capabilities
- `creator-sub-roles`: Comprehensive categorization of creators into specific entity/profession types (Institusi, Pemerintah, MC, Penyanyi, WO, EO, Komunitas).

### Modified Capabilities
- `user-roles`: Updates the creator role to enforce selection and validation against the newly expanded `sub_role` list.

## Impact

- `App\Enums\CreatorSubRole` enum will be expanded.
- Database seeder for `sub_role_categories` will be updated to insert the dynamic data.
- API validation and logic handling creator applications or profile updates will accept the newly defined sub-roles.
