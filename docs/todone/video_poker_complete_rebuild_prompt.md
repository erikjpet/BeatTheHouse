# Agent Prompt — Video Poker COMPLETE REBUILD (Play Like a Real Machine)

Copy everything below this line into the worker agent. This is a large,
ground-up rebuild; use a capable model. MULTIPLE prior attempts failed and
the current shipped implementation is unacceptable. FORGET the current
implementation entirely — this is a from-scratch rebuild, NOT a cleanup of
the broken foundation. Do not preserve the current rendering, control, or
cabinet code; replace it. Rebuild it correctly from the real machine outward.

## STRICT COMPLETION MANDATE (read first)

This work is NOT done until EVERY acceptance criterion below is PROVABLY met
and confirmed in the running game. Do not archive this prompt, do not declare
success, and do not stop early because "most" of it works. If a required
behavior is not yet real, keep working. The only acceptable stopping points
are: (a) everything proven and confirmed, or (b) a specific gate you genuinely
cannot pass — then stop, do NOT mark it done, and report exactly what is
unmet. "Reworked the art a bit" or "the loop mostly works" is a FAILURE.

## The exact failures this rebuild MUST fix (named, provable must-fixes — the
## owner is seeing ALL of these in the current build right now)

1. **Multiple hands display as identical.** On multi-hand cabinets the player
   sees the SAME hand 2-3 times — it looks like one hand copied. (The dealing
   may compute distinct hands, but the RENDERER draws them identically — fix
   the display, not just the logic.) The rebuilt game MUST deal AND DISPLAY N
   genuinely different hands. PROVE with a capture of a 3-hand cabinet showing
   three visibly distinct hands.
2. **Betting is stuck at 1 and cannot be changed.** The bet controls do not
   work. The rebuilt game MUST let the player change coins-per-hand (1-5) and
   Bet Max, with the total wager and paytable column updating live. PROVE with
   an interaction test that drives the bet to 5 and asserts the wager changes.
3. **It is unclear what the player must do to get a payout.** A first-timer
   MUST always know the next step (DEAL → hold cards → DRAW) and see clearly
   WHY they won or didn't (winning hand named, paytable row flashing). PROVE
   with a driven walkthrough and a clear-guidance capture.
4. **The art is bad and must be reworked.** Each cabinet MUST have art on par
   with the slot machines (below), not the current look. PROVE with slot-
   parity captures.

All four must be demonstrably fixed and CONFIRMED before this prompt is
complete.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (900×430 board, immediate-mode canvas, per-game modules,
data-driven, seeded RNG). `scripts/games/video_poker.gd` (~3,457 lines) is
broken and off-theme. Rebuild video poker so it plays, looks, and FEELS like
an actual casino video poker machine — professional art on par with the slot
machines, working intuitive controls, correct multi-hand play, real casino
smoothness/animation/excitement, and a cheat that makes sense.

## PART 0 — Deliverable: a real video poker audit (do this first, write it down)

Produce `docs/plans/video_poker_reference.md`: an audit of how a REAL video
poker machine plays — the exact order of operations, what makes it intuitive,
and how multi-hand ("Triple Play") machines work. Use it as the build spec.
The authoritative spec is below; your audit must reproduce and expand it, and
every item becomes a PROVABLE acceptance step (see QA).

### Real video poker — order of operations (the machine's rhythm)

1. **Bet.** Select coins-per-hand (1–5). Max bet (5 coins) is meaningful:
   the Royal Flush pays 800×/coin at 5 coins vs 250×/coin at 1–4 — a "Bet
   Max" button is standard and the paytable's 5-coin column is the headline.
2. **Deal.** Press DEAL. Five cards are dealt face-up from a freshly
   shuffled 52-card deck.
3. **Hold.** The player toggles HOLD on any of the five cards (0–5). Held
   cards show an unmistakable "HELD" marker. Default: nothing held.
4. **Draw.** Press DRAW (the SAME primary button, now relabeled DRAW). Every
   non-held card is replaced.
5. **Evaluate & pay.** The final hand is scored against the always-visible
   paytable; the winning row highlights/flashes; credits are paid.
