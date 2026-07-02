# Slot Cabinet Backgrounds and UI Reposition Plan

Scope: this is an art and layout proposal only. No `.gd` or `.json` files were edited. All rectangles are in the slot renderer's 960x540 design space and use `{x, y, w, h}`.

## Artwork Deliverables

New 960x540 PNG backgrounds:

- `res://assets/art/slots/pinball_classic_3_reel_em_bumper_drop.png`
- `res://assets/art/slots/pinball_line_5x3_lane_multiball.png`
- `res://assets/art/slots/pinball_video_feature_full_table.png`
- `res://assets/art/slots/buffalo_classic_3_reel_heritage.png`
- `res://assets/art/slots/buffalo_line_5x3_ways.png`
- `res://assets/art/slots/buffalo_video_feature_link_arena.png`

Suggested future `data/art/art_manifest.json` `game_surfaces` entries:

```json
{
  "slot_pinball_classic_3_reel": {
    "path": "res://assets/art/slots/pinball_classic_3_reel_em_bumper_drop.png",
    "brief": "1960s electromechanical pinball-slot cabinet, wood, brass, glass, centered three-reel bay"
  },
  "slot_pinball_line_5x3": {
    "path": "res://assets/art/slots/pinball_line_5x3_lane_multiball.png",
    "brief": "1980s solid-state pinball-slot cabinet, painted metal, DMD lamps, wide five-column reel bay"
  },
  "slot_pinball_video_feature": {
    "path": "res://assets/art/slots/pinball_video_feature_full_table.png",
    "brief": "modern black-chrome LCD pinball-slot cabinet, RGB trim, large reel LCD and right feature screen"
  },
  "slot_buffalo_classic_3_reel": {
    "path": "res://assets/art/slots/buffalo_classic_3_reel_heritage.png",
    "brief": "mechanical western slot cabinet, dark wood, brass, saloon glass, compact three-reel bay"
  },
  "slot_buffalo_line_5x3": {
    "path": "res://assets/art/slots/buffalo_line_5x3_ways.png",
    "brief": "sunset ways slot cabinet, copper and sunset glass, wide five-column reel bay"
  },
  "slot_buffalo_video_feature": {
    "path": "res://assets/art/slots/buffalo_video_feature_link_arena.png",
    "brief": "flagship bronze LED video-link cabinet, arena ring feature screen, large video reel bay"
  }
}
```

Do not flip `use_external_game_surfaces` as part of this art drop. An engineer should hook these paths into the game surface lookup and decide whether the key should be format-specific, machine-id-specific, or both.

## Variation Plans

### 1. Pinball / classic_3_reel: EM Bumper Drop

Asset: `res://assets/art/slots/pinball_classic_3_reel_em_bumper_drop.png`

Art direction: 1960s electromechanical wood, brass, and glass. The art uses a centered chrome three-reel bay, analog side meter panels, a brass marquee, and a shallow pinball apron under the reels.

| Slot | Current | Proposed | Change and reason | Alignment notes |
| --- | --- | --- | --- | --- |
| `topper_rect` | `{x:92, y:22, w:776, h:72}` | `{x:100, y:20, w:760, h:78}` | Inset and slightly taller so title copy sits inside the brass marquee glass, away from side bulbs. | Centered on cabinet and reel bay. |
| `reel_window` | `{x:270, y:104, w:420, h:106}` | `{x:274, y:112, w:412, h:112}` | Lower, a touch narrower, and taller to fit the chrome three-window bezel. | Center x remains 480. |
| `tease_panel` | `{x:72, y:116, w:160, h:220}` | `{x:68, y:112, w:176, h:224}` | Wider and slightly higher to use the left analog meter glass. | Hugs the left wooden column. |
| `feature_panel` | `{x:708, y:112, w:176, h:224}` | `{x:716, y:112, w:168, h:224}` | Shifted right and narrowed to preserve the brass gutter beside the reels. | Mirrors the left panel visually. |
| `playfield_rect` | `{x:272, y:226, w:416, h:120}` | `{x:258, y:236, w:444, h:112}` | Wider, lower, and shorter so the pinball mini-playfield reads as an apron below the reels. | Centered under `reel_window`. |
| `belly_rect` | `{x:92, y:350, w:776, h:72}` | `{x:94, y:354, w:772, h:68}` | Slightly lower and shorter to clear the brass shelf above it. | Centered in the lower belly glass. |
| `result_strip` | `{x:116, y:370, w:728, h:40}` | `{x:128, y:372, w:704, h:38}` | Inset for a darker, more readable message strip inside the belly glass. | Centered inside `belly_rect`. |
| `controls` | `{x:110, y:432, w:740, h:72}` | `{x:118, y:436, w:724, h:66}` | Lower and inset to sit on the black control apron without touching the wood feet. | Centered under result strip. |

