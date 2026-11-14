# Pawn Shop: execution brief

Prepared: 2026-11-14
Room identity: pawn_shop
Status: Pawn authoring is active after the Bar final native PASS. First room/floor sources exist; exact assembly and every Pawn audit/runtime gate remain pending. No Pawn runtime package is approved or activated.

## Narrative and own facade

This is Sal's quiet, barred, fluorescent shop: "Mistakes go on Sal's shelf." The UI describes cash, repairs and second chances behind glass. The security cue "Set something on the tray. Sal opens the glass" grounds the existing transaction window and small inspection light. It is a practical collateral/repair stop in the debt-and-heat roguelike, not a boutique jeweler, casino vault, police laboratory or glamorous treasure room.

The actual facade/backdrop supply rich violet/plum masonry, cold cyan-lit barred glass, worn gray metal and aged yellow/gold sign framing. Inside, combine those anchors with mismatched dark old wood, dusty glass, dull hardware and a dry work floor. Use cold practical light and compact warm inspection accents, not Bar's teal timber or Gas chrome. Preserve vivid local hue separation and crisp pixel construction without making the whole room bright cyan.

Do not import the exterior guitar, radio, camera, jewelry, outside layout or stock silhouettes into live sale bays. No painted Sal, customers, scenario actors, second inventory, price cards or gameplay labels.

## Reference roles and exact clean target

- Frozen clean target: E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261114/guides/pawn_shop_clean_geometry_v1_1800x860.png, SHA-256 e1d09c3c23d867b82d770f22c7620da7780eab44b7d0fa69798ace766f9ad71a. Director independently viewed actual pixels.
- Preserved original pawn_shop_legacy_geometry_1800x860.png, SHA-256 686ec3cb7571950b4d2a2552727515bf67b4e5aa4a651b11ec08750f5c32fb61.
- Own facade assets/art/travel/exteriors/pawn_shop.png, SHA-256 33a7870d7bddda7c4b68ed65b312aa99f4b868d9fa530bdec36191d7e393f272; backdrop SHA-256 9ca2332a0230399bf8b6545ca05dc594d8a8503cc3c0a124d7003a8f48ac4f3e.
- Owner-preferred supplied pixel design and accepted Gas R12 control hard contours, decisive local ramps, sharp clustered materials and bright contrasting accents. They are rendering references, not Pawn architecture or material donors.
- Approved Delta Queen facade remains secondary fine-detail/material-craft reference.

Work on the fixed 900 x 430 board, final opaque 1800 x 860 at pixel_scale 2. Preserve raw generated originals. Nearest-grid exact fitting and assembly are allowed; no blur filter, global quantizer, muddy uniform grading or photographic micro-noise. Keep source detail while separating glass, wood, masonry, metal and rubber planes.

## Fixed fixtures and resolved legacy ambiguities

All coordinates are board units. Native textures are twice the destination values.

- Wall/floor visual horizon y246. Floor starts BEHIND the lower counter, not at its bottom304 or the runner bottom298.
- Dark soffit y0..32 and existing warm trim y32..38.
- Existing SAL'S PAWN wordmark at306,58,size31; BUY SELL TRADE at330,94,size16. Preserve copy/placement, no new brand or slogan.
- Left case[56,70,218,146], inner[72,86,186,104]. Existing thin internal lips[78,y,174,5] at98/126/154/182. Keep empty live bays and all existing frame/support edges.
- Central cage/recess[316,92,268,132], with existing diagonal security mesh.
- Central construction[342,116,214,74] is a framed SECURITY TRANSACTION/VALUATION WINDOW, not a cast placeholder. Its inset[358,132,182,42] is dusty cold glass; amber[408,148,76,16] is a compact inspection/tray light behind that glass. Do not paint a face, new monitor UI or merchandise there.
- Legacy rear body[316,224,268,54] is the rear cage plinth/base fascia. Preserve its exposed upper224..236 rim and existing line at232 behind the low field. It is not a reason to shift or duplicate the foreground transaction counter.
- MAPPED main front[316,262,268,42], counter ID pawn_counter, opaque PNG 536 x 84. The contact/replay front is262, NOT224.
- Right case[612,72,224,150], inner[630,92,188,108], internal cool rail[652,170,142,18].
- MAPPED right lower front[600,184,246,28], counter ID pawn_estate_shelf, opaque PNG 492 x 56; top184/front212.
- Broad original field[58,236,792,62] has no mapped interaction support. Interpret it as shadowed case toe-kick y236..246 plus a FLAT dark rubber/work runner lying on floor y246..298. Preserve the footprint/material field without a raised top, platform edge, new legs or obstruction.
- Side access x0..72 and828..900, roughly y230..414, remains clear.

