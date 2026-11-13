# BTH-ENVART-001 Phase 2 — background

Status: branch implementation locally qualified; NEXT pending the owner's later main merge. Branch `codex/environment-art-layers`. No main or pipeline changes.

Before: original renderer at e5152c34, Phase0 captures and receipts. After: cached enabled/validated pack resolved using the final room art identity; nearest-filtered background replaces only the room drawing. External-background precedence remains intact. Missing/rejected packs retain all room and scene-life code. Scheduling, geometry and object drawing are unchanged.

## Actual results

- Cold import exit0. Background contract 14 assertions pass: packed identity, external precedence, nearest filtering, bounded cache, missing/rejected fallback and no-pointer clock/redraw with placement overlay.
- Unchanged animation_liveness_without_pointer_check.gd exits0.
- All20 original/new fallback pixel buffers are identical (no tolerance or masks). Reproduction uses the exact original source in `BTH-ENVART-001-r2-baseline-source-01/evidence/worker.log` and controlled static snapshots. Production-loader rejection coverage remains the65 Phase1 checks.
- Smoke content: 1 test ID,0 findings, including unchanged per-frame tripwire. Smoke runtime:6 IDs,0 findings. No relevant Python changes;224 previously passing tests remain applicable. Broad Phase0 project-validation, UI coach and native-addon performance limitations remain recorded in Phase0; this is not an all-green Smoke claim.
- Real Base/No Scenario captures:20 rooms1280x720 plus Gas1920x1080 and three existing-camera easing poses (zooms1.21/1.289/1.333). Reviewed Gas and a camera pose; fixtures/labels readable. Static captures do not establish absence of every motion shimmer.
- Paired draw-body CPU, same actual generated Gas snapshot with10 objects,180 redraws each: original mean2.478067ms/p952.565ms; packed mean2.395544ms/p952.481ms. Includes all retained child draw callbacks, excludes GPU and probe bookkeeping. Passes mean and p95 no-higher criterion. Probe instruments copies, never product scheduling.
- Existing perf-overlay complete-frame upper bounds: Phase0 mean8.1484ms/p956.959ms vs Phase2 mean7.372ms/p958.2997ms,180 samples. These include scheduling/noise and are not isolated draw CPU. Autonomous redraws77 vs76. Engine static bytes352218794→388710868 before vs352680371→389172445 after; texture bytes78206103 vs85464337. The new background adds7258234 texture bytes.

## Captures and raw evidence

Before play: `E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/gas_station_casino.png`.
After play/resolutions/camera: `E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/`.
Fallback image pairs and exact comparisons: `E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/`.
Paired timing: `E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-cost-01/evidence/draw_cost.json`.

All workers used storage admission before writes/child launches,12% aggregate CPU,2GiB capped Job, assignment-before-resume and verified zero owned-process closure. Exact commands, before/after outputs, storage/launch manifests and captures are sealed below. No checks were skipped or weakened. Contract unchanged; temporary corrected scanline remains authorized. Phase8/10 await final art. NEXT is pending, because its existing watcher consumes main and the user requires branch-only work.

Raw evidence hash list:

