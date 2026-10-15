---
name: commit
description: Create focused git commits with Conventional Commits messages. Use for every git commit you create, whether the user asks for one or you commit as part of a task, and when the user asks for a commit message.
---

# Git Commit

If the user asks only for a commit message, inspect the relevant context and
return the proposed message without staging changes or creating a commit.

## Step 1: Gather Context

When working in a repository, run the skill's context-gathering script:

```bash
<skill-location-dir>/scripts/collect-context.sh
```

The script outputs the current working directory first. Verify you are in the correct repository before proceeding.

For a message-only request based on a supplied diff or description, use that
material directly; repository access is not required.

## Step 2: Select the Commit Scope

Commit only changes that belong to the user's requested work. Preserve unrelated
staged or unstaged changes.

- Group changes thematically, with a separate commit for each coherent change.
- Inspect the intended unstaged changes and new files before staging them; the
  context script only shows the full diff for changes already staged.
- Stage explicit paths only when all changes in those files belong to the commit.
  If a file mixes intended and unrelated changes, stage only the intended hunks.
- Never use `git add .`, `git add -A`, or another broad staging command.
- If staged changes mix unrelated work, split them before committing when this can
  be done safely; otherwise ask the user which changes belong in the commit.
- Review the staged diff immediately before committing.

## Step 3: Write the Commit Message

Use Conventional Commits by default. Follow project-specific message conventions
when they differ from the defaults below.

**Subject** (always):
- Use Conventional Commits: `<type>[optional scope][!]: <description>`.
- Prefer `feat`, `fix`, `docs`, `refactor`, `test`, `perf`, `build`, `ci`,
  `chore`, `style`, or `revert`; choose the type that describes the change.
- Use imperative mood: "add foo", not "added foo" / "adds foo".
- Keep the subject at most 72 characters, with no trailing period.
- Add a scope only when it makes the subject more precise.
- Mark breaking changes with `!` and explain them in a `BREAKING CHANGE:` footer.

Use a subject alone by default. Add a body when context, rationale, or breaking
changes need explanation, or when the user requests a detailed message.

- Separate the subject and body with a blank line.
- Explain why the change is needed without repeating the diff.
- Use bullets when they make multiple related points easier to scan.

## Step 4: Create the Commit

```bash
git commit -m "message"
git commit -m "title" -m "- bullet 1
- bullet 2"
```

## Step 5: Verify and Report

Inspect the created commit and the remaining staged and unstaged changes. Confirm
that the commit contains only the intended changes and unrelated work is preserved.
Return the commit hash and subject for each commit created.

## Rules

- Never add AI-attribution signatures, footers, or suffixes to commit messages.
  Factual mentions of AI tools that are relevant to the changes are allowed.
- If a pre-commit hook modifies in-scope files, inspect and stage only those hook
  changes, then retry once.
- If a hook fails, diagnose and fix a straightforward in-scope problem. Ask the
  user only when the fix is ambiguous, substantial, or outside the requested work.
