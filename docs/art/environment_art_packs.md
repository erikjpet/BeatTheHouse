# Environment art packs

A room is a 900 × 430 board. Draw on that grid; deliver PNGs at 2× resolution. Art changes the room background, its animation and counter fronts. People, objects, labels, interactions, placement coordinates and the camera keep their existing positions.

## Folder and activation

Copy the delivery folder over the repository root. For each room use:

```text
data/art/environments/<environment_id>.json
assets/art/environments/<environment_id>/background.png
assets/art/environments/<environment_id>/anim/<name>.png
assets/art/environments/<environment_id>/counters/<foreground_art_id>.png
```

Texture paths in JSON are relative to that room's asset folder and must stay inside it. Use forward slashes and PNG files. `data/art/environments/index.json` contains `{"enabled": ["gas_station_casino"]}` during the proof. The full delivery lists all 20 room identities below. A disabled, missing or invalid pack uses the existing code drawing. An invalid enabled pack logs the reason and rejects the whole pack. An omitted counter entry keeps that counter's original front.

The existing flat `<environment_id>.png` files stay beside these folders. Do not delete them or the code drawing. New PNGs use the existing cold-import pipeline. Do not edit project settings, export presets, pipeline pins or placement data to activate art.

## Manifest and board grid

```json
{
  "schema": "bth.environment_art/v1",
  "environment_id": "gas_station_casino",
  "board_size": [900, 430],
  "pixel_scale": 2,
  "background": {"texture": "background.png"},
  "animations": [],
  "counters": {}
}
```

`background.texture` is required and must be exactly 1800 × 860 pixels. Empty animations and counters are valid. Coordinates are board units: rectangles are `[x, y, width, height]`, points and speeds are `[x, y]`. Positive rectangle sizes must intersect the board; movers may start or end offscreen. Transparent animation/counter areas reveal earlier layers. Nearest filtering preserves the authored pixels at the board scale.

Draw order is background, animations in JSON order, counter fronts, scenario wash, focus dim, live objects and overlays. A person behind a counter receives the same counter-front replay over their lower body. The scenario tint covers all three art layers. Background art must leave live objects and labels readable.

## Five animation types

Every entry needs a unique `id`, `type` and `texture`. All timing uses the existing room clock, including its drunk time scale. No entry retains a separate simulation or depends on pointer input.

| Type | Required fields beyond id/type/texture | Texture and behavior |
| --- | --- | --- |
| `frames` | `frames`, `fps`, `rect` | Horizontal strip; each frame is exactly twice the rect width and height. Integer frame count > 0 and fps > 0. `loop` defaults to `loop`; `pingpong` visits endpoints once per turn; `once_hold` holds the last frame. |
| `pulse` | `rect`, `min_opacity`, `max_opacity`, `period` | PNG exactly twice rect size. Sine opacity between the two limits, multiplied by common opacity; positive period in seconds. |
| `mover` | `size`, `from`, `to`, `duration` | PNG exactly twice size; optional horizontal `frames`/`fps` strip. Linear pass in positive duration seconds; optional nonnegative `gap` hides it between passes. Optional `clip` clips the sprite and its source pixels to that rectangle. |
| `scroll` | `rect`, `speed` | PNG exactly twice the **full rectangle**, including for scan lines. Scroll wraps within the rect in board units per second; negative or zero speeds are allowed. A small tile such as 16 × 68 for a 900 × 34 rect fails validation; deliver 1800 × 68. |
| `sweep` | `origin`, `from`, `to`, `period` | PNG stretches from origin to the endpoint, which eases from `from` to `to` and back over one positive period. Its authored height / 2 is beam thickness in board units; its width stretches along the beam. |

Common optional fields:

| Field | Default and meaning |
| --- | --- |
| `blend` | `mix`; `add` adds the texture light. Manifest order is preserved even when blend modes alternate. |
| `opacity` | 1; finite value from 0 to 1. |
| `phase` | 0 seconds; added to the shared clock to offset an entry. |
| `web_low_detail` | true; false skips this entry when the existing Web low-detail switch is active. |
| `still` | `first`; `hide` suppresses it with Reduce Motion, or a valid zero-based frame number selects a strip frame. |

With Reduce Motion, entries have a stable pose: strips select `still`, movers sit at `from`, pulse/scroll/sweep use their phase at a zero clock. A hidden still entry stays hidden. This does not disable processing or the room's normal redraw scheduling. While a placement overlay is open, animated rooms continue advancing without input.

For a four-frame 64 × 10 strip deliver 512 × 20 pixels. For the Gas 900 × 24 pulse deliver 1800 × 48. The active starter proof manifest is a worked example; its full-width generated scan line replaces the supplied undersized tile without editing that original PNG. These are placeholders, not final art.

## Counter fronts

Use the exact foreground id in the table, never a replacement placement coordinate. A base rectangle is `[x0, top_y, x1-x0, front_y-top_y]`. Optional `"bleed": [left, top, right, bottom]` contains nonnegative board units. Its destination becomes `[x-left, y-top, width+left+right, height+top+bottom]`; PNG dimensions must be twice that expanded width and height.

