# Area: Code Shape

Structure, reuse and the damage AI agents typically leave. Report table rows:
Structure; Reuse and duplication.

## Inputs

- Scan sections: Overview; Large source files; Flat directories; Change
  hotspots; Exact duplicate files; Same function or exported symbol defined in
  several files; Deep relative imports.
- Tools: if the project already has `madge` or `jscpd`, or the user approved
  running them, run them for circular dependencies and copied code.

## Owned by Other Areas

Leave these to the named area even when you notice them:

- Test files, including their size and duplicated test helpers: tests and CI.
- Unused dependencies: dependencies.
- Comments, suppressions and debug leftovers: code quality.
- Plan, summary and report files: documentation and leftover files.

## Structure and Organization

A healthy structure lets a newcomer guess where code lives and where new code
goes.

- One clear organizing principle: by feature or domain (preferred for front-end
  apps of any size), or by technical type for small apps. Mixed principles in the
  same layer are a finding.
- Flat directories with dozens of files: group them into subdirectories by feature
  or concern. Asset folders (icons, images) are acceptable when consistently named.
- Files above the line threshold: split by responsibility. Exceptions are data
  tables, generated files, migrations, fixtures and translation catalogs.
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

## Reuse and Duplication

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
  two icon sets, two HTTP clients, two CSS approaches, two test runners. Which
  one stays is usually the user's call: fill "Needs decision" with the options
  and what each would cost to keep.
- Versioned or copied modules (`v1/`, `v2/`, `-new`, `-copy`, `Legacy`): decide
  which version is live and remove the rest.
- Exact duplicate files and assets (from the scan).
- For each finding, name the mechanism to keep and the copies to replace.

## AI-Agent Anti-Patterns

The damage agents typically leave in structure and reuse:

- New helper or component written next to an existing one that does the same.
- Copies with suffixes (`v2`, `new`, `copy`, `fixed`) and the old version kept.
- God files that grew by appending instead of splitting.

The other typical agent damage (narrating comments, suppressions, weakened
tests, plan files, needless dependencies, one-off scripts) is checked by the
areas that own it.
