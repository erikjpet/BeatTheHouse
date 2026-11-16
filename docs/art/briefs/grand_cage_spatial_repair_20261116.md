# Grand Cage spatial source audit — 2026-11-16

Task: `BTH-ENV-SPATIAL-CAGE-001`; room/art key `grand_casino_cage`.
Owner of this bounded audit: sidebar agent `/root/high_limit_source_trial`.
Parent/runtime owner: `/root`, task `6afa5098-a83c-8191-9486-9c03c92ed02a`.

Status: SOURCE_PLAN_FOR_REVIEW. No candidate, generation, code, production art,
manifest, placement, runtime, QA job or TEST change is made by this audit. The
only authored file is this new brief. Parent owns the task ledger and any later
approval, guarded assembly, native qualification and TEST delivery.

## Disposition and proposed scope

The current R2 teller is a built-in cabinet with a continuous front, rather than
a freestanding tabletop that needs legs. Its existing top at board y260 and
front/base at y316 sit on the room's floor starting y250. Current raw art and
retained populated R2 Base/stock views show its continuous gold-edged lower face
and dark base against that floor. The backing and barred windows are separate
from the lower cabinet. Queue posts start y320, only four board pixels beyond
the cabinet base; speculative new feet would crowd that existing arrangement.
No specific unsupported surface, new floor-plane discontinuity or counter
geometry defect was demonstrated in these inspected views. Preserve the current
cabinet, floor, gift case, ATM, return door, queue, ledger and replay byte for
byte. This is a bounded source disposition, not fresh runtime acceptance for
all possible populations.

One actual defect is confirmed: `cage_sign_pulse` has positive alpha over its
entire rectangle and an unrelated bright horizontal stripe below THE CAGE.
That rectangle also overlaps three board rows of the cyan soffit stripe. A
source-derived, glyph-only alpha cut is the proposed next candidate. It requires
no image generation and no background reconstruction. Review this plan before
writing that candidate or its helper.

## Source identity and custody

Coordinates below use the 900×430 board unless stated native. Current package
images are native nearest-neighbour 2×; all 22 current PNGs were read-only
decoded and have zero non-uniform original 2×2 blocks.

| Current input | SHA-256 |
| --- | --- |
| `assets/art/environments/grand_casino_cage/background.png` (1800×860, 436255 bytes) | `9c6f7bb773711b56fbdbddd65d1318342df397ef0130b83c1565784757c7a2f7` |
| `assets/art/environments/grand_casino_cage/anim/cage_sign_pulse.png` (464×112, 536 bytes) | `02069bd24cb4abc4fc9ed4cfd0a774bda4ac536499ef2a4e28513b1f06f4faee` |
| `assets/art/environments/grand_casino_cage/counters/grand_cage_teller_counter.png` (776×112, 31545 bytes) | `3af64a745fa97b8261d8ac44146086b5afffee339b6f332fa20841a5a3034e4d` |
| `data/art/environments/grand_casino_cage.json` | `ab70b2d0fc3e7d02a0b8c645cb1b71a0e056e1e63d7d1c029669cbb3f66c1b9e` |
| `data/art/environments/index.json` (current 20-room index) | `11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24` |
| `data/environments/placement_surfaces.json` | `9caa123fb96816777328ad88f022fe05defb74ef5b4f645b7a15bcac67c25cf1` |
| `data/environments/developer_placement_overrides.json` | `c5c9808497ee3d4f056bb5a7f24a64524d4e59ee50e3fff106eb41e09383245f` |
| `scripts/ui/pixel_scene_canvas.gd` | `c2ce2abee8827372d66fd6c9647a74e06f5db8fed520bbd812b8c7eb29f4af38` |

