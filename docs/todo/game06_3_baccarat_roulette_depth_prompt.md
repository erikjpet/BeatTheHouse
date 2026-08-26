Status: TODO
Board row: `game06_3` in `docs/todo/README_0_6_board.md`

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
