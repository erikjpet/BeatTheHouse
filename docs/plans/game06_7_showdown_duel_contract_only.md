# game06_7 SHOWDOWN-DUEL contract-only staging

Status: **UNREVIEWED / clean-parked / dependency-held**

Base: frozen `game06_1` vocabulary head `a2760d81`. Integration is held until
accepted `game06_1` and `game06_2` successor heads exist. This branch consumes
no rejected runtime and changes no shared ritual, blackjack, environment, crew,
world, assembly, or board file.

## Immutable authority and outcome ladder

The duel ritual is a presentation projection. It never calculates a card,
transfer, cheat roll, heat change, route, reward, or terminal outcome. Those
values remain owned by `GrandCasinoShowdownModel`, `GrandCasinoDuelModel`, the
blackjack settlement adapter, and `RunState`.

| Authority input | Frozen before condition | Contract-only after condition |
| --- | --- | --- |
| Invitation gate | `grand_casino_invite` remains the invitation flag | Read-only; no ritual transition writes or bypasses it |
| Clean route | `high_roller_cashout` through the Players Card review | Separate clean-ending staging id; route and rewards untouched |
| Crew route | `crew_heist` seam route | Separate crew-ending staging id; consumes public crew projection only |
| Showdown route | `pit_boss_showdown` | Read-only terminal route reference |
| Walk out clean | margin `>= 12`, or Rourke stack reaches zero | `walk_out_clean`; cashout/victory authority unchanged |
| Shown the door | margin `>= -60` and `< 12` after the fifth hand | `shown_the_door`; victory and retained-chip authority unchanged |
| Taken out back | margin `< -60`, or player stack reaches zero | `taken_out_back`; `casino_taken_out_back` failure unchanged |
| Pat-down failure | blatant tier: at least three contraband, or watched cheat plus contraband | Immediate existing failure; presentation cannot soften it |
| Duel length | ends on stack zero or after at most five hands | Read-only `hand_index`/`hand_limit`; no dramatic timer |
| Base stake | ante 20; serious pat-down adds forced ante 5 | Read-only authoritative ante |
| Rourke edge | 10% plus 20% per cheat level | Read-only edge/result reference |
| Edge call | correct swing 18; false call cost 6 | Controls forward the existing action only |
| Player cheat | detection 55% + 5% per aggression + 5% per cheat level; caught cost 18 | Existing result/heat facts only; no presentation roll |

The model fallback `shown_the_door_min = -8` is not used to redefine shipped
content: `data/events/events.json` supplies the authoritative `-60` threshold.
The preservation proof must test the data-backed thresholds as well as early
stack-zero outcomes.

## Staging phase graph

The contract projects the shipped encounter through stable, receipt-bound
presentation phases:

1. `approach` — Rourke's call and the walk; only the shipped walk response is
   accepted.
2. `seating` — pat-down result, chair, table, rail, and visible current stakes.
3. `response` — three saved interrogation beats; evidence and responses remain
   authoritative references.
4. `commitment` — one duel hand's existing blackjack commitment controls.
5. `reveal` — the authoritative hand/edge result is made legible.
6. `phase_break` — a receipted transition between hands; it cannot deal or
   settle.
7. `crowd_change` — actors, rail, staff, and security derive from the current
   ladder state at the same action boundary.
8. `outcome_staging` — exactly one authoritative duel or route ending.
9. `exit` — terminal acknowledgement with no economic or narrative mutation.

Every transition requires an accepted frozen-envelope action or an existing
authoritative result receipt. Entry operations and one-shot dialogue/audio use
their own receipt keys. Reentry restores a legal phase and drains only effects
whose receipts are absent.

## Public projection and hidden information

Rourke behavior is derived only from public duel fields: status, hand index,
hand limit, stacks, margin, aggression, current public edge/call result, last
bark, and terminal outcome. The bounded states are `arrival`, `confidence`,
`pressure`, `tilt`, `respect`, `contempt`, `suspicion`, and `realizing_loss`.

The room projection derives crowd tier, rail posture, staff posture, security
presence, table state, and exit state from those same public fields. Crew actors
may be projected only from an explicit public crew-presence list supplied by
the accepted crew seam. Private Turn identity, eligibility, rolls, alternative
members, and unrevealed contradiction state are forbidden inputs and forbidden
output keys.

## Row-local deliverables

- a versioned SHOWDOWN-DUEL ritual contract and immutable ladder table;
- a pure projection model for staging, controls, actor/object state, and public
  persistence — never settlement;
- executable contract tests for phase reachability, receipt/replay safety,
  ladder preservation, ten-seed determinism, hidden-state noninterference,
  native/Web canonical parity, accessibility, and bounded liveness;
- visual proof for every staging phase, all three duel rungs, clean and crew
  endings, maximum crowd, cheat/call state, crew presence, reduced motion,
  small screen, and colorblind presentation.

No integration or accepted-ready handoff is possible from this lineage alone.
The final candidate must be replayed onto accepted `game06_1` and `game06_2`
successors without importing any rejected runtime commit.

## Park manifest

- Canonical closed-shape artifact:
  `data/games/showdown_duel_game_ritual_v1.json` (`game_ritual/1`).
- Row-local design declaration:
  `data/games/showdown_duel_ritual_v1.json`
  (`showdown_duel_projection/1`). It carries the immutable outcome authority
  and privacy clauses without extending the canonical vocabulary shape.
- Pure staging projection:
  `scripts/core/grand_casino_duel_ritual_projection.gd`.
- Executable row proof:
  `scripts/tests/foundation/game06_7_showdown_duel_contract.gd`.
- Surface evidence and manifest:
  `docs/plans/evidence/game06_7_showdown_duel/`.

Frozen vocabulary conformance passes with all 72 negative fixtures and five
neutrality targets. The row-local proof passes all nine staging phases and ten
deterministic seeds. Native and Web semantic reports have identical canonical
SHA-256 `0fbde506dcf5395a82d0801e5fd52a509b1296ae35339a9cf3d90345b57c385a`.
Native measured 500 serializations in 215.31 ms with 5.92 ms maximum idle;
throttled Chrome measured 1327.935 ms with 39.72 ms maximum idle.

This park is deliberately **not** an accepted-ready head. The Integrator must
receive a newly replayed immutable product head after both accepted dependency
successors exist; this branch remains preserved as contract-only staging.
