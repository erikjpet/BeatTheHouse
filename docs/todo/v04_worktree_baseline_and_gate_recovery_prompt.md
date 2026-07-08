# Agent Prompt - v0.4 Worktree Baseline And Gate Recovery

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. This is the first v0.4 release-prep task. The goal is not feature
work; the goal is to make the repository auditable before Act 1 completion
work continues.

## Read first

- `README.md`
- `docs/plans/0.4_act1_completion_plan.md`
- `docs/todo/RULES.md`
- `docs/todo/QUEUE.md`
- `docs/todone/RULES.md`
- Current `git status --short`

## Context

The shared worktree currently contains many uncommitted changes from completed
or partially completed tasks: dialogue/talk, attribute glyphs, open-hours,
jazz/beach/home/collection work, semantic layout, UI/performance bugfixes, and
todo/todone moves. 0.4 cannot start from a vague dirty tree.

## Required work

1. Inventory the current dirty tree by file cluster and owner task. Use `git
   diff --stat`, targeted `git diff -- <path>`, and the archived prompt records
   in `docs/todone/`.
2. For each completed task already moved to `docs/todone/`, verify the
   execution record exists. Fix missing records only with factual evidence from
   local commands or the prompt's current implementation state.
3. Move any completed prompt file still under `docs/todo/` only if its work is
   provably complete and verified. Do not duplicate existing tasks.
4. Decide whether each dirty cluster is:
   - committed as completed work,
   - kept as an intentional local WIP with a queue entry,
   - reverted only if it is generated cruft you can prove is not source, or
   - converted into a fresh todo prompt.
5. Known red gate to clear, not discover: the execution record in
   `docs/todone/playtest_root_fix_agent_prompt.md` discloses a
   `ui_scene_compile` crash (exit -1, no diagnostics, orphaned headless
   Godot processes) from 2026-07-06. Treat reproducing-or-clearing that
   crash as in-scope for this baseline; if it still reproduces, root-cause
   it before declaring the ui gate recovered.
6. Run a fresh baseline:
   - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
   - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
   - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
7. If those pass, run the default gate:
   - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -TimeoutSec 600`
8. Commit locally in auditable chunks. Do not push.

## Hard constraints

- Do not overwrite or discard unrelated user work.
- Do not weaken validators or tests.
- Do not run overlapping Godot gates.
- Keep completed tasks archived in `docs/todone/` with execution records.
- Keep `docs/todo/QUEUE.md` accurate after partitioning.

## Done gate

- `git status --short` is clean, or only deliberate leftovers are listed in
  the final summary with their owning prompt.
- `validate_project.ps1` passes.
- `check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300` passes.
- `check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
  passes.
- Default `check_godot.ps1 -RequireGodot -TimeoutSec 600` is no worse than the
  recorded baseline.
- This prompt is moved to `docs/todone/` with an execution record and committed
  locally.
