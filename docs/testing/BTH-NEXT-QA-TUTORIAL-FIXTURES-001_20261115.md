# Tutorial native fixture classification

Source main df1a8bed, 2026-11-15. Isolated guarded native QA, not Web playtesting. No user saves touched.

- Fresh tutorial Save/Main Menu/new Host Continue:17/17. Deliberate failed-writer branch preserves run. Fixture then invokes Skip while failed-save exclusive confirmation remains open, producing an engine popup error; this is not yet a player-reachable defect.
- Corner Store authored lesson ordering: PASS, synthetic completed earlier lessons.
- Target nonoverlap: Pull Tabs purchase/collect and Blackjack anchor reach their assertions. Later Heat intervention fails because fixture writes global suspicion.level=98 while local authoritative Heat remains0; add8 produces8. Public add_suspicion setup reaches expected intervention. Subsequent chip assertion still fails, even with current blackjack_chip action; investigating staged hand state.
- Cadence: fails before isolated Peek because historical fixture fingerprint ade054601e003faaedf3e6a304c60da04d724cb11f61eed2a59bca0a9eb0854b does not match preserved original pin fbf5f57b1111a90bb650c5d8668eda8c90404b596c5ecbf91ca8a015acf44700. All exact extension guards pass. Current/restored fingerprints match; round_trip_diff empty. Standalone hostile probe cannot run its73 cases until baseline is valid. No fingerprint was repinned.

## Raw evidence hashes
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-resume-20261115-01\evidence\worker.log SHA256 ea5a36f17d3bace2bc47c3903a7dc4ac0ad596504c1ad103a17c7bcc1b6cbd5d
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-resume-20261115-01\evidence\job.json SHA256 2e73b58ca17ad7487f1a102ee10d4a7b48ca78b558d8e81c2b094b067dcb0f1b
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-resume-20261115-01\evidence\storage-manifest.json SHA256 6423b21d4936e4d786123f7f2fee287f1c563299c4e481a00e3aa0132e87c82e
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-corner-20261115-01\evidence\worker.log SHA256 0c40b6192c78e6361de673bd2e5b5a7dbac068676e1f6c12464c13780f704a62
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-corner-20261115-01\evidence\job.json SHA256 2c5d55fb50412116431cbaf9ea99e5a170e25e47ccbf84a31527c325182eba00
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-corner-20261115-01\evidence\storage-manifest.json SHA256 6989a915e92535001cb99f68f01f758064cfee1f2341896db63eb711f20b2ffc
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-cadence-20261115-01\evidence\worker.log SHA256 cd9703cb19740dec4932725edeca40e4a852f861be6828580d8f012effa265c1
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-cadence-20261115-01\evidence\job.json SHA256 0aa7720ab3ddab9185b7038250c07168e6b6ee143c2bf8c9efd37973264ae4fd
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-cadence-20261115-01\evidence\storage-manifest.json SHA256 10147e1eec69f6a1a3bc980edf8772ed36d083370146a3909efbb0d3dfb0eb8c
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-01\evidence\worker.log SHA256 3c7e22f6a38a2d28dfe7d5857ce5d9b92488fe80a3be1b7e8a18cf99becf59a2
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-01\evidence\job.json SHA256 03590434eafda794469036dc79692ae669ce50270788a0724ebb0725b4fabc78
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-01\evidence\storage-manifest.json SHA256 f11b8fb4cd5f9577d3c9b3710efe22f8fc4d0ea18572b3256760f741bb6ba4bf
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-pin-20261115-01\evidence\worker.log SHA256 e0b5b9c695b4bb5e86aa23764db22b2b4a2d1f9974034dfe3f7362a128fa4a64
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-pin-20261115-01\evidence\job.json SHA256 4aba696bd447623b09fd0a7eedaf45e7f28780ee6caae19940f0f845e5f88518
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-pin-20261115-01\evidence\storage-manifest.json SHA256 0b0e8b8b87802982469348355eabb58b5df47cffbb5954fd54a84c5d7ac58c60

## Confirmed classification and candidate repair

All three are test discrepancies, not demonstrated player defects. Production code unchanged.

1. Travel integration commit f35ba137 added an empty travel_journey_receipt to the non-travel fixture. Requiring exactly that empty dictionary before detached historical projection recovers the ORIGINAL pinned hash byte-for-byte. Missing, nonempty and wrong-type receipts now have three additional hostile cases:76/76 PASS. Full cadence PASS. Current full-state and restored fingerprint checks remain unchanged.
2. Heat setup must use add_suspicion for location authority. Clearing UI state does not settle a sealed Blackjack hand: real chip placement correctly restored the locked hand. Public Stand and normal presentation time settle it; explicit empty-hand assertion precedes next wager. Current blackjack_chip action then raises it. Full target test PASS. This remains synthetic staged tutorial coverage.
3. Resume fixture now closes its deliberately triggered failed-save confirmation before Skip.17/17 PASS, no exclusive-popup error; pre-existing size-anchor warnings remain.

