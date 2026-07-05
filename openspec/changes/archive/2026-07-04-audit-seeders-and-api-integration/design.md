## Context

We have successfully consolidated the database migrations into clean, logical files and translated the `sub_role` mappings to English across the system. We now need to confirm that our seeders accurately populate the database with these new structural assumptions (especially the usage of UUIDs for users and updated english enum slugs). Furthermore, we need to ensure the frontend successfully consumes the updated API contracts without any serialization errors or regressions.

## Goals / Non-Goals

**Goals:**
- Audit `UserSeeder`, `RemainingTablesSeeder`, and `OpportunityLocationSeeder`.
- Verify database population logic and ensure there are no missing fields or mismatched enum values.
- Verify frontend API consumption specifically around User profiles, Creator Applications, and Opportunities which heavily use `sub_role`.

**Non-Goals:**
- Changing existing UI elements beyond fixing mapping errors.
- Modifying the core architecture of the backend API or database.

## Decisions

- **Seeder verification via CLI**: We will run the seeders via `php artisan db:seed` (already verified implicitly via `migrate:fresh --seed`). We will then do targeted queries in Tinker or through API calls to verify the data structure (e.g. UUID usage for `user_id`).
- **Frontend verification via runtime execution**: We will run the frontend flutter app or visually inspect the models (`UserModel.dart`, `CreatorApplicationCard.dart`) to ensure they perfectly align with the new English roles. 

## Risks / Trade-offs

- **Risk**: Missed references to old Indonesian enum values (e.g., `institusi` or `fotografer`) in the frontend, leading to null values or parsing exceptions.
  - **Mitigation**: Perform a global text search in the frontend codebase for the old Indonesian terms to ensure complete replacement.
