# Claude Project Instructions for Kreavana

## 🚨 STRICT RESTRICTION: NO AUTOMATED GIT PUSH

If you are Claude (Anthropic / Claude Code / Claude Desktop / Claude API):

1. **DO NOT EXECUTE `git push`**:
   - You are **STRICTLY FORBIDDEN** from running `git push` commands (neither `git push origin <branch>` nor `git push origin main`).
   - This repository policy ensures that Claude is **never recorded as a contributor or committer/pusher** on GitHub.
   
2. **Permitted Actions for Claude**:
   - You may read, analyze, and modify code locally.
   - You may create local branches and local commits if requested.
   - When changes are ready, instruct the user to run `git push` manually, or leave pushing to the authorized Antigravity agent.

3. **Required Git Workflow for Manual / Antigravity Operations**:
   - Always `git checkout main && git pull origin main` before branching.
   - Work on a dedicated branch (`git checkout -b <type>/<name>`).
   - Always merge latest `main` locally into the branch before pushing.
   - Only after local merge verification can the branch and `main` be pushed (manually by user or by Antigravity).

4. **Mandatory Rule Compliance, Database-Backed Data (Zero Mockups), & New Migrations**:
   - **Read Workspace Rules First**: Before acting on any prompt, read `.agent/rules/*.md`, `.github/rules/*.md`, `.github/copilot-instructions.md`, `CLAUDE.md`, `GEMINI.md`, and `AGENTS.md`.
   - **Zero UI Mockups / DB-Backed Dummy Data**: Never hardcode static dummy/mockup lists in Flutter widgets/services or API fallback arrays. All displayed data must come from the real database (`backend` / `users_api`), showing clean empty states when empty. When creating dummy/demo data, always create it inside the database via Laravel Seeders, Factories, or schema-valid DB records.
   - **Immutable Existing Migrations**: Never edit, alter, or delete existing migration files in `backend/database/migrations/` or `users_api/database/migrations/`. Any change to an existing table MUST create a new timestamped migration (`php artisan make:migration <descriptive_name>`) alongside Model/Seeder updates and `php -l` checks.
