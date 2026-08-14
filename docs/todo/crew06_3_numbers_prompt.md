Status: TODO
Board row: `crew06_3` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 crew06_3: The Numbers (Lottery Racket: Play, Run, Rig)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 3 "The
Numbers" (owner-approved round 4 with mandates: riggable by crew
operation AND by solo cheat; crew players are paid a cut for fix work;
successful fixes leak into town rumors; **fully independent of the
heist**). This prompt is self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `crew06_3`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[crew06_3]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log: crew06_9
   past-posting grievance source live.

## Dependencies

`crew06_1` (trust/jobs), `streets06_1` (multi-stop routes),
`town06_2` (rumor registry) DONE. `town06_3` optional (sweep pause
seam — wire if landed, else register + log). `crew06_6`'s Numbers desk
is the L3 home; until it lands, the desk functions as a minimal L3
interactable you ship (coordinate on the board).

## Task

### 1. The game (anyone can play — no crew required)

- **Daily draw**: one three-digit number per in-game day, resolved at
  a fixed action boundary from the run RNG. Diegetic source: "the
  handle" — the last three digits of the track's published take.
  Nobody picks the winning number; the town just talks about it.
- **Slips**: buy at crew-touched venues (bar, gas_station_casino,
  corner_store, motel, the Punchline — data list): pick 3 digits +
  stake (bounded). Straight (exact order, long capped payout) and box
  (any order, shorter). Slips are inventory items with the contraband
  marker (sweep-sensitive). Data: `data/crew/numbers.json` — payouts,
  caps, close times, venue list.
- **Staggered closes**: each venue's book closes at a different
  action-boundary offset before the draw; the number *posts* at the
  Punchline first, then is common knowledge. This ordering is the
  load-bearing fact for past-posting — model it explicitly and
  document it in the data file.
- Yesterday's number + "hot numbers" superstition feed the rumor
  system (register a numbers rumor class; superstition rumors are the
  one rumor class marked non-factual — they are *truthfully* what the
  town is saying, not what will hit; document this nuance in the
  registry).

### 2. Runner mode (crew path, via Lucky)

- Collection route jobs from Lucky (`associate+`): a multi-stop
  Streets run — collect slips from 3–4 venues, deadline = post time,
  deliver to the Punchline desk. Pay = data percentage of the bag +
  trust. Late: crew eats losses, trust hit, `job_abandoned` grievance
  if ditched. Swept while carrying: slips confiscated + street heat +
  the worst version of the talk.
- Sweep interplay: collections pause at swept nodes (town06_3 seam).

### 3. The crew fix (operation, not menu)

- At high trust (Lucky + Mags at data ranks), the fix operation
  unlocks as a three-step job chain:
  1. **The bribe run** — a hard Streets package run (radioactive
     cargo: elevated patrol paint, no stash allowed).
  2. **The camouflage** — an allocation puzzle before the fixed draw:
     place spread bets across ≥N venues under per-venue concentration
     caps (too concentrated = operation heat; too thin = smaller
     take). Present as a simple allocation surface at the desk.
  3. **The payday** — the fixed number hits; **the player is paid a
     cut scaled to their step-1/2 performance** (owner mandate),
     alongside their own slip winnings if placed within caps.
- Failing step 1 aborts the chain cleanly (retry later per data).

### 4. The solo cheat — past-posting (no crew required)

- **Discovery-gated**: never advertised. Knowledge assembles from a
  rumor chain (staggered-close chatter) + one Silas encounter (buy
  the tip: where the number posts first). Assembled knowledge sets a
  hidden flag enabling the play.
- **The play**: be where the number posts (Punchline at post time, or
  Silas sells today's number for a price), then physically reach a
  still-open book before its close offset and place a winning slip.
  Travel speed is the whole exploit: bus timing, `roadside_map`,
  weather, route choice. No special UI — the systems just permit it.
- **The risk**: each past-post rolls detection (data odds scaling
  with repetition and stake). Caught = **street debt, not law**: a
  Knuckles collection encounter, winnings clawed back + penalty, and
  — if the player is on the crew path — the
  `numbers_past_posting_in_colors` grievance (crew06_1 taxonomy).
- Solo route must be fully playable with zero crew trust (prove it).

### 5. The leak (owner mandate)

- Any successful fix (crew or solo past-post above a stake threshold)
  seeds next-day rumor chatter carrying the number/pattern: pile-on
  NPC betting (bigger declared pools, capped payouts per data), venue
  twitchiness (strictness up at Numbers venues), and — if a sweep
  exists — a data-odds chance the sweep re-routes toward a Numbers
  venue. Repeat fixes escalate the leak (document the escalation
  curve).

## Hard rules

- **Independence (owner-locked)**: zero heist references — no flag,
  requirement, or payout of the heist touches the Numbers, and vice
  versa; the only shared surface is crew trust/grievances.
- Determinism: draws, detection rolls, leak effects — seeded,
  boundary-driven; same seed + actions → same numbers and outcomes.
- Economy: straight/box payouts and caps documented; long-run player
  EV negative on honest play (it's a racket), positive only via
  running, fixing, or past-posting — prove with the harness.
- Hidden discovery stays hidden: no journal, no quest UI.
- Perf/save/style/voice rules as the other prompts (street register).
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Draw determinism + boundary timing; save/load around post time.
2. Slips: buy/close/settle lifecycle at every venue offset; contraband
   confiscation path.
3. Runner route end-to-end: pay + trust on time; late/ditch/swept
   fixtures produce the documented consequences.
4. Fix chain: all three steps; cut scales with performance fixtures;
   step-1 failure aborts cleanly.
5. Past-posting: knowledge assembly (rumors + Silas) flips the flag;
   the race succeeds/fails on travel timing fixtures; detection +
   Knuckles consequence + in-colors grievance (crew fixture) vs no
   grievance (solo fixture).
6. Leak: post-fix rumors carry the number; caps/strictness apply;
   escalation on repeat.
7. EV harness: honest play negative; fix/past-post EV positive within
   documented bands.
8. Independence audit: grep-level + test proof of no heist coupling.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: data schema, close-offset table, fix/past-post tuning, leak
curve, EV evidence, and gate results. On an unfixable gate failure:
stop at last green commit, set `BLOCKED`, report verbatim.
