# game06_3 Roulette depth manifest

Branch: `codex/game06_3-impl`
Frozen ritual contract: `a2760d816c781e711ff0923c296f97b786662453`

This logical group is self-contained in the Roulette module. It does not import,
copy, or depend on the rejected shared runtime head `44fefe5f`.

The shipped seeded wheel result remains the sole outcome authority. The added
row-local projection exposes the authored sequence `betting -> no_more_bets ->
spin -> ball_settle -> croupier_settlement -> betting`, exact pending/at-risk and
per-bet accounting, croupier/neighbour/security actor state, wheel/ball/dolly/felt
object state, and three material table-energy tiers. Presentation explicitly
marks the wheel as non-authoritative.

Pending stacks now support removing one selected denomination from one named
stack. Clicking a player stack selects the exact target; the stake-down binding
provides the keyboard/controller equivalent. Late input remains rejected before
the action boundary while the wheel is locked.

Executable proof: `scripts/tests/foundation/game06_3_depth_contract.gd`.
