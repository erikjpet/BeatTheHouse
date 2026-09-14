Status: DONE — fixes uncommitted in worktree, awaiting owner review
Source report: `docs/plans/agent_playtest/agent_playtest_report_2026-09-12.md` (23 findings, BUG-01 … BUG-23)

# Agent Prompt — Playtest Fixes 01: Validate and Fix the 2026-09-12 Agent Sweep

Copy everything below this line into the agent.

---

You are working on **Beat The House**, a Godot 4.6 GDScript roguelite. This
prompt is self-contained: every rule you need is below. Read the named code
before editing — do not plan from this prompt alone.

## Goal

A four-agent playtest sweep produced a report of 23 bugs:
`D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_report_2026-09-12.md`.
Read it in full first. The owner wants **every valid bug fixed**.

**The report is a set of claims, not facts.** For each bug you must:

1. **independently prove it is real** on the current code;
2. **find its actual root cause** — the report's "Likely cause" is a
   hypothesis with a confidence level;
3. only then **fix it**.

Bugs you cannot prove are not fixed. They are reported back with evidence.

## Hard rules

- **No commits, no pushes, no merges, no stashes, no resets** — anywhere. Leave
  all changes uncommitted in the fix worktree for owner review.
- Other agents are working in `D:\Projects\Beat-The-House` with uncommitted
  changes. **Do not edit, stage, or run the game from that checkout.** Several of
  those uncommitted files overlap this work:
  - `scripts/ui/pixel_scene_canvas.gd`
  - `scripts/ui/environment_interaction_controller.gd`
  - `scripts/ui/environment_interaction_view_model.gd`
  - `scripts/core/environment_placement.gd`
  - `scripts/core/run_state.gd`

  The only files you may create or edit in the main checkout are:
  - the fix report named in "Deliverables";
  - the execution record at the bottom of this file.
- Two other worktrees also touch files in this scope:
  - `D:\Projects\Beat-The-House-worktrees\backroom-poker-tweaks`: heavy
    `scripts/games/crew_draw_poker.gd` changes;
  - `D:\Projects\Beat-The-House-worktrees\game-prop-art`: room-prop drawing in
    `pixel_scene_canvas.gd`.

  Do not touch those worktrees. Keep your diffs in shared files minimal and
  local, and list every function you changed in those files so the owner can
  merge.
- **Validate before fixing, always.** No product code changes for a bug until its
  validation record (section 3) is written.
- **Fix root causes, not symptoms.** Keep each fix to what the bug needs.
  - No drive-by refactors, balance changes, or voice rewrites.
  - No changes to deterministic generation outcomes for valid seeds.
- **Design boundary:** use the report's **Recommended** option. If validation
  shows it is wrong or insufficient, use the smallest correct fix and record the
  deviation. If the only correct fix changes game design, stop on that bug and
  record it as an owner decision. Examples: removing double-click purchase,
  making Instant Coffee an active item, honoring typed seeds in the tutorial.
- Scratch output, screenshots, logs, and harness sessions go under
  `.tmp/playtest_fixes01/` in the fix worktree (ignored, never committed).

## 1. Worktree and harness

- Base: local `main` (`git -C D:\Projects\Beat-The-House rev-parse main`). The
  report tested `56de66598a2bcdbc3f171f090b48c361daf35563`. If `main` has moved,
  note it: each bug must be validated on the new base.
- Create the fix worktree (reuse it if it exists and is clean):
  `git -C D:\Projects\Beat-The-House worktree add -b codex/agent-playtest-fixes D:\Projects\Beat-The-House-worktrees\playtest-fixes main`
- Godot: the main checkout's `.tools\godot-4.6-stable\` console exe or
  `$env:GODOT_BIN`. Point `GODOT_BIN` at it; do not copy `.tools`.
- **Interactive harness:** the sweep built `tools/agent_playtest_session.gd` and
  `tools/agent_playtest_session.ps1`, which exist only as untracked files in
  `D:\Projects\Beat-The-House-worktrees\agent-playtest`. Copy both into the
  fix worktree's `tools/`.
  - Read their header comments to learn the command-file protocol: `look`,
    `click_button`, `click_object`, `click_action`, `click_xy`, `key`, `type`,
    `wait`, `quit`. It also sets per-session persistence isolation via
    `BTH_DISTRIBUTION_DATA_ROOT` and the settings/inventory/meta env vars.
  - They are validation tooling, not fixes: list them separately in the report.
