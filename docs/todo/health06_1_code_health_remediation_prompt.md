# Agent Prompt - health06_1: Code Health Remediation (CH-01 ... CH-36)

Status: TODO. Self-contained. This file is the only coordination document for
this work; there is no board, queue, claim or archive ceremony to follow.

## How to launch this row

Paste the block below into the worker agent, from a shell whose working
directory is `D:\Projects\Beat-The-House`:

> Read `docs/todo/health06_1_code_health_remediation_prompt.md` in full and
> execute it end to end, in phase order. Its source of truth is
> `docs/plans/code_health_audit_2026-09-20.md`, which is baselined on commit
> `4384378a` - read the numbered finding in that report before each fix, because
> this prompt summarises it rather than replacing it. Obey section 1 exactly:
> never commit or push, never revert the pre-existing uncommitted work, verify
> every line anchor against the live tree before editing it, and ship a
> regression with every fix. Respect the `fixsweep06_1` interlock in section 2.
> Update the section 9 ledger in this file as you go and write the section 10
> final report into it when done.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6, GDScript, Windows).

Your assignment is to remediate the 36 findings in
`docs/plans/code_health_audit_2026-09-20.md` and to land the nine new
components that make them stay fixed.

That report is **baselined on commit `4384378a`**. Its line numbers are exact
at that commit and will have drifted in the live tree. **Always confirm an
anchor by reading the surrounding code before you edit it.** If a finding no
longer reproduces, record that in the ledger with evidence and move on - do not
invent a replacement.

---

## 1. Rules (binding, inlined, no external documents)

1. **Never run `git commit` or `git push`.** Not once, not at the end. Leave
   every change in the working tree and report what you changed. Only an
   explicit instruction from the owner during this run may override this.
2. **The worktree carries pre-existing uncommitted work from another agent.**
   The `docs/todo/fixsweep06_1_extended_playtest_bug_sweep_prompt.md` run has
   landed all nine waves and is finishing verification. Do not
   revert, stash, checkout-over or "clean up" any of its changes. Build on top.
   Check `git status` before you start and again before you finish, and report
   any file you touched that it had also modified.
3. **Verify before you edit.** Every anchor in this prompt and in the report is
   from commit `4384378a`. Read the code at the named symbol, not the named
   line.
4. **One headless Godot at a time.** `tools/check_godot.ps1` stops early if
   another Godot process is running for this project. Long suites need an outer
   timeout longer than the harness timeout (the full suite reserves 1800 s).
   Killing the parent PowerShell early can strand Godot children writing
   `user://` logs and has caused native access-violation dialogs on later runs.
   **Assume the other agent may be running gates. Check first, and wait rather
   than racing it.**
5. **Every fix ships with a regression that fails before it and passes after.**
   Write the test first where practical, confirm it reproduces, then fix. A fix
   with no test is not done.
6. **Do not hand the owner homework.** If you hit a decision section 3 does not
   settle, choose the safest reversible option, implement it, finish the work,
   and record the call and the alternatives in the ledger. Never end with "the
   owner should decide X" while leaving code unfixed.
7. **Do not widen scope.** No refactors, renames or formatting sweeps outside a
   named finding. No version bump, no tagging, no packaging, no publishing.
8. **Report honestly.** If a finding resists a clean fix, land the best correct
   partial fix behind a test that documents the remaining gap and mark it
   `PARTIAL` with specifics. Never mark a row `DONE` that a gate does not prove.

---

## 2. Interlock with `fixsweep06_1` - read before starting

The `fixsweep06_1` agent fixed 58 player-visible defects across 36 production
files. At the final re-verification of this plan its ledger read **Waves 1-9
`DONE`, Final verification `TODO`**, with the owner running additional
verification and making minor finalising changes. Its changes are uncommitted
and sit in the same working tree you are working in.

Before starting, re-read the ledger table at the end of
`docs/todo/fixsweep06_1_extended_playtest_bug_sweep_prompt.md`:

| This phase | May start when | Status at final re-verification |
| --- | --- | --- |
| 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11 | the sweep's wave rows are `DONE` | **unblocked** |
| 10 (CH-26) | the sweep's **Final verification** row is `DONE` | **blocked until then** |

