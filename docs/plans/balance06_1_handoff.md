# balance06_1 partial handoff

## Repository state

- Worktree: `D:\Projects\Beat-The-House-worktrees\cross-balance`
- Branch: `codex/cross-balance`
- Exact claimed base: `3d4a41da0b2caf72324c29bcc2a3a8b9314ce3ea`
- Exact harness commit: `e74a57cebbda198cda9c1a95ada1c2081f1bb7c6`
- Final branch head: the commit containing this handoff, report, and archived
  evidence. The collecting manager should resolve `codex/cross-balance`; the
  final task response records its full SHA after the commit exists.
- No merge, push, board edit, product-data change, tuning change, or suite-defect
  patch was made.

Collection note: the clean semantic landing branch starts at current main and
preserves the two logical source commits without merging or cherry-picking the
entangled source branch. The harness blobs are source-identical. The second
logical commit retains this handoff, report, checksum manifest, and smaller
validation evidence while deliberately omitting the three large raw `n=1`
measurement JSONs as recorded in the report's landing evidence disposition.

Immediately before the documentation/evidence commit, `git status --short`
contained only the intended untracked report and evidence tree. The final handoff
requires a clean `git status --short`; that check is recorded in the final task
response.

## Commits

1. `3d4a41da0b2caf72324c29bcc2a3a8b9314ce3ea` — existing Wave 1 row claim; this
   is the handoff base, not implementation work.
2. `e74a57cebbda198cda9c1a95ada1c2081f1bb7c6` — adds the opt-in seeded economy
   audit prototype and its PowerShell launcher, unchanged from the measured
   precommit worktree blobs.
3. The branch-tip handoff commit — tracks 61 of the 65 artifacts named by the
   source manifest and adds the honest partial report, evidence provenance, and
   this status map. The four `foundation_systems.systems_*.godot.log` files
   remained ignored and source-worktree-only.

## Contract requirement map

| Requirement | Status | Exact handoff state |
| --- | --- | --- |
| Enumerate sources, costs, pressures, gates, caps, and rate limits | PARTIAL | A grouped human-readable model and machine-readable source register exist. They have not received independent completeness review. |
| Identify shared versus independent constraints | PARTIAL | The report identifies the shared bankroll/action/heat/travel/terminal constraints and the principal independent local brakes. No multi-seed evidence tests their combined effect. |
| Runnable, seeded, opt-in harness outside default suites | DONE as prototype | `tools/cross_economy_audit.gd` and `.ps1` are committed at `e74a57ce...`; archived import/load checks passed. The prototype still lacks full-run evidence. |
| Pure gambler, Crew maximizer, Numbers specialist, pusher grinder, cheater, heist rusher, mixed opportunist, and Crew-ignoring control | PARTIAL | All eight policies instantiate and executed one 208-action seed plus one eight-action smoke seed. Every 208-action row was censored active; this does not prove complete-run policy quality. |
| Enough seeds to report distributions and justify sample count | NOT STARTED | Only `n=1` per playstyle exists. The planned 64/style run was not started. |
| Bankroll curves, debt thresholds, victory timing, action consumption, heat, failure causes, and pressure-vs-choice endings | PARTIAL | The harness emits these fields and raw ledgers, but the archived point samples contain no observed terminal or victory and cannot support distribution claims. |
| Meaningful 0.5 comparison | PARTIAL | The report identifies the landed structural two-seed control fixture. No historical 0.5 numeric distribution was run or inferred. |
| Ranked findings | NOT STARTED | No economy finding is asserted from the censored point samples. |
| Ranked proposals with predicted effects and risks | NOT STARTED | No evidence-backed findings exist, so no proposals were invented. |
| Persisted coin-pusher EV run | NOT STARTED | The planned 600k-drop command is documented; it was not run. |
| Project validation and relevant suites | PARTIAL | Project validation/import/script-load and the four-shard systems suite passed in archived runs. Contracts hit an unrelated known test-double defect and timed out; no retry or patch was attempted after handoff direction. |
| Do not tune product values | DONE | Only tools and documentation/evidence are committed. |
| Report under `docs/plans/` | DONE as partial handoff | The report follows the required section structure and explicitly marks incomplete sections. |

## Commands, seeds, and builds

