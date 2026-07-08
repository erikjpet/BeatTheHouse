## Execution Record

- Completion date: 2026-07-07
- Implementing/evidence commits:
  - `9904fda` - claimed the queue entry.
  - `502b008` - fixed the review-discovered 0.3.3 save compatibility coverage gap.
  - Archive/report commit - this commit.
- Deliverable: `docs/plans/v04_work_review_2026_07.md`
- Verification gates:
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` - PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite smoke -TimeoutSec 300` - PASS, report `.tmp\test_reports\20260707_232134_smoke\summary.json`.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300` - initial FAIL on the new review fixture shape, then PASS after `502b008`, report `.tmp\test_reports\20260707_232414_smoke\summary.json`.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300` - PASS, report `.tmp\test_reports\20260707_232519_smoke\summary.json`.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite contracts -TimeoutSec 420` - PASS, report `.tmp\test_reports\20260707_232658_smoke\summary.json`.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games -TimeoutSec 420` - PASS, report `.tmp\test_reports\20260707_232941_smoke\summary.json`.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite pull_tabs -TimeoutSec 300` - PASS, report `.tmp\test_reports\20260707_233225_smoke\summary.json`.
  - `powershell -ExecutionPolicy Bypass -File tools\collection_meta_check.ps1 -RequireGodot` - PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10 -SeedPrefix V04-REVIEW` - PASS, 10 seeds, 317 checkpoints, hash `4286288731`.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100` - PASS, stuck `0`.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot` - PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\environment_generation_audit.ps1 -RequireGodot` - PASS, 596 samples, 500 transitions, 0 failures.
  - `powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1` - PASS, report `.tmp\web_perf_smoke\report.summary.json`.
- Deviations:
  - The queue-level claim push was performed because `QUEUE.md` required it. The prompt's completion rule says do not push; completion commits after the claim were kept local.
  - `v04_meta_home_environment_prompt.md` was recorded as owner-rejected/superseded rather than treated as standalone-current; its live contract was verified through the critical meta-home rework archive.

# Agent Prompt - v0.4 Completed-Work Review And Confirmation Pass

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). An unusually large volume of work landed on
2026-07-06 and 2026-07-07: two full feature waves executed by multiple agent
sessions. Your job is an **adversarial verification pass** over every one of
those completed prompts: confirm the work is accurate (does what its prompt
required), complete (no silently skipped requirements), integrated (the
features work together, not just alone), and efficient (no perf-discipline
violations). You are a reviewer, not a re-implementer.

## Scope: what you are reviewing

Authoritative list: every prompt archived in `docs/todone/` with an
execution-record date of 2026-07-06 or later, plus the implementing commits
from `git log` since `c9a719d` (the 0.3.3 release commit). At writing time
that means at least:

dialogue_system, talk_content_pass, talk_overlay_decision_system,
attribute_glyph_system, time_system_open_hours,
environment_semantic_layout, jazz_club_content_completion,
beach_environment, item_meta_p0_collections_schema, item_meta_p1_bag_drops,
run_inventory_screen_extraction, playtest_root_fix + CRITICAL table-env fix,
v04_worktree_baseline_and_gate_recovery (incl. the table-surface idle perf
recovery commit), web_audio_bridge_modernization,
v04_content_style_guide_and_copy_audit, v04_meta_home_environment,
profile_persistence_completion, and act_two_seam (if archived by the time
you start — if it is still claimed in QUEUE.md, wait for it).

Derive the final list yourself from the archive + git log; do not trust this
paragraph over the repository.

## Method (per prompt, in archive order)

1. Read the prompt AND its execution record. Extract every numbered
   requirement, hard constraint, and claimed verification result.
2. Verify claims against the **current** tree, not the record: the feature
   waves landed nearly simultaneously and later work may have broken earlier
   work. Requirements are confirmed by reading the implementing code and by
   running targeted checks — not by the record saying PASS.
3. Exercise the feature through its test surface: run the specific
   foundation checks/harnesses the prompt named. Batch shared suites — run
   each FoundationSuite ONCE at the end for the union of prompts rather than
   per-prompt repeats; run cheap targeted harnesses
   (collection_meta_check, determinism, stuck sweep) as you go.
4. Hunt edge cases the original agent plausibly skipped. Minimum set:
   - Save/load round-trips mid-state for every new persistent field
     (dialogue node, talk queue, clock/eviction grace, meta store, profile
     history, act marker).
   - Old-save and corrupt-file loading for every store touched (RunState
     fixture, profile, meta collection, user settings).
   - **Upgrade-path fixture:** the existing RunState fixture is 0.3.0-era,
     but live players are on 0.3.3. Capture a genuine 0.3.3-shaped save
     (pre-dialogue/clock/act-marker fields) as a new committed fixture
     (follow scripts/tests/fixtures/run_state_0_3_0_save.json's pattern)
     and assert it loads and normalizes through every new field added this
     week. This is what protects real players who update to 0.4.
   - Rapid/hostile input on every new interactive surface (talk dock
     choices, dialogue advance, home interactions, pawn sell confirm, bag
     open) — no double-applies, no stranded overlays.
   - Determinism: two-process probe with seeds that exercise dialogue,
     talk events, eviction, and loadout injection together.
   - The owner-binding isolation rule: daily and challenge runs must not
     read or write the meta store, start at meta housing, or receive
     drops/decay. Verify by test, not by reading intent.

## Integration matrix (the part single-prompt review misses)

Explicitly test feature intersections; record each cell PASS/FAIL:

| Intersection | What to confirm |
| --- | --- |
| Talk dock × glyphs | Choice effect badges render and match applied consequences |
| Dialogue × time system | Closing-time eviction during a mid-conversation dialogue resolves per both contracts (event counts as grace action; conversation suspends, not strands) |
| Time system × world map | Closed venues block with "opens at" reasons; broke-eviction walk fallback works; revisit pricing scales with distance |
| Meta home × time/travel | Meta map is clockless and free; entering/leaving meta mode never advances or corrupts the run clock |
| Collections × inventory screen | Injected loadout items appear and behave in the run inventory; meta instance mapping survives save/load |
| Meta home × profile | Gold, housing tier, run history, and streaks all persist through the same restart cycle without cross-corruption |
| Jazz/beach content × generation | Environment generation audit passes; new venues respect open hours |
| Style guide checks × all new copy | The copy-audit foundation check passes over dialogue/talk/meta/home text added after the audit landed |

## Efficiency review (the codebase's standing disciplines)

- Grep every file added/heavily modified since `c9a719d` for per-frame
  violations: `duplicate(true)` in `_process`/`_draw` paths, per-frame
  ImageTexture creation, per-frame JSON stringify, unseeded `randf`.
- Confirm new UI (talk dock, home screens, reveal panel, badges) caches
  textures and only redraws on state change (the SA.2 tripwire patterns —
  extend a tripwire if you find an uncovered hot path).
- Confirm the baseline task's table-surface idle recovery (`066e479`) still
  holds: `tools\foundation_performance_probe.ps1 -RequireGodot` passes with
  the 0.3.2-era idle budgets.

## Deliverable

`docs/plans/v04_work_review_2026_07.md`: one row per reviewed prompt —
requirements verified / gates rerun / defects found — plus the integration
matrix and an efficiency-findings section. For every defect: fix it in place
if it is small and unambiguous (with its own local commit and a line in the
report); file a new docs/todo prompt (and QUEUE entry marked for PM review)
if it is structural. Zero unexplained FAILs may remain in the report.

## Hard constraints

1. Do not weaken, budget-bump, or delete any existing check to make a
   verification pass. If a check is wrong for intended new behavior, say so
   in the report and fix the check to assert the intended behavior.
2. Do not re-implement working features to your taste; this is verification.
3. One Godot instance at a time; check for running instances first.
4. Match house style in any fix (tabs, typed GDScript, sparse comments).

## Done gate

- Report written with every scope prompt covered and every integration cell
  filled.
- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
- Each FoundationSuite run once, green: smoke, systems, ui, contracts,
  games, pull_tabs (dialogue pilot), plus any suite a defect fix touched.
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10 -SeedPrefix V04-REVIEW`
- `tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- Prompt archived to `docs/todone/` with an execution record; QUEUE.md
  updated. Commit locally per queue lifecycle; do NOT push.
