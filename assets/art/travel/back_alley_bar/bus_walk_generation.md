# Bus generation and retired traveler history

Generated on 2026-11-11 with the built-in image generation tool. These files are the exact returned PNG byte streams. No resizing, cropping, alpha cleanup, recoloring, or image conversion was applied. Existing street_strip.png and foreground_strip.png were used as context and left unchanged.

## Current status

The bus remains in use. The generated traveler below is historical provenance
only: player_walk_strip.png is removed and no longer referenced by the runtime.
Travel now uses CharacterAvatarView and the existing shared character painter.
No new bitmap character was generated for this revision. Bus wheels are animated
as textured layers at runtime using the separate JSON composition contract.

## Files and measured composition (original generation)

- bus_arrival.png: 1774 x 887, RGBA, 842538 bytes. SHA-256 cae4a4ae10254083d5f3dc818da0f5203e32cd58221e9223ea4780aec6d6bb4a.
- player_walk_strip.png: 1774 x 887, RGBA, 607361 bytes. SHA-256 f5dfe495418f536d4fed79345e34aafe844dc1536f3583dd09668d22729b5c73.
- Both were requested at a 2:1 ratio; the tool selected the actual dimensions above, not the ideal pixel dimensions stated in the prompts.
- Both contain very faint generated alpha residue. Alpha was preserved exactly. Use explicit draw regions rather than deriving scale from raw alpha getbbox.
- Bounds below use [left, top, right-exclusive, bottom-exclusive].

### Bus

- Raw nonzero-alpha bounds: [0, 19, 1774, 853].
- Visible alpha >= 128 bounds: [13, 216, 1762, 733], equivalent to Rect2(13, 216, 1749, 517).
- Visible wheel contact is at inclusive y=732, with lower/exclusive baseline y=733. Wheel centers are approximately x=347 and x=1347.
- Door inner dark rectangle is approximately [1487, 324, 1627, 638]; full doorway/step continues to about y=660. These are visually inspected composition anchors, not alpha segmentation results.
- Door horizontal center x=1557; tight-bus fraction (1557-13)/1749 = 0.88279. Door step relative to tight top is approximately y=444.
- Right-facing flat side elevation, no passengers or text, dark closed door suitable for a warm open-door overlay.

### Traveler strip

- Raw nonzero-alpha bounds: [0, 21, 1758, 887].
- Equal mathematical cell width is 443.5. Use integer boundaries [0, 444, 887, 1330, 1774] for widths [444, 443, 443, 444], or equivalent floating regions. The clear gaps make the one-pixel width differences harmless.
- Cell-local visible alpha >= 128 bboxes, in frame order: [71,114,389,784], [121,115,321,782], [60,115,390,784], [140,114,341,783].
- Union of visible bboxes in cell-local coordinates: [60,114,390,784], equivalent to Rect2(60,114,330,670). This is a common non-destructive crop for all poses.
- Inclusive source foot baselines: [783,781,783,782]. Optional vertical offsets [0,2,0,1] align feet to y=783. No offset has been applied to PNG bytes.
- All four poses show the same anonymous traveler facing right, viewed from behind at three-quarter angle. Two targeted edits fixed duplicate half-cycle poses and then lowered high knees into a relaxed walk.

## Source context

Inspected assets/art/travel/back_alley_bar/street_strip.png, assets/art/environments/back_alley.png, and assets/art/ui/travel_bus.png. New sprites match the dark purple/cyan/magenta chunky pixel aesthetic. No reference image bytes were edited into the bus. The traveler edits referenced only its immediately preceding generated strip.

## Exact bus prompt

Use case: stylized-concept. Asset type: replaceable transparent 2D game sprite for Beat the House bus arrival animation. Create ONE unbranded city bus in absolutely strict SIDE ELEVATION facing RIGHT. The front is at the right edge, the rear is at the left. Wide 2:1 transparent canvas, ideally 1536x768. Bus occupies most horizontal canvas with generous small alpha padding, centered vertically. Wheels are on exactly the same horizontal baseline. Flat orthographic side view, no visible front face, no visible top plane, no perspective foreshortening. Body is a simple long dark navy and deep purple block with chunky hard-edged pixel shapes; cyan rim accents and subtle magenta trim, dark rubber tires, a row of muted warm amber windows. Front passenger doorway is near RIGHT-FRONT, immediately behind the front axle or at front corner; show a clearly defined tall dark CLOSED flat doorway so the game can overlay a warm open rectangle. Keep door simple and rectangular. Style match the inspected purple brick street and old venue art: crisp retro chunky neon pixel art, restrained colors, large clean shapes, NOT detailed illustration or photorealistic. No passenger silhouettes. No lettering, route numbers, symbols, brand, logos, signs, caption or watermark. No scenery, road, ground, ground shadow, cast shadow, reflection, smoke or glow spilling outside the bus silhouette. Actual transparent alpha everywhere outside this single bus; no white or checkerboard painted background. The only subject is the full bus, nothing cut off.