The current logical room set is 24 files: 22 PNGs, its manifest and the current
index. A read-only custody seal is
`dcd9781169080f546281b942773a18f106965d9811b360cc86fe432d0ac62584`.
Its explicit encoding is SHA-256 of sorted project-relative forward-slash paths,
each encoded as `path + TAB + lowercase_file_sha256 + LF`, UTF-8. This is this
audit's custody encoding, not an alias for a previous package-seal schema.

All 23 room-specific payloads match `payload_files` in the retained R2 native
review exactly. Only the global index differs from that historical 17-room
package; that old index SHA is
`cc37982c9bc9b7216134465caf5e4eb6171b71428990351ef5576ef063721b02`.
Do not restore it. Historical R2 package identity
`a228a9e91f6d387fd4790703fa6a2e0038e1df03a92762f3be8cfa9602dace0b`
is not the current 24-file custody identity.

Original generated source personally viewed, read-only:
`E:/CodexQA/BTH/workspaces/BTH-ENVART-ARTIST-20261115/sources/grand-cage-source-r1.png`,
1815×867, 1483078 bytes,
SHA `84324259d5c0a00aac8c76751510bdbbbc6dc7e1ae25c48a0825b854bb4f888e`.
It is historical source, not an activatable replacement for the assembled room.
The current source folder inventory contains no Cage spatial repair trial;
the task ledger is open under the parent above. No duplicate generation was
started.

## Own-room geometry and depth contract

| Structure/support | Exact existing contract to retain |
| --- | --- |
| Teller front | x260..648, top260, front316; `foreground_art_id=grand_cage_teller_counter` |
| Replay | one opaque 776×112 native crop at native [520,520,1296,632), board [260,260,648,316) |
| Replay/source proof | all 86912 RGBA pixels equal the corresponding final-background crop; zero mismatches, all alpha255 |
| Teller backing | source assembly fits own backing to [274,112,356,148], ending y260; procedural fallback's backing height168 is historical, not an instruction to reassemble this PNG |
| Barred windows/slots | windows x286/398/510, y124, 98×112; 18 architectural bars; slots [x+10,218,78,10] |
| Ledger | [464,246,58,10], above the top; preserve its paint and dynamic Linda contact |
| Queue | three posts x296/430/604, y320..370; ropes y330; own source recipe uses separate post/rope masks, no floor rectangle |
| Gift case | [54,124,190,150]; shelf contacts y178/y238; no static EMPTY or shop inventory baked into its glass |
| ATM | wall-mounted [668,116,104,174]; screen [680,132,80,54]; no invented feet |
| Return door | [812,118,70,206], FLOOR sign/handle unchanged |
| Floor | own source floor begins y250; public walk lane [64,358]→[836,358], clearance8; no actor routes authored in this surface record |

The retained own-room recipe, read but not executed, is
`E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261115/assemble_cage_v1r1.py`,
SHA `fbd991ceb439b23fd1fb5a80b0697ee13967d0751963ec688a709ab1c0528998`.
It restores the floor from its normalized own-source crop [0,375,900,430],
nearest-resized to 900×180 at [0,250]. No Grand public/High Limit donor period or
shadow-erasure template applies here. Since no background change is proposed,
the entire floor, its seams, reflections, counter base and separate queue-post
contact pixels remain original. The R2 derivation is
`.../derive_cage_r2.py`, SHA
`412206472e7de550c3053f6800a778d0802b6d8ccb2b0a519f52ab0259c8ff32`.
Its steel-shaft recolour and eleven glint x offsets are already active and must
not be reverted.

Depth source: `pixel_scene_canvas.gd` lines5394..5428 paints Behind bodies, then
the authored counter replay, then Standard and Front bodies, then adornments.
Linda's native draw layer is -1; counter fixture body is Standard, so its live
terminal and text may visibly overlap the counter face by design. Do not erase
that live paint, adjust z-order or move labels to make a source image cleaner.
The replay is also drawn as authored foreground at line3980. Its crop must
remain from the exact same unchanged final background.

## Actual populated anchors and paint excursions

