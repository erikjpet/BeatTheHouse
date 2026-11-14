# Back Alley: execution brief

Prepared: 2026-11-14
Room identity: back_alley
Status: Back Alley is the active package. Exact R3 has cleared static and base/settled-scenario/minimum/peak/Reduce Motion visual review, but full native motion/outcome/technical audit is still pending. No Back integration or TEST publication is authorized by this brief.

Read the shared environment art direction, room briefs and animation translation ledger. This brief is not approval of an unmade package.

## Narrative and local identity

This is a working service alley in the Street register: wet, electric, practical and risky. The game is a casino roguelike about debt and heat, not a glamorous resort. The alley is a place for dangerous bargains, not a theatrical criminal lair, abandoned corridor or horror set.

The actual current travel facade supplies these anchors:
- rich irregular plum/purple masonry with dark recessed mortar;
- one exposed amber practical and its localized warm pool;
- restrained cyan/magenta passage light;
- wet stone/asphalt with sharp, selective reflected color.

Do not copy the facade's entire building, upstairs windows, fire escape or right-side table placement into the room. Current interior fixtures and access geometry remain authoritative.

## Rendering references and source roles

1. Frozen clean geometry target: back_alley_clean_geometry_v2_1800x860.png, SHA-256 8ff3e8da1316962c3cfc7a9520c87a0ef894fb28c58df6a80df390d03dcea60e. Its original guide, SHA-256 f9603b2acd5abb32f1aaf1f27421cf2f9116272c829e1da44b125a298afc54d4, is preserved.
2. Own current facade: assets/art/travel/exteriors/back_alley.png and matching backdrop. These control local material and color identity.
3. Accepted Gas R12 background: use its decisive local ramps, hard pixel construction and bright contrasting accents as rendering reference, not its architecture, wall pattern or floorboards.
4. Approved Delta Queen facade remains a secondary fine-material/detail-craft reference.

The old flat Back Alley proof and art_rework_test_04 layout are not approved material donors. Do not infer approval from their filenames.

Use crisp clustered pixel painting on the fixed 900 x 430 board, delivered as an opaque 1800 x 860 PNG. Preserve original generated sources. Normalize/assemble nearest-only as needed; do not blur or globally quantize away fine detail.

Keep the stronger shared philosophy: readable material planes, intentional hard edges, vivid local color separation, dark contact shadows and compact bright practical cores. Avoid a uniformly brown/amber wash, gray muddy midtones, photographic brush noise, coarse symbolic boxes or science-fiction spectacle.

## Fixed geometry

Coordinates are board units. Native textures are twice these values.

- Wall/floor boundary: y236.
- Central folding table: [282,192,336,24].
- Table legs: [318,216,14,78] and [572,216,14,78].
- Hanging wire: x450 from the ceiling to the lamp.
- Lamp fixture: [420,104,60,16], with the existing small lower light core around [432,120,36,10].
- Right crate/front: [638,168,208,50].
- Right crate counter PNG: back_alley_crate_display, exactly 416 x 100, opaque over its physical front.
- Ordinary bin bodies: [118,248,42,54] and [742,248,42,54], retaining their existing lid/support positions.
- Keep side-access areas clear: approximately x0..88 and x812..900, y220..414.

The clean target removes baked rain, five old stock blocks and lower marker dashes. It retains table, lamp/wire, bins and the exact right crate. Its opaque crate replay was excluded from rain inversion, so its original pixels are intact.

Do not add a new foreground counter, doorway, platform, luxury furniture or new interaction support.

## Current live anchors and quiet material

Read current placement_surfaces.json, developer_placement_overrides.json and actual runtime object layout before final assembly. The baseline override SHA-256 is c5c9808497ee3d4f056bb5a7f24a64524d4e59ee50e3fff106eb41e09383245f. Do not change these files to accommodate art.

Recorded current anchor examples:
- Shop items: [324,191], [411,192], [495,192], [580,192].
- Merchant: [808,187].
- House Drink: [661,166].
- Crew group: [848,287].
- Street lender: [52,306].
- Patrons: [119,411] and [36,400].
- Main exit: [866,394].

These examples do not replace the current runtime data or scenario overrides.

Leave all live stock bays empty. Do not paint watches, price cards, offered goods, people, merchant silhouettes, gameplay labels or a duplicate drink into the background.

Plan label-safe real materials for the UNION of base, scenario, work-phase and outcome positions:
- dark purple wall planes behind the table stock;
- dark warm wood faces on table and crate, with thin amber/gold edges rather than broad pale faces under yellow names;
- localized lamp light that does not wash out the gold shop labels;
- sparse reflected color in the floor rather than bright bars beneath roaming text.

Use actual label rectangles and settled-route captures. Do not guess names from tiny pixels, move labels or place floating UI-like backing patches. A generator matching a fixture's outer rectangle does not prove its support edge is at the right row; measure contact lips explicitly.

