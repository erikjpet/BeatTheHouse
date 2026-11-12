# Landmark and outdoor layered travel art

## Current assets

Updated 2026-11-12 using built-in image-generation edits of the existing admired destination art. Each destination has an integrated main venue/access-ground image with real transparent background, plus a separate opaque distant setting. Files are exact returned PNG bytes. No raster resizing, cropping, recoloring, compositing or alpha modification was applied after generation.

Main layers are native 1774 x 887 RGBA. Backdrops are RGB, 1774 x 887 except Back Alley at 1774 x 886. That one-pixel native difference is recorded in backdrop_reference_size.

The image tool produced near-opaque solid main surfaces, predominantly alpha 252-254, rather than uniformly 255. Transparent background pixels are genuinely alpha 0. Runtime alpha snapping may be used without changing source files. Do not describe the source ground as fully 255-opaque.

## Files and geometry

### back_alley

- exteriors/back_alley.png: 1774 x 887 RGBA, 1465323 bytes; SHA-256 8a645dc31e708c9a6a255f79c665d04217ee62bc1d9bf44992604bafb0b9c65c.
- backdrops/back_alley.png: 1774 x 886 RGB, 2058312 bytes; SHA-256 e37d7b9bfc8d43015f8691d48a03095a2e493b1a285200bec319950b5bd40158.
- Threshold [1394, 720]; inside [1394, 650]; clear foreground begins near y=760; wheel baseline y=842.65 (UV 0.95). Roof/silhouette begins near y=328.
- Arrival path alpha range: 253-253. Clear ground alpha range: (252, 254).

#### Exact edit prompts

**main**

Use case: background-extraction. Edit target: attached original nighttime Back Alley pixel-art scene. Create MAIN foreground scene layer, transparent background, native1774x887. Keep the admired wet purple brick frontage, warm upper windows, fire escape, cyan/magenta neon, drainpipe, hanging amber bulb, empty folding table and OPEN dark right-side passage with visible receding cobbled floor. No door may close the alley.
Remove ALL distant city buildings, neighboring rooftop blocks, tanks and sky behind the main facade to true alpha0. Recompose the near facade only so its parapet silhouette lies near y .38-.43 and its base/sidewalk near y .76, preserving all identity detail in a shorter two-level facade. Passage mouth remains x .72-.85, from y .54 to .76, center x .785. Deep visible cobbled floor waypoint about [1394,605], threshold [1394,675], and unobstructed route between. Keep deep passage walls/floor opaque, not a see-through hole.
NATURALLY EXTEND the existing wet foreground street downward into the same continuous painted scene. Sidewalk and curb near y .76-.79; broad clear dark wet street occupies y .80 to1 with coherent perspective and subtle cyan/magenta/amber reflections from these lamps. No separate generic road strip, abrupt material swatch or added lane marks. No objects in full-width wheel corridor y .92-.98. Table, drains and stairs stay above sidewalk/curb. Solid building, street and passage pixels fully alpha255; only the distant city/sky regions behind its roof alpha0. No people, cars, text or new objects.

**backdrop**

Use case: precise-object-edit. Attached original Back Alley pixel-art scene is the edit target. Make ONLY its separate opaque far-neighborhood BACKDROP at1774x887. Keep the original admired navy/purple cloudy night sky, distant cyan/magenta/amber downtown towers, layered roof tanks and lit apartment block rooflines. Remove the entire foreground broad purple-brick wall, fire escape, lamp, table, neon passage, sidewalk and street. Inpaint the removed foreground area as a continuous plausible distant neighborhood, extending the smaller far buildings down behind where that foreground facade used to be. View is over nearby lower rooftops toward distant illuminated city; no large foreground replacement building, no duplicated alley, no passage, main venue, neon wall lamps, table or signs. The backdrop skyline should have distinct silhouette roofs and sky, with the most distant tower tops around y.2-.40 and neighboring rooftops around y.42-.58. Rest can be shadowy distant facades/roof terraces. Same crisp detailed pixel style, no people or cars. Fully opaque edge to edge, no alpha/checkerboard.

