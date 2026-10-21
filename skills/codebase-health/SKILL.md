---
name: codebase-health
description: Review a repository's structural health and maintainability, with a front-end focus, then fix what the user approves. Checks file organization, oversized files and flat directories, duplicated logic instead of reuse, flaky or dead tests, CI/CD and test configuration, framework best practices, outdated or vulnerable dependencies, Node.js and package-manager setup, dead scripts, leftover files, documentation bloat, excessive comments and non-English code. Use when the user asks for a codebase or repo health check, maintainability or tech-debt review, cleanup or tidy-up, a check of what AI agents did to the codebase, even if they never say "health". Not for reviewing a single diff or PR, or for a dedicated security audit.
---

# Codebase Health

Answer one question: can this codebase be maintained cheaply and extended easily?
Every check below serves that question. AI agents tend to leave specific damage:
parallel reimplementations instead of reuse, growing god files, versioned copies,
plan and summary documents, narrating comments and stale configuration. Look for
that damage first.

The work has two phases: a read-only review that ends in a Markdown report, then
fixes for the items the user approves, delivered as pull requests. Do not change
files during the review.

## Step 1: Set the Scope

- Review the whole repository unless the user names a path, package or area.
- Read the project's own rules first: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`,
  ADRs, lint and formatter configs. Documented conventions override the defaults
  in this skill; report a convention as a problem only when it hurts maintenance.
- Identify the stack: frameworks with major versions, build tool, test runners,
  package manager, runtime, monorepo layout and deployment target.

## Step 2: Collect Signals

Run the scan script from the repository, optionally with a scope path and
thresholds (defaults: 350 lines per file, 20 files per directory):

```bash
<skill-location-dir>/scripts/scan.sh [path] [max-lines] [max-files-per-dir]
```

The script outputs the working directory first. Verify you are in the intended
repository. Its sections are leads, not findings: generated files, fixtures,
translation catalogs and intentional exceptions show up too. Confirm each lead by
reading the code before it enters the report.

Then gather what the script cannot:

- Dependencies: run the package manager's outdated and audit commands (for
  example `npm outdated` and `npm audit`, `pnpm outdated` and `pnpm audit`,
  `bun outdated` and `bun audit`, `yarn npm audit`). They need network access and
  installed dependencies; if they cannot run, say so in the report.
- Current versions: check the active Node.js LTS lines and package-manager
  releases against an authoritative source (nodejs.org release data or
  endoflife.date, the package registry), not memory.
- Framework practices: do not use a memorized list of framework rules. Fetch
  the current official documentation for the installed versions (Context7 MCP
  when available, otherwise the official site) and derive the checks from it, as
  described in section 4 of the checklist.
- Dead code and dependencies: if the project already has `knip`, `depcheck`,
  `ts-prune`, `madge` or `jscpd`, run it. Otherwise offer to run one with the
  package runner of the project's package manager (for example `npx`, `pnpm dlx`,
  `yarn dlx` or `bunx`) and wait for the user's answer; never add it to the
  project during review.
- Test health: run the test suite once if it is reasonably fast; note failures,
  skipped tests and duration. When `gh` is available, recent CI runs
  (`gh run list --limit 30`) show flaky or slow jobs.

## Step 3: Review Each Area

Work through [references/checklist.md](references/checklist.md). It lists what to
check per area, front-end specifics and the common AI-agent anti-patterns. For a
large repository, when subagents are available, split the review by area (for
example structure and reuse; tests and CI; dependencies and environment; code
quality and framework practices), give each the scan output and the checklist
section, then merge, deduplicate and verify their findings yourself.

Rules for findings:

- Back every finding with evidence: `path:line`, a command output or a count.
  Mark anything unconfirmed as "to verify" instead of stating it as fact.
- Judge by maintenance cost, not taste. A 400-line file that is a flat data table
  is fine; a 300-line component mixing fetching, state and rendering may not be.
- Group repeated instances into one finding with a list of locations.
- Prefer a few precise findings over a long list of nitpicks.

Severity:

- **Critical**: breaks builds, deploys or tests, exposes secrets, or has a known
  exploitable vulnerability in shipped code.
- **High**: makes routine changes expensive or risky (duplicated core logic, god
  modules, untrustworthy tests, unsupported runtime).
- **Medium**: noticeable friction or waste (slow or wasteful CI, outdated majors,
  misleading docs, dead scripts).
- **Low**: cleanup and polish.

## Step 4: Write the Report

Write the report as a Markdown file using
[references/report-template.md](references/report-template.md). Write it in the
user's language unless they ask otherwise; keep code identifiers as they are.

