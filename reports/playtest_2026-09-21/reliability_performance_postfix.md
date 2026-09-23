# Beat the House post-fix reliability, performance, persistence, and packaging report

Date: 2026-09-21  
Candidate commit: `b7c51bf4749422c434e9689b02852084d66ac192`  
Candidate tree: `0b6c0f3b875f3d9d2a88bc7eaf75fb26f5faf543`  
Godot: 4.6 stable (`89cea1439`)  
Scope: persistence/save-load/autosave/corruption/migration; long-session memory and state size; async/lifecycle behavior; startup and Windows/Web packaging; audio cache/recovery.  
Product changes: none. Temporary probes and evidence are under `.tmp/playtest_2026-09-21/reliability_performance/`.

## Executive summary

The current candidate passed three independent 180-simulated-minute foundation soaks, 37 legacy save migrations, the durable-store baseline, lifecycle, audio-recovery, packaging-runtime, desktop-startup, Web-server lifecycle, project validation, and multiple performance source contracts. The 2026-09-20 semantic-digest and compact-rollback regressions did not recur in 1,512 measured plus 1,512 prewarm actions.

Twelve distinct defects remain: five High, three Medium, and four Low. The most important player-runtime issue is an unbounded feature-music cache that retained 24 full stem packs, grew static memory by 88,272,048 bytes, was omitted from the advertised 64 MiB PCM budget, and survived the run-cache clear. Persistence probes also demonstrated loss of the prior backup generation after a failed atomic install, a permanent autosave failure loop retrying every other frame, and silent acceptance of object-shaped settings corruption.

Release qualification is currently blocked by several independent tooling defects. The code-health archive move broke path/root assumptions throughout the final performance pipeline; default Windows packaging rejects the normal coexistence of debug and release native DLLs; the PCK auditor falsely rejects all 41 shipped native PCM files; and the Web export helper mixes Godot stdout into its return value and falsely reports a successful export as a failed exit code.

## Coverage and results

### Independent long-session soaks

Each full run used `tools/foundation_soak_probe.ps1 -SimMinutes 180 -ActionsPerSample 28 -RequireGodot` with seed prefixes `RELPOSTFIX-A`, `RELPOSTFIX-B`, and `RELPOSTFIX-C`. Each report contains 19 samples at ten-minute intervals, 504 measured actions, and 504 prewarm actions.

| Run | Result | Wall time | Peak process RSS | Retained full-window growth | Retained robust slope/sample | Max serialized state | Save-loads | Travels | Runs started |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | PASS | 661.575 s | 757,862,400 B | 199,758 B | 11,405 B | 912,671 B | 21 | 199 | 10 |
| B | PASS | 677.079 s | 770,064,384 B | 106,438 B | 6,634 B | 912,671 B | 21 | 194 | 11 |
| C | PASS | 567.928 s | 732,299,264 B | 122,082 B | 6,330 B | 995,557 B | 21 | 204 | 10 |

Aggregate coverage was 540 simulated minutes, 1,512 measured actions, 1,512 prewarm actions, 31 generated runs, 63 save/load cycles, and 597 world travels in 1,906.582 seconds of wall time. Peak-RSS variance was 37,765,120 bytes across runs. The largest serialized run was 995,557 bytes, below the 1,500,000-byte cap. All retained-growth results were below the 4 MiB cap, all retained slopes were below 262,144 bytes/sample, and every sample reported zero orphan nodes. The probe does not record per-action latency; startup/launch latency was measured separately below.

Both prohibited 2026-09-20 regression phrases occurred zero times across all three logs:

- `scenario semantic inventory version or digest changed`
- `failed to restore its declared compact host-action rollback token`

Run A and C emitted Godot's generic ObjectDB warning at shutdown; B did not. A short verbose diagnostic exposed exactly one leaked `RefCounted` with reference count zero, but the short run intentionally failed its minimum-sample rule and did not identify an owning product class. Since all full runs had zero orphan nodes and flat retained counts, this is recorded as a harness observation, not a retained product defect.

### Focused runtime and migration coverage

