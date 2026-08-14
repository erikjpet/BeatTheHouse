Status: TODO
Board row: `crew06_7` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 crew06_7: Coordinated Plays (Crew in the Casino)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 3
"Coordinated plays": five limited-use, visible-cost tools available
when a `made` member is present in-venue — never passive buffs.
Blackjack's count/suspicion systems and the skill-cheat pattern
(`docs/plans/skill_based_cheating_methods_plan.md`) are the
integration substrate. This prompt is self-contained for rules and
scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `crew06_7`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[crew06_7]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log: crew06_8
   lifelines ready.

## Dependencies

`crew06_1` + `crew06_5` DONE (rank/presence). Verify by code which
members can be in-venue (itineraries/residency) — a play needs its
member physically present at the venue, and presence must be checkable.

## Task

### 1. The play framework

- A play is: requirement (member + rank + venue/game context) →
  activation (explicit player action with a visible diegetic beat) →
  effect window → cost. Limited uses per run per play (data:
  `data/crew/plays.json`), seeded outcomes where chance exists,
  costs always visible before activation (uses, cash cut, member
  cooldown, heat risk on detection).
- Presence: the member must be at the venue (crew06_5 presence
  systems). Activating pulls them to the table ambient placement for
  the window.

### 2. The five plays

1. **Spotter** (Switch, blackjack): during the window, count accuracy
   assistance (the existing count-challenge surface gets a
   confidence assist — never auto-answers) + suspicion accrual
   reduced (data multiplier). Detection risk: a pit sweep during the
   window burns the play and adds heat.
2. **Distraction** (Velvet or Lucky): once-per-activation immediate
   heat/suspicion dump at the current venue (data amount) with a
   scene beat; the member is "spent" (cooldown) afterward.
3. **Big Player call-in** (needs Spotter active): walk into a
   pre-warmed shoe — next blackjack session starts at the spotted
   count state; pairs the two plays into the classic team structure.
4. **Chip Dump** (any member, baccarat): partner-play moves a
   data-bounded chip amount between player and member discreetly
   (money movement with a laundering flavor — a transfer with a fee
   and a detection roll, not free money).
5. **Table Flood** (any two members present): the crew crowds the
   table for a window — camouflage: cheat-detection odds reduced
   (data multiplier) for the window's duration.
- Grievance seam: letting a Distraction member eat a resulting
  security consequence (the escalation lands while they're spent —
  detectable condition) writes `distraction_heat_dumped` via the
  crew06_1 taxonomy.

### 3. Presentation

- Plays surface through a compact in-venue affordance only when
  available (no dead buttons); every activation has a one-line
  diegetic beat per member voice; effects end visibly.

## Hard rules

- Never passive: no play effect without explicit activation; all
  effects windowed and visible.
- Game cores untouched: plays modify inputs the games already expose
  (suspicion rates, count surfaces, detection odds, transfers) — no
  forked game logic; where a game lacks the seam, add the generic
  seam, never a special case.
- Determinism: windows in action boundaries; detection rolls seeded.
- Balance: each play's numbers in data with documented intent; the
  full five together must not trivialize heat — cap concurrent
  active plays at one (+ Big Player pairing) and prove heat pressure
  survives in the harness.
- Perf/save/style/voice as other prompts. Suite timeout = max(300s,
  baseline×1.5).

## QA / Tests

1. Requirement matrix: each play activates only with member + rank +
   context; absent member = no affordance.
2. Effect windows: apply, persist exactly N boundaries, end; uses
   deplete; cooldowns hold.
3. Spotter + Big Player pairing transfers count state correctly;
   Spotter detection burn path.
4. Chip Dump conserves money minus fee; detection roll consequences.
5. Table Flood multiplier applies only in-window (cheat harness
   fixture).
6. `distraction_heat_dumped` writes exactly on the documented
   condition.
7. Heat-pressure harness: a max-plays run still hits heat thresholds
   under sustained aggressive play.
8. Save/load mid-window restores; visual QA + manual smoke.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: play data schema, per-play tuning, heat-pressure evidence, and
gate results. On an unfixable gate failure: stop at last green commit,
set `BLOCKED`, report verbatim.
