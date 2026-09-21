# Beat the House — Extended Performance, Memory, and Liveness Soak

**Playtest date:** 2026-09-20  
**Candidate commit:** `4384378a00d2e81e259aa28ae01ffbbc7cf21fd5`  
**Scope:** Long-session performance, retained-memory behavior, save/load stability, repeated environment travel, game-action liveness, cache bounds, and failure recovery  
**Disposition:** Three retained defects; no product files changed and no fixes attempted

## Executive summary

Three independent 360-simulated-minute foundation soaks completed. Each run performed 1,008 measured actions after a separate 1,008-action prewarm. Across the three runs, the workload executed 6,048 action attempts, including 2,193 game actions, 1,868 travel attempts, 258 save/load cycles, 131 generated runs, and 1,484 environment revisits.

The principal performance result is positive: the candidate did **not** exhibit an unbounded retained-memory, node, resource, serialized-state, or cache-growth failure. All three soak reports passed their configured performance gates. The strongest diagnostic run ended with a 3,317,632-byte retained-memory increase, 21 additional objects, four additional resources, six additional nodes, and zero orphan nodes. Its fitted retained-memory tail slope was only 3,120.6 bytes per ten-minute sample, well below the 262,144-byte cap. Serialized run state peaked at 1,071,562 bytes against a 1,500,000-byte cap. Pinball sessions remained capped at 32 and Slot background textures remained capped at six.

The soak nevertheless found a high-impact state-integrity defect. During long dynamic-room sessions, an immutable scenario semantic proof is refreshed using live Numbers/character/delivery context. When that live context changes, the regenerated digest no longer matches the stored proof. The game invalidates the semantic proof, rejects travel to routes that the map still presents as enabled, and later rejects unrelated game actions in the affected room. This failure appeared as 132, 128, and 122 no-move travel warnings in the three independent runs. The final instrumented run established that all 122 warnings were real production confirmation failures with the exact error `scenario semantic inventory version or digest changed; explicit migration is required`; none were attempts to select a disabled route.

Two secondary defects were also retained. Ten recovery failures across the first two soaks show that Coin Pusher's compact rollback can reject its own token after a failed environment-turn boundary, risking partial live-machine mutation. Separately, the shared sealed-action host exposes Blackjack-specific failure messages while the player is using Slot or Bar Dice, obscuring the actual failing system.

## Severity and priority

| ID | Severity | Priority | Summary | Reproduction |
|---|---:|---:|---|---|
| EXT-PERF-001 | High | P1 | Dynamic-room semantic digest drift blocks enabled travel and cascades into rejected game actions | Three long runs; 382 no-move warnings total; exact confirm failure captured 122/122 times in diagnostic run |
| EXT-PERF-002 | Medium | P2 | Coin Pusher compact rollback can fail after a rejected turn boundary | Four failures in soak A and six in soak B; schedule/state dependent and absent with diagnostic seed |
| EXT-PERF-003 | Low | P3 | Shared action host reports Blackjack-specific errors in Slot and Bar Dice | 82 wrong-game messages in final diagnostic run |

## Test design

### Runtime regimen

Each of the three long runs used the same workload shape but an independent deterministic seed prefix:

- 360 simulated minutes;
- one sample every ten simulated minutes, for 37 samples including the baseline;
- 28 measured actions per interval, for 1,008 measured actions;
- 1,008 additional workload-prewarm actions before measurement;
- 30 settle frames before each retained measurement;
- repeated run generation, travel, environment revisit, game, service, lender, item, event, save, and load operations;
- explicit stress of Pinball session caches and Slot autoplay/background texture caches;
- process-level stderr capture and post-run process-liveness verification.

The final run used a diagnostic subclass of the existing soak probe. It did not change product behavior. When a travel attempt did not move the player, it recorded the selected target, the target's enabled status, all presented choices, the result returned by `confirm_world_map_travel()`, the current node, and the run message. When a game action did not advance its turn, it recorded the game, action, state hashes, scenario state, run status, and result message. This made it possible to distinguish expected refusals from product failures without counting every refusal as a bug.

### Static and targeted performance coverage

Before the long soaks, the following performance contracts passed:

- `perf06_budget_contract_test.ps1`;
- `perf06_phase_qualification_contract_test.ps1`;
- `perf06_required_matrix_contract_test.ps1`;
- `perf06_allocation_contract_test.ps1`;
- `perf06_allocation_call_root_audit.ps1`.

