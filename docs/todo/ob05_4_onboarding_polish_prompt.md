# Agent Prompt — Onboarding Slice 4: Polish, Copy Pass, Fresh-Profile Gates

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). This file is self-contained;
the binding design contract is `docs/plans/0.5_onboarding_tutorial_plan.md`.
REQUIRES onboarding slices 1-3 landed. This is the closing onboarding
slice: polish and proof, no new mechanics.

## Task

1. **Copy pass**: every coach bubble and tutorial line read end-to-end
   in one sitting for voice (content style guide), brevity (one idea
   per bubble), and accuracy against the shipped mechanics. Fix drift.
2. **Small-screen + reduce-motion pass**: every bubble anchor, gating
   highlight, and tutorial scene verified in small-screen play mode and
   with reduce-motion on; fix clipping/overlap (tabs-never-scroll rules
   apply to any multi-part surfaces).
3. **Timing tune**: the guided path must land under ~15 minutes; if
   slice 3's measurement exceeded it, trim beats via data (shorter
   gating, fewer forced inspections), never by cutting the seven-beat
   structure.
4. **Fresh-profile proof matrix** (manual + scripted where possible):
   - brand-new profile → full tutorial → win → starter card → first
     normal run with prestige tip;
   - skip at beat 1 and at beat 6 → clean normal play after;
   - replay-from-menu on a veteran profile;
   - tips-off profile → zero coach anywhere;
   - legacy profile (pre-onboarding fields) → loads, never sees the
     tutorial, tips fire normally.
5. **Web export smoke**: the tutorial is most new players' first
   session ON ITCH — run the web perf smoke and click through the full
   tutorial in the web export; report load/perf feel and any
   web-specific issues found (fix in-scope ones).

## Hard rules

- Data/copy/layout changes only; mechanical changes get reported, not
  hot-patched. Determinism, zero-copy per-frame, idle liveness binding.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- `tools/web_perf_smoke.ps1`
- `tools/foundation_mouse_playtest.ps1` (strict single run)

## On completion

Commit, delete this prompt file in the final commit, push, report the
proof-matrix results, measured tutorial duration, and gate results. On
an unfixable gate failure: stop at the last green commit and report
verbatim.