- Save it outside the repository, in the session scratchpad directory or the
  system temp directory, named `codebase-health-<repo>-<YYYY-MM-DD>.md`. Save it
  inside the repository only if the user asks.
- If the host provides a tool to publish artifacts, publish that Markdown file as
  an artifact. If it provides a file-sharing tool, send the file. Otherwise give
  the path.

## Step 5: Summarize in Chat

Assume the user will not open the report. The chat summary alone must let them
understand what was found and decide what to fix. Write it in the user's
language, in plain words, without jargon or long explanations.

- Start with a one or two sentence verdict.
- Group findings by fix batch, each batch under a short plain-language heading.
  Put findings that need the user's decision rather than a fix (for example a
  choice between two libraries) in their own group.
- One bullet per finding: ID with severity, what is wrong, why it matters and
  what the fix does, in one or two short sentences. Add the main location only
  when it helps the user recognize the problem.
- Order groups and bullets from most to least severe.
- End with a short line saying how to answer: everything, whole batches, single
  IDs, or everything except some IDs.

Example:

```markdown
**Verdict:** The app works, but the same logic is copied in many places, so each
change has to be made several times.

**Batch 1: Remove copied code**
- **H1 (high):** Date formatting is written separately in 4 files. Keep one shared
  helper and use it everywhere.
- **M2 (medium):** Two button components do the same thing. Keep `Button` and
  remove `PrimaryButton`.

**Batch 2: Speed up CI**
- **M4 (medium):** Every pull request installs dependencies from scratch. Add
  caching to save about 2 minutes per run.

**Needs your decision**
- **M6 (medium):** The project uses two date libraries. Which one should stay?

Reply "all", name batches ("1, 2"), name IDs ("H1, M4"), or exclude some ("all
except M2").
```

Add the link or path to the full report after the summary, as an optional
reference.

## Step 6: Apply Approved Fixes

Change only what the user approved, one batch at a time. Work on your own branch
and commit as you go; the user reviews the result as pull requests.

- Start from an up-to-date default branch on a new branch, for example
  `codebase-health/<YYYY-MM-DD>`, following the project's branch naming if it has
  one. If the working tree has uncommitted changes, leave them out of your
  commits and tell the user.
- Record the baseline first: run the project's lint, typecheck, tests and build
  where available. Do not blame pre-existing failures on fixes.
- Keep refactors behaviour-preserving. Move or merge code with its tests; update
  imports everywhere; prefer the existing mechanism when merging duplicates.
- Before deleting a file, script or dependency, prove it is unused: search for
  references (including dynamic imports, config files, CI and docs) or use the
  dead-code tool. List untracked files before removing any of them.
- Upgrade major dependency versions in their own batch and read the migration
  guide first.
- After each batch, rerun the same checks and compare with the baseline. Do not
  move on while a batch introduces new failures.
- Commit focused changes as you work. If any skill for creating commits is
  available, use it; otherwise follow the project's commit conventions. Never
  mix two batches in one commit.

## Step 7: Open Pull Requests

Push the work and open pull requests. If any skill for creating pull requests is
available, use it; otherwise use the hosting platform's CLI, such as `gh`, and
the project's pull request template.

- Open one pull request when the change is easy to review in one sitting.
- Split large work into stacked pull requests, one per batch or group of related
  batches: each branch starts from the previous one and its pull request targets
  that previous branch, with the first targeting the default branch. Split when
  the diff is large or batches carry different risk, for example a refactor and
  a major dependency upgrade. Batches that do not depend on each other can be
  separate pull requests against the default branch instead of a stack.
- Each pull request description lists the finding IDs it fixes in plain words,
  the check results compared with the baseline, and, in a stack, its position
  and the pull requests it depends on.
- Update the report: mark each finding as fixed, skipped or deferred with the
  pull request that fixes it, and republish or resend it.
- Close with a short chat summary in the same plain style as Step 5: links to
  the pull requests in merge order, a bullet per finding ID saying fixed, skipped
  or deferred and why, and the check results compared with the baseline. Ask
  whether to merge them.

## Step 8: Merge After Approval

Merge only after the user explicitly approves it in chat, and only the pull
requests they approved.

- Before each merge, confirm that required checks pass and nothing blocks the
  merge. Never bypass branch protection, required reviews or failing checks.
- Use the merge method the repository uses (its settings or recent history).
- Merge a stack from the bottom up. After each merge, point the next pull request
  at the default branch, rebase it if the merge method rewrote commits, push,
  and wait for its checks before merging it.
- Stop and report when a merge conflict or a failing check needs a decision.
- After merging, delete the merged branches if the repository does not do it
  automatically, and report what was merged.
