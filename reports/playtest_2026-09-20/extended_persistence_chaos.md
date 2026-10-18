# Beat the House — Extended Persistence Chaos Playtest

**Date:** 2026-09-20  
**Scope:** Production save codec and save service; atomic generations; corrupt, truncated, empty, oversized, legacy, tutorial, mid-game, repeated-load, slot/path, deterministic-restoration, asynchronous-save, and restart behavior.  
**Tester:** `persistence_chaos` extended wave  
**Product changes:** None. This pass only created isolated evidence and this report.

## Executive summary

This pass ran 56 production-codec checks plus six independent fresh-process quit/relaunch cycles. It confirmed **one player-impacting persistence defect**, reproduced six times across both manual and ordinary asynchronous save paths:

> When an encoded run exceeds the codec's 32 MiB maximum, `SaveService` installs an invalid primary save and reports success. With no older generation, Continue becomes unavailable. With an older generation, Continue silently restores stale progress from the backup.

All 16 corrupt-primary recovery cases correctly fell back to the prior atomic generation. Both legacy 0.3 fixtures, 17 historical/current save fixtures, three tutorial phases, all represented game-state families, two orphan-temporary-file cases, three isolated slot IDs, two ordinary async saves, and repeated ordinary-domain loads remained loadable. Six old fixtures exhibited a one-time integer-to-float normalization on a layout metadata field; no behavior depended on that type, and the value remained numerically identical. Artificial RNG values near signed 64-bit maximum lost JSON precision, but production RNG state is bounded below 2,147,483,647, so that result is out of the reachable state domain.

The raw probe marks the six expected legacy type-normalization observations and two deliberately out-of-domain RNG probes as strict mismatches. They are not counted as player bugs in this report.

## Test environment and production fidelity

- Engine: Godot 4.6 stable console/headless runtime from the project toolchain.
- Save root: isolated distribution-style root at `.tmp/playtest_extended/persistence_chaos/runtime_data` using the shipped `PersistencePaths` environment override.
- Serializer: `RunState.to_save_snapshot` → `RunSaveCodec.encode` → `RunSaveCodec.pack_for_storage` → `SaveService` file installation.
- Loader: `SaveService.load_run` → `RunSaveCodec.unpack_from_storage` → `RunSaveCodec.decode` → `RunState.from_dict`.
- No raw `RunState.to_dict` JSON round-trip was used to claim a production defect.
- Each confirmed defect signature was reproduced at least twice.

Primary evidence:

- `.tmp/playtest_extended/persistence_chaos/extended_persistence_probe.json`
- `.tmp/playtest_extended/persistence_chaos/main_run.log`
- `.tmp/playtest_extended/persistence_chaos/quick_fire_1.log` through `quick_fire_6.log`
- `.tmp/playtest_extended/persistence_chaos/quick_read_1.log` through `quick_read_6.log`
- Probe source: `.tmp/playtest_extended/persistence_chaos/extended_persistence_probe.gd`

## Coverage matrix

| Area | Executions | Result |
|---|---:|---|
| Distribution path and isolated slot boundaries | 5 | Passed; unsafe-name collision recorded as non-player API observation |
| Oversized saves | 6 | **Defect reproduced 6/6**: two empty-slot sync, two replacement sync, two replacement async |
| Corrupt primary with valid backup | 16 | Passed 16/16 |
| Orphan `.tmp` atomicity | 2 | Passed 2/2 |
| Minimal legacy/default migration | 2 | Passed 2/2 |
| 0.3.0 and 0.3.3 legacy envelopes | 4 | Passed 4/4 |
| Historical/current mid-game and tutorial fixtures | 17 | All loaded and resaved; six harmless metadata type normalizations |
| Repeated ordinary async single-writer save | 2 | Passed 2/2 |
| Repeated load/canonical state | 2 | Canonical loads matched; artificial >2^53 RNG boundary excluded as unreachable |
| Graceful direct-SceneTree quit/relaunch | 6 | 4 durable, 2 worker teardown failures; excluded because this bypasses player exit guards |

### Corruption forms

Each corruption was applied to a newly written primary while retaining a valid prior backup, then loaded through a fresh `SaveService` instance. Every case was repeated twice.

1. Empty file
2. Truncated JSON
3. JSON array instead of object
4. Empty JSON object
5. Valid packed envelope with incorrect SHA-256
6. Valid-length packed envelope containing an invalid Z85 character
7. Packed envelope claiming an uncompressed size above 32 MiB
8. Wrong save schema

For every case, `slot_status` identified the primary as corrupt, identified the backup as loadable, and `load_run` returned the backup generation with the expected bankroll.

