# Video Poker Reference: Real-Machine Spec

This document is the implementation spec for the complete video-poker rebuild. It records the real casino-machine rhythm the game must prove in code, tests, captures, and manual acceptance.

## Machine rhythm

1. Bet: the player selects one to five coins per hand. Five coins is the standard max-bet state and carries the royal-flush jackpot column.
2. Deal: one five-card base hand is dealt face-up from a freshly shuffled 52-card deck.
3. Hold: the player toggles any subset of the five cards. Held cards must show an unmistakable `HELD` marker and stay locked through draw.
4. Draw: the primary button relabels from `DEAL` to `DRAW`. Non-held cards are replaced.
5. Evaluate and pay: the paytable stays visible, the active bet column remains highlighted, the winning row flashes, and credits/bet/win meters update.
6. Double-up: after a clean win, the player may gamble the win against a dealer card by picking one of four face-down cards. Higher doubles, equal pushes, lower forfeits; the chain is capped.

## Multi-hand rule

Multi-hand video poker is one base deal plus independent completion hands:

- One base five-card hand is dealt.
- Holds from the base hand apply to every hand.
- For one-hand play, the draw is normal draw poker: replacements come from the original deck after the opening five cards.
- For two- or three-hand play, each hand is completed from its own independent 52-card deck with only the held cards removed. Non-held base cards are discarded presentation cards and may reappear in any result hand.
- Each result hand is scored and paid separately; total return is the sum of result hands.
- The RNG stream for each hand must be deterministic, distinct, and replayable from the same run seed, machine state, holds, and action stream.

## Cabinets

The owner-locked cabinet roster is:

- Jacks or Better: one hand, 9/6 Jacks-or-Better paytable, retro-neon baseline.
- Double Deuces: two hands, Deuces Wild paytable, electric wild-card cabinet.
- Triple Double Bonus: three hands, Double Double Bonus paytable with kicker rows, premium gold high-roller cabinet.

Every cabinet must render as a full casino cabinet sibling to the slot machines: authored cabinet background, integrated control deck, visible paytable, card area sized for its hand count, and clear credits/bet/win meters.

## Controls

The interface must support mouse and touch at 1280x720 and small-screen:

- Primary button: `DEAL` when idle, `DRAW` when a hand is active.
- Card taps: toggle holds, one hit target per card.
- Bet controls: bet-one / bet step and bet-max.
- Denomination button where available.
- Holdout controls while a cheat is armed.
- Double-up start and pick controls after a clean win.

## Cheat

The cheat is an in-draw holdout: during the draw, the player times a cabinet-flavored skill input and palms in a better card. It must:

- Use the shared deterministic skill economy: seeded ideal card, quality-to-heat/evidence tiers, item and alcohol modifiers.
- Happen during the draw flow, not as a separate off-machine minigame.
- Give blunt feedback naming the swapped card and resulting hand.
- Offer a reduce-motion single-input fallback.

## Proof matrix

The rebuild is accepted only when these are proven:

| Deliverable | Required proof |
| --- | --- |
| Order of operations | Driven bet -> deal -> hold -> draw -> pay test, with held cards unchanged and non-held cards replaced. |
| Multi-hand independence | Many-seed test showing two- and three-hand cabinets do not copy a shared draw; hand results report deck rule and pool size. |
| Controls | Surface-command and mouse-playtest coverage for deal/draw, holds, bet controls, cheat controls, and double-up picks. |
| Hand evaluation | Fixture tests for Jacks-or-Better, Deuces Wild, and Double Double Bonus kicker rows. |
| RTP | Per-cabinet RTP audit inside declared sanity bands. |
| Determinism | Same seed + holds + inputs produces identical hands, payouts, and holdout outcome across replays. |
| Art parity | Captures show each cabinet as a unique full machine using the same visual footprint as slot cabinets. |
| Feel | Manual playthrough confirms the rhythm is obvious, hands differ, controls respond, wins land, and the holdout reads as a real video-poker cheat. |
