# Agent Prompt - fixsweep06_1: Extended Playtest Bug Sweep (BTH-001 ... BTH-058)

Status: DONE. Self-contained. This file is the only coordination document for
this work; there is no board, queue, claim or archive ceremony to follow.

## How to launch this row

Paste the block below into the worker agent, from a shell whose working
directory is `D:\Projects\Beat-The-House`:

> Read `docs/todo/fixsweep06_1_extended_playtest_bug_sweep_prompt.md` in full
> and execute it end to end: all 58 defects, BTH-001 through BTH-058, in the
> wave order it gives. Its source of truth is
> `reports/playtest_2026-09-20/Beat_the_House_Extended_Playtest_Bug_Report_2026-09-20.md`
> (the full extended playtest report; the `.docx` beside it is the same
> content), backed by the fifteen specialist wave reports in that same
> directory - `ui_environment.md`, `gameplay_progression.md`,
> `games_performance.md`, `persistence_chaos.md`, `accessibility_input.md`,
> `packaged_platform.md`, `extended_accessibility_input.md`,
> `extended_persistence_chaos.md`, `extended_packaged_platform.md`,
> `extended_game_rules_fuzz.md`, `extended_progression_economy.md`,
> `extended_audio_feedback.md`, `extended_lifecycle_recovery.md`,
> `extended_localization_text.md`, `extended_performance_soak.md`. Read the
> report's detailed finding before each fix; the prompt's per-defect anchors are
> a summary of it, not a replacement. Obey section 1 rules exactly: never commit
> or push, never revert the pre-existing uncommitted worktree changes, treat
> `reports/` and `.tmp/` as read-only evidence, one headless Godot at a time,
> and every fix ships a regression that fails before it and passes after. Do the
> section 4 baseline capture before your first edit. Update the section 7 ledger
> in this file as you go and write the section 8 final report into it when done.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6, GDScript, Windows).

Your assignment is to **fix every one of the 58 confirmed defects** in the
2026-09-20 extended playtest report, land a durable regression for each, and
leave the tree green against the project's own gates. The report author fixed
nothing: every defect below is still live in source.

Authoritative evidence, already in the repository:

- `reports/playtest_2026-09-20/Beat_the_House_Extended_Playtest_Bug_Report_2026-09-20.md`
  (full report; mechanical text extraction of the `.docx` beside it)
- `reports/playtest_2026-09-20/*.md` (the fifteen specialist wave reports with
  the deeper per-defect evidence)

Every defect summary below carries its own root-cause anchor, so you can work
straight from this file; open the report when you need the full reproduction,
measured geometry or evidence tables.

Line numbers in this prompt were taken at `HEAD 4384378a` and were spot-checked
on 2026-09-20. They will drift as you edit. Always confirm by reading the
surrounding code, never by trusting the number.

---

## 1. Rules (binding, inlined, no external documents)

1. **Never run `git commit` or `git push`.** Not once, not "just to be safe",
   not at the end. Leave every change in the working tree and report what you
   changed. Only an explicit instruction from the owner during this run may
   override this.
2. **The worktree already carries pre-existing uncommitted owner changes.**
   At handoff they were: `data/crew/world06_6_heist_sequences.json`,
   `data/environments/placement_surfaces.json`, `scripts/core/run_generator.gd`,
   `scripts/games/baccarat.gd`,
   `scripts/tests/fixtures/crew06_5_ignored_run_baseline.json`,
   `scripts/tests/foundation/check_core_content.gd`,
   `scripts/tests/foundation/check_lenders_release_saves.gd`,
   `scripts/tests/foundation/crew_plays_contract.gd`,
   `scripts/tests/foundation/crew_recruitment_contract.gd`,
   `scripts/tests/foundation/env06_8_environment_readability_contract.gd`,
   `scripts/tests/foundation/scenario_backlog_contract.gd`,
   `scripts/ui/foundation_main.gd`,
   `tools/scenario_room_multiseed_finalization.gd`,
   `tools/archive/world06_6/world06_6_sign_packages.gd`, plus untracked
   `scripts/tests/foundation/table_game_authority_test_driver.gd` and
   `reports/playtest_2026-09-20/`.
   Do not revert, stash, checkout-over or "clean up" any of them. Build on top.
3. **Evidence is read-only.** Never edit, move or delete anything under
   `reports/` or `.tmp/`. The report's `.tmp/playtest_extended/...` paths were
   produced on the QA machine and may not exist here; do not treat their absence
   as a reason to skip a fix. Every root cause below is provable from source.
4. **One headless Godot at a time.** `tools/check_godot.ps1` stops early if
   another Godot process is running for this project. Long suites need an outer
   timeout longer than the harness timeout (the full suite reserves 1800 s).
   Killing the parent PowerShell early can strand Godot children writing
   `user://` logs and has caused native access-violation dialogs on later runs.
5. **Every fix ships with a regression that fails before it and passes after.**
   Write the test first where practical, confirm it reproduces the defect, then
   fix. A fix with no test is not done.
6. **Do not hand the owner homework.** If you hit a decision that section 3
   does not already settle, choose the safest reversible option, implement it,
   finish the work, and record the call and the alternatives in the ledger.
   Never end with "the owner should decide X" while leaving code unfixed.
7. **Do not widen scope.** No refactors, renames, formatting sweeps or drive-by
   improvements outside a defect's fix. No version bump, no tagging, no
   packaging/upload, no publishing.
8. **Report honestly.** If a defect resists a clean fix, say so with the
   evidence, land the best correct partial fix behind a test that documents the
   remaining gap, and put it in the ledger as `PARTIAL` with specifics. Never
   mark a row `DONE` that a gate does not prove.

---

## 2. Read before you touch code

- `README.md` sections "Running The Project" and "Validation" (gate commands,
  concurrency rule, current known-red state).
- `docs/current_game_state.md`.
- `docs/todo/README_0_6_board.md`, "Current owner-directed sequence" - the
  placement redesign context that Wave 2 must respect.
- The report file named above, at least the Consolidated bug index and the
  detailed section for each wave you are about to start.

**Known-red baseline, important:** the broad Contract suite is *already* red at
room/scenario composition (label/hit-region overlap, colliding route endpoints,
stale placement-dependent expectations). Those reds are largely the same defects
as Wave 2. You must capture the baseline in section 4 before changing anything,
so you can prove which reds you cleared and that you introduced none.

---

## 3. Binding decisions (already made - do not relitigate)

- **D1 - Placement is fixed at both levels.** Wave 2 repairs the placement
  *policy* (silent acceptance of collisions, developer-placement audit
  suppression) *and* the checked-in coordinates that currently collide. Do not
  defer the data fixes to the pending placement redesign; the policy gates you
  add are exactly what that redesign needs to inherit.
- **D2 - Collision severity.** After Wave 2: route-vs-route and
  route-vs-actionable-control intersections are fatal content errors. Other
  direct interaction-rect intersections are placement errors that fail the
  audit. Footprint/spacing-only warnings (the 8 px margin) stay non-fatal
  warnings - the report explicitly excluded fourteen of those as non-defects.
- **D3 - Version identity.** Do **not** change `project.godot`
  `config/version="0.5.1"`; the retained stamp is intentional until the release
  row runs. Instead, give non-release exports a distinct visible and embedded
  development identity (`0.6.0-dev+<short-commit>`) plus a machine-readable
  build manifest, and make the player-visible menu string and telemetry read
  that identity. Release stamping stays the release row's job.
- **D4 - Nothing under `builds/` gets deleted.** Stale/loose artifacts are
  *moved* into `builds/quarantine/` (reversible). Packaging tooling gains the
  guard that prevents the situation recurring.
- **D5 - Background play pauses.** BTH-052 is fixed by pausing player-affecting
  simulation on OS focus loss/minimize. No new opt-in setting, no consent
  prompt.
- **D6 - 0 % volume is a hard mute** on native and Web, restoring the prior dB
  when raised above zero.
- **D7 - The clipped High-Limit title is fixed as data, not art.** Set that room
  to `title_mode: "text"` in `data/ui/environment_ui.json` and add the asset
  bounds audit. Do not attempt to regenerate the raster.
- **D8 - Money transactions use one shared helper.** BTH-043 is fixed by a
  single transaction helper shared by item offers and paid hooks
  (snapshot -> price -> boundary -> apply, full restore on any failure), not by
  copy-pasting an ordering fix into two call sites. The existing Jazz
  `show_drummer_glasses` rollback path must keep its current behavior.
- **D9 - Audio caches get a byte-budgeted LRU.** Default budget 64 MiB per
  cache domain, active/pending keys protected, run-scoped caches cleared at the
  return-to-menu / new-run boundary.
- **D10 - Text fixes are structural.** Wave 7 replaces baked English with
  structured keys/parameters resolved at presentation time; it does not
  hand-patch individual strings and leave the generator intact.

---

## 4. Baseline capture (do this before any edit)

