# BTH-ENVART-001 Phase 6 — loading and memory

Status: locally qualified on the feature branch; NEXT pending the owner's later main merge. Section3 art format, original art and pinned project/export/native inputs unchanged.

Before: snapshot publication synchronously loaded/validated every PNG. After: live views select a pending pack, draw the existing room while it loads, and atomically activate only a fully validated pack. The accepted destination is prefetched before the departure cinematic; Main continues polling during cinematic/modal ownership. Get is called only for terminal resource status, never in-progress. Draw code performs no loading. Initial retained layers receive the current clock/Reduce Motion/detail pose before their first render.

The cache admits current+previous, or current+departure target. A superseded started request drains its terminal engine tokens before a different third texture set can start. Departed references are evicted; hidden canvases free their pack/render-target references and retained commands without disabling processing. The legacy external-background path does not allocate an unused art surface.

## Actual checks and before/after

- Cold entry: before snapshot publication62814us, pack on frame0 after synchronous wait; after25570us, one live code-fallback frame, pack on frame1, autonomous clock advances. This measures the full existing snapshot work, not only texture loading (`r2-p6-before-01`, `r2-p6-load-final-01`). Entry-frame captures prove a rendered fallback rather than an empty room.
- Loading contract36 checks,0 failures: three-room churn, every-step two-texture-set bound, immediate prefetched arrival, previous-pack WeakRef released, superseded requests cannot publish, malformed board/missing file fallback, hidden render-target release, show/reacquire, no-input placement liveness, Punchline/Grand identities and complete token draining (`r2-p6-loading-03`). Loading01 had a QA WeakRef inference compile error, fixed with explicit types; retained.
- Unchanged mandatory liveness passes with a QA-only pack for its hard-coded animation_liveness_environment id. Verbose output records its background/pulse being loaded (`r2-p6-liveness-packed-02`). It also passes on the restored production index (`r2-p6-liveness-01`). Synthetic Corner/Bar/test-room PNGs were generated only on E:, then exact owned files removed and index bytes restored; no Phase8 rollout.
- Background14, animation30, counter11 checks pass. All20 original/new missing/rejected fallback buffers remain pixel-identical. Artist checker valid=true,5 animations/1 counter/7 textures on the restored index.
- Existing real travel preparation check:152 assertions,0 failures, including legal Gas routes, native and production atomic-Web branch, staged publication, Skip/acknowledgment, cancellation and pending-receipt reload. This is native-host travel QA, not a browser travel claim (`r2-p6-travel-01`). No travel settlement/rules changed.
- Smoke content1 ID/per-frame tripwire0 findings; runtime6 IDs0 findings. Earlier224 Python tests remain exact-source qualification for unchanged Python product/checker paths. Inherited project-validation/UI-coach/native-addon perf limitations remain open.
- Strict same-frame paired idle draw CPU1200 draws/version, retained child callbacks included: original mean2.265158ms/p952.457ms; after2.246530ms/p952.452ms, PASS (`r2-p6-cost-01`). No schedule/cadence change.
- Source invariants: all535 original functions retained,529 byte-identical; only six authorized integration/loading/visibility seams differ. All supplied PNGs/spec unchanged and tested input hashes equal branch bytes (`r2-p6-invariants-01`).

## Matched memory survey and Web

Full20-room survey with the same forced legacy Gas menu setup as Phase0: baseline engine static352218794→388710868 bytes, texture78206103; Phase4 texture110232337; after loading cleanup static353176562→389668636, texture97979409. Cleanup reduces texture memory by12252928 bytes versus Phase4. Gas's total new residency is about19.8MB over baseline, including the2x background, animation textures and retained render target; the background alone is6192000 RGBA bytes. Raw full survey,1920/camera captures and metrics: `r2-p6-captures-01/evidence/captures/`.

Final isolated Web launches into the visibly packed Gas room with0 console/page errors (`r2-p6-web-01`).180 rAF whole-frame samples: mean6.949250ms/p957.04ms vs Phase0 mean6.897778/p957.10ms. These include scheduling and are not isolated draw CPU. JS heap before entry275529590→after idle277418957 bytes; Phase0 275109432→280628750. JS heap excludes GPU residency.

The pinned single-thread Web engine executes a load request on its caller. This implementation stages one texture request per process frame before arrival and never waits on an in-progress get; it cannot claim off-thread Web decoding. No template/pin change was made. This follows the engine's documented status/get boundary and its pinned no-worker behavior: [Godot background loading](https://docs.godotengine.org/en/4.6/tutorials/io/background_loading.html), [pinned worker task implementation](https://github.com/godotengine/godot/blob/89cea143987d564363e15d207438530651d943ac/core/object/worker_thread_pool.cpp#L202). The native cold-entry and Web live/idle measurements above state the practical scope, rather than claiming zero main-thread work.

