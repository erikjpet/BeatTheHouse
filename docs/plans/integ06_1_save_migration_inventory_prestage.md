# integ06_1 save/migration inventory pre-stage

Status: **UNREVIEWED, PARTIAL, DEPENDENCY-HELD**  
Trace base: `9ea919fe9b53ab3ae37e085ed462febaa8ad76f8`

This read-only pre-stage was stopped before Families 1 and 2 merged. It is not
an `integ06_1` report and contains no migration verdict. No save was synthesized,
no harness/product/test file was changed, and no runtime or expensive gate ran.

## Loadable historical fixtures found

| Artifact | Provenance | What it genuinely establishes | Gap |
| --- | --- | --- | --- |
| `scripts/tests/fixtures/run_state_0_3_0_save.json` | Added by `e364e485efa3fe21c4c8d828e8799a620dd7b5e9` on 2026-07-03 for save/load interruption compatibility; envelope identifies schema `beat_the_house.foundation_run`, version 1, slot `sb3_030_compat`. | A committed historical compatibility input with explicit legacy/unknown fields. | It is 0.3.0-era, not the required genuine mid-0.5 state. |
| `scripts/tests/fixtures/run_state_0_3_3_save.json` | Added by `502b008fea81b49198614fef57f9ff7bb674141f` on 2026-07-07 as a v0.3.3 compatibility review fixture; envelope identifies schema `beat_the_house.foundation_run`, version 1, slot `sb3_033_compat`. | A committed historical compatibility input covering later pre-0.5 fields. | It is 0.3.3-era, not the required genuine mid-0.5 state. |

## Existing artifacts that are not migration inputs

| Artifact | Why it must not be represented as a genuine player save |
| --- | --- |
| `scripts/tests/fixtures/punchline_l2_pre_rework_baseline.json` | Canonical environment/L2 baseline, added by `3c694d6f956288d321a2633b47385cdb820d4c45`; it has no foundation-run save envelope. |
| `scripts/tests/fixtures/crew06_5_ignored_run_baseline.json` | Generated checkpoint/hash golden repeatedly refreshed through `2425bba5eab6678b66775401d94f6da851270bbd`; it records hashes and trace checkpoints, not a loadable player-save envelope. |
| `docs/plans/evidence/**/user_data/**/saves/*.json` | Outputs captured by validation harness runs. Their provenance is generated test state, so each must be assessed separately and may not be relabeled as a historical 0.5 or owner-build save. |

## Genuine-state gaps identified before parking

No committed fixture found in the initial inventory is identified by provenance
as a genuine 0.5-release or mid-0.6 owner-build save. The future matrix still
needs provenance-backed captures for every prompt category: each environment
archetype, every game mid-state, each lender rung, tutorial, scratch-ticket
partial progress, Grand Casino invited/uninvited states, every victory threshold,
and pre-depth mid-0.6 snapshots. Plausible hand-authored substitutes are forbidden.

## Migration promises already routed for the future matrix

The umbrella prompt explicitly requires cells for:

- pre-0.6 `small_underground_casino` to the three-layer Punchline model
  (`docs/todone/env06_4_punchline_rework_prompt.md:86-97`);
- in-flight old-board delivery re-pointing to real travel nodes
  (`docs/todone/rework06_1_map_delivery_prompt.md:156-189`);
- coin-pusher compact persistence, legacy migration, and all V3 successor formats
  (`docs/todo/pusher06_1_solver_core_prompt.md:70,162` and the
  `pusherv3_2` through `pusherv3_10` prompt family);
- scenario snapshot schema migrations
  (`docs/todo/env06_6_dynamic_scenario_runtime_prompt.md:88,174`).

This list is only the umbrella's explicit minimum. The promised-migration scan
across every board/work-log row was interrupted and must be completed before the
real matrix is considered exhaustive.

## Draft commands after dependencies land

Commands are intentionally templates until the final harness exists; recording
fake runnable commands would be misleading.

```powershell
# Inventory/provenance check (read-only)
git log --follow --format='%H|%ad|%an|%s' --date=iso -- <fixture-path>

# Future opt-in migration matrix; replace with the committed harness command.
pwsh -File <integ06_1-opt-in-runner.ps1> -Mode Migration -FixtureManifest <manifest>

# Future round-trip and native/Web comparison on the exact integrated head.
pwsh -File <integ06_1-opt-in-runner.ps1> -Mode RoundTrip -FixtureManifest <manifest>
pwsh -File <integ06_1-opt-in-runner.ps1> -Mode Parity -SeedManifest <seeds>
```

Next action after Families 1 and 2 merge: complete the board/work-log migration
promise ledger, obtain provenance-backed missing saves from real historical
builds, then implement the opt-in harness. Until then `integ06_1` remains TODO.