The allocation audit covered all seven registered hot call roots. None contained forbidden direct deep-copy, JSON serialization, artificial delay, or callable-indirection patterns. The existing current-candidate surface probe also completed with no failures across all 11 game surfaces and ten resolve paths. Coin Pusher's native backend, ceiling refusal, incremental update, and active-sequence checks passed. Scratch Tickets reached 5.374 ms against its 6 ms low-end pointer budget; Blackjack averaged 3.708 ms against its 4.5 ms resolve budget. Both are worth watching, but neither crossed a gate or reproduced as a user-visible slowdown and neither is retained as a defect.

## Long-run measurements

| Metric | Soak A | Soak B | Diagnostic soak |
|---|---:|---:|---:|
| Result | Pass | Pass | Pass |
| Simulated minutes | 360 | 360 | 360 |
| Measured actions | 1,008 | 1,008 | 1,008 |
| Prewarm actions | 1,008 | 1,008 | 1,008 |
| Total game actions | 684 | 725 | 784 |
| Total travel attempts | 616 | 624 | 628 |
| Save/load operations | 86 | 86 | 86 |
| Generated runs | 45 | 45 | 41 |
| Retained-memory change | +2,640,254 B | +2,775,338 B | +3,317,632 B |
| Retained-memory tail slope | +47,894.3 B/sample | +16,608.5 B/sample | +3,120.6 B/sample |
| Retained object change | +17 | +13 | +21 |
| Retained resource change | +1 | 0 | +4 |
| Retained node change | +4 | +4 | +6 |
| Orphan nodes at tail | 0 | 0 | 0 |
| Maximum serialized state | 1,071,562 B | 1,071,562 B | 1,071,562 B |
| No-move travel warnings | 132 | 128 | 122 |
| Compact rollback errors | 4 | 6 | 0 |

The apparent retained deltas are bounded initialization/cache plateaus, not continuing growth. In soak A and B, object, resource, and node tail slopes were all zero. In the diagnostic run, the final tail slopes were 0.286 objects, 0.143 resources, and zero nodes per sample, all within their configured limits. The diagnostic retained baseline stabilized around 337.4 MB for most of the run, then stepped to roughly 338.7 MB as a small number of additional resources and nodes were first encountered; it remained flat thereafter.

## Confirmed defects

### EXT-PERF-001 — Dynamic-room semantic digest drift blocks enabled travel and cascades into game-action rejection

**Severity:** High  
**Priority:** P1  
**Systems:** Dynamic room sequences, scenario semantic inventory, world-map travel, save/load, environment game preflight  
**Player impact:** A live run can enter a partially soft-locked state. Routes remain visible and enabled, but confirmation leaves the player in place and displays an internal migration error. Once the proof is invalidated, Coin Pusher and Pull Tabs actions in the affected room can also be rejected. Repeated attempts and save/load cycles do not repair the invalidated proof.

#### Observed behavior

Across the three independent soaks, 382 travel attempts selected a presented destination but did not change the current node. The instrumented diagnostic run captured all 122 of its failures at the production confirmation boundary:

- the requested target was present in `travel_enabled_node_ids`;
- the matching travel choice had `enabled: true` and an empty `disabled_reason`;
- target selection succeeded;
- `confirm_world_map_travel()` returned `{ok: false}`;
- the sole error was `scenario semantic inventory version or digest changed; explicit migration is required`;
- current node, run status, and selected-node state showed that the travel did not occur.

Diagnostic route distribution:

| Current node | Enabled target | Count | Confirmation result |
|---|---|---:|---|
| Bar | Back Alley | 57 | Semantic inventory version/digest changed |
| Corner Store | Bar | 45 | Semantic inventory version/digest changed |
| Back Alley | Bar | 16 | Semantic inventory version/digest changed |
| Apartment | Back Alley | 2 | Semantic inventory version/digest changed |
| Apartment | Corner Store | 1 | Semantic inventory version/digest changed |
| Back Alley | Corner Store | 1 | Semantic inventory version/digest changed |

The first instrumented failure occurred in run 7 at action 277. The player was in the Apartment, Corner Store was one of only two enabled destinations, and confirmation failed with the digest-change error.

The invalid state also crossed subsystem boundaries. In run 9, environment `bar_003` rejected four later game actions with `Dynamic room sequence semantic records are not finalized.`:

