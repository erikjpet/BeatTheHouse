Status: COMPLETE — full Baccarat and Roulette depth is landed, verified, and archived
Board row: `game06_3` in `docs/todo/README_0_6_board.md`

## Execution Record

- Completed: 2026-09-02.
- Recovered implementation: `212475356cedb42056a2677b590e5b69ed0ac8aa`
  (including the preserved Roulette and completed Baccarat depth work), with
  later sealed-authority corrections `1354ae26` and `679b1d8a` already on
  `main`.
- Closeout verification: `45239305` modernizes the seed audits to exercise the
  real sealed host boundary; `9c2e6b1a` adds the 10-seed native/Web
  presentation-parity probe. No product rules, payouts, budgets, or acceptance
  limits were changed during closeout.
- Focused acceptance: the combined depth contract passed for both games. The
  focused Foundation Roulette and Baccarat suites each passed with zero
  failures. Roulette's rules audit passed all 157 payout and hit-region
  targets. Roulette passed 10/10 live authoritative spins with 96 trajectory
  frames per spin; Baccarat passed 400 advancing-shoe hands plus 10/10 sealed
  host commits with exact bankroll and road-history accounting.
- Determinism: two independent 10-seed runs produced the same 560 checkpoints,
  combined hash `1246250829`, and byte-identical report SHA-256
  `E5C12ECAE8FEC14D78F4AEBA30AF04B6552892C153956C9EB6D3F6569D869F94`.
- Platform parity: a fresh Web release export in Chrome 152 and native Windows
  produced the identical semantic hash
  `ba2fa83da58c9865fb2801b6d561e7e98b2ecd26fcbc3fa0df6b5cfd6c010ab7`
  across 10 Roulette spins and 10 Baccarat squeeze states, with no browser
  errors.
- Performance and visual/accessibility: all measured Baccarat and Roulette
  renderer/resolve coverage and unchanged budgets passed. Canonical visual QA
  exited cleanly with no warnings; the focused contract additionally covers
  sparse/crowded/max-energy states, small-screen hit regions, reduced motion,
  non-color phase cues, save/revisit, actors, objects, crew, and security.
- Honest aggregate-gate note: the unchanged full performance probe retained an
  unrelated Coin Pusher skill-stop draw red (`7.90 ms` versus `7.00 ms`) and did
  not mark that separate active sequence checked. It did not produce a
  Baccarat or Roulette failure and was not weakened or hidden. Broad wrapper
  attempts that included unrelated prechecks timed out; the row-owned suites
  were rerun directly and passed.
- Disposition: the owner's direction to close this row is fulfilled by the
  actual full two-game implementation (the earlier D3 full-closure outcome),
  without a requirement reduction, split successor, or exception.

# Agent Prompt — 0.6 game06_3: Baccarat and Roulette Depth

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over two
shipped table games, not a rules rewrite. Read `scripts/games/baccarat.gd`
(~3600 lines), `scripts/games/roulette.gd` (~4300 lines), the `game06_1` ritual
contract document under `docs/plans/`, and the landed `craps06_3` table for the
house pattern before editing.

## Why this rework exists

Both games are mathematically complete and presentationally inert. Baccarat is
the most ceremonial game on any real floor and currently resolves as three
buttons and a result line. Roulette is the most physical game on any real floor
and currently resolves as a bet list and a number. Neither has a croupier who
does anything, a layout you place chips on, or neighbours whose money is on the
same felt as yours.

## Board and dependencies

Follow the active board protocol. Claim `game06_3`. `game06_1` must be landed
and reviewed; build only on its accepted head. You own `scripts/games/baccarat.gd`,
`scripts/games/roulette.gd` and their tests exclusively. You may not edit the
shared runtime or visual layer; file a runtime request instead.

Do these as two separate logical commit groups on one branch. They share a
vocabulary, not an implementation.

## 1. Roulette — the wheel and the felt

- Chip placement on the real layout: inside and outside bets addressed by named
  board regions, including split, street, corner, line and column positions, with
  place, add, remove one, undo, clear, repeat last and rebet over a pending set.
  Never force a clear-all to correct one chip.
