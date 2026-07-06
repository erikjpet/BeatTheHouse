# Agent Prompt — CRITICAL: Table Environments Not Loading (Auto-Resolved Results)

Priority: **CRITICAL — execute before any other prompt in this folder.**

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). A release-blocking regression exists **in the
uncommitted working tree on the project-manager machine** (the pushed `main`
at `87e78a6` passed all gates and does not have this bug — hence this prompt
can only be executed on that machine, or after the WIP is committed to a
branch).

## Bug report (owner playtest, 2026-07-06)

- The roulette table and **all other table environments** do not load.
- Play reverts to "initial pages with automated results" — the table
  environment is not getting triggered; results appear to resolve
  automatically without the table surface/session.

## Step 0 (mandatory): preserve the repro

Snapshot the dirty tree to a WIP branch before touching anything:
`git checkout -b wip/table-env-regression && git add -A && git commit -m "WIP snapshot: table env regression repro"`,
then return to work either on that branch or back on `main` with the WIP
intact. The bug must remain reproducible until root-caused.

## Investigation state (from the PM's interrupted diagnosis)

The uncommitted tree mixes at least three workstreams; the regression is in
one of them. Diff sizes vs HEAD and prime suspects, in order:

1. **Home environment feature (in progress):** `data/environments/archetypes.json`
   (+~1,293 lines — heavily reworked), `scripts/core/run_generator.gd` (+116),
   `scripts/core/environment_instance.gd`, `scripts/core/world_map.gd` (+112).
   The feature changes the starting environment from shop to home types. If
   table venues' archetypes lost/renamed their game-object spots or the
   generator routes travel to wrong archetypes, table environments would fail
   to build — matching "table env not getting triggered."
2. **Playtest root fix (in progress):** `scripts/ui/game_surface_canvas.gd`
   (net −~300 lines — the ambient-overlay consolidation described in
   `docs/todo/playtest_root_fix_agent_prompt.md`), `scripts/games/roulette.gd`
   (+168), `scripts/games/blackjack.gd` (+243), `scripts/ui/foundation_main.gd`
   (+~1,715 across streams). If surface activation was broken during the
   overlay-ownership rework, opening a table could fall through to a
   non-interactive path that auto-resolves.
3. Inventory extraction (new `run_inventory_screen.gd` / view model) — least
   likely but shares foundation_main.

## Localization protocol

1. Reproduce headlessly first: `tools\check_godot.ps1 -RequireGodot
   -FoundationSuite games` and `-FoundationSuite ui` on the WIP branch —
   table-session contract failures should localize the break far faster than
   manual play. If suites pass but the bug reproduces interactively, use
   `tools\foundation_mouse_batch_playtest.ps1 -RunCount 3 -RequireGodot` and
   read its per-run logs for the table-open step.
   **Check no other Godot instance is running first** (the editor was open
   during the PM session; `tasklist | findstr Godot`).
2. Bisect by workstream, not by commit (nothing is committed): selectively
   revert one workstream's files to HEAD in a scratch checkout (e.g.
   `git checkout HEAD -- data/environments/archetypes.json scripts/core/run_generator.gd ...`),
   retest, restore. Identify which stream breaks table loading.
3. Root-cause within that stream. Do not band-aid: if archetype data lost
   table spots, fix the data authoring; if surface activation predicates
   regressed, fix the ownership predicate (the playtest-root-fix prompt's
   architectural section is the reference for intended behavior).

## Hard constraints

1. Preserve all three in-progress workstreams — fix the regression **within**
   the offending stream; do not revert another stream's work to mask it.
2. Per-frame paths stay zero-copy; match house style (tabs, typed GDScript).
3. Add a regression guard: whatever invariant broke (e.g. "every table-game
   archetype resolves a playable table session on entry") gets a foundation
   check so this cannot silently regress again.

## Verification

1. Manual: enter roulette, blackjack, baccarat, and bar dice environments —
   each loads its table surface, accepts a wager, and resolves only on player
   action.
2. `tools\validate_project.ps1`, then `tools\check_godot.ps1 -RequireGodot
   -FoundationSuite games` and `-FoundationSuite ui` once at the end.
3. Move this prompt to docs/todone/ with an execution record per RULES.
