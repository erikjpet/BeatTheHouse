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
