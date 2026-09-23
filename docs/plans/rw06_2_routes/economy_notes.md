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
passed. Seven 2026-09-23 current-main exploratory clean probes then accepted PLAY
and publicly observed the tutorial Apartment at $80 / 0 Heat. The first stopped
after one counted action on tutorial replay policy; the second stopped after
four because the run menu needed semantic scroll; the third stopped after six
because a partially clipped button was mistaken for a fully rendered target;
the fourth proved full visibility and stopped after seven because the harness
had not released its wheel-button input before clicking; the fifth proved that
release, visibly opened the confirmation, and stopped after seven because the
dialog's internal OK/Cancel controls were not yet public; the sixth exposed the
controls, selected exact OK, and stopped after eight because its Window-local
coordinates were injected into the root Viewport; the seventh disproved direct
child-Window injection and established the need for a Window-position offset
through the root embedder. Every failure happened before a route economy
decision and is a replay-policy/bridge finding, not product economy evidence.
Therefore there is not yet an honest route money curve or tuning recommendation.
The subsequent embedder-correction launch failed GDScript parsing before
readiness or any player action, so it adds no eighth economy observation.
The next authorized launch was then cut off by its caller's five-second outer
timeout before the engine's normal nine-second readiness publication. It also
issued no gameplay command and adds no economy observation; the exact session
was closed gracefully with empty stderr and zero surviving Godot processes.
The following attached launch reached the confirmation after seven actions but
failed on a nonexistent dialog-parent viewport method before OK input. It adds
no route economy observation; its bounded cleanup exited without force and
left zero Godot processes while the API correction proceeds engine-free.
The next probe finally reached normal play: the seeded run began at $100 and
the first natural Back Alley to Gas Station Casino trip cost $7 and raised heat
from 0 to 1. A clipped Dealer's Advice CTA stopped the run at action 15 before
any game or Clean-ladder decision, so this is a preliminary visible checkpoint,
not yet an affordability or tuning conclusion. Its money-curve SHA-256 is
`DEE1A481172A67DBC49A4796534265736933D69713A4A6E2EB3AD614E2B3ED43`.
The following fixed-seed probe continued naturally through Gas Station ($93,
heat 1), Motel ($87, heat 0), Roadside Bar ($79, heat 0), and Kitty Cat Lounge
($63, heat 2), where the visible High Roller Invitation appeared. That is $37
of travel spend before accepting the invitation. Cash is below the nominal $70
Grand Casino travel cost, but the invitation's effect on that cost is not yet
observed; therefore this is an affordability signal, not evidence of an economy
wall and not a tuning recommendation. The run stopped on an exact-action replay
policy defect before accepting the clearly rendered choice. Its money-curve
SHA-256 is
`B0BC21CEF1AFCC823237881BAD87C8618EC03E691AE7F66DE2C96C1B12D56867`.
The next probe accepted that invitation and proved it does not waive the $70
fare. The fixed route was therefore $7 short at Kitty Cat Lounge. This is not
yet a hard economy wall: Roulette and Slot were visibly available, so normal
play could earn the shortfall. A product presentation defect hid the disabled
Grand route behind the three-card cap; rw06_2 now keeps the event-unlocked card
visible with its affordability reason without changing any number. The old
replay then spent another $16 reaching Delta Queen ($47, heat 3) instead of
surfacing the shortfall; it now fails closed before that waste. Probe money
curve SHA-256 is
`7E552A23EE8A2BD5C49E42B832896FEE864C1E8276517E0DE4267B23EA1FFF1D`.
The smallest data-only lever, if normal-play earning later proves impractical,
would be a travel-cost or starting-cash adjustment in rw06_3. Do not apply it
from this single seed before the replay measures the earning path.
Copy the exact values from the qualifying route summaries into this table:

| Ending | Seed | Start cash | Grand entry cash | Lowest cash | Chips bought | End cash | Peak heat | Counted actions | Friction / rw06_3 recommendation |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Clean | `RW06-CLEAN-ROUTE-01` | pending | pending | pending | pending | pending | pending | pending | pending |
| Cheat | `RW06-CHEAT-ROUTE-01` | pending | pending | pending | pending | pending | pending | pending | pending |
| Crew | `PLAYTEST-CATALOG-01` | pending | pending | pending | pending | pending | pending | pending | pending |

No rw06_3 data change is recommended until these public curves exist. If a
route fails from variance or affordability, preserve the failing curve and name
the smallest data-only lever; do not tune against a hypothetical number.
