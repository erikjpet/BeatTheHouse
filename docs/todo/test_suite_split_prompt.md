# Agent Prompt — Split the Test Monoliths into Per-System Suite Files

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: this task is part of the 0.4.0 polish line, not a
post-release change. This file is fully self-contained.

## The problem (verified)

- `scripts/tests/foundation_check.gd` is **~19,200 lines in one file**
  (grown ~50% in two weeks) and `scripts/tests/ui_scene_compile_check.gd`
  is ~6,900. Together they are 26k of the repo's ~78k script lines.
- They are the second-worst merge-collision surface after
  `foundation_main.gd`: every feature task appends tests to the same file.
- `tools/check_godot.ps1` already supports named `-FoundationSuite`
  groups (`systems`, `ui`, ...), so the runner architecture for splitting
  exists — the monolith is just history, not design.

## The task

1. **Map the current suites.** Read `tools/check_godot.ps1` and both test
   files to understand how suites select tests today (function-name
   prefixes, registration lists, or switch blocks — verify, don't guess).
2. **Split `foundation_check.gd` into per-system files** under
   `scripts/tests/foundation/` (e.g. `check_run_state.gd`,
   `check_world_map.gd`, `check_events.gd`, `check_debt_lenders.gd`,
   `check_items_shop.gd`, `check_saves.gd`, `check_games_<family>.gd`,
   `check_collections_meta.gd`, `check_time_system.gd`, ...). Choose
   boundaries by the system under test, not by file size; shared helpers
   go into a single `check_common.gd` (or equivalent) that every suite
   file uses.
3. **Split `ui_scene_compile_check.gd`** the same way if its structure
   allows (compile-check scaffolding + per-screen checks); if it is
   genuinely one cohesive harness, split only its clearly separable
   sections and justify what stayed.
4. **Keep the runners working.** `check_godot.ps1 -FoundationSuite
   systems|ui|...` must keep working with the same suite names (extend
   with finer-grained names if cheap, but never break existing ones —
   other prompts and release evidence cite them). `validate_project.ps1`
   must keep passing.
5. **Test-count parity is the acceptance bar.** Before splitting, capture
   the exact number of test functions/assertion units per suite; after
   splitting, the counts must match exactly (list any intentional
   dedups). Zero tests may be lost, disabled, or weakened. Move code
   verbatim; this is relocation, not rewriting.
6. Migration is one-shot: no compatibility shims, no stub monolith left
   behind re-exporting the old file. Delete the monolith(s) in the same
   commit that lands the split, so there is exactly one home for tests.

## Hard rules (binding)

- Zero production-code changes. If a test needs a production change to
  survive relocation, something is wrong — stop and report instead.
- Suite wall-time must not regress by more than noise; report before/after
  timings per suite.
- Match existing style: tab indentation, typed GDScript, sparse comments.
  Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## QA (all required)

1. Test-count parity table (per suite, before vs after).
2. Full battery green: every `-FoundationSuite` name that
  `check_godot.ps1` supports, run to PASS after the split.
3. Deliberate-failure probe: temporarily break one known assertion in a
   split file, confirm the suite fails loudly (proves tests actually run
   post-split), then revert. State that you did this.
4. `validate_project.ps1` green.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- Every supported `-FoundationSuite` via
  `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite <name> -TimeoutSec 300`

## On completion

When every gate passes: commit the work with a clear message, delete this
prompt file in the same commit so it cannot be executed twice, push, and
report the new file map, the parity table, per-suite timings before/after,
and each gate result. If a gate fails and you cannot fix it, stop, do not
commit, and report the failure output verbatim.
