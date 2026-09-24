# rw06_2 economy handoff

Status: **PROBE 29 MEASURED; GRAND INVITATION REPAIR IMPLEMENTED; POST-CHANGE/QUALIFYING CURVES PENDING**
Working base: current rw06_2 peer branch
Owner: rw06_3 (data-only tuning after rw06_2 produces qualifying traces)

Do not change game rules, RNG, odds, payout math, wager math, or RTP from this
document. These are route constraints and measurements for the rw06_3 balance
pass. The committed replay writes every visible bankroll/chip/heat/clock change
to `money_curve.ndjson` so the live handoff can be updated without reading save
files or private run state.

## Current balance decision

Probe 29 now supplies one exact public fixed-seed Clean measurement. It is
exploratory rather than qualifying because the worktree carried the acknowledged
unstaged Pixel dependency and the engine reported an ObjectDB leak warning, but
the public economy failure itself is specific and reproducible:

`$100 -> $108 -> $101 -> $95 -> $105 -> $97 -> $81 -> $126`.

The run stopped at action 63 with `$126`, a displayed current-stop Grand fare of
`$95`, and the replay's immediate `$50` chip reserve: `$145` required and a
measured `$19` shortfall. This replaces the earlier engine-free `$33` estimate.
Because Probe 19 also recorded 24 straight `$2` Slot losses, a gambling win is
not a deterministic recovery route. rw06_3 therefore implements one data-only
Grand invitation package: accepting grants the explicitly disclosed `$50`
first stake, and Grand travel is free from the two normal invitation venues
(`kitty_cat_lounge`, `delta_queen`) plus the Q-011 `beach` detour. Other origins
retain the positive base fare; game numbers and payout tables do not change.
Exact before/after arithmetic is logged in `docs/plans/rw06_3_balance_changes.md`.

If Clean later exceeds the 350-action release budget or repeatedly bankrolls
out after reaching Grand, inspect the three Players Card segment thresholds
before touching game odds or payouts. If The Count exceeds the same budget,
inspect Bishop's route-local job trust rewards before global rank thresholds.
These are ordered diagnostic levers, not approved changes. Preserve Probe 19's
24 consecutive `$2` Slot losses (`$63 -> $15`) as evidence that gambling is not
a deterministic recovery policy.

## Known numeric pressure

| Route | Required visible economy | First-pass risk to measure |
| --- | --- | --- |
| Clean / Players Card | Verify the invitation's disclosed +$50 grant and the $0 Grand trip from Kitty Cat Lounge, Delta Queen, or Beach; without an existing Rook discount, any other origin keeps its rendered positive fare. Qualifying segments are Bronze: 1 settled game and +$5; Silver: 3 and +$15; Gold: 5 and +$30. Each segment must stay at or below 30 heat. This is at least 9 settled games and +$50 aggregate Grand net winnings. | Record entry cash/chips, hands required, deepest drawdown, refills at Linda, and whether a basic-strategy player can finish without an exploit or a long variance grind. |
| Cheat / Pit Boss | Verify the same invitation grant/eligible-origin comp through the public route and retain enough ordinary chips only for the pre-showdown trigger hands. The five-hand Rourke duel uses internal stacks. The intended dirty-money trigger needs a visible cheat plus at least +$30 Grand net winnings; public heat alternatives are 70 for staff attention and 95 forced. A duel margin of at least -60 is a win. | Record cash/chips when Rourke triggers, the cost of provoking him, the internal five-hand duel margin curve, and whether the successful `shown_the_door` rung reads as a win. |
| Crew / The Count | Verify the applicable rendered Grand route price. Identity setup requires one settled blackjack wager of $8-$30 on each of three distinct visits, with heat peak at or below 35 and the rise from starting heat strictly below 35. The first-pass route acquires 125 chips before setup/play and settles three additional live-play rounds at $8-$30. | Record income from the Crew favor/Bishop-job ladder, travel and package costs, chip purchases, total setup bankroll floor, heat peak, and getaway cash. Flag any >25-action stretch without new income or a new goal. |

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

