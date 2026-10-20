# Ox route advice and Rafi ride

This separate delta starts at `4508442d832269dcd3076fe7fb7e9a684f7112d9`
on `codex/optional-character-offers-batch-two`, preserving June and Sable.

Ox has a 20% shared game-day chance across both Punchline layers and Delta
Queen. Free, 15-minute advice grants the existing `route_scouting_active`
effect when canonical scouting is absent. That effect currently lasts for the
rest of the run. It grants detailed previews without adding destinations,
access, items or home changes.

Rafi hosts the Bar-to-Grand-Casino ride. It costs exactly $5 in total and uses
normal canonical route duration and consequences. Coffee retains priority when
eligible. Both alternatives share one saved 20% Bar operating-cycle roll and
one persisted selection/claim. An invalid ride cannot select the alternative;
later access can bind that same winning roll, without rerolling. Once selected,
eligibility changes cannot switch alternatives.

The ride preview names the actual destination and shows fare, departure,
duration and arrival. Invitation, visibility, progression, travel locks,
available cash and arrival hours remain required. One lifecycle transaction
owns claim, clock, install and fare. Rejected installation restores all state
without autosaving or replaying travel from before the claim. Paying the last
$5 completes the trip, then evaluates the canonical zero-funds ending.

## Focused native qualification

Official Windows Godot 4.6 stable, `89cea1439`:

- `character_offers_roads_and_ride_check.gd`: **61 assertions, zero failures,
  exit 0**, elapsed **15.456 seconds**.
- `character_offers_batch_two_check.gd`: **151 assertions, zero failures,
  exit 0**, elapsed **7.024 seconds**. The former assertion that Ox was
  unapproved was removed; fixture bindings now support host arrays.

The new contract covers scouting ownership and duration, saved rolls and
claims, expiry, shared venue cycles, alternative priority, invalid routes before
selection, invitation/visibility/progression/lock/cash gates, exact fare with an
ordinary Rook fare modifier, actual canonical travel, normal duration without
extra action turns, save/load, stale callbacks and rejected-install rollback.
The rejected-install fixture advertises a real scenario publication failure so
the old scenario-suppression retry would be eligible; offered rides must avoid
that retry and return to their transaction owner.

Each command had a 45-second watchdog and isolated test storage. No browser or
rendered game was launched. Console launcher priority/affinity metrics do not
measure the engine child and are not CPU or memory qualification. Both commands
printed the existing Windows root-certificate-store warning; neither contract
requires network access. Source parsing and `git diff --check` also passed.

## Integration dependency

This branch still descends from `b82b84b9dec4a0a158a6ef6e758540c49ce56afd`.
It does not contain the separately cloud-qualified first-batch cache/signature
and fixture patch (qualified combined tree
`e784898e90d8d5f0f07ebce3beafdf93e59d9def`). Integrate the separate June/Sable
commit and this delta onto that qualified line, preserving its fixes, then run
focused combined projection/cache checks. This record does not claim main/NEXT
publication or visual Web qualification.
