# rw06_1 — Fixed, modular room slots (replaces runtime placement solving)

Status: TODO. Self-contained. Launch with this file only. Timebox: 3 days.
Depends on rw06_0 being DONE (finished fixes are on `main`).

## Goal

Rooms stop overlapping, scattering and colliding because scenario objects no
longer search for space at runtime. Each of the 21 production map records,
covering 18 room archetypes including their subrooms, gets a fixed set of
authored **stage slots**. Scenario objects bind to those slots in a
deterministic order. An object that can't get a slot doesn't appear in the room,
and its actions appear in a **room action list** instead. Adding a slot later
must be a single JSON edit that the validator covers automatically.

When this row is done, the `Contract` suite is fully green.

## Owner decisions (binding, do not relitigate)

- Fixed slots per room, plus an overflow action list. No free-form or random
  scattering.
- Placement must be semantic. The owner rejected the earlier spawn-slot pilot
  because it put things in floor rows. So:
  - people stand in walk areas or behind counters;
  - surface items sit on counters, shelves or coolers;
  - wall-mounted objects are on walls;
  - exits and doorways are on room edges.
- Modularity: a slot is data (id, position, footprint class, hit rect, label
  anchor, facing). No slot is special-cased in code.
- Nothing useful from the old solver is lost. Read
  `docs/plans/postfix06_2_placement_harvest.md` on `main`. The solver code
  itself was deactivated but is preserved in `main`'s history at the SNAPSHOT
  commit named in that report; recover any piece with
  `git show SNAPSHOT:<path>`. Port every item marked KEEP or ADAPT, and record
  what you did with each one in
  `docs/plans/rw06_1_placement_harvest_disposition.md`. Items marked DROP get
  their reason recorded there and stay only in history.

## Owner questions (binding for every agent)

All owner decisions, including the hard gates, go through
`D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`. Always use that absolute path (the primary checkout copy). Follow
its protocol:

- append a short, precise question with options and a recommendation;
- mark your work `WAITING Q-NNN`;
- keep working on anything that doesn't depend on the answer.

Read the file at the start of every session. Pick up any ANSWERED entry whose
`Resume` is yours, even if another agent asked it. Never talk to the owner any
other way, and never stall waiting.

## Read before editing

- `data/environments/placement_surfaces.json`: it already has
  `object_slot_positions`, `scenario_object_slot_positions` and
  `class_overrides` per map. Build on these; do not start a parallel schema.
- `data/environments/archetypes.json`: `layout`, `object_fixtures`,
  `semantic_zones` and `semantic_anchors`.
- `data/environments/scenario_sequences/*.json`: the 55 scenarios and the objects
  they author.
- `scripts/core/scenario_layout_resolver.gd`,
  `scripts/core/environment_instance.gd`, `scripts/ui/pixel_scene_canvas.gd`:
  the current production route.
- The UIENV rows in `postfix06_2_post_fix_remediation_ledger.md` (in
  `docs/todone/` after rw06_0; `docs/todo/` before that): the
  exact failing seeds. Every one of them becomes a regression fixture.
- `tools/environment_layout_screenshots.gd` and `tools/fix06_31_contact_sheets.ps1`:
  existing capture tools.

## Design to implement

1. **Schema.** Add per-map `stage_slots` (and `exit_slots` if exits aren't
   already fixed). Each slot has: `id`, `pos`, `footprint_class` (from
   `class_overrides` classes), `hit_rect`, `label_anchor`, `facing` and
   `priority`. Base room objects keep their existing slot positions. Stage slots
   must be disjoint from base slots by construction.
2. **Binding.** For each object a scenario phase shows, pick the free compatible
   slot. Order: authored preferred slot, then slot priority, then id. No RNG is
   needed. If RNG is ever needed, it must be seeded from run RNG at the action
   boundary. Binding persists through save, reload and revisit, and a revisit
   produces the identical layout.
