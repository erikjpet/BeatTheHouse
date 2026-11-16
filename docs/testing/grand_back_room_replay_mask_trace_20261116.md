# Grand Back Room: furniture replay and fixed-contact trace

Date: 2026-11-16. Task: BTH-ENV-SPATIAL-GBR-001. Scope: read-only technical support for the owner's first composition correction. This note is not visual acceptance, candidate approval, a new renderer implementation, or permission to reuse an old qualification for changed artwork. The owner rejected the shelf/platform composition. Full-height physical bodies and a believable deeper floor still require composition work and populated review.

## Result

The existing production path can draw taller, furniture-only foreground replays without changing interaction geometry or animation scheduling. A counter manifest entry already supports `bleed: [left, top, right, bottom]` in board units. The compiler expands its art rectangle; the foreground painter draws that expanded rectangle without clipping it back to the old counter front. PNG alpha is retained. Thus a correctly registered opaque furniture silhouette can cover floor glints on solid furniture while transparent gaps leave the animated floor visible.

This is conditional technical feasibility. Increasing an opaque crop would cover a rectangular floor area and reproduce the depth error. The proposed inputs must instead carry a physical silhouette: opaque furniture, transparent floor and under-table openings, with explicit treatment of the OFFICE foreground and the silver floor strip. The renderer does not infer any of those relationships from the picture. No source, art, manifest, cache, animation, placement, QA workspace, or runtime was changed for this trace.

## Evidence identity and coordinate systems

Current room is `grand_casino_back_room`, not Grand public, High Limit, or Private Crew. Its current production background and manifest match the retained populated v3 capture project byte-for-byte:

| Input | SHA-256 |
| --- | --- |
| `assets/art/environments/grand_casino_back_room/background.png` | `46492785829f659c5869d91a6510d424ea4977e6921b1ece7de1225aa804e6ca` |
| `data/art/environments/grand_casino_back_room.json` | `cc8553a5856289c7fe6b42754db43b4bd02d07e5c793ca1fea54e7655eca103d` |
| `counters/grand_table_left.png` in that art directory | `9a96841d98e0f5ee53d15563c94881f3ce34ab4569182f7009f6b0609c4dafac` |
| `counters/grand_table_right.png` in that art directory | `de3a5e82cce15772a929306eb423aaf44b96ff3302cf8c73aec1eb12b7dc0964` |

Retained project: `E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GBRTRIAL-20261116/qa_source`, source commit `a9c02a9557abfd644b27f36be392d354fc70c6ef`, tree `edcf685c282567daa2bb82a6ba49d818e5950ed6`.

Actual full-app populated frame viewed:

- `E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GBRNATIVE-20261116-v3-capture/evidence/capture/frame_000.png`
- SHA-256 `31b4d60aa78f1a9da2bf87bdc0e7f2e25f2565e691738475b733950f48055f76`, 1280 x 720.
- Capture JSON beside it: `animation_capture.json`, SHA-256 `3342ed79ece4a408f567cfae8afbdab01bd1612d441a623e24ed2086e8908afd`.
- Capture phase receipt SHA-256 `562f8f45b8b04db9be2daef0e4da47b2d90c643675bd7408ac4c6ca67c579cd8`.
- First recorded clock `8.45244366666685`. Canvas-local board display rect `[18.3720703125, 0, 1243.255859375, 594]`, scale `1.38139534883721`, camera zoom 1 and offset zero. Full-app content starts at y126.

Board coordinates below use 900 x 430. Native art uses 1800 x 860, exactly two native pixels per board unit. Full-app screenshot coordinates are a third coordinate system and must not be substituted for either. Rectangles are `[x,y,width,height]`; alpha-envelope bounds are `[x0,y0,x1,y1)`.

The viewed Base frame contains Blackjack, Craps, and Leave, with no people. It demonstrates the current populated game composition, but cannot establish human-scale leg height or future NPC/body visibility by itself.

The current D `environment_art_pack.gd`, `environment_art_renderer.gd`, and `pixel_scene_canvas.gd` have different byte hashes from retained E solely because of CRLF/LF. Direct comparison after replacing CRLF with LF was equal for each of those three complete files. The game painters, placement implementation, placement map, and saved developer overrides match the retained project byte-for-byte. This is a narrow code bridge for these inspected files, not certification of an arbitrary current-HEAD project or of every project dependency.

