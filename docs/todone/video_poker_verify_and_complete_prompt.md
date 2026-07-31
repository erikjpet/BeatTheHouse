# Agent Prompt — Video Poker: VERIFY Everything Is Done Per Spec (and Finish What Isn't)

Copy everything below this line into the worker agent. Use a capable model.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. The video poker rebuild has been merged to `main`
(`scripts/games/video_poker.gd` + `scripts/games/video_poker_renderer.gd`).
Your job: INDEPENDENTLY VERIFY that EVERY requirement and feature in the spec
is actually met, with concrete PROOF — and where any is NOT met, FINISH
implementing it until you can prove it. Do not trust prior claims or commit
messages. Do not conclude "done" on assumption. Conclude done ONLY when every
item below is proven with the stated evidence.

Binding spec: `docs/todone/video_poker_complete_rebuild_prompt.md` and
`docs/plans/video_poker_reference.md`. A prior code review found the mechanics
largely implemented and TESTED (multi-hand independence has a test:
`scripts/tests/foundation/check_table_games.gd` `_check_video_poker_multi_hand`),
but TWO things were NOT confirmable without running the game: the multi-hand
DISPLAY actually showing distinct hands on screen, and the ART being
slot-parity. Verify these especially — capture them.

## Rules of this pass

- This is VERIFY-AND-FINISH, not a rebuild: do NOT churn code that already
  works and is proven. Only change what a verification step shows is actually
  broken or unproven, then prove it.
- Every item needs EVIDENCE: a screenshot capture (under `.tmp/vp_verify/`)
  for visual items, a driven test/assertion for logic items. "Looks right" or
  "should work" is not proof.
- Produce `docs/plans/video_poker_verification.md`: one row per requirement →
  PASS (with the capture path / test name) or FIXED (what was wrong, what you
  changed, and the new proof). No row may be blank or hand-waved.

## The verification checklist (prove EACH; finish any that fails)

1. **Multi-hand DISPLAY distinctness (the headline).** Drive a 3-hand Triple
   Double Bonus cabinet through a deal+draw and CAPTURE the screen: it must
   show THREE visibly distinct hands (different cards and different results),
   not one hand mirrored. If the render shows identical hands, FIX the renderer
   (`video_poker_renderer.gd`) until three different hands display. PROOF: the
   capture.
2. **Betting works.** Interaction test drives coins-per-hand 1→5 and Bet Max;
   assert the total wager and the highlighted paytable column update; never
   stuck at 1. PROOF: test + a capture at bet 5.
3. **Clarity — how to win.** A first-timer can tell the next step
   (DEAL → hold → DRAW) and see WHY they won/lost (winning hand named, paytable
   row flashes). PROOF: a driven walkthrough + capture of a win with the row
   highlighted.
4. **Art slot-parity.** CAPTURE each of the three cabinets and place them
   beside a slot-machine capture; each must read as equally professional and
   be visually distinct per cabinet. If any cabinet is weak vs the slot bar
   (`scripts/games/slots/slot_renderer.gd`), improve it. PROOF: side-by-side
   captures.
5. **Cheat.** The in-draw holdout triggers, uses a clean skill input, and gives
   BLUNT feedback naming the exact swapped card and resulting hand; reduce-
   motion fallback works; economy preserved (seeded ideal card, quality→heat/
   evidence). PROOF: capture of the cheat resolving with the blunt result beat.
6. **Hand evaluation + paytables + RTP.** Correct per cabinet incl. Deuces
   wilds and DDB four-of-a-kind kicker bonuses; per-cabinet mass-sim RTP within
   declared bands. PROOF: run `tools\video_poker_rtp_audit.ps1` and report the
   table.
7. **Multi-hand independence (data).** The N hands draw from independent decks
   with distinct per-hand seeds. PROOF: `_check_video_poker_multi_hand` (and
   any related test) passes; cite it.
8. **Determinism.** Same seed + same holds → identical hands/payouts across
   replays and save/load mid-hand. PROOF: determinism probe + a save/load test.
9. **Double-up.** The gamble works after a win (double-or-nothing, cap). PROOF:
   a driven double-up test/capture.
10. **Controls.** DEAL, DRAW, each HOLD toggle, bet +/-, Bet Max, double-up
    picks all work by mouse AND touch at 1280×720 and small-screen. PROOF:
    interaction tests.
11. **Feel.** Card flips/slides, held-lock, draw reveal, payout flash scaled to
    the win, double-up tension; smooth, within the performance-probe budget.
    PROOF: perf probe within budget + a short manual feel note.
12. **Three cabinets.** Jacks or Better/1, Double Deuces (Deuces Wild)/2,
    Triple Double Bonus (DDB)/3 all present and correct. PROOF: captures of all
    three.

## Hard rules

