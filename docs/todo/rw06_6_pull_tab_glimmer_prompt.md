# rw06_6 — pull-tab yellow glimmer

You own the narrow Q-014 pull-tab presentation feature for Beat the House 0.6.0.
Work only on a dedicated `codex/rw06_6-pull-tab-glimmer` branch and
`D:\Projects\Beat-The-House-worktrees\rw06_6-pull-tab-glimmer` worktree based
on current `origin/main`. Do not edit rw06_1 placement or rw06_2/rw06_3 ending
work. If a shared file overlaps another active branch, stop that edit, report
the overlap to the release orchestrator, and continue non-conflicting work.

Owner communication is only through
`D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`. Read its
protocol at the start and before every owner decision. Q-014 is already
ANSWERED. Ask any new question there with options, mark this row WAITING on the
scoreboard through the orchestrator, and keep working on unblocked tasks. Never
stall. Only the release orchestrator edits the scoreboard.

## Product contract

- While the pull-tab machine/screen is active, schedule a yellow light glimmer
  at a newly sampled interval from 25 through 35 seconds.
- Select only from the best 16 eligible high-tier winning tickets that are
  currently remaining and unrevealed in that exact machine. Never select a
  revealed, removed, consumed, stale, or other-machine ticket.
- The glimmer indicates only the ticket's visible location. It must not reveal
  or serialize its hidden prize, value, tier, contents, odds, or ranking.
- Do not change ticket generation, ticket contents, win odds, payout tables,
  purchase/reveal/consume behavior, machine inventory, or any economy value.
- Closing the pull-tab surface clears the transient hint and stops its timer.
  Reopening starts a fresh 25–35 second interval from the then-current eligible
  inventory. Save/Continue stores no glimmer target, hidden value, ranking, or
  countdown; a restored and newly opened surface also starts a fresh interval.
- Normal motion may use a brief yellow glimmer animation. Reduced-motion mode
  must show an equivalent non-animated yellow highlight, with no pulsing,
  flashing, or repeated movement.
- If fewer than 16 eligible winning tickets remain, select from all eligible
  ones. If none remain, show no glimmer and keep the presentation stable.

## Required regression evidence

Add a focused production-path regression that proves, under controlled time and
RNG:

1. no hint is visible before 25 seconds;
2. an eligible hint appears no later than 35 seconds;
3. the target belongs to the current top-16 eligible remaining/unrevealed
   winner set, including fewer-than-16 and empty-set cases;
4. revealed, removed, consumed, stale, and other-machine tickets are rejected;
5. ticket data, odds, payout tables, inventory, and economy are byte-for-byte
   unchanged by scheduling and display;
6. close/reopen and Save/Continue follow the transient-state rules above;
7. reduced motion produces a static yellow highlight; and
8. public/save serialization contains no hidden target prize/value/tier/rank.

Capture a meaningful fail-before run against the pre-fix product and a
pass-after run on the exact pushed implementation commit. Record commands,
commit IDs, exit codes, pass/fail markers, elapsed time, evidence paths, and
SHA-256 hashes. A fixture failure, timeout, skipped engine, or manually injected
target is not valid red/green evidence. Never weaken an assertion or gate.

## Validation and custody

- Canonical Godot 4.6 console:
  `D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe`.
- Follow Q-009 isolation: own worktree, APPDATA/LOCALAPPDATA/XDG folders, log,
  and live PID lease in
  `D:\Projects\Beat-The-House-worktrees\.godot_leases\`. Focused runs may share
  the four-process ceiling; every full Smoke/Contract/Full or timing run is
  EXCLUSIVE.
- Run the relevant engine-free source/static checks and the full project
  validator before focused Godot evidence. The release orchestrator decides
  whether a broader full suite can be shared with the final candidate.
- Commit and push normally; never force-push. Report the exact pushed tip and
  evidence to the orchestrator. The orchestrator reviews and merges to `main`.
  After merged-main validation, delete the branch/worktree before this row is
  DONE.
- Put genuinely out-of-scope work in `docs/plans/0.6.1_backlog.md`.
- Do not package, upload, publish, use butler, tag, or post anything.
