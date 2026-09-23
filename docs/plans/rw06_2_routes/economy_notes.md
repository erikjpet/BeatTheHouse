# rw06_2 economy handoff

Status: **FIRST-PASS RULE AUDIT; LIVE ROUTE CURVES PENDING**
Source base: `7da3e5dab59b`
Owner: rw06_3 (data-only tuning after rw06_2 produces qualifying traces)

Do not change game rules, RNG, odds, payout math, wager math, or RTP from this
document. These are route constraints and measurements for the rw06_3 balance
pass. The committed replay writes every visible bankroll/chip/heat/clock change
to `money_curve.ndjson` so the live handoff can be updated without reading save
files or private run state.

## Known numeric pressure

| Route | Required visible economy | First-pass risk to measure |
| --- | --- | --- |
| Clean / Players Card | Preserve the $70 Grand Casino travel cost. Qualifying segments are Bronze: 1 settled game and +$5; Silver: 3 and +$15; Gold: 5 and +$30. Each segment must stay at or below 30 heat. This is at least 9 settled games and +$50 aggregate Grand net winnings. | Record entry cash/chips, hands required, deepest drawdown, refills at Linda, and whether a basic-strategy player can finish without an exploit or a long variance grind. |
| Cheat / Pit Boss | Preserve the $70 Grand Casino travel cost and enough chips for the five-hand fixed-ante duel. The intended dirty-money trigger needs a visible cheat plus at least +$30 Grand net winnings; public heat alternatives are 70 for staff attention and 95 forced. A duel margin of at least -60 is a win. | Record cash/chips when Rourke triggers, the cost of provoking him, five-hand duel drawdown, and whether the successful `shown_the_door` rung reads as a win. |
| Crew / The Count | Preserve the $70 Grand Casino travel cost. Identity setup requires one settled blackjack wager of $8-$30 on each of three distinct visits, with heat peak at or below 35. The first-pass route acquires 125 chips before setup/play and settles three additional live-play rounds at $8-$30. | Record income from the Crew favor/Bishop-job ladder, travel and package costs, chip purchases, total setup bankroll floor, heat peak, and getaway cash. Flag any >25-action stretch without new income or a new goal. |

## Live measurements still required

The first engine contract and the launcher detach/atomic-command regression
passed. Two 2026-09-23 current-main exploratory clean probes then accepted PLAY
and publicly observed the tutorial Apartment at $80 / 0 Heat. The first stopped
after one counted action on tutorial replay policy; the second proved that fix
and stopped after four counted actions because the visible run menu needed a
semantic scroll input to reveal **Skip Lessons**. Both failures happened before
any route economy decision and are replay-policy/bridge findings, not product
economy evidence. Therefore there is not yet an honest route money curve or
tuning recommendation.
Copy the exact values from the qualifying route summaries into this table:

| Ending | Seed | Start cash | Grand entry cash | Lowest cash | Chips bought | End cash | Peak heat | Counted actions | Friction / rw06_3 recommendation |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Clean | `RW06-CLEAN-ROUTE-01` | pending | pending | pending | pending | pending | pending | pending | pending |
| Cheat | `RW06-CHEAT-ROUTE-01` | pending | pending | pending | pending | pending | pending | pending | pending |
| Crew | `PLAYTEST-CATALOG-01` | pending | pending | pending | pending | pending | pending | pending | pending |

No rw06_3 data change is recommended until these public curves exist. If a
route fails from variance or affordability, preserve the failing curve and name
the smallest data-only lever; do not tune against a hypothetical number.
