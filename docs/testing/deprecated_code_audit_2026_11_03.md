# Deprecated implementation audit ╬ô├ç├╢ 2026-11-03

Baseline: `87a06b9a4acbe86b0f761d2cd0ab929f5584b716`.
Task: `BTH061-AUDIT-001` on the existing stability release task list.
Removal commit: `6a784623bdedd6b253d41ef42110adbfd4d67a12`.

Status correction, 2026-11-04: this report establishes the scoped removals and
their deployed acceptance. Its closing statement did not establish completion
of the original codebase-wide audit. The umbrella task is reopened in the
[continuation](deprecated_code_audit_2026_11_04.md). Previous coordination
deferrals are not intentional user holds; remaining candidates and inherited
check failures are being actively resolved without removing live compatibility.

This audit is separate from the Crew-delivery/game-surface repair. It removes
confirmed superseded implementations and assets; it does not claim to fix the
reported game fallback or room-publication failures.

## Evidence and removals

| Removed | Evidence for retirement | Active replacement |
| --- | --- | --- |
| `FoundationMain._interactable_environment_cache_token` (48 lines) | `55a3e213` replaced its sole caller; current source/data/scenes/tools have no remaining method or callable reference. This private helper only serialized environment fields. | `_interactable_object_cache_key` consumes `RunState.room_presentation_revision()`. |
| `RunState._clock_display_for_absolute_minutes` (4 lines) | `04b35205` replaced its sole delivery caller; no serialization or dynamic-dispatch dependency exists. | `CrewDeliverySchedule.timing_text` and `window_text` use `PlayerText.format_game_clock`. |
| `EnvironmentPlacement.surface_map_by_id` and `authoring_surface_map` (10 lines) | First is uncalled; second is a pure alias used by three tests and one obsolete source assertion. Locked edits became runtime authority in `701998d5`. | `surface_map` already composes `_with_runtime_slot_geometry` for every caller. Existing placement assertions now call that boundary directly; the static checker examines its actual composition. |
| `data/games/rituals/crew06_10_poker_nights.json` (62 lines) | No production/test/tool loader reads it. Named references are historical custody. It duplicates five implemented nights using superseded before/draw/after phases. | `ScenarioSequenceCatalog` overlay metadata and `CrewDrawPoker` select the current ordered engine and night behavior. |
| Retired scratch-art generation (567 deleted lines, 5 added) | The generator itself labels the v2 faces unused; the October 9 audit retained it only for live reveal icons. | Authored `*_background_pro.png` faces, measured region JSON, procedural foil, and the retained nine-icon generator. |
| Seven scratch reveal PNGs | `bell`, `clover`, `star`, `twofer` have explicit `pro_*` replacements. `dust`, `crossword_cell`, `bingo_cell` have no runtime loader; their marks/cells are rendered procedurally. No current data/manifest/tool read remains. | The renderer's explicit 17-entry preload map; every retained asset is byte-unchanged. |

The scratch generator no longer recreates seven old faces, the v1 foil tile,
preview composites, or fourteen retired reveal icons. The nine live output
names, helper ASTs and complete drawing/filter/save operation traces match the
baseline. No live PNG was regenerated. Pillow was unavailable, so the trace
comparison is not a real PNG pixel comparison.

## Review boundaries

The audit considered production core/game/UI symbols, script paths, class names,
static and callable/string dispatch, inheritance contracts, scenes, resources,
JSON loaders, current tools/tests, prior audit rationale and ownership holds.
A single missing textual caller was treated as a lead rather than proof.

Retained deliberately:

- Save migrations, compatibility simulations and old live-hand restoration.
  In particular, Crew's five-card engine remains reachable through explicit
  `legacy_v1` metadata and restoration of old live hands. Removing it requires a
  separately designed compatible hand migration.
- `Craps06EnvironmentBinding`, `GameRitualHostAuthority` and debug/test seams
  exercised by authority, checkpoint, replay and forgery contracts. Test-only
  use does not establish retirement.
- The hidden CheatDock snapshot adapter, Godot callbacks and content-selected
  game modules, which have real consumers.
- `ScenarioLayoutResolver._substantially_overlaps` and `COLLISION_RATIO`, already
  reserved under the existing cleanup's O1 finalization-owner hold.
- Public Keys vocabulary, distinct allowlisted scenario adapters, native solver
  implementations, qualified export/parity entry points and historical tools,
  evidence, fixtures and custody manifests.

The user's dirty placement file, original saves/profiles, stable/itch channels,
hosting audience, watcher, engine/template pins and native inputs were untouched.

## Validation

Native checks use pinned Godot `4.6.stable.official.89cea1439`, disposable roots,
and the maintained private Windows Job helpers. Every job ended with zero active
owned processes. Raw receipts/logs remain outside Git in the task workspace's
`evidence/`, `tool_audit/` and audit notes.

