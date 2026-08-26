Status: LAUNCHER
Board section: `Family 1 — Game depth parity` in `docs/todo/README_0_6_board.md`

# Orchestration Prompt — Game Depth Parity Program (Family 1)

Copy everything below this line into one primary Codex agent. That agent is the
program integrator and must employ sub-agents; it is not permitted to implement
the whole program alone.

---

You are the primary integrator for the game depth parity program in
`D:\Projects\Beat-The-House`. Your job is to use as many sub-agents as the
current runtime safely permits, complete every task below, independently review
each implementation branch, preserve logical individual commits, merge accepted
work through an integration branch, run an exact-tree release audit, and merge
the finished program back into the branch from which you started.

Required task contracts, in dependency order:

1. `docs/todo/game06_1_table_machine_ritual_runtime_prompt.md`
2. `docs/todo/game06_2_blackjack_depth_prompt.md`
3. `docs/todo/game06_3_baccarat_roulette_depth_prompt.md`
4. `docs/todo/game06_4_machine_games_depth_prompt.md`
5. `docs/todo/game06_5_counter_games_depth_prompt.md`
6. `docs/todo/game06_6_bar_dice_depth_prompt.md`
7. `docs/todo/game06_7_showdown_duel_depth_prompt.md`
8. `docs/todo/game06_8_games_depth_release_gate_prompt.md`

The active board is `docs/todo/README_0_6_board.md`. The eight task prompts are
binding acceptance contracts. Read them completely before planning, then read
all repository `AGENTS.md` files that govern touched paths. Do not weaken or
reinterpret a task to make it fit the available time or agent count. Continue
until the full program is finished, or report a genuine blocker with exact
evidence.

## Why this program exists

The owner's 2026-08-25 depth standard says a game must not resolve as a static
control panel. The depth program applies that standard to craps
(`craps06_3`), back-room poker (`crew06_10`) and the coin pusher (V3 rows).
`data/games/games.json` ships eleven games. The other eight — blackjack,
baccarat, roulette, video poker, slot, scratch tickets, pull tabs, bar dice —
plus the Grand Casino showdown surfaces, still resolve as panels. `depth06_1`
would pass while most of the game fails its own stated bar. This program closes
that gap.

## Authority and non-negotiable outcome

- You are explicitly authorized to create local branches and isolated Git
  worktrees, assign implementation and review work to sub-agents, commit the
  requested changes, merge accepted branches, resolve in-scope conflicts, and
  merge the fully accepted integration branch back into the starting branch.
- Do not push, open a pull request, publish a build, delete user work, or modify
  remote state unless the user separately requests it.
- Existing dirty/untracked files belong to the user. Record them at preflight,
  never copy them into worktrees, never stage them, and never use reset/clean/
  checkout commands that could discard them.
- Every game id in `data/games/games.json` must finish as a played sequence.
  Partial conversion is not a valid stopping point. A game whose only change is
  new art, new text, or a new sound has not been converted.
- No RTP, EV, payout table, cheat contract, or money-conservation guarantee may
  move. This is a presentation-and-interaction program with rules preserved.

## 1. Hard dependency on the depth program

`game06_1` depends on `craps06_3` being landed and reviewed. Craps is the first
game to receive a tactile throw/settlement ritual, and this program must
generalize that landed seam rather than invent a rival vocabulary. Do not start
`game06_1` implementation until `craps06_3` is DONE on the board and you have
read its accepted head.

While waiting, keep every slot busy with the read-only audits in section 3.

## 2. Preflight and immutable baseline

1. Capture and report: absolute repository path; starting branch and exact HEAD;
   upstream/ahead/behind; tracked modifications and untracked paths; existing
   worktrees and branches matching `codex/game-*`; available agent concurrency;
   supported validation/test commands and their practical runtimes.
2. If tracked user changes overlap any required file, do not hide or overwrite
   them. Create worktrees from the exact starting HEAD and leave the original
   working tree untouched until final integration; stop only if the overlap
   makes an honest final merge impossible.
3. Create `codex/game-depth-integration` from the exact starting HEAD in an
   isolated worktree. Record its path. All accepted work merges here first.
4. If the eight task contracts and this launcher are not present in the starting
   commit, copy only their exact current contents into the integration worktree
   and commit them first as `game06_0: add game depth program contracts`.
5. The primary integrator is the only agent allowed to edit the active board,
   archive task prompts, merge branches, or resolve cross-branch conflicts.
6. Establish a live program ledger containing branch, worktree, owner, file
   ownership, base commit, dependencies, status, reviewer, findings, test
   evidence, accepted head, merge commit, and cleanup status.

## 3. Spawn the initial parallel audit team

Give each agent a bounded, read-only audit with a required written handoff:

- **Shared surface seam:** `scripts/core/game_module.gd`,
  `scripts/games/table_game_visuals.gd`, `scripts/ui/game_surface_canvas.gd` —
  every extension point, every current consumer, and the exact places a ritual
  contract can attach without changing games that have not opted in.
