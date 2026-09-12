# perf06_1 Performance and Platform Report

Status: qualification not yet run; this report is the live execution ledger.

Candidate custody begins from pushed `origin/main` commit `c570f2ce6fafa4212292f8b129ca08f2e9e1e954`. The binding candidate may change when the required `fix06_31` environment work lands; only the final exact pushed candidate may supply binding figures.

## Harness recovery and review

The six named harness artifacts on `origin/main` are byte-identical to `codex/perf06-final-run`: `docs/plans/perf06_1_final_runtime_runbook.md`, `docs/plans/perf06_1_static_harness_review.md`, `tools/perf06_binding_preflight.ps1`, `tools/perf06_phase_qualification_contract.ps1`, `tools/perf06_capture_quiescence.ps1`, and `tools/perf06_matrix_contract.ps1`. The stale branch was neither merged nor cherry-picked.

The historical `[UNREVIEWED]` changes `92bb16f5` and `618d0033` were read and verified on 2026-09-11. Their hostile-fixture suites pass and demonstrate rejection of nonignored untracked files, staged and unstaged changes, occupied ports, below-floor idle liveness, forged static-zero authority, missing active progress, published timing overruns, missing witness custody, wrong sequencing, and mutable evidence destinations:

- `powershell -ExecutionPolicy Bypass -File tools/perf06_binding_preflight_contract_test.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/perf06_phase_qualification_contract_test.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/perf06_quiescence_contract_test.ps1`

## Non-measurement gates

All runbook section 2 gates passed on `c570f2ce` on 2026-09-11. This includes Godot parser/import, required-matrix, budget, phase qualification, quiescence, binding preflight, allocation, Web idle liveness, Coin Pusher clock, Web prestage, Coin Pusher action diagnostics, complementary startup, run-UI deferral, backglass readability, deferred validation, Web READY snapshot, idle-liveness runtime, and Coin Pusher production static-cache checks. Total observed wall time for this local gate batch was 116.9 seconds; its output is validation only and is not binding performance evidence.

## Enforcement wiring

Completed on 2026-09-11 without changing any product code or published budget. `tools/check_godot.ps1` initially added 13 cheap performance contract stages in both Audit and Full; the Phase 3 terminal-launcher regression test brings the current total to 14. Smoke and Contract are unchanged. `tools/validate_project.ps1` pins the stage function, both suite registrations, the structural idle timing/liveness contract, the allocation/copy contract, and exact-candidate terminal host-library discovery so the wiring cannot disappear silently.

The shared phase assertion rejects idle rows unless sampled frame and draw mean/p95/max values are positive and the same assertion also contains a passing, positive, contract-owned liveness counter and floor. A 0.000 idle draw fixture and a below-floor liveness fixture both fail. The shared allocation/copy assertion records allocation, shallow-copy and deep-copy rates per steady-state frame, rejects invalid counters or non-steady scope, and enforces the unchanged zero steady-state deep-copy policy. Its hostile fixtures reject recurring deep copies, negative counters, and warm-up evidence presented as steady state.

Verification:

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1` — PASS.
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -Suite Audit -RequireGodot` — PASS in 731.7 seconds, including all 13 new `perf06_audit_*` stages, the permanent 8×55 room finalization gate, Slot Pinball, the 10,000-case Slot deep audit, and Roulette audits. Structured diagnostic report: `.tmp/test_reports/20260911_192001_audit/summary.json`.

## Reduced-sample dry run

Phase 3 ran on 2026-09-11 alongside the active `fix06_31` work, so every number below is deliberately **non-binding**. The host was not quiescent, the candidate was a clean isolated worktree rather than pushed `origin/main`, and the operator supplied no director witness. The runs used 120 idle frames where a surface consumer requires that published sample shape, 80 active frames, 60-second memory windows, 12 resolve samples, 32 composition seeds over two shards, and one terminal shard. Profiles were the captured normal and reproducible one-CPU/BelowNormal dry-run manifests.

