# Agent Prompt — 0.5 Slice 3: The Living Floor — Rourke Agent + Rival Cheaters

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Immediate-mode canvas
rendering (`scripts/ui/pixel_scene_canvas.gd` draws rooms and ambient
characters); run logic in `scripts/core/run_state.gd`; seeded RNG via
`RngStream` forks only. This file is self-contained; the binding design
contract is `docs/plans/0.5_grand_casino_rework_plan.md` section 3 — read
it first. Requires slices 1-2 landed; re-verify their actual code.

## Task

### 1. Rourke as a one-room living agent

- Rourke occupies exactly ONE of the three casino rooms at a time.
  State on RunState (serialized): current room, current spot, actions
  until next move evaluation.
- **Movement rule**: track a decaying heat-gain accumulator PER ROOM
  (updated when suspicion increases, attributed to the room where the
  gain happened). At action boundaries, every N actions *(tunable,
  propose 3)*, Rourke moves one room toward the hottest accumulator,
  with inertia (stays put when accumulators are near-equal). All from a
  seeded fork (`create_rng("rourke_floor")` style); never wall-clock.
- **Spatial watch**: `pit_boss_watch_status()`
  (`run_state.gd` — re-verify location) returns watched/active ONLY
  when Rourke is in the player's current room; his presence, position,
  and facing render on the room canvas as a living character (reuse
  the ambient patron/dealer drawing pipeline in pixel_scene_canvas —
  presentational animation from state snapshots, zero per-frame
  copies). The player must be able to SEE whether Rourke is in the
  room at a glance.

### 2. Rival cheater NPCs

- A seeded cast of 1-3 rival cheaters *(tunable)* per casino day,
  each assigned a room and a visible tell (rendered patron with a
  distinct idle behavior).
- On action boundaries, cheaters generate small heat events in their
  room (raising that room's accumulator — pulling Rourke toward them
  and away from you). Their heat does NOT raise the player's suspicion
  directly; it heats the ROOM.
- **Escort events**: seeded chance per action window that Rourke, when
  in a cheater's room, catches them: a visible scene — Rourke walks the
  cheater across the Main Floor to the back-room door (story log entry
  + canvas moment). The cheater leaves the cast; Rourke is OFF THE
  FLOOR (no room) for K actions *(tunable, propose 4)* — the game's
  best cheat window, taught by showing.

### 3. Pre-Grand cameos

- A rare seeded talk-dock event at the tier-2 casinos (delta_queen,
  kitty_cat_lounge): Rourke scouting. Choices feed the EXISTING
  prior-boss-event modifier flags (`grand_casino_event_*` family — see
  `docs/plans/grand_casino_endgame_design.md`); do not invent a new
  modifier channel.

## Hard rules

- Determinism: every draw from named seeded forks at action boundaries;
  determinism probe must stay self-consistent. NPC rendering is
  presentation-only and derives from simulation state.
- Zero-copy per-frame (the 32.6 ms/frame lesson): character animation
  reads immutable snapshots; accumulators update at action boundaries
  only.
- Idle-animation liveness gates untouched — living characters ADD idle
  motion; the perf probe must stay within budgets (measure the casino
  rooms before/after and report).
- Save compat: Rourke/cheater state serializes; canonical ids/flags
  unchanged. Style: tabs, typed GDScript, sparse comments; `.tmp/`
  reports. Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Movement: scripted heat gains pull Rourke room-to-room
   deterministically per seed; inertia holds on ties; save/load
   restores position mid-run.
2. Spatial watch: cheat results while Rourke is elsewhere get no
   watched-cheat evidence; same cheat with Rourke present sets it
   (existing evidence rules now spatial).
3. Cheaters: room heat accumulates from NPC events without touching
   player suspicion; escort removes the cheater and benches Rourke for
   K actions.
4. Cameo event feeds an existing prior-boss flag.
5. Perf probe: casino room idle within budget with all characters
   animating; liveness counters advance.
6. Manual smoke: watch Rourke chase heat, witness one escort scene,
   time a cheat in the window.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_performance_probe.ps1 -RequireGodot`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit (logical units), delete this prompt file in the final commit,
push, report the movement model, tunables chosen, perf numbers, and gate
results. On an unfixable gate failure: stop at last green commit, report
verbatim.
