# Finding Format

Every area subagent follows these rules and returns its result in this format,
so the main agent can merge the areas into one report.

## Rules for Findings

- The review is read-only: do not change, install or delete anything in the
  repository. Commands you run, such as tests, may write files Git ignores
  (coverage, caches); that is fine. If a command changes a tracked file or
  leaves a new untracked one, do not revert it yourself, because the user may
  have had their own changes there: name the file under "Not Checked" so the
  main agent can tell the user.
- Skip checks that do not apply to the stack.
- Back every finding with evidence: `path:line`, a command output or a count.
  Mark anything unconfirmed as "to verify" instead of stating it as fact.
- Judge by maintenance cost, not taste. A 400-line file that is a flat data table
  is fine; a 300-line component mixing fetching, state and rendering may not be.
- Group repeated instances into one finding with a list of locations.
- Prefer a few precise findings over a long list of nitpicks.
- When a tool an area file names is not available, use a search-based check
  where it is practical, mark its results "to verify" and name the tool under
  "Not Checked".
- Scan sections are leads, not findings: generated files, fixtures, translation
  catalogs and intentional exceptions show up too. Confirm each lead by reading
  the code.
- Documented project conventions override the defaults in the area file; report
  a convention as a problem only when it hurts maintenance.

## Severity

- **Critical**: breaks builds, deploys or tests, exposes secrets, or has a known
  exploitable vulnerability in shipped code.
- **High**: makes routine changes expensive or risky (duplicated core logic, god
  modules, untrustworthy tests, unsupported runtime).
- **Medium**: noticeable friction or waste (slow or wasteful CI, outdated majors,
  misleading docs, dead scripts).
- **Low**: cleanup and polish.

## Output

Return Markdown in this shape. Leave out sections that would be empty. Do not
number findings; the main agent assigns IDs.

```markdown
## Area: <area name>

### Status
| Row | Status | Summary |
| --- | --- | --- |
| <report table row this area owns> | OK / Attention / Problem | <one line> |

### Findings

**<Short title>**
Severity: Critical / High / Medium / Low
Confidence: confirmed / to verify
Where: `path/to/file.ts:42`, `path/to/other.ts`
Evidence: <what you saw, a count or a command result>
Fix: <concrete change, naming what to keep and what to remove>
Effort: S / M / L
Needs decision: <only when the user must choose, for example between two
libraries; state the options>

### Dismissed Leads
- <Scan or tool lead you checked and rejected, and why, in one line.>

### Extra Tables
<Only when the area file asks for one, for example the CI timing table.>

### Not Checked
- <Check that could not run, and why.>
```

Effort guide: S is under an hour, M is up to a day, L is more than a day.
