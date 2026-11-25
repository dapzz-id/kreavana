# Kreavana Repository AI Agent Instructions

> **MANDATORY PRE-FLIGHT STEP**: Before analyzing, planning, writing code, generating dummy data, or changing database schemas on **any prompt**, read the project rule files first:
> `.agent/rules/*.md`, `.github/rules/*.md`, `.github/copilot-instructions.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, and `GEMINI.md`.

---

## Mandatory Standards for Every Prompt

### 1. Read All Repository Rules First (`Baca Aturan Dulu`)
- Never start editing code before reviewing the active rules in `.agent/rules/` and `.github/rules/`.
- Ensure every plan complies with:
  - AI prompt, data source, & migration rules (`.agent/rules/ai-prompt-and-database-standards.md`)
  - Routing & strict RBAC guards (`.agent/rules/page-routing-and-permissions.md`)
  - Big Tech, OWASP Top 10, latest advisory audit, & 20-year Senior Cyber Security persona rules (`.agent/rules/security-bigtech-and-owasp-standards.md`)
  - Git workflow rules (`.agent/rules/git-workflow.md`)
  - IAM (`users_api`) & enterprise security hardening (`CLAUDE.md`)

### 2. Database-Backed Dummy & Display Data Only (No Mockups)
- **Zero hardcoded UI/API mockups**: Never add static dummy arrays, sample fallback lists, or fake hardcoded JSON in Flutter (`frontend/`) or controller fallbacks in Laravel (`backend/`, `users_api/`).
- **Truth from database**: All displayed items, counters, statuses, and relationships must originate from real database queries. Empty DB results must render clean empty states rather than fabricated items.
- **Create dummy data inside the database**: When dummy, demo, or test data is needed, create or update Laravel Seeders (`backend/database/seeders/`, `users_api/database/seeders/`), Factories, or real DB records matching actual database schema constraints.
- **Paginated views**: Data tables/lists backed by the database must use consistent pagination (`AppPaginationBar` / paginated API endpoints).

### 3. Never Modify Existing Migrations — Always Create a New Migration
- **Do NOT edit committed/existing migrations** in `backend/database/migrations/` or `users_api/database/migrations/`.
- **Always create a new migration** (`php artisan make:migration <descriptive_name>`) whenever adding, altering, renaming, or removing columns, enums, indexes, or foreign keys on existing tables.
- Keep `up()` and `down()` reversible where practical, update matching Eloquent Models/Seeders, and verify with `php -l`.

### 4. Big Tech Security, OWASP Top 10, Latest Advisory Check & Mandatory Security Framing
- **Every added or edited feature** across `backend/`, `users_api/`, and `frontend/` (Web & Mobile) MUST comply with **Big Tech Company security standards**, **OWASP Top 10 / OWASP API Top 10 / OWASP MASVS**, and have **zero known vulnerabilities or recent security advisory bypasses** (`composer audit --locked` = 0 CVE, `EnforceJsonSecurity`, `TrustHosts`, wildcard arrays locked with `array|list|max:N`, exclusive `$validated` usage without `$request->all()`, no hardcoded secrets, prefix-aware RBAC).
- **Mandatory Cyber Security Framing**: Whenever checking, auditing, or adding security standards/controls, ALWAYS apply the prompt framing:
  > `"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks]"`

### 5. Git & Model-Specific Safety
- Always sync `main`, work on a dedicated `<type>/<name>` branch, merge latest `main` locally before pushing, and merge cleanly to `main` (`.agent/rules/git-workflow.md`).
- **Claude agents**: never run automated `git push` (`.claude/CLAUDE.md` / `CLAUDE.md`).
