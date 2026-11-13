# BTH-ENVART-001 — Phase 0 baseline (2026-11-12)

Status: baseline recorded on branch `codex/environment-art-layers`; all task states remain Open until required later NEXT delivery. No renderer/game code changed. Owner's later branch-only instruction supersedes immediate main publication/NEXT promotion in the original request. No main push, merge, tag, pin, project or preset change.

## Source and exact scope

Production baseline: `e5152c34bfe146600214fb206ec80a5e3e8a27cb`, tree `d12ae1840f5b970e6e2888be8e5c0de23ec261f6`. Plan copied byte-for-byte from Downloads and committed first as `236b972b`; SHA-256 `41758c4e59cc75f980e1d34d09db4d21aa10f49f5da77c94b9025f3498aab58c`. Parent plus eleven phase batches registered in both ledger views at `3f0b8cea` before baseline tests. Phase11 excluded; phases8/10 await the owner's final art folder.

The existing layout survey is extended by `tools/environment_art_baseline_capture.gd` to select the actual Environment Library's **Base / No Scenario** and enumerate all layered room identities. It uses the current app/generator/object geometry. Every room has its own PNG and full canvas object-layout/snapshot record. No canvas processing or animation scheduling was disabled.

## Actual before / after outputs

Phase0 establishes the before, with no product behavior change. There is no packed-art after image or after performance claim yet.

| Gate | Real result / count | Evidence run (under `E:/CodexQA/BTH/runs/`) |
| --- | --- | --- |
| Cold import | exit0, no owned process left | `BTH-ENVART-001-p0-import-02` |
| Project validation | exit1: `scripts/ui/character_avatar_view.gd:4 (Appearance)` preload constant does not end in Script; unchanged source | `BTH-ENVART-001-p0-validate-01` |
| Script load census | 866 loaded, 0 failures; standard nine split-fragment and UI-fragment exclusions retained | `BTH-ENVART-001-p0-loadcheck-01` |
| Smoke content / per-frame cost tripwire | 1 check ID, 0 failures | `BTH-ENVART-001-p0-smoke-content-01` |
| Smoke runtime | all6 remaining Smoke check IDs, 0 failures | `BTH-ENVART-001-p0-smoke-runtime-01` |
| UI flow compile/runtime | exit1: coach did not regain foreground ownership after automatic travel Skip completion; no second settlement | `BTH-ENVART-001-p0-ui-01` |
| Cold Continue room projection | PASS, 9 restored objects and damaged authority rejected | `BTH-ENVART-001-p0-cold-01` |
| Game Library | 11/11 real launcher entries PASS | `BTH-ENVART-001-p0-library-01` |
| Dave bus encounter | PASS | `BTH-ENVART-001-p0-dave-01` |
| Roulette audio | 14 events, 0 failures | `BTH-ENVART-001-p0-roulette-01` |
| Foundation perf Smoke | exit1, 7 findings; raw list below. The fresh source workspace lacked the ignored native Coin Pusher addon, so this is not qualified native-solver timing. No fallback/skip is counted as a pass. | `BTH-ENVART-001-p0-perf-01` |
| Unchanged no-pointer liveness check | PASS | `BTH-ENVART-001-p0-liveness-01` |
| Python | 180 tests in41.473s, OK | `BTH-ENVART-001-p0-python-01` |
| Corrected baseline survey | 20/20 room identities at1280x720, no scenario | `BTH-ENVART-001-p0-captures-02` |
| Web baseline | exact NEXT e5152c34, no scenario, overlay redraw count162 at final capture, 0 observed console/page errors, browser exit0/owned active0 | `BTH-ENVART-001-p0-web-gas-02`, `BTH-ENVART-001-p0-web-browser-03` |

The generic first survey (`p0-captures-01`) actually picked scenarios and showed a coach card. Visual inspection rejected it as the requested baseline. It remains retained and hashed; only `p0-captures-02` is accepted. Initial setup/import adapter failures and two bounded browser attempts are likewise retained. The final browser used installed Playwright Chromium with a fresh E: profile and the same12% aggregate CPU/2GiB Job cap. No browser security settings, certificates, caps or user profiles were changed. The NEXT redirect dropped query parameters; the final run used the verified immutable URL with the perf overlay query.

### Gas Station before captures

- [Native play / Base](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/gas_station_casino.png)
- [Native main menu / current flat background](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/gas_station_casino_menu_before.png)
- [Web play with existing perf overlay](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/web.png)
- [All20 room snapshots and object rectangles](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/layout_report.json)

## Idle cost and memory

