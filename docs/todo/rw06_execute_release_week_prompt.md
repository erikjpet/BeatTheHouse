# rw06 — Release-week execution agent (orchestrator)

Status: TODO. Self-contained. Launch with this file only.

You own getting Beat the House 0.6.0 from its current state to an upload-ready
artifact handoff by **2026-09-29**. You do this by executing the release-week rows in order. You may
run rows yourself or delegate them to sub-agents. Either way, you are accountable
for verifying every row before it counts as DONE.

## Read first (in full)

1. `docs/todo/README_0_6_release_week.md`: the plan, owner decisions, order,
   scoreboard and shared rules. It is binding.
2. Each row prompt, when you reach it:
   - `docs/todone/rw06_0_custody_commit_prompt.md` (completed/archive record)
   - `rw06_1_fixed_slot_rooms_prompt.md`
   - `rw06_2_three_endings_prompt.md`
   - `rw06_3_balance_prompt.md`
   - `rw06_4_release_gate_ship_prompt.md`
   - `docs/todone/rw06_5_owner_gameplay_fixes_prompt.md` (completed/archive record)
   - `rw06_6_pull_tab_glimmer_prompt.md`
3. `docs/todo/rw06_2p_endings_peer_agent_prompt.md` and
   `docs/todo/rw06_2p_status.md`: the Q-009 peer handoff for rw06_2/rw06_3.
4. `docs/plans/0.6.1_backlog.md`: where everything out of scope goes.

## Owner questions file (you enforce it)

`D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md` is the only channel to the owner. Read its protocol now.

- You and every sub-agent ask there and keep working. Never stall on an answer.
- Put a short pointer to the file in every sub-agent brief.
- Check the file at least every 30 minutes and at every session start. Route
  each ANSWERED entry to whoever now owns its `Resume` work, or do that work
  yourself.
- After MERGED, the primary checkout is where the plan files get their first
  commit (rw06_0, commit 1). After that, you alone commit the questions file
  from the primary checkout: run `git pull --ff-only`, then commit only that
  file.
- Run `git pull --ff-only` in the primary checkout after every push to `main`,
  so the owner always reads current files there.
- Those are the only git writes allowed in the primary checkout. Keep it
  otherwise clean and on `main`.
- Owner checkpoints and hard gates in this plan are questions in this file.

## Deliverable

Two upload-ready zip files: the itch.io Web build and the Windows `.exe`, both
at 0.6.0, built with `tools/export_itch.ps1` without `-Push`, PCK-audited and
packaged-smoke verified. The owner uploads them personally. No agent ever runs
butler or any upload or publish command.

## Startup: you launch at the same time as the worker handoff

The owner starts you at the same moment the running postfix06_2 worker receives
its steer (`rw06_pre_worker_handoff_message.md`). While that worker does its
handoff:

- **Never** run git write commands in, edit files in, or switch branches in the
  primary checkout `D:\Projects\Beat-The-House`. The worker is using it. You may
  read files there, including the untracked plan files.
