Status: TODO — execution prompt that finishes the stalled `perf06_1` row
Priority: P1 — `perf06_1` is the only row blocking `playtest06_2`, which produces the owner's next build
Board row: `perf06_1` in `docs/todo/README_0_6_board.md` (currently `IN_PROGRESS`, stale since 2026-09-04)
Opened: 2026-09-11 by PM audit of the row's real state
Supersedes the open items of: `docs/todo/perf06_1_performance_platform_pass_prompt.md` (still binding for intent; this file is the plan)

## Execution Record

_Fill in on completion: date, commit hashes, gate results, deviations._

# Agent Prompt — perf06_1: Finish the Performance and Platform Pass

Copy everything below this line into one agent. It may spawn sub-agents freely.

---

You are working in `D:\Projects\Beat-The-House`. This prompt is complete on its
own. Read all of it before running anything. Several phases are cheap and safe
to do today; one phase must not start until a scheduling condition is met, and
that condition is stated in section 2. Respect it.

## 0. The true state of this row — verified, do not re-derive

The board says `perf06_1` is `IN_PROGRESS` with agent `/root/perf_closeout`,
started 2026-09-03. In reality:

- **The row is stalled, not progressing.** Its branch `codex/perf06-final-run`
  has not moved since 2026-09-04.
- **Its harness work is already on `main`, byte-identical.** `git log
  main..codex/perf06-final-run` lists 4 commits, but that is a hash artifact:
  the same content was rebased onto `main` under different hashes
  (`618d0033`, `92bb16f5`, `6a3485c7`, `33128713`). Verified byte-identical on
  both sides: `docs/plans/perf06_1_final_runtime_runbook.md`,
  `docs/plans/perf06_1_static_harness_review.md`,
  `tools/perf06_binding_preflight.ps1`,
  `tools/perf06_phase_qualification_contract.ps1`,
  `tools/perf06_capture_quiescence.ps1` and `tools/perf06_matrix_contract.ps1`.
  **Do not cherry-pick the branch and do not merge it.** Treat it as a stale
  duplicate, leave it alone, and work from `main`.
- **Two of the landed commits are still labeled `[UNREVIEWED]`** in their
  subjects on `main`: `92bb16f5` "fix(perf): make final qualification fail
  closed" and `618d0033` "docs(perf): stage exact final qualification runbook".
  They are tooling and docs only, no product code, but nobody has verified that
  those fail-closed contracts actually fail closed.
- **Nothing has been measured.** `docs/plans/perf06_1_measurement_prestage.md`
  section "Current completion state" records: native matrix NOT RUN, Web matrix
  NOT RUN, low-end matrix NOT RUN, per-surface allocation/copy matrix NOT RUN,
  composition matrix BLOCKED, **budget/enforcement changes NONE**,
  **optimizations NONE**, final verdict NOT AVAILABLE.
- **The enforcement half of the row is entirely unmet.** Searching for `perf06`
  returns **nothing** in `tools/check_godot.ps1` and nothing relevant in
  `tools/validate_project.ps1`. Every `perf06_*` contract exists as a standalone
  script that no suite runs. The only wired performance stage is a 90-second
  `foundation_perf_smoke`. The original prompt's section 3 — "a future
  regression fails a suite rather than a playtest" — is not delivered.
- **The stated blockers are now clear.** The row's note says the binding matrix
  waited on landed `integ06_1` and `env06_8`. Both are `DONE`. What remains is
  an exact quiesced candidate and the run itself.

**The good news:** `docs/plans/perf06_1_final_runtime_runbook.md` on that branch
is a near-turnkey seven-step qualification procedure with exact commands, exact
sample policy (120 idle frames, 240 active frames, 600-second memory windows,
Chrome CPU throttle 4, 1280x720 compatibility), fail-closed checks at every step
and an immutable-evidence discipline. **Do not rewrite it.** Your job is to
recover it, verify it, close the enforcement gap, execute it, and interpret what
it produces.

## 1. What "finished" means

The original row's terminal conditions still bind:

