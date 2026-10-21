# Codebase Health Checklist

Each area lists what to check and why it matters for maintenance cost. Skip checks
that do not apply to the stack.

## Contents

1. Structure and organization
2. Reuse and duplication
3. Code quality
4. Framework and tooling practices
5. Tests and test configuration
6. CI/CD
7. Runtime and package manager
8. Dependencies
9. Scripts
10. Leftover and misleading files
11. Documentation
12. Comments and language
13. AI-agent anti-patterns

## 1. Structure and organization

A healthy structure lets a newcomer guess where code lives and where new code
goes.

- One clear organizing principle: by feature or domain (preferred for front-end
  apps of any size), or by technical type for small apps. Mixed principles in the
  same layer are a finding.
- Flat directories with dozens of files: group them into subdirectories by feature
  or concern. Asset folders (icons, images) are acceptable when consistently named.
- Files above the line threshold: split by responsibility. Exceptions are data
  tables, generated files, migrations, fixtures and translation catalogs.
  Oversized test files usually signal a missing fixture or helper.
- Colocation: component, styles, tests and stories near each other, or a
  consistent mirrored `tests/` tree. Not a mix of both.
- Dumping grounds: `utils.ts`, `helpers/`, `common/`, `misc/` that grow without a
  theme. Split them by domain.
- Deep relative imports (`../../../`): suggest path aliases already supported by
  the build tool and TypeScript config.
- Barrel files (`index.ts` re-exporting everything) in app code: they slow builds
  and tests and create cycles. Fine at package boundaries.
- Circular dependencies between modules or features.
- Monorepos: each package has one purpose, shared code lives in shared packages,
  not copied between apps; workspace tooling (Turborepo, Nx, workspaces) is
  configured consistently.
- Change hotspots that are also large files are the most expensive places in the
  repository; prioritize them.

## 2. Reuse and duplication

The most important check for agent-written code. Agents often implement a
feature from scratch instead of finding the existing mechanism.

- Same symbol defined in several files (from the scan), then read the bodies:
  identical or near-identical logic is a finding even with different names.
- Typical duplicates: date and number formatting, API clients and fetch wrappers,
  error handling, validation schemas, auth checks, local-storage access, debounce
  and throttle hooks, modal and toast logic, constants and enums, types that
  mirror each other.
- Parallel UI primitives: several button, input, modal or badge components with
  overlapping props instead of one primitive with variants.
- Several libraries for the same job: two date libraries, two state managers,
  two icon sets, two HTTP clients, two CSS approaches, two test runners.
- Versioned or copied modules (`v1/`, `v2/`, `-new`, `-copy`, `Legacy`): decide
  which version is live and remove the rest.
- Exact duplicate files and assets (from the scan).
- For each finding, name the mechanism to keep and the copies to replace.

## 3. Code quality

- Components and functions doing several jobs: data fetching, state, business
  rules and rendering in one place.
- Type and lint suppressions (`@ts-ignore`, `as any`, `eslint-disable`) clustered
  in files: they hide real errors.
- TypeScript strictness: `strict` enabled, no broad `skipLibCheck` workarounds for
  own code, no `any` in public types.
- Debug leftovers (`console.log`, `debugger`) in application code.
- Unused exports, files, dependencies and feature flags that are always on or off.
- Defensive code for impossible cases, swallowed errors (`catch {}`), and
  error handling that only logs.
- Inconsistent naming of files and symbols within the same layer.
- Dead branches behind constant conditions; commented-out code.

## 4. Framework and tooling practices

Do not rely on a fixed list or on memory: agents often write code for an older
major version than the one installed. Derive the checks from the project.

1. Identify each framework and major tool with its installed version, taken from
   the lockfile rather than the range in `package.json`: UI framework,
   meta-framework, build tool, styling, state and data libraries, test runners,
   linters.
2. Fetch the current official documentation for those versions: best-practice
   guides, the migration guide from the previous major, deprecation notes and the
   recommended project structure. Prefer Context7 MCP; otherwise use the official
   site.
3. Turn the docs into a short list of checks for this project, then search the
   code for violations. Cite the documentation page in each finding.

Typical agent mistakes to look for in any framework:

- APIs, patterns or config options from an older major, or deprecated ones.
- Old and new paradigms mixed in the codebase without a migration plan.
- Reimplementing what the framework or its official packages already provide.
- Working around the framework's model with escape hatches and suppressions
  instead of following it.
- Crossing boundaries the framework defines, such as server and client code,
  build and runtime, or public and secret configuration.
- File layout and naming that differ from the framework's documented conventions.
- Lint rules or plugins recommended by the framework not enabled.

Independent of the framework:

- Styling: one approach per project; design tokens or theme variables instead of
  hard-coded colors and spacing; dead style files.
- Accessibility basics: semantic elements over clickable generic elements, labels
  on form controls, alt text.
- Build tooling: deprecated plugins or options, configuration copied from old
  templates, leftovers of a previous build tool.

