# Ordinary generated gameplay and persistence batches

Source 29636fad, runtime unchanged from deployed 8bfa0b8f. Five batches use real Main, normal seeded campaign start, offered Gas travel/game entry and production surface dispatch. No scenario pins or wallet/RNG/stock/outcome rewrites. Isolated E profiles, same-process new Host Continue, not separate-process cold restart or Web testing.

1. Scratchers: final 20/20. Predeclared D/E/F seeds. D has no offered Gas route (not reached). E/F paid tray purchases preserve wallet/RNG and every ticket field. F finishes reveal/file/floor. E reaches an authored response popup after filing; floor path not reached, no decision bypassed.
2. Pull Tabs: final 32/32. New G/H/I seeds all reach Gas machines and preserve paid trays/cash/RNG. G/I collect/reveal/file exactly one ticket into custody and return to floor. H reaches an authored response popup after file; floor not reached.
3. Coin Pusher: 12/12, ordinary seed A, three paid drops 94 to 91. Normal Leave completes chunked settle in 264 ms with final projection. Main Menu saves, new Host Continue preserves exact saved machine and wallet/RNG; reentry does not recharge drops. Native_v3 available.
4. Video Poker holds: 26/26, targeted ordinary B/C seeds known to offer game. Holds 0+2 and all five displayed cards survive Continue; Draw settles exact net -2/-1. No forced cards. Helper inherited fidelity label says three seeds; actual rows/loop have two, which is the claimed scope. Initial card comparison was strengthened to actual five-card surface data rather than potentially empty UI entries.
5. Partly scratched ticket: 16/16, ordinary F Lucky7s. Production pointer-dispatch begin/move/end at actual region coordinates changes mask revision to 2 without completing ticket. Save/new Host Continue preserves exact partial latex/ticket values; Scratch All/File returns to floor. Native dispatch, not OS pointer input.

## Failed diagnostic assumptions retained
Initial Scratch 20 checks failed two strict tray comparisons. Leaf probe shows integer-to-float representation after JSON restore (price 2 becomes 2.0). Final recursive comparison permits only exactly equal numeric int/float values, no tolerance/rounding; zero other differences. Pull Tabs initial 30 checks similarly failed three strict tray comparisons; final exact numeric recursive check finds no other changes. Original failures retained, no production test weakened or product patch needed.

Initial Coin Pusher helper expected floor after five frames, before authored chunked settlement finished. Source confirms deliberate yielding. Corrected bounded wait observes game_exit_settle_active false, without artificial physics advancement or bypass. Original premature expectation retained, not a player defect.

All runs timeout false and active_at_release 0. Owner saves untouched. These supplement, not close, original all-eleven-game/visual coverage and historical cause-unknown objectives.