> This row remains TODO or BLOCKED if any surface reports an idle figure without
> a passing liveness counter, if any budget is exceeded without an owner-approved
> exception, if Web or low-end regresses against 0.5 figures without an
> explanation the report can defend, or if an optimization changed behavior.

Plus the deliverable: a report under `docs/plans/` with the measurement method,
the full per-surface and per-composition matrix for native, Web and low-end,
export size and load figures, the published budget table with liveness pairings,
every optimization with before/after numbers, and every routed finding with
severity and destination.

## 2. Scheduling constraint — read before you run anything heavy

The qualification requires a **quiescent host**. `tools/perf06_capture_quiescence.ps1`
throws if any `Godot_v4.6-stable_win64`, `Godot_v4.6-stable_win64_console`,
`BeatTheHouse` or `chrome` process is alive, and the runbook repeats that check
itself. It also requires `HEAD` to equal the pushed `origin/main` exactly.

**Row `fix06_31` (environment object placement) is running on this machine right
now and spawns Godot continuously.** It is also actively changing environment
composition cost — it measured room compositions of 300-825 ms and a ~51 s
content step during its own profiling. Therefore:

- **Phases 1, 2 and 3 below are safe to run now**, alongside `fix06_31`. They do
  not produce binding numbers and none of them needs a quiet host.
- **Phase 4, the binding qualification, must not start until `fix06_31` has
  merged to `origin/main` and no Godot or Chrome process is running.** A binding
  matrix measured on a tree whose environment placement is about to change is
  wasted machine-hours, and a matrix measured next to a competing Godot process
  is invalid.
- This ordering is a feature: your matrix becomes the proof that `fix06_31` did
  not cost frame time. If it did, that is a finding you route back, not
  something you fix here.

If `fix06_31` is still unlanded when Phases 1-3 are done, report that you are
ready and waiting, with your time estimate from Phase 3, and stop. Do not idle
in a polling loop, and do not start the binding run "just to see".

## 3. Phase plan

Commit at the end of each phase. Keep `main` green.

### Phase 1 — Recover custody of the harness (safe now)

1. `git fetch --all`. Branch from **current `origin/main`**. The harness is
   already there; confirm that for yourself before assuming anything else in
   this section — compare `docs/plans/perf06_1_final_runtime_runbook.md` and the
   `tools/perf06_*` set on `main` against `codex/perf06-final-run`. They were
   byte-identical when this prompt was written. **Do not cherry-pick or merge
   the stale branch**, and do not delete it.
2. **Review the landed `[UNREVIEWED]` work properly.** `92bb16f5` and `618d0033`
   are on `main` still carrying that label. For each: read the diff, then run
   the matching hostile-fixture test and confirm it actually fails closed —
   `tools/perf06_binding_preflight_contract_test.ps1`,
   `tools/perf06_phase_qualification_contract_test.ps1`,
   `tools/perf06_quiescence_contract_test.ps1`. A contract that cannot be shown
   to reject a bad fixture is not a contract. Record the verification in your
   report and in the board note; the labels are historical and stay in history.
3. Run every non-measurement gate from runbook section 2 against today's `main`
   to prove the harness works before a candidate exists. Record which pass,
   which fail and why. A harness failure now is far cheaper than one at hour six.
4. Correct the board row note to the true state and re-claim the row with your
   own agent identity and today's date. The previous claim is seven days cold.

### Phase 2 — Close the enforcement gap (safe now)

The row cannot close with zero wired gates. Wire the existing contracts so a
future regression fails a suite:

- Register the **cheap contract-level** perf checks in `tools/check_godot.ps1`,
  following the precedent of `scenario_room_multiseed_finalization` in the
  `Audit`/`Full` suites, and add a `Require-Text` assertion in
  `tools/validate_project.ps1` so the wiring cannot be silently removed — that
  is exactly how the 8x55 room gate is protected.
- **Do not add anything heavy to Smoke/contracts.** That stage measured
  227.786 s against a 230.391 s budget at `fix06_30`. A budget increase needs
  owner sign-off. Heavy producers belong in `Audit`/`Full`.
