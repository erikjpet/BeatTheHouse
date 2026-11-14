# Motel lobby: execution brief

Prepared: 2026-11-14
Room identity: motel, not motel_room
Status: Motel R3 is the active QA-only package. Exact static and Base/all four settled scenario visual gates have cleared. Full motion/work/outcome/technical audit is pending; no Motel package is passed, integrated or activated.

## Narrative and room-specific identity

The actual archetype is a shop and recovery stop with moods quiet, pink and temporary. "Thin walls. Luck runs thinner." This is a modest roadside reception/common room where room keys, rumors and passing people meet, distinct from the paid private Motel Room. Use tired everyday hospitality, cheap repairs and practical furniture. Do not make a bedroom, luxury hotel, derelict horror room or another purple-brick shop.

The current travel facade and backdrop control local identity: faded rose/plum plaster above a low violet masonry base, oxidized teal coping/metal, honey-lit curtains and small practicals, burgundy timber and a pink MOTEL/VACANCY sign. The interior translates those materials into worn plaster, faded waiting upholstery, cheap veneer/laminate, dark CRT glass and a matte low-cost floor. Keep pink and teal accents clear and lively while concentrating honey highlights in compact practical cores. Do not copy the exterior building, courtyard, parked-car geometry or extra windows.

## Reference roles and pixel treatment

1. Frozen cleaned target: E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261114/guides/motel_clean_geometry_v1_1800x860.png, SHA-256 f22befd872174d2cb6aaf92ea27d3f36b3bbf7de7a367c2bc5d97f7f8b80ba0c. Director independently viewed its actual pixels. It controls exact fixture silhouettes and support contacts. Original guide motel_legacy_geometry_1800x860.png, SHA-256 11f6a92e1d3e9411f3381b1a5f4e4e506d0d4a39dfeee45f59335715e81cc5d6, is preserved.
2. Own facade: assets/art/travel/exteriors/motel.png, SHA-256 f594d19f7fd33623a5b1564866f9bde2aeed1ece4bbdb76628a3ad4598236326. Matching backdrop SHA-256 6c809d997c1b29329ba3928b786386c943358d4934016147f3a3f27c4f620ee7.
3. The owner's supplied preferred pixel-art design and accepted Gas R12 establish decisive local color ramps, hard contours, sharper clustered texture and bright contrasting accents. Use these as construction/style references, not Gas brick patterns, gold cage, columns or floorboards.
4. Approved Delta Queen facade is a secondary detail/material-craft reference.

Use crisp clustered painting at the fixed 900 x 430 board, delivered as opaque 1800 x 860 pixels. Preserve fine material detail, but group it into intentional cloth, wood, plaster and metal clusters rather than photographic noise. No global quantizer, blanket desaturation, blurry brush texture or broad dark wash. Preserve all generated originals; exact nearest-grid fitting and assembly are permitted.

## Fixed geometry and interpretation

All coordinates are board units; native textures are double.

- Visual wall/floor boundary y246. The placement floor band starts 244; do not confuse the band with the visible horizon.
- Window/sign outer frame [42,56,242,168], inner dark glass [62,72,202,116], existing MOTEL wordmark.
- Existing door [260,84,86,126], inset [274,98,58,112], small glass [282,112,42,72] and amber handle [324,142,6,6].
- Curtain bay [288,44,324,192] with its existing posts and vertical folds. Curtains are fabric, not security bars.
- Large existing [96,224,452,72] mass becomes a low faded waiting banquette/upholstered bench in the SAME footprint. The legacy bedspread/bed_foot_rail names do not authorize a bedroom. No pillows, sheets, new bed, extra rail or extra furniture.
- Main mapped table/front [370,176,260,52], counter ID motel_lobby_table, exact opaque PNG 520 x 104. Mapped width 260 takes precedence over old procedural width 258.
- Right merchandise front [700,246,170,40], counter ID motel_merchandise_counter, exact opaque PNG 340 x 80.
- Low support [450,286,224,38], with thin contact edge at286 and legs [466,324,12,48] / [646,324,12,48]. It is empty for current live items, not a baked telephone.
- CRT case [664,106,146,112], display [680,122,114,68], existing lower trim [686,196,102,10].
- Narrow existing vending/display body [742,58,54,146] overlaps the right CRT area. Preserve both silhouettes and their established depth rather than moving the appliance to improve a new composition.

