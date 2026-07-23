# Agent Prompt — Scratch Ticket Refinement Pass (Finalize the Game)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Immediate-mode canvas
rendering on a 900×430 board; per-game modules under `scripts/games/`;
content data-driven; audio synthesized in `scripts/ui/sfx_player.gd`;
seeded RNG via `RngStream` forks only. This is a STRUCTURED REFINEMENT
WORK ORDER for the already-shipped scratch-ticket game (renovation landed
in commit `c0fa142e`). The mechanics work but read like a rough draft:
tickets look flat, text is unreadable, symbols reveal in whole sections,
scratch masks misalign with the art, and there is no result moment or
multi-buy. This pass finalizes the game — execute every phase, satisfy
every checklist item, keep the determinism/zero-copy/save contracts.

## What exists (audit before editing; code reality wins)

- Module: `scripts/games/scratch_tickets.gd` (~2,085 lines) — free-form
  mask scratching, per-section reveal.
- Data: `data/games/scratch_tickets.json` — seven tickets: `two_fer`
  ($2), `lucky_7s` ($5), `tic_tac_gold` ($10), `crossword_corner` ($15),
  `bonus_bingo` ($20), `high_roller_holdem` ($50), `golden_vault`
  ($100). Roster, prices, mechanics, sizes, and RTP bands are LOCKED —
  do not change gameplay outcomes; this pass is presentation, feel, and
  flow.
- Sound: `sfx_player.gd` scratch synth (soft foley from the renovation).
- Tests: `scripts/tests/foundation/check_scratch_tickets.gd`.
- Determinism contract (KEEP): outcome fixed at purchase; scratching,
  reveal order, and coverage never change results.

---

## PHASE A — Unique themed ticket art (make them pop)

Each of the seven tickets currently looks generic. Give each a distinct,
exciting visual identity drawn immediate-mode in the game's pixel style —
real-scratch-ticket energy: bold, colorful, graphical.

- [ ] Every ticket has its OWN theme: a dedicated palette, border/frame
  treatment, title banner, background motif, and symbol art that matches
  its mechanic and name. No two tickets share a look.
  - `two_fer` — cheap-and-cheerful cherries/fruit, red/green.
  - `lucky_7s` — hot Vegas sevens, gold/red, lucky-number motif.
  - `tic_tac_gold` — gold grid, X/O/nugget symbols.
  - `crossword_corner` — newsprint/puzzle look, ink on cream.
  - `bonus_bingo` — bingo-hall dauber colors, playful multi-card board.
  - `high_roller_holdem` — green felt, playing-card suits, classy.
  - `golden_vault` — premium black/gold, vault/bars, the flagship.
- [ ] Use color and contrast so tickets read as vibrant objects, not
  flat rectangles — background, symbols, prize legend, and frame are
  clearly distinct layers.
- [ ] Price and size scale visually (the $100 Golden Vault must LOOK
  premium next to the $2 2-fer).
- [ ] The latex/scratch layer reads as an actual silver scratch coating
  over the printed art, distinct from the ticket face.

---

## PHASE B — Per-symbol scratch regions + individual reveal

Scratching currently clears whole sections. Change it so EACH SYMBOL /
scratch box has its OWN independent scratch region.

- [ ] Every individual symbol box (each match spot, each number cell,
  each grid square, each card, each ladder rung) is its own scratch
  region with its own coverage tracking.
- [ ] A symbol box pops to its FULLY-REVEALED state only when its own
  region reaches 80% scratched *(tunable)* — not when the section does.
- [ ] At that 80% moment, per box: play a short, satisfying POP reveal
  ANIMATION that clears the box's remaining latex, plus a small POP
  sound effect (new soft synth cue in `sfx_player.gd`, distinct from the
  scratch-loop). Each box pops independently as the player works it.
- [ ] Scratch progress is SILENT: never render a progress bar,
  percentage, or coverage meter on the ticket or UI. Coverage is
  internal state only; the only feedback is the latex visibly thinning
  and the pop when a box completes.

---

## PHASE C — Mask-to-art alignment

Many tickets misalign: latex covers areas that shouldn't be covered and
leaves printed areas exposed that should be under scratch.

- [ ] Every scratch region's geometry EXACTLY matches the printed symbol
  box beneath it — the latex covers precisely the scratchable art and
  nothing else (titles, prize legends, borders, and instructions stay
  permanently visible and uncovered).
- [ ] Verify per ticket, per size (small rectangle / medium square /
  large rectangle / tall) at 1280×720 and small-screen scaling — no
  drift between the mask and the art at any size.
- [ ] Fix the region-layout so it is data-derived from the ticket's own
  art layout (single source of truth), not a separately-authored mask
  that can desync.

---

## PHASE D — Readability + win clarity

Text is too small and prizes/conditions are unclear.