## Exact initial traveler prompt

Use case: stylized-concept. Asset type: transparent 4-frame walking-cycle spritesheet for a small 2D game traveler. Canvas is landscape 2:1 ideally 2048x1024. It contains EXACTLY FOUR full-body character sprites in a single horizontal row, at centers of four equal-width invisible cells: x=12.5%,37.5%,62.5%,87.5% of canvas. Each sprite is the SAME anonymous adult traveler in the SAME rear three-quarter angle, consistently oriented and moving to the RIGHT. The head is turned away from viewer toward right, face completely featureless/unseen. No portrait detail, no hats, bags or props. Dark navy/purple neutral jacket and dark trousers, simple shoes, small cyan rim edge highlight. All four figures same proportions, same scale, same costume, same direction and same common foot baseline at about y=88% with head near y=15%. Narrow silhouette centered in each own cell with clean transparent separation; whole head, hands and feet fully inside its cell. Four DIFFERENT consecutive normal WALK animation poses: frame 1 right-foot forward/left-foot back contact with counter-swing arms; frame 2 feet passing under body, one heel lifting; frame 3 opposite left-foot forward/right-foot back contact with opposing arm swing; frame 4 opposite passing pose. Make gait readable and natural. This is a walking animation cycle of one character, NOT different people, NOT turnaround angles, NOT scene variants. Style: very simple crisp chunky retro neon pixel art, large hard-edged blocks, sparse flat shaded color clusters, deep purple with restrained cyan edge compatible with purple brick street. Entire image outside four silhouettes must be actual TRANSPARENT ALPHA. NO background, no ground, no ground shadow, no reflection, no labels, no text, no numbers, no borders, no panel lines or grid, no watermark. No extra duplicates. Prioritize four equally sized and aligned usable walk frames.

## Exact traveler pose correction prompt

Edit the immediately preceding transparent four-frame walking spritesheet. Keep the same canvas dimensions, transparency, character identity, dark purple jacket/trousers, anonymous rear three-quarter facing RIGHT, crisp chunky pixel style, four equal-width cells, scale, cell centers and baseline. Change ONLY poses in cells 3 and 4 (right half). Currently they repeat cells 1 and 2. They must instead show the OPPOSITE half of the gait with reversed arm and leg swing. Cell 3: the visible foreground/near arm hangs diagonally BACK to the LEFT of the torso, with its hand behind the hips at the LEFT; the far arm reaches FORWARD to the RIGHT, partially occluded by the torso. Reverse which leg is foreground and use noticeably different angular knee shapes so it is not a duplicate of frame 1. Cell 4: opposite passing pose from cell 2, foreground leg planted straight under hip while far leg's knee advances forward to the RIGHT, far heel lifted; foreground hand behind the thigh on LEFT, far hand forward on RIGHT. Maintain four distinct natural consecutive walk poses. Never mirror the character or change facing direction. Keep cells 1 and 2 untouched. No background, no ground, no shadows, no cell lines, no text. Actual transparent alpha outside figures.

## Exact final traveler gait correction prompt

Edit this existing transparent four-frame walking spritesheet with ONLY one correction: make the leg poses of cells 3 and 4 a relaxed normal walk rather than a high-knee march. Preserve EVERYTHING else, including all arm poses, exact rear three-quarter facing-right character, all head and body placement, scale, pixel-art style, cell centers, existing alpha background, and cells 1 and 2. In cell 3 put the leading/rightward shoe DOWN ON THE SAME ground baseline as the other planted shoe (about y=782), with the leading leg mostly extended naturally, not a raised bent knee. This is a two-foot contact pose, opposite half of gait to cell 1. In cell 4 lower the advancing knee substantially, with the lifted shoe passing just beside the planted ankle, only slightly above the baseline; no thigh lifted high, no marching. Keep all four distinct and fully contained in the same four equal cells. Actual transparent alpha everywhere outside characters. No ground, no shadows, no grid, no text, no extra objects.
