## Context

Currently, the `sub_role` data structure isn't properly aligned with the actual needs of the platform. We need distinct categories to handle various types of creators, such as Government (Pemerintah), Singers, Institutions, Wedding Organizers, Event Organizers, MCs, and Communities. These need to be consistently defined in both the database and the backend enums.

## Goals / Non-Goals

**Goals:**
- Seed the `sub_role_categories` table with the requested comprehensive list of roles.
- Update `App\Enums\CreatorSubRole` to strictly reflect these new roles.
- Ensure API and application logic (e.g., Creator Applications) gracefully handle these new types.
- Enhance route authorization middleware to support checking specific sub-roles (e.g., allowing access only to `creator` with `sub_role` `pemerintah`) alongside generic role-based checks.

**Non-Goals:**
- Completely restructuring how the frontend displays these roles (we only ensure backend data is correct and ready for the frontend).

## Decisions

- We will modify `App\Enums\CreatorSubRole` to include cases for all new roles requested by the user, generating clean, standard slugs for each (e.g., `institusi`, `pemerintah`, `mc`, `penyanyi`, `wedding_organizer`, `event_organizer`, `komunitas`).
- The seeder for `sub_role_categories` (which may currently reside in `RemainingTablesSeeder` or a dedicated seeder) will be updated to insert these exact categories, complete with default descriptions, icons, and colors.
- We will update the existing `RoleMiddleware` or create a new `SubRoleMiddleware` that can parse route definitions (like `middleware('role:creator,pemerintah')`) to validate a user's exact sub-role.

## Risks / Trade-offs

- **Risk:** Existing creators mapped to old sub-roles (like `kreator` or `lainnya`) might encounter issues if the enum drops those values. 
- **Mitigation:** We will keep a fallback/default or migrate existing users to a mapped category if necessary, but this is a fresh setup so resetting or updating seeders directly should suffice.
