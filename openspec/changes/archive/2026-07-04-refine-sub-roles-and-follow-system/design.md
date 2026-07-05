## Context

Two separate but related problems need fixing alongside adding a new social feature:
1. The `pihak_slug` column in `opportunities` and `dashboard_stats` was never renamed during the `pihak → sub_role` migration, causing inconsistency.
2. The creator sub-role list has an unwanted `lainnya` entry and is missing 4 specific creator types (Makeup Artist, Fotografer, Editor, Videografer).
3. The platform has no way for users to follow/unfollow each other — a basic requirement for creator discovery.

## Goals / Non-Goals

**Goals:**
- Rename `pihak_slug` to `sub_role_slug` in `opportunities` and `dashboard_stats` via a new migration.
- Update the enum and seeder to exactly the 11 required sub-roles.
- Build a complete follow/unfollow system (backend + frontend).

**Non-Goals:**
- Activity feeds based on follows (out of scope for now).
- Private accounts or follow-request approval flows.

## Decisions

### Column Rename Strategy
Use `Schema::table` with `renameColumn` inside a new migration file. Update all models, services, controllers, seeders, and request validators that reference `pihak_slug`.

### Follow System Architecture
- New `user_follows` table with `follower_id` (UUID FK → users) and `following_id` (UUID FK → users), unique pair constraint.
- New `UserFollow` model, `FollowRepository`, `FollowService`, `FollowController`.
- Register 4 new API routes under `api.php`.
- Profile response adds `followers_count` and `following_count` computed from the `user_follows` table.
- `is_following` boolean added to profile response when viewing another user's profile (authenticated request).

### Frontend Follow UI
- Profile page: display follower/following counts as clickable stats.
- Follow/Unfollow button appears on other users' profiles.
- Optimistic toggle on click with API confirmation.

## Risks / Trade-offs

- **Risk:** Renaming `pihak_slug` in a running system could break existing API consumers that still send `pihak_slug` as a query param.  
  **Mitigation:** Accept both `sub_role_slug` and `pihak_slug` as query params in controllers (fallback) during the transition period. Since this is a fresh dev environment, full rename is safe.

- **Risk:** Sub-role list change breaks existing creator records that have `lainnya`.  
  **Mitigation:** `migrate:fresh --seed` will reset all data; no live production data to migrate.

## Migration Plan

1. Create new migration to rename `pihak_slug` → `sub_role_slug` in `opportunities` and `dashboard_stats`.
2. Update all PHP references to `pihak_slug` in those contexts.
3. Update enum (remove `lainnya`, add `makeup_artist`, `fotografer`, `editor`, `videografer`).
4. Update seeder.
5. Create `user_follows` migration and all follow system files.
6. Update frontend profile and add follow UI.
7. Run `migrate:fresh --seed` and test.