- **Craps ritual harvest:** what `craps06_3` actually landed for phases, pointer
  verbs, actor states and energy projection, and which parts are general.
- **Per-game inventory:** for all eight games plus the duel — `surface_state`,
  `draw_surface`, `surface_action_command`, `surface_pointer_command` shape,
  action vocabulary, cheat hooks, tutorial lesson references, crew play hooks,
  heist honesty fields, RTP/EV harnesses and their exact commands.
- **Consumer map for blackjack specifically:** Players Card, tutorial lessons,
  `crew_play_model` spotter/big player, heist honesty and detection fields, and
  every test that asserts on its settled fields.

Note for the auditors: today only `scratch_tickets.gd` and `coin_pusher.gd`
implement `surface_pointer_command`. Tactile pointer interaction exists in two
of eleven games. That is the size of the gap.

Audit agents cite paths and symbols, identify shared files, propose commit
boundaries, and map every prompt requirement to implementation and tests. They
do not edit code. Use their handoffs to produce the execution plan and the
file-ownership matrix.

## 4. Branch and worktree topology

Use isolated worktrees for every concurrent implementation. Never let two agents
change branches in the same worktree. Branch families:

- `codex/game-ritual-runtime` for `game06_1`;
- `codex/game-blackjack` for `game06_2`;
- `codex/game-tables` for `game06_3`;
- `codex/game-machines` for `game06_4`;
- `codex/game-counter` for `game06_5`;
- `codex/game-bardice` for `game06_6`;
- `codex/game-showdown` for `game06_7`;
- `codex/game-release-remediation` only for exact-tree findings that cannot
  cleanly return to their owning branch.