Run and archive, under `.tmp/fixsweep06_1/baseline/`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Contract -FoundationSuite contracts
```

Record in the ledger: every failing stage and assertion, verbatim. This is your
"was already red" list. At the end you must show that list shrank and that no
new failure appeared.

---

## 5. The waves

Work the waves in order. Each wave ends with its own gate run and a ledger
update. Within a wave, defects may be fixed in any order.

Each entry reads: **symptom** -> **verified root cause** -> **required fix** ->
**required regression**.

---

### Wave 1 - Transaction and state integrity (5 defects)

These are the highest-risk defects in the report: they corrupt persisted state,
duplicate history, grant unpaid goods, or soft-lock a live run.

**BTH-043 / XPE-01 - Debt boundary invalidates affordability but the purchase
still commits (High).**
Symptom: with a debt clock at one action and `forced_repayment`, buying a $12
item with $14 returns `ok: true`; the boundary takes $4 first, the stale $12
delta then applies, bankroll clamps to $0, the run ends `failed /
bankroll_zero`, and the player still receives the item. Same for the $14
`punchline_cover_charge` service with $16. 4/4 affected cases, matched no-debt
controls pass 4/4, deterministic across two seeds.
Root cause: `RunActionService.buy_item_offer()` checks affordability at
`scripts/core/run_action_service.gd:237`, builds the result at :248, advances
the environment at :249, and applies at :252. `use_hook()` builds at :981,
advances at :1001, applies at :1005. The boundary reaches
`_advance_global_boundary_finish()` / `_advance_debt_clocks()`
(`scripts/core/run_state.gd:14111-14113`); forced repayment deducts a third of
current bankroll (`run_state.gd:14630-14648`). `GameModule.apply_result()` then
applies the stale cash delta (`scripts/core/game_module.gd:871-873`) without
re-checking affordability and keeps granting inventory/flags at :952-964.
Fix (per D8): add one transaction helper used by both paths - snapshot run and
environment, reserve/apply the price, advance the boundary, re-validate, apply
the result, and restore everything on any failure, returning a clear
cancellation with offers, inventory, flags, Heat and story untouched.
Additionally stop `apply_result()` from applying non-cash rewards after a cash
delta has transitioned the run to failed, unless the result declares terminal
settlement semantics. Preserve the Jazz `show_drummer_glasses` behavior at
`run_action_service.gd:985-1000`.
Regression: matrix over bankroll below / equal / above `price + forced_payment`
with debt clocks at 0, 1 and 2 actions, for both an item offer and a paid
service, asserting API status, final bankroll, run status, debt balance, offer
consumption, inventory, flags, Heat and story log together. Include the Jazz
special case.

**BTH-042 / EXT-GAME-001 - Rejected Blackjack transaction leaks a completed
story record; retry duplicates it (Medium).**
Symptom: with the environment-turn boundary forced to reject, the sealed host
returns `ok=false, blackjack_host_committed=false,
error_code=forced_turn_rejection`, yet `story_log` grew from 0 to 1 with the
full completed result; the normal `blackjack_retry_pending` replay then makes
it 2 where a clean single delivery gives 1. 3/3. Bankroll, chips, RNG and the
rest of the serialized run match the clean control - only history is corrupt.
Root cause: `GameModule.apply_result(proposed_candidate, ...)` runs at
`scripts/ui/foundation_main.gd:2579`, *before*
`_sealed_action_host_advance_environment_turn(proposed_candidate)`. The story
append escapes the candidate/alias boundary via
`scripts/core/game_module.gd:981` -> `RunState.log_story()`
(`scripts/core/run_state.gd:13504-13508`), and since publication never happens
there is no compensating removal.
Fix: make the transaction candidate own every collection any `apply_result()`
path can mutate - story, profile, crew, reputation histories - before
`apply_result()` is called, and stage result-driven history/analytics writes as
deltas published only after the environment-turn boundary succeeds.
Regression: snapshot the entire live `RunState` immediately before a forced
boundary rejection and assert exact equality afterwards except the permitted
pending-delivery ledger; extend the retry contract to compare the complete
final save snapshot and assert exactly one story record.

**BTH-039 / PERSIST-EXT-01 - Oversized save reports success, installs an
unloadable primary, loses or rolls back progress (High).**
Symptom: 6/6 across three variants. Empty slot: `save_run` returns OK, `has_run`
is true, a fresh service reports `primary_exists=true, primary_corrupt=true,
primary_loadable=false`, no loadable backup, `load_run` null. Sync replacement:
the good generation rotates to backup, the invalid one installs as primary, and
Continue silently loads the older bankroll. Async replacement via
`begin_save_run`/`wait_for_async_save`: identical.
Root cause: `RunSaveCodec.pack_for_storage` returns `{}` on empty input,
oversize past `MAX_STORAGE_BYTES`, or compression failure
(`scripts/core/run_save_codec.gd:104-110`). The sync payload builder inserts
that `{}` unchecked (`scripts/core/save_service.gd:328-336`), the async worker
does the same (:157-166), both judge success by write/rename only (:42-86,
:170-202), and rename success fingerprints the invalid primary as trusted
(:30-38, :84-86, :138-142). The reader rejects it later (:340-371) - after
success was reported and both generations were mutated. `FoundationMain` then
advances autosave bookkeeping and shows success
(`scripts/ui/foundation_main.gd:6743-6757`).
Fix: make `pack_for_storage` return a structured success/error result with an
oversized/compression failure code; stop both save paths before opening a temp
file or rotating any generation; validate the written temp payload with the same
envelope/decompress/hash checks used by `_worker_payload_loadable` before
rotating; only fingerprint after validating the installed generation; propagate
the error so autosave bookkeeping is unchanged and the UI says the autosave
failed.
Regression: empty-slot oversized sync save returns non-OK with both generations
absent; existing-slot oversized sync and async saves return non-OK with primary
and backup preserved byte-for-byte; compression-failure injection follows the
same rules; any save reported OK passes `slot_status.primary_loadable` in a
fresh service; a failed save adds no trusted fingerprint.

**BTH-044 / EXT-PERF-001 - Dynamic-room semantic digest drift blocks enabled
travel and cascades into game-action rejection (High).**
Symptom: across three 360-minute soaks, 382 travel attempts selected a presented
destination and did not move. All 122 instrumented failures were at the
production confirmation boundary with the target in `travel_enabled_node_ids`,
`enabled: true`, empty `disabled_reason`, and
`confirm_world_map_travel()` returning `{ok: false}` with "scenario semantic
inventory version or digest changed; explicit migration is required". Afterwards
the same room rejected Coin Pusher `drop_quarter` and Pull Tabs `buy_tab` with
"Dynamic room sequence semantic records are not finalized." Save/load does not
repair it.
Root cause: `scripts/core/run_state.gd` treats scenario base semantics as an
immutable pre-sequence seal, but `_scenario_finalize_trusted_base_semantics()`
re-derives it on refresh: at :2646 it calls `_scenario_base_producer_context()`
again instead of loading the context stored with the seal, and that function
(:3171-3183) derives `numbers_venue_ids`, `numbers_silas_present` and
`delivery_handoff_node_id` from *current* run state. The regenerated digest is
compared with the stored proof at :2695-2707, a legitimate live change fails the
comparison, and `_invalidate_scenario_semantic_proof()` (:3186-3194) then erases
readiness, inventory, base interactions/actors/producer context, layout
authority and the render snapshot. Later travel and game preflights correctly
fail closed on the proof that refresh itself destroyed.
Fix: on refresh, read and validate the persisted
`scenario_base_producer_context` associated with the existing inventory instead
of regenerating it; bind the exact producer-context fields and digest into
durable provenance at initial installation and rebuild from that immutable
record after load; exclude genuinely live availability (Numbers presence,
delivery handoff) from the immutable identity digest and authorize it through a
separately versioned live projection; and make a refresh mismatch retain the
last validated proof until a valid migration/rebuild succeeds instead of erasing
the only usable proof. As defense in depth, do not present a route as enabled
when confirm-time semantic preflight cannot succeed.
Regression: install a proof, mutate each producer-context input individually,
refresh, and assert the original identity digest stays valid; repeat across
save/load and environment revisit; with an active scenario, change Numbers venue
availability, Silas presence and delivery handoff state and then confirm every
enabled route; after any failed travel preflight assert
`scenario_semantic_ready`, the prior inventory and authorized game actions are
intact.

**BTH-045 / EXT-PERF-002 - Coin Pusher compact rollback can reject its own token
after a failed turn boundary (Medium).**
Symptom: soaks logged four and six occurrences of "Game module failed to restore
its declared compact host-action rollback token", always after a module returned
an accepted result and `_advance_environment_turns_checked()` rejected the turn
(`foundation_main.gd:_resolve_game_action()` line 12365).
Root cause: `host_action_rollback_snapshot()` stores a direct reference to the
live machine in `snapshot["machine"]`; `restore_host_action_rollback()` calls
`_ensure_live_machine()` again and requires `is_same(...)`. If resolution or the
rejected path rebinds the live-machine entry, the identity guard returns false
before any state is restored, and the host skipped the full rollback copy
because a compact snapshot was declared.
Fix: store the live-machine cache key plus sufficient immutable rollback data
and restore into the currently registered machine rather than requiring
reference identity; expose a stable generation/token from
`_ensure_live_machine()` and validate semantic identity plus generation; and if
compact restore still returns false, execute the full run/environment fallback
captured before resolution. Include game, action, cache key and identity
generation in the failure payload.
Regression: force `_advance_environment_turns_checked()` to reject after a Coin
Pusher quarter resolves and compare the complete machine/session/durable
projection byte-for-byte with the pre-action state; repeat after live-machine
cache replacement, environment revisit and save/load; assert a failed compact
restore automatically falls back to a complete rollback.

**Wave 1 gate:** Smoke plus the focused game/persistence suites, plus every new
regression above.

---

### Wave 2 - Placement authority and audit truth (22 defects)

Read D1 and D2 first. **Fix BTH-021 before anything else in this wave** - until
the audit stops lying, you cannot verify any other fix here.

**BTH-021 / UIE-021 - Scenario layout audit falsely reports a clean room
(Critical).**
Symptom: the captured Bar / Dead Tuesday state reports
`room_canvas.object_layout.overlap_count=9` while
`scenario_layout_audit.normal_overlap_count=0`,
`small_screen_overlap_count=0`, `collision_adjustment_count=0`, `valid=true`.
100 %.
Root cause: `_overlap_count` returns zero for the entire room whenever any
developer placement exists
(`scripts/ui/scenario_layout_resolver.gd:1620-1643`); related validation loops
also skip developer-placed targets and rooms (:824-847). Checked-in project
overrides therefore disable the safety gate in ordinary shipped content, not
only in an editor preview.
Fix: distinguish temporary user freeform edits from shipped project data; always
compute and report overlaps regardless of placement origin; make route and
actionable-control collisions non-waivable (D2).
Regression: a contract that loads the Bar / Dead Tuesday state, asserts the
audit's overlap counts equal the canvas layout's, and asserts a seeded
route-vs-route collision is reported as fatal even in developer-placement mode.

**Critical route/scenario authority - fix next:**

- **BTH-010 / UIE-010 (Critical)** Grand Casino Back Room route overlaps
  Blackjack, 128 px². Authored slots `[0,176]` and `[120,176]`
  (`data/environments/placement_surfaces.json:385-387`); the resolver records no
  placement error. Fix: reserve a route rail, move Blackjack, and make
  route/game intersection fatal in content validation.
- **BTH-012 / UIE-012 (Critical)** Grand Casino Cage: `travel:grand_casino` and
  `travel:leave` both at `[824,350]`, 1,044 px²
  (`data/environments/archetypes.json:4378-4389`). Fix: give each route a unique
  slot or render one route selector; remove the redundant Leave in this subroom.
- **BTH-013 / UIE-013 (Critical)** High-Limit: `casino_door_spots[1]` and
  `travel_spots[0]` both at `[808,350]`, 5,824 px²
  (`archetypes.json:3978-3993`). Same fix shape as BTH-012.
- **BTH-017 / UIE-017 (Critical)** Bar Dead Tuesday: `event:rowdy_regular` at
  `[77,178]` vs Bar Dice moved to `[65,146]` by a checked-in developer override,
  3,920 px². Fix: return Bar Dice to a machine zone, reserve its footprint
  against base events, and reject intersecting project overrides.
- **BTH-019 / UIE-019 (Critical)** Pull Tabs vs `bar_dead_tuesday_task_0` at
  `[316,188]`, 2,916 px². Fix: dedicated wall slot for the task and enforced
  scenario/base interaction disjointness.
- **BTH-020 / UIE-020 (Critical)** `travel:leave` vs
  `bar_dead_tuesday_safe_exit`, 94 px²; both target the right exit rail and the
  resolver skips the ambiguous route check because the room is developer-placed.
  Fix: one exit authority, and route-vs-route stays fatal in developer-placement
  mode.
- **BTH-018 / UIE-018 (High)** Coin Pusher vs
  `bar_dead_tuesday_patron_zone:[300,266]`, 1,152 px²
  (`placement_surfaces.json:42`). Fix: scenario fallback slot, reserve all
  current base hitboxes during scenario layout, never suppress scenario/base
  validation for project overrides.

**Placement-policy defects - two shared root causes, fix the policy once and the
data per room:**

*Exact placement bypass* (`environment_instance.gd:699-715` - manual/category
overrides are accepted as exact and skip collision recovery; category overrides
also silently supersede object-specific coordinates):

- **BTH-002 (High)** Corner Store `item:odds_notebook` vs `item:trunk`, 3,360
  px²; `item_spots:1` at `[189,144]`
  (`data/environments/developer_placement_overrides.json:87`).
- **BTH-003 (High)** Corner Store `event:late_shift_discount` vs
  `shopkeeper:merchant`, 2,304 px² (overrides :75, :113).
- **BTH-004 (Medium)** Late Shift Discount vs `service:cashier_tip`, 228 px²;
  the exact event override is accepted without testing later generated service
  authority (`environment_instance.gd:703-715`).
- **BTH-005 (High)** merchant vs `service:cashier_tip`, 525 px²; the merchant's
  exact override (:113) reserves nothing against the generated service.
- **BTH-006 (High)** Gas Station `game:pull_tabs` vs `game:scratch_tickets`,
  994 px²; `[430,126]` and `[526,127]` are closer than two 110x72 controls allow
  (overrides :161-168). Preserve the 44 px minimum target when separating.
- **BTH-007 (High)** Gas Station `service:house_drink` vs `numbers:book`, 378
  px²; `[170,186]` and `[71,183]` (overrides :173-180).
- **BTH-008 (Medium)** Gas Station `event:parking_lot_tip` vs `event:side_door`,
  63 px²; successive event-slot category overrides `[693,344]` and `[792,345]`
  (:127-134) where category overrides take precedence at
  `environment_instance.gd:699-705`. Treat doors as reserved and stop category
  overrides silently superseding a safer object-specific coordinate.
- **BTH-014 (High)** House `home_storage:place` vs `home_container:trunk_01`,
  810 px²; `[320,293]` and `[231,297]` (overrides :219-230).
- **BTH-016 (High)** Motel `event:parking_lot_tip` vs `lender:motel_friend`,
  936 px²; `[33,345]` and `[115,357]` (overrides :235-254).

*Exhausted placement accepted* (`environment_instance.gd:715-736` - when no
candidate fits, the colliding rectangle is stored with no placement error):

- **BTH-001 (High)** Bar `game_hook:pull_tabs:ticket_redeemer` vs `game:slot`,
  2,436 px²; dense authored Bar slots (`placement_surfaces.json:41`).
- **BTH-009 (Medium)** Grand Casino `game:slot` vs `game:slot:2`, 144 px²;
  authored coordinates 126 px apart (`placement_surfaces.json:381-383`) while
  support correction yields 110 px controls plus spacing.
- **BTH-011 (High)** Grand Casino `game:craps` vs ticket redeemer, 170 px²
  (`placement_surfaces.json:385-386`).
- **BTH-015 (Medium)** Jazz Club `service:jazz_cello_round` vs ticket redeemer,
  252 px² (`placement_surfaces.json:131-132`).

Required policy fixes for this group, applied once:
1. Promotion of a checked-in developer/category override is validated against
   direct-hit rectangles and **fails** on intersection instead of being accepted
   as exact.
2. Collision packing reruns after *all* manual and generated entries are
   assembled, not only over the manual set.
3. An exhausted placement search raises a placement error; it never stores a
   colliding rectangle as valid.
4. Category overrides never silently supersede a safer object-specific
   coordinate; doors and route rails are reserved footprints.

Then move the specific colliding coordinates above so every affected room passes
the now-honest audit. Prefer moving the non-route, non-door object; keep every
interactive control at or above the 44 px minimum target.

**BTH-026 / UIE-025 (Low)** Corner Store resolved label still covers another
actionable object: `resolved_object_overlap_count=1`, the
`event:late_shift_discount` label intersects `service:cashier_tip` by 15 px².
The label resolver clears label-label collisions but accepts one label-object
collision over the crowded manual layout. Fix: resolve object positions first
(BTH-003/004/005 above largely do this), then permit an extra label row or hide
labels until focus when density exceeds the layout budget, and assert
`resolved_object_overlap_count == 0`.

**Wave 2 gate:** the Contract suite with `-FoundationSuite contracts`, plus a
fresh 18-archetype layout capture. Every room must report zero direct
interaction-rect intersections and zero route ambiguity. Spacing-only warnings
may remain (D2). Compare against the section 4 baseline and show the reds you
cleared.

---

### Wave 3 - Game-surface layout (2 defects)

**BTH-022 / UIE-022-A - Bar Dice Rail Cups panels obscure the left patron rail
(High).** 2/2 production frames. First opponent panel `Rect2(68,136,164,48)`
intersects patron 0's safe region `Rect2(44,30,142,158)` by 118x48 = 5,664
design px, and the next two rows continue down the same x-range.
Root cause: `scripts/games/bar_dice.gd:70-80` hard-codes opponent row origins at
x=76 while seating the first patron at x=94; `_draw_opponent_dice_rows()` builds
164x48 panels starting eight px left of those origins (:3191-3208); patron safe
rects are independently derived as 142x158 (:3495-3500). Nothing relates the two
systems, and draw order (patrons at :552-565, then rows) makes the overlap
destructive.
Fix: move opponent rows to a dedicated rail lane that intersects no patron safe
rect, and export opponent-panel rectangles as layout metadata.

**BTH-023 / UIE-022-B - Dealer-status widgets cover Iris (High).** Iris at
`(660,70)` -> safe region `Rect2(610,16,142,158)`; the shared dealer renderer
writes `Rect2(566,92,118,9)`, `Rect2(566,116,118,6)` and `Rect2(566,130,122,22)`
(`scripts/games/table_game_visuals.gd:139-178`), 2,826 px² inside her region.
Fix: supply Bar Dice-specific status-widget bounds that fit inside the central
dealer station, or move Iris to a genuinely free right-rail position and
recompute safe rects from the final layout; make the shared dealer renderer
return its occupied rectangles.

Why the tests missed both:
`scripts/tests/foundation/check_table_games.gd:7444-7467` validates
`text_panel_rects` against `patron_safe_rects` but Rail Cups and dealer-station
rectangles are in neither collection.
Regression (covers both): export opponent-panel and dealer-station rectangles
into the tested collections and add a general pairwise collision assertion
against patron safe rects, so the failure cannot return when row count or
scaling changes.

---

### Wave 4 - Accessibility and input authority (9 defects)

**BTH-028 / A11Y-001 - World-map destinations cannot be selected by keyboard
(High).** Nodes have `focus_mode=FOCUS_NONE`, empty button text, label only in
`tooltip_text`; opening the overlay never places focus inside it.
`scripts/ui/world_map_overlay_controller.gd:717-731` (`_hit_button`), :527-554,
:557-581 (labels), `scripts/ui/foundation_main.gd:3785-3804` (open path),
:10007-10009 (Close button is a local variable, so it cannot serve as entry
focus). Fix: focusable node buttons with `accessibility_name`/visible text from
the node label, roving spatial focus between nodes, stored Close button, focus
moved into the map on open and restored on close. Regression: select and confirm
a destination using only key events.

**BTH-029 / A11Y-002 - Escape does not close Settings (Medium).** 2/2:
`visible_after_escape:true`, `back_signal_count:0`.
`scripts/ui/settings_menu.gd:178-196` handles Tab trapping only and has no
`ui_cancel` branch; `foundation_main.gd:778-784` routes only web-audio gestures
and TalkDock hotkeys; the focus-return code at `settings_menu.gd:204-219` runs
only after something else hides Settings. Fix: `ui_cancel` in SettingsMenu
emitting `back_requested` and marking the event handled, plus a central
modal-cancel router with explicit priority so Escape closes only the topmost
dismissible overlay. Regression: Escape from the main menu and from the run
menu, both asserting focus restoration.

**BTH-030 / A11Y-003 - Small-screen action targets are 34 px (High).**
`ENVIRONMENT_ACTION_HEIGHT` and `ENVIRONMENT_INLINE_ACTION_HEIGHT` are 34
(`scripts/ui/small_screen_policy.gd:14-15`) while the same file defines
`CONTROL_TOUCH_TARGET_HEIGHT=52` (:10); `pixel_scene_canvas.gd:3982-3987`
returns them and :4071-4082, :4436-4443 draw with them. Fix: both heights at
least 52 px with detail-card height/placement recomputed; if a compact visual
row must stay, keep the 34 px visual but expand each non-overlapping hit rect to
52. Regression: a layout audit enumerating every clickable rect - not only
native Buttons - under small-screen mode.

**BTH-031 / A11Y-004 - Rebuilt gameplay actions lose large-text and small-screen
sizing (High).** New card buttons come back at 13 px font / 44 px height. Apply
transforms the existing tree then rerenders (`foundation_main.gd:16259-16268`);
rerendered cards call `_add_card_button` which delegates straight to
`FoundationWidgets.add_card_button` (:19936-19937) with 44/13 defaults
(`scripts/ui/foundation_widgets.gd:37-54, 77-83`), bypassing the accessible
`_button` path (:20760-20764). 51 call sites. Fix: route dynamic action
construction through the accessibility-aware helper and apply
`_apply_accessibility_to_node` to every newly created subtree before it becomes
interactive. Regression: apply settings, rebuild an environment card and an
event popup, assert effective font and target sizes.

**BTH-032 / A11Y-005 - TalkDock attention motion runs with Reduce Motion
(Medium).** Panel starts at alpha 0.88, portrait at scale 1.04, tween created,
with `reduce_motion:true`. Every entry calls `_play_attention_animation`
(`scripts/ui/talk_dock.gd:324-343`); `set_reduce_motion` (:535-541) never
cancels/normalizes it; `_play_attention_animation` (:1307-1319) has no guard.
`scripts/ui/coach_overlay.gd:971-978` already implements the intended pattern.
Fix: early return after normalizing panel alpha and portrait scale, and kill
active attention tweens when Reduce Motion is enabled mid-animation.
Regression: two consecutive entries with Reduce Motion on, asserting no valid
tween and settled transforms.

**BTH-035 / A11Y-006 - Decision popups leak keyboard focus to obscured controls
(High).** 2/2: focus stays on the Settings button behind the popup, Escape does
nothing, Enter activates Settings *behind* the popup leaving both visible, and
`current_overlay_state_snapshot()` returns `contract_valid:false` with
`decision_popup overlaps settings_visible`. `_show_meta_popup()` never calls
`grab_focus()` or installs a trap (`foundation_main.gd:17061-17083`); the same
pattern is in triggered event popups (:4854-4904) and wager confirmation
(:13051-13077); choice buttons (:13080-13117) are never focused;
`_hide_event_choice_popup()` (:18975-19005) restores no prior focus owner.
Fix: a shared modal focus controller (store prior owner, focus the first enabled
choice, trap navigation, restore on close), `ui_cancel` routed by
topmost-overlay priority honoring each snapshot's dismissible flag and refusing
cancel for blocking decisions, and global/open-overlay actions guarded while a
decision popup owns input. Regression: keyboard and controller coverage for
every event-popup constructor, including background-button activation and
contract validity.

**BTH-036 / A11Y-007 - World map clipped at the minimum safe window (High).**
At 640x360 the panel is `x=-110, y=-90, w=860, h=540`; at 800x450 `x=-30,
y=-45`. Fixed 860x540 minimum and +/-430/+/-270 centre offsets
(`foundation_main.gd:9978-9987`), holder and map layer at 800x430 minimums
(:10018-10027), while `_safe_window_size()` explicitly permits 640 px
(`scripts/core/user_settings.gd:264-276`). Fix: clamp panel size to viewport
minus safe margins, replace fixed offsets with full-rect anchors plus a centered
responsive container, scale or scroll the 800x430 content at narrow sizes while
keeping node hit targets at the small-screen minimum, and recompute on
`NOTIFICATION_RESIZED` while open. Regression: 1280x720, 960x540, 800x450 and
the 640x360 floor.

**BTH-037 / A11Y-008 - Large-text Settings extends below the minimum safe window
(Medium).** At 640x360 with small-screen + large text + 130 % scale the Settings
rect is `x=88, y=60, w=464, h=447`, bottom at y=507 - 147 px below the frame.
Fixed 48 px top/bottom margins (`foundation_main.gd:9628-9631`), small-screen
policy changing only left/right to 72 (:20596-20603;
`small_screen_policy.gd:18`), and a 300 px minimum on the settings scroll
container (`settings_menu.gd:82`). Fix: viewport-bounded modal height with fixed
heading/action rows and only the body scrolling, responsive vertical margins,
the 300 px minimum dropped when height is smaller, and
`ensure_control_visible()` on focus changes. Regression: 640x360 at every
text/UI-scale combination, asserting Back, Restore Defaults and Apply are
visible.

**BTH-038 / A11Y-009 - Controller can navigate but cannot accept or cancel
(High).** Verified: `project.godot` has **no `[input]` section at all**, so
`ui_accept` is Enter/KP-Enter/Space and `ui_cancel` is Escape - engine defaults
with no joypad events - while directional actions do carry D-pad and stick
events. `pixel_scene_canvas.gd:803-827` activates only via `ui_accept`;
`scripts/ui/run_inventory_screen.gd:675` and
`scripts/ui/meta_item_interaction_screen.gd:288` depend on `ui_cancel`;
`scripts/ui/game_surface_canvas.gd:1056-1062` locally special-cases
`JOY_BUTTON_A`, proving the intent. Fix: add project-level joypad south/A to
`ui_accept` and east/B to `ui_cancel` (define the actions explicitly so the
keyboard events are preserved), then remove the per-surface exception or keep it
only for hold semantics with duplicate suppression. Regression: a no-keyboard
controller smoke path - start run, inspect/activate an object, enter and exit a
game, open/close inventory, acknowledge and cancel dismissible overlays,
navigate Settings.

---

### Wave 5 - Application lifecycle and pause ownership (4 defects)

**BTH-052 / LIFE-001 - Alt-tab or minimization does not suspend time-sensitive
gameplay (High).** `FoundationMain._process()` unconditionally enters the run
clock, game automation, real-time surface refresh and environment runtime
(`foundation_main.gd:689-734`); the guards at :737-746, :2836-2864, :2879-2900
know internal pause state but not OS lifecycle state; the root notification
handler handles resize and WM close only (:787-797). Fix per D5: application
focus/visibility becomes an explicit simulation pause owner gating clock,
automation, real-time game state and environment runtime, handled centrally on
focus-out/in and pause/resume, with non-gameplay maintenance such as save
completion controlled separately. Regression: focus out / minimize during a
continuous clock, autoplay and a real-time table, asserting no player-affecting
state change until focus returns.

**BTH-053 / LIFE-002 - OS focus loss can strand or later complete a stale
game-surface hold (High).** Drag and keyboard/controller hold capture store
persistent state and emit begin
(`scripts/ui/game_surface_canvas.gd:1141-1149, 1174-1208`); the safe recovery
method that emits cancel and clears capture (:1219-1231) is called only for
Control `NOTIFICATION_FOCUS_EXIT` and visibility loss (:1234-1238), and OS
deactivation may preserve the GUI focus owner. The existing test injects only
`Control.NOTIFICATION_FOCUS_EXIT`
(`scripts/tests/foundation/check_coin_pusher.gd:457-461`). Fix: route root
application focus-out, application pause and window hide/minimize to
`_cancel_captured_surface_pointer()`, make cancellation idempotent, clear any
coalesced move before processing focus-in input, and reject orphan
release/motion events until a fresh press begins. Regression: begin each input
modality, deliver application focus-out without a release, assert exactly one
cancel and empty capture state.

**BTH-047 / EXT-AUDIO-002 - Run Menu and in-run Settings do not pause the
game-surface clock or timed audio (Medium).** 4/4 entries:
`simulation_progression_paused=true`, `canvas_environment_activity_paused=false`,
screen still GAME, and clock deltas of 302-306 ms during each nominal 300 ms
pause - none of eight samples froze.
`GameSurfaceCanvas.set_environment_activity_paused()` owns the pause-safe clock
(`game_surface_canvas.gd:127-133, 1257-1282`) but `FoundationMain` calls it only
from the Pal tutorial-conversation handler (`foundation_main.gd:9723-9738`);
Settings stacking on the Run Menu (:16221-16255) never updates canvas pause
state, and `_sync_surface_audio()` runs before presentation early-returns
(`game_surface_canvas.gd:1257-1267`), propagating the mismatch into audio
markers and loops. Fix: centralize canvas pause ownership around
`_simulation_progression_paused()` and update both environment and game canvases
on every modal state change; give surface SFX an explicit pause/resume contract
for loops and scheduled markers rather than stopping and restarting from zero.
Regression: start a timed surface channel, open Run Menu then Settings, advance
real time, assert the surface simulation clock, marker count and loop phase do
not advance.

**BTH-054 / LIFE-003 - Settings Back leaks an unsaved High Contrast choice
globally (Medium).** Settings edits a draft copied on open
(`settings_menu.gd:60-67`); the Text Size and Small Screen callbacks call
`_apply_accessibility_settings()` (:394-427) which reads the draft's High
Contrast value and mutates global visual-style state (:474-487); Back emits only
a close request and neither teardown (:162-164, :211-219) nor
`FoundationMain.close_settings_menu()` (`foundation_main.gd:16242-16256`) rolls
the palette back. Fix: keep preview palette state scoped to the Settings subtree
and publish global VisualStyle only after Apply commits, with an explicit
commit-versus-cancel close contract instead of treating visibility loss as
teardown. Regression: a matrix over each draft field followed by Back, asserting
UserSettings, global visual-style state and newly constructed controls all match
the pre-open committed state.

---

### Wave 6 - Audio identity, lifecycle and recovery (5 defects)

**BTH-046 / EXT-AUDIO-001 - Music cache key reuses stale compositions
(Medium).** 4/4 pair comparisons collided: a Bar pair with 65.195 s vs 36.606 s
arrangements shared `stem:11:bar:local bar:bar:procedural`, and two generated
Jazz Clubs with different ids, signatures, BPM, mode, root, motif and texture
shared `stem:11:jazz_club:classical jazz club:jazz:procedural`.
`_music_profile_from_environment()` builds a full profile
(`scripts/ui/procedural_music_player.gd:2885-2937`) but `_ambient_cache_key()`
includes only version, archetype, theme, palette and authored track
(:2940-2948), while the reuse path at :463-465 assumes that key fully identifies
the PCM. Scenario state deep-merges `music_profile_override`
(`scripts/core/scenario_engine.gd:1728-1729`), weather mutates ambience, volume
and texture (`scripts/core/run_state.gd:12704-12712`), and Jazz Club generation
randomizes mode, texture, BPM, root, progression, motif, arrangement length and
signature per instance (`scripts/core/environment_instance.gd:759-796`).
`_remember_profile()` can also overwrite metadata under the colliding key while
stale PCM stays cached. Fix: make the stem-cache identity a stable hash of every
PCM-affecting field including the generated signature, and separate composition
identity from live mix identity so ambience/volume update gains without forcing
regeneration. Regression: generate two same-archetype scenario instances and two
Jazz Club instances, assert distinct profile fingerprints and require distinct
stem keys or proven mix-only equivalence.

**BTH-048 / EXT-AUDIO-003 - Decoded audio is retained for the whole app/page
lifetime (Medium).** Every registered WebAudio PCM payload stays in
`window.BTHWebAudio.pcmBuffers` until the page dies
(`scripts/ui/web_audio_bridge.gd:167-179, 226-247`; `stopAll()` removes sources
only, :454-466); Godot's `_ambient_stream_cache`, `_ambient_primer_cache`,
`_ambient_instant_cache` and `_web_music_bed_cache` are cleared only in
`_exit_tree()` (`procedural_music_player.gd:330-342`) and explicitly preserved
by `stop()` (:508-575); resetting GDScript debug stats clears only
`_registered_pcm_keys`, so the reported count can hit zero while JS buffers
remain. One full procedural stem set is roughly 37 MB of raw PCM. Fix per D9:
byte-budgeted LRU for both Godot stem sets and JS AudioBuffers protecting
active/pending keys, run-scoped caches cleared at return-to-menu / new-run, a
real `disposePcm(keys)` / `clearInactivePcm()` bridge operation, actual JS
buffer count and bytes in diagnostics, and debug reset made observational only
(or clearly separated from resource clearing).

**BTH-049 / EXT-AUDIO-004 - 0 % volume is attenuation, not mute (Low).** 12/12
observations: -80 dB, `muted=false`, `linear_gain=0.0001`. Verified:
`UserSettings._set_volume()` maps zero to -80 dB and never calls
`AudioServer.set_bus_mute()` (`scripts/core/user_settings.gd:298-305`);
`WebAudioBridge._audio_bus_linear()` returns zero only when the mute flag is set
(`scripts/ui/web_audio_bridge.gd:700-706`). Fix per D6. Regression: native and
Web contract assertions that 0 % produces exactly zero output gain and that
raising the slider restores the prior dB.

**BTH-050 / EXT-AUDIO-005 - Malformed settings silently discard preferences
(Low).** 4/4 invalid-file loads returned the complete default settings object
through a void API. `UserSettings.load()` resets first, calls `from_dict()` only
for a dictionary root and returns no status
(`scripts/core/user_settings.gd:60-69`);
`FoundationMain._initialize_user_settings()` applies it with no load outcome
(`foundation_main.gd:8640-8645`), and the next Apply overwrites the only
evidence. Run-save recovery already does this correctly. Fix: return a
structured load outcome (`loaded`, `missing`, `recovered_defaults`,
`invalid_schema`, `io_error`), preserve the invalid file with a timestamped
suffix, and surface a concise main-menu/Settings banner. Regression: malformed
JSON and a valid array root both produce the right outcome code, a preserved
file and a visible banner.

**BTH-051 / EXT-AUDIO-006 - WebAudio SFX delivery failures are ignored (Low).**
`SfxPlayer._play()` ignores `WebAudioBridge.play_stream()`'s boolean and always
returns on Web (`scripts/ui/sfx_player.gd:1602-1607`); `_start_reel_loop()` does
the same and marks `_web_surface_loop_active = true` after an unverified request
(:1561-1569), while the bridge legitimately returns false when not ready, when
payload materialization fails, or when JS registration/playback rejects
(`web_audio_bridge.gd:515-531`). Fix: honor the return value; set the loop
active flag only after success and keep a bounded retry; for one-shots use an
engine fallback where supported, and count/report dropped cues through a
player-visible "audio unavailable" status after repeated failures. Regression:
inject bridge failure and assert retry/fallback/status rather than a silent
drop.

---

### Wave 7 - Player text and readability (6 defects)

**BTH-055 / EXT-TXT-001 - Shared authority errors call every game Blackjack
(Medium).** Bar Dice, Baccarat, Roulette, Slot and Video Poker all surface
strings like "Blackjack action intent is unavailable.", "Retry or cancel the
pending Blackjack action...", "Blackjack game proposal failed closed
validation.", "Blackjack transaction could not cross the environment boundary."
and "Blackjack replay did not match the canonical committed response."
`FoundationMain._resolve_game_action()` passes `result.message` straight to
`_show_message()`, so this is player-visible. Literals live in the shared paths
at `foundation_main.gd:1651-1992`, :2288-2641, :12220-12330 and :12430. A soak
independently observed 82 runtime wrong-game messages (report EXT-PERF-003,
merged here). Fix per D10: neutral keys such as `sealed_action.pending`,
`sealed_action.retry_failed`, `sealed_action.boundary_failed`, with a trusted
game display name passed through the authority contract only where naming the
provider helps, and internal diagnostic detail separated from player recovery
copy. Regression: a table-driven test invoking every rejection code once for
every authority provider (Bar Dice, Baccarat, Blackjack, Roulette, Slot, Video
Poker) asserting no other game's name appears.

**BTH-056 / EXT-TXT-002 - Grand Casino copy says dollars/"Bankroll" when chips
move (Medium).** Modules author cash prose before the economy layer decides
currency: `GameModule.apply_result()` calls
`RunState.route_grand_casino_game_currency()`
(`scripts/core/game_module.gd:867`), and the router
(`scripts/core/run_state.gd:4702-4729`) moves `bankroll_delta` into
`chips_delta`, zeroes the cash delta and sets `result.currency="chips"` without
rebuilding `result.message`. Craps already does it right in `_roll_message()`
(`scripts/games/craps.gd:1171-1182`). Fix: build player-facing result copy only
after currency routing, using `result.currency`, `bankroll_delta` and
`chips_delta`; carry structured message keys and parameters from each module and
let the host supply the final currency noun/symbol; separate formatters for
cash, chips and mixed settlements; stop using `$` as a generic score marker.
Regression: Grand Casino and non-casino message assertions for every routable
game, checking both the named unit and the balance that actually changes.

**BTH-057 / EXT-TXT-003 - Outcome card uses an unsuffixed 24-hour clock (Low).**
Verified: `RunReportViewModel.build_outcome()` interpolates
`"%s · Day %d, %02d:%02d"` (`scripts/ui/run_report_view_model.gd:496-507`) while
`RunState.clock_display_text()`, `FoundationHudViewModel.clock_model()`, the
Scratch Ticket schedule copy and `RunReportViewModel.format_game_clock()` all
produce 12-hour AM/PM. Fix: route every game-clock display through one
formatter. Regression: midnight, noon, 13:00 and day rollover across HUD,
schedules, map, report outcome and replay clock.

**BTH-058 / EXT-TXT-004 - Hand-built grammar produces singular and
sentence-joining errors (Low).** Shipped text includes "1 tickets across 1
active rows.", "1 tickets remain across four deal rows.", "1 actions." and
"Natural hand.0 won, 1 lost, 0 pushed." Sites:
`scripts/games/scratch_tickets.gd:189`, `scripts/games/pull_tabs.gd:372`,
`scripts/ui/career_stats_view_model.gd:170`,
`scripts/core/crew_play_model.gd:176,346`,
`scripts/core/run_action_service.gd:1228`, and
`scripts/games/baccarat.gd:2872-2895` (adjacent `%s%s` with no separator). Fix
per D10: count-keyed messages instead of suffix concatenation and baked plural
nouns, counts kept structured until presentation, and a real
sentence-composition boundary for the Baccarat join. Regression: zero, one, two
and large-count assertions for every count-bearing status model.

**BTH-024 / UIE-023 - Object labels truncate silently (Medium).** "Gas Station
Casino Numbers B", "Bar Dead Tu". Label width is hard-capped at 126 px
(`scripts/ui/pixel_scene_canvas.gd:92, 5059-5068`); `_fit_draw_text` strips one
trailing character at a time and returns the bare prefix (:3878-3896), rendered
directly by `_draw_object_label` (:5336-5352). Fix: reserve ellipsis width,
expose the full identity as tooltip/accessibility text, and allow a two-line
label for long route/source names. Regression: assert a known long label renders
with an ellipsis and exposes its full text.

**BTH-025 / UIE-024 - High-Limit title plate art is clipped (Medium).** Both the
rendered frame and the source asset
`assets/art/ui/environment_titles/grand_casino_high_limit.png` end at "GRAND
CASINO HIGH LIMI". `EnvironmentHeader` uses title art by default
(`scripts/ui/environment_header.gd:28-37`) and the High-Limit config does not
opt into text mode; the texture widget preserves aspect rather than generating
visible text (:87-101). Fix per D7: set `"title_mode": "text"` for that room in
`data/ui/environment_ui.json` (the key already exists and is in use at line 29)
and add an asset-content bounds audit that flags a title raster whose ink
reaches the right edge. Regression: the bounds audit covering every title asset.

---

### Wave 8 - Tutorial focus (1 defect)

**BTH-027 / GP-01 - Wrong-order Corner Store tutorial loses the actionable Buy
target (Medium).** Buy the Pencil before the Coffee and the final "buy remaining
Coffee" lesson arrives with Coffee deselected: `selected_info.visible == false`,
action rect `Rect2(0,0,0,0)`, and the coach ring pointing at the shelf object
`(117.58,253.84 120.56x72.33)` instead of the Buy action, while the offer is
present and affordable ($8, bankroll $66). Recoverable by re-clicking, but the
instruction points at the wrong control.
Root cause: `FoundationMain._resume_after_completed_tutorial_action()` clears
stale focus before resolving the final active lesson
(`foundation_main.gd:16381-16392`), and
`_clear_stale_focus_before_dependent_tutorial_target()` examines only the first
directly authored dependent (:16395-16411) - it neither skips dependents already
satisfied out of order nor compares the selected object with the eventual active
lesson. `PixelSceneCanvas` then exposes an action rect only for the selected
object (`pixel_scene_canvas.gd:4839-4845`) and the target resolver falls back to
the shelf object (`foundation_main.gd:15003-15006`).
Fix: resolve/refresh the final active lesson first and clear selection only if
that lesson truly targets a different object; skip already-complete or
ineligible lessons while walking dependencies; and, defensively, restore the
object's selection when an action-target lesson activates for the same object.
Regression: the existing route
`scripts/tests/tutorial_corner_shop_order_check.gd:65-104` becomes a required
gate asserting both `selected_info.visible` and a non-empty `buy_item` action
rect.

---

### Wave 9 - Release packaging and artifact custody (4 defects)

Read D3 and D4 before starting. This wave changes tooling, export configuration
and quarantine layout. It does **not** export, package, tag, upload or publish.

**BTH-033 / PKG-001 - Unreleased 0.6 packages identify as published 0.5.1 with
no embedded source identity (High).** All three Windows executables and the Web
start menu report 0.5.1; neither local upload ZIP matches the immutable
published 0.5.1 artifact; no artifact-owned commit identity exists, and
performance telemetry accepts a caller-provided `bth_perf_source_commit` so it
cannot prove which source was exported. Anchors: `project.godot:19`,
`export_presets.cfg:26-27`, `scripts/ui/foundation_main.gd:17384-17389`,
`tools/export_itch.ps1:46-52,194`.
Fix per D3: stamp non-release exports as `0.6.0-dev+<short-commit>` and display
that identity in the menu while leaving `config/version` alone; embed a
machine-readable manifest with version, commit, tree, dirty-state digest, engine
hash, export-preset hash, platform and native-library hash, and make telemetry
read the manifest instead of trusting a caller string; refuse packaging when the
version equals an immutable published tag but the source tree and artifact
hashes do not match that tag's release record.

**BTH-034 / PKG-002 - Four unbound build snapshots (High).** The upload ZIP's
executable, `builds/windows/BeatTheHouse.exe` and `builds/itch/BeatTheHouse.exe`
have three different sizes and SHA-256 values while all claim 0.5.1; the Web PCK
is dated 2026-09-17 against a 2026-09-19 Windows EXE with eighteen and seven
later commits respectively. `builds/` is ignored at `.gitignore:19`, and
`tools/export_itch.ps1:252-258` archives the current output directory without
requiring a manifest, comparing the archive payload to a named candidate, or
quarantining older loose executables.
Fix: export both platforms into a new versioned staging directory keyed by
commit/tree and package only from that immutable root; generate and verify a
cross-platform manifest requiring the same candidate commit/tree in both
products and comparing every archived file hash against the staged directory;
name internal artifacts with version, platform and short commit; quarantine
superseded builds (D4 - move, never delete).

**BTH-040 / EXT-PKG-003 - Production PCKs disclose internal QA reports and
native toolchain metadata (Medium).** All three current payloads carry the same
six files totalling 15,194 bytes: `native/coin_pusher/build_profile.json`,
`native/coin_pusher/godot_web_release_build_profile.json`,
`native/coin_pusher/toolchain.lock.json` (compiler versions, upstream commits,
archive URLs and hashes), `reports/foundation_bar_dice_post_fix.json`,
`reports/foundation_bar_dice_pre_fix.json` and
`reports/gdscript_load_check_blackjack_web.json` (192 internal paths). Cause:
`export_presets.cfg:8` and `:110` use `export_filter="all_resources"` while the
exclusion lists at `:10` and `:112` omit `reports/*`, `reports/**`, `native/*`
and `native/**`; `tools/export_itch.ps1:94-107` checks loose output files for
five player-save filenames only and never audits the packed directory
(:243-244).
Fix: exclude `reports/**` and native source/build metadata while explicitly
retaining the compiled native side libraries and the required `.gdextension`
descriptor; add a post-export PCK manifest audit rejecting development-only
prefixes and unexpected file types; extend the release manifest policy to cover
reports, toolchain locks, logs, test outputs and secrets.

**BTH-041 / EXT-PKG-004 - The loose itch Windows executable is missing its
native Coin Pusher DLL (High).** `builds/itch/BeatTheHouse.exe` (171,994,584
bytes, SHA-256 `1B3796FF...AC033F49`) starts with two failed dynamic-library
opens, "GDExtension dynamic library not found" and "Error loading extension",
then runs every Coin Pusher scenario on `gdscript_v3` instead of `native_v3` -
about 9.4x slower (40.3/40.9 ms p95 versus 4.3 ms) and failing the authored
ceiling-refusal contract. The embedded `.gdextension` points at an external DLL
that is not beside the loose EXE, and
`scripts/games/coin_pusher/coin_pusher_solver.gd:460-470,558-564` deliberately
falls back. `tools/export_itch.ps1:163-179` correctly rejects the Windows output
directory without exactly one native DLL, but :182-193, :251-256 only replace
the named ZIP and never clean or quarantine stale loose artifacts.
Fix: quarantine the loose executable per D4; allow only named upload archives
plus a manifest in the upload directory; add a preflight auditing the
distribution directory for executable-looking artifacts not owned by the current
package operation; if a standalone folder is intentional, copy EXE and DLL
together and validate the pair by launching the Coin Pusher native-backend
contract; and make distribution builds fail clearly when a required native
extension is absent rather than silently shipping the fallback.

---

## 6. Verification ladder

Per wave: the wave's own new regressions plus the suites that own the touched
systems. After the final wave, in this order, with output archived under
`.tmp/fixsweep06_1/final/`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Contract -FoundationSuite contracts
powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot
powershell -ExecutionPolicy Bypass -File tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 200
powershell -ExecutionPolicy Bypass -File tools\ui05_popup_fit_check.ps1
powershell -ExecutionPolicy Bypass -File tools\ui05_surface_coverage_check.ps1
```

Then a soak long enough to exercise Wave 1's semantic-proof and rollback fixes:

```powershell
powershell -ExecutionPolicy Bypass -File tools\foundation_soak_probe.ps1 -RequireGodot -SimMinutes 180 -ActionsPerSample 28
```

The soak must report zero "scenario semantic inventory version or digest
changed" travel refusals and zero "failed to restore its declared compact
host-action rollback token" errors.

Idle-animation guard, mandatory whenever you touch draw or pause paths: a
reported idle cost of 0.000 is a red flag, not a win. Never accept an idle
number without a liveness counter proving the table is still animating.

---

## 7. Progress ledger - update this file in place as you go

Set each row to `TODO` / `IN PROGRESS` / `DONE` / `PARTIAL` / `BLOCKED`, and
record the touched files, the regression that proves it, and any decision you
had to make under rule 6.

| Wave | Defects | Status | Evidence / regression | Notes |
| --- | --- | --- | --- | --- |
| Baseline | section 4 capture | DONE | `.tmp/fixsweep06_1/baseline/` contains command logs, exit codes, pre-edit HEAD and full worktree status. Standalone `validate_project.ps1`: `Beat the House foundation architecture validation passed.` (exit 0, 186.1 s). Smoke: `validate_project             TIMEOUT   143451ms` (exit 124). Contract/contracts: `validate_project             TIMEOUT   145958ms` (exit 124). | Both Godot wrappers timed out in their prerequisite validation stage before reaching suite assertions; this is the verbatim pre-edit known-red list. No competing project Godot process was present. |
| W1 Transactions/state | BTH-039, 042, 043, 044, 045 | DONE | `.tmp/fixsweep06_1/wave1/`: BTH-039 and BTH-043 red/green `fixsweep06_1_wave1`; BTH-042 `game06_2_depth_contract.gd` no longer reports the leaked/doubled story assertion (its unrelated pre-existing compatibility-core assertion remains); BTH-044 semantic contract red with all 3 mutable producer fields then green (`failures=0`); BTH-045 rebound-cache contract red then green (`coin_pusher_contract`, `failures=0`). Combined new-regression gate passed; direct Smoke passed 7/7 checks. | Save packing now fails before touching generations; item/service money commits are detached and atomic; rejected retries re-detach after publication; scenario refresh uses durable sealed producer identity and a separate live projection; Coin Pusher rollback uses cache key/generation and restores into a rebound cache entry, with full host fallback and diagnostic payload if compact restore fails. Touched: `run_save_codec.gd`, `save_service.gd`, `run_action_service.gd`, `game_module.gd`, `run_state.gd`, `environment_instance.gd`, `coin_pusher.gd`, `foundation_main.gd`, associated contracts and shard registration. |
| W2 Placement authority | BTH-021 first, then 010, 012, 013, 017, 018, 019, 020, then 001-009, 011, 014, 015, 016, 026 | DONE | `.tmp/fixsweep06_1/wave2/`: focused `fixsweep06_1_wave2` contract green; production-order `layout_final/layout_report.json` covers 18 archetypes with 0 direct intersections, 0 route ambiguities, 0 placement errors/fallbacks, and Corner Store resolved label/object overlap 0; `dead_tuesday_pass/grounding_audit_after.json` has 19 live records and 0 failures. Every contract ID that was red in the first broad rerun was rerun green: scenario engine/sequence, tier-2, semantic presentation/restore and hidden shards 0-3, environment inventory, content-arrival, foundation, lender, M2, and Crew recruitment (`crew_recruitment_green.json`). | Audit counts no longer disappear in project/developer rooms. Final packing validates exact overrides, reserves routes first, reruns with generated hooks, distinguishes fatal normal-hit authority from nonfatal spacing/label expansion, and makes scenario-owned objects recover on valid same-class surfaces. Specific reported coordinates were moved. Revisit rebuilds now preserve a separately named durable producer-context seal without persisting ephemeral layer proof; the Crew-ignored deterministic fixture was recaptured with unchanged Crew invariants. |
| W3 Game-surface layout | BTH-022, 023 | DONE | `.tmp/fixsweep06_1/wave3/bth022_023_before.json` failed the new Bar Dice occupancy contract on all three missing geometry collections; `bth022_023_after.json` passed `bar_dice_contract` with `failures=0`, including its idle-animation liveness assertion. | Rail Cups moved to a dedicated lower-left lane clear of patrons and the console. Bar Dice now supplies a central dealer-status layout. The shared renderer returns the exact station/widget rectangles it draws; layout metadata combines those with Rail Cups and text panels into one patron-exclusion collection checked pairwise against all patron safe regions. Touched: `bar_dice.gd`, `table_game_visuals.gd`, `check_table_games.gd`. |
| W4 Accessibility/input | BTH-028, 029, 030, 031, 032, 035, 036, 037, 038 | DONE | `.tmp/fixsweep06_1/wave4/accessibility_before.log` records all nine unfixed signatures; `accessibility_after.log` passes the focused contract, including keyboard-only map select/Travel confirm, global A/B delivery, popup focus/cancel authority, 52 px custom targets, dynamic-control scaling, two reduced-motion entries, four map sizes, and the 18-case 640x360 Settings matrix. Full `compile_run_menu_and_game_flows.gd` then passed in 205 s. | Map focus navigation no longer mutates selection until Accept. A shared topmost-modal cancel/focus controller covers every decision constructor and blocks background Settings activation; blocking decisions refuse cancel. Settings owns Escape and focus restoration. Map/Settings geometry is viewport bounded; only Settings body scrolls and follows focus. `project.godot` explicitly preserves keyboard accept/cancel while adding joypad A/B, so the local game-surface A exception was removed. The full UI gate exposed two Wave-2-only deterministic hashes; both were recaptured with every scalar/route/RNG/story invariant unchanged. |
| W5 Lifecycle/pause | BTH-047, 052, 053, 054 | DONE | `scripts/tests/fixsweep06_1_lifecycle_contract.gd`; `.tmp/fixsweep06_1/wave5/lifecycle_before.log`; `.tmp/fixsweep06_1/wave5/lifecycle_after.log`; `.tmp/fixsweep06_1/wave5/coin_pusher_contract.json`; `.tmp/fixsweep06_1/wave5/ui_scene_gate.log` | Added centralized application/modal pause ownership for progression, surface presentation, and audio; cancelled focus-loss input exactly once while rejecting stale releases; preserved Web/native loop phase across pause/resume; made Settings High Contrast a truly local draft until Save and restored it on Back. Focused lifecycle regression, Coin Pusher contract, and full UI gate pass. |
| W6 Audio | BTH-046, 048, 049, 050, 051 | DONE | `scripts/tests/fixsweep06_1_audio_recovery_contract.gd`; `.tmp/fixsweep06_1/wave6/audio_recovery_before.log`; `.tmp/fixsweep06_1/wave6/audio_recovery_after.log`; `.tmp/fixsweep06_1/wave6/lifecycle_regression.log`; `.tmp/fixsweep06_1/wave6/accessibility_regression.log`; `.tmp/fixsweep06_1/wave6/ui_scene_gate.log` | Stem identity now hashes canonical PCM-affecting composition data while ambience/volume are live mix axes; Godot and Web decoded PCM use 64 MiB byte-budgeted LRUs with protected active keys, run-boundary clearing, real JS disposal and actual diagnostics; 0% hard-mutes; invalid settings are preserved with structured outcomes and visible banners; Web SFX failures retry/fallback and surface status. Focused regressions and full UI gate pass. |
| W7 Player text | BTH-024, 025, 055, 056, 057, 058 | DONE | `scripts/tests/fixsweep06_1_player_text_contract.gd`; `.tmp/fixsweep06_1/wave7/player_text_before.log`; `.tmp/fixsweep06_1/wave7/player_text_after.log`; `.tmp/fixsweep06_1/wave7/ui_scene_gate.log` | Added a shared keyed player-text boundary for neutral authority recovery, post-routing cash/chip settlement, canonical 12-hour clocks, count grammar and sentence composition. Currency copy preserves meaningful game-result context while replacing stale currency-authored wording; the full UI gate caught and now covers the all-in case. Object labels reserve an ellipsis, use two lines, and expose full tooltip/accessibility identity. Unsafe High-Limit and Back Room title rasters use text fallback. Touched: `player_text.gd`, authority/result/clock view models, affected count-bearing game/core models, `pixel_scene_canvas.gd`, `environment_ui.json`, and the focused contract. |
| W8 Tutorial | BTH-027 | DONE | `.tmp/fixsweep06_1/wave8/tutorial_before.log` reproduces the zero-area Coffee action; `tutorial_after.log` passes with visible selected info and a non-empty aligned Buy rect; `guardrail_recovery.log` passes 1,622 irregular boundaries; `ui_scene_gate.log` passes the full UI flow gate. | Tutorial completion now evaluates the settled final active lesson before reconciling focus, so already-satisfied dependents are skipped by the authoritative lesson evaluator. Selection is cleared only when that resolved anchor truly differs, and an allowed action on the same prior object defensively restores its card before coach geometry sync. `dialogue_cadence.log` and `talk_target_nonoverlap.log` record unrelated legacy-probe failures before focus assertions (invalid Blackjack fixture JSON; expected Heat 75 versus runtime 8); neither appears in the focused, stress, or full UI gate. Touched: `foundation_main.gd`, `tutorial_corner_shop_order_check.gd`. |
| W9 Packaging custody | BTH-033, 034, 040, 041 | DONE | `.tmp/fixsweep06_1/wave9/packaging_before.log` records all four missing boundaries; `packaging_after.log` and `packaging_runtime.log` pass; `current_web_pck_audit.json` independently enumerates the six reported leaks plus the newly excluded `.gitkeep`; `validate_project.log` and `ui_scene_gate.log` pass. Quarantine evidence: `builds/quarantine/20260921T015912Z/quarantine_manifest.json` plus the adjacent later manifest for two additional stale export roots. | D3 retained `project.godot` 0.5.1 while manifest-backed non-release identity is `0.6.0-dev+<short-commit>` and telemetry trusts embedded identity for distributions. Export tooling now defaults to one Windows/Web candidate in immutable commit/tree/dirty-digest staging, embeds per-platform manifests, audits PCK contents, verifies native side libraries and ZIP bytes, and refuses overwrite/unowned executable artifacts. Export filters remove reports, native toolchain sources, logs, test residue and secret file types while preserving addon binaries/descriptors. D4 moved 17 opaque roots/files into reversible timestamped quarantine; nothing was deleted. Distribution Coin Pusher fails closed when native authority is absent. No export, package, push or publish was performed. |
| Final verification | section 6 ladder | DONE | `.tmp/fixsweep06_1/final/01_validate_project_frozen.log` through `08_soak_frozen.log`; Smoke report `.tmp/test_reports/20260921_013324_smoke/summary.json`; Contract report `.tmp/test_reports/20260921_014040_contract/summary.json`; copied soak JSON `.tmp/fixsweep06_1/final/foundation_soak_probe_report_frozen.json`. | Frozen-tree ladder passed in the required order. Soak: 19 samples, 504 measured actions, 0 max orphans, 0 node/resource retained slopes, 10,512 B/sample robust memory slope, 1,205,388 B retained growth, 912,599 B max serialized state, and zero occurrences of both prohibited Wave-1 error phrases. No commit, push, export, package, upload, tag, or publish was performed. |
| 2026-09-21 reconfirmation | BTH-001 through BTH-058 | DONE | Fresh evidence under `.tmp/fixsweep06_1/reconfirm_20260921/`; final Smoke report `.tmp/test_reports/20260921_024306_smoke/summary.json`; final Contract report `.tmp/test_reports/20260921_025022_contract/summary.json`; copied performance and soak JSON in the reconfirmation directory. | All 58 original findings are not reproducible under their focused wave regressions and the complete section 6 ladder. The first fresh Smoke run exposed a separate intermittent main-menu Exit control restoration failure. A deterministic regression was captured red, the standard/meta return boundary was fixed, the full UI gate passed twice, affected W4/W5/W8 regressions passed, and the entire ladder was restarted from validation and passed. No export, package, upload, tag, publish, commit, or push was performed during this reconfirmation. |

---

## 8. Final report (write it here, at the end of this file)

1. A row per defect: BTH id, status, files changed, the regression that proves
   it, and for anything not `DONE` the exact remaining gap with evidence.
2. Baseline versus final gate comparison: which pre-existing failures you
   cleared, which remain, and proof that you introduced none.
3. Every decision you made under rule 6, with the alternatives you rejected.
4. The complete list of changed and added files, still uncommitted, so the owner
   can review the diff in one pass.
5. Anything you found that the report missed, stated plainly, fixed if it was in
   scope and recorded if it was not.

### Completion summary

All 58 confirmed defects are `DONE`. The fixes were applied in the prescribed
wave order, every wave has a red/green regression under
`.tmp/fixsweep06_1/wave*/`, and the frozen-tree section 6 ladder passed in the
required order. No work was committed or pushed.

Regression abbreviations used below:

- `W1`: `.tmp/fixsweep06_1/wave1/` focused transaction, semantic-seal and
  rollback red/green contracts plus the registered `fixsweep06_1_wave1` shard.
- `W2`: `.tmp/fixsweep06_1/wave2/` placement regression, final 18-room layout
  report, grounding audit and rerun dependent contracts.
- `W3`: `bth022_023_before.json` / `bth022_023_after.json` in the Wave 3 evidence
  directory and `bar_dice_contract`.
- `W4`: `scripts/tests/fixsweep06_1_accessibility_contract.gd`, its before/after
  logs, and the full UI-scene gate.
- `W5`: `scripts/tests/fixsweep06_1_lifecycle_contract.gd`, its before/after
  logs, Coin Pusher contract and UI-scene gate.
- `W6`: `scripts/tests/fixsweep06_1_audio_recovery_contract.gd`, its before/after
  logs, lifecycle/accessibility reruns and UI-scene gate.
- `W7`: `scripts/tests/fixsweep06_1_player_text_contract.gd`, its before/after
  logs and UI-scene gate.
- `W8`: tutorial before/after probe, 1,622-boundary guardrail recovery and full
  UI-scene gate in `.tmp/fixsweep06_1/wave8/`.
- `W9`: packaging static/runtime contracts, PCK audit, validation and UI gate in
  `.tmp/fixsweep06_1/wave9/`.
- `FINAL`: all eight frozen-tree logs under `.tmp/fixsweep06_1/final/`.

File-set abbreviations used below expand to these exact paths:

- `PLACEMENT`: `data/environments/archetypes.json`,
  `data/environments/developer_placement_overrides.json`,
  `data/environments/placement_surfaces.json`,
  `scripts/core/environment_instance.gd`, `environment_placement.gd`,
  `scenario_layout_resolver.gd`, `run_generator.gd`,
  `tools/environment_layout_screenshots.gd`, and the affected foundation
  placement/content fixtures.
- `A11Y`: `project.godot`, `scripts/ui/foundation_main.gd`,
  `foundation_screen_builder.gd`, `game_surface_canvas.gd`, `settings_menu.gd`,
  `small_screen_policy.gd`, `talk_dock.gd`, `visual_style.gd`,
  `world_map_overlay_controller.gd`, and
  `scripts/tests/fixsweep06_1_accessibility_contract.gd`.
- `AUDIO`: `scripts/core/user_settings.gd`, `scripts/ui/foundation_main.gd`,
  `procedural_music_player.gd`, `settings_menu.gd`, `sfx_player.gd`,
  `web_audio_bridge.gd`, and `scripts/tests/fixsweep06_1_audio_recovery_contract.gd`.
- `TEXT`: `scripts/ui/player_text.gd`, `foundation_main.gd`,
  `foundation_hud_view_model.gd`, `run_report_view_model.gd`,
  `career_stats_view_model.gd`, `pixel_scene_canvas.gd`,
  `scripts/core/game_module.gd`, `run_state.gd`, `crew_play_model.gd`, affected
  game modules, `data/ui/environment_ui.json`, and the Wave 7 contract.
- `PACKAGE`: `project.godot`, `export_presets.cfg`,
  `scripts/core/build_identity.gd`, `scripts/games/coin_pusher.gd`,
  `scripts/games/coin_pusher/coin_pusher_solver.gd`, `tools/export_itch.ps1`,
  `tools/audit_pck_manifest.py`, `tools/fixsweep06_1_packaging_contract_test.ps1`,
  and `scripts/tests/fixsweep06_1_packaging_runtime_contract.gd`.

### Per-defect disposition

| Defect | Status | Files changed | Regression proving the fix |
| --- | --- | --- | --- |
| BTH-001 | DONE | `PLACEMENT` (Bar pull-tabs redeemer/Slot coordinates and packing) | `W2`, `FINAL` |
| BTH-002 | DONE | `PLACEMENT` (Corner Store notebook/trunk coordinates) | `W2`, `FINAL` |
| BTH-003 | DONE | `PLACEMENT` (Corner Store discount/item placement) | `W2`, `FINAL` |
| BTH-004 | DONE | `PLACEMENT` (discount/cashier-tip placement) | `W2`, `FINAL` |
| BTH-005 | DONE | `PLACEMENT` (merchant/cashier-tip placement) | `W2`, `FINAL` |
| BTH-006 | DONE | `PLACEMENT` (Gas Station Pull Tabs/Scratch Tickets placement) | `W2`, `FINAL` |
| BTH-007 | DONE | `PLACEMENT` (Gas Station drink/numbers-book placement) | `W2`, `FINAL` |
| BTH-008 | DONE | `PLACEMENT` (Gas Station event placement) | `W2`, `FINAL` |
| BTH-009 | DONE | `PLACEMENT` (Grand Casino duplicate Slot placement) | `W2`, `FINAL` |
| BTH-010 | DONE | `PLACEMENT` (Back Room fatal route reservation/coordinates) | `W2`, `FINAL` |
| BTH-011 | DONE | `PLACEMENT` (Grand Casino Craps/redeemer placement) | `W2`, `FINAL` |
| BTH-012 | DONE | `PLACEMENT` (Cage route endpoints) | `W2`, `FINAL` |
| BTH-013 | DONE | `PLACEMENT` (High-Limit route endpoints) | `W2`, `FINAL` |
| BTH-014 | DONE | `PLACEMENT` (House storage/container placement) | `W2`, `FINAL` |
| BTH-015 | DONE | `PLACEMENT` (Jazz service/redeemer placement) | `W2`, `FINAL` |
| BTH-016 | DONE | `PLACEMENT` (Motel event/lender placement) | `W2`, `FINAL` |
| BTH-017 | DONE | `PLACEMENT` plus checked-in Dead Tuesday scenario data | `W2`, `FINAL` |
| BTH-018 | DONE | `PLACEMENT` plus Coin Pusher scenario-surface recovery | `W2`, `FINAL` |
| BTH-019 | DONE | `PLACEMENT` plus Pull Tabs task recovery | `W2`, `FINAL` |
| BTH-020 | DONE | `PLACEMENT` (leave-route/action collision authority) | `W2`, `FINAL` |
| BTH-021 | DONE | `PLACEMENT`; audit/grounding logic and developer-store isolation in `tools/check_godot.ps1` | `W2`, `FINAL` |
| BTH-022 | DONE | `scripts/games/bar_dice.gd`, `table_game_visuals.gd`, `scripts/tests/foundation/check_table_games.gd` | `W3`, `FINAL` |
| BTH-023 | DONE | `scripts/games/bar_dice.gd`, `table_game_visuals.gd`, `scripts/tests/foundation/check_table_games.gd` | `W3`, `FINAL` |
| BTH-024 | DONE | `scripts/ui/pixel_scene_canvas.gd`, `data/ui/environment_ui.json`, `TEXT` | `W7`, `FINAL` |
| BTH-025 | DONE | `data/ui/environment_ui.json`, `scripts/ui/pixel_scene_canvas.gd` | `W7`, `FINAL` |
| BTH-026 | DONE | `PLACEMENT` (resolved-label/object overlap policy) | `W2`, `FINAL` |
| BTH-027 | DONE | `scripts/ui/foundation_main.gd`, `scripts/tests/tutorial_corner_shop_order_check.gd` | `W8`, `FINAL` |
| BTH-028 | DONE | `A11Y` (map focus/selection authority) | `W4`, `FINAL` |
| BTH-029 | DONE | `A11Y` (Settings cancel ownership/focus restore) | `W4`, `FINAL` |
| BTH-030 | DONE | `A11Y` (52 px custom targets) | `W4`, `FINAL` |
| BTH-031 | DONE | `A11Y` (dynamic-control accessibility adoption) | `W4`, `FINAL` |
| BTH-032 | DONE | `scripts/ui/talk_dock.gd`, `visual_style.gd`, `foundation_main.gd` | `W4`, `FINAL` |
| BTH-033 | DONE | `PACKAGE` (manifest-backed development identity) | `W9`, `FINAL` |
| BTH-034 | DONE | `PACKAGE` (immutable custody manifests and overwrite refusal) | `W9`, `FINAL` |
| BTH-035 | DONE | `A11Y` (topmost modal focus/cancel controller) | `W4`, `FINAL` |
| BTH-036 | DONE | `A11Y` (bounded map geometry at four sizes) | `W4`, `FINAL` |
| BTH-037 | DONE | `A11Y` (Settings body scroll/focus visibility matrix) | `W4`, `FINAL` |
| BTH-038 | DONE | `project.godot`, `scripts/ui/game_surface_canvas.gd`, `foundation_main.gd` | `W4`, `FINAL` |
| BTH-039 | DONE | `scripts/core/run_save_codec.gd`, `save_service.gd`, Wave 1 regression/shard registration | `W1`, `FINAL` |
| BTH-040 | DONE | `export_presets.cfg`, `tools/audit_pck_manifest.py`, `export_itch.ps1` | `W9`, `FINAL` |
| BTH-041 | DONE | `PACKAGE` (native side-library custody and distribution fail-closed behavior) | `W9`, `FINAL` |
| BTH-042 | DONE | `scripts/core/game_module.gd`, `run_state.gd`, `scripts/tests/foundation/game06_2_depth_contract.gd` | `W1`, `FINAL` |
| BTH-043 | DONE | `scripts/core/run_action_service.gd`, `run_state.gd`, Wave 1 focused regression | `W1`, `FINAL` |
| BTH-044 | DONE | `scripts/core/run_state.gd`, `environment_instance.gd`, `scenario_layout_resolver.gd`, semantic contracts | `W1`, `FINAL` |
| BTH-045 | DONE | `scripts/games/coin_pusher.gd`, `scripts/ui/foundation_main.gd`, `check_coin_pusher.gd` | `W1`, `FINAL` |
| BTH-046 | DONE | `AUDIO` (canonical PCM-affecting music identity) | `W6`, `FINAL` |
| BTH-047 | DONE | `scripts/ui/foundation_main.gd`, `procedural_music_player.gd`, `sfx_player.gd`, `W5` contract | `W5`, `FINAL` |
| BTH-048 | DONE | `AUDIO` (64 MiB byte-budgeted Godot/Web LRUs and disposal) | `W6`, `FINAL` |
| BTH-049 | DONE | `scripts/core/user_settings.gd`, `procedural_music_player.gd`, `sfx_player.gd`, `web_audio_bridge.gd` | `W6`, `FINAL` |
| BTH-050 | DONE | `scripts/core/user_settings.gd`, `scripts/ui/settings_menu.gd`, `foundation_main.gd` | `W6`, `FINAL` |
| BTH-051 | DONE | `scripts/ui/sfx_player.gd`, `web_audio_bridge.gd`, `foundation_main.gd` | `W6`, `FINAL` |
| BTH-052 | DONE | `scripts/ui/foundation_main.gd`, `game_surface_canvas.gd`, audio players, lifecycle contract | `W5`, `FINAL` |
| BTH-053 | DONE | `scripts/ui/game_surface_canvas.gd`, `foundation_main.gd`, `check_coin_pusher.gd` | `W5`, `FINAL` |
| BTH-054 | DONE | `scripts/ui/settings_menu.gd`, `visual_style.gd`, `foundation_main.gd` | `W5`, `FINAL` |
| BTH-055 | DONE | `TEXT` (neutral keyed authority recovery copy) | `W7`, `FINAL` |
| BTH-056 | DONE | `TEXT` (post-routing cash/chip settlement copy) | `W7`, `FINAL` |
| BTH-057 | DONE | `scripts/ui/run_report_view_model.gd`, `foundation_hud_view_model.gd`, `player_text.gd` | `W7`, `FINAL` |
| BTH-058 | DONE | `TEXT`, including `baccarat.gd`, `pull_tabs.gd`, `scratch_tickets.gd`, career/crew models | `W7`, `FINAL` |

### Baseline versus frozen-tree gates

| Gate | Pre-edit baseline | Frozen-tree result |
| --- | --- | --- |
| Standalone validation | PASS, 186.1 s | PASS, 106.7 s (`01_validate_project_frozen.log`) |
| Smoke | Timed out in prerequisite validation at 143,451 ms; no Smoke assertion ran | PASS, all 10 stages (`02_smoke_frozen.log`) |
| Contract/contracts | Timed out in prerequisite validation at 145,958 ms; no contract assertion ran | PASS; contract shards 214,202 ms (`03_contract_frozen.log`) |
| Performance | Not a baseline command | PASS, 75 observations/8 seeds; live animation counters nonzero (`04_performance_frozen.log`) |
| Stuck-state | Not a baseline command | PASS, 200 seeds, zero stuck (`05_stuck_state_frozen.log`) |
| Popup fit | Not a baseline command | PASS, 3 viewport/content pairs (`06_popup_fit_frozen.log`) |
| Surface coverage | Not a baseline command | PASS, 63 UI scripts plus 6 supplement entries (`07_surface_coverage_frozen.log`) |
| 180-minute simulated soak | Not a baseline command | PASS, 504 actions, zero sampled orphans, 912,599-byte max serialized state (`08_soak_frozen.log`) |

The two baseline timeouts are cleared, all known Wave 2 composition reds are
covered by the final layout/contract evidence, and no final gate has a failing
stage or assertion. The Godot shutdown-only `ObjectDB instances leaked` warning
remains the report's explicitly excluded shutdown diagnostic; every in-run and
retained sample has zero orphan nodes. It is not counted as a newly introduced
failure.

### Decisions and rejected alternatives

1. Applied D1/D2 exactly: fixed both placement policy and checked-in coordinates;
   rejected deferral to the later redesign and rejected making spacing-only
   warnings fatal.
2. Applied D3: retained `config/version="0.5.1"` and added manifest-backed
   `0.6.0-dev+<short-commit>` identity; rejected a release-version bump.
3. Applied D4: moved opaque build outputs to two timestamped quarantine roots;
   rejected deletion and rejected silently overwriting loose artifacts.
4. Applied D5: OS focus/minimize is a central pause owner; rejected background
   continuation and a new opt-in setting.
5. Applied D6: 0% is a native/Web hard mute with prior level restoration;
   rejected attenuation-only behavior.
6. Applied D7: switched unsafe High-Limit and Back Room title raster use to text
   with an asset-bounds audit; rejected raster regeneration.
7. Applied D8: one detached transaction helper owns item and paid-hook commits;
   rejected duplicate call-site ordering patches.
8. Applied D9: each decoded-audio domain has a 64 MiB protected LRU and actual
   Web disposal; rejected count-only and process-lifetime caches.
9. Applied D10: introduced keyed/parameterized player-text composition; rejected
   patching isolated English strings.
10. Isolated developer placement storage inside `check_godot.ps1`; rejected
    reading or mutating the operator's global `user://` authoring residue.
