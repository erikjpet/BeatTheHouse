# Agent Prompts — Pinball Feature Rework Execution

Companion to `pinball_feature_rework_plan.md`. Three prompts:
- **Prompt A** — master build prompt (start here, fresh session).
- **Prompt B** — resume prompt (re-issue any time the agent stops early, a
  session ends, or context compacts).
- **Prompt C** — independent final acceptance audit (fresh session, after the
  builder claims completion).

---

## Prompt A — Master build

```
Read docs/plans/pinball_feature_rework_plan.md in full before doing anything
else. It is the binding spec for this task. Your job is to execute the complete
clean-room rework of the pinball slot feature event described there, through
ALL phases (0-6), and you must not declare the work complete until every
acceptance criterion at the bottom of this prompt is verified with fresh
command output.

ORIGINAL INTENT (the plan implements this; if the plan and this list ever
conflict, this list wins — flag the conflict in the progress doc):
1. Physics, bounces, and streaks of a real pinball table.
2. Feature sequence events like an actual pinball-branded slot machine feature
   (locks, multiball, jackpot ladders, lit inserts).
3. A skill-based, timing-based shot system where a skilled player — or a
   player with an edge through items — can reach large bonuses.
4. Quick playout with lifelike physics: plinko-board smoothness, with the ball
   able to be bumped BACK UP the board by bumpers, flippers, and launchers.
5. Fully designed machine layouts with named sequences that can be hit within
   each layout.
6. A dynamic plinko/pinball board interactable through nudges that adjust
   trajectory to reach higher-paying areas.
7. The end result must play like a round of Ballionaire — similar satisfaction
   and smoothness. Ballionaire is the explicit reference game and Phase 0
   requires researching it before any code is written.
8. The 6 implemented pinball items (drain_cleaner, jackpot_magnet,
   splitter_token, return_spring, tilt_dampener, bumper_battery) must all work
   in the new system, and new items must be added.
9. The rework must eliminate the game-wide slowdown during the feature (root
   cause and fix are specified in plan sections 1 and 3.2).

WORKING RULES
- Maintain docs/plans/pinball_rework_progress.md as your checkpoint file.
  After EVERY phase: record phase status, files changed, every verification
  command you ran, and a paste of its actual output (or a faithful summary
  with the pass/fail line verbatim). On startup, if this file already exists,
  resume from the first incomplete phase — never redo completed phases and
  never trust a phase marked complete without evidence recorded next to it.
- Phase 0 is mandatory and comes first: research Ballionaire using web search
  (store page, gameplay videos/reviews, design writeups or developer
  interviews) and write docs/plans/pinball_feel_reference.md per plan §9
  Phase 0. Extract NUMERIC feel targets (seconds per drop, events per second,
  bounce feel, tally presentation) and reconcile them against plan §3.4,
  updating §3.4 where they disagree. Every feel decision in later phases must
  cite this doc.
- Also in Phase 0: record a performance BASELINE of the current pinball
  feature (run tools/slot_pinball_performance_probe.gd via the pattern in
  tools/check_godot.ps1) so the final acceptance can prove the slowdown is
  gone by comparison.
- Commit at each phase boundary with a message naming the phase (per-phase
  commits are authorized for this task). Do not push unless asked.
- VERIFICATION GATES per phase are defined in plan §9 and §3.5. Run them with
  tools/check_godot.ps1 (see the suite definitions inside it for how probes
  are invoked headlessly). Known baseline: foundation_performance_probe
  slot-autoplay failures are PRE-EXISTING (see memory
  project_perf_probe_pre_existing) — do not chase them, but you must not
  introduce any NEW failures anywhere in the suite.
- If a gate fails: diagnose and fix, then re-run. You may not skip a gate,
  weaken a threshold, delete a failing assertion, or mark a phase done with a
  failing gate. If genuinely blocked after 3 distinct fix approaches, record
  the blocker with evidence in the progress doc, continue with independent
  work, and return to it before final acceptance.
- Never claim a criterion passes without the command output recorded in the
  progress doc. "It should work" is not evidence.
- Do not stop because the session is long, the context compacted, or a step
  failed. The only valid stopping points are: (a) all final acceptance
  criteria pass, or (b) a blocker that requires a decision only the user can
  make — and in that case state the blocker precisely and what you need.

FINAL ACCEPTANCE (run everything in one final pass with fresh outputs;
record under a "FINAL ACCEPTANCE" heading in the progress doc):
[ ] powershell -File tools/check_godot.ps1 -Suite Full passes, with no
    failures other than the documented pre-existing baseline.
[ ] Determinism probe: same seed + same input script produces identical
    results across 100 seeds.
[ ] Performance: rewritten pinball perf probe meets plan §3.5 budgets
    (sim tick <= 150us avg @ 4 balls, zero allocations per tick), and the
    Phase 0 baseline comparison shows the feature-time frame cost reduced by
    an order of magnitude — the slowdown is demonstrably gone.
[ ] All 3 boards (Bumper Alley, Lock & Cascade, Jackpot Works) playable end
    to end, and every named sequence in plan §4 is reachable and pays: skill
    shot, bumper streak, locks -> multiball, cascade, jackpot, super jackpot,
    wizard mode. Prove via scripted headless runs that hit each sequence.
[ ] Skill-edge probe: perfect-play policy beats random policy by the tuned
    margin in plan §5.4 (+15-25%) across 1000 seeds, always under session cap.
[ ] All 6 existing items verified active in the new sim via probe assertions;
    at least 3 new items from plan §6.2 implemented end to end (items.json,
    hooks, verified in probe).
[ ] Nudge, tilt meter, tilt dampener, and flipper rescue all functional and
    covered by a test or probe assertion.
[ ] scripts/games/slots/slot_pinball_table.gd is deleted and grep shows no
    remaining references to it or to the removed per-tick session
    round-tripping (pinball_session deep copies, slot_bonus_tick catch-up).
[ ] Every numeric feel target in docs/plans/pinball_feel_reference.md is
    checked off with a one-line rationale (met / consciously deviated + why).
[ ] Write a final summary in the progress doc mapping each of the 9 ORIGINAL
    INTENT points above to concrete evidence (file + probe output).

Only after every box is checked with evidence are you done. Your final message
must state each acceptance item with its result.
```

