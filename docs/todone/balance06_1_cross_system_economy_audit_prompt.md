Status: DONE (accepted partial audit prototype and evidence archive; full audit remains a separately ordered follow-on)
Board row: `balance06_1` in `docs/todo/README_0_6_board.md`

## Execution Record

- **Completed:** 2026-08-26
- **Source and landing:** Finalized provenance head `1c0dec3b1e091939cccc8295b9a218be2aa42b96`; independently accepted clean semantic head `7967a1e1fbe563dbf8008d0e64048c46f4dcecaf`; main merge `7c748f5bba4409491e35eddc97793d6ec90da711`.
- **Landing method:** The behind source branch was preserved as provenance and not merged wholesale. Its net payload landed as the two opt-in harness files plus 62 report, handoff and evidence paths. The three large supersedable raw `n=1` JSONs were omitted while their hashes, reproduction commands, immutable source commit and retained ignored originals remain recorded.
- **Independent review:** Final post-land review returned `ACCEPT 7c748f5bba4409491e35eddc97793d6ec90da711` with no findings. Review confirmed no product, economy, RNG, schema or migration change and no weakened/default-suite test path.
- **Post-land verification:** The exact ignored native addon was supplied and both Contract and full Smoke reported `native_v3`. Contract completed all 16 functional checks with zero failures/stderr but measured 259.847s against the unchanged 230.391s budget; this timing-only red is routed as `fix06_5`. Systems passed all 55 checks in 130.423s total. The eight-playstyle opt-in smoke passed at eight actions; the 208-action determinism outputs were byte-identical at SHA-256 `F5812EB31021889F939E2E2F8B43F4A601A6BD1036D230699196639C82F404E2`; full Smoke passed every stage in 231.036s summed stage time.
- **Scope boundary:** This DONE verdict is deliberately limited to the runnable opt-in prototype, honest partial report and complete small-evidence archive. The 64-seed-per-playstyle distributions, uncensored terminal-run evidence, historical numeric comparison, 600k-drop pusher EV run, ranked findings and proposals remain NOT STARTED and are retained as the ordered `balance06_1-follow-on` after Families 1 and 2.
- **Custody:** The initial interrupted Contract attempt and the precondition/interrupted Systems attempt are retained beside the corrected runs. Source, landing, verification and ignored evidence worktrees remain retained; no cleanup, remote, release, version or packaging action occurred, and primary owner WIP was untouched.

# Agent Prompt — 0.6 balance06_1: Cross-System Economy and Difficulty Audit

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a measurement and
reporting row. You produce evidence and proposals; you do not tune. Read
`data/economy/*`, `data/crew/jobs.json`, `data/crew/plays.json`,
`data/crew/numbers.json`, `data/crew/heist.json`, `data/items/items.json`,
`data/services/services.json`, `data/debt/*`, the coin pusher EV harnesses, and
every landed row's economy note in `docs/todo/README_0_6_board.md`.

## Why this row exists

Every 0.6 prompt audited its own economic slice and each was individually
restrained. Nobody has measured what happens when a single run has access to all
of them at once: crew jobs, package deliveries, lookout holds, collections,
stake jobs, the Numbers including a rig route, five coordinated plays, a heist
payout, three coin pusher machines, craps, and the eight other games. Each was
approved against a bankroll that did not include the others.

The owner playtest is next. If 0.6 inflates the economy, the playtest measures
inflation instead of design, and the owner's judgment about feel is spent on a
number that a tuning pass could have fixed first.

## Board and dependencies

Follow the active board protocol. Claim `balance06_1`. This row can start
immediately and does not depend on the depth programs — the depth programs
change presentation, not economic values, and every one of them is required to
prove its values unchanged. If you find a depth row that did move a value, that
is a finding and it is routed back to that row.

You own a report and a measurement harness. You do not own product data. Do not
tune anything. `release06_1` is the only row permitted to apply balance changes.

## 1. Build the model

- Enumerate every income source, every cost and every pressure in a run, with its
  landed value, its gating, its per-run cap and its rate limit. Sources include
  game EV, job rewards, Numbers payouts, heist payouts, play effects, item sales,
  services, scenario rewards, souvenir sales and debt mechanics.
- Enumerate every constraint that is supposed to hold the economy down: action
  budget, expiry windows, uses per run, cooldowns, rank gates, heat, detection,
  street debt, lender pressure and terminal conditions.
- Identify which constraints are shared and which are independent. Independent
  constraints multiply; that is where inflation comes from.

## 2. Measure real runs

- Build a seeded harness that plays complete runs to terminal under named
  playstyles, at minimum: pure gambler, crew maximizer, Numbers specialist,
  coin pusher grinder, cheater, heist rusher, and a mixed opportunist. Include a
  crew-ignoring run as the control.
- Run each across enough seeds to distinguish signal from variance, and report
  the distribution, not just the mean. Say how many seeds and why that number.
- Measure per playstyle: bankroll over time, time to each debt threshold, time to
  each victory route, action budget consumption, heat trajectory, failure causes,
  and how often a run ends because of pressure rather than because of a choice.
- Measure the control against 0.5 behavior where a comparison is meaningful, so
  the report can say what 0.6 changed rather than only what 0.6 is.

## 3. Report findings

- Rank findings by how much they distort the run: dominant strategies, dead
  strategies, sources that outpace their intended tier, constraints that never
  bind, and any path that reaches a victory route far faster than its peers.
- Call out anything that trivializes debt, since debt pressure is the spine of
  the run.
- Call out anything that makes a whole system pointless — a job kind nobody would
  take, a game nobody would play, a service nobody would buy — because that is a
  content loss as much as a balance one.
- For each finding, propose the smallest change that would address it, with the
  predicted effect and the risk. Proposals are ranked, not applied.

## 4. Discipline

- Do not change product values, tuning files or content data. If a genuine bug
  is found — money created from nothing, a conservation violation, a value that
  contradicts its own documented band — that is a defect finding routed as a
  `fix06_*` row, not something you patch inside this branch.
- Every number in the report must be reproducible from a stated command, seed
  and build. A claim without a reproduction is not a finding.
- Determinism: seeded harness, action boundaries, no wall-clock dependence.
- The harness must live where the other test harnesses live and must not slow
  the default suites. Long runs are opt-in.

## 5. Deliverable

A report under `docs/plans/` containing: the source and constraint model; the
harness description with exact commands; per-playstyle distributions with seed
counts; the ranked findings with evidence; the ranked proposals with predicted
effects and risks; and an explicit statement of what the report does not cover.

Also deliver the harness itself, committed and runnable, so `release06_1` can
re-measure after tuning and `playtest06_2` can cite it.

Run project validation and the relevant foundation suites to prove the harness
does not disturb the existing gates. Archive with the report path and the exact
commands recorded on the board.
