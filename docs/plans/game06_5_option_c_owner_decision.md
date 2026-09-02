# game06_5 Option C owner decision

Status: **SUPERSEDED 2026-09-02 / HISTORICAL RECORD**

The owner's later instruction selected a denser interlocking Crossword and
authorized compatible word changes. That implementation is active on remote
`main` at `996a98b6`. The Option C rules below document the former safe hold;
they are not current product or release authority.

Decision ID: `game06_5-option-c-no-new-supply-existing-issued-valid`

The program root selects Crossword Option C. The six aligned ticket families
`two_fer`, `lucky_7s`, `tic_tac_gold`, `bonus_bingo`,
`high_roller_holdem`, and `golden_vault` are the active 0.6 offering.

Crossword Corner is held, not deleted:

- no ordinary or practice generation, restock, selection, stale-index or direct
  resolution path may create a new Crossword purchase;
- an unsold Crossword stock row already present in a historical save remains
  serialized as held evidence, is not player-facing, cannot be purchased, and
  is neither refunded nor converted into an owned ticket;
- an already-issued Crossword ticket in player inventory, the active slot,
  pending queue, winner pile or loser pile remains visible and retains its exact
  play, file, portability, save/revisit and redemption behavior;
- Crossword definitions, art, regions, topology, word generation, price,
  payouts, stock weight and RTP remain unchanged.

The six-family alignment gate must explicitly report Crossword as `HELD`.
This decision supersedes the option-neutral waiting state in
`game06_5_crossword_owner_decision_evidence.md` without widening any other
implementation boundary.
