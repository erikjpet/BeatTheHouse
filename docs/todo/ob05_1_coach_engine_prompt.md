# Agent Prompt — Onboarding Slice 1: The Coach Engine + First-Time Tips

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Immediate-mode canvas
rendering; UI via extracted components + pure view models
(foundation_main gains wiring only); content data-driven from
`data/*.json`; profile persistence is schema-versioned with atomic
writes. This file is self-contained; the binding design contract is
`docs/plans/0.5_onboarding_tutorial_plan.md` Part 1 — read it first.
No dependency on the Grand Casino rework; but if it has landed, its
surfaces (chips, card tiers) are valid tip subjects.

## Task

### 1. Lesson data + loader

- `data/tutorial/lessons.json`: each lesson declares `id`, `trigger`
  (screen, environment kind/archetype, game id, state predicates,
  dependency on other lesson ids), `anchor` (interactable object id /
  HUD element key / surface action / none), `copy`, `completion`
  (anchored action / any action / explicit OK), optional `gating`
  (tutorial-only; tips never gate).
- Load + validate through `ContentLibrary` like every other pack
  (ids unique, anchors well-formed, dependencies acyclic, referenced
  ids exist where checkable). Validation errors surface through the
  existing boot-time path.

### 2. CoachOverlay component

- New extracted component (`scripts/ui/coach_overlay.gd` +
  `coach_view_model.gd` pure builder): one bubble at a time, queued;
  anchored to canvas objects via the interaction-focus rect system
  (highlight + dim) or to HUD element keys; distinct "dealer's advice"
  visual identity using the existing VisualStyle palette and panel
  idioms. Non-blocking unless the lesson declares `gating`.
- Triggers evaluate at action boundaries / screen transitions only —
  find the existing refresh seams and hook there; never per frame.
  Bubble view model builds on state change only.

### 3. Profile seen-state + settings

- `tips_seen{}` and `tutorial_completed` persist in the PROFILE
  (extend the schema-versioned profile persistence; a legacy profile
  without the fields loads unchanged).
- Settings: "Coach tips: on/off" toggle + "Reset tips" action in the
  existing settings overlay.

### 4. Ship 6-8 first-time tips (normal runs)

Author these lessons (one-shot each, non-gating, exact copy per
`docs/plans/content_style_guide.md` voice): first heat gain, first debt
taken, first closing-time warning, first pawn interaction, first item
purchase, first travel/map open; plus, ONLY if the casino rework has
landed: first chips gained, first card tier. Verify each trigger
predicate against real state flags — no invented signals.

## Hard rules

- Zero-copy per-frame (bubble rendering reads a prepared snapshot);
  idle-animation liveness untouched; determinism unaffected (the coach
  observes state, never mutates simulation).
- Reduce-motion respected (no bubble animation, instant show/hide).
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports only.
  Suite timeout = max(300s, ceil(recorded baseline × 1.5)).
- SCHEDULING GUARD: do not run while the gc05 queue is mid-flight on
  this tree (gc05_*_prompt.md present in docs/todo) unless you are
  operating in an isolated worktree branch per an orchestrator's
  instructions — this task wires into foundation_main and the settings
  overlay, which that queue also touches.

## QA / Tests

1. Loader validation: bad lesson packs (dup ids, unknown anchor kind,
   cyclic deps) rejected with clear errors; shipped pack loads clean.
2. Trigger unit tests: each shipped tip fires exactly once for its
   scripted state, persists as seen across save/load AND across app
   restart (profile round-trip), and never fires with tips disabled.
3. Gating: a gating lesson blocks only what it declares; non-gating
   tips never block input (assert input routing).
4. UI suite: bubble anchors to a room object rect and a HUD key;
   small-screen mode fits.
5. Manual smoke: fresh profile, play until 4+ tips fire naturally;
   toggle off; reset; verify re-fire.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit (schema+loader; component; tips as logical units), delete this
prompt file in the final commit, push, report the lesson schema, the
tip list shipped, and gate results. On an unfixable gate failure: stop
at the last green commit and report verbatim.
