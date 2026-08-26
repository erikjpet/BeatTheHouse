# Cross-Cutting Completion Program Ledger

This is the live integration ledger required by `cross06_0`. It records program
state on `codex/cross-completion-integration`; task branches remain the source of
their own detailed handoffs and test evidence.

## Immutable preflight

- Repository: `D:\Projects\Beat-The-House`
- Starting branch: `main`
- Starting HEAD: `9976e24f59614f6142856e43c2a31dae21aa8fcc`
- Upstream at preflight: `origin/main`; ahead `0`, behind `9`
- Integration worktree: `D:\Projects\Beat-The-House-worktrees\cross-completion-integration`
- Integration bootstrap: `64d387e9d8f882651ae84b8629273ceaf2b8247a`
- Available concurrency: four total agents, including the primary integrator
- `AGENTS.md`: none found in the repository
- User state: fifteen tracked paths were modified and the untracked paths shown
  by the preflight `git status --short --untracked-files=all` snapshot belonged
  to the user. Only the exact eleven required contracts were copied into the
  isolated integration worktree. No other user path may be copied, staged, or
  modified.

## Validation surface and practical runtime

| Gate | Practical runtime/evidence at preflight |
| --- | --- |
| `tools/validate_project.ps1` | First clean probe exceeded a 120-second wrapper window; a direct quiet rerun passed with exit 0 in 75.3 seconds. |
| `tools/check_godot.ps1 -RequireGodot -FoundationSuite <name>` | Supported names: smoke, contracts, games, systems, ui, slot/slots, slot_acceptance, blackjack, roulette, baccarat, craps, video_poker, bar_dice, crew_poker, pull_tabs, scratch_tickets, coin_pusher, audit, all/full. |
| Foundation recorded baselines | all 153.768s; systems 29.141s; UI compile 83.234s; contracts 153.594s; games 146.950s; slot 25.535s; slot acceptance 638.945s; audit 646.713s; focused game suites generally 11-86s where recorded. |
| Extended gates | 10-seed determinism, native/Web parity, performance with mandatory idle-liveness counter-gate, visual QA, accessibility, save/migration, soak, and row-specific harnesses. |

## Rows

| Row | Branch | Worktree | Owner | File ownership | Base commit | Dependencies | Status | Reviewer | Findings | Test evidence | Accepted head | Merge commit | Cleanup |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `meta06_1` | `codex/cross-meta` | `D:\Projects\Beat-The-House-worktrees\cross-meta` | `/root/wave1_meta06_1` | Career/run-report view models and screens; profile stats path; focused tests and documented captures | `3d4a41da` | None | IN_PROGRESS | TBD, non-author | None reported | Pending handoff | - | - | Retained |
| `balance06_1` | `codex/cross-balance` | `D:\Projects\Beat-The-House-worktrees\cross-balance` | `/root/wave1_balance06_1` | Opt-in economy harness, audit report, harness tests only; no product/tuning data | `3d4a41da` | None | IN_PROGRESS | TBD, non-author | Pending audit | Pending handoff | - | - | Retained |
| `board06_1` | `codex/cross-board` | `D:\Projects\Beat-The-House-worktrees\cross-board` | `/root` | Board and companion logs; verified ignored orphan UIDs only | `3d4a41da` | Quiet-window coordination | COORDINATING | TBD, non-author | None reported | Pending | - | - | Retained |
| `polish06_0` | `codex/cross-polish` | `D:\Projects\Beat-The-House-worktrees\cross-polish` | `/root/wave1_polish06_0` | Parked program document and newly defined parked prompts/templates; no execution | `3d4a41da` | None | IN_REVIEW; outputs PARKED | `/root/review_polish06_0` | Self-review reports no known logic gap; four integration assumptions recorded | Clean exact-head self-review; validation PASS 86.6s; diff check PASS; independent rerun pending | `be14c1ce` (candidate) | - | Retained |
| `pusherv3_11` | `codex/cross-pusher-audit` | Not created | Unassigned independent auditor | Closure audit report/evidence only | TBD | `pusherv3_10` | HELD | TBD | - | - | - | - | Not created |
| `audio06_1` | `codex/cross-audio` | Not created | Unassigned | Surface SFX manifest/assets/shared path/tests | TBD | Families 1 and 2 rituals | HELD | TBD | - | - | - | - | Not created |
| `integ06_1` | `codex/cross-integ` | Not created | Unassigned auditor | Integration harness/report/tests only | TBD | Families 1 and 2 merged | HELD | TBD | - | - | - | - | Not created |
| `perf06_1` | `codex/cross-perf` | Not created | Unassigned auditor | Performance harness/report/gates and evidence-named behavior-preserving optimization only | TBD | Families 1 and 2 merged | HELD | TBD | - | - | - | - | Not created |
| `teach06_2` | `codex/cross-teach` | Not created | Unassigned | Tutorial lessons, coach surfaces, focused tests/evidence | TBD | `depth06_1`, `game06_8`, `world06_7` | HELD | TBD | - | - | - | - | Not created |
| `playtest06_2` | `codex/cross-playtest` | Not created | Unassigned | Playtest prompt refresh, verified seed list, script and capture format | TBD | `integ06_1`, `perf06_1`, preceding audit findings | HELD/LAST | TBD | - | - | - | - | Not created |

## Coordination log

- 2026-08-25: The only other active Codex task currently editing the board was
  identified as the `pusherv3_10` implementer. A quiet-window request was sent;
  structural `board06_1` edits remain held pending confirmation. No live Family 1
  or Family 2 integrator task was visible. The existing depth-program integration
  and worker worktrees were clean and were not touched.
- 2026-08-25: Later waves remain held until their exact dependency heads land on
  this integration branch.
- 2026-08-25: Wave 1 claim state landed at `3d4a41da`; every Wave 1 task
  worktree was fast-forwarded to that exact clean head before implementation.
- 2026-08-25: The `board06_1` pre-edit audit found eleven ignored `.gd.uid`
  files whose sibling source paths are absent. Removal remains held for the
  board quiet window and independent exact-path review.
