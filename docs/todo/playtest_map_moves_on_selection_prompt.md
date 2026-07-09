# Agent Prompt - Playtest Fix: World Map Must Not Move When A Node Is Selected

Priority: playtest blocker for the 0.4 release (runs before the repackage
step).

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). Owner playtest: **selecting an area on the
world map makes the map move** — the view shifts/re-frames on click
instead of staying put.

## Likely mechanism (verify, then fix at the source)

`scripts/ui/world_map_canvas.gd` derives its view window from focus
bounds: `_bounds_focus_nodes()` (:316) reads
`snapshot.map_focus_node_ids`, and the window is computed and clamped from
those nodes' bounds (:279-312). If node selection adds the selected node
to (or replaces) `map_focus_node_ids`, every selection recomputes the
bounds and the whole map re-frames — which matches the observed bug.
Trace who writes `map_focus_node_ids` (world_map.gd snapshot building
and/or foundation_main's selection handling) and confirm.

## Required behavior

1. **Selecting a node never changes the map framing.** Selection updates
   highlight/detail state only. The view window is stable across an
   entire map session: computed once from stable inputs (all visible
   nodes, or the route-relevant set at map open) and unchanged by
   selection, hover, or preview interactions.
2. Re-framing is allowed ONLY on events that genuinely change what exists
   to look at (new node revealed, map opened fresh). If such a case
   occurs while the map is open, the window updates without a jarring
   jump (either imperceptible or smoothly interpolated — pick the
   cheaper one consistent with existing canvas patterns; no new tween
   systems for this fix).
3. Applies to both map modes (in-run world map and the meta map — they
   share this canvas).

## Guard

Extend the map/UI foundation coverage: capture the computed view window,
perform a selection action on a node near the map edge (the worst case
for bounds shift), and assert the window is identical before and after.
Cover hover too if hover feeds the same path.

## Verification

1. Manual: open the map, click several nodes including edge nodes — the
   map does not move; travel previews/details still display correctly.
2. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
3. `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
   and `-FoundationSuite systems -TimeoutSec 300` (with the new guard).
4. Note that 0.4.0 packages remain stale until the repackage step.
   Archive to docs/todone/ with the execution record (confirmed trigger,
   before/after behavior); update QUEUE.md and commit per the queue
   lifecycle.

## Hard constraints

1. Fix the framing trigger at its source; do not freeze the camera by
   suppressing legitimate reveal re-framing.
2. Zero-copy per-frame rules hold; no per-frame bounds recomputation if
   the window is now session-stable (compute on open/reveal only).
3. Match house style: tabs, typed GDScript, sparse constraint comments.