---

## Prompt B — Resume (re-issue on any early stop)

```
Continue the pinball feature rework. Read, in this order:
1. docs/plans/pinball_feature_rework_plan.md (the spec)
2. docs/plans/pinball_feel_reference.md (feel targets, if it exists yet)
3. docs/plans/pinball_rework_progress.md (your checkpoint)

Resume from the first phase that is not marked complete WITH recorded
verification evidence. If a phase is marked complete but has no evidence,
re-run its gates before trusting it. All working rules, gates, and the FINAL
ACCEPTANCE checklist from the original build prompt still apply (they are
restated at the top of the progress doc — if they are not, copy them there
from docs/plans/pinball_rework_agent_prompts.md Prompt A first). Do not stop
until final acceptance passes or you hit a user-decision blocker, which you
must state precisely.
```

---

## Prompt C — Independent final acceptance audit (fresh session)

```
You are auditing a completed rework, not building it. Do not take the
builder's word for anything.

Read docs/plans/pinball_feature_rework_plan.md,
docs/plans/pinball_feel_reference.md, and the FINAL ACCEPTANCE section of
docs/plans/pinball_rework_progress.md. Then independently RE-RUN every
acceptance gate yourself: check_godot.ps1 -Suite Full, the determinism probe,
the performance probe (compare against the Phase 0 baseline recorded in the
progress doc), the sequence-reachability runs for all 3 boards, the skill-edge
probe, and the item verification probes. Also grep for leftover references to
slot_pinball_table.gd and per-tick pinball_session deep-copying.

Then audit against the original request: (1) real-pinball physics with
bounces/streaks, (2) branded-pinball slot feature sequences, (3) timing-based
skill shot with item edge reaching large bonuses, (4) quick lifelike plinko
playout with bumpers/flippers/launchers returning the ball up-board,
(5) designed layouts with hittable sequences, (6) nudge trajectory control to
higher-pay areas, (7) Ballionaire-like satisfaction and smoothness per the
feel reference doc, (8) all 6 existing items + new items working, (9) the
feature-event slowdown eliminated with measured evidence.

Produce a verdict table: each item PASS (with your own fresh evidence, not the
progress doc's) or FAIL (with exact repro). If anything fails, fix it, re-run
the affected gates, and repeat until all pass. Your final message is the
verdict table.
```
