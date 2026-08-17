Status: TODO
Board row: `crew06_8` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 crew06_8: The Heist (Plans A + B, Victory Route)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 3 "The
Heist": **Plans A ("The Count") + B ("The Whale Game") ship; C + D
stay documented only.** Plans are world-seed-gated (owner decision 16:
live only when the run's world criteria align — common enough, never
forced). The Grand Casino boss structure (duel, invite gate, chips,
Players Card) per `docs/plans/grand_casino_endgame_design.md` is
read-only substrate; the act-seam contract
(`docs/plans/act_two_seam.md`) is extended, not broken. This is the
biggest composite task on the board. This prompt is self-contained for
rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `crew06_8`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[crew06_8]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log: crew06_9
   unblocked.

## Dependencies

`crew06_5/6/7`, `craps06_1`, `rework06_1`, `env06_3` DONE. The Turn
is crew06_9 — build this slice so the ladder's fourth outcome is a
stub the next prompt fills (define the seam explicitly).

## Task

### 1. Plan gating + the planning table

- Plan criteria (`data/crew/heist.json`):
  - **Plan A**: *Audit Night* seeded at `grand_casino` (env06_3 flag)
    + Bishop at `inner_circle`.
  - **Plan B**: a whale anchor seeded (*Whale Aboard* or *Gala
    Night*) + Velvet at `inner_circle`.
- The L3 planning table (crew06_6 furniture) becomes live once any
  member reaches `inner_circle`: shows each plan as live / missing
  stars (diegetic: "no audit on the books this season" — truthful
  criteria states, no checklist UI beyond the table's own diegetic
  presentation).
- Locking a plan is explicit and singular (one heist per run);
  locking fires the crew06_9 traitor-resolution seam (stub: resolves
  "no turn" until crew06_9).

### 2. Plan A — The Count (procedural, silent)

- **Setup objectives** (each a real, tracked-at-the-table activity):
  1. *Furniture identity*: N clean Grand Casino sessions inside
     bet-band + suspicion-ceiling constraints (reuse session stats;
     progress is diegetic via Bishop's lines).
  2. *The schedule*: a real-venue delivery hold at the cage during a shift
     change.
  3. *The swap cart*: a hard real-map package run to the service
     perimeter.
  4. *(Optional)* the corridor guard's marker via Debt Court
     (env06_3 content seam) — completing it removes a Play-phase
     hazard.
- **The Play**: a phase-timed sequence at a designated table:
  maintain a live boring session (bet band + no heat spikes) while
  crew beats interleave; three decision points (call the go early vs
  hold; the deliberate small-heat distraction and sitting on it;
  dock vs corridor exit — availability depends on Setup completion).
  Failure paths: heat spike mid-window degrades the outcome band;
  identity shortfall forces abort-with-consequences (not a run end).
- **Payout**: flat massive cash band scaled per data; no gambling
  winnings involved.

### 3. Plan B — The Whale Game (social, loud)

- **Setup objectives**:
  1. *The vouch*: the whale-scenario social chain (stake-horse his
     table with deliberate-loss targets; entourage beats).
  2. *The rig*: component sourcing (Estate Lot / pawn seam from
     env06_3) + `craps_setting_trained` (either source).
  3. *The name*: Velvet's identity-building (spend/be-seen
     requirements, data-tuned).
  4. *The drunk*: Lucky seeding (automatic once 1–3 complete).
- **The Play**: the private invitational — a multi-round high-stakes
  table sequence (craps rounds + card rounds) with the full
  skill-cheat system live, a house counter-rig in play (scripted
  hazard rounds where honesty is correct), Rourke's attention as the
  suspicion meter, coordinated plays as data-limited lifelines.
  Win condition: finish top of the table without the rig being made;
  losing the bankroll or getting made degrades the outcome.
- **Payout**: the pot (variance-real: the score can shrink at the
  table); a compressed cage/interview getaway beat.

### 4. Getaway + outcome ladder + victory route

- **Getaway**: the real-map `delivery_begin_getaway` mode with
  plan-flavored parameters (A: dock run; B: front-door walk that
  turns into a chase only on hot outcomes). Outcome ladder:
  *Clean Sweep / Out Hot / Somebody Got Pinched / The Turn (stub)* —
  ladder position derives deterministically from Play performance +
  getaway result.
- **Victory route**: new `crew_heist` route id through the existing
  victory path: run ends as an Act 1 victory; `act_seam` payload gains
  `victory_route: "crew_heist"` + route payload hook
  `town_remembers` (+ outcome band, per the seam's banding style).
  Schema-version the seam addition; existing two routes byte-stable.
- Ending copy per outcome rung (Voice Bible II; the roadmap's tone
  notes per plan are binding).

## Hard rules

- Boss-structure read-only: the duel and Players Card routes remain
  fully playable and unchanged in runs that never lock a plan
  (full regression) and in runs that abort a heist.
- Everything optional: no heist pressure in non-crew runs; aborting
  at any pre-Play point is a costed retreat, never a run end.
- No Numbers coupling (owner-locked independence).
- Determinism: criteria evaluation, phase timers, hazards, ladder
  derivation — seeded + boundary-driven; scripted heists reproduce.
- Perf/save/style rules as other prompts; mid-heist save/load
  restores phase state exactly.
- Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Gating matrix: each plan live only under its criteria; missing-star
   presentation truthful; no-inner-circle runs never see a live table.
2. Plan A end-to-end: all setup permutations (with/without optional
   guard), all three decision points, both exits, ladder derivation
   fixtures.
3. Plan B end-to-end: vouch chain, both rig-training sources,
   counter-rig hazard rounds, made-vs-clean and rich-vs-bust ladder
   fixtures.
4. Getaway chase: plan-flavored parameters; ladder integration.
5. `crew_heist` seam payload written correctly; showdown +
   players-card regression byte-stable; pre-0.6 profile loads.
6. Abort paths from every pre-Play stage; save/load at every phase.
7. Visual QA + manual smoke of both full heists; screenshots to
   `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: criteria/data schema, both plans' phase graphs, ladder
tuning, seam extension shape, the crew06_9 stub seam, and gate
results. On an unfixable gate failure: stop at last green commit, set
`BLOCKED`, report verbatim.
