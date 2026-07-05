## Why

To comply with OWASP security standards, API endpoints should not leak sensitive system information (such as indicating whether a username exists during failed login). We need to return generic error messages (e.g., "Unauthorized").
Additionally, there's a need to standardize database table and column names to English (like renaming `user_pihak` to clarify its purpose as a sub-role mapping) to improve code maintainability and convention consistency. This also requires syncing changes to the frontend.

## What Changes

- Modify API error responses in the backend (especially authentication) to return generic, secure messages instead of descriptive errors that might disclose information to attackers.
- Rename the `user_pihak` table and any related Indonesian-named tables/columns (like `pihak_category`) to standard English (e.g., `user_sub_roles` and `sub_role_categories`), and update all relevant Models, Migrations, Repositories, and Services to reflect this.
- Clarify the usage of `user_pihak` as a mapping for creator sub-roles.
- Adjust the Flutter frontend code to consume the new generic error responses gracefully and adapt to any data structure changes caused by table renames, ensuring no errors.

## Capabilities

### New Capabilities
- `db-naming-standardization`: Defines the standard for English naming conventions for database tables and columns in the project, particularly translating legacy Indonesian terms.

### Modified Capabilities
- `auth-response-optimization`: Changing the requirement for error messages to be generic for OWASP compliance.
- `creator-sub-roles`: Adjusting the database schema underlying sub-roles (translating `user_pihak` and `pihak_category` to English equivalents).

## Impact

- **Backend**: Modifications across AuthController, relevant Services, Models (`UserPihak`, `PihakCategory`), Repositories, and new Migrations for renaming.
- **Database**: Schema changes (table/column renames).
- **Frontend**: API response parsing updates (handling generic errors) and data model adjustments in the Flutter app.
