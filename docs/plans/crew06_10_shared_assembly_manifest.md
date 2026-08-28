# crew06_10 shared assembly manifest

Frozen contract: `a2760d816c781e711ff0923c296f97b786662453`  
Implementation branch: `codex/crew06_10-impl`

This row does not edit Crew or world models, EventModule, env06_6, shared game
catalogs, master probes, the 0.6 board, or owner artifacts. Integrator assembly:

1. Register `data/games/rituals/crew06_10_poker_nights.json` with the accepted
   `game_ritual/1` catalog.
2. Set `crew_poker_turn_engine: ordered_v1` and one authored
   `crew_poker_night_id` on the five scenario packages. Unregistered tables
   preserve the landed `legacy_v1` behavior until assembly is atomic.
3. Route `crew_poker_public_facts` into env06_6 only at the receipted game-action
   boundary. Scenario runtime owns room aftermath and route authority.
4. Add `scripts/tests/foundation/crew06_10_depth_contract.gd` to the shared
   foundation shard inventory without changing its row-local proof.

Row payload:

- `scripts/games/crew_draw_poker.gd`
- `data/games/rituals/crew06_10_poker_nights.json`
- `scripts/tests/foundation/crew06_10_depth_contract.gd`
- `docs/plans/crew06_10_shared_assembly_manifest.md`
- `docs/plans/crew06_10_policy_and_turn_engine.md`

The Turn compatibility remains the existing neutral
`tell_learned(member_id)` seam. No hidden condition or learned counter enters
the public surface, action history, fact payload, or ritual definition.
