# Video Poker Reference: Real-Machine Spec

This document is the implementation spec for the complete video-poker rebuild. It records the real casino-machine rhythm the game must prove in code, tests, captures, and manual acceptance.

## Machine rhythm

1. Bet: the player selects one to five coins per hand. Five coins is the standard max-bet state and carries the royal-flush jackpot column.
2. Deal: one five-card base hand is dealt face-up from a freshly shuffled 52-card deck.
3. Hold: the player toggles any subset of the five cards. Held cards must show an unmistakable `HELD` marker and stay locked through draw.
4. Draw: the primary button relabels from `DEAL` to `DRAW`. Non-held cards are replaced.
5. Evaluate and pay: the paytable stays visible, the active bet column remains highlighted, the winning row flashes, and credits/bet/win meters update.
6. Double-up: after a clean win, the player may gamble the win against a dealer card by picking one of four face-down cards. Higher doubles, equal pushes, lower forfeits; the chain is capped.

The primary action never changes position. Its label is the state machine:
`DEAL` while no hand is active, then `DRAW` after the opening five cards
arrive. Payout is automatic. A player should never search for a collect
button or wonder whether another click is required to receive a win.

The five-coin ladder is coins *per hand*, not a five-value total-bet menu.
Consequently:

- one-play total wager = denomination × coins;
- two-play total wager = denomination × coins × 2;
- three-play total wager = denomination × coins × 3.

Every generated denomination must permit all five coin levels at that
cabinet's fixed hand count. A machine that can afford one coin but silently
clamps Bet Max is invalid.

## Multi-hand rule

Multi-hand video poker is one base deal plus independent completion hands:

- One base five-card hand is dealt.
- Holds from the base hand apply to every hand.
- For one-hand play, the draw is normal draw poker: replacements come from the original deck after the opening five cards.
- For two- or three-hand play, each hand is completed from its own independent 52-card deck with only the held cards removed. Non-held base cards are discarded presentation cards and may reappear in any result hand.
- Each result hand is scored and paid separately; total return is the sum of result hands.
- The RNG stream for each hand must be deterministic, distinct, and replayable from the same run seed, machine state, holds, and action stream.

The visual model follows the same rule. Before DRAW, every lane may mirror the
shared base hand and must say that it is awaiting the common hold decision.
After DRAW, every lane must bind to its own final-hand array. Reusing the base
hand or best hand for all lanes is a renderer defect even if settlement data
is correct.

The required cabinet layouts are gameplay-first:

- one hand: one large row spanning the glass;
- two hands: equal side-by-side lanes;
- three hands: two lanes above and one centered below.

All hands remain on screen together. Each result lane names its evaluated
hand and individual pay, so a player can reconcile the summed WIN meter.

## Cabinets

The owner-locked cabinet roster is:

- Jacks or Better: one hand, 9/6 Jacks-or-Better paytable, retro-neon baseline.
- Double Deuces: two hands, Deuces Wild paytable, electric wild-card cabinet.
- Triple Double Bonus: three hands, Double Double Bonus paytable with kicker rows, premium gold high-roller cabinet.

Every cabinet must render as a full casino cabinet sibling to the slot machines: authored cabinet background, integrated control deck, visible paytable, card area sized for its hand count, and clear credits/bet/win meters.

The previous implementation baked empty controls and labels into cabinet PNGs
and then drew a second live UI on top. The rebuild forbids that split-brain
composition. Cabinet ornament, paytable, cards, meters, buttons, hit regions,
guidance, and result emphasis share one authored coordinate system. Decorative
art may frame live regions but may not duplicate or cover them.

Cabinet identities:

- Neon Jacks uses a cyan/magenta diner-neon chassis, alternating lamps,
  chrome rails, and a broad single-hand glass.
- Double Deuces uses a green/blue split chassis, electrical traces, deuce
  motifs, and balanced left/right hand windows.
- Triple Double Bonus uses a black/gold high-roller chassis, crown and coin
  ornament, and a deliberate two-over-one three-hand composition.

## Controls