### Save fixtures and gameplay phases

The production loader and current saver were exercised against:

- Foundation 0.3.0 and 0.3.3 legacy saves
- Tutorial start
- Tutorial corner-store arrival
- Tutorial gas-machine open
- Bar Dice mid-game
- Blackjack mid-game in Delta Queen and underground casino environments
- Video Poker mid-game in Delta Queen and underground casino environments
- Slot mid-game/current depth fixture
- Pull Tabs mid-game
- Scratch Tickets mid-game and partially scratched ticket state
- Baccarat mid-game
- Roulette mid-game
- Current environment-depth Bar Dice fixture
- Current world-depth Crew debt/delivery fixture

The restored environment game-state dictionaries collectively contained `bar_dice`, `baccarat`, `blackjack`, `pull_tabs`, `roulette`, `scratch_tickets`, `slot`, and `video_poker`. Current fixtures additionally exercised crew, numbers, delivery, town, scenario, music, closing-time, Grand Casino, economic, inventory, debt, heat, history, and narrative domains through the same production codec.

## Confirmed bug PERSIST-EXT-01

### Title

Oversized run save reports success, installs an unloadable primary, and loses or rolls back progress

### Severity and confidence

- **Severity:** P2 / high integrity impact, low expected frequency
- **Confidence:** High
- **Reproduction:** 6/6 across three variants
- **Player impact:** The UI can say the run was saved although the new generation cannot be loaded. A first save produces no resumable run. A later save silently rolls the player back to the previous backup generation.

### Reproduction variants and observed results

#### A. First save into an empty slot — repeated twice

1. Create a valid active `RunState`.
2. Add a valid persisted narrative string large enough to make the encoded state exceed 32 MiB.
3. Call production `SaveService.save_run`.
4. Inspect through the same service, then through a fresh service.

Observed on both repetitions:

- `save_run` returned `OK` (`0`).
- The writing service's trusted fingerprint caused `has_run` to return `true` immediately.
- A fresh `slot_status` reported `primary_exists=true`, `primary_corrupt=true`, `primary_loadable=false`, and no loadable backup.
- `load_run` returned `null`.

#### B. Oversized synchronous replacement — repeated twice

1. Save a small valid generation with bankroll 811/812.
2. Attempt to save an oversized newer generation with bankroll 911/912.
3. Load from a fresh service.

Observed on both repetitions:

- Both baseline and oversized `save_run` calls returned `OK`.
- The new primary was corrupt and the backup was loadable.
- Continue loaded bankroll 811/812, silently discarding the new 911/912 generation.

#### C. Oversized asynchronous replacement — repeated twice

1. Save a small valid generation with bankroll 1011/1012.
2. Call `begin_save_run` for an oversized newer generation with bankroll 1111/1112.
3. Call `wait_for_async_save`, matching the completion boundary used by the normal autosave machinery.
4. Load from a fresh service.

Observed on both repetitions:

- `begin_save_run` returned `OK`.
- `wait_for_async_save` returned `OK`.
- The primary was corrupt and the backup was loadable.
- Continue loaded bankroll 1011/1012 instead of 1111/1112.

### Expected behavior

If the codec cannot represent a run, the save call and async completion must return a failure. The service must leave the existing primary and backup untouched. The UI must not report “Saved” or update its loadable-generation bookkeeping.

### Root cause

The fault is an error-contract gap between the codec, save service, and UI:

1. `RunSaveCodec.pack_for_storage` returns an empty dictionary when serialized input is empty, exceeds `MAX_STORAGE_BYTES`, or compression fails (`scripts/core/run_save_codec.gd:104-110`).
2. The synchronous payload builder places that empty dictionary directly into `run_state` without checking it (`scripts/core/save_service.gd:328-336`).
3. The async worker does the same (`scripts/core/save_service.gd:157-166`).
4. Both write paths judge success only by filesystem write/rename. A valid primary may first be rotated to backup; the invalid `{}` generation is then installed as primary (`scripts/core/save_service.gd:42-86`, `170-202`).
5. A successful rename fingerprints the invalid primary as trusted, so `has_run` can temporarily claim it is loadable (`scripts/core/save_service.gd:30-38`, `84-86`, `138-142`).
6. The reader correctly rejects the empty packed state later (`scripts/core/save_service.gd:340-371`), but by then the service has already reported success and mutated both generations.
7. `FoundationMain` treats the returned `OK` as a completed save, advances autosave bookkeeping, and presents success/writing status (`scripts/ui/foundation_main.gd:6743-6757`).

### Fix options for a later implementation agent

