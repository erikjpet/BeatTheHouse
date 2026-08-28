Status: **CONTRACT-READY / UNREVIEWED — do not claim until Families 1 and 2 are accepted**

Board row: `balance06_1-follow-on` (to be added or opened only by the board
owner)

# Agent Prompt — balance06_1-follow-on: Full Cross-System Economy Audit

Copy everything below this line into the implementation agent only after the
board owner has made the row claimable.

---

You are working in `D:\Projects\Beat-The-House`. Complete the measurement work
deferred from `balance06_1`: run full combined-economy distributions on the
accepted Families 1 and 2 game, run the existing 600,000-accepted-drop pusher
EV program, publish ranked findings, and publish option-neutral proposals for
later owner disposition. This is an audit and evidence row. It does not tune
the game.

The partial audit landed at
`7c748f5bba4409491e35eddc97793d6ec90da711`. Its finalized provenance head is
`1c0dec3b1e091939cccc8295b9a218be2aa42b96`, its independently accepted
semantic head is `7967a1e1fbe563dbf8008d0e64048c46f4dcecaf`, and the committed prototype
harness identity is `e74a57cebbda198cda9c1a95ada1c2081f1bb7c6`. These are provenance, not a
base-selection instruction. Work only from the exact integrated candidate
assigned by the board after both families are accepted.

This row is not release activity. Never push, publish, upload, tag, version,
package a release, alter remote state, or claim an owner/release gate.

## Read before claiming

Read in full:

- `docs/todone/balance06_1_cross_system_economy_audit_prompt.md`;
- `docs/plans/balance06_1_cross_system_economy_audit.md`;
- `docs/plans/balance06_1_handoff.md` and
  `docs/plans/evidence/balance06_1/README.md`;
- `tools/cross_economy_audit.gd`, `tools/cross_economy_audit.ps1`,
  `tools/coin_pusher_ev_harness.ps1`, and
  `tools/coin_pusher_ev_shard.gd`;
- `docs/plans/0.6_living_world_roadmap.md`,
  `docs/plans/0.6_remaining_work_program.md`, and
  `docs/todo/cross06_0_cross_cutting_orchestration_prompt.md`;
- the accepted execution records, contracts, reports, and exact heads for all
  Family 1 and Family 2 rows;
- `docs/todo/playtest06_2_playtest_gate_refresh_prompt.md`,
  `docs/plans/0.6_post_playtest_program.md`, and
  `docs/todo/balance06_2_post_playtest_tuning_prompt.md`;
- the current board, every current economy data file, every live consumer of
  measured values, and the accepted pusher closure record.

If any named document has moved, resolve it from the board and history and
record the resolved path. Do not silently substitute a similar document.

## Claim and exact-tree gate

Do not self-open, self-claim, or edit the board. Claim only when the board owner
assigns this row and identifies an integrated exact commit containing accepted
Families 1 and 2. Before touching a harness, record:

- branch, full `HEAD`, full tree hash, clean tracked status, and upstream/base
  relationship;
- accepted heads and landing commits for every Family 1 and Family 2 input;
- the exact partial-audit and pusher harness blob hashes used or replaced;
- Godot/native-plugin binary identity and SHA-256, Web runtime identity, OS,
  CPU, worker count, and tool versions;
- an immutable manifest of every economy/RNG/policy/value input and its blob or
  content hash.

The recorded tree is the measurement subject. A source change, harness-policy
change, value change, plugin change, or altered input manifest invalidates
affected evidence. Freeze a new identity and rerun those measurements; never
combine results from different trees into one distribution.

If either family is not accepted, the candidate is dirty, a required exact
head cannot be identified, or the ignored native plugin cannot be built and
hashed for the exact candidate, commit a clearly labelled unreviewed handoff,
park the row with the reason, and stop. Historical green evidence is not a
substitute.

## Authority: measure, do not redesign

Preserve all accepted economy values, RTP/EV bands, rewards, costs, odds,
eligibility, caps, routes, rules, RNG algorithms/streams, action policies,
geometry, physics, save schemas, migration behavior, and performance budgets.
Do not tune, normalize, rebalance, repair, refactor, or broaden production
authority to make a measurement pass.

The only permissible code changes are opt-in audit/test tooling and the
smallest non-production fixtures needed to observe accepted behavior. They
must not run in default gameplay or default suites, change production state,
introduce caller-authored outcomes, or weaken a gate. If the audit exposes an
observable product defect, preserve the evidence and route a separate
`fix06_*` candidate through the board owner. Infrastructure defects that block
the audit are repaired inline when truly blocking and batched when not, with
no product-behavior change.

