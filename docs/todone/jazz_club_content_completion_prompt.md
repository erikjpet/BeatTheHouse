## Execution Record

- Completion date: 2026-07-07.
- Implementing commit: not created; pre-existing overlapping dirty changes in shared files made a task-only commit unsafe from this workspace state.
- Verification gates:
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` -> PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems` -> PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite contracts` -> PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\environment_generation_audit.ps1 -Runs 100 -Visits 6 -SeedPrefix JAZZ-CONTENT-20260707` -> PASS.
- Deviations:
  - The user explicitly requested this parked task, so it was executed despite the queue's blocked/parked note.
  - Local commit was skipped to avoid sweeping unrelated pre-existing dirty work into a misleading jazz-club commit.
  - `tools\check_godot.ps1 -RequireGodot -Suite Smoke` was also sampled: all early stages passed, but `foundation_perf_smoke` failed on pre-existing idle surface p95 budgets outside this jazz content scope.

# Agent Prompt - Jazz Club Content Completion (parked T4.2)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike - see CLAUDE.md). This promotes the parked Act-1 board task T4.2
(docs/plans/act_one_feature_complete_task_board.md:721). The jazz club is a
rare no-games room whose purpose must be legible: **a breather with an
angle** - heat-cooldown / luck-buff / story venue. Complete one venue
deeply instead of adding a shallow new one.

## What exists (read first)

- `data/environments/archetypes.json` -> `jazz_club` (layout, props, spots).
- `data/services/services.json` -> six jazz services already exist:
  `jazz_sax_round`, `jazz_cello_round`, `jazz_drummer_round`,
  `jazz_band_tip_jar`, `listen_to_jazz`, `show_drummer_glasses`. Audit what
  each actually does today and what the musician reward hooks reference.
- `data/events/events.json` -> check for club-scoped events (36 events
  currently; types include social/pressure/landmark).
- The talk dock and (if landed) dialogue system - the club is the showcase
  venue for conversational content.
- `scripts/ui/procedural_music_player.gd` - the club must sound distinct;
  verify its music profile actually differs in-room.

## Deliverables

### 1. Coherent service menu

The six services must form a legible menu with distinct, documented
effects - proposal (tune to what exists rather than rebuilding):

- Musician rounds (sax/cello/drummer): pick-your-flavor luck/heat/alcohol
  trade-offs, each mechanically distinct and stated in its summary.
- `jazz_band_tip_jar`: money -> heat cooldown over the next N actions (the
  "lay low with the band" move).
- `listen_to_jazz`: cheap/free small heat decay, time passes (integrates
  with the clock if the time system has landed - listening costs minutes).
- `show_drummer_glasses`: the story/reward hook (see 3).

Every service summary states its effect plainly (glyph badges via the
landed attribute system where applicable).

### 2. Two-to-three club-scoped events

Per T4.2's spec, author with talk presentation where a person speaks:

- **The trio**: a set-break conversation; choices trade money/luck/story.
- **A connected regular**: knows the underground scene; can mark a route
  or seed a story flag; wrong move = suspicion.
- **An after-hours invitation**: rare; seeds a concrete Grand Casino
  advantage (use an existing advantage/evidence hook from
  docs/plans/grand_casino_endgame_design.md - verify the exact key before
  writing data).

### 3. The musician reward, made concrete

The rare musician reward must be a real, visible thing: a specific item
(existing or one new items.json entry with icon via the icon-art pipeline)
that lands in inventory with story text, survives save/load, and is
referenced by the club events so the thread is followable.

### 4. Presentation check

Verify the club renders its distinct look and music profile in-room; fix
data (not engine) if the profile is wired but indistinct. If the time
system has landed, confirm the club's open hours feel right for the
fiction (evening venue) and adjust the data if the owner's table left it
proposed.

## Hard constraints

1. Data-first: services/events/items are content; touch engine code only
   if a documented effect (e.g. "heat decay over N actions") lacks an
   existing consequence key - and then extend the shared applier once, not
   per-service.
2. Seeded randomness only; talk entries follow the shipped talk contract.
3. Copy voice: terse, diegetic; simulated gambling only.
4. Coverage: (a) each service applies its documented effect (systems-suite
   checks), (b) club events gate to the club scope, (c) musician reward
   round-trips save/load, (d) environment generation audit still passes.
5. Match house style: tabs, typed GDScript, sparse constraint comments.

## Verification gates (run at the end)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. `tools\check_godot.ps1 -RequireGodot -FoundationSuite contracts` and
   `-FoundationSuite systems`.
3. `tools\environment_generation_audit.ps1 -RequireGodot` (or the current
   audit wrapper - check tools/ for the exact name).
4. Move this prompt to docs/todone/ with an execution record per RULES;
   update QUEUE.md. Commit locally; do NOT push.
