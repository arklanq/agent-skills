# Dashboard components.

These are optional building blocks, not a required layout. Read this catalog first, then only the component files needed. The default evidence-first composition is in `evidence.js`. Card-based maps remain available in `roadmap.js`, and simpler list components in `work.js`. All are optional and need no package manager or network. Session creation copies the library, so later library changes do not silently alter existing dashboards.

## API.

Every component returns a DOM element; append it to your layout. Supplied content is rendered using `textContent`.

| Component | Data | Useful for. |
| --- | --- | --- |
| `evidenceMap(state)` | Tasks, milestones, and their supplied order. | Framed stage map with counts, waiting marker, and links to evidence sections. Defined in `evidence.js`. |
| `evidenceLedger(state)` | Tasks, milestones, panels, and changedIds. | Full evidence rows grouped by milestone; unassigned tasks remain visible. Defined in `evidence.js`. |
| `priorityPanels(state)` | Current activity, next step, decisions, events. | Blocking decisions first, then activity and history. Defined in `evidence.js`. |
| `roadmap(state)` | State with tasks and milestones. | Ordered stages, current position, and remaining work. Defined in `roadmap.js`. |
| `taskBoard(tasks, changedIds?)` | Tasks and changed task IDs. | Task areas with visible status, evidence, blockers, and expandable details. Defined in `roadmap.js`. |
| `mapPanels(state)` | State with now, next, decisions, events. | Current action, decisions, and recent changes. Defined in `roadmap.js`. |
| `element(tag, text?, className?)` | DOM tag, plain text, optional CSS class. | Creating safe custom layouts. |
| `t(key, vars?)` | Key from `defaultStrings` in `i18n.js`, optional `{name: value}` placeholders. | Interface copy in the user's language: `state.ui.strings` overrides the English default. |
| `locale()` | None. | The `ui.lang` tag for `toLocaleString` and similar calls, or undefined for the browser default. |
| `status(status)` | `todo`, `doing`, `done`, `blocked`, `unknown`. | A compact readable status label. |
| `taskList(tasks, changedIds?)` | Task objects with `id`, `title`, `status`, optional `evidence`, `blocker`. | Expandable work rows with changed-item highlights. |
| `milestone(milestone, tasks)` | Milestone with `title`, `taskIds`, optional `proposed`; full task list. | Counting unfinished work without inventing a percentage estimate. |
| `decisions(decisions)` | Objects with `title`, optional `default`, `blocking`. | Exposing decisions and proposed defaults. |
| `activity(events)` | Objects with `at` (ISO timestamp) and `text`. | The eight latest reported events. |

The registry is `window.DashboardComponents`. Starter class names and CSS variables live in the session's `template.html`. Add new styles there or in a `<style>` element produced by your custom renderer. Use `--bg`, `--surface`, `--fg`, `--muted`, `--line`, `--wash`, and `--accent` to preserve the fixed dark palette.

## Evidence-first default.

Use `evidenceMap(state)` and `evidenceLedger(state)` together. Every supplied milestone is one roadmap stage, including when there is only one. Without milestones, task nodes link to individual rows. The map shows per-stage completed counts and marks the first unfinished stage as current only when doing or blocked; blocked is labelled “Waiting here” (`map.waiting`). Empty milestones remain unknown. Clicking a stage focuses its evidence section. Full titles, panel labels, evidence, and active blockers remain readable without expanding cards. Tasks outside milestones appear in a separate group. Completed tasks do not display leftover blocker fields as active blockers.

Mark a changed subset with quiet text labels only, never card outlines. Animate only the icon of an in-progress task. An initial snapshot where every task is marked changed does not mark the entire board. Blocking decisions come before informational decisions and current activity, and the side column moves before the task list on small screens. Do not infer which tasks a decision unlocks from the existence of unrelated blocked tasks.

```js
window.dashboardRender = (state, root, {element, components: C}) => {
  root.append(element('h1', state.title), C.evidenceMap(state));
  const grid = element('div', null, 'layout ad-grid');
  grid.append(C.evidenceLedger(state), C.priorityPanels(state));
  root.append(grid);
};
```

The default template supplies the ledger styles. Existing sessions retain their own template and components. `roadmap`, `taskBoard`, and `mapPanels` below remain available for compact card-oriented compositions.

## Card roadmap behavior.

With two or more milestones, each supplied milestone becomes a stage and its status is derived from its referenced tasks. With one milestone, its task order becomes the roadmap. Without milestones, task order is used. An empty milestone is unknown. All referenced tasks done means done; an explicitly active task means in progress; unresolved blockers mean blocked; partial completion means in progress. These are visual summaries of supplied facts, not inferred dependencies. Only an in-progress stage gets the current-position marker. Selecting a stage opens the relevant task details; stages without known tasks are disabled.

```js
window.dashboardRender = (state, root, {components}) => {
  root.append(components.roadmap(state));
  root.append(components.taskBoard(state.tasks, state.changedIds));
  root.append(components.mapPanels(state));
};
```

Use [the visual direction](../references/visual-direction.md) for the user's chosen design language. The three components can be composed independently; they do not require the default layout.

## Custom composition.

Write this in the session's `custom.js`. Saving it refreshes the open dashboard. Return content synchronously; the runtime provides state and preserves open details with stable `data-key` attributes.

```js
window.dashboardRender = function (state, root, {element, components}) {
  root.append(element('h1', state.title));
  root.append(element('p', state.goal));
  const blocked = state.tasks.filter(task => task.status === 'blocked');
  if (blocked.length) {
    root.append(element('h2', 'Waiting on a dependency'));
    root.append(components.taskList(blocked, state.changedIds));
  }
  root.append(element('h2', 'Current work'));
  root.append(components.taskList(
    state.tasks.filter(task => task.status !== 'blocked'), state.changedIds
  ));
};
```

The helper argument also contains `defaultRender(state, root)` to reuse the starter view. An exception in a custom renderer falls back to that view. Keep all required progress information visible when replacing it: current work, next step, milestone remaining count when supplied, blockers, decisions, and changed items. Do not add last-updated timestamps or relative freshness labels. Connection status is maintained automatically by the surrounding runtime and does not claim content freshness. Evidence is plain text; never inject supplied HTML or automatically load remote resources.

## Grow the library.

1. Deliver the working session view first. Keep one-off visualizations in `custom.js`.
2. Promote useful reusable components as a new independent `.js` file defining a uniquely named registry function. Avoid top-level lexical declarations; use an IIFE. File loading order is alphabetical, so do not invoke another component at module initialization.
3. Add the input contract, use case, and a working example to this catalog. Verify an example in a browser, including narrow layouts in the fixed dark theme.
4. For existing components, preserve the function name and input contract. Make incompatible changes under a new name; existing session copies stay pinned until explicitly refreshed.
5. Stage changes in the temporary session and publish with `scripts/library.mjs`, following [references/library.md](../references/library.md). The helper locks and checks the inspected library digest before replacing files. Report added or changed components briefly.

Reusable components read all interface copy through `C.t` and add new keys with English text to `defaultStrings` in `i18n.js`. One-off copy in a session's `custom.js` can be written directly in the user's language.

Do not store task data, project names, or private evidence in the reusable library. No new abstraction is required merely because a drawing is novel.