The interface must support mouse and touch at 1280x720 and small-screen:

- Primary button: `DEAL` when idle, `DRAW` when a hand is active.
- Card taps: toggle holds, one hit target per card.
- Bet controls: bet-one / bet step and bet-max.
- Denomination button where available.
- Holdout controls while a cheat is armed.
- Double-up start and pick controls after a clean win.

Touch and mouse share the exact same registered rectangles. At both supported
screen sizes every live button is inside the cabinet control deck, card hit
regions do not overlap, and visual button state is derived from the same
enabled condition used to register its hit target.

First-player guidance is persistent and state-specific:

- idle: `SET BET` and `DEAL` are emphasized;
- hold: every card says `TAP` or `HELD`, and `DRAW` is emphasized;
- settled: the outcome headline names the winning hand or says `NO PAY`,
  every winning paytable row flashes, and automatic payout is stated.

## Cheat

The cheat is an in-draw holdout: during the draw, the player times a cabinet-flavored skill input and palms in a better card. It must:

- Use the shared deterministic skill economy: seeded ideal card, quality-to-heat/evidence tiers, item and alcohol modifiers.
- Happen during the draw flow, not as a separate off-machine minigame.
- Give blunt feedback naming the swapped card and resulting hand.
- Offer a reduce-motion single-input fallback.

The holdout is not a second poker game. It overlays the live draw glass,
preserves the cards and controls beneath it, and resolves through the same
DRAW action. The feedback contract is literal: it names the palmed card, the
slot replaced, and the resulting evaluated hand. Quality still maps to the
existing heat/evidence tiers and item/alcohol modifiers.

## Paytable audit

The cabinet roster is fixed:

| Cabinet | Evaluation | Required special cases |
| --- | --- | --- |
| Jacks or Better | 9/6 Jacks-or-Better | high pair floor; max-coin Royal column |
| Double Deuces | Deuces Wild | natural royal, four deuces, wild royal, five of a kind |
| Triple Double Bonus | Double Double Bonus | four aces with 2–4 kicker; four 2–4 with A–4 kicker |

The declared max-coin optimal-play references are separate from the finite
deterministic simulation of this game's concise recommendation policy:

| Cabinet | Locked schedule | Reference optimal RTP |
| --- | --- | ---: |
| Jacks or Better | 9/6 | 99.54% |
| Double Deuces | Illinois Deuces: 25/15/9/4/4/3 | 98.91% |
| Triple Double Bonus | 10/6 Double Double Bonus | 100.07% |

Reference checks: [9/6 Jacks or Better](https://www.purevideopoker.com/games/jacks-or-better/),
[Illinois Deuces schedule](https://videopokeredge.com/deuces-wild/pay-table/), and
[10/6 Double Double Bonus](https://www.readybetgo.com/video-poker/strategy/double-double-bonus-2698.html).

RTP sampling is a regression audit, not an outcome source. Outcomes continue
to use the injected deterministic stream and the declared paytable. The audit
records wager, gross return, win rate, and top hit per cabinet over the same
round count and fixed seed. The observed sample is labeled recommendation-policy
RTP; it is not misrepresented as perfect-strategy theoretical RTP.

## Animation and sound rhythm

- DEAL slides/flips the shared opening cards.
- Held cards lock with an unmistakable banner and border.
- DRAW reveals replacements as a short cascade while held cards remain fixed.
- Settlement pauses on each hand's reason, then emphasizes the matching
  paytable row and updates WIN.
- Larger aggregate wins increase light/flash emphasis without hiding cards or
  controls.
- Double-up shows the dealer card first and keeps four equal, obvious picks.

Reduce motion keeps state ordering and sound hooks but removes spatial
movement and lengthens the holdout input window. Rendering reads the module
snapshot; it does not copy decks or rebuild result data every frame.

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

The live proof capture must include, for every cabinet, idle, hold-guidance,
and settled-result frames. The three-play settled capture must contain three
different visible card signatures. A slot reference must be captured by the
same running-game harness; static sketches or empty wireframes are not valid
art evidence.