- Show available funds, total new stake, at-risk stake, per-bet payout and per-bet
  resolution. A crowded layout must stay readable and each stack must be
  identifiable at 1280×720 and at small-screen sizes.
- Presentation phases: `betting → no more bets → spin → ball settle → croupier
  settlement → betting`. The authoritative number stays seeded and rules-owned;
  the wheel and ball are presentation and may never determine or alter it.
- The wheel is a scene object with real state: rotor motion, ball travel, drop,
  bounce and rest in the pocket that matches the authoritative result. Reduced
  motion shortens travel without hiding the result.
- The croupier is an actor: waves off bets, spins, places the dolly, clears
  losing chips, pays in order. Clearing must visibly precede paying, because
  that is the beat that makes the game legible.
- The "no more bets" moment must be a real, readable gate with an accessible
  non-color-only state, and late input must be rejected gently without charge.

## 2. Baccarat — the ceremony

- Presentation phases: `betting → shoe → deal → squeeze/reveal → third-card rule
  → settlement → betting`, with the third-card rule shown as procedure rather
  than asserted in text. A player who watches twice should be able to predict
  the draw.
- The card squeeze is the game's signature: a bounded tactile reveal verb with
  keyboard, controller and reduced-motion equivalents producing identical
  outcomes and fair timing. It may never change or reroll a card.
- Commission handling on banker wins must be visible and accounted for
  explicitly, with the running commission and its settlement legible.
- The shoe, the road boards and the discard tray are scene objects with state.
  Road boards must reflect the authoritative history exactly; they are a memory
  aid, never a prediction, and nothing in the game may treat them as one.
- The dealer and callers are actors with states for shoe change, deal, call,
  third card, pay, sweep, suspicion and idle.

## 3. Populated rooms

- Neighbours are actors with their own seeded wagers and reactions. They must
  never consume or generate player money and must never alter player odds or
  outcomes. Their money on the felt is the point; their influence is forbidden.
- Table energy must change actors, objects or interactables — crowd size, rail
  space, croupier attention, security presence. Music and a patron line alone
  are a validation failure.
- Heat and pit attention become visible presence at both tables while remaining
  the same underlying number.

## 4. Cheats and crew integration

- Preserve every landed cheat contract, its detection math and its heat effects
  exactly. Integrate cheat flows into the ritual rather than a detached panel.
- Crew coordinated plays that list `baccarat` or `roulette` in
  `data/crew/plays.json` — including the chip dump, which ships as a
  player-funded transfer of $40 for a $6 fee — must present as visible crew
  presence using the `game06_1` actor vocabulary, with availability, cost,
  window, detection and heat contracts untouched.

## 5. Tests and acceptance

- Preserve and extend the full rules and RTP matrix for both games. Money
  conservation asserted exactly, including roulette multi-bet settlement and
  baccarat commission.
- Phase-machine assertions: no input can double-spin, double-settle, place a bet
  after the gate, strand a wager or charge on a rejected verb.
- Wheel and ball presentation provably lands on the authoritative pocket for
  10 seeds on native and Web; squeeze presentation provably cannot alter a card.
- Neighbour determinism across 10 seeds and proof they cannot affect player
  outcome or bankroll.
- Assert every energy tier changes at least one actor, object or interactable
  state and settles correctly when it falls.
- Save, exit and revisit at every phase boundary in both games, including
  mid-spin, mid-squeeze and at settlement, with no lost or double-settled wager
  and no replayed one-shot effect.
- Visual QA: sparse and crowded layouts, maximum bet density, every phase, both
  cheat flows, maximum energy, reduced motion, small screen, colorblind.
- Playtest checklist: a new player can place an inside and an outside roulette
  bet and read the result; and can bet baccarat, watch a third card be drawn and
  explain why it was drawn.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, RTP, performance, accessibility and visual QA. Archive only
with exact evidence for both games; one finished game is not a pass.
