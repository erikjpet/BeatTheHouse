# Crew terminal diagnostics and post-ending coverage

Stable IDs: `BTH-QA-CREW-ENDING-001` / `BTH-QA-CREW-ENDING-001-SIDEBAR-20261116`. Owner: sidebar task `6afa5073-0cb4-8191-82b0-326a14a3e029`.

Native source: `a77b2811d2e9be6bc71567d7194cb8142e53a90b`. Its only difference from tested product baseline `3cecec33096ea336ecd8d5dd06378c62e2043cc6` is the three previously reviewed QA documentation files. No product patch or guard change was made. This is headless native public-host and actual Control-signal coverage, not browser/WASM or pointer acceptance.

The final three continuing-campaign cases use `7d02874673508aa59243d7bb447a05f731fe29dd`; that commit adds only this follow-up QA proof and ledger updates. Both documentation-only source comparisons were checked against the same product baseline before launch.

## Independent classification

1. **Heist dictionary comparison: harness numeric-type mismatch.** An isolated public dictionary with round 3 and score 100 compares unequal after JSON parse because its integer values become floats (Godot types 2 to 3). Comparing both sides after wire normalization succeeds. The actual terminal snapshot also has a float round. This independently reproduces the comparison behavior without replaying a paid hand. The original failed log remains unchanged; the previously recorded cold checkpoint retains round 3, all decisions, score 100 and 14 chips.
2. **Getaway fare assertion: incomplete accounting expectation.** The offered fare was $0, and the same arrival completed Clean Sweep and awarded $1,150. Official terminal Continue has $1,327 = $177 - $0 + $1,150, 14 chips, and exactly one Heist payout report row of $1,150. Menu/title Continue and repeated report reads preserve the same outcome and RNG; no second travel or reward was invoked.
3. **Terminal room authority: derived presentation proof observed outside its active-room lifecycle.** The independent active-getaway control loads on ENVIRONMENT with valid room authority and no errors. The terminal copy loads on VICTORY and initially reports the same three mismatches for layout audit, renderer snapshot and semantic projection. A separate normal Menu / Resume test, with no stale-game probe, leaves the wallet/heist/RNG unchanged and rebuilds valid room proof on Resume. A stale native game-entry request is rejected without changing gameplay state. Normal saved Main Menu and title Continue return to VICTORY and preserve the earned outcome. Source `foundation_main.gd:7462-7464` checks room playability/recovery only for nonterminal loads; `close_run_menu()` invokes the normal presentation refresh. The original active-room assertion was therefore outside its required boundary. No playable-room rejection, invalid authority acceptance or lost terminal outcome was established in these bounded checks. Preserve the original validator result; do not weaken room validation or claim all terminal callers are qualified.

## Continued reward and next-run coverage

The real enabled report Claim button stored the single pending Roadside Luck Blue Bag. Exactly one unopened bag and one instance ID were added; the next instance ID is 4 and unopened count is 1. Cash, chips, completed heist and run RNG stayed unchanged. A stale same-marker claim callback did not grant another bag or consume collection allocation/RNG. Official Continue preserved the claimed state.

A separate OS-process Continue then retained the claimed bag and enabled the normal New Run button. Its actual pressed signal started a generated active run at Back Alley with $100, zero chips, valid room authority, no inherited Crew score or companion error, and the same one unopened bag. Normal Save/Continue retained the new run's wallet/RNG and valid room. The original pending-bag terminal checkpoint remains untouched; all continuation work used complete verified copies of save_dir, appdata and localappdata.

The new standard campaign then continued normally: its actually offered Parking Lot Tip / Follow the tip revealed a direct Punchline route. The posted $8 journey arrived in the club with $92, and the genuinely offered Side Door / Try the word entered the casino free. Save/Continue retains wallet, chips, run RNG, standing, layer and valid room authority. The Crew lender is visible and the Crew Back Room remains gated; no new loan, reputation grant or second heist was forced. These three further cases pass 4, 10 and 8 checks.

Current native continuation checkpoint: `E:/CodexQA/BTH/runs/crew-sidebar-continuing-side-door-20261116-01`, slot `NEXT-ORDINARY-20261115-O`, Punchline Casino, $92, no modal, one earned unopened bag. The original terminal checkpoint remains `crew-sidebar-count-terminal-cold-20261116-01` with $1,327 / 14 chips and its pending reward. Do not confuse the distinct disposable branches.

## Evidence

All eight workers exited 0, were assigned to capped Jobs before execution, and released with zero owned processes. Each storage manifest and both launch gates are in the case's evidence directory. The source checkpoint tree hashes remained unchanged after each worker.

| Case | Checks | Worker log SHA-256 |
| --- | --- | --- |
| crew-sidebar-independent-terminal-20261116-01 | 15/15 | `345e72cae46586f91c2d9ddb98b85d3111ed59b4e004540849d1c94348d53def` |
| crew-sidebar-independent-active-20261116-01 | 5/5 | `399418ba730ae9e11dda08de586cd95cc407a0fcd82ea6c4061fd744509967b8` |
| crew-sidebar-independent-menu-20261116-01 | 4/4 | `f6a995b18d9d315b1b49b45e642fdb2899d9124c4a63358a4db541dffbd6444a` |
| crew-sidebar-postending-bag-20261116-01 | 12/12 | `c14204546a750fa8a26d84985b57623f94fd67ef19f262e5f8db2705898bd76f` |
| crew-sidebar-postending-new-run-20261116-01 | 13/13 | `3f8792a31569a0711cbe00c22e5b61f4ec65b0de35be8d1a470112c30a8b52dd` |
| crew-sidebar-continuing-inspect-20261116-01 | 4/4 | `bf7697dae2887cdfb971b4c8bd6f2c327bb92ec4da1d62cb84d4b486783ad2f0` |
| crew-sidebar-continuing-tip-20261116-01 | 10/10 | `81d0a888deab9fd4dd3dff3d2e50d7763b2216a774b4e1ef3c597d3f38a12662` |
| crew-sidebar-continuing-side-door-20261116-01 | 8/8 | `a039d0c0dc68db4d77d8234281639cfe9ced232f0d273dde7e11d184668a678b` |

The earlier proof commit a77b2811 was pushed without force and remote refs/heads/main verified at its full SHA. This publishes QA evidence, not browser acceptance. Native continuation and original parent scope remain Open; browser/WASM and human pacing remain unverified.