11. Added `docs/plans/0.5_ui_surface_coverage_supplement.json` for the six UI
    scripts created after the historical coverage report; rejected rewriting the
    historical source report.
12. Kept contract shard merge semantics but bounded child concurrency to eight
    and launched measured long shards first; rejected unbounded host
    oversubscription and rejected weakening the contract wall-time budget.
13. During final soak verification, fixed an unreported Run Report teardown leak:
    new-run transition now releases runtime rows plus deep-copied map/timeline
    graphs. Rejected hiding the report or raising memory caps.
14. The remaining isolated `Performance.MEMORY_STATIC` endpoint spike had flat
    nodes/resources/application caches and repeated at allocator page boundaries.
    Retained growth now uses the median of the final three canonical resets and a
    six-sample median pairwise slope, with the original 4 MiB/256 KiB limits,
    peak checks and exact orphan/node/resource/object checks unchanged. Rejected
    raising limits, dropping the soak, or accepting the failed raw endpoint.

### Complete uncommitted worktree inventory

This is the complete final `git status --short --untracked-files=all` inventory:
65 modified and 34 untracked paths. The 14 modified and 16 untracked evidence
paths listed in section 1 were present in the baseline and were preserved; some
of those files also necessarily received in-scope fixes. The two untracked code
health documents appeared outside this sweep after baseline and were not edited.