Engineering note: the pinball takeover should remain the current full `{x:0, y:0, w:960, h:540}`. This background does not need to solve takeover composition because the takeover draw path covers the full design space.

### 2. Pinball / line_5x3: Lane Multiball

Asset: `res://assets/art/slots/pinball_line_5x3_lane_multiball.png`

Art direction: 1980s solid-state painted metal with a dot-matrix topper, cyan/orange trim, lamp matrices, and a wider five-column reel bay.

| Slot | Current | Proposed | Change and reason | Alignment notes |
| --- | --- | --- | --- | --- |
| `topper_rect` | `{x:62, y:18, w:836, h:58}` | `{x:56, y:16, w:848, h:64}` | Wider and taller to become a proper DMD marquee band. | Spans the painted-metal shoulders. |
| `reel_window` | `{x:246, y:92, w:468, h:208}` | `{x:236, y:94, w:488, h:204}` | Wider and slightly shorter for the large five-column glass. | Centered between side lamp panels. |
| `tease_panel` | `{x:54, y:92, w:168, h:260}` | `{x:56, y:94, w:158, h:258}` | Inset and narrowed to fit the left insert-lamp matrix. | Top aligns with reel bay. |
| `feature_panel` | `{x:738, y:92, w:160, h:260}` | `{x:746, y:94, w:158, h:258}` | Shifted right and narrowed to match the right insert-lamp matrix. | Top aligns with reel bay. |
| `playfield_rect` | `{x:248, y:310, w:466, h:78}` | `{x:238, y:312, w:484, h:74}` | Wider and shorter so the pinball lane strip locks to the reel width. | Same center and width family as `reel_window`. |
| `belly_rect` | `{x:54, y:356, w:844, h:68}` | `{x:60, y:356, w:840, h:66}` | Slightly inset under the painted metal flange. | Runs almost full cabinet width. |
| `result_strip` | `{x:72, y:374, w:808, h:40}` | `{x:80, y:374, w:800, h:38}` | Inset and shorter for a clean dark readout zone. | Centered inside belly glass. |
| `controls` | `{x:54, y:432, w:844, h:76}` | `{x:64, y:434, w:832, h:72}` | Inset from the sloped apron edges. | Full-width operational rail. |

Engineering note: the art implies the cabinet has a slight painted slant, but the live UI should remain rectangular. A future trapezoid/skew option would be visual polish only.

### 3. Pinball / video_feature: Full Table

Asset: `res://assets/art/slots/pinball_video_feature_full_table.png`

Art direction: modern black-chrome LCD cabinet with magenta/cyan RGB rails, a large left reel LCD, a narrow telemetry spine, and a right vertical feature screen.

| Slot | Current | Proposed | Change and reason | Alignment notes |
| --- | --- | --- | --- | --- |
| `topper_rect` | `{x:42, y:14, w:876, h:52}` | `{x:36, y:12, w:888, h:56}` | Wider and taller to read as a full LCD header. | Aligned to the outer chrome frame. |
| `reel_window` | `{x:62, y:78, w:508, h:290}` | `{x:60, y:82, w:520, h:284}` | Wider, lower, and slightly shorter to sit in the primary screen bezel. | Left screen is the hero surface. |
| `tease_panel` | `{x:592, y:78, w:128, h:290}` | `{x:598, y:84, w:118, h:282}` | Narrowed and lowered to become a central telemetry spine. | Vertically matches the reel screen interior. |
| `feature_panel` | `{x:732, y:72, w:170, h:312}` | `{x:736, y:78, w:176, h:306}` | Slightly wider and lower to fit the right LCD bezel. | Right edge hugs the chrome upright. |
| `playfield_rect` | `{x:732, y:88, w:170, h:292}` | `{x:736, y:92, w:176, h:286}` | Nested inside the right feature screen with top/bottom padding. | Same x and width as `feature_panel`. |
| `belly_rect` | `{x:42, y:376, w:876, h:50}` | `{x:42, y:376, w:876, h:50}` | Unchanged; the existing shallow strip matches the glass shelf. | Full-width lower LCD shelf. |
| `result_strip` | `{x:56, y:382, w:848, h:38}` | `{x:64, y:384, w:832, h:36}` | Tighter inset for better contrast inside the shelf. | Centered in `belly_rect`. |
| `controls` | `{x:42, y:432, w:876, h:78}` | `{x:48, y:434, w:864, h:74}` | Inset to avoid the chrome legs and RGB foot rail. | Full-width lower control glass. |

