# General NEXT QA: ordinary beach routes and Slot

Stable ID: BTH-NEXT-QA-GENERAL-SIDEBAR-001. Visible sidebar owner 6afa5080-2f00-8191-804a-d401aa98a020. Recorded 2026-11-16T04:25:03.994200+00:00.

This continuation adds99 qualified checks to467, for566 general-exploration checks. Seventeen bounded native Jobs closed with zero owned processes; ten diagnostics/original failures are retained outside the pass count. All sampled gameplay preceded the Slot fix on runtime3cecec33. The separate current-main Slot correction has215 focused checks; these are not added to the exploration count.

## Ordinary routes and coverage

Two predeclared fresh seeds SIDEBAR-GAMES-20261116-G/H followed normal affordable routes through Alley, Motel, Gas Station, Corner, Bar and Delta Queen. No module, bankroll, flag, RNG, outcome, clock or offer was injected. The first broad route probes were setup diagnostics and did not reach the desired game; they are excluded.

Cold Continue restored an intentional static travel receipt. The actual visible Continue to Delta Queen Riverboat Casino Button acknowledged it without an extra fare or RNG advance. Earlier wrong-oracle receipt probes remain excluded. Two actually offered Walk the Deck services cost10 each and reduced the deck lock2 to0. The then-offered beach route was free. G reached beach with34; H with28. A fallback cost0 in the probe's absent generic last_service_attempt field is not the price of the deck services.

Normal beach offers included Slot with2/5/10/15/20 stakes. G generated five reels; its actual2 loss left32. Cold Continue and actual canvas hit geometry preserved the selected stake, single paid round and normal reveal timing. A blocked rapid click during reel motion did not add a wager. After the canvas became ready, actual5 selection and Spin made one new paid round; cold settlement left27, RNG1205754093, round count2 and selected5. No bonus/autoplay appeared.

H generated six reels. Actual MAX20 and Spin naturally lost20, leaving8, RNG493541604 and one paid round. Cold Continue and normal reveal then exposed a real defect: actual20 Spin was correctly refused, but actual enabled MIN2 stayed20 despite no modal or deferred-input gate. The real canvas mapped MIN to slot_bet index0. A separately labeled detached diagnostic reported pending_delivery. Repeated wait did not repair it.

## Confirmed defect and disposition

BTH-SLOT-UNFUNDED-SELECTION-001 tracks that exact H defect. Current-main68f5592 reproduced it before the narrow player funding preflight. The tested fix is now pushed to main1240cebdd15ee294e8997b46d20819762d691923/tree07fa7f46fc250247b26134b19350b155e2641904. Its215-check focused warm/cold/legacy recovery evidence is separate in docs/testing/BTH-SLOT-UNFUNDED-SELECTION-001_20261116.md. NEXT follow-through is underway; no Web startup or visual claim is made here.

One earlier G probe invoked the host directly while the canvas blocked Spin. That skips the real input gate and is not player evidence of a rapid-click bug. It is retained as a diagnostic and was not repaired as a product defect. Native canvas tests use actual hit regions and press/release event handlers; they are not rendered OS-pointer or Web/WASM proof.

## Custody and evidence

Only exact copies of this task's closed owned recent saves and companions were used; source hashes remained unchanged. No Erik save/profile or browser was touched. Storage planning and launch gates reserved4GiB plus20GiB headroom on admitted E:. Bounded12% CPU/2GiB Jobs used assignment-before-resume and closed0. No scheduling or animation code was changed by exploration. Item/scenario implementation remains paused.

