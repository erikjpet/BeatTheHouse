# BTH-ENVART-001 — Phase 1 loader and validator (2026-11-12)

**Implemented on `codex/environment-art-layers`, not qualified, not merged, not delivered to NEXT. Stop before Phase2.** The core loader tests pass, but the supplied pack fails the size contract and introduces a new Smoke content failure. No gate was skipped, changed or waived; no delivered file was edited. Phase1 and the parent remain Open.

## Before / changes / after

Before: no `EnvironmentArtPack`, no environment-art artist checker, and no extracted starter pack in this checkout. The original production canvas/menu remain exactly the baseline source.

Added:

- `scripts/ui/environment_art_pack.gd`: v1 enable-list gate, logged null-return rejection, 2x dimensions, schema/id/board, finite geometry, five closed animation types, time/loop/still/common fields, strip divisibility, room/layer counter ids and bleed. Successful parsing compiles typed animation/counter records, source frame regions and texture metadata once. This phase adds no draw or process function.
- `tools/check_environment_art_pack.py`: independent engine-free manifest checker, direct PNG sizes/chunk CRC checks, room/layer counter lookup, enabled/all/explicit room modes; never edits the pack.
- `scripts/tests/environment_art_pack_contract.gd` and `tools/tests/test_environment_art_pack.py`: positive typed fixtures, negative contracts, exact size rules, framed mover, loops/still/bleed and current fallback-canvas liveness.
- All9 supplied files: seven PNGs plus two manifests, byte-identical to the original ZIP. Normal Godot cold import ran in the admitted E: workspace. Generated `.import`/`.uid` sidecars follow the existing ignore policy; no import/pipeline pin, project setting or preset changed.

This is a loader seam only. Canvas background integration, animation drawing/timing, counter replay, threaded loading/eviction, authoring reload/documentation and the new menu remain unimplemented. A passing loader fixture is not a passing rendered-pack proof.

## Actual delivered-pack results — both remain red

Artist checker, `p1-delivered-check-01`, exit1:

```text
{"valid": false, "environment_id": "gas_station_casino", "reason": "animations[3]: texture is 16x68; expected 1800x68"}
```

Production `load_pack("gas_station_casino")`, `p1-delivered-engine-01`, exit1:

```text
WARNING: Environment art pack 'gas_station_casino' ignored: animations[3]: texture is 16x68; expected 1800.0x68.0
ENVART_DELIVERED_PACK {"reason":"animations[3]: texture is 16x68; expected 1800.0x68.0","valid":false}
```

The owner explicitly resolved the ambiguity as **“Keep the full-rectangle size rule; supply corrected art.”** Required replacement: `assets/art/environments/gas_station_casino/anim/scanline.png` at1800x68 for rectangle `[0,42,900,34]`, pixel_scale2. [Unmodified delivered texture](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-02/evidence/scanline-delivered.png).

Smoke content, `p1-smoke-content-01`, introduces exactly one finding versus Phase0:

```text
Release copy blocker marker 'placeholder' found at res://data/art/environments/gas_station_casino.json.note: STARTER PACK - placeholder art for building and proving the renderer. It will be replaced by the final pack.
```

The delivered manifest needs a version that satisfies that unchanged gate (the non-contract authoring `note` can be omitted by the supplier). The worker neither removed the factual starter note nor exempted the path/check. The format contract and original plan remain unchanged. These two supplied-pack findings prevent qualifying Phase1 and advancing to Phase2 under the ordered, no-worse-than-baseline requirements.

## Checks against Phase0

| Gate | Phase0 before | Phase1 after |
| --- | --- | --- |
| Cold import | exit0 | exit0, new PNGs through normal cold import |
| Godot loader contract | absent | 65 assertions, 0 failures |
| Python suite |180 tests OK |224 tests OK in44.407s;44 new tests |
| Script load census |866, 0 failures |868, 0 failures |
| Smoke content |1 check ID, 0 failures |1 new release-copy failure from the delivered note; no per-frame tripwire findings |
| Smoke runtime |6 check IDs PASS |same6 PASS |
| Project validation |Appearance preload naming violation |same unchanged-source violation |
| UI flow |coach/travel Skip foreground-ownership failure |same failure / same receipt and once-only settlement |
| Cold Continue |PASS,9 restored objects |PASS,9 restored objects |
| Game Library |11/11 PASS |11/11 PASS |
| Dave encounter |PASS |PASS |
| Roulette audio |14 events, 0 failures |14 events, 0 failures |
| No-pointer liveness (unchanged script) |PASS |PASS |
| Full perf Smoke |7 findings; native solver absent |first7 / quiet repeat8 findings; not qualified, see below |
| Base / No Scenario captures |20 rooms at1280x720 |same20 rooms, same207 object identities |

