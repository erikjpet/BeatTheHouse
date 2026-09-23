# rw06_3 — Balance on the three ending routes

Status: TODO. Self-contained. Launch with this file only. Timebox: 1 day.
Depends on rw06_2's routes and `docs/plans/rw06_2_routes/economy_notes.md`
existing. Use the owner's run notes on the scoreboard if they are present.

## Goal

A competent, non-exploiting player can reach each ending within a reasonable run
length. Money pressure should feel real without walling the player off.

Targets:

- Each ending reachable in roughly 150–350 player actions on its route. This
  is a guideline: if evidence shows a different range plays better, propose it
  to the orchestrator with numbers.
- No ending needs a single lucky outcome, but a jackpot or legitimate fast
  route may shorten a run a lot. Keep those possible; don't tune them away.
- Bankruptcy is a real risk in reckless play.

## Owner questions (binding for every agent)

All owner decisions, including the hard gates, go through
`D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`. Always use that absolute path (the primary checkout copy). Follow
its protocol:

- append a short, precise question with options and a recommendation;
- mark your work `WAITING Q-NNN`;
- keep working on anything that doesn't depend on the answer.

Read the file at the start of every session. Pick up any ANSWERED entry whose
`Resume` is yours, even if another agent asked it. Never talk to the owner any
other way, and never stall waiting.

## Scope (data only)

- Tune prices, rewards, service and lender terms, event weights, route costs,
  gate thresholds (Players Card ladder steps, Crew trust steps) and heist payout
  bands. Tune these in the data under `data/`.
- **Do not change** game rules, RTP, EV or payout tables of the 11 games. The
  owner-ruled Coin Pusher bands stay: `[0.72, 0.94]` for Quarter Falls and
  Vault Drop tray EV, `[0.70, 1.08]` for Jackpot Ridge.
- If a code change is needed, write it up in `docs/plans/0.6.1_backlog.md`, or
  on the scoreboard if it blocks an ending.

## Method

1. Measure first with `tools/cross_economy_audit.ps1`, the diagnostic mode (full
   binding runs are 0.6.1 work), and with the three rw06_2 routes replayed
   with `tools/rw06_2_ending_replay.ps1`.
2. Change one thing at a time. Record each change as
   `old → new, reason, measured effect` in
   `docs/plans/rw06_3_balance_changes.md`.
3. Replay all three routes after the final tuning. All must still reach the win
   state. If tuning changed a route's decisions, update that route file.

## Rules

- Never weaken a test, budget or deterministic assertion. Update golden fixtures
  only when the change is an intended data change, and explain it in the commit.
- Everything stays seeded and deterministic.

## Acceptance

- The three routes are green after tuning.
- Smoke and Contract are green.
- The change log is committed.
- Results reported to the orchestrator for the scoreboard.

## Finish

- Commit in a worktree branch, verify, fast-forward `main`, and push. Never force-push. Then delete the branch (local and origin) and remove the
  worktree. The row is not DONE while its branch exists.