The exact measurement commands are in
`docs/plans/balance06_1_cross_system_economy_audit.md` and
`docs/plans/evidence/balance06_1/README.md`. In summary:

- Determinism: prefix `BALANCE06-1-DETERMINISM`, one seed per each of eight
  styles, max 208 actions, embedded build label `WORKTREE-PRECOMMIT`.
- Smoke: prefix `BALANCE06-1-SMOKE`, one seed per style, max eight actions,
  embedded build label `STATIC-SMOKE`.
- Actual executable tree for both: tracked base `3d4a41da...` plus the two exact
  harness blobs frozen by `e74a57ce...`.
- The two determinism outputs are byte-identical at SHA-256
  `f7cf3730922226710244dc49e985a98aaa8d5824f24f78d4b6851252d3cec897`.
- No number in the report comes from an unrecorded estimate. The statistical
  target of 64 seeds/style remains a planned sample, not a measured result.

## What the next manager should not rediscover

- The contracts red is not this row. Archived stderr proves
  `BlackjackGame._draw_count_challenge` calls missing method
  `surface_add_exact_hover_hit` at `scripts/games/blackjack.gd:2939` on the
  `SurfaceHarness` test double defined at
  `scripts/tests/foundation/check_core_content.gd:139`. Ownership is `fix06_4`
  on `codex/cross-remediation`.
- The contracts attempt spent 300.047 seconds before timeout. Do not rerun it on
  this branch until the owning fix lands.
- The passing systems wrapper spent 41.382 seconds in its four parallel shards;
  its preceding validation/import/load stages took 48.167s, 17.753s, and
  27.258s. The second wrapper's corresponding stages took 49.470s, 17.979s, and
  24.907s.
- The harness is deliberately opt-in, inherits ordinary production drivers from
  `endgame_metrics_probe.gd`, and adds explicit specialist state machines. Its
  source register is useful even before full simulation.
- One seed/style at 208 actions produced eight active censored rows. Increasing
  seed count without first deciding how complete-run termination should behave
  would multiply cost without answering pressure-versus-choice questions.
- The pusher policy did not reach a natural pusher on its sole full-length seed;
  no pusher EV conclusion exists.

## Artifact map

- Immutable source head `1c0dec3b...` and the preserved source-worktree
  `.tmp/balance06_1/` — smoke, determinism first, and byte-identical determinism
  repeat JSON. The clean landing omits these three large supersedable blobs.
- `docs/plans/evidence/balance06_1/validation/foundation_systems_retry1/` — all
  23 tracked root reports/logs plus 25 isolated user-data files from the passing
  systems run (48 tracked files total). The four manifest-named
  `foundation_systems.systems_activation.godot.log`,
  `foundation_systems.systems_core.godot.log`,
  `foundation_systems.systems_events_saves.godot.log`, and
  `foundation_systems.systems_world_release.godot.log` files remained ignored
  and source-worktree-only.
- `docs/plans/evidence/balance06_1/validation/foundation_contracts_1/` — all ten
  files from the blocked contracts run, including the diagnostic stderr.
- `docs/plans/evidence/balance06_1/SHA256SUMS.txt` — preserves hashes for the
  complete 65-file `.tmp` source artifact set, including omitted raw
  measurements. Eight JSON checkout byte streams differ from those raw hashes
  because the source commit itself applied Git text normalization; the clean
  landing preserves the source Git blobs exactly and the evidence README names
  that inherited boundary.
- `.tmp/balance06_1/` in the retained source worktree — the original ignored
  files are intentionally preserved in place. No owner/source artifact was
  deleted or rewritten during collection.

## Honest account of the elapsed work

Across the roughly thirteen-hour wall-clock span after the claim, no commit was
made until this handoff. The time went into reading and grouping the broad
economy surface, building a 1,311-line harness/launcher prototype, debugging
specialist paths and deterministic output, running smoke/determinism probes, and
then spending too much time on foundation validation retries. The systems run
did provide useful coverage, and the contracts stderr isolated a real defect,
but repeated suite work did not advance the required multi-seed economy result.

The better sequence would have been: commit the opt-in prototype as soon as it
parsed; archive the first smoke output immediately; run one deterministic seed
per style; inspect censoring before scaling; and stop at the first clearly
external contracts defect. That would have made the work recoverable hours
earlier and preserved the remaining time for complete-run policy design or an
honest early partial handoff.
