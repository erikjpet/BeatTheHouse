Status: SUPERSEDED — do not claim. The V3 machine rework
(docs/plans/coin_pusher_v3_machine_rework_plan.md, owner round-6 design session
2026-08-17) replaces this work. See the pusherv3_* rows on the board.
Board row: `pusher06_3` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — pusher06_3: Jackpot Ridge + The Vault Drop

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike. Binding design contracts:
`docs/plans/0.6_coin_pusher_simulation_plan.md` section 4, and the
Coin Pusher section of `docs/plans/0.6_living_world_roadmap.md`.

## What this task is

Quarter Falls plays on the real solver. This task builds the other
two machines. The owner's standing requirement (round-2 decision 5,
reaffirmed in the rework): the three variations implement
**completely unique mechanics, bonuses, and strategies** — not one
system with three number sets.

The acceptance bar is blunt: **a player must describe these as three
different machines.** If Ridge and Vault differ only in tuning
constants and cosmetics, the task has failed regardless of test
status.

Both bonus systems are **physical**. Their pieces live in the pile,
obey the same solver as the coins, and are worked loose by pushing
and nudging. Nothing here may be an overlay minigame bolted on top of
a pile that does not know about it.

## Board protocol

1. Before work: set row `pusher06_3` to `IN_PROGRESS` with agent +
   date, append a Work Log line, commit the claim. If not `TODO`,
   stop.
2. Log discoveries/deviations tagged `[pusher06_3]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move to `docs/todone/`; Work Log naming `pusher06_4`
   unblocked.

## Dependencies

`pusher06_1` and `pusher06_2` DONE. Both variations run on the same
solver and publish through the same snapshot/event boundary — extend
those, never fork them. Verify by code.

## Task

### 1. Jackpot Ridge — the sequencing pusher

**Feature pucks are physical bodies in the pile**, with their own
mass and footprint, distinct from coins:

- **Multiplier pucks** — banked by physically pushing them off the
  ledge; arm ×2/×3/×5 for a defined window.
- **Lock pucks** — freeze a shelf for a cycle when banked.
- **Dud pucks** — jam a lane physically until worked loose, changing
  how the pile builds around them.
- **Ridge Run** — banking three multipliers within one sweep cycle
  triggers a cascade (back wall double-push for M cycles).

The sub-game is a **physics puzzle**: which puck to free first, what
the pile does when you free it, and whether a nudge that loosens one
puck buries another. Ridge is where nudge mastery pays most and where
the alarm line gets walked closest — its deeper nudge affordance
(larger tolerance pool, finer force granularity) carries over from
the shipped design.

Cheat hooks: `weighted_keyring` (heavier nudge within tolerance), the
Mags dampener (tolerance band up one).

### 2. The Vault Drop — the progressive pusher

**Key fragments are physical objects in the pile.** Fragments pushed
off the ledge bank toward the machine's vault:

- **The vault round** — a pick-and-reveal bonus behind a door on the
  playfield. Spend banked fragments on cells holding cash, items,
  fragment refunds, and a **RESET** cell that slams the progressive
  down. Stop anytime; greed is the boss. Cell odds are documented in
  data and honest — never tuned below the documented floor.
- **The town-fed progressive** — the meter is TownState-driven,
  growing on action boundaries, faster in crowded scenarios at its
  venue, per-machine and persisted with the node. Register it as a
  rumor fact class so the town can talk about a fat vault ("the vault
  at the corner store is *hanging*").
- **Strategy is map-level EV**: which venue's meter is worth the
  trip, whether to bank fragments or cash a thin vault before the
  sweep arrives. This is the one machine played by *traveling*.

Cheat hook: `xray_glasses` peeks exactly one cell, truthfully.

### 3. Shared framework discipline

- One solver, one snapshot/event boundary, one nudge system, one
  alarm contract across all three machines. Variation logic is
  additive modules over the shared core — enforce by structure, and
  say so in your report.
- The alarm contract is unchanged in all variations: hard alarm locks
  that machine for the night, heat spike, node memory, and **never a
  forced exit from the environment** (owner decision 23).
- Per-variation seeding, distribution across tier-1 venues, and
  scenario access effects (Graveyard Shift lax alarms, Trucker Convoy
  busy machine) carry over from the shipped design.

### 4. Economy honesty

As in `pusher06_1`, RTP is emergent and measured, never imposed. Tune
the *machines* (geometry, puck/fragment spawn seeding, sweep throw,
vault cell distribution, meter growth) to land in the documented
bands. Report the measured band per variation; the Vault Drop's band
is meter-dependent and must be documented as such.

## Hard rules

- Three genuinely different sub-games. Shared logic with different
  numbers is a failure condition.
- Bonus pieces are physical and obey the solver — no overlay
  minigames.
- Authoritative simulation preserved: what physically crosses the
  payout edge is what pays. The `pusher06_1` authority test stays
  green.
- No re-abstraction under perf pressure: lower the coin/piece cap and
  report the number.
- Determinism absolute, Windows and Web, including meter growth and
  vault cell selection.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports;
  suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Ridge: puck lifecycle (arm/expire/lock/jam/clear) on real physics;
   Ridge Run triggers exactly on three multipliers banked in one
   cycle; cascade duration per data; a puck buried by a nudge behaves
   physically.
2. Vault: fragments bank only when physically pushed off; vault round
   pays per documented odds; RESET slams to floor; xray peek reveals
   exactly one truthful cell; meter grows only on action boundaries
   and faster under a crowded-scenario fixture; meter persists per
   machine.
3. Distinctness evidence: a written comparison of the three machines'
   verbs, decisions, and failure modes — plus captures of each — that
   an outside reader could use to tell them apart.
4. Determinism across runs, processes, Windows vs Web for both new
   variations.
5. Distribution sweep (20 seeds): all three variations reachable;
   busy-machine mutation blocks play when set.
6. EV harness per variation within documented bands.
7. Perf at the shipped cap with pucks/fragments present; idle
   liveness green.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- the performance probe at existing budgets

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: each sub-game's mechanics and why they are structurally
different, the shared-core enforcement, vault odds table, meter
tuning, measured EV bands, determinism evidence, perf numbers, and
the distinctness captures. On an unfixable gate failure: stop at the
last green commit, set `BLOCKED`, report verbatim.