**reframe**

Edit this exact transparent Back Alley main foreground scene to make its NEAR BUILDING SHORTER and free the UPPER THIRD for transparent backdrop. Canvas1774x887 unchanged. The entire region y0-300 must be completely empty genuine alpha0. Move/redraw the highest brick parapets at y340, ordinary roofline at y385, upper windows compact at y420-490, the lit open passage from y510 to675. Keep facade full width and preserve wet purple bricks, four warm windows, fire escape, hanging bulb and folding table. Entrance center remains x1394, threshold y675, deep walkable cobbles aroundy595. Building base y675. Sidewalk y675-710. Existing continuous wet street should naturally fill y710-887 with clear full-width vehicle ground, no added road strip. This is a shorter building with compact upper level, NOT simply vertically shifting the large building out of frame. Preserve pixel-art detail, colors and identity. Keep all distant city and sky absent, alpha0; scene solids alpha255. Do not add objects, people or text.

### beach

- exteriors/beach.png: 1774 x 887 RGBA, 1325819 bytes; SHA-256 1be53b110e18cab26d30701939609bc5cda9f241b6b53e5b3623843afca3227e.
- backdrops/beach.png: 1774 x 887 RGB, 1710969 bytes; SHA-256 c66bb6137d1514957c2539c3ec12ac34825479ee4b1a14dca5014b0f04e50e9c.
- Threshold [1394, 725]; inside [1394, 630]; clear foreground begins near y=735; wheel baseline y=842.65 (UV 0.95). Roof/silhouette begins near y=420.
- Arrival path alpha range: 252-253. Clear ground alpha range: (251, 254).

The access spur leads from broad wooden boardwalk onto open sand. No asphalt or vehicle staging on the sand is painted into this image.

#### Exact edit prompts

**main**

Use case: background-extraction. Edit target: attached original beach nighttime pixel-art scene. Create its MAIN foreground layer for a two-layer side-scrolling game. Preserve its admired warm beach sand, cyan surf, little distant-left neon pier, wooden beach access, rope posts, dune grasses and lanterns in the same crisp detailed pixel style. Remove ALL distant coastal city, hills and sky, and far ocean ABOVE the near cyan surf to genuine alpha=0 transparency; no checkerboard or solid replacement color.
Recompose to native1774x887 2:1. Near surf horizon at y.48-.54 with beach sand spanning .54-.70. Keep a clear open sand access at x .78. The short wooden access spur reaches sand at x .78,y .67, and meets broad foreground wood at x .78,y .75. Preserve access opening without rope crossing it.
NATURALLY EXTEND the existing foreground BOARDWALK into one coherent broad continuous wooden travel surface across the FULL WIDTH from y.76 to bottom1, with unified plank perspective and warm lantern reflections. This boardwalk and beach are one painted scene. Keep all grasses, driftwood, lamps, rope posts and dunes above y.76; the whole lower quarter must be completely clear wood, no obstacles or separate pasted-on road strip, no asphalt. Full-width wheel corridor at y .94-.96. No people, cars, text, extra venue or backdrop buildings. The solid surf/sand/wood scene must be fully opaque alpha255, only the removed sky/city is transparent.

**backdrop**

Use case: precise-object-edit. Edit target: attached original beach pixel-art image. Extract its admired distant coastal nighttime setting as the separate OPAQUE backdrop, native1774x887. Preserve the navy/purple clouded sky and illuminated coastal city/hills with amber,cyan,magenta accents across the bay at original scale and horizon. REMOVE all near beach sand, surf foam, foreground boardwalk/access, rope posts, lamps, driftwood, grasses and the entire left neon pier. Fill those removed areas with continuous calm dark teal ocean from the distant city shoreline near y.54 to the bottom edge, with subtle coherent city reflections. No beach, dock, bridge, foreground lights or main objects remain. No duplicated pier or new skyline design. Same crisp detailed pixel-art style and rich palette. Opaque edge-to-edge, no alpha, no checkerboard, no text or people.

