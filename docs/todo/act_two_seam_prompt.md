# Agent Prompt — Act 2 Seam: Cross-Act Contract, Save Marker, Victory Hook (parked T8.1)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). This promotes the parked Act-1 board task T8.1
(docs/plans/act_one_feature_complete_task_board.md:1825). It is a **seam,
not content**: define what carries from Act 1 into a future Act 2, stamp
saves with an act marker, and replace the victory screen's shrug with a
deliberate hook. Small task, disproportionate polish.

## The embarrassment being fixed

`scripts/ui/foundation_main.gd:8011` hardcodes
`"The next act is not implemented yet."` into every victory summary
(exposed as `next_act_line`, :8068; asserted by
tools/foundation_visual_qa.gd:854). A content release whose victory screen
shrugs is the wrong look.

## Deliverables

### 1. Design doc: `docs/plans/act_two_seam.md`

Short and decisive. Read `docs/plans/grand_casino_endgame_design.md`,
run_state.gd victory routes and to_dict/from_dict, save_service.gd, and
ProfileInventory first. Define:

- **Carries across acts:** victory route (players-card cashout vs showdown
  — the two routes MUST produce distinct payloads), final bankroll band
  (band, not exact value — define 4–5 bands), key story flags (the
  `story_flags` dict if the dialogue system has landed; otherwise reserve
  the key with an empty default), and profile lifetime stats (already
  persisted separately).
- **Resets:** everything else — runs stay self-contained.
- **Where it lives:** the cross-act payload is recorded into the profile
  file (one `act_seam` section) at victory, versioned like the rest.

### 2. Save-schema act marker

- RunState serialization gains `act: 1` with a migration default: saves
  without the marker load as act 1 (prove with the existing 0.3.0 save
  fixture pattern — see scripts/tests/fixtures/run_state_0_3_0_save.json
  and SB.3's compatibility test for how old-save coverage is done).
- SaveService/profile files gain the same marker where relevant.

### 3. Victory-screen hook

- Replace the "not implemented yet" line with a deliberate, diegetic
  "to be continued" beat, distinct per victory route (e.g. the clean
  cashout hints at bigger rooms; the showdown route hints at consequences).
  Keep it to 1–2 lines of copy in the game's terse voice; this is a hook,
  not a trailer. No prestige/purchase teaser: ui_scene_compile_check.gd
  (:943-944, :1588, :4069) actively forbids exposing prestige hooks while
  prestige data is empty — respect those assertions; if your new copy trips
  them, the copy is wrong, not the test.
- Update tools/foundation_visual_qa.gd:854, which currently REQUIRES the
  "not implemented" text — flip that assertion to require the new hook per
  route instead.

## Hard constraints

1. No Act 2 content, no prestige data, no meta-currency.
2. Old saves (no marker) and old profiles load with defaults; new fields
   normalize; SB.3-style idempotence for everything added.
3. Both victory routes write the payload; every failure route writes
   nothing to `act_seam`.
4. Coverage: (a) victory writes the cross-act payload and the two routes
   differ, (b) markerless save loads as act 1, (c) profile without
   `act_seam` normalizes, (d) visual-QA asserts the per-route hook lines.
5. Match house style: tabs, typed GDScript, sparse constraint comments.

## Verification gates (run at the end)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. `tools\check_godot.ps1 -RequireGodot -FoundationSuite systems` and
   `-FoundationSuite ui`.
3. `tools\foundation_visual_qa.ps1 -RequireGodot` (the flipped victory
   assertion must pass).
4. Move this prompt to docs/todone/ with an execution record per RULES;
   update QUEUE.md. Commit locally; do NOT push.
