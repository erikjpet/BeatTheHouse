Status: TODO
Board row: `crew06_9` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-18
- **Completion/implementation commits:** `627b8ac9`, `7a3ab2ca`
- **Verification:** PM line-by-line scope/design/privacy review; `crew_turn_contract` and owning heist contracts PASS on the integrated tree; combined Systems, Contracts, and UI suites PASS; two-process 10-seed/510-checkpoint determinism PASS (`3528944666`); canonical visual QA PASS.
- **Deviations:** None. Hidden state remains under neutral compact save keys, legacy saves remain accepted, and no player-visible surface names the system outside its authored ending copy.

# Agent Prompt — 0.6 crew06_9: The Turn (Hidden Betrayal System)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 3 "The
Turn — full design v2" (owner-approved round 4, including the pool
ruling and both hidden guarantees). crew06_8 left the
traitor-resolution seam and the ladder's fourth outcome as a stub;
crew06_1 owns the grievance ledger; crew06_2 owns tells;
town06_2 owns itineraries/rumors; crew06_3 owns the past-posting
grievance. **The prime directive: the game never admits this system
exists.** This prompt is self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `crew06_9`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[crew06_9]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log: release06_1
   path clear (pending Wave E siblings).

## Dependencies

`crew06_8`, `crew06_2`, `town06_2`, `crew06_3` DONE. Audit the
grievance writers that exist across landed prompts (crew06_1/3/6/7)
before building — the ledger is your input surface; code reality wins.

## Task

### 1. Traitor resolution (at plan lock)

- Fill crew06_8's seam: when a heist plan locks, resolve The Turn
  from the run RNG weighted by per-member grievance ledgers.
- **Eligibility (owner-locked)**: Rook never; the locked plan's
  architects never (A: Bishop; B: Velvet + Mags); all other met
  members eligible.
- **Clean hands = zero (hidden guarantee #1)**: an empty ledger for a
  member = zero chance from that member; all ledgers empty = The Turn
  cannot occur. Base chance above zero only from nonzero ledgers;
  curve in `data/crew/heist.json` (documented, hidden from UI).

### 2. Clue emission (three classes, systems-surfaced)

Active only when a traitor exists; each clue is witnessable, never
logged for the player:

1. **The wrong tell** (crew06_2 seam): during L3 planning-phase
   scenes, the traitor's authored tell misfires (fires during heist
   table-talk, not cards). Witnessing it counts **only if**
   `tell_learned(traitor)` is true — the skill gate. Non-learned
   players see nothing distinguishable.
2. **The itinerary lie** (town06_2 seam): the traitor states a
   whereabouts claim (planning dialogue) contradicted by the
   traveler/residency record for a period the player can have
   evidence about (a rumor heard, a sighting made). Emission only
   generates lies the run's actual state can contradict.
3. **The light envelope** (jobs seam): one post-lock job payout from
   the traitor comes up short in a checkable way (the shortfall
   references a figure verifiable at the job board/Numbers desk).
- Witnessing sets hidden per-clue flags. No journal, no counter, no
  UI acknowledgment — ever.

### 3. The confrontation + the hedge

- **Unmarked option**: with ≥2 witnessed clues pointing at one
  member, an unlabeled extra option appears in the pre-departure
  planning interaction (diegetically phrased; nothing signals it is
  special).
  - Right member: Turn cancelled → loyalty beat scene → small heist
    edge (one free coordinated-play use in The Play; wire via
    crew06_7 data).
  - Wrong member: `wrong_accusation` grievance to the accused,
    crew-wide trust hit, traitor odds re-resolve upward (documented
    curve), darkened table mood line.
- **The hedge**: with exactly 1 witnessed clue, a different unmarked
  option: quietly restructure your role — if the Turn fires, the
  outcome upgrades from full Turn collapse to *Out Hot* with a
  partial-haul band; if no traitor, a small cost (crew reads it as
  cold feet: minor trust hit). Insurance, not immunity.

### 4. Turn execution (plan-specific beats)

- Fill the ladder's fourth outcome for both plans: A — the corridor
  doesn't hold (beat + collapse consequences); B — the rig gets
  pointed at you mid-game (beat + exposure consequences). Each is a
  dramatic failure ending with unique copy and a story-scar flag in
  the run record/act seam (banded, per crew06_8's seam style) — never
  a save wipe, never a soft-lock.

### 5. Discipline audit

- Sweep every player-visible surface (UI, logs, save-file plain
  strings, achievements/challenges) to confirm nothing names the
  system: no "traitor", "clue", "betrayal meter", tracker, or count
  anywhere player-visible. The word "turn" may only appear inside
  the ending copy itself.

## Hard rules

- Determinism: resolution, emissions, and re-resolution — seeded,
  reproducible per seed + action sequence.
- The two guarantees are absolute and covered by tests: clean-hands
  zero; correct two-clue confrontation always cancels.
- Emission honesty: every emitted clue is genuinely witnessable in
  that run's state (no lie without a contradicting record; no
  envelope without a checkable figure) — assert in debug.
- Perf/save/style/voice as other prompts; mid-heist saves preserve
  hidden state under neutral keys.
- Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Eligibility matrix: Rook/architects never selected across a large
   seeded sweep; per-plan suspect pools correct.
2. Clean-hands: zero-ledger runs never produce a traitor (property
   test, wide seed sweep).
3. Weighting: ledger fixtures shift selection odds per curve.
4. Skill gate: identical scenes with/without `tell_learned` — clue
   witnessable only with it.
5. Lie emission always contradictable by run records (debug assert +
   fixture sweep); envelope always checkable.
6. Confrontation: right/wrong/hedge paths produce exactly the
   documented consequences; wrong-accusation re-resolution.
7. Both plan-specific Turn beats play; scar flags land in the seam;
   no soft-lock.
8. Discipline audit script/checklist evidence attached to the board
   note.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: resolution curve, emission conditions, confrontation wiring,
discipline-audit evidence, and gate results. On an unfixable gate
failure: stop at last green commit, set `BLOCKED`, report verbatim.
