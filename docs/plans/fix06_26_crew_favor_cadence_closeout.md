# fix06_26 — Crew favor cadence closeout

Status: **DONE (timeboxed contained wiring fix)**

## Result

The successful Crew lender action already created the `+45` bankroll change and
favor debt. The follow-up event was blocked before probability in two places:

- its pooled speaker inherited `environment_actor=true`, so the action shortlist
  excluded it in home/recovery rooms;
- it used the ordinary quiet-visit budget even though it is an explicit debt
  call.

`crew_favor_delivery` now declares `environment_actor=false` and
`cadence.bypass_budget=true`. No money, odds, RNG, payout, schema, migration or
event chance changed.

## Evidence

`fix06_26_crew_favor_cadence_contract.gd` passes the production-facing
boundaries: the event is present in the home/action shortlist,
`EventModule.can_trigger()` accepts it with the due flag, and
`RunState.event_cadence_allows_world_event()` accepts it. A diagnostic rerun of
the existing composition producer then rolled `32` against the unchanged `45%`
chance and queued the Crew favor.

The broader Systems shard retained seven pre-existing `family_loan` assertions
and exceeded its aggregate time allowance. None names or contradicts the new
Crew-favor contract; the focused contract is the binding row evidence.

## Deferred finding

After the Crew event queued, the previously red full composition route advanced
farther and rejected a revisit whose scenario semantic digest predated a Crew
rank mutation. That is a separate maximal-composition/revisit integration
finding. The owner explicitly deferred the full composition matrix and directed
this row to remain timeboxed, so it is retained for refinement and is not called
green. It does not change the playtest-build acceptance bar.