## Manifest, raw counter authority, and art expansion

The current counter manifest has only texture paths, with no explicit rect or bleed:

```json
"grand_table_left": {"texture": "counters/grand_table_left.png"},
"grand_table_right": {"texture": "counters/grand_table_right.png"}
```

`scripts/ui/environment_art_pack.gd:611-634`, `room_counter_rectangles`, reads the raw placement-surface authority and maps counter foreground art IDs. It constructs the rectangle from `x0`, `top_y`, `x1`, `front_y`. It does not read saved slot-position overrides.

| Counter ID / foreground art ID | Raw board rectangle | Existing native PNG / master crop |
| --- | --- | --- |
| `left_table` / `grand_table_left` | `[82,258,272,36]` | 544 x 72, master `[164,516,544,72]` |
| `right_table` / `grand_table_right` | `[546,258,272,36]` | 544 x 72, master `[1092,516,544,72]` |

Both current replay PNGs are entirely opaque and exact crops of the opaque final master. Their bottom edge is native588 exclusive (board294). That is the old narrow apron replay contract, not a renderer requirement that furniture must stop there.

In `compile_manifest` (`environment_art_pack.gd:406-459`, counter block434-458), line443 accepts `bleed`, default `[0,0,0,0]`. All four components must be finite and nonnegative. Lines449-450 apply `grow_individual(left,top,right,bottom)` to the raw art rectangle. `_texture` (576-607, dimensions596-600) requires PNG dimensions equal the expanded board size times two. The texture loader has no all-opaque predicate and preserves PNG alpha. `_board_rect_valid` (690-691) requires a positive finite rect intersecting the board; it does not guarantee the whole expanded rect is inside it. A future input proof should require the intended bounds, rather than relying on this weaker parser condition.

For a bottom-only bleed `b` in board units:

- Left becomes `[82,258,272,36+b]`; right becomes `[546,258,272,36+b]`.
- Each PNG becomes `544 x (72+2*b)`; native origins remain `(164,516)` and `(1092,516)`.
- Bottom is native `588+2*b`, exclusive. An exclusive end at700 means `b=56`, PNG height184. To include native row700, use at least exclusive702 (`b=57`, height186) if retaining integer board/NN2 alignment.
- General bleed `[L,T,R,B]` gives board origin `(x0-L,258-T)`, size `(272+L+R,36+T+B)`, then native x2.

These are registration equations, not a selected leg length, foot position, or composition. The compiler accepts fractional bleed, but a new NN2 pixel-art mask should explicitly prove its chosen block alignment. Enlarged dimensions without bleed fail the expected-dimensions check; bleed without matching PNG dimensions also fails. Changing `placement_surfaces.json` or its `front_y` to enlarge artwork is unnecessary and risks changing another authority.

Room packs are cached by room ID (`environment_art_pack.gd:120-152`); `_set_environment_art_pack` can retain the same instance. A later preview must demonstrate a fresh import/load or the supported reload path. Merely editing a PNG while viewing an old cached pack is not proof of the correction.

## Draw path and the exact occlusion that alpha supplies

`environment_art_renderer.gd` draws the opaque background (21-26) and environment animations (36-74). `configure` (77-108) sets the native 1800 x 860 viewport/nearest scaling; `present` (120-126) uses the normal clock and redraw path. This renderer output contains background plus animations, not live objects or counter foregrounds.

`pixel_scene_canvas.gd` then composes the full room:

1. `_draw` (3919-3992) draws authored environment output through `_draw_environment_art_animations` (4033-4037; call3930).
2. It draws `_draw_authored_counter_foregrounds()` at3980 even when no behind-counter NPC exists.
3. `_draw_scene_objects` (5394-5431) draws Behind bodies, replays foregrounds required by those bodies at5421, then Standard bodies at5422, Front bodies at5424, and all labels/adornments last at5427-5428.

