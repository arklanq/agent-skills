# Report Template

Use this structure. Omit empty severity sections. Keep each finding to a few
lines; the evidence and the fix matter more than the description.

```markdown
# Codebase health: <repository or scope>

<YYYY-MM-DD> · <stack summary, for example "Next.js 16, React 19, Vitest, Bun 1.3">

## Verdict

<Two to four sentences answering: can this codebase be maintained cheaply and
extended easily? Name the biggest risk and the highest-value fix.>

| Area | Status | Summary |
| --- | --- | --- |
| Structure | OK / Attention / Problem | <one line> |
| Reuse and duplication | | |
| Code quality | | |
| Framework practices | | |
| Tests | | |
| CI/CD | | |
| Runtime and package manager | | |
| Dependencies | | |
| Scripts and leftover files | | |
| Documentation and comments | | |

## Findings

### Critical

**C1. <Short title>**
Where: `path/to/file.ts:42`, `path/to/other.ts`
Evidence: <what you saw, a count or a command result; start with "To verify:"
when it is not confirmed>
Fix: <concrete change, naming what to keep and what to remove>
Effort: S / M / L

### High

**H1. ...**

### Medium

**M1. ...**

### Low

**L1. ...**

## Needs your decision

Findings where the user must choose before anything is fixed, with the options.

- **M6.** <Question and options, for example which of two libraries stays.>

## CI timing

Include when CI timing was measured. Median seconds over <N> successful runs,
with the p90 of the total. Add a runner column when jobs ran on several runner
labels.

PR CI wait: <median over N comparable PR commits, last required check and
dependency chain, or workflow-only timing and why>. Runner time: <median
runner-minutes per commit or workflow run in the same sample>.

| Workflow / job | Queue | Setup | Work | Total (p90) |
| --- | --- | --- | --- | --- |
| <workflow> / <job> | | | | |

## Fix plan

Batches in recommended order. Each batch is independent and verifiable.

1. **<Batch name>**: C1, H2. <What changes and how it is verified.>
2. **<Batch name>**: H1, M3. <...>

## Not checked

- <Area or check that could not run, and why, for example "npm audit: no network
  access".>

## Changed during the review

Include only when a review command changed a tracked file or left a new one.

- <File and the command that changed it.>
```

Effort guide: S is under an hour, M is up to a day, L is more than a day.

After fixes, add a `Status` line under each finding: `Fixed`, `Skipped` or
`Deferred`, with a short reason for the last two.
