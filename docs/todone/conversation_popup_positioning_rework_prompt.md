# Agent Prompt — Conversation Popup Positioning Rework

Copy everything below the line into the worker agent. This reworks how the
conversation dock is positioned relative to the focused object, its info panel,
and the camera. It is related to the deferred selection-stability fix
(`tutorial_selection_flash_and_object_teleport_fix_prompt.md`) — the two touch
the same focus/camera seam, so coordinate; do not re-solve the object-teleport
bug here, but do fix the popup-driven camera/focus churn described below.

## The problem

The conversation popup (the talk dock) causes bad camera and focus behavior:
camera shifts and focus moves that don't make sense, and constant back-and-forth
movement. The dock's side can flip-flop, and the popup can overlap the
highlighted object and its info panel. It needs a stable, legible composition.

## Required behavior

1. **Always anchored to the BOTTOM of the screen.** The dock never floats in
   the middle or top; it lives along the bottom edge in one of the two bottom
   corners.
2. **Left corner or right corner based on what is pointed at / selected.** The
   dock occupies the bottom-LEFT or bottom-RIGHT corner depending on where the
   focused object is — never centered, never straddling.
3. **Character representation always toward the OUTER edge of the screen.** The
   portrait sits on the outer side of the dock (against the screen edge), with
   the text/choices toward the interior. Bottom-left dock → portrait on the far
   left; bottom-right dock → portrait on the far right.
4. **The dock is always on the OPPOSITE side from the focus.** When an object is
   focused and its info panel is shown, the dock goes to the opposite corner so
   both are visible. The highlighted object AND its info/attribute panel must
   remain fully on-screen and **never overlapped** by the dock.
5. **No constant movement / nonsensical shifts.** The side is decided
   deterministically and stably — it does not oscillate while the same
   conversation/selection is active, and the camera does not chase the dock.

## Root-cause direction (fix the churn, not the symptom)

- **Side flip-flop:** `talk_dock.gd` chooses its side in `_preferred_layout_side()`
  and repositions from `set_avoid_global_rect()` whenever the side or occupancy
  changes. If the avoid rect (the focused object + its info panel) jitters even
  slightly, the side flips and the panel re-lays-out every frame. Decide the
  side ONCE per conversation/selection (at the action boundary when the focus is
  set), and add hysteresis so a tiny change in the avoid rect cannot flip it.
  Do not recompute side/position on a per-frame or per-jitter basis.
- **Camera/focus feedback:** the focus/camera pan (`environment_interaction_view_model.gd`
  / `environment_interaction_controller.gd` / `foundation_main.gd`) shifts the
  view toward the selected object while the dock reserves space at the bottom —
  if the pan target reacts to the dock's occupied rect (or vice-versa) they
  chase each other. Break the loop: the camera settles on a single stable
  target for the active selection; the dock reserves a fixed bottom-corner
  footprint that the focus composition accounts for up front (there is already
  an `environment_reserved_global_rect()` for exactly this — use it as the
  source of truth so the object is authored into a safe spot before the dock
  opens, rather than moving things after).
- **Overlap guarantee:** compute the focused object's rect, its info/attribute
  panel rect (`item_found_popup.gd` / `attribute_badge_row.gd`), and the dock's
  bottom-corner rect together, so the dock's corner is chosen to leave the
  object + info panel fully visible and unoverlapped. If both cannot fit, move
  the object/info composition, not by re-flipping the dock mid-conversation.

## Seams

`scripts/ui/talk_dock.gd` — `_position_panel()`, `_expanded_layout_rects()`,
`_preferred_layout_side()`, `set_avoid_global_rect()`, `portrait_panel`,
`occupied_global_rect()`, `environment_reserved_global_rect()`, `VIEWPORT_MARGIN`,
`EXPANDED_PORTRAIT_SIZE`. Focus/camera: `environment_interaction_view_model.gd`,
`environment_interaction_controller.gd`, `foundation_main.gd` (whoever sets the
avoid rect and drives the pan). Info panel: `item_found_popup.gd`,
`attribute_badge_row.gd`.

## Acceptance

1. Open conversations across many different selected objects (left-side,
   right-side, center, and no-selection), at desktop and small-screen sizes:
   the dock is always bottom-anchored, snapped to one bottom corner, portrait
   on the outer edge, on the OPPOSITE corner from the focused object.
2. The focused object and its info/attribute panel are fully visible and never
   overlapped by the dock in any of those cases.
3. The side does NOT oscillate while a conversation/selection is active; the
   camera settles and does not chase — capture a short clip/log showing no
   per-frame position churn (position/side change counters do not advance while
   idle in a conversation).
