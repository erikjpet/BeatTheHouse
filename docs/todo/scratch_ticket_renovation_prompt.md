# Agent Prompt — Scratch Ticket Renovation: Feel, Sound, Roster, Sizes, Machine, UI

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Immediate-mode canvas
rendering on a 900×430 board; per-game modules under `scripts/games/`;
content data-driven; audio is PROCEDURALLY SYNTHESIZED in
`scripts/ui/sfx_player.gd`; seeded RNG via `RngStream` forks only. This
file is self-contained and is a STRUCTURED WORK ORDER: execute the phases
in order, satisfy every checklist item, and do not skip or reinterpret a
requirement. The owner approved the ticket roster in Phase B verbatim —
build exactly those seven.

## What exists today (audit before editing; code reality wins)

- Module: `scripts/games/scratch_tickets.gd` (~1,680 lines), currently
  GRID-BASED (each ticket has `{"grid": {"columns", "rows"}}` and the
  scratch reveal instant-uncovers the cell under the pointer).
- Data: `data/games/scratch_tickets.json` — current roster (lucky_7s,
  cash_cow, high_voltage, gold_rush_doubler, bonus_box, word_hunt,
  second_chance, devils_cut, fools_gold, midnight_rare) at prices
  $2/$5/$10/$15. THIS ROSTER IS RETIRED and replaced by Phase B.
- Sound: `sfx_player.gd` — the `scratch_scrape_loop` family event and
  `_sample_scratch_scrape_loop(...)` synth. This is the "ringy metallic"
  sound to REPLACE.
- Tests: `scripts/tests/foundation/check_scratch_tickets.gd`.
- Placement: the `gas_station_casino` archetype game pool.
- Determinism contract (KEEP): a ticket's full outcome is fixed by a
  seeded roll AT PURCHASE. Scratching is presentation/pacing only —
  reveal order, brush path, and coverage NEVER change the result.

Retire the old ids cleanly; scratch tickets are consumed within a run, so
no long-term save migration is needed, but confirm no persisted state
dangles on the retired ids and update every test/reference.

---

## PHASE A — The scratch feel + sound (the core of this renovation)

The single most important outcome: scratching must feel like a REAL
scratch-off and be satisfying. Replace the grid-instant-reveal with a
free-form, accumulating, partial-reveal scratch system.

Checklist (all required):

- [ ] **Free-form, not grid.** Remove cell-snapped revealing. The latex
  is a continuous per-ticket scratch MASK (high-resolution coverage
  buffer, not game-logic cells). The player scratches anywhere with
  near-free control; the mask is presentation only.
- [ ] **Partial reveal per pass (~2/3).** A single drag over an area
  removes only ~66% of that area's remaining latex *(tunable)*, not all
  of it. The underlying art shows through progressively; a spot needs
  MULTIPLE passes to fully clear.
- [ ] **Smaller brush footprint.** The scratched swath per drag is
  SIGNIFICANTLY smaller than today's, so the player naturally works back
  and forth to clear a section. Brush radius is tunable; default chosen
  for a real-scratch cadence, not tedium.
- [ ] **Reliable registration (fix the dropped input).** Interpolate the
  scratch stroke between pointer samples so fast drags leave a
  continuous path with no gaps or missed segments; capture pointer
  motion robustly (mouse AND touch for web). Scratching must register
  every time.
