# Bar: execution brief

Prepared: 2026-11-14
Room identity: bar
Status: R4 has static visual GO for isolated trial capture after bounded R3 material corrections. Actual R4, full native proof and TEST acceptance remain pending. No final Bar package approval is implied.

## Narrative and local identity

The actual archetype describes "Cheap neon. Regulars get loud." Its moods are noisy, loose and local. This is a working-neighborhood dive in the Street register, with Rafi's pull-tab service and regulars who notice strangers. Use ordinary accumulated wear, warm hospitality on a small budget and practical fixtures, not a luxury lounge, nightclub, abandoned criminal lair or generic purple-brick room.

The actual travel facade/backdrop anchors are weathered DEEP TEAL painted timber/panels, burgundy wood, amber rippled glass, hot-pink neon and small warm metal details. These colors and materials must be unmistakable in the interior. Green pool felt and a faded wine booth add the room's existing identity. The exterior's wet street does not authorize wet indoor asphalt. Use a worn, low-polish indoor floor with sparse room-colored light.

Do not copy the facade's building, window/door composition, street or bottle array into the interior. Do not add a new outside skyline, bar crowd, live band, bartender, sale stock or second drink service in the background.

## References and crisp pixel construction

1. Frozen clean geometry target: E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261114/guides/bar_clean_geometry_v1_1800x860.png, SHA-256 69c53003d57c8fb0e30888857d3437883bb83cace027474b5e88657dc4a1fe88. Director independently viewed its actual pixels. Original bar_legacy_geometry_1800x860.png, SHA-256 717f9efec2042681ef0f10f56ea9f63865e93d0097bb56ff1f8bf8164950839d, remains preserved.
2. Own facade assets/art/travel/exteriors/bar.png, SHA-256 c585c3be27d68aee1c722e729c9c5ea1b33d2a681651e4e73498c5952435f701; matching backdrop SHA-256 5d985b115913d2cbe7eadec3e3f5808afd4bbc2fdf8bcf41822e3fddd90917e7. These control local palette/materials.
3. The owner's preferred supplied pixel-art design and accepted Gas R12 establish hard contours, decisive local ramps, sharper clustered texture and bright contrasting accents. Borrow that rendering language, not Gas architecture, brick patterns, gold cage or purple floorboards.
4. Approved Delta Queen facade remains secondary detail/material-craft reference.

Create crisp clustered pixel painting on the fixed 900 x 430 board, delivered as opaque 1800 x 860. Preserve believable fine detail while separating material planes. Concentrate bright accents in small neon cores, amber edges and selective glass highlights. Do not impose a global low-color quantizer, blanket desaturation, gray muddy midtones, photographic brush noise or a blurry glow blanket.

The primary field should read teal painted wood and warm burgundy/brown bar construction. The mirror can carry deep amber patterned-glass depth with limited warm highlights; it must remain quiet beneath live game and drink names. No full-bright honey stock wall.

## Exact existing geometry

All coordinates are board units; native textures are double.

- Wall/floor visual horizon y244.
- Back mirror/frame [54,52,498,130], inner pane [72,70,462,84].
- Main counter/front [38,178,548,56], counter ID bar_main_counter, opaque PNG 1096 x 112.
- Six existing stool seats at x106/186/266/346/426/506, y230, each 42 x 12. Their posts are x+16, y242,10 x 48, ending 290. Keep their count and placement.
- Pool-table body [598,188,224,76], inner green felt [612,200,196,48].
- Pool pendant [654,124,112,14], hanging wire x710 from y80 to124.
- Real dartboard centered[824,92], radius24. It supports league-night wall props; do not replace it with a new target UI symbol.
- Small existing booth body [654,302,142,42], inner upholstery [662,310,126,22], seat[670,332,110,14], legs[672,346,10,38] and[768,346,10,38], ending 384.
- Preserve DIVE and COLD BEER identities and their existing placement. No extra BAR copy, invented slogan or brand is required.

Do not invent furniture from abstract/reserved support names. Keep the booth empty for its live seated outcome actor. Do not add another pool table, stage, stool, foreground rail, doorway or interaction support.

The cleaned guide removes 13 coarse bottle bodies/necks and lower helper markers. Patrons and moving pool balls were already absent. Existing stool/pool/pendant/booth geometry remains; the booth legs were restored through 384 where old lower marker pixels had painted over them.

## Empty live bays and quiet physical material

