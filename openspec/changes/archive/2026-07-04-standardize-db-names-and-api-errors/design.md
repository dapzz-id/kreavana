## Context

Currently, the backend returns detailed error messages (like "Username/Email atau password salah") which is an anti-pattern for security (violates OWASP recommendations). This can be used for enumeration attacks.
Additionally, the database has tables and columns named in Indonesian (e.g., `user_pihak`, `pihak_category`), which makes the codebase inconsistent for English conventions. The `user_pihak` table acts as a mapping for sub-roles when a user is a creator.

## Goals / Non-Goals

**Goals:**
- Replace descriptive authentication errors with a generic "Unauthorized" message.
- Standardize database table and column names to English (`user_pihak` -> `user_sub_roles`, `pihak_category` -> `sub_role_categories` or similar).
- Ensure the frontend properly handles these generic errors and the updated table references without breaking.

**Non-Goals:**
- Complete restructuring of the entire database schema beyond the scope of translation/standardization of `pihak`.
- Altering the core authentication flow (JWT generation remains the same).

## Decisions

- **Generic API Errors**: Authentication endpoints will simply return 401 Unauthorized for any credential mismatch. The frontend will display this generic error to prevent user enumeration.
- **Database Renaming**:
  - `user_pihak` will be renamed to `user_sub_roles` because it explicitly maps a user to a specific sub-role (category) when they act as a creator.
  - `pihak_category` (and related columns/variables like `pihak_slug`) will be renamed to `sub_role_category` or `sub_role_slug`.
- **Migration Strategy**: We will create new Laravel migrations to rename the tables and columns to avoid losing existing data. We will also rename the Eloquent models from `UserPihak` to `UserSubRole` and `PihakCategory` to `SubRoleCategory`.

## Risks / Trade-offs

- [Risk: Broken Data Relations] → Mitigation: Ensure all foreign key constraints are properly dropped and re-added if necessary during the migration, or carefully rename columns before renaming tables.
- [Risk: Frontend Breakage] → Mitigation: The frontend must be rigorously updated and tested to consume the new generic error responses and any API response keys that change due to the column renames (e.g., replacing `selected_pihak` with `selected_sub_role`).