6. **Double-up (optional, skippable).** Gamble the win: a dealer card shows,
   the player picks 1 of 4 face-down cards; higher doubles, tie pushes, lower
   forfeits. Repeatable to a cap.

### Multi-hand (the fix for "both hands are the same")

- ONE base hand of five cards is dealt.
- Holds chosen on the base hand apply to ALL hands.
- **Each of the N hands is completed from its OWN INDEPENDENT 52-card deck
  with the held cards removed** — so each hand's drawn cards are independent
  and the hands DIFFER. NEVER share one deck across hands; NEVER copy the base
  draw. This is the root bug: the current code draws all hands from one
  remaining deck.
- Bet = coins-per-hand × N hands. Each hand is scored and paid separately;
  total win is the sum.
- Layout: the base hand at the bottom, the N hands stacked above it; held
  cards mirrored across every hand.

### What makes it intuitive (bake these in)

- ONE primary action button that reads DEAL → DRAW and back — the whole
  rhythm lives on that button; nothing else competes for it.
- Tap a card to toggle HOLD; a bold HELD banner on held cards.
- The paytable is ALWAYS visible; the active bet column is highlighted; the
  winning combination flashes on a win.
- CREDITS / BET / WIN meters always visible and updating.
- A "Bet Max" shortcut.

## PART 1 — Core gameplay (correct, deterministic)

Rebuild the bet → deal → hold → draw → evaluate → pay → (double-up) loop
exactly as above, single-hand AND multi-hand with INDEPENDENT decks per hand.
Correct hand evaluation for each cabinet's paytable (including wilds and
kicker bonuses, below). Deterministic: same seed + same holds → identical
hands and payouts, reproducible across save/load mid-hand; multi-hand
independence must itself be deterministic (each hand's deck seeded distinctly
from the same run seed). No wall-clock in outcomes.

## PART 2 — Controls that actually work (and are tested)

The controls are currently broken — this is a first-class deliverable. The
DEAL/DRAW button, per-card HOLD toggles, bet +/- and Bet Max, and double-up
picks must all work by mouse AND touch, at 1280×720 and small-screen. Prove
each control works with an interaction test (drive the input, assert the
state change). A player must never be unable to hold a card, deal, or draw.

## PART 3 — Three cabinets, slot-machine-quality art

Three owner-locked cabinets (hand count in the identity):

| Cabinet | Base game | Hands | Identity |
| --- | --- | --- | --- |
| **Jacks or Better** | Jacks or Better (9/6) | 1 | retro-neon, the clean baseline |
| **Double Deuces** | Deuces Wild | 2 | electric/wild, two hands |
| **Triple Double Bonus** | Double Double Bonus | 3 | premium gold high-roller, three hands |

The ART QUALITY BAR is the slot machines: study
`scripts/games/slots/slot_renderer.gd` (~2,708 lines) and the Buffalo/Pinball
families (`slot_family_buffalo.gd`, `slot_family_pinball.gd`) and MATCH that
professionalism. Each cabinet is a complete authored machine, immediate-mode
in the game's pixel style: a full cabinet with integrated buttons (not
generic UI bolted on), a themed paytable display, CREDITS/BET/WIN meters, the
card area, and the multi-hand stack — UNIQUE per configuration, cohesive, and
professional. They should sit next to a slot machine and look like siblings
from the same casino.

Paytables (research-accurate, audited RTP per cabinet):
- **Jacks or Better 9/6:** Royal, Straight Flush, Four of a Kind, Full House
  (9), Flush (6), Straight, Three of a Kind, Two Pair, Jacks-or-Better.
- **Double Deuces (Deuces Wild):** 2s wild; Natural Royal, Four Deuces, Wild
  Royal, Five of a Kind, Straight Flush, Four of a Kind, Full House, Flush,
  Straight, Three of a Kind.
- **Triple Double Bonus:** the Double Double Bonus four-of-a-kind kicker
  bonuses (Four Aces w/ 2-4 kicker, Four 2-4 w/ A-4 kicker, etc.); high
  variance.

## PART 4 — The cheat, reworked to fit the machine