- Coin Pusher `drop_quarter` at actions 338 and 347;
- Pull Tabs `buy_tab` at actions 346 and 349.

This is not merely a stale map message. Travel finalization invalidates semantic readiness, and subsequent environment-turn/game ingress then fails closed.

#### Reproduction path

1. Start or generate runs until a dynamic room sequence is active, such as the Bar fight-night sequence exercised by the soak.
2. Preserve the room across normal play while progressing state that affects Numbers venues, Silas presence, or the delivery handoff node.
3. Revisit rooms and exercise save/load boundaries so scenario semantics are refreshed.
4. Open the world map and select a route that is visibly enabled.
5. Confirm travel.
6. Observe that the player remains in the same node and receives the internal version/digest migration error.
7. Return to a game in the affected scenario room and attempt a normal action.
8. Observe that the action may be rejected because dynamic-room semantic records are no longer finalized.

The exact action at which the live producer context changes depends on generated content, so the long deterministic seeds are the most reliable current reproducer. The failure is not timing-only: after invalidation, repeated travel and game attempts consistently fail.

#### Root cause

`scripts/core/run_state.gd` treats scenario base semantics as an immutable pre-sequence seal, but refresh reconstructs part of that seal from mutable live state:

1. `_scenario_finalize_trusted_base_semantics()` determines that a refresh is in progress.
2. At line 2646 it calls `_scenario_base_producer_context()` again rather than loading the producer context that was stored with the original seal.
3. `_scenario_base_producer_context()` at lines 3171–3183 derives `numbers_venue_ids`, `numbers_silas_present`, and `delivery_handoff_node_id` from current run state.
4. The newly derived context is inserted into `semantic_environment` and used to stamp records and build the semantic inventory/digest.
5. At lines 2695–2707, the regenerated version/digest is compared with the stored proof. A legitimate live change to any producer-context input causes the comparison to fail.
6. `_invalidate_scenario_semantic_proof()` at lines 3186–3194 erases readiness, inventory, base interactions/actors/producer context, layout authority, and render snapshot, then stores the lifecycle error.
7. Later travel and environment-game preflights correctly fail closed because the proof that refresh itself erased is no longer ready.

The internal comment says trusted records come from an immutable pre-sequence baseline. Recomputing producer context from live Numbers/delivery state contradicts that invariant. The digest is detecting a real difference, but the difference is introduced by the refresh algorithm rather than by an incompatible save migration.

#### Why this is not a harness or dirty-worktree artifact

- All 122 diagnostic targets were explicitly marked enabled by the production world-map snapshot.
- The failure came from the production `confirm_world_map_travel()` result, not from the probe's selection logic.
- Every diagnostic no-move warning carried the same product error. There were no warnings caused by selecting absent, disabled, closed, or unaffordable routes.
- The tracked dirty files were last modified no later than 01:35:37, while the diagnostic process ran from 15:45:13 to 16:04:58. No tracked product/data file changed during the run.
- `scripts/core/run_state.gd`, where the failing digest is computed, was unchanged in the worktree.
- The two earlier soaks reproduced the same route-stall family under independent runs before the diagnostic instrumentation was added.

#### Fix options

1. **Reuse the sealed producer context on refresh.** When `refresh_attempt` is true, read and validate the persisted `scenario_base_producer_context` associated with the existing semantic inventory. Do not call `_scenario_base_producer_context()` to regenerate origin identity.
2. **Bind origin context into durable provenance.** Store the exact producer-context fields and digest with source provenance at initial installation. Reconstruct the semantic inventory after load from that immutable record, not from current Numbers/delivery projections.
3. **Separate identity inputs from live availability.** If Numbers presence or delivery handoff availability is intentionally dynamic, exclude it from the immutable identity digest and authorize it through a separately versioned live projection.
4. **Avoid destructive invalidation for expected live changes.** A refresh mismatch should retain the last validated proof until a valid migration/rebuild succeeds. Erasing the only usable proof turns a recoverable inconsistency into a room-wide soft lock.
5. **Fail the map choice before presentation as defense in depth.** If confirm-time semantic preflight cannot succeed, do not present the route as enabled. This improves UX but does not replace digest-stability repair.

#### Regression tests

