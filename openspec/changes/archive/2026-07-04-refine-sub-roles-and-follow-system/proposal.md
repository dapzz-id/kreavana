## Why

Two issues need addressing: (1) The `opportunities` and `dashboard_stats` tables still use the stale `pihak_slug` column name instead of `sub_role_slug`, causing inconsistency with the rest of the schema. (2) The creator sub-role list (`lainnya` was erroneously included and several real roles were missing) needs to be corrected to the exact set of 11 categories requested: Institusi, Pemerintah, MC, Penyanyi, Wedding Organizer, Event Organizer, Komunitas, Makeup Artist, Fotografer, Editor, Videografer. Additionally, the platform currently lacks a social following system, which is essential for creator discovery and community building.

## What Changes

- **BREAKING** Rename `pihak_slug` column to `sub_role_slug` in `opportunities` and `dashboard_stats` tables via a new migration.
- Update all code that references `pihak_slug` in models, controllers, services, and seeders to use `sub_role_slug`.
- Update `App\Enums\CreatorSubRole` to the definitive 11-item list: `institusi`, `pemerintah`, `mc`, `penyanyi`, `wedding_organizer`, `event_organizer`, `komunitas`, `makeup_artist`, `fotografer`, `editor`, `videografer`.
- Reseed `sub_role_categories` with the new 11 entries — remove `lainnya` and add `makeup_artist`, `fotografer`, `editor`, `videografer`.
- Create a `user_follows` table and backend endpoints for following/unfollowing users, listing followers, and listing following.
- Add follow/unfollow button and follower/following counts to the frontend profile views.

## Capabilities

### New Capabilities
- `user-follow-system`: Users can follow and unfollow other accounts. Each user has a visible follower count and following list.

### Modified Capabilities
- `creator-sub-roles`: The enum and database list of creator sub-roles is being replaced with the definitive 11-item set. `lainnya` is removed; `makeup_artist`, `fotografer`, `editor`, `videografer` are added.
- `opportunities-schema`: `pihak_slug` column renamed to `sub_role_slug` — **BREAKING** schema change.
- `dashboard-stats-schema`: `pihak_slug` column renamed to `sub_role_slug` — **BREAKING** schema change.

## Impact

- **Backend:** New migration for column renames, updated Opportunity/DashboardStat models, new `UserFollow` model + migration, new `FollowController`, `FollowService`, `FollowRepository`, updated `RemainingTablesSeeder`, updated `CreatorSubRole` enum.
- **Frontend:** Profile page gets follow/unfollow button and follower/following counts. Opportunity listing filters update to use `sub_role_slug`.
- **API:** New routes `POST /api/follow/{userId}`, `DELETE /api/follow/{userId}`, `GET /api/users/{userId}/followers`, `GET /api/users/{userId}/following`.