3. **Overflow.** If no compatible slot is free, the object is not drawn, and its
   actions go into a room action list:
   - a compact, accessible list in the room UI;
   - it uses `scripts/ui/modal_focus_scope.gd` conventions and 44-pixel targets;
   - it works with keyboard, controller and touch;
   - it respects hidden state (never list hidden-only actions).

   Overflow should be rare. Tune slot counts per map so the common scenarios fit.
   The same rule covers **generated base inventory** (games, items, services,
   lenders, travel): every generated base object gets a base slot or an
   overflow entry, so generated inventory is never silently missing.
3b. **Actor routes.** Scenario actors that move walk only between slots, along
   authored walk lanes, and end on distinct slots. Route endpoints can't
   collide by construction. The static validator checks this.
4. **Remove runtime search.** Remove repack, displacement and exhaustive search
   from the production route. Delete that code only after its harvest
   disposition is recorded. The SNAPSHOT commit keeps the history.
5. **Static validator** (the replacement for 415-composition runtime search):
   - Per map, in both normal and expanded (small-screen) layouts, no two slots'
     hit rects or labels overlap, including base slots.
   - Every slot sits inside its semantic zone.
   - Exits are reachable along the walk lane.
   - Per scenario × legal host map, every authored object gets a slot or an
     overflow entry, and every action is reachable.

   It runs in the `Contract` suite in seconds.

## Tests that encode the superseded solver

Some existing Contract assertions test mechanics of the old solver (repack,
displacement, search order, exact coordinates it produced). You may replace
them, but only with slot-system tests that protect the **same player-facing
guarantees**:

- no hit or label overlap in normal and expanded layouts;
- actions reachable, and focus activation works;
- safe exits reachable;
- offered destinations installed;
- physical support is semantic (things sit on counters, walls, floors correctly);
- no hidden-state leaks;
- deterministic across save, reload and revisit.

Record every replaced or removed assertion, and the guarantee that now covers
it, in `docs/plans/rw06_1_placement_harvest_disposition.md`. Dropping a
guarantee is weakening a test and is forbidden.

## Early owner look (day 2, non-blocking)

As soon as 3 representative rooms work, ask the owner for a quick yes or no in
`rw06_owner_questions.md`, with the contact sheet path. Use
`corner_store`, one bar and the busiest Grand Casino room, each with its busiest
scenario, in normal and expanded layouts. Keep working on other rooms while
waiting, and apply the owner's feedback to all rooms. The owner rejected the
last placement attempt only after it was finished; this check exists so that
can't happen again.

## File ownership (rw06_2 runs at the same time)

- You own: the three files above, the placement data JSONs, the environment
  tests and tools, and the new action-list UI.
- Do not edit game modules or ending, Crew or economy logic.
- If `foundation_main.gd` needs changes, keep them to a narrow hook and rebase
  often.

## Acceptance

- `tools/validate_project.ps1` passes.
- `tools/check_godot.ps1 -Suite Smoke -RequireGodot` passes.
- `tools/check_godot.ps1 -Suite Contract -RequireGodot`: **zero failing shards**.
- Static slot validator green on all 21 production map records × both layouts,
  with all 18 room archetypes represented, and on 55 scenarios × legal hosts.
- Every historical UIENV exact seed from the ledger is a passing regression case.
- `tools/environment_generation_audit.ps1 -Runs 100 -Visits 6 -RequireGodot`
  is green.
- Capture report enumerating all 21 production map records/subrooms, plus a
  contact sheet of all 18 room archetypes (busiest scenario each, normal and
  expanded layouts), saved under `.tmp/rw06_1/contact_sheet/`. Link it on the
  scoreboard for owner review.
- Idle-liveness and performance smoke unchanged or better. Never weaken a
  budget or liveness floor.

## Finish

- Commit to a branch in a worktree, verify, fast-forward `main`, and push.
  Never force-push. Then delete the branch (local and origin) and remove the
  worktree. The row is not DONE while its branch exists.
- Report the Contract count, P1 count and contact sheet link to the
  orchestrator, who updates the scoreboard.
- Put any ideas you didn't build (more slots, per-scenario custom layouts,
  animations, visual identity) in `docs/plans/0.6.1_backlog.md` under "Rooms".
