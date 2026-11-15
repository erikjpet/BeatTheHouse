# Crew reward round-trip fixture repair

Classification: test discrepancy, not a demonstrated gameplay defect. Source e1df844d. Only scripts/tests/crew_delivery_reward_check.gd changes; no reward rules, game state production code, geometry validator or renderer changed.

## Reproduction and cause
The existing curve fixture settles four deliveries and checks reputation 0/25/50/75/100, cash 22 per handoff, remaining duties and no repeated reward after SaveService reload. Its unmodified curve failed after delivery 2 with 39 checks and cascading failures.

1. Raw SaveService deliberately removes derived scenario layout audit/render snapshot/projection. The fixture then advances the clock without the Host Continue rebuild. At the second restored Bar, authority validation fails and the midnight-crossing clock advance rolls back to 1380 instead of 1740. The next offer is correctly unavailable before its cooldown. Stage probes showed valid authority before Save and absent derived proofs immediately after reload, with unchanged sealed authority digest and trusted-rebuild marker.
2. Matching the Host rebuild exposes another omitted fixture step: materializing a closed handoff leaves its outcome cleanup_pending. The normal Host then consumes, acknowledges and cleans that outcome. The test did not; a third delivery revisiting the first room collides with the old pending owner. Completing the existing consume operation removes that false collision. No lifecycle dictionaries, outcome tokens or receipts are fabricated.

Relevant production paths: Main room-catalog restore around12810; Main _consume_world_sequence_outcomes around17261; RunState world_sequence_consume_delivery_outcome around3498; RunState SCENARIO_DERIVED_NONCAUSAL_ENVIRONMENT_FIELDS and save restoration. The runtime intentionally preserves guards against invalid rooms, duplicate rewards and unfinished owners.

## Repair and evidence
- Restore override uses official superclass SaveService round-trip, rebuilds only when a scenario has scenario_restore_pending_trusted_rebuild, asserts valid authority and unchanged cash/chips/RNG/reputation/duties.
- Each materialized handoff must have exactly one real pending receipt; normal consumption must succeed and leave no pending receipt. All previous reward and retry assertions remain.
- Clock advance success is now asserted instead of ignored.
- Curve requires an explicit absolute output path with an existing admitted directory, and safely handles FileAccess.open failure. The first exploratory invocation omitted that path; its generated diagnostic authority file was moved out of the isolated E checkout into its own private QA run. It was never committed or transmitted. No C files or user saves were touched.
- External faithful-loop prototype 61/61; final repository curve 69/69, expected four-step reputation curve, zero remaining duties.
- Missing-output negative exits 64 before fixture work, as expected.
- Adjacent obligations 92/92; package-window cases pass duplicate sources, Save/Continue, walking route, early/opening/midnight/close/skip, once-only failure/reward, legacy, cooldown and showdown. Reward-model 259/259 and adjacent reputation 17/17 passed before patch; final reruns recorded below.

This remains synthetic native coverage with fixture funding/presence/appointment timing. It does not claim browser control, ordinary unscripted campaign coverage or completion of BTH061-006. Raw failed probes preserved: runs01-04 expose original failure;05 has only restored proof repair and exposes missing cleanup;06 is an external helper indentation parse error before execution;07 is full faithful prototype;08 is final on-source green.

