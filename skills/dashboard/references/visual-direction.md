# Visual direction

The user selected a stage map, then supplied a project-map reference with a dark canvas, a prominent current stage, task areas below, and a right-hand column for next action, decisions, and changes. Use this as the default visual language, not a fixed composition for every task.

## What should be understood at a glance

- Where the work stands in the supplied sequence.
- What remains before the next supplied milestone.
- What is in progress, what is blocked, and why.
- What changed since the previous update and what happens next.

## Visual grammar

Start with a near-black background, restrained dot texture on the map, yellow/amber in-progress state, mint completed state, and coral blockers; lavender is reserved for non-status accents. Use this fixed dark palette. Do not add a theme selector, color picker, system-theme detection, or saved appearance preferences. Use the bundled Manrope font, clear 14–16px task text, compact metadata, and a strong horizontal roadmap on desktop. Convert the roadmap to a readable vertical sequence on narrow screens.

The active stage needs a positional marker as well as color. The next milestone's unfinished work belongs near the roadmap. The default uses compact evidence rows grouped by supplied milestones. Show full titles, panel labels, evidence, and active blockers without truncation. Clicking a roadmap stage focuses its evidence section. Show stage counts and use the “Waiting here” marker (`map.waiting`) for a blocked current stage. Keep unassigned tasks visible. Indicate changed subsets with a quiet text label only. Do not outline task cards to signal either a change or progress. Completed tasks must not present a leftover blocker as an active block. Put blocking decisions before current activity and informational decisions. On narrow screens, place this side content before the evidence list. Do not infer a relationship between a decision and every blocked task.

## Adapt rather than decorate

The component library supplies parts, not proof that a tailored design is complete. Choose a useful scale: a small task may need only a short sequence and its current result; parallel streams may need branches or grouped areas. Do not merely add a heading above the default renderer and call that a custom design. Equally, do not invent a different layout when the supplied map already communicates this work well. State briefly why the chosen composition fits.

The roadmap follows the main agent's supplied order. It is not evidence of dependencies or a license to infer project scope. Supplied milestones become roadmap stages, including when there is only one. Without milestones, show the supplied task sequence. Empty milestones remain unconfirmed. Do not invent percentage progress, commit counts, delivery dates, deadlines, or dependency edges to imitate the reference image. Silence is not permission to perform a gated action.

Localize interface copy to the requested language: translate shipped keys through `ui.strings`, and read copy in reusable components through `C.t`. Preserve the automatic transport, data semantics, offline export, keyboard access, and the automatic header status, including its dashboard-agent activity states, when changing presentation. Do not show a last-updated date, time, or relative freshness label; a connected dashboard does not guarantee up-to-date work reports.

## Activity motion

Elements representing in-progress actions must have a subtle animation tied to their own status. Apply this to active task rows or cards, stage markers, current-work panels, and newly designed components; do not limit motion to the two shipped examples. Animate the icon or a small status indicator, not a task card border, background, or text. Do not add progress outlines to tasks: their color, icon, and status already identify them. Changed tasks may retain a quiet text label, regardless of status, but no outline. The roadmap node may retain its pulse; the current-work panel uses a small animated indicator rather than an animated frame.

Start the animation when the represented action is in progress and stop it when that action becomes waiting, blocked, completed, or not started. Another active action elsewhere does not justify animating an inactive element. These are activity cues, not measured progress. Pause loops offscreen or when the tab is hidden, and disable them for prefers-reduced-motion. Keep text, controls, and layout stationary.

The current-work panel is a separate activity summary: while tasks are in progress it uses a subtle yellow/amber surface, a prominent current-action sentence, and an explicit “In progress” badge (`now.badge`) with a visibly pulsing dot. Do not reduce this to an almost invisible unlabelled dot. Keep task-row animations confined to their icons and leave task borders static. Use `scripts/preview.mjs` to inspect all five task statuses together before shipping template changes.

Use the semantic `--doing` and `--task-doing` tokens for every in-progress cue: task icon, active map node, “You are here” pin and pulse, and the “Now” panel and badge. Do not use the decorative `--accent` token as a second in-progress color.
