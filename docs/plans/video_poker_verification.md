# Video Poker Verification

Date: 2026-07-31

This is an independent verify-and-finish pass against
`docs/todone/video_poker_complete_rebuild_prompt.md` and
`docs/plans/video_poker_reference.md`. The pass used a live 1280x720 root
viewport, real surface pointer events, a 960x600 touch run, renderer-command
inspection, deterministic simulations, and fresh screenshots under
`.tmp/vp_verify/`. Prior completion claims and commit messages were not
accepted as evidence.

## Verification table

| # | Requirement | Status | Concrete proof |
|---:|---|---|---|
| 1 | Multi-hand display distinctness | PASS | `.tmp/vp_verify/triple_double_bonus_04_result.png` visibly shows three separately framed hands with different cards and different outcomes. `.tmp/vp_verify/proof_report.json` records three distinct renderer signatures and three result rows. `foundation_video_poker` also passes `_check_video_poker_multi_hand` and `_check_video_poker_multi_hand_many_seeds`. |
| 2 | Betting works | PASS | `_check_video_poker_bet_controls` drives the 1-5 coin ladder, Bet -, and Bet Max, while asserting wager and active paytable column. Fresh Bet Max captures are `.tmp/vp_verify/jacks_or_better_02_bet_max.png`, `.tmp/vp_verify/double_deuces_02_bet_max.png`, and `.tmp/vp_verify/triple_double_bonus_02_bet_max.png`; the proof report records 5 coins per hand and total wagers 5/10/15. |
| 3 | Clarity: how to win | PASS | The live proof drives DEAL, individual HOLD controls, and DRAW. `.tmp/vp_verify/triple_double_bonus_03_hold_guidance.png` shows the persistent five-step path and held-card lock. `.tmp/vp_verify/triple_double_bonus_04_result.png` names `WIN: JACKS OR BETTER`, reports `PAID 5 CREDITS`, highlights the Jacks-or-Better paytable row, and labels each hand's result. |
| 4 | Art slot parity | PASS | Fresh side-by-side captures compare the full-width, machine-specific cabinets with the live slot surface: `.tmp/vp_verify/jacks_or_better_slot_parity.png`, `.tmp/vp_verify/double_deuces_slot_parity.png`, and `.tmp/vp_verify/triple_double_bonus_slot_parity.png`. Each video-poker cabinet has distinct color/material treatment, title art, hand layout, integrated paytable, machine buttons, meters, and cabinet edge lighting at the same gameplay scale as the slot. |
| 5 | In-draw Holdout cheat | FIXED | Verification found two defects: the exact outcome feedback existed in data but was never rendered, and the target card was recomputed after the draw so the named card could differ from the inserted card. The settled renderer now draws the blunt result strip, and the challenge's committed target card is reserved from the draw pool and inserted into its committed slot. `_check_video_poker_cheat` now asserts the exact named card landed, the result names the resulting hand, and the renderer drew both. `.tmp/vp_verify/jacks_or_better_holdout_result.png` visibly says `SWAPPED IN 9 OF SPADES • RESULT: NO PAY` and shows the 9 of Spades in the final hand. The same test retains seeded timing, grade-to-heat/evidence, item/alcohol modifiers, serialization, and one-beat reduce-motion coverage. |
| 6 | Evaluation, paytables, and RTP | PASS | `foundation_video_poker` passes `_check_video_poker_evaluation`, `_check_video_poker_paytable_variants`, `_check_video_poker_royal_bonus`, and `_check_video_poker_rtp_bands`, including Deuces Wild and DDB kicker rows. Fresh `tools/video_poker_rtp_audit.ps1` passed all locked-paytable assertions and declared sample bands; results are below. |
| 7 | Multi-hand independence | PASS | `_check_video_poker_multi_hand` proves independent 52-card decks minus held cards, identical held cards, per-hand results, correct gross sum, and distinct renderer state. `_check_video_poker_multi_hand_many_seeds` repeats the proof across 36 two/three-hand seeds and rejects copied draws. The fresh three-hand screenshot and proof report independently verify the display. |
| 8 | Determinism and save/load | PASS | `foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` produced identical 320-checkpoint runs with combined hash `4255336226`. `_check_video_poker_save_load_mid_hand` serializes/restores the dealt hand, holds, wager, and active paytable column, then completes a valid draw. `_check_video_poker_cheat` separately verifies deterministic challenge construction and mid-challenge serialization. |
| 9 | Double-up | PASS | `_check_video_poker_double_up` drives all four choices, deterministic replay, bankroll deltas, win/loss sampling, and fair-rate bounds. The live pointer proof confirms all four targets are visible and the first press resolves. Captures: `.tmp/vp_verify/jacks_or_better_double_up_open.png` and `.tmp/vp_verify/jacks_or_better_double_up_result.png`. |
| 10 | Controls | PASS | `_check_video_poker_surface_contract` and `_check_video_poker_bet_controls` cover DEAL, DRAW, five HOLD targets, Bet +/-, Bet Max, denomination, Holdout, and direct-resolution contracts. The live proof physically drives every hold, Deal/Draw, Bet Max, and all four double-up picks by mouse at 1280x720 and by touch at 960x600. Touch result capture: `.tmp/vp_verify/jacks_or_better_small_screen_touch_result.png`. `foundation_mouse_playtest.ps1 -RequireGodot` also passed with 63 recorded input events. |
| 11 | Casino feel and performance | PASS | Live walkthrough confirmed cards reveal in sequence, held cards remain visibly locked, replacement cards reveal after DRAW, a winning row/result flash appears at settlement, Holdout has a centered two-beat timing sequence, and double-up presents dealer-versus-four-card tension. Performance passed: draw resolve average `1.100 ms`, p95 `1.084 ms`, max `3.050 ms` against `2.5/4.5/5.0 ms` budgets; idle renderer p95 `1.167 ms` and 49 liveness redraws against floor 8. No full snapshot calls occurred. |
| 12 | Three cabinets | PASS | Fresh captures prove Jacks or Better / 1 hand (`.tmp/vp_verify/jacks_or_better_04_result.png`), Double Deuces / Deuces Wild / 2 hands (`.tmp/vp_verify/double_deuces_04_result.png`), and Triple Double Bonus / DDB / 3 hands (`.tmp/vp_verify/triple_double_bonus_04_result.png`). The proof report records hand counts 1/2/3 and max-coin wagers 5/10/15. |