These are retained R2 resolved Base geometry, not the un-overridden defaults in
`placement_surfaces.json`. Current developer slot overrides are Linda [493,247],
counter [494,298], ATM [721,210], Floor travel [849,292], Leave [868,394].
Preserve both authored records and overrides byte for byte.

| Published object | Actual board body/hit rect x,y,w,h | Actual label rect x,y,w,h |
| --- | --- | --- |
| `staff:grand_casino_linda` | 457,167,72,80 | 469,150,48,15 |
| `casino_fixture:cage_atm` | 669,123,104,174 | 686,106,70,15 |
| `casino_fixture:cage_counter` | 431.999969482422,250,124,48 | 444.499969482422,300,99.0000305175781,15 |
| `travel:grand_casino` | 817,256,64,72 | 786,228,98,26 |
| `travel:leave` | 836,358,64,72 | 844,341,40,15 |

The source painter at lines5125..5139 keeps Linda featureless: opaque head,
body, one arm and a translucent accent, with bars repainted afterward. Its feet
come from `rect.center.x,rect.end.y-2` (493,245 here); normal idle Y excursion is
±1.5 from `sin(flicker*1.7+pose_index)`, zero under reduced motion. Pose index is
clamped0..3 and facing only chooses the arm side. Runtime bars x294..610 step15,
y124..236, explain why the typed body diagnostic is much wider than her body.
Generic feet-shadow paint also contributes below the nominal figure, and must
not be mistaken for a new art-support mask.

Read-only actual typed masks are under the R2 contexts evidence directory listed
below. Native half-open bounds and positive-alpha counts (alpha>0, including
shadows, bars and non-body effects) are:

| Host | Body count; [x0,y0,x1,y1) | Adornment count; [x0,y0,x1,y1) |
| --- | --- | --- |
| 0 Linda | 51314; [588,248,1226,504) | 892; [954,304,1018,329) |
| 1 ATM | 27998; [1347,265,1537,531) | 3972; [1361,216,1523,566) |
| 2 Counter | 18858; [874,478,1102,600) | 4678; [895,509,1081,624) |
| 3 Floor travel | 9715; [1618,520,1781,652) | 5567; [1578,460,1762,653) |
| 4 Leave | 8999; [1656,724,1800,856) | 2939; [1681,688,1791,857) |

All ten masks have zero alpha>0 pixels intersecting the proposed 5532 glyph
texels. Counter body/adornment have 13818/4374 pixels inside the existing replay
rectangle; these are genuine live Standard/adornment paint, not permission to
edit that rectangle or a visibility failure. Linda has zero pixels inside it.
These are single retained-clock typed masks, not all-clock envelope proofs.

The Base publishes five objects and five selection captures. There are no
direct Cage scenario IDs in this surface's `scenario_slot_ids`. Other possible
populations include optional Bishop at event slot [620,350], four shop item
slots, runtime delivery/held/contact/live-table reserves. Their absent typed
masks were not invented or claimed qualified. Current shop overrides are
[101,177], [195,178], [102,232], [196,234]; leave their live icons, labels and
individual click targets intact.

## Exact sign defect and proposed material mask

Existing clip is board [334,36,232,56], native origin [668,72], atlas464×112.
Read-only decoded RGBA census is exactly:

- 49376 texels `(255,228,92,46)`;
- 2592 texels `(255,228,92,255)`;
- zero transparent texels, total51968.

The second group is the recipe's local board rectangle x8..223,y46..48
inclusive: native local [16,92,448,98), global [684,164,1116,170). The current
background has no gold emitting material on that stripe. The visible horizontal
line in the populated evidence is animation paint over wall panels. The same
blanket pulse tints panel gaps and the soffit's cyan strip, rather than following
the existing seven gold letters.

