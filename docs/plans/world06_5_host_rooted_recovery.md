# world06_5 host-rooted recovery

## Candidate

- Exact base: `b11efafa885672431425a31b4792cd51fa488514`
  (`world06_4` frozen candidate).
- Branch: `codex/finish06-world5-recovery-b11e`.
- Worktree: `C:\bth-finish06-world5-recovery-b11e`.
- Recovered sources: `codex/world06_5` through `07e98f16` and its remediation
  through `7f496a5a`; the complete proposal, authored data, presentation, and
  economics package was already an ancestor of the exact base.
- This pass adds only the missing World 1 host authority, atomic settlement,
  exact restore, and replay boundaries. The five plays, Police Sweep track,
  encounter ladder, delivery composition, and authored presentation were not
  rebuilt.

## Preserved authored contract

- `data/crew/plays.json` is byte-identical to the exact World 4 base.
- The exact five plays and landed `game_ids` remain unchanged: Spotter and Big
  Player at blackjack; Distraction and Table Flood at blackjack, baccarat,
  roulette, craps, and video poker; Chip Dump at baccarat.
- Minimum ranks, uses, costs, cooldowns, windows, detection rates and heat,
  effect payloads, the one-window cap, and the sole `spotter:big_player`
  exception are unchanged.
- Chip Dump remains the shipped player-funded transfer: $40 cash to 40 chips
  plus the $6 fee. The host verifies both ledgers and rolls back an incomplete
  transaction.
- The hidden deterministic Sweep track, pressure and wake behavior, all five
  costed encounter rungs, and their landed ranges remain unchanged.

## Authority closure

- Coordinated-play activation and expiry advance require RunState's private,
  non-serialized host capability. RunState derives the exact current
  environment and active game, then verifies sequence and exact cash/chip
  deltas before committing. A substituted table, game, or caller capability
  cannot mutate uses, cooldowns, actors, money, chips, detection, or heat.
- Sweep sightings and claims require the same private host capability.
  RunState derives the current player node, live delivery/inventory cargo,
  adjacent exits, current actors, and earned Switch intel from trusted owners;
  no public resolver accepts a caller claim or caller-authored outcome.
- Authenticated Sweep intel is player-safe and usable by the route proposal.
  Unauthenticated calls fail closed without current node, heading, segment,
  seed, action, or other hidden track facts.
- Sweep economic resolution is one transaction. RunState snapshots the complete
  environment turn, applies the landed rung, records the model-owned encounter
  tombstone, and restores the snapshot if any authority or conservation check
  fails.

## Persistence and replay

- Play-window termination and detection append canonical tombstones bounded to
  16 entries. The current state schema accepts only its exact key set; exact
  schema-1 states migrate to schema 2; unknown keys and oversized tombstone
  sets fail closed.
- Sweep resolutions append canonical, cost-validated tombstones bounded to 16
  entries. Exact schema-1 snapshots restore without the added tombstone field;
  exact schema-2 snapshots preserve it; unknown keys, invalid rows, and
  oversized sets are rejected.
- The model-owned last-claim state plus the durable tombstone prevents a second
  cost before or after save/load. Failed transactions roll back the claim as
  well as cash, debt, cargo, delivery, Numbers, travel-lock, event, and story
  effects.
- Host capabilities are recreated on new/load and are never serialized.

## Coverage and evidence

- `tools/validate_project.ps1`: PASS four times (`67.8s`, `66.0s`, `65.4s`,
  `66.0s`).
- `git diff --check`: PASS.
- Authored coordinated-play data versus the exact base: no diff.
- Focused contracts cover the exact five-play/game matrix, the cap and pairing
  exception, Chip Dump conservation, ten-seed detection determinism, hostile
  capability rejection, exact current/legacy restore, bounded tombstones,
  authenticated usable intel, hostile claim rejection, all five Sweep rungs,
  delivery and Numbers cargo confiscation, foreign-lock composition, and
  exactly-once resolution before and after save/load.
- Godot execution is serialized by Warden and remains pending there; this lane
  did not invoke Godot.