### delta_queen

- exteriors/delta_queen.png: 1774 x 887 RGBA, 1586008 bytes; SHA-256 4414fe5c94f850fb233c3f0e14cabed29291aac08b881823c12db4cdf4241767.
- backdrops/delta_queen.png: 1774 x 887 RGB, 2017956 bytes; SHA-256 3410e184aa99856708496a5b86c58220f06be600d86cdc0a64885f3b5aac1240.
- Threshold [1442, 724]; inside [1366, 592]; clear foreground begins near y=740; wheel baseline y=842.65 (UV 0.95). Roof/silhouette begins near y=338.
- Arrival path alpha range: 252-253. Clear ground alpha range: (250, 254).

The vessel occupies roughly x70-1640. A static crop covering the entire vessel needs source width about0.90; a0.78-width close crop keeps entrance/sign/gangway identity but cannot contain both ends simultaneously. Gangway threshold-to-inside line stays within its brass rails.

#### Exact edit prompts

**main**

Use case: background-extraction.
Edit target: the attached original DELTA QUEEN nighttime pixel-art casino riverboat image. Create the MAIN foreground layer of a two-layer side-scrolling game scene, not a new design. Keep the admired detailed pixel art, entire white/magenta riverboat silhouette, red paddlewheel, brass rails, warm windows, correctly spelled DELTA QUEEN gold sign, and right-side gangway. Remove ALL distant buildings, skyline, sky, distant river, cranes and waterfront behind it to genuine alpha transparency. Do not paint a black/white/checkerboard background.
Output wide 2:1, ideally 1774x887. Recompose the ship within x .10-.91, roof/stack silhouette starts y .40, hull bottom about y .67. Its main entrance remains x .75-.78,y .60-.67. Gangway runs freely from entrance down to its foot at x .80,y .76. Brass rails terminate at gangway edges, never block its center.
Paint a NATURALLY EXTENDED broad STONE QUAY as part of the SAME scene, from near y .76 continuously to bottom y1, with coherent stone perspective/texture and warm lamp reflections. This is the actual foreground driving/walking ground, not an appended swatch or separate generic road. Lower band y .79-1 is opaque unobstructed flat quay, wheel path at .95. Mooring ropes, bollards, lanterns and quay edge stay above y .77 and outside the gangway. No objects or seams crossing the wheel corridor. No asphalt, cars, people, text except DELTA QUEEN, no new buildings.
Local water immediately under the ship and between hull and quay may remain opaque with reflections, but behind ship sides and above ship the distant city/sky must be alpha-transparent. Preserve full scene footprint across width for panning. Main ship and its ground are ONE integrated image. The bottom 21% must be clear coherent stone foreground. Transparent background required.

**backdrop**

Use case: precise-object-edit.
Edit target: attached original DELTA QUEEN night riverboat pixel-art image.
Produce its separate OPAQUE BACKDROP layer, preserving the original admired nighttime waterfront setting. Keep the exact layered skyline, amber-lit art-deco towers and warehouses, subtle cyan/magenta accents, navy/purple clouds, harbor lights and dark river reflections. Remove the ENTIRE foreground DELTA QUEEN boat, paddlewheel, sign, rails, gangway, lanterns, bollards, ropes and stone quay. Inpaint all removed foreground to continuous open river with plausible warm/cyan/magenta reflections; no silhouette, boat ghost, hole, foreground dock or repeated main venue. The far shore should sit about y.47, the open river continues all the way to the bottom. Preserve original artistic style, palette, perspective and scale. Wide 2:1 native1774x887 if possible. Opaque edge-to-edge background, no alpha, no checkerboard, no text, people, vehicles or boats. This layer will be behind the separate transparent boat/quay layer.

### grand_casino