Normal isolated Web PCK size: 124972504 bytes; SHA256 3d3e6a39823e6702f31d75f191bb95610e6c1086e62b2c2a1130562deb37ec25. Baseline NEXT PCK124979752 bytes. Isolated exports lack embedded NEXT release identity; size is not an art-only delta. Cold import and normal export ran separately, with override absent at export. Current main's verified Web native asset/template were reused with recorded hashes; owned temporary inputs removed. No NEXT promotion/manual substitute pipeline occurred.

Raw evidence prefix: `E:/CodexQA/BTH/runs/BTH-ENVART-001-`. All assigned workers used admitted E: storage before writes/child creation,12% per-Job aggregate CPU/2GiB memory, assignment-before-resume and verified zero closure. Raw command/output/capture/manifests, including failed QA setup, are hashed below. NEXT result: pending owner later main merge. Final20-room/12-doorway delivery deferred; no contract changes.

```text
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-animation-01/evidence/adapter.py
055f965cb556493658c2681a34edeeda881c97110af6eb1271842168c8e51f27  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-animation-01/evidence/all_five_types.png
9ab71263b9c91c4a9938a36275e35dd87338ad0aa5368c2fd9fba2fd4798a798  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-animation-01/evidence/job.json
15a9d07a7435771caee8fe0cf4bf3fc8d3eee4fa47068768b2f4b4b1eca3dde7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-animation-01/evidence/launch-claim.json
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-animation-01/evidence/reduce_motion_first.png
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-animation-01/evidence/reduce_motion_later.png
7d01eabd7c670d8ddf1cd070d378367d8b00b514458dd3b1cef6ba78b836a033  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-animation-01/evidence/storage-manifest.json
e5fb7e7f28c3ecc32359e11e85bd31c9547c87fc77e214ae87f33b15aebe261e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-animation-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-artist-01/evidence/adapter.py
3ab128d3ab71c1df56df9d3376f78aade02c26668f09026c5198af24c457f80c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-artist-01/evidence/job.json
6f1878352b4ee708e787c2f6ed6d2756763de648c92019f2ab7e352f5ad1dbed  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-artist-01/evidence/launch-claim.json
560eb8916251712a834e30d0c86262350f8298aadf5aa36f535121edc1d72a1c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-artist-01/evidence/storage-manifest.json
83ae398ed60d5f995eb7f8768b9d25d40ef91648c44684bdedeb2f108bf1e8be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-artist-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-background-01/evidence/adapter.py
463449780d39d1ef9ecbf70a02ad161982d506b4c5fc163f072d399555c99f75  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-background-01/evidence/job.json
e6ddda2f0575afd04bfa9fd0958dd7ad54dd52427632fa0dc7c775fdda6e21a4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-background-01/evidence/launch-claim.json
6213faeaca46e47435524f4bedd021ef6e9a411c651720833513b04b2605a13b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-background-01/evidence/storage-manifest.json
fb1360b179b932b20552250bb4975005a20d14a70abc99ad6bf1af1abb928125  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-background-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-before-01/evidence/adapter.py
d414cb504598313dbc21e7bb8430f593aaadf9aabea026aba92cdc8c33e71329  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-before-01/evidence/entry_frame_0.png
fd9c592afebbf15e0f82aa85d31b82cbad65df4133e27535882203e61db08093  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-before-01/evidence/input-environment_art_load_probe.gd
fc7e1c1c888eee64930bb2e4221a136125631044a312789b460f646dae6cfb47  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-before-01/evidence/job.json
cc901ef3e9f1cf7c3bca37d87457d7ff783df1820494b4071d70c990fd834d47  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-before-01/evidence/launch-claim.json
8525fbb0808214af28de4adbec5210ab11b235a4c0fd07494605ae4125b335ee  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-before-01/evidence/load.json
f07e0a34f5d1a3f4778c398c7800426a1e5f409d89cf99de19c2263bfe48f64a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-before-01/evidence/storage-manifest.json
b9d269d168fd49949bd5f22ecf5a93ceec5c9d2526ff749f3a025d25eb2ebc11  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-before-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-browser-01/evidence/adapter.py
4aef3b0f91ebcfbee6a92a5290051e49a816aab406e86343ecce5d4c61087eee  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-browser-01/evidence/job.json
2b2ed31ed7a6f4fc6e63526e22e3a5eeb5d16fa338337649a66a6c4c5bd102bf  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-browser-01/evidence/launch-claim.json
f071a8823307bc223c084843378d3af3b685a087fe10b20ad8b40df5871dd042  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-browser-01/evidence/storage-manifest.json
21560db9598f0b91aff37844137a0af7c407bb203afb37eea368e64cf846ff01  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-browser-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/adapter.py
0f1f58f60e077359dfd4191d105a0efd1ecc3f73d4d4978c4e1ca951408449f6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/apartment.png
fe32bc93e9e1ccf4bd1f4c8ce0cf77815f5464f2b4c43b4b7426f636e05dbff8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/back_alley.png
43471e57e192bb71de87a23a220a0f261c095506f7bead27921c5babb95743f8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/bar.png
59478120ebc5774d7b8a61acc5ee19e9583019fba74ce7e95c015e481b96593a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/beach.png
c7d5cbef1144e7013e18907b05e5533e865ecbb41fe883acb49cf985ced06e49  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/camera_samples.json
ff8139b6f0412ba5b02df7d0454d867770cbf487d1b3515177c9ffb4b5a93886  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/corner_store.png
779051bbd42e6ad44e549470b7572293fbd087d1a3e7ed0d3f831c9000a2213b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/delta_queen.png
ed17ebe66ddfeba9f9f4563ee9eadc46d96eb78849c2a6d56f5a4243e31f0de0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/gas_station_camera_0.png
b96288e0cc1d42d4b7512e8b5ced2a29bdb0a2da0705557bc1249783deb8df7c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/gas_station_camera_1.png
fca9d8aabe3c293f0fba4d9b272c3a0056e3863ecca76557ca618f1cf4674cf4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/gas_station_camera_2.png
28c3ec56fce6cc60ee455920091b39e9271ca47591fac0ce6c6fdacb0d7813c6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/gas_station_casino.png
c42ebf014290146726914298efd790b778a5fcc5e7c1db7ef3589f9de5c39f8b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/gas_station_casino_1920.png
eac0cae16610ee22b5f9365b9958fa96e6f99a1082914c834a4a8da0f9e2158b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/gas_station_casino_menu_before.png
8cedaf25f49c93e68e4a95370f5ac7a6023e74bc50264fbc2757574f8f6c7527  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/gas_station_idle_cost.json
9bb217a0a06e9da4de6d02442b5f976adf68a410e40a384b271d06ed9a70e7fb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/grand_casino.png
106afea59c7a462e6870e72f4c8b066d53fe0442e337abcd0b7c966aacd3338e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/grand_casino_back_room.png
41b4b31d8f29f5f2b50229b198e9ba02f88b0872ec7779aa06f439e6cbf23240  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/grand_casino_cage.png
3dc2d735cf345f7f09b4dcf07c143710e20ce28dab10f022c895ea120b80b67d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/grand_casino_high_limit.png
748fa7ac3ea515b7b2407eada95772a9b9a37aaf35472f0a9b02b997b0f08c0b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/house.png
a8f582a5fcf415d2ce1914b2a79b9f575de0fd914b5e88e99fa85ad1e921c0e1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/jazz_club.png
074304b253937e16e70ec4f51098f92261476481cfe779c4589678553eff615c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/kitty_cat_lounge.png
a0f8053a57fe0376e026134954f853abf31f0b8c00b1c6c47dd23b5a62de46e8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/layout_report.json
4e7fdc170880044a6b3ea0f2d0fc0e1c946f93b8ece3d2686ffbad60f74d14fc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/motel.png
e2d83893207f38a0c846e4c4dd35d075003c027bddb1fc0eb8804c31523d0bbf  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/motel_room.png
9cf125a9298f55b401266cf78838ff2e4fa46e12a439e24c227bde2bc269db02  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/pawn_shop.png
50829ef34a32328acb90cc96024af26302aad2d6afc13a0048cc3de9ce8b2ce7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/punchline_back_room.png
d13430f5e10f118191a281f2f234c06b06f54f4547be4f95ae62a2920068529f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/punchline_club.png
fb9a81136e2d95ec1e184e6880a1de52f018abd3478c8f28247797c133d7cb63  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/captures/small_underground_casino.png
36fc33edb8db09657ced44e905c6f473c9c777b2bd7d95417c927490c02b432a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/job.json
3ae28f46033c66ee3423c01c2a476dca5492dd6967773223170ce47c279f52ff  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/launch-claim.json
5100e8bc4bc2604fcaf486deea636958785c7d85a94944cabb5408fda8809f51  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/storage-manifest.json
da2efbc2d207227265596611afc2f295115807d6738cf9060cdfc6ce4d7e87c1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-captures-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-content-01/evidence/adapter.py
a62dfac3d4fc9c4acb46687d0f5d91ef95c4b2900bf1d4def898cbd7d497a648  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-content-01/evidence/content.json
f0c3b072c2dbe1943a0131716a2ff67f8042e530a50e37dbc4fd2d3a1adb3ae4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-content-01/evidence/job.json
7db281bdf964b5fb6dbe66ee930461961d123b60feb5d049490dd06002c1659d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-content-01/evidence/launch-claim.json
85a2b8c3095e2842f7da4b208fe853c669e198530b85c846263087e1ad1b6186  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-content-01/evidence/storage-manifest.json
0c075db98a3b837de41f0e2378e13d1eb4b0a1c00113f44d1711048d4a3318fd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-content-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-cost-01/evidence/adapter.py
3d360ab9863625c1205d26eeb90d747e88c4a959686477a3a7f2710a1b7aded1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-cost-01/evidence/draw_cost.json
28231872cb01ffbb55a37bc200abb77346946a7ee489033d9fbacd5bf08c67e9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-cost-01/evidence/job.json
19070d492287f6a53791ccc7c422e45c9eff8ee8f878f34c6ecbfde039872e34  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-cost-01/evidence/launch-claim.json
651f10207f50fbd51bee6064eeb5c77f3e3cf77fab88998679a800d5fdbedb6f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-cost-01/evidence/profile_renderer.gd
f4e1141475c8b413bfc9c37c3ca18e9f6576d51d3fef39773ce61b179215be05  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-cost-01/evidence/storage-manifest.json
199a37fb578d3c2c63124f83ca4d9415ae711717fb30ec928fd21cef1fc3ccfc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-cost-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-counter-01/evidence/adapter.py
5c3d85cda6ca926a04a9b907b3e5bba1db3b272ebd4908e323fb6527a1eb9b57  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-counter-01/evidence/code_counter_and_replay.png
35f867b9c90a1b168941fae03f868f6ef302382f8b6dd145ae4f9da5e00d7a15  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-counter-01/evidence/first_pass_scenario_tint.png
329ef3918a1194d3a5a00dfd2b70a224bab75a4e9e41fc8abc62ff42e19b8340  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-counter-01/evidence/job.json
430a5a1fab3cf0b70f618714414ac7592e690510b813ca0921392fceb371df61  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-counter-01/evidence/launch-claim.json
a2212975ea5781d66c27ad1783956361b8d2c93ac55251d5039e6f4fe6c325a2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-counter-01/evidence/pack_counter_and_replay.png
d756227a51a6833c0161bc2a43dff75916aab85e6293472622e102ab5f110097  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-counter-01/evidence/storage-manifest.json
6245ab3a5249debda46253a0e4ca1c3f02d85a9ddb3baacb1e09266445ed2404  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-counter-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/adapter.py
9c34c4ea306efe66a13a9707a64f53573a31779e3b300bd359ed61c2f2ec33fc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/coin_pusher_native_v3_10.web.template_release.wasm32.nothreads.wasm
afbb1f3c824d6b64811fa57cc80d65003176c68550afdfe6da5c9243d452e7ee  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/export-policy.json
c88982c8d49a27ae20ba5f3775cce2e8fbf843026a8411ca586daedcd876755b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.apple-touch-icon.png
be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.audio.position.worklet.js
5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.audio.worklet.js
9438e36575ee3f0eecb199010bc46e519fd1955568de56eb1b84b9501b535cde  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.html
bc1bdb3acaa0c7de8a4ac147b841c604c9bc5f794616130e440e9076a84be37a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.icon.png
8cf4a21cded9270718a67c6f1aab3d794eca91e3903ad866532c925565dd1fc4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.js
3d3e6a39823e6702f31d75f191bb95610e6c1086e62b2c2a1130562deb37ec25  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.pck
3cb4495c0b98dfbe4b663cbf2b6836473572339beb66d902367893162a70be0e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.png
f344425186abd04d042ee9fe50439a27bb71936fb7c439ed79a3d827c2cfc5f0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.side.wasm
58263765a7f63d873211210ba389dce0b7bb45c0e50a67e978ea081ec9f1e8e8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/index.wasm
5dd3ee5aba759a39a8284ff4c1e99838c9186e5d6b5f9d996165b12a2a886cf9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/job.json
3f86aaf8b6497533f601a84f6d20564b3a5757e188fa6574072da39d30c26de3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/launch-claim.json
9b46df18acddaa7a79f46f4fc2419a306d1a1dc8a836a728325faf1bd3dacec8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/storage-manifest.json
11dc1d862cf6e2188f9dbdb837f6b4ba1b9cbe57e563651ae8899642890a0b5f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/template.json
46367ec66075d024672842f848746a1b9f0d90053f04ce4fa49a2ea1fc966aa1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-cleanup-01/evidence/adapter.py
ce56053c7d71d8f405c516562df81990891ad6743e1f869aa956ce24dfe8472d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-cleanup-01/evidence/cleanup-adapter.py
b2c7617de659efa6cfe1efafaeacdfff5bd6bcf310aefe1c2e0af85db8e57232  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-cleanup-01/evidence/cleanup.json
27f02ae2418367dace1947c6ebfaa6ced6aa2965e0caca04b06c2d4e29d54148  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-cleanup-01/evidence/job.json
3dc55052b7805137d11ad1aa90e4301ede421fdcc19255df20a6f81bfa1e9d69  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-cleanup-01/evidence/launch-claim.json
9a8b48201646820395b1f1be2f49605306be3b77e730d814a63c07bf302a4f99  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-cleanup-01/evidence/storage-manifest.json
884e3f164c383af039c39662716e6c0ebac7f1b1b65c38df3736b1a1dd6a9335  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-export-cleanup-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/adapter.py
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/apartment_after.png
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/apartment_before.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/back_alley_after.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/back_alley_before.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/bar_after.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/bar_before.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/beach_after.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/beach_before.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/corner_store_after.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/corner_store_before.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/delta_queen_after.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/delta_queen_before.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/gas_station_casino_after.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/gas_station_casino_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/grand_casino_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/grand_casino_back_room_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/grand_casino_back_room_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/grand_casino_before.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/grand_casino_cage_after.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/grand_casino_cage_before.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/grand_casino_high_limit_after.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/grand_casino_high_limit_before.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/house_after.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/house_before.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/jazz_club_after.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/jazz_club_before.png
f98a292cd0b2480266e5030b4a7eca6de4047381cbb89cf5ac60f8460568dc12  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/job.json
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/kitty_cat_lounge_after.png
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/kitty_cat_lounge_before.png
d69f181308bdc2cbd2dfbedcde674a8c8c299ef8efea0e8f1b2020ac324f65d5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/launch-claim.json
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/motel_after.png
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/motel_before.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/motel_room_after.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/motel_room_before.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/pawn_shop_after.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/pawn_shop_before.png
45b52f3335285e488836c99e29b134f877ad4274fdd91a46acb13a7c877fa0d5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/pixel_comparison.json
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/punchline_back_room_after.png
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/punchline_back_room_before.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/punchline_club_after.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/punchline_club_before.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/small_underground_casino_after.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/small_underground_casino_before.png
5a5272d3851a767fa9cc6822bd5b1a1bb5c1d40a6fbb4fcdc7297dc5a933e5c6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/storage-manifest.json
25a024df9a7f59b550bc423237aaeb468f863a9b9a7d39308debf2d9890ab302  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fallback-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/adapter.py
8fabcfbd9d8bf310f6241b52985f29e6457b7541331924a21e920f0904d42547  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/fixture-adapter.py
94e4d262eb8bde2c3464103149ae5a0abd0b4e06c632e1cf52798dcc1c8008f5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/fixture-inputs/assets/art/environments/animation_liveness_environment/anim/pulse.png
a1cf62baf1893d9ffc1a7bb50816013071a5ec97fa0f507dc0bed90087b4a678  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/fixture-inputs/assets/art/environments/animation_liveness_environment/background.png
de50ff40dcd550a4a5caa79665a17d10830abb8163da1f5ac0ffde9684a41722  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/fixture-inputs/assets/art/environments/bar/background.png
08b5ed7c88ac1c5424eec08ac8b1ed0af1a37a43b8ff9977770b3f203911749a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/fixture-inputs/assets/art/environments/corner_store/background.png
66a51597e91746491ccc006e753868672b90f2e1f3d5f0b909d88fc3c9885b21  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/fixture-inputs/data/art/environments/animation_liveness_environment.json
ca583bceb3c10b69c7f1d1a779ca6e51da6b69eb66a0f02d268d84241e00e50a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/fixture-inputs/data/art/environments/bar.json
b01b7e0d86ccc156392cdf3dbc299adeb9110a77844bb911ae5c5a2a72535948  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/fixture-inputs/data/art/environments/corner_store.json
b86c81897f7329a98cefb14989173e836a282198baa8d85893221d6b62e656ed  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/fixtures.json
3dd358ee99530b18df7eca1b664deb0dc2ef248ed3085d6dee3585907f39dd4f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/input-environment_art_pack.gd
8fabcfbd9d8bf310f6241b52985f29e6457b7541331924a21e920f0904d42547  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/input-environment_art_qa_fixtures.py
55c1d8f54303c1196710e75356fc662bc2369c41871e18abca3cfa1c0096adde  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/job.json
f28149a47d578247fe4d1142e0f101380658445ae5b611bb2515c77027a9508c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/launch-claim.json
eaee7a9c59c05c3e7d9a2290049f4628b4094e88020827e94261518f9ad9c045  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/storage-manifest.json
fd00b9d69e8e521653bbe77f134a1efde134c703c3259cb43d6d7d2d83489639  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-cleanup-01/evidence/adapter.py
e75974a32ebc096818d6f8bc41e215c5f4ccfb55df16bc97b40104e663ba8ab1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-cleanup-01/evidence/cleanup.json
8fabcfbd9d8bf310f6241b52985f29e6457b7541331924a21e920f0904d42547  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-cleanup-01/evidence/fixture-adapter.py
3cfce602fd154985ee7a4b6586d9cd8191b1587ad65b6e54b9a3654cb155f6ba  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-cleanup-01/evidence/job.json
919d567cb8473152fcb29330b2bab9d44ae669b4ddfebcf390ae7993085403b0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-cleanup-01/evidence/launch-claim.json
bc3de32f1749ae571f227a1f578e7afa6fd5f637c561484b402247efb135d3c3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-cleanup-01/evidence/storage-manifest.json
a21172cd8502b8caebbc1f4879dfc50e984e299292703139b8e4ad836136c55f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-fixtures-cleanup-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-01/evidence/adapter.py
871acb2f944dc7dafcbf799f68f3f344ba5382281a645ee0f206aa59ff28bb7a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-01/evidence/job.json
88e527f0628746891f95dafdc2479b6c9c7941c9991b517c4c0d74ee8e860b99  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-01/evidence/launch-claim.json
b26e88837e4e745090c33708a3a514061dc42d92af0ff675d98ce94a0efa40b8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-01/evidence/storage-manifest.json
6fcb115dcea2bba952f321039ed60333a9551e4ae1792eb6e36f796f3d34c2e8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-web-01/evidence/adapter.py
3d60d9a092fec7f7a8ba8e1fd55e869d7583b372e23f114dcb670edb5966b5a6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-web-01/evidence/job.json
9f80f7fbdb6c09e154b6b6d47f015ba44688eb262a90b03b1129f5cdd2ce0a65  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-web-01/evidence/launch-claim.json
1b30c8c7e8ab70d340a71ba5c3f7be069157783c121fecf8cde70de9352579a1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-web-01/evidence/storage-manifest.json
c3d5bc0ac4ca1aa21c56fd22a7255c525bbffb9e124e3c87273b5f7356a85780  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-web-01/evidence/web-addon.json
f30b4722fd371a7ea5d4b74f0672972edc83bec7fa5866309b118bb207e4b129  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-import-web-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-invariants-01/evidence/adapter.py
38b9f927e365cb8037cbfa120766d60d7056fbf414f33e3058f8640fc1520be7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-invariants-01/evidence/job.json
91af842dc9ef8e284b9c6f3822bb0b059a2701651ab2368b04ab6ce5571fc1a7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-invariants-01/evidence/launch-claim.json
e5d4b76bc91b8e587d84e897960190c0f9b2990cb988fc750b87a1a35bcd1afb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-invariants-01/evidence/source_invariants.json
74e35efbc68f592eb3330cca59de64cee4cc3710f2635ed8a8781ef2c80afebc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-invariants-01/evidence/storage-manifest.json
afc746b829f0a3b9516990d748cd70ad80609385a934cf1622c9647394a0eeb3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-invariants-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-01/evidence/adapter.py
1964a2b32fae7624a241ddacf21c2fd06162146acbe039b841eb9d42172feffd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-01/evidence/job.json
8ad21d4a9357710d5495029db7071d72a68da6c8c749b1094816391fbd3ff520  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-01/evidence/launch-claim.json
8d4308b5e7c1985ab89bca40f08d3521347e2c74fc6c5291e6d5d0ce2bf95d39  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-01/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-01/evidence/adapter.py
5e0aeb4711d0aa7a1424735d5870893f322d618cb88b8a7472ca1babc7221e4c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-01/evidence/job.json
95494ac18f74c13f2d0b43f9452233b8b952497059af04e5d775302ba6f1a82b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-01/evidence/launch-claim.json
ccdefb71aaa4ea8e594c49ed55aabc89c42e0d7461b7f39b83c0098f3f81dea9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-01/evidence/storage-manifest.json
833713da3f8f0992b6cf751a7b7bb4274e27611137a2e3fb7f067c114a8f470b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-02/evidence/adapter.py
9c701c89368db5333bb52380f3e80e687a4fb8076986fe0276bf557d203406d1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-02/evidence/job.json
2d1f175adbf2e928b52edcddeb2f7cac5cdbc79e16fd7a3b6a1b2d61472c57d5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-02/evidence/launch-claim.json
628f0abb8483d34ce7a8b0916931ffabe022f64af45062905f14fc79dc1d53c4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-02/evidence/storage-manifest.json
833713da3f8f0992b6cf751a7b7bb4274e27611137a2e3fb7f067c114a8f470b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-liveness-packed-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/adapter.py
e4363e82e44e9e5707c643324d7dea7b7a4fd2541817e62492415f63ef4e0b1c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/entry_frame_0.png
d414cb504598313dbc21e7bb8430f593aaadf9aabea026aba92cdc8c33e71329  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/entry_frame_1.png
29a926982f38ca4fbf2ff4938f1aeaa6c114ba62114f8831a8163ab00123c3b3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/input-environment_art_draw_cost_probe.gd
3b4a1935e94a95d9a5af1c32d3c503180ea9dfe8e7b5086bcf5a83d195839bfb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/input-environment_art_pack.gd
725a6a6be1cd0a66374a818e41290e424e74d0a873d45e943ed433a4d13d7b4f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/input-foundation_main.gd
aafc0f3dcc7d187c735f1145e10a2c3e4c982dbe56aa808715293c75584a0118  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/input-pixel_scene_canvas.gd
57647a5c84b7d4d3fa74c586200890801fed0ba960a46d5a5a3bf87a39c9e44b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/job.json
619c5f3dce9d536494d61e3dcf26795a9d0d13023ed4e466f2a7d1e4ae3d1225  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/launch-claim.json
c73270de5bf5767cdd446e58c8b2abe8b401604e7d8237605e506bc3db853761  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/load.json
23802e3bdfdc9d6a40d6b382eed5837e9abef217aea7de4e3ef63b0b7da42815  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/storage-manifest.json
456e9bbe064770ac707c542c59655a6154e1bf61fee59c125b418e741c0c7810  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-final-01/evidence/adapter.py
e4363e82e44e9e5707c643324d7dea7b7a4fd2541817e62492415f63ef4e0b1c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-final-01/evidence/entry_frame_0.png
d414cb504598313dbc21e7bb8430f593aaadf9aabea026aba92cdc8c33e71329  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-final-01/evidence/entry_frame_1.png
da987e30159f3bf68248b6a640416be4950f3684c15b853dc222f1cd936a8409  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-final-01/evidence/job.json
e7c8ba360024017953f9ef93c6e647c71af8124127fbb520689fa912fc0e2b72  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-final-01/evidence/launch-claim.json
a0162bd6aaf8d0b674b507b90efa67b1dcbb7775a13ce7ac29f010a080695499  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-final-01/evidence/load.json
da89b529ae1bd03206bf0951dd13df183984e509cc42f8cbce4ddc63dabf759f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-final-01/evidence/storage-manifest.json
b35bd6303a7e42508f29c8235b006d9e8e37c8d6f0fd9473e27f1eb9cfdbf335  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-load-final-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-01/evidence/adapter.py
aebd622389b727235ddff1785ca5eb17343676942bf09be844b9e117452af4f8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-01/evidence/input-environment_art_loading_contract.gd
900b44af05602f6259eed0a2cb33a45d1899cb30bd71aaaed5a744bcc9ccad96  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-01/evidence/input-environment_art_renderer.gd
a554e330fe4a4afa3d6401475afc1dd5a02da6b148976c96f5c2ed3a79b7fed7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-01/evidence/input-pixel_scene_canvas.gd
76ed74ce923e8cce3c34676d89972d5ced9fb80843c477b1bdf75d9da35d36d1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-01/evidence/job.json
8a8a3eaa5035c5c66332bed05cb77c4b028cb07db4fe6175e96dcf04d1c60160  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-01/evidence/launch-claim.json
6b3602108e6a99fdb697b35022fca429a76bbd354f6b86a16e3ae468a11b89ae  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-01/evidence/storage-manifest.json
963ac0d33d62004739b50c51e9aed1cf7604a3f6327ff1b5797000b5e26b3f80  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-02/evidence/adapter.py
da62aa15ce31c01cfa19381dd536810608fc8e7ed4b10617540e7f21236a0d6c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-02/evidence/input-environment_art_loading_contract.gd
76e9550fe55e795ff4152a03accf11dddcbc904d3d94884960178f9506502abb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-02/evidence/job.json
c0424ac906e3f99e8e2087ef9baf0271ee80901cd9ed68b7dcd2dbf2a9858fa2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-02/evidence/launch-claim.json
ff4a0406d057d61b555c02b5f08598b778ecf1d364af2244dfd488cd18caf795  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-02/evidence/loading.json
3aee746ab490b390e0eca575ecd7a2f248b0d024a258941dda690c9a8a474875  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-02/evidence/storage-manifest.json
040778e74013b2ebcfe9c43cbda89ef78fae3cd3c62af69bb99e784a6402ea88  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-03/evidence/adapter.py
4fd14856cc51a26ed223062b6d7786cc1f2c5260e5eeaf5c36ebbbac92e35ad4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-03/evidence/input-environment_art_loading_contract.gd
c1c202c1207710592d98be87b92b0ec28c519d1baa2983277c17a6a88657a09e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-03/evidence/input-environment_art_pack.gd
c672fe961a6098323540e120e158d2af194c7430378aaf2516c161e218136455  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-03/evidence/job.json
c238a40f94b6ba6a307bb00154f0134dd8c4180424f5afa1fe6066ccf4c78fd7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-03/evidence/launch-claim.json
d477e3c9176323db0be96eca10799d9a6c16bf3979ce7d2be0c5bbf235b6c523  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-03/evidence/loading.json
35b0d875d05fbb5dd615656097a9f967f4657a2897ee9f2e37303640e3bdd4b3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-03/evidence/storage-manifest.json
51a6096363d8ac4ac708d289d3718eac049ddd8ce8db46d0df8fcdc571c626a2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-loading-03/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-runtime-01/evidence/adapter.py
18481900fac20d683db11ae0019c840bbc40ba2753c70de2431c2770508df934  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-runtime-01/evidence/job.json
23976dc9225cb5b3b8aa923dde77da02ac460df3d2ec56bbe0ccb059a2445016  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-runtime-01/evidence/launch-claim.json
23c8764573c61f6ca08f6f7708ce243bfceafe246c0839976d1e206300dd98c6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-runtime-01/evidence/runtime.json
83daff49dfafb268b63201b39b7d27c7044e46f897f646faf879b30e8a89c30f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-runtime-01/evidence/storage-manifest.json
14da398c36746082a3bb72ac373c7fe46da1768b6ea7e72f4b73a1364612852f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-runtime-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-server-01/evidence/adapter.py
8a80e22f4e4b60eeaae8eb9c19e1f4a5077f129816befcdf13caa0a01c4fe307  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-server-01/evidence/job.json
9ed2268f400bbbfa5a6122fe6d3741b432a0dae95f614957a2581d250cf0bd9a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-server-01/evidence/launch-claim.json
a86746cbcb5ee22cca3f5c9d87d4e159ac1b88c33b9a6146a8dac728eaceeb99  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-server-01/evidence/storage-manifest.json
af569a3699d38922c3e5b1948a472c593f7cb25adadd1f4cde42f34907554dca  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-server-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-travel-01/evidence/adapter.py
95572044d00ce934030e9604dc8cea63b08a67483fd3bc01f064bb36a109631d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-travel-01/evidence/destination-preparation.json
99646d477bff73e15822c34d1e5a3010db1bfa0133fd97b2654d7870a329a56f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-travel-01/evidence/job.json
eba6652d28513f690f9e6ae937f478a44ce85506d3b3e870c9a12250aa12e7ee  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-travel-01/evidence/launch-claim.json
9014e4ad3b126d9613466ffe1d3ecaa4a434f9378af15d82cfe804fed5ea33e2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-travel-01/evidence/storage-manifest.json
b517d240ec86c22166cd1ef0325533a3c905b6409d28d10d5c69eb070315defd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-travel-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/adapter.py
18fbc2fb962d846d0cc6ee228b4bb71369bf1ac4b92556aea3c2734bcb3565c2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/base-selection.png
2c1ea6e48f2c452669151b42c243840365c67e7bbbc52084e7434fcb4ad92f46  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/gas-after-idle.png
246cf3362ed1429a65701ec66484b3019685cf01aec9e57814b8c03b7a100978  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/gas-before-idle.png
df4934d1abcdd2fc10554b0bdf429b7fc0fb6b5c63e6b76c99ebc27bdcde6ae8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/gas-web-idle.json
46bdda3cc3a4fd93889a666d846f78851d8004c13e748b4e3ec9f3a2cf6a6c5a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/job.json
1830d85dc92180a77ca72cd0c69b80cb8c37135058d2c9d3fa3c0872d3194d1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/launch-claim.json
518285557e08fc8cee0510157b3ab4303c8dde7c324e413d4714adf5520f944d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/storage-manifest.json
4ec6c909bb11a6877174162dc104bceda35645b19725bed8e1bbe998b9f24e65  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/web-observation.json
aed94962191d40cbef79b8db5df3450a98b379fae89cd43c4786c2a9eb89a0aa  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/web.png
db2ffd2ea19fc2e27ef8575e37a5ed1180aa995f0b18dc6f732f14ceff517091  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-web-01/evidence/worker.log
7f6040859a0ad012dab74b299092cc68295e8f1d53e1f6e60eca85459ab38a1c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p6-seal-01/evidence/phase.json
```
