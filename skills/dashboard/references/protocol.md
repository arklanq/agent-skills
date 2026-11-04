# Runtime and data contract

The only prerequisite is Node.js 18+ on macOS/Linux; the runtime has no third-party dependencies. Session files live in `os.tmpdir()/agent-dashboard-<uid>/<session-key>/`. The session key separates chats; it does not identify a repository. Files are local and temporary. The server binds to 127.0.0.1 on a free port and serves only the dashboard, state, and event endpoints.

## Commands

Run `node <skill>/scripts/dashboard.mjs --help` for arguments. Commands are `start`, `update`, `activity`, `status`, `stop`, `export`. `serve` is the internal detached-process entrypoint, not a second startup path.

Only the dashboard agent runs `update`; the main agent sends it signals instead (see [dashboard-agent.md](dashboard-agent.md)). `update --file <patch.json>` accepts a file, or stdin by default. Store input files inside the session or pass stdin; never put scratch updates into the checkout. CLI output is JSON. Validation failure returns nonzero and leaves the prior state intact. Updates serialize through a file lock and replace state atomically. A repeated identical patch does not increment the revision (appending an event intentionally does).

## Patch fields

| Field | Meaning. |
| --- | --- |
| `title`, `goal`, `now`, `next` | Text from the main agent's signals. Omitted fields stay unchanged. |
| `tasks` | Array of partial task records merged by stable `id`. New records need `id`, `title`, and `status`. |
| `removeTasks` | Explicit array of task IDs to remove; update milestone references in the same patch. |
| `milestones` | Complete replacement array in intended order. Each has `id`, `title`, `taskIds`, and optional `proposed` boolean. Only referenced tasks count toward a milestone. Empty membership means unspecified scope, not completion. |
| `decisions` | Complete replacement array. Each has `id`, `title`, optional `default` text and `blocking` boolean. Displayed proposals are not approvals. |
| `events` | Append-only array of `{at, text}` records. Use ISO timestamps. The runtime keeps the latest 100. |
| `ui` | Optional `{lang, strings}`. `lang` is a BCP 47 tag that sets the page language and date format; `start --lang` sets it initially. `strings` maps interface keys from `components/i18n.js` to translated text and merges by key; missing keys fall back to English. |

Tasks support `todo`, `doing`, `done`, `blocked`, `unknown`. Optional fields: `panel` (group label), `milestone` (display label), `evidence` (plain text), `blocker` (plain text). A done task requires nonempty evidence, which can be explicit user confirmation; a blocked task requires a nonempty blocker. Use unknown when the signals carry no evidence. Do not equate edited files, commits, elapsed time, or an idle agent with completed work.

```json
{
  "title": "Reconnect flow",
  "goal": "Keep the player's session after a brief disconnect.",
  "now": "Running the recovery checks.",
  "next": "Verify the deployment preview.",
  "tasks": [
    {"id": "recovery", "title": "Recover the session", "status": "done", "evidence": "Recovery integration checks passed."},
    {"id": "preview", "title": "Check the deployment preview", "status": "blocked", "blocker": "Waiting for the preview deployment."}
  ],
  "milestones": [{"id": "verified", "title": "Verified reconnect", "taskIds": ["recovery", "preview"]}],
  "decisions": [],
  "events": [{"at": "2026-10-10T09:30:00Z", "text": "Recovery integration checks passed."}]
}
```

Runtime-owned fields: `revision`, `updatedAt`, and `changedIds`. Do not patch them. `changedIds` identifies tasks changed by the last content update. Textual event history can describe deleted tasks and structural changes. `updatedAt` is internal metadata recording content writes, not network heartbeats. Do not display it as a last-updated date, time, or relative freshness label in the dashboard. The template owns one fixed dark palette with a lavender accent. It ignores old appearance settings; there is no preferences endpoint.

## Creative rendering

Each session receives its own `template.html`, `components/*.js`, `custom.js`, and bundled `font.css`. `/` assembles them with current state into one HTML page. Export uses the same renderer. Keep exactly one of each required marker in template.html: `/*__STATE__*/`, `/*__COMPONENTS__*/`, `/*__CUSTOM__*/`. The optional `/*__FONT_FACE__*/` marker in the style block inserts the copied font CSS; keep it in the shipped template. Older sessions without this marker remain compatible. The font includes its license and makes no network requests. Do not dump `font.css` into model context: it contains base64 font data, not design instructions.

Read the component catalog for the renderer hook and helpers. Use `custom.js` for session-specific layouts; no framework is required. Components load alphabetically. Render supplied strings as text, never as HTML or executable code. Do not fetch CDNs or local repository files. Respect reduced motion and maintain keyboard access.

`GET /events` emits `update` when state revision changes, `layout` when session presentation files change, and `activity` when the activity status changes. The shipped client fetches `/state` on update and reloads on layout changes. It reconnects using EventSource. The server checks every 350 ms; there is no LLM polling. A reconnect fetches the current snapshot even if earlier events were missed. Offline exports make no live requests and must say they are snapshots.

## Activity status

The header status shows whether the dashboard agent is working on the dashboard. `activity` starts or renews a 3-minute lease in `activity.json`; `activity --done` clears it. An expired lease counts as idle, so a stopped agent never leaves the dashboard marked as busy. The server also counts any state or layout write as activity for a few seconds, and an untouched shipped layout as a first draft in progress for up to 10 minutes after `start`. The first draft ends with the first `activity --done`. While the first draft is in progress, the live page shows a loading screen with only the work title and an indeterminate bar, so neither the English defaults nor an unfinished design appear; `?draft` in the URL skips it for inspection. Exports never show it. `GET /events` emits `activity` with `idle`, `draft` (the first design is in progress) or `work`. Transport problems take precedence in the label. The status reports dashboard work only, not the main agent's progress.

## Recovery

If content seems stale, the main agent uses `status`, compares it with known chat facts, and signals the missing progress. If disconnected, repeat `start` using the same session key. It preserves files and restarts a dead server. Inspect `server.log` on failure. If temporary files were cleared, start a new session from the main agent's current plan. Never reconstruct scope by scanning branches or issues.

The runtime does not schedule model work or guarantee updates after the host stops executing. Leave a truthful current activity before long operations. `stop` verifies the session identity and uses a session token; it never kills a process by an unverified PID.
