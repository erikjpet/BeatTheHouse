# Environment Library debug mode

Status: **IMPLEMENTED ON `main` — HISTORICAL IMPLEMENTATION RECORD.**
Original branch: `codex/environment-library-debug-mode` (historical provenance;
do not treat it as the current source boundary).

## Goal

Add an **Environments** practice/debug mode alongside the existing Games
library. It must let a tester select any environment, every authored scenario,
and supported world conditions, then enter the real production environment
without creating or saving a normal run.

## Product contract

- Expose the launcher on the main menu and under Settings > Developer.
- List every environment archetype, including hidden rooms and homes.
- List every scenario for the selected environment without progression,
  rarity, weight, or unlock filtering, plus Base / No Scenario.
- Allow normal seeded, deterministic random, and exact condition selection.
- Use a test-only seed namespace: the same request is repeatable inside this
  mode, but the same visible seed need not match a normal run.
- Start with the Games-library practice bankroll and an empty inventory.
- Generate through the same canonical environment, scenario, game-state,
  layout, installation, and finalization code used by normal runs.
- Add a Leave / Choose Environment object to every test room. It opens the
  selector in place of the travel map and can replace the room repeatedly.
- Preserve player-owned attributes across replacements while discarding prior
  room, route, world-map, and generation state.
- Never autosave, overwrite a run, record profile/career results, grant meta
  rewards, or complete challenges from this mode.
- Do not add multiplayer or networking structure.

## Implementation outline

1. Add an environment-practice session flag alongside the Games compatibility
   flag so the established no-save practice boundary remains intact.
2. Extract a request-based environment build seam from `RunGenerator` while
   preserving the normal-run RNG order and output.
3. Add normalized environment-test requests, namespaced seeds, exact scenario
   selection, and pre-generation town-condition overrides.
4. Add a versioned player-state carry snapshot for repeated environment swaps.
5. Build one reusable selector for main-menu and in-session travel-overlay use.
6. Add a test-only Leave contract and atomic room replacement with rollback.
7. Add catalog, determinism, state-carry, isolation, layered-room, and UI tests.

## Completion evidence

- Every current environment and scenario can be launched.
- Same complete test request reproduces the same canonical environment without
  depending on how many test rooms were previously opened.
- Existing normal-run seed fixtures remain unchanged.
- Second and later rooms retain player cash, inventory, heat, drunkenness,
  debt, chips, and other player-owned attributes.
- No save/profile/progression state changes during an environment test session.
- Leave always opens the selector and never performs normal travel.
- Focused contracts and headless project loading pass on the final branch tip;
  any unrelated broad-validator baseline failure is recorded below.

## Validation recorded on branch

- `environment_test_mode_check.gd`: PASS (18 environments, 55 scenarios,
  deterministic exact generation, seed isolation, state carry, layers).
- `check_environment_library_launcher.gd`: PASS (main-menu launch, exact
  conditions, Leave loop, second-room replacement, return to main menu).
- Existing `check_game_library_launchers.gd`: PASS (all 11 launchers).
- `fixsweep06_1_lifecycle_contract.gd`: PASS.
- Headless project/editor load: PASS.
- Self-review confirmed Scenario / Normal Entrance opens an authored layered
  scenario in its authored room, practice rooms receive the same living-town
  setup as normal generation, and only player-owned state crosses rooms.
- `developer_placement_mode_check.gd` retains 11 failures that reproduce
  identically on untouched `main`; they are unrelated to this feature.
- Repository Smoke twice reached its process-isolation guard because another
  Codex task started Godot tests concurrently; neither attempt reported a
  project or feature assertion failure.
- The same full `validate_project.ps1 -Quiet` release gate was then run with a
  clean process census and passed (324 seconds).
- After rebasing onto the concurrent inventory UI update, all focused checks
  passed again (including its inventory test). The combined full-audit rerun
  reached only the process-custody guard when an unrelated YouTube downloader
  server started under the site repository during the audit.