Keep room passages, existing returns/exits, curtains, physical support surfaces and all current live geometry unchanged. No new camera, room board, scenario bed, clerk, caller, sale stock, phone, cards or other duplicated live props in the background.

## Clean-target annotations

Remove frozen CRT white diagonals, generic colored vending rectangles, coarse pink upholstery patches and lower marker dashes. Keep appliance frame/glass and the complete upholstery/support mass. The source upholstery marks use sin(x), not time; no lobby bedspread animation is required. Generic card backs are already omitted from the guide and must stay absent.

The short angled pink stroke near the door may become restrained physical painted door-header trim, not a luminous security ray. New material detail can restore believable weave, scuffs and seam shadows without copying the guide's flat placeholders.

## Live anchors and label-safe real materials

Read current placement_surfaces.json, effective developer_placement_overrides.json and actual runtime layouts. Effective override SHA-256 c5c9808497ee3d4f056bb5a7f24a64524d4e59ee50e3fff106eb41e09383245f must remain unchanged. base_saved:false does not make its slot_positions inactive.

Current examples: Phone [388,176], front-desk staff [448,202], June [764,272], Marco [224,229], drink [715,189], Numbers [837,258], lender [406,366], shop contacts [633,285]/[560,285]/[487,285]/[592,173]. Event staff may stand [522,208]; owned-room return is near[302,150]. These examples do not replace all scenario overrides or measured label rectangles.

Plan for the UNION of base, settled scenarios, work phases and outcome actors:
- Low item-support face is dark, with a genuinely thin teal/cream edge, not a broad bright stripe behind gold names.
- Plan quiet curtain material for the pink Phone name, and a dark staff front for gold names. Use a pale material split only if measured CURRENT settled label bands justify it; do not assume the Phone title sits on the front. The current strict-c5 settled preflight confirms Base Phone name[344.3,111,87.4,15] on curtain, staff gold name[413,204,70,15] on the main front and Drink name[677.1,124,75.8,15] over the upper CRT. In all four initial scenarios Phone shifts to y98; scenario staff names often occupy y113 on the curtain, and Conventioneers Drink moves to y98. Current source-bound metadata, not old p9 diagnostics or anchor guesses, is authoritative. Avoid repeating Corner's broad pale staff-face washout.
- Right front, CRT bezel and lower curtain material should remain quiet where drink, Numbers, June or scenario names cross.
- Compact screen/practical cores should not fill measured name bands. A small art-only relocation within the same housing may be used if actual evidence shows a collision, without moving the fixture or label.
- Keep material boundaries architectural. No floating label-sized plaques or broad screen darkening without an actual need.

The current production Drink footprint covers much of the CRT's left glass while the existing narrow vending body covers its right. Current strict-c5 metadata and actual app images verify this relationship. The live Drink model rectangle is a conservative envelope, not a solid opaque block: its procedural sprite naturally occludes later-drawn pixels only where it actually paints. Begin with dark CRT phosphor/glass and compact detail, then measure the exact current settled labels. Luminance and scan can be masked or translated to visible portions of the SAME existing glass/bezel when necessary, retaining both meaningful motifs without a bright white-noise wash, new fixture or hidden-motion metadata pass. The overlapping vending/display body is part of the background, not an opaque foreground counter. Therefore later CRT animation does not automatically stay behind it: author an explicit visible-glass alpha mask that excludes the cabinet silhouette. This physical occlusion correction is approved without renderer changes.

## Required motion and explicit translations

Read the room drawing function, scene-life branch and shared helpers, not only one list. _cycle_color seed choices and the static upholstery pattern are not motion.

- Pink MOTEL/window-sign breathing within the existing glass; preserve the additional small pink band [82,118,150,8] as a deliberate local sign-light treatment.
- Ten thin CRT luminance rows [684,126+6i,106,2]. Integer i means they share a one-second luminance ramp; do not invent ten independently phased fluorescent fixtures.
- A DISTINCT fast CRT scan within x680..790, y126..188. The source helper uses endpoints, not width/height; original speed8 translates to roughly160 board units/second.
- Three restrained cyan glass/hardware glints from [420,148], [524,154], [746,194]. Keep them physically motivated on visible existing material; they may adapt to nearby trim/glass without moving contacts, inventing props or punching holes in opaque fronts.
- Seven restrained moving reflected-light assets on the matte floor in this room's amber/pink/teal palette.