- [ ] **80% section auto-sweep.** Each ticket defines SECTIONS (the
  result-bearing areas). When a section reaches 80% mask coverage
  *(tunable)*, play a short, satisfying SWEEP animation that clears the
  remaining latex of that section at once (the "you've done enough,
  here's your reveal" payoff). Below threshold, nothing auto-clears.
- [ ] **Satisfaction pass.** Latex flakes/crumbs shed at the brush
  (presentational particles from the module snapshot — zero-copy rules
  apply); the sweep has a clean motion; result reveals read clearly.
  Reduce-motion disables particles and the sweep animation (instant
  clear on threshold) and enables a "scratch all" control. Drunk level
  adds visual wobble to the brush ONLY — never more strokes, never a
  changed outcome.
- [ ] **Sound rework.** Replace the metallic `scratch_scrape_loop` synth
  with a SOFT, dry foley scratch — the sound of a coin dragging on
  cardstock / scratching cloth or skin: broadband filtered noise with a
  gentle grain envelope, NOT a ringy metallic tone. Re-synthesize it in
  `sfx_player.gd`'s procedural system (no external asset required);
  loudness/rate tied to active scratching, fading when the pointer
  stops. It must sound like paper being scratched.

Acceptance (report explicitly): scratch ten tickets by hand — a section
needs several honest back-and-forth passes but never feels grindy, fast
swipes never skip, the 80% sweep lands as a payoff, the sound is soft and
paper-like, and the tenth ticket is still satisfying.

---

## PHASE B — The seven-ticket roster (owner-approved; build exactly this)

One unique ticket per denomination, each a DISTINCT real scratch-off
mechanic, complexity and physical size rising with price. Data-driven in
`data/games/scratch_tickets.json` with whatever schema these mechanics
require (extend it deliberately; the old grid schema will not fit most of
these). Each ticket declares its sections (for Phase A's auto-sweep), its
size (Phase C), its stock weight (Phase D), and an audited RTP band
(~0.70–0.85 target; expensive tickets may sit slightly higher with far
higher variance and larger top prizes). Outcomes fixed at purchase;
`effective_luck` shifts the purchase-time prize roll via the existing
luck hook.

| $ | id | Name | Mechanic | Rules |
| - | -- | ---- | -------- | ----- |
| 2 | `two_fer` | **2-fer** | Match 2-of-3 | Three spots, a symbol under each; any two matching symbols win that symbol's prize from a small legend. Simplest. 1 section. |
| 5 | `lucky_7s` | **Lucky 7s** | Key-number match | A "Winning Numbers" area (2 numbers) + six "Your Numbers", each hiding a number and a prize; each of yours matching a winning number pays its prize; wins add up. **SEVEN RULES (owner-locked): if a 7 appears in the Winning Numbers → the player wins ALL prizes on the ticket; if a 7 appears among Your Numbers → that spot is automatically a winner and pays its prize regardless of the winning numbers.** 2 sections. |
| 10 | `tic_tac_gold` | **Tic Tac Gold** | Tic-tac-toe | 3×3 grid; each completed line of three matching WIN symbols pays that line's prize (multiple lines pay separately); one bonus instant-win spot. 2 sections. |
| 15 | `crossword_corner` | **Crossword Corner** | Crossword | A letter bank (~18 letters) fills a crossword grid; completed words pay by count off a legend (e.g. 3 words = $X, 4 = $Y). Most hands-on scratching. 2 sections. |
| 20 | `bonus_bingo` | **Bonus Bingo** | Bingo | Scratch ~24 caller numbers, daub up to four bingo cards; each completed line pays; blackout pays big. 5 sections (caller + 4 cards). |
| 50 | `high_roller_holdem` | **High Roller Hold'em** | Beat-the-dealer poker | Reveal YOUR five cards and the DEALER'S five; beat the dealer's rank to win the prize for your hand; a wild-card slot and an instant "pocket aces" win-all. 3 sections. |
| 100 | `golden_vault` | **The Golden Vault** | Multi-game premium | A multiplier spot (2×–20×), a five-rung cash match-to-win ladder, a GOLD BAR win-all bonus, and a final vault top-prize reveal. Rarest stock, biggest top prize. 4+ sections. |

Each ticket gets a UNIQUE face drawn immediate-mode in the game's pixel
style (distinct palette, symbol set, and layout per ticket). Winners
remain pending until cashed at the clerk (preserve the existing
pull-tabs-style redeemer flow); conspicuous big wins draw
attention/heat consistent with the current system.

---

## PHASE C — Physical ticket sizes (four orientations)

Tickets are not all one size. Define four sizes; assign per Phase B;
lower price = smaller. The play surface (right side of the board) sizes
itself to the active ticket.

| Size | Orientation | Tickets |
| ---- | ----------- | ------- |
| Small rectangle | wide, short | 2-fer ($2) |
| Medium square | balanced | Lucky 7s ($5), Tic Tac Gold ($10) |
| Large rectangle | wide, tall | Crossword Corner ($15), Bonus Bingo ($20) |
| Tall | narrow, tall | High Roller Hold'em ($50), Golden Vault ($100) |

Sizes are data-declared and drive both the on-surface layout and the
machine's dispenser rendering (Phase E). All sizes must scratch, lay out,
and read cleanly at 1280×720 and supported small-screen scaling.

---

## PHASE D — Machine stock (price-weighted rarity)

- The vending machine seeds its available tickets per visit/day from a
  named seeded fork, weighted INVERSE to price: $2/$5 common, $100 a
  seldom, exciting find. Every denomination is possible each visit;
  higher denominations are increasingly rare.
- Weights are tunable data. Verify stock draws deterministically per seed
  and rotates with the day-keyed streams if that system is present.

---

## PHASE E — The vending machine environment art

Replace the current basic box-shape machine with a detailed, authored
scratch-ticket VENDING MACHINE that reads as a real one, drawn
immediate-mode in the game's pixel style, on the LEFT of the board (play
surface on the RIGHT). Model the FORM FACTOR on a modern state-lottery
scratch dispenser (tall floor unit): a top marquee/jackpot header, a
glass front showing MULTIPLE VISIBLE ROWS of scratch tickets in their
dispenser slots (the actual in-stock tickets and their sizes should read
in the rows), a bright branded side panel, ticket-selection buttons, and
a bottom dispensing tray. Use the game's OWN fictional lottery identity
and palette — do NOT reproduce any real lottery's logo, name, or
trademarked branding; evoke the machine, not the brand.

Checklist:
- [ ] Tall floor-standing unit, clearly a ticket machine, not a box.
- [ ] Marquee/header with an in-world jackpot/brand flourish.
- [ ] Glass front with visible dispenser rows reflecting current stock
  and ticket sizes.
- [ ] Selection affordance + dispensing tray; buy interaction reads
  spatially (approach → select → dispense onto the play surface).
- [ ] Consistent with the gas-station-casino environment's look.

---

## PHASE F — UI rework

By the end of this work order the scratch UI is fully reworked, cohesive,
and clean:
- [ ] Machine-left / surface-right composition holds for every ticket
  size; the bought ticket animates from the tray to the surface.
- [ ] Clear, uncluttered readouts: price, prize legend/rules for the
  active ticket, current winnings, and the cash-at-clerk affordance.
- [ ] The scratch surface, brush feedback, section states, and sweep
  reveals are legible and satisfying.
- [ ] "Scratch all" convenience control present; reduce-motion path
  clean; small-screen scaling holds (tabs/compaction, never scroll on
  the core surface).
- [ ] Item interactions preserved (x-ray peek etc. from the current
  system) and readable in the new UI.

---

## Hard rules (binding)

- Determinism: outcomes fixed at purchase; brush/coverage/order never
  change results; stock and any variation from named seeded forks at
  action boundaries; the determinism probe stays self-consistent.
- Zero-copy per-frame: the scratch mask updates on input events; the
  surface, particles, and machine render from the module snapshot under
  the allocation-free idle contract. No per-frame `duplicate(true)`.
- Idle-animation liveness untouched; reduce-motion fully supported.
- No cheat ACTION added (item-driven only, consistent with the
  skill-cheat exemption for this game).
- Economy: unchanged — machine charges cash, winners cash at the clerk.
- Style: tabs, typed GDScript, sparse comments; copy per
  `docs/plans/content_style_guide.md`; `.tmp/` reports only. Suite
  timeout = max(300s, ceil(recorded baseline × 1.5)).

## QA / Tests (extend `check_scratch_tickets.gd`; all required)

1. Determinism: seed + purchase → identical outcome regardless of scratch
   path/order/coverage; save/load mid-scratch restores mask + outcome.
2. Per-ticket mechanic + payout tests for all seven, INCLUDING the Lucky
   7s seven-rules (winning-7 win-all; your-7 auto-win) and each ticket's
   section auto-sweep at threshold.
3. Reveal integrity: the 80% sweep reveals the same result the mask would
   have; partial scratching never pays early or wrong.
4. Sizes: each ticket lays out and scratches at its declared size at
   1280×720 and small-screen.
5. Stock weighting distribution over seeded mass sampling ($100 rarity
   within band); deterministic per seed.
6. Full per-type RTP table within declared bands (mass simulation).
7. Sound: the scratch event maps to the new soft synth (assert the
   family/routing changed; no metallic sample path remains).
8. FEEL ACCEPTANCE (manual, report in words): the ten-ticket hand-scratch
   bar from Phase A.

## Gates (all must pass)

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` (games suites + scratch)
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_performance_probe.ps1 -RequireGodot` (the scratch
  surface stays within a budgeted allocation; add/keep it as a measured
  surface)
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_mouse_playtest.ps1` (strict single run)

## On completion

Commit in logical units (feel+sound engine; roster+data; sizes; stock;
machine art; UI), delete this prompt file in the final commit, push, and
report: the scratch-feel tuning values, the per-type RTP table, the
machine art description, the feel-acceptance results in your own words,
and every gate result. On an unfixable gate failure: stop at the last
green commit and report verbatim.