Engineering note: the art includes curved/glossy RGB edge treatment that the current rectangular layout cannot express. The proposed rects keep the actual interaction surface simple.

### 4. Buffalo / classic_3_reel: Heritage

Asset: `res://assets/art/slots/buffalo_classic_3_reel_heritage.png`

Art direction: mechanical western cabinet in dark wood and brass, with carved side posts, saloon-style marquee glass, compact three-reel brass bay, and a buffalo plaque.

| Slot | Current | Proposed | Change and reason | Alignment notes |
| --- | --- | --- | --- | --- |
| `topper_rect` | `{x:112, y:22, w:736, h:66}` | `{x:118, y:20, w:724, h:70}` | Inset and taller so the topper sits inside the saloon mirror frame. | Centered between carved posts. |
| `reel_window` | `{x:300, y:104, w:360, h:108}` | `{x:296, y:110, w:368, h:112}` | Wider, lower, and taller for the brass three-window reel bay. | Centered on cabinet. |
| `tease_panel` | `{x:78, y:112, w:174, h:232}` | `{x:78, y:112, w:178, h:230}` | Slightly wider and shorter to fill the left carved glass panel. | Hugs left post. |
| `feature_panel` | `{x:708, y:112, w:174, h:232}` | `{x:704, y:112, w:178, h:230}` | Slightly wider and shifted left for symmetrical right panel spacing. | Mirrors `tease_panel`. |
| `playfield_rect` | `{x:286, y:228, w:388, h:108}` | `{x:280, y:230, w:400, h:106}` | Wider and lower to frame the buffalo plaque under the reels. | Centered under reel bay. |
| `belly_rect` | `{x:92, y:346, w:776, h:80}` | `{x:92, y:346, w:776, h:80}` | Unchanged; the existing belly size fits the broad brass lower glass. | Full lower glass panel. |
| `result_strip` | `{x:116, y:370, w:728, h:42}` | `{x:122, y:372, w:716, h:40}` | Inset and slightly lower for a clean black readout inside brass trim. | Centered in `belly_rect`. |
| `controls` | `{x:104, y:432, w:752, h:72}` | `{x:112, y:434, w:736, h:68}` | Inset and lower to sit on the wooden apron. | Centered under belly. |

Engineering note: the carved topper has an arched visual line, but live title text should stay in the rectangular topper safe zone.

### 5. Buffalo / line_5x3: Ways

Asset: `res://assets/art/slots/buffalo_line_5x3_ways.png`

Art direction: copper and sunset glass cabinet, wide ways reel display, warm side glass, and a narrow stampede meter under the reels.

| Slot | Current | Proposed | Change and reason | Alignment notes |
| --- | --- | --- | --- | --- |
| `topper_rect` | `{x:54, y:18, w:852, h:64}` | `{x:50, y:16, w:860, h:68}` | Larger sunset marquee, with enough vertical room for title and feature text. | Nearly full-width between copper uprights. |
| `reel_window` | `{x:216, y:92, w:528, h:244}` | `{x:208, y:96, w:544, h:238}` | Wider, lower, and slightly shorter to emphasize the ways grid. | Centered between narrow side panels. |
| `tease_panel` | `{x:54, y:94, w:140, h:250}` | `{x:58, y:98, w:132, h:244}` | Narrowed and inset to sit in the left copper side glass. | Top tracks the reel bay. |
| `feature_panel` | `{x:764, y:94, w:140, h:250}` | `{x:770, y:98, w:132, h:244}` | Narrowed and shifted right for the matching side glass. | Top tracks the reel bay. |
| `playfield_rect` | `{x:214, y:346, w:530, h:42}` | `{x:208, y:344, w:544, h:44}` | Aligned to reel width and made a touch taller for the stampede meter. | Same x and width as `reel_window`. |
| `belly_rect` | `{x:54, y:356, w:852, h:68}` | `{x:56, y:356, w:848, h:68}` | Tiny inset to clear copper side rails. | Full lower glass. |
| `result_strip` | `{x:72, y:374, w:816, h:40}` | `{x:78, y:374, w:804, h:40}` | Inset for contrast and side rail clearance. | Centered in belly glass. |
| `controls` | `{x:54, y:432, w:852, h:76}` | `{x:62, y:434, w:836, h:72}` | Inset and lower to avoid the glowing foot rail. | Wide control apron. |