`_ensure_room_surface_draw_cache` (2569-2592) caches raw surface/counter dictionaries; foreground replay order is sorted art/counter identity, not inferred image depth. `_draw_counter_foreground_art` (8821-8833) checks that the raw front has area, then uses `draw_texture_rect(counter_art.texture, counter_art.rect, false)`. It does not clip the expanded compiled art rect back to the raw front. `_draw_room_foreground_occluders` (8794-8812) selects supporting counters for actual Behind objects and draws the same helper.

Consequences:

- Alpha255 furniture redraws over an environment glint; alpha0 holes/floor reveal the already composed background and animation. This changes spatial occlusion, not the motion clock, glint count, or scheduling.
- The same alpha also occludes other environment animation underneath it. It is not a selective floor-glint filter.
- Full opaque floor-colored rectangles would hide glints over open floor. Alpha0 is required for those exposed regions, including floor around/between legs. Keep contact-shadow floor in the background rather than making an opaque floor patch in replay.
- Opaque replay RGB should match the same final master at its registered coordinates. That correspondence alone is insufficient: a mistaken strip painted through a leg in the master remains a depth error even if replay RGB matches it exactly.
- Current three Base objects are Standard0 and paint after replay. Enlarging the replay does not move or mask their hit geometry. Behind NPC lower bodies can be masked by replay; future floor-object visibility must be proven in actual populated contexts. Geometry independence does not establish unobscured visible bodies.
- A raw native-art/board2x capture of renderer output cannot prove the final foreground glint occlusion. Use the actual full app or the full production board900 composition with the counter replay pass.

No canvas scheduling/performance changes are proposed. Existing no-input redraw, reduced-motion policy, placement-overlay liveness, and game-surface redraws remain release gates.

## Live contacts are saved slots, not nominal map coordinates

`environment_placement.gd:171-181` supplies the placement authority; `_with_runtime_slot_geometry` applies saved slot geometry at388-390. `pixel_scene_canvas.gd` obtains model geometry at8111-8155 and fixed game geometry at8133-8137. The Grand-public-only visual enlargement at8207 does not apply to this room. `_interaction_rect_for_object` (8337-8350) and `_board_rect_for_object` (8308-8334) do not consult foreground PNG alpha or bleed. Art and objects share the board/camera transform (`_scale_canvas`,4198-4201).

The raw map nominal left/right contacts are `(218,258)` and `(682,258)`, with hit rects `[182,210,72,48]` and `[646,210,72,48]`. These are not the retained actual game contacts: developer slot overrides put left at `(214,248)` and right at `(680,247)`.

Actual native layout from capture3342:

| Actual object | Draw and hit rect, board | Fixed bottom contact | Label rect, board | Slot / layer |
| --- | --- | --- | --- | --- |
| Blackjack | `[178,200,72,48]` | `(214,248)` | `[181.899993896484,183,64.1999969482422,15]` | `fixed.game_table_left`, Standard0, z0 |
| Craps | `[644,199,72,48]` | `(680,247)` | `[656,182,48,15]` | `fixed.game_table_right`, Standard0, z1 |
| Leave | `[4,354,64,72]` | preserve existing | `[16,337,44,15]` | existing travel object |

Blackjack footprint is `[170,192,88,64]`; Craps footprint `[636,191,88,64]`. Existing saved floor/event positions, lanes and the exit must also remain unchanged. The logical floor band is `[16,246,868,184]`, contact_y258..430; it does not need relocation merely to paint a deeper visual floor. The public lane is board x64 ->450 ->836 at y358 with clearance8.

## Actual production paint excursions

The game-body dispatcher is `_draw_scene_object_body` (5434-5465), then `_draw_game_prop` (9698-9744). Craps calls `CrapsRoomPropScript.draw` at9725-9726. Its own painter (`scripts/ui/game_props/craps_room_prop.gd:17-66`) derives its safe/felt/dice/stick geometry from the fixed game rect. Blackjack follows the card-table branch9736-9743: cards at offsets `26+i*28`, `6+(i%2)*6`, size20 x28, plus its existing icon. The third card extends to board x280, 30 beyond the model/hit rect's right edge250. `_draw_interactable_light` (5304-5312) and `_draw_object_shadow` (8782-8791) add translucent excursions. A rect-corners-only tabletop test misses these painted pixels.