- **Structural liveness pairing.** Every idle timing assertion must sit in the
  same test as its liveness counter assertion, so a later well-meaning edit
  cannot separate them. This project has frozen idle table animation four times
  by rewarding a 0.000 idle figure. An idle cost of 0.000 is a failure.
- **Allocation assertion class.** A per-frame allocation and deep-copy assertion
  with a negative fixture, so the pattern that once cost 32.6 ms/frame in the
  slot bonus watchdog cannot return silently.
- These must be green on `main` before the candidate run, and they must not
  depend on binding measurement data to pass.

### Phase 3 — Reduced-sample dry run (safe now, do not skip)

Execute the **entire** runbook end to end at reduced sample counts against a
scratch candidate, writing to `.tmp/perf06-dryrun-<stamp>/`:

- roughly `-Frames 30 -ActiveFrames 60 -MemorySeconds 60`, composition
  `-SeedCount 32 -ShardCount 2`, terminal soak `-ShardCount 1`.
- The `HEAD == origin/main` and quiescence checks will refuse to pass during a
  dry run. Satisfy them honestly: run the dry run from a clean checkout of
  current `origin/main` at a moment when no Godot job of yours is running, or
  run the producers directly and record explicitly that the custody wrappers
  were exercised separately. **Never edit a contract to make a dry run pass**,
  and never label dry-run output as evidence.

Purpose: prove every producer and consumer executes, prove the section 7
aggregation actually consumes what sections 3-6 emit, and **measure the
wall-clock cost of the real run**. Report that estimate. A multi-hour binding run
that dies at step 7 on a schema mismatch is the failure mode this phase exists
to prevent.

Fix whatever the dry run breaks, in the harness only.

### Phase 4 — Binding qualification (only when section 2's condition is met)

Execute `docs/plans/perf06_1_final_runtime_runbook.md` exactly, at full sample
counts, all seven steps, three profiles (`native`, `web`, `low_end`).

- **Witness identities.** The runbook requires distinct
  `BTH_PERF_WORKER_WITNESS` and `BTH_PERF_DIRECTOR_WITNESS` values. Use your own
  agent identity as the worker witness. The director witness is supplied by the
  operator who launches you; it is an attestation that the host was quiescent.
  **Do not invent a second identity and do not reuse your own.** If no director
  value was supplied, say so and stop — that is a one-line answer from the
  owner, not a reason to fabricate custody.
- **No retrying into a pass.** A producer failure stops qualification. Diagnose,
  fix the cause, and start a fresh evidence directory. Evidence directories are
  immutable; `perf06_capture_quiescence.ps1` refuses to overwrite one.
- **No waiving.** A red budget stays red. It is resolved by a measured
  optimization or an explicit owner exception, never by editing
  `tools/perf06_budget_table.json` to fit the result.
- If a run must be abandoned, keep the partial evidence directory and say why.

### Phase 5 — Optimize only what the measurements name

- Work in measured-cost order. Do not refactor for elegance and do not touch a
  surface the numbers exonerate.
- Every optimization preserves behavior exactly: identical outcomes, identical
  determinism, identical native/Web parity, identical liveness. Prove each with
  the relevant gate, not by inspection. Run `tools/foundation_determinism_probe.ps1`
  and the parity gates after each one.
- **Anything that changes behavior, feel or timing is a finding, not a fix.**
  Route it as a `fix06_*` row with severity and destination, and say so in the
  report.
- Re-measure the affected cells after each optimization into a **new** evidence
  directory, and state clearly in the report which numbers came from which
  candidate.
- Note for this cycle: `fix06_31` will have just rewritten environment
  placement. If room composition or environment draw cost appears in your
  ranking, route it to that row rather than optimizing its fresh code yourself.

### Phase 6 — Report and budgets

Write `docs/plans/perf06_1_performance_platform_report.md` containing:

1. The measurement method: hardware manifest, build type, resolution, settings,
   seed set, warm-up policy, samples per figure, and the artifact SHA-256 index
   the runbook's section 7 produces.
2. The full matrix: every surface and composition across native/Web/low-end,
   idle and active, with mean, p95, max, draw behavior, allocation behavior, and
   the liveness counter beside every idle figure.
