# Area: Code Quality

Code quality, comments and language. Report table rows: Code quality;
Documentation and comments (comments part only).

## Inputs

- Scan sections: Overview; Type and lint suppressions; Debug leftovers in
  application code; TODO / FIXME / HACK markers; Non-ASCII characters in code;
  Comment-heavy files.
- Tools: if the project already has a dead-code tool (for example `knip` or
  `ts-prune`), or the user approved running one, run it for unused exports and
  files.

## Owned by Other Areas

Leave these to the named area even when you notice them:

- Files on the scan's large-file or change-hotspot lists: code shape. Report
  the mix of responsibilities here only for files that are not on those lists.
- Duplicated logic and parallel implementations: code shape.
- Unused dependencies: dependencies.
- Framework-specific APIs and lint rules: framework practices.

## Code Quality

- Components and functions doing several jobs: data fetching, state, business
  rules and rendering in one place.
- Type and lint suppressions (`@ts-ignore`, `as any`, `eslint-disable`) clustered
  in files: they hide real errors.
- TypeScript strictness: `strict` enabled, no broad `skipLibCheck` workarounds for
  own code, no `any` in public types.
- Debug leftovers (`console.log`, `debugger`) in application code.
- Unused exports, files and feature flags that are always on or off.
- Defensive code for impossible cases, swallowed errors (`catch {}`), and
  error handling that only logs.
- Inconsistent naming of files and symbols within the same layer.
- Dead branches behind constant conditions; commented-out code.
- Implicit state machines: one thing (a request, a form, a dialog, an order, a
  connection) described by several boolean flags or loosely typed status
  values, with transitions spread across handlers, callbacks or effects. This
  allows impossible combinations (loading and failed at once) and every new
  case adds another flag. Fix: one status value with an explicit set of states
  (an enum, a union type or the language's equivalent) and transitions in one
  place. Suggest a state-machine library only for complex flows and only if it
  fits the stack; preserve behaviour, including the states the UI or API
  exposes.

## Comments and Language

- Comments that narrate what the code does, restate names, or describe the
  change history ("now uses X instead of Y"). Keep only comments that explain
  why, constraints or non-obvious behaviour.
- Large JSDoc blocks on private or self-explanatory functions.
- Commented-out code.
- Code, identifiers, comments, commit-facing docs and test names in English.
  User-facing strings in the product's language are fine, ideally in an i18n
  catalog. Watch for non-English words written without diacritics, which the
  scan cannot detect.