The principal retained attempt is `.tmp/perf06-grand-order-check-20260911-211900/` on candidate `38580344`. It proved the parser/non-measurement/static-cache/allocation paths, normal native and Web producer launches, cold/warm selection, runtime summaries, and fail-closed surface consumption. Later harness fixes necessarily moved terminal evidence to candidate `10eee85a` and low-end evidence to `a69943d8`; those directories are named below and were never overwritten.

| Path | Result | Wall time / key result |
| --- | --- | --- |
| Foundation, normal | RED | 192.6 s; five timing rows red. Report SHA-256 `95cb4029d77752e36c4288699b7b16b6058ba3cc313339b33df5775ff28c2b8f`. |
| Native distribution first start | PASS | 128.0 s. Summary SHA-256 `237df8db232c5c6e96daed2ca29a0c0b7ffa6bcb4717aa4d04050fe4ce0f5d92`. |
| Native L0.2 | RED | 277.3 s; four blackjack draw-p95 phases measured 5.554-5.898 ms against 5 ms. Liveness passed. |
| Native Grand Casino | runtime PASS / surface RED | Runtime budgets passed; the consumer rejected 15 rows without complete live evidence. |
| Native Coin Pusher | RED | 139.6 s; ceiling-refusal draw p95 7.693 ms against 5 ms. Liveness passed. |
| Web distribution first start | PASS | 65.7 s after the locked Web toolchain was installed and bundled Playwright was placed on `NODE_PATH`. |
| Web L0.2 cold | RED | 432.7 s; all 60 scenarios completed. Corner Store open was 3,488 ms/1,200 ms; six frame-p95 rows were also red. |
| Web L0.2 warm | RED | 424.1 s; all 60 scenarios completed. Corner Store improved to 2,405 ms but remained over 1,200 ms; five frame-p95 rows were red. |
| Web Grand Casino | runtime PASS / surface RED | 218.9 s; all 43 runtime scenarios completed, then the consumer rejected the same 15 incomplete-live-evidence rows as native. |
| Web Coin Pusher | RED | 174.6 s; ready was 21,803 ms/20,000 ms and six frame/draw rows were red. |
| Composition matrix, 32 seeds / 2 shards | INCOMPLETE | The execution host cut off the coordinator after 635.9 s while shard children were still active. It retained 115 partial files but no manifest, so the output is intentionally not consumable. |
| Terminal soak, 1 shard | RED | 469.4 s; the corrected launcher reached native custody, then failed on resource growth 25/8 plus terminal/progression and active-system witness failures. Runtime SHA-256 `d3a598deffd2a672354e29ace47122bfcc0b791a333745841becfd193ffa01f2`. |
| Low-end launcher preflight | PASS | 2.3 s on the declared one-CPU/BelowNormal whole-process profile. |
| Low-end whole-matrix launcher | RED at first producer | 224.5 s; dialogue p95 31.528/16 ms, crew selection 36.037/16 ms, eviction transition 22.248/16 ms, Coin Pusher active-drop draw p95 16.07/7 ms, and the shipped 160-body live sequence did not complete. Report SHA-256 `b00e0f99bc63700bc3c508945266209b8107323ba33f31fe0f15f54f2e2aedc3`. |

Grand Casino supplied the clearest deterministic product blocker on both platforms: `scenario::grand_casino_convention_crowd_convention_coordinator` cannot resolve both normal and expanded-small-screen geometry without ambiguity. Runtime timing can pass while `semantic_ready` remains false; the surface consumer correctly refuses to call that evidence live. This is in the active environment-placement scope and is routed to `fix06_31`, not masked here.

Phase 3 also found and fixed these harness defects, each in a new candidate and with a permanent regression contract where applicable:

- stale native discovery after an in-run build;
- producer dictionaries rejected by the report builder;
- missing real progress evidence for slot autoplay, Slot Pinball, and scripted memory;
- incomplete Grand Casino setup/install ordering that invalidated evidence before the semantic seal;
- terminal soak copying obsolete, unversioned host libraries from another worktree instead of deriving versioned libraries from the exact candidate descriptor;
- low-end child invocations serializing `SwitchParameter` objects instead of passing an actual switch.