| Check | Result |
| --- | --- |
| Final frozen editor import/parse | Exit 0; no script or missing-asset errors. The host's root-certificate-store error is retained in the log. |
| `crew06_10_scenario_registration_contract.gd` | PASS, five current ordered-engine nights. |
| `fixsweep06_1_player_text_contract.gd` | PASS, including clock formatting. |
| Scratch generator AST, all nine operation traces, Python compilation and asset hashes | PASS. All seventeen runtime preload assets remain present and unchanged. |
| `crew_package_windows_check.gd` | FAIL on baseline and candidate with exactly the same nineteen failure lines, starting with unavailable favor events. |
| `environment_slot_placement_mode_check.gd` | FAIL on baseline and candidate with the same Empty-capacity visibility assertion. |
| `character_offers_cache_check.gd` | FAIL on baseline and candidate with the same failure/error lines, including a fixture's nil run during background refresh. |
| `environment_fixed_slot_static_check.py` | FAIL on baseline and candidate with the same nineteen data/geometry errors. Original checker and all tracked inputs were restored for the baseline comparison. |
| `validate_project.ps1 -Quiet` | Stops at unchanged `character_offer_model.gd:7`: preload alias `Hours` does not end in `Script`. The baseline contains that identical declaration. |

For each baseline comparison, the original runtime source/data/assets/tests were
temporarily restored from the baseline commit in this isolated audit checkout.
The baseline runtime Git diff was empty. The exact cleanup diff was restored
afterward and verified by SHA-256. No failed assertion or fixture was weakened.
These inherited failures are not counted as passing tests or as newly diagnosed
player failures. Initial import overlapped asset removal and logged missing
retired files; that attempt is retained and superseded only by the final frozen
import.

Commands are recorded in the native job receipts. The targeted entry points are
`godot --headless --path . --script res://scripts/tests/<check>.gd` and
`res://scripts/tests/foundation/crew06_10_scenario_registration_contract.gd`.
The engine-free placement checker is
`python tools/environment_fixed_slot_static_check.py <source> <report>`.

## NEXT follow-through

The removal commit and tracking commit `8d3c52756d99a315050e62601b5da3531ddef0c4`
were pushed to main. At 22:02:29 UTC the existing watcher retained NEXT
`87a06b9a4acbe86b0f761d2cd0ab929f5584b716` and reported
`Asset/importer/settings inputs changed; cold-import qualification required`.
The seven PNG deletions and inert JSON deletion change eight guarded input paths.
Follow-through uses the existing exact-input cold-import request workflow, with
normal cache-free import/export/audit by the same capped watcher. No cache
classification, guard, exporter, watcher, resource cap or deployment audience is
changed.

The watcher consumed the exact request (SHA-256
`0f2720104ce44ef195bb60cf5566227cc37e126d003c964c13994cfcbaf1ffb9`) and promoted
`be4cd6716e3e1f7614008c9cc70a27cee7b48def`, tree
`11de9feffd8d3c505e504c92321f2babb45f0f89`, at 22:08:22 UTC. Served metadata,
redirect, `BUILD.json`, `build_manifest.json`, `REF` and `VERSION` match the exact
pipeline provenance. Four engine/PCK/native payload HEAD requests return 200,
with matching recorded lengths and correct WASM MIME; exact-build pipeline
payload hashes were reused. The PCK audit passes with all eight retired source
inputs and old imported textures absent, all seventeen live scratch symbols
present, and all three changed production bytecode files present.

A fresh, sandboxed headless Chromium at trusted localhost loads that immutable
build and visually reaches the main menu showing `0.6.0-dev+be4cd6716e3e`.
All four required payload responses are 200, page errors are empty, and browser
and context close normally. The maintained private Job reports exit 0 and zero
active owned processes. No game input, existing browser profile or player save
was used. This is basic Web startup, not an all-game playtest. Stable, itch and
hosting audience remain outside the change. Final raw receipts are
`evidence/next-identity.json`, `evidence/next-startup/startup.json`,
`evidence/next-startup/job.json` and the reviewed startup screenshot in the
isolated task workspace. This closes only implementation batch `BTH061-AUDIT-001-BATCH-001`, not the full `BTH061-AUDIT-001` audit objective, against the removal
commit above; remaining compatibility and inherited-check ambiguities remain
explicit rather than being marked fixed.


## Full audit objective remains active

The user requested an audit to find other deprecated implementations and remove confirmed obsolete code completely. The first shipped removal batch and its NEXT verification do not establish whole-codebase review. Keep parent `BTH061-AUDIT-001` Open while recording subsequent batches separately.

The current coverage inventory records95 core files (46 match previously reviewed blobs,49 differ;4 lack prior review) and a UI/game graph of127 files/7322 functions. A symbol/graph scan is not semantic review. Remaining work needs explicit removed/retained/reviewed dispositions, caller/dispatch and save-compatibility evidence, classification of every remaining candidate, named inherited-failure follow-ups, tested commits and relevant NEXT verification. See the [machine ledger](../todo/bth_task_ledger.json) and [manual reconciliation checks](../todo/bth_task_ledger_checks.md).