## Evidence hashes
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryscratch-20261115-01\evidence\worker.log` SHA256 `9885a61ceee6fd916726c486597e7de2b7114b3909feecded6655c48038fe979`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryscratch-20261115-01\evidence\job.json` SHA256 `6beb4c46ac788e7867c7aa37b37bc36222477ddc2a5e332d3e8099a7e9d0bbf0`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryscratch-20261115-01\evidence\storage-manifest.json` SHA256 `66ed79c913d32957e07cd75ac3fa67a621daf2683ba6d3dace1be64900f3b49c`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryscratch-20261115-02\evidence\worker.log` SHA256 `023d3fe76be19b62b26bdbfd2de4924f85f76f2736abfa65da6983b413af0fbb`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryscratch-20261115-02\evidence\job.json` SHA256 `7a159b382e3b5619ac3a4d04d9f309deda61be63796f56e492284b821f036be9`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryscratch-20261115-02\evidence\storage-manifest.json` SHA256 `41340dc794efe5cf8759be33c8630ec3e17b9589365c0aadc459ea5940648644`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryscratch-20261115-03\evidence\worker.log` SHA256 `488f5e675cc47d6fa21f6467c462d3e343224284eb0657965647b967965a5c9f`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryscratch-20261115-03\evidence\job.json` SHA256 `ba640df6a13282efa338a1c78cc38b5c5b96914ee76b53cacd783159a87a2ead`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryscratch-20261115-03\evidence\storage-manifest.json` SHA256 `be16589799a2d488a0322b009f0c7405949c18a26dddcafc1f90c6c8177680a7`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypulltabs-20261115-01\evidence\worker.log` SHA256 `45fdc9c8d8f3630308399e51d2057a8080cfe50ce4c2256eccdea43dce4b5b2e`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypulltabs-20261115-01\evidence\job.json` SHA256 `7ba3de254220e94676754c822c942a1648daaa37cd987da75307f6335a3758e9`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypulltabs-20261115-01\evidence\storage-manifest.json` SHA256 `a772ff848fddc68571f1e6d368a69a4fdf82ced2ae9427af891b62d53ba045d9`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypulltabs-20261115-02\evidence\worker.log` SHA256 `eedfcc562a366051f295f520ebc2eaed14ca5ecec65901432f89d7b8e22c36c4`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypulltabs-20261115-02\evidence\job.json` SHA256 `34861a3fabb613fd5035bed2218a79197358527722769e6b854bb74d1b491d8a`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypulltabs-20261115-02\evidence\storage-manifest.json` SHA256 `5b42d2362ac5836e78bce34d6959475e667ee9c3d572531a6ad89a25b13d9d50`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypusher-20261115-01\evidence\worker.log` SHA256 `d605aeba617dea753e9858636f9640ee9967de24a45c08fe734fc12a4dc0f158`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypusher-20261115-01\evidence\job.json` SHA256 `4837bb12dd06b703f1bcc61c00e49bdcb2401000d80f2e5a2ecdb8f393110309`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypusher-20261115-01\evidence\storage-manifest.json` SHA256 `d3fddb27e5f8878eb970be17c27a7472aed5a4dc34d5079c33742cec70030a1b`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypusher-20261115-02\evidence\worker.log` SHA256 `3c5fa855e5a51d15a40dd281e4106f5cdb3562eee96b002a863f21a35aa849f9`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypusher-20261115-02\evidence\job.json` SHA256 `c5a4b82e4a12047fac427653041f86d4c0518b0c938ce84186d498665a3c01ff`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarypusher-20261115-02\evidence\storage-manifest.json` SHA256 `41552fc940b2b27832bb6b9d77966dafb6aebd7a0048d5b6c96ce1275afb0c43`
- `E:\CodexQA\BTH\runs\next-bugfinder-vpholds-20261115-01\evidence\worker.log` SHA256 `36cb0d50ce56424dabb71b942a9cd9b215ce5b72ac8b60a42f9d76f6a2c6cfa6`
- `E:\CodexQA\BTH\runs\next-bugfinder-vpholds-20261115-01\evidence\job.json` SHA256 `675d870f968426f0d4ddc7acf7f0ca188010562f534df34db0fa30c1df022576`
- `E:\CodexQA\BTH\runs\next-bugfinder-vpholds-20261115-01\evidence\storage-manifest.json` SHA256 `797930bbcb5a2fc5353f109cd40b83965c28f8a3fa200a1bc551c78e642259dd`
- `E:\CodexQA\BTH\runs\next-bugfinder-vpholds-20261115-02\evidence\worker.log` SHA256 `781a99a6b1b298c5c8840c51d0bbd9bcaae5cc1300c838ac87e71fcbb9402460`
- `E:\CodexQA\BTH\runs\next-bugfinder-vpholds-20261115-02\evidence\job.json` SHA256 `1869766ce2a65d0fb71c3241970ee959324b2b9fdc15d21ba2e9f641f7a982c0`
- `E:\CodexQA\BTH\runs\next-bugfinder-vpholds-20261115-02\evidence\storage-manifest.json` SHA256 `72ec3abb1ae791a5d177587af3f6400256b90ad9d4d4ceea7b625b2abf9abd3b`
- `E:\CodexQA\BTH\runs\next-bugfinder-scratchpartial-20261115-01\evidence\worker.log` SHA256 `397432808723e44e20077fe4c8945fc22e7bfa51fb75a8ed3c04c94f3d5283b3`
- `E:\CodexQA\BTH\runs\next-bugfinder-scratchpartial-20261115-01\evidence\job.json` SHA256 `bc6f9b88da80ed4c96f7ce6eed7465da65b4a4c4350de7796734ece4ced3363e`
- `E:\CodexQA\BTH\runs\next-bugfinder-scratchpartial-20261115-01\evidence\storage-manifest.json` SHA256 `443266ca2428205aca2fe67c6ee2c0b437aa31980c8cee258d78fc0da3b3e113`

Reconciliation 23 retains 109 existing findings, including unknown historical owners for the original Scratch-exit and eleven-game objectives. These supplemental samples do not reassign/close them. The first proof write failed on local text encoding before ledger mutation; UTF-8 rewrite verified before staging.