The director explicitly approves those seven floor movers as a consolidated interpretation of shared sheen plus the older lower reflection/bob/stripe family. It is not a request to render a wet floor or literal neon dashes. This consolidation does not waive separate CRT luminance, scan, sign or glass motion.

Use existing renderer primitives only. All authored motifs must visibly move in actual production pixels and remain stable under the supported Reduce Motion setting. No preview-only boost or renderer change.

## Current R3 measured material refinement and scope

The generated source keeps the facade-local rose/teal/honey palette and the public waiting-banquette interpretation. Its floor and fixture drift were fitted to the frozen target; a matching same-scale matte floor plate supplies exact depth at y246 without vertical stretching. No extra furniture or duplicate live stock was introduced.

The first real trial showed two bounded material weaknesses. R3 changes ONLY:
- The first existing back-cushion face y225..263 becomes low-value ink-plum, preserving source weave, wine seam/piping and a thin top row 224. This supports Base/scenario pink Parking names and Wedding's gold Best person, which shares the same physical panel. A pale patch was deliberately rejected because it could wash out the gold name.
- The low support retains a single bright teal contact row 286; the actual lip y287..289 is dark so gold item-name upper strokes are complete. The existing dark wood face and geometry remain unchanged.

Exact current package SHA-256: 4b22c9cfda8ad88f0d989b544c50cc84efd4fc290583a3e87464f9963821b971.
Background SHA-256: b23d84e7a320189a5343cd2be2b1655d58f2c54e4c8e27d8943af8a7ed164fb0.
R2 is preserved as an honest trial; these are not edits to handed-off source bytes.

The current package has 14 authored motion entries. CRT luminance uses one synchronized 16-frame atlas for the original row family, while the fast scan is distinct in a bounded 31-frame atlas. Both alpha masks exclude the static vending silhouette and the relevant gold title band; the live Drink body is not erased as a whole rectangular mask. The first two cyan glints are restrained reflected-light changes on existing curtain fold edges, not glass stars or new props.

Director actual visual review now covers Base plus all four naturally settled initial scenarios: Conventioneers, Stakeout, Wedding Overflow and Weekly Rates. The dark cushion improves both pink Parking placements and preserves Best person gold; the thin lip improves lowdesk names. Phone and scenario staff remain readable on the honey curtain. Room Nine Door is lower contrast over a narrow rose-plaster gap but remains readable with its actual outline; no broad curtain/plaster grade is requested.

This is NOT final package PASS. Full per-entry actual-composite motion, both replays, published work/outcome contexts and all remaining native receipts are still final gates. TEST/Web identity, browser visuals and UI/save/revisit end-to-end coverage are separate and must not be inferred from these initial views.

## Package, source and acceptance sequence

- One opaque 1800 x 860 background; mapped opaque 520 x 104 and 340 x 80 fronts; separated motion textures; room manifest data/art/environments/motel.json.
- Keep sources, inputs, prompts and each handed-off candidate immutable with exact paths/hashes and a new version for every correction.
- Start with one coherent guide-aligned room source. A separate floor plate is justified only if the returned source lacks adequate exact-grid floor depth; do not pre-generate or stretch by default.
- Independent static review must measure all contacts and check upholstery, curtains, appliance overlaps and both fronts.
- Early actual full-room 10-12 second preview, with every authored motif shown through faithful crops and a crisp actual PNG. Inspect normal min/peak and supported Reduce Motion states.
- Before final native PASS, verify all current Motel scenarios and relevant authored work/outcome families with natural settled arrivals and the same production membership/presentation boundary.
- Assert actual canvas objects, debug geometry and nonempty label rectangles for each room-visible authored visual; declare hidden/non-room exclusions. Authority membership alone is not visual proof. Validate selected production interaction labels rather than assuming semantic labels always win.
- Check geometry/hits/labels, both counter replays, per-entry motion, floor wrap, Reduce Motion, no-input liveness and converted-preview visibility.
- Only the exact passed package may be integrated into the existing art branch, retaining all earlier accepted packs. TEST/Web identity and browser visual review remain a separate post-integration gate.
- Checkpoint readable direction, sources/recipes and review state in GitHub without enabling unapproved art.