Actual retained diagnostics use the unchanged production dispatcher on a transparent canvas, with geometry_equal=true, source/route clock `4.18733174603174`. Directory:
`E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GBRNATIVE-20261116-v3-contexts/evidence/`.
The metadata file `__none_metadata.json` in that directory has SHA-256 `d60c2b0c127ffda44ef2e2887d889f4bed395d41a820af79158b843597a1276c`.

| Actual PNG | Nonzero-alpha native bounds | Nonzero-alpha board bounds | Alpha255 board bounds |
| --- | --- | --- | --- |
| `__none_host_0_body.png` (Craps) | `[1294,403,1426,498)` | `[647,201.5,713,249)` | `[649,204,711,235)` |
| `__none_host_0_adorn.png` | `[1300,370,1420,496)` | `[650,185,710,248)` | none |
| `__none_host_1_body.png` (Blackjack) | `[356,391,560,500)` | `[178,195.5,280,250)` | `[178,200.5,280,240)` |
| `__none_host_1_adorn.png` | `[368,370,488,498)` | `[184,185,244,249)` | none |
| `__none_host_2_body.png` (Leave) | `[12,710,132,831)` | `[6,355,66,415.5)` | `[15.5,404.5,56.5,407.5)` |
| `__none_host_2_adorn.png` | `[17,680,127,849)` | `[8.5,340,63.5,424.5)` | none |

These are actual pixels at one retained state/clock, measured by decoding existing PNG alpha in memory; no new render was launched. Body shadows and adornments are not all game-face support pixels. Future tabletop support and non-obscuration proofs must use the appropriate actual masks and additional relevant states, not treat every alpha bounding box as felt coverage. This note does not claim exhaustive hover, selection, game-state, scenario, or future-actor paint coverage.

PNG SHA-256s, in table order:

```text
00796388634d8a17b03db46d2f1eb1c3bf3fd1916b9058b056e28ff3abc999e2
ce3346ab23b7c7c964eb9610cba8e57000bece61e0eeb3fe4a243d9b530c8a20
9f4dac08430771743a540d112b014616c13fa06d968a75840eae41a2f40a88a9
0c1361b7664e6d1b28d32169d9befd23c7cdd340241f2e7f86ac780274f6836f
9e48e21dc14348a228fe4dac02a90453c45769df952f76f0b558f43649efc439
8dc5d8c5c33d86604d6226a735ecbf73004c5f0c5e846047e8e079a10f422ce5
```

## OFFICE and floor-strip depth are composition constraints

The room's procedural source (`pixel_scene_canvas.gd:4898-4935`) places table modules at x82/546, top y206, inner felt y214..258, old apron y258..294. It places the OFFICE body at board `[344,318,212,48]`, inner panel `[364,330,172,20]`, and feet from `(370,366)` toward `(364,394)` and `(530,366)` toward `(536,394)`. It also places a silver strip `[72,302,756,6]` (native y604..616) and gold strip `[96,398,708,6]` (native y796..808).

OFFICE is baked architecture, not one of the two replay IDs or the three current live objects. It therefore does not get an automatic separate depth layer. A leg reaching native680..700 crosses the silver strip; the solid leg must actually occlude it in the final master/replay. The OFFICE body/feet must remain in front where composition requires. Because the existing table x spans82..354 and546..818 narrowly overlap the OFFICE x span344..556, a long table-body replay can overwrite OFFICE edge pixels if its mask is derived as a simple rectangular or isolated-table cutout. Require a visible-furniture mask with OFFICE foreground excluded at any real overlap. Preserve near gold-floor inlay and all non-table originals outside the explicitly approved composition region.

This trace does not select a new vanishing point or claim that longer legs alone solve the shelf impression. The fixed game paint envelopes and full-room perspective must guide the tabletop and body design together.

## Animation contract to preserve

Current manifest has 16 native motions, seven marked low-detail: `casino_light_1`, `casino_light_2`, `casino_light_3`, `casino_sign_pulse`, `floor_glint_0`, `floor_glint_1`, `floor_glint_2`. All seven floor movers remain present in normal detail; low detail retains the first three. They use `still:"hide"`, additive blend, opacity0.08, and x travel -90..950.