PixelSceneCanvas has no separate production draw timer. The existing perf overlay explicitly reports a **whole-frame upper bound** for rooms; these are not isolated CPU draw-call timings. Native uses the same overlay statistics helper with process deltas. Web records browser requestAnimationFrame deltas alongside the actual overlay capture; the sampling sources are different and must be compared within platform, not to each other. Both used180 no-input samples and the maintained12% CPU/2GiB aggregate Job caps.

| Measurement | Native before | Web before |
| --- | --- | --- |
| Mean frame upper bound | 8.1484ms | 6.8978ms |
| p95 frame upper bound | 6.9590ms | 7.1000ms |
| Max | 133.3333ms | 7.2000ms |
| Autonomous redraw evidence | 77 redraws /180-frame window, animation active | overlay162 redraws at final capture |
| Memory before idle / before entry | engine static352,218,794 bytes | used JS heap275,109,432 bytes before spawning room |
| Memory after idle | engine static388,710,868 bytes | used JS heap280,628,750 bytes |
| Texture memory | engine-wide78,206,103 bytes | not exposed by browser heap sample |

These are whole-app readings, including continuing audio/resource work; no pack memory or leak conclusion follows. No layered-art after measurements exist yet. Raw numeric samples and resource identities remain in the E: evidence.

## Starter contract finding / owner resolution

The delivered ZIP SHA-256 is `6ac7a17ca7bcf6fb5e959a4af21049b07e4fdd8d2308a9454191de53729740d4`. It was present in Downloads, while its claimed extracted folders were absent from this checkout. No delivered art was edited.

`scanline.png` is16x68; its manifest rectangle is `[0,42,900,34]` with pixel_scale2, requiring1800x68 under section3. The owner explicitly selected **“Keep the full-rectangle size rule; supply corrected art.”** The plan remains unchanged. The strict validator must reject the current pack and preserve the existing code fallback; proving a packed Gas Station requires the corrected PNG. [Unmodified delivered scanline capture](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-02/evidence/scanline-delivered.png), [size/manifest receipt](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-02/evidence/contract-preflight.json).

## NEXT / branch disposition

The existing watcher and served metadata identify baseline NEXT `e5152c34bfe146600214fb206ec80a5e3e8a27cb`; the browser loaded `/play/dev/e5152c34bfe146600214fb206ec80a5e3e8a27cb/` and displayed its version. This verifies baseline startup only. ENVART branch commits have not reached NEXT. Main merge is explicitly deferred by the owner; no bypass or alternate watcher was created. Stable, itch and audience are unaffected.

## Guard and raw evidence custody

All QA workspaces, profiles, temp, native state, captures and declared outputs are beneath `E:/CodexQA/BTH`. Each actual worker has a fresh storage manifest and final pre-child launch gate, assignment-before-resume,12% CPU/2GiB aggregate memory cap and owned cleanup. Default storage admission reserved4GiB expected writes plus20GiB reserve. The source worktree on D: is a development checkout; all engine/browser/Python campaign writes ran in the admitted E: workspace. Every finished owned Job recorded active_at_release0. No active profile or old save was migrated.

[Machine baseline receipt](E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-02/evidence/baseline.json). The following hash inventory covers209 raw evidence files, including unsuccessful attempts, their adapter copies, manifests, launch gates and captures. Its external SHA-256 is `5b6b706c5d3a444a0bb64e58ebdd0857c7c6d22e6e156ba8fd1da1379fdbed42`.

### Baseline perf findings (retained, not repaired by ENVART)

- Idle coin_pusher surface averaged 66.82 ms per frame, above 45.00 ms.
- Coin Pusher V3 timing used gdscript_v3 instead of the locked native_v3 solver.
- Coin Pusher V3 300-body tick p95 51.237 ms exceeded 12.000 ms and left insufficient renderer headroom.
- Coin Pusher coin_pusher_active_skill_release frame p95 278.409 ms exceeded 22.000 ms.
- Coin Pusher coin_pusher_active_collect frame p95 267.309 ms exceeded 22.000 ms.
- Performance probe did not exercise the shipped 160-body Coin Pusher DROP/carriage/skill-stop/collect live sequence.
- Performance probe did not report raw 300-body Coin Pusher solver stress timing.

### Raw evidence SHA-256 list

