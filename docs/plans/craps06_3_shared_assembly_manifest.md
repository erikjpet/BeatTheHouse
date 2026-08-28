# craps06_3 shared assembly manifest

Implementation branch: `codex/craps06_3-impl`
Frozen ritual contract: `a2760d816c781e711ff0923c296f97b786662453`
Rejected product head: `f5a30b19caad9669111bcd63fc23c72e2099634e`
Rejected handoff head: `1b8ae52c54c74d0c4308d2f148d5cbddfa6fb80e`
Remediation product head: `e8cc589e045d2b2262f98e68b474d869ead4382c`

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

## Remediation gate record

- Row-local executable contract: PASS. It executes all five profile sequences,
  the normal `craps_roll` legal boundary, deterministic save/revisit during an
  active roll, hostile double-roll rejection, exact return to betting, ten
  deterministic throw projections, pointer/keyboard equivalence, and material
  actor/object changes across all three energy tiers.
- Visual capture: PASS at 1280x720, including the dense working layout, active
  dice presentation, and reduced motion. The generated evidence remains under
  `.tmp/craps_table_visual_qa/` and is intentionally not staged.
- Million-roll rules gate: every RTP row, dice-setting fairness row, and street
  parity row passed. The wrapper exited nonzero only because the separately
  owned environment lane currently reports unresolved delivery-clerk and
  delivery-runner route aliases.
- The shared registered foundation script cannot run on this frozen row base:
  its inherited parent and helper methods arrive through the separately owned
  integration package. Its two prior Craps assertions are reproduced as
  executable row-local checks and pass; the Integrator must rerun the exact
  registered shard after merging this head with the environment-lane package.