| Glint index | Board y | Size | Duration | Phase | Low |
| --- | --- | --- | --- | --- | --- |
| 0 | 274 | 72 x2 | 57.77777777777778 | 0.0 | true |
| 1 | 288 | 68 x2 | 50.73170731707317 | 6.682926829268292 | true |
| 2 | 302 | 64 x2 | 45.21739130434783 | 11.91304347826087 | true |
| 3 | 316 | 60 x2 | 40.78431372549019 | 16.11764705882353 | false |
| 4 | 274 | 56 x2 | 37.142857142857146 | 19.571428571428573 | false |
| 5 | 288 | 52 x2 | 34.09836065573771 | 22.459016393442624 | false |
| 6 | 302 | 48 x2 | 31.515151515151516 | 24.90909090909091 | false |

The SHA-pinned full JSON is authoritative for exact numeric bytes. No deletion, mover clipping, count reduction, timing edit, input-gated redraw, or motion suppression is a solution to furniture occlusion. Larger alpha replays should be tested at phase-accurate solid-body and open-floor samples while preserving all existing liveness laws.

## Frozen old gates that cannot qualify changed physical inputs unchanged

The following old assumptions are explicit, not silently waived:

| Frozen source / exact lines | Prior law | Why a new physical-input proof is required |
| --- | --- | --- |
| `tools/assemble_grand_back_room_spatial_candidate.py:54,241,249-259` | Fixed544 x72 crops; changes y<602; generated body/support bounded below588, complete feet/maxy587 | A genuinely taller body exceeds those selected old geometry bounds. Preserve the old proof and create a new bounded composition/source/mask contract. |
| Same assembler429-440 | Entire foreground is an opaque exact crop; fixed allowed targets/membership | A furniture silhouette with floor holes is not an opaque rectangular master crop. New targets/dimensions/manifest deltas need explicit custody. |
| `tools/assemble_grand_back_room_spatial_candidate_v2.py:165-171` | Foregrounds remain opaque master crops and identical to predecessor; only BG may change | Enlarged alpha foregrounds and bleed cannot meet that unchanged-input law. |
| `tools/grand_back_room_spatial_native_profile.py:33-40,173-205` | Exact prior candidate/proof/review/recipe/producer, nine PNG+JSON targets, manifest only lamp2 x450->448 | New two bleed fields/dimensions/masks are a new candidate; preserve motion entries and explicitly authorize only the intended additional art-input changes. |
| Same profile209 | Full background is opaque1800 x860 | Retain this gate. Foreground transparency does not require a transparent master. |
| Same profile230-235 | Fixed counter dimensions, full RGBA equality to opaque master crop | Replace for the new inputs with binary physical alpha, registered on-mask master RGB equality, alpha0 floor/holes, NN2/block and independent silhouette/depth proof. Do not claim the old whole-RGBA-crop gate passed. |

Frozen predecessor package is `e20695c6715e4156027cc211b6c7291ff2820e3d52d317dbbfc9b6cc5ca931c7`. No old candidate, assertion, receipt, or review is relabeled by this note.

The old runner also has an independent source-base constraint: its `prepare_worker:188` requires the archive raw baseline seal to equal the original065 baseline. A current committed source already containing activated e206 art will not pass that unchanged predicate. The complementary preview-path note documents this routing issue. A future preview must truthfully bind chosen source base S, the new sealed overlay and current production-code bridge. It must not monkeypatch an old approval/config or call a retained a9 archive current HEAD.

Original context observer:
`E:/CodexQA/BTH/workspaces/BTH-ENVART-GRANDBACK-TRIAL-20261115/tools/envart_grandback_preart_metadata.gd`, SHA-256 `7f6750153fad8f18ddde9f811ab9cec8946afe96656e23009fa44c7192e4a3c1`.
It checks source hashes at68-74, opens actual MainScene75-101, allows natural arrivals, saves actual full-app PNG at187 before diagnostics, and rehashes at208-218. It does not contain an opaque-mastercrop predicate. `_paint_hosts` uses typed native actual objects; its geometry JSON comparison at287 is not a serialized target passed to the painter. The architecture diagnostic helpers are `ArchitectureCanvas:309-330` and `_source_background:332-343` (including authored counter replay mode2 and procedural architecture+replay mode3); do not invent a `_source_replay_images` API or mistake procedural architecture-only diagnostic images for the final authored master. New input qualification remains necessary before this observer can be reached through the frozen adapter.

