# Agent Prompt — Fix Selection Flashing + Environment Object Teleporting (do this as part of your current tutorial work)

Copy everything below this line into the worker agent. This is a follow-up
to the guided-tutorial rework you are executing — fix these two bugs while
completing that work, since they are most visible during the tutorial's
highlight-and-select flow.

---

Two player-visible bugs in the current build, both around highlighting and
selecting environment objects. Root-cause them precisely (do not guess-patch),
then fix them cleanly. They are probably the SAME underlying cause.

## Bug 1 — Environment objects change position when selected (the beer
## "teleports across the environment")

Selecting/highlighting an object causes environment objects to MOVE to new
positions (reported: the beer/drink object jumps across the room). Object
positions must be STABLE for the lifetime of an environment instance and must
never change as a result of selecting, focusing, or refreshing the UI.

Where to look:
- Object positions derive from layout SPOT fields via
  `scripts/ui/environment_interaction_view_model.gd`
  (`layout_spot_field_name`, `layout_spot_to_board_position`,
  `_interaction_rect_for_object`/`focus_rect`), keyed by object type
  (`service_spots`, `event_spots`, `item_spots`, `lender_spots`, ...). The
  beer is a service/drink object → `service_spots` (confirm).
- The environment generator RANDOMIZES some spot fields with
  `rng.pick_many(...)` (see `environment_instance.gd` `_generated_layout_
  variant` / `ensure_generated_layout`). That randomization is meant to run
  ONCE at environment generation — NOT on every refresh.
- Trace what happens on `focus_interactable_object(...)` and the action-panel
  / world-header refresh path in `scripts/ui/foundation_main.gd`
  (`_refresh_world_header`, `_render_action_panel`, `_rebuild_actions`, the
  object-layout snapshot): find where the object→spot assignment (or the spot
  field order) is being RE-COMPUTED or RE-ROLLED during selection/refresh
  instead of read from a fixed, cached layout.

The fix (principle): compute each object's board position ONCE when the
environment instance is generated, cache it stably (in the environment/run
state or a per-instance layout cache), and read it unchanged on every
subsequent refresh, selection, and focus. Selecting an object must never
re-run `pick_many`, re-order a spot field, or re-derive a different
object→spot index. Determinism unchanged.

## Bug 2 — Selection/highlight glitches and flashes

When an object is highlighted/selected, the highlight flashes/glitches. The
coach/interaction highlight (`scripts/ui/coach_overlay.gd` — `live_anchor_
rect`, `set_live_anchor_rect`, and its `queue_redraw`; dim alpha flips
between 0.10 and 0.40 on `highlight_emphasis`) is being driven unstably.

Likely causes to confirm:
- The anchor rect is recomputed repeatedly (every frame or every refresh) and
  chases a MOVING target (Bug 1) — fixing Bug 1 may remove most of the flash.
- The selection state oscillates (select → refresh → re-layout → re-select),
  each cycle firing `queue_redraw` with a changed rect/alpha.
- The highlight is rebuilt per frame rather than on actual selection change.

The fix (principle): the highlight anchor reads from the STABLE cached object
rect and updates ONLY when the selection actually changes (an action
boundary), not per frame and not in a select/refresh loop. No oscillation, no
per-frame rect recompute, steady dim/emphasis. Zero-copy per-frame and
idle-liveness rules apply.

## Prove the fix

1. Select/deselect and highlight objects repeatedly in a room that has the
   beer/drink and other objects (and in the tutorial's guided highlights):
   NO object changes position at any point, and the highlight is steady with
   no flash/flicker. Capture before/after.
2. Repeat across several environments and both screen sizes; repeat with the
   tutorial's scripted highlight sequence — nothing teleports, nothing
   flashes.
3. Determinism unchanged (object layout is still seeded and reproducible —
   the same seed yields the same fixed positions); no per-frame allocation
   introduced; idle-liveness untouched.

## Hard rules

- Root cause, not symptom; do not "fix" the flash by hiding the highlight or
  the teleport by pinning one object — fix the layout-stability and
  highlight-update seams properly. Determinism preserved (seeded layout, same
  positions per seed). Zero-copy per-frame; idle-liveness untouched. Tabs,
  typed GDScript, sparse comments; captures under `.tmp/`. Never revert or
  stage unrelated user-owned work.
- Fold this into your current tutorial work: commit it in its own logical
  unit(s) with a clear message, and include the before/after proof in your
  report. It gates the same suites your tutorial work does; the stuck-state
  sweep and visual QA must stay green.

## Gates (with your existing work)

- `tools\validate_project.ps1`
- `-FoundationSuite` systems + ui
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_visual_qa.ps1`

## Report

The confirmed root cause of each bug (they may be one), the exact fix, and
the before/after proof that objects no longer move on selection and the
highlight no longer flashes.

Execution record: implemented in `0113eabf`; proof is recorded in
`docs/plans/tutorial_selection_flash_and_object_teleport_fix.md`.
