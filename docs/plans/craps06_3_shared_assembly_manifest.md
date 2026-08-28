# craps06_3 shared assembly manifest

Implementation branch: `codex/craps06_3-impl`
Frozen ritual contract: `a2760d816c781e711ff0923c296f97b786662453`

The row deliberately makes no shared-catalog, shared-index, master-probe, or
scenario-runtime edit. The Integrator should apply the row payload by
three-way merge, then make these shared registrations in its assembly branch:

1. Register `data/games/rituals/craps06_3_sequences.json` with the accepted
   `game_ritual/1` definition catalog when that shared consumer lands.
2. Add `scripts/tests/foundation/craps06_3_depth_contract.gd` to the shared
   foundation shard inventory without modifying the test itself.
3. Route each `craps_public_facts` record into env06_6 at the game-action safe
   boundary. The scenario runtime owns room aftermath; Craps owns no route or
   scenario lifecycle mutation.
4. Bind the five profile ids to authored environment packages. No game-id
   branch belongs in shared runtime code.

Row-local payload paths:

- `scripts/games/craps.gd`
- `data/games/rituals/craps06_3_sequences.json`
- `scripts/tests/foundation/craps06_3_depth_contract.gd`
- `docs/plans/craps06_3_shared_assembly_manifest.md`
- `docs/plans/craps06_3_bet_matrix.md`

Files intentionally not touched include `data/games/games.json`, shared game
catalogs/indexes, shared master probes, env06_6, env06_7 assembly files,
crew/world models, the 0.6 board, and `main`.
