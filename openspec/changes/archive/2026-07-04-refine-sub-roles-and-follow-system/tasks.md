- [x] 1.1 Create a new migration to rename `pihak_slug` to `sub_role_slug` in both the `opportunities` and `dashboard_stats` tables.
- [x] 1.2 Update the `Opportunity` model's fillable/references to use `sub_role_slug`.
- [x] 1.3 Update `DashboardStat` model's fillable/references to use `sub_role_slug`.
- [x] 1.4 Update `OpportunityController`, `OpportunityService`, `OpportunityRepository`, `DashboardController`, `DashboardService`, `DashboardRepository`, and any related request classes to use `sub_role_slug` instead of `pihak_slug`.
- [x] 1.5 Update `StoreOpportunityRequest` validation rule from `pihak_slug` to `sub_role_slug`.
- [x] 1.6 Update `RemainingTablesSeeder` and `OpportunityLocationSeeder` (if applicable) to use `sub_role_slug` key in opportunity/dashboard_stat arrays.

## 2. Refine Creator Sub-Roles to Exact 11

- [x] 2.1 Update `App\Enums\CreatorSubRole` to the definitive 11 values: `institusi`, `pemerintah`, `mc`, `penyanyi`, `wedding_organizer`, `event_organizer`, `komunitas`, `makeup_artist`, `fotografer`, `editor`, `videografer`. Remove `lainnya`.
- [x] 2.2 Update `RemainingTablesSeeder` `sub_role_categories` entries to match — remove `lainnya`, add `makeup_artist`, `fotografer`, `editor`, `videografer` with appropriate icons, descriptions, and colors. Update seeded opportunities/dashboard stats to use valid new slugs.

## 3. Build User Follow System (Backend)

- [x] 3.1 Create migration for `user_follows` table: `id` (UUID), `follower_id` (UUID FK → users), `following_id` (UUID FK → users), `created_at`. Add unique constraint on `(follower_id, following_id)`.
- [x] 3.2 Create `App\Models\UserFollow` model with relationships (`follower`, `following`).
- [x] 3.3 Create `App\Repositories\FollowRepository` with methods: `follow()`, `unfollow()`, `isFollowing()`, `getFollowers()`, `getFollowing()`, `getFollowersCount()`, `getFollowingCount()`.
- [x] 3.4 Create `App\Services\FollowService` to orchestrate follow/unfollow logic, prevent self-follows, and return structured responses.
- [x] 3.5 Create `App\Http\Controllers\FollowController` with methods: `follow()`, `unfollow()`, `followers()`, `following()`.
- [x] 3.6 Register follow routes in `routes/api.php`: `POST /follow/{userId}`, `DELETE /follow/{userId}`, `GET /users/{userId}/followers`, `GET /users/{userId}/following`.
- [x] 3.7 Update `ProfileService::getProfileData()` to include `followers_count`, `following_count`, and `is_following` (when authenticated) in the profile response.
- [x] 3.8 Register `FollowRepository` and `FollowService` in `AppServiceProvider` or via constructor injection.

## 4. Build User Follow System (Frontend)

- [x] 4.1 Create a follow API service function in the frontend (e.g., `followUser(userId)` and `unfollowUser(userId)`).
- [x] 4.2 Update Profile Screen to show "Follow", "Following" buttons and follower stats.
- [x] 4.3 Ensure creator application screen uses exact 11 sub-roles and removes `lainnya`.

## 5. Testing & Verification

- [x] 5.1 Run `php artisan migrate:fresh --seed` — ensure all migrations succeed and seeders run without errors.
- [x] 5.2 Test follow/unfollow endpoints via API: follow user, unfollow user, self-follow rejection, duplicate follow idempotency.
- [x] 5.3 Verify profile response includes `followers_count`, `following_count`, and `is_following`.
- [x] 5.4 Verify opportunity and dashboard_stat queries use `sub_role_slug` and return correct results.