Engineering note: the painted cabinet has a slight left lean, but the UI should stay axis-aligned. The current `lean` field is enough for cabinet art direction, not for UI geometry.

### 6. Buffalo / video_feature: Link Arena

Asset: `res://assets/art/slots/buffalo_video_feature_link_arena.png`

Art direction: bronze LED flagship video-link cabinet with arena arches, a large main video reel display, a telemetry spine, and a right ring feature screen.

| Slot | Current | Proposed | Change and reason | Alignment notes |
| --- | --- | --- | --- | --- |
| `topper_rect` | `{x:38, y:12, w:884, h:56}` | `{x:34, y:10, w:892, h:58}` | Wider and taller to become an LED ribbon header. | Aligned to outer bronze frame. |
| `reel_window` | `{x:54, y:78, w:530, h:290}` | `{x:52, y:82, w:540, h:284}` | Wider, lower, and slightly shorter to fill the main video glass. | Main hero screen. |
| `tease_panel` | `{x:604, y:78, w:126, h:290}` | `{x:608, y:84, w:120, h:282}` | Narrowed and lowered to become a telemetry spine between screens. | Top aligns to reel interior. |
| `feature_panel` | `{x:744, y:72, w:170, h:312}` | `{x:744, y:78, w:178, h:306}` | Wider and lower to match the right arena screen bezel. | Hugs right bronze upright. |
| `playfield_rect` | `{x:744, y:88, w:170, h:292}` | `{x:744, y:92, w:178, h:286}` | Nested inside the right screen with padding for the ring art. | Same x and width as `feature_panel`. |
| `belly_rect` | `{x:42, y:376, w:876, h:50}` | `{x:42, y:376, w:876, h:50}` | Unchanged; the existing shallow belly matches the video shelf. | Full-width shelf. |
| `result_strip` | `{x:56, y:382, w:848, h:38}` | `{x:64, y:384, w:832, h:36}` | Tighter and slightly lower for readable contrast. | Centered in shelf. |
| `controls` | `{x:42, y:432, w:876, h:78}` | `{x:48, y:434, w:864, h:74}` | Inset from the bronze legs and LED foot rail. | Full-width lower control glass. |

Engineering note: the arena feature art is circular, but the live feature surface should remain rectangular until the renderer supports clipping/masking non-rectangular feature screens.

## Before/After Summary

### EM Bumper Drop

| Slot | Before | After |
| --- | --- | --- |
| `topper_rect` | `{x:92, y:22, w:776, h:72}` | `{x:100, y:20, w:760, h:78}` |
| `reel_window` | `{x:270, y:104, w:420, h:106}` | `{x:274, y:112, w:412, h:112}` |
| `tease_panel` | `{x:72, y:116, w:160, h:220}` | `{x:68, y:112, w:176, h:224}` |
| `feature_panel` | `{x:708, y:112, w:176, h:224}` | `{x:716, y:112, w:168, h:224}` |
| `playfield_rect` | `{x:272, y:226, w:416, h:120}` | `{x:258, y:236, w:444, h:112}` |
| `belly_rect` | `{x:92, y:350, w:776, h:72}` | `{x:94, y:354, w:772, h:68}` |
| `result_strip` | `{x:116, y:370, w:728, h:40}` | `{x:128, y:372, w:704, h:38}` |
| `controls` | `{x:110, y:432, w:740, h:72}` | `{x:118, y:436, w:724, h:66}` |

### Lane Multiball

| Slot | Before | After |
| --- | --- | --- |
| `topper_rect` | `{x:62, y:18, w:836, h:58}` | `{x:56, y:16, w:848, h:64}` |
| `reel_window` | `{x:246, y:92, w:468, h:208}` | `{x:236, y:94, w:488, h:204}` |
| `tease_panel` | `{x:54, y:92, w:168, h:260}` | `{x:56, y:94, w:158, h:258}` |
| `feature_panel` | `{x:738, y:92, w:160, h:260}` | `{x:746, y:94, w:158, h:258}` |
| `playfield_rect` | `{x:248, y:310, w:466, h:78}` | `{x:238, y:312, w:484, h:74}` |
| `belly_rect` | `{x:54, y:356, w:844, h:68}` | `{x:60, y:356, w:840, h:66}` |
| `result_strip` | `{x:72, y:374, w:808, h:40}` | `{x:80, y:374, w:800, h:38}` |
| `controls` | `{x:54, y:432, w:844, h:76}` | `{x:64, y:434, w:832, h:72}` |

