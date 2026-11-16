# Agent Skills

## Branches

- `main`: the base branch of the skill collection. Changes to skills land here
  first.
- `personal`: `main` plus personal-only commits (for example the
  `repo-standards` skill). Never merge it into `main`.

Sync: after every change on `main`, rebase `personal` onto `main` and push it
with `git push --force-with-lease origin personal`.
