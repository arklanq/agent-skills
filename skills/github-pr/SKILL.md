---
name: github-pr
description: Create or update GitHub pull requests with gh CLI, safe base-branch selection, and optional ticket metadata. Use for every GitHub pull request you create or update, whether the user asks for one or you open it as part of a task.
---

# GitHub Pull Request

Create or update pull requests using GitHub CLI. Tickets are optional, and a
ticket platform must never be assumed without project-specific evidence.

## Instructions

### Step 1: Gather Context

Run the skill's context-gathering script:

```bash
<skill-location-dir>/scripts/collect-context.sh
```

The script outputs the current working directory first. Verify you are in the correct repository before proceeding.

Pass a remote name as the first argument when the intended PR repository differs
from the automatically selected remote, for example in a fork workflow. GitHub
lookups and the base comparison use that selected remote. A failed lookup means
the PR state is unknown, not that no PR exists; resolve reported errors before
creating a PR. Comparisons use locally available refs, which may need refreshing.

### Step 2: Analyze Context

From the script output, determine:

**Base branch:**

- Prefer the base of an existing PR for the current branch.
- For a new PR, use the remote's detected default branch.
- Use another branch as the base only when the user says the work is stacked or
  repository metadata clearly identifies the parent branch. Do not infer a stack
  solely by parsing decorated `git log` output.

**Push status:**

- The context script reports the PR remote, upstream, and commits absent from the
  locally known push destination. The upstream and push destination can differ.
- If the push destination is unknown, verify the intended head remote and branch
  before deciding whether a push is needed. Local refs may be stale.

**Existing PR:**

- The script lists branch-name matches. Verify the head repository and branch
  against the intended push destination before treating a PR or its displayed
  base as a match; different forks can use the same branch name.
- Exactly one verified matching PR → update it within the requested scope.
- A successful lookup finds no matching PR → create a new PR.
- A failed lookup or multiple matches → resolve the uncertainty first.

**Ticket system:**

Detect ticket usage before adding any ticket identifier:

1. Prefer an explicit ticket ID or URL supplied by the user.
2. Otherwise inspect repository evidence such as `CONTRIBUTING`, the PR template,
   branch naming, recent PR titles, and provider configuration or URLs.
3. Identify a provider only from evidence such as a provider URL or integration
   config. A token like `ABC-123` alone is a generic ticket candidate, not proof
   of Linear, Jira, YouTrack, or another platform.
4. If the project has no clear ticket convention, omit ticket metadata. Never ask
   for or invent a ticket merely to create the PR.

### Step 3: Push if Needed

Push to the verified remote and branch hosting the PR head. In a fork workflow,
this may differ from both the upstream and the remote used for the base comparison.

```bash
git push -u <head-remote> HEAD:refs/heads/<head-branch>
```

### Step 4: Create or Update PR

Use the verified base repository explicitly in both cases. For a new PR, specify
the verified head branch with `--head`; qualify it with the fork owner when needed.

```bash
gh pr create --repo <base-repository> --head <head-selector> --draft --base <base-branch> --title "title" --body-file <body-file> --assignee "@me"
```

For an existing PR, edit the verified PR number instead of creating another one.
Pass only the fields that the task requires changing; creation defaults do not
reset its existing assignees, base, or draft status.

```bash
gh pr edit <pr-number> --repo <base-repository> --title "title" --body-file <body-file>
```

**Guidelines:**

- Use Conventional Commits for the title, with the linked ticket ID as the scope
  when available, e.g. `feat(PRO-123): add import functionality`. Follow repository-specific
  title conventions when present.
- Use the repository PR template when present; otherwise use the bundled `template.md` fallback.
- Write for senior developers. Keep the description short and proportional to
  the changes, preferably one concise bullet per major change. Omit details
  reviewers can infer from the diff or linked ticket.
- Link the ticket by its ID instead of duplicating its description. Use a verified
  ticket URL; never invent a provider or link.
- For stacked PRs, describe only this branch's changes.
- Use the assignee specified by the user or repository. Otherwise assign the
  authenticated GitHub user with `--assignee "@me"`, as in the example above.
- Create in draft mode unless explicitly requested otherwise.
- Write the description to a temporary file and pass it with `--body-file` to preserve
  multiline Markdown and avoid shell interpolation.

### Step 5: Output

Read back the created or updated PR to verify its repository, head, base, and
requested metadata changes. Always return its URL.

```
Created or updated PR
* Merge: `<branch>` into `<base-branch>`
* PR URL: <url>
* Ticket: <id and provider, only when detected>
```

### Finalization

When the PR is the final version with no further iterations expected, and a
ticket is linked, propose these state changes for explicit approval:

1. Change the PR from draft to ready for review.
2. Move the linked ticket to In Review, when the corresponding integration is available.

Execute only the changes explicitly approved by the user. Approval already given
in the conversation counts; do not request it again. Skip changes already applied
and skip the proposal entirely when there is no linked ticket or the user has
indicated that the PR is still a work in progress.

## Rules

- Never add AI-attribution signatures, footers, or suffixes to PR titles or
  descriptions. Factual mentions of AI tools that are relevant to the changes
  are allowed.

## Requirements

- GitHub CLI (`gh`) installed and authenticated
- Git remote configured
- Push access to repository