| Check | Result | Notable evidence |
| --- | --- | --- |
| `health06_1_durable_store_contract.gd` | PASS | Baseline primary/backup and forced-failure contract passed; RP-005 is a deeper pre-existing-backup case absent from this contract. |
| `fixsweep06_1_lifecycle_contract.gd` | PASS | Lifecycle cleanup contract passed. |
| `fixsweep06_1_audio_recovery_contract.gd` | PASS | Pause/recovery baseline passed; RP-006 exercises the untracked feature cache. |
| `fixsweep06_1_packaging_runtime_contract.gd` | PASS | Runtime build-identity baseline passed. |
| `integ06_1_v051_migration_smoke.gd` | PASS | 37 v0.5.1 fixtures migrated and round-tripped, including mid-game, debt, scenario, tutorial, and Grand Casino states. |
| `desktop_startup_latency_contract.gd` | PASS | Ready-to-menu 97 ms; immediate Play 3,683 ms; immediate Continue 402 ms. |
| Diagnostic packaged Windows launch | PASS (diagnostic only) | Isolated distribution profile; main menu interactive at 71 ms relative; fresh-start contract passed; Play-to-tutorial 2,521 ms; bounded exit after 9.339 s; no stderr. Artifact is not qualified because upstream packaging gates failed. |
| Direct Web PCK audit | PASS (diagnostic only) | 1,174 packed files, zero audit failures, embedded `build_manifest.json`, 11 non-empty output files. Wrapper still failed before registration because of RP-012. |
| `web_server_lifecycle_test.ps1` | PASS | Hostile cleanup, PID reuse, listener ownership, and spaced-path cases passed. |
| `validate_project.ps1` | PASS | Static project validation completed in 126.5 s. |

### Static contract coverage

Packaging, Web export-mode, Web idle-liveness, Web prestage, Coin Pusher Web-clock, action-diagnostic, run-UI deferral, and backglass contracts passed. Health correctness, god-object, hot-path, hygiene, I/O-result, scoped-telemetry, serialization, shared-primitives, static-source, and test-harness contracts passed. Failures are described in RP-001 through RP-004.

## Retained defects

### RP-001 — High — Code-health archive move makes the documented performance qualification pipeline unusable

Confidence: certain. Category: release/test infrastructure; no claim of a player-runtime fault.

Reproduction:

1. Run any of the top-level contract commands below from the repository root. Each exits 1 because its dependency was moved under `tools/archive/` without updating the caller:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File tools/perf06_required_matrix_contract_test.ps1`
   - `... tools/perf06_budget_contract_test.ps1`
   - `... tools/perf06_phase_qualification_contract_test.ps1`
   - `... tools/perf06_quiescence_contract_test.ps1`
   - `... tools/perf06_binding_preflight_contract_test.ps1`
   - `... tools/perf06_allocation_contract_test.ps1`
   - `... tools/integ06_1_terminal_soak_launcher_contract_test.ps1`
2. Run the documented archived host-profile command with a relative output: `tools/archive/perf06/perf06_capture_host_profile.ps1 -ProfileId postfix-root-probe -Out .tmp/playtest_2026-09-21/reliability_performance/archive_root_probe_profile.json -Method physical -WebCpuThrottleRate 4`.
3. Observe exit 0, but the file is written under `tools/archive/.tmp/...`; the repository-root path the runbook consumes does not exist.

Expected: every documented gate resolves repository-root resources and produces evidence where the runbook declares it.  
Actual: active callers look for removed top-level helpers, while moved scripts compute the repository root as one parent of their now-deeper `$PSScriptRoot`. The full low-end launcher also looks inside its archive directory for live top-level `foundation_performance_probe.ps1`, `perf06_native_runtime_matrix.ps1`, and `web_perf_smoke.ps1`. The archived surface-report builder similarly misses the top-level budget table and phase contract.  
Frequency: 100% for affected commands.  
Impact: `check_godot` Audit/Full and the published final performance runbook cannot complete. Some producers can report success while writing evidence to the wrong tree, creating a custody hazard.

Root cause: commit `b7c51bf4` moved helpers one or two directory levels deeper but preserved assumptions from their former `tools/` location. Examples: `tools/check_godot.ps1:1361-1377`, `tools/archive/perf06/perf06_capture_host_profile.ps1:11`, `tools/archive/perf06/perf06_build_surface_report.ps1:12,40,49`, and `tools/archive/perf06/perf06_low_end_matrix.ps1:19,130,139,143,160`. The broken commands remain advertised in `docs/plans/perf06_1_final_runtime_runbook.md:24-194` and `docs/plans/integ06_1_final_execution_ledger.md:272-275`.

Fix options:

- Introduce one repository-root resolver that walks to a marker such as `project.godot`, and use it in moved scripts.
- Update active callers to explicit archive paths, or restore maintained helpers to `tools/`; avoid a half-archived dependency graph.
- Add a zero-runtime dependency/path preflight that executes every published entry point with temporary outputs.

### RP-002 — Low — Thirty-two orphan `.gd.uid` files remain after tool scripts were archived

Confidence: certain. Category: repository/tool hygiene.

Reproduction: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/health06_1_dead_code_contract_test.ps1`.  
Expected: every GDScript UID has a corresponding script at the same path.  
Actual: the command exits 1 and lists 32 top-level `tools/*.gd.uid` files whose `.gd` partners moved to `tools/archive/...`.  
Frequency: 100%.  
Impact: dead-code gate remains red and stale UID identities can confuse editor/import bookkeeping.

