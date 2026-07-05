## 1. Update Database Constants and Enums

- [x] 1.1 Update `App\Enums\CreatorSubRole` with the new categories (`institusi`, `pemerintah`, `mc`, `penyanyi`, `wedding_organizer`, `event_organizer`, `komunitas`, dll) and their respective labels.

## 2. Update Database Seeding

- [x] 2.1 Update `RemainingTablesSeeder` (or create a new seeder if necessary) to dynamically insert the new specific sub-roles into the `sub_role_categories` table, ensuring properties like `slug`, `name`, `description`, `icon`, and `color` are properly set.

## 3. Verify Application Logic

- [x] 3.1 Verify that the creator application submission endpoint properly validates the new `sub_role_category` slugs against the `sub_role_categories` table or the enum.
- [x] 3.2 Verify that profile updates for a creator can correctly save and return the new sub-role.
- [x] 3.3 Create or update the route authorization middleware (e.g., `RoleMiddleware`) to support sub-role validation (e.g., parsing `middleware('role:creator:pemerintah')`) and restricting access accordingly.

## 4. Run Migration and Testing

- [x] 4.1 Run `php artisan migrate:fresh --seed` to ensure the database correctly populates the new categories without constraint errors.
- [x] 4.2 Test via API endpoints to ensure the enum mappings resolve accurately and no 500 errors occur when fetching profiles or applying as a creator.