- Determinism, zero-copy per-frame, idle-animation liveness untouched; keep the
  module's external contract; never weaken a test/budget to pass. Style: tabs,
  typed GDScript, sparse comments; captures/reports under `.tmp/` (the
  verification doc goes in `docs/plans/`). Suite timeout = max(300s, ceil(
  recorded baseline × 1.5)). Never revert or stage unrelated user-owned
  uncommitted work.
- Work on `main`. If another agent is active on the tree, use an isolated
  worktree branch and merge back when green.

## Gates (all must pass)

- `tools\validate_project.ps1`
- `-FoundationSuite games`, `ui`, `systems`, and any video-poker suite
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- `tools\foundation_visual_qa.ps1`
- `tools\video_poker_rtp_audit.ps1`
- `tools\foundation_mouse_playtest.ps1` (strict single run)

## On completion

Conclude COMPLETE only when ALL 12 checklist items are PROVEN (every row of
`video_poker_verification.md` is PASS or FIXED with evidence) AND all gates
pass:

1. Commit any fixes in logical units.
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, the
   verification table with proof paths, RTP table, gate results), and stage
   the move.
3. PUSH to the remote.
4. Report the full verification table (12 items, each PASS/FIXED with its
   proof), the RTP table, and a plain verdict: "VIDEO POKER COMPLETE PER SPEC —
   all 12 proven" or the exact list of what remained unmet.

If any checklist item cannot be proven or a gate cannot pass, do NOT declare
complete: keep implementing until it can, or stop at the last green commit and
report exactly what is unproven and why.

---

## Execution record

Date: 2026-07-31

Commits:

- `53240c75` - fixed and proved the exact Holdout result beat.
- `269383df` - recorded the independent 12-requirement verification.
- Archive commit: the commit containing this execution record.

Independent verification result:

| # | Requirement | Result | Proof |
|---:|---|---|---|
| 1 | Multi-hand display distinctness | PASS | `.tmp/vp_verify/triple_double_bonus_04_result.png`; three distinct renderer signatures in `proof_report.json` |
| 2 | Betting 1-5 and Bet Max | PASS | `_check_video_poker_bet_controls`; three `*_02_bet_max.png` captures |
| 3 | Deal/hold/draw and win clarity | PASS | `triple_double_bonus_03_hold_guidance.png` and `triple_double_bonus_04_result.png` |
| 4 | Slot-parity cabinet art | PASS | Three `.tmp/vp_verify/*_slot_parity.png` comparisons |
| 5 | In-draw Holdout | FIXED | Exact committed card now lands and the renderer names it plus the resulting hand; `jacks_or_better_holdout_result.png` |
| 6 | Evaluation, paytables, RTP | PASS | Evaluation/paytable tests and fresh 10,000-round RTP audit |
| 7 | Independent multi-hand decks | PASS | `_check_video_poker_multi_hand` and `_check_video_poker_multi_hand_many_seeds` |
| 8 | Determinism and save/load | PASS | 10 seeds / 320 checkpoints / hash `4255336226`; `_check_video_poker_save_load_mid_hand` |
| 9 | Double-up | PASS | `_check_video_poker_double_up`; double-up open/result captures |
| 10 | Mouse and touch controls | PASS | Live 1280x720 mouse and 960x600 touch proof; strict mouse playtest |
| 11 | Feel and performance | PASS | Draw avg/p95/max `1.100/1.084/3.050 ms`; idle p95 `1.167 ms`, liveness 49/8 |
| 12 | Three cabinets | PASS | Fresh Jacks or Better, Double Deuces, and Triple Double Bonus result captures |

RTP audit (10,000 rounds each):

| Cabinet | Hands | Sampled RTP | Declared band | Result |
|---|---:|---:|---:|---|
| Jacks or Better | 1 | 0.9665 | 0.88-1.12 | PASS |
| Double Deuces | 2 | 0.8576 | 0.78-1.12 | PASS |
| Triple Double Bonus | 3 | 0.9344 | 0.80-1.18 | PASS |

Gate results:

- `tools/validate_project.ps1`: PASS
- `-FoundationSuite games`: PASS (`20260731_002121_smoke`)
- `-FoundationSuite ui`: PASS (`20260731_002352_smoke`)
- `-FoundationSuite systems`: PASS (`20260731_002722_smoke`)
- `-FoundationSuite video_poker`: PASS (`20260731_002849_smoke`)
- Determinism probe, 10 seeds: PASS
- Performance probe: PASS
- Visual QA: PASS
- Video-poker RTP audit: PASS
- Strict mouse playtest: PASS (63 input events)

Deviations: none. The pass ran in an isolated `video-poker-verify` worktree
because unrelated user-owned work and another active Godot task occupied the
primary tree. No unrelated primary-tree file was staged, reformatted, or
reverted. Full detail is in `docs/plans/video_poker_verification.md`.
