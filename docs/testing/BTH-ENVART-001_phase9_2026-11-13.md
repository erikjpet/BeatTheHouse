# BTH-ENVART-001 Phase 9 — packed main menu

Implemented on codex/environment-art-layers for a later merge. Local art checks pass; NEXT acceptance remains pending. The existing menu redesign check retains four reproduced baseline failures, so this is not an all-green menu-suite or NEXT claim.

The selector now chooses only enabled room art identities, including Punchline's three layer identities and Grand's four rooms. It retains immutable content references and duplicates only the selected room. Enabled rooms use the same canvas pack path as play; there is no external flat texture, including during live-code loading/failure fallback. Only an empty enabled list invokes the original, retained legacy selector/PNG path. Board/camera, click-through, object code, rules, placements and menu UI remain unchanged.

## Before and after proof

- Before the menu change: unchanged tools/main_menu_redesign_check.gd produced exactly four errors: Career remains on the main menu; Inventory remains on the main menu; Games remains on the main menu; debug game library was not moved into Settings (r2-p9-menu-before-01). Source confirms the first three controls are built by the existing screen builder and Settings is lazy. After: exactly the same four messages, no additional failure (menu-after-01). Only the background-source assertion gained a bounded wait for validated packed art; all other assertions remain intact. No UI removal or test skipping/weakening was used to hide these existing failures.
- Final focused production-menu contract:37 assertions,0 failures (menu-02). Natural Gas selection, same compiled art resource as play, unchanged framing/click-through, autonomous clock/redraw and visible pixel changes, stable Reduce Motion, all20 candidate identities, layer identity retention, immutable library data, missing-pack live code, empty-index legacy fallback and byte-exact index restoration pass.
- Enabling the live packed menu exposed a shutdown warning: seven RefCounted art objects remained at exit (runtime-01 and verbose-01). Main now releases its static pack cache and drains outstanding engine tokens at application teardown, alongside the existing prewarm drain. This exit-only drain never runs at room arrival or on a scheduled draw. Menu-02 tests both ready-pack WeakRef release and closing during a newly issued load. Runtime-final-01 repeats all6 Smoke IDs with0 findings and no ObjectDB leak warning; the earlier warning remains raw evidence.
- Final content/per-frame tripwire1 ID,0 findings; final runtime6 IDs,0 findings;224 Python tests pass. Unchanged mandatory liveness passes with a generated QA-only packed room (verbose liveness-packed-01 explicitly loads its PNGs), and again after lifecycle cleanup (liveness-final-01). All20 old/new fallback images remain pixel-identical. Final source invariants retain all535 original canvas functions,529 byte-identical, only six authorized seams changed. Supplied PNGs, the spec and pinned project/export/native inputs are unchanged; tested source hashes equal branch bytes.
- Final isolated Web export02 and browser web-02: packed Gas menu and production library Base/No Scenario play visibly animate,0 console/page errors. Physical F6 has no packaged authoring handler. Full five-scenario/Reduce Motion Web qualification remains in Phase5; Phase9 does not change those draw functions. Initial Web export01/browser01 is retained as an earlier lifecycle version, not the final artifact.

Native full20-room survey includes Gas1280,1920 and existing camera easing poses. Before files are E:/CodexQA/BTH/runs/BTH-ENVART-001-p0-captures-02/evidence/captures/gas_station_casino.png and gas_station_casino_menu_before.png. After files are E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/gas_station_casino.png and gas_station_casino_menu_after.png. Menu-02 also captures the final lifecycle source. Web final captures: r2-p9-web-02/evidence/menu-after.png, menu-idle.png, base-selection.png, gas-before-idle.png and gas-after-idle.png. All raw paths in this document are under E:/CodexQA/BTH/runs/ unless fully qualified.

Visual art finding: placeholder bright fascia/window highlights compete with Parking Lot Pat / Buy a Drink labels in the final Web Base capture. This is reported with gas-before-idle.png. Live coordinates/labels and delivered pixels were not edited. Final art needs a readability review against baseline before room acceptance.

## Measurements and limits

Strict same-frame paired CPU draw bodies,1200 root draws/version and retained child callbacks included: original mean2.286859ms/p952.472ms; layered mean2.272246ms/p952.458ms, PASS. This measures scheduled draw work, not GPU time. The final follow-up changes only application teardown; canvas/renderer draw bodies and cadence are identical to this measured run.

Existing native perf-overlay whole-frame upper bound,180 samples: baseline mean8.1484ms/p956.959ms; after7.329915ms/p956.944444ms. This is not isolated draw CPU. Full survey engine static baseline352218794→388710868 bytes; after353203200→389695274. Texture memory78,206,103→95,916,649 bytes, +17,710,546. The final menu shares the pack rather than retaining the old flat Gas PNG; Phase6's forced-legacy-menu comparison was97,979,409. A background alone is6,192,000 decoded RGBA bytes; animation textures and the retained render target also consume memory.

Web Base baseline:180 browser rAF intervals, mean6.897778ms/p957.100000ms; JS heap before→after 275109432→280628750 bytes.

Web Base final:180 browser rAF intervals, mean6.948750ms/p957.035000ms; JS heap before→after 277441917→277373111 bytes.

Web packed menu final:180 browser rAF intervals, mean7.157750ms/p957.025000ms; JS heap before→after 276763757→274683537 bytes.

Browser intervals are whole-frame upper bounds. JS heap is not total engine/GPU memory; builds/menus and GC state differ, so these are observations rather than a heap improvement claim. The pinned no-threads Web template executes background requests on its calling thread; one PNG is staged per process frame during departure/loading. Do not claim off-thread Web decoding or zero main-thread work; no pin was changed (see Phase6 primary-source explanation).

Final PCK 124978744 bytes, SHA256 2d5826bebbe87258b321c1a283a1527d35b853376afa3185fd7270bc169fd707; existing deployed main PCK 124979752; numerical difference -1008 bytes. This is an unbound local QA export versus pipeline-bound main, not an art-only package-size delta or NEXT identity. Cold import and normal export are separate; override is absent at export. Verified pinned template/current-main Web native asset reused, temporary owned addon inputs removed. Native host export logs retain the missing Windows addon errors while packaging the verified Web library; browser has no corresponding errors. No native gameplay/performance-addon qualification is inferred.

