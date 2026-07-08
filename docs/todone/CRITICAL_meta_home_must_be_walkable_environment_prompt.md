## Execution Record

- Completion date: 2026-07-07
- Implementing commits: a0e11fb (claim), 80d4273 (walkable meta home implementation)
- Verification gates:
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` - PASS (`Beat the House foundation architecture validation passed.`)
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300` - PASS (`ui_scene_compile PASS`, report `D:\Projects\Beat-The-House\.tmp\test_reports\20260707_225618_smoke\summary.json`)
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300` - PASS (`foundation_systems PASS`, report `D:\Projects\Beat-The-House\.tmp\test_reports\20260707_225753_smoke\summary.json`)
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 5 -SeedPrefix V04-METAHOME-REWORK` - PASS (5 seeds, 160 checkpoints, combined hash `478083386`)
  - `Godot_v4.6-stable_win64_console.exe --path . --script res://tools/environment_layout_screenshots.gd -- --out=.tmp\meta_home_review --meta-home-review` - PASS (`META_HOME_LAYOUT_SURVEY_DONE`, screenshots listed below)
- Screenshot evidence:
  - `D:\Projects\Beat-The-House\.tmp\meta_home_review\back_alley.png`
  - `D:\Projects\Beat-The-House\.tmp\meta_home_review\motel_room.png`
  - `D:\Projects\Beat-The-House\.tmp\meta_home_review\apartment.png`
  - `D:\Projects\Beat-The-House\.tmp\meta_home_review\house.png`
  - `D:\Projects\Beat-The-House\.tmp\meta_home_review\pawn_shop.png`
- Verified click path: open Home from the main menu, click a home container, click an unopened bag, click the apartment/house trade-up station, use the map prop to travel to the pawn shop, click the pawn sell counter, confirm a sale, then use the pawn shop exit/map prop to return home.
- Deviations from prompt: none. The accepted backend was retained; the rejected full-screen collection browser is no longer the Home entry path.

# Agent Prompt - CRITICAL: The Meta Home Must Be A Walkable Environment, Not A Menu

Priority: **CRITICAL — top of queue. Execute before every other entry.**

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). This is a **rework of rejected work**. The
`v04_meta_home_environment` task (now archived with a REJECTED notice in
docs/todone/) was supposed to deliver a persistent, **walkable** home
environment. What it delivered instead was:

1. **A menu.** The "home" is a menu/list screen. The owner explicitly did
   not ask for a menu — the entire point of the feature was to REPLACE the
   menu-style inventory browser with an environment the player stands in
   and interacts with, exactly like an in-run room. The original prompt
   said this in its first paragraph and again in §3 ("Walkable room using
   the existing environment rendering (pixel scene canvas + archetype
   spots)"). This requirement was not optional and was not met.
2. **The menu is also broken.** Its content cuts off on screen and it is
   not actually usable even judged as the wrong thing.

## What "an environment" means here — no room for interpretation

The player's home renders and behaves **exactly like an in-run room does**:

- It is drawn by the same environment rendering stack the run rooms use
  (`scripts/ui/pixel_scene_canvas.gd` + authored archetype spots from
  `data/environments/archetypes.json`). The archetypes already exist and
  already render in runs: `back_alley`, `motel_room`, `apartment`, `house`.
  Runs start in these rooms today — the meta home is those same rooms in a
  meta interaction mode.
- The player interacts by clicking **props/objects placed in the room**
  (the same interaction-spot machinery in-run rooms use), not by scrolling
  a list:
  - **Storage containers** (the owned bag/backpack/suitcase/trunk render
    as props; homeless alley = only your containers on the ground/against
    the wall) — clicking one opens its contents.
  - **Bags** stored at home are visible objects; clicking an unopened bag
    offers the single Open button and plays the reveal.
  - **Trade-up station** is a physical prop that only exists in the
    apartment/house archetypes.
  - **Upgrade sign/prop** shows the next housing tier and its gold price.
  - **Exit/door or map prop** leaves to the meta map. The meta map then
    reaches the pawn shop, which is likewise a **room** with a counter
    prop (its one interaction), not a screen.
- Detail panels opened FROM a prop (item inspection with floats/badges,
  container contents, sell confirm) are acceptable popups — the in-run
  inventory popup is the established pattern — but the home itself is a
  room you stand in, never a full-screen menu.
- Every popup/panel must fit inside the 1280×720 viewport with nothing cut
  off, including with 4-choice/long-content cases (the current cut-off bug
  must be impossible, not just fixed for one case; assert popup rects stay
  inside the screen rect in the scene-compile check, following the existing
  run-inventory popup assertions at ui_scene_compile_check.gd's snapshot
  contract as the pattern).

## What to keep

The rejected task's **backend is not the problem** — keep and reuse:
`MetaCollectionService` state (housing tiers, gold, prices in
data/collections/collections.json, homeless carry-everything rule,
trade-up gating, pawn pricing, daily/challenge isolation), the meta map
travel, and the run linkage. This rework is about the **presentation and
interaction layer**: replace the menu with the in-world room. Salvage any
view-model/data plumbing that feeds cleanly into prop-driven interactions.

## What to remove

The menu-screen implementation of the home must be **removed**, not left as
a parallel path. One home experience: the room. (The main-menu entry now
leads to the meta map/home room.)

## Verification (owner will personally re-review this)

1. Screenshot evidence: use `tools/environment_layout_screenshots.gd` (or
   the visual-QA harness) to capture the back_alley, motel_room, apartment,
   and house meta rooms plus the pawn shop, showing props placed without
   overlap (the pad-8 collision rule applies to authored spots).
2. Manual-path check via the mouse-batch/visual-QA harness: walk home →
   click a container → inspect an item → open a bag → (at apartment+) use
   the trade-up station → exit to map → pawn shop → sell with confirm →
   return home. Every step through real clicks on room props.
3. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
4. `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
   and `-FoundationSuite systems -TimeoutSec 300` — including the updated
   popup-fits-screen assertions.
5. `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 5
   -SeedPrefix V04-METAHOME-REWORK` — the presentation rework must not
   touch run determinism.
6. Archive this prompt to docs/todone/ with an execution record that
   includes the screenshot paths; update QUEUE.md. Commit locally; do NOT
   push.

## Hard constraints

1. Reuse the in-run environment/interaction machinery — do not write a
   second room renderer or a second interaction system.
2. Zero per-frame allocations; the meta rooms obey the same idle-redraw
   discipline as run rooms (dirty/animation gating — see CLAUDE.md).
3. All prior owner-binding rules from the archived prompt still apply
   unchanged (daily/challenge isolation, homeless rule, trade-up gating,
   pawn-only gold faucet, no rent).
4. Coordinate with the claimed act-two-seam task: if it is still claimed
   in QUEUE.md, wait for it to archive before starting (foundation_main
   overlap).
5. Match house style: tabs, typed GDScript, sparse constraint comments.