- **Original evidence** (each bug links to it): screenshots, command files, result
  JSON, notes and logs under
  `D:\Projects\Beat-The-House-worktrees\agent-playtest\.tmp\agent_playtest\2026-09-12\<session>\`.
  Each session's `notes.md` holds the seed and command sequence behind each
  finding. Read-only.
- Run `powershell -File tools\validate_project.ps1` in the fix worktree and
  record the baseline. Run the validation gates from section 6 once on the
  untouched base and record every failure as **pre-existing** before you change
  anything.

## 2. Bug groups (shared root causes — validate individually, fix together where the cause is shared)

| Group | Bugs | Area |
|---|---|---|
| G1 Run lifecycle | BUG-01 | new run / abandon / generator / save |
| G2 Coin pusher exit | BUG-02 | `foundation_main.gd` exit settlement, `coin_pusher.gd` settle jobs |
| G3 Money & canonical results | BUG-03, BUG-08, BUG-09, BUG-13, BUG-16 | pre-funded wagers, Numbers Book/Silas, HUD wallet delta, event-loan result |
| G4 SFX cue contracts | BUG-04, BUG-15 | `craps.gd`, `events.json`, `surface_sfx_manifest.json`, `sfx_player.gd` |
| G5 Tutorial & modal ownership | BUG-05, BUG-06, BUG-07, BUG-19, BUG-23 | `coach_overlay.gd`, talk dock, Settings/Inventory/Run Menu, Run Setup |
| G6 Room objects & copy | BUG-10, BUG-12, BUG-14, BUG-17, BUG-18, BUG-22 | interaction view model/canvas, item purchase, Dave text, risk copy, result panel, item behaviour copy |
| G7 Game surfaces | BUG-11, BUG-20, BUG-21 | Video Poker, Roulette, Back-Room Poker raise panel |

You may use sub-agents to **validate** groups in parallel. Each needs its own
harness session name and persistence root. **All code changes are made
serially by you** in the single fix worktree, so edits never collide.

## 3. Validation protocol (every bug, before any fix)

For each BUG-NN:

1. **Reproduce through the player path.** Replay the original route with the
   harness from the recorded seed and command sequence, on the unfixed base. Try
   at least twice, from a fresh persistence root each time. Capture PNG + result
   JSON.
2. **Confirm in code.** Read the code the report names and trace the real path.
   Confirm or correct the root cause, with file:function:line.
3. **Write a failing regression test** at the lowest production seam that proves
   the bug. Examples: a module-level surface command test, a result-pipeline
   test, a static contract scan. Add it to the existing test file for that area;
   do not create a parallel suite. Run it and confirm it **fails on the
   unfixed base**.
4. **Classify:**
   - `VALID`: reproduced through the player path **or** proven by a failing
     test that uses the production seam, with root cause confirmed in code.
   - `VALID-DIFFERENT-CAUSE`: the bug is real, but the report's cause is wrong.
     Record the real one.
   - `ALREADY FIXED`: does not reproduce on the current base, and the code shows
     why (cite the commit if found).
   - `NOT REPRODUCIBLE`: at least two faithful replays plus a code trace show no
     defect path. Record exactly what you tried.
   - `NOT A BUG`: working as designed. Cite the design source (data, plan doc,
     test contract).
   - `HARNESS ARTIFACT`: the sweep harness caused it (wrong target, timing,
     isolation leak). Fix the harness copy if cheap.
   - `OWNER DECISION`: real, but every correct fix changes design.
   - `OWNED ELSEWHERE`: real, but an in-flight worktree or the main checkout's
     uncommitted work already changes that exact code path. Check read-only
     with `git -C <path> diff` / `git -C <path> log main..HEAD`. Record what it
     changes and whether it would fix the bug. Do not duplicate the fix.
5. Write the validation record into the fix report (section 7) **before**
   touching product code for that bug.

Only `VALID` and `VALID-DIFFERENT-CAUSE` bugs get fixed.

## 4. Per-bug requirements (apply after validation)

Line numbers are from the report on `56de6659`; re-locate them.

**G1 — BUG-01 empty room after abandon/restart.**
- Find *why* generation yields an empty `current_environment` after the
  tutorial-skip → abandon → New Run → Main Menu → typed-seed sequence. Suspect
  stale generator/run state reused across runs. Fix that cause.
- Also make new-run creation transactional:
  - validate a non-empty environment with at least one safe exit before first
    render and autosave;
  - on failure, return to Run Setup with a clear message, and never autosave
    the broken state.
- **Existing broken saves:** Continue on a save with an empty/exitless
  environment must recover to a safe playable state (e.g. regenerate the current
  node deterministically, or open the world map) instead of soft-locking. Add a
  fixture-based test with a new fixture; never rewrite golden fixtures in
  `scripts/tests/fixtures/`.
- Prove same seed ⇒ same first room for normal (non-abandon) starts before and
  after.

**G2 — BUG-02 coin pusher Leave never completes.**
- Exit settlement must finish within a fixed bound: `MAX_SETTLE_TICKS` or
  equivalent. Find the path where a recovered shim clears completion and fix it.
- At the bound, force a final stable, deterministic projection. Payouts for
  coins already committed to fall must be settled exactly, never silently
  dropped. Show an on-screen "Leaving…" status while settling.
- Cover all three machines (Quarter Falls, Jackpot Ridge, Vault Drop), including
  after slam nudge, repeated Leave clicks, Run Menu open during settlement, and
  save/quit during settlement.
- Keep the native Coin Pusher library contracts green (`-FoundationSuite coin_pusher`).
  Performance must stay within budget and idle liveness must pass.

**G3 — money and results.**
- **BUG-03:** give exactly one layer ownership of each wager cost. Then **audit
  every game that goes through the pre-funded Grand Casino / practice wager
  path** (`foundation_main.gd` pre-fund + each module's returned
  `bankroll_delta`): pull tabs, scratch tickets, and any other module using it.
  Add a conservation test per module: bankroll change == displayed cost ±
  displayed winnings.
- **BUG-08, BUG-09, BUG-16:** locate the canonical result/acknowledgement
  pipeline other money actions use (`last_hook_result` / recent-result /
  structured HUD). Route Numbers slips, Silas's tip, and the Counter Phone family
  loan through it, so wallet, Result panel, and message update immediately.
  - **BUG-09** also needs model-level idempotency: a second purchase is rejected
    without charging, and the button is disabled or hidden after purchase.
  - Check other one-time purchases in `numbers_model.gd` for the same missing
    guard.
- **BUG-13:** reset the HUD wallet delta on every practice launch from the Games
  library.

**G4 — SFX cues.**
- **BUG-04:** Craps emits its own profile's event classes (`chip_place` /
  `chip_collect` or whatever the `craps_table` profile defines), and the stuck
  command no longer happens. Confirm the hang is caused by the error, not a
  separate issue.
- **BUG-15:** add `phone_call` to `crew_world` in `surface_sfx_manifest.json`
  with its visual-event counterpart, following the existing entries. Use an
  existing audio master if no dedicated one exists, and note it.
- **Add one contract test** that scans every SFX event class emitted from game
  modules and `data/**/*.json` events and asserts each exists in the profile it
  is emitted under. Fix any other mismatches it finds; each one is a validated
  bug by construction. List them.

**G5 — tutorial and modals.** Run
`scripts/tests/tutorial_guardrail_recovery_stress_check.gd`,
`tutorial_dialogue_trigger_cadence_check.gd`,
`tutorial_talk_target_nonoverlap_check.gd` and
`tutorial_corner_shop_order_check.gd` before and after.
- **BUG-05:** while Settings, Inventory, or Run Menu owns input, suspend the
  tutorial talk dock/dialogue. Restore it, with any queued dialogue intact, on
  close.
- **BUG-06:** after dialogue acknowledgement, keep the active lesson's
  instruction visible, e.g. as the pointer presentation, until the required
  action completes.
- **BUG-07:** coach overlay actions must consume input so nothing underneath
  (including native `OptionButton` popups) receives it. Only allowed tutorial
  actions pass through.
- **BUG-19:** during the mandatory first-night lesson, disable the Run Setup
  seed field and say why. Do not change which seed the tutorial uses.
- **BUG-23:** trap Tab/Shift-Tab focus inside Settings, and restore the prior
  focus owner on close. Apply the same trap to Inventory and Run Menu if they
  share the defect (validate them).

**G6 — room objects and copy.**
- **BUG-10:** Vic Mercer in the Punchline back room. First check the main
  checkout's uncommitted reusable-spawn-slot work (read-only diff of
  `environment_interaction_view_model.gd`, `pixel_scene_canvas.gd`,
  `environment_placement.gd`, `scenario_layout_resolver.gd`). If it changes this
  path, classify `OWNED ELSEWHERE` and state whether it resolves Vic.
  Otherwise:
  - fix Vic;
  - add an audit that every enabled interactive object in every
    reachable room has both a drawn entry and a hit entry. Build it on the
    existing environment audits and tools (e.g.
    `tools/environment_layout_screenshots.gd`, the scenario finalization tools).
  - Fix any other objects the audit finds.
- **BUG-12:** after a double-click purchase, the panel shows the purchased
  item's result and its offer is removed or disabled before any affinity
  refocus. Keep double-click purchase.
- **BUG-14:** when Dave has no previous node, use a placeholder-free fallback
  line in the file's existing voice. Also scan `characters.json` / town-network
  templates for other placeholders that can resolve empty. Add a test that no
  rendered character line contains an empty substitution (`" ."`, `"{"`, a
  double space before punctuation).
- **BUG-17:** game detail cards show game-local risk copy. Render travel
  suspicion cues separately. No raw or title-cased internal IDs reach
  player-facing text. Add a test.
- **BUG-18:** the travel Result panel wraps to fit, measured by rendered width.
  Check normal and small-screen layouts with screenshots.
- **BUG-22:** base the item behaviour summary on active/passive capability, not
  `class` alone. Instant Coffee reads as passive. Check every item in
  `items.json` for the same mismatch and add a test.

**G7 — game surfaces.**
- **BUG-11:** Video Poker denomination/bet commands change only the wager. They
  never deal, and every new hand starts with no holds. Keep the Video Poker
  suite and idle liveness green.
- **BUG-20:** Roulette rim labels stay inside the wheel region during idle, spin
  and result. Verify with screenshots and the Roulette visual capture if one
  exists. No per-frame allocations; liveness passes.
- **BUG-21:** Back-Room Poker raise decrement controls are disabled, with
  disabled styling and no registered hit, at the minimum; increment likewise at
  the maximum. This file changes heavily on `codex/backroom-poker-tweaks`:
  touch only the raise-panel boundary logic and record the exact hunk for the
  merge.

## 5. Engineering rules (hard repo rules)

- GDScript: tabs, static typing on new vars/functions, match surrounding naming
  and idiom; comments only where a constraint isn't obvious.
- **Zero-copy per frame.** Nothing added to draw, `_process`, or per-frame code
  may `duplicate()` or build collections. A past per-frame deep copy cost
  32.6 ms/frame.
- **Idle liveness gate:** perf work here has frozen idle animation four times
  because idle budgets reward 0.000. Any touched surface (coin pusher, roulette,
  video poker, poker) must still pass its idle liveness counter. Never accept a
  0.000 idle cost without the liveness check.
- Determinism: all randomness via the provided RNG streams. Save/load round
  trips stay stable. If any saved state shape changes, bump the version with a
  migration and a test.
- Hidden information stays hidden. Presentation never receives future outcomes
  or hidden cards.
- Build on existing tests, tools and seams; no parallel harnesses.

## 6. Validation gates (in the fix worktree, after all fixes)

1. `powershell -File tools\validate_project.ps1`
2. `powershell -File tools\check_godot.ps1 -RequireGodot -Suite Smoke`
3. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games`
4. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems`
5. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui`
6. Game suites for every touched game: `-FoundationSuite coin_pusher`, `pull_tabs`,
   `scratch_tickets`, `craps`, `video_poker`, `roulette`, `crew_poker`.