Only a later owner-authorized `balance06_2` row may apply supported tuning.
This row cannot infer that authority from a finding, a target band, a failed
distribution, or a playtest note.

## Anti-loss protocol

Work on a named `codex/` branch in a named worktree. Commit WIP at least every
30 minutes with `UNREVIEWED` in the subject until acceptance-ready. Nothing may
exist only in a working tree. Never leave a stash or unnamed detached `HEAD`.
Never remove a worktree containing uncommitted tracked changes, and never
delete a branch whose commits are unreachable from main.

If blocked for more than 20 minutes, commit the exact WIP, record the blocker
and decision needed, park the row, and switch to explicitly pre-staged work.
Do not idle. Do not delete, move, stage, or repurpose owner files under
`.tmp/`, `.tools/`, or `review_artifacts/`. Raw evidence generated there must
be copied into a committed evidence destination only by an explicit,
hash-verified step; do not stage those owner directories themselves.

## 1. Audit the audit harness before scaling it

Treat the landed eight-playstyle harness as a prototype, not as proof that its
policies exercise the accepted combined game. Before the full run:

1. Trace every policy action through production entry points. The harness may
   choose from player-visible legal actions; it may not fabricate route access,
   crew/job status, rewards, costs, outcomes, receipts, capabilities, draw
   results, machine state, or settlement data.
2. Publish a coverage matrix for each playstyle against games, jobs, crew,
   plays, Numbers, deliveries, heists, items, services, events, travel,
   lenders/debt, heat, scenarios, and pusher machines. State inaccessible and
   never-selected opportunities separately from selected actions.
3. Validate stopping rules and censoring. Every run must reach an accepted
   terminal condition or be labelled censored with exact reason, action count,
   and remaining reachable routes. Do not describe a censored run as a win,
   loss, or voluntary ending.
4. Record opportunity denominators. A specialist that never reached its
   named system is failed policy/coverage evidence, not evidence that the
   system has zero value.
5. Freeze playstyle definitions, seed construction, maximum actions, tie
   breakers, selection rules, and output schema before the first full shard.
   Hash them. Any change restarts affected shards.

Retain the eight required playstyles: crew-ignoring control, pure gambler,
crew maximizer, Numbers specialist, coin-pusher grinder, cheater, heist rusher,
and mixed opportunist. Additional policies require a written reason and do not
replace any required policy.

## 2. Full combined distributions

Run at least 64 deterministic seeds for each required playstyle on the same
exact candidate and frozen policy: at least 512 complete or explicitly
censored runs. Use the accepted 208-action maximum unless the accepted design
defines an earlier terminal condition. A higher ceiling requires a separately
reported sensitivity run; it must not erase or relabel the 208-action result.

For every playstyle and in aggregate, publish machine-readable raw runs and
distribution summaries, including:

- bankroll, liquid cash, inventory value, debt principal/interest, and net
  position over action/time checkpoints;
- source/sink ledgers and conservation reconciliation by system and origin;
- time/actions to debt thresholds, recovery, each victory path, insolvency,
  arrest/failure, abandonment, and censoring;
- game/route usage, opportunity denominators, action consumption, travel,
  heat, crew trust/resources, Numbers participation, plays, deliveries, jobs,
  heists, items/services/events, and scenario effects;
- terminal cause split into system pressure, policy choice, unavailable route,
  and action-cap censoring;
- mean, median, standard deviation, stated confidence interval, percentiles,
  tails, success/incidence rates, and sample count. Never report a mean alone.

Explain seed independence, deterministic repeat semantics, confidence method,
multiple-comparison risk, censoring bias, policy limitations, and the smallest
effect the sample can credibly discuss. Do not turn statistical noise into a
finding.

### 0.5 comparison

Compare with 0.5 numeric data only when an authentic, comparable 0.5 source,
policy, seed rule, and measurement definition can be cited and reproduced.
Report differences in scope and uncertainty. If no comparable control exists,
write `NO COMPARABLE 0.5 BASELINE`; do not reconstruct values from memory,
documentation prose, or present-day assumptions.

## 3. Existing 600,000-drop pusher EV program

Use the accepted production pusher implementation and the existing EV harness.
Run exactly three machine strata with at least 200,000 accepted paid player
drops each: `quarter_falls`, `jackpot_ridge`, and `vault_drop` — at least
600,000 accepted paid drops combined. Record attempted versus accepted drops,
shards, seeds, policy hash, geometry hash, machine instance count, pile resets,
and rejection reasons.