Valid Godot fixtures use real typed Texture2D resources and a manifest read from disk through the loader seam. Invalid texture paths also exercise the actual ResourceLoader failure boundary. The delivered-pack check exercises real imported PNGs and the public production loader, and correctly returns null. No claim is made that the supplied pack is valid or that a packed room was rendered.

### Geometry and captures

All207 objects preserve membership, interaction rectangles, footprints, z-order/type/authority and non-route object/label rectangles. Full capture layout records differ in14 rooms because autonomous route actors were at different clock positions; those raw differences are retained, not erased. This is not a byte-equal pixel claim. Production canvas, camera, object layer, placement maps, scenarios/rules/payouts and menu source have no diff.

| Surface | Before (Phase0) | After Phase1 — existing rendering, not layered art |
| --- | --- | --- |
| Gas Station play | [before](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/gas_station_casino.png) | [after / current room](E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/gas_station_casino.png) |
| Gas Station menu | [before](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/gas_station_casino_menu_before.png) | [after / current flat backdrop](E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/gas_station_casino_menu_before.png) |

[Before full layout/snapshots](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/layout_report.json), [after full layout/snapshots](E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/layout_report.json), [machine geometry and measurement comparison](E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-summary-01/evidence/phase1.json).

### Idle cost / memory limits

These are existing-renderer readings, not layered-art performance. The existing overlay has no isolated room draw CPU timer; room figures are **whole-frame upper bounds**, not draw-call duration. Render/display cadence changed between capture runs, so lower numbers do not prove improvement. Animation scheduling code is untouched.

| Reading | Phase0 native | Phase1 native, unchanged room |
| --- | --- | --- |
| Samples |180 |180 |
| Mean / p95 / max frame upper bound |8.1484 /6.9590 /133.3333ms |2.9079 /2.7778 /37.1003ms |
| Autonomous redraws in sampled window |77 |31 (shorter wall-clock window) |
| Engine static memory before / after idle |352,218,794 /388,710,868 bytes |352,230,318 /352,253,926 bytes |
| Engine-wide texture memory |78,206,103 bytes |78,206,103 bytes |

Phase0 exact NEXT Web:180 browser-frame samples, mean6.8978ms /p957.1000ms; JS heap275,109,432 bytes before room entry and280,628,750 after idle. Its actual overlay shows autonomous redraw count162 and no console/page errors in the bounded run. There is no ENVART Web after measurement: this branch is not deployed and the renderer is not integrated. Memory is whole-app/heap data with ongoing resource/audio work; no pack-memory, leak or speedup conclusion follows.

The performance suite remains red. The source workspace lacks the ignored locked native Coin Pusher addon, so its fallback solver timing cannot qualify the native budget. Phase1's first run also reports Blackjack idle p9513.04ms versus a5ms gate; the quiet repeat does not repeat Blackjack but reports Craps idle p955.46ms versus5ms. All three complete failure lists and timings are retained below. The worker did not adjust the budgets, install/rebuild native code, suppress a case, or select a passing run. No no-worse/performance acceptance is claimed.

## NEXT and stop disposition

No ENVART commit is on main or NEXT. Existing NEXT baseline is `e5152c34bfe146600214fb206ec80a5e3e8a27cb`; Phase0 verified its exact startup/identity. The owner requires a branch for later merge. The existing watcher builds main, so branch delivery is pending; no alternate build/promotion path or pipeline change was used.

Phases2-7 and9 are unstarted behind Phase1's failed gates. Phase9 also requires Phase5 to pass. Phases8/10 await the owner delivery; Phase11 is excluded. Required next input is corrected starter scanline plus a delivered manifest that passes the existing release-copy gate. Resume on this same branch, preserving all red evidence and baseline findings.