7. The four tutorial checks listed in G5.
8. Every new regression test: **red on base, green after fix**. Record both runs.
9. `tools/foundation_performance_probe.gd` for coin pusher, roulette, video poker,
   crew poker and a room scene: within `tools/perf06_budget_table.json`,
   liveness passing, before/after numbers recorded.
10. **Player-path replay:** for every fixed bug, replay its original harness route
    on the fixed build and capture the "after" PNG + result JSON. Then run a short
    regression play in each group area (≈40 actions each) to catch fixes that
    broke neighbouring behaviour. Include one full save → quit → relaunch →
    Continue.

A gate that also fails on the untouched base is pre-existing: record it and
don't fix unrelated failures. A new failure is yours to fix before completion.

## 7. Deliverables

Write the fix report in the **main checkout**:
`D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_fixes_2026-09-12.md`

Do not edit the original sweep report. Structure:

1. **Header**
   - base commit;
   - fix worktree path and branch (uncommitted);
   - harness files copied;
   - pre-existing gate failures.
2. **Summary table:** one row per BUG-01…23 with:
   - validation class and root cause (confirmed or corrected);
   - fixed? (yes / no + why);
   - regression test name;
   - files changed;
   - before/after evidence links.
3. **Per-bug records:**
   - validation steps and results (replays, test red run);
   - root-cause trace;
   - the fix, and any deviation from the Recommended option;
   - test green run;
   - after-evidence;
   - anything related found and fixed (e.g. other SFX mismatches, other
     one-time purchases, other hidden room objects).
