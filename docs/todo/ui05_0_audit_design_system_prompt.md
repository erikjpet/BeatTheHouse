# Agent Prompt — UI Overhaul Phase 0: Surface Audit + Design-Token Foundation

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720; small-screen play mode
exists). UI is code-built (no scenes beyond main): `VisualStyle` palette,
`FoundationWidgets` helpers, extracted screen components under
`scripts/ui/`. This file is self-contained; the binding design brief is
`docs/plans/0.5_ui_overhaul_brief.md` — read it first, including the
design philosophy you are implementing the foundation for. THIS PHASE
RUNS LAST IN 0.5 — refuse to start if any gc05_*, audio_jazz_*, ob05_*,
or other feature prompt remains in docs/todo (report and stop; the
overhaul skins a finished game).

## Task

### 1. Full UI surface inventory + heuristics audit (report deliverable)

Enumerate EVERY player-facing surface (the brief's scope list is the
starting checklist — verify and extend it from code). For each surface
record: owning component/file, entry points, layout approach, which
VisualStyle/FoundationWidgets pieces it uses vs hand-rolled styling,
small-screen behavior, reduce-motion behavior, and heuristic findings
(hierarchy problems, inconsistent spacing/type/colors, missing states,
overflow risks). Capture screenshots per surface (the promo capture
tool `tools/promo_screenshots_0_4.gd` shows the drive-and-capture
pattern; extend a variant to walk surfaces). Write the audit to
`docs/plans/0.5_ui_audit_report.md` (this one belongs in the repo, not
.tmp — later phase prompts are authored from it) with a
priority-ordered fix list per surface.

### 2. Design-token foundation

- Extend `VisualStyle` into a real token system: spacing scale, type
  scale (named steps, not raw sizes), color ROLES (surface, panel,
  accent-primary/danger/success, text-primary/muted), radii, border
  widths, and interaction states (idle/hover/press/focus/disabled) —
  as named constants consumed by widgets, with the current visual
  identity preserved (this is codifying the look, not changing it).
- Extend `FoundationWidgets` into the widget kit: panel, heading,
  label, button variants (primary/secondary/danger/ghost), list row,
  stat chip, tab bar — each built from tokens, each with all
  interaction states, each safe in small-screen mode.

### 3. Prove it on ONE screen

Migrate the SETTINGS overlay (lowest-risk, every widget type present)
to the token system end-to-end as the reference implementation. No
other screen changes in this phase — the audit report plus one proven
screen is the deliverable that phase 1-2 prompts get authored from.

## Hard rules

- Visual identity preserved: the settings screen after migration should
  read as "the same game, tidier" — before/after captures required.
- Zero-copy per-frame; idle-animation liveness untouched; perf probe
  surfaces stay in budget.
- Zero behavior change anywhere; zero changes to non-settings screens
  beyond additive token/widget definitions.
- Style: tabs, typed GDScript, sparse comments; audit report in
  docs/plans, working captures under `.tmp/`. Suite timeout =
  max(300s, ceil(recorded baseline × 1.5)).

## QA / Tests

1. UI suite green; settings overlay exercises every widget variant
   (extend its checks to cover the new states).
2. Small-screen + reduce-motion verification on settings.
3. Visual QA route pass; before/after captures of settings attached to
   the report.
4. Token adoption assertion: settings contains no raw color/size
   literals outside the token system (scripted check).

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_performance_probe.ps1 -RequireGodot`

## On completion

Commit (tokens/kit; settings migration; audit report as logical units),
delete this prompt file in the final commit, push, and report: the
audit's top-10 priority findings, the token/widget API summary, and
gate results. Then STOP — phases 1-3 are authored from your report plus
the owner's answers to the brief's open questions. On an unfixable gate
failure: stop at the last green commit and report verbatim.