The old full rear224..278 body was partly covered by the low field in the original draw order. Do not expose a new second freestanding desk or make the runner a solid volume. Existing upper/lower/serial/hold support metadata describes contact planes and reserves, not permission to invent extra cabinets.

Clean target removes 16 left colored stock placeholders, 4 right stock columns, static amber marks on the low field and lower helper marker dashes. Actual security mesh, transaction glass/tray, all case/shelf lines and both opaque mapped fronts remain. Mesh is real static construction; its scan/light motion is separate.

## Live geometry and quiet physical material

Read current placement_surfaces.json, developer_placement_overrides.json and actual runtime object/label layouts. Override SHA-256 c5c9808497ee3d4f056bb5a7f24a64524d4e59ee50e3fff106eb41e09383245f stays unchanged. base_saved:false does not disable current slot positions.

Recorded current anchor examples:
- Six shop contacts[117,127], [199,127], [117,182], [199,183], [722,182], [808,181].
- Sal[448,286]; small Slot[540,269] with existing scale0.5.
- Event people[448,212], [707,307], [780,307]; exit[868,394].
- Estate Lot Day, Serial-Check Day and Sal's Mood have substantial scenario overrides. These examples are not substitutes for current settled labels or source-published work/outcome layouts.

Plan the UNION rather than guessing title position from a contact anchor:
- Dark quiet glass behind gold shop names; no bright painted stock or broad neon shelf faces.
- Thin cool shelf edges with subdued real faces, not full-bright cyan bars across title rows. Preserve actual supports and measure their visible contact rows.
- Dark old-wood main/right fronts for Sal and other gold names, with small contrasting yellow edges outside measured name bands.
- Compact amber tray lighting and cold scan on their real surfaces; do not wash gold names with a broad lamp rectangle.
- Quiet dry floor/runner for cyan Slot and roaming pink/gold scenario names.
- Respect live sprite alpha: actors/items render after animation and naturally occlude it. A model rectangle is not an opaque pixel mask.
- Mask animation against fixed BG case/window/frame construction where needed; those bodies do not automatically occlude later animation.
- No floating label-sized backing patch, moved label, new support or alpha hole through an opaque front.

No older promo screenshot or alternate-layout archive is layout/style authority. Use actual current baseline metadata before final assembly decisions and validate the normal production selected labels, including interaction overrides.

## Meaningful motion and approved interpretations

Read the drawing routine, scene-life branch and shared helpers. Static stock_cycle_color and the low field's sin(x) amber marks are NOT clocked motion.

1. SAL'S PAWN sign-light pulse family[292,42,320,68], gold, source alpha.13/speed4. Follow actual glyph/light surfaces, not a large flat wash. BUY SELL TRADE remains static authored copy.
2. Central security glass/mesh vertical scan within x332..570,y98..218, about72 board units/second. Original family has a main thin row and fainter companion19px apart. Keep meaningful vertical travel on visible glass/mesh and off unrelated fixed opaque construction.
3. Separate amber inspection/tray-panel breath[410,148,72,14], source alpha.20+abs(sin(t*3.4))*.16. Do not merge into the sign/scan or bake it permanently at peak. A compact physical warm base must remain coherent under Reduce Motion.
4. Very sparse high cool air/dust drift from the five-ribbon family, x66..826 around y86/104/122/140/158, source alpha.018 and horizontal rates10..18 with small vertical bob. Interpret as faint fluorescent-air/dust life, not a room-wide smoking fog.
5. Three small warm hardware/glass glints centered[150,84], [414,118], [690,154]. Keep them physically motivated on existing visible material; genuine actor/item occlusion is allowed when verified, while a permanently hidden fixed-front glint needs a visible existing-surface adaptation.
6. Seven restrained cyan/amber/plum floor-light movers on dry floor/work-runner material.

The director explicitly approves the seven floor movers as consolidation of shared sheen and the older lower reflection/bob/stripe family. Do not copy wet pavement or literal marker dashes. Sign, scan, amber tray, high air/dust and three glints remain distinct.

A small number of coherent faint drift/scroll fields may translate the old five-ribbon high-air family under existing renderer primitives, preserving comparable sparse density, high placement and slow lateral/vertical life. Exact seeded trajectories and literal ribbon counts are not required. Use stepped pixel alpha/detail, not blur. Actual visible motion is still required; metadata alone is not a pass.

All authored assets must move in normal production pixels and stop under the supported Reduce Motion setting. Keep a coherent lit/physical room in the reduced state. No new renderer code, preview-only opacity/speed boost or clock pause.

## Source, package and acceptance