Proposed deterministic mask predicate, applied only inside this exact clip to
the unchanged current background's native RGB samples:
`R>=100 AND G>=70 AND 10*R>=9*G AND 4*G>=5*B`.
It selects5532 native texels =1383 complete nearest2× board pixels, global
half-open bounds [700,88,980,134), local atlas [32,16,312,62), board
[350,44,490,67). Its seven four-connected board components correspond in order
to T,H,E,C,A,G,E:

| Letter | Board pixels | Half-open board bounds |
| --- | --- | --- |
| T | 140 | [350,44,367,66) |
| H | 233 | [369,44,387,66) |
| E | 186 | [392,44,405,67) |
| C | 174 | [415,44,432,67) |
| A | 224 | [433,44,453,67) |
| G | 241 | [454,44,473,67) |
| E | 185 | [476,44,490,66) |

Future candidate proposal: preserve all existing RGB bytes everywhere; preserve
the existing alpha46 on those5532 glyph texels; set only alpha to zero on the
other46436 texels. The discarded stripe is entirely outside the selected mask.
No alpha boost, dilation, glow rectangle, new underline, static-word redraw or
colour change is proposed. No other practical exists inside this particular
clip that needs an added mask. Current brightness may become subtle after the
rectangle is removed; fresh real-clock visual review must judge legibility and
motion. Any requested brightness change would require a separately stated
reviewed parameter change, not an implicit opacity adjustment.

## Animation and live-state invariants

Keep the full manifest and index byte-exact. Inventory is20 native /16 default
low detail, each with an individual original texture path:

- Sign: pulse min0.12/max0.24, period0.9239978392911157,
  phase0.9941176470588236, blendadd, stillfirst, lowtrue; same clip and dimensions.
- ATM: [682,138,76,41],32 frames, atlas4864×82,
  fps16.297466172610083, phase0, opacity0.3, looploop/add/stillfirst/lowtrue.
- Eleven steel glints: x299+30*i,y124,w3,h112; pulse min0.12/max0.2,
  period1.7453292519943295, original individual phases, add/stillfirst/lowtrue.
  The +5 R2 x correction relative to old procedural bars is deliberate.
- Seven floor glints: width72-4*i,height2; fromx-90 tox950;
  y274+(i%4)*14, duration1040/(18+2.5*i), phase137*i/(18+2.5*i),
  opacity0.08/add/stillhide. Only i0..2 are lowtrue; i3..6 remain lowfalse.

Only the sign PNG alpha would change. Background, counter, other19 animation
PNGs, all timing, low-detail flags, reduced-motion behavior and PNG2× structure
remain original. No canvas scheduling/render/runtime edits, pointer-dependent
redraws or no-input liveness suppression are part of this proposal.

Keep the EMPTY compatibility behavior introduced by
`f035e1d5ed460aaeac6e9245c4988320203bd839`: the shared live predicate at canvas
lines4995..5004 emits EMPTY at [116,198],size13 only when no unsold stock exists;
packed mode calls it at line3932. Live stock uses the ordinary item renderer.
Retained packed empty/available fixture images differ only in EMPTY semantics;
they do not contain actual reached shelf-item offers and do not prove stock
transactions, Linda lifecycle, save/revisit or live Web behavior.

## Evidence actually inspected and historical limits

Source reading inputs:

| Document | SHA-256 |
| --- | --- |
| `docs/art/briefs/grand_cage.md` | `dfbe445878376b3343aa5dd300a96add765172abdf2698b97b7195bc15d300e0` |
| `docs/art/environment_spatial_rework_direction.md` | `9a438875d8c5b4d923e1f5938caa9d900e5433aed0e27f3836907284245e579b` |
| `docs/testing/environment_spatial_review_evidence_20261116.json` | `57999e3e5049f6b290cb74562aa6957e6938be652596e701953001042f9f3f6e` |
| `docs/testing/grand_cage_r2_native_trial.json` | `29a9ab1330855d1e95c2c7d88bc882dcb3d920c560e3a561a3df498cd10473d9` |
| `docs/testing/grand_cage_empty_label_compatibility.json` | `ef9527de615b127b885bf46f25a24014f2123c651433b1055c7d52f0330491dc` |

