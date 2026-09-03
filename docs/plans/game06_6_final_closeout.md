# game06_6 Bar Dice final closeout

Date: 2026-09-02
Functional candidate: `9a6b6abb43b41bebd5d3a12a9a6bbddb25ad68f5`
Recovered product integration: `d98de5440bec7685f4bb26eace77f2dbb1627f53`

## Verdict

`game06_6` is accepted as complete. The recovered Bar Dice product is the
shipped 3,593-line implementation, not a rebuild. It presents the complete
seven-phase wager/cover/cup/throw/reveal/call/settle ritual through the sealed
Foundation host, preserves the existing Ship/Captain/Crew rules and economy,
and supplies deterministic opponent, onlooker, tell, energy, accessibility,
save/revisit, and presentation state.

Closeout added only `tools/game06_6_bar_dice_web_capture.mjs` so the existing
platform probe could be executed in a fresh Web release export. No game rule,
payout, probability, budget, product data, or runtime authority changed.

## Recovered dependency disposition

- Game ritual host/runtime integration `5a2b1e1a6782a13308585e1a974adeeb86be0647`
  is an ancestor of the closeout candidate. Bar Dice exposes the accepted
  sealed-action proposal/funding/apply boundary; compatibility resolution is
  observational and cannot commit a live run.
- Craps depth integration `7d230a63c14377eea55b2a506bfbf4df67cfb7f3`
  is also an ancestor. Its public environment adapter is deliberately
  Craps-owned and rejects a foreign Bar Dice producer/game/table identity.
- The active prompt explicitly requires a filed finding when that seam is not
  general enough. `docs/plans/game06_6_product_recovery_inventory.md` records
  that finding. Bar Dice does not call private Craps helpers, copy teaching,
  sweep, refund, relocation, or aftermath rules, or create a second street
  authority path.
- Consequently, caller-authored interruption data cannot mutate Bar Dice.
  The ritual projection accepts only a future already-authoritative public
  interruption fact and proves exact returned-stake/aftermath presentation from
  every nonterminal phase. A future generic street-host adapter remains outside
  this row's ownership; its absence is fail-closed, not duplicated behavior.

## Functional and economy evidence

- Project validation: PASS.
- Clean Godot import and GDScript load census: PASS, 303 scripts, zero failures.
- `game06_6_bar_dice_contract.gd`: PASS, seven phases and ten seeded projections.
- Focused shipped-game suite `bar_dice_game_suite`: PASS, zero failures in
  73.405 seconds. It covers scoring, generated identity, the full surface,
  visible results, keep/reroll, patron determinism, match legs, bonuses,
  wager lifecycle, cheats, items/luck/alcohol, edge bands, and save/load.
- The suite's 1,000-round fixed samples retained the authored house edges:
  friendly `0.1106`, standard `0.1423`, and sharp `0.1719`.
- Live Main-scene ante probe: PASS for `$40`, `$2`, `$10`, `$40`, and reopened
  `$5` selections through actual rendered hit regions.
- Sealed host settlement: PASS for exact wager identity through funding lease,
  delivery, apply receipt, result, story entry, and bankroll delta. Below-floor
  wagers reject without money, RNG, or table-state mutation.
- Craps dependency contracts: core depth PASS for five ritual profiles;
  environment integration PASS for five distinct responses and nine hostile
  authority cases.

Focused suite report SHA-256:
`847F7C3E8D462C99469C72DAF438DF02A66A69449BB94A8273CB504E0DEC6718`.

## Determinism and lifecycle

Two independent ten-seed runs each completed 560 checkpoints and produced the
same combined hash `3142248255`. Each pass includes ten
`game_bar_dice_roll` and ten `skill_bar_dice_controlled_roll` authoritative
checkpoints. The two reports are byte-identical with SHA-256:
`7FF8067FE2652AF98AC1D48CF94868493F3C820551BC27BC4DE0E870FE70D89F`.

The row contract additionally proves:

- no phase skip, double transition, receipt conflict, or replayed settlement
  one-shot;
- save/load normalization at all seven phases;
- exact refused and partial-cover conservation;
- interruption projection from every nonterminal phase with exact returned
  stake and aftermath receipt;
- no future dice, RNG, timing, private throw, hidden sweep, or wall-clock leak;
  and
- identical pointer, keyboard, controller, and reduced-motion action ids.

## Native/Web, performance, and visual evidence

The native OpenGL run and fresh Web release export in Chrome
`152.0.7977.65`, with CPU throttled 4x, both passed all 15 semantic states and
produced the identical hash:
`4e24b5f7230e6169cec55ce0e812fe76639dfff64ce3f49165d7644fc115019c`.
Canonical semantic objects are equal after key-order normalization. Web console,
page, and request errors were all zero. The fresh final export contained ten
files totaling 69,195,746 bytes and reported no export/import/script error.

Native report SHA-256:
`0160B42293BA8701D0F5EEF8BC725E3B53BBD983D218011AD68080303EBA3CA1`.
Web report SHA-256:
`07A58247733BA08F910E989E93FD7ABC140EE084C9F4FD9F8B2201F4431139FF`.

The unchanged full performance probe passed. Bar Dice completed 48/48 resolve
samples with average/p95/maximum `0.611/0.646/0.677 ms` against unchanged
`1.5/3.0/4.0 ms` budgets; surface and resolve coverage were both present.
The full report had zero failures. Report SHA-256:
`0115DD7260461BC36A52B9128B02532E63E33C3173C574605A362D42FE847BC7`.

The native raster refresh reproduced all 15 retained 1280x720 captures and the
contact sheet byte-for-byte: quiet/crowded bar, agreed/refused wager, shake,
throw, reveal, call, win, bad beat, interruption, partial return, reduced
motion, small screen, and colorblind labels. Every capture records visible
focus, phase, cash, non-color labels, and minimum 160x64 controls. Manifest
SHA-256:
`A94F67AE704C0FC556091B13657712BC1C9CAF1BBD613D2BF5D46B75959AEB3A`.

Canonical Foundation visual QA also exited zero with no warnings and exercised
Bar Dice in the production Main scene. Report SHA-256:
`B916289FA7C653DE04DAA9167A2E21EAA4161CA5DE3D176F92266F1DE5A71779`.

Godot 4.6 stable console SHA-256:
`FC759F9D296FE54F09AB66D41DF6DDD2D278493B0E71109F6688EF029AD271AE`.

## Retained non-green attempts

- The focused wrapper completed project validation, clean import, and the
  303-script load census, then its outer command timed out while the slower
  Bar Dice suite was still running. The exact game suite was rerun directly and
  passed in 103.5 seconds total / 73.405 seconds measured check time.
- An extra whole-runtime contract invocation exceeded its 900-second outer
  limit without producing a verdict. Its verified orphan processes were
  stopped. This is retained as a timeout, not a pass and not attributed to Bar
  Dice. The row-owned sealed-host checks and focused shipped-game suite passed.
- A first screenshot refresh used the dummy headless renderer and correctly
  produced no pixels. It was rerun under the real NVIDIA OpenGL renderer and
  passed all 15 captures. No blank output was accepted.
- A first transient Web export included unrelated tools and logged a missing
  unrelated Main-scene dependency. The final fresh export isolated the Bar Dice
  probe, produced zero export errors, and is the only export used for verdict.

No failure, timeout, budget, or earlier rejected head was erased or converted
into passing evidence.
