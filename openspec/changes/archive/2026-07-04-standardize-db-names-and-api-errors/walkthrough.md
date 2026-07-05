# Standardize Database Names and API Errors

The implementation for standardizing DB names and API errors is complete! We have fully replaced references to `pihak` with English equivalents and tightened our API responses to adhere to OWASP guidelines.

## Changes Made

### 1. Database & Migrations
- Executed migration to rename tables: `user_pihak` to `user_sub_roles` and `pihak_categories` to `sub_role_categories`.
- Renamed columns in `users`, `user_sub_roles`, and `creator_applications` to `selected_sub_role` and `sub_role_slug`.
- Renamed Eloquent Models `UserPihak` and `PihakCategory` to `UserSubRole` and `SubRoleCategory`.
- Updated `$fillable` arrays to match the new columns.

### 2. Backend Logic Updates (Services, Repositories, Middlewares)
- Updated `UserSubRoleRepository` and `SubRoleCategoryRepository` to reference the new models.
- Updated `AdminService`, `DashboardService`, `OpportunityService`, `ProfileService`, and `AuthService` to use the updated repository names and column mapping correctly.
- Mapped old keys like `pihak_category` to `sub_role_category` and `pihak_slug` to `sub_role_slug` in responses across all APIs (`DashboardController`, `OpportunityController`, etc.).
- Standardized the API responses in `RoleMiddleware` and `PermissionMiddleware` to return `{ "status": false, "message": "Unauthorized" }` or `"Forbidden"` without exposing internal validation errors to attackers.
- Updated `AuthController.php` and `bootstrap/app.php` to throw a generic `"Unauthorized"` message for bad logins and expired sessions.

### 3. Frontend Adjustments
- Replaced `pihak` with `subRole` throughout the entire `d:\Kreavana\frontend\lib` directory using an automated script.
- Ensured Models (`user_model.dart`, `opportunity_model.dart`) can successfully parse `sub_role_slug` and `selected_sub_role` from the updated API schema.
- Updated `ApplyCreatorRequest` mapping and frontend form submissions to send `sub_role_category`.

## Validation
- `flutter analyze` was run and verified no critical syntax errors remain in Dart.
- Checked JSON structures returned by Controllers against frontend parsers.
- All tasks in `tasks.md` are marked complete!

You can now review the application and perform further end-to-end testing. When you're ready, we can run `/opsx-archive` to finalize this change!
