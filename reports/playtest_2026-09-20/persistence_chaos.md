# Beat the House — Persistence, Interruption, and Chaos Playtest Report

**Date:** 2026-09-20  
**Tester:** `persistence_chaos` wave-two specialist  
**Build under test:** current dirty worktree at `4384378a00d2e81e259aa28ae01ffbbc7cf21fd5`  
**Runtime:** Godot 4.6 stable (`89cea1439`), Windows 10  
**Disposition:** **0 confirmed player-facing persistence defects**. The broad systems run's persistence failures are reproducible test-harness defects, not failures of the shipped `SaveService` path.

## Scope and method

The regimen covered save/load across dynamic scenario queues, repeated disk generations, restored travel, travel locks, pending and active triggered events, forced-closing state, custom challenge modifiers, and failed-run terminal state. It also reviewed the broad systems failures for Bar Dice mid-step continuation, world-map snapshot restore, travel-lock restore, pending/active event restore, challenge modifier restore, dialogue/talk state, and closing-time flow.

The decisive comparison was between:

1. the broad fuzz harness's `RunState.to_dict() -> JSON.stringify -> JSON.parse -> RunState.from_dict()` shortcut; and
2. the player path, `SaveService.save_run() -> RunSaveCodec.encode()/pack_for_storage() -> disk -> unpack/decode -> RunState.from_dict()`.

Every disk-backed probe used an isolated persistence root. Two independent seeds were run, and each was saved/loaded through two consecutive generations. Runtime execution was serialized with the other playtest workers.

## Confirmed product bugs

None in this specialty.

The broad systems report contained 41 save/interruption failures, but its most serious-looking cluster (GP-02, pending scenario facts disappearing) does not occur through the shipped save codec. No persistence issue below met the playtest standard of a player-realistic two-run reproduction.

## GP-02 — Pending dynamic-scenario facts are **not** lost by production saves

**Classification:** Excluded; harness-only false positive  
**Broad-run symptom:** `scenario_sequence_state.fact_queue size 1 != 0` on six checkpoints, followed by normalization non-idempotence reports.  
**Broad-run reproducibility:** 4/4 fuzz seeds showed related raw-JSON failures.  
**Production-path reproducibility:** 0/2 seeds; 0/4 disk restore generations.

### Corrected evidence

The actual `SaveService` probe entered a dynamic-scenario room, added a player-equivalent pending heat fact, and observed an existing arrival fact plus the new fact. Queue sizes were:

| Seed | Before disk save | First disk restore | Second disk restore | Loaded-1 vs loaded-2 mismatch |
|---|---:|---:|---:|---|
| `PERSIST-QUEUE-0` | 2 | 2 | 2 | none |
| `PERSIST-QUEUE-1` | 2 | 2 | 2 | none |

The raw probe JSON labels these rows failed because its first assertion incorrectly expected exactly one queued fact; the observations themselves show preservation at `2 -> 2 -> 2`. The first fact was the production arrival fact, so two was the correct pre-save value.

### Root cause of the false positive

The fuzz checkpoint in `scripts/tests/foundation/check_lenders_release_saves.gd:5567-5584` serializes `run_state.to_dict()` directly through JSON and sends the parsed dictionary straight to `RunState.from_dict()`. JSON materializes numbers without preserving Godot's integer type.

Dynamic scenario restore intentionally validates the exact typed envelope. `scripts/core/scenario_sequence_runtime.gd:2403-2415` rejects a queued fact unless `ingress_serial` is a positive `TYPE_INT`. Consequently, the raw-JSON shortcut turns that field into a float and the strict normalizer discards the fact.

The shipped path is different. `scripts/core/save_service.gd:328-335` passes `to_save_snapshot()` through `RunSaveCodec.encode()` and storage packing. `scripts/core/run_save_codec.gd:204-216` routes every `scenario_*` value through `_encode_exact_integers()`, whose implementation at lines 392-409 wraps exact integers before JSON. Load reverses the codec before constructing `RunState` (`scripts/core/save_service.gd:340-371`).

### Recommended test fix

Change the fuzz checkpoint to exercise `SaveService` or the complete `RunSaveCodec.encode -> pack -> unpack -> decode` path. Keep the strict `TYPE_INT` validation; weakening scenario authority validation would hide malformed or tampered saves.

### Evidence

- `.tmp/playtest_2026-09-20/gameplay_progression/systems_1/systems.json`
- `.tmp/playtest_2026-09-20/persistence_chaos/persistence_probe.json`
- `.tmp/playtest_2026-09-20/persistence_chaos/actual_save_probe_2/console.log`

## EX-02 — Repeated RunState normalization failures are raw-JSON artifacts

**Classification:** Excluded; harness-only  
**Broad-run symptom:** non-idempotence after a second direct `RunState.from_dict()` across fuzz actions, Blackjack count state, world-map snapshot, travel lock, pending/active event, and challenge modifier fixtures.  
**Production result:** both seeds produced no mismatch between the complete loaded snapshot after disk generation one and the complete loaded snapshot after disk generation two.

### Root cause

The same checkpoint bypasses the save codec at `check_lenders_release_saves.gd:5569-5584`. It therefore tests an unsupported raw dictionary/JSON boundary, not the save format installed by `SaveService`. The production codec restores exact typed scenario authority before `RunState.from_dict()`.

The custom challenge's numeric modifier types did become ordinary JSON numbers on the first disk load (for example, `starting_bankroll` changed from Godot `TYPE_INT` to `TYPE_FLOAT`), but all gameplay consumers explicitly cast these values (`scripts/core/run_state.gd:4917-4925`), semantic values were unchanged, and the first and second loaded snapshots were identical. No player-visible effect was found.

