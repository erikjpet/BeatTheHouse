# game06_3 review handoff

Branch: `codex/game06_3-impl`
Frozen base: `a2760d816c781e711ff0923c296f97b786662453`
Roulette logical head: `c0d2b75e1fdc47f283488481e2bad0557ab8dbb6`
Baccarat logical head: `0d4b3ebb66eb91db659f21444dac19f6f5873c61`

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
