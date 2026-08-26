Status: PARKED - do not claim until triage and owner-required fixes are complete
Board row: `balance06_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** -
- **Completion/tuning commits:** -
- **Candidate base and harness identity:** -
- **Changed values and supporting finding/proposal ids:** -
- **Before/after evidence:** -
- **Verification:** -
- **Deviations:** -

# Agent Prompt - 0.6 balance06_2: Post-Playtest Balance Tuning

Copy everything below this line into the agent only after the board coordinator
has changed this row from `PARKED` to `TODO`.

---

You are working in `D:\Projects\Beat-The-House`. This is the one post-playtest
row that may apply tuning values. It consumes the ranked, measured proposals
from `balance06_1` and the owner's accepted felt-experience findings from the
playtest. It proves the result with the same committed harness before and after.

This row is not release activity. Do not bump a version, build/package a
release, tag, upload, publish, write final public copy, or claim an owner
release gate. Do not change presentation, prose, content, rules or system
structure.

Read in full:

- `docs/plans/0.6_post_playtest_program.md`;
- the `balance06_1` execution record, report and committed harness;
- `docs/plans/0.6_post_playtest_triage.md` and every accepted balance-related
  `PT06-*` finding;
- every post-playtest `fix06_*` execution record;
- the current roadmap, board, economy data and every live consumer of a value
  proposed for change.

## Claim gate

Follow the active board protocol. Do not self-unpark. Claim only if the row is
`TODO`, `balance06_1` and `triage06_1` are DONE, every owner-required
`fix06_*` row is DONE, and the owner has confirmed that the tuning inputs are
complete. Verify the committed harness exists and runs on the candidate base
before touching a value. If not, stop through the board's blocked protocol.

The post-playtest program supersedes the old balance-application wording in
`release06_1`: this row applies the final tuning; `release06_1` later re-runs
and verifies it but does not silently tune again.

## 1. Freeze the comparison

Before any product edit, record:

- clean base commit and exact `balance06_1` harness commit/path;
- harness commands, tool/engine identity, playstyles, seed sets, action policy,
  sample counts, stopping rules and output schema;
- current tuning values and their exact consumers;
- baseline per-playstyle distributions for bankroll over time, debt thresholds,
  victory time, action use, heat, failure causes and pressure-versus-choice
  endings, plus every game/route EV or RTP measurement the proposal affects.

Commit or reference the immutable baseline report before tuning. A harness
failure or a baseline that does not reproduce `balance06_1` within its stated
variance is a blocker to diagnose, not permission to change seeds, policies,
budgets or thresholds.

## 2. Build the joint-support matrix

Create `docs/plans/0.6_post_playtest_balance_tuning.md`. Every candidate change
must have a row with:

- exact value/path and current value;
- ranked `balance06_1` finding and proposal id;
- accepted playtest `PT06-*` finding describing the felt experience;
- proposed value and predicted distribution change;
- route/playstyles helped and harmed;
- rule, presentation, content and save consumers checked;
- risk, rollback value and acceptance band;
- disposition: `APPLY`, `NO CHANGE`, or `NEEDS OWNER DESIGN DECISION`.

Apply a value only when both evidence sources support the same direction. A
simulation finding without owner felt support stays a proposal. A feel note
without measured support stays a finding. Conflicting signals produce
`NO CHANGE` or an owner design decision; the agent does not choose a design.

## 3. Tuning-only ownership

Allowed changes are numeric or enumerated tuning values already exposed by the
landed design, and only the values identified in the joint-support matrix.
They may live in data or named tuning constants, but changing code paths merely
to reach a new outcome is not tuning.

Forbidden changes include:

- game rules, eligibility, phase order, caps as concepts or outcome classes;
- new/removal of content, items, services, jobs, events, dialogue or routes;
- UI, art, audio, animation, voice or public text;
- RNG algorithms, seed flow, harness policies or test tolerances;
- save schema, migration behavior or hidden-information surfaces;
- bug fixes, refactors, cleanup, versioning and release artifacts.

If the smallest supported change crosses a forbidden boundary, record it as a
new finding for owner disposition and leave the value unchanged. A conservation
violation or implementation bug returns to a `fix06_*` row; do not tune around
it.

## 4. Apply in reversible logical units

Group only coupled values whose prediction was measured together. One commit
must identify the affected system and `PT06-*` / `balance06_1` proposal ids.
After each group, run focused rules/conservation/EV checks and the common
harness slice. Revert that group through a new corrective commit if its
acceptance band fails; do not weaken the band or keep an unexplained change.

Never tune directly from a single seed or a mean. Inspect distribution shape,
tails and cross-playstyle displacement. A gain for one playstyle that makes a
different intended route dead is not an improvement unless the owner explicitly
approved that tradeoff as design.

## 5. Before-and-after proof

On the final head, rerun the exact baseline commands with identical playstyles,
seed sets, action policies, sample counts and stopping rules. The report must
place before and after side by side for:

- each changed value and its predicted versus observed effect;
- bankroll distribution over time, percentiles and tails;
- time to debt thresholds and each victory route;
- action use, heat trajectory and terminal causes;
- dominant/dead strategy incidence;
- affected game RTP/EV and money-conservation checks;
- crew, Numbers, job, delivery, play, heist, pusher, craps, service, item,
  scenario and 0.5-control interactions as applicable.

Explain variance and non-results. Do not assert `feels better` as evidence; map
the measurements back to the owner's finding and record the owner acceptance
of the final felt result separately.

## 6. Regression gates

Run on the exact final source:

- `tools/validate_project.ps1`;
- the committed `balance06_1` full-run harness and every affected EV/RTP audit;
- affected Foundation systems and UI suites;
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`;
- relevant save/migration, money-conservation, platform-parity and performance
  checks identified by the changed value's consumers.

Budgets, bands, liveness floors, assertions, seed sets and sample counts do not
move to accommodate the result. Suite timeout is max(300 seconds,
baseline x 1.5).

## Completion

Finish only when every changed value has joint support, before/after evidence,
an accepted band and clean focused/full regressions; every rejected proposal is
recorded; the diff contains tuning values and its report only; and the owner
has accepted the tuning result. Commit in logical `balance06_2` units and hand
off for independent review.

The primary integrator then records the exact report/harness commands and
accepted head, updates and archives through the board protocol, and may unpark
`cleanup06_1`. Do not start cleanup, voice or release work.
