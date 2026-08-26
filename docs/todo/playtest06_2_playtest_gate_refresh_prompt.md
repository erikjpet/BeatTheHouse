Status: TODO
Board row: `playtest06_2` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 playtest06_2: Playtest Gate Refresh

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This row repairs the handoff
that ends the entire 0.6 board. Read
`docs/todo/playtest06_1_playtest_readiness_prompt.md` in full, the board's
terminus section, `docs/plans/0.6_remaining_work_program.md`, and the reports
from `balance06_1`, `integ06_1`, `perf06_1` and `pusherv3_11`.

## Why this row exists

`playtest06_1` was written on 2026-08-13, before the owner's depth rework, before
`pusherv3_5` through `pusherv3_10`, and before all three programs in the
remaining-work document. Its dependency is literally "ALL other rows DONE", which
no longer identifies a specific set. Its scope describes verifying a version of
0.6 that does not exist.

It also lacks the things a playtest handoff most needs: a seed list, a route
through the content, and a format for capturing what the owner finds. The board
says the owner's findings become `fix06_*` rows and owner decisions — but nothing
defines how a note becomes a row without an agent guessing at intent.

## Board and dependencies

Follow the active board protocol. Claim `playtest06_2`. This row runs after
`integ06_1` and `perf06_1`, because it must know what they found. It amends
`playtest06_1` rather than replacing it: `playtest06_1` remains the row that
performs the readiness work, and this row rewrites what that work is.

**No release activity.** No version bump, no tag, no packaging, no publish, no
final balance tuning. That is `release06_1`'s alone and it stays parked.

## 1. Re-scope playtest06_1

- Replace its dependency with the explicit list of rows that must be DONE,
  naming them, including the depth program, both new families, the pusher V3
  audit and the cross-cutting rows that gate on them.
- Rewrite its verification matrix to cover what 0.6 now contains, absorbing the
  gates the three release-gate rows already ran rather than duplicating them.
  Where a gate has already passed on the exact tree, cite it; where it has not,
  require it.
- Keep its existing hard rules intact: playability sweep with no dead
  interactions and no soft-locks, every major path reachable with named seeds,
  the perf guard with the idle-liveness counter-gate, an honest state-of-the-
  update report, and a local owner build.

## 2. Name the seeds

- Produce a named seed list that collectively reaches: every archetype, a
  representative spread of the 55 scenarios including their branches, all
  eleven games, all three coin pusher machines, the full crew path from
  recruitment to both heist plans, a Turn that fires and one that does not, all
  three Cass endings, both victory routes plus the crew route, and a
  crew-ignoring run.
- For each seed say what it is for and what the player should expect to be able
  to reach. A seed with no stated purpose is not a test.
- Verify each seed actually delivers what it claims on the current build. A seed
  list that has drifted is worse than none.

## 3. Write the playtest script

- A route through the game the owner can follow, in sessions, that reaches the
  content worth judging without requiring them to grind for it.
- Say explicitly what is finished, what is known-rough, and what is deliberately
  absent — production music above all, since its absence will otherwise dominate
  every impression.
- Include the known findings from `balance06_1`, `integ06_1`, `perf06_1` and
  `pusherv3_11` as context, so the owner is not rediscovering things the agents
  already know.
- Keep it short enough to be used. A checklist nobody follows teaches nothing.

## 4. Define the capture format

- A structure for the owner's findings that an agent can turn into a `fix06_*`
  row without inventing intent: what happened, where, what was expected, how
  badly it matters, and whether it is a defect or a design objection.
- Define the split explicitly: defects become `fix06_*` rows; design objections
  become owner decisions recorded in the roadmap. An agent may never redirect
  locked design on its own reading of a playtest note — that rule already exists
  on the board and this format must enforce it structurally.
- Provide the triage protocol that `polish06_0` will consume: severity, routing,
  and what makes a finding blocking versus deferred.

## 5. Acceptance

- `playtest06_1`'s prompt updated in place with the new dependency list, scope
  and matrix, and the board row's Depends On updated to match.
- The seed list verified on the current build, with evidence per seed.
- The playtest script and capture format delivered under `docs/plans/`.
- An explicit statement of what the playtest is not for, so the owner is not
  asked to do QA that a gate should have caught.
- No release activity performed and none scheduled by this row.

Run project validation to confirm nothing outside documentation changed. Archive
with the seed verification evidence and the document paths recorded on the board.