The starter does not visually prove other19 room packs, all12 doorways, layered Punchline/Grand identities, multiple counter fronts/bleed, mixed mix/add ordering, pingpong/once_hold loops, a framed mover/gap, or per-room scenario readability/Reduce Motion/Web behavior. Validator fixtures cover applicable data rules; renderer behavior for these remains future work.

## Delivered files and custody

All9 files match the supplied ZIP exactly:

```text
b44a321e50a82a4343804460fe27220e14942836f34c1e7b656b3b73560e322b  assets/art/environments/gas_station_casino/counters/gas_station_staff_window.png
a416e40ef36a986fae7098d3bce0973836bfe6337e3c5f186a4cc67d9dac095d  assets/art/environments/gas_station_casino/anim/laser.png
192cfe3d9645a2e0e299e46930ccf3a86bd0942c9872b5e6d0d97e5dc4f28826  assets/art/environments/gas_station_casino/anim/soffit_lamp_flicker.png
38599195079207c3a72b062adb544154e333dcadc370b2468ec8e3a520e51633  assets/art/environments/gas_station_casino/anim/headlight_streak.png
611c79bf6af088bcd202376a1060798ec60fdd1159859235be051c0fc128a847  assets/art/environments/gas_station_casino/anim/scanline.png
41d8c45c20bbb3cb617cb0c183f0709765271f356d8afd20066649fc4e64a443  assets/art/environments/gas_station_casino/anim/neon_fascia_glow.png
afd2bab7d8c6300abda5ce26e5eefe13a807a6daabcacb30d704563397f69880  assets/art/environments/gas_station_casino/background.png
51987b63383c1724f55840baee8fc958f57e4df4d842e93c81955ab50f2d4e95  data/art/environments/index.json
c09924b1f329b68cee382896e6902e8560d31a431c02045e77e5e1b55016809e  data/art/environments/gas_station_casino.json
```

All raw data remains under `E:/CodexQA/BTH`, with per-worker storage admission (4GiB expected writes +20GiB reserve), final pre-child launch gates, assignment before resume,12% CPU/2GiB capped Jobs and zero owned processes at release. Profiles/saves/evidence were retained. No C: QA fallback or security change was made.

### Complete retained perf findings

`p0-perf-01` (7 findings):

- Idle coin_pusher surface averaged 66.82 ms per frame, above 45.00 ms.
- Coin Pusher V3 timing used gdscript_v3 instead of the locked native_v3 solver.
- Coin Pusher V3 300-body tick p95 51.237 ms exceeded 12.000 ms and left insufficient renderer headroom.
- Coin Pusher coin_pusher_active_skill_release frame p95 278.409 ms exceeded 22.000 ms.
- Coin Pusher coin_pusher_active_collect frame p95 267.309 ms exceeded 22.000 ms.
- Performance probe did not exercise the shipped 160-body Coin Pusher DROP/carriage/skill-stop/collect live sequence.
- Performance probe did not report raw 300-body Coin Pusher solver stress timing.

`p1-perf-01` (7 findings):

- Idle blackjack surface animated idle draw p95 13.04 ms exceeded 5.00 ms.
- Coin Pusher V3 timing used gdscript_v3 instead of the locked native_v3 solver.
- Coin Pusher V3 300-body tick p95 49.190 ms exceeded 12.000 ms and left insufficient renderer headroom.
- Coin Pusher coin_pusher_active_skill_release frame p95 268.250 ms exceeded 22.000 ms.
- Coin Pusher coin_pusher_active_collect frame p95 271.670 ms exceeded 22.000 ms.
- Performance probe did not exercise the shipped 160-body Coin Pusher DROP/carriage/skill-stop/collect live sequence.
- Performance probe did not report raw 300-body Coin Pusher solver stress timing.

`p1-perf-quiet-02` (8 findings):

- Idle craps surface animated idle draw p95 5.46 ms exceeded 5.00 ms.
- Idle coin_pusher surface averaged 46.44 ms per frame, above 45.00 ms.
- Coin Pusher V3 timing used gdscript_v3 instead of the locked native_v3 solver.
- Coin Pusher V3 300-body tick p95 48.909 ms exceeded 12.000 ms and left insufficient renderer headroom.
- Coin Pusher coin_pusher_active_skill_release frame p95 262.789 ms exceeded 22.000 ms.
- Coin Pusher coin_pusher_active_collect frame p95 270.878 ms exceeded 22.000 ms.
- Performance probe did not exercise the shipped 160-body Coin Pusher DROP/carriage/skill-stop/collect live sequence.
- Performance probe did not report raw 300-body Coin Pusher solver stress timing.

