# BTH-ENVART-001 Phase 7 — artist reload and guide

Status: implemented and locally qualified on the feature branch. NEXT is pending the later owner-directed main merge; the existing watcher only builds main. No alternate deployment was created.

Before (`r2-p7-before-01`): production Environment Library Bar practice generated and captured; no authoring reload handler existed (2 expected-baseline assertions). After (`r2-p7-reload-02`): 14 assertions, zero failures. Physical and logical F6 reload changed JSON paths and overwritten raw PNG pixels without import/restart. Captures show blue then green owned synthetic backgrounds, unchanged live objects and placement overlay. Invalid board size gives the existing code room; corrected saved bytes restore art. Snapshot equality, autonomous clock/process state, repeat suppression and normal-run gating pass. Native editor feature=true, template=false. The helper also gates out Web, template and distribution builds; no packaged authoring control is exposed.

The view releases old art/retained commands before a developer reload. The pack reads raw PNGs and shares the normal metadata preparation and exact compiler; production async loading is unchanged. No delivered PNG was edited. QA-only synthetic Bar/Corner/liveness art and temporary index were cold-imported, then hash-checked owned files removed and index bytes restored (`fixtures-01`, `cleanup-01`). Reload01 also passed but initially displayed code because regenerated QA inputs had not yet been cold-imported; import01 and reload02 provide the final full fixture run. Expected invalid-manifest warnings are retained.

`docs/art/environment_art_packs.md` documents the unchanged section3 contract, fixed grid, all20 room/layer identities,21 foreground ids and rectangles/PNG dimensions, bleed, allfive animation types, shared clock/Reduce Motion, full-rectangle scroll rule, checker commands, preview/reload, final drop-in delivery and protected-source/readability rules.

Checks: loading35 assertions/zero failures (includes every-step two-set residency observations; total varies with frames), unchanged mandatory liveness PASS with its QA-only packed room, Smoke content1 ID and runtime6 IDs with zero findings, exact fallback pixel equality for20 rooms, artist checker valid/5 animations/1 counter/7 textures. Source invariants retain all535 original canvas functions,529 unchanged, only six authorized seams changed; supplied PNGs and spec unchanged, tested inputs equal branch bytes. Phase6 draw implementation/cadence is unchanged (strict paired CPU mean2.265158→2.246530ms, p952.457→2.452ms; full-survey texture78,206,103 baseline→97,979,409 bytes). No new memory/performance claim is made for explicit developer reload work outside scheduled drawing. The unchanged Python checker/product paths retain their224-test qualification.

Captures:

- Before: `E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-before-01/evidence/reload_before.png`
- After JSON edit: `E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/reload_blue.png`
- After PNG edit/placement live: `E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/reload_green.png`
- Invalid fallback: `E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/reload_invalid_fallback.png`

Inherited Phase0 project validation/UI-coach/native-addon performance limitations remain unclaimed. The next-phase unchanged menu check was reproduced before menu changes: four existing assertions fail (Career/Inventory/Games object presence, lazy Settings library). Its raw output is `r2-p9-menu-before-01/evidence/worker.log`; Phase9 must preserve visible-menu guarantees while addressing the current source/lazy initialization assumptions. Runtime reconciliation retains700 pre-existing global findings; no ENVART task/instance finding (the historical global coverage record references ENVART evidence but belongs to BTH-RUNTIME-CLEANUP-001).

All phase7 assigned Jobs closed with zero owned processes and no cleanup errors. Manifest/reserve checks and capped assignment-before-resume receipts are raw evidence. No contract exception or pipeline setting change.

## Raw evidence SHA-256