### Full Table

| Slot | Before | After |
| --- | --- | --- |
| `topper_rect` | `{x:42, y:14, w:876, h:52}` | `{x:36, y:12, w:888, h:56}` |
| `reel_window` | `{x:62, y:78, w:508, h:290}` | `{x:60, y:82, w:520, h:284}` |
| `tease_panel` | `{x:592, y:78, w:128, h:290}` | `{x:598, y:84, w:118, h:282}` |
| `feature_panel` | `{x:732, y:72, w:170, h:312}` | `{x:736, y:78, w:176, h:306}` |
| `playfield_rect` | `{x:732, y:88, w:170, h:292}` | `{x:736, y:92, w:176, h:286}` |
| `belly_rect` | `{x:42, y:376, w:876, h:50}` | `{x:42, y:376, w:876, h:50}` |
| `result_strip` | `{x:56, y:382, w:848, h:38}` | `{x:64, y:384, w:832, h:36}` |
| `controls` | `{x:42, y:432, w:876, h:78}` | `{x:48, y:434, w:864, h:74}` |

### Heritage

| Slot | Before | After |
| --- | --- | --- |
| `topper_rect` | `{x:112, y:22, w:736, h:66}` | `{x:118, y:20, w:724, h:70}` |
| `reel_window` | `{x:300, y:104, w:360, h:108}` | `{x:296, y:110, w:368, h:112}` |
| `tease_panel` | `{x:78, y:112, w:174, h:232}` | `{x:78, y:112, w:178, h:230}` |
| `feature_panel` | `{x:708, y:112, w:174, h:232}` | `{x:704, y:112, w:178, h:230}` |
| `playfield_rect` | `{x:286, y:228, w:388, h:108}` | `{x:280, y:230, w:400, h:106}` |
| `belly_rect` | `{x:92, y:346, w:776, h:80}` | `{x:92, y:346, w:776, h:80}` |
| `result_strip` | `{x:116, y:370, w:728, h:42}` | `{x:122, y:372, w:716, h:40}` |
| `controls` | `{x:104, y:432, w:752, h:72}` | `{x:112, y:434, w:736, h:68}` |

### Ways

| Slot | Before | After |
| --- | --- | --- |
| `topper_rect` | `{x:54, y:18, w:852, h:64}` | `{x:50, y:16, w:860, h:68}` |
| `reel_window` | `{x:216, y:92, w:528, h:244}` | `{x:208, y:96, w:544, h:238}` |
| `tease_panel` | `{x:54, y:94, w:140, h:250}` | `{x:58, y:98, w:132, h:244}` |
| `feature_panel` | `{x:764, y:94, w:140, h:250}` | `{x:770, y:98, w:132, h:244}` |
| `playfield_rect` | `{x:214, y:346, w:530, h:42}` | `{x:208, y:344, w:544, h:44}` |
| `belly_rect` | `{x:54, y:356, w:852, h:68}` | `{x:56, y:356, w:848, h:68}` |
| `result_strip` | `{x:72, y:374, w:816, h:40}` | `{x:78, y:374, w:804, h:40}` |
| `controls` | `{x:54, y:432, w:852, h:76}` | `{x:62, y:434, w:836, h:72}` |

### Link Arena

| Slot | Before | After |
| --- | --- | --- |
| `topper_rect` | `{x:38, y:12, w:884, h:56}` | `{x:34, y:10, w:892, h:58}` |
| `reel_window` | `{x:54, y:78, w:530, h:290}` | `{x:52, y:82, w:540, h:284}` |
| `tease_panel` | `{x:604, y:78, w:126, h:290}` | `{x:608, y:84, w:120, h:282}` |
| `feature_panel` | `{x:744, y:72, w:170, h:312}` | `{x:744, y:78, w:178, h:306}` |
| `playfield_rect` | `{x:744, y:88, w:170, h:292}` | `{x:744, y:92, w:178, h:286}` |
| `belly_rect` | `{x:42, y:376, w:876, h:50}` | `{x:42, y:376, w:876, h:50}` |
| `result_strip` | `{x:56, y:382, w:848, h:38}` | `{x:64, y:384, w:832, h:36}` |
| `controls` | `{x:42, y:432, w:876, h:78}` | `{x:48, y:434, w:864, h:74}` |