Phase 10 moves ~120 functions out of `run_state.gd` and extracts clusters from
`foundation_main.gd` - the two files the sweep's final verification is most
likely to touch. If its Final verification row is not `DONE` when you reach
phase 10, skip it, record the blocking state in the ledger, and finish the
rest. **Before every phase, run `git status` and `git diff --stat`; if a file
you are about to edit changed since your last read, re-read it first.** Minor
finalising edits from the owner may still be landing.

If a phase's precondition is not met, skip it, record the exact blocking state
in the ledger, and continue with the next eligible phase. Do not wait idle.

---

## 3. Binding decisions (already made - do not relitigate)

- **D1 - One durable store.** `DurableStore` (report 3.1) becomes the only JSON
  persistence implementation. The run save, profile, collection, developer
  placements and settings all route through it. Do not leave a second
  implementation "for now".
- **D2 - Never delete a valid generation before a validated replacement exists
  on disk.** This is the invariant the whole of Cluster A enforces.
- **D3 - Backups everywhere.** Every durable store gets a `.bak` generation,
  not just the run save.
- **D4 - Additive typing.** `IoResult` and the `Keys` constants are adopted at
  named boundaries only. No project-wide sweep, no mass rewrite of the 38,171
  dictionary accesses.
- **D5 - Static caches are bounded.** Every cache introduced or converted gets
  an entry budget and protects active keys. Default 64 entries unless the
  report names a different number.
- **D6 - Dark tests are triaged, not deleted wholesale.** For each of the 46
  contracts CH-23 finds, **plus the five new `fixsweep06_1_*` contracts at
  `scripts/tests/` root**, either make it pass, or delete it with a one-line
  reason in the ledger. 51 dispositions. Leaving one dark is not an option.
  **Never delete a `fixsweep06_1_*` contract** - those encode just-fixed
  player defects; if one fails, fix the code or the fixture, not the test.
- **D7 - Style reformatting lands in its own change.** CH-21 must not share a
  commit-equivalent chunk of work with any behavioural fix.
- **D8 - `builds/`, `reports/` and `.tmp/` contents are never deleted by this
  row.** CH-35 adds a retention *tool*; it does not run a destructive sweep.
- **D9 - No new dependencies.** `gdlint` configuration (CH-36) is added as
  config plus a validator hook. Do not vendor a linter into the repo.

---

## 4. Read before you touch code

- `docs/plans/code_health_audit_2026-09-20.md` in full - it is the specification
  for this work.
- `README.md` sections "Running The Project" and "Validation".
- `docs/todo/fixsweep06_1_extended_playtest_bug_sweep_prompt.md` ledger table.
- `scripts/core/save_service.gd` - the closest existing implementation of
  `DurableStore`, and the behaviour you are generalising.
- `scripts/core/content_library.gd:44-50` - the existing correct bounded-cache
  implementation you are lifting for `StaticDataCache`.

**Known-red baseline.** The broad Contract suite is already red at
room/scenario composition. Capture the baseline in phase 0 before changing
anything, so you can prove which reds you cleared and that you introduced none.

---

## 5. Baseline capture (before any edit)

