# Agent Prompt — Locked-Route Affordance in the Travel UI (Data-Driven, Opt-In)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: this task is part of the 0.4.0 polish line, not a
post-release change. Content is data-driven from `data/*.json`; travel
logic lives in `scripts/core/run_state.gd` and `scripts/core/world_map.gd`;
the UI host is `scripts/ui/foundation_main.gd` with the map canvas in
`scripts/ui/world_map_canvas.gd`. This file is fully self-contained.

## Current reality (verified; re-verify line numbers before editing)

`RunState.travel_route_status` (`run_state.gd:2910-2959`) marks a route
with unmet `requires_flags` as `available: false, hidden: true`
(`:2944-2950`), and hidden routes vanish entirely from travel lists. The
same happens for `hide_until_travel_count_met` (`:2934`). That is correct
for secrets, but it gives the player zero feedback that a known,
story-relevant destination is locked and what would unlock it — e.g. the
Grand Casino invite gate (route `grand_casino` in
`data/travel/routes.json` requires the `grand_casino_invite` flag; its
map node may already be visible as a revealed silhouette via neighbor
discovery, `world_map.gd enter_node :464-498`).

Note: if the grand-casino invite-gate task has already landed when you
run, build on its final state; if the routes still use the older
travel-count-only gate, this task still applies to the mechanism — wire
the affordance so whichever routes opt in get it.

## The task (expand the existing system; no new systems)

1. **Data:** support an opt-in field on route definitions in
   `data/travel/routes.json`: `"locked_hint": true`. Routes WITHOUT it
   keep today's behavior exactly (hidden means hidden). Add validation
   for the field in `content_library.gd` route validation.
2. **Core:** in `travel_route_status`, when a route is unavailable due to
   `requires_flags` (or travel-count hiding) AND the route has
   `locked_hint: true`, return `hidden: false` plus a new
   `"locked": true` field and keep the existing `condition_text` /
   `travel_count_condition_text` as the display reason. Check BOTH flag
   evaluation paths (`:2944` and the second one near `:3148`) so the
   status is consistent everywhere.
3. **UI:** locked routes render in the travel list and on the world map
   as visibly locked (dimmed/lock treatment consistent with existing
   disabled styles — reuse the existing disabled-row rendering, do not
   invent a new visual language), showing `condition_text`, and are NOT
   selectable for travel. The map node, if revealed, shows the same
   locked state in its info panel.
4. **Apply to data:** set `locked_hint: true` on the `grand_casino`
   route (the boss should be a visible goal with "You need an
   invitation…" style text). Leave `small_underground_casino` as a hidden
   secret (no hint) — that discovery moment is intended. Do not change
   any other route's behavior.

## Hard rules (binding)

- Existing behavior for every route without `locked_hint` must be
  byte-identical: same lists, same map, same messages. This is opt-in.
- No information leaks: a locked row must never show cost, risk, distance
  previews, or destination internals beyond label + condition text
  (verify what `travel_route_preview` exposes and gate it).
- Zero-copy per-frame: locked-state computation happens where route
  status is already computed (action-boundary refreshes), never per
  frame. Idle-animation liveness untouched. Determinism unchanged.
- Match existing style: tab indentation, typed GDScript, sparse comments
  that state constraints only. Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## QA / Tests (extend the foundation test suite; all required)

1. Route with `locked_hint` + unmet flags → status
   `available:false, hidden:false, locked:true`, condition text present;
   attempting travel is rejected.
2. Same route with flags met → normal available behavior, `locked` false.
3. Route WITHOUT `locked_hint` + unmet flags → `hidden:true` exactly as
   today (regression guard).
4. UI: travel list renders the locked row disabled with condition text;
   selection/confirm is impossible (drive via the UI suite's interaction
   patterns).
5. No-leak test: locked row/preview contains no cost/risk/distance data.
6. Full suites + visual QA + strict single mouse playtest run.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_visual_qa.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`

## On completion

When every gate passes: commit the work with a clear message, delete this
prompt file in the same commit so it cannot be executed twice, push, and
report the changes, which routes opted in, test additions, and each gate
result. If a gate fails and you cannot fix it, stop, do not commit, and
report the failure output verbatim.
