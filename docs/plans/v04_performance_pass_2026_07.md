Verdict: no player-visible slowdown introduced.

# v0.4 Player-Style Performance Pass - 2026-07

This pass ran after the completed-work review fixes and measured before
touching performance code. Initial interaction measurements found route
regressions in the player path, then the final probe battery was rerun after
the fixes.

## Player-Style Playthrough

The strict mouse batch is the current player-style driver. It covers the main
menu, meta/home entry routes, world-map travel, object interaction, shop/item
purchase, lender/service hooks, game entry, run completion, save/load, and the
visual QA route checks used by the release gate.

| Phase | Initial result | Final result |
| --- | --- | --- |
| Pull-tabs room with clerk/redeemer objects | Failed visual QA because game hooks generated unstable object ids and overlapped the clerk/redeemer hit areas. | Passed after game hooks use explicit `object_id`/`dialogue_id` and layout entries are bound before rendering. |
| World-map travel target list | Failed visual QA because enabled plus fallback targets could exceed the capped target budget. | Passed after enabled/fallback candidates are capped together. |
| Item purchase save/load route | Failed batch coverage because a later QA restart could hide the purchased item before the check ran. | Passed after item purchase now immediately performs the save/load coverage check. |
| Strict interaction smoke | 0/10 before fixes due the route failures above. | 10/10 playable-loop pass, 10/10 R100 pass, 10 victories, 0 true failures, 242.791s wall time. |

## Enforced Probe Budgets

`tools/foundation_performance_probe.gd` now enforces the new v0.4 surfaces in
the normal performance probe. Each budget is p95 frame time on the development
hardware, matching the prompt's active conversation and overlay target.

| Surface | Budget p95 | Measured p95 | Measured max | Status |
| --- | ---: | ---: | ---: | --- |
| Meta home idle | 16.0ms | 7.391ms | 7.723ms | PASS |
| Talk dock active | 16.0ms | 6.909ms | 6.934ms | PASS |
| Dialogue active | 16.0ms | 6.907ms | 6.915ms | PASS |
| Eviction map transition | 16.0ms | 6.907ms | 6.945ms | PASS |

The same probe covered every required game surface and resolve path.

| Resolve path | Budget avg/p95/max | Measured avg/p95/max | Status |
| --- | ---: | ---: | --- |
| Pull-tabs buy | 1.5 / 2.5 / 4.0ms | 0.872 / 0.939 / 1.052ms | PASS |
| Slot spin | 6.0 / 8.0 / 10.0ms | 3.858 / 5.446 / 5.678ms | PASS |
| Bar dice roll | 1.5 / 3.0 / 4.0ms | 0.700 / 0.715 / 2.514ms | PASS |
| Blackjack basic play | 4.5 / 5.5 / 7.0ms | 2.621 / 2.723 / 2.971ms | PASS |
| Baccarat deal | 1.25 / 1.75 / 3.0ms | 0.850 / 0.905 / 1.000ms | PASS |
| Roulette spin | 2.0 / 3.0 / 4.0ms | 1.100 / 1.178 / 1.245ms | PASS |
| Video poker draw | 2.5 / 4.5 / 5.0ms | 1.059 / 1.196 / 2.924ms | PASS |

## Web Smoke

The first web smoke after the route fixes produced one narrow browser-frame
miss: `slot_active` frame p95 was 112.282ms against the 110.000ms budget. A
rerun on the same tree passed without a code or budget change, so this is
recorded as a one-sample browser spike rather than a waived regression.

Final web smoke passed with `ready_wall_msec=14085` against the 20000ms boot
budget, telemetry overhead `0.019645ms` against the `0.1ms` budget, 20
scenarios covered, and zero failures.

## Soak

The initial 60-minute soak failed retained growth slopes:

| Metric | Initial retained slope | Cap |
| --- | ---: | ---: |
| Resource count | 1.000/sample | 0.500/sample |
| Object count | 8.333/sample | 2.000/sample |

Root causes were lazy finite texture/resource warming on map/glyph surfaces,
world-map hit buttons being recreated during overlay refreshes, and stale
pixel-scene object animation phase entries surviving room churn. The fixes
prewarm finite glyph and map icon textures, pool world-map hit buttons, and
prune the object phase cache to currently active room objects.

Final 60-minute soak passed:

| Metric | Final retained slope | Cap | Status |
| --- | ---: | ---: | --- |
| Static memory | 0 bytes/sample | 262144 bytes/sample | PASS |
| Nodes | 0/sample | 0.5/sample | PASS |
| Objects | 1.000/sample | 2.000/sample | PASS |
| Resources | 0.333/sample | 0.5/sample | PASS |

Coverage included 99 world travels, 42 game actions, 41 slot actions, 7
save/loads, 5 item actions, 4 event actions, 8 service actions, 2 lender
actions, 2 pinball cache stress blocks, and 5 started runs.

## Fixes Landed

- `245e4d9 Fix v04 player route performance regressions`
  - Bound pull-tab clerk/redeemer hooks to explicit object/dialogue ids.
  - Capped world-map enabled/fallback travel targets together.
  - Verified item purchase save/load coverage immediately after purchase.
- `2f7f3d9 Enforce v04 player performance budgets`
  - Added enforced meta home, talk dock, dialogue, and eviction/map transition
    budgets to the performance probe.
  - Warmed finite attribute glyph textures at startup.
  - Prewarmed map icons and background textures.
  - Reused a fixed pool of world-map node hit buttons.
  - Pruned pixel-scene object animation phase cache to active objects.

## Verification

| Command | Result |
| --- | --- |
| `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` | PASS - foundation architecture validation passed. |
| `powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot` | PASS - no failures; all required game surfaces, resolve paths, slot autoplay, casino slot previews, and new v0.4 surfaces covered. |
| `powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1` | PASS - final summary had zero failures. |
| `powershell -ExecutionPolicy Bypass -File tools\foundation_soak_probe.ps1 -RequireGodot -SimMinutes 60 -ActionsPerSample 28 -SeedPrefix V04-PERFPASS` | PASS - retained slopes within caps. |
| `powershell -ExecutionPolicy Bypass -File tools\foundation_mouse_batch_playtest.ps1 -RunCount 10 -RequireGodot` | PASS - strict gate, 10/10 playable, 10/10 R100, 10 victories, 0 true failures. |