4. **Not fixed:** every bug classified other than VALID, with evidence and what
   the owner needs to decide or who owns it.
5. **Merge notes:** every function changed in files that overlap the main
   checkout's uncommitted work, `backroom-poker-tweaks`, or `game-prop-art`.
6. **Gates and performance:** results, pre-existing vs new, perf before/after.
7. **Changed files list,** grouped by bug.

## 8. Completion

1. `git -C D:\Projects\Beat-The-House status` shows nothing from you except the
   fix report and this prompt file. The fix worktree holds all code changes,
   uncommitted.
2. Quit all harness sessions, and make sure no Godot processes you started are
   still running.
3. Append an execution record to the bottom of **this file**
   (`D:\Projects\Beat-The-House\docs\todo\playtest_fixes01_agent_sweep_2026-09-12_prompt.md`)
   with:
   - date and base commit;
   - fix report path;
   - counts per validation class;
   - fixed count;
   - gate results;
   - owner decisions needed.

   Change `Status: READY` to `Status: DONE — fixes uncommitted in worktree,
   awaiting owner review`. Do not move the file.

If a gate fails and you cannot resolve it without exceeding a bug's scope, leave
the work uncommitted, set `Status: BLOCKED`, and paste the failing output
verbatim into the execution record.

## Execution record — 2026-09-12/13