- exteriors/grand_casino.png: 1774 x 887 RGBA, 1435725 bytes; SHA-256 9112d9ca7ffb7e2d41a7d9ded23433daea92afa7f4f836b3635b1ae975d08f89.
- backdrops/grand_casino.png: 1774 x 887 RGB, 2241900 bytes; SHA-256 ffbc51384af6222f40d9123dda7da4f76bbe486e9bacc5ef9e5607d7f75b69d2.
- Threshold [1343, 701]; inside [1343, 677]; clear foreground begins near y=715; wheel baseline y=842.65 (UV 0.95). Roof/silhouette begins near y=389.
- Door leaf polygon: [[1232, 520], [1454, 520], [1454, 698], [1232, 698]]; double hinged, paired outside hinges.
- Arrival path alpha range: 253-253. Clear ground alpha range: (251, 254).

Fountain and planters are set back to the facade edge. The lower forecourt lane is uninterrupted stone and all gold lines are flat inlays.

#### Exact edit prompts

**main**

Use case: background-extraction. Edit target: attached original Grand Casino nighttime pixel-art scene. Create its MAIN foreground layer,1774x887, transparent background. Keep original luxurious gold/magenta casino facade, wide chandelier windows with suit symbols, gold canopy, closed textured purple double doors with handles, velvet ropes, fountain and planters. Remove ALL distant skyline, large gold stepped hotel tower, far greenery and sky behind the low casino facade to true alpha0. The separate backdrop will retain those.
Recompose the near casino roof near y .40-.43, doorway rightcenter x.755 with threshold at y .75. Keep closed doors as full visible unobstructed paired leaves and correct perspective, lower panels and handles. Maintain doorway width aboutx .695-.82. Canopy above, security ropes to sides, never across doorway path.
Paint a naturally EXTENDED coherent inlaid stone forecourt across the entire foreground to bottom y1, the same elegant gold/purple stone and continuous perspective, no appended generic road or separate swatch. Move fountain BACK toward the facade at leftx .22 so its basin ends by y .77, and planters end by .77. Everything below y .80 must be clear continuous flat stone vehicle/pedestrian approach. Clear wheel baseline y .95. Preserve original admired art style and identity. Solid building, entrance, fountain and plaza alpha255, only background removed alpha0. No cars, people, new text, asphalt, checkerboard or painted black sky.

**backdrop**

Use case: precise-object-edit. Attached original Grand Casino pixel art is edit target. Create the separate OPAQUE distant-city BACKDROP,1774x887. Preserve exactly the admired navy night sky, blue clouds, warm golden stepped art-deco HOTEL tower, surrounding smaller city towers and landscaped distant grounds. REMOVE the entire low foreground casino facade with gold canopy, suit-symbol windows, doors, ropes, fountain and forecourt. Inpaint their removed lower half as a plausible continuous distant hotel neighborhood: shadowy landscaped approaches and smaller far buildings leading up to that golden hotel, no duplicated low casino venue, no large near entrance, no fountain or close plaza objects. Keep same scale and positions of skyline and golden hotel in upper half. Extend distant neighborhood to bottom edge behind where foreground layer will cover it. Same detailed crisp neon pixel style, opaque edge-to-edge, no alpha/checkerboard, people, cars, signage or text.

**reframe**

Edit this exact transparent casino foreground. Keep canvas1774x887, roofliney390, all facade identity detail and genuinely empty transparent upper sky. Make TWO focused geometry corrections: 1) Move the fountain, its entire base, and both planters farther BACK toward the building so that the lowest pixel of each is at y690 or above. Reduce their size modestly as needed; fountain remains left nearx380, planters near side edges. 2) Shorten the facade slightly so door bottoms, wall base and rope-post feet lie at y670, not720. Door leaves remain closed and textured; door opening x1230-1456, topy505,bottomy670.
Then naturally paint the same inlaid polished forecourt stone continuously fromy670 to bottom887. The entire bandy700-887 must be EMPTY flat walkable/driveable pavement, with coherent diagonal gold inlays and reflections, no objects or raised borders anywhere in it. No appended swatch. Keep all upper sky transparent alpha0 and scene solids alpha255. No city, text, vehicles or people.

