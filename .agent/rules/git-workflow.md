# Mandatory Git Workflow Rules for Antigravity & AI Assistants

Before pushing any changes or merging to main, you MUST follow this sequence strictly:

1. Always pull latest `main` first:
   ```bash
   git checkout main
   git pull origin main
   ```
2. Create and work on a feature/fix branch:
   ```bash
   git checkout -b <type>/<description>
   ```
3. Commit all changes to the branch.
4. Before pushing to the new branch, always sync and merge locally from latest main:
   ```bash
   git checkout main
   git pull origin main
   git checkout <branch-name>
   git merge main
   ```
5. Push the new branch to origin:
   ```bash
   git push -u origin <branch-name>
   ```
6. Switch to main, pull to verify no new commits arrived, merge the branch locally, and push main:
   ```bash
   git checkout main
   git pull origin main
   git merge <branch-name>
   git push origin main
   ```

## Special AI Rules:
- **IF USING CLAUDE (Anthropic / Claude Code / Claude Desktop)**:
  - NEVER execute automated `git push` to any branch or to `main` so Claude is never recorded as a GitHub contributor.
  - Claude may only modify files, create branches, and make local commits.
  - Pushing must be handled manually by the user or performed through Antigravity.