Root cause: the archive commit renamed 32 `.gd` files but did not move or remove their companion UID files. The failing detector is `tools/health06_1_dead_code_contract_test.ps1:39-55`.

Fix options: move each UID alongside its archived script, or delete UIDs intentionally if the archived tools should receive new identities; add paired-file handling to future archive moves.

### RP-003 — Low — Standalone-contract self-test hard-codes a stale file count

Confidence: certain. Category: test infrastructure.

Reproduction: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/health06_1_standalone_contracts_contract_test.ps1`.  
Expected: the discovery self-test accepts the current reviewed foundation contract set.  
Actual: exit 1, `The post-triage CH-23 census changed; re-audit the standalone discovery set.` Current count is 81; the test requires exactly 80.  
Frequency: 100%.  
Impact: health qualification is red without identifying a behavioral regression.

Root cause: `tools/health06_1_standalone_contracts_contract_test.ps1:31-32` uses a brittle exact count rather than a named manifest or discovery invariant.

Fix options: replace the count with an explicit expected-path manifest, or update the reviewed census and add assertions for the particular newly included/excluded contracts.

### RP-004 — Medium — Complementary startup contract was not updated for `GameModuleRegistry`

Confidence: certain. Category: release/test infrastructure.

Reproduction: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/perf06_web_complementary_startup_contract.ps1`.  
Expected: the maintained complementary-startup gate validates lazy module loading and passes on the refactored implementation.  
Actual: exit 1, `RunGenerator no longer falls back to the ordinary dynamic module loader after its retained cache lookup.`  
Frequency: 100%.  
Impact: `check_godot` Audit/Full fails even after archive paths are repaired; a documented startup qualification command is unusable.

Root cause: `run_generator.gd` now delegates module construction to `GameModuleRegistryScript.create_module`; the actual `load(module_path)` fallback moved to `scripts/core/game_module_registry.gd:22-34`. The contract still searches for literal `module_script = load(module_path)` inside `run_generator.gd` at `tools/perf06_web_complementary_startup_contract.ps1:18-22`. The gate is invoked by `tools/check_godot.ps1:1372` and advertised at `docs/plans/perf06_1_final_runtime_runbook.md:82`.

Fix options: validate the delegated registry contract and bounded cache instead of implementation text in `RunGenerator`, or add a focused runtime module-load test.

### RP-005 — Medium — Failed atomic install deletes the previously valid backup generation

Confidence: high. Category: persistence resiliency.

Reproduction: run `reliability_postfix_probe.gd`; inspect `durable_store_failed_install`. The probe writes generation 1, writes generation 2 (creating a valid generation-1 backup), enables `debug_force_rename_failure`, then attempts generation 3.  
Expected: failed installation leaves both the generation-2 primary and generation-1 backup intact.  
Actual: failure is reported and generation 2 is restored as primary, but `backup_exists_after=false` and `backup_preserved=false`.  
Frequency: 100% in the deterministic fault-injection probe.  
Impact: a transient install/rename failure reduces two-generation recovery to one generation. A later primary corruption has no fallback, increasing save-loss risk.

