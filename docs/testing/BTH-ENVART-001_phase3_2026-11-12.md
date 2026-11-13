# BTH-ENVART-001 Phase 3 — animation layer

Status: implementation locally qualified on `codex/environment-art-layers`; NEXT pending later owner main merge. Contract unchanged. Original code routines and PNGs retained.

Before: Phase2 draws the pack background with no art animations. After: all five closed types are pure functions of the existing flicker clock, with frames/phase/loops, pulse opacity, mover gaps and clipped source regions, scrolling with arithmetic wrap/clipping, and origin-to-endpoint sweeps. Typed precompiled fields are used throughout draw code. Consecutive blend runs retain CanvasItems and preserve manifest order; a 2x nearest opaque SubViewport composites the identical striped underlay, background and mixed/additive animation below counters/scenario tint. The first frame draws the background directly until the surface is prepared. The underlay is retained after that, avoiding duplicate work.

No canvas processing or idle schedule was disabled or changed. The same root redraw calls request retained animation redraws; placement overlays cannot suppress them. Reduce Motion and the existing Grand Web detail switch control individual entries exactly as specified.

## Actual checks and measured changes

- Animation contract:30 passing checks, including actual GPU-readback pixels for frames, pulse, clipped mover/gap, scroll boundaries, sweep endpoints, mixed/add order, still hide, Web opt-out and all-five Reduce Motion pixel equality between clocks0 and99. Final alias-cleanup run `r2-p3-animation-04` exits0.
- Background contract:14 pass, including a valid packed Gas canvas advancing clock/redraws without pointer input while placement is open (`r2-p3-background-02`). Unchanged mandatory liveness script passes (`r2-p3-liveness-03`).
- Smoke content/per-frame tripwire:1 ID,0 findings (`r2-p3-content-03`). Final-source Smoke runtime:6 IDs,0 findings (`r2-p3-runtime-02`). Existing224 Python qualification remains applicable (Python source unchanged).
- All20 missing/rejected-pack pixel comparisons remain exact (`r2-p3-fallback-01`). Final optimization is restricted to the active prepared pack branch; code fallback remains unchanged. Real all20 captures plus Gas1920/camera poses are in `r2-p3-captures-02`; Gas reviewed, labels remain readable.
- Early cost probe01 failed due to QA Windows path escaping. Fixed without changing product. Probe02 measured a regression2.454922→2.691144ms mean. Probe03 after blend grouping still failed the strict comparison2.462261→2.569500ms. Both are retained, not called passes.
- After retaining the duplicate underlay, longer balanced original/current/current/original sampling (180 warmup+600 autonomous draws per block,1200 per version) passes unchanged no-higher mean AND p95 criteria. Original mean2.569123ms/p952.798ms; packed mean2.342955ms/p952.474ms. All retained child draw bodies included (2400 callbacks after vs1200 original), excluding GPU and probe bookkeeping. `r2-p3-cost-04/evidence/draw_cost.json` retains each sample. No threshold relaxed; sample count increased.
- Phase0 inherited project validation/UI-coach/native-addon perf limitations remain open. Content and all six runtime Smoke IDs match their zero-finding baseline. No broad all-green or qualified native-addon performance claim.

Existing perf-overlay complete-frame bounds and memory (not isolated draw CPU):

```json
{
	"environment_id": "gas_station_casino",
	"idle_draw_cost": {
		"avg_ms": 7.34558765432099,
		"count": 180,
		"max_ms": 66.6666666666667,
		"p95_ms": 8.33333333333333,
		"source": "complete_frame_upper_bound"
	},
	"liveness": {
		"scene_idle_animation_active": true,
		"scene_idle_animation_redraw_count": 76
	},
	"memory_static_after_bytes": 388835041.0,
	"memory_static_before_bytes": 352342967.0,
	"platform": "Windows",
	"texture_memory_bytes": 110232337.0,
	"viewport": [
		1280,
		720
	]
}
```