1. **Preferred: explicit codec result.** Change `pack_for_storage` to return a structured success/error result, including an oversized/compression failure code. Make both sync and async save paths stop before opening a temp file or rotating any generation.
2. **Minimum guard:** After packing, reject an empty dictionary and return an error such as `ERR_OUT_OF_MEMORY`, `ERR_FILE_TOO_BIG`, or a project-specific error before writing.
3. **Defense in depth:** Validate the fully written temporary payload with the same envelope/decompress/hash checks used by `_worker_payload_loadable` before rotating the primary. Never install or trust a generation that the production reader cannot open.
4. **Trust correction:** Only call `_remember_primary_fingerprint` after validating the installed generation, rather than treating rename success as save validity.
5. **UI contract:** Ensure synchronous and async error propagation leaves `autosave_completed_generation` and `autosave_loadable_available` unchanged and shows “Autosave failed.”

### Regression tests recommended

- Empty-slot oversized sync save must return non-OK and leave both generations absent.
- Existing-slot oversized sync save must return non-OK and preserve primary and backup byte-for-byte.
- Existing-slot oversized async save must return non-OK from completion and preserve both generations.
- Compression failure injection must follow the same preservation rules.
- A save reported as `OK` must pass `slot_status.primary_loadable` in a fresh service instance.
- A failed save must not add a trusted fingerprint.

## Validated non-bugs and observations

### Legacy layout metadata changes integer type once

Six 0.5.1 fixtures changed `layout.generated_object_rect_version` from Godot `TYPE_INT` to `TYPE_FLOAT` after the first current packed round-trip. The numeric value was unchanged, all environments and game states remained present, and no consumer was found that required exact Variant type for this presentation-version field. This follows the codec's deliberate policy of exact-integer wrapping only for type-sensitive scenario, delivery, and world-sequence roots. It is recorded for format hygiene, not counted as a gameplay bug.

### Near-`int64` RNG precision loss is unreachable

Two adversarial probes assigned `rng_state` values near 9.22e18. JSON converted them from 9223372036854775000/4999 to 9223372036854774784. This did not qualify as a player bug because normal `RngStream` state is reduced modulo 2,147,483,647 and text seeds are masked to 31 bits. Ordinary repeated loads and derived RNG draws remained deterministic.

### Direct SceneTree shutdown race bypasses player exits

Two of six deliberately immediate `SceneTree.quit` cycles destroyed the `SaveService` while its async worker was entering `io_mutex.lock`, producing either “Bad address index” or “Cannot call method 'lock' on a null value,” followed by no saved run. This is a real lifecycle hazard for unguarded callers, but it is **not counted as a player-reachable defect**:

- The in-game Exit action calls forced synchronous autosave before quitting (`scripts/ui/foundation_main.gd:16213-16218`).
- The window-manager close notification also calls forced synchronous autosave (`scripts/ui/foundation_main.gd:793-797`).
- The synchronous save boundary joins an in-flight worker before proceeding (`scripts/ui/foundation_main.gd:6737-6743`).

If a future platform adds a lifecycle exit that calls `SceneTree.quit` directly, it must use the same durability boundary.

### Slot identifier collision is not exposed by the shipped UI

The sanitizer removes unsafe characters rather than escaping them, so API inputs `a/b` and `ab` resolve to the same filename. The shipped UI uses the fixed `autosave` slot and does not expose arbitrary IDs. This remains an API-hardening observation only.

## Passed resilience findings

- Valid backup recovery worked for all 16 corrupt-primary trials.
- A valid primary remained authoritative when an orphan `.tmp` file existed.
- Minimal raw legacy saves received working defaults for town, numbers, status, clock, and newer state domains.
- 0.3.0 and 0.3.3 envelopes loaded and resaved twice each.
- Tutorial saves loaded at three distinct lesson/travel phases.
- Current mid-game, environment-depth, and world-depth fixtures survived two current-format generations.
- Separate safe slot IDs remained isolated under a distribution-style absolute persistence root.
- A second `begin_save_run` correctly returned `ERR_BUSY` while a moderate async generation was active; completion and reload succeeded twice.
- Repeated fresh-service loads produced identical normalized snapshots and identical derived RNG draw sequences within the valid RNG domain.

## Conclusion

The corruption recovery and legacy migration paths were robust across the tested matrix. The principal integrity gap is before atomic installation: the codec can signal refusal only by returning `{}`, while the save service mistakes that value for a writable generation. Correcting that contract and validating the temporary generation before rotation would prevent both false success and stale-backup rollback without weakening the existing two-generation recovery behavior.
