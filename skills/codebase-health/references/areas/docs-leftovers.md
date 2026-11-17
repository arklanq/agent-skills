# Area: Documentation and Leftover Files

Report table rows: Documentation and comments (documentation part only);
Scripts and leftover files (leftover files part only).

## Inputs

- Scan sections: Overview; Suspicious and leftover files; Agent-style notes and
  reports in the repository; Documentation files by size; Tool configuration
  files (for configs of unused tools).
- Depth: check every path, command and version the docs mention against the
  repository; check their other claims on a sample, not one by one.

## Optional Skills

If a skill below is installed and fits the project, use it; otherwise just skip
it and do the checks in this file without it. Use its rules as support for the
findings below, not to review the docs sentence by sentence.

- `writing-guidelines`: the project has documentation written as prose.

## Owned by Other Areas

Leave these to the named area even when you notice them:

- Comments in code: code quality.
- Script files and scripts declared in manifests: dependencies.

## Leftover and Misleading Files

- Backup and temp files (`.bak`, `.orig`, `.old`, `copy`), OS files
  (`.DS_Store`), logs, editor files that should be ignored.
- Committed build output, coverage reports, screenshots and test evidence that
  belong in CI artifacts.
- Empty or near-empty files and directories, placeholder modules.
- Configs for tools the project no longer uses.
- Committed `.env` files with real values (Critical when they hold secrets).
- `.gitignore` gaps that let these files in.

## Documentation

Good documentation is short, concrete and still true.

- The README covers purpose, prerequisites, setup, main commands and a short
  structure overview. Nothing more is required.
- Docs that duplicate the code: implementation details, file-by-file
  walkthroughs, API listings that drift. Remove or reduce them to pointers.
- Agent leftovers: plans, progress logs, summaries, handoffs and reports
  committed as documentation. Keep a decision record (ADR) only when it states a
  decision that still applies.
- Stale instructions: commands, paths or versions that no longer exist.
- Agent instruction files (`AGENTS.md`, `CLAUDE.md`): short, current, no
  contradictions between them.
