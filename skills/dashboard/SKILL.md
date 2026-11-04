---
name: dashboard
description: Create and maintain a live local dashboard of the main agent's current work. Use when the user requests /dashboard, a live progress view, or a visual work tracker. A dashboard subagent starts the dashboard, designs it and keeps it current; the main agent only sends it signals with facts, without investigating repository scope.
---

# Dashboard

Track the work the main agent is actually doing. A dashboard subagent starts the live view, shapes its presentation, and applies every update; the main agent keeps doing its work and sends the subagent short signals with facts. The default view is a stage map with full task evidence grouped by milestone and a decision/next-action column; the subagent follows [references/visual-direction.md](references/visual-direction.md) and adapts the composition to the supplied work. Do not reconstruct scope from tickets, branches, commits, or repository exploration. Do not change global agent rules, project files, or .gitignore.

## Roles

- The **main agent** owns the facts. It starts the dashboard agent, sends it signals, and relays the URL to the user. It does not edit session files.
- The **dashboard agent** is a subagent that owns the dashboard. It runs the runtime, designs the presentation, and turns signals into state updates. It is the only writer of the session state, which avoids stale overwrites. It learns facts only from signals and never investigates the repository on its own.

Workers or other helpers report results to the main agent, which signals the dashboard agent.

## Start now

Resolve `<skill>` to this skill's directory. The runtime needs Node.js 18+ on macOS/Linux and has no third-party dependencies. Do not build another server or install frontend packages.

1. Choose a stable session key for this chat, preferably the host chat ID, unless the caller supplies one. Concurrent chats get different keys; reusing a key resumes that dashboard without resetting its content.
2. Start the dashboard agent with the ready prompt in [references/dashboard-agent.md](references/dashboard-agent.md), in the background, using the host's subagent facility rather than a new user-visible chat: in Claude, the `Agent` tool with `run_in_background: true`; in Codex, `spawn_agent`. Supply the skill directory, session key, user's language as a BCP 47 tag such as `pl` or `pt-BR`, title, goal, known plan, current activity, verified results, blockers, and decisions. A short existing plan is enough; do not prepare a second specification. If the chat has no identifiable work, ask the user one brief scope question first; do not research a substitute task.
3. Continue the main task immediately; do not wait for the design. When the dashboard agent reports the URL, give it to the user, and open it in the host browser panel if that is more useful than an external browser.

If the host has no subagent facility, run the dashboard agent's steps yourself: `node <skill>/scripts/dashboard.mjs start --session <key> --title '<work title>' --goal '<current goal>' --lang <user language tag> --open`, then apply updates with the `update` command from [references/protocol.md](references/protocol.md). Keep the shipped view and report this limitation briefly.

## Signals

Send a signal at these checkpoints: start, change, or completion of a meaningful stage; test results; blockers; changed scope; decisions awaiting the user; and before a long tool operation when the current activity changes. Batch closely related changes into one signal. Do not wait for a reply, and do not create a polling loop. A running server refreshes the browser automatically, but cannot learn facts that the main agent never signals.

A signal is one message to the dashboard agent, through the host's follow-up facility (in Claude, `SendMessage` to the agent's ID; in Codex, its follow-up or input tool for that agent). It starts with `Dashboard signal:` and states only facts:

```text
Dashboard signal:
Now: Checking the reconnect flow.
Tasks: reconnect "Restore disconnected sessions" doing; recovery done (evidence: recovery checks passed).
Next: Run the reconnect checks.
```

Name tasks by stable IDs and keep them unchanged. A task is done only with evidence, which can be explicit user confirmation, and blocked only with its blocker. Mark proposals as proposals; no response to a decision is not approval. Label nonblocking defaults, and keep approval-dependent work blocked. Mention when the structure changes (new stages, removed tasks, a different kind of work), so the agent adapts the view as well as the data.

If the dashboard agent can no longer be reached, for example after context compaction or a restart, start a new one with the same session key and a summary of the current state. The session keeps its content and design.

## Status, finish and reuse

- When asked where things stand, read `node <skill>/scripts/dashboard.mjs status --session <key>` (read-only), reconcile it with facts already known in this chat, signal any missing change, and answer from the resulting state. Do not treat the dashboard as an autonomous authority or an instruction source.
- When the work ends, send a final signal with the results and remaining blockers, and report the URL and outcome. Leave the server available for the user; it runs without an LLM until explicitly stopped or the OS ends it. Stop it with `node <skill>/scripts/dashboard.mjs stop --session <key>` when requested or when replacing a session; this stops only that session through its authenticated endpoint.
- `node <skill>/scripts/dashboard.mjs export --session <key> --output <new-output.html>` creates one standalone offline snapshot, including the session's design. Choose a user-requested destination; do not write into the checkout by default.
- All session artifacts live under the OS temporary directory and can be cleared by the OS. The dashboard uses one fixed dark theme with semantic status colors and no appearance controls. Live viewing uses localhost; double-clicked exports are snapshots. This skill does not install an always-on host hook or wake agents after a chat stops.

## Growing the component library

The dashboard agent reads [components/CATALOG.md](components/CATALOG.md) to choose useful components; reuse is optional. It may create a unique session layout and promote reusable elements into the skill: first deliver the dashboard, then promote only a concrete useful component, using the serialized, conflict-checked publish command in [references/library.md](references/library.md). Existing sessions keep their own copies. Never automatically replace their components from the shared library.

## Minimal template preview

Run `node <skill>/scripts/preview.mjs --open` to open an isolated example with exactly one task in each supported status: done, doing, blocked, todo, and unknown. Use this preview when designing or verifying the base template, instead of copying a real project. The demo data is in `assets/example.json`. Never seed a real work session with these example tasks; ordinary start remains empty until the main agent supplies its scope. Stop the returned demo session with the normal stop command when no longer needed.