4. Determinism preserved; no per-frame allocation added to the dock or focus
   hot paths.

## Hard rules

- Root cause, not symptom. Decide side/position at the action boundary, never
  per-frame; add hysteresis against jitter. Determinism preserved (seeded;
  boundaries not wall-clock). Zero-copy per-frame; idle liveness untouched.
  Tabs, typed GDScript, sparse comments. Captures under `.tmp/`. Never revert
  or stage unrelated user-owned work. Do not re-solve the object-teleport/flash
  bug here — coordinate with its prompt.
- Commit in logical units (dock side/position stabilization; camera/focus
  decoupling; overlap-safe composition).

## Gates (all must pass)

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (systems + ui)
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_visual_qa.ps1`
- `tools\foundation_mouse_batch_playtest.ps1` (strict — no churn, no soft-locks)

## On completion

Only after every gate passes and the composition is confirmed stable and
overlap-free across selections and screen sizes: commit per unit, then ARCHIVE
this prompt (git mv `docs/todo/` → `docs/todone/`) with an execution record
(date, commit hashes, before/after captures showing bottom-corner placement,
outer-edge portrait, opposite-of-focus side, no overlap, and no churn, plus
gate results), and report. If blocked, stop at the last green commit, do NOT
push, and report what remains.

## Execution record

- Date: 2026-08-05
- Implementation commits:
  - `9b58e4ce` — pace tutorial blackjack guidance, freeze game logic/Peek time,
    remove tutorial auto-deal, add the one-time dealer reprieve, cap/intervene
    on tutorial Heat, and retire terminal conversations.
  - `49df9d9b` — stabilize the TalkDock in deterministic bottom corners with
    outer-edge portraits and action-boundary side selection.
  - `e63d59c8` — decouple camera/focus composition, preserve presentation
    animation during Pal-only simulation freezes, and add overlap/churn probes.
  - `2aacb73f` — keep the baseline world-map detail/confirmation composition
    clear of the reserved TalkDock footprint without depending on unrelated
    map-controller work.
  - `f408430c` — preserve the established seen-location map contract while
    retaining the new tutorial and TalkDock regression coverage.
- Before evidence:
  - `.tmp/tutorial_rework/captures/03_path_a_xray_pull_tab.png` — prior centered
    dock overlapped the pull-tab tray/control region.
- After evidence:
  - `.tmp/tutorial_rework/nonoverlap_1280/01b_xray_focus_opposite_dock.png`
  - `.tmp/tutorial_rework/nonoverlap_1280/06_path_a_xray_winner_near_bottom.png`
  - `.tmp/tutorial_rework/nonoverlap_1280/08_path_b_raised_bet_chips.png`
  - `.tmp/tutorial_rework/nonoverlap_640/06_path_a_xray_winner_near_bottom.png`
  - `.tmp/tutorial_rework/nonoverlap_640/08_path_b_raised_bet_chips.png`
  - Machine-readable placement records:
    `.tmp/tutorial_rework/nonoverlap_1280/layout_records.jsonl` and
    `.tmp/tutorial_rework/nonoverlap_640/layout_records.jsonl`.
- Stability evidence:
  - `.tmp/tutorial_rework/nonoverlap_1280/stability_1280x720.json`
  - `.tmp/tutorial_rework/nonoverlap_640/stability_640x360.json`
  - Both sampled 180 idle frames with unchanged side, position, occupied rect,
    camera target refresh count, and camera offset (`stable: true`).
- Gate results at detached clean commit `f408430c`:
  - `tools\validate_project.ps1`: PASS (also run by both suite gates).
  - `tools\check_godot.ps1 -RequireGodot -FoundationSuite systems`: PASS.
  - `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui`: PASS.
  - `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`:
    PASS, 320 checkpoints, combined hash `578175084`.
  - `tools\foundation_visual_qa.ps1`: PASS.
  - `tools\foundation_mouse_batch_playtest.ps1`: PASS, strict mode, 2/2
    playable-loop passes, 2/2 R100 passes, 2/2 victories, zero true failures.
- Focused acceptance probe:
  - `scripts/tests/tutorial_talk_target_nonoverlap_check.gd`: PASS for pull-tab
    Buy/collect, collection tray, blackjack chips, Pal-only freezes, continuing
    environment presentation, frozen game/Peek simulation time, Heat
    intervention, and dealer-dialogue priority.
- Worktree isolation: the systems/UI gates were repeated in a detached clean
  worktree so unrelated in-progress world-map changes remained untouched and
  unstaged.