Archive under `.tmp/health06_1/baseline/`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Contract -FoundationSuite contracts
```

Also record `git status --short` and `git rev-parse HEAD` verbatim. Record every
failing stage and assertion. This is your "was already red" list.

---

## 6. The phases

Work in order, skipping any whose interlock is unmet. Each phase ends with its
own gate run and a ledger update.

### Phase 0 - `DurableStore` and Cluster A (CH-01..CH-06) - P1

Build `scripts/core/durable_store.gd` to the contract in report section 3.1:
`write_json`, `read_json`, `backup_path`, `status`. The write sequence is
mandatory and ordered - directory, temp open, store, **check `get_error()`**,
close, **validate the temp**, rotate primary to `.bak`, rename, **validate the
installed primary**.

Then:

- **CH-01** - replace the `save()`/`load()` bodies of
  `scripts/core/profile_inventory.gd` and
  `scripts/core/meta_collection_service.gd`. Both currently
  `store_string` without checking the error, then `DirAccess.remove_absolute`
  the good primary, then rename - with no backup generation in existence.
  Surface the load outcome so the main menu can report a recovered-from-backup
  load the way the run save already does.
- **CH-02** - route all six production `store_string` sites through
  `DurableStore`. Re-verified live: only `save_service.gd` checks the write
  error (`:67`, `:206`). `user_settings.gd:109-114` still returns `OK` without
  checking `get_error()` **and without ever calling `close()`**;
  `developer_placement_store.gd:156`, `meta_collection_service.gd:116`,
  `profile_inventory.gd:75` and `perf_telemetry_overlay.gd:3481` all close but
  never check.
- **CH-03 - RESOLVED, no work.** Sweep Wave 6 already made
  `UserSettings.load()` return a `Dictionary` (`:61`) with
  `_recover_invalid_settings_file()` (`:87`). Fold that existing recovery path
  into `DurableStore`; do not rewrite it.
- **CH-04 - STILL LIVE and now the dangerous half.** `window_mode` (`:157`) and
  `text_size` (`:167`) in `UserSettings.from_dict()` still assign a raw
  `Variant` into `String`-typed members, while the sibling `drunk_effect_mode`
  (`:171`) uses `str(...)`. Wave 6's new recovery path is only reached if this
  assignment does not fail first. Route both through `JsonCoerce.coerce_enum`
  (build that one function now; the rest of `JsonCoerce` comes in phase 2).
- **CH-05** - `developer_placement_store.gd` reports `{"ok": true}` from an
  unconditional `return OK`.
- **CH-06** - validate `BTH_DISTRIBUTION_DATA_ROOT` in
  `scripts/core/persistence_paths.gd`: reject empty-after-normalisation, non
  absolute and non `user://` roots, and any root containing `..`.

**Gate:** the durable-store contract from report 6.1, for all five stores.

### Phase 1 - Restore the dark contract suite (CH-23) - P1

46 of 81 files in `scripts/tests/foundation/` are reachable from no gate, and
45 of them are standalone `extends SceneTree` scripts. They are also excluded
from the exhaustive parse (`tools/check_godot.ps1:1272`) and the load check
(`:831`), so they are not even syntax-checked.

1. Add a `standalone_contracts` stage to `tools/check_godot.ps1` enumerating
   every `scripts/tests/foundation/*.gd` whose first line is `extends SceneTree`
   and which no split runner preloads, running each with `--headless --script`.
2. Narrow both exclusions - now at `check_godot.ps1:837` (load check) and
   `:1278` (exhaustive parse) - from the directory prefix to the explicit
   nine-file split-runner list. The sweep modified `check_godot.ps1` (it now
   isolates `BTH_DEVELOPER_PLACEMENT_PATH` for gate runs); keep that change.
3. Run them all. **Expect failures.** Triage each per D6: fix, or delete with a
   one-line reason. Record every disposition in the ledger.

**The pattern is still active - include these five.** Re-verification caught the
fix sweep creating new dark contracts while this plan was being written, none
wired into any runner:

- `scripts/tests/fixsweep06_1_accessibility_contract.gd`
- `scripts/tests/fixsweep06_1_audio_recovery_contract.gd`
- `scripts/tests/fixsweep06_1_lifecycle_contract.gd`
- `scripts/tests/fixsweep06_1_packaging_runtime_contract.gd`
- `scripts/tests/fixsweep06_1_player_text_contract.gd`

Wire these five **first** in phase 1 - they are the regression net for the
sweep's work and should be gating before you touch anything else.

The same sweep *did* wire its Wave 1-2 work correctly -
`fixsweep06_1_regressions.gd` is preloaded at `check_core_content.gd:37` and
invoked at `:630-631` - so the project knows how. There is simply no gate that
requires it. Your standalone stage must cover `scripts/tests/*.gd` as well as
`scripts/tests/foundation/*.gd`.

This phase is the largest single time cost in the plan. Budget for it.

### Phase 2 - Shared primitives (CH-29, CH-11, CH-15)

