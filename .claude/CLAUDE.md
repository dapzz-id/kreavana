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