Probe19 then measured the attempted earning path without changing any game
number. Storm made the visible Grand fare $109, not the nominal $70. Starting
from $63, 24 lowest-stake $2 Slot spins all lost and ended at $15, so this exact
slot-only policy spent $48 without progress. That is severe variance friction
for rw06_3 to retain, but it is not yet a tuning recommendation or a product
softlock: the replay had bypassed public deterministic liquidity. The same run
had shown the Crew lender at the opening Alley, the Brother-in-Law lender at the
Motel, and $8/$10/$6 positive-cash event options along its scouting route; the
invitation room still showed the Crew, Roulette, Slot, and enabled travel.
Source-owned public terms offer $45 for two Crew favors and $30 for $33 family
repayment, while outside debt does not remove Players Card eligibility.

Classify this sample as **public recovery omitted + replay action-budget
limitation**, not as a confirmed Clean economy wall. rw06_2 should first replay
a strict visible funding route and reserve the $50 needed by the current clean
chip helper after the displayed fare. If that public route still cannot reach
and sustain Grand across qualifying/fresh seeds, hand rw06_3 the smallest
data-only adjustment with the failed curves. Probe19 summary/trace/curve hashes
are `AF647469BC70A4CEB63F3F3287D32B96A8E796077CAC35E66DF774BE030DD824`,
`F72B12BA13A315E5FDD6D3F4B857B1FF2869ADC85FF8F2BD3756D810DC2A1D81`,
and `1BB9E5CC5033717D1BB9E1AB3DB8855BF540A1D672C560967B748BD09DFEB6EA`.

The recovery implementation now treats the displayed fare plus $50 as its
target. That reserve comes directly from the Clean route's immediate
`Ensure-GrandCasinoChips -Minimum 50` call, not a tuning proposal. Lender
principal and repayment are parsed from a fully rendered TalkDock and verified
against the rendered bankroll, Result feedback, and debt-indicator count. The
public HUD does not expose authenticated debt identities or balances, so the
replay requires the count to increase by exactly one and attempts Crew funding
only from a visibly debt-free state; it never infers a Crew-favor merge. Inline
event copy identifies a positive-cash choice but does not display +8 or +10, so
those source values never drive selection. The post-action check binds the exact
allowlisted Result message to the observed positive bankroll and heat deltas.

The replacement source matrix is green: machine jam 2 valid/20 hostile, funding
8 valid/59 hostile, and cash events 2 valid/39 hostile. The valid funding cases
include the production-shaped Back Alley Crew/street pair and Motel
brother/friend pair, including the disabled-brother branch. `machine_jam` always
chooses the exact visible de-escalation copy, **Wait it out**, with no hidden
cash/heat inference. These are engine-free policy results. The expanded Godot
public-observation contract passed under its serialized lease; the next live
route remains pending a separate serialized engine lease.

Source data alone cannot certify affordability after all travel. In Probe19's
public state, $63 plus Kitty Crew ($45), minus the displayed $16 trip to Delta,
plus Delta Crew ($45) yields $137 against a $159 fare-plus-reserve target before
another stop. Back Alley then offers one generated $25/$45 lender and may show
the +$8 event; Motel may offer $20/$30 and may show the +$10 wedding event, but
their presence and intervening fares are generated. The next live route must
measure the actual visible sequence. If it exhausts the bounded sources below
the recomputed target, preserve that public curve as a classified exploratory
finding for rw06_3; do not change economy data or gates in rw06_2.

Copy the exact values from the qualifying route summaries into this table:

| Ending | Seed | Start cash | Grand entry cash | Lowest cash | Chips bought | End cash | Peak heat | Counted actions | Friction / rw06_3 recommendation |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Clean | `RW06-CLEAN-ROUTE-01` | 100 | blocked before entry at 126 | 81 | 0 | 126 at stop | pending | 63 | Probe 29: $95 fare + $50 reserve left a measured $19 shortfall; invitation grant/comp repair pending replay. |
| Cheat | `RW06-CHEAT-ROUTE-01` | pending | pending | pending | pending | pending | pending | pending | pending |
| Crew | `RW06-HEIST-AUDIT-0002` | pending | pending | pending | pending | pending | pending | pending | Q-013 natural Audit/Count fixed route; live curve pending. |

The Grand invitation package is the sole current rw06_3 change. Do not tune
another value until this package is replayed and the Cheat/Heist public curves
exist. Preserve every failing curve and continue choosing the smallest
data-only lever; never tune against a hypothetical number.
