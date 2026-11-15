# Live AUTO, Slot exit and interrupted ordinary travel

Source 724ef2fe, runtime unchanged from delivered 8bfa0b8f. Normal generated seed NEXT-ORDINARY-20261115-J, no forced money, outcomes or availability. Native Host callbacks only; fresh Main in the same process, not Web or separate-process cold testing.

- Enabled AUTO Save/Continue: 21/21 including arrival checks. Natural Pawn Buffalo cabinet manual spin 1 costs 2 (97 to95). AUTO enabled before Save remains enabled on Continue; after 1980 ms the next spin settles once (count 2, cash 93, net -2). Normal AUTO toggle stops further spins during the 3-second observation.
- Exit during Slot result: 19/19 including shared arrival. Normal floor return preserves sealed authority and nonempty room controls. Save/Continue and reentry preserve wallet/RNG and exactly one spin settlement.
- Interrupted ordinary Back Alley-to-Bar bus trip: 9/9 after saving 3 seconds into the still-active cinematic. Destination already committed: bar_002, cash 97, one travel, 24 minutes. Continue preserves destination, fare and RNG. Recovery uses an intentionally static receipt, not a replayed animation: it remains at phase receipt after 5 seconds and normal acknowledge reveals the valid room with controls, clearing receipt_pending without charging again. This is not a frozen live cinematic. Source load_foundation_run calls _begin_travel_presentation(receipt,true); travel_cinematic_overlay explicitly excludes receipt_only from auto completion. It differs from fresh trips that automatically arrive.

## Exploratory failure classification
The first 0.2-second save attempt occurred before destination publication verification. The existing guard reported Room check pending; existing save retained. There was no prior valid save in that new QA profile. The diagnostic incorrectly assumed Continue succeeded, dereferenced nil and timed out; this was a helper error, not evidence of a game freeze. The second staged probe retains that failed assumption in raw evidence. The third helper checks load success and used 3 seconds, when the normal preparation completed; it passed. No production guard was weakened and no live save was edited. The early-publication case does not establish lost prior-save data or a product defect.

Broad acceptance remains open. No runtime changes. Raw evidence hashes follow.
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-resumeauto-20261115-01\evidence\worker.log` SHA256 `f7e52c2187695a5da5db2fc9e4937f8aed95ae59e7a19f8edd3ac573ba0effc0`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-resumeauto-20261115-01\evidence\job.json` SHA256 `ca26ba2cd8f749ff2b791b573eb7487ed503c0f06e0fcaf038ace0dd7f62f1c3`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-resumeauto-20261115-01\evidence\storage-manifest.json` SHA256 `7ab904580166526b79e2eeb48ca41835805404d28ebfa09e9e8c326ea1f2c27a`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-leave-20261115-01\evidence\worker.log` SHA256 `3d2ee84ce0098a11d78287b64c584a4f0440006ccf9e7961e789195f32c60cdf`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-leave-20261115-01\evidence\job.json` SHA256 `38e598a705e9ec8b8cebc1c7f69049244597bf7b28bdfeff72ce357892f975fa`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-leave-20261115-01\evidence\storage-manifest.json` SHA256 `c150fb02168b0a82dd19c21f06939cfe87ac4184bf9da8fe25568a744809dffe`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarytravel-interrupted-20261115-01\evidence\worker.log` SHA256 `1430149c1c617e5e80d35e6a1eae772dbc715f04ef3b419dd816c2c0ea63a4a1`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarytravel-interrupted-20261115-01\evidence\job.json` SHA256 `9f7c09bcb99ae3f33f3a2101f0c40072db8f21eb946073cd99d3d20dd803e57b`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarytravel-interrupted-20261115-01\evidence\storage-manifest.json` SHA256 `dcf966b9e9e8d90a72736818757a9c7c704a51d649158660875539b55b73ffd4`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarytravel-interrupted-20261115-03\evidence\worker.log` SHA256 `42a05035b95d9112fc22bd76b0a46cf26bf4eb34cb6e9997f761ee27c3b66812`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarytravel-interrupted-20261115-03\evidence\job.json` SHA256 `84629e99a682346dbd97e7c47c5eb78814ec37f34148c19553ace1e91e1d3076`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarytravel-interrupted-20261115-03\evidence\storage-manifest.json` SHA256 `c578851e179ab39f2d98cdf9e8c4a298f5bd18c941dcb1b722745501d8032fcc`

- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarytravel-interrupted-20261115-02\evidence\worker.log` SHA256 `c3af26e36451d2d7c16611dee9e0d076a5b63c6e0341b26481f2c98c2e2a2f2d`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarytravel-interrupted-20261115-02\evidence\job.json` SHA256 `28383c7a33709bc136791ffe83ea62cd69bb4444a22dc81d2beddba685f05e1f`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarytravel-interrupted-20261115-02\evidence\storage-manifest.json` SHA256 `6727858f568d27b320f32d243ea4d4463bb1629b9f6974864f823bb2dda02fa2`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-20261115-01\evidence\ordinary_slot_resume_auto.gd` SHA256 `886b0b2803807e79cba69caade5f9c6c671e27745416c2412c2b75cd70177792`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-20261115-01\evidence\ordinary_slot_leave.gd` SHA256 `eca61a949f9e1656f6df98c4574fd85846dba7e7f0d561897b607657fdcac472`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-20261115-01\evidence\ordinary_interrupted_travel.gd` SHA256 `8a441dc482bca642ec42bcba135e35cd9b53da9e8b22c4401d98bfdca038a689`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-20261115-01\evidence\ordinary_interrupted_travel_probe.gd` SHA256 `427826c9423d48961e61dbc75bab1482d67e962d35c9aadcd50c23f3b635c7a9`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-20261115-01\evidence\ordinary_interrupted_travel_ready.gd` SHA256 `7be1171af13e84b79f20ad286eed222716de7b985edfbfa147e2f62e2d396780`

All five native jobs released with zero owned processes. The two erroneous early-save helpers timed out; three final scoped tests exited zero. Reconciliation run27 retains109 pre-existing global findings, including the historical BTH061-006 owner absent from the supplied snapshot. No reassignment or closure is implied.

## Early-save preservation follow-through
A fresh normal campaign was allowed to publish and save its starting room before taking the bus. Save at 0.2 seconds into travel was refused while publication was pending. The prior Back Alley save remained loadable with exact room identity, wallet100 and RNG. The uninterrupted trip then automatically finished and a normal Save stored Bar with cash97 and one fare. Final7/7; no product defect found. First preservation helper passed6/6 but checked the internal support wording rather than the player-facing wording, so its conditional exact-state assertion did not run. The final helper recognizes the actual user-facing message and executes that seventh assertion. Both raw runs are retained.
- `E:\CodexQA\BTH\runs\next-bugfinder-earlytravel-preservation-20261115-01\evidence\worker.log` SHA256 `80021b8ced04150b34572722e70044c2b5af13d07edfec0b86f3e3e5f8433f42`
- `E:\CodexQA\BTH\runs\next-bugfinder-earlytravel-preservation-20261115-01\evidence\job.json` SHA256 `7acbd04f1e177528cb0c31c364ce99ea12fa8a16e61a60f137fcb1060f7c7dc5`
- `E:\CodexQA\BTH\runs\next-bugfinder-earlytravel-preservation-20261115-01\evidence\storage-manifest.json` SHA256 `d6e5c1215063884a7d44db48a59196cd7cb8ace2bf76c4ccea1d02986318e831`
- `E:\CodexQA\BTH\runs\next-bugfinder-earlytravel-preservation-20261115-02\evidence\worker.log` SHA256 `8acabd0e6537593aaa4cc4043cbdef79bfe60c434f2e998fa5a104d918876838`
- `E:\CodexQA\BTH\runs\next-bugfinder-earlytravel-preservation-20261115-02\evidence\job.json` SHA256 `1b888d7a438c554dd15cc8eea3781b44d05ce68c67852604e5fe6ad0b953be84`
- `E:\CodexQA\BTH\runs\next-bugfinder-earlytravel-preservation-20261115-02\evidence\storage-manifest.json` SHA256 `033ff2e20684b49fa838a9c250d316d537aa142e2588004305616896bcc60eaa`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-20261115-01\evidence\ordinary_early_travel_preservation.gd` SHA256 `278400fedf51a0f8f3e2a0ea1566fc190ceef97358028b718afacc60d353a918`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryslot-20261115-01\evidence\ordinary_early_travel_preservation_wording.gd` SHA256 `a3f993afd90e57f5cb603622ecfd705bb70fc8ea78dbcd0cf94764dfd535e59d`

Reconciliation run 28: 109 pre-existing errors remain, same historical owner snapshot gap. Both preservation jobs exited zero with no owned processes left.