- [ ] Prize amounts, symbols, and numbers are rendered LARGE and
  high-contrast — legible at a glance at 1280×720 and small-screen.
- [ ] Each ticket shows a clear, always-visible HOW-TO-WIN line and its
  prize legend in plain language (e.g. "Match 2 symbols to win",
  "Match your numbers to the winning numbers — any 7 wins it all").
- [ ] On resolution, the ticket clearly states WHETHER the player won
  and WHY (which line/match/hand paid, and how much) — not a bare number.
- [ ] Instruction copy per `docs/plans/content_style_guide.md`: short,
  second person, unmistakable.

---

## PHASE E — The result moment (don't auto-file)

Currently a finished ticket drops straight to the pile.

- [ ] When a ticket is fully scratched (all boxes revealed), enter a
  RESULT state on the surface: prominently show what the player won (with
  the winning condition highlighted) or that it was a loser. Winnings are
  applied to the pending-cash-at-clerk flow as today.
- [ ] The ticket stays on the surface in this result state until the
  player CLICKS it; the click files it to the pile/stack and advances to
  the next queued ticket (Phase F). No auto-advance.
- [ ] Reduce-motion: the result state still shows; only animation is
  suppressed.

---

## PHASE F — Multi-buy + scratch queue

- [ ] The machine lets the player BUY SEVERAL TICKETS AT ONCE (choose a
  quantity, or buy multiple before scratching), charged cash per ticket
  at purchase; each ticket's outcome is rolled at ITS purchase (seeded,
  deterministic).
- [ ] Bought-but-unscratched tickets form a QUEUE, visibly stacked/
  waiting near the surface.
- [ ] The player scratches ONE ticket at a time; filing a resolved
  ticket (Phase E click) brings the next queued ticket to the surface.
- [ ] Queue state serializes and restores (save/load mid-queue keeps the
  pending tickets and their fixed outcomes).
- [ ] The purchase, queue, result, and filing flow reads cleanly in the
  reworked UI; nothing overlaps or clips at either screen size.

---

## Hard rules (binding)

- Gameplay outcomes, roster, prices, mechanics, sizes, and RTP bands are
  UNCHANGED — this pass is art, feel, readability, and flow only.
- Determinism: outcomes fixed at purchase; per-box reveal order/coverage
  never change results; multi-buy rolls each ticket at its own purchase
  from named seeded forks; the determinism probe stays self-consistent.
- Zero-copy per-frame: masks, per-box coverage, particles, pops, and the
  queue render from the module snapshot under the allocation-free idle
  contract; no per-frame `duplicate(true)`.
- Idle-animation liveness untouched; reduce-motion fully supported
  (scratch-all + instant reveals + result state, no animation).
- Save-compat: queue + per-ticket + per-box state serialize; a legacy
  mid-scratch save loads cleanly.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports only.
  Suite timeout = max(300s, ceil(recorded baseline × 1.5)).

## QA / Tests (extend `check_scratch_tickets.gd`; all required)

1. Determinism preserved: seed + purchase → identical outcome regardless
   of per-box scratch order/coverage across all seven tickets; multi-buy
   rolls are independent and reproducible; save/load mid-queue and
   mid-scratch restores masks, per-box coverage, and pending outcomes.
2. Per-box reveal: a box pops only at its own 80% coverage; the pop
   reveals the same symbol the outcome fixed; no early/wrong reveal.
3. Alignment: automated check that each scratch region's rect matches its
   art box (no covered legend/title, no exposed scratch symbol) for every
   ticket at every size.
4. Result flow: a finished ticket enters the result state and does NOT
   file until clicked; the click files it and advances the queue.
5. Multi-buy: buying N charges N× cash, produces N queued tickets,
   scratched one at a time in order.
6. No progress meter is rendered anywhere (assert the UI exposes no
   coverage/percentage readout).
7. Sound: the per-box pop maps to the new pop cue; the scratch loop is
   the soft foley; no metallic path.
8. FEEL/READABILITY ACCEPTANCE (manual, report in words): buy a stack of
   mixed tickets, scratch each — every ticket looks distinctly themed and
   vibrant, text and prizes are instantly readable, each box pops
   satisfyingly at 80%, the win/loss result is unmistakable, and filing
   + queue advance feels clean.

## Gates (all must pass)

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` (games + scratch)
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_performance_probe.ps1 -RequireGodot` (scratch surface
  stays within its budgeted allocation)
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_mouse_playtest.ps1` (strict single run)

## On completion

Commit in logical units (per-ticket art; per-box regions + pop; alignment;
readability; result moment; multi-buy queue), delete this prompt file in
the final commit, push, and report: a per-ticket description of the new
themed art, the per-box reveal tuning, the readability changes, the
multi-buy/queue flow, the feel/readability acceptance in your own words,
and every gate result. On an unfixable gate failure: stop at the last
green commit and report verbatim.
