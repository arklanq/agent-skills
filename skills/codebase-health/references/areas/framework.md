# Area: Framework and Tooling Practices

Report table row: Framework practices.

## Inputs

- Scan sections: Overview; Package manifests; Other ecosystem manifests and
  version files; Tool configuration files.
- Documentation: the current official docs for the installed versions, fetched
  as described below.

## Optional Skills

If a skill below is installed and fits the project, use it; otherwise just skip
it and do the checks in this file without it. Load them one at a time: first
the one for the project's main framework or UI library, then another only when
a lead needs it.

- `vercel-react-best-practices`: the project uses React or Next.js.
- `vercel-composition-patterns`: the project has its own React components.
- `modern-web-guidance`: the project ships HTML, CSS or client-side JavaScript.
- `web-design-guidelines`: the project has a user interface.

## Owned by Other Areas

Leave these to the named area even when you notice them:

- Several libraries or approaches for the same job, including two styling
  approaches: code shape.
- Unused packages: dependencies.
- Directory layout beyond the framework's documented conventions: code shape.

## Derive the Checks

Do not rely on a fixed list or on memory: agents often write code for an older
major version than the one installed. Derive the checks from the project.

1. Identify each framework and major tool with its installed version, taken from
   the lockfile rather than the range declared in the manifest: application
   framework, UI library, build tool, styling, state and data libraries, test
   runners, linters.
2. Fetch the documentation for those versions: best-practice guides, the
   migration guide from the previous major, deprecation notes and the
   recommended project structure. Prefer, in this order, docs shipped inside the
   installed package or named in the project's agent rules (they match the
   installed version exactly), Context7 MCP, and the official site. Start with
   the tools that shape most of the code, such as the application framework, UI
   library and styling; fetch docs for the others only when a lead points there.
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

## Independent of the Framework

- Styling: design tokens or theme variables instead of hard-coded colors and
  spacing; dead style files.
- Accessibility basics: semantic elements over clickable generic elements, labels
  on form controls, alt text.
- Build tooling: deprecated plugins or options, configuration copied from old
  templates, leftovers of a previous build tool.
