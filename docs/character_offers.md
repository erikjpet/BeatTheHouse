# Optional character offers

`data/environments/character_offers.json` attaches optional attributes to existing
fixed characters in `placement_surfaces.json`. It does not create characters,
physical objects, manifest actions, services, employment, or quest state.

Each definition declares one canonical `character_id`, an `id`, exact dialogue
and accept/decline labels, and `hosts` mapping archetype IDs to fixed object IDs.
The initial catalog has one offer per canonical character. Chance is an integer
percentage. Effects use shared fields: `minutes`, `cash_cost`, `cash_reward`,
`required_item_id`, `drunk_reduction`, `pending_reduction`, and `heat_reduction`.
Eligibility uses `requires_alcohol`, `min_heat`, and
`minimum_minutes_before_close`. `item_summary` must disclose benefits lost when
selling an item. `free_home_ride` enables the shared actual-home travel flow,
with an authored `shift_end_minute` and `window_start_minute`.

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
sales inspect carried entries only, skip reserved entries and remove exactly one.

The ride preview simulates the wait and normal route duration on a fully
detached run. It requires the actual active home to remain available through
arrival and displays its name, wait, departure, duration and arrival. Acceptance
rechecks the plan and runs claim, wait and comped canonical travel under one
lifecycle rollback boundary. The travel path checks the expected active home
before installing it and before autosaving. There is no generic-home fallback.

## Focused qualification

Run in the qualified Godot 4.6.0 environment:

```text
godot --headless --path . --script res://scripts/tests/character_offers_check.gd
```

This contract exercises deterministic saved successes/misses, eligibility,
expiry, shared Dot cycles, exactly-once action effects, stale responses,
inventory ownership and canonical clock consequences, including Iris forecast
and arrival safety. Source-only parsing does not replace native qualification.
No animation scheduling or rendering cadence is changed by the offer layer.