## Captures and delivery

Before static pack: `E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/gas_station_casino.png`.
After animated pack: `E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/gas_station_casino.png`.
Original Phase0 play/menu captures remain under `BTH-ENVART-001-p0-captures-02`. Main menu still uses its old source until Phase9.

Every worker admitted E: storage before writes/child creation, used12% aggregate CPU/2GiB Job assignment-before-resume and closed with zero owned processes. Raw commands, outputs, captures, failures and manifests are hashed below. NEXT has not received this branch: the existing main-only pipeline is unchanged. Required NEXT acceptance remains pending the user's later merge. Final20-room and12-doorway delivery remains deferred.

```text
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-01/evidence/adapter.py
055f965cb556493658c2681a34edeeda881c97110af6eb1271842168c8e51f27  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-01/evidence/all_five_types.png
0b006ae7bfe50860eef21b396ea9df662303b389a76d8ce4eab8a0f65b51874b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-01/evidence/input-environment_art_animation_contract.gd
1e53e1f7ae14dac196ef280a11b51f509a4bdd2f599b26ad16a39febfd601857  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-01/evidence/job.json
8bbb85e8ee11658c8a996d2e28867ea4b543aa71efbf7e092c38d72b710833a8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-01/evidence/launch-claim.json
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-01/evidence/reduce_motion_first.png
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-01/evidence/reduce_motion_later.png
a29196a87ad614f60ea90231474f489024995f29ed4354f0cbfa75bbb65cd142  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-01/evidence/storage-manifest.json
e5fb7e7f28c3ecc32359e11e85bd31c9547c87fc77e214ae87f33b15aebe261e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-02/evidence/adapter.py
055f965cb556493658c2681a34edeeda881c97110af6eb1271842168c8e51f27  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-02/evidence/all_five_types.png
a1a8a67c0bc775d4ba937a27adbdd65adda15ecc76750655ffa058cc48afb4ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-02/evidence/job.json
4e5172ad832d7411b58925f17bc575218d339e8a19a26949c0e7e533a2d53586  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-02/evidence/launch-claim.json
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-02/evidence/reduce_motion_first.png
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-02/evidence/reduce_motion_later.png
c2456dc60f1cbc6d180c305f9137c2d89ebe6cc1a3cdc9b8198e4b081942f739  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-02/evidence/storage-manifest.json
e5fb7e7f28c3ecc32359e11e85bd31c9547c87fc77e214ae87f33b15aebe261e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-03/evidence/adapter.py
055f965cb556493658c2681a34edeeda881c97110af6eb1271842168c8e51f27  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-03/evidence/all_five_types.png
60f062df9ff955c1031dc998e60f77252da378d43d7f9010f8991e0ea3a649e2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-03/evidence/job.json
41caca0a135f492031b3793e29f9127164a2f23070c9bcf9f3b167e457b382df  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-03/evidence/launch-claim.json
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-03/evidence/reduce_motion_first.png
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-03/evidence/reduce_motion_later.png
85241140696b70da72b5730da8819ff4f35d8484c2eeea453f47b0933ca792b5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-03/evidence/storage-manifest.json
e5fb7e7f28c3ecc32359e11e85bd31c9547c87fc77e214ae87f33b15aebe261e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-03/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-04/evidence/adapter.py
055f965cb556493658c2681a34edeeda881c97110af6eb1271842168c8e51f27  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-04/evidence/all_five_types.png
3fef73c91aed633fb28b2d296dbf75980e27bf941760157377e0f6fb8e1fe5a3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-04/evidence/input-environment_art_animation_contract.gd
50321bf34d51c6d894f8f16b99cfe435c6ceb8790a87626cd271989ec71a56e1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-04/evidence/job.json
d25065379ddd30d9182cd4500d8a1661ecae498f8a6a87fdf0ba64615eac199d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-04/evidence/launch-claim.json
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-04/evidence/reduce_motion_first.png
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-04/evidence/reduce_motion_later.png
480342a406aecabc230e83b20b7c06f2f7005ee054f55dd85b4a0fbdab89ecb7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-04/evidence/storage-manifest.json
e5fb7e7f28c3ecc32359e11e85bd31c9547c87fc77e214ae87f33b15aebe261e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-animation-04/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-01/evidence/adapter.py
aa9e7dff82191b971c46988856facff2d91192ee45f2b5fc71b0e188174b0fac  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-01/evidence/job.json
76e1204e3689e4fd879e81b9c22fdd06ba62060b531207cc4ac3a932a684b1dc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-01/evidence/launch-claim.json
378002862a4ea79e39dfcc164a3fbce1c9d61e95a34b38a63c9276ae7077a494  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-01/evidence/storage-manifest.json
fb1360b179b932b20552250bb4975005a20d14a70abc99ad6bf1af1abb928125  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-02/evidence/adapter.py
d4a7ed5298989a15514e449670408561cb69d65e6cdce07cc052322ce0031b76  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-02/evidence/job.json
575bf0bcebf6ac1884d7e82670f20ddf304a222bdd3222c6f09b1d7080d4f052  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-02/evidence/launch-claim.json
aa5ebec57e0783921db1717e3b83a8646157933db529cacf783170d2cb967153  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-02/evidence/storage-manifest.json
fb1360b179b932b20552250bb4975005a20d14a70abc99ad6bf1af1abb928125  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-background-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/adapter.py
f4284a2bb5a2642f98145eba75475d52c400e00ba1d7841333c331aa5ce08efe  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/apartment.png
5b19f69d121a542b38444d8df31cc72ff62b99d2b2b0dc835ba584467014604f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/back_alley.png
6220905c3a339cdcb2c9694f669b5927716f59c39f0350f177c7f6f6083e2b12  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/bar.png
b0dfe40c246879e1894f39b8df9bddc61783de206876dfd2012b39ccbe7d1c5e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/beach.png
5177515954b115f2f4625b71e91e3cd819f5e2b6084e333bc0a982de7bb160c5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/camera_samples.json
baeb6fd59af8650912e240fa64aa3badafeb37180880900758d01af4aa7f9cd6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/corner_store.png
9ba56fde5d6cb701b4e765515a658344b2a86dbe979f58ef95d71b9c6f62c805  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/delta_queen.png
2c09660fd0d2f34a7e8a133488e52266711a27c1194d13cb6494ac449b69ea4c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/gas_station_camera_0.png
bcd7c96f7e3a2a35b83096dacfb2dd260145ec1d6210d0ea4963e1e7eda07d29  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/gas_station_camera_1.png
bc0d6fee335d7c3f9503cdaad28dc421e6819d7d84ac8d83506cb60b427c38d0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/gas_station_camera_2.png
8640a55be3ff9354040cbfec9941bd9fdf0f75e710ae15caf8aaae17167c494a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/gas_station_casino.png
3e8ea33a6fdda80dae2e7899ca74917a15d4f11c3036b338f78ba60035b17804  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/gas_station_casino_1920.png
26adfedae9a72c7d91245eff1b63de308fcd6945d497ad09b0d7884fac9e94ab  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/gas_station_casino_menu_before.png
a245fb7edf281b76d01e3d24fa30de21b4438ea0dbbad9a9a0d183fc7b04e4b4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/gas_station_idle_cost.json
48ca04bce006cf0abaaf796132173b8ea1d7e458c2c0271ee166692b91f359f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/grand_casino.png
2b06238b2b0a49c32adaa73fadd0c98b887adcb957adceb6bfb35fc33086b5fc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/grand_casino_back_room.png
e36c487dd696c1bb1868d31d6972811940a0250c52dbd878ea474dc3331f5e2b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/grand_casino_cage.png
99f58e0f601f11093a217c3623bb799861abc6e9377d69f5528f89ae3aa620a0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/grand_casino_high_limit.png
64fc8f0c61919d2aae154ee1a674866abd4eac46b287aaf69f00bd2339ae9519  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/house.png
3e510d75e911fc32e1aedfb2901cc053b558b76413d6e97fd4fc24a6ae14b478  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/jazz_club.png
f868406a8763595482d3d33cddfcb87fdcc067364ebf14ea6e9d2a7a23d2483b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/kitty_cat_lounge.png
afd503a70678657e07c87c3b22dfc77b6c13ab79705327f7c7f96ee74859fe1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/layout_report.json
61dd6646806da95651fd4e7492c3905305f099441808bb101d04448963dcf3a2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/motel.png
c2f2d7ac9316007fb51dd430dc493bc590616c013e0c6b543d4ca36f216f9d0c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/motel_room.png
6c2479397488af11e2369f044d34cb059917c3e3773a0e98c553d12f4e1b7dc2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/pawn_shop.png
d44cd7ef77c746c71db91c3012d40dad48820998292af0c0e8649455a660dfe9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/punchline_back_room.png
dbef492f234a3cbe9b736b1b5d44f2b46fdc08a2e27e7b1736406bb276f2d8a2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/punchline_club.png
9fe58a1757eda112f8cd2f90e8d3ca746159b1ea447b81ab24d5d3d5d22bc2d0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/captures/small_underground_casino.png
9fe53d2219c9693379904a5a08159c534d650dc40ec37751f29f15e2c990f22f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/job.json
8c6e2d22b3e4f62c55d1d00f020f3bdfce0e5f98c5a310dc8b215670ec4f16ba  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/launch-claim.json
025a3dcb5571c31ded7b40f20b4ce06deb7165c187f592e4a8b7ffb261a6257c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/storage-manifest.json
01b0b5796d64ca4aa57d2fc05bcb6a5bbbdb342c4c1c181d37fec1f0e4844856  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/adapter.py
340232f2eb1b2ad44e60a6461d2643221ebb159a7315d89e8479dfabf0a21ecb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/apartment.png
d05d977ce3755fc00d537513bb2bb18e2698fb9b7f6c5f54e429aff037b2282c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/back_alley.png
c0fc18f28366a956de6d7d9dd035e3231fad72402e8b66d33f95e544d98374e9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/bar.png
4bae0be9b6e2f9f0111a1ec844066c9f9830515eacb6ee1d8203d0fb1ecd191a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/beach.png
0c55d3cae4ff87fe209919d825beb9da318aad55ac9fe7867890c1389980b414  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/camera_samples.json
bd819f94e7c012fbc24019ade22420e90f8b6bf420a916ea0fbdb22e9a5dc5d7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/corner_store.png
86e649ab43f52690bec755c8503f436b7a24cfb287afcb173248e565509813dd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/delta_queen.png
3ff53e8feb082af590d94d1b1fa7f60838c9ab082ff1c5341732fa6d917f7f30  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/gas_station_camera_0.png
79f0578a1fb7348274c69dd0cd63b9a9e6c3189eabe4c1761f265e623548dac0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/gas_station_camera_1.png
46ab759c623848dbcd67c80df9e6400aff119f4cc7c916743dc1b7a177b0792b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/gas_station_camera_2.png
01398d1cad1c5c767449fa94b7e8fbfa328ea7fc6efbbd518f81cb8729ed32be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/gas_station_casino.png
8ecb5ec262e77a28a8c9b5500e4a53cd84f9e1f786a18753a426d495dfd9dc43  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/gas_station_casino_1920.png
1d5821dd7789f98ee61a019832bd6b849c4e1f7e5d8bded6520c73de59af2719  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/gas_station_casino_menu_before.png
5e5955bed805f23569aec18f021fb196dc08eb76eb28272f6357da072494c306  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/gas_station_idle_cost.json
2d23c793cfe66f70c85c871002157a925cf172e02042f6d6821a48f6c41c5345  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/grand_casino.png
0f09fe689133c1192c442f948013d1a14a358dd52c69e44647fc7954b187c352  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/grand_casino_back_room.png
f16e2dd820e8523a785e58791526ec525c8147437a4b81d1c3b9926ff7879187  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/grand_casino_cage.png
5f183fb3de359ca39a79116b9f684f4fcd166438fc009eb5bfe4ddde93ccbe37  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/grand_casino_high_limit.png
b2b704905d5b6207d9837e56251b73df238885d2fc491eb0403ae4145e2ce012  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/house.png
289411472c8a3659a6ff777f4dcfc9a1700bfa8e0bd5d3263896ef22ab8e6e77  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/jazz_club.png
3616b71f8dae3e27ab509bffdebf0c7afe918e40085270475832329d5c635c78  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/kitty_cat_lounge.png
93d9f2197805f62d075c9942b55bd02a0fa2c6f69daac19ebd2759631b815be7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/layout_report.json
a258380f3a034218487bdc04c476cc6a75f4222b872ab8a82a2551f61ccaa9ea  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/motel.png
4f1a7a36ca4c0debf33457e22d3ceff736f9db115c3406a7b74dd1b02fe646de  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/motel_room.png
40bc35bda33bf6fc0e21c8046dfdeffdd3806a974bbff3c8e504d362c31f6908  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/pawn_shop.png
b73630f9266b6090f86cfead0d5305052eb3e2ebe72c5fe9115c534c620294e2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/punchline_back_room.png
ea3b4b5c90d4df20c25e87fa93967057493ef3f7073b1133c60d12e4f66d8340  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/punchline_club.png
9198720f6b277d7e59f963a049778d9641e631dbc25edf2a1e9b5ffe072aa904  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/captures/small_underground_casino.png
fb185a45b27142ebfedb74cf598b67867df6b93b265b1ae800fb124fd33b1738  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/job.json
b98315fd5e2afe079138b2d159de69375604f56e38f792515fdc9a8f7f124fa5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/launch-claim.json
022e504ae683016bea697f7960f59d3a36b8239ff689046afbd8be466690ea4b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/storage-manifest.json
efd86dde0a1da81a32374db49d3f95b35fcbad00059ed50b11ea7efd22d77a31  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-captures-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-01/evidence/adapter.py
1dc87df33bd50ce83ee2b9836caa5d811910a61dfa74c301e4ac597c898833fa  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-01/evidence/content.json
c7b436da7ea95322cacdd016817b4de36c3776ffa676198efc50d7f502eef23f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-01/evidence/job.json
bfc1f9ea639b2575b6fcbdab0050a671582fedc19fb17fc5f6be5b924354f056  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-01/evidence/launch-claim.json
76291c111dc5d23878d0a409acb91c21b9be48b97fa6eef77837b506814e8c71  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-01/evidence/storage-manifest.json
695d7670523cf2be2b227e38a6da6a28508c008572e5cadfbe518c9f39608dd8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-02/evidence/adapter.py
88cd88c0907273175c6d9e00b15ab152d5e22dedcd11f66cca7e30cbb0337c89  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-02/evidence/content.json
e0b8a479371021ff9882f6ff546d6294a971249642a14912f7b8a6557dddbcc7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-02/evidence/job.json
9655e38321263e59166031ce4d8bb307754cb98bcd2051849d6bbf5f411fac45  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-02/evidence/launch-claim.json
cfe229515fd00484f32be595ed45296f2fc8498ef4e04473213ba150230857bf  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-02/evidence/storage-manifest.json
d6835a79133545655144828d117b26e0d1438f70a38398f521e4a54704ee0224  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-03/evidence/adapter.py
1634c46affcdcb8e55e419659712543191ae397a789ebe8a0e2b20489a75928d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-03/evidence/content.json
0957bae64b6beb97cdd3e3b52c11a808a4f8875ca69558acd344e547b24f6bec  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-03/evidence/job.json
bc0aab08116c39c5eb4b235b8d2e036ac9d18188c5dc874203f65c73de029f2f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-03/evidence/launch-claim.json
03257ba910f0557b54813d711f5597c3e0b692361fbc8eae6d13d545d6c90e35  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-03/evidence/storage-manifest.json
afae5b9523e459909f273fccd6d2fead60f77aaaa6471009d6dbedeab2876f76  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-content-03/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-01/evidence/adapter.py
e1f5d46364e588316a3d26a214545e0023fba195aaef125537b38f2565081747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-01/evidence/draw_cost.json
f789acee94511a538610d21a8eac562c48e20509ff5d7593036535201a4e93f5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-01/evidence/job.json
e8575e589603c65b95a1a266725939ebca591f342e9697948a6e2c37417e1f53  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-01/evidence/launch-claim.json
419e94a103ca324ba1ae5cc0e6b0a2e91869b451d43f8cde9e3fdd26ef8a1640  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-01/evidence/profile_renderer.gd
ae34259ced117d33063388665dafc36302605dd35c83f8ecc864adc2ca3906e3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-01/evidence/storage-manifest.json
9ee4d21a5379f2e8a17203873195c9a5a69fccd68fb6c86b73a9d744edbd7349  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-02/evidence/adapter.py
8eec47be7f7f457255ee7d745b3462a917812c75a2940c7451b8c4b7c878b616  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-02/evidence/draw_cost.json
a28f63c8a1bbe83754c5e5a25e3e270827cd4345b1398e2edf4ef7862fcc0b7b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-02/evidence/input-environment_art_draw_cost_probe.gd
7dc3ae4f9c66313edf3d2837fee3aa056f1ee84c148ed33783542fce936ec4ad  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-02/evidence/job.json
32558c9166ae53716e0b1522180f51efe4223e5af1668c48eb82ff6680adafea  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-02/evidence/launch-claim.json
419e94a103ca324ba1ae5cc0e6b0a2e91869b451d43f8cde9e3fdd26ef8a1640  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-02/evidence/profile_renderer.gd
17204a74145123c7eaee9b0f996513284106efa77de6886afe83e0e338c6d1aa  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-02/evidence/storage-manifest.json
e2084c490da9b101f32efba814c32acc60d8806be205da2b0a81a362acdffb7b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/adapter.py
ae5303ec54dfca2497a1bae419be22358f8c7203f6a19236b27c181753edd962  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/draw_cost.json
b406cc4a03d1213f9770701737e65ca179fd7adae4394ab54cf1069002b1dd94  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/input-environment_art_draw_cost_probe.gd
dda387dcb16328aaf7a689aba95af0b5fcba6a94141e2d781fa22ff5f83d680f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/input-environment_art_draw_profile.gd
e4709d8b64ce301dda0b9be4494b17c0fea4cfb08b87449e8c0ef0d42b9d5724  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/input-environment_art_renderer.gd
e980e1f78f2121eecaf4d4bd68bf14a063f3fc93f0039eeaf39fb05325353d3e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/job.json
3e8735724593daba75863f1eaf0ac255f579518fe100d6fe84226b398805b16f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/launch-claim.json
dd8ccf7b8d3f4f7369b1b351058255b09de49d8a58e104757f63400f87cc4282  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/profile_renderer.gd
83d597b96e3efa519160ed83adb3da87fc4b74717b08605168e8d435b170aad4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/storage-manifest.json
71475020a1aad31c1b35aa993e47da390f54dab76855f71d624e8d4fbb06fd0d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-03/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/adapter.py
813a85e14d523e0f840a2aec42986718a4dd7e2243cd17a6e56c613446e29311  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/draw_cost.json
c6d30c382bac6d8b0f894cda74466673b31601ca78f0afa5d8d55c19099b05e3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/input-environment_art_draw_cost_probe.gd
a4e48ea260e27fcb72850f4a2517cb987183a3ea8646c8fcb7dd8ad831501123  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/input-environment_art_renderer.gd
d4a4ba302daa73d15ac33a9be0a9733ba0bef37d548ee8c02e3541421567aba1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/input-pixel_scene_canvas.gd
6d68e3ee4e8fefd6f05535c60a6596844ac80f03a225b91428e2eb4f26a1fcdc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/job.json
672be8901f51aec99c0080d95ed32f8872bb0bd015ad42c292a789d78de49e32  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/launch-claim.json
03ec840e885a65e73fa7735fb0685aa03e191c50b4c8a43a801beae8ef1eb70b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/profile_renderer.gd
fbeb1deeabb8729db027da8bd882f2d68361b3a29eff08e0148be8322d45802e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/storage-manifest.json
a1f3dfd6acf011f1b9b336f24bd01aa1cfe00ca2d16ddb44aa6bb753abd8849d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-cost-04/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/adapter.py
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/apartment_after.png
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/apartment_before.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/back_alley_after.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/back_alley_before.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/bar_after.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/bar_before.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/beach_after.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/beach_before.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/corner_store_after.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/corner_store_before.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/delta_queen_after.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/delta_queen_before.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/gas_station_casino_after.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/gas_station_casino_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/grand_casino_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/grand_casino_back_room_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/grand_casino_back_room_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/grand_casino_before.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/grand_casino_cage_after.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/grand_casino_cage_before.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/grand_casino_high_limit_after.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/grand_casino_high_limit_before.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/house_after.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/house_before.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/jazz_club_after.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/jazz_club_before.png
f9858f8b563908043c89987dae4d518181f34703d3d765f1c18d28e105c7a778  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/job.json
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/kitty_cat_lounge_after.png
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/kitty_cat_lounge_before.png
a119a3ee9bee71a7f8317eb2756818202624b4fec69fedeec96db99f33b62fce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/launch-claim.json
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/motel_after.png
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/motel_before.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/motel_room_after.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/motel_room_before.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/pawn_shop_after.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/pawn_shop_before.png
45b52f3335285e488836c99e29b134f877ad4274fdd91a46acb13a7c877fa0d5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/pixel_comparison.json
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/punchline_back_room_after.png
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/punchline_back_room_before.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/punchline_club_after.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/punchline_club_before.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/small_underground_casino_after.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/small_underground_casino_before.png
65b2373cfb30f6ce53d467e9cf75b2191ab30f3766a2e489192e6d6f25aef874  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/storage-manifest.json
25a024df9a7f59b550bc423237aaeb468f863a9b9a7d39308debf2d9890ab302  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-fallback-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-import-01/evidence/adapter.py
6fd4c30a0ae4a8830e6acfc5f982f0d3d09091cbe84f25b538cabd1dba333cd9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-import-01/evidence/input-environment_art_pack.gd
de28fcab4e570cd4d7bc81ff69982beb5f807e308aa9628d131b7daf9c58cec9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-import-01/evidence/input-environment_art_renderer.gd
dee6e6f870f610756500c6be09ac1b9a6082477340015b6669138852613c2cae  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-import-01/evidence/input-pixel_scene_canvas.gd
7c2ec9d8af50c49474c3756a194f2754387b753ecc4db366791a9ac64b11f47c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-import-01/evidence/job.json
b218d89566f76603832780499a9c67b56c4e8c2781288f29bb92618b3108e0f6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-import-01/evidence/launch-claim.json
c3b2bda26a72754ef4fdd6174c4c0c2c060c9e01d2441ded763988b61a02792d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-import-01/evidence/storage-manifest.json
cb6f71f4ec922a0f9e7be635225603b30ba8ea4d870c65dc44bfc9c5fbfe7465  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-import-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-01/evidence/adapter.py
05ab5b0bfa293c4e85b5c2a31ce0bc4f1811b043c27d2b90a540870acf95d3a1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-01/evidence/job.json
f24b106071d6b25a0bcfb286a1f71220cd477c512e208a2fabd1000532b86fb2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-01/evidence/launch-claim.json
b8e818673024fe3a7ba1e68ef63eff71db517922e5d51fb428a4a10521602d41  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-01/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-02/evidence/adapter.py
3df1be42c64b969363d1cfef191844f42facae710ce7a43f4cddcc219f806da5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-02/evidence/job.json
00b7617138b1363e66551164eb17e2d9630e3a594e81ace2e56dc18a84bee2ed  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-02/evidence/launch-claim.json
c2d7063211c4ad17561eb417b20122d6f90892741d7fa759440cb45eb8ffce4d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-02/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-03/evidence/adapter.py
e0eec4dbc96cfd23687a5d672b7743f502a87d54a6d97038b2d2f687df379ef0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-03/evidence/job.json
f96468535487b0d43a17ee9cd38ca3f6342e92586b502dcc2939df26a16973aa  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-03/evidence/launch-claim.json
b3a030fef280c0c247eae2ba35379d5a5b5d4b96237d717d524ef869fa6b8134  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-03/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-liveness-03/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-01/evidence/adapter.py
6b9e2f8aacd91ed67d4e1e1d94eb947f9c3ddad70bad4096d6ea1ac708c0ca46  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-01/evidence/job.json
1ad7246fb01def8e9d2ef24ebd080d7de73afe1760570874d0dd273db0759004  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-01/evidence/launch-claim.json
6e3b69ff284655154021682f98352648cf967d2a4a64c75418457890b5dc50cc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-01/evidence/runtime.json
9ff7ef5d97fdf5aa88cc410440ff0100d076ea5a8806c1eff880d3d1164f9189  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-01/evidence/storage-manifest.json
c44d5fde30d189ab4c6c5f9e523cc7dab157bb3a713c18e9b187f5084d2ce5e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-02/evidence/adapter.py
6d3a2e6a5c9736898aae7f64f011a80a8870b8796d1b616b834123d942becb78  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-02/evidence/job.json
76f84e0a43dbac38ee75aaae94c2180cd13e18516c976752a5ff69f992ddad55  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-02/evidence/launch-claim.json
8437a44a14d85a58fbacd94d03a4fcc2a72ee624422431e835c3b37b22642bad  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-02/evidence/runtime.json
f111cc99294742b9156942b65962d9fa67896a23b63e41ba743ff34eef893166  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-02/evidence/storage-manifest.json
299c2c1166f345eff81d95707ced6a420f43aa79e4f3de357c7a9176236c4e4a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-runtime-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-seal-01/evidence/adapter.py
091cd1a32816546fd30803db0f95b14c1b8ffdd5749decaf70f601fff38dbe84  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-seal-01/evidence/job.json
6e1db0204101723577593713c86b01894c1a658e06ad10b100b74a563252684b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-seal-01/evidence/launch-claim.json
fc4ba10061e62fd97fba592916f0dc40e7e94c0695661466985735b830ec186a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-seal-01/evidence/phase.json
df47a94ed5c09bf15782d6db42fa6da1e38e29a76242a0797fdeb4a11c3b0186  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-seal-01/evidence/SHA256SUMS.txt
d54e8dd6b43a09880bbc165b5f551f03859f1ff1944d18b7dbfd4be56d6ed153  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-seal-01/evidence/storage-manifest.json
55147d20f254448bdeb1daaac4b6cbdd961033578aafd683469be72f2692f346  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-seal-01/evidence/worker.log
cd98c45a0bf07db0de53ecf92eddbd0df54732acd907eb40d81fb5161101273f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p3-seal-02/evidence/phase.json
```