```text
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/adapter.py
ea6a2ef8111276d1caca581c9b6e4213660847e202e714906645e0e109163159  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/apartment.png
bf65a00e9e23438dccda847fb1257bbc27446acbb9b1dc4fc5cec318fc120b6e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/back_alley.png
32b00e76eed6aae1cc7d523037e37cf22dd758f451dc8aadcb959c8638096204  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/bar.png
8ef7ab7ce93eecd2b3654bc6f897dd50baaf37e4c19c74b9d1914fbd6bb7da6c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/beach.png
d90eee2f0072070fc4712ade1963b22cef0e1b86df502a0f24722c38ccb55c14  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/camera_samples.json
9ec7f590856bd58c6a9c822772ee5a1e11553eab6a4fe1dc981e15bdba375b17  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/corner_store.png
9061275c1b94017778c7bbd971d19424bd48c7c6cc4367e9ed66eda95add482f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/delta_queen.png
9d375158a1d5a1632c3eef30af102676a06f9d2d383537e3d6edf005b4417541  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/gas_station_camera_0.png
da20a1e3d9203424747b4a7d8da9420ac9ccd2594930047afdaa195fde2ff302  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/gas_station_camera_1.png
cbeece41148eaa9be6c0809f4ed371d71c88acf298c640a380346fa2e131bdeb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/gas_station_camera_2.png
a1175709dac9193b287609b901a6fe8dce1d164f66f951f87bd816de4fa63319  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/gas_station_casino.png
db0bc6e837c0a088e29ef755d0dc1e591bf197b4ad63b1a4bc76e54e0f64e6a2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/gas_station_casino_1920.png
d5d22cd4af1d05b38cd1d581042d352cc0f12996983ab64c3bda8231474be182  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/gas_station_casino_menu_before.png
b90240810daf14b0934acc8dd086dcbaa8af34635236d64ed1394a5a755b355b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/gas_station_idle_cost.json
2ad1161091fa8ba556c4943db10ce14611e59f0724049a8d6b2eafc8fa4c70a9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/grand_casino.png
730c25f608957bda8c73649913abf075ac70e4184af89a0eb038964c2a26284f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/grand_casino_back_room.png
ed0c7d719580811df12f6fa92e9b14c92a65e2d6fba848ac8deed022fde2cfc2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/grand_casino_cage.png
35d0e631ed247011c2525a796f697e667a9bfb26992107383b961b4da7341490  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/grand_casino_high_limit.png
e38344d705fb014196fb3ed870ecac0e17c755e8cbe17dd3a230f6c83af23d3a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/house.png
8f8e8506a308f6b61e288dfeeecbd01bbab91c766f509f8a83c877ef91934abd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/jazz_club.png
51867e1e1ff0b78e92e72e12667661da54a14c54e48013e68bff1a645880b11c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/kitty_cat_lounge.png
974291a1f5b3d065e82ad06fbfed9d916218ffdc303d758f00f3ee8552c30b16  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/layout_report.json
f369d73ada45b61d08434da164b0021b0891970b974d4b7a5a557a13c7ffc2a8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/motel.png
8f16a3de799f2993150a385846103ca910f21b2cbc9c902bf83c48ed0049c6c6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/motel_room.png
76b83a2552da3a32c7778969d3c64faa850dcee330479eb60b99cc3a42df9992  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/pawn_shop.png
0fc6649e6a4e148657eb76e3e0f5a89440d43ce146ee9680e773ca2a7b8528fe  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/punchline_back_room.png
95228d50e21571de2845c270bbaecd0184fb17f5a6b863cdf8a9d28754fe5c5a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/punchline_club.png
0542ee1c5cdec289da81606ec39f6426034a4b01709cee8b2efe8ad601b08e78  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/captures/small_underground_casino.png
03f1da3575b960061df89d88e88301a19b860c6081ba8f24a94429dc0e1bee1b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/job.json
aac77111d5179943beaceae699d8ab165d9137c6fa181992ecc29932db52a1e0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/launch-claim.json
f0cb17a34ebcaa68f0267ed8b99f2f089ea834248a7a38935e39094cf99bb0e8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/storage-manifest.json
0ce09bbe5c54f7c34dd072c02141682ef8556f75e14cc5aa69f3fd1c9c176154  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-captures-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-content-01/evidence/adapter.py
95ed38c00020538275f0e1907f4b7a4bb6d41811c3c329abb3109e4d1d938363  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-content-01/evidence/content.json
edd55ead86c3402d4ae4c71c8be9882df6dabe3e3e6fae89ad88f0e2dadd95c3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-content-01/evidence/job.json
3bd58cb59a681b6b52818c6be4956d0d092c1116b68121d07a6645aaada27d83  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-content-01/evidence/launch-claim.json
cb4904a7bde46dd1ed1f8c8a060b5936811d8809c30c4ba870f0e58d2446be32  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-content-01/evidence/storage-manifest.json
f911f7e7f26cc11dd11e83b9b62885f8a0f7234f16abb5fe1a1ec741347f35ec  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-content-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-contract-01/evidence/adapter.py
0ec79aee34664fe3e781562e25ae5f884103050ca898e486d1d878f4c96c3768  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-contract-01/evidence/job.json
45fe7a2661404502b83cc4756ee63f3af411a3673ea0d567646cc5d7711bae2f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-contract-01/evidence/launch-claim.json
a820c6f80dc9252017c6cbba6fc5f0441549f2de4e6d7ac890a5c7b7d6ef23bf  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-contract-01/evidence/storage-manifest.json
fb1360b179b932b20552250bb4975005a20d14a70abc99ad6bf1af1abb928125  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-contract-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-cost-01/evidence/adapter.py
de8cdb0ea7aee83fd37259d43f829560d756cff78a3a876e7036c2c757f0b605  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-cost-01/evidence/draw_cost.json
9c2baa4b56afd9ced4b8383ac9f52a95814acf7755ce0b64075daa7413467b6f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-cost-01/evidence/input-environment_art_draw_cost_probe.gd
67b7f6b808f28a988e1d4e2a875c772dc0e8e64a045892c2b8c13065fbcd6c60  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-cost-01/evidence/input-environment_art_draw_profile.gd
aaee7ee6959c40bbf8744ccab37064116b6222dd95b6bb1451b94a683ad671d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-cost-01/evidence/job.json
17bede82fd753082326d95f022fdd47f1aea13bc8960b4a1608b9a6937f32a1d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-cost-01/evidence/launch-claim.json
9c6ea91c0c53b18690e4d6f009a2d383a279ac492f722835f56ad2e8da933b71  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-cost-01/evidence/storage-manifest.json
aced577d08cb41e2be0180c2963c33368e33788bb5b17e61b4099c2a3e347fd9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-cost-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/adapter.py
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/apartment_after.png
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/apartment_before.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/back_alley_after.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/back_alley_before.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/bar_after.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/bar_before.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/beach_after.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/beach_before.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/corner_store_after.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/corner_store_before.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/delta_queen_after.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/delta_queen_before.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/gas_station_casino_after.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/gas_station_casino_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/grand_casino_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/grand_casino_back_room_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/grand_casino_back_room_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/grand_casino_before.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/grand_casino_cage_after.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/grand_casino_cage_before.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/grand_casino_high_limit_after.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/grand_casino_high_limit_before.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/house_after.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/house_before.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/jazz_club_after.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/jazz_club_before.png
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/kitty_cat_lounge_after.png
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/kitty_cat_lounge_before.png
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/motel_after.png
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/motel_before.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/motel_room_after.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/motel_room_before.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/pawn_shop_after.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/pawn_shop_before.png
45b52f3335285e488836c99e29b134f877ad4274fdd91a46acb13a7c877fa0d5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/pixel_comparison.json
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/punchline_back_room_after.png
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/punchline_back_room_before.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/punchline_club_after.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/punchline_club_before.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/small_underground_casino_after.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/captures/small_underground_casino_before.png
56597361b4844939d876fbc1cd2533c12a0c4048730bcbcf7334661b2105d345  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/job.json
c6e559eeaac2e02f6c8a67e1f09338d449a89247f4811564c9805022b8d58c09  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/launch-claim.json
514157a7bf0b036e4cefab839bc25f6730d6be4e42b6fa21fb3a53a300d0de85  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/storage-manifest.json
25a024df9a7f59b550bc423237aaeb468f863a9b9a7d39308debf2d9890ab302  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-fallback-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/adapter.py
2e183eb91045effc5be5bd8b9ff8df72112d99a34a6753b55e794d145ad2576e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/input-environment_art_background_contract.gd
bc54c061c031a46327ab5034c94884dc01359b10d82fa2666b9f709b15179fa5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/input-environment_art_fallback_capture.gd
e2d5ac043cf522da1fdcf13b3d9e34e44f3c438fe818acf23aa4d414737a432c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/input-environment_art_pack.gd
d9097a1ea752de6d0c0342995841a06bc8e720514b9f46bc72e7917ce7b63857  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/input-environment_art_phase_capture.gd
f95269c2ec502324adef3c3973296284daa80a45cc0bf29d1e286ab00125af37  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/input-pixel_scene_canvas.gd
e38a6546b0ad46efda6bf7e9e58f03bb2cb4a0e94236d9e3bdad9c840cf97981  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/job.json
b70a6e4becd33d0f89a34b8905837d9cd1ba1a7524f2261c437aecf0483197db  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/launch-claim.json
0e1e521aa6b23ebd08b2c1e36fa94acee381d763072ecad503898faac7593753  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/storage-manifest.json
e099446de59039f998d1d7826e590bb93e960f06355679a828493193572baa39  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-import-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-liveness-01/evidence/adapter.py
16eaf73ef5bb11584e565499d75e7df716e4fc757c3920120e577005a58c23f9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-liveness-01/evidence/job.json
9519eb401173a30e919434fbe1df75b301c425ab8fa9af77c175d16471ee5f49  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-liveness-01/evidence/launch-claim.json
3e80d43d24f9554d056143f5c20d0e11eeea264d96619f1fbc6e83eadadb4e82  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-liveness-01/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-liveness-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-runtime-01/evidence/adapter.py
f06356ff4879d6d4241229f63748aa0f54724cb78637898d9ab73fb27e941657  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-runtime-01/evidence/job.json
d433df6d0e766fd95a576a69fb528779887b451c31e379fe1be13e6e6d45890e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-runtime-01/evidence/launch-claim.json
11701bbfb39f9180558d944c001941eac59269ced2996bd892c62bac6b432861  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-runtime-01/evidence/runtime.json
7caec12fb8cfa919382ea98f2c9f8633624d1a400d9840af1bfbf5554d378d3e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-runtime-01/evidence/storage-manifest.json
95239015f1548e4f40fa66ed2b7f55c5a49de09e8797d81c72f6f38aa9f412a6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-runtime-01/evidence/worker.log
a5f1cc230e81bfb3b7a88bb3d14520dbb6760d449476bd7973dd326eb663941d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p2-seal-01/evidence/phase.json
```
