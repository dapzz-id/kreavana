## 1. Backend Seeder Verification

- [x] 1.1 Run `php artisan db:seed` or `migrate:fresh --seed` (if not done) to verify the seeders populate the database without exceptions.
- [x] 1.2 Inspect `users`, `user_sub_roles`, `dashboard_stats` via Tinker to ensure `id` is a UUID and English role slugs are correctly mapped.

## 2. Frontend API Consumption Audit

- [x] 2.1 Verify login and session retrieval successfully map `sub_role` using English values without serialization errors.
- [x] 2.2 Verify profile and opportunities screens correctly parse the sub roles.
- [x] 2.3 Verify `CreatorApplicationCard.dart` successfully displays the updated categories to the user and can submit an application using the new slugs.

## 3. Bug Fixes (If any)

- [x] 3.1 Fix any mapping errors encountered during frontend verification.
- [x] 3.2 Ensure any hardcoded strings related to `sub_role` in the frontend are updated to English if missed previously.