Each shard must use one persistent machine instance with no favorable reset or
outcome selection. Exercise the full accepted apparatus/phase domain and
natural collection cadence. Preserve the production 160-body cap and exact RNG
stream ownership. Opening stock, paid-origin physical value, ending active
paid value, credited/rider value, Plinko instant value/bonus drops, Ridge
credits, and Vault option/fragments must be reconciled and reported separately
as defined by the accepted harness. Never merge option or rider value into the
physical coin-drop ROI.

Publish per-machine conservation, lower/upper stock-adjusted physical ROI,
shard dispersion and 95% intervals, authored-band comparison, phase/apparatus
coverage, origin reconciliation, and all existing assertions. This audit may
report an out-of-band result; it may not change geometry, apparatus, values,
bands, physics, shard policy, RNG, or tolerance to make it pass.

## 4. Hostile authority and privacy probes

For every audit-facing adapter or seam, add or preserve negative controls that
attempt to substitute caller-authored run/seed identity, game/node/route,
member/job/debt state, receipt/delivery status, reward/cost/payout, outcome,
availability/capability, RNG state, value manifest, and terminal status.
Unauthorized fields must be ignored or rejected before mutation. Rejected
probes must leave economy, world, crew, machine, save, work queues, receipts,
and every RNG stream byte-identical.

The harness and reports must not expose information unavailable to the acting
player, including future Numbers draws or rig state, Turn state, sweep state,
heist outcomes, hidden detection/heat inputs, unrevealed scenario facts, or
other private authority. Use paired observers with identical public knowledge
and different hidden state: their available policies and player-visible audit
payloads must remain byte/behavior equal until the accepted reveal boundary.
The final internal research archive may contain privileged diagnostics only in
a clearly separated, access-labelled payload that is never fed back into the
policy.

## 5. Functional qualification and quiesced-checkpoint evidence

This row qualifies its own exact head with functional checks only. It does not
own performance qualification. It must not schedule, run, rerun, extend, or
hold a verdict on a performance suite or checkpoint, even if an older prompt
or handoff lists that suite among broad gates.

Verify the following functional requirements on the exact final source:

- repeated native runs with the same manifest are byte-identical after removal
  only of explicitly documented timestamps/paths;
- Web and native produce equivalent accepted actions, RNG consumption,
  terminal states, ledgers, distributions, pusher shard results, and rejection
  behavior for a representative frozen sample;
- save/load at meaningful boundaries resumes to the same terminal result and
  RNG consumption as uninterrupted execution;
- the accepted 0.5-to-0.6 migration fixtures and current schema load without
  inventing balances, opportunities, machine stock, crew/world state, or
  authority;
- maximal composition covers all accepted Families 1 and 2 systems together,
  including no-sequence and crew-ignoring paths, without double settlement,
  orphaned work, receipt reuse, or cross-system RNG drift.

Use the exact applicable commands discovered from the accepted input records,
including `tools/validate_project.ps1`, focused Foundation/system suites,
`tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`, relevant
save/migration/parity/composition functional gates, the cross-economy harness,
and the pusher EV harness. Do not invent a green functional command by omitting
a required suite or native/Web mode.

Performance evidence comes only from the next Integrator-owned quiesced
checkpoint for which this head is eligible under the binding cadence: the
five-landing checkpoint or the pre-playtest checkpoint, whichever occurs next.
The audit consumes and links that checkpoint's exact head/tree, native-plugin
hash, commands, durations, budgets, liveness result, and verdict. It may not
trigger the checkpoint, substitute row-local timing, or describe its own shard
durations as performance acceptance. If the eligible checkpoint has not yet
run, hand off the functionally qualified exact head and mark performance
evidence `PENDING INTEGRATOR CHECKPOINT`; do not idle, rerun it locally, or
withhold the head.

## 6. Cost-aware execution cadence

Do not spend the expensive run before cheap failures are excluded. Execute and
commit evidence in this order:

1. exact-tree/native-plugin preflight, import/load, schema, and harness smoke;
2. one seed per playstyle plus small pusher shards, then hostile probes;
3. deterministic repeat and native/Web representative sample;
4. eight seeds per playstyle and reduced pusher shards; inspect policy reach,
   opportunity denominators, censoring, conservation, runtime, and artifact
   growth;