```text
 M data/crew/world06_6_heist_sequences.json
 M data/environments/archetypes.json
 M data/environments/developer_placement_overrides.json
 M data/environments/placement_surfaces.json
 M data/ui/environment_ui.json
 M export_presets.cfg
 M project.godot
 M scripts/core/crew_play_model.gd
 M scripts/core/environment_instance.gd
 M scripts/core/environment_placement.gd
 M scripts/core/game_module.gd
 M scripts/core/run_action_service.gd
 M scripts/core/run_generator.gd
 M scripts/core/run_save_codec.gd
 M scripts/core/run_state.gd
 M scripts/core/save_service.gd
 M scripts/core/scenario_layout_resolver.gd
 M scripts/core/user_settings.gd
 M scripts/games/baccarat.gd
 M scripts/games/bar_dice.gd
 M scripts/games/coin_pusher.gd
 M scripts/games/coin_pusher/coin_pusher_solver.gd
 M scripts/games/pull_tabs.gd
 M scripts/games/scratch_tickets.gd
 M scripts/games/table_game_visuals.gd
 M scripts/games/video_poker_renderer.gd
 M scripts/tests/fixtures/crew06_5_ignored_run_baseline.json
 M scripts/tests/foundation/check_coin_pusher.gd
 M scripts/tests/foundation/check_core_content.gd
 M scripts/tests/foundation/check_lenders_release_saves.gd
 M scripts/tests/foundation/check_table_games.gd
 M scripts/tests/foundation/crew_plays_contract.gd
 M scripts/tests/foundation/crew_recruitment_contract.gd
 M scripts/tests/foundation/crew_turn_contract.gd
 M scripts/tests/foundation/env06_8_environment_readability_contract.gd
 M scripts/tests/foundation/game06_2_depth_contract.gd
 M scripts/tests/foundation/scenario_backlog_contract.gd
 M scripts/tests/foundation/scenario_semantic_presentation_contract.gd
 M scripts/tests/tutorial_corner_shop_order_check.gd
 M scripts/tests/ui_scene/compile_components_and_main_flow.gd
 M scripts/ui/career_stats_view_model.gd
 M scripts/ui/foundation_hud_view_model.gd
 M scripts/ui/foundation_main.gd
 M scripts/ui/foundation_screen_builder.gd
 M scripts/ui/game_surface_canvas.gd
 M scripts/ui/perf_telemetry_overlay.gd
 M scripts/ui/pixel_scene_canvas.gd
 M scripts/ui/procedural_music_player.gd
 M scripts/ui/run_report_screen.gd
 M scripts/ui/run_report_view_model.gd
 M scripts/ui/settings_menu.gd
 M scripts/ui/sfx_player.gd
 M scripts/ui/small_screen_policy.gd
 M scripts/ui/talk_dock.gd
 M scripts/ui/visual_style.gd
 M scripts/ui/web_audio_bridge.gd
 M scripts/ui/world_map_overlay_controller.gd
 M tools/check_godot.ps1
 M tools/environment_layout_screenshots.gd
 M tools/export_itch.ps1
 M tools/foundation_soak_probe.gd
 M tools/foundation_systems_shards.ps1
 M tools/scenario_room_multiseed_finalization.gd
 M tools/archive/ui05/ui05_surface_coverage_check.ps1
 M tools/archive/world06_6/world06_6_sign_packages.gd
?? docs/plans/0.5_ui_surface_coverage_supplement.json
?? docs/plans/code_health_audit_2026-09-20.md
?? docs/todo/fixsweep06_1_extended_playtest_bug_sweep_prompt.md
?? docs/todo/health06_1_code_health_remediation_prompt.md
?? reports/playtest_2026-09-20/Beat_the_House_Extended_Playtest_Bug_Report_2026-09-20.docx
?? reports/playtest_2026-09-20/Beat_the_House_Extended_Playtest_Bug_Report_2026-09-20.md
?? reports/playtest_2026-09-20/Beat_the_House_Playtest_Bug_Report_2026-09-20.docx
?? reports/playtest_2026-09-20/accessibility_input.md
?? reports/playtest_2026-09-20/extended_accessibility_input.md
?? reports/playtest_2026-09-20/extended_audio_feedback.md
?? reports/playtest_2026-09-20/extended_game_rules_fuzz.md
?? reports/playtest_2026-09-20/extended_lifecycle_recovery.md
?? reports/playtest_2026-09-20/extended_localization_text.md
?? reports/playtest_2026-09-20/extended_packaged_platform.md
?? reports/playtest_2026-09-20/extended_performance_soak.md
?? reports/playtest_2026-09-20/extended_persistence_chaos.md
?? reports/playtest_2026-09-20/extended_progression_economy.md
?? reports/playtest_2026-09-20/gameplay_progression.md
?? reports/playtest_2026-09-20/games_performance.md
?? reports/playtest_2026-09-20/packaged_platform.md
?? reports/playtest_2026-09-20/persistence_chaos.md
?? reports/playtest_2026-09-20/ui_environment.md
?? scripts/core/build_identity.gd
?? scripts/tests/fixsweep06_1_accessibility_contract.gd
?? scripts/tests/fixsweep06_1_audio_recovery_contract.gd
?? scripts/tests/fixsweep06_1_lifecycle_contract.gd
?? scripts/tests/fixsweep06_1_packaging_runtime_contract.gd
?? scripts/tests/fixsweep06_1_player_text_contract.gd
?? scripts/tests/foundation/fixsweep06_1_regressions.gd
?? scripts/tests/foundation/table_game_authority_test_driver.gd
?? scripts/ui/player_text.gd
?? tools/audit_pck_manifest.py
?? tools/fixsweep06_1_packaging_contract_test.ps1
?? tools/fixsweep06_1_update_crew_golden.gd
```