## 5. Tests and test configuration

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
- Configuration: one unit test runner per project, fitting the build tool;
  test environment set per need (DOM emulation only where the DOM is needed), setup files that are actually used, coverage thresholds
  that reflect reality, no duplicated config between workspace packages.
- End-to-end: stable locators (roles, labels, test IDs) instead of selectors
  tied to markup structure, the dev server reused locally, traces or videos only
  on failure or retry, a sensible worker count, only the browsers that matter.
- Speed: slow suites get skipped by people; note the duration and the slowest
  files when you run them.

## 6. CI/CD

CI should be correct, current, fast and cheap.

- Correctness: CI runs the same lint, typecheck, test and build commands as local
  scripts; required checks exist for the main branch; failing steps are not
  masked with `continue-on-error` or `|| true`.
- Currency: action versions on current majors (for example `actions/checkout`,
  `actions/setup-node`), pinned by tag or SHA consistently; runner images not
  deprecated; Node.js version taken from `.nvmrc` or `package.json` via
  `node-version-file`, not hard-coded in several places.
- Speed and cost: dependency caching, a frozen-lockfile install with the
  project's package manager instead of a plain install, `concurrency` with `cancel-in-progress` for pull
  requests, path filters for docs-only changes, `timeout-minutes` on jobs, jobs
  parallelized where independent, expensive suites (e2e, visual) limited to where
  they add value, matrices no wider than needed, artifact retention set.
- Duplication: the same steps copied across workflows instead of a reusable
  workflow or composite action.
- Automation: Dependabot or Renovate configured and its PRs not piling up.
- Deployment config (`vercel.json`, `netlify.toml`, Dockerfiles): no stale
  settings for removed routes, matching runtime versions, no secrets in files.

## 7. Runtime and package manager

- One package manager: one lockfile type, matching `packageManager` field,
  matching CI setup. Several lockfiles are a finding.
- Runtime version declared once and consistently: `.nvmrc` or `.node-version`,
  `engines`, CI, Docker images and deploy settings agree. The version must be a
  supported LTS line (or a current Bun release) according to official data.
- `packageManager` and Corepack: version pinned and current enough.
- `.npmrc`, `bunfig.toml`, `.yarnrc.yml`: no obsolete or conflicting options, no
  tokens committed.
- Monorepo workspace config matches the actual package directories.

## 8. Dependencies

- Critical and high vulnerabilities from the audit, split into runtime and
  development dependencies. Development-only issues are usually lower severity.
- Outdated majors, especially the framework, build tool, test runner, TypeScript
  and lint tooling. Note how far behind and whether the version is still
  supported.
- Unused dependencies and missing ones used through transitive installs.
- Dependencies in the wrong section (build tools in `dependencies`, runtime
  libraries in `devDependencies`).
- Deprecated packages and abandoned packages with maintained alternatives.
- `overrides` and `resolutions` that are no longer needed.
- Heavy dependencies with small usage that a few lines or a platform API can
  replace.

## 9. Scripts

- `package.json` scripts that reference missing files or binaries, duplicate each
  other, or are not used by anyone (check CI, docs and other scripts).
- Script files (`scripts/`, ad-hoc or one-off folders) not referenced anywhere and
  not documented: either document them in one line or delete them.
- One-off migration or data-fix scripts that already ran.
- Inconsistent script naming (`test:unit` next to `unit-test`).

## 10. Leftover and misleading files

- Backup and temp files (`.bak`, `.orig`, `.old`, `copy`), OS files
  (`.DS_Store`), logs, editor files that should be ignored.
- Committed build output, coverage reports, screenshots and test evidence that
  belong in CI artifacts.
- Empty or near-empty files and directories, placeholder modules.
- Configs for tools the project no longer uses.
- Committed `.env` files with real values (Critical when they hold secrets).
- `.gitignore` gaps that let these files in.

## 11. Documentation

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

## 12. Comments and language

- Comments that narrate what the code does, restate names, or describe the
  change history ("now uses X instead of Y"). Keep only comments that explain
  why, constraints or non-obvious behaviour.
- Large JSDoc blocks on private or self-explanatory functions.
- Commented-out code.
- Code, identifiers, comments, commit-facing docs and test names in English.
  User-facing strings in the product's language are fine, ideally in an i18n
  catalog. Watch for non-English words written without diacritics, which the
  scan cannot detect.

## 13. AI-agent anti-patterns

Quick list to keep in mind across all areas:

- New helper or component written next to an existing one that does the same.
- Copies with suffixes (`v2`, `new`, `copy`, `fixed`) and the old version kept.
- God files that grew by appending instead of splitting.
- Plan, summary, progress and report Markdown files in the repository.
- Narrating comments and oversized JSDoc.
- Suppressions (`any`, `@ts-ignore`, `eslint-disable`) added to make errors go
  away.
- Tests weakened, skipped or rewritten to pass instead of fixing the code.
- Defensive checks, fallbacks and try/catch for cases that cannot happen.
- New dependencies added for trivial tasks.
- Configuration options copied without need, including outdated ones.
- One-off scripts left behind after a task.