3. Web export size, initial load, time to first interactive frame, memory
   ceiling, cold and warm startup.
4. The published budget table with its mandatory liveness pairings.
5. Every optimization with before and after numbers.
6. Every routed finding with severity and destination.
7. **Honest comparator handling.** `perf06_1_measurement_prestage.md` section
   "Missing 0.5 comparators" lists what has no like-for-like 0.5 record: Coin
   Pusher, the dynamic scenario runtime with a full sequence staged, crew
   sequences at current actor counts, the environment expansions at maximal
   population, `integ06_1` maximal compositions, the allocation matrix, physical
   low-end runs, and full per-surface Web tables. These are **"no historical
   comparator"** — not regressions and not passes. Establish the 0.6 baseline for
   them and compare only metrics whose definitions still match. Do not
   manufacture a comparison.
8. A plain-language section the owner can read in two minutes: is the game fast
   enough to ship on Web and on a low-end machine, and where is it closest to
   the line.

If any budget is red at the end, do not close the row. Report it with the number,
the surface, and the proposed optimization or the exception you need, and stop
for the owner's ruling. That is the one decision in this row that is not yours.

### Phase 7 — Closeout

Only after every gate is green and the report is written:

- Commit in logical units: harness recovery; enforcement wiring; optimizations;
  report.
- Fill in the Execution Record at the top of this file.
- Set the board row to `DONE` with a one-line verification summary, the report
  path and the exact commands.
- `git mv` this file and `docs/todo/perf06_1_performance_platform_pass_prompt.md`
  to `docs/todone/`. Archive, never delete.
- Append a line to `docs/todo/README_0_6_work_log_2026-08-26.md` naming
  `playtest06_2` as unblocked.
- Merge to `main` with `main` green and push so `origin/main` is in sync. If
  another agent is mid-merge, use an isolated worktree and hold.

## 4. Hard limits

- **Never weaken a test, budget, liveness floor or deterministic assertion to go
  green.** Never refresh a golden without proving the content legitimately
  changed. Never edit the budget table to match a measurement.
- **An idle draw cost of 0.000 is a failure, not a pass.** Four recorded
  regressions in this project.
- **No per-frame deep copies.** 32.6 ms/frame, once, in the slot bonus watchdog.
- **Measurement is not behavior change.** No change to money, RNG, RTP, payouts,
  odds, schema or migration. No gameplay, feel or timing changes — those are
  findings.
- **No release activity:** no version bump, tag, packaging, upload or publish.
- **Delete nothing:** no branch, worktree, stash or evidence directory. No `gc`,
  `reset --hard` or `clean`. `codex/perf06-final-run` stays where it is.
- **Never stage owner property:** `.tmp/`, `.tools/`, `review_artifacts/`,
  `builds/`. All evidence lives under `.tmp/` and is referenced by path and hash
  in the report, never committed.
- **Do not restructure the board** beyond your own row.
- Leave no diagnostics in the tree.

## 5. Standards every row inherits

- Action boundaries, never wall-clock; everything seeded from run RNG.
- Hidden state is absolute; a leak is an automatic P0.
- Native/Web parity is a requirement, not a nice-to-have.
- Tab-indented, typed GDScript; PowerShell matching the existing `tools/` style;
  sparse comments that state constraints rather than narrate.
- Cheap validation: `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`.
  Targeted: `tools/check_godot.ps1 -Suite <Smoke|Contract|Audit|Full> [-FoundationSuite <name>]`.
  Godot: `.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe`.

## 6. Reporting cadence

Report at the end of each phase, briefly: what you ran, what it said, what you
changed, and what you are waiting on. After Phase 3, give the wall-clock estimate
for the binding run so the owner can decide when to give up the machine. After
Phase 4, lead with the headline: does it hold its frame budget on Web and
low-end, and what is closest to the line.

Your terminal condition is a committed report that answers "is 0.6 fast enough to
ship, on every platform we ship to", backed by a green three-profile matrix and
gates that will catch the next regression without a human noticing it first.