Ignored but review-relevant reversible/evidence outputs are
`builds/quarantine/20260921T015912Z/`,
`builds/quarantine/20260921T015945Z/`, and `.tmp/fixsweep06_1/`.

### Findings the source report missed

- The final soak exposed completed Run Report ownership surviving into a new
  run: four money-flow rows, one item row, and deep-copied timeline/map data.
  `RunReportScreen.clear_report()` plus the new-run boundary now release all of
  them. The UI regression verifies every retained collection returns to zero;
  the final soak has flat nodes and resources.
- The soak's single-endpoint retained-memory statistic could fail on an isolated
  Godot allocator-page acquisition despite 17 preceding flat canonical samples.
  The estimator is now robust to one isolated endpoint while retaining every
  original cap and exact leak check; two failing attempts and the final pass are
  archived under `.tmp/fixsweep06_1/final/`.
- The historical UI surface-coverage report predated six newly added scripts.
  A validated supplement accounts for them without mutating historical evidence.
- The final soak records fail-closed warnings when its generic selector proposes
  a destination that does not change the current node. It still completes 209
  valid measured travels, has no failure, and contains zero semantic-digest or
  compact-rollback error signatures. This is diagnostic harness noise, not a
  player-facing defect, so no production behavior was changed for it.

---

## 9. Fresh reconfirmation - 2026-09-21

