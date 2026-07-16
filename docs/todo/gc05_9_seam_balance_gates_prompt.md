# Agent Prompt — 0.5 Slice 9: Act 2 Seam, Full-Arc Balance, Design-Lock Update, Release Gates

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). This is the CLOSING slice of
the 0.5 Grand Casino rework; the binding design contract is
`docs/plans/0.5_grand_casino_rework_plan.md` (sections 9 + engineering
constraints) and the canonical-id contract is
`docs/plans/grand_casino_endgame_design.md`. Requires slices 1-8 landed —
verify each by code inspection before starting and report anything
missing (if a prior slice is absent, STOP and report; do not
reimplement it here).

## Task

### 1. Act 2 seam (D2)

- Gold-card clean victory sets `act_two_seam_ready = true` and logs the
  seam story entry consistent with `docs/plans/act_two_seam.md`. The
  run still ends as the Act 1 victory in 0.5 — the seam is a recorded
  door, not a playable transition.
- The run report/victory presentation mentions the seam in one line of
  copy ("the Gold card opens doors beyond this city") without promising
  UI that does not exist.

### 2. Full-arc balance pass (D1 — both routes stay hard)

- Play-test and tune BOTH paths end-to-end with the endgame metrics
  probe (`tools/endgame_metrics_probe.gd` / its wrapper — extend it to
  understand the new tier/duel/outcome states so winnability tooling
  stays honest):
  - Clean route: Bronze/Silver/Gold thresholds vs realistic bankroll
    curves; Linda's comps must help but never trivialize; the
    heat-ceiling squeeze must stay tense at Silver+.
  - Cheat route: Rourke-dodging must be learnable but never safe; the
    duel win rate for a prepared player lands in the owner-intended
    "hard boss" band; blatant pat-down fails must feel earned, not
    random.
  - The middle "shown the door" ending occurs at a meaningful rate —
    neither dominant nor vestigial.
- All retuning is DATA changes; log every value changed with before/
  after and the measured reason in the commit + report.

### 3. Design-lock document update

- Revise `docs/plans/grand_casino_endgame_design.md` to match shipped
  0.5 reality: three rooms, chips, tiers, Linda, phases, duel, ladder —
  preserving its canonical-id tables and marking superseded sections.
  One source of truth when this slice lands.
- Update README's implementation claims and CHANGELOG's 0.5 section
  (in-development framing until the owner publishes).

### 4. Full release gate battery (0.5 evidence)

Run and record, per-suite timeout = max(300s, baseline×1.5):

- `tools/validate_project.ps1`
- every supported `-FoundationSuite`
- `tools/foundation_performance_probe.ps1 -RequireGodot`
- `tools/foundation_soak_probe.ps1 -RequireGodot`
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- `tools/foundation_visual_qa.ps1` (zero warnings)
- `tools/foundation_mouse_batch_playtest.ps1` (strict, 60 runs)
- `tools/web_perf_smoke.ps1`
- endgame metrics probe across both routes and all three duel endings

Write the results to `.tmp/release_readiness_0_5_0.md` and cite it from
CHANGELOG truthfully (only what actually ran and passed).

## Hard rules

- Data-first tuning; no mechanical redesigns in this slice — genuine
  mechanical problems found here get REPORTED with evidence, not
  hot-patched.
- Determinism, zero-copy per-frame, idle liveness, canonical ids, save
  compat: all binding as in every slice.
- Never delete anything under `.tmp/`, `.tools/`, or `builds/`. Do not
  bump versions or touch publish steps — owner actions.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.

## On completion

Commit (tuning, seam, docs, evidence as separate logical commits),
delete this prompt file in the final commit, push, and report: the
balance table (every tuned value, before/after, why), route/ending
completion rates measured, the seam flag proof, and every gate result
with the readiness report path. Then list the owner's remaining manual
steps (playtest, packaging, upload, tag). On an unfixable gate failure:
stop at last green commit, report verbatim.
