---
name: ship
description: >
  Ship a feature: stage relevant files, write a commit message, commit, push, and open a
  pull request — all in one command. Use when the user says "ship", "ship it", "ship this
  feature", "commit and push", or "open a PR". Derives the PR title and summary from the
  diff. Asks for confirmation before pushing to shared branches.
---

# Ship

Stage → commit → push → open PR in one flow.

## Workflow

1. **Assess state** — run `git status` and `git diff` in parallel. Identify what's changed.

2. **Stage** — add files by name (never `git add -A`). Skip secrets, binaries, and generated
   lock files unless the user explicitly named them.

3. **Commit** — write a message that explains *why*, not just *what*. Use a HEREDOC:
   ```bash
   git commit -m "$(cat <<'EOF'
   <imperative summary under 72 chars>

   <optional body if non-obvious context is needed>

   Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
   EOF
   )"
   ```

4. **Push** — push the current branch with `-u` if no upstream is set yet.
   - If the branch is `main` or `master`: ask the user to confirm before pushing.

5. **Open PR** — use `gh pr create` with a title (≤70 chars) and a body derived from the diff:
   ```bash
   gh pr create --title "..." --body "$(cat <<'EOF'
   ## Summary
   - bullet 1
   - bullet 2

   ## Test plan
   - [ ] ...

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

6. **Return the PR URL** so the user can click it.

## Guidelines

- If there's nothing staged or modified, say so and stop.
- If a pre-commit hook fails, fix the issue and create a **new** commit — never `--amend`.
- Never use `--no-verify`, `--force-push`, or skip signing unless explicitly asked.
- Prefer specific file paths over `git add .`.