NEXT observation in meta-02: watcher source_branch=main, deployed e5152c34bfe146600214fb206ec80a5e3e8a27cb. This feature branch is unmerged and not deployed. No alternate watcher, manual NEXT build, main push, force push, tags or stable/itch publication. NEXT checks for every phase remain pending the later authorized merge. Ledgers remain Open. Inherited Phase0 Appearance validator, UI-coach and native-addon performance limits remain recorded.

Stop here as requested. Phases8 and10 wait for the final20-room/12-doorway folder; Phase11 is excluded. Needed from that delivery beyond the starter: all20 exact room/layer ids; full-size scroll textures; final counter transparency/bleed and readability on each scenario;12 same-path/same-size doorway replacements and generation provenance. No contract change was needed. The supplied16×68 scan line remains untouched; the owner-authorized generated proof PNG follows the full-rectangle rule.

All assigned phase9 QA Jobs (including earlier failure/warning evidence) closed with zero owned processes. Raw storage manifests,4GiB write+20GiB reserve gates, capped assignment-before-resume and exact cleanup receipts are hashed below. Final scoped ledger reconciliation is recorded in the second phase commit; global historical findings are not silently changed.

## Raw evidence SHA-256

```text
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-01/evidence/adapter.py
27230aa5610c5cb46ba5bab7278464981de0468d64102b677718641d3e22215d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-01/evidence/job.json
b2a3a25c417e9b51fea844d7c696d186a1788116fbe0953354867fba14f88def  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-01/evidence/launch-claim.json
7fb06f0a16ee276457d10ac4bb0c7ed75697166ae61434d90d3abfaed5983bcd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-01/evidence/storage-manifest.json
0954830b8adf3c457d4e685a158b696ee0c12d4400ab422e78f83f98de55ea42  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-02/evidence/adapter.py
2bbd79ce2980ef462c19c15a95f1c2a0dd4c3cb60741ba057a63b22dc184214b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-02/evidence/job.json
172e8ae11d85ffbfb93591f0c41015f06ab9e55d3b00c357895d58be3f9798b6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-02/evidence/launch-claim.json
e278402871ac35790b40adec8ad6fb0f0d17ed568c877469ae1e1e1a8b869d93  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-02/evidence/storage-manifest.json
d36c7cd58f2a74f63f8d74749512d3becdf77f9596c6fe8134b9d08cd18ff38f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-browser-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/adapter.py
527312e770ec951ceb9303aaa6d49af52d8ec9df05a92d1f87df3f0d8dc8a244  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/apartment.png
85e5f3276f399304b809e351128c4882a4637eab91010157168c4cb7779c4775  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/back_alley.png
cbad0d004d4f464d2be40da668cf5b898108f70da27a3d9f30a20e29405fde08  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/bar.png
4813930feab82572d529fadf71348865b3def0a24448948e9aa506208da3c2e2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/beach.png
8c44612f9c84920ea302e9be7daee184bffd09bbaba3fa0a00cb56659ac0b252  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/camera_samples.json
adb2f881723ca21e935ab48886f1ee732784663f9454e87b1b2b048b843284ab  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/corner_store.png
139205b243f62ceb09089855557b2f3561a33f3146ab7cc5dddea715c4291e33  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/delta_queen.png
5059a35f08346eab37cbeaee9997a51e3372a7ea66d166dda9d14102bb00b53d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/gas_station_camera_0.png
4fb2fbe038c23452fa912a16d9b5e9570b92176567121dc76fdb4dcb500b83bc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/gas_station_camera_1.png
f4fedaac83a7dae5002e261d844791dffd7eb6bd1a8a4a63ef757da07e21358a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/gas_station_camera_2.png
79a9626d64a8d42a84d89fb9683ba226dc539046007b8243e057af5950c6bf8d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/gas_station_casino.png
f80ff42f3456e42ed203dc2518b164f81b1dd59d0a35652d7cdc5139a6b81327  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/gas_station_casino_1920.png
cca86f561926a347e58e59d7a245b001ae32f076db61173f152f35c40a455bd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/gas_station_casino_menu_after.png
6f735c348cafe8f611fe875f1f5eaef19f40f248ecd086a0e27b567a77916bf3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/gas_station_casino_menu_idle.png
4f88c70b9ee71f4bb800756c925b14e1c7489b1938598369bc46ed9916e8df54  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/gas_station_idle_cost.json
4e93e7b3e225b93d9a93329cf8380c732a9438467342e24d9d5356e4f75ce3a4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/grand_casino.png
87e38f4c48142cb420f145174f1be21ee11882b675d42ad7393bd614a3fe6f48  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/grand_casino_back_room.png
bb2fd45c3f04a1b70df206305f331802b13c78269448c2e1098c9b760bf52248  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/grand_casino_cage.png
5af1a6425e26e3b6a45124ff6fc16c4e12fa028302e9c609b2a3aee6038508d4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/grand_casino_high_limit.png
277319794bb91fb00d5645c5873207c5fe4c86ed1c478e073c576c54451a4dc7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/house.png
ad5fda50026081ca6c54a56ee1af0f3b11c77956b794bae0bf218afb395e2039  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/jazz_club.png
12da50a31ea30250041b19d5cc465b804d330389f99e8d154f3f3373bb68a6c3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/kitty_cat_lounge.png
ddcacbf5434ceb226e70fe9d7c6c573696e36e9849561bbba089559c1027cca1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/layout_report.json
480da5457ef1aa2a78e6973495bb4ff23b7f099e0837fa2d44375ca136bd3be7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/menu_liveness.json
03cb7ff1726ce5481ac0fe87f7afec64b01a68e49fe82ca021854168bc37d942  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/motel.png
abdff3fb525a48605a8bea6c8dbd6819c3e533acb87c27687cd831d88e870f20  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/motel_room.png
e7da8965d4bac6fc2276cb6a8e2b20fbb18d6cf116f5a365c55bba7fa971286c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/pawn_shop.png
7b7b39f87dc3f7fa70d9af586c937857cd3eeacbcfe261325b8852ed643fb193  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/punchline_back_room.png
217c9784cd675bf4db018efd045f326d66e1716d1a6b2e4ceae073d03d6faf7b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/punchline_club.png
4e8b1c9d6edc58069cb2c785522c0a7b47d8a2f92fbd838c3f6322329c23a5db  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/captures/small_underground_casino.png
ba2fa14fed22fe6bba23497b13beb04d87dffd26b076af03e1f193e2c105da81  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/job.json
f5a32d17d754be9fae0a1a5172e80fab88fe5b4a007b8d901745e41142816e9a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/launch-claim.json
60ada0eeeedcfc4ed3609e2845a87d1fc54274fcbad929dd31932d166eea9e15  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/storage-manifest.json
943edb562de713812c10e447b217f45117a2ad53790177cb6857e81d656cf2fd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-captures-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-fixtures-01/evidence/adapter.py
e75974a32ebc096818d6f8bc41e215c5f4ccfb55df16bc97b40104e663ba8ab1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-fixtures-01/evidence/cleanup.json
8fabcfbd9d8bf310f6241b52985f29e6457b7541331924a21e920f0904d42547  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-fixtures-01/evidence/fixture-adapter.py
b4193332625bfdde4168cae7abd43aafb523823a7fa9c8c8cffdb9e85ad79468  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-fixtures-01/evidence/job.json
e6caeb3431c3db97e466ef3ecaf514c36f781521492372e4d9fb11efcc28ea31  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-fixtures-01/evidence/launch-claim.json
a148715b20253d1fca3fb02729c06ca55687a3d03abae53ef87ad22a529e6913  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-fixtures-01/evidence/storage-manifest.json
a21172cd8502b8caebbc1f4879dfc50e984e299292703139b8e4ad836136c55f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-fixtures-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-01/evidence/adapter.py
ce56053c7d71d8f405c516562df81990891ad6743e1f869aa956ce24dfe8472d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-01/evidence/cleanup-adapter.py
b2c7617de659efa6cfe1efafaeacdfff5bd6bcf310aefe1c2e0af85db8e57232  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-01/evidence/cleanup.json
917dbc2d70a41548a5f36f89745a82208854b111085406818935d77fda5458b7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-01/evidence/job.json
2cb452427dc139e210b98ae95a04d86a56a998a3882cdb9d10a6b9ace5262fac  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-01/evidence/launch-claim.json
63e36b9a8c89aa257ebfb2d16f8d8a39e243f4180fd744bf0f3f6bff695bc6a3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-01/evidence/storage-manifest.json
884e3f164c383af039c39662716e6c0ebac7f1b1b65c38df3736b1a1dd6a9335  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-02/evidence/adapter.py
ce56053c7d71d8f405c516562df81990891ad6743e1f869aa956ce24dfe8472d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-02/evidence/cleanup-adapter.py
b2c7617de659efa6cfe1efafaeacdfff5bd6bcf310aefe1c2e0af85db8e57232  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-02/evidence/cleanup.json
4179e7fc51d4764d19faefe6a1431216fe7783b818016e75b8de5598f3208bf7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-02/evidence/job.json
fb6987cf8c57496034a644bb0f5ee74cf1aac719b52b523b19843c142416de9f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-02/evidence/launch-claim.json
663b4491f54021824a2013514ce72437034b553637b2426e7572800bca900f6c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-02/evidence/storage-manifest.json
884e3f164c383af039c39662716e6c0ebac7f1b1b65c38df3736b1a1dd6a9335  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cleanup-web-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-01/evidence/adapter.py
9d1a2f9481f28bf5d4cceaa1d4dadae9ec5f68467df070019c7423970a62dcc6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-01/evidence/content.json
e25669aeadebf396e38092203488203924d7ad53f0f8d0c70db1669434ef9df8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-01/evidence/foundation_check_split_runner.gd
ca3be63348c6e3af87176d22069a75c5ab906671531a935003938b6ca98c8a6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-01/evidence/job.json
e905757d7ad775522454e38c81b3a6dae2ea99ef108b7b8cda7d629d8f3b6822  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-01/evidence/launch-claim.json
6597be74d5a5bd19c0de8afc8ab9c3be3b28d5c48c83df60c28bdd69dc23fe70  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-01/evidence/storage-manifest.json
c646360384d981f14732903d9984f034e1aaa1512ef253fa0dfc6c97f277bf57  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-final-01/evidence/adapter.py
f756b4d803f91f4984b25f8855cfd2abd0d6c66e5e1883f7aaca24b25c9d7183  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-final-01/evidence/content.json
e4a886f11fc3a1b400e58bc31ec7b421f9add2290f46ce25edfd0ff75ee05c09  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-final-01/evidence/job.json
5fe761fd9c9f2d39587ca2eeda34d2256631b7b0e0432329e59c84caf087690d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-final-01/evidence/launch-claim.json
72e0960f220d6ae8b11d9c2648c49f3af65abbd41a2d1fc01206e591f2911989  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-final-01/evidence/storage-manifest.json
6d5603cf7e057b448d0bfa87e97dd48b79a84c76fa7cfd88f5104899dc823681  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-content-final-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cost-01/evidence/adapter.py
4f3e956f0f29f7a06e99b56c9714222fc826f53a9ea70aed91e17b0187a917bb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cost-01/evidence/draw_cost.json
e3303d3ab56dce66a340a1128b65006db02c8f3c2393ff5313884612e5705bb7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cost-01/evidence/job.json
48e7652e3777341fa63853b8f9499dde217550d28a428667f152f7df705a9b8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cost-01/evidence/launch-claim.json
651f10207f50fbd51bee6064eeb5c77f3e3cf77fab88998679a800d5fdbedb6f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cost-01/evidence/profile_renderer.gd
e353ba1a2aea3287b6946fe3d1b845b557d37a50a6f5b0d43ef6a22bc1216074  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cost-01/evidence/storage-manifest.json
c930e537137538d83d22f554750bd0f3f98d775301c5c704b9f8b918ab9fefd1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-cost-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/adapter.py
9c34c4ea306efe66a13a9707a64f53573a31779e3b300bd359ed61c2f2ec33fc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/coin_pusher_native_v3_10.web.template_release.wasm32.nothreads.wasm
afbb1f3c824d6b64811fa57cc80d65003176c68550afdfe6da5c9243d452e7ee  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/export-policy.json
c88982c8d49a27ae20ba5f3775cce2e8fbf843026a8411ca586daedcd876755b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.apple-touch-icon.png
be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.audio.position.worklet.js
5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.audio.worklet.js
e0a02a0fac9cd4cfb2a1ce6490ec034a57e5cca0a28fc7b3e23c52685817ef32  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.html
bc1bdb3acaa0c7de8a4ac147b841c604c9bc5f794616130e440e9076a84be37a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.icon.png
8cf4a21cded9270718a67c6f1aab3d794eca91e3903ad866532c925565dd1fc4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.js
43068a34a8b849874850fffd9372b07e073b18c688925ed4d98f9c7e8e6f07d6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.pck
3cb4495c0b98dfbe4b663cbf2b6836473572339beb66d902367893162a70be0e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.png
f344425186abd04d042ee9fe50439a27bb71936fb7c439ed79a3d827c2cfc5f0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.side.wasm
58263765a7f63d873211210ba389dce0b7bb45c0e50a67e978ea081ec9f1e8e8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/index.wasm
d41595526505cdb61c0370b9064bb224442ade10125d3f19a82cd5647cf963ab  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/job.json
dd2496655e341c0456baf66ce17823a887730fdc2f70ae6db2869f74263f3c96  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/launch-claim.json
5f968e8b6d802e5a10193c87a082ab345c673c99a67cec7e9be6a9bf3b501108  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/storage-manifest.json
6c9d807202c62fddda20ea119f1b51b041e45e14cb4303a47cfc8bd2a9387b97  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/template.json
46367ec66075d024672842f848746a1b9f0d90053f04ce4fa49a2ea1fc966aa1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/adapter.py
9c34c4ea306efe66a13a9707a64f53573a31779e3b300bd359ed61c2f2ec33fc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/coin_pusher_native_v3_10.web.template_release.wasm32.nothreads.wasm
afbb1f3c824d6b64811fa57cc80d65003176c68550afdfe6da5c9243d452e7ee  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/export-policy.json
c88982c8d49a27ae20ba5f3775cce2e8fbf843026a8411ca586daedcd876755b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.apple-touch-icon.png
be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.audio.position.worklet.js
5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.audio.worklet.js
c815f900132348bb4043ad20ccd1f0dbee455179777e2a9875ad80d2990a9f42  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.html
bc1bdb3acaa0c7de8a4ac147b841c604c9bc5f794616130e440e9076a84be37a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.icon.png
8cf4a21cded9270718a67c6f1aab3d794eca91e3903ad866532c925565dd1fc4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.js
2d5826bebbe87258b321c1a283a1527d35b853376afa3185fd7270bc169fd707  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.pck
3cb4495c0b98dfbe4b663cbf2b6836473572339beb66d902367893162a70be0e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.png
f344425186abd04d042ee9fe50439a27bb71936fb7c439ed79a3d827c2cfc5f0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.side.wasm
58263765a7f63d873211210ba389dce0b7bb45c0e50a67e978ea081ec9f1e8e8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/index.wasm
d35030144700d5db68e40c4157cc8b00b0b51f6137bafae8616c1700faacd84f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/job.json
075c0dfaad6af8d7b0c032ee99530d44d23d427052408d92ce539c0cc55e8e7c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/launch-claim.json
f933e30484565782c1210a320d944d440b785a699be8c0c95d0f819499952189  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/storage-manifest.json
480806901a5a1702d03a168ed833ae84da0c93d8ec4352749b2fd98169de0a35  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/template.json
46367ec66075d024672842f848746a1b9f0d90053f04ce4fa49a2ea1fc966aa1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-export-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/adapter.py
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/apartment_after.png
7b15a0a212a57fea62dcbd36c84e30a8547f12c816b0c5eb6439d929c1ae852b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/apartment_before.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/back_alley_after.png
1cf129d689112d135e89f29b128c8078bec0d425df850b4908a26b42039643c8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/back_alley_before.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/bar_after.png
5d43021887fd18bc0675e73ef5c031201c2f7db07267af88bb5ccdf5ee1f8821  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/bar_before.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/beach_after.png
1b50c404b478bf7d29d45c5498e1d3be534d162fe36e5ee3855f11a9f5259971  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/beach_before.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/corner_store_after.png
70cbbfb05da18a343ff7387941206e7d25be9b8ba1e43b4f49fa9fffb74a75e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/corner_store_before.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/delta_queen_after.png
78d621af744ac9850268ef7d5e8913c41108e6764a21672c70115ca4798a6208  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/delta_queen_before.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/gas_station_casino_after.png
7c05809373ea3d81884ef8afdff929394d70cffbfd07194c4b2049db0df248f2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/gas_station_casino_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/grand_casino_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/grand_casino_back_room_after.png
02b3caec0a26a215d794e1917ee091dd02a7b51957eb775f2874b10e769613d9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/grand_casino_back_room_before.png
0d1f26d40fd6a9cfecfb22cb387dfdc5d941ab035bb5b727617521516b65f0c7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/grand_casino_before.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/grand_casino_cage_after.png
de600e6b1135013a2a906a830905da55f3045c889b51b17c1181a1c4a2304964  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/grand_casino_cage_before.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/grand_casino_high_limit_after.png
b2dd98281cc73e5c72f7bdae4ab7803a5cf511659489cbb708f9f87713329a1a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/grand_casino_high_limit_before.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/house_after.png
5f2873fedfa9f2a31f80bac840c0da99a36623502d47c3ea51ab4249798f7751  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/house_before.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/jazz_club_after.png
89a5ddb1eb7028dc9a7c38f2ba26027e65248146ef4d6eee12d06d0e0a7b018f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/jazz_club_before.png
bba82bb245afe7c5fefbb87d59008b90de2ee2e888b844632d981e6a49c8a701  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/job.json
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/kitty_cat_lounge_after.png
5a6449bf888842bde47f98e5aba4cd47fef49d71a1395f799cbd698762f5f0ce  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/kitty_cat_lounge_before.png
6c1978d836c212eac3916aabd21219d102f055a57da128035b138fa817fa7019  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/launch-claim.json
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/motel_after.png
4454f7fb7f3842c54ab89951353f8cc8f4570218900ebee30be547a56b03b6be  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/motel_before.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/motel_room_after.png
bfcb958d10e502807dbec43527177435b9ea69bbd2a4ac8ec12bbbe5c21dfd79  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/motel_room_before.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/pawn_shop_after.png
25e61c18888d056c9fbf51525f46ed5e8b6aeb4a4069234f2dd36eb35a626747  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/pawn_shop_before.png
45b52f3335285e488836c99e29b134f877ad4274fdd91a46acb13a7c877fa0d5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/pixel_comparison.json
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/punchline_back_room_after.png
5a4c20825f08a143a8904c3ca9613b89eda24682d7703ed12aa2918ba2afd8af  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/punchline_back_room_before.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/punchline_club_after.png
d0ef61d3b79fa736098842422cabb109465414c5668cdbf7723d36c6c3e1bf8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/punchline_club_before.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/small_underground_casino_after.png
a10de8c010b707331eb132a67e347bf64b527bea39f518ae6c46adb4cb73ecbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/small_underground_casino_before.png
98d15c6a710e9c15d8025451f8b727771f54aa721b1af81c6306957c16fa8869  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/storage-manifest.json
25a024df9a7f59b550bc423237aaeb468f863a9b9a7d39308debf2d9890ab302  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fallback-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/adapter.py
8fabcfbd9d8bf310f6241b52985f29e6457b7541331924a21e920f0904d42547  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/fixture-adapter.py
94e4d262eb8bde2c3464103149ae5a0abd0b4e06c632e1cf52798dcc1c8008f5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/fixture-inputs/assets/art/environments/animation_liveness_environment/anim/pulse.png
a1cf62baf1893d9ffc1a7bb50816013071a5ec97fa0f507dc0bed90087b4a678  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/fixture-inputs/assets/art/environments/animation_liveness_environment/background.png
de50ff40dcd550a4a5caa79665a17d10830abb8163da1f5ac0ffde9684a41722  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/fixture-inputs/assets/art/environments/bar/background.png
08b5ed7c88ac1c5424eec08ac8b1ed0af1a37a43b8ff9977770b3f203911749a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/fixture-inputs/assets/art/environments/corner_store/background.png
66a51597e91746491ccc006e753868672b90f2e1f3d5f0b909d88fc3c9885b21  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/fixture-inputs/data/art/environments/animation_liveness_environment.json
ca583bceb3c10b69c7f1d1a779ca6e51da6b69eb66a0f02d268d84241e00e50a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/fixture-inputs/data/art/environments/bar.json
b01b7e0d86ccc156392cdf3dbc299adeb9110a77844bb911ae5c5a2a72535948  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/fixture-inputs/data/art/environments/corner_store.json
b86c81897f7329a98cefb14989173e836a282198baa8d85893221d6b62e656ed  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/fixtures.json
189a2a3e4f248804cf1418b0caa22335cd114883685939ddfc186febac092981  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/job.json
6e06dfa4216fad9600977923a1a4aa5714bfcf14eb58e8750abb0bd75a1c44c4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/launch-claim.json
55c1dafb66ab3021c784824ab64df1cdc500dc914b4c77ee0db40d9ec795cc2c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/storage-manifest.json
fd00b9d69e8e521653bbe77f134a1efde134c703c3259cb43d6d7d2d83489639  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-fixtures-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-fixtures-01/evidence/adapter.py
a80165d027f240eec766ed54cdb5f043dace9e74b8b71863699e58c27ba3cc83  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-fixtures-01/evidence/job.json
ac10c4b7175f9a2b98966a4a5c999d3959599ecd488f6829ef5885ba94dcdb54  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-fixtures-01/evidence/launch-claim.json
49ba21dcd8ce3e1668b6ea7a657cdd0968b23efdae17644c6c5442f3674d7697  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-fixtures-01/evidence/storage-manifest.json
48123523b3ab591d2396479bf4c20e65bf5493da87c71acaf47f7203fd8bc7eb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-fixtures-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-01/evidence/adapter.py
65d823228e58a8d0b181d095e514d30bd20834d5fb40e3c01cf264abbd18e886  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-01/evidence/job.json
144eb7cd4057a550f81ad3675ae2bca17582150a8a43868b0b04609006583517  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-01/evidence/launch-claim.json
5460f4756e1ac365b0bdd991aaee36b00a1174ac8b9cd07fd2c7e47fee74b6d0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-01/evidence/storage-manifest.json
c3d5bc0ac4ca1aa21c56fd22a7255c525bbffb9e124e3c87273b5f7356a85780  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-01/evidence/web-addon.json
565651041b652f543a4d1920161d300722109a2bed181f5300f001b7eccbf16e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-02/evidence/adapter.py
283bb387a5bfe4ee3312ebd74d5cad83e39caed5035c62e681aa04790d56b9e2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-02/evidence/job.json
0840f09f7bdadae5821f083a214d02bbad98626ace9e131771e446ea3dbb71c4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-02/evidence/launch-claim.json
20a459be75b091366e4ac05fea5c8fe7f047e891dcb621715cd4fa3d60a175a7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-02/evidence/storage-manifest.json
c3d5bc0ac4ca1aa21c56fd22a7255c525bbffb9e124e3c87273b5f7356a85780  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-02/evidence/web-addon.json
1bf7edc67efa11b580b0dccb80a4fe1ea2201655eaaf99ea762a474ba2524d0d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-import-web-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-01/evidence/adapter.py
355aa3615a2d37148f9d2d0a6ba9c4a01db1ebec5e3f3cbe26f43b72df96e454  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-01/evidence/input-environment_art_web_proof.cjs
664391daa74b457e9e499c0c6f6cb5293c95902b87ed0eb22a84d9b91829c870  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-01/evidence/job.json
285807edf5d917cdafe688ac87f620c98c0c45109bded7b38e469086b591705f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-01/evidence/launch-claim.json
632d16b5a0a5f013e0c53fc2c9b383709985f1d11803aa329712a9c83a77f3bb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-01/evidence/source_invariants.json
31e030ee741982eff538b44f432712bcd5c14181237b5ea5269f427f724a8cb4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-01/evidence/storage-manifest.json
d0bc83a5a2ae89a74712404601becf716d0c1ccfff2b9d220b174251c08708d7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-final-01/evidence/adapter.py
d859208819616a2953b6f754e12d6a75cd6f4694a4ae7808dee24de69f0a854a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-final-01/evidence/job.json
8eaa06c3248c7e9df188d91869dc6288663562f36935039522dc60863452c44c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-final-01/evidence/launch-claim.json
5ab3b373bbe85d1719ecc6880ab97dad1cf6e8960cd2db447ea6de1697c8f1aa  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-final-01/evidence/source_invariants.json
df92fd523c7e4006a5cc0bf5596b9bbb386f8704057dafd67e8a404f82b1109a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-final-01/evidence/storage-manifest.json
bb5626d757a427b0c594536e85b58990ba4c287ee5cfc4b2e5ba073d2fe3dd67  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-invariants-final-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-final-01/evidence/adapter.py
2f38fa0bd5f79ac2110bced1bce2bad32ba36ec06000938fa0b57118bf1f019c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-final-01/evidence/job.json
4b50af4341eb7448574dd56b9934d8cb78682a431282dcebee9ab14669d7c7b4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-final-01/evidence/launch-claim.json
2ea83cc9e6cb5cbb8c46493b421b2d27367dc622c458959220a2e9f3f301bae0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-final-01/evidence/storage-manifest.json
e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-final-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-packed-01/evidence/adapter.py
9540ece938b0740c96df09bd6622e1df6bcfca7f805e8b99da94d10c9447bc26  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-packed-01/evidence/job.json
b349eacc3034ee9bc604170e29bdde06eb328ac9b5236280167ad8cc4d1a6c34  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-packed-01/evidence/launch-claim.json
9ee3721e4c7ad7ae9416f10dd400e157047639e5216b522c4819b1f694697c72  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-packed-01/evidence/storage-manifest.json
833713da3f8f0992b6cf751a7b7bb4274e27611137a2e3fb7f067c114a8f470b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-liveness-packed-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/adapter.py
449b38efb2af87cedf33fd34ba37dea269db9dc73a2e3b7f5389c45b52756e41  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/input-environment_art_menu_contract.gd
8d8f1c3c7c1723d4500c5f254228cbbb7db51e13b48a7aab4701a7e6dd259cc8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/input-environment_art_phase_capture.gd
cfe4849f7e6fd74966c6b0090d00a576d4a8819a0337aa3e21f17dd879238158  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/input-foundation_main.gd
d9d8f4ac60caab822a4da2c248e81b21c409a9ad6dcbb7673f68c4545e67dab6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/input-main_menu_redesign_check.gd
9f7b635ea1f08f1a62f0206b9bf35af9d402610cbc0d17f9bdaa6b375aba2f91  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/job.json
e0adad075d3a84679e7a81b5c68009382ce84e617b282c32b276854a13b495e5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/launch-claim.json
9444866aefb8137fd29b2af2e1d527ce106419883f0fe2e0696230ea09b20fd7  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/menu.json
dcc8a4cd74220266d7114655fd115101a7f3db452547ef1e5117bbdec3e5000a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/menu_after.png
4d82e1878cfb337a57f24dcfe79299a32f586978a81d680060af231937c10158  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/menu_idle.png
2b70570683a49e532bbb383e9cd87eb6c9572dabb3e4cbdeee8dd7424dc7e258  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/storage-manifest.json
32b2a5a3682f7895746d626e94ad8d932ec8236cf2c5f1cf91ec23f2b9eacd3a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/adapter.py
3c05726fa35f7a01cbdb0454bac3afdfd31c158ffd5863fcb2272507a407731e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/input-environment_art_menu_contract.gd
067cf5f9673bd85705f4971e9c4db70aaafcfe1cec912b926ed9edc685fb5d8f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/input-environment_art_pack.gd
ef8ac19d9311a7e95a22885e660161e114b3631987c24b9405f7326c17a63839  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/input-foundation_main.gd
ee10c161cf390fb9a72b0b7b4b069b60b3e51e84108588098587816a8933eb37  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/job.json
275735b2c43cfc568372df43b70c7b2e9eeb1274c5a7dc8fdd328cc67c7a9f89  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/launch-claim.json
af57cf37d82a436fc79ec9dc1c121e775805a1875719965d6545de5cc9f26c95  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/menu.json
866e7bb824f2f900f8d64aa2d693d264cba55826af647bdd9300378b033e98bc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/menu_after.png
512f7363a77c23f4da94a4af3de24b6f166d637aad17e6fb7ff4b39e5158e611  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/menu_idle.png
bc80119874f8abdda04593f17a40720d083818b7f85a595bd3702c04a1a01df2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/storage-manifest.json
40cc95508076209037f4c3e5a229a3e867f73f185fc6b87c45343376e9604d3f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-after-01/evidence/adapter.py
c226705c818ff1fe177b027bf29698f87f0247a17d13208e0a537102bbc9aa0e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-after-01/evidence/job.json
e6d0d7bbb8ac35f84b14239cbb8972af104d0e58cdc03d229c9e4dfbc1a5b610  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-after-01/evidence/launch-claim.json
062e45d087d1784b8a1762aa506a3ca1f83d2359c38c278de95e1ec1fe37c485  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-after-01/evidence/storage-manifest.json
049657194fc014dea23639c0acf13ab37b47794ff63bb3aebb129a43834b9b2c  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-after-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-before-01/evidence/adapter.py
9420ca61a9aa20d14871f6ea221c268efd03afb77fbaad967187531c8cd4a5bc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-before-01/evidence/job.json
b6af66a973f3e2f7bb45ca56ad1c1bb7df19dfdf790c37fe6ff038ec5881c005  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-before-01/evidence/launch-claim.json
80d9e13aaa3f9c3086659258112a2bb369ba48c9592429fd9c5539607b56e55f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-before-01/evidence/storage-manifest.json
04a03a9b1613508253ef4fc0daea63b93aabc9e709969c2ff1c43915ca074204  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-menu-before-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-01/evidence/adapter.py
7e13e18df9626338a6c2523e537100d687d5b9769570ca9044f31ffb2061f527  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-01/evidence/job.json
d7d4644ffb7d3546edabd995420ab275547c3a17dc4febdc61a31d2ae1b980db  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-01/evidence/launch-claim.json
66f92bb486cb80c12397656cf9390cc761031c283c08cd73a4da7a6b1e305b11  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-01/evidence/metadata-adapter.py
055af059615823ce6ab9bc2d7cadf9cf5f6e326c4c73b77712397fa35a4e3456  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-01/evidence/observed-next-status.json
4de1798df053a3fb5cba4af837fb28019d350b05fe375bb855ca33fb4030cd18  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-01/evidence/phase9_metrics.json
a7b0dd569d076ccffd7ecb59375fd00222322f3030cced7fee30a7fe57ab07a6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-01/evidence/storage-manifest.json
25710a3f2fdec31af80a96c8f90f749918b3dee22bacc610e6b777aa648325a5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-02/evidence/adapter.py
225657773f05bb70f5e1e6cdde44aa5a196ddf3cefa61645a9cfd53cefb6afa2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-02/evidence/job.json
f7da3e878ca85f86c429c345865c49b579cd2d76c8872650d9d583374bdf9c9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-02/evidence/launch-claim.json
7779a827ce18949b3eeba2166cb6d874f60253a7f3bae470a7c5ea90f677fe75  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-02/evidence/metadata-adapter.py
3e6604251ffff67864c3fced4d7e9079797ac6e6e100a4c71642738365de5740  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-02/evidence/observed-next-status.json
263e9de3cecdbf904a40901bfef33ff6f94ae058056dcbb71af30e0bffe88565  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-02/evidence/phase9_metrics.json
aa645898089bfde7d56288788bd862bb269979c30be155867950362a1639d340  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-02/evidence/storage-manifest.json
e0658a7b7fe4771f575a3653fc9410d42c0ea6fbe93ce6174d18704c26ab53c2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-meta-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-python-01/evidence/adapter.py
8da5b9667c7edf83ee25777eb0b609cd4f51c6701368e930f406d3016aca49a2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-python-01/evidence/job.json
895b95d236818c7f80a4092012f384c9ab3b4808c8d0915f9edb2a8ae0153b73  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-python-01/evidence/launch-claim.json
d9da394364483039d5157b90540288a38621863f74b1117585435eb6f0717400  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-python-01/evidence/storage-manifest.json
e31fd9f0a8091bcceff7adc4719d7d4de8868d158eb4284bcefdac6a7148ddbc  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-python-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-01/evidence/adapter.py
6fae0887791f7902f019b8fbc1f15a2ddd7d138bcf1c20057940a4fb97a9c146  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-01/evidence/job.json
20a5438b629dc2438119667932d466ae45fd27e6c1d853fe8074de62363db17e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-01/evidence/launch-claim.json
54c9369ba383a7d3135c40e3cd6e6632f211a691475373079a260097f1c9f62f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-01/evidence/runtime.json
86a0d29327c8dfbf0d812818aa57d801e1a7c08a5b09b5c4572d4510da8e042b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-01/evidence/storage-manifest.json
27af5881473e9fe2f1a9ef3a9a502a62e71ef92a1f127fa0db13725982a34fed  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-final-01/evidence/adapter.py
59b9fbce3d392012af6d51a81142a9a634095ef1925938e651db998bc1cdbede  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-final-01/evidence/job.json
cafc62645fcae61b940ff1d662749f3aa838b5bd58eff1e53b625dece4951527  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-final-01/evidence/launch-claim.json
fc4124967303f8922ef5cc29cd013ca39a7e64e9336d8ead5263df2d8e33951a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-final-01/evidence/runtime.json
2fd355c0794f69610f3ea2468c4ec56f8730313a4bbd1394ba81894f639e615d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-final-01/evidence/storage-manifest.json
04aedd25f9b896edbe43523bd4f1c5ae41c6470184980376c9ba679732656b62  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-final-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-verbose-01/evidence/adapter.py
514b9adfce864232c219072bba844beee0b780cd6b5d0541fd396f9a4f743684  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-verbose-01/evidence/job.json
eedc7c0255e405b09613f7381aa7c735e5bcbde6d5063ae16c174a4b4fe77332  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-verbose-01/evidence/launch-claim.json
c23469fc6b75350a96557f0184214e0c595ee29fd30511282657067a237fe7ae  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-verbose-01/evidence/runtime.json
276e0dd83a77a7be0109cdaeed40882f94333ecc651a6759df092a0933bdc15a  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-verbose-01/evidence/storage-manifest.json
37e48ca55be6886cfa7cff9fa3d003e2338a47052f2858a32a59e25c74df2a6e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-runtime-verbose-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-01/evidence/adapter.py
6b1a37bae59dcbdc92fd965a7f09445abf1fb47d58a870c2922c7c5e2602ac8e  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-01/evidence/job.json
f49fe701afacdb8cb0943e28540fe35e405b3e5733d6bcbcde54039746678000  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-01/evidence/launch-claim.json
36e30ca5f8bf055dabc3dfe2580cbee64ba1d804416768215096192770e777a6  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-01/evidence/phase.json
30be04eb3ad033a13ca4d3786ded4b633c09555b33258021317327f1dcf261c9  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-01/evidence/SHA256SUMS.txt
1cf4ec56dcac983aeae7231ea645c505bb7c670cdbb93aa676eb4c7abe10f116  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-01/evidence/storage-manifest.json
5e6c8d062f37dfbdd6204771967dc056291462c76dbd787feb4e72220604de30  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-01/evidence/adapter.py
235d73657d11b1249a143af26c1d47f686a3723d30c1f5420f21023de6bf4fe5  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-01/evidence/job.json
2b36c7c3c81b27aa36ab6e77d7bd332f50da71dced716647b5eb29f33db2a307  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-01/evidence/launch-claim.json
57dc30eea0b9129db4b1e407176e16762daa9594cbbe8e3c96c8f14c784f4773  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-01/evidence/storage-manifest.json
36d070fdb9c84ba109771c359f2fbe6ac4e0fafcbe049eb0d86e2f73bd38d143  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-02/evidence/adapter.py
ffe1732be6e43e9b67f4d9b6c2b093883005c6d7b475cb52c5dc09f981580689  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-02/evidence/job.json
b852bbbb8b456f262ff77a75fe5970aae45646d5544fe6552a9234606d962e3f  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-02/evidence/launch-claim.json
fbde8c60aaf7d0adbc00bb90fd05f6cbb3197eb601a86f8bf4e3cae67e9a41a4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-02/evidence/storage-manifest.json
d6f191190c7c23f74d62eebe19fbd935035f5a0f74d4b86485fe9313b1a5e2c0  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-server-02/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/adapter.py
36d9fe7ea7b5b11a8eaec0952a3eba9ced26cf64c3e73a5a1e0202e6aa3a6900  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/base-selection.png
f5135d136ec77a9bd908d07bc415e3b7702a7c06c5c73c903d08f0779fad35a2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/gas-after-idle.png
925fc5179cacb76561f9d78272546fc99e38c56e2801d638d575952e1b0a57f8  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/gas-before-idle.png
91991c1230f3023a2562581bda3e1aa00938c3ad2de313e8a8afc0bedda55d32  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/gas-web-idle.json
d43180e5acec072745d39299395045a1e1babdf79e8832ee27cad678f9c791f4  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/input-environment_art_web_proof.cjs
1dd89d97d098b8a6674c599997433ff0bb9d5b0518bcfa164b3f9a6177a7b435  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/job.json
5ca48d705a6c0d76cbf8bf4696ff509c7d1749734312bbc76b45e29ea38eee55  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/launch-claim.json
7648166add0cd8dab3c7c5ec17985952aeb7bfcae0652cddf34b5e94d914fd39  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/menu-after.png
ed87cebb546389e650beeec6833b4d9d6f5fc6abeab3deb2894bc1bfcd281735  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/menu-idle.png
54fdd50aea9c46bad216fea8c7afe2549104d3614037c99f17ba8b2f2e235aeb  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/menu-web-idle.json
60c6ad781d6fbee16f3d3b9372aeee32e52875a4f8025b3d65efc781d1b322ed  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/storage-manifest.json
6b3d89450a9a5486772af9175e6affec3d44918cd8ef5fa6c5525331a0ba5a7b  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/web-observation.json
bfa348ff453bb2561201b86ca55d968cf37f0d143a43e112f0d49a36d25f9afd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/web.png
e5cbeb849c46360ae502f34608ae6f169364d8c207f6483551cd9718a6547e48  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-01/evidence/worker.log
4e3f8919ed22b8c849777cff46eb90c6975a0a1e31584c2113916821a47b6b9d  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/adapter.py
995cf834f2a8ab2c94b565dae9753ec6cc5a7137d21f0039f6520745fa2d8846  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/base-selection.png
9f751c15ae96e6fffb6655a292e93fd1b771cf462e4f31b5954c887bccc27493  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/gas-after-idle.png
9b67c7dc27a841744ef55fb09eedfac2f9bd028cbe0a6b4463b3130b8bb50aaa  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/gas-before-idle.png
9113b821b5f1291c833af216f93a5f8170876bf493a9d5053b3f96bad9026a34  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/gas-web-idle.json
ff62e5ebe901fa056f927c39bfb8e7ad37cf8231eeb349f75817831d41adcec1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/job.json
16d74cf8745b2e4887e2ee622ab408e2a74325e865112e3dc26654821a265067  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/launch-claim.json
22b166f225e498e8b69f0b94a3790505ed74f61f325605c096bde5687a9415ee  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/menu-after.png
8e14609d40190477e113566c232e348c50fbea29daa45dd2afffb0e7dda2e3d1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/menu-idle.png
5f8c7e4114e84945fe452281c9aa765d8dbc2294704412078676c5eb081ed104  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/menu-web-idle.json
5c0a6b4f0a7b67247183b9edf3fbf901e58fcacc97166ebc85b0af45933a61c1  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/storage-manifest.json
0cc02f2a2496d45e319c2e178a29c214dd8ad933d82d279ac3e6613cc178a0dd  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/web-observation.json
db29db660615e3af2988e8bacc788475d9b451fb9853b3fdc877bf270a16ebef  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/web.png
020b9b5a30b92ee0476ab934348a6e1a2c2c6516b5a65e0834b85da53ea0cd47  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-web-02/evidence/worker.log
79ad4f6e08377cf2e2771db34f30bd781560819a9525b3cc7ec4ed4059caadd2  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-02/evidence/phase.json
b8201d0e4da352f1ecca1b836199ed84133308aa1c9179e255bb32aab8e56a97  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-02/evidence/job.json
b739f474a03dcedd10ccaa00b38aec613f0f7039ee6db543855fc2c2d8d07000  E:/CodexQA/BTH/runs/BTH-ENVART-001-r2-p9-seal-02/evidence/storage-manifest.json
```
