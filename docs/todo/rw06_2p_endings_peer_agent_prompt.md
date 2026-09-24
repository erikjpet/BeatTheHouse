# rw06_2p — Endings and balance peer agent

Status: TODO. Self-contained. Launch with this file only.

You are a **peer** of the release orchestrator (a separate agent running
`rw06_execute_release_week_prompt.md`). You own two rows end to end:

- **rw06_2**: all three endings reach their win state. Follow
  `docs/todo/rw06_2_three_endings_prompt.md`.
- **rw06_3**: data-only balance on the ending routes. Follow
  `docs/todo/rw06_3_balance_prompt.md`.

Read `docs/todo/README_0_6_release_week.md` (the plan and rules), and Q-005 and
Q-009 in `D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`. They
are binding.

## Startup handoff (don't collide with the orchestrator)

1. Read `D:\Projects\Beat-The-House\docs\todo\rw06_2p_status.md`. Until it
   contains the orchestrator's handoff paragraph (branch, tip, next step), don't
   edit code or push. Do read-only prep only, and re-check every 10 minutes.
   The orchestrator writes the handoff after it reads Q-009 (it checks the
   questions file every 30 minutes).
2. After the handoff, you own `codex/rw06_2-prep` (or a successor branch you
   create). The orchestrator no longer touches rw06_2/rw06_3 code or branches.

## Ownership

- **You own:** ending logic, route replay tooling
  (`tools/rw06_2_ending_replay.ps1`, the agent playtest bridge), game, event,
  Crew and ending fixes, economy data for rw06_3, `docs/plans/rw06_2_routes/`,
  and `docs/todo/rw06_2p_status.md`.
- **You don't touch:** room placement (`scenario_layout_resolver.gd`,
  `environment_instance.gd`, `environment_slot_binder.gd`,
  `pixel_scene_canvas.gd`, the placement JSONs), the room action list UI, the
  scoreboard (`README_0_6_release_week.md`), or rw06_4. If an ending is blocked
  by a room problem, write it in your status file for the orchestrator.
- **`foundation_main.gd` is shared.** Keep your edits there narrow, rebase
  often, and merge small.

## Speed rules (owner priority: working software, fast)

- Find out quickly whether each ending works. Exploratory runs may drive the
  game through the same production action entry points the UI uses (no state
  injection, no debug shortcuts). The real-input replay bridge is required only
  for the final qualifying runs.
- You may run up to 3 sub-agents, one per ending (clean, cheat, heist), each in
  its own worktree.
- Godot: follow Q-009. Isolated focused runs may run in parallel under the
  shared lease folder `D:\Projects\Beat-The-House-worktrees\.godot_leases\`
  (at most 4 Godot processes machine-wide). Full Smoke/Contract suites and any
  timing measurement are exclusive.
- Keep documentation light. Your status file holds one short entry per real
  milestone, with no hashes for exploratory runs.
- Rooms still use the old layout on `main` until rw06_1 lands. Don't wait on
  that for exploration; the final qualifying pass happens after rw06_1 is on
  `main`.

## Status file format (`docs/todo/rw06_2p_status.md`)

Keep this block at the top, current:

```
Endings: clean <none|partial|WIN> · cheat <…> · heist <…>
Replay script: <not ready|ready|qualifying 3/3>
Balance (rw06_3): <not started|in progress|done>
Blocked on: <nothing | room issue for orchestrator | Q-NNN>
Updated: <date time>
```

Below it, add one dated line per milestone.

## Rules (binding)

- Owner decisions go only through the questions file: ask, then keep working.
- Never weaken a test, budget, idle-liveness floor or deterministic assertion.
- Everything is seeded and happens at action boundaries. Every consequence fires
  exactly once. No hidden-state leaks. A run that ignores the Crew stays a true
  no-op.
- No changes to game rules, RTP or payout tables. Balance is data-only.
- Git: work in worktree branches, fast-forward `main`, push. Never force-push.
  Delete your branches and worktrees once merged. A row isn't DONE while its
  branch exists.
- Never package, upload or publish anything.

## Done

- rw06_2: 3/3 endings reach the win state through the real-input replay on
  `main` after rw06_1 has landed.
- rw06_3: balance changes logged and all three routes still green.

When both are done, set your status file to DONE and tell the orchestrator in
that file that rw06_4 can start.