This second pass started from clean `main` at
`93e7550b9d0116d59cb61198b4ccfdafbc810cc1`, equal to `origin/main`. The source
report and all fifteen specialist reports remained read-only. Every focused
Godot invocation used an evidence-local developer-placement path, and no two
Godot jobs overlapped.

### Fresh evidence keys

- `RC-W1-W3`: `wave1_to_wave3_contract.log`, followed by the restarted final
  Contract report `.tmp/test_reports/20260921_025022_contract/summary.json`.
- `RC-W2-LAYOUT`: `wave2_layout.log` and `wave2_layout/layout_report.json`;
  `LAYOUT_SURVEY_DONE 18 environments`.
- `RC-W4`: `wave4_accessibility.log` and
  `wave4_accessibility_after_menu_fix.log`.
- `RC-W5`: `wave5_lifecycle.log` and
  `wave5_lifecycle_after_menu_fix.log`.
- `RC-W6`: `wave6_audio.log` and `wave6_audio_final_tree.log`.
- `RC-W7`: `wave7_player_text.log` and `wave7_player_text_final_tree.log`.
- `RC-W8`: `wave8_tutorial.log` and `wave8_tutorial_after_menu_fix.log`.
- `RC-W9`: the initial and final-tree `wave9_packaging_static*.log` and
  `wave9_packaging_runtime*.log` pairs.