- Do all of your own work in worktrees under
  `D:\Projects\Beat-The-House-worktrees\`, created from `origin/main`. If you
  hit a git lock error, wait and retry. Never delete a lock file.
- During this historical handoff phase, run no Godot at all. After MERGED, use
  the Q-009 lease policy under Standing duties.
- Never touch the worker's branch `wip/postfix06_2-snapshot`. The worker merges and deletes it itself.

**Phase 0: prep while you wait.** Everything here is read-only, or lives only in
your own worktree. **Run no Godot process until the worker reports MERGED.**
Its Contract baselines are timing-sensitive, and contention could create false
reds.

1. Read the plan, all the row prompts, `docs/plans/grand_casino_endgame_design.md`
   and the Crew/heist sections of `docs/plans/0.6_living_world_roadmap.md`.
2. Start rw06_2's research on `origin/main`: map each ending's intended route and
   read `tools/agent_playtest_session.ps1` and `.gd` to plan the replay script.
   Draft `docs/plans/rw06_2_routes/*.md` in your worktree. Hands-on harness use
   waits until after MERGED.
3. Start rw06_1's design reading: `placement_surfaces.json`, `archetypes.json`,
   the scenario sequences, and the current resolver. Draft the slot schema.

**Gate into rw06_0.** Poll every 10–15 minutes with `git fetch origin`. rw06_0
starts only when all of these are true:

- the worker has reported MERGED;
- `origin/main` contains the postfix06_2 merge commit and
  `docs/plans/postfix06_2_placement_harvest.md`;
- `origin/wip/postfix06_2-snapshot` has been deleted;
- the primary checkout is on `main` with no tracked modifications.

If the snapshot branch hasn't appeared within 3 hours, or the merge hasn't
landed within 10 hours, raise a question in the questions file. Keep doing
Phase 0 work in the meantime.
Once the merge lands, rebase your Phase 0 worktrees onto the new `main`.

## Execution order

1. **rw06_0.** Run it and verify it. Nothing else starts until `main` has the
   finished fixes and the todo folder is organized.
2. **rw06_1, rw06_5 and rw06_6 are the release orchestrator's implementation
   rows.** rw06_5 holds the owner's original requested fixes. Q-014 adds rw06_6
   as a separate narrow pull-tab presentation lane; it must not overlap rw06_1
   placement or rw06_2/rw06_3 ending work. A separate Q-009 peer owns rw06_2
   and then rw06_3 from the pushed handoff in `rw06_2p_status.md`.
   - The release orchestrator stops editing rw06_2/rw06_3 code and branches
     after that handoff. It reads the peer status and copies milestones into the
     scoreboard.
   - Watch for drift. The peer must not edit placement files, and rw06_1 must
     not edit game, Crew, ending or balance logic.
   - The peer does rw06_2's final three-ending pass on `main` **after** rw06_1
     lands.
3. **Owner checkpoint.** Once rw06_1 and rw06_5 have landed, ask the owner in
   the questions file. The peer continues rw06_2's 3/3 ending work in parallel
   and does not delay this requested playthrough:
   - the build is ready for their start-to-finish run;
   - the rw06_1 contact sheet link, for their visual review of room placement.

   Ask for their notes in `rw06_owner_questions.md`, and keep working on
   anything that doesn't depend on them.
   Owner blockers become scoped fixes, assigned to rw06_1 for placement or
   to the rw06_2/rw06_3 peer for everything else. Non-blockers go to the 0.6.1
   backlog.
4. **rw06_3** is owned by the peer and starts after the owner's notes are
   handled and rw06_2's route evidence exists.
5. **rw06_4** (gate and artifact handoff) starts only after rw06_6 also lands,
   the owner's required start-to-finish run is complete, and every blocking
   owner note is handled. It has four release hard stops after that playthrough:
   source approval, release-copy approval, artifact approval, and artifact
   handoff/upload confirmation. Each is asked in the questions file. Agents
   post the two zip paths and SHA-256
   hashes for the owner, never run `export_itch.ps1 -Push`, butler, or any
   upload/publish command, and tag only after the owner confirms they uploaded.

## Your standing duties

- **Resumability.** Your state lives in the repository, not in your memory. You
  will run for about a week and your context will be compacted or restarted.
  Before and after every significant step, make sure the scoreboard and the row
  Status column reflect reality. On any restart, resume from the scoreboard, the
  row statuses, `git log` and `git worktree list`. Never redo work that is
  already on `main`.
- **You are the only scoreboard editor.** Sub-agents report to you, and you
  commit the scoreboard updates to `main`. This avoids merge conflicts from
  parallel rows.
- **Peer status.** Read `docs/todo/rw06_2p_status.md` on the same cadence as the
  owner questions file. Copy real rw06_2/rw06_3 milestones into the scoreboard;
  do not edit the peer's code or branch after handoff.
- **Early placement look.** Relay rw06_1's day-2 three-room contact sheet to the
  owner right away, and route their answer back.
- **Q-009 room split.** First land the shared Q-008 rendering fixes that move
  nonphysical concepts to the action list and draw true behind-counter
  occlusion. Then split `placement_surfaces.json` by map ownership across up to
  three rw06_1 agents: Grand Casino maps; Bar plus Corner Store; all other
  rooms. They may edit only their assigned map objects and report back for one
  integration pass.

- **Scoreboard content.** After every row completion or full test pass, update
  `README_0_6_release_week.md` with current values and a dated history line.
  The owner uses it to see whether things are improving, so it must always be
  true and current.
- **Verify independently.** Before marking a row DONE, rerun its acceptance
  gates yourself on the merged `main`. A branch or a sub-agent's claim is not
  evidence.
- **Scope.** If something doesn't block "three endings to the win state, stable
  rooms, owner-requested fixes (rw06_5 and Q-014/rw06_6), slim gate green", it goes to `docs/plans/0.6.1_backlog.md` with enough
  detail to act on. Nothing is silently dropped.
- **Schedule.** If a row is going to overrun its day budget, raise a question
  early. Give one recommended cut: narrow an ending, or reduce slots and rely on
  the overflow list. Never weaken a gate to hold the date.
- **Git.** You and your sub-agents may commit and push to `main` via worktree
  branches and fast-forward. Every branch and worktree you or a sub-agent
  creates is merged into `main` and then deleted, both locally and on origin,
  before its row is DONE. At an intermediate owner checkpoint, `git branch -a`
  and `git worktree list` must show no leftover branch or worktree for a row
  already completed or abandoned; active parallel rw06 rows remain visible and
  are recorded on the scoreboard. At final closeout, no rw06 or postfix06_2
  branch or worktree may remain. Never force-push, never rewrite history,
  never delete branches you didn't create, never stage `.tmp/`. Archive;
  never delete docs.
- **Godot leases (Q-009).** Isolated focused runs may overlap, up to four Godot
  processes machine-wide, only when each has its own worktree, isolated
  `APPDATA`/`LOCALAPPDATA`, explicit `--log-file`, and own-process cleanup. Use
  the canonical console at
  `D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe`
  and repeat that exact path in every sub-agent brief. Worktrees must not
  auto-detect another engine. Use
  `check_godot.ps1 -AllowConcurrentGodot` for such focused runs. Coordinate in
  `D:\Projects\Beat-The-House-worktrees\.godot_leases\`: clear only leases whose
  filename PID is dead; a normal run waits while `EXCLUSIVE.lease` exists or
  four live leases exist, writes `<agent>-<pid>.lease`, and deletes it on exit.
  Full Smoke/Contract/Full, performance or timing measurements, soak, and every
  rw06_4 gate are EXCLUSIVE: create `EXCLUSIVE.lease` first, wait for all other
  leases and Godot processes to clear, run alone, then remove it.
- **Blockers.** A genuine blocker goes into the questions file with what you
  tried, the exact evidence, and the smallest decision needed. Anything else is
  work.

## Rules (inherited, binding)

- Never weaken a test, budget, idle-liveness floor or deterministic assertion
  to get to green. An idle draw cost of 0.000 without its liveness counter is a
  failure.
- Everything is seeded and happens at action boundaries, never on wall-clock
  time. Every consequence fires exactly once across save, reload, travel,
  revisit, abort and expiry.
- Hidden state never leaks: Turn, traitor, rigged-draw and unrevealed-ticket
  information.
- A run that ignores the Crew stays a true no-op for Crew systems.
- Game rules, RTP and payout tables don't change. Balance is data-only, in
  rw06_3.

## Done

0.6.0's two verified zips are handed to the owner, the owner confirms in the
questions file that they uploaded them, and the exact source is then tagged
`v0.6.0`. The scoreboard is all green, and no release-week branch or worktree remains unmerged. Every row prompt is archived to `docs/todone/` with its execution
record filled in. The 0.6.1 backlog contains everything that was deferred.
