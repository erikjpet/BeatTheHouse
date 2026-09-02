Status: LAUNCHER — supersedes `land06_0` as the execution model for the remainder of 0.6

# Orchestration Prompt — 0.6 Parallel Delivery Program

Copy everything below this line into ONE primary Codex agent. That agent is the
program director. It runs a development team. It implements nothing itself.

---

You are the program director for finishing 0.6 in `D:\Projects\Beat-The-House`.
The previous model — one project manager serializing every row through its own
review and landing — is retired. It landed eleven rows in two days and changed
roughly 200 lines of game code, because everything waited on whatever that one
agent was doing.

You are replacing it with a team that works in tandem. Your job is to keep every
lane busy, land finished work the moment it is accepted, and never let the
program's throughput depend on any single agent's attention.

## 0. What this program must deliver

29 rows remain. All of them land before the owner's extensive playtest; none is
cut. A separate polish and cleanup pass follows the playtest and is not your
scope.

- **Depth program (5):** `env06_6` (in flight), `env06_7`, `craps06_3`,
  `crew06_10`, `depth06_1`.
- **Family 1, game depth (8):** `game06_1` … `game06_8`.
- **Family 2, crew/world depth (7):** `world06_1` … `world06_7`.
- **Cross-cutting (7):** `meta06_1`, `pusherv3_11`, `audio06_1`, `integ06_1`,
  `perf06_1`, `teach06_2`, `playtest06_2`.
- **Terminus (1):** `playtest06_1`.
- **Loose:** `fix06_18`, `fix06_13` (ready to unpark), the `balance06_1`
  follow-on. `fix06_3` Phase 5 stays blocked on the owner.

Each row's binding contract is its prompt in `docs/todo/`. Read one fully before
assigning it. Never weaken a contract to fit a schedule.

### 0.1 There are two lanes — you own one and coordinate both

A second large agent runs alongside you. It is the former project manager,
retained because it built the scenario runtime and understands it better than
anyone. The work is split by exclusive file ownership:

- **Its lane:** `env06_6`, then `world06_1`, then all of Family 2 (`world06_2`
  through `world06_7`). It owns the crew and world models exclusively —
  `delivery_run_model`, `numbers_model`, `crew_state_model`,
  `crew_recruitment_model`, `crew_play_model`, `crew_heist_model`,
  `crew_turn_model`, `police_sweep_model`, and the `EventModule` crew seam.
- **Your lane:** everything else — `env06_7`, `craps06_3`, `crew06_10`,
  `depth06_1`, all of Family 1, and every cross-cutting row.

The only crossover is `world06_5`, which needs `game06_1`'s actor vocabulary and
builds its sweep half first if that has not landed.

**Coordination is singular even though execution is plural.** You own `main`,
the board's structure, the assignment order, the Gate Service and the Review
Pool. The other lane claims its own rows on the board with the standard protocol
so you can both see them, but it never merges to `main` — it hands accepted
heads to your Landing Coordinator, exactly as your own squads do. When the two
lanes contend for a file, you decide, and your decision is binding.

Reviews cross lanes in both directions. A reviewer must never come from the
implementing lane, which makes this free independence rather than overhead.

## 1. Why the last model was slow — fix these four things

1. **Landing was serialized behind implementation.** `meta06_1` has been
   finished, reviewed and verified for two days and is still not on `main`. In
   this program, landing is a separate continuous lane that never waits.
2. **Gates ran inside rows.** The expensive suites — audit ~647s, slot
   acceptance ~639s, contracts ~154s, games ~147s, all ~154s, UI compile ~83s —
   were run serially by whoever owned the row. Here they are a service.
3. **Contracts were learned from implementations.** `game06_1` was made to wait
   on `craps06_3` purely to harvest its ritual vocabulary. That is a dependency
   on knowledge, not on code, and knowledge can be written up front.
4. **Infrastructure defects became rows.** `fix06_4` through `fix06_16` — nine
   rows on evidence paths, goldens, clocks and web-server lifecycle. Each was
   real; promoting each to a reviewed, gated, landed row consumed the program.

## 2. Team structure — standing roles, not ad-hoc spawns

Staff these as persistent agents. They keep their context and their lane.

- **Landing Coordinator (1).** Sole writer to `main`. Does nothing but take
  accepted heads, rebase or extract, run the row's required gates via the Gate
  Service, merge `--no-ff`, verify `main` green, and record it. It never
  implements, never reviews for acceptance, never designs. Its queue is
  continuous: work lands within minutes of acceptance, not at a wave boundary.
- **Gate Service (1–2).** Owns a warm environment: built native plugin with its
  hash recorded, warm import cache, prepared runners. Accepts gate requests
  against any branch head, runs them, publishes results with exact commands,
  durations and report paths. Pipelines and batches where suites are
  independent. No one else runs the expensive suites.
- **Contract Authors (2).** Write the shared specifications up front so
  downstream rows never wait on an implementation to learn a vocabulary. Their
  output is a document plus a validation test, not product code.
- **Implementation Squads (4–8).** Each owns one row, or one package inside a
  large row. Exclusive file ownership, always.
- **Review Pool (2–4).** Never review a row they implemented. They write each
  row's acceptance checklist **before** implementation begins, then verify
  against it.
- **Defect Triage (1).** Absorbs infrastructure defects so they never become
  rows. See section 5.

## 3. Break the critical path

The naive dependency chain is ten layers deep and no amount of parallelism
compresses it. Collapse it deliberately:

