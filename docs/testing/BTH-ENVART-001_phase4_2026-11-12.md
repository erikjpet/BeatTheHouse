# BTH-ENVART-001 Phase 4 — counter fronts

Status: locally qualified on the feature branch; NEXT pending the owner's later main merge. No contract, geometry, object-layer, hit-test or label changes.

Before: Phase3 background/animations with code counter fronts. After: the existing `_draw_counter_foreground_art` first resolves a validated pack counter and draws its precompiled rectangle/texture. Both original call sites automatically use it, including the replay over a person. Entries absent from the pack and the legacy external-background path retain the exact code counter.

## Actual proof

- Rendered counter contract11 checks pass (`r2-p4-counter-02`): background/animation → counter → scenario → person/replay; initial tint above animation; identical replay texture covering lower body; optional bleed without contact mutation; missing-entry and external-background code fallback. Separate first-pass and replay captures avoid incorrectly expecting scenario tint to be reapplied after the person.
- Initial counter test01 failed6 assertions. It exposed a real initialization issue: Reduce Motion could leave the parent on its background-only first frame after its retained surface became ready. Renderer now publishes the completed surface with one autonomous redraw on readiness. No idle cadence/input rule changes. The test also explicitly redraws after changing its own fixture and examines the tinted first pass before enabling replay. The original failures remain raw evidence.
- All30 animation checks pass on final source (`r2-p4-animation-01`), including Reduce Motion equality. Unchanged mandatory no-pointer liveness passes (`r2-p4-liveness-02`).
- Final Smoke content1 ID/per-frame tripwire0 findings; runtime6 IDs0 findings (`r2-p4-content-02`,`r2-p4-runtime-02`), matching the Phase0 content/runtime baseline. Python source unchanged; earlier224 passing tests remain historical qualification. Inherited project-validation, UI-coach and native-addon perf findings remain open; no broad all-green claim.
- Final real all20-room survey and Gas1280/1920/camera captures exit0 (`r2-p4-captures-02`). Before is `r2-p3-captures-02/evidence/captures/gas_station_casino.png`; after is `r2-p4-captures-02/evidence/captures/gas_station_casino.png`, both under E:/CodexQA/BTH/runs/BTH-ENVART-001-. Focused pixel captures are in `r2-p4-counter-02/evidence/`.
- Steady draw CPU was last qualified in Phase3 (original2.569→packed2.343ms mean, all child callbacks included); it is remeasured for the completed room in Phase5. Existing perf-overlay whole-frame bounds and engine memory for this phase are recorded below, without treating them as isolated draw CPU.

```json
{
	"environment_id": "gas_station_casino",
	"idle_draw_cost": {
		"avg_ms": 7.49031419753087,
		"count": 180,
		"max_ms": 76.0343333333332,
		"p95_ms": 6.961,
		"source": "complete_frame_upper_bound"
	},
	"liveness": {
		"scene_idle_animation_active": true,
		"scene_idle_animation_redraw_count": 77
	},
	"memory_static_after_bytes": 388834921.0,
	"memory_static_before_bytes": 352342847.0,
	"platform": "Windows",
	"texture_memory_bytes": 110232337.0,
	"viewport": [
		1280,
		720
	]
}
```

All evidence workers used approved E: admission before writes/child creation,12% CPU/2GiB capped Jobs, assignment-before-resume, and verified zero owned-process closure. No old art or room code removed. NEXT delivery has not occurred: branch-only work and the existing main watcher are preserved. Phases8/10 await final delivery.

Raw commands, outputs, captures, storage/launch receipts and hashes:

```text
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-animation-01/evidence/adapter.py
055f965cb556493658c2681a34edeeda881c97110af6eb1271842168c8e51f27  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-animation-01/evidence/all_five_types.png
008cbce99e28333358d6d5868b313d4c4f498161746745d58870e2fe83a2f4b0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-animation-01/evidence/job.json
1c74bfda806dc291ca400a1719f838305921f2ad3576704b117ad36564653d6a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-animation-01/evidence/launch-claim.json
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-animation-01/evidence/reduce_motion_first.png
33514306636d8c9689562f3b8000c613e04911034b56642158050dab868c6f66  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-animation-01/evidence/reduce_motion_later.png
ae9466f237fc8601846223f7c9e71d73beef6c9123405de9e1b8cfc941c57cfa  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-animation-01/evidence/storage-manifest.json
e5fb7e7f28c3ecc32359e11e85bd31c9547c87fc77e214ae87f33b15aebe261e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-animation-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/adapter.py
6fb9c6d8e2b0206c5c79d702c9bc2b2bd37b2cdf3ed5dc8192356d65f1011f6f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/apartment.png
a1c7ed5a5d6338b955f248b67cbe05a07a643e15234a6f4cbda5e91bd64a9ffa  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/back_alley.png
9941c0b06abd38fca08b64f87708185adfd87b0d0264c1d004d6828e8b430744  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/bar.png
4938938888cb08367d3348011e5467c77f29311d0ca4df4fc519eab6715ced65  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/beach.png
221d93115e391fa227eea148dd325912ed57d33debbb6dea70f901151484da3e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/camera_samples.json
5b6ece7e28c20737f7eebd926144e96ab17c90fe5c42848d3f3f48be6174ed68  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/corner_store.png
ca58798b3956ab237072ecb02a6a399f6bd4df465643c9429e6e3979a30b213f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/delta_queen.png
953a588da9bc2dcbeb59a9d0368f021ac88b7cf82d9e9be15fe0a563f1c56518  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/gas_station_camera_0.png
a0f2e979545638ee66995e4278abb44cbcb751f8b659dd993d163652228f1698  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/gas_station_camera_1.png
6d9b8e6b97e747a8c46f7fe7578506fbc21fe026ec7f02cbd7e6e41f20471715  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/gas_station_camera_2.png
2de07eba918c6bf6f7dd41cf1e2376227f13fa2a45bc8f0c25c79551b6120ec7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/gas_station_casino.png
42d48692dcb5089ccc10ab9692c023a5c7845572f454384fca5248203e0fad6a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/gas_station_casino_1920.png
d6c220b6835ebe8e0dea2819f2dde0ca3fa89ff6c22d6a935695112841660c12  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/gas_station_casino_menu_before.png
39e08b1b4ab65b3003f73260609cf3fde5e5e13d4149d68ac4df2125f0dac6cc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/gas_station_idle_cost.json
bb22e43a0069fdd68a4512aa130cde8b8f699fbe054e813216c9ae19e5ebd95a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/grand_casino.png
fe12d24c5d235340a419f9706bf762c4cf64674f21d1dd01439ec37799678f1f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/grand_casino_back_room.png
f28e90e134c9d57936f87fe1a65365c48bbc94ddcb60887877b2005bb28759ed  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/grand_casino_cage.png
1369a4820b49698ad6b0bc907adad648a9b1bf5a358c0823339c505ab4b2959d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/grand_casino_high_limit.png
0e2bb4154f91a9ee7ef2f06fccbd53f0fab65e07b46625a570557056a134aba6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/house.png
ed9d4410b0ea1df8b46730b0f93729ad455ccba4bb3bcf9af31fd4571e08fdfa  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/jazz_club.png
cf569547f9ba15d18853b893e238e6c77723c5f5b9fb6de710054bb732af8b72  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/kitty_cat_lounge.png
c06fba051cbab9f0fdf191bb6a003723b98193547d0517732bbb046301382408  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/layout_report.json
4a9ad729ed65c5bc31b114525b7a7d6ed962cdda8f37e8eafe1421109a21e4fb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/motel.png
53d1628e2dac1a9cdc10b85067eefd976c749bbe1efe2b05f63a0a7049decf26  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/motel_room.png
129fca00a2d612196a87e5e5f0db176b532ad52108d5c5be2d3d0672645bd627  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/pawn_shop.png
b4de63b56d6c637e8e1815daae158eb3f598c246745d84ef469c37b0c25d68e8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/punchline_back_room.png
a8f843c24abb8bf8ad1a659e3ae1bea44bbc8d307f0091d8f1c1a5139d6b67c0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/punchline_club.png
6ec77f2b31fc91376678be7a5f459420046b20df1b694e74f2fba581563f6cc6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/captures/small_underground_casino.png
cf31424be3642e0c4d2241d4b22b6e12af059128f1522e955ea245aa268a6536  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/job.json
54442b0244fa3ef15e2da5427c41e85ad50f4f034a10c99aa8fefdc6f63988de  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/launch-claim.json
4b13f45d13d6943554caa02760e584ab608e39cd9a587072291b6d04929bb8cc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/storage-manifest.json
0dabca598ac2d9b4f2c73b86c57c1d19ff9568aaf3cad2ef129ba9d771082fe6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/adapter.py
82bca8e52b1ab38ac28b492f9fcb6dbd1594b9ece0b2d2c5bb8bf8fefb1f4905  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/apartment.png
a4eb29f426c8c12ec9b0262939617c00970fb818b7d8ad8303fe03658d5f2559  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/back_alley.png
281bb695a1555244166c9dce6ceffa88ef6f9edd0c36534cc045fc056dda2b0a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/bar.png
df8fac313df912f072521d8b570edd29f5038f6c4522572d1621962a06f11cff  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/beach.png
7d698d3361efe2520c7c6417d8eae65cb83af57a7972a979d69f12f756dc99bc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/camera_samples.json
a179d94c4160155b778a16aa6d679a766ced0cc638a8e7683dcb0393f98603e3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/corner_store.png
7d54dda6673c54fc02c4cb04a939faee88fb8e81ca620ca05f074e45d4ad047b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/delta_queen.png
febc3cb96775646d83641a7a2d9fad95eba83cbcac6c262a38a110257221f5c2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/gas_station_camera_0.png
8368d8eebbbc02fc1ce0fd621f0682889f02372148cfeef07dd8d225ceb96952  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/gas_station_camera_1.png
7ca701325445b26e3d93f941f6b65626dea93eafc7a4ba3f0c7763c8a89f8222  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/gas_station_camera_2.png
9e75f4afacedc041ff2efb537096d58c0c3c6ca7c20f010f3bdb823eec86fd10  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/gas_station_casino.png
4f1af73efbff930477c06707e11aaab042ee2d232cb58a69fc0546802cbb36ae  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/gas_station_casino_1920.png
3bc680be7cf4f58034eb5f01491ffef27b95f0e02a17bc9b308467b68f670ac1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/gas_station_casino_menu_before.png
6a0f5da86b568cf6d0c7e97dfbd4a7a5f9a4dbaaa06d95b8b9fbbca0c432cd44  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/gas_station_idle_cost.json
6c5ef82035b398ca9cb698ad2767420d8fd14bcb428276c5c530928470896620  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/grand_casino.png
1b78d3aa8c991b22ce1a06bc35dfff2f54ceaf0b0ee3538291197b170c4f75f3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/grand_casino_back_room.png
36ac5ce3eb6042f806a6b61b14f4ba01e7dd0995a41c95f5ed3659d1db8b822b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/grand_casino_cage.png
b1ad8dd8a0ceef5e340a54e2c43837a6a13223088360145921431bf060b2756d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/grand_casino_high_limit.png
f2505c3f42ed7f8159feed359c84a1fbdb07c1f5562336347578ac26e43fdbde  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/house.png
561447e85b02ef90838c2c1fc7333fb2afc4ea7585346137d5dd2b9284fde472  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/jazz_club.png
48c324aa7169c992ee62d115aad3cdfb53df586e389a2d42d663d7614b50d853  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/kitty_cat_lounge.png
6f5db2024101c9d71df6f09e1d0b691ce78eb9a8626d7cf73633c05bb4192c8a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/layout_report.json
687af00f47cc440482d1b9c260a22ecc793a706ef4caf96d3f4452625659c16b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/motel.png
bba6738ec2a1e5137eb5c15b4c47f467efaff0a509f17e5903fe6236035fdf92  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/motel_room.png
9f829390795422b9f92286b7e4e8dbda3b3595a3b72921779d6c34c4f7f3ece0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/pawn_shop.png
aed9835c3b507896e6772fbe2ba396b51ff1e35739ad27c9d842081919169ab6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/punchline_back_room.png
4b87271fb247bd9a6b934825f7139d135e270bd52e8ccffc2702cd39bf086744  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/punchline_club.png
fbd62e8eb5c55ba978780bc956fb3f3949f9992ed4cc58058badf3d4cd3dc718  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/captures/small_underground_casino.png
029ef34f21b43b97267390589df1b41d4a6333843101109a141fe92747fb6a6a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/job.json
e118a051c4946c165b28e9fc234c22b02ea2c4f0845b30667f2d59f9be3b53b3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/launch-claim.json
a913193351496b6ba9fa6b13c5b712dbd21ec28b7b2652a86b8131706483ffc2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/storage-manifest.json
9c85165d1cf0612097fe7a6a49c41bbd46da77ec9c7b1125356b90ebd9e2e8ef  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-captures-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-01/evidence/adapter.py
4645542f847cfeeca547378f2f97072ef3e9c51ad50c422175d3796e982fa1e7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-01/evidence/content.json
42fff579b09db53d39e831a015f4fa8717970e7aca4139528cd474d538faf3df  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-01/evidence/job.json
9087eedb7676ef2a5cde545c5877d9b99fb4a612b07f2e621633ac7accb0b958  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-01/evidence/launch-claim.json
e0a5759f0f5c351b19750cb8212c9dc301686075ce35937078bd38048213f4f8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-01/evidence/storage-manifest.json
d1a59d5f5c5473ef05d0722b9f1d7c16254dfd11e4d48d117fcf9de4efe73040  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-02/evidence/adapter.py
8cdfdbeb71c5563d459c3441aea805d65193fbd073daf86db7595a1f2a97edb1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-02/evidence/content.json
0133b1f8ff98cc692135e238cb3968f0e2950560594212cf919a6894fe3be994  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-02/evidence/job.json
e7ef43757dd60d6efb2b0dc0910a48c5b57c46a667f8097ef05df537d8e0f0ba  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-02/evidence/launch-claim.json
0cbd9d0d3ca32af9c371826b22b9fb40f1fa55b89698b5f7194f295c215ab498  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-02/evidence/storage-manifest.json
732e584542785c854f5ac291ea57e8ebe31cc7a94b2dee95f4755200be26af5f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-content-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-01/evidence/adapter.py
9f47289bd86d4de98fa04c01579dd8a94d2e7d2e5737ecf685440b7ae8d6d939  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-01/evidence/code_counter_and_replay.png
09d0825aea3e61f71ee9ac34e1275ea13978ebaa0f68d0def69fb8b7285b2901  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-01/evidence/input-environment_art_counter_contract.gd
0070d9c7ae414c8b5bdf92ac2ca7ec16161976e3301bbba41bee28d4795d2716  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-01/evidence/input-pixel_scene_canvas.gd
410de53de72421fe9c97a4aa97f4659e51505a0a80b0e26f55db038f107c4655  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-01/evidence/job.json
5c72c1d4982cfc2ba458078c38c97f7701f3da33be3ada85996f0ea884de84b6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-01/evidence/launch-claim.json
9f47289bd86d4de98fa04c01579dd8a94d2e7d2e5737ecf685440b7ae8d6d939  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-01/evidence/pack_counter_and_replay.png
6a8ed7f8981dfed20c721a0271b30b4760b957e1c71bd17236d8c8d3a58dc912  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-01/evidence/storage-manifest.json
7c18b870b92eb4a559f35cfee963d0607763d35e25fea8e3d3c6eb1d27bbf1dd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/adapter.py
5c3d85cda6ca926a04a9b907b3e5bba1db3b272ebd4908e323fb6527a1eb9b57  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/code_counter_and_replay.png
35f867b9c90a1b168941fae03f868f6ef302382f8b6dd145ae4f9da5e00d7a15  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/first_pass_scenario_tint.png
9148011c8702be52351a124a35348e532d2a8eebae6007b83d0b84a1d82d5479  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/input-environment_art_counter_contract.gd
2cdaef9bc601f121ace06f37a15e24bee033691e6daa6338f24ec51e4102d7e3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/input-environment_art_renderer.gd
fbd428142aabbb1b75d8b98eb267c5c28ca58f977aa9f524db456ab3403e567e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/job.json
7c0f44998a9b67bccd4690ce5366ac35a17512db6e6cd1f0971e792991ec7c63  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/launch-claim.json
a2212975ea5781d66c27ad1783956361b8d2c93ac55251d5039e6f4fe6c325a2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/pack_counter_and_replay.png
fae2cc751001ef4cd17bb9a5fe322177267898bac71310f394a17c4ddf359f23  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/storage-manifest.json
6245ab3a5249debda46253a0e4ca1c3f02d85a9ddb3baacb1e09266445ed2404  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-counter-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-01/evidence/adapter.py
a929413fe1ae6e0b77ee76b2919de76da24b54921cd3d09a12ed91ea4b1bc98d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-01/evidence/job.json
d214f276daeaf8375a05742a306271c02d634a03a593d2dc8b80bbfa11873144  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-01/evidence/launch-claim.json
a7160937045e9a4467ff1b119250b210a5dd3f077b52879e9ec370dc67cc7015  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-01/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-02/evidence/adapter.py
67fe89b4537fc033e39b86e2fe15dc10bc120d2d740a50b2c0441cba52c30168  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-02/evidence/job.json
58a3777d9e3927c3204b169456af6e3356570050e58df6cf39b7bd65461d21c6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-02/evidence/launch-claim.json
dad8af15add34353d4122ca0e46c161bec0cb36a463679d6861a86dbdd11be2e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-02/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-liveness-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-01/evidence/adapter.py
fb7e63216953e589cf24c88e306905c77b8a0a55a4bc6b54cbee23250372b46d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-01/evidence/job.json
c560b3cc81bb45c49b5c5625149b172da270271f41fc5708dfdc73b43bd2440a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-01/evidence/launch-claim.json
637f6a4bd3830f72f30a449e373026e1256a4e14d4fec6948317b50547d4aae3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-01/evidence/runtime.json
4b933ae8c8e594b193f48d24a42ca587afe67a582b99527e6b6deeaae4664448  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-01/evidence/storage-manifest.json
db121e8ee5db365ab81b7bfb464b28cd0ddfcec2200941ab9846e8c8af95c224  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-02/evidence/adapter.py
8fff78297005fc8263e4931e7e349b1bebe424b381d53158d9fae4ac81b92447  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-02/evidence/job.json
385515af952aacc715cb7db71ea90f494ba9fc509002546c098d3ba0c6d8c4c0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-02/evidence/launch-claim.json
5529ef8c7ceac9747585486f19453601e0464328f46449229f94451b21b41103  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-02/evidence/runtime.json
b1e33f20bc5bca263fc9131040c51d7471f50b8200f7f55cb3cabdd740a36495  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-02/evidence/storage-manifest.json
28888e066ad235d988646f6541c72aabaafd0c664d8c68bb9400cc70e6d5d138  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-runtime-02/evidence/worker.log
b754d21c862f636713d2c1ce20a15446f7fa4e2c19e1ae173ca945d08b5b1a35  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p4-seal-01/evidence/phase.json
```