- Install a dynamic-room semantic proof, mutate each producer-context input individually, refresh, and assert that the original identity digest remains valid.
- Repeat the above across save/load and environment revisit.
- With an active scenario, change Numbers venue availability, Silas presence, and delivery handoff state, then confirm every enabled travel route.
- After every failed travel preflight, verify that `scenario_semantic_ready`, the prior inventory, and authorized game actions remain intact.
- Add a deterministic replay using the diagnostic seed prefix and assert zero `scenario semantic inventory version or digest changed` errors during ordinary gameplay.

### EXT-PERF-002 — Coin Pusher compact rollback can reject its own token after a failed turn boundary

**Severity:** Medium  
**Priority:** P2  
**Systems:** Coin Pusher live simulation, environment-turn transaction recovery  
**Player impact:** When an otherwise successful Coin Pusher action cannot commit its environment turn, the game attempts a compact rollback. If rollback rejects its token, the failed action may leave some live machine/session mutation in memory even though the surrounding turn did not commit. The soaks did not prove durable save corruption, but failure of the declared recovery contract makes subsequent outcomes and presentation state unreliable.

#### Observed behavior

Soak A logged four and soak B logged six occurrences of:

`Game module failed to restore its declared compact host-action rollback token.`

Every occurrence followed this stack:

1. `foundation_main.gd:_resolve_game_action()` line 12365;
2. `resolve_selected_game_action()`;
3. the soak's ordinary `_try_play_environment_game()` path.

The two runs independently reproduced the failure with the same workload shape. The diagnostic seed did not reproduce it, establishing that it is schedule/state dependent rather than a constant failure. The error occurs only after a module returned an accepted result but `_advance_environment_turns_checked()` rejected the turn boundary.

#### Root-cause analysis

Only Slot and Coin Pusher implement compact action rollback. Slot's restore path returns true for every supported snapshot with a non-empty state key and replaces the durable state from a deep copy. Coin Pusher is the practical failing path:

- `host_action_rollback_snapshot()` stores a direct reference to the current live machine in `snapshot["machine"]`.
- `restore_host_action_rollback()` calls `_ensure_live_machine()` again and requires `is_same(snapshot_machine, ensured_machine)`.
- If resolution or the rejected environment-turn path replaces/rebinds the live-machine entry, `_ensure_live_machine()` returns an equivalent or successor dictionary with a different identity.
- The identity guard returns false before shell, simulation motor target, live-session flags, or durable machine state are restored.
- `foundation_main.gd` logs the error and returns; there is no whole-run fallback because the compact snapshot caused the host to skip the full rollback copy.

Thus the recovery scheme depends on object identity surviving precisely the failed transaction it is intended to undo. A replacement-on-write or cache rebind makes the rollback token unusable.

This defect was often reached in the same broad long-session conditions as EXT-PERF-001, because semantic preflight can reject the environment-turn boundary. It remains a separate defect: regardless of why the boundary rejects, a module that declares compact rollback support must be able to restore its token.

#### Fix options

1. Store the live-machine cache key and sufficient immutable rollback data; on restore, rebind the saved machine or restore into the currently registered machine instead of requiring reference identity.
2. Have `_ensure_live_machine()` expose a stable generation/token and make rollback validate semantic identity plus generation, not raw dictionary identity.
3. If compact restore returns false, execute the full run/environment fallback captured before resolution. This costs more only on an exceptional path and prevents partial mutation.
4. Add a debug/result payload identifying the game, action, cache key, and identity generation when rollback fails so future probes can prove the exact replacement boundary.

#### Regression tests

- Force `_advance_environment_turns_checked()` to reject after a Coin Pusher quarter resolves, then compare the complete machine/session/durable projection byte-for-byte with the pre-action state.
- Repeat after live-machine cache replacement, environment revisit, and save/load.
- Assert that a failed compact restore automatically falls back to a complete rollback.
- Run the two reproducing long-soak seed prefixes and require zero rollback-token errors.

### EXT-PERF-003 — Shared sealed-action host reports Blackjack failures in Slot and Bar Dice

**Severity:** Low  
**Priority:** P3  
**Systems:** Shared action-authority host, game error presentation  
**Player impact:** Players receive a technically unrelated Blackjack message while playing another game. This is especially confusing during an already serious recovery failure and makes support reports point at the wrong subsystem.

#### Observed behavior

The final diagnostic run captured:

- 71 Slot `spin` attempts reporting `Blackjack host could not create a detached delivery.`;
- three Bar Dice `roll` attempts reporting the same message;
- eight Slot `spin` attempts reporting `Blackjack delivery content changed before settlement.`.

