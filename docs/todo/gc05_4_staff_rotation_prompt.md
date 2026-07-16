# Agent Prompt — 0.5 Slice 4: Casino Memory + Daily Staff Rotation

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Data-driven content; seeded
RNG via `RngStream` forks; day rollover already exists in the clock
system (`run_state.gd` day rollover helpers). This file is
self-contained; the binding design contract is
`docs/plans/0.5_grand_casino_rework_plan.md` section 4 — read it first.
Requires slices 1-3 landed; re-verify their actual code.

## Task

1. **Within-run memory, surfaced.** The casino already persists
   attention/evidence/counters across visits. Surface it: on re-entry,
   a short authored line reflects what the staff remembers (e.g. a
   pending review, prior showdown pressure, high prior heat) — pick
   from a small data-authored line table keyed by the dominant
   remembered state. No new state; presentation of existing flags.
2. **Daily soft reset (seeded).** On in-run day rollover, roll a seeded
   per-day staff assignment for the Grand Casino:
   - Dealer identity per table MAY change (visual identity + name line;
     a fresh dealer resets any per-table familiarity/tell state that
     exists — audit what per-dealer state the table games actually
     track and reset exactly that; do not invent new familiarity
     mechanics in this slice).
   - The bartender MAY change (resets bar comp state if any exists).
   - The rival-cheater cast rerolls (slice 3's daily cast already keys
     by day — verify and align).
   - "Or not": each rotation is an independent seeded chance *(tunable,
     propose 50%)*; some days nothing changes.
   - **Rourke and Linda NEVER rotate.**
3. Rotation draws from a fork keyed by day index
   (`create_rng("gc_staff_day:%d")` style) so the same seed always
   produces the same staffing timeline regardless of visit order.
4. A subtle presentation cue on first entry of a new day ("new face at
   the felt") when rotation occurred.

## Hard rules

- Determinism: rotation independent of visit order and action count
  within the day (keyed by day index only); probe stays
  self-consistent.
- Zero-copy per-frame; idle liveness untouched; rotation evaluated at
  the existing day-rollover boundary only.
- Save compat: staffing state serializes; loading mid-day reproduces
  the same staff. Canonical ids/flags unchanged.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Same seed → identical staffing timeline across replays and across
   different visit orders; save/load mid-day preserves staff.
2. Rotation resets exactly the audited per-dealer/bar state and nothing
   else (regression: heat, evidence, counters, card progress all
   survive day rollover).
3. Rourke/Linda identity stable across all days.
4. Re-entry memory lines fire for the right dominant state.
5. Manual smoke: sleep/roll a day, spot a changed dealer, confirm a
   no-change day also occurs on some seed.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit, delete this prompt file in the final commit, push, report the
audited per-dealer state that rotation resets, tunables, and gate
results. On an unfixable gate failure: stop at last green commit, report
verbatim.