### Recommended test fix

Define two separate contracts: (a) codec-backed player persistence, which should be byte/typed stable after decoding, and (b) permissive raw-dictionary migration, which should compare semantic values rather than exact numeric Variant types outside authority-bearing roots.

## EX-03 — Motel-to-Jazz-Club continuation selects a non-player-valid route

**Classification:** Excluded; harness route-selection bug  
**Broad-run symptom:** four `Travel destination was not installed` failures, always attempting Motel to Jazz Club.  
**Production result:** restored runs selected a production-available route and traveled successfully in 2/2 seeds (`gas_station_casino` and `bar`).

### Root cause

The fuzz driver iterates `WorldMap.travel_target_ids()` and checks only `travel_route_status()` (`check_lenders_release_saves.gd:5469-5485`). It omits the production availability predicate in `scripts/core/run_generator.gd:1007-1019`, which also verifies that the target survives the actual travel-card selection, is neither hidden nor locked, and will be open at arrival time. Passing the incomplete candidate into real travel correctly leaves the current room installed, after which the harness reports a continuation failure.

### Recommended test fix

Select destinations through the production travel view model or `_world_target_is_available()` equivalent before calling travel. Preserve the production rejection behavior.

## EX-04 — Bar Dice controlled-roll “mid-step” fixture does not persist its mid-step

**Classification:** Excluded; invalid fixture  
**Broad-run symptom:** restored clone could not continue for step zero.  
**Frequency:** 1/1 targeted fixture.

### Root cause

The fixture creates the controlled-roll challenge in local `ui_state` (`scripts/tests/foundation/check_slots_surfaces.gd:1954-1978`). The save/load test then passes only `dice_run` into `_save_load_checkpoint()` (`scripts/tests/foundation/check_lenders_release_saves.gd:5859-5866`), discarding the very UI state that makes the fixture “mid-step.” Its generic continuation routine is therefore not testing restoration of the stated condition.

Production autosave preparation asks the active game to checkpoint its UI state before saving (`scripts/ui/foundation_main.gd:6722-6724`). The fixture must exercise that lifecycle or explicitly verify the intended cancel/restart behavior for transient, uncommitted control input.

### Recommended test fix

Drive Bar Dice through `FoundationMain`, trigger the real autosave boundary, restart the application surface, and assert the authored behavior (resume, safely cancel, or restart without charging the player). Do not label a RunState-only fixture as controlled-roll mid-step persistence.

## EX-05 — Talk, dialogue, and closing-time failures are fixture lifecycle defects

**Classification:** Excluded from product bug count  
**Evidence:** the broad systems run reported 2 TalkDock, 3 dialogue-effect, and 2 closing-time failures. An isolated TalkDock check reproduced its two assertions, confirming that this is independent of save/load.

The TalkDock test instantiates `FoundationMain`, assigns `library` and `run_state`, and calls `_refresh_talk_dock()` without entering the production environment/game screen lifecycle (`scripts/tests/foundation/check_items_events_world.gd:898-921`). The result is not a player navigation path. The adjacent dialogue fixture constructs a synthetic event payload, and the closing fixture directly swaps internal app/run fields. These failures are useful test-maintenance signals but were not counted without a player-realistic reproduction.

### Recommended test fix

Enter the environment through the public Foundation flow, wait for one rendered frame, and exercise the visible TalkDock/closing dialogue controls. Build dialogue choices with the current production event schema instead of a private synthetic shortcut.

## Passed persistence matrix

| Area | Repetitions | Result | Evidence |
|---|---:|---|---|
| Actual SaveService repeated disk generations | 2 seeds × 2 generations | PASS; loaded snapshots identical | `persistence_probe.json` |
| Pending dynamic-scenario fact queue | 2 seeds × 2 generations | PASS; `2 -> 2 -> 2` | `persistence_probe.json` |
| Legal travel after repeated restore | 2 | PASS | `travel_0`, `travel_1` observations |
| Active travel lock | 2 | PASS; remaining actions stayed `2` | `states_0`, `states_1` |
| Forced-closing state | 2 | PASS | `states_0`, `states_1` |
| Pending then active triggered event | 2 | PASS | `states_0`, `states_1` |
| Failed-run terminal status and reason | 2 | PASS | `states_0`, `states_1` |
| Standard SaveService foundation round trip | 1 broad-suite execution | PASS | `systems_1/systems.json` |
| Travel-route foundation | 1 broad-suite execution | PASS | `systems_1/systems.json` |
| World-map foundation | 1 broad-suite execution | PASS | `systems_1/systems.json` |
| Run report | 1 broad-suite execution | PASS | `systems_1/systems.json` |
| Demo boss objective / terminal victory | 1 broad-suite execution | PASS | `systems_1/systems.json` |
| Recovery/loss pressure | 1 broad-suite execution | PASS | `systems_1/systems.json` |

## Limitations

- Headless probes validate authority and continuation, not the visual appearance of the Continue flow.
- No tracked game, source, or data file was modified and no bug was fixed.
- The custom probe script and its isolated save data live only under `.tmp/playtest_2026-09-20/persistence_chaos`.
- The broad systems report remains valuable for identifying harness gaps, but its raw-JSON persistence failures must not be entered as player bugs without codec-backed reproduction.

## Final recommendation

Do not file GP-02 or the associated non-idempotence/travel cascade as product bugs. File one test-infrastructure work item to route save fuzz through the shipped codec and production destination filter, and one fixture work item to make Bar Dice/TalkDock/closing-time checks use the actual UI lifecycle. The current player persistence path passed every independently exercised state in this regimen.