- `RC-FINAL`: `final_restart_01_validate_project.log` through
  `final_restart_08_soak.log`, plus the copied performance/soak JSON reports,
  all under `.tmp/fixsweep06_1/reconfirm_20260921/`.

### Per-defect reconfirmation

`NOT REPRODUCIBLE` means the detailed report reproduction is now contradicted
by its focused fresh regression and by the owning full-suite gate. No original
BTH finding remains partial, blocked, or accepted as a waiver.

| BTH id | Fresh status | Fresh proof |
| --- | --- | --- |
| BTH-001 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-002 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-003 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-004 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-005 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-006 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-007 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-008 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-009 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-010 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-011 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-012 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-013 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-014 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-015 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-016 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-017 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-018 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-019 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-020 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-021 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-022 | NOT REPRODUCIBLE - DONE | `RC-W1-W3`, `RC-FINAL` |
| BTH-023 | NOT REPRODUCIBLE - DONE | `RC-W1-W3`, `RC-FINAL` |
| BTH-024 | NOT REPRODUCIBLE - DONE | `RC-W7`, `RC-FINAL` |
| BTH-025 | NOT REPRODUCIBLE - DONE | `RC-W7`, `RC-FINAL` |
| BTH-026 | NOT REPRODUCIBLE - DONE | `RC-W2-LAYOUT`, `RC-W1-W3`, `RC-FINAL` |
| BTH-027 | NOT REPRODUCIBLE - DONE | `RC-W8`, `RC-FINAL` |
| BTH-028 | NOT REPRODUCIBLE - DONE | `RC-W4`, `RC-FINAL` |
| BTH-029 | NOT REPRODUCIBLE - DONE | `RC-W4`, `RC-FINAL` |
| BTH-030 | NOT REPRODUCIBLE - DONE | `RC-W4`, `RC-FINAL` |
| BTH-031 | NOT REPRODUCIBLE - DONE | `RC-W4`, `RC-FINAL` |
| BTH-032 | NOT REPRODUCIBLE - DONE | `RC-W4`, `RC-FINAL` |
| BTH-033 | NOT REPRODUCIBLE - DONE | `RC-W9`, `RC-FINAL` |
| BTH-034 | NOT REPRODUCIBLE - DONE | `RC-W9`, `RC-FINAL` |
| BTH-035 | NOT REPRODUCIBLE - DONE | `RC-W4`, `RC-FINAL` |
| BTH-036 | NOT REPRODUCIBLE - DONE | `RC-W4`, `RC-FINAL` |
| BTH-037 | NOT REPRODUCIBLE - DONE | `RC-W4`, `RC-FINAL` |
| BTH-038 | NOT REPRODUCIBLE - DONE | `RC-W4`, `RC-FINAL` |
| BTH-039 | NOT REPRODUCIBLE - DONE | `RC-W1-W3`, `RC-FINAL` |
| BTH-040 | NOT REPRODUCIBLE - DONE | `RC-W9`, `RC-FINAL` |
| BTH-041 | NOT REPRODUCIBLE - DONE | `RC-W9`, `RC-FINAL` |
| BTH-042 | NOT REPRODUCIBLE - DONE | `RC-W1-W3`, `RC-FINAL` |
| BTH-043 | NOT REPRODUCIBLE - DONE | `RC-W1-W3`, `RC-FINAL` |
| BTH-044 | NOT REPRODUCIBLE - DONE | `RC-W1-W3`, `RC-FINAL` |
| BTH-045 | NOT REPRODUCIBLE - DONE | `RC-W1-W3`, `RC-FINAL` |
| BTH-046 | NOT REPRODUCIBLE - DONE | `RC-W6`, `RC-FINAL` |
| BTH-047 | NOT REPRODUCIBLE - DONE | `RC-W5`, `RC-FINAL` |
| BTH-048 | NOT REPRODUCIBLE - DONE | `RC-W6`, `RC-FINAL` |
| BTH-049 | NOT REPRODUCIBLE - DONE | `RC-W6`, `RC-FINAL` |
| BTH-050 | NOT REPRODUCIBLE - DONE | `RC-W6`, `RC-FINAL` |
| BTH-051 | NOT REPRODUCIBLE - DONE | `RC-W6`, `RC-FINAL` |
| BTH-052 | NOT REPRODUCIBLE - DONE | `RC-W5`, `RC-FINAL` |
| BTH-053 | NOT REPRODUCIBLE - DONE | `RC-W5`, `RC-FINAL` |
| BTH-054 | NOT REPRODUCIBLE - DONE | `RC-W5`, `RC-FINAL` |
| BTH-055 | NOT REPRODUCIBLE - DONE | `RC-W7`, `RC-FINAL` |
| BTH-056 | NOT REPRODUCIBLE - DONE | `RC-W7`, `RC-FINAL` |
| BTH-057 | NOT REPRODUCIBLE - DONE | `RC-W7`, `RC-FINAL` |
| BTH-058 | NOT REPRODUCIBLE - DONE | `RC-W7`, `RC-FINAL` |

