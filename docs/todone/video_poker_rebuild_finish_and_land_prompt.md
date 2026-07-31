# Agent Prompt — Finish & LAND the Video Poker Rebuild (branch: video-poker-rebuild)

Copy everything below this line into the worker agent. Use a capable model.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. The video poker rebuild was started on the branch
**`video-poker-rebuild`** (worktree `D:/Projects/Beat-The-House-video-poker-
rebuild`) but it is NOT merged to `main` — so the owner is still playing the
OLD broken code on main and none of the fixes have reached them. Your job:
finish the remaining rebuild deliverables ON THAT BRANCH, PROVE every one, and
MERGE it to main so the fixes are real. Build on the branch's existing work —
do NOT restart from scratch.

The binding spec is `docs/todo/video_poker_complete_rebuild_prompt.md` (its
archived copy on the branch) and `docs/plans/video_poker_reference.md`.

## What the branch already did (verify, keep, build on)

- Betting: `COIN_LEVELS := [1,2,3,4,5]` with bet up/down/Bet Max wired.
- Multi-hand: each hand draws from its OWN independent 52-card deck minus the
  held cards, independently seeded (the "3 identical hands" LOGIC bug fixed).
- The real-video-poker reference/audit doc exists; module shrank to ~2,856
  lines.

## STRICT COMPLETION MANDATE

Not done until EVERY acceptance criterion below is PROVABLY met, CONFIRMED in
the running game, AND merged to main. Do not stop early, do not declare
success on a partial result, and do not leave it unmerged. If a behavior isn't
real, keep working. Only stop on a gate you genuinely cannot pass — then stop,
do NOT merge, and report exactly what is unmet.

## Finish & PROVE these (the owner's four failures + the rest)

1. **Multi-hand DISPLAY distinctness (verify the RENDER, not just logic).**
   The deck logic is fixed, but the owner saw the SAME hand drawn 2-3 times.
   Confirm the multi-hand renderer draws N VISIBLY DIFFERENT hands on screen,
   each labeled, each showing its own cards and its own result. If the render
   still mirrors one hand, FIX IT. PROVE with a 3-hand cabinet capture showing
   three different hands with different results.
2. **Betting works end to end.** Interaction test: drive coins-per-hand 1→5
   and Bet Max; assert the total wager and the highlighted paytable column
   update; the player is never stuck at 1. Capture.
3. **Clarity — how to win.** A first-timer always knows the next step
   (DEAL → hold → DRAW) and sees WHY they won/lost (winning hand named, the
   paytable row flashes). PROVE with a driven walkthrough + capture.
4. **Art is slot-parity.** Each of the three cabinets (Jacks or Better/1,
   Double Deuces/2, Triple Double Bonus/3) has professional art matching the
   slot machines (`scripts/games/slots/slot_renderer.gd`), unique per cabinet.
   PROVE with side-by-side captures next to a slot machine. This is the item
   most likely still weak — hold it to the slot bar.
5. **The cheat.** An in-draw holdout with a clean skill input and BLUNT
   feedback naming the swapped card + resulting hand; reduce-motion fallback;
   economy preserved (deterministic ideal card, quality→heat/evidence tiers).
   Verify it exists and feels good; rebuild it if it doesn't.
6. **Real casino feel.** Card flips/slides, held-lock, draw reveal, payout
   flash scaled to the win, double-up tension; smooth at both sizes; zero-copy
   per-frame; within the performance-probe budget.
7. **Correctness & RTP.** Hand evaluation per cabinet (Deuces wilds, DDB
   kicker bonuses); per-cabinet mass-sim RTP within bands (report the table).
8. **Determinism.** Same seed + same holds → identical hands/payouts across
   replays and save/load mid-hand; multi-hand independence deterministic.

## Integration — LAND it on main

1. Rebase/merge `video-poker-rebuild` onto the LATEST `origin/main` (main has
   moved — resolve conflicts preserving both sides' intent; never discard main
   work). Re-run the branch's suites after.
2. Run the FULL battery on the integrated result (gates below), all green.
3. MERGE to main (no squash — keep the rebuild history), push, and delete/
   clean the worktree + branch stragglers.
4. Archive `video_poker_complete_rebuild_prompt.md` to `docs/todone/` (if not
   already) with the completion record, and delete/archive THIS follow-up
   prompt the same way.

## Hard rules

- Determinism, zero-copy per-frame, idle-animation liveness untouched; tokens
  for chrome, per-cabinet art immediate-mode; web-safe. Keep the module's
  external contract (game id, surface hooks). Never weaken a test/budget to
  pass. Style: tabs, typed GDScript, sparse comments; captures/RTP under
  `.tmp/`. Suite timeout = max(300s, ceil(recorded baseline × 1.5)). Never
  revert or stage unrelated user-owned uncommitted work.

## Gates (all green on the integrated tree before merge)

- `tools\validate_project.ps1`
- `-FoundationSuite games`, `ui`, `systems`, and any video-poker suite
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- `tools\foundation_visual_qa.ps1`
- the video poker RTP audit
- `tools\foundation_mouse_playtest.ps1` (strict single run)

## On completion

Only after all eight deliverables are PROVEN and confirmed in the running
game AND the branch is MERGED to main:

Report: the branch-vs-spec audit (what was already done, what you finished),
the multi-hand-distinct-display proof, the betting-works proof, the slot-
parity art captures, the cheat design, the RTP table, the feel acceptance in
your own words, the merge commit hash on main, and every gate result.