Forget the current cheat (it does not make sense and feels bad). Design a
cheat that FITS video poker naturally: the classic move is a HOLDOUT — during
the DRAW, the player skillfully palms a better card into the hand. Make it:
- **Integrated into the draw**, not a separate confusing minigame off to the
  side — it happens in the moment the cards flip.
- **A clean skill input** (timing/precision) that is intuitive and feels
  good to pull off; per-cabinet flavor on the same skill core.
- **Blunt feedback:** a loud, unmistakable beat states exactly what the cheat
  did — the card swapped in and the resulting hand ("You palmed the Ace —
  FOUR ACES").
- **Preserve the economy:** deterministic ideal card, quality→heat/evidence
  tiers, alcohol/contraband modifiers; same seed + inputs → same result.
- Reduce-motion: a generously-timed single input, still blunt about outcome.

## PART 5 — Real casino feel

Cards flip and slide with satisfying timing; the deal deals, held cards lock
visibly, the draw reveals with a beat, wins celebrate at a scale matched to
the payout (the winning paytable row flashes; big multi-hand wins are
exciting), double-up has tension. Use the game's SFX (following the
casino-smooth/realistic sound palette). Smooth at both screen sizes; zero-
copy per-frame; the surface animates from the module snapshot; add the video
poker surface to the performance probe with a budget.

## PROVABLE DELIVERABLES / QA (every real-VP behavior must be proven)

Report each as PASS with the evidence. NONE of these may be skipped or
hand-waved; an unproven item means the work is not done — keep going.
1. **Order of operations:** a driven test performs bet → deal → hold subset →
   draw → evaluate → pay, asserting each stage's state and that only non-held
   cards changed.
2. **Multi-hand independence AND DISPLAY (the headline failure):** with
   identical holds, the N hands' DRAWN cards differ (independent decks) —
   assert across many seeds they are not copies — AND the on-screen render
   shows N visibly distinct hands (fix the renderer that currently draws the
   same hand 2-3 times). Capture a 3-hand cabinet proving three different
   hands on screen.
2b. **Betting works:** an interaction test drives coins-per-hand 1→5 and Bet
   Max and asserts the total wager and paytable column update; the bet is
   never stuck at 1.
3. **Controls:** interaction tests prove DEAL, DRAW, each HOLD toggle, bet +/-,
   Bet Max, and double-up picks all work (state changes on input) at both
   sizes.
4. **Hand evaluation & paytables:** correctness per cabinet incl. Deuces wilds
   and DDB kicker bonuses; per-cabinet mass-sim RTP within declared bands
   (report the table).
5. **Determinism:** same seed + same holds → identical hands/payouts across
   replays and save/load mid-hand; cheat deterministic given inputs.
6. **Cheat:** triggers in-draw, resolves to the correct tier/heat/evidence,
   and the blunt beat names the swapped card + resulting hand; reduce-motion
   fallback works.
7. **Art parity:** side-by-side captures of each VP cabinet next to a slot
   machine showing comparable polish; each cabinet visually unique.
8. **Feel acceptance (manual, in words):** play all three cabinets — the
   rhythm is obvious, controls respond, multi-hand hands differ and pay
   separately, wins are exciting, the cheat feels good, and it reads as a
   real casino machine.

## Hard rules

- Determinism, zero-copy per-frame, idle-animation liveness untouched; tokens
  for chrome, per-cabinet art immediate-mode; web-safe. Style: tabs, typed
  GDScript, sparse comments; captures/RTP under `.tmp/`. Suite timeout =
  max(300s, ceil(recorded baseline × 1.5)).
- Rebuild cleanly: it is fine to replace the existing module wholesale, but
  keep its external contract (game id, surface-command hooks the host calls)
  so the rest of the game still drives it; update tests to match.
- Working tree may contain uncommitted user-owned work; never revert or stage
  it. Stage explicitly.

## Gates

- `tools\validate_project.ps1`
- `-FoundationSuite games`, `ui`, `systems`, and any video-poker suite
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- `tools\foundation_visual_qa.ps1`
- the video poker RTP audit (extend for the three cabinets)
- `tools\foundation_mouse_playtest.ps1` (strict single run)

## On completion

