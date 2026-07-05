## 1. Environment Configuration

- [x] 1.1 Update `.env` to change `JWT_ALGO` to `HS256`.
- [x] 1.2 Remove `JWT_PRIVATE_KEY` and `JWT_PUBLIC_KEY` from `.env`.
- [x] 1.3 Update `.env` to change `REDIS_CLIENT` to `phpredis`.
- [x] 1.4 Verify JWT configuration and test login endpoint.

## 2. Database Migrations

- [x] 2.1 Update `2026_01_01_000004_create_jobs_table.php` (if it contains auto-incrementing application IDs, change to UUID if appropriate, else skip system tables).
- [x] 2.2 Update `2026_01_01_000005_create_personal_access_tokens_table.php` to use UUID for tokenable relationships if applicable.
- [x] 2.3 Update `2026_01_01_000006_create_user_sessions_table.php` to use UUID for primary key.
- [x] 2.4 Update `2026_01_01_000007_create_chats_table.php` to use UUID for primary key.
- [x] 2.5 Update `2026_01_01_000008_create_chat_participants_table.php` to use UUID for primary key and `chat_id` foreign key.
- [x] 2.6 Update `2026_01_01_000009_create_messages_table.php` to use UUID for primary key and `chat_id` foreign key.
- [x] 2.7 Update `2026_01_01_000010_create_notifications_table.php` to use UUID for primary key.
- [x] 2.8 Update `2026_01_01_000011_create_sub_role_categories_table.php` to use UUID for primary key.
- [x] 2.9 Update `2026_01_01_000012_create_user_sub_roles_table.php` to use UUID for primary key.
- [x] 2.10 Update `2026_01_01_000013_create_opportunities_table.php` to use UUID for primary key.
- [x] 2.11 Update `2026_01_01_000014_create_creator_applications_table.php` to use UUID for primary key.
- [x] 2.12 Update `2026_01_01_000015_create_dashboard_stats_table.php` to use UUID for primary key.
- [x] 2.13 Update `2026_01_01_000016_create_reports_table.php` to use UUID for primary key.
- [x] 2.14 Update `2026_01_01_000017_create_wallet_transactions_table.php` to use UUID for primary key.
- [x] 2.15 Update `2026_01_01_000019_create_auth_logs_table.php` to use UUID for primary key.

## 3. Eloquent Models Update

- [x] 3.1 Update `Chat`, `ChatParticipant`, `Message` models to use `HasUuids`.
- [x] 3.2 Update `Notification` model to use `HasUuids`.
- [x] 3.3 Update `SubRoleCategory`, `UserSubRole` models to use `HasUuids`.
- [x] 3.4 Update `Opportunity`, `CreatorApplication`, `DashboardStat` models to use `HasUuids`.
- [x] 3.5 Update `Report`, `WalletTransaction`, `AuthLog`, `UserSession` models to use `HasUuids`.

## 4. Verification

- [x] 4.1 Run `php artisan migrate:fresh` to apply database schema changes.
- [x] 4.2 Run database seeders (if any) to ensure they work with UUIDs.
- [x] 4.3 Test login endpoint manually or via tests to ensure JWT issue is fully resolved.