- `scripts/core/json_coerce.gd` with the canonical `_copy_dict`, `_copy_array`,
  `_string_array`, `_dictionary_array`, `_int_array`, `_stable_hash`,
  `_valid_sha256` and `coerce_enum`. Put the game-facing subset on `GameModule`
  itself - all eleven games already extend it. Then delete the 201 duplicate
  copies across 68 groups.
- `scripts/core/static_data_cache.gd`, lifted from the working implementation
  at `content_library.gd:44-50`.
- **CH-11** - `collection_item_resolver.gd` declares `var _loaded` per instance,
  so each resolver re-parses a 2,041-line JSON. `collection_drop_service.gd`
  constructs a fresh resolver inside three loops plus `_roll_bag_marker`, so a
  four-marker run end parses that file about sixteen times on a UI screen.
  Convert to a static bounded cache and hold one resolver.
- **CH-15 - WITHDRAWN, no work.** Re-verification found Wave 6 fixed the two
  real cases (`procedural_music_player._evict_pcm_cache_key()` at `:514`;
  `web_audio_bridge.disposePcm`/`clearInactivePcm` at `:258`/`:272`) and that
  the other three were false positives in the audit: `_delivery_board_cache` is
  single-entry, `_scenario_sequence_definition_cache` resets with `= {}` at
  `run_state.gd:494`, and `sfx_player._stream_cache` is keyed by a finite
  normalized event vocabulary. Build `StaticDataCache` anyway for CH-11 and for
  future use, but do not "fix" these five.

### Phase 3 - Correctness defects (CH-07..CH-10)

- **CH-07** - `world_sequence_package_catalog.gd` bounds packages-per-file by
  `PACKAGE_PATHS.size()`, an unrelated quantity, and cannot distinguish a
  missing/corrupt file from an unknown id. Add an explicit
  `MAX_PACKAGES_PER_FILE`, separate the two failure modes in the return, and
  `push_error` the IO one.
- **CH-08** - `item_effect.gd` `_merge_modifier_value` does
  `target.get(key, 0) + value`, which evaluates `Dictionary + int` when an
  earlier source set that key to a container. Guard the accumulate and add the
  key-type conflict to `ContentLibrary` item validation so bad data fails at
  load.
- **CH-09 - UPGRADED.** The formatter now exists: sweep Wave 7 added
  `scripts/ui/player_text.gd`, whose `format_time_of_day()` (`:74-80`) returns
  `"%d:%02d %s"` and **keeps minutes**. `environment_hours.gd:128-135` still
  returns `"%d %s"` and **drops them**, and does not reference `PlayerText`. Two
  formatters, different behaviour. Route `_clock_label()` through
  `PlayerText.format_time_of_day()`, delete the local implementation, and assert
  that no production file outside `player_text.gd` formats an AM/PM string.
- **CH-10** - one shared `_route_is_affordable(bankroll, cost)` for both
  affordability checks in `run_terminal_evaluator.gd`.

### Phase 4 - Hot-path performance (CH-12, CH-13, CH-14)

- **CH-12** - `run_terminal_evaluator._create_game_module()` does
  `load()` -> `.new()` -> `setup()` (which deep-copies the definition) per
  `game_id` on every terminal evaluation, constructing an 8,636-line
  `BlackjackGame` to answer a boolean. Build
  `scripts/core/game_module_registry.gd` with **static capability queries**
  (`definition_declares_recovery_hook`, `definition_defers_bankroll_zero`)
  preferred over instances, absorb `run_generator._game_module_script_cache`,
  and add an `archetype_by_id` index to `ContentLibrary`.
- **CH-13** - `card_shoe.draw_cards()`/`card_array()` deep-copy every card in
  the shoe; a six-deck draw performs 312 dictionary deep copies. Copy the array
  shallowly and deep-copy only what is handed out.
- **CH-14** - add `RngStream.shuffled()` implementing Fisher-Yates over a
  shallow copy (the correct implementation already exists at
  `card_shoe.shuffle_cards()`), use it at the four sites that call
  `pick_many(x, x.size())`, and stop `pick_many` deep-copying.

### Phase 5 - Dead and misleading code (CH-17..CH-22)