## Required next bounded proof, not work executed here

1. Parent-selected, owner-reviewable full-room composition and new final master. Preserve exact game contacts/paint, camera, labels, door mappings, original motion and placement authorities. Do not bake live actors, game faces, or labels into replay.
2. Exact chosen two-counter bleed/dimension/registration equations; only approved pure-art manifest fields differ. All16 original motion dictionaries and seven-low membership remain byte-equivalent in content. Protect all other room/control files.
3. Independently traced visible furniture silhouettes: binary alpha255/0, NN2 alignment, complete intended legs/feet, no opaque under-table floor rectangle, no halos, no omitted body, and explicit OFFICE/floor-strip overlap law. On-mask RGB must equal the same final master; opaque-master and untouched exterior proofs remain.
4. Actual populated composition with full game paint and relevant actor contexts, then phase-accurate glint samples over both furniture and exposed floor in normal/low/reduced modes. Current Base contains no people and one-state alpha envelopes do not qualify all later visibility. Keep no-input and placement-overlay liveness intact.
5. Fresh admitted QA source/install/import identity and current alpha/dimension/UID checks under the repository storage/guard rules. New physical inputs need their own proof/policy/review, not a relaxed old receipt. No new preview or runtime was launched for this note.

Complementary setup/dependency note, owned by `/root/review_test_adapter`:
`docs/testing/grand_back_room_composition_preview_path_20261116.md`, SHA-256 `5adfc6cfd63c40f91aa641f83b86083a150cd0321783a1a7a02ad885381dbd28`.

## Source hashes for reproducible reading

All D paths below are relative to `D:/Projects/Beat-The-House/.tmp/environment-art-layers`.

| Source | Current D SHA-256 |
| --- | --- |
| `scripts/ui/environment_art_pack.gd` | `067cf5f9673bd85705f4971e9c4db70aaafcfe1cec912b926ed9edc685fb5d8f` |
| `scripts/ui/environment_art_renderer.gd` | `900b44af05602f6259eed0a2cb33a45d1899cb30bd71aaaed5a744bcc9ccad96` |
| `scripts/ui/pixel_scene_canvas.gd` | `c2ce2abee8827372d66fd6c9647a74e06f5db8fed520bbd812b8c7eb29f4af38` |
| `scripts/ui/game_props/craps_room_prop.gd` | `9c53698831fa0c7a1ce56592f0098d3774a71e01e02202ed93c6808da0261b9c` |
| `scripts/ui/game_props/game_prop_kit.gd` | `1417c1f2472f247c1ddf1a3db678acac1338588293b85bba6adef097c6c65ea4` |
| `scripts/core/environment_placement.gd` | `f0b4661ef896c13d939713b2b4bdf3ebc4d22a29b4d15611c726ba5d13de39f6` |
| `data/environments/placement_surfaces.json` | `9caa123fb96816777328ad88f022fe05defb74ef5b4f645b7a15bcac67c25cf1` |
| `data/environments/developer_placement_overrides.json` | `c5c9808497ee3d4f056bb5a7f24a64524d4e59ee50e3fff106eb41e09383245f` |
| `tools/assemble_grand_back_room_spatial_candidate.py` | `2dc30990563c5881b9b7546e306cbf1479867e20275ffee8d4cc342a94156ac3` |
| `tools/assemble_grand_back_room_spatial_candidate_v2.py` | `9ed6c29917c74cdecb044e9639271af631a65e7268ce6015b3b881f50ea6474d` |
| `tools/grand_back_room_spatial_native_profile.py` | `c34375889ac8e35f8852c724cbe0e801d5c181920c9fae7583883583a21cb594` |

Retained E byte hashes for the three line-ending-only differences: pack `442cd86c6e9172f9830cdc94e5aa00ba39bbebde7427db94a0e4bbb896e83d0b`; renderer `9c69c3ddb3e33abe3a30864ee857467ea6cabd47b2918316507e00c447582a72`; canvas `695359df463096a612c093160ab08169aa8aafe2729e16a400745e6375b1b0b2`.

Status: technical trace complete; composition, new masks, changed-input qualification and visual acceptance remain open. Parent owns the task ledgers and any implementation/runtime decision.
