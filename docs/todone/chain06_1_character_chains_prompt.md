Status: DONE
Board row: `chain06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-17
- **Completion/implementation commits:** `e1538661`, `280a477e`, `2dea0124`, `2a5ce370`
- **Verification:** Six-chain/21-beat focused contract, Cass three-ending runs, prefix sweep, icon-actionability sweep, and save/load fuzz PASS; combined Contracts, Systems, UI, 10-seed determinism, and zero-warning visual QA PASS.
- **Deviations:** Added one generic eligible-beat environment projection helper; progression remains authoritative in existing `story_flags` and adds no UI.

# Agent Prompt — 0.6 chain06_1: Character Storyline Chains

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 5. Chains
are flag-driven (`story_flags`), deterministic, interruptible, and
degrade gracefully — missing a beat never blocks anything. Voice: both
voice bibles per character register. This prompt is self-contained for
rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `chain06_1`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[chain06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Dependencies

`town06_2` (itineraries — Cass/Silas/Dave), `env06_2`, `env06_3`
(anchor scenarios) DONE. Verify landed flags/APIs by code.

## Task

Author six chains as data + events (reuse existing event/dialogue
mechanics; add only generic chain sequencing helpers if the flag
idiom truly needs them — log any such addition):

1. **Cass Venn (marquee)** — the rival counter racing you to the same
   finish line. Beats fire wherever her itinerary puts her:
   first-contact at a shared table; escalation (she marks you /
   you're in her seat); the proposition; then three endings driven by
   player choices + run state: *truce* (split the town: she stops
   heating your venues), *tip-off* (cross her and she burns you — a
   one-time targeted heat spike with warning signs), *flameout*
   (stay clean past her escalation: witness her getting made at the
   Grand Casino — a scene with mechanical aftermath: floor attention
   spikes for everyone for a window).
2. **Sal — the Estate Lot** — one item in Estate Lot Day carries a
   story; following its trail crosses three venues (data-picked from
   the run's world) and ends at Sal's counter with a changed Sal (his
   Mood micro-scenarios weight after the ending; sell-back beat with
   a real choice).
3. **Nico** — what the soft loans cover: two beats at the motel
   (Weekly Rates anchored) + one payoff that resolves the dangling
   `favor_owed` consequence into a real favor call with a choice.
4. **Rourke's scouts** — escalate the shipped cameo events into a
   legible 3-step pre-boss arc (noticed → named → expected) driven by
   run heat/winnings bands; each step recolors Grand Casino staff
   lines. No mechanical boss changes.
5. **The Trio** — formalize the lucky-coin/glasses gifts into a chain
   with a Rent Party payoff (the band remembers every gift this run).
6. **Dave** — his bus stories reference his actual itinerary and, at
   chain end, one story that is *useful* (a true rumor with heard-tier
   map payoff).

Per chain: beats defined in data (conditions on flags/state/venue,
never wall-clock), each beat skippable-forever without breaking later
content (later beats' conditions must tolerate missing earlier ones or
gate on them explicitly), endings set durable-for-the-run flags
consumed by lines/scenarios where cheap.

## Hard rules

- Interruptible + graceful: no chain state can dead-end an event
  pool, lock a venue, or leave a dangling required beat (property:
  any prefix of any chain is a valid final state).
- Deterministic availability; no new UI (chains live in events,
  dialogue, and ambient lines).
- Cass's mechanical effects (heat spikes, attention windows) are
  data-tuned and bounded — flavor-forward, never run-ruining.
- Perf/save/style rules as other prompts; chains serialize via
  existing story_flags.
- Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Each chain end-to-end per ending (Cass ×3) via scripted runs.
2. Prefix property: truncate every chain at every beat; verify no
   blocked content, no dangling requirement (automated sweep).
3. Cass effects bounded per data; flameout aftermath window expires.
4. Beats fire only at correct itinerary/scenario positions.
5. Save/load mid-chain; pre-0.6 saves unaffected.
6. Manual smoke of the Cass chain + one other; screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: chain/beat inventory, ending flags, prefix-sweep evidence, and
gate results. On an unfixable gate failure: stop at last green commit,
set `BLOCKED`, report verbatim.
