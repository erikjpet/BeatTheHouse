Status: TODO
Board row: `push06_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 push06_2: Jackpot Ridge + The Vault Drop

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). push06_1 shipped
the pusher framework (coarse deterministic pile model, universal
nudge/alarm system, pile persistence) and Quarter Falls. Binding
design contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 4
coin pusher variations 2 and 3. Owner mandate: the three variations
implement **completely unique mechanics, bonuses, and strategies** —
not layouts. This prompt is self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `push06_2`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[push06_2]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Dependencies

`push06_1` + `town06_1` DONE (the Vault Drop progressive is a
town-state meter). Verify landed framework APIs by code.

## Task

### 1. Jackpot Ridge (the puck pusher)

- Shelf carries **feature pucks** alongside coins: multiplier pucks
  (arm ×2/×3/×5 for the next N drops), lock pucks (freeze one shelf a
  cycle), dud pucks (jam a lane until cleared). Puck spawn schedule is
  seeded per session.
- **Ridge Run** bonus: three armed multipliers pushed off within one
  shelf cycle → cascade (back wall double-push for M cycles).
- Strategy identity = sequencing: which puck comes off first, arming
  before/after locks, clearing duds vs playing around them. Ridge has
  the deepest nudge affordance in the family (largest tolerance pool,
  finest force granularity) — nudging pucks, not just coins.
- Cheat: `weighted_keyring` (heavier nudge within tolerance); a
  Mags-crafted "nudge dampener" item hook (raises tolerance one band —
  item itself ships via content06_1; wire data-driven).

### 2. The Vault Drop (the progressive pusher)

- Pile carries **key fragments**; fragments pushed off the ledge bank
  toward the machine's **vault**.
- **Town-fed progressive**: each Vault Drop machine's jackpot meter is
  TownState-driven — it grows on action boundaries (faster under
  crowded scenarios at its venue), seeded and deterministic. Register
  the meter as a rumor fact class ("the vault at the corner store is
  fat") with town06_2's registry.
- **Vault round**: spend banked fragments to open vault cells —
  cash amounts, items, fragment refunds, and the RESET cell that
  slams the progressive down. Stop anytime; banked fragments persist
  with the pile (node snapshot).
- Strategy identity = map-level EV: reading which venue's meter is
  worth the trip (rumors/Switch), banking vs cashing before the sweep
  arrives. The machine plays the whole town.
- Cheat: `xray_glasses` — peek one vault cell before choosing (reuse
  the shipped peek pattern from scratch tickets).

### 3. Placement + distribution

- Variation availability seeded per node across tier-1 venues so a
  run sees a varied spread (weights in data); scenario access effects
  respected (Graveyard Shift maintenance opens lax-alarm play;
  Trucker Convoy occupies the good machine — machine-busy state as an
  environment mutation).

## Hard rules

- Both variations run on the push06_1 framework — no forked pile or
  nudge code; variation logic is config + variation-specific modules
  over shared core (enforce by structure).
- Determinism/perf/save/voice rules identical to push06_1 (probe,
  boundary-only meter growth, idle attract liveness, snapshot
  persistence).
- The RESET cell must be honest: odds documented in data, never
  rug-pull-tuned below the documented floor.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Ridge: puck lifecycle matrix (arm/expire/lock/jam/clear); Ridge Run
   triggers exactly on 3-in-cycle; cascade duration per data.
2. Vault: meter grows only on boundaries, faster under a crowded
   scenario fixture; fragments bank/persist; RESET slams to floor;
   xray peek reveals exactly one truthful cell.
3. Determinism: scripted sessions on both variations reproduce across
   runs; meter timeline identical per seed.
4. Distribution: 20-seed sweep shows all three variations reachable;
   busy-machine mutation blocks play when set.
5. EV harness per variation within documented bands (vault EV
   documented as meter-dependent).
6. Visual QA + manual smoke on both; screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: puck schedule shape, meter tuning, vault odds table, and gate
results. On an unfixable gate failure: stop at last green commit, set
`BLOCKED`, report verbatim.
