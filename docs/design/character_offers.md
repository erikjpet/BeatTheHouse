# Optional character offers

`data/environments/character_offers.json` attaches optional attributes to existing
fixed characters in `placement_surfaces.json`. It does not create characters,
physical objects, manifest actions, services, employment, or quest state.

Each definition declares one canonical `character_id`, an `id`, exact dialogue
and accept/decline labels, and `hosts` mapping archetype IDs to fixed object IDs
or arrays of fixed IDs when one character occupies different room layers.
Alternative definitions for a character share one saved operating-cycle roll
and decision. Lower `alternative_priority` values are preferred; the first
eligible alternative is selected once for that cycle. Subsequent eligibility
changes cannot switch that saved decision or provide a second reward.
Chance is an integer percentage. Effects use shared fields:
`minutes`, `cash_cost`, `cash_reward`,
`required_item_id`, `inventory_add_item_id`, `drunk_reduction`,
`pending_reduction`, and `heat_reduction`.
Eligibility uses `requires_alcohol`, `min_heat`, and
`minimum_minutes_before_close`. `requires_no_route_scouting` requires the
canonical scouting level to be zero. The generic `flags_set` dictionary uses
the existing GameModule flag convention. Ox sets `route_scouting_active` to
enable detailed travel previews for the rest of this run. It does not grant an
item, additional destinations or access. `effect_summary` discloses the
player-facing result of an authored flag grant. `excluded_carried_item_id` hides an offer when
any matching item is carried, including reserved or dictionary-backed entries;
it does not inspect or change home storage. `item_summary` must disclose the
consumed item and its removed effect. `item_gain_summary` discloses the item and
benefit received through `inventory_add_item_id`. A definition with both
`required_item_id` and `inventory_add_item_id` is a generic item recipe: consume
exactly one available carried input and grant one output atomically.
`free_home_ride` enables the shared actual-home travel flow,
with an authored `shift_end_minute` and `window_start_minute`.
`ride_target_node_id` enables an immediate ride to an existing canonical world
destination. Both ride types require a valid route preview before an offer is
displayed or an alternative is selected; an invalid route cannot consume the
character's selection for that cycle.

`CharacterOfferModel` derives one independent deterministic roll from the run
seed, canonical character, and operating cycle. Both winning and missed rolls
are stored in `RunState.narrative_flags.character_offer_cycles`; normal run
saves, snapshots, rollback and codec paths therefore retain the same authority.
Nested records are replaced on write to preserve in-flight save snapshots.
The gameplay RNG is never consumed by this feature.

`cycle_archetype_id` uses `EnvironmentHours.operating_cycle_id`: overnight hours
belong to their opening day, while 24-hour venues rotate at midnight. Dot uses
explicit `cycle_hours` of 11:00–05:00, from the earliest opening to the latest
close across her three venues. Her roll and claim are shared across them.
Sable and Ox each use the always-open `small_underground_casino` cycle across
their venues, giving each character one shared game-day roll and claim. Their
current venue must still be open, and Sable's 45-minute repair must finish
before that venue closes.

## Item offers

June's `june_spare_watch` offer appears on the existing `motel:june` character
with a 25% daily chance. It costs $5 and 15 minutes, requires $5 cash and no
carried Pocket Watch, then grants one `pocket_watch`. Its existing item benefit
shows the exact minute on the HUD clock. The player stays at the motel.

Sable's `sable_cufflink_repair` offer has a 20% daily chance and costs no cash
and 45 minutes. It is bound to `punchline:casino_dealer` in Punchline's hidden
casino layer and `delta_queen:right_table_dealer` on the Delta Queen. No offer
is shown in Punchline's public club layer, where that physical host is absent.
It requires an available, unreserved carried `broken_cufflinks` and no carried
`coolers_cufflinks`, consumes exactly one broken pair and grants one repaired
pair while the player stays in the venue. The removed broken pair narrows the
Blackjack peek window to 50% of normal. The repaired pair absorbs the Heat from
one failed Blackjack peek, then becomes Broken Cufflinks; it does not prevent
the other consequences of being caught. The item's numeric absorb value `1`
enables this single use, rather than limiting the protection to one Heat point.
Reserved items, collateral and home storage cannot supply the repair input.

June and Sable use the same saved roll, eligibility, preview, claim and
transaction paths as the first batch. No character-specific core branch,
standalone character, quest or employment system is added.

## Rafi's alternative ride

