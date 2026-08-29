# game06_6 Bar Dice product recovery inventory

Status: implementation candidate evidence; no acceptance verdict.

## Recovered work

- Exact frozen contract lineage `6251c232..348ecd55` was replayed from its
  original commits onto the Game 5 successor base. No directory replacement or
  regenerated evidence was used.
- Exact dependency-manifest lineage `a9952ded..308d810f` was replayed after the
  contract payload.
- Every reachable branch, every commit in `--all` touching
  `scripts/games/bar_dice.gd`, and every unreachable commit reported by
  `git fsck --no-reflogs --unreachable` was inspected. No post-contract Bar Dice
  product implementation exists. The nearest substantial implementation is the
  shipped 3,300-line `scripts/games/bar_dice.gd`; its blob is identical at the
  contract base, frozen contract head, latest historical product head, and the
  replay base.

## Accepted dependency binding used

Bar Dice consumes the landed Game 1 sealed host through the same
`BlackjackActionAuthority` engine and Foundation transaction path. It adds only
game-owned proposal methods and table-state adapters. Legacy direct resolution
now simulates detached state and returns a receipt-required result that cannot
apply to a live run. Wager funding, RNG advancement, result apply, environment
turn, receipt consumption, exact replay and publication remain Foundation-owned.

The shipped rules engine remains the sole owner of dice, skill grades, winner,
pot, rake, payout, carry and press. Presentation phases and actor/object
projections consume public state only.

## Craps seam limitation

The accepted `scripts/core/craps06_3_environment_binding.gd` public seam is
correctly fail-closed, but it is intentionally restricted to a prepared and
committed transaction whose `producer_id` and `game_id` are both `craps`, whose
table is Craps-owned, and whose response fact comes from the authored Craps
profile. A Bar Dice transaction cannot pass that proof without forging Craps
ownership. The other teaching/dispersal helpers in `scripts/games/craps.gd`
remain private to Craps.

Accordingly this row does not duplicate sweep detection, heat thresholds,
refund, training, relocation or aftermath persistence, and it does not weaken
the accepted Craps seam. The shipped Bar Dice candidate exposes no independent
interruption authority. A future shared street-game host adapter must be owned
outside `game06_6`; until then, synthetic interruption stays projection-only in
the frozen contract proof and cannot mutate product state.

This is the precise dependency gap authorized by the row prompt's “file the
finding with evidence” clause. It is not resolved by caller claims, direct
calls to Craps private helpers, or copying the rules.