```text
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-artist-01/evidence/adapter.py
8e490cbe8eab76ceb2e987f1522637eb4cf76d991f36febd755560b89c03a7f8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-artist-01/evidence/job.json
535923b916dab36714efe05a68906a16251d2cb925dd7ab31b9d160ed5d1fe8a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-artist-01/evidence/launch-claim.json
f27f478de4320cb79c5881b97038b3bda3167e6004cddb2b6d435154f437ebb8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-artist-01/evidence/storage-manifest.json
83ae398ed60d5f995eb7f8768b9d25d40ef91648c44684bdedeb2f108bf1e8be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-artist-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-before-01/evidence/adapter.py
03e683108660bc000753a62de8158637820460c45a45a66db705fe19a344fa95  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-before-01/evidence/job.json
b2fcfd42fa9a2d3b9ff09d08fe91049ed2cb916b8f045c06e750749f3e767aa7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-before-01/evidence/launch-claim.json
0c00f6031548ef0b2a729aba65d37103fcc5e27ee25476ad90f0e5ed89d1970b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-before-01/evidence/reload.json
a9f31931bbcd2e97f2d4fc23298acabcbfb3128139280ac3dd9555fd5528dc24  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-before-01/evidence/reload_before.png
c2daa7f79e20615696ae6c68b747032b0d972dd7fa19942eca722b451583ab8e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-before-01/evidence/storage-manifest.json
6dbc5ee7c02e02af00d281c388fed5c255340d0c1a2c75ffefeb11275ed09b9c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-before-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-cleanup-01/evidence/adapter.py
e75974a32ebc096818d6f8bc41e215c5f4ccfb55df16bc97b40104e663ba8ab1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-cleanup-01/evidence/cleanup.json
8fabcfbd9d8bf310f6241b52985f29e6457b7541331924a21e920f0904d42547  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-cleanup-01/evidence/fixture-adapter.py
98dd4c4ea32011f95f9206b458dc783f7b00547cec897dcf0bb57eb77388690e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-cleanup-01/evidence/job.json
f88346e7d8a1833d6f47ca4fd3e0087a77e2e5eed24678325abf43adbe1b8042  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-cleanup-01/evidence/launch-claim.json
fbd82ad80210c8927f1f22e7f09326e7c5f3dd8768d2d3efcef2f46396ee1ce3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-cleanup-01/evidence/storage-manifest.json
a21172cd8502b8caebbc1f4879dfc50e984e299292703139b8e4ad836136c55f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-cleanup-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-content-01/evidence/adapter.py
e22662fec1d53950941234d3069cd4c3f9f70f97fcd53c62b4fe35c48d55fe7b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-content-01/evidence/content.json
e25669aeadebf396e38092203488203924d7ad53f0f8d0c70db1669434ef9df8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-content-01/evidence/foundation_check_split_runner.gd
ccb7a5a99c6516bcebc91c199aa7a20504de914f6e40ec1f890b7399aa7b6e80  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-content-01/evidence/job.json
779faa64451f0b3226666e57c5878149e332abd9e75486a156310ed9d57b27da  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-content-01/evidence/launch-claim.json
371a26915c363d0170cd69c25d564fc73a569dca4ef01662dd93b86bf15d031c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-content-01/evidence/storage-manifest.json
099ea0b9f21d83ac232d3d3f5844ff5d20784776a8a0959d5c09bf4421194846  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-content-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/adapter.py
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/apartment_after.png
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/apartment_before.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/back_alley_after.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/back_alley_before.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/bar_after.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/bar_before.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/beach_after.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/beach_before.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/corner_store_after.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/corner_store_before.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/delta_queen_after.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/delta_queen_before.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/gas_station_casino_after.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/gas_station_casino_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/grand_casino_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/grand_casino_back_room_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/grand_casino_back_room_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/grand_casino_before.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/grand_casino_cage_after.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/grand_casino_cage_before.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/grand_casino_high_limit_after.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/grand_casino_high_limit_before.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/house_after.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/house_before.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/jazz_club_after.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/jazz_club_before.png
a14761ba34e677e112f1a4376b9f39051a11baa9968285877b5e9989a0093b15  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/job.json
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/kitty_cat_lounge_after.png
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/kitty_cat_lounge_before.png
2a96a8b2dfd1459cb4739406c46b47cc82f18cb708a66f2160706ba8ab300077  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/launch-claim.json
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/motel_after.png
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/motel_before.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/motel_room_after.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/motel_room_before.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/pawn_shop_after.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/pawn_shop_before.png
45b52f3335285e488836c99e29b134f877ad4274fdd91a46acb13a7c877fa0d5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/pixel_comparison.json
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/punchline_back_room_after.png
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/punchline_back_room_before.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/punchline_club_after.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/punchline_club_before.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/small_underground_casino_after.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/small_underground_casino_before.png
0ac84109a0de5db7a9abc4cca910012386e5ccdbef7e73881030d6052b764556  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/storage-manifest.json
25a024df9a7f59b550bc423237aaeb468f863a9b9a7d39308debf2d9890ab302  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fallback-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/adapter.py
8fabcfbd9d8bf310f6241b52985f29e6457b7541331924a21e920f0904d42547  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/fixture-adapter.py
94e4d262eb8bde2c3464103149ae5a0abd0b4e06c632e1cf52798dcc1c8008f5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/fixture-inputs/assets/art/environments/animation_liveness_environment/anim/pulse.png
a1cf62baf1893d9ffc1a7bb50816013071a5ec97fa0f507dc0bed90087b4a678  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/fixture-inputs/assets/art/environments/animation_liveness_environment/background.png
de50ff40dcd550a4a5caa79665a17d10830abb8163da1f5ac0ffde9684a41722  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/fixture-inputs/assets/art/environments/bar/background.png
08b5ed7c88ac1c5424eec08ac8b1ed0af1a37a43b8ff9977770b3f203911749a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/fixture-inputs/assets/art/environments/corner_store/background.png
66a51597e91746491ccc006e753868672b90f2e1f3d5f0b909d88fc3c9885b21  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/fixture-inputs/data/art/environments/animation_liveness_environment.json
ca583bceb3c10b69c7f1d1a779ca6e51da6b69eb66a0f02d268d84241e00e50a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/fixture-inputs/data/art/environments/bar.json
b01b7e0d86ccc156392cdf3dbc299adeb9110a77844bb911ae5c5a2a72535948  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/fixture-inputs/data/art/environments/corner_store.json
b86c81897f7329a98cefb14989173e836a282198baa8d85893221d6b62e656ed  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/fixtures.json
597d7d521a0e35476828c024c4780f20099a42a99c43f144744a39cb76bc35db  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/input-environment_art_reload_contract.gd
b619a42ff64a685461a74daab1d3a90fbad8ae32b5d6137cfeb465805c34f591  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/job.json
e79c1c794918db9a44d57f70fd0edec7f0e8042ea2ffe7e38a8fd73d593411ff  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/launch-claim.json
c7dff69b2f1ede1be818bfc1fce387d5e774edb64de990e26344b035be2dcf4a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/storage-manifest.json
fd00b9d69e8e521653bbe77f134a1efde134c703c3259cb43d6d7d2d83489639  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-fixtures-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-import-01/evidence/adapter.py
9256947dbb47f3f6f234a265e47cbf01b1b757c478e97adc990ddebc92925959  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-import-01/evidence/job.json
245954611373f383e8e29ddb6bde4a6da422936994aef84138553fb6b52c203d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-import-01/evidence/launch-claim.json
07e8d5ce5cfb09b27a1b1a138144667a98d6dc51b9c28cba4c8b503eda901bcb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-import-01/evidence/storage-manifest.json
2851e22071a02e90fcaee505d85aede99c7bf8bbd15858dd1d4e3c240879b249  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-import-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-invariants-01/evidence/adapter.py
3d94f5e48a9baa894342bc3189a91995874e9978b4f1316f76ce71b19f818659  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-invariants-01/evidence/job.json
12dd197430bfcce30f407dfbb5fb92b6746ed9ba238b5021ddc696da463355c1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-invariants-01/evidence/launch-claim.json
ed97cbd9dc7686a326d7886555c84d1a70771a443b225313c55570859ee29953  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-invariants-01/evidence/source_invariants.json
8f5fb1b16af7fb68c0b2856fdf3c08a35749e75f02a8a3ec9769ada5cb7ee2b3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-invariants-01/evidence/storage-manifest.json
341856e09c9c32af5a262923866501922a6a9f6e7442a7492febd1395e026dd6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-invariants-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-liveness-packed-01/evidence/adapter.py
8d01d3cd90dc0d15de5594dddd9bbfef4d177d219409dc9b62e5163cb0cd605a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-liveness-packed-01/evidence/job.json
ebed04fd737c930bf656e80a9f010cd109ea02917ec43620c9c124cec20359d2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-liveness-packed-01/evidence/launch-claim.json
92ddb5e42be47d0c0c1972f5471c1fd6fea8d7b5e3b6f2d91b4384a91558eac4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-liveness-packed-01/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-liveness-packed-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-loading-01/evidence/adapter.py
6269b5f410120cdea097beb16e00f234da22caaeaf8aa51af3ae10888110122f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-loading-01/evidence/job.json
f8a43ffe68f4005304a2695ff2bd3fdee1fa58c788722c1a77a20e220674a0f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-loading-01/evidence/launch-claim.json
49859b10a99d5184225548cd535d528a1973cef4f2d0eb6c6e146a8fbbbcb093  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-loading-01/evidence/loading.json
86acf7188f176b01e303d5a4a8cd98b63a7ca42ea774f06c29978969b0daf289  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-loading-01/evidence/storage-manifest.json
4013eae3f9e15fe374becccfef712126093f3277b8c825f15ee9919347e4a043  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-loading-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/adapter.py
71f0a41df2e01d1d060797b91ee9fb3631f332f1a336ca7271c9811f44a98508  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/input-environment_art_pack.gd
8a3345afa353c3d00d645bddfba2f738fd0ca136948b15669f5ba2ed4f375d8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/input-foundation_main.gd
b24ac475bab6cb51f72b549254de0b47fae7dce2a4ad8e2de6888a31beb02e27  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/input-pixel_scene_canvas.gd
222d4e91e67f7639a70aa50a891975a9746139e223d3a3b5079677b1130e4ddc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/job.json
f56b559205fa51d608f0ade513d1caafa04b9649314bf08883488ee7b91d0018  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/launch-claim.json
b73a2c18198e7452d80354adb58e199fffe79d8af2a5b352a0be11946c5c012b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/reload.json
270ce897a20abd08be1e36a672819f2f79cbf22a9d245889c81e637d98f8e10a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/reload_before.png
d1ae88af533fc65aeba9b71af712dbaa962ca4e6a94328f777456ab22359aadd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/reload_blue.png
467bc3b792a0c8492cb7ad6d5fa8de5cbd02e4558a140f9df116dbba646627ad  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/reload_green.png
6b626d265f204f43fe56d863de5f82e751864b5cbf429a777f7713331e870e96  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/reload_invalid_fallback.png
d0f60a7dd9cd209c26b5db24ee508c103fd7bde91530291fccdfd24dacc454ee  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/storage-manifest.json
47bd63d5d7a7bb640692f67d91896e4346ad65031c8f21f113197d930eea3947  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/adapter.py
f776bd3cf19a1c5d0bd288ddac6b2609447da260406a1aa38f204e66c3305d87  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/job.json
1c358f5f3c84f421b3245568d57de9ca9d99d3408537cb8b1fee0d4941dae646  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/launch-claim.json
b73a2c18198e7452d80354adb58e199fffe79d8af2a5b352a0be11946c5c012b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/reload.json
88a89bf7e2765896257e884c95e77219e1170228d921ae7e02445e56a18cf93b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/reload_before.png
b94f228180828eae57885cd057017886236370baa118a8e5c06067c11d727db4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/reload_blue.png
cc77401f25a956a491cbbfb457320e414b3e84bc707ed7e6a3d771eb8c67a7bf  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/reload_green.png
d802be2a32ee87abe3597ebf154e21d15f959abc84c37f6457ef93caa3bf6d05  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/reload_invalid_fallback.png
2d7ef6c13312359353a4e8665605ee61fd1fd01b8ae85a2c1b49c618e1f532cb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/storage-manifest.json
2e251a02b2d42bdf09e03b1e73339a6e607ed40de2a62dfe472885b69d6db1d3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-reload-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-runtime-01/evidence/adapter.py
de23e4642ae8d40dfa45524b9be529b16155ce8baae3338801fb67ffbcb45003  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-runtime-01/evidence/job.json
c1229906a5c86b845c7f3d23158cfec6d5985cd9083a05745d72b1bd050376ca  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-runtime-01/evidence/launch-claim.json
6b429d21c3e8e0a8dfd954fdbb431b1cec0add0d220819d4da19661c76b19aa2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-runtime-01/evidence/runtime.json
a099bc4364baf339294a9d6d96ec6b2f70032ccdd9b44c202537daea3d14320b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-runtime-01/evidence/storage-manifest.json
b0ba11c32030789811c989b88fa8fa4ec2d1b56e71307156107be0d114380b95  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-runtime-01/evidence/worker.log
fe07465b7b3c52fbf5353b32d508becb50b51c8a3b6c9066efcb2ee0c4a88926  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-seal-01/evidence/phase.json
4d59adcb07ddf672e2a8d9384f6342ceeb5dd5423c762b370123eaf37095d62b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-seal-01/evidence/job.json
3f74e5ddfb9da8b1a300b6ed75c9f7c50365eca426746841f50374147b6345a4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p7-seal-01/evidence/storage-manifest.json
```
