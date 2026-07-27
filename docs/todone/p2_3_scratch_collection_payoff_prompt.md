# Agent Prompt - P2: Resolve the Scratch Ticket Collection (dangling mechanism)

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike preparing 0.5. This file is self-contained. This task closes a
mechanism that is currently tracked, persisted, and displayed - but leads
nowhere.

## The dangling mechanism

The scratch ticket machine draws a collection counter on its cabinet:

```
scripts/games/scratch_tickets.gd:1682
	"%d/%d PRINTS FOUND"
```

backed by `COLLECTION_TOTAL := 7` and
`profile_inventory.scratch_ticket_types_discovered`, which is normalized,
persisted across runs, and included in the profile schema
(`scripts/core/profile_inventory.gd:26`, `:188`).

**There is no payoff.** Grepping the whole tree, `scratch_collection_count`
and `scratch_collection_total` are read in exactly one place - the label that
draws them. Completing the set fires no event, grants no item, unlocks
nothing, and is not acknowledged anywhere. A player who chases 7/7 gets a
number that stops changing.

## It just got much harder to complete

Stock generation was retuned today (`a8953759`, then further edited in the
working tree). Current rule in `_generate_machine_state`:

```gdscript
var stock_roll := machine_rng.randi_range(0, 19)
var remaining := 0 if stock_roll < 15 else mini(maximum, stock_roll - 14)
```

That is a 75% chance each of the 7 types is out of stock, so a machine
carries **~1.75 stocked types on average**. The tag is
`full_roster_75_out_of_stock_1_to_5`. Discovering all 7 print types now takes
many machine visits across many runs - which makes an unrewarded counter more
conspicuous, not less.

## Task

Resolve the mechanism. Pick the smallest design that makes the counter
honest, and say why in your report. Options, roughly in ascending cost:

1. **Acknowledge completion** - a distinct on-cabinet completion state plus a
   one-time event/dialogue beat when the 7th print is found. Cheapest honest
   close.
2. **Reward completion** - the above plus a concrete grant: a collection item
   (the item/collection meta system already exists - see
   `data/collections/collections.json` and
   `scripts/core/collection_item_resolver.gd`), a meta unlock, or a
   permanent small perk at scratch machines.
3. **Remove the counter** - if the collection is not meant to pay off in 0.5,
   delete the display and keep the persisted data for a later act, so nothing
   dangles in front of the player.

Whichever you choose:

- Do NOT leave a visible progress counter with no resolution.
- The reward (if any) must be reachable given current scarcity. Verify by
  simulation across seeds, not by assumption: estimate machine visits needed
  to see all 7 types at the current 75% out-of-stock rate, and report the
  number. If it is unreasonable for a normal player, say so plainly and
  recommend either a stock-rule adjustment (e.g. guarantee an undiscovered
  type appears at some rate) or a lower `COLLECTION_TOTAL`.
- Any grant must go through the existing authoritative services - do not mint
  items ad hoc. Prices, floats, durability, and RNG stay authoritative.
- Determinism holds: seeded stock and seeded rewards.

## Related open question for the owner (report, do not decide alone)

`data/collections/collections.json` carries `"draft": true`, and
`collection_item_resolver.gd:388` actively REQUIRES it
("Collection schema must carry draft=true for P0 owner review"). The
collection schema is therefore still formally in owner review while shipping
in 0.5. Flag in your report whether your change depends on that schema
being finalized, so the owner can decide whether 0.5 ships with the draft
flag still set.

## Hard rules

- Zero-copy per-frame; idle-animation liveness untouched - never accept a
  0.000 idle-draw number without the liveness counter check.
- Working tree may contain other people's uncommitted work; treat it as
  user-owned, never revert, reformat, or stage it. Stage explicitly.
- Style: tabs, typed GDScript, sparse comments. Captures under `.tmp/`.

## Gates

- `tools\validate_project.ps1`
- `-FoundationSuite scratch_tickets`, `games`, `systems`, `ui`
- `tools\scratch_tickets_rtp_audit.ps1`
- `tools\collection_meta_check.ps1`
- `tools\foundation_determinism_probe.ps1`

## On completion

Only after every gate passes AND you have confirmed the change end to end:

1. Commit the work in logical units.
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append a short execution record to the bottom of the moved
   file (date, implementing commit hashes, gate results, deviations), and
   stage the moved file so the archive lands in the final commit.
3. PUSH to the remote.
4. Report: the option you chose and why, the simulated visits-to-complete
   number, the draft-flag finding, and gate results.

On an unfixable failure, stop at the last green commit, do NOT push or
archive, and report verbatim.

---

## Execution Record

Date: 2026-07-26

Implementing commit:

- `6f5e109a` - Close scratch ticket collection payoff

Design choice:

- Chose option 1, acknowledge completion. The scratch collection counter is now
  honest without tying 0.5 to the draft collection schema: completing the seven
  print set creates a one-time profile acknowledgement, logs a run-story beat,
  appends a player-facing clerk message to the completing scratch action, and
  changes the machine cabinet from progress text to `FULL SET FOUND`.

Reachability simulation:

- Probe: `.tmp/scratch_collection_completion_probe.py`
- Runs: 20,000 deterministic seed labels
- Current stock model: 75% out of stock per ticket type, remaining rolls
  stocked 1-5
- Visits to discover all seven types: mean `9.485`, median `9`, p75 `12`,
  p90 `15`, p95 `17`, p99 `23`, max `41`
- Finding: chasey but reachable; no stock-rule adjustment or lower
  `COLLECTION_TOTAL` recommended for this acknowledgement-only close.

Draft-flag finding:

- This change does not depend on `data/collections/collections.json` being
  finalized because it does not mint collection items or use collection
  resolver grants. The existing `"draft": true` flag remains a separate owner
  shipping decision.

Gate results:

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite scratch_tickets` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\scratch_tickets_rtp_audit.ps1` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\collection_meta_check.ps1` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1` - PASS; hash `793128878`

Deviations:

- The prompt file was untracked in `docs/todo/`, so it was archived by moving
  the exact file to `docs/todone/` and adding the archived copy rather than
  using `git mv`.
