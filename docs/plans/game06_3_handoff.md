# game06_3 review handoff

Branch: `codex/game06_3-impl`
Frozen base: `a2760d816c781e711ff0923c296f97b786662453`
Roulette logical head: `c0d2b75e1fdc47f283488481e2bad0557ab8dbb6`
Baccarat logical head: `0d4b3ebb66eb91db659f21444dac19f6f5873c61`
First rejected product head: `2852387f478930a69f568987eb835ee0c1ccfff1`
First-remediation implementation heads: `641419cccc5d9a9fe758776130ed4363ce6c739c`, `987a2f2aa07e0755b864315a34924de19868f369`

No rejected game06_1 runtime head is in this branch's ancestry. The row has no
shared-runtime import, copied runtime definition, compatibility call, or edit.

## Gate record

- `game06_3_depth_contract.gd`: PASS for Roulette and Baccarat. This includes
  exact accounting, ordered phases, single-stack correction, late-input policy,
  deterministic save/revisit, squeeze authority isolation, reduced-motion
  equivalence, third-card procedure, commission, actors/objects, crew/security,
  and all material energy tiers.
- Roulette rule audit: all 157 targets passed hitbox and payout checks. Its
  wrapper failed only for 250 inherited missing-asset content errors on the
  frozen base; no Roulette-specific failure remained.
- Baccarat seed audit: 400 hands completed with no game-specific failure;
  Banker/Player/Tie rates were 0.468/0.460/0.072 and resolve p95 was 1.007 ms.
  Its wrapper likewise failed only for the same inherited 250 missing-asset
  content errors.
- `git diff --check`: PASS for each logical group.

Generated reports remain under `.tmp/` and are intentionally not staged.

## First-remediation record

- Baccarat squeeze progress now physically controls the rendered card: back at
  zero, bounded face reveal while held/dragged, full face only at completion.
  The exact hit is a shared hold region, so pointer/touch and native
  keyboard/controller confirm routes converge; reduced motion completes the
  same fixed card, incomplete release persists, and late input is side-effect
  free.
- Roulette stake-down removal resolves only an explicitly focused named stack.
  Direct pointer removal carries its exact stack index; absence of focus is a
  gentle non-mutating refusal, never implicit last-stack removal.
- Both renderers now visibly consume actor, object, phase, and energy projection
  state in non-color-only ritual strips.
- Focused executable proof passes real pointer/hold/confirm/reduced-motion/late
  squeeze commands, exact focused Roulette removal, all phase save/revisit
  boundaries in both games, renderer consumption, and 10-seed neighbor outcome
  and bankroll isolation.
- Project validation: PASS. Canonical visual QA: exit 0, with inherited missing
  assets still printed by the frozen base. Roulette audit: 10/10 generated
  tables, surface checks, draw checks and spin resolves; 96 trajectory frames
  min/max, resolve p95 2.364 ms. Baccarat audit: 400 hands, rules/rates clean,
  resolve p95 1.325 ms and surface-state p95 2.582 ms; wrapper red is exactly
  250 inherited missing-asset errors. Canonical performance probe exercised
  Roulette and Baccarat liveness successfully and failed only inherited Coin
  Pusher full-cap budgets/coverage.
- The full table suite is unavailable on this frozen base because its inherited
  `check_table_games.gd` parent (`check_slots_surfaces.gd`) does not resolve,
  producing missing inherited helper parse errors before any test runs.

## Final closeout — 2026-09-02

The complete recovered implementation is on current `main` through
`212475356cedb42056a2677b590e5b69ed0ac8aa`, including the later sealed-host
corrections `1354ae26` and `679b1d8a`. The prior D3 choice is no longer a
product ambiguity: both full games are present, so this closeout takes the
full-closure outcome without reducing Baccarat, splitting a successor row, or
granting an exception.

Closeout commit `45239305` repaired stale audit callers that had continued to
treat the now-observational compatibility resolver as a committing boundary.
The audits now use the real `FoundationMain` sealed action host, verify exact
money/history mutations, and advance Baccarat's statistical shoe from returned
authoritative snapshots. Commit `9c2e6b1a` adds a small cross-platform semantic
probe for Roulette's authoritative pocket presentation and Baccarat's fixed-card
squeeze presentation. Neither commit changes game rules or product behavior.

Exact closeout evidence:

- Project validation and clean editor import: PASS.
- `game06_3_depth_contract.gd`: PASS for Roulette and Baccarat.
- Focused Foundation suites: Roulette PASS, zero failures, 803 ms; Baccarat
  PASS, zero failures, 348 ms.
- Roulette rule audit: PASS for all 157 wager targets and all payout/hit regions.
- Roulette seed audit: 10/10 generated tables, surfaces, draw checks, and sealed
  host spins; every trajectory had 96 frames. Full host resolve p95 was
  510.343 ms and surface-state p95 was 1.905 ms. Report SHA-256:
  `12610C2EB50DE37D1DAC648904E4964763BEE00271D97A7B1C172324AE19157B`.
- Baccarat seed audit: 400 advancing-shoe hands and 10/10 sealed host commits;
  Banker/Player/Tie rates were 0.477/0.440/0.083, flat Banker delta was +109,
  proposal resolve p95 was 37.694 ms, and surface-state p95 was 1.277 ms.
  Report SHA-256:
  `2C0DE7A796689B1CA1A6EACE0FD7E19CEE2D921EB8916E025F18845E60AC20E8`.
- Determinism: two 10-seed passes were byte-identical, with 560 checkpoints,
  combined hash `1246250829`, and report SHA-256
  `E5C12ECAE8FEC14D78F4AEBA30AF04B6552892C153956C9EB6D3F6569D869F94`.
- Native/Web: fresh Web release export plus Chrome 152 and native Windows each
  passed 10 Roulette and 10 Baccarat cases with semantic hash
  `ba2fa83da58c9865fb2801b6d561e7e98b2ecd26fcbc3fa0df6b5cfd6c010ab7`.
  Roulette presentation ended in the authoritative pocket; Baccarat normal and
  reduced-motion squeeze states targeted the same fixed card. Browser errors:
  zero.
- Performance: Baccarat resolve avg/p95/max was
  1.096708/1.242/1.281 ms against 1.25/1.75/3.0 ms budgets; Roulette was
  1.44325/1.537/1.684 ms against 2.0/3.0/4.0 ms budgets. Renderer and resolve
  coverage were both present for both games.
- Canonical visual QA exited 0 with no warnings. Combined focused coverage also
  exercised phase and energy tiers, crowded layout/hit regions, actors and
  objects, cheats/crew/security, reduced motion, accessibility cues, and every
  save/revisit boundary.

Two broad wrapper runs timed out in unrelated prerequisite census work, so they
are not presented as green evidence; their row-focused checks were rerun
directly and passed. The unchanged aggregate performance probe also retained a
separate Coin Pusher skill-stop draw red (7.90 ms versus 7.00 ms) and missing
active-sequence coverage. That unrelated red remains recorded and no limit was
changed. `game06_3` itself has no remaining automated implementation or
verification blocker; only the program's eventual human playtest remains.
