Status: DONE
Board row: `fix06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-14
- **Completion/implementation commits:** `0204c373`, `31f2e605`, `5c1ea0c6`, `7f24fada`
- **Verification:** `tools/validate_project.ps1`; foundation `systems`, `ui`, and `all`; 10-seed determinism (350 checkpoints, hash `1671116934`); full visual QA (58 states, zero warnings); 99-event before/after catalog audit (32 authored speakers, 67 synthesized, only 3 beach events changed); broken synthesized-speaker fixture rejected by `interactable_event_class_guard`.
- **Deviations:** None.

# Agent Prompt — 0.6 fix06_1: Dead Scenario Event Interactions (Beach) + Interactability Class Guard

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Owner-reported
defect, PM-reproduced 2026-08-14 with headless probes. This prompt is
self-contained for rules and scope.

## The confirmed defect (root-caused; verify, then fix)

All three beach scenario events (`scenario_bonfire_story`,
`scenario_storm_stranger`, `scenario_festival_lucky_pitch`) place
their icons in generated beach environments but silently refuse all
interaction — icons with no action. Root cause chain:

1. The authored definitions in `data/events/events.json` declare **no
   `speaker`**.
2. `ContentLibrary` event normalization injects a default speaker
   dictionary with `environment_actor: true`.
3. `EventModule._event_requires_room_actor()`
   (`scripts/core/event_module.gd:461`) sees the non-empty normalized
   speaker with `environment_actor: true` → requires a room actor.
4. `EventModule._environment_allows_room_actor()`
   (`scripts/core/event_module.gd:472`) hard-denies kind `recovery`
   AND archetype `beach` → `can_trigger` returns false.
5. The icon still renders (placement reads `event_ids` at
   generation), but `_eligible_event_option` → empty → the context
   card shows "Nothing is happening here right now."

Evidence: 15-seed interaction probe — 39/42 scenario events pass the
full `can_trigger` + `choices` chain; the only failures are these
three, all at the beach. Punchline L2 events verified working (layer
flattening presents `kind: casino`).

## Task

### 1. Root fix (generic — no beach special case, no event allowlist)

- Fix the normalization/requirement mismatch at its root: a speaker
  that was **synthesized by normalization** (not authored) must not
  make an event require a room actor. Preferred shape: the
  normalizer marks synthesized speakers (`environment_actor: false`
  on synthesis, or an explicit authored-flag), so
  `_event_requires_room_actor` only demands an actor when the
  authored data actually declared one. Choose the cleanest
  implementation consistent with code reality — but it must be
  generic and data-driven, never keyed to event ids or the beach.
- Regression duty: prove no shipped event changes behavior. Any
  event that authored its own `speaker` keeps exact current
  semantics; events that never authored one (audit the full
  `events.json`) must be listed in your report with before/after
  `can_trigger` results in their host environments — behavior may
  only change from "silently dead" to "working" (or stay identical).
- The three beach events must present their authored choices in the
  real context-card path and resolve their consequences end-to-end.

### 2. The class guard (this is why the defect survived three waves)

- Promote the interaction probe into a permanent foundation contract
  test (`scripts/tests/foundation/` family): for a seeded sweep of
  generated environments across ALL archetypes (including entered
  Punchline layers), **every** `interactable`-mode event id present
  in `event_ids` must yield `can_trigger == true` and non-empty
  `choices` — i.e., an icon may never exist without a working
  interaction. Legitimately conditional events (heat/tier/flag-gated)
  must be expressed through their conditions so the guard can
  recognize an intentionally-dormant event (assert the gate reason is
  an authored condition, never a normalization artifact); document
  the mechanism in the test.
- Wire the guard into the standard foundation suite so Waves D/E
  events (heist, chains, content pass) inherit the protection
  automatically.

### 3. UI click-through spot check

- Extend the visual-QA/mouse-playtest tooling with one scripted
  click: open a scenario event icon in a generated environment and
  capture the context card showing its choice buttons (evidence to
  `.tmp/`). One venue is enough — the class guard covers breadth;
  this covers the UI seam the model-level guard cannot see.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `fix06_1`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[fix06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Hard rules

- Generic fix only: no event-id allowlists, no beach/archetype
  special cases in the requirement logic.
- Never weaken `_environment_allows_room_actor` itself — the beach
  staying actor-free is shipped design; the fix is that actor-free
  events stop demanding actors.
- Determinism, perf, save-compat, voice, and style rules as all 0.6
  prompts (tabs, typed GDScript, `.tmp/` reports, suite timeout =
  max(300s, baseline×1.5)).

## QA / Tests

1. The three beach events: full interaction end-to-end in a seeded
   run (choices presented, consequences applied, resolve flags set).
2. The class guard passes on the current tree and FAILS when a test
   fixture reintroduces the defect (prove both directions).
3. Full-events audit table in the report (authored-speaker vs
   synthesized) with zero behavior changes outside the dead-icon
   class.
4. UI click-through capture attached.
5. Standard gates green.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: the chosen normalization fix, the audit table, guard test
name, and gate results. On an unfixable gate failure: stop at last
green commit, set `BLOCKED`, report verbatim.