The combined native/Web/low-end matrix consumer could not validly run: red producer summaries are rejected before surface reports, Grand Casino surface reports are red, the composition producer has no manifest, and the low-end launcher correctly stopped at its first red gate. This is fail-closed behavior, not a schema mismatch or a partial pass.

### Binding-run wall-clock estimate

Reserve **12 uninterrupted hours**, with an optimistic lower bound of about **8 hours**, after the prerequisites are met. The normal reduced producers already consumed about 40 minutes excluding the incomplete composition attempt; each normal and low-end L0.2 cold/warm path gains nine minutes when its memory window grows from 60 to 600 seconds. The 32-seed/2-shard composition attempt exceeded 10.6 minutes before producing a manifest, while the binding run requires 512 seeds/8 shards. The one-shard terminal attempt took 7.8 minutes before an early native failure, while binding requires three complete shards across native and Web. The low-end launcher repeats the full producer and integration matrix under one logical CPU, removing most shard parallelism. The estimate includes setup and artifact hashing but no retry; a red producer stops the run.

## Binding measurement method and artifact index

Pending the scheduling prerequisites and full seven-step runbook execution. As of the final 2026-09-11 check, `origin/main` is still `c570f2ce`, `fix06_31` exists only on its active local branches, Chrome processes are present, and both `BTH_PERF_WORKER_WITNESS` and `BTH_PERF_DIRECTOR_WITNESS` are unset. Phase 4 was therefore not started.

## Native, Web, and low-end matrix

No binding measurements are available. Dry-run timing and failure rows above are diagnostic only and do not establish a 0.6 baseline.

## Export, startup, load, and memory

No binding measurements are available. The dry run did verify fresh Web export, isolated first-run storage, cold/warm browser profiles, ready/first-interactive capture, and memory-window schema, but its red and non-quiescent values are not a ship measurement.

## Published budgets and liveness pairings

The published table remains unchanged. Its structural contract and both native/Web consumers were exercised. An idle timing row is rejected unless the same assertion carries positive sampled timing plus a passing positive liveness counter and floor; zero animated-idle liveness remains a failure.

## Optimizations

None. No product code, behavior, RNG, economy, payout, feel, timing rule, budget, or liveness floor has been changed by this row. Phase 3 changes are evidence-harness fixes only.

## Historical comparator handling

The missing like-for-like 0.5 comparators named in `docs/plans/perf06_1_measurement_prestage.md` will be labeled `no historical comparator`. They will establish 0.6 baselines and will not be called regressions or passes against invented history.

## Routed findings

- **P1 / `fix06_31`:** Grand Casino convention-coordinator geometry is ambiguous in normal plus expanded-small layouts; native and Web both remain semantically unready and lose 15 live matrix rows.
- **P1 / integration follow-up after `fix06_31`:** one-shard terminal soak exceeded retained-resource growth (25/8), missed several terminal outcomes, and lacked exact active-system witnesses. Re-evaluate on the landed environment candidate before assigning product ownership.
- **P1 / `perf06_1` binding rerun:** normal Web cold/warm startup and several frame/draw rows were red on the busy host. These are provisional scheduling risks, not claimed regressions, until the required quiescent run.
- **P1 / `perf06_1` low-end:** the declared one-CPU launcher failed its first producer on four timing rows and one real-progress sequence. Re-measure after `fix06_31`; do not waive or tune budgets from this dry run.
- **Harness / resolved here:** exact-candidate library discovery, low-end switch forwarding, native solver refresh, producer dictionary compatibility, and real progress capture defects listed above.

## Owner summary

There is no ship verdict yet. The qualification machinery now fails closed and the dry run found real blockers before consuming machine-hours, but 0.6 cannot be called fast enough for Web or low-end until `fix06_31` lands, the host is quiescent, a distinct director witness is supplied, and one fresh 8-12 hour three-profile run is fully green.