DO NOT COMPLETE until all four named must-fixes AND all provable deliverables
are met and CONFIRMED in the running game — including the manual feel/clarity
acceptance. If the multi-hand display still shows identical hands, if the bet
still can't change, if a new player can't tell how to win, or if the art
isn't slot-parity, the work is NOT done — keep working. Do not archive a
partial result.

Only after every gate passes AND every PROVABLE DELIVERABLE is proven and the
game plays like a real machine:

1. Commit in logical units (audit doc; core loop + multi-hand decks; controls;
   cabinets/art; cheat; feel/animation).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, the
   proof results for each deliverable, per-cabinet RTP, gate results), and
   stage the move.
3. PUSH to the remote.
4. Report: the audit summary, how multi-hand independence is now proven, the
   control-test results, per-cabinet art (with slot-parity captures), the
   cheat design, RTP table, feel acceptance, and gate results.

On an unfixable gate or an unproven deliverable, stop at the last green
commit, do NOT push, and report exactly what is not yet real.

---

## Execution record — 2026-07-30

Branch/worktree: `video-poker-rebuild` in `D:\Projects\Beat-The-House-video-poker-rebuild`.

Preflight/reconciliation:
- The primary checkout carried user-owned work and another task was active, so this rebuild stayed isolated.
- Coordination confirmed `origin/main` and the branch base were identical; no pull or mutation of the primary checkout was performed.
- Gate runs waited for zero Godot processes. The final live proof uses a real root viewport because headless/subviewport `frame_post_draw` does not complete in this Godot configuration.

Commits:
- `9e55d61d` — initial independent multi-hand draw foundation.
- `706b236e` — expanded the real-video-poker reference into the binding rebuild contract.
- `14bd731e` — replaced the renderer and control presentation, removed the dormant prior renderer, added strict interaction/display/performance/RTP/live proofs, and corrected gross WIN presentation.
- Archive commit: this execution-record commit.

Named must-fix proof:
- Multi-hand display: PASS. The live 1280×720 capture for Triple Double Bonus shows three visibly different hands. `proof_report.json` records three distinct rendered signatures and three result rows.
- Betting: PASS. Foundation tests drive coins-per-hand through 1, 2, 3, 4, and 5, verify a strictly increasing total wager, then verify Bet Max and the active paytable column. The live mouse and 960×600 touch walkthroughs both reach five coins.
- Payout clarity: PASS. The machine permanently shows `SET BET → DEAL → TAP CARDS TO HOLD → DRAW → AUTO PAY`; the primary control changes DEAL/DRAW, every result names each hand and pay, WIN reports gross paid credits, and the matching paytable row flashes.
- Slot-parity art: PASS. Fresh live side-by-side captures under `.tmp/video_poker/rebuild_proof/*_slot_parity.png` compare each full-screen authored VP cabinet with a live slot cabinet.

Provable deliverables:
- Order of operations: PASS. Tests and the live walkthrough drive Bet Max → Deal → Hold cards 1 and 3 → one-press Draw → per-hand evaluate/pay, then start and resolve Double Up.
- Independent decks: PASS. Each hand draws deterministically from its own 52-card deck minus held cards. Many-seed assertions reject copied hands; the live 2-play and 3-play captures record 2/2 and 3/3 distinct displayed signatures.
- Controls: PASS. Bet −, Bet +, Bet Max, Deal/Draw, all five Hold targets, Holdout, Double Up, and all four double-up picks have visible hit targets and state-change assertions. Mouse at 1280×720 and touch at 960×600 both pass; Draw and double-up picks resolve on the first press.
- Evaluation/paytables: PASS. Fixtures cover Jacks or Better, Deuces Wild natural/wild categories, and Double Double Bonus ace/low-card kicker bonuses; the RTP audit asserts the locked 9/6, Illinois Deuces, and 10/6 DDB schedules.
- Determinism/save compatibility: PASS. Ten-seed replay produced identical 320-checkpoint hashes (`2740974421`) and the suite covers mid-hand state normalization plus deterministic holdout inputs.
- Holdout cheat: PASS. It begins in the Draw phase, uses cabinet-themed timing/target beats on one shared skill core, preserves quality-to-heat/evidence and item/alcohol modifiers, and reports the exact swapped card and resulting hand. Reduce-motion uses one generous deterministic beat.
- Real casino feel: PASS. Deal/draw card-back reveals, locked HELD banners, active paytable columns, payout-row flash, tiered result emphasis, cabinet lamps, and tense double-up presentation are live; reduce-motion removes oscillation without removing feedback.
- Zero-copy/performance: PASS. The renderer reads the immutable surface snapshot without deep-copying per frame; outcome copies remain action-boundary only. VP idle liveness measured 49 redraws/120 frames against a floor of 8.

