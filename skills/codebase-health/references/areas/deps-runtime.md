# Area: Dependencies, Runtime and Scripts

Report table rows: Runtime and package manager; Dependencies; Scripts and
leftover files (scripts part only).

## Inputs

- Scan sections: Overview; Package manifests; Environment and package manager
  files; CI/CD and automation files (for runtime versions only).
- Audit and outdated commands: run the package manager's outdated and audit
  commands (for example `npm outdated` and `npm audit`, `pnpm outdated` and
  `pnpm audit`, `bun outdated` and `bun audit`, `yarn npm audit`). They need
  network access and installed dependencies; if they cannot run, say so under
  "Not checked".
- Update checker: if the project already uses a tool that lists available
  dependency updates for its ecosystem, or the user approved running one, run
  it in its read-only mode to list every available update. Examples are
  `npm-check-updates` (`ncu`) for JavaScript and the Versions Maven Plugin
  (`mvn versions:display-dependency-updates`) for Maven. Never let it rewrite
  manifests during the review.
- Current versions: find the runtime the project actually runs on (for
  example Node.js, Bun, Deno, a JVM or Python) and check its supported release
  lines and the package manager's releases against an authoritative source
  (the runtime's release data, endoflife.date, the package registry), not
  memory. Skip runtimes the project does not use.
- Unused dependencies: this area owns them. Run a dependency or dead-code tool
  the project already has or the user approved (for example `knip` or
  `depcheck`).

## Owned by Other Areas

Leave these to the named area even when you notice them:

- Install, caching and runtime setup steps inside CI jobs: tests and CI.
- Packages the framework recommends or deprecates: framework practices.
- Leftover files that are not scripts: documentation and leftover files.

## Runtime and Package Manager

- One package manager: one lockfile type, matching `packageManager` field,
  matching CI setup. Several lockfiles are a finding.
- Runtime version declared once and consistently: `.nvmrc` or `.node-version`,
  `engines`, CI, Docker images and deploy settings agree. The version must be a
  supported LTS line (or a current Bun release) according to official data.
- `packageManager` and Corepack: version pinned and current enough.
- `.npmrc`, `bunfig.toml`, `.yarnrc.yml`: no obsolete or conflicting options, no
  tokens committed.
- Monorepo workspace config matches the actual package directories.

## Dependencies

- Critical and high vulnerabilities from the audit, split into runtime and
  development dependencies. Rate them by reach first: a flaw in code the
  application calls with outside input can be Critical or High, while one in a
  development tool, a build step or a code path the application never reaches
  is usually Medium or Low. Then weigh the advisory's own severity.
- Outdated majors, especially the framework, build tool, test runner, TypeScript
  and lint tooling. Note how far behind and whether the version is still
  supported.
- Available updates from the update checker: return them as one finding that
  proposes updating all dependencies with that tool, with major updates listed
  separately because they get their own fix batch.
- Unused dependencies and missing ones used through transitive installs.
- Dependencies in the wrong section (build tools in `dependencies`, runtime
  libraries in `devDependencies`).
- Deprecated packages and abandoned packages with maintained alternatives.
- `overrides` and `resolutions` that are no longer needed.
- Heavy dependencies with small usage that a few lines or a platform API can
  replace.
- New dependencies added for trivial tasks.

## Scripts

- `package.json` scripts that reference missing files or binaries, duplicate each
  other, or are not used by anyone (check CI, docs and other scripts).
- Script files (`scripts/`, ad-hoc or one-off folders) not referenced anywhere and
  not documented: either document them in one line or delete them.
- One-off migration or data-fix scripts that already ran.
- Inconsistent script naming (`test:unit` next to `unit-test`).