Create worktrees under a verified sibling directory such as
`D:\Projects\Beat-The-House-worktrees\`. Resolve every path before creation or
cleanup. Never recursively delete a computed path; use `git worktree remove`
after verifying the registered path and only after its branch is safely merged.

## 5. Dependency-aware execution waves

### Wave 1 — the ritual runtime

Claim `game06_1`. Assign it to one runtime worker. Its branch must include at
least these logical commits: (1) the ritual/phase/actor contract and its
validation; (2) shared visual-layer actor and object support; (3) pointer verb
and hit-region support with accessibility equivalents; (4) opt-in wiring plus
focused tests; (5) one proof game re-expressed on the contract, with evidence.

The proof must be the landed craps ritual re-expressed through the contract with
no craps special-casing. If the contract cannot express what craps already does,
the contract is wrong.

Do not merge Wave 1 on implementer confidence. Apply the review protocol in
sections 7 and 8. Once accepted, merge with `--no-ff` into the integration
branch, run smoke and regression gates there, update the board, and record the
integration commit. Only that accepted commit may base consumer branches.

### Wave 2 — parallel game conversion

From the accepted runtime commit, start `game06_2` through `game06_7`
concurrently, one owner per branch, keeping all slots occupied and swapping a
completed implementer for a reviewer immediately.

Ownership is by file and is exclusive. `game06_2` owns `blackjack.gd`;
`game06_3` owns `baccarat.gd` and `roulette.gd`; `game06_4` owns `slot.gd`,
`scripts/games/slots/*`, `video_poker.gd` and `video_poker_renderer.gd`;
`game06_5` owns `scratch_tickets.gd`, `pull_tabs.gd` and the ticket renderers;
`game06_6` owns `bar_dice.gd`; `game06_7` owns the Grand Casino duel and
showdown models and surfaces.

`game06_7` also consumes blackjack settlement. Base it on the accepted
`game06_2` head rather than the bare runtime commit, and say so in the ledger.

If a worker needs a change to a `game06_1` file, it does not edit it. It files a
runtime request with exact evidence; you decide whether to reopen `game06_1` on
its own branch or grant a narrow, reviewed exception recorded in the ledger.

### Wave 3 — integrate games one at a time

Each game branch requires independent review and all focused gates before it is
eligible. Merge accepted branches one at a time with `--no-ff`, preserving
logical commits. After each merge run its focused tests plus cross-game surface,
save and UI smoke on the integration branch. If a later merge breaks an earlier
one, assign the finding to the responsible branch or an explicit cross-system
remediation commit; never mask it in the merge resolution.

### Wave 4 — independent release gate

Claim `game06_8`. Spawn at least two reviewers who owned none of the relevant
implementation: one for correctness, state, determinism, RTP/EV and economy; one
for player-facing visuals, interaction, accessibility, pacing and the unlabeled
per-game identity contact sheets. Run the entire `game06_8` prompt on the exact
integration head. Reviewers must sample the build themselves, not read reports.
Any P0/P1 or unmet prompt checkbox blocks closure.

## 6. Standing rules for every worker

- Preserve rules and math exactly. If a depth change appears to require a math
  change, stop and file it; do not adjust an RTP band to make a ritual work.
- Presentation may never reroll, reorder or alter an authoritative outcome, and
  may never read wall-clock time for a result.
- Every pointer verb needs a keyboard, controller and reduced-motion equivalent
  that produces identical outcomes and fair timing.
- Every energy or heat tier must change at least one actor, object or
  interactable state. Music and text alone fail.
- Idle life comes from actors and machinery. The liveness counter-gate in
  `scripts/ui/performance_liveness_guard.gd` is mandatory: an idle draw number of
  0.000 is a failure, not a pass. This regression pattern has recurred four
  times in this project's history.
- Nothing new runs per frame that can run at an action boundary. Per-frame deep
  copies of state are forbidden — the slot bonus watchdog is the recorded
  precedent.
- Save, exit and revisit mid-ritual must never lose, double-settle or silently
  resolve a wager, and rehydration must not replay rewards, dialogue, audio or
  one-shot effects.

## 7. Mandatory branch self-review protocol

Before requesting review, every implementer stops editing and produces a branch
handoff containing: exact base and head commits plus `git status` proving only
intended files; the commit list with one-sentence purposes; a prompt checklist
mapping every owned requirement to file, symbol, test and capture;
`git diff --check` and a diff-stat ownership audit; a full base-to-head diff
review for debug code, TODO stubs, dead paths, generated files, hardcoded test
shortcuts, non-deterministic time or randomness, duplicated consequences and
save hazards; focused tests, regression suites, determinism, parity,
performance, visual and accessibility evidence with exact commands and results;
and known risks or assumptions, where "None" must be explicit.

A branch is not reviewable with dirty tracked changes, uncommitted required
work, missing evidence, skipped prompt rows or unrelated files.

## 8. Mandatory independent review protocol

Assign a reviewer who did not author the branch. The reviewer starts from the
recorded base, reads the binding prompt sections, and independently checks the
full diff and commit boundaries; correctness, error paths, state ownership,
migrations, idempotency, cleanup, deterministic RNG and action boundaries,
Web/native behavior, performance and accessibility; tests for false positives,
missing negative cases, overfitted fixtures and weakened assertions; actual
player-facing behavior and captures rather than state flags; and interactions
with already accepted work.

Findings are `P0` (data loss/security/unshippable), `P1` (incorrect or missing
required behavior), `P2` (material quality gap) or `P3` (non-blocking polish).
P0/P1/P2 require a fix or a written owner-approved exception; the integrator
cannot waive them. The reviewer issues exactly one of `ACCEPT <exact-head>` with
coverage and rerun evidence, or `REJECT <exact-head>` with actionable findings.
Acceptance is invalid after the head changes.

## 9. Commit and merge discipline

- Preserve individual logical commits. Do not squash a task into one commit.
- Commit messages use the task id and outcome, for example
  `game06_2: stage dealer procedure and chip placement beats`.
- Before every merge verify a clean integration worktree, the expected branch
  head, recorded reviewer acceptance, diff/check results and no unrelated files.
- Merge with non-interactive `git merge --no-ff`. Resolve conflicts only in the
  integration worktree, inspect every conflicted hunk, rerun both sides' focused
  tests, and never use blanket "ours" or "theirs" for product or data files.
- After each merge record accepted head, merge commit, tests and cumulative game
  count in the ledger. A failed post-merge gate reopens the responsible task.
- Do not stage `.tmp`, review artifacts, captures outside their documented
  evidence location, editor state, or pre-existing user files.

## 10. Final merge back to the starting branch

Only after `game06_8` passes and all eight rows are DONE or archived: verify the
integration worktree is clean and complete; run `git diff --check`, project
validation, the full supported foundation matrix, 10-seed determinism,
native/Web parity, RTP and EV gates, performance, accessibility, save and
migration, and visual QA on that exact head; produce the closure report mapping
every game to branch, reviewer, accepted head and merge commit; return to the
original working tree and confirm its tracked state has not changed since
preflight; merge `codex/game-depth-integration` with `--no-ff` without squashing
or force-updating; run a final validation; and only then remove clean registered
worktrees whose accepted heads are reachable from the final branch.

## 11. Communication and terminal conditions

Send concise progress updates at wave boundaries, after reviews, after each
merge, and whenever a gate reopens work. Include counts: games accepted out of
nine surfaces, branches accepted and merged, unresolved findings, next
dependency. Never describe a row as complete before its independent reviewer
accepts the exact head and post-merge gates pass. If an agent stalls, reassign
its bounded remaining work without discarding valid commits. If a test is flaky,
diagnose and fix determinism; do not rerun until lucky or loosen thresholds.

A genuine blocker must include three attempted safe approaches, exact evidence,
affected prompt rows, preserved branch heads, and the smallest user decision
needed. Hard work, merge conflicts, long tests and review findings are not
blockers.

Your final response must lead with the outcome and include starting and final
branch and commits, all created branches, reviewer verdicts, merge commits, the
per-game completion summary, the complete gate table, closure-report paths, any
retained worktrees or branches, and explicit confirmation that pre-existing user
files were not staged or modified.