## Evidence hashes
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-obligations-20261115-01\evidence\worker.log` SHA256 `dcf2061d1c94ac23818b049242997abd3800d4f2943a17e084bd5bef73dc0a1d`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-obligations-20261115-01\evidence\job.json` SHA256 `d9774be95b8ba2662dc156edb742d43ec6b85b0b0dae24261298322a76d5bd7c`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-obligations-20261115-01\evidence\storage-manifest.json` SHA256 `1fa8da45ea58c5751065af86c1ed9c0ff2095cd2248a4bbadbd9e9f757964f96`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-windows-20261115-01\evidence\worker.log` SHA256 `a6b90f3a97965d387e4fcdd47577c5459124e5e8f5cdf07e083b5c3b81d67970`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-windows-20261115-01\evidence\job.json` SHA256 `92a59ac0b9272140a8bc3934339ddc8ad81572b645fa3224c90aa51180be83a0`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-windows-20261115-01\evidence\storage-manifest.json` SHA256 `7dfe3f37694a522e8c5d0e5b991cbaa90bc733a1b214b1442d0dd20f0e46805c`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-01\evidence\worker.log` SHA256 `dd21cbf25f059212096298f6b47c64eb1914460c190dd4c669e8631a9ff925bf`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-01\evidence\job.json` SHA256 `9eec429dc1cad1d58c76fb5667937e9b284f48bcefe2526c5b99e33e1e1d697c`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-01\evidence\storage-manifest.json` SHA256 `76bcefe7017356bd1959f0a22b0ab4e30f52089ea680b12aaeea644d2b86bef3`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-02\evidence\worker.log` SHA256 `9b0102071f73e2fb5786277a34900319486508bddc38fb203f4e7a5d636da0ae`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-02\evidence\job.json` SHA256 `82a7ddef3720ee88d99873d7e46ba1ceea72ee3db741dda01e79d8eafad823e4`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-02\evidence\storage-manifest.json` SHA256 `27d57e310bba45cb899ba9951493dd63fa31ef472272e469a09ea81084394598`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-03\evidence\worker.log` SHA256 `db180cde79f27d07376f7ce5e620de8419fca6503c2f208a1bd1899bd20896cc`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-03\evidence\job.json` SHA256 `f98c918f049ef63aa737e0520592664184013fafb153fafcf14fd82013320185`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-03\evidence\storage-manifest.json` SHA256 `298d68cd5944132c245992d472c63239691dc7c3c2fefd896713ab911f0ee368`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-04\evidence\worker.log` SHA256 `b033e647cc43114710e8b0cf32c515224c277f4cb43ab126ee05c4c9d320ea48`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-04\evidence\job.json` SHA256 `b376469497855c51c2c1d97e9db8498c108202bef0cf15ef467653b8d4b4996d`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-04\evidence\storage-manifest.json` SHA256 `86560357bbd8e3509a3d58257ad891d18400fa44cee90bb305893decef3870b5`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-05\evidence\worker.log` SHA256 `eb18193f59aa9189841385e98a1d342e48411658e561ff727af7e0aa31f76a1c`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-05\evidence\job.json` SHA256 `f1b7bb8c4a30177cbe011b24213eac23237e02169bedfc63c1b53541963b51d6`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-05\evidence\storage-manifest.json` SHA256 `5d668c275ccaef9df461fc30999bb030910461184b3ddb46a690d10937d67ce7`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-06\evidence\worker.log` SHA256 `b4aa3ef04847186f2a66ab80f78935203589b2341a6548b078a6d485496fde5b`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-06\evidence\job.json` SHA256 `c21ed3d12168daa53f4776f2ea6a1015881f18a940ed3b3a844a6ef3e4bb56b8`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-06\evidence\storage-manifest.json` SHA256 `cb86bc7cfad93a7a0b8b24b35a2e86a034efe88a88ea7d0c0a0e1d79bdc2e3a2`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-07\evidence\worker.log` SHA256 `deb246cf39be17a1897c116ccf7c01b28ada9c69f04acba3a9a45a260f34d973`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-07\evidence\job.json` SHA256 `77593fd868af9d0fc30d1ebd55b8b74b15ce266248da703c27634f95fa860bbb`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-07\evidence\storage-manifest.json` SHA256 `8d0e09b7cb403a82fcedfd2bbd3baf5c4e8ed927ae2e26fdd6c5d8026763a92f`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-08\evidence\worker.log` SHA256 `12d83b853bcd5fa630362b0f4a0811f0bbc01682c208077947c8af890ccf6c5b`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-08\evidence\job.json` SHA256 `3e342b8b7603b110f3550598ed0c45e797ed7daee13a3bd3544f96852985c20c`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-08\evidence\storage-manifest.json` SHA256 `a9d2c4e396e73fed2cdfbec2738ae8df9698c2ce49b0952a6d11476277eaaa62`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-nooutput-20261115-01\evidence\worker.log` SHA256 `a12c595bf1d5b9097f61be59e543949f3750209ee4f311243289ee9802ae5274`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-nooutput-20261115-01\evidence\job.json` SHA256 `63a67bf1e465cfba620793b70ccc2a5facf2d731c85b99395c0f7c91d5b8fa01`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-nooutput-20261115-01\evidence\storage-manifest.json` SHA256 `45f20fb1a8c4b81e8d6b8ebe8b97d198f993b59d66a8ec49fca044a10461116c`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-model-20261115-01\evidence\worker.log` SHA256 `690b200fd0ac14f15c2623a0807a44db019383583ca24920ee53075091311a6b`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-model-20261115-01\evidence\job.json` SHA256 `da6063734a6513b8840bdde1b49f783bc40f8a911c0f8fc4308cec5875d16eb6`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-model-20261115-01\evidence\storage-manifest.json` SHA256 `0a1da47852cf9e13673c860381b30eecedc8f3cc70e5f76b674c1377096bbee1`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-adjacent-20261115-01\evidence\worker.log` SHA256 `1890487bc2e7f017b9d33c4f3cf430e1618af19a183dae40b24461b7c151a32a`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-adjacent-20261115-01\evidence\job.json` SHA256 `a285d4eb167e63046147a57a10397d7026b68aa153fe13c0de5394a436aab3fa`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-adjacent-20261115-01\evidence\storage-manifest.json` SHA256 `bca09e8f22139c1bb9fccc3ebb798c47c6f883fbd0baebc7da4530ea4074b7a9`

## Final matrix
Final on-source curve 69/69 (run09), model 259/259 (model03), adjacent 17/17 (adjacent02). The initial new restore override incorrectly required room authority for three intentionally roomless model-only fixtures (model02: three new failures). The final override returns after official SaveService restore when no environment is installed; it does not invent a room or bypass a failing existing room. Original model checks remain 259. Curve room checks remain 69. Missing-output negative exits 64 before fixture work. All owned capped jobs released with zero active processes.
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-09\evidence\worker.log` SHA256 `12d83b853bcd5fa630362b0f4a0811f0bbc01682c208077947c8af890ccf6c5b`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-09\evidence\job.json` SHA256 `666ceedb5f7f60332d41466843eb13780c5bf0f4fb0eda4cd4f4e70692395f63`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-20261115-09\evidence\storage-manifest.json` SHA256 `6e2e78a670e4d9fea4e585b5250d2b7843e56b9c3446a76c376d8e3a5c1a8dd0`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-model-20261115-02\evidence\worker.log` SHA256 `7f393006e089711f9f562f40ec3bb438ce88af91de2bfea7049f2d5b51920924`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-model-20261115-02\evidence\job.json` SHA256 `55747d58a8499a35796d40193805035a53b7e371aa5da86b905e6ac77a3c5e74`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-model-20261115-02\evidence\storage-manifest.json` SHA256 `c78a43a27b431f5f34d7cedadf47df382295dbdd3e5a3676df537caa1bf93239`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-model-20261115-03\evidence\worker.log` SHA256 `690b200fd0ac14f15c2623a0807a44db019383583ca24920ee53075091311a6b`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-model-20261115-03\evidence\job.json` SHA256 `3a29c9c152544048d10f97e46b671b50a1d7ac56e345d4ae73d84d03d282b9ed`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-model-20261115-03\evidence\storage-manifest.json` SHA256 `5071db6636f43532ef5d3376a5f13546da36e1d03d15b03ff5e8f2ab6baea6ca`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-adjacent-20261115-02\evidence\worker.log` SHA256 `1890487bc2e7f017b9d33c4f3cf430e1618af19a183dae40b24461b7c151a32a`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-adjacent-20261115-02\evidence\job.json` SHA256 `a63080509203b211461b6158ab6463e87a3c7a2340685ec302cee8c5542ca72f`
- `E:\CodexQA\BTH\runs\next-bugfinder-crew-reward-adjacent-20261115-02\evidence\storage-manifest.json` SHA256 `c79f458c93e1ae87ad0b4a1a6d1c451e7a856d7168a60e52077bcbf4b63c7c3b`

Final test source SHA256 `b73aaeaecc929a1f5e981e016a2bf96392f8b8c0d2b7cd217042452ae6984508`.

Manual reconciliation run 29: 109 pre-existing global findings remain; zero findings for this newly registered scoped repair. Other backlog objectives and original BTH061-006 stay open.
Independent review approved the scoped test repair after the final matrix. No runtime/NEXT behavior change is claimed.
