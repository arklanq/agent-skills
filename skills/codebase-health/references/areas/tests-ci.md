# Area: Tests and CI/CD

Report table rows: Tests; CI/CD. Also fill the CI timing table of the report.

## Inputs

- Scan sections: Overview; CI/CD and automation files; all "Test smells"
  sections; Test files without obvious assertions; Test files with the most
  test declarations; Test files that generate tests in loops.
- Test run: run the test suite once if it is reasonably fast; note failures,
  skipped tests, the duration and the slowest files. Skip per-file durations
  when the whole suite takes under about 30 seconds.
- Flaky jobs: the same job failing and passing on the same commit. A rerun
  that passed hides its failed first attempt from `gh run list --status
  success`, so look at runs with more than one attempt and read the earlier
  attempts' jobs with
  `gh api repos/{owner}/{repo}/actions/runs/<id>/attempts/<n>/jobs`.
- CI timing: measure where CI time goes instead of judging it from the workflow
  files, as described under "Measured time" below. Return the 5 slowest jobs
  with the median seconds of queue, setup and work. If the project uses a CI
  provider other than GitHub Actions, use that provider's API or CLI when
  available; otherwise list the check under "Not checked".

## Owned by Other Areas

Leave these to the named area even when you notice them:

- Whether runtime versions agree across manifests, CI and deploy settings:
  dependencies.
- Type checking and lint rules the framework recommends: framework practices.

## Tests and Test Configuration

Tests are only useful when the team trusts them.

- Dead tests: `.skip`, `.todo`, `xit`, commented-out tests, test files no runner
  includes (compare file patterns with the runner's `include`), tests for deleted
  code, tests without assertions.
- Focused tests (`.only`) committed: they silently disable the rest of the suite.
- Flaky patterns: fixed waits (`waitForTimeout`, `cy.wait(1000)`, `setTimeout`),
  real time and dates without fake timers, real network calls, shared mutable
  state between tests, order dependence, random data without a seed.
- Retries used to hide flakiness: retries should be CI-only and low, with
  failures investigated.
- Over-mocking: tests that assert on mocks instead of behaviour, snapshot tests of
  whole pages that nobody reviews.
- Tests weakened, skipped or rewritten to pass instead of fixing the code. Look
  at recent history of test files (`git log -p` over test paths) for added
  `.skip`, removed assertions or loosened expected values in the same commit
  as a code change.
- Configuration: one unit test runner per project, fitting the build tool;
  test environment set per need (DOM emulation only where the DOM is needed),
  setup files that are actually used, coverage thresholds that reflect
  reality, no duplicated config between workspace packages.
- End-to-end: stable locators (roles, labels, test IDs) instead of selectors
  tied to markup structure, the dev server reused locally, traces or videos only
  on failure or retry, a sensible worker count, only the browsers that matter.
- Speed: slow suites get skipped by people; note the duration and the slowest
  files when you run them.
- Test file size and balance: a file with many tests, or with loops or `.each`
  generating them, is a lead even below the line threshold. When the runner
  keeps a file on one worker (no `fullyParallel` in Playwright, Vitest's
  default per-file workers, sharding by file), the slowest file sets the floor
  for the whole run or shard. Take per-file durations from the runner's JSON
  report or CI log (Playwright's "Slow test file" lines), compare the slowest
  file with the shard or run total, and split files by feature or scenario
  until no single file dominates. Loops that reload the page for every case
  usually belong in a unit test, with one end-to-end case left.

## CI/CD

CI should be correct, current, fast and cheap.

- Correctness: CI runs the same lint, typecheck, test and build commands as local
  scripts; required checks exist for the main branch; failing steps are not
  masked with `continue-on-error` or `|| true`.
- Currency: action versions on current majors (for example `actions/checkout`,
  `actions/setup-node`), pinned by tag or SHA consistently; runner images not
  deprecated; runtime version read from the project's version file (for
  example `node-version-file`), not hard-coded in several jobs.
- Measured time: for GitHub Actions, list recent successful runs with
  `gh run list --status success --limit 150 --json databaseId,workflowName`,
  then read each run's jobs with
  `gh api repos/{owner}/{repo}/actions/runs/<id>/jobs --paginate`. Each job has
  `created_at`, `started_at`, `completed_at` and timed `steps`. Split it into:
  - Queue: `started_at` minus `created_at`, waiting for a runner.
  - Setup: job preparation, service containers, checkout, toolchain or
    runtime setup, dependency, tool and browser installation, cache or
    artifact restore, and post-job cleanup steps.
    Classify steps by the action they use and by their name.
  - Work: the remaining steps, the task the job exists for.
  Aggregate per workflow and job name with median and p90, list the 5 slowest
  jobs, and use the dominant part to choose the fix: long queues point to
  runner capacity, concurrency or too many parallel jobs; long setup points to
  caching, install method or checkout depth; long work points to splitting,
  sharding or running less. Leave out skipped and cancelled jobs, earlier
  attempts of rerun runs, and jobs that no longer exist in the current
  workflow files; they distort the numbers. When the workflows use several
  runner labels (for example hosted and self-hosted), group by label too,
  because queue times differ.
- Speed and cost: dependency caching, a frozen-lockfile install with the
  project's package manager instead of a plain install, `concurrency` with
  `cancel-in-progress` for pull requests, path filters for docs-only changes,
  `timeout-minutes` on jobs, jobs parallelized where independent, expensive
  suites (e2e, visual) limited to where they add value, matrices no wider than
  needed, artifact retention set.
- Duplication: the same steps copied across workflows instead of a reusable
  workflow or composite action.
- Automation: Dependabot or Renovate configured and its PRs not piling up.
- Deployment config (`vercel.json`, `netlify.toml`, Dockerfiles): no stale
  settings for removed routes, matching runtime versions, no secrets in files.