The game ID and selected action in each marker were Slot or Bar Dice, not Blackjack. These were product result messages returned to the normal game-action path.

#### Root cause

The generalized sealed-action host in `scripts/ui/foundation_main.gd` contains hard-coded Blackjack nouns. For example, `_sealed_action_host_prepare_delivery()` returns `Blackjack host could not create a detached delivery.` at line 1959 and `Blackjack delivery content changed before settlement.` at line 1976. The same host is now used by other action-authority games, so the error string no longer describes the active module.

#### Fix options

- Replace shared-host errors with game-neutral wording such as `The game action could not be prepared safely.`
- Or interpolate the active game's localized display name.
- Keep technical error codes (`internal_fail_closed`, `receipt_content_conflict`, and similar) separate from player-facing text.

#### Regression tests

- Force each shared-host rejection while current game is Blackjack, Slot, and Bar Dice.
- Assert that the player-facing text is neutral or names the actual current game and never names a different game.

## Expected refusals and excluded noise

The diagnostic recorded 190 game actions that did not advance a turn. They were classified rather than counted as 190 defects:

- 78 Craps rolls, seven Coin Pusher drops, three Pull Tabs purchases, and two Scratch Ticket purchases were normal all-in cancellation paths;
- ten Slot spins correctly refused while an active bonus was unfinished;
- two Bar Dice rolls correctly refused an unavailable ante;
- one Scratch Ticket purchase correctly reported a sold-out ticket;
- one marker contained a successful travel message during a game probe and was a probe classification edge case;
- four Coin Pusher/Pull Tabs failures were downstream manifestations of EXT-PERF-001;
- 82 wrong-game Blackjack messages were consolidated into EXT-PERF-003.

One `ObjectDB instances leaked at exit` warning occurred in soak B and one in the diagnostic run. It is not retained as a product leak because:

- all 37 in-run retained samples in each run reported zero orphan nodes;
- node/object/resource slopes remained within caps;
- the warning was absent in soak A;
- the process exited normally and left no Godot process behind;
- the warning appeared only during engine shutdown, after the final report was written.

The tracked worktree was dirty before testing, but it did not change during the diagnostic process. The report therefore describes the exact candidate filesystem state tested. No migration warning was dismissed solely because the tree was dirty; EXT-PERF-001 was retained because production state and source behavior proved it was generated internally during ordinary play.

## Areas that passed

- No sustained retained-memory growth above the 4 MiB cap.
- No retained node, object, or resource growth above configured caps.
- No in-run orphan nodes.
- No serialized run-state overflow above 1.5 MB.
- No Pinball session-cache overflow above 32 entries.
- No Slot background-texture cache overflow above six textures.
- Environment history and story-log counts remained within their caps.
- Save/load cycling completed 258 times across the three runs without a report-level failure.
- All 11 game surfaces and ten resolve paths passed the current performance matrix.
- All seven allocation hot roots passed the forbidden-operation audit.
- Coin Pusher native, incremental, ceiling-refusal, full-cap, and active-sequence performance checks passed.
- No hung process remained after any completed soak.

## Evidence index

Primary long-run reports and logs are stored under `.tmp/playtest_extended/performance_soak/`:

- `foundation_soak_360_a.json`, `.stdout.log`, `.stderr.log`;
- `foundation_soak_360_b.json`, `.stdout.log`, `.stderr.log`;
- `foundation_soak_360_diagnostic.json`, `.stdout.log`, `.stderr.log`;
- `foundation_soak_diagnostic.gd` — diagnostic-only probe subclass;
- `allocation_call_root_audit.json`.

The current-candidate game-surface performance report is `.tmp/playtest_2026-09-20/games_performance/performance_current.json`.

## Recommended fix order

1. Fix EXT-PERF-001 first. It is the only retained high-severity failure and can block both travel and room gameplay.
2. Fix EXT-PERF-002 next, then rerun the EXT-PERF-001 failure injection to prove that rejected turns always restore Coin Pusher state.
3. Correct EXT-PERF-003 while touching the shared host so future failure reports name the correct subsystem.
4. Rerun the full three-seed 360-minute matrix and the existing performance contracts. Acceptance should require zero digest-change migration errors during ordinary play, zero rollback-token errors, zero wrong-game error messages, and continued compliance with all memory/state/cache caps.