Read current placement_surfaces.json, developer_placement_overrides.json and actual runtime object/label layouts. Effective override SHA-256 c5c9808497ee3d4f056bb5a7f24a64524d4e59ee50e3fff106eb41e09383245f must remain unchanged. base_saved:false does not disable its current slot positions.

Current anchor examples:
- Three games contact[74,178], [371,179], [213,176].
- Drink[533,177], bartender[460,201], Numbers[619,188], Dot[287,233].
- Event staff[149,193]; other event contacts include[132,262], [209,264], [370,244], [448,244], [527,244].
- Exit[880,430]. Darts, Payday and Live Band have substantial local overrides; these examples do not replace them.

The 13 removed neon-colored bottle blocks are seed-static placeholder decor, not immutable geometry or animated fixtures. First-source mirror bays should remain deep and quiet for actual live games/Drink. Tiny subdued unbranded distant bottle silhouettes are optional only in proven pockets outside the UNION of live hosts and names. They are not required and must not become a second sale-stock display.

An older live diagnostic puts several game/drink gold names around y111..129 inside the back-mirror field. It is useful for initial quiet-material planning, not current authority. It also places the cyan Numbers title around y190 at the counter/pool edge rather than assuming it sits on COLD BEER. Verify current Base and all scenario labels before brightening either region.

Plan for base, naturally settled scenarios, work phases and authored outcomes:
- Dark detailed real bar wood beneath bartender and scenario gold names; keep the warm contact rim genuinely thin.
- Quiet deep teal/amber glass behind game/drink title bands; no bright bottle necks under text.
- Dark green felt and restrained pool/upper-rail highlights for cyan/gold titles near Numbers.
- Thin high smoke must not obscure name bands.
- Floor and booth stay quiet where band, darts, payday and seated aftermath actors appear.
- Use physical panels, cloth faces, glass shading and real trim for contrast, never floating label-sized plaques or moved labels.
- Measure actual contact rows and label rectangles. A correct module bounding box does not prove its lip is at the correct row.

## Required meaningful motion

Read BOTH _draw_bar and its _draw_scene_life branch, plus shared helpers. _cycle_color(x) bottle selection is static, not animation.

1. Pink DIVE sign-light pulse, original family rect[616,52,122,40], speed4.
2. Cyan COLD BEER sign-light pulse, original family rect[596,102,172,34], speed5.4.
3. First white pool ball, center[642+sin(t*1.5)*7,222], radius5.
4. Second white pool ball, center[756+cos(t*1.7)*5,232], radius4. Preserve their distinct phases/rates and small excursions, not a frozen rack or a single shared floor glint.
5. Sparse thin high cyan smoke: five original ribbons across x96..520 around y72/90/108/126/144, widths180/164/148/132/116, horizontal rates10..18 and small vertical bob. Keep the high region, faint density and slow lateral float. No baked haze blanket.
6. Four small warm glass/hardware glints from[98,92], [190,86], [362,92], [780,166].
7. Seven restrained amber/teal/pink moving floor reflections on worn low-polish indoor material.

The director explicitly approves seven floor movers as a consolidated interpretation of shared sheen plus the old lower bob/stripe family, not literal neon dashes or wet Alley asphalt. It does not waive either pool ball, the two signs, high smoke or four glints.

The five-ribbon smoke family may use a small number of coherent scrolling/drifting assets with existing renderer primitives if comparable sparse density, high-field placement and slow lateral/vertical life are visibly preserved. Exact procedural seed trajectories and literal band counts are not required. This is an explicit visual interpretation, not claimed frame equivalence or permission for hidden metadata-only motion.

Sign animation should follow actual authored glyph/light surfaces, not a large flat pulse rectangle. Source family rectangles describe legacy glow regions, not a demand to paint those entire rectangles over live names. Glints should sit on visible existing material and not need alpha holes through the solid counter.

Use the existing five renderer primitives only. Bound frame atlases for Web texture limits. Keep physical pool-ball resting states coherent under Reduce Motion; all normal-mode authored motion must actually move and all supported reduced-mode motion must stop.

## Source, package and acceptance sequence