Root cause: `scripts/core/durable_store.gd:49-61` deletes the old backup and renames the current primary over it before installing the temporary generation. On failure, `_restore_rotated_primary` at lines 161-168 renames that new backup back to primary; the original backup is already gone. Existing `health06_1_durable_store_contract.gd:58-75` injects failure before a pre-existing backup exists, so it misses this sequence.

Fix options:

- Use a third temporary name for the old backup and commit/rollback all three generations transactionally.
- Preserve the old backup until the new primary has been installed and validated.
- Extend the contract to fault every transition with both primary and backup pre-populated.

### RP-006 — High — Feature-music stem cache is unbounded, outside the PCM budget, and survives run cleanup

Confidence: high. Category: long-session performance/memory.

Reproduction: run `reliability_postfix_probe.gd`; inspect `audio_feature_cache`. It generates 24 distinct valid feature keys by varying cue, palette, and BPM, then calls `clear_run_scoped_caches()`.  
Expected: feature PCM participates in the 64 MiB cache budget and run cleanup removes inactive feature entries.  
Actual: 24 entries grow static memory by 88,272,048 bytes; `pcm_cache_policy_snapshot.bytes` remains zero against a 67,108,864-byte budget; the cache remains at 24 entries after cleanup.  
Frequency: 100% in the probe.  
Impact: long sessions visiting different music palettes/BPMs can retain another 3.09-3.80 MiB stem pack per key indefinitely, producing increasing memory pressure outside telemetry and eviction policy. Web payload preparation can add further retained data.

Root cause: `_feature_stem_cache` is declared separately at `scripts/ui/procedural_music_player.gd:226`. `_feature_stem_set_for_input` uses cue, base palette, and BPM in the key and inserts without a cap at lines 4435-4470. `_load_feature_stem_pack` reloads a full pack for every new key at line 4565. `clear_run_scoped_caches` at lines 394-410 only iterates `_all_pcm_cache_keys()`, and `_exit_tree` at lines 338-352 clears the ambient/accounting caches but not `_feature_stem_cache`.

Fix options: cache delivered packs by delivery style independently of cue/palette/BPM; account feature entries in the existing PCM LRU; clear inactive feature packs at run/scene boundaries; add a cache-size and byte-budget soak contract.

### RP-007 — Medium — Permanent async autosave errors retry every other frame without backoff

Confidence: high. Category: persistence/concurrency/performance.

Reproduction: run `reliability_postfix_probe.gd`; its `AlwaysFailSaveService` accepts each async request and completes it with `ERR_CANT_CREATE`. Over 20 frames, inspect `autosave_retry`.  
Expected: a persistent I/O error is latched or retried with bounded exponential/time backoff and a visible recovery action.  
Actual: `begin_count=10`, `pending_after=true`, and status remains `Autosave failed.`—one complete retry every two frames.  
Frequency: 100%.  
Impact: disk-full, permission, or persistent serialization failures can continuously recapture/serialize and retry disk I/O, causing CPU/I/O churn and repeated backup rotation attempts for the rest of a run.

Root cause: on async failure, `scripts/ui/foundation_main.gd:5821-5825` immediately restores `pending_autosave` and schedules it for the next frame. `_flush_pending_autosave_if_ready` at lines 5791-5801 then starts it as soon as the failed request is no longer in flight. No error counter, time backoff, or fatal-error classification exists.

Fix options: add capped exponential backoff and failure telemetry; stop automatic retries for non-transient errors until another dirty generation or explicit user retry; preserve a single pending generation without serializing it every frame.

### RP-008 — Low — Object-shaped settings corruption is silently accepted as valid settings

Confidence: high. Category: settings recovery.

Reproduction: write `{\"unrecognized_corrupt_payload\":true}` to the configured settings path and call `UserSettings.load()`; the focused probe automates this.  
Expected: an object with no recognized settings schema is preserved as invalid and defaults are restored with a recovery result.  
Actual: result is `code=loaded`, `outcome=loaded-primary`, no `preserved_path` is returned, and the corrupt source remains in place while defaults are silently used.  
Frequency: 100%.  
Impact: corruption that still parses as a JSON object is hidden from the player and support logs; the original evidence can later be overwritten.