Rafi's `rafi_grand_casino_ride` is attached to his existing `bar:bartender` host.
It shares the coffee offer's 20% roll and the Bar's operating cycle. Eligible
coffee has priority `0`; the ride has priority `10` and can be selected when
coffee is ineligible. Only the selected offer label is shown, and accepting or
declining either consumes Rafi's shared cycle. A cycle that has already selected
coffee cannot later produce the ride, or the reverse.

The ride costs exactly $5, departs immediately, and applies the normal route's
travel time and consequences to the Grand Casino. The preview shows the
destination, fare, departure, duration and arrival before acceptance. It uses
the existing route and travel APIs without granting access or changing the
player's home. There is no additional default action-time charge.

The offered $5 fare replaces the ordinary route fare; it is charged once by
the existing travel result. Invitation, visibility, route locks and arrival
hours still apply. The ride cannot reveal or unlock an unavailable Grand Casino.
Acceptance rechecks the displayed plan and owns one rollback boundary across
the claim, clock advancement, destination installation and fare. A rejected
travel or arrival consequence restores the claim, time, cash and prior room.

## Ox's route advice

Ox's `ox_knows_the_roads` has a 20% daily chance, costs no cash and takes 15
minutes. It uses his existing `punchline:club_bouncer` and
`punchline:casino_bouncer` hosts in Punchline's public club and hidden casino,
plus `delta_queen:deck_boss` on the Delta Queen. These share one canonical Ox
roll and claim, including transitions between the two Punchline layers.

The offer is eligible only when `RunState.travel_scouting_level()` is zero.
Acceptance grants the existing detailed route-preview effect for the remainder
of the run and keeps the player in the venue. Existing item or service scouting
suppresses the offer. It does not change the player's inventory, home, access
permissions or number of route choices.

## Shared lifecycle

Rolls are remembered while the character is present even if an eligibility gate
currently fails. A winning roll can become eligible during that visit. Accept
and decline consume the cycle; an unclaimed offer expires on departure or close.
Current-cycle reentry cannot reroll. A new operating cycle permits one new roll.
Tutorial and practice presentation do not show these optional offers.

The interaction controller decorates the final authenticated host record after
room/scenario composition. Existing attached actions and sealed geometry remain
intact. Confirmation shows the exact dialogue, all costs, duration and effects.
Selection tokens bind cycle, visit, clock and relevant player state. Responses
revalidate both the current token and the owning popup.

Non-travel effects execute on a detached host action candidate and publish once.
They call `advance_game_clock_minutes` for their stated time without adding
environment turns, preserving delivery deadlines, home/rent rollover and ATM
interest. Recovery uses canonical RunState helpers, including exact Heat
reduction during intoxication and independent pending-alcohol recovery. Item
sales and recipes inspect carried entries only, skip reserved entries and remove
exactly one. Item grants use the existing canonical inventory and effect APIs;
the recipe's output exclusion prevents consuming an input when its unique
output is already carried.

## Iris's home ride

Iris's ride preview simulates the wait and normal route duration on a fully
detached run. It requires the actual active home to remain available through
arrival and displays its name, wait, departure, duration and arrival. Acceptance
rechecks the plan and runs claim, wait and comped canonical travel under one
lifecycle rollback boundary. The travel path checks the expected active home
before installing it and before autosaving. There is no generic-home fallback.

## Focused qualification

Run in the qualified Godot 4.6.0 environment:

```text
godot --headless --path . --script res://scripts/tests/character_offers_check.gd
godot --headless --path . --script res://scripts/tests/character_offers_batch_two_check.gd
godot --headless --path . --script res://scripts/tests/character_offers_roads_and_ride_check.gd
godot --headless --path . --script res://scripts/tests/character_offer_canvas_actions_check.gd
godot --headless --path . --script res://scripts/tests/character_offers_cache_check.gd
godot --headless --path . --script res://scripts/tests/animation_liveness_without_pointer_check.gd
```

This contract exercises deterministic saved successes/misses, eligibility,
expiry, shared Dot cycles, exactly-once action effects, stale responses,
inventory ownership and canonical clock consequences, including Iris forecast
and arrival safety. The roads-and-ride contract covers Ox's scouting gate,
shared host cycles, Rafi's persisted alternative selection, invalid routes,
the exact offered fare and rejected-travel rollback. Source-only parsing does
not replace native qualification.
No animation scheduling or rendering cadence is changed by the offer layer.