Per-cabinet RTP audit (`10000` deterministic rounds each, five coins per hand):
- Jacks or Better / 1 hand / 9/6: declared optimal RTP `99.54%`; concise-policy sample `0.9665`, inside declared sample band `0.88–1.12`.
- Double Deuces / 2 hands / Illinois 25/15/9/4/4/3: declared optimal RTP `98.91%`; concise-policy sample `0.8576`, inside declared sample band `0.78–1.12`.
- Triple Double Bonus / 3 hands / 10/6 DDB: declared optimal RTP `100.07%`; concise-policy sample `0.9344`, inside declared sample band `0.80–1.18`.

Gate results:
- `tools/validate_project.ps1`: PASS (`27.7s` final standalone run).
- `tools/check_godot.ps1 -FoundationSuite games`: PASS; `foundation_games 95.660s`.
- `tools/check_godot.ps1 -FoundationSuite ui`: PASS; scene compile and all UI subchecks green.
- `tools/check_godot.ps1 -FoundationSuite systems`: PASS; `foundation_systems 28.477s`.
- `tools/check_godot.ps1 -FoundationSuite video_poker`: PASS; `foundation_video_poker 34.912s`.
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`: PASS; 10 seeds, 320 checkpoints, matching hash `2740974421`.
- `tools/foundation_performance_probe.ps1 -RequireGodot`: PASS; VP resolve avg `1.130ms`, p95 `1.149ms`, max `3.122ms` against `2.5/4.5/5.0ms`.
- `tools/foundation_visual_qa.ps1`: PASS.
- `tools/video_poker_rtp_audit.ps1`: PASS at 10,000 rounds/cabinet; wrapper now honors `GODOT_BIN`.
- `tools/foundation_mouse_playtest.ps1 -RequireGodot`: PASS; 63 visible mouse-control events, victory and recovery/debt pressure.
- `tools/video_poker_rebuild_proof.gd`: PASS; failures `[]`, live 1/2/3-hand mouse captures, 960×600 touch capture, and mouse/touch double-up proof.
- UI05 asset pipeline, popup fit, surface coverage, and token adoption checks: PASS.

Manual feel/clarity acceptance:
- Jacks or Better reads as the large, clean baseline: one hand dominates the screen and the neon shell supports rather than crowds it.
- Double Deuces keeps both hands side-by-side at readable card size; shared holds are unmistakable and the two independent results are easy to compare.
- Triple Double Bonus uses two hands above and one centered below; all three remain readable, pay separately, and the gold high-roller treatment clearly differs from the other cabinets.
- Across all three, the bet/deal/hold/draw rhythm is obvious without prior knowledge, inputs respond once, wins explain themselves, and Holdout feels embedded in Draw rather than like a detached menu.

Deviations:
- Work remained on the isolated `video-poker-rebuild` branch and is pushed without merging because another task owns the dirty primary checkout.
- Captures and RTP reports remain under `.tmp/` as required and are intentionally untracked.

### Landing supplement — 2026-07-30

- The finish-and-land pass rebased the branch onto latest `origin/main`, strengthened the live display proof, and reran the complete integrated gate battery.
- Triple Double Bonus now has explicit acceptance evidence for three unique displayed signatures, three result rows, and mixed independently evaluated outcomes in one live capture.
- Final proof commit: `d8b40241`.
- Non-squash merge to `main`: `6cb9d7619ec5c04250d3fd94734c907ea0f3df43`.
- Full landing details and fresh gate timings are recorded in `docs/todone/video_poker_rebuild_finish_and_land_prompt.md`.