### Additional defect found and closed during reconfirmation

The first fresh Smoke run passed five stages, then failed
`ui_scene_compile`: after the pawn immediate-credit flow returned to the main
menu, the live Exit Game button could remain locally hidden/disabled. An
isolated rerun passed, but a stress repetition reproduced the same failure, so
it was not waived as timing noise.

- Pre-fix evidence: `final_02_smoke.log`, `ui_scene_compile_repro_02.log`, and
  deterministic `menu_restore_regression_before.log` (`visible=false`,
  `visible_in_tree=false`, `disabled=true`, visible parent, live field identity).
- Fix: `foundation_main.gd` now makes the main-menu return path the explicit
  normalization boundary for persistent utility controls, and the meta-session
  return also closes run configuration and uses that boundary.
- Regression: `compile_environment_layout.gd` deliberately seeds the exact
  stale control state before returning; `compile_components_and_main_flow.gd`
  reports the full control identity/state if restoration fails.
- Post-fix evidence: `menu_restore_regression_after_01.log` and `_after_02.log`
  both pass the complete UI scene gate; fresh W4, W5 and W8 focused reruns pass;
  restarted Smoke passes all 10 stages.

### Restarted final ladder result

| Rung | Result |
| --- | --- |
| Project validation | PASS |
| Smoke | PASS, 10/10 stages, 430.2 s |
| Contract / contracts | PASS, 4/4 stages, 377.5 s |
| Performance | PASS, 75 observations, 8 seeds, 16/16 liveness observations nonzero/passing, 0 failures |
| Stuck-state sweep | PASS, 200 seeds, 48 slot scenarios, 9 wait scenarios, 0 stuck |
| Popup fit | PASS, 3 representative viewport/content pairs |
| UI surface coverage | PASS, 63 scripts plus 6 supplement entries |
| Soak | PASS, 19 samples, 504 measured actions, 0 max orphans, 0 retained node/resource slope, 1,300 B/sample robust retained-memory slope, 1,239,360 B retained-memory growth, 912,599 B max serialized state |

The final soak contains zero occurrences of both required prohibited phrases:
`scenario semantic inventory version or digest changed` and
`failed to restore its declared compact host-action rollback token`.