Root cause: `scripts/core/user_settings.gd:73-83` calls `DurableStore.read_json(path)` without a validator. DurableStore considers every dictionary loadable (`durable_store.gd:152-158`), while `from_dict` quietly defaults missing keys. Validators are used for profile, meta collection, developer placement, and run saves but omitted here.

Fix options: add a settings schema/version plus a validator requiring a recognized-key envelope; preserve invalid primary files through the existing recovery path; include migration for older valid settings objects.

### RP-009 — Low — Mobile export presets do not opt into distribution identity or isolated persistence

Confidence: high. Category: latent packaging/platform configuration. Android/iOS are credential-blocked and are not current 0.6 release targets, so this is not a current Web/Windows release blocker.

Reproduction: inspect `export_presets.cfg:34-40` and `:71-77`, or export either runnable mobile preset directly.  
Expected: any exported distribution uses fail-closed build identity and the isolated `user://distribution` persistence root.  
Actual: Android and iOS have empty `custom_features`; only Windows and Web set `distribution_build`. `BuildIdentity._distribution_build()` (`scripts/core/build_identity.gd:77-79`) and `PersistencePaths.distribution_build()` (`scripts/core/persistence_paths.gd:11-20`) therefore classify a manual mobile export as a source/development build unless an environment override is injected.  
Frequency: 100% for direct mobile exports from the presets.  
Impact: a future/manual mobile package can share development save paths and fail open to source-harness identity instead of missing-manifest distribution identity.

Root cause: distribution hardening was added only to the maintained Windows/Web pipeline; the credential-blocked presets were not updated and no static gate covers them. The mobile `0.5.1` version stamps are not retained as a defect because README lines 41, 47, and 526-533 explicitly describe them as unreleased/credential-blocked pending `release06_1`.

Fix options: add `distribution_build` to all export presets regardless of signing readiness; make exported builds detect distribution status without an optional feature; extend packaging contracts to all runnable presets.

### RP-010 — High — Default Windows packaging rejects normal debug/release native-library coexistence

Confidence: certain. Category: release packaging.

Reproduction: with the repository's existing debug and release DLLs in `addons/coin_pusher_native/bin`, run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_itch.ps1 -Target all`.  
Expected: release packaging selects the locked `template_release` DLL that it just built.  
Actual: after 97.9 seconds of successful native build, it exits 1: `Expected one built windows native side library before export; found 2.`  
Frequency: 100% while both normal build variants coexist.  
Impact: the maintained default Windows/Web packaging command cannot create a candidate; a developer is tempted to delete an unrelated build artifact to proceed.

Root cause: `Get-NativeSourceLibrary` at `tools/export_itch.ps1:119-123` filters only `coin_pusher_native*.dll` and `*.nothreads.dll`; it does not select the requested `template_release` or `template_debug` variant. The build directory legitimately contains one of each.

Fix options: pass the requested native target into the selector and require exactly one matching platform/target/architecture/threading tuple; add a fixture with both debug and release libraries to the packaging contract.

### RP-011 — High — Windows PCK audit rejects all shipped native PCM assets

Confidence: certain. Category: release packaging/audit.

Reproduction: after selecting the release DLL, run the Windows export and mandatory PCK audit. The diagnostic run produced the EXE, sidecar manifest, and release DLL, then exited 1: `PCK AUDIT FAIL (41)` with every `assets/audio/sfx_native/*.bthpcm` file reported as an unexpected type.  
Expected: the allowlist accepts the project's shipped native PCM container while continuing to reject unknown/leaked content.  
Actual: 41 valid project assets cause a deterministic audit failure.  
Frequency: 100% for the current Windows preset.  
Impact: no Windows artifact can pass the mandatory custody/audit step. This does not imply the PCM content is invalid; it is an auditor policy defect.

Root cause: `export_presets.cfg:9` deliberately includes `assets/audio/sfx_native/**`, but `tools/audit_pck_manifest.py:29-32` allows `.bthadpcm`, `.bthsfx`, and `.bthstems` while omitting `.bthpcm`.

Fix options: add `.bthpcm` to the reviewed allowlist and add positive/negative PCK-audit fixtures covering every custom audio container.

