## 1. Database & Migrations

- [x] 1.1 Create migration to rename table `user_pihak` to `user_sub_roles`
- [x] 1.2 Create migration to rename table `pihak_category` to `sub_role_categories`
- [x] 1.3 Update column names if any (e.g., `pihak_slug` to `sub_role_slug` in `user_sub_roles`)
- [x] 1.4 Rename Model `UserPihak` to `UserSubRole` and `PihakCategory` to `SubRoleCategory`
- [x] 1.5 Run migrations to verify changes

## 2. Backend Logic Updates (Services & Repositories)

- [x] 2.1 Update Repositories related to the renamed models (`UserSubRoleRepository`, `SubRoleCategoryRepository`)
- [x] 2.2 Update Services that use these repositories (e.g. `ProfileService`, `AdminService`) to reflect the new class names and database references
- [x] 2.3 Refactor any authentication endpoints in `AuthController` or `AuthService` to ensure failed logins throw/return generic "Unauthorized" messages (code 401) without details like "Username/Email salah"
- [x] 2.4 Verify all API response formats conform to the OWASP requirement

## 3. Frontend Adjustments

- [x] 3.1 Update Flutter models to parse new keys if necessary (e.g. translating `selected_pihak` to `selected_sub_role` based on backend changes)
- [x] 3.2 Ensure frontend error handlers catch generic 401 messages properly without breaking
- [x] 3.3 Test API integrations (login, profile fetch, sub-role fetching) on the frontend

## 4. Testing & Verification

- [x] 4.1 Verify that authentication and profile endpoints correctly return the expected data format (e.g. login failure returns 401 with generic "Unauthorized" message instead of 404).
- [x] 4.2 Verify creator application and profile fetching still correctly map and return sub-roles.