The all20 index's Cage entry still points to historical **R1** video frame000,
SHA `2bd6c6447bf6c4d686243783be21ebbcb5bcfee91427551e5a44f9bf1e756d00`.
R1's eleven fully obscured glints were fixed by R2. The index is left unchanged
in this bounded audit; its R1 image must not stand in for current R2 geometry or
visibility evidence.

R2 contexts root:
`E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-contexts-01/evidence/`.
Read metadata `__none_metadata.json`, SHA
`3cdf393984aa8dbcf6e8e92e6178611fefffec8541e67c6e144a5c0ecda78480`;
source_paint geometry_equal is true, five actual body/adornment pairs use the
unchanged production dispatcher and captured clocks. Actual-play PNG personally
viewed: `__none_actual_play.png`, SHA
`0827417492075f5f81e7df596e7ded7841b8cd0b84b121abb66c39f53e19c2ef`.
Typed files are `__none_host_0_body.png`/`_adorn.png` through host4.

R2 stock root:
`E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-stock-states-01/evidence/`.
Read `cage-composed-stock-states.json`, SHA
`dd98f4067b67baca481574e971d3bbabc758b8ef3039edb3343309596e2035e6`.
Personally viewed `stock_packed_empty.png`, SHA
`06daa5c6385fb9a9d47b32aacc3e55b9069b73e146391b30b5f9afe6018008e5`,
and `stock_packed_available.png`, SHA
`7be204bcb8628b71b334a4afae21683ab0e8bd1940cd15a7acbf5118be19eb06`.
These are cloned semantic fixtures, not a naturally reached stocked shop.

Personally viewed retained R2 real-clock capture
`E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-video-01/evidence/capture/frame_030.png`,
SHA `bf17639cf3fc564c255b3af90e8a698dc8f32e8ebf73109e4311fd995c484dec`.
No new motion capture was run. Historical review records Native82,
Base14840, stock12, separate compatibility52, visibility36/36 and original
no-pointer liveness, with actual62frames/8.135911s (not a full57.78s floor
cycle). Those are historical R2 qualifications, not a PASS for the proposed cut.

## Next review and acceptance work

1. Parent/director and independent reviewer assess this structural disposition
   and exact glyph mask before any new Cage helper, PNG or runtime is created.
2. If authorized, a separate bounded assembler may create one non-active
   candidate that changes only this atlas's alpha. Require exact24-member
   custody; original23 room payload identities above plus current index; reject
   unknown physical paths/reparses; source/controls unchanged before and after.
   Prove exactly5532 retained alpha46 texels,46436 cuts, seven components,
   untouched RGB, zero changes to other23 logical files and all original2×2
   block equality. No background assembly, donors or replays need rewriting.
3. Root performs admitted E-only guarded native qualification after independent
   static review. Reuse actual Cage acceptance contracts and preserve their
   assertions; do not import Grand/Hidden object or animation counts. Fresh
   Base/5selections/10typed masks, empty/available fixtures, original EMPTY
   compatibility, glint visibility and ATM checks remain required. Cover normal,
   low detail and reduced motion at actual clocks, plus original no-pointer
   liveness and animated preview. Verify the glyph pulse is visible without a
   rectangle and verify no new seams at the untouched cabinet/floor.
4. Conditional Bishop/shop/runtime populations absent from retained Base must
   remain explicit qualification limits until observed; do not invent fixtures
   as reached gameplay. Parent owns scoped commit and exact served TEST
   verification. This source plan closes neither Cage nor the all20 objective.

No external blocker was encountered in this bounded audit. The next dependent
step is review of this concrete plan, as explicitly required by the parent's
assignment; generation is unnecessary under the proposed disposition.