If any deliverable is unproven or a gate cannot pass: STOP, do NOT merge to
main, and report exactly what is not yet real.

---

## Execution record — 2026-07-30

Landing:
- Rebuild branch: `video-poker-rebuild`.
- Rebase: branch was already exactly based on latest `origin/main` (`1ffd2cbc`), so `git rebase origin/main` completed with no rewrite or conflicts.
- Final branch proof commit: `d8b40241` (`Strengthen live multi-hand display proof`).
- Non-squash main merge: `6cb9d7619ec5c04250d3fd94734c907ea0f3df43`.
- Unrelated dirty primary files were checked for path overlap before merge; overlap was `NONE` and those files remained unstaged.

Branch-versus-spec audit:
- Existing branch work already implemented 1–5 coin betting, Bet Max, independent per-hand decks, correct paytable/evaluator fixtures, the authored cabinet renderer, in-draw Holdout, double-up, animation, and performance coverage.
- Finish work strengthened the live proof so Triple Double Bonus must expose three unique rendered signatures, three separately bound result rows, and independently different outcomes. The accepted capture has two no-pay hands plus one independently paid `Jacks or Better`.
- Fresh live captures and slot-parity composites were generated after the strengthened proof and preserved under `.tmp/video_poker/rebuild_proof/`.

Acceptance evidence:
- Multi-hand display: PASS. Triple Double Bonus reports `distinct_rendered_hands=3`, three different card signatures, `result_rows=3`, and result labels `No Pay` plus `Jacks or Better`.
- Betting: PASS. The interaction suite drives 1→2→3→4→5 coins, verifies strictly increasing total wager, Bet Max, and active-column state. Live mouse and 960×600 touch proofs both reach five coins.
- Clarity: PASS. The persistent strip reads `SET BET → DEAL → TAP CARDS TO HOLD → DRAW → AUTO PAY`; the primary button changes DEAL/DRAW; results name each hand and paid credits; the winning paytable row flashes.
- Art: PASS. Neon Jacks, Double Deuces, and Triple Double Bonus each use a unique full-width authored shell, paytable treatment, hand layout, meter/control deck, colors, and animation. Side-by-side live slot captures are under `.tmp/video_poker/rebuild_proof/*_slot_parity.png`.
- Holdout: PASS. The skill chain occurs during Draw, uses cabinet-flavored timing/target beats, names the exact swapped card and resulting hand, preserves deterministic quality→heat/evidence plus item/alcohol modifiers, and has a generous reduced-motion path.
- Casino feel: PASS. Sequential card-back/face reveals, HELD locks, win-row flashes, independently labeled lanes, animated cabinet lamps, gross WIN meter, and one-press double-up picks remain smooth at both sizes.
- Correctness/RTP: PASS. Fixtures cover Jacks or Better, Deuces wild categories, and Double Double Bonus kicker bonuses. The 10,000-round-per-cabinet audit remained inside every declared sample band.
- Determinism: PASS. Two 10-seed replays produced identical 320-checkpoint hashes (`2740974421`); multi-hand draw stream keys and Holdout inputs remain deterministic.

RTP:
- Jacks or Better / 1 hand / 9/6: declared optimal `99.54%`; deterministic concise-hold sample `0.9665`, band `0.88–1.12`.
- Double Deuces / 2 hands / Illinois 25/15/9/4/4/3: declared optimal `98.91%`; sample `0.8576`, band `0.78–1.12`.
- Triple Double Bonus / 3 hands / 10/6 DDB: declared optimal `100.07%`; sample `0.9344`, band `0.80–1.18`.

Integrated gate battery:
- `tools/validate_project.ps1`: PASS (`26.3s`).
- `-FoundationSuite games`: PASS; `foundation_games 94.336s`.
- `-FoundationSuite ui`: PASS; scene compile, inventory integration, and UI05 design-system checks green.
- `-FoundationSuite systems`: PASS; `foundation_systems 27.530s`.
- `-FoundationSuite video_poker`: PASS; `foundation_video_poker 33.805s`.
- `foundation_determinism_probe -RequireGodot -SeedCount 10`: PASS; 320 checkpoints, hash `2740974421`.
- `foundation_performance_probe -RequireGodot`: PASS; VP resolve avg `1.106ms`, p95 `1.121ms`, max `3.203ms`; idle liveness `49/120` against floor `8`.
- `foundation_visual_qa.ps1`: PASS.
- `video_poker_rtp_audit.ps1`: PASS; 10,000 rounds per cabinet.
- `foundation_mouse_playtest.ps1 -RequireGodot`: PASS; 63 visible mouse inputs, victory and recovery paths.
- `video_poker_rebuild_proof.gd`: PASS; live mouse/touch cabinet loop, three-hand display evidence, and mouse/touch double-up evidence.

Manual feel acceptance:
- Neon Jacks gives the single hand the largest possible reading area and cleanest rhythm.
- Double Deuces keeps two full-size hands side-by-side, with shared holds and separate results immediately understandable.
- Triple Double Bonus uses two hands above and one centered below; the accepted result capture makes all three hands visually distinct and shows which lane paid.
- Bet, Deal, Hold, Draw, payout, and optional Double Up read like one real-machine loop. Controls respond once, the paytable explains wins, and Holdout feels embedded in the draw rather than detached from it.

Deviations: none. All required deliverables were proven before the non-squash merge.