- One opaque 1800 x 860 background, exact opaque 536 x 84 and 492 x 56 fronts, separated motion textures, manifest data/art/environments/pawn_shop.json.
- Preserve raw sources/prompts/provenance and immutable candidate paths/hashes; new versions for corrections.
- One coherent clean-guide source after Bar's final native PASS. No pre-generated stock sheet or new prop module. A floor plate is justified only if returned depth at 246 cannot be fitted without visibly stretching/repeating material.
- Static review measures both fronts, case lips, transaction-window/mesh depth, exposed rear rim, flat runner and side access.
- Early actual full-room motion plus faithful motif crops and a crisp actual PNG. Prioritize labels over cases, Sal/Slot and any injected glass/mesh actors.
- Test all current Pawn scenarios plus relevant authored work/outcome families with normal production publication/membership and naturally settled actors.
- Assert actual canvas objects, debug geometry and nonempty selected-production-label rectangles for each room-visible authored visual. Explicit source-proven hidden/non-room exclusions are allowed; authority keys alone are not rendered-object evidence.
- Verify exact geometry/hits/labels, both opaque front replays, per-entry actual-composite motion/RM, floor wraps, no-input liveness and converted-preview visibility. Declare genuine natural occlusion with source/painted-mask evidence rather than drawing an effect above people.
- Only exact final native PASS permits integration into the existing art branch; retain earlier accepted packs. TEST/Web identity and actual browser visuals are separate gates. Do not imply UI/save/revisit end-to-end coverage.
- Checkpoint direction, source recipes/backup and honest review state on GitHub. Do not activate unapproved assets, move main/NEXT, alter audience or modify travel facades/doorways in this interior package.

## Current measured four-context pre-art supplement

The strict173/c5 baseline is now captured and closed BEFORE the first source image. The director personally inspected all four actual full-app PNGs: Base, Estate Lot Day, Serial-Check Day and Sal's Mood. Source publication, normal settled arrivals, actual object/geometry/hit rectangles and selected-card titles were measured without a Pawn pack. This is pre-art planning evidence, not a Pawn art PASS or work/outcome coverage.

Authoritative union: E:/CodexQA/BTH/runs/BTH-ENVART-PAWN-20261114-union-01/evidence/pawn_preart_union.json, SHA-256 9ade78efe6ed2e596c7c7911f8d5b76f9906f2148bcacbe0a0810f80049a46d2. Readable .md sibling. Initial scope449 checks/0 findings,53 actual canvas objects and selected titles,39 distinct IDs across four contexts; no hidden/non-room/hosted exclusions in these initial cases. Full exact evidence ZIP ca69b0d6d15c57a7c25e2df0c1de256acba031d991b63183d5c0908bc966e409 is at runs/BTH-ENVART-PAWN-20261114-closure-01/evidence/pawn_preart_evidence.zip. Native and closure Jobs are drained.

Actual PNG root is E:/CodexQA/BTH/runs/BTH-ENVART-PAWN-20261114-current-four-01/evidence: __none_actual_play.png, pawn_shop_estate_lot_day_actual_play.png, pawn_shop_serial_check_day_actual_play.png and pawn_shop_sals_mood_actual_play.png. These current positions supersede any older promotional capture or guessed name bands.

Use these real physical material priorities in the FIRST source, retaining vivid facade colors and selective aged-metal accents elsewhere:
- Main counter front262..304 stays dark detailed old wood. Base/Serial/Mood gold Sal title[424,288,48,15] and Mood Sal Shopkeeper[319.4,288,93.2,15] share it. Do not make this face pale or aged-yellow.
- Lower transaction/cage construction needs quiet dark depth and thin worn metal edges. Estate gold Sal moves to[424,197,48,15], Estate Appraiser[314.6,185,104.8,15], Serial Records Clerk[318.3,188,87.4,15]. Do not flatten the whole room or paint a label plaque; retain actual frame/mesh/plinth construction.
- Base/Serial/Mood Chatty Clerk is PINK, title[407.2,113,81.6,15], above the transaction-frame top116. Its actual model[416,130,64,82] covers the tray center, but envelopes are not opaque masks. Keep this source bay empty, not a frozen cast substitute.
- Mood Private Appraisal is CYAN, title[310.7,138,110.6,15], model[330,155,72,48]. Its title crosses glass and the LEFT EDGE of the tray envelope. Keep the surrounding glass genuinely dark; the amber tray is a compact inspection accent, not a large bright panel. Editor must mask real frame/mesh/title restrictions and prove motion through actual painted gaps or another current context, rather than blanket-model exclusions or forced effects above actors. This does not move the physical tray.
- Estate task 'Establish the estate provenance' is CYAN, title[200,185,126,26], not assumed gold. Gold lower-left stock names also begin184 and211; Serial held-item title[139,240,126,26] and task[59,266,126,26] extend onto the flat runner/floor. Keep actual left case faces, runner and toe-kick quiet; thin selective support edges, no broad glowing rail or new platform.
- Right stock titles include gold bands183/184 and106..132, while Estate False-Bottom Cup and pink Estate Map extend to248/247. Preserve the exact mapped opaque right front184..212 and current effective item contacts; use a dark real shelf face with restrained edge light, not a pale/yellow slab.
- Lower floor needs quiet room-local dry materials for current provenance/task/exit titles. Retain the flat runner interpretation and existing clear exits, with no raised stage or new supports.