### RP-012 — High — Web export helper mixes Godot stdout into the exit-code return value

Confidence: certain. Category: release packaging/orchestration.

Reproduction: run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_itch.ps1 -Target web`.  
Expected: a successful Godot export returns integer exit code 0 and proceeds to sidecar manifest, PCK audit, and candidate registration.  
Actual: all 11 Web files are produced, but the wrapper exits 1 with `Godot web export failed with exit Godot Engine v4.6...` followed by the entire progress stream.  
Frequency: 100% when Godot writes normal stdout.  
Impact: the maintained Web packaging path always false-fails before custody metadata is completed. The directly produced PCK independently audited PASS with 1,174 files, proving the blocker is orchestration rather than packed-content integrity.

Root cause: `Invoke-WebExportWithLockedTemplate` runs Godot at `tools/export_itch.ps1:137`, allowing stdout into the PowerShell success pipeline, then returns `$LASTEXITCODE` at line 138. Caller line 327 assigns every output object plus the integer to `$exitCode`; line 329 compares that array to zero and throws.

Fix options: stream console output explicitly to host while returning only a typed integer; alternatively execute via `Start-Process` with dedicated stdout/stderr files and consume `Process.ExitCode`. Add a noisy-success executable fixture to the packaging contract.

## Non-defect observations and limitations

- The three generic soaks did not exercise feature music (`feature_stem_cache_size=0` in their snapshots); RP-006 is established by a focused deterministic cache probe rather than those generic soak results.
- Travel warnings such as a requested target not changing the node were already modeled as warnings by the soak harness. All full runs passed their correctness and growth gates; these warnings are not independently retained here.
- The PowerShell `Start-Process` objects used for B/C returned a null `ExitCode` after reaping, while the outer commands returned 0 and both JSON reports said PASS. This is recorded as evidence-wrapper telemetry behavior, not a product defect.
- The diagnostic Windows artifact launched successfully, but it is not a qualified distributable: the normal packaging command failed RP-010, the workaround export failed RP-011, and its embedded manifest therefore never reached complete candidate registration.
- Mobile version `0.5.1` is intentionally parked by current documentation. Only the missing distribution feature is retained.

## Suggested fix order

1. Repair RP-010, RP-011, and RP-012 so a clean Windows/Web candidate can be generated and audited without workarounds.
2. Repair RP-001 and RP-004 so the documented Audit/Full and final performance pipelines can execute on that candidate.
3. Bound and account the feature cache (RP-006), then rerun a feature-heavy long session in native and Web builds.
4. Harden persistence failure behavior (RP-005 and RP-007) and settings validation (RP-008), with fault-injection coverage for every generation state.
5. Clear the health/tooling hygiene failures (RP-002 and RP-003) and harden mobile preset identity (RP-009).

## Evidence index

Primary evidence directory: `.tmp/playtest_2026-09-21/reliability_performance/`.

- `reliability_postfix_probe.log` — focused persistence/settings/audio/autosave results.
- `foundation_soak_{A,B,C}_report.json`, `foundation_soak_{A,B,C}_samples.jsonl`, and process JSON/logs — independent soak evidence.
- `soak_aggregate.json` — cross-run metrics.
- `targeted_runtime_summary.json` plus `targeted_*.log` — durable store, lifecycle, audio, packaging runtime, migration, and startup checks.
- `archive_root_probe_result.json` and `missing_top_level_ps_dependencies.json` — archive relocation proof.
- `health06_1_dead_code_contract_test.log`, `health06_1_standalone_contracts_contract_test.log` — health failures.
- `perf06_*contract_test.log` and `integ06_1_terminal_soak_launcher_contract_test.log` — broken and passing performance gates.
- `export_itch_all.log`, `export_itch_all_workaround.log`, `export_itch_web_direct.log` — three independent packaging blockers.
- `export_itch_workaround_custody.json` — debug DLL before/after SHA and clean tracked status.
- `packaged_windows_runtime_report.json` and process/stdout/stderr logs — bounded fresh-profile diagnostic launch.
- `web_direct_pck_audit.json`, `web_direct_integrity.json` — directly produced Web artifact integrity.