- **CH-17** - `environment_runtime_scheduler.stale_pop_count` is declared,
  reset and reported but never incremented. Increment it where a stale entry is
  actually discarded, or delete it and its `debug_snapshot` key.
- **CH-18** - delete the two orphaned doc comments above
  `platform_services.unlock_achievement()`; they describe deleted cloud-save
  functions.
- **CH-19** - `cage_economy_model.gd:10` `ORIGINATION_FEE` is permanently 0 and
  published to the UI through `run_state.gd:4515` and
  `cage_atm_view_model.gd:36`. Remove it and both publications, or implement
  the fee.
- **CH-20** - delete `tutorial_flow.apply_caught_transition()` and its call
  sites (it ignores both arguments and returns `{}` on every path), collapse the
  `repair_legacy_frontier` alias, and decide the legacy blackjack-count
  migration: 0.5.1 is the last public release, so confirm whether any save can
  still reach it and delete it if not, recording the decision.
- **CH-21** - reformat `game_ritual_layout.gd` and `crew_turn_model.gd` to
  house style. **Isolated change, per D7.**
- **CH-22** - delete the 19 orphaned `.gd.uid` files.

### Phase 6 - Declarative serialization (CH-28)

Build `scripts/core/run_state_schema.gd` per report 3.6 and drive both
`RunState.to_dict()` (73 fields) and `from_dict()` (71 fields) from it, keeping
the environment/world-map compaction and exact-integer fields as explicitly
registered transforms. Add the symmetry gate from report 6.3, extended to
`UserSettings`, `ProfileInventory` and the meta collection store.

### Phase 7 - `IoResult` at the money boundaries (CH-27)

Build `scripts/core/io_result.gd`, adopt it in `DurableStore`,
`UserSettings.load`, `RunActionService` and `GameModule.apply_result`, and add
a `Keys` constants file for the ~40 highest-frequency dictionary keys (`id`
1,652 uses, `label` 349, `display_name` 313, `archetype_id` 292,
`bankroll_delta` 160). Make silent-failure returns `push_warning` in debug
builds. **Additive only, per D4.**

### Phase 8 - Scoped telemetry (CH-16)

`foundation_main._process()` contains its whole body twice - once behind
`if perf_telemetry_overlay == null` and once with `Time.get_ticks_usec()`
bracketing six subsystem calls. Introduce a no-op sink so there is one path,
plus a `_timed(name, callable)` wrapper that reads the clock only when the sink
is live.

### Phase 9 - Test harness (CH-24)

Add `_expect(condition, message, context)` to the shared foundation harness
(currently 7,379 `failures.append` against 236 `_fail(`), then split the
mega-functions along the `_check_*` boundaries already inside them. Start with
the **4,631-line** `_run()` at
`scripts/tests/ui_scene/compile_components_and_main_flow.gd:3722`.

### Phase 10 - God-object extraction (CH-26) - after the sweep only

Move the `crew_*` facade out of `run_state.gd`: 120 functions plus their
backing fields into a `CrewRunFacade` that `RunState` owns and forwards to. The
logic already lives in seven `crew_*_model.gd` files; only the facade stayed
behind, and `run_state.gd:8910-8930` shows how thin the delegators are. Then
`grand_*` (62), then `delivery_*` (28). For `foundation_main.gd`, extract the
`sealed_*` cluster (43 functions).

Mechanical moves only. No logic changes. Gate after each cluster.

### Phase 11 - Hygiene (CH-30..CH-36)

- **CH-30** - typed options object for the top ten of the 373 functions with six
  or more parameters, worst first (`slot_resolver._spin_result` at 17,
  `scenario_layout_resolver._authority_record` at 15).
- **CH-31** - doc comments on public functions in contract-owning files only;
  `scenario_host_transaction.gd` at 0/66 first. No blanket sweep.
- **CH-32** - move the 81 row-named one-shot tools to `tools/archive/<row-id>/`.
  A move, never a delete.
- **CH-33** - `docs/archive/<version>/` for completed-row plans and evidence.
- **CH-34** - write up the `branding/` custody options (388 MB tracked, 327 MB
  of it uncompressed WAV renders of procedurally generated music; `.git` is
  816 MB) as a short decision memo in the ledger. **Do not move or delete
  anything** - this is the owner's call.