Model, label and hit rectangles in the union are geometric envelopes, not opaque paint. Contact metadata does not authorize drawing furniture for every support ID. Preserve effective overrides and the two exact foreground fronts. When later context/object occlusion is expected, prove actual source-painted coverage and meaningful motif visibility somewhere; do not invent holes, move labels or make a hidden asset look present through preview-only boosts.

No further structural reinterpretation is needed from these baseline views. The original frozen guide/geometry, own-facade identity, empty inventory/cast bays and meaningful motion inventory remain unchanged. This supplement authorizes source-prompt planning only. Pawn source generation still waits for Bar's explicit exact final native art PASS; later Pawn static, actual, full source-context and TEST gates remain separate.

## First source and art-only scan clipping checkpoint

Bar R4 exact package398469b22c7c0eed36220757e79ce0829498aa79f4ecd1ce019df493abb02d39 received final native PASS, so the conditional Pawn source release took effect. This does not approve a Pawn pack or claim Bar TEST acceptance.

Raw Pawn room source: E:/CodexQA/BTH/workspaces/BTH-ENVART-ARTIST-20261114/pawn_shop-v1/source/background-guide-v1.png,1815 x867 opaqueRGB,SHA-25672b0794caeaff74a02d0472259d4da6ea9fe6171b1899279383da368ec68cc01. Director personally viewed it. Its own vivid plum masonry, cold glass, worn metal and old wood are strong and crisp; no full-room regeneration is requested. It is SOURCE ONLY, not geometry-conformant: the broad low field became a raised-looking fascia/deep mat and the side floor horizon is too low.

Editor must restore only the actual toe-kick236..246, continuous floor246 onward, FLAT runner246..298, exact main front262..304, existing rear plinth224..236 and other frozen contacts. Do not keep a vertical runner face, raised stage, step, invented support or extra furniture merely because the generator drew it. Preserve detailed fixture surfaces and selective accent color while repairing assembly. The full-width unoccluded raw floor is only about80 board pixels deep, insufficient for the required184 without repetition/stretch, so one matching floor-only source was justified.

Matching floor source: artist/pawn_shop-v1/source/floor-material-v1.png,1815 x867 opaqueRGB,SHA-256e7c878d9e2ce1e33b640dfee6564699b64c5a11447b694a93aee1d817cf4d031. Director personally inspected its dry plum/charcoal shallow tile joints and controlled scuffs; suitable for a same-scale184-board-depth crop. No additional room source, wet effect or extra runner was generated. Exact perspective/runner integration remains an assembly gate, not a package PASS.

The director approves the following OPTIONAL art-only layered clipping technique if the unchanged existing contract supports it:
1. A continuous vertical scan scroll retains its72px/s cadence and main/faint19px companion relationship.
2. A subsequent one-frame STATIC RGBA replay restores exact fitted-background pixels only on fixed frame/mesh/tray and source-shaped quiet-glass masks.
3. Separate tray breath, air and local glints follow as appropriate. Live objects remain above these existing animation layers; counter foreground/replay remains unchanged.

The replay mask MUST NOT scroll with the scan. It contains no cast, live label glyphs, substitute body envelope, floating badge or invented architecture. It is exact-material clipping, not an alpha hole in either opaque foreground front. Use genuine fixed physical/source-shaped masks, not a broad unverified model rectangle.

This option avoids a full-width horizontal scan atlas exceeding Web limits. It requires NO renderer/schema/validator change; if a one-frame entry is unsupported, report the constraint and choose another existing-primitive design rather than modifying code. Declare the entry explicitly STATIC OCCLUSION in external asset/audit rosters. It is not one of the moving motifs and must not be counted as an animated asset that failed to move. Still include its hash, alpha/order, exact BG equivalence with scan absent and Reduce Motion stability in proof.

Every actual moving family remains mandatory and must produce meaningful native canvas changes somewhere in current contexts. Prove static architecture stays fixed and other effects survive. Natural live coverage is acceptable only with painted-mask evidence; showcase another actual context or correctly scoped art target when needed, without promising that a hidden effect shows through a person. No frame-timing, opacity or preview amplification may hide a missing motif.

Pawn remains the sole active unapproved source/assembly package. Bar's served gate is separate, and Jazz clean-guide preparation may occur only in genuine idle time without delaying Pawn. No Jazz source release before Pawn's explicit exact final native PASS.
