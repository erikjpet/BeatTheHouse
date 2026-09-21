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
| Baseline | section 5 capture | DONE | `.tmp/health06_1/baseline/`: clean `main` at `65bda04a91fd3ea2c193bac72f73ed91c66ca9da`; validation exit 0 (106.3 s); Smoke exit 0, 10/10 stages (436.0 s); Contract/contracts exit 0, 4/4 stages (377.0 s); frozen summary JSON copied beside the verbatim logs/status/HEAD. | Fresh live-tree baseline is fully green; the audit's historical room/scenario known-red state was cleared by the completed fixsweep before this row began. No project Godot process was present. |
| 0 DurableStore + Cluster A | CH-01, 02, 04, 05, 06 | DONE | `.tmp/health06_1/phase0/`: failure-first contract exit 1 before `DurableStore`/`JsonCoerce`; `health06_1_durable_store_contract.gd` exit 0 after (all five stores, write/rename faults, backup loads, fresh reads, trust invalidation, malformed enums, placement reporting, root validation); existing audio-recovery contract exit 0; foundation shard ownership contract exit 0; final `validate_project.ps1` exit 0 (112.2 s). | CH-03 recovery semantics preserved. All production `store_string` sites now route through the one checked durable writer; profile/meta/settings backup recovery is surfaced. |
| 1 Dark contract suite | CH-23 | DONE | `.tmp/health06_1/phase1/`: standalone-gate regression failure-first logs for discovery, per-stage persistence isolation, serial shard execution, and serial budget; initial 51-contract census; focused repaired-contract reruns; final serial gate `final_contracts_gate_serial/summary.json` exit 0 with 52/52 stages, all 48 retained standalone contracts PASS and all 18 foundation shards PASS (1,063.159 s, below 2,024.349 s serial budget). | 51/51 dispositions recorded below: 41 passed unchanged, seven stale contracts repaired, three obsolete contracts deleted under D6. The audit missed that its shard launcher overlapped up to eight Godot jobs; it is now serial and its baseline is the captured sum of the 18 section-5 shard durations. |
| 2 Shared primitives | CH-29, 11 | DONE | `.tmp/health06_1/phase2/`: failure-first source/behavior regressions; `health06_1_shared_primitives_contract.gd` PASS; exact 440-script load check PASS; final `final_smoke_gate/summary.json` exit 0 with validation, import, exhaustive GDScript load, and foundation Smoke all PASS (7/7 checks, zero stderr issues). | Added bounded copy-isolating `StaticDataCache`; collection definitions now parse once and `CollectionDropService` holds one resolver. Consolidated the seven helper families into `JsonCoerce`/`GameModule`, retaining named whitespace, uniqueness, empty-string, UTF-8 hash, overflow-hash, and zero-hash compatibility policies where the old helpers intentionally differed. Split-runner composition now deduplicates the shared preload and view-model collaborators call it directly. CH-15 withdrawn - see report 4.3. |
| 3 Correctness | CH-07, 08, 09, 10 | DONE | `.tmp/health06_1/phase3/`: combined source contract failed before at CH-07 and passes after; `health06_1_correctness_contract.gd` PASS for valid/oversized/corrupt/unknown packages, guarded modifier conflicts plus load-time rejection, minute-preserving venue hours, and shared affordability boundaries; `final_smoke_gate/summary.json` exit 0 with all four stages PASS and foundation Smoke 7/7. | Package file count now has an explicit 64-entry security bound and structured failure results; IO failures emit errors. Numeric modifier conflicts deliberately replace a structured predecessor before later numeric accumulation, while authored conflicts fail validation. `EnvironmentHours` and the HUD fallback now use `PlayerText`; terminal travel uses the stricter existing leave-positive-bankroll rule for both world and local routes. |
| 4 Hot paths | CH-12, 13, 14 | DONE | `.tmp/health06_1/phase4/`: combined source contract failed before with all 16 CH-12/13/14 assertions and passes after; `health06_1_hot_paths_contract.gd` PASS for static capabilities/index refresh, card copy boundaries, and deterministic shallow shuffles; isolated `final_smoke_gate_isolated/summary.json` exit 0 with validation, import, exhaustive aggregate load, both foundation Smoke shards, UI compile, launcher/encounter/audio checks, and performance probe all PASS (10/10). | Added shared `GameModuleRegistry`, authored static recovery/defer capabilities, and explicit refresh-safe `archetype_by_id`; terminal checks now instantiate only capability candidates and RunGenerator delegates to the shared script cache. Card arrays/shoes retain shallow undrawn records and isolate only dealt cards. The four audited full selections use Fisher-Yates; the intentional order/layout digest change was rebaselined while route, economy, story, and final RNG state stayed fixed. The gate also exposed and fixed duplicate inherited `JsonCoerce` preloads and a stale rebuilt-menu test reference; non-isolated UI-user contamination is retained as Phase 9 before-evidence. |
| 5 Dead code | CH-17, 18, 19, 20, 21, 22 | DONE | `.tmp/health06_1/phase5/`: combined source regression failed first with all six findings and passes after; behavior regression PASS; both reformatted scripts pass check-only parsing; isolated `final_smoke_gate_retry/summary.json` exit 0 with all 10/10 Smoke stages PASS. | Removed the inert scheduler counter, orphan cloud comments, zero origination fee, and no-op caught transition; deleted all 22 live orphan `.gd.uid` files (the audit's 19 plus three Phase-1 obsolete-contract remnants). Collapsed the migration alias but retained one neutrally named migration because public 0.5.1 saves contain no release discriminator; its reachable repair is regression-covered without leaking game-specific vocabulary into Foundation. CH-21 was formatting-only. |
| 6 Serialization | CH-28 | DONE | `.tmp/health06_1/phase6/`: source and Godot symmetry regressions failed before and pass after; RunState check-only parse PASS; isolated `smoke_gate/summary.json` exit 0 with all 10/10 stages PASS. | Added one 71-field `RunStateSchema` used by both directions, with registered exact-integer and environment/world-map transforms plus explicit legacy-only inputs. Canonical payloads now always expose their full key set. Added declared-key/stable-round-trip coverage for `UserSettings`, `ProfileInventory` (including unknown-field retention), and the meta collection store. |
| 7 IoResult | CH-27 | DONE | `.tmp/health06_1/phase7/`: source/behavior contracts failed before and pass after; durable-store fault suite PASS; Smoke functional stages 9/9 PASS, with only one transient Baccarat idle p95 spike in the bundled perf stage; the identical 0-run/120-frame performance smoke retry PASS with live animation and full renderer/surface/resolve coverage. | Added validated `IoResult`, 40 highest-frequency `Keys` constants, and adopted the shape at DurableStore, `UserSettings.load`, RunActionService money results, and `GameModule.apply_result`. Former silent GameModule early exits now return typed failures; only message-less failures warn in debug builds, avoiding noise for expected, explained rejections. No draw/pause code changed. |
| 8 Scoped telemetry | CH-16 | DONE | `.tmp/health06_1/phase8/`: source/behavior regressions failed before and pass after; full UI flow compile PASS; exact 0-run/120-frame performance smoke PASS with nonzero live animation, 46 observations, and full renderer/surface/resolve coverage. | Added a permanent no-op sink and one `_timed` path; the disabled path executes operations without reading the clock, while the live overlay records the same subsystem names. Subsystem order and conditions are unchanged, and `_process` no longer has a telemetry-null duplicate. |
| 9 Test harness | CH-24 | DONE | `.tmp/health06_1/phase9/`: source/behavior regressions failed before and pass after; generated UI runner PASS; Smoke runtime/launchers/encounter/audio/performance PASS; function census and full validation retries PASS; focused generated Foundation content retry PASS. | Added reusable `FoundationTestHarness._expect(condition, message, context)` and adopted it in runner orchestration. Split the 4,631-line `_run` entry point into a small coordinator plus named component-preflight, Foundation-boot, and main-flow boundaries; generated-source composition still passes. Intentional scoped timing callables now carry the permanent per-frame-budget justification required by the existing gate. |
| 10 God objects | CH-26 | DONE | `.tmp/health06_1/phase10/`: initial ownership source/behavior regressions failed before and passed after; strengthened physical-extraction source regression failed before and passes after; focused facade behavior/save round-trip PASS; both original owners check-only parse PASS; final `physical_smoke_gate_retry/summary.json` exit 0 with all 10/10 stages PASS. | Sweep Final verification was confirmed DONE before work. `CrewRunFacade` now owns 121 crew function bodies and state, `GrandCasinoRunFacade` 63 Grand Casino/Rourke/Cage bodies and state, `DeliveryRunFacade` 28 delivery bodies and state, and `SealedActionHost` 44 sealed transaction-host bodies. `RunState` and `FoundationMain` retain compatibility forwarders only. The first composed content run exposed ref-count cycles from facade back-references; all three RunState facade owner links are now weak and the identical content shard plus full Smoke gate exit cleanly. No gameplay logic was intentionally changed. |
| 11 Hygiene | CH-30..36 | DONE | `.tmp/health06_1/phase11/`: combined hygiene regression failed before and passes after; permanent static-source-rules contract failed before and passes after; reused-profile UI regression failed before and passes after; exhaustive loader retry PASS; final isolated `smoke_gate_final/summary.json` exit 0 with all 10/10 stages PASS. Archive manifests: `tools/archive/health06_1_row_tools_manifest.json` (81 row tools) and `docs/archive/health06_1_docs_manifest.json` (1,436 documents/evidence artifacts). | Added typed options value objects for the ten worst live high-arity functions, contract-owner API comments, bounded cache declarations, official-style `.gdlintrc` plus validator integration, a dry-run-by-default `.tmp` retention tool, and all seven permanent audit source rules. Moved rather than deleted archival material; `branding/` remained byte-for-byte untouched. The combined gate exposed a missed consequence of Phase 0 backup recovery: the UI fixture removed its isolated primary profile but not `.bak`; it now clears both and passes against the same contaminated test root. CH-25 was resolved by sweep Wave 3. |
| Final verification | section 8 ladder | DONE | `.tmp/health06_1/final/`: restarted `validate_project.ps1` PASS (120.9 s), then post-whitespace validation PASS (116.9 s); `smoke_restart/summary.json` PASS 10/10 (431.1 s); `contracts_restart/summary.json` PASS 62/62, including all retained standalone contracts and all 18/18 Foundation contract shards (2,103.8 s); performance PASS with 75 observations and live-animation counters (`16_performance_report.json`, confirmed warning-free under the identical verbose sequence in `17_sequence_performance.json`); 200-seed stuck-state sweep PASS with 0 stuck states; 180-minute/504-action soak PASS with 0 orphan nodes, node growth 0, object growth -1 and cache cap 32. | The first final census correctly caught four stale regression surfaces after intentional remediation: a sealed-host override seam, two Blackjack fixture hashes, the Crew-ignored persistence golden, and the confrontation source fingerprint; each was repaired and rerun green before the authoritative ladder. One diagnostic performance retry recorded a non-reproducible Scratch p95 spike (5.32 ms vs 5.00); unchanged reruns measured 1.055 ms with 50 redraws/floor 8 and passed. No source budget was widened. |

### CH-34 branding custody decision

Decision: leave `branding/` byte-for-byte in place for this remediation and stop adding new uncompressed reference renders to Git. Existing clones already carry the 388 MB history, so moving or deleting the current 327 MB WAV set would create churn without shrinking `.git`. For future revisions, release-store custody is the safest default for trailer masters and reproducible reference renders; Git LFS is the fallback only when normal branch-to-branch asset versioning is genuinely required. Rejected alternatives: deleting the current files (destroys convenient provenance), moving them during this pass (outside the owner's explicit custody boundary), and continuing to commit 12 MB WAV revisions (permanently compounds every clone). No branding file was moved, deleted, rewritten, or staged by health06_1.

### CH-23 disposition table (fill during phase 1)

| Contract file | Ran? | Result | Disposition | Reason |
| --- | --- | --- | --- | --- |
| `scripts/tests/foundation/back_alley_fence_night_install_contract.gd` | Yes | FAIL | Deleted | Froze obsolete fixed-seed arrival geometry and the retired `HostileRawProjectionHost` dependency shape; current environment package and scenario-semantic contracts are the live replacement. |
| `scripts/tests/foundation/craps_full_table_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/craps06_3_depth_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/craps06_3_environment_integration_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/crew06_10_depth_contract.gd` | Yes | FAIL | Deleted | Directly drove the retired pre-sealed poker resolver/policy path; current scenario-registration and Hold'em production-host audits replace it. |
| `scripts/tests/foundation/crew06_10_scenario_registration_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/env06_6_cluster_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/env06_6_full_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/env06_6_r1_transaction_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/env06_6_v2_s2_authority_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/env06_7_package_b_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/env06_7_package_c_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/env06_7_package_d_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/env06_7_package_e_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/env06_7_production_authority_contract.gd` | Yes | FAIL | Deleted | Froze the pre-expansion manifest seed matrix and exact geometry; Packages B-E plus the scenario semantic/uniqueness contracts cover the live authority. |
| `scripts/tests/foundation/env06_8_environment_readability_check.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/fix06_26_crew_favor_cadence_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/game06_2_depth_contract.gd` | Yes | FAIL -> PASS | Updated + gated | Updated its source assertion to the live `_table_state(..., read_only_run_state, owns_table_state)` contract; focused rerun and the isolated census pass. |
| `scripts/tests/foundation/game06_2_repeated_reprieve_contract.gd` | Yes | FAIL -> PASS | Updated + gated | Repaired the inherited canonical fixture normalizer and current source/baseline hashes; focused rerun and the isolated census pass. |
| `scripts/tests/foundation/game06_3_depth_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/game06_4_machine_ritual_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/game06_6_bar_dice_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/game06_7_showdown_duel_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/integ06_1_v051_fixture_driver.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/integ06_1_v051_migration_smoke.gd` | Yes | FAIL -> PASS | Updated + gated | Removed the obsolete assumption that grounded migrated placements have no fallback IDs and added actionable diagnostics; focused rerun and the isolated census pass. |
| `scripts/tests/foundation/normal_grand_host_greeting_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/punchline_event_scope_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/scenario_uniqueness_boot_diagnostics_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/scenario_uniqueness_pair_precompute_contract.gd` | Yes | FAIL -> PASS | Updated + gated | Refreshed the production-authority source fingerprint after verified live-code changes; behavioral assertions remained green. |
| `scripts/tests/foundation/scenario_validation_memo_contract.gd` | Yes | FAIL -> PASS | Updated + gated | Refreshed the production-authority source fingerprint after verified live-code changes; behavioral assertions remained green. |
| `scripts/tests/foundation/world_sequence_adapter_spec_contract.gd` | Yes | FAIL -> PASS | Updated + gated | Added the four live required handlers (`grant_item`, `grant_cash`, `change_scene_object`, `play_cue`) and updated the companion contract document. |
| `scripts/tests/foundation/world_sequence_delivery_proof_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_2_delivery_depth_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_3_numbers_authored_semantics_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_3_numbers_depth_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_4_authored_semantics_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_4_hostile_authority_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_4_jobs_model_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_4_recruitment_model_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_5_plays_authored_semantics_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_5_plays_model_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_5_sweep_model_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_6_confrontation_surface_contract.gd` | Yes | FAIL -> PASS | Updated + gated | Refreshed its governing-prefix fingerprint after verified live-code changes; all behavior assertions pass. |
| `scripts/tests/foundation/world06_6_heist_authored_semantics_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_6_heist_surface_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/foundation/world06_7_hidden_information_contract.gd` | Yes | PASS | Retained + gated | Passed the initial census and the isolated standalone gate. |
| `scripts/tests/fixsweep06_1_accessibility_contract.gd` | Yes | PASS | Retained + gated first | Player-defect regression; explicitly prioritized and never eligible for deletion. |
| `scripts/tests/fixsweep06_1_audio_recovery_contract.gd` | Yes | PASS | Retained + gated first | Player-defect regression; explicitly prioritized and never eligible for deletion. |
| `scripts/tests/fixsweep06_1_lifecycle_contract.gd` | Yes | PASS | Retained + gated first | Player-defect regression; explicitly prioritized and never eligible for deletion. |
| `scripts/tests/fixsweep06_1_packaging_runtime_contract.gd` | Yes | PASS | Retained + gated first | Player-defect regression; explicitly prioritized and never eligible for deletion. |
| `scripts/tests/fixsweep06_1_player_text_contract.gd` | Yes | PASS | Retained + gated first | Player-defect regression; explicitly prioritized and never eligible for deletion. |

---

## 10. Final report

Completed 2026-09-21 against live baseline `65bda04a91fd3ea2c193bac72f73ed91c66ca9da`. No commit, push, stash, reset or revert was performed. All work remains uncommitted.

### 10.1 Finding disposition

| Finding | Status | Files changed | Regression / proof |
| --- | --- | --- | --- |
| CH-01 | DONE | `durable_store.gd`, `profile_inventory.gd`, `meta_collection_service.gd` | `health06_1_durable_store_contract.gd`: write/rename faults preserve the prior generation; corrupt primary recovers from `.bak`; fresh instances reread reported-success writes. |
| CH-02 | DONE | `durable_store.gd`, `save_service.gd`, `developer_placement_store.gd`, `profile_inventory.gd`, `meta_collection_service.gd`, `user_settings.gd`, `perf_telemetry_overlay.gd` | Durable-store contract plus permanent static rule reject production JSON `store_string` calls outside `DurableStore`. |
| CH-03 | RESOLVED | No new behavioral change; existing `user_settings.gd` recovery was preserved while moving storage under `DurableStore`. | Sweep BTH-050 regression plus Phase 0 malformed/backup settings cases pass. No remaining gap. |
| CH-04 | DONE | `json_coerce.gd`, `user_settings.gd` | Durable-store contract loads number, array and null enum values without typed-assignment failure and restores defaults. |
| CH-05 | DONE | `developer_placement_store.gd`, `durable_store.gd` | Forced write/rename failures now return failure and keep the previous placement bytes intact. |
| CH-06 | DONE | `persistence_paths.gd` | Contract accepts absolute and `user://` isolation roots and rejects relative, empty and traversal roots. |
| CH-07 | DONE | `world_sequence_package_catalog.gd` | Correctness contract covers valid, oversized, unreadable/corrupt and unknown-id package outcomes against explicit `MAX_PACKAGES_PER_FILE`. |
| CH-08 | DONE | `item_effect.gd`, `content_library.gd` | Correctness contract proves guarded structured-to-numeric replacement and authored key-type conflict rejection at load. |
| CH-09 | DONE | `environment_hours.gd`, `player_text.gd`, `foundation_hud_view_model.gd` | Correctness/static contract proves minute-preserving canonical AM/PM formatting and rejects production-local formatters. |
| CH-10 | DONE | `run_terminal_evaluator.gd` | Correctness contract proves one `_route_is_affordable` boundary for world and local travel, including exact-bankroll rejection. |
| CH-11 | DONE | `static_data_cache.gd`, `collection_item_resolver.gd`, `collection_drop_service.gd` | Shared-primitives contract proves one bounded parse cache, copy isolation and one resolver per drop service. |
| CH-12 | DONE | `game_module_registry.gd`, `game_module.gd`, game modules, `content_library.gd`, `run_terminal_evaluator.gd`, `run_generator.gd`, `data/games/games.json` | Hot-path contract proves static capability lookup, refresh-safe archetype indexing and no capability-only module construction. |
| CH-13 | DONE | `card_shoe.gd` | Hot-path contract proves shallow undrawn storage with isolated dealt cards and stable behavior. |
| CH-14 | DONE | `rng_stream.gd`, `environment_instance.gd`, `environment_event_resolver.gd` | Hot-path contract proves deterministic shallow Fisher-Yates selection; full Smoke and contract census validate rebaselined ordering. |
| CH-15 | WITHDRAWN | No remediation required; `static_data_cache.gd` still establishes the convention used by CH-11. | Re-verification confirms the named caches are evicted, reset, single-entry or finite-vocabulary. No remaining gap. |
| CH-16 | DONE | `foundation_main.gd`, `perf_telemetry_overlay.gd` | Scoped-telemetry contract proves one subsystem path, zero clock reads when disabled and matching live attribution when enabled. |
| CH-17 | DONE | `environment_runtime_scheduler.gd` | Dead-code contract proves the permanently-zero metric and snapshot key are absent. |
| CH-18 | DONE | `platform_services.gd` | Dead-code/static orphan-comment regression passes. |
| CH-19 | DONE | `cage_economy_model.gd`, `run_state.gd`, `cage_atm_view_model.gd` | Dead-code contract proves the zero origination-fee concept is absent from model, state and UI. |
| CH-20 | DONE | `tutorial_flow.gd`, production call sites | Dead-code behavior contract proves the no-op caught transition is gone and the reachable neutral 0.5.1 migration still repairs old saves. |
| CH-21 | DONE | `game_ritual_layout.gd`, `crew_turn_model.gd` | Dedicated format-only phase contract plus check-only parsing and full contract census. |
| CH-22 | DONE | 22 orphan `.gd.uid` files removed (the audited 19 plus three obsolete Phase 1 contract UIDs). | Dead-code contract rescans the live tree and reports zero orphan UIDs. |
| CH-23 | DONE | `check_godot.ps1`, `foundation_systems_shards.ps1`, `split_test_runner_helpers.ps1`, repaired/deleted standalone contracts | Standalone source gates failed first; final `contracts_restart/summary.json` passes all 62 stages, including every retained standalone contract and 18/18 serial Foundation shards. The 51-row table above is the complete corrected census. |
| CH-24 | DONE | `foundation_test_harness.gd`, `compile_components_and_main_flow.gd`, generated-runner helpers | Test-harness contract proves `_expect` and split orchestration; generated UI runner and final Smoke pass. |
| CH-25 | RESOLVED | No new behavioral change; the sweep's collision metadata was preserved. | Final Smoke/game contracts pass; no remaining gap. |
| CH-26 | DONE | `crew_run_facade.gd`, `grand_casino_run_facade.gd`, `delivery_run_facade.gd`, `sealed_action_host.gd`, `run_state.gd`, `foundation_main.gd` | God-object source/behavior contract proves physical ownership of 121/63/28/44 bodies, compatibility forwarders and save round-trips; final Smoke and full census pass without ref-count leaks. |
| CH-27 | DONE | `io_result.gd`, `keys.gd`, `durable_store.gd`, `user_settings.gd`, `run_action_service.gd`, `game_module.gd` | IoResult source/behavior contract proves validated result shapes, constants and explicit money-boundary failures; final runtime-economy shard passes without silent-failure warnings. |
| CH-28 | DONE | `run_state_schema.gd`, `run_state.gd`, `user_settings.gd`, `profile_inventory.gd`, `meta_collection_service.gd` | Serialization contract proves the 71-field declared schema, exact key sets, transforms, unknown-field policy and stable round trips. |
| CH-29 | DONE | `json_coerce.gd`, `game_module.gd` and migrated core/game/UI/test callers | Shared-primitives source/behavior contract and exhaustive script load prove the seven duplicate helper families are centralized while compatibility policies remain explicit. |
| CH-30 | DONE | `function_options.gd` plus the ten owning call sites (`slot_resolver`, `scenario_layout_resolver`, `blackjack`, `slot_renderer`, `video_poker_renderer`, `video_poker`, `run_state`, `scenario_sequence_runtime`, `bar_dice`) | Hygiene contract proves typed option values replace the ten worst live positional signatures; final exhaustive load and contract census pass. |
| CH-31 | DONE | Contract-owning public API files, led by `scenario_host_transaction.gd` | Hygiene/static rules require public contract-owner comments; validation passes. |
| CH-32 | DONE | 81 row-named tools moved under `tools/archive/`; `tools/archive/health06_1_row_tools_manifest.json` | Hygiene contract verifies every manifest source/destination and the 14 allowed top-level tool families. Nothing was deleted. |
| CH-33 | DONE | 1,436 completed documents/evidence artifacts moved under `docs/archive/`; `docs/archive/health06_1_docs_manifest.json` | Hygiene contract verifies the manifest and live-doc allowlist. Nothing was deleted. |
| CH-34 | DONE | This prompt's custody memo only; `branding/` unchanged. | Hygiene contract hashes/custody assertions pass; decision recorded below. |
| CH-35 | DONE | `tools/rotate_tmp_runs.ps1` | Hygiene contract proves dry-run default, explicit `-Apply`, bounded keep count and protected `reports/`/`builds/`; no destructive sweep was run. |
| CH-36 | DONE | `.gdlintrc`, `validate_project.ps1`, preload-constant call sites | Hygiene and permanent static-rule contracts pass; validator uses gdlint when installed and keeps repository-native enforcement otherwise. No dependency was vendored. |

All findings are `DONE`, `RESOLVED`, or correctly `WITHDRAWN`; there is no `PARTIAL`, `BLOCKED`, or remaining implementation gap.

### 10.2 Baseline versus final gates

| Gate | Section 5 baseline | Final |
| --- | --- | --- |
| `validate_project.ps1` | PASS, 106.3 s | PASS, 120.9 s; post-whitespace PASS, 116.9 s (`final/05_validate_project_restart.log`, `final/21_validate_after_whitespace.log`) |
| Smoke | PASS, 10/10, 436.0 s | PASS, 10/10, 431.1 s (`final/smoke_restart/summary.json`) |
| Contract/contracts | PASS, 4 aggregate stages, 377.0 s; standalone contracts were not yet gated | PASS, 62/62, 2,103.8 s: all retained standalone contracts plus 18/18 Foundation shards (`final/contracts_restart/summary.json`) |
| Performance | Not a separate baseline rung | PASS, 75 observations; full renderer/surface/resolve coverage and nonzero animation liveness (`final/16_performance_report.json`, clean verbose confirmation `final/17_sequence_performance.json`) |
| Stuck-state sweep | Not captured | PASS, 200 seeds, 48 slot scenarios, nine wait-state families, 0 stuck (`final/09_stuck_state.log`) |
| Soak | Not captured | PASS, 180 simulated minutes, 504 actions, 19 samples, 0 orphans, node growth 0, object growth -1, bounded cache 32 (`final/10_soak.log`) |

The live section-5 baseline was already green because fixsweep had cleared the historical room/scenario failures before health remediation began. Therefore there were no pre-existing live gate failures to hide or waive. The new failure-first regressions reproduced every live CH defect before its fix. During final verification the expanded census found and corrected four stale compatibility/fixture guards; the authoritative rerun is fully green. No final gate failure remains and no budget was loosened. A single diagnostic performance retry recorded a non-reproducible 5.32 ms Scratch p95 sample; unchanged runs before and after passed, with the accepted rerun at 1.055 ms and 50 redraws against a floor of 8.

### 10.3 CH-23 complete census

The canonical table immediately above Section 10 contains **51/51 rows**: the audit's 46 dark contracts plus the five `fixsweep06_1_*` contracts. Disposition totals are 41 retained unchanged, seven repaired and gated, and three obsolete contracts deleted with individual reasons. The audit text saying “all 46” is superseded by binding decision D6 and the live 51-row census. The final gate proves all 48 retained standalone files run serially and pass; none remains dark.

### 10.4 Decisions made under rule 6

- CH-08: runtime merge deliberately replaces an incompatible structured predecessor when a numeric modifier arrives, while authored conflicts fail ContentLibrary validation. Rejecting every runtime merge was less compatible; silently adding incompatible variants was unsafe.
- CH-17: removed the permanently-zero metric instead of inventing semantics not established by the scheduler.
- CH-19: removed the zero fee from model/state/UI instead of creating an unrequested economy change.
- CH-20: retained one neutrally named reachable migration because public 0.5.1 saves have no release discriminator; deleting it could strand real saves, while retaining the game-specific alias would preserve misleading API vocabulary.
- CH-23: retained/fixed any contract that still expressed live authority; deleted only the three obsolete contracts identified in the table. Wholesale deletion and leaving failures dark were rejected.
- CH-26: kept compatibility forwarders on the original owners, used weak owner references in RunState facades, and preserved the overridable sealed-host boundary. Removing public seams or keeping strong cycles was rejected.
- CH-32/33: moved provenance into versioned archives with manifests. Deletion was rejected; leaving all row artifacts in active roots was rejected.
- CH-34: left `branding/` byte-for-byte in place and recorded release-store custody as the future default. Deletion/move in this row and continued large WAV revisions were rejected.
- CH-35: shipped dry-run-by-default retention with explicit apply. Running a destructive cleanup in this row was rejected by D8.
- CH-36: added configuration and an optional validator hook with repository-native fallback. Vendoring a linter or making an unavailable dependency fail validation was rejected by D9.
- Final performance: did not widen the 5.00 ms Scratch budget after one noisy 5.32 ms sample; unchanged reruns passed and retained mandatory liveness proof.

### 10.5 Fixsweep overlap and non-clobber proof

The exact 41-path intersection between fixsweep commits `4384378a..65bda04a` and the health worktree is frozen at `.tmp/health06_1/final/18_fixsweep_overlap_paths.txt`. It includes the expected high-risk owners (`run_state.gd`, `foundation_main.gd`, `game_module.gd`, `run_action_service.gd`, `save_service.gd`, `user_settings.gd`, scenario/layout/game/UI contracts and the gate scripts). Each was reread from the live tree before its phase edit. Compatibility was then proved by the five prioritized fixsweep standalone contracts, the retained scenario/game contracts, final Smoke 10/10, and the authoritative 62/62 contract run. The final census specifically caught and repaired the sealed-host override seam rather than allowing extraction to bypass a fixsweep test override. Baseline was clean and no owner edit arrived during a phase, so no unrelated uncommitted delta was overwritten.

### 10.6 Complete uncommitted file manifest

The complete current worktree is frozen for one-pass review in:

- `.tmp/health06_1/final/22_final_git_status.txt` - exact porcelain status (1,255 entries: 390 modified, 823 deleted source paths participating in moves, 42 collapsed untracked roots).
- `.tmp/health06_1/final/22_tracked_changed_paths.txt` - all 1,091 tracked changed/deleted paths.
- `.tmp/health06_1/final/22_untracked_added_paths.txt` - all 862 individual added paths, expanding untracked directories.
- `.tmp/health06_1/final/22_final_git_diff_stat.txt` - final tracked diff statistic.
- `tools/archive/health06_1_row_tools_manifest.json` and `docs/archive/health06_1_docs_manifest.json` - exact source/destination mappings for all 81 tool moves and 1,436 document/evidence moves.

These manifests include the archive moves and every source, test, fixture, tool and configuration addition. All remain uncommitted; no staging, commit or push occurred.

### 10.7 Audit misses found during remediation

- CH-23's reported “46” became 51 after the five fixsweep contracts landed; the final table and gate use 51.
- The Foundation shard launcher overlapped up to eight Godot jobs despite the one-process rule. The gate is now serial and budgeted against the captured sum of shard baselines.
- Durable backup recovery exposed a contaminated UI fixture that removed its primary profile but not `.bak`; the fixture now clears both and passes from the same reused root.
- Initial facade extraction created ref-count cycles through strong owner references; weak references removed them and the same Smoke/content paths exit cleanly.
- Physical extraction initially bypassed a test subclass override at the sealed-action boundary; the host now calls the Foundation seam, preserving polymorphic compatibility.
- Intentional serialization and authored-data changes invalidated two Blackjack hashes, the Crew-ignored golden and one source fingerprint. Each was recaptured only after behavior/source invariants passed, then proved in the full census.
- The Foundation expected unsupported-service fixture produced a deliberately message-less failure, which correctly triggered the new CH-27 debug warning and polluted a fail-closed shard. The fixture now supplies an explicit error code/message; production warning behavior remains intact.
- `gdlint` is not installed on this workstation. The validator reports that fact, continues enforcing the repository-native equivalent rules, and will invoke gdlint automatically when available, as required by D9.
- The performance wrapper can emit a transient post-pass ObjectDB cleanup line in non-verbose mode. The identical editor-refresh plus full eight-run probe sequence passes under verbose cleanup reporting with no ObjectDB/RID diagnostics (`17_sequence_editor.log`, `17_sequence_probe.log`); gameplay/runtime ownership is clean. One separate timing retry also produced a non-reproducible Scratch p95 outlier, recorded rather than hidden.