- Base commit: `56de66598a2bcdbc3f171f090b48c361daf35563`.
- Fix report: `D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_fixes_2026-09-12.md`.
- Fix worktree/branch: `D:\Projects\Beat-The-House-worktrees\playtest-fixes`, `codex/agent-playtest-fixes`; all changes remain uncommitted.
- Validation classes: 22 VALID, 1 OWNED ELSEWHERE, 0 NOT-A-BUG, 0 NEEDS-DESIGN.
- Fixed: 22 of 22 owned VALID bugs. BUG-10 was not changed because its Vic/lender placement path overlaps the main checkout's in-progress reusable spawn-slot work.
- Regression proof: `playtest_fixes01_regressions` failed 22 assertions on the untouched base and passed after the fixes; `coin_pusher_exit_settle_bound` passed for all three cabinet variations. The final Coin Pusher player replay completed 42/42 commands with zero script/conservation errors.
- Gates: final `tools/validate_project.ps1` PASS; touched game suites and surface-SFX audit PASS; tutorial guardrail and corner-shop checks PASS. Smoke/games native runs can exit `-1` without shard reports; no-native games/systems exceed the 300-second ceiling; UI has the pre-existing Path A missing-apartment-route failure; two tutorial checks and the late-run Crew performance coverage probe retain clean-base/pre-existing failures. Full attribution and logs are in the fix report.
- Performance: native-v3 Coin Pusher and all requested measured game paths were within budget with liveness passing; the overall probe remained nonzero only for the pre-existing inaccessible late-run Crew dialogue coverage.
- Player replay: all ten original streams completed (916 command/result pairs), plus normal/small-screen BUG-18 captures and a full save → quit → relaunch → Continue sequence.
- Owner decision needed: the reusable spawn-slot owner must integrate/confirm an explicit interactive `lender:street_lender` placement in the Punchline back room and replay BUG-10/Vic after merge.
- No commit, push, merge, stash, reset, or stage was performed.
