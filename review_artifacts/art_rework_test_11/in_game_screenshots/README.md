# Test 11 In-Game Screenshots

This folder contains 36 screenshots captured from the real Beat the House Godot scene at the active 1600 × 900 game window. The game retains its 1280 × 720 design-space layout while rendering at this 16:9 desktop resolution.

- `noon/` — all 18 environments with the game clock fixed at 12:00 PM and the Test 11 daytime painting loaded into the live environment canvas.
- `midnight/` — all 18 environments with the game clock fixed at 12:00 AM and the restored Test 04 night painting loaded into the live environment canvas.
- `paired_in_game_contact_sheet.png` — every noon/midnight pair together.
- `noon_in_game_contact_sheet.png` and `midnight_in_game_contact_sheet.png` — time-specific overviews.
- `capture_report.json` — environment names, time values, source background paths, viewport size and resolved interactable-object layouts.

The screenshots include the actual game HUD, environment header, interactable objects, gameplay overlays and travel controls. They were produced with `tools/test11_environment_time_screenshots.gd` and did not replace production environment assets.