- **CH-35** - add a `.tmp/` retention tool keeping the last N runs per stage.
  The rotation helper at `check_godot.ps1:359` already sorts by
  `LastWriteTimeUtc`. **Ship the tool; do not run a destructive sweep** (D8).
- **CH-36** - add `gdlint` config matching house style (tabs, one blank line
  between members, two between functions) and wire it into
  `validate_project.ps1`. Normalise the ~20 preload-constant naming stragglers.

---

## 7. New permanent gates (build these, they are the deliverable)

1. **Durable-store contract** (report 6.1) - for all five stores.
2. **Static source rules** in `validate_project.ps1` (report 6.2) - the six
   checks listed there are the exact sweeps that produced the audit; move them
   into the validator rather than reinventing them.
3. **Serialization symmetry gate** (report 6.3).
4. **Standalone contract stage** (report 6.4).

---

## 8. Verification ladder

Per phase: that phase's new regressions plus the suites owning the touched
systems. After the final phase, archived under `.tmp/health06_1/final/`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Contract -FoundationSuite contracts
powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot
powershell -ExecutionPolicy Bypass -File tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 200
```

Then a soak long enough to exercise the cache budgets from phase 2:

```powershell
powershell -ExecutionPolicy Bypass -File tools\foundation_soak_probe.ps1 -RequireGodot -SimMinutes 180 -ActionsPerSample 28
```

Idle-animation guard, mandatory whenever you touch draw or pause paths: a
reported idle cost of 0.000 is a red flag, not a win. Never accept an idle
number without a liveness counter proving the table is still animating.

---

## 9. Progress ledger - update this file in place as you go

Status values: `TODO` / `IN PROGRESS` / `DONE` / `PARTIAL` / `BLOCKED` /
`NOT REPRODUCED`.

| Phase | Findings | Status | Evidence / regression | Notes |
| --- | --- | --- | --- | --- |
| Baseline | section 5 capture | TODO | | |
| 0 DurableStore + Cluster A | CH-01, 02, 04, 05, 06 | TODO | | CH-03 resolved by sweep Wave 6 |
| 1 Dark contract suite | CH-23 | TODO | | 46 + 5 new sweep contracts = 51 dispositions |
| 2 Shared primitives | CH-29, 11 | TODO | | CH-15 withdrawn - see report 4.3 |
| 3 Correctness | CH-07, 08, 09, 10 | TODO | | |
| 4 Hot paths | CH-12, 13, 14 | TODO | | |
| 5 Dead code | CH-17, 18, 19, 20, 21, 22 | TODO | | |
| 6 Serialization | CH-28 | TODO | | |
| 7 IoResult | CH-27 | TODO | | |
| 8 Scoped telemetry | CH-16 | TODO | | `_process` null-branch now at `foundation_main.gd:702` |
| 9 Test harness | CH-24 | TODO | | |
| 10 God objects | CH-26 | TODO | | needs sweep Final verification DONE |
| 11 Hygiene | CH-30..36 | TODO | | CH-25 resolved by sweep Wave 3 |
| Final verification | section 8 ladder | TODO | | |

### CH-23 disposition table (fill during phase 1)

| Contract file | Ran? | Result | Disposition | Reason |
| --- | --- | --- | --- | --- |
| _(one row per dark contract)_ | | | | |

---

## 10. Final report (write it here, at the end of this file)

1. A row per finding: CH id, status, files changed, the regression that proves
   it, and for anything not `DONE` the exact remaining gap with evidence.
2. Baseline versus final gate comparison: which pre-existing failures you
   cleared, which remain, and proof that you introduced none.
3. The complete CH-23 disposition table - all 46 contracts accounted for.
4. Every decision made under rule 6, with the alternatives rejected.
5. Any file you touched that `fixsweep06_1` had also modified, and how you
   confirmed you did not clobber its work.
6. The complete list of changed and added files, still uncommitted, so the owner
   can review the diff in one pass.
7. Anything you found that the audit missed - stated plainly, fixed if in
   scope, recorded if not.
