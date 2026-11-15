# Kreavana Workspace Instructions (Antigravity / Gemini)

> **STOP AND READ FIRST**: Before planning, searching broadly, editing files, creating seed data, or modifying database structures for **any** prompt, you MUST read the repository rule files in `.agent/rules/*.md` and `.github/rules/*.md` (plus `.github/copilot-instructions.md` and `CLAUDE.md`).

---

## Core Mandatory Rules

### 1. Read Workspace Rules Before Acting (`Baca Aturan Dulu`)
- On every task/prompt, read the active rules before starting implementation:
  - `.agent/rules/ai-prompt-and-database-standards.md`
  - `.agent/rules/git-workflow.md`
  - `.agent/rules/page-routing-and-permissions.md`
  - Mirror / detailed references: `.github/rules/*`, `.github/copilot-instructions.md`, `CLAUDE.md`, `.claude/CLAUDE.md`
- Never improvise workflows that contradict Git workflow, RBAC routing, `users_api` IAM isolation, or database rules.

### 2. Database-Backed Dummy & UI Data (Zero Mockups)
- **NO frontend/UI mockup data**: Never hardcode static dummy lists, fallback sample arrays, or placeholder JSON objects inside Flutter widgets, providers, services, or API controllers.
- **Database as single source of truth**: Every screen, dashboard KPI, list, and detail page must query real records from `backend` / `users_api`. When tables are empty, render clean empty states and `0` counts.
- **Dummy data lives in the database**: Whenever dummy/demo/sample data is requested, generate it inside `backend/database/seeders/` or `users_api/database/seeders/` (or Factories / real DB records) strictly conforming to actual table columns, enums, and foreign keys.
- **Pagination**: Multi-item data lists fed from the database must be paginated cleanly (e.g., `AppPaginationBar` / API pagination).

### 3. Always Create a New Migration for Existing Database Changes
- **Never edit historical migrations**: Do NOT modify, overwrite, or append columns to existing migration files in `backend/database/migrations/` or `users_api/database/migrations/`.
- **Always create a new migration**: Any change to an existing table (add/rename/alter/drop columns, enums, indexes, or foreign keys) MUST use a newly generated timestamped migration (`php artisan make:migration <descriptive_name>`), plus corresponding updates to Eloquent models, seeders, and `php -l` syntax checks.

### 4. Architecture, Security & Git Workflow Summary
- **Routing & RBAC**: Follow `1 Page = 1 Route` (`context.go(AppRoutes.<route>)` + `appRouter.redirect` guards in `.agent/rules/page-routing-and-permissions.md`).
- **IAM (`users_api`) & Security**: Passwords stay isolated in `users_api`; backend uses fail-closed S2S HMAC + JWT verification (`CLAUDE.md`).
- **Git Workflow**: Follow the mandatory 6-step branch flow in `.agent/rules/git-workflow.md` (pull `main` -> feature/fix/chore branch -> commit -> pull & merge `main` locally -> push branch -> merge into updated `main` -> push `main`). Claude models must never run `git push`.