- One opaque 1800 x 860 background; exact opaque 1096 x 112 bar front; separated motion textures; manifest data/art/environments/bar.json.
- Preserve all source images, prompts, reference provenance and every handed-off candidate as immutable paths/hashes. Corrections receive new versions/seals.
- Start with one coherent clean-guide room source after Motel final native PASS. Do not pre-generate bottle sheets or pool props. Generate a matching floor plate only if returned exact depth at 244 is insufficient without stretching.
- Static review checks geometry, all six stools, pool/pendant/dartboard/booth construction, floor joins and every physical contact edge.
- Early actual production full-room preview plus faithful motif crops and a crisp actual PNG. Show every authored asset without preview-only opacity/speed boosts, pans or fake motion.
- Test all current Bar scenarios and relevant work/outcome families with normal production membership/publication and naturally settled actors.
- Assert actual canvas objects, geometry and nonempty selected-production-label rectangles for each room-visible authored visual, with declared source-proven hidden/non-room exclusions. Authority-key membership alone is not visual proof.
- Verify geometry/hits/labels, exact counter replay, per-entry actual motion/Reduce Motion, floor wraps, no-input liveness and converted-preview visibility.
- Only the exact passed package may enter the existing art branch, retaining prior accepted packs. TEST/Web identity and actual browser visual review are separate post-integration gates.
- Keep planning, source/recipe backup and honest review state checkpointed to GitHub. Do not enable unapproved art, change main/NEXT/audience or modify current travel facades/doorways during this interior package.

## Current trial checkpoint: R4, not accepted

Motel R3 received exact final native art PASS and the Bar source was released. The first raw source is preserved at artist/bar-v1/source/background-guide-v1.png, SHA-256 11a65a14a8dd9d60e371e6b3abb111b132527c76ffc3e65d73b6443148f269f6. Its own teal/amber/burgundy identity and ample floor depth are retained; no second material source was needed.

R3 trial package b053927dba7b7531cc6585d7deab4b464ed8ddd395647cc106afb90b50483894 has 17 entries: two signs, two independent balls, two smoke fields translating five ribbons, four glints and seven floor movers. The old [780,166] sparkle is now a tiny broken timber-grain reflection at the same material site, not a glass star. Smoke cores are sparse stepped 3-6-pixel ribbons. The actual effective peak is 11/255 * 0.9 = 0.0388, approximately the intended 0.035 density, not a strict <=0.035 claim. The correction is recorded separately without changing sealed bytes.

The director, artist and auditor viewed the actual Base and priority Fight Night, Wake and Payday Rush scenes. Base is clear. Fight Night's Betting Book title is pink and readable, correcting an earlier assumed-gold planning label. Two real, bounded material failures were identified: cyan Remembrance tray middle strokes cross the bright pendant diffuser in Wake; Payday's gold Rush bartender tail crosses an upper-left amber mirror hotspot. The R3 actual-motion trial remains honest review evidence, not a final PASS.

R4 package 398469b22c7c0eed36220757e79ce0829498aa79f4ecd1ce019df493abb02d39, background SHA-256 22cc647f3766b0391ba6912836b933774d1872d9080425cf5f71e74384e7674f, corrects only these physical surfaces:
- Keep pendant outer [654,124,112,14], wire, frame and position. Its real diffuser y128..136 becomes dark warm bronze; compact honey emission remains only in the existing right internal end [736,128,24,4]. Current Base plus all seven initial scenarios have no label/model intersection with that pocket. The lower row137 was not chosen because the Wake title band still covers it.
- Dim only the source-shaped amber hotspot pixels within actual mirror glass x72..221, y70..106. Preserve ripple detail, amber hue, the frame and other reflection pools. No flat text badge, moved label, blur or global grade.
- All 17 motion payloads, counter, manifest and index bytes remain identical to R3. Exactly 2,771 board background pixels differ in the two allowed regions.

The director personally inspected exact R4 board pixels and issued static GO. This authorizes isolated early actual Wake, Payday and Base review, not implementation. Full current initial-context coverage is Base plus seven scenarios; check the complete current catalog rather than the three early priority examples. Follow with room-specific work/outcome proofs, exact geometry/label equivalence, counter, motion, Reduce Motion and liveness before any exact-package PASS. No final Bar PASS or TEST activation is recorded here.

Pawn Shop is the next read-only prepared room. Its frozen guide and separate execution brief are ready, but its source generation remains conditional on the Bar's explicit exact final native art PASS. Do not add another routine briefing wait after that gate.

## Later checkpoint status

Exact R4 initial actual review clears all eight current cases (1,017 checks, no findings). Full native acceptance remains in progress. This source checkpoint is non-active, not an audit PASS or deployment. Served TEST remains the four accepted rooms on source 173b235d.