### Raw evidence SHA-256 list

130 raw files. External inventory SHA-256 `05515ef304cee56db6386b6f8aa9dc5fc35c72722c8171b9ad1b74e946133bc2`. The current summary Job envelope is separate from its input-file inventory.

```text
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/adapter.py
78d5d211a36db14e19dfefce5385aa084621d135c3ff94408962c388b10e4064  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/apartment.png
df7ac8567f6057a27f1fb4c55422e54560e4f1db6962e187c52e655036f54b81  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/back_alley.png
2d8a45c261f654de614c0086263ffcaddfd2b686bdb12c0c8d7008bd4e446443  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/bar.png
8af82fc1d7cdf30e111f5eb63781b415bf6135289f6e91797bf00d6b9a587f61  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/beach.png
3d2af450cf774439b093c7246d6e3140569b90aed5a0864adcda47bfd54260ae  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/corner_store.png
133cf176db18f1572421de11ef4dc3f312a8224773745273155475a4442fc53f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/delta_queen.png
c7e372d1f5dd05d0187be196235b70f81be03e73a3e54f678aa96291f499e698  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/gas_station_casino.png
b6096b125f99c800d7a20137e1ea702507ab4ef7d6fc1dd716e7a8f674f1714d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/gas_station_casino_menu_before.png
f5642c04473b53b05a20ac6a7d218f8e8a51c6e18f5cb8e1eeae76edf8d5af16  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/gas_station_idle_cost.json
d131cd8c24b63038a1346f39c088c9b0423744dea8b3d3504ef5e78fbca71f1f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/grand_casino.png
7b4592f2082775d0c574f19eebbc51e99f7893a4859a249d5b051daec8b041f1  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/grand_casino_back_room.png
b0948a0e951e9773c70bf32316afb554b53073cc1fa7e7956c708b71a27ba798  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/grand_casino_cage.png
ccc94c29a62cd7a52c3c8979323e4093146c9a669a04f0d965af1ca82958d044  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/grand_casino_high_limit.png
483e4d6c8fc101cc51c8b2b06ab8ee1d6ca9b8d8419f1ad2170a1f32ca3b4ac2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/house.png
b405b299dceb9c9733222185f511f7930c047911217620c6f8440bf2d6576399  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/jazz_club.png
6d07dec330a2f1596a0a3fbe33d4d79980ba6a7d10339fa80bb3a7b54eeb6cb2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/kitty_cat_lounge.png
6e76ba0793869aa843cb0b9d73a18d506ff59da828145aec22e3908404d73cdd  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/layout_report.json
bb7bd8318c79da40eeba947244a41a066bb44fcdeccd0ec086dde5eefecf6f05  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/motel.png
85521add36907106cd6445390a62ded84116ca28095351cf78665ea2a1841ed9  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/motel_room.png
0989bda66491436a295821acd3d915e65d5a32cc3ed669cade68162235ec65bd  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/pawn_shop.png
c9ad7600e770b141444f6bf8f817cd9ab547730b1c89056f82d5f81acf172a7f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/punchline_back_room.png
cd594d4bd059d009fcf3de82a27c80900aae92a2dd7677b35aba8b01626278f4  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/punchline_club.png
93bf305a94165ff33fbe9bde1b8ecf5274770433679780ce6b3a63d35f59ee58  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/captures/small_underground_casino.png
d02b08fa2d06c31a97ed448473541ad811ffda6d1fecc41b105ac1377b058aba  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/job.json
965e7d3a92f87a38d688fe6764e6835339d1d4f22d1f2c86fb520fe3d11bfe88  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/launch-claim.json
816d6178f00b3678e803f086175533050cc9aaa8cf4c7a661951e436b3daac42  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/storage-manifest.json
2258ea3abb54d335f91b921ba809da009c34012c136a0418610b3c3f5136deed  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-captures-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-cold-01/evidence/adapter.py
61bbae64b225f77357f80d1f77827e976612ee5b517ea61715902730b7f89220  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-cold-01/evidence/job.json
8c507a672005396905dc65830690f0069576c61303cd8304f052d9bdb9f71672  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-cold-01/evidence/launch-claim.json
67c227de4999f52ab852ce416d1dcbe62b696c0573ec8390131b6eb3cf749227  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-cold-01/evidence/storage-manifest.json
bd612d20b28df2d07e4fd5ce72ae4d8bb3488780f81ed27a742c23c5a2791f9e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-cold-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-dave-01/evidence/adapter.py
4187f22959d8f244c6ff6fa5f9ffabbfa900af3f530b3d949d84e1eec744e98c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-dave-01/evidence/job.json
6599ef14ee79629a2c6365f7e4dfacc86d71f448b78494a577f0b1a0b0a6a65d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-dave-01/evidence/launch-claim.json
2687f021c2ee99f739b1bc51a8d59ab71af13803c2da0223ed63077f085005bf  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-dave-01/evidence/storage-manifest.json
2c92efdb31068a94b3d207bc849b669f4b4e170970ddbbcca5fb0ea5281050a0  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-dave-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-check-01/evidence/adapter.py
bd5a4251708530425f8346c6ea6ae8d5a6224fb5e070be171a9a6bd2d36076e8  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-check-01/evidence/job.json
dc8b260ebf3b5dd73568224079def040e42fb31971091602d37d17cb1d808231  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-check-01/evidence/launch-claim.json
4211ea15c2509a5fd74ac5cf61fc2daf757c4265266b65594027df725eb358ef  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-check-01/evidence/storage-manifest.json
c9d01fddf56979dbb91bda488fdfbd2359ebccc71da0e92592f5875b65c30396  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-check-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-engine-01/evidence/adapter.py
c3033cc8b801a1a94258afbbee39911aba833a3c738fb85cd0d6292b4cfd8eb2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-engine-01/evidence/job.json
f11afb055dc54d76f3c89cfce223f8e62196c1417a54d59e564ec8bcc0886371  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-engine-01/evidence/launch-claim.json
00aeb8575f7aeed6a95f9843eba1a6533173a4708eaea67ff5bb9ac7e9993ca6  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-engine-01/evidence/storage-manifest.json
0982e7d99331c7eb1684609289e86007e7ba61bc9ca29c71d1a5d09b6b9f389a  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-delivered-engine-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-engine-contract-01/evidence/adapter.py
29c8cf354f44ae556f224f0cb4216772f01b1d83815b43fcbaa51bb255669478  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-engine-contract-01/evidence/job.json
bfe14ef7ea5b8a4f0cfdd58ace001f0875eda5062f75e3a7fc1c274451e3eaae  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-engine-contract-01/evidence/launch-claim.json
18395514091240c850c85fb338f85070a52f894e369a7993f4fe299cebc80ee0  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-engine-contract-01/evidence/storage-manifest.json
95e50664fe2dff3d50b3eb2ab01edd2697f3e0af8fa5647c2738648aea1de445  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-engine-contract-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/adapter.py
afd2bab7d8c6300abda5ce26e5eefe13a807a6daabcacb30d704563397f69880  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-background.png
51d013a26499e2e5d199d3de1f7d8bcae2af4a56ec1bd982386a0a00d13ad070  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-check_environment_art_pack.py
ebab64ab375e4e427259e4a6949e9ffebe2b07a0ed8aa981ae81cc9819bb849d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-environment_art_pack.gd
edf8e6be87375d73db26b06fc3315b9e8af244955b2c50c603a8e4a18e71e260  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-environment_art_pack_contract.gd
c09924b1f329b68cee382896e6902e8560d31a431c02045e77e5e1b55016809e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-gas_station_casino.json
b44a321e50a82a4343804460fe27220e14942836f34c1e7b656b3b73560e322b  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-gas_station_staff_window.png
38599195079207c3a72b062adb544154e333dcadc370b2468ec8e3a520e51633  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-headlight_streak.png
51987b63383c1724f55840baee8fc958f57e4df4d842e93c81955ab50f2d4e95  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-index.json
a416e40ef36a986fae7098d3bce0973836bfe6337e3c5f186a4cc67d9dac095d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-laser.png
41d8c45c20bbb3cb617cb0c183f0709765271f356d8afd20066649fc4e64a443  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-neon_fascia_glow.png
611c79bf6af088bcd202376a1060798ec60fdd1159859235be051c0fc128a847  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-scanline.png
192cfe3d9645a2e0e299e46930ccf3a86bd0942c9872b5e6d0d97e5dc4f28826  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-soffit_lamp_flicker.png
d18140cb3bdeb2cf1e95707a936de843fa803bba66092cf9ea279c1b5f64fd36  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/input-test_environment_art_pack.py
cb45fefdb05ef66ef6321b878dd37fb1d5be2a44fd8f45442bbebcebc89c1aeb  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/job.json
c4bcbc732d8941996040151e22e019bdcfaf47fa2828a22c2d2c46985420fa78  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/launch-claim.json
56a394623efb71f6b17279fa65b6d97ea8501539cd83a8580d50d77f2153c922  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/storage-manifest.json
16450689c29b57c386f749c20d65847aa8859817d0eec41d63755f6356270b3d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-import-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-library-01/evidence/adapter.py
81ea0b1f9df8facc6d46f548dd10fd079653c8cabffecf26ff4b0fc21be02ae7  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-library-01/evidence/job.json
b3762865f95a4f4e00995490b3508eb348524eff3460459a2abcb33793c417b6  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-library-01/evidence/launch-claim.json
e4cabb84ca8b8456b434563d072a8151ce8379bd0f961a5b63dd5db4b18afbfc  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-library-01/evidence/storage-manifest.json
bc4cc7527b98c6a6a477b73304601fd4f433c99407899fa2881caba00bc20430  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-library-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-liveness-01/evidence/adapter.py
686c61a48d0b77d7512901b011d34fe17e86c5b78c2aed2de392f5f27867c924  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-liveness-01/evidence/job.json
7072b5eadc6df983c4c80617a1a5bddb8ee8011724862387f605ac9278a86015  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-liveness-01/evidence/launch-claim.json
0a7eab8bc0f98cca88ebb729c36fb231e34522a8e7dde416778b01095b8c9c69  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-liveness-01/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-liveness-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-loadcheck-01/evidence/adapter.py
d482240ba58b91856abb284c62cae496df55debb1644e339a567040f2dccc076  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-loadcheck-01/evidence/gdscript_load_check.json
59170a3431d7eb6d0580523a6826a3e89ac5191fe4188b3a8bb86181dda82795  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-loadcheck-01/evidence/job.json
3b0c2e1b1d08ef90625c03edb8d125546f62fd583664843830a8e968a6e686b8  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-loadcheck-01/evidence/launch-claim.json
377656357d130876070c0f32e087d90481db18159708e4ce15d7d4e8d445626b  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-loadcheck-01/evidence/storage-manifest.json
575561bba59ca3d8bc972894017a2a1ef9f5b24aedb8dda031a5fabdec30a545  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-loadcheck-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-01/evidence/adapter.py
c27a2a2acf7f9a4d4fd6739e6201efcae0eaf544ad808541fb86ede33ba1a6cb  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-01/evidence/job.json
2bb9d7ba4451ef0ed4605ea8479ca5a1f53a23efbe843eb88b09f039e55cb6a7  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-01/evidence/launch-claim.json
bfd5b792f8d157790d2485b6019573eec2669588291baa27e5e46a2dd0490ac1  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-01/evidence/storage-manifest.json
7aac96757cca0f6c44e019c0b4eb5489920fb3ed60469a84761f90c316288a5b  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-quiet-02/evidence/adapter.py
de23998de7a2a5bc94e0becec979cae0de019722cf88aa061f3875ba54c95c30  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-quiet-02/evidence/job.json
ba50e88d05eaf5b22083fde06fa00c9d7f6b19d63b10279f2a60b568d1c95f67  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-quiet-02/evidence/launch-claim.json
3e417d1f5cbb0dcbfa67d6774462e99b71be87aad69693e91c03c6f379e5899c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-quiet-02/evidence/storage-manifest.json
41dbbe13d80acdb63343b4316eb0620e193e1348701622a76d690389d37bb72e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-perf-quiet-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-python-01/evidence/adapter.py
9e2309a79f4081610394fae198af3f9b4a364cca7533d5268d85b2f117db993a  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-python-01/evidence/job.json
6f91b0635fda5d253a7de837e82fd0d8e840804ffc3451ba2ca96f4b1aed8ed6  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-python-01/evidence/launch-claim.json
6d656b50878b362d5cf9bcddea836057196421354b693ad915ad362700e9b390  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-python-01/evidence/storage-manifest.json
7d27e00420cb4f8849b5af8f8440213d703ab0827f91bd5a3301b9315a38c09f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-python-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-roulette-01/evidence/adapter.py
aec1f576cc42e5b3df2d10f00b8a83b337dd1051ca5993eee1928e10590111b5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-roulette-01/evidence/job.json
0682ba1c87c920a809a586aed66dfb0e5f872cc38a024160b4816aa8fcafd279  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-roulette-01/evidence/launch-claim.json
cadf38a6a9c492a206ebec7ffffb8a8f723c67bcf3dd885409627bc90223758b  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-roulette-01/evidence/storage-manifest.json
237847494c26bf658768d8cc3650500e9f620eb10760209d4de628ca68a03e3c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-roulette-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-content-01/evidence/adapter.py
7d954cf29eea1eca34ddb3646a6e3c2301144068bd7caffd5e7d1bc01c082c4d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-content-01/evidence/foundation_smoke_content.json
804b79c2ea872f3bf9b2aac35e6c9baaa0f0a24e4cf4fd37eb5d595ac4fe8de5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-content-01/evidence/job.json
37b7a9d2b522166e27f76073821b154b07f503c88c7e330c4a4aea93aedf6926  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-content-01/evidence/launch-claim.json
893eea1cb7bbfb0686a1498fe9dd0623fa820839398262320a0be408c8b280e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-content-01/evidence/storage-manifest.json
76786a0c61ba2b8fac95a48350a276da7f7417379ad5903e92e84160fff86e67  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-content-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-runtime-01/evidence/adapter.py
59b639abe799df6b3b6ab405357926f352de2733b8cf95306f0ba7ad27f92bc8  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-runtime-01/evidence/foundation_smoke_runtime.json
f36cd5d0836a040048c144d7399ebf2db569c57ff3ccfdc5a535ac87bf47a731  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-runtime-01/evidence/job.json
316f98cf1eb573f5baef35751073931cccdd1b3c944329436ec1230696c7cf61  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-runtime-01/evidence/launch-claim.json
5438794257f99fd8251b0141f6f2650673b11354b3a9417cbd798c328b9478e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-runtime-01/evidence/storage-manifest.json
b344e9d2dbe87f23c47a0a5284a602290f5510ec690849718cfbbc02c13973ea  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-smoke-runtime-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-ui-01/evidence/adapter.py
dc39c4248872b5aa8d2058098a45b4365996bd91308307bcfa9ee7d86c7b302d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-ui-01/evidence/job.json
073852d261f50afc097bed16deaee19b15e7523bf2d0477421b5074427664d21  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-ui-01/evidence/launch-claim.json
346e0170fe7f8042e614a578d8cdebb5a01a3007795e8d1e2e4e93238596a6de  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-ui-01/evidence/storage-manifest.json
0018e05bf11a6f2eb04dc350042df7344c75e2e4d42b3419c1a567cddfb89411  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-ui-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-validate-01/evidence/adapter.py
255fe54019cffbe8a2919e77588368218ae6872d2877eb60baa4afacbeb939f6  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-validate-01/evidence/job.json
449291a937d41d7cfa1f094c1cbfad4e6157a796245063ffa95bf3c8caf44fd8  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-validate-01/evidence/launch-claim.json
ca056ad31a41e3d94210f9163aa0af7ca68d5a5c836428c6c68578334681facb  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-validate-01/evidence/storage-manifest.json
497fedf851bfff4c98c97bc98032e9a38edd10640b8863aea615fdb58d8b4c8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-validate-01/evidence/worker.log
36fb2a58c796fe1c8dea572a594647ea0701b2a3cd825934008aa77efde18cf9  E:/CodexQA/BTH/runs/BTH-ENVART-001-p1-summary-01/evidence/phase1.json
```