5. freeze hashes, then run the 64-seed-per-playstyle full distribution in
   resumable deterministic shards;
6. run 200,000 accepted paid drops per pusher machine in deterministic shards;
7. rerun the required exact-final-source focused functional, composition,
   save/migration, determinism, parity, and broad non-performance gates; hand
   the exact head to the Integrator and link the next cadence-eligible quiesced
   performance checkpoint when it exists.

Each invocation record includes command, working directory, exact commit/tree,
input/output hashes, start/end timestamps, wall duration, exit code, stdout,
stderr, engine/plugin identity, and worker/shard identity. A retry remains in
the ledger with its cause; do not overwrite failed output. Aggregation must
reject missing, duplicated, differently hashed, or mixed-tree shards.

## 7. Findings and option-neutral proposals

Assign stable finding IDs. Rank findings by measured cross-system consequence,
effect size, uncertainty, reproducibility, affected routes/playstyles, and
tail risk. Examine dominant and dead strategies, debt trivialization or traps,
victory-route disparity, non-binding constraints, economy conservation,
pressure-versus-choice endings, and pusher/game EV interactions. State null and
inconclusive results as plainly as positive findings.

Classify each observation:

- **observable product defect:** behavior violates an accepted contract,
  invariant, authority, privacy, conservation, save, determinism, parity, or
  performance rule. Preserve a reproduction and propose a separate `fix06_*`
  row; do not repair or tune around it here;
- **measured balance/design question:** accepted behavior produces a measured
  distribution that may warrant owner consideration. Keep it as a finding and
  proposal for owner/playtest input and possible later `balance06_2` work;
- **harness/infrastructure issue:** affects measurement validity without
  changing product behavior. Repair inline only if blocking and document it.

Every proposal must cite finding IDs and current exact values/consumers, then
present at least two concrete options plus `NO CHANGE`. For each option state
the predicted distribution shift, routes helped/harmed, risks, unknowns,
required owner authority, and the exact before/after measurement that would
test it. Keep proposals option-neutral: do not select, recommend, silently rank,
or implement an option. If options cross rules, content, RNG, save, migration,
or system structure, label them owner design decisions rather than tuning.

The accepted playtest accounting consumes these findings as known context.
It must distinguish a reproduced defect from an owner design objection and
must not treat this report as felt-experience acceptance.

## Deliverables

Commit:

- `docs/plans/balance06_1_follow_on_cross_system_economy_audit.md`, containing
  provenance, method, distributions, limitations, ranked findings, and
  option-neutral proposals;
- `docs/plans/evidence/balance06_1_follow_on/README.md`, containing the exact
  reproduction and custody record;
- machine-readable input/value/policy manifests, coverage, raw-run/shard
  indexes, aggregate distributions, pusher EV results, gate matrix, command
  ledger, duration ledger, and SHA-256 manifest under that evidence directory;
- only necessary opt-in harness/test changes under `tools/` or the established
  test location, with their ownership and production non-effect proved.

Large raw artifacts that cannot reasonably be committed must remain preserved
at a named, non-destructive custody path with size and SHA-256 in the committed
manifest. The handoff must say exactly how the independent reviewer can access
them. Never claim that omitted evidence is committed.

## Immutable independent-review handoff

Finish only from a clean named branch. Commit logical units and provide the
Integrator with:

- exact full head and tree hashes, base/parent lineage, clean status, and full
  commit list;
- file ownership/diff summary proving no product values, RNG, rules, geometry,
  schemas, migrations, budgets, tolerances, or release artifacts changed;
- requirement-to-evidence matrix and complete SHA-256 manifest;
- commands, durations, exit codes, tool/plugin/platform identities, retry and
  failure ledger, raw-evidence custody, and known limitations;
- the frozen policy/value/input manifests and reviewer-sized deterministic,
  native/Web, save/load, hostile-authority, composition, and pusher samples.

The author does not review, gate, merge, edit the board, or hold a verdict.
Hand the exact accepted-ready head to the dedicated Integrator for independent
review, Gate Service verification, and landing. Review is immutable and
head-specific: any change after handoff invalidates the verdict and requires a
new exact-head review. The independent reviewer must reproduce representative
samples and verify aggregation hashes before accepting; historical or
different-tree green results do not count.

Do not declare `balance06_1-follow-on` DONE, claim findings are owner decisions,
or begin playtest, tuning, cleanup, voice, or release work. Only the Integrator
records acceptance and landing through the active board protocol.