```json
"counters": {
  "gas_station_staff_window": {
    "texture": "counters/gas_station_staff_window.png",
    "bleed": [0, 0, 0, 0]
  }
}
```

These rectangles come from the existing placement surface maps. The table documents them; changing the table or PNG must never move a contact surface.

| Room art identity | Counter foreground id | Base rect (board units) | PNG without bleed |
| --- | --- | --- | --- |
| `corner_store` | `corner_store_register` | `338, 206, 286.0, 48` | `572.0 × 96` |
| `back_alley` | `back_alley_crate_display` | `638, 168, 208, 50` | `416 × 100` |
| `motel` | `motel_lobby_table` | `370, 176, 260, 52` | `520 × 104` |
| `motel` | `motel_merchandise_counter` | `700, 246, 170, 40` | `340 × 80` |
| `bar` | `bar_main_counter` | `38, 178, 548, 56` | `1096 × 112` |
| `gas_station_casino` | `gas_station_staff_window` | `532, 80, 104, 8` | `208 × 16` |
| `punchline_club` | none | — | — |
| `small_underground_casino` | `punchline_right_table` | `438, 142, 286, 98` | `572 × 196` |
| `punchline_back_room` | none | — | — |
| `jazz_club` | `jazz_bar` | `590, 188, 284, 48` | `568 × 96` |
| `kitty_cat_lounge` | `kitty_champagne_bar` | `584, 190, 268, 48` | `536 × 96` |
| `delta_queen` | `delta_right_table` | `330, 170, 270, 92` | `540 × 184` |
| `beach` | `beach_towel_stall` | `76, 198, 170, 36` | `340 × 72` |
| `pawn_shop` | `pawn_counter` | `316, 262, 268, 42` | `536 × 84` |
| `pawn_shop` | `pawn_estate_shelf` | `600, 184, 246, 28` | `492 × 56` |
| `grand_casino` | `grand_table_left` | `82, 258, 272, 36` | `544 × 72` |
| `grand_casino` | `grand_table_right` | `546, 258, 272, 36` | `544 × 72` |
| `grand_casino` | `grand_host_station` | `344, 318, 212, 48` | `424 × 96` |
| `grand_casino_high_limit` | `grand_table_left` | `82, 258, 272, 36` | `544 × 72` |
| `grand_casino_high_limit` | `grand_table_right` | `546, 258, 272, 36` | `544 × 72` |
| `grand_casino_back_room` | `grand_table_left` | `82, 258, 272, 36` | `544 × 72` |
| `grand_casino_back_room` | `grand_table_right` | `546, 258, 272, 36` | `544 × 72` |
| `grand_casino_cage` | `grand_cage_teller_counter` | `260, 260, 388, 56` | `776 × 112` |
| `motel_room` | none | — | — |
| `apartment` | none | — | — |
| `house` | none | — | — |

Punchline's three art identities share one venue archetype but use their own layer art keys. The four Grand Casino rooms also keep separate packs. Use these identities verbatim so travel, layer changes and Continue select the correct art.

## Check and preview

From the repository root:

```text
python -B tools/check_environment_art_pack.py
python -B tools/check_environment_art_pack.py gas_station_casino
python -B tools/check_environment_art_pack.py --all
```

The first checks enabled rooms, the second checks one room, and `--all` also checks disabled manifests. Errors include room, field and expected dimensions. Fix authored inputs before enabling a room. If a delivered pack fails, remove only its id from the enabled list and report the finding with a capture; do not recolor, crop, redraw or otherwise repair delivered art yourself.

Open Settings → Environment Library in the existing developer UI. Choose room, Base / No Scenario and a fixed seed, then Spawn. Layered venues expose their normal layer selection. Use exact scenario selections to review the scenario wash; also check a person behind each counter, placement overlays, Reduce Motion, normal camera framing, larger window sizes and Web. Busy art behind a live label is an art finding; do not move the object or label.

In a native Godot editor development build, **F6 reloads the current practice room** from disk. Save PNG or JSON, focus the game and press F6. Raw PNG reading bypasses stale imported textures, including a newly named PNG. Invalid edits show the original live room drawing and log the validation reason; correct the file and press F6 again. F6 preserves the room snapshot, animation clock and placement state. It is unavailable in normal runs, while the library selection overlay is open, and in packaged or Web builds. Existing F5 seed refresh and F9 random room/scenario controls retain their behavior.

Do not disable canvas processing, remove autonomous redraws, tie redraws to input or pause animation behind a placement overlay. Validate all 20 rooms against baseline captures before rollout. Keep raw QA outside the repository under the approved E: storage policy. The final folder must also contain the 12 travel doorway replacements at their existing paths and sizes (1024 × 1536; pawn_shop 1086 × 1448), for the later doorway phase. Final-room rollout and doorway acceptance wait for that delivery; old source retirement requires separate owner approval.
