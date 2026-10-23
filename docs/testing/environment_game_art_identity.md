# Environment game-art identity regression (2026-10-23)

Reported Web NEXT: idle Craps, Blackjack and Video Poker displayed outdated art,
then changed model on pointer enter. Reproduced on source and deployed NEXT
`c43391adefadc929c9de019608ae153eb0dffcce` in a fresh, muted, owned browser.
The normal Environment Library generated the Grand Casino Main Floor; no user
browser, save or profile was opened. Idle, hover and leave captures reproduce the
change for all three reported games.

## Cause and removal inventory

`pixel_scene_canvas.gd::_draw_game_prop` dispatched unselected Web Grand Casino
props to `_draw_low_detail_game_prop`; selected/hovered props took the current
normal painters. This was a procedural renderer fork, not stale PNG imports or
a browser cache. `315655474792bd8a6669629a9946137231ea46e1` introduced the
Grand Casino performance fallback. `12d1665dcfcae919f67565fcf2ff6878e7f0d61a`
later exempted generated slot/pull-tab cabinets but deliberately retained the
fallback for other games. Thus current art coexisted with the older idle path.

Before removal, tracked-source searches found exactly one caller of
`_draw_low_detail_game_prop`, and its only delegated calls were the five
`draw_low_detail` methods below. No other code, catalog, dynamic method name,
scene or tool referenced these entry points. All were tracked and remain
recoverable from Git history.

- `scripts/ui/pixel_scene_canvas.gd`: removed the idle dispatch and obsolete
  generic table/video-poker painter.
- `scripts/ui/game_props/bar_dice_room_prop.gd`: removed `draw_low_detail`.
- `scripts/ui/game_props/coin_pusher_room_prop.gd`: removed `draw_low_detail`.
- `scripts/ui/game_props/craps_room_prop.gd`: removed `draw_low_detail`.
- `scripts/ui/game_props/scratch_ticket_room_prop.gd`: removed `draw_low_detail`.
- `scripts/ui/game_props/street_craps_circle_prop.gd`: removed `draw_low_detail`.

Idle and focus now share the current painter for Craps, Blackjack/card tables,
Video Poker, Baccarat, Roulette, Coin Pusher, Scratch Tickets, Bar Dice and Street
Craps. Slot/pull-tab cabinets retain their existing current path. Legitimate
small-size helpers remain because the current painters still call them at small
geometry, independently of hover. No gameplay image or untracked data was
deleted. Ambient Web detail/cadence and autonomous animation are preserved.

## Focused checks

Run each with the pinned Godot 4.6 engine, `--headless --audio-driver Dummy --path .
--script res://scripts/tests/<name>.gd`, inside the normal owned 12% CPU/2 GiB Job:

- `environment_game_art_path_check`: initial bounded reproduction failed with
  27 legacy calls; fixed dispatch passes all ten prop families across forced
  Web/native detail modes and idle/focus/leave. Also rejects restoration of the
  removed fallback entry points.
- `environment_hover_affordance_check`: PASS.
- `animation_liveness_without_pointer_check`: PASS.

Native headless checks do not substitute for deployed Web visual verification.
The delivery receipt records exact NEXT identity, served artifacts, and browser
captures after publication. No full suite or unrelated implementation lane was
opened.
