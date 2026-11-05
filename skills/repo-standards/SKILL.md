---
name: repo-standards
description: Audit a GitHub repository's settings and branch ruleset against the personal repo standards (main as default branch, merge options, "main branch protection" ruleset, required status checks such as `gate`), then fix the differences once the user approves. Use when the user asks whether a repo is configured correctly, wants to check, audit, set up, or align GitHub repo settings, branch protection, rulesets, auto-merge, or required checks, or has just created a new repo, even if they never say "standards".
---

# Repo Standards

Check one GitHub repository against the standards below and report the result. The
audit is read-only. Change nothing until the user has seen the report and approved
the specific changes, because these settings affect how everyone merges.

Requires an authenticated `gh` and `jq`. Changing settings requires admin access.

## The standards

Repository settings:

| UI option | API field | Value |
|---|---|---|
| Default branch | `default_branch` | `main` |
| Automatically delete head branches | `delete_branch_on_merge` | `true` |
| Allow auto-merge | `allow_auto_merge` | `true` |
| Allow rebase merging | `allow_rebase_merge` | `true` |
| Allow squash merging | `allow_squash_merge` | `true` |
| Squash default commit message: "Pull request title" | `squash_merge_commit_title`, `squash_merge_commit_message` | `PR_TITLE`, `BLANK` |
| Allow merge commits | `allow_merge_commit` | `true` |
| Merge default commit message: "Pull request title" | `merge_commit_title`, `merge_commit_message` | `PR_TITLE`, `BLANK` |

At least one active ruleset named exactly `main branch protection`, targeting the
default branch (`~DEFAULT_BRANCH`), with these rules: restrict deletions, block force
pushes, require a pull request, and require status checks with "Require branches to
be up to date" on. Other rulesets may exist alongside it. If several carry this name,
one fully compliant ruleset satisfies the standard.

## Step 1: Audit

Use the repository the user named, otherwise the one in the current directory.

```bash
<skill-location-dir>/scripts/audit.sh [owner/repo]
<skill-location-dir>/scripts/discover-checks.sh [owner/repo]
```

`audit.sh` prints `STATUS`, check, expected, and actual. `UNKNOWN` means the value
could not be read, for example without admin access or on a private repository whose
plan has no rulesets. Report it as not verified, never as a pass or a failure.

## Step 2: Decide the required status checks

This is the one standard that needs judgment. A wrong choice is costly: a required
check that never runs blocks every pull request forever, so go down this list and stop
at the first match, using the output of `discover-checks.sh`.

1. **`gate` exists.** It appears in the check table, or a workflow that runs on
   `pull_request` defines it. Require exactly `gate`. The context is the job's `name:`
   when set, otherwise its id, so a job with id `gate` and `name: Gate` reports as `Gate`
   and counts as this case with that spelling. Say so if it has not run yet.
2. **No `gate`, but other usable checks exist.** Pick them and explain each pick. A check
   is usable only if it reports on every pull request. Reject checks that:
   - run only on `push`, `schedule`, or `workflow_dispatch`, so a pull request never gets them;
   - have `paths` or `branches` filters on the trigger, because a skipped workflow leaves
     the check waiting forever;
   - have a job-level `if:` that can skip them, because GitHub treats a skipped job as passed;
   - have a matrix whose values may change, because each value is a separate check name;
   - belong to a disabled workflow, deploy previews, bots, or labelers, or rarely pass in the check table.

   Prefer the checks that verify the code (build, lint, tests). Mark this as an improvised
   choice for the user to confirm, and mention that a single `gate` job would be more durable.
3. **No usable checks.** The `required_status_checks` rule must be absent, and "Require
   branches to be up to date" does not apply because it lives inside that rule. An absent
   rule passes; a present one fails, since it can only block merges.

Then compare with the current state. Required checks must match the decision exactly.
Report extra contexts as a failure, but ask before removing them because they may be
deliberate. A required context that no longer runs is the most urgent finding.

## Step 3: Report

The reader wants to see at a glance what is wrong and what to do about it, so keep the
report minimal but concrete. Write it in the user's language and use this template:

```markdown
## repo-standards: owner/repo

**N differences** (M checks pass)

| Check | Expected | Actual |
|---|---|---|
| Allow auto-merge | `true` | `false` |
| Squash default commit message | `PR_TITLE` + `BLANK` | `COMMIT_OR_PR_TITLE` + `COMMIT_MESSAGES` |
| Ruleset `main branch protection` | active | missing |

**Required checks:** `check`. Improvised, no `gate` in this repository. It ran on 10/10 pull requests.
- `scan`: left out, it only labels pull requests.
- `release`: left out, it runs only on tags.

**Not verified:** Allow auto-merge, the token has no admin access.

**Good to know:**
- Direct pushes to `main` will stop working, also for you. 5 of the last 10 commits had no pull request.

**Fixes:**
1. Turn on auto-merge.
2. Set the squash default commit message to "Pull request title".
3. Create the ruleset, requiring `check`.

Which fixes should I apply?
```

Keep to these rules:

- Put only differences in the table, with passing items as a count. Merge the title and
  message of one commit default into a single row.
- Omit any section with nothing to say, except the required checks line.
- Keep each line to one fact and its evidence. Do not explain what a setting does, repeat
  the table in prose, or paste a ruleset payload unless the user asks.
- List rejected checks only for case 2 of Step 2, with one short reason each.
- In "Good to know", include only what changes the user's decision. Turn the `NOTE` lines
  into this section. When a fix adds the pull request requirement, say that direct pushes
  will stop working, for the user too unless a bypass actor exists, and quote the count
  from the `Recent default branch commits without a pull request` note if there is one.

A compliant repository gets only this:

```markdown
## repo-standards: owner/repo

**Compliant** (M checks pass)

**Required checks:** `gate`. It ran on 10/10 pull requests.
```

If there are differences, always end by offering the fixes, even when the user asked only
for a check, so that they can go from report to fix in one reply. Then stop, because
approval to audit is not approval to change.

## Step 4: Apply approved changes

Apply only what the user approved.

Send only the settings that differ. The commit title and message fields must go
together as a pair:

```bash
gh api -X PATCH repos/<owner/repo> \
  -F delete_branch_on_merge=true -F allow_auto_merge=true \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=BLANK
```

For the ruleset, preview first, show the user anything unexpected, then repeat with
`--apply`. The script updates an existing repository ruleset in place and keeps its
other rules and bypass actors.

```bash
<skill-location-dir>/scripts/apply-ruleset.sh <owner/repo> --check gate
<skill-location-dir>/scripts/apply-ruleset.sh <owner/repo> --check gate --apply
```

Use `--no-status-checks` for case 3 of Step 2. A ruleset owned by an organization cannot
be changed through the repository, so point the user to the organization settings.

A default branch other than `main` needs more care. Do not treat it as a routine setting:
renaming (`POST repos/<owner/repo>/branches/<old>/rename`) retargets pull requests but
requires everyone to update their clones, and it can break workflows that name the old
branch. Explain this and get a separate, explicit approval.

## Step 5: Verify

Re-run `audit.sh` and report the final state. GitHub can ignore a setting without an
error, for example auto-merge on a plan that lacks it, so only the second audit proves
a change worked. Report any remaining difference with its cause rather than retrying.

`audit.sh` always prints a `REVIEW` line for required status checks, even on a compliant
repository, because it does not make that decision. Compare the line with your decision
from Step 2: if they match, the item passes.