All four final Jobs exit0 with active_at_release0. No browser acceptance or complete First Night progression is claimed.
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-02\evidence\worker.log SHA256 64f0b1c79e142ee47d4111151255fba087829ed56f9e67e4fcc07fd625f5b08d
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-02\evidence\job.json SHA256 a5dcbf252514906545dac4228ba16d39e132dc63e708269646a1516e9d79262c
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-03\evidence\worker.log SHA256 21c47b5a6bf0ddd1e204a6d33353e56ba4a9c51ee6853cf17493bda395421cda
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-03\evidence\job.json SHA256 d268d606cde7b052156bc5b43788b68b3dbf9e038302e59efd17a8dae17c8a3e
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-04\evidence\worker.log SHA256 3611f39c9dc7d1513e82bf17406576a85e2b9fa9b1b78bd65fc259880d35f240
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-04\evidence\job.json SHA256 65aa11462f4852a77808a59c5a572bce42b581c5f365fec4dbcd9e9f60d44ede
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-05\evidence\worker.log SHA256 98d8ea83a64fea14ab99c1d9e0c915f4716f38849dd87068d2c8c96a036389b5
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-05\evidence\job.json SHA256 bfb0018e47addce58ce7db0fe0d475fb62964bf37f19afe097b811661e8cd936
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-06\evidence\worker.log SHA256 d8b22f920e9d83b9f068274cd52b93436b2a676d9ccd272b3ee2d4ab7fc37377
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-06\evidence\job.json SHA256 48577afdabb36e77eba4873b5c80683af20eb7244ec733593ddf2873b1371033
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-pin-20261115-02\evidence\worker.log SHA256 67edfc84a28ea62d76fb3adac9d2eed5c10137cc493ef5b8c8795eeff5f87b7d
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-pin-20261115-02\evidence\job.json SHA256 981bf89bc056e166f1baaab62fffa8117f0392d8562f7494e283e71737db232c
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-pin-20261115-03\evidence\worker.log SHA256 d9d155c7f8f0705889fa1f77d292e6ed309c04aca324091a4431b322eecc5e27
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-pin-20261115-03\evidence\job.json SHA256 a0b00f900375d2d97e3ac9e58b37a69bfea67fe82bdf5b829e90b29f420f5c21
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-resume-20261115-02\evidence\worker.log SHA256 fc586f1d276f0f38a8529001956f0be3169933e61d9f094dcee548043a0bd6a8
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-resume-20261115-02\evidence\job.json SHA256 0cb28f93d28aa8859c0eaaa885a9443bb084b2859ffc61b30abfca84069b8e5e
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-cadence-20261115-02\evidence\worker.log SHA256 e0b7739f8cbae68d62e2e6eddfbd69e4f8c9bb113790ae49b49b96ebba84bac9
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-cadence-20261115-02\evidence\job.json SHA256 c2fa84e502879a670a1d50b5e2468011a3576a112beb75d8515dcacb36bdcf2d

## Final reviewed boundary checks

The target test now waits up to10 seconds for rendered can_stand plus no finite animation, invokes Stand, then waits for can_deal, an empty live hand and no finite animation. Final targets09 PASS. Candidate07 had a test-only Variant type inference parse error; candidate08 read a diagnostic wrapper rather than the rendered state and timed out its readiness assertion. Both are retained; final helper uses realtime_surface_state and explicit bool. Resume03 now asserts failed-save confirmation visible, invokes the actual Cancel handler, and asserts hidden dialog plus unchanged live facts:19/19. Historical pin03 remains76/76; cadence02 PASS.

Reconciliation34:109 pre-existing global findings, zero scoped tutorial findings. Earlier ledger attempts31/32 failed schema validation and33 exposed misplaced readable row; corrected before commit.
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-07\evidence\worker.log SHA256 fdb3f9dd142ee2f1fe6313b8725e7299fa6bed608bc3b10119d109d50bee900b
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-07\evidence\job.json SHA256 869481dd7b91a76f20c2f459aba074f584fb454de57a73bb661d15f4e392750e
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-08\evidence\worker.log SHA256 5ba3943e728703b30287e4576ed59fcd69eda35607a0586d8805228de9f838eb
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-08\evidence\job.json SHA256 9a8225902c6acd058a48d6a0d8e8c05b49b8fc47fcc93f920cf9bc5c95b9ac02
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-09\evidence\worker.log SHA256 d8b22f920e9d83b9f068274cd52b93436b2a676d9ccd272b3ee2d4ab7fc37377
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-targets-20261115-09\evidence\job.json SHA256 94dc9f84017924539e544a2f12f7ff331dd151d973d17347a68ac4732f6499ec
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-resume-20261115-03\evidence\worker.log SHA256 6d8868c1569494a98f9ab6a88ecb7fe996b5177c3d14914601e7d95e78a313d9
- E:\CodexQA\BTH\runs\next-bugfinder-tutorial-resume-20261115-03\evidence\job.json SHA256 24d5dd5ce2d9346f58fac563e977f6cd692b20b1aded8bfdc287a3846fcb207d

Independent review approved final state-based waits, real Cancel and exact additive-field projection. Repair commit 0111a7f770b0d980280c88c7be740839408d7871 pushed to main. Broader general gameplay and browser acceptance remain open.