```text
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/adapter.py
e14987eb29b0c989ea07501a04ef3d0b5490d0dfc2847b550c836fca8fc99fd5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/apartment.png
b54fb189afaf712716b10e247cee7353b77e2de8fc03af922fb881e8308c1cfe  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/back_alley.png
d24567258005bc3367329109ca0003d3aaa9a17626ab3c78e39490dfafd4e3a6  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/bar.png
f4f7376610e48596fbaf7b532f046aa721d60814a40d46ee3d03d9174666a1ef  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/beach.png
2222cd1375c948df40aa0f7fac12b070236f1ad372e9f24a4fb0472a22525630  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/corner_store.png
d246d985c83781f46a6938cd28e8e5b14b7337fcb1775f7a49eb61d62c35503c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/delta_queen.png
3caed9db0b2aaccb97734555084099edd9dfa0b0e9fd273945936e9f47e7fdf0  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/gas_station_casino.png
be8c50e7b3ad3e858d27c9c04675da962be681e818a835d8857c1319c20961ac  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/gas_station_casino_menu_before.png
c2684aae8ebb4569bd5da73c1817ffb33301df31939e76a2e2301abd82bebe76  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/gas_station_idle_cost.json
e23318e5b52984bd75433acfa2785c1ab3a7781cf0739cbed271261876f843af  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/grand_casino.png
d45d40d3fa42e712da8ab855f5bdd52ffa8edf1bb09e0aefa2c213ad2f8096fb  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/grand_casino_back_room.png
e3ed2fdda693387da402fd210f5467b7b1f244e709637e6a69f75b23dccb197b  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/grand_casino_cage.png
2b769f2baa761f668999154cf7d508c92867db729a3fd1ac20f555dd26da2300  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/grand_casino_high_limit.png
a1c88dff12e3b2734d9d0edad75d307efb09bc0640ca7ff6bf54e34d039bc2af  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/house.png
6cd02fbf7d1e01452a59f6842ed5e5c97e6b9fcc61d52a65ece3e34e14bdd5cf  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/jazz_club.png
054e9da63b57d27d65dfdde04159cc168eb92d308d2d79e4a4881b1902f926a7  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/kitty_cat_lounge.png
8df8701445b8e38c05c47edf9ddcfc2707a64735f3192d6b75078580c9ae3532  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/layout_report.json
c0f47bc8fc00c8409ea8697983f8f9f55f20d98a722c13837489b64c4904257c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/motel.png
fccafe6c5bad807fa2990ed4f5ef385d600152499d022304b6144be2b9515ed2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/motel_room.png
35519d05de7b2b5eba415c577d6589b9aa17d82accef8a496e9c22af301fcd1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/pawn_shop.png
253984f5f2082815bdb958a0bfa3975d78f2548b884759f6f04bdc3dfbfee741  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/small_underground_casino.png
054e8153add305bbdd1e9409c05f9cb87a20830f55018066289b4bafaa2144e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/small_underground_casino_back_room.png
8fd39037d847f97145325592c092b51a8d47bdca3dd9bf069853c1942b19c584  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/captures/small_underground_casino_casino.png
ff28dcf07b144e52e1510e495d09d4f4e155e61090ff0d50f686deb7266e0a11  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/input-environment_art_baseline_capture.gd
be51424014fcc26306da1c58ecf90b9327b5d334bb2fe51f5ddbe5256db224f8  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/job.json
228eea78483eed4fee807e8d1e7237e42430aee1939b679b409b5ae9f6cec191  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/launch-claim.json
d398f614cf02c5ebb31fc38e0e1483c4e006941216045c4ae8aac6ba400e7125  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/storage-manifest.json
fb5988920efb3f76dd421f15367846ce694ad54e636133377cd4d78d3d712e6d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/adapter.py
995cf2d8b9076b1115c57da55988f1d71f0a2a2089087ca368b0a3122bd7c410  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/apartment.png
3718a8f2369a92bcb93b5eff51649003b97e044e1ce21bb4ba08b693bb8d3908  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/back_alley.png
750b0a838a9976871c3783615218c0c18a9877e28ee4987f332de51f10d7b26c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/bar.png
42581da506fc06f206902f4112be0063bc07ae5ee72354ad7e1f89cafeb8a1fa  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/beach.png
830c64527bcc01320393d955a64504aee1d7bb156cb3a85435fa8cb93c0eb0be  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/corner_store.png
43bb1365dbcb9fe2c7e86973121548afb2268616a8390ec4a0db70e392e0d3b9  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/delta_queen.png
5e9590ba12955a7261794101d772555c21ac4f84b931b97c54665e1fe73d75c4  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/gas_station_casino.png
03c96ea9900ec030cab71a4a1085eebfa901b5fd55120ad2e31faf23f2b3608a  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/gas_station_casino_menu_before.png
da4bf697b99a17c438894eaff050c31db0645a7866cfdcb1b5ad8d79e9ebdae7  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/gas_station_idle_cost.json
7c2a0ec365e4c0079ba0df89901d1e282a0c29ec2f20cfb63d73f61d2b40813f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/grand_casino.png
ee84b6a7a1ba566e58885b0b4b372b844bb5bf58a359862d6b8b2e16a721e81d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/grand_casino_back_room.png
dfa4aa30f68b15df4d5e1744f6a555e5787ccc61651c4f22588e634105105fb4  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/grand_casino_cage.png
3bc1ebdf8105f92b48fd1d5b9b1dbf54a3a5cc2fc18b82e60c3a192b7e9e3e65  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/grand_casino_high_limit.png
b398aab0af4e6ad70ad6f9310038e815f6e9ad4f9fc2bf756f0d440550e8bf0f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/house.png
0bf88b322aba09665e29f80b1025507df76caa584b109597b1aacfd4ad56f753  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/jazz_club.png
c223383edb426c447bd4a544c03989486dd442cd241c182f0184e079c1e5cca4  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/kitty_cat_lounge.png
d44f774a35498e56132fb1e1cffabffa82f4183a709828506418fcf941e4872c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/layout_report.json
913e0b30aee7cf132fb9cb70c813cb5412417da542a270a284de29f90f121f94  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/motel.png
704ecb2df89a086a336ea23a5a14befe1fbb66024fb63babe994398ff8cfebde  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/motel_room.png
e8531a4e933f5e344d0a4ccf8e01bedfe36b53c8384d1ffb7c280a61264d5558  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/pawn_shop.png
7ea04b94c5afaaf2c6715c63e74c097ae4ca323d196d91c89c1daa53352cc4f3  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/punchline_back_room.png
969475b0e80c801385172df3a183d735b0aaf9feb5cc4bb57f8d72302975960e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/punchline_club.png
363b53032c7a7f1cdb05babd3eaf675ede87bed06098df5d96c97f0b879d4eba  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/small_underground_casino.png
89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/input-environment_art_baseline_capture.gd
b4ebf2148d54bdb9eb9aa4ad16dfc35c6132834b1527f3f91b241bc5bb6e3bf5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/job.json
110c4129bc16194e18a0f63b8d226fe21ffade0ac4c5df8b78a78440b94f0bf1  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/launch-claim.json
7fa1c87f0b112ac3432e5d2407699b9904b714b324dbe9cce80041d93b42cd7f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/storage-manifest.json
dc53a4ac54c4b610e29253dcd62ecc3e298778d6e0fd43514809a0871031db90  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-cold-01/evidence/adapter.py
79276027b0edf37c465ef90785e2b8f9c772efcde725b64d686b647a037b2257  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-cold-01/evidence/job.json
f8b29c137b9203363a8853992db46aeaa02abd3ca45adc2bce1db701dc2225ae  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-cold-01/evidence/launch-claim.json
472c8e2e84c4da60583ec0b6039766da0cef8897f6badbbe3333ad8bdbcaf0da  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-cold-01/evidence/storage-manifest.json
bd612d20b28df2d07e4fd5ce72ae4d8bb3488780f81ed27a742c23c5a2791f9e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-cold-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-dave-01/evidence/adapter.py
ff7eb6d9cb199c11ac546e885e87a1d324a7a765b000cc0f9d94e3c04d88c4a7  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-dave-01/evidence/job.json
88e2912512164f48120eab557021508578ac050b8099ace061dc02240606705d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-dave-01/evidence/launch-claim.json
00da5a25a490d7415c9b3e966a32d1509ce2fa56edb5514e283741679f74dbdc  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-dave-01/evidence/storage-manifest.json
2c92efdb31068a94b3d207bc849b669f4b4e170970ddbbcca5fb0ea5281050a0  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-dave-01/evidence/worker.log
4d3bfd104e9fde31cc9830b2808e893ba08d8dc8d247cebe9bde8a0cebdf9fdd  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-import-01/evidence/adapter.py
d086c2f312fc91e75f308be2262f9d2e00e3add82f862ec8bf2f6d3db5f26bb3  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-import-01/evidence/storage-manifest.json
34c1090e711994fd8c65eb866766969a5b81a0b65d5bb61374646447bb7c9ccf  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-import-02/evidence/adapter.py
e25669aeadebf396e38092203488203924d7ad53f0f8d0c70db1669434ef9df8  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-import-02/evidence/foundation_check_split_runner.gd
289ccaa22f51a32e0a4d14a1da4eeaa428905266fa2a25ed2e58497f371f7fd8  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-import-02/evidence/job.json
a43c3b7edc0a1a464dcdf88d7765071cae13b89008f9741fd65f4f65d4bf9aaf  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-import-02/evidence/launch-claim.json
69c9baf3694278292f134d61597c70399e8cde8cb68c6503aad8705ce0754eb3  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-import-02/evidence/source-sync.json
09a68756c8a2838606dc605450952300d58e176644be85ed88191a762936f98e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-import-02/evidence/storage-manifest.json
753702dddb08d6349c160c15a1ecfa46a883c9ce0dd58e43d36388a141e35a21  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-import-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-library-01/evidence/adapter.py
a750e50f36969648aff0655ae140b054111b1860cd1f1bd23a82b44c3a552c5b  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-library-01/evidence/job.json
e2bae80d8463953ea44caf633a7bf7e86c3e7f734c4a5e6dd852c1f671fb152f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-library-01/evidence/launch-claim.json
45580ec9d9c5d0616dba78a01276292bd0f619c0402a47ee43035cb7f5b98cdf  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-library-01/evidence/storage-manifest.json
bc4cc7527b98c6a6a477b73304601fd4f433c99407899fa2881caba00bc20430  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-library-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-liveness-01/evidence/adapter.py
82e01a7f7ee860d520e4f72b31029ed4c9a87c38421931d3d25eddb3bc22ff33  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-liveness-01/evidence/job.json
ba77df81f033e5be3630331721da33c508bfa4d822d55a9bc6910674ec31773e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-liveness-01/evidence/launch-claim.json
efecdc854568f1e7d6f5c73b8adbd08fe385ad78245fcee4b1f8310811423ef1  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-liveness-01/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-liveness-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-loadcheck-01/evidence/adapter.py
611e72f2513252baade2b389abecff0cbef7d9d4787cda6e0be0d7935dd703ef  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-loadcheck-01/evidence/gdscript_load_check.json
47e9d0233e60880fb6a62ed047c6deb721e5db2454fcb2dfd2d76f38065c0b2a  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-loadcheck-01/evidence/job.json
7df964c26f192554dfc137040a223c33c68bdc766e87e31e36a7691d3052dba2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-loadcheck-01/evidence/launch-claim.json
71401367516a900e05edea8dd00983470740462c2e7d3db32db2182bfc8db5a4  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-loadcheck-01/evidence/storage-manifest.json
3227d2f415ee89dfed2027d8dc4d31defe00ac7bda53b0e9f079d93da0b4c134  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-loadcheck-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-perf-01/evidence/adapter.py
3d58c0ff97fc0fc0ac6a34ef6dfb742d30c3611e8c9a2cb3cdfa09807f84d927  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-perf-01/evidence/job.json
1a0373e4a543e3bf1ab697e05b3d7673feb6f431090f0f14cff82403048da319  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-perf-01/evidence/launch-claim.json
3d826b7514e8b2e9f18967088b99456a13d0ee43d72bc78a98705663910ef89d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-perf-01/evidence/storage-manifest.json
3465babb343550c20898997890c74b02be8b0f26ac6be16653d679cae2b44bed  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-perf-01/evidence/worker.log
34c1090e711994fd8c65eb866766969a5b81a0b65d5bb61374646447bb7c9ccf  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-python-01/evidence/adapter.py
c41edd9d654ec5ad2e2e965939f0a615a26716ac05196f0ae955dc38d498849e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-python-01/evidence/job.json
d06e6d7f2d7c3b3489a957ef4abd7baa22d1a1b01268dce714a10d6de1945ad6  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-python-01/evidence/launch-claim.json
4d649001a942c562b2f30ecfb60a6e4b10739b0f8e1e4716d92f6b8c4dcbea01  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-python-01/evidence/storage-manifest.json
89113112edaf35f8cd07c0ea237ea43e0a911facc99cd7c71741360c851d4c01  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-python-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-roulette-01/evidence/adapter.py
ce114d0a839da2cd3f1a3804528e5eb048be50f63352c63ab5b49e8a6cf84766  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-roulette-01/evidence/job.json
ddb18ddaafc0e70a7e348613bc58357d6e462409b19b222c42a07661940495a9  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-roulette-01/evidence/launch-claim.json
30c1f30d003274ba99627f193e438b39cce60c18210e2a9407c46e5096bc356e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-roulette-01/evidence/storage-manifest.json
237847494c26bf658768d8cc3650500e9f620eb10760209d4de628ca68a03e3c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-roulette-01/evidence/worker.log
34c1090e711994fd8c65eb866766969a5b81a0b65d5bb61374646447bb7c9ccf  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-content-01/evidence/adapter.py
9c476075256811067bb11c02ccb5e6ea860a0c8cb02a82ad5fe20354912d3e72  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-content-01/evidence/foundation_smoke_content.json
0f47e82f23fab072a4bfcc90db9a4cfa688f7dbbfdea72949fb26591a82fe2b8  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-content-01/evidence/job.json
0b13153045dfd0d258f5b35c2ca93cef634aefa6700526ccf65082981b085b98  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-content-01/evidence/launch-claim.json
848213c6583fd6fea6ea7ce7f4549138bca307ee7a2eaba978cd9775d88dfe4c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-content-01/evidence/storage-manifest.json
3c911853e3dfdc1f11439dadd3d1d8bbd4d570c4c185f69e9cb9c118d39099fd  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-content-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-runtime-01/evidence/adapter.py
68d1b5e020679d1906126baeec3f2851a251777d06aae6cdcc0f3a297676608a  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-runtime-01/evidence/foundation_smoke_runtime.json
9a9bb51822c56e067d40cc95ce63393c888155586a058600b0af208a07abcfd4  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-runtime-01/evidence/job.json
7e8f10faacc53cfe32f00c85e415b7a8fd240823a6e624815759ff2684926ff3  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-runtime-01/evidence/launch-claim.json
06394f09d72be9360b3570357296bc38d3acaa38569143f83cae4a0977399be5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-runtime-01/evidence/storage-manifest.json
aa82910008ab0cab4c30cf86bf7694252f5fe66815ccb21d0062776f60585954  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-smoke-runtime-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-01/evidence/adapter.py
86b5c51be30019b3211de55432df6f673e515e30fbbf688a2a41d757bc9badd5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-01/evidence/job.json
63743c5cd8bac356ed1ebc2458a99915128b57c3b92c0e0961ba798dfd5597d0  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-01/evidence/launch-claim.json
98a971bc2e5127e7c510e0078ec5b7bc888c547ab2d750b958082a282d846aa9  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-01/evidence/storage-manifest.json
8d4c375ae4e6f7149cc9833344a50983bca0d2abdff787e7c6c3e952209d3f4c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-ui-01/evidence/adapter.py
ca0e813d3f696398e344b0c2982d94edeba49365a09333221b7e621c95bc17cc  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-ui-01/evidence/job.json
da44833aa3c81259c64fa69c1786aec12a051c65a9419dc8ff0b24032fcbf0e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-ui-01/evidence/launch-claim.json
f6f41d072083f3806bb57397f7998de54434a8898c753fc595876340ccffd15b  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-ui-01/evidence/storage-manifest.json
0018e05bf11a6f2eb04dc350042df7344c75e2e4d42b3419c1a567cddfb89411  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-ui-01/evidence/worker.log
559ee89ae2928cf99db95c554f7c9fbb48576668f569b622aa1bb7792ca6bab6  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-validate-01/evidence/adapter.py
ff8c46c060eb915cec7759a0f7205183f522474606ef265f0d53f2c41019b972  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-validate-01/evidence/job.json
b805e2ed6e1740e0cf72d9d5025282724bf5c91917cee49dd7e37e2932e93d24  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-validate-01/evidence/launch-claim.json
e17d14d524ae7db5a0e51b50faab81d5bb54190915781b4d419acf79c2a89f23  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-validate-01/evidence/storage-manifest.json
2ea8a237cb847c8df94e43d63c6fce8c2146cb34a1f85c5cfd1b685106f3d018  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-validate-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-01/evidence/adapter.py
e23310e829b7a17c59dda5254f9d5427340c876b7af26eeac49b8807cea4c156  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-01/evidence/job.json
545f4d41bc6ad25ab084db87e63e0f55202f518e76883d35d426226cc99cd7ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-01/evidence/launch-claim.json
da2886fde9faa1e852fd653a145b21e12b2fc63f2859ea8926bdfd83f2f88a1d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-01/evidence/storage-manifest.json
42e089982c2667a81f45b319bb34b664424fb6dce44f937c011fa1a8407089db  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-02/evidence/adapter.py
51c949689a4e5546cfc066b20fd59fc47ba7f8e865086cb65c1b8563b9f1ff20  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-02/evidence/job.json
f680b3b8d9c70924f791e1d2931dbef02846572343184ffb5ff1fbd1e1c28a3f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-02/evidence/launch-claim.json
c1fa959f56905b441ddde08bcf98a5a688d76736e8318f50d2ae9f1f5e06985d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-02/evidence/storage-manifest.json
285e95df83a5a3a0072152452d3c2440d84321a3587e86b45b445ed59e3acdee  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-02/evidence/web-observation.json
92a6c05cebcafec92fbbdba22b1e88cb3fc488de3e897415517aa2d51b68ef5c  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-02/evidence/web.png
20e653e51996c53b08be82ba36ce57be7e63a4f86994aa862c7a8eb0d4a52833  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-boot-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-01/evidence/adapter.py
06fcf6f9329637f270b83211696938fa0c2560ee73275a9e89a09a4e8b111387  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-01/evidence/job.json
8f18d2bc41c31a4882c745a336dfac7e2500a49db38d376c6e14b71c2d77a3e9  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-01/evidence/launch-claim.json
e6b63f2a5a3c126f456682e7b64b6376659c89a7337e2ceedc27cf26b87383f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-01/evidence/storage-manifest.json
717e8078fffd5579c55be75052a00baec8a33346eed853c79b692dab6a737857  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-02/evidence/adapter.py
47c66a09ca89d66d52f54fa0bf3db17a6ef62f5945e10d8a2b05cb589921522e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-02/evidence/job.json
bd9d05ca101fd3601ed3db8f53eb8ebd9a7b759f618409d3f5722451d8836088  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-02/evidence/launch-claim.json
fed0f23fa0f24df96df1d01dd3d05f66092e37b5afef0b101688e76d8cff52f5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-02/evidence/storage-manifest.json
b44e0cc75633baabc4e5aa57dfc81d0321c826388eb8ae0f61d39a1cb88c6256  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-03/evidence/adapter.py
6c5c3cd685cbea5a7579a20b4a476aa8604ebd51b98efdc872a3c3bf43520784  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-03/evidence/job.json
1bb81d9b354e75488b49542b53c1cb1e59cf421081c86191bba4bf5d1eec175e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-03/evidence/launch-claim.json
b3929c06a24d16d24fc7ff6d56cf4f541889e91dcd52b10aa9635a23dc2a8770  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-03/evidence/storage-manifest.json
802d6b7518426dd84d02ad2edfae6db1e430bcfad8e14f1489b332b545d32575  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-browser-03/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-01/evidence/adapter.py
ee85da15b61d92c8457c0c283f7212ce33712d74941df15426303d94858b8fff  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-01/evidence/job.json
59bda5ff2a410e517a12bcd4fd6a74ef1b1704498e52ef631a35705d7ce1c841  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-01/evidence/launch-claim.json
1036a2899ed24b4661ef31482e11df8e43af8b4261894836386d4595b99a51d1  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-01/evidence/storage-manifest.json
bf225015441e601114f1ccbf3edabf92e7cad1ce8b3d506011f190b755fb884e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/adapter.py
6fae84d076249480bd6556b2ba62f2b3ff84107541581c7a4ea667d61d3089b1  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/gas-before-idle.png
c3e32d656f22dea65def1e7cd26ac770eabb6047c6b5d2b781208ccee29efb38  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/gas-web-idle.json
d134c9cc6bba69d5deaa93c8517a515f753603a82c6f35ec1df36b25f7e4a5eb  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/job.json
3f5dfe7fd3c03dd7564c1577c48f0d785e687f10b33a090dfc187a13a31ba05f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/launch-claim.json
497da297457fe71713f51d79f0d1b88833e5bbf9011a8854aac5078dde0b725d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/storage-manifest.json
06d6eda09e4e2c65dfa25379e8bc66e1f1d5f8d1d3b7cec6c75d787dea973554  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/web-observation.json
7513e9ca8c747cd60aa00ed70c2e9d876f57ad9db854c55e75fb976ec40c3bbf  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/web.png
5d961272a7779e3427c47045e31b29c29309913b9311e5ccf6658ff7247799b9  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-gas-02/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-library-01/evidence/adapter.py
ca674e8ae6a575534ce121c9543327b0476b594eb4db0fdfff4afa1816a83fdf  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-library-01/evidence/job.json
1a4465f3e24e60646aee2d6402ec6daa885c8c7a043cbf930c94327f8281ec00  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-library-01/evidence/launch-claim.json
d46516565ce4fde4ed86365c239f22204b0d56fa73260ec0331b278554b7399f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-library-01/evidence/storage-manifest.json
e59177d370a7fa823183b74d4565b77e57f391aa2c697e02e92c1d29720399e8  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-library-01/evidence/web-observation.json
1e6b66757b68ff0cd3816c604312186cc14bd72bf6cb0c24eb3ec6597254a3c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-library-01/evidence/web.png
45a5e5efa0def335033e99887711c37f9749aa6947198875055817b8fe676f12  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-library-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-selector-01/evidence/adapter.py
fa61a326b051f4dd2bf29ea5f3afd1eeb3f2c7513d925fb521fd622cacda6746  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-selector-01/evidence/job.json
28fdd0239796ced4884d751495a3227cd8a7b92f55b248525f19de99733f3e06  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-selector-01/evidence/launch-claim.json
f57e35e6fe2476988aa051ad97d2af8ac83bb605e7713b9a87c77f45c190fb74  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-selector-01/evidence/storage-manifest.json
7deb90b349a0a9d95ae1e7a33b753b991a9521bd265186bc64c32f2ef46e1e56  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-selector-01/evidence/web-observation.json
92bc072b028a8ed45de65ff86ae9259b3127731e05cf5126739820594e5f7148  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-selector-01/evidence/web.png
d2e9bb8ab7a07515dce407f41b473b1d8796ced977f706cf2d4f54e8c4f92e89  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-selector-01/evidence/worker.log
a91ce5ef35bbc37b24a5d1091c9f9aae2820c60246b89aee15f3704d72c10cd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-telemetry-01/evidence/adapter.py
1fdbcfe44200420de0beba0a57b41c9f8bb2e06a97d2cb9d8a07673392a2a7b0  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-telemetry-01/evidence/job.json
66eda53e04eaa97dd3ae483ff19688e7f08385b8f14c719a805970138abb7492  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-telemetry-01/evidence/launch-claim.json
efb10e3720a2de022a5eb16e4ae57424dc3c870f74bc07aa7f0086f85744c6e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-telemetry-01/evidence/storage-manifest.json
853f6d895ce62636d87e01662cd6c8b8ad58413c35f8578a84a5b4119967b82e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-telemetry-01/evidence/web-observation.json
0a3079f15c938a2d35c97cbe356fd478f88912abc0230647794050b7080da23f  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-telemetry-01/evidence/web.png
3d4f41e5d27f5a208b7ddf0c9fe7622ccaa5eeb8d826f4913094c340ce1e7e5a  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-web-telemetry-01/evidence/worker.log
1c6c69a7108c39cc14d68f4d099b56b7e23b49b2b1d0840e4f7ac06c42c7511c  E:/CodexQA/BTH/runs/BTH-ENVART-001-source-20261112/evidence/job.json
a5a7f451758cb243997c50cd8df616cdaca09bc360d0be1273e9b861cdf172df  E:/CodexQA/BTH/runs/BTH-ENVART-001-source-20261112/evidence/launch-claim.json
c7a7e6684d59f565f0d43346e24e3f27751f67524a70dfa992aac87639681eb2  E:/CodexQA/BTH/runs/BTH-ENVART-001-source-20261112/evidence/storage-manifest.json
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  E:/CodexQA/BTH/runs/BTH-ENVART-001-source-20261112/evidence/worker.log
1c83c2b8295e83404bc630d0e60a5a63d7502c5ce1555e842164cb9850169707  E:/CodexQA/BTH/runs/BTH-ENVART-001-source2-20261112/evidence/job.json
151bbec9e2469eb15d446ddded52d33eb9676151a0e0ff502a02e61164c30b7d  E:/CodexQA/BTH/runs/BTH-ENVART-001-source2-20261112/evidence/launch-claim.json
b9eb0e2e587c85cf1744df90fe5ce13ddcfbab389a058cc8de0568aab9add607  E:/CodexQA/BTH/runs/BTH-ENVART-001-source2-20261112/evidence/storage-manifest.json
a2105c4a0c702b8b4afe1df25095802a749202c4b5b8d900c7937deaa2071ed9  E:/CodexQA/BTH/runs/BTH-ENVART-001-source2-20261112/evidence/worker.log
611c79bf6af088bcd202376a1060798ec60fdd1159859235be051c0fc128a847  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-02/evidence/scanline-delivered.png
c09924b1f329b68cee382896e6902e8560d31a431c02045e77e5e1b55016809e  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-02/evidence/starter-manifest.json
6fb7b66bc2b730fb1ac0cbbd23adf8589b7ac8e20fa31eda3ca0b1cbc446d22d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-02/evidence/contract-preflight.json
265ca69e3b2aa54f5cffc83ac236b8010d7f7bee024467726cea1b024069017d  E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-summary-02/evidence/baseline.json
```
