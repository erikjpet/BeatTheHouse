Status: TODO
Board row: `balance06_1` in `docs/todo/README_0_6_board.md`

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