## RTP audit

The audit used 10,000 rounds per cabinet and the deterministic concise-hold
policy. These sampled values are regression evidence within the declared
bands, not claims of theoretical perfect-play return.

| Cabinet | Hands | Locked schedule | Declared optimal RTP | Declared sample band | Sampled RTP | Result |
|---|---:|---|---:|---:|---:|---|
| Jacks or Better | 1 | 9/6 | 0.9954 | 0.88-1.12 | 0.9665 | PASS |
| Double Deuces | 2 | Illinois 25/15/9/4/4/3 | 0.9891 | 0.78-1.12 | 0.8576 | PASS |
| Triple Double Bonus | 3 | 10/6 DDB | 1.0007 | 0.80-1.18 | 0.9344 | PASS |

## Gate record

| Gate | Result | Evidence |
|---|---|---|
| `tools/validate_project.ps1` | PASS | Foundation architecture validation passed. |
| `-FoundationSuite games` | PASS | `.tmp/test_reports/20260731_002121_smoke/summary.json` |
| `-FoundationSuite ui` | PASS | `.tmp/test_reports/20260731_002352_smoke/summary.json` |
| `-FoundationSuite systems` | PASS | `.tmp/test_reports/20260731_002722_smoke/summary.json` |
| `-FoundationSuite video_poker` | PASS | `.tmp/test_reports/20260731_002849_smoke/summary.json` |
| `foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` | PASS | 10 seeds, 320 checkpoints, identical hash `4255336226` |
| `foundation_performance_probe.ps1 -RequireGodot` | PASS | 62 observations / 8 seeds; video-poker numbers recorded above |
| `foundation_visual_qa.ps1` | PASS | Full visual QA completed without a failure exit. |
| `video_poker_rtp_audit.ps1` | PASS | `.tmp/video_poker/rtp_audit.json`; all three samples within declared bands |
| `foundation_mouse_playtest.ps1 -RequireGodot` | PASS | 63 input events; victory and failure/recovery paths passed |

## Manual acceptance

At 1280x720, each cabinet uses the available surface like a real machine:
the paytable remains readable, the controls sit in an integrated button deck,
and the hand arrangement changes deliberately from one large hand, to two
side-by-side hands, to a two-over-one three-hand layout. The deal/hold/draw
rhythm is immediately legible; card motion is short enough to feel responsive
but long enough to read; held cards stay visually anchored; settlement names
the winning hand and lights the matching pay row. Double-up creates a clear,
compact tension beat. The Holdout interaction now ends with literal,
unambiguous truth about the card inserted and the evaluated result. Mouse and
small-screen touch runs both completed without missed controls, overlap, or a
second-click requirement.
