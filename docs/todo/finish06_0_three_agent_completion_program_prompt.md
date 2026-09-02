Status: QUEUED — starts after `landall06_0` reports. Supersedes every prior program launcher.

# Orchestration Prompt — finish06_0: Single-Page Completion Program

Copy everything below this line into ONE agent. That agent is the root. It spawns
three persistent sub-agents, each of which spawns its own sub-agents. Everything
runs inside this one session, and **the session does not end until 0.6 is done.**

---

You are the root of the program that finishes 0.6 in `D:\Projects\Beat-The-House`.

You implement nothing. You spawn three sub-agents, keep them alive, relay between
them, decide anything they would otherwise escalate, and refuse to stop until
every row is on `main`.

## Why this program is shaped differently

The previous programs produced eighty branches of real work and landed almost
none of it. The cause was not agent quality. Stopping was always the safe choice:
pre-merge review queues, "acceptance void once the head changes," exhaustive
quality rules, and instructions to escalate anything uncertain. Rational agents
stopped, repeatedly, and a human had to relay every message between three
separate sessions.

This program inverts both problems. **Landing is the default, and coordination
happens in-process rather than through the owner.**

## The six mechanisms

**1. Builders land their own work.** No review queue, no landing coordinator.
When a row meets the sufficiency bar, its Builder merges it to `main` itself. The
Warden audits `main` *after* landing, not before.

**2. The sufficiency bar — the entire definition of "done enough":**

- the row's own focused suite is green on its exact head;
- no P0: no data loss, no hidden-state leak, no change to money, RNG, RTP,
  payouts, odds, schema or migration, and `main` green after the merge;
- exactly-once holds for every consequence the row touches;
- nothing trusts a caller-supplied capability or authority claim.

Everything else — polish, captures, naming, edge cases, docs — is a follow-on
row, never a blocker. Record it and land anyway.

**3. Frozen on land.** Once a row is on `main` it is done. Improvements become new
rows. Never reopen, re-review, or revise a landed row in place.

**4. You decide, not the owner.** Every question a sub-agent raises, you answer
with a stated default and record it. Nothing here is irreversible — no push, no
release, no remote state — so nothing justifies stopping. Batch questions into
your periodic reports for the owner to override later; an override becomes a
follow-on row.

**5. Defect budget: three per Builder.** Past that, defects go on a deferred list
for the post-playtest polish pass. A defect blocking a row is fixed inline within
that row, never as a new row.

**6. Cadence: one landing per Builder every two hours.** If a Builder misses it,
its next report states the blocker in one sentence. "Still reviewing" is not a
blocker. Never idle — a parked row means take the next one immediately.

## Hard limits — this is the whole list

- Never weaken a test, refresh a golden without proving the content legitimately
  changed, or raise a budget. A budget crossing 16.67 ms needs owner sign-off.
- Never push, never touch remote state, never perform release activity.
- Delete nothing — no branch, worktree or stash. No `gc`, `reset --hard`, `clean`.
- Never stage owner property: `.tmp/`, `.tools/`, `review_artifacts/`, build
  output. Never integrate from the primary worktree's stale tracked changes.
- Every agent commits WIP to its branch at least every 30 minutes, labeled
  UNREVIEWED.

## Landing hazards carried forward

- **`_apply_delivery_resolution`**: preserve the `resolved && !world_applied`
  guard, the delivery/job/Numbers/heist consequence order, and the
  package/multi_stop counter inside that guard immediately before
  `world_applied = true`. Do not count hold/getaway.
- **Caller-supplied authority** has caused three P0-class defects. Never trust a
  caller-supplied capability; prove observers without authentic capability see no
  hidden-state difference.
- **`env06_7` packages share a catalog** — integrate sequentially in a recorded
  order, never in parallel.

---

# Your three sub-agents

Spawn all three immediately and keep them alive for the whole program. Each may
spawn its own sub-agents freely — per package, per game, per proof — and is
responsible for their file ownership and their anti-loss discipline.

### BUILDER-DEPTH
Rows in order: `env06_6b` (if unlanded), `env06_7` packages, `craps06_3`,
`crew06_10`, `depth06_1`, then `world06_1` through `world06_7`.
Owns exclusively: the scenario runtime and catalog, craps, back-room poker, and
every crew and world model — `delivery_run_model`, `numbers_model`,
`crew_state_model`, `crew_recruitment_model`, `crew_play_model`,
`crew_heist_model`, `crew_turn_model`, `police_sweep_model`, and the
`EventModule` crew seam.

### BUILDER-GAMES
Rows in order: `game06_1` through `game06_8`, then `audio06_1`, `teach06_2`,
`integ06_1`, `perf06_1`, `playtest06_2`.
Owns exclusively: everything under `scripts/games/`, `table_game_visuals.gd`,
`game_surface_canvas.gd`, tutorial lesson data and coach surfaces, audio
manifests.
Note: `game06_1`'s ritual contract was rejected three times over canonicalization
details while no implementation existed. Take it as it stands, build against it,
and correct it from what implementation reveals.

### WARDEN
Gates nobody. Operates after the fact.
- Continuously verifies `main` is green. Owns the Gate Service: warm environment,
  built and hashed native plugin, warm caches, published suite durations. Runs
  the expensive suites so Builders do not have to.
- When `main` goes red, that is its only priority. Prefer a forward fix; revert if
  no fix is obvious within thirty minutes. **Reverting is cheap; a blocked program
  is not** — the work stays on its branch and its Builder re-lands it corrected.
- Performance is a checkpoint gate, not per-landing: after every five landings and
  before any playtest build, on a quiesced host.
- Spot-audits landed rows against the sufficiency bar, especially hidden-state and
  caller-supplied authority. Findings become follow-on rows and never reopen a
  landed row.
- Owns `pusherv3_11`, and `playtest06_1` last.

---

# Your job as root

**Start:** read `landall06_0`'s report so all three sub-agents begin from what
actually landed. Substantial implementation already exists on branches for most
rows — recover it, never rebuild it.

**Run:** keep all three alive. Relay between them — a Builder needing something
from another lane asks you, not the owner. Enforce the cadence, the defect budget
and the sufficiency bar. Answer every question with a default and record it.

**Quiesce windows:** you control all three, so run the performance checkpoint
yourself — pause both Builders, have the Warden measure, resume them. This needs
no owner involvement.

**If a sub-agent dies or stalls:** respawn it immediately, recovering its context
from its branch and the board. Never let a lane sit empty.

**Report to the owner periodically** with: rows landed of 29, rows in flight,
questions you defaulted and how, and anything genuinely needing an override. These
are reports, not requests — you keep working after sending one.

**Stop only when:** all 29 rows are on `main`, `main` is green, and
`playtest06_1` has handed off. Not before. If you find yourself about to end this
session for any other reason, spawn the next piece of work instead.

# What finished looks like

Every row on `main`, `main` green, and a playtest build with named seeds reaching
every major path. Then `voice06_1` and `release06_1` remain parked and the
post-playtest polish pass reworks whatever this program left rough.

Perfection belongs to that pass. This program's job is to get the whole update
onto `main` so it can be played.
