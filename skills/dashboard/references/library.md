# Reusable component library

The skill's `components/` directory is shared across sessions. Each session receives copies on first start. Rendering can use these components, combine them with new elements, or replace the entire layout. Reuse is optional; optimize for clarity and a fast useful first view.

## Use and customize

Read `components/CATALOG.md`, then only relevant source files. Make task-specific changes in the session copy or `custom.js`. Do not store project facts, task IDs, evidence, or private content in the shared library. If a component has a clear second use, promote it after delivering the dashboard; repeated use is sufficient but not required.

## Publish a new or improved component

1. Run `node <skill>/scripts/library.mjs inspect` and retain its digest. Immediately read the current target source (if it exists) and `components/CATALOG.md`.
2. Stage the proposed `.js` file and complete updated `CATALOG.md` in a directory under the current temporary session. Do not edit shared files directly. Use a lowercase kebab-case filename. Preserve unrelated catalog entries. Document the API, intended use, and a minimal example.
3. Verify the component in the session: normal and narrow layouts, the fixed dark theme, and at least one data update. Preserve the existing public function signature. Use a new component name for an incompatible API. Inspect the actual rendered result; syntax alone does not prove it works.
4. Publish using the original digest:

```sh
node <skill>/scripts/library.mjs publish \
  --file <session-dir>/staging/component-name.js \
  --catalog <session-dir>/staging/CATALOG.md \
  --expected <digest>
```

The helper syntax-checks the JavaScript, then locks the shared library, verifies that nothing changed since inspection, and publishes complete files. A conflict fails without overwriting the library. Re-read and reconcile once; do not blindly retry with a new digest. Starting a session uses the same lock while copying the library. Do not remove another component as incidental cleanup.

Report the published component and why it is reusable in one sentence. Existing sessions stay unchanged. To adopt an improvement into a current session, explicitly copy the needed component after checking its contract; do not automatically refresh the whole library.
