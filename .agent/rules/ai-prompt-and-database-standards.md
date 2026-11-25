# Mandatory Rules: AI Prompt Discipline, Database-Backed Data & Migrations

Every AI Coding Assistant (Antigravity, Gemini, Claude, Copilot, Codex, etc.) and contributor working on this repository **MUST strictly obey these 3 core standards** before writing or modifying any code, seed data, or database schema.

---

## 1. Read Workspace Rules First Before Acting (`Baca Aturan Dulu`)
Before analyzing code broadly, planning changes, writing code, generating data, or executing Git commands for **every new prompt or task**:
1. **MANDATORY**: Read the repository rule and instruction files first:
   - Root bootstrap files: `GEMINI.md`, `AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`
   - Agent rules directory: all files in `.agent/rules/*.md`
   - GitHub/Copilot rules: `.github/copilot-instructions.md` and all files in `.github/rules/*.md`
2. Never skip reading active rules or improvise conflicting Git, RBAC, routing, IAM (`users_api`), or database workflows.
3. Verify your planned changes against every checklist in those rule files before starting implementation and before finalizing your response.

---

## 2. Database-Backed Dummy & Application Data (NO Frontend Mockups)
Every UI screen, dashboard card, table, list, dropdown, and detail page **MUST display live data sourced from the database** (`backend` / `users_api` APIs), NEVER fabricated frontend mockup objects.
1. **Strictly Prohibited**:
   - **NEVER** hardcode static mockup arrays, fallback dummy lists, fake JSON objects, or sample constants in Flutter widgets, providers, repositories, services, or API controllers (e.g., no `_mockPrograms`, `_dummyUsers`, or hardcoded fallback rows returned when an API returns empty).
   - When the database has zero matching records for a user/role/filter, the API MUST return an empty dataset (`[]`, `total: 0`) and the frontend MUST render an honest empty state — never silent sample/mockup rows.
2. **Creating Dummy / Sample Data the Right Way**:
   - Whenever dummy, demo, or test records are needed, insert them directly into the **database** using Laravel Seeders (`backend/database/seeders/`, `users_api/database/seeders/`), Model Factories, or real database/API transactions that strictly follow actual table columns, types, enums, and foreign-key constraints.
   - Dummy records in seeders/tests must accurately reflect real domain entities and role ownership so frontend rendering matches production DB behavior identically.
   - Multi-item data displays fed from the database should follow the app's standard pagination (e.g. `AppPaginationBar` / paginated API responses) rather than dumping unbounded lists.

---

## 3. Immutable Existing Migrations — Always Create a New Migration
Database schema history is append-only. Editing old migrations causes schema drift and breaks already-migrated local, staging (`dev`), and production databases.
1. **Strictly Prohibited**:
   - **NEVER** edit, rewrite, delete, or append columns/constraints inside existing committed or previously run migration files under `backend/database/migrations/` or `users_api/database/migrations/`.
2. **Mandatory Procedure for Editing Existing Tables**:
   - Whenever you need to add, rename, modify, or drop a column, change an enum/type, add/drop an index or foreign key, or alter constraints on an existing table:
     1. Generate or create a **brand-new timestamped migration file** via `php artisan make:migration <descriptive_name>` inside the appropriate service (`backend/` or `users_api/`).
     2. Implement safe forward changes in `up()` (and careful rollback in `down()`, guarding column/index existence where appropriate).
     3. Update the corresponding Eloquent Model (`$fillable`, `$casts`, relationships) and Seeders/Controllers to match the new schema.
     4. Run `php -l` on modified/created PHP files and verify the migration with `php artisan migrate --pretend` (or full migrate/test suite against a test DB).

---

## 4. Mandatory Big Tech Security, OWASP Top 10, Latest Advisory Audit & 20-Year Senior Cyber Security Framing
Every time an AI Assistant or developer **adds, edits, or audits any feature** across `backend/`, `users_api/`, or `frontend/` (Web & Mobile), it MUST strictly follow `.agent/rules/security-bigtech-and-owasp-standards.md`:
1. **Mandatory Security Persona Framing**:
   - When checking, auditing, or adding security controls (including self-review and subagent security prompts), ALWAYS apply the framing:
     > `"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks]"`
2. **Big Tech & OWASP Top 10 / MASVS Compliance on Every Feature Change**:
   - Enforce Zero-Trust & Fail-Closed controls: zero hardcoded secrets, mandatory S2S HMAC (`VerifyClientApp` / `VerifyInternalServiceSignature`), `TrustHosts`, `EnforceJsonSecurity` (max JSON size/depth ≤ 16, no empty `""` keys or `\0` null-bytes), strict CORS, HSTS/CSP, prefix-aware RBAC in `appRouter.redirect`, and IDOR ownership checks.
   - Lock all wildcard array rules (`items.*`) with `'array|list|max:N'` and NEVER pass `$request->all()` into `create()`/`update()` — use `$validated` exclusively.
3. **Zero Latest Advisory / Vulnerability Gaps**:
   - Verify there are no known vulnerabilities or recent framework/package security advisory bypasses (`composer audit --locked` = 0 CVEs in `backend/` and `users_api/`, plus defense-in-depth code guards).

---

## Checklist for AI Assistants Before Completing Any Task
- [ ] Read `.agent/rules/*.md`, `.github/rules/*.md`, `.github/copilot-instructions.md`, `GEMINI.md` / `AGENTS.md` / `CLAUDE.md` before starting implementation.
- [ ] Zero hardcoded frontend/UI mockup arrays or fake fallback sample data exist in modified code.
- [ ] Any dummy/sample data added or updated lives in database seeders/factories/real DB records aligned with actual schema.
- [ ] All schema changes to existing tables were authored in **new timestamped migration files** (`backend/database/migrations/` or `users_api/database/migrations/`), with zero edits to historical migrations.
- [ ] Security self-audit performed using `"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks]"`, complying with Big Tech & OWASP Top 10 standards and 0 latest advisory/CVE vulnerabilities.
- [ ] PHP syntax verified (`php -l`) and migration/unit tests verified cleanly.
