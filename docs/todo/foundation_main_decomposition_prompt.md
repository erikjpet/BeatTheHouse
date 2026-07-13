# Agent Prompt — Decompose foundation_main.gd for Long-Term Maintainability

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: this task is part of the 0.4.0 polish line, not a
post-release change. This file is fully self-contained.

## The problem (verified)

`scripts/ui/foundation_main.gd` is ~13,700 lines and absorbs every new
feature. It is the single most merge-collided file in the repo — recent
release work repeatedly ended in worktrees where task-only commits could
not be partitioned because unrelated changes all landed in this one file.
Every future task pays this tax. The repo already proved the extraction
pattern works: `scripts/ui/run_inventory_screen.gd` +
`run_inventory_view_model.gd` were extracted as signal-based components
(`foundation_main.gd:4240` wires `sell_requested` etc.), and
`talk_dock.gd`, `game_surface_canvas.gd`, `pixel_scene_canvas.gd`,
`world_map_canvas.gd` are already separate.

## The task

Extract the highest-cohesion clusters into signal-based components
following the RunInventoryScreen precedent (component owns its nodes and
rendering; host owns simulation state; communication via signals and
explicit view-model dictionaries; no back-references into host internals).

**Required extractions (in this order, one commit each):**

1. **Meta-session controller** — the meta home/pawn-shop session code
   (~`foundation_main.gd:10100-10850` today: `_build_meta_pawn_environment`,
   `_meta_pawn_interactable_objects`, meta world-map nodes, meta travel,
   meta popup flows). This is the largest coherent cluster and the newest,
   so it moves cleanly.
2. **World-map overlay controller** — the run world-map overlay open/
   close/selection/travel-confirm flow (search `_world_map_overlay`,
   `selected_world_map_node_id`, prewarm path).
3. **Wager-confirmation + result popup flows** — the confirmation popup
   state machine (`_show_wager_confirmation_popup`,
   `_wager_needs_final_bankroll_confirmation`, pending-terminal-check
   state) and the event-choice popup if it shares the pattern.

**Explicitly out of scope:** game-surface command routing, the action
pipeline, `_refresh`/render-environment internals, and anything the
perf-fix tasks in this queue touched (`_process` fan-out, snapshot
pipeline) — do not churn those again; build on their current state.

**Rules of extraction:**

- Move code verbatim where possible; refactor only what the seam forces.
  This task's diff should be dominated by relocation, not rewriting.
- Each component gets a `class_name`, an explicit `configure(...)` or
  view-model entry point, and signals for every host-bound action. No
  component reads `run_state` directly unless the host passes it
  explicitly (match how RunInventoryScreen receives data today).
- After each extraction commit, the full gate battery below must pass
  before starting the next extraction. If extraction 3 proves unsafe
  within the effort budget, ship 1-2 and report why.
- Net effect target: `foundation_main.gd` shrinks by at least ~2,000
  lines; zero behavior change.

## Hard rules (binding)

- Zero functional or visual change. This is a pure architecture move.
- Zero-copy per-frame; idle-animation liveness untouched; determinism
  unchanged (seeds→hashes identical).
- Match existing style: tab indentation, typed GDScript, sparse comments
  that state constraints only. Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## QA (extensive — this is an architecture rework; all required per extraction)

1. Full behavior suites: `FoundationSuite systems` and `ui`.
2. `tools/foundation_visual_qa.ps1` full route pass.
3. Strict mouse playtest: `tools/foundation_mouse_playtest.ps1` single
   strict run per extraction; after the final extraction, a 10-run batch
   via `tools/foundation_mouse_batch_playtest.ps1`.
4. Determinism probe (10 seeds) after the final extraction.
5. Meta smoke (after extraction 1): home → pawn shop travel → sell for
   gold → back home → start run → finish run → collection drop → home.
6. Map smoke (after extraction 2): open/close overlay, select node,
   travel, revisit, scout preview.
7. Popup smoke (after extraction 3): all-in wager confirmation accept and
   decline; environment-game autoplay confirmation path.

## Verification gates (all must pass, after every extraction commit)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_visual_qa.ps1`
- After final extraction additionally:
  `powershell -ExecutionPolicy Bypass -File tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
  and the 10-run strict mouse batch.

## On completion

When every gate passes: push the extraction commits, delete this prompt
file in a final commit, push, and report per-extraction line deltas, the
final `foundation_main.gd` line count, the component APIs (signals +
entry points), and each gate result. If a gate fails and you cannot fix
it, stop at the last green extraction commit, do not commit further, and
report the failure output verbatim.