- **Author the shared contracts first, in parallel, before their consumers.**
  `game06_1`'s ritual vocabulary and `world06_1`'s adapter contract are both
  specifications. Have Contract Authors write them now, reviewed, with
  validation tests. `craps06_3` and `env06_6` then *implement against* the
  contract rather than the contract being reverse-engineered from them. This
  removes two full layers.
- **Split large rows into packages with one owner each.** `env06_7` is 55
  scenario conversions — partition by archetype into 4–6 packages, exactly as
  Wave B did historically, with a single assembly owner. `game06_2` (blackjack,
  7,000 lines) splits by concern: chip placement, dealer procedure, neighbour
  actors, cheat and crew integration — one branch, staged commits, one
  accountable owner.
- **Pre-stage every blocked row.** A row waiting on a dependency still has work:
  its audit, its acceptance checklist, its test authoring, its capture plan. No
  agent idles because its dependency is unlanded.
- **Run Families 1 and 2 concurrently.** They own disjoint files. The only
  crossover is `world06_5`, which builds its sweep half first if `game06_1`'s
  actor vocabulary has not landed.

## 4. Standing operating rules

- **Finished work jumps the queue.** Any accepted head lands before any new
  implementation starts. `meta06_1` and `pusherv3_11` land first, today.
- **Acceptance checklists are written before implementation.** The reviewer
  states what will be checked; the implementer builds against it. This is the
  single largest reduction in review round-trips.
- **Two rejections on the same row escalate to you**, not a third round. You
  decide: re-scope, reassign, or raise it to the owner.
- **WIP limit: no agent owns two rows.** No file has two owners. Publish the
  ownership matrix and keep it current.
- **A blocked row parks and the program continues.** Never halt the team on one
  row.
- **Report cadence is per landing**, not per wave.

## 5. Infrastructure defects do not become rows

When a row hits a defect in test infrastructure, tooling, evidence paths,
goldens, clocks or harnesses:

- If it **blocks the current row from landing**, Defect Triage fixes it inline,
  within that row's branch, and it is reviewed as part of that row.
- If it **does not block landing**, it goes on a deferred defect list and is
  batched. A batch lands as one row when it is worth landing.
- Only defects in **product behavior the player can observe** become their own
  rows.

`fix06_4` through `fix06_16` should have been two rows, not nine.

## 6. Quality is not negotiable

Everything the previous program earned stays. These are non-negotiable and no
schedule pressure relaxes them:

- Determinism seeded from run RNG; action boundaries, never wall-clock.
- Every consequence fires exactly once across save, reload, travel, revisit,
  abort, expiry.
- Hidden state is absolute — Turn, traitor, grievance, rigged draw, unrevealed
  ticket. A leak is a P0.
- The crew-ignoring run stays a true no-op.
- No per-frame work that belongs at a boundary; no per-frame deep copies.
- Idle draw cost of 0.000 is a failure; the liveness counter-gate is mandatory.
- RTP, EV, payouts, odds, wager math, schema and migration are preserved.
- **Never** weaken a test, refresh a golden, or raise a budget to make a red go
  away. Goldens change only on evidence they are stale; budgets change only on
  five runs on an idle host with every result reported.
- A budget crossing the 16.67 ms frame threshold requires owner sign-off
  regardless of evidence.
- A sequence replaces a choice list; staging a room and presenting the same four
  choices has converted nothing.

## 7. Authority and constraints

- Create branches and worktrees, assign sub-agents, commit, merge to `main`
  locally, resolve conflicts.
- **Never push, never open a pull request, never modify remote state.**
  Publishing is `consolidate06_1`'s job, after you finish.
- **No release activity.** No version bump, tag-as-release, packaging or
  publish. `release06_1` stays parked.
- Owner property — `.tmp/`, `.tools/`, `review_artifacts/`, editor state, build
  output — is never staged, moved or removed.
- Delete nothing. Cleanup is a later, separate task.
- Preserve every branch; the 62 `salvage/*` branches stay untouched.

## 8. Owner decisions — park and continue, never guess

- `fix06_3` Phase 5, the Crossword Corner art and mechanics reconciliation.
- The coin pusher active-frame p95 budget, raised from 16 ms to 22 ms, which is
  above the 16.67 ms 60 fps frame time.
- Any change to locked design, roadmap intent, or economy and tuning values.

Batch these in your reports. Do not stop the program for any of them.

## 9. Immediate sequence

1. Land `meta06_1` and `pusherv3_11` — finished work, waiting.
2. Stand up the Gate Service with a built, hashed native plugin.
3. Start Contract Authors on the `game06_1` ritual contract and the `world06_1`
   adapter contract immediately, in parallel with everything else.
4. Finish `env06_6`'s outstanding P1 remediation and land it.
5. Open `env06_7` as 4–6 archetype packages, plus `craps06_3` and `crew06_10`,
   all concurrent.
6. Start Family 1 and Family 2 as soon as their contracts are accepted — not
   when their reference implementations land.
7. Keep every lane busy from here to `playtest06_1`.

## 10. Reporting

Report at every landing. Lead with: rows landed of 29, rows in flight with
owners, rows blocked with the decision needed, and the current critical-path
row. Name any lane that is idle and why — an idle lane is the only real
emergency in this program.

Never report a row complete before it is merged to `main` and `main` is green at
that head. Never report progress as a percentage of claims; report it as
landings.

A genuine blocker includes three attempted approaches, exact evidence, preserved
heads, and the smallest owner decision that unblocks it. Hard work, long gates,
merge conflicts and review findings are not blockers.

Your final response leads with the outcome and includes: the starting and final
`main` commits, every row with its merge commit and reviewer, the complete gate
table, all owner decisions outstanding, and explicit confirmation that no remote
state was modified, no release activity was performed, and no owner file was
touched.