### kitty_cat_lounge

- exteriors/kitty_cat_lounge.png: 1774 x 887 RGBA, 1475745 bytes; SHA-256 66baa7f8387e274839208887b478342919319eb7867acbbfe99590e91018bdca.
- backdrops/kitty_cat_lounge.png: 1774 x 887 RGB, 1937367 bytes; SHA-256 b8a9c8ba5bea78cdeafe518c5ab499bd8f3d70f2ddc0c824ee72b512dfc49279.
- Threshold [1310, 719]; inside [1310, 694]; clear foreground begins near y=770; wheel baseline y=842.65 (UV 0.95). Roof/silhouette begins near y=357.
- Door leaf polygon: [[1210, 529], [1413, 529], [1413, 712], [1210, 712]]; double hinged, paired outside hinges.
- Arrival path alpha range: 253-254. Clear ground alpha range: (251, 254).

#### Exact edit prompts

**main**

Use case: background-extraction. Edit target: attached original Kitty Cat Lounge nighttime pixel-art scene. Create MAIN foreground scene1774x887 with genuine transparent background. Preserve the admired pink scalloped canopy, cat/champagne neon motifs, warm curtained windows, LOUNGE sign, gold-trimmed textured closed red double doors and velvet ropes. Remove ALL neighboring apartment blocks, distant city towers, roof tanks, chimneys and sky behind the near lounge roof to alpha0, no painted replacement background.
Keep near lounge roofline aroundy350 (.40), canopyy390-440. Recompose facade slightly shorter so door threshold and wall base are y670 (.755), door topy480, door leaves x1208-1413 centeredx1310. Preserve legible closed art-deco textured door leaves and gold handles, ropes only to each side.
Naturally extend the existing sidewalk and wet street as ONE continuous painted scene: sidewalky670-710, curb at710, and broad clear dark wet road fromy715 through887, with continuous reflected pink/amber lights. This is integrated foreground, no appended generic strip or abrupt swatch. All posts/ropes/window details abovey700, entire wheel corridor across image y815-870 completely clear. Scene solids fully alpha255, only upper/background removed alpha0. Crisp original pixel style. No cars, people, extra signage, new main building, checkerboard or black painted sky.

**backdrop**

Use case: precise-object-edit. Edit target: attached original Kitty Cat Lounge scene. Produce only its separate OPAQUE BACKDROP layer,1774x887. Keep admired far warm-window brick apartment neighborhood, roof tanks, rooftop vents, chimneys, layered downtown towers, cyan/magenta skyline accents and navy/clouded sky, at original scale and positions. Remove the ENTIRE near lounge front: pink canopy, cat signs, curtains, LOUNGE letters, doors, rope posts, sidewalk and close road. Fill the removed near scene with continuous smaller distant neighborhood buildings and rooftops extending behind where the lounge stood. No duplicate lounge or pink storefront, no main venue remnants, no new signs, people or cars. Preserve crisp original detailed pixel-art style. Opaque edge-to-edge, no alpha or checkerboard.

**reframe**

Edit this exact transparent Kitty Cat Lounge scene. Canvas1774x887 unchanged. Keep the roofline at y360, canopy at y410, every recognizable cat, champagne, LOUNGE neon and curtain detail. Make building shorter below canopy: redraw windows and doors to fit y475-680, with door leaf bottom and wall base at y680 instead of760. Keep full visible paired red/gold textured doors centeredx1310. Rope-post bases also at680. Sidewalk y680-720, curb at720. The wet street must occupy the FULL WIDTH of bottomy725-887, about160pixels deep, naturally painted as part of this same scene with pink/amber reflections. Nothing except flat clear street in that lower band. No added strip, scenery or props. Keep the entire top region genuinely transparent, scene solids alpha255, preserve original style and lighting.