| Run | Evidence class | Checks / failures | Exit | Owned | Log SHA256 |
| --- | --- | --- | --- | --- | --- |
| sidebar-fresh-game-route-G-20261116-01 | retained diagnostic/original failure | 22 / 0 | 0 | 0 | 6dbf48a3a5feed203865046c71bbd350296cea4a223dea74c95937036f711c15 |
| sidebar-fresh-game-route-H-20261116-01 | retained diagnostic/original failure | 22 / 0 | 0 | 0 | 7f101ea8227b003ba7dfc71b50fc6c85cc79381f2dfd2d277f9cc9028185f96f |
| sidebar-beach-route-G-20261116-01 | retained diagnostic/original failure | 3 / 1 | 1 | 0 | 38b6533b689d9f549dae261118e5328b2c381ba097390217a3e5c10bf6c36e3d |
| sidebar-beach-route-G-20261116-02 | retained diagnostic/original failure | 3 / 1 | 1 | 0 | 1101bca956b713c346bdcccadd7dc859f23d72c9ea8d67474f120ffd578bffbd |
| sidebar-beach-route-G-20261116-03 | retained diagnostic/original failure | 3 / 1 | 1 | 0 | 1a8ed232c15d56b1d4971c96568ec00d33611976c8f768baf1d524185be4be18 |
| sidebar-beach-route-G-20261116-04 | qualified | 18 / 0 | 0 | 0 | c1bdc144e1b5b76866950cf0fd42c890e721404849329217aaa164b83ed8b28d |
| sidebar-beach-route-H-20261116-01 | qualified | 18 / 0 | 0 | 0 | 80842cf7ef3baa1c9e1197fab41a9ad40f02d6c30b1c8973048ff19bbe9e12a5 |
| sidebar-beach-slot-producer-G-20261116-01 | retained diagnostic/original failure | 11 / 1 | 1 | 0 | c1df6a3e800b7ec1b151a8a9ca5dd9de9b35c3f541575b8dd38f9c8737b5e5df |
| sidebar-beach-slot-producer-G-20261116-02 | qualified | 11 / 0 | 0 | 0 | 58b5270d5c4347822838d9fc178f920d084647b637aa514f6ae46d8eb549a10c |
| sidebar-beach-slot-cold-G-20261116-01 | qualified | 11 / 0 | 0 | 0 | ea55796ea1d59f434c7a24c3f464c992ab176fd694b28299d4d7a42b29495167 |
| sidebar-beach-slot-canvas-G-20261116-01 | qualified | 14 / 0 | 0 | 0 | d439c41e68691bc78a61009f2b6db5855cfac30adcb121ff960ab5aa22fe7931 |
| sidebar-beach-slot-five-cold-G-20261116-01 | qualified | 12 / 0 | 0 | 0 | 22b99e190845a2c2eba2a8f8373e14285ccda2b9e233604ecc58461d07bccc4f |
| sidebar-beach-slot-max-H-20261116-01 | qualified | 15 / 0 | 0 | 0 | f314feb2ee0b50c7b297bb6381aa73b99e1f8b4903a2de78bc5ff3fb8fd35bb7 |
| sidebar-beach-slot-max-cold-H-20261116-01 | retained diagnostic/original failure | 15 / 1 | 1 | 0 | 4d930aab29d916bce95070514da488ade9603efbf8f02b3bafeba4b94a574459 |
| sidebar-beach-slot-max-cold-H-20261116-02 | retained diagnostic/original failure | 15 / 1 | 1 | 0 | cd88d4615e6ae6f83afc4f5f5bcd32d7235b4f489bd28039131b03ceb4f1b3ae |
| sidebar-slot-min-trace-H-20261116-01 | retained diagnostic/original failure | 15 / 1 | 1 | 0 | be15b132ad222ee873dd0ea10473dfcee1fd68d5963f4f5c0490d34ffb49f4e6 |
| sidebar-slot-min-intent-trace-H-20261116-01 | retained diagnostic/original failure | 15 / 1 | 1 | 0 | 4af02f72b6d01d903b7eb8af0ca45d3e3aaffd6219d4f95194815a73cfaaedd3 |

Exact commands, guarded manifests, launch gates, custody, diagnostics and case JSON remain under E:/CodexQA/BTH/runs/<run>/evidence. The broad continuous general-QA/ending scope stays Open. Continue distinct normally offered routes/games; the three ending tasks retain their own owners and acceptance.