## Motion inventory and interpretation

Read BOTH the room's drawing routine and its scene-life branch, plus shared helpers. Seed-selected colors are not motion.

Required meaningful treatments:
- exposed bulb/pool breathing and the small practical light-cone variation;
- falling rain, from the original 18-streak family, with diagonal drift roughly [92,156.4] board units/second;
- eight faster low rain-light streaks, around y282/294/306, from the original90-unit/second family;
- three puddle-ring locations: [180,304], [420,292], [710,312];
- two restrained warm glints; the old [792,174] point would be hidden inside the opaque crate front, so adapt it to visible top trim or adjacent material without an alpha hole;
- common moving floor light, using this room's amber/cyan/magenta wet-material palette.

NO HEAT and PAY CASH are static source signage, not legacy clocked pulses. Do not count seed-selected text colors as animation.

The background source must not bake falling streaks, expanding rings or frozen lower dashes. Separate actual motion layers carry those effects. Static wet-material reflections are allowed when they are clearly material/light structure rather than frozen copies of moving assets.

Art direction explicitly approves two coherent translations for this forthcoming package:
- A full-field scroll/rain asset may represent the old 18 trajectory family if actual visible density, diagonal drift and cadence remain comparable. Exact 960/360 wraps and seed trajectories need not be copied. This is visual translation, not claimed frame equivalence.
- Seven wet-material floor-light movers may consolidate the common sheen plus older lower reflection-marker family, rather than literal lower bobbing rectangles. Keep the separate falling rain, eight fast ground streaks and three puddle rings visibly distinct. Bulb pool/cone may share a synchronized pulse.

These are concept decisions only. Actual assets still need visible runtime proof and a final exact-package audit.

Use the existing five renderer primitives only. Check Web texture limits before selecting wide frame atlases; prefer an appropriately bounded strip or existing mover/scroll behavior rather than new renderer code.

## Current R3 art-only refinement and evidence scope

The first actual trial revealed two label/material collisions. The director approved the following narrow decorative adaptation without moving a fixture, live object, label or contact:
- Preserve the complete lamp silhouette at y104..130. Put a compact honey emitting strip inside its upper housing at [436,109,28,5], above the measured Thermos name band[432,116,126,26]. Lower housing/glass y115..130 is dark bronze/plum. The same breathing cadence and synchronized source-derived warm-brick pool remain.
- Keep the table's bright thin contact rim y192..193. Its real wood face y194..216 is darker, preserving grain/chips beneath Shoe-Cut Marker's measured name band[361.5,194,99,15].

The broad floor source is assembled at the same 900-grid scale using its y100..294 region to fill floor y236..430, with no vertical stretch. Table legs and bins are replayed at their original supports. The preliminary flat pool/cone wash was replaced by a source-derived delta mask on the actual warm brick footprint.

Exact current R3 package: f42919a146d4fdc17d7cd120ef926b44f6ccaefabcaf6a8a171e805db2150b68. Background SHA-256 a8533e7dbd30cd75153e961cbf999acb0ffb1577e49111c3ed1eabba5704ffb6. It contains 23 authored entries across the distinct required motifs. Raw generated sources and earlier trials remain preserved.

Director and independent artist/auditor have reviewed the corrected actual base view, natural lamp minimum/peak and supported Reduce Motion view. The director has also personally reviewed naturally settled Street Craps, Cruiser Parked, Fence Night and Nothing Moving. No new art-induced material/label failure was found in that scope. This is NOT full package PASS: all 23 per-entry visibility, published work/outcome contexts, counter replay, geometry, liveness and other technical receipts remain final gates. Actual rendered-object assertions must cover room-visible authored content, not merely authority keys. Do not infer browser/TEST acceptance from native evidence.

## Package and review sequence

- One opaque 1800 x 860 background.
- Exact room manifest at data/art/environments/back_alley.json.
- Separated animation textures under assets/art/environments/back_alley/anim/.
- Exact opaque 416 x 100 crate-front texture under the mapped counter ID.
- Source files and all handed-off candidates remain immutable; corrections receive a new version/path/seal.
- Review static exact-grid material and all physical contact edges first.
- Then capture actual production full-room motion plus faithful named crops. Show every authored asset/motif, without preview-only amplification, pans or fake motion.
- Include a crisp actual PNG alongside the animated preview.
- Check all current room scenarios and relevant work/outcome states, with settled actors at their real supports, not only arrival snapshots.
- Verify geometry/hits/labels, counter replay, Reduce Motion, no-input liveness and converted-preview visibility.
- Only the exact passed package may enter the existing art branch; retain enabled Gas and Corner packs when adding it.
- TEST/Web served identity and browser visuals are a separate post-integration gate. Do not claim them from native evidence.
- Keep readable planning and non-active source backups in GitHub checkpoints without enabling unapproved assets.
