Status: DONE — fixes merged to `main` in `429079bb`; regression group and merged player path pass on 2026-09-14
Source report: `docs/plans/agent_playtest/agent_playtest_postfix_06_claim_audit_2026-09-13.md` (9 failed fixes, 1 unverified, BUG-32 … BUG-37)
Predecessors: `docs/todo/playtest_fixes01_agent_sweep_2026-09-12_prompt.md`, `docs/todo/playtest_fixes02_continuation_2026-09-12_prompt.md` (both DONE, uncommitted)

# Agent Prompt — Playtest Fixes 03: Finish the Fixes That Failed Player Replay

Copy everything below this line into the agent.

---

You are working on **Beat The House**, a Godot 4.6 GDScript roguelite. This
prompt is self-contained: every rule you need is below. Read the named code
before editing — do not plan from this prompt alone.

## Why this task exists

Two fix workers (Fixes 01 and 02) reported all owned BUG-01…31 fixed, each with
a regression test that went red → green. An independent player-input audit then
replayed those bugs through the real game and found **8 of the "fixed" bugs
still fail for the player, and one fix introduced a new regression** (BUG-07).
It also found six new bugs.

The pattern behind the misses: the regression tests asserted a model or
internal seam (bankroll changed, result dictionary published, speaker hydrated,
focus trapped) while the player-visible surface (HUD wallet, selected card,
nameplate, scrolled control, confirmation text) stayed wrong. **In this task a
seam test is necessary but never sufficient. A bug is fixed only when the
visible player replay passes.**

## Scope

Fix in the existing fix worktree (13 items):

| Group | Bugs | Area |
|---|---|---|
| F1 Tutorial input (do first) | BUG-07 | Coach overlay shield eats the tutorial's own TalkDock buttons |
| F2 Visible money | BUG-08, BUG-09 | HUD wallet stays stale after Numbers slip / Silas tip |
| F3 Selection and modal UI | BUG-12, BUG-19, BUG-23 | Double-click purchase card, fixed-seed explanation, Settings focus scroll |
| F4 Dialogue copy | BUG-30, BUG-31 | Chained "Unknown Caller" nameplate, Lucky loan confirmation terms |
| F5 New game/run bugs | BUG-32, BUG-33, BUG-35, BUG-36 | Blackjack post-HIT pulse, Run Content home, Pinball zero-ball settle, Craps refund wallet |
| F6 Re-verify only | BUG-26 | Duplicate scenario instruction — route was not reached by the audit |

**Out of scope — do not touch (held for the environment spawn-slot work):**
BUG-10 (Vic not hittable), BUG-34 (Gas Station Numbers Book label clipped),
BUG-37 (both Tier-2 destinations reject Travel on scenario-label vs exit
conflicts). All three live in the room placement / scenario layout path that
the main checkout is rewriting uncommitted (`scenario_layout_resolver.gd`,
`environment_placement.gd`, `environment_interaction_controller.gd`,
`pixel_scene_canvas.gd`, `data/environments/spawn_slots.json`). A competing fix
here would create a large merge conflict. If you happen to observe new evidence
for these three, record it in the report; do not edit for them.

## Hard rules

- **No commits, pushes, merges, stashes, resets, rebases, checkouts, or
  staging** — anywhere. Leave all changes uncommitted.
- **Work only in the existing fix worktree:**
  `C:\Users\theep\.codex\worktrees\Beat-The-House-playtest-fixes`
  (also reachable through the junction
  `D:\Projects\Beat-The-House-worktrees\playtest-fixes`), branch
  `codex/agent-playtest-fixes`, HEAD `56de66598a2bcdbc3f171f090b48c361daf35563`.
  Do not create another worktree or branch.
- The worktree holds the combined **uncommitted** Fixes 01 + 02 diff
  (30 tracked files, +741/−107; content fingerprint
  `45add38e02d9de93e2ecae3f2092f32714ab5431`). Before editing, record
  `git status`, the fingerprint, and the full diff. Preserve every inherited
  hunk; when a failed fix needs rework, change that hunk deliberately and list
  the before/after in the report. Never revert unrelated inherited work.
- **Main checkout** `D:\Projects\Beat-The-House` has other agents' uncommitted
  work. Do not edit, stage, or run the game from it. The only files you may
  create or edit there:
  - the fix report named in Deliverables;
  - the Status line and execution record of this prompt file.
- Do not touch the `backroom-poker-tweaks`, `game-prop-art`, `agent-playtest`,
  or `feat06-1` worktrees. `agent-playtest` is read-only evidence.
- **Validate before fixing.** Write each bug's validation record into the
  report before changing product code for it.
- Smallest root-cause fix. No drive-by refactors, balance changes, lender-term
  changes, voice rewrites, or deterministic-outcome changes for valid seeds.
- Scratch output and harness sessions go under `.tmp/playtest_fixes03/` in the
  fix worktree and stay uncommitted.

## Evidence and harness

- Audit evidence (PNG + `NNNN.command.txt` + `NNNN.result.json` per step):
  `C:\Users\theep\.codex\worktrees\Beat-The-House-playtest-fixes\.tmp\agent_playtest\2026-09-13\<session>\`
  Sessions: `verify31_b1`, `verify31_c1`…`c8`, `verify31_d1`…`d4`,
  `claim06_b1`…`b6`, `claim06_c1`…`c3`, `claim06_d1`…`d5c`.
- Original sweep evidence:
  `D:\Projects\Beat-The-House-worktrees\agent-playtest\.tmp\agent_playtest\2026-09-12\`.
- Harness (already in the fix worktree, untracked tooling):
  `tools/agent_playtest_session.gd` and `tools/agent_playtest_session.ps1`.
  Read the `.ps1` usage before launching. Every session needs a unique name
  and its own isolated persistence directory.
- Host memory: only launch game sessions while free physical memory is above
  8 GB, run at most three sessions at once, and quit each session explicitly.
  After every quit, confirm the wrapper PowerShell process also exited — a
  stale wrapper in the audit grew to ~42 GB. Kill only processes whose command
  line you have verified belongs to a session you started.

## 1. Baseline

1. Record branch, HEAD, status, diff fingerprint, and the full inherited diff.
2. Read in full: the source audit report, the Fixes 01 report
   (`docs/plans/agent_playtest/agent_playtest_fixes_2026-09-12.md`), and the
   Fixes 02 report
   (`docs/plans/agent_playtest/agent_playtest_fixes_continuation_2026-09-12.md`),
   including their lists of pre-existing gate failures.
3. Run and keep the logs:
   - `powershell -File tools\validate_project.ps1`
   - `powershell -File tools\check_godot.ps1 -RequireGodot -Suite Smoke`
   - the Fixes 01 and Fixes 02 regression suites
     (`playtest_fixes01_regressions`, `playtest_fixes02_regressions`).
   Known inherited failures/timeouts (native DLL exit −1 in Smoke/games,
   300-second shard ceilings for `games`/`systems`, Path A apartment-return
   fixture, tutorial cadence stale hash, `tutorial_blackjack_raise` empty
   staging rect, late Crew dialogue perf probe) stay classified as inherited.
   A timeout is never a pass.

## 2. Validation protocol — every bug

1. **Reproduce through visible input** on the current worktree, in a fresh
   session, following the audit session's command files up to the failing step.
   Try twice where timing or RNG matters. Keep before PNG + result JSON.
   If the old command stream drifts, reach the same state by the shortest
   deterministic visible route and document it; do not substitute a seam test
   for the reproduction.
2. **For the 8 failed fixes, explain the miss.** Identify the inherited hunk,
   the regression test that went green, and exactly why that test did not
   observe what the player sees. Record it as one line:
   `test asserted <X> at <file:function>; player sees <Y> from <file:function>`.
3. Trace the real root cause as `file:function:line`.
4. Add or move the regression assertion to the seam the player actually sees
   (HUD label text/value, rendered selection, dock nameplate, control visible
   in the scroll viewport, confirmation string, registered hit action). Prove
   it red on the current worktree before the fix.
5. Classify: `VALID`, `VALID-DIFFERENT-CAUSE`, `NOT REPRODUCIBLE`,
   `NOT A BUG`, `HARNESS ARTIFACT`, or `OWNER DECISION`. Only the first two get
   product changes.
6. **Acceptance:** after the fix, the visible replay of the original failing
   path passes twice in fresh sessions, with after PNG + result JSON. No bug is
   reported fixed on seam tests alone.

## 3. Per-bug requirements

Line numbers are hints; re-locate every symbol.

### F1 — BUG-07 tutorial input regression (do this first)

- Original bug: clicking Pal's "Skip tip" over the Numbers Book also toggled
  the native Straight/Box `OptionButton` underneath.
- Fixes 01 added a full-screen `_input` shield in `scripts/ui/coach_overlay.gd`
  (`_input` → `_consume_blocked_pointer_input`) that allows only the coach
  panel/anchor rectangles. It now swallows the tutorial **TalkDock's** own
  "Pick them up", "Hide", and "Good to know" controls
  (`verify31_d1/0010`–`0012`, `claim06_b1/0094`–`0099`,
  `claim06_d3/0024`–`0031`). Mouse and keyboard both fail. This blocks the
  First Night tutorial and, after Continue, any run with an active tutorial
  stack.
- Required outcome: tutorial TalkDock choices and every other intentionally
  interactive tutorial control work by mouse and keyboard, **and** the original
  click-through onto covered controls stays fixed.
- Prefer allowing input by ownership (the shield passes events whose target is
  the coach or the TalkDock / a registered tutorial-owned control) over another
  hard-coded rectangle list. Check how the shield interacts with native popups
  (`OptionButton` popups are separate windows) and with keyboard focus.
- Regression: drive the real overlay + TalkDock and assert a TalkDock choice
  resolves while a click at a covered control's position does not reach it.
- Replay: `verify31_d1` route and the `claim06_d3` First Night route through
  Pal's "Good to know" warning to the first ordinary favor. Also Save → quit →
  relaunch → Continue with the tutorial stack active and confirm the dock still
  accepts input (this is what blocked Street Craps in `claim06_b6`).

### F2 — BUG-08 and BUG-09 visible wallet

- Both now charge correctly and publish a Result, but the **visible HUD wallet
  stays stale** (`verify31_c5/0044`: internal $87, HUD $88 with old `+30`;
  `verify31_c6/0102`: internal $38, HUD $50/+45).
- These almost certainly share one missing step: the Numbers/Silas handlers
  publish the result but never refresh the structured HUD wallet/delta the way
  the standard action pipeline does. Find how a normal game or shop action
  updates the HUD and route both handlers through that same path. Do not add a
  second manual wallet write.
- Regression: after each action, assert the rendered HUD wallet value and delta
  badge equal canonical bankroll and this action's delta.
- Keep BUG-09's inherited one-time purchase guard and disabled option.

### F3 — selection and modal UI

**BUG-12 — double-click purchase keeps the old card.**
- Still reproduces (`verify31_c1/0016`): double-click Ledger Pencil while
  Instant Coffee is inspected → pencil bought for $14, but the selected card
  still shows Instant Coffee and its Buy button.
- Fixes 01 reordered affinity refocus vs. result presentation. Find what still
  re-selects or re-renders the previously inspected offer after the purchase
  (double-click event order: first click selects, second applies — check
  whether the stale selection is restored from a cached selection id).
- Outcome: after purchase the card shows the purchased item's result or
  clears; the sold offer cannot be bought again from a stale card.

**BUG-19 — fixed tutorial seed unexplained.**
- The seed field is now disabled for the mandatory First Night, but nothing on
  the setup screen says why (`verify31_d3/0003`–`0005`); there is no tooltip
  and focus/hover shows nothing.
- Outcome: a visible, always-shown status line next to the disabled field,
  e.g. that the first night uses a fixed lesson seed and later runs use the
  typed seed. Tooltip alone is not enough — disabled controls often do not
  show tooltips. Use existing setup-screen label styling; keep copy short.

**BUG-23 — Settings focus does not scroll into view.**
- Focus now stays inside Settings, but Tab reaches the off-screen Text Size
  control without scrolling to it, and Enter opens its popup below the viewport
  over the fixed footer (`verify31_d2/0024`–`0026`).
- Outcome: whenever focus moves inside Settings, the focused control is
  scrolled fully into view in its `ScrollContainer` (Godot's
  `ensure_control_visible` or `follow_focus`); dropdown popups open fully on
  screen. Check every focusable Settings control at 1280×720 and small-screen
  mode.

### F4 — dialogue copy

**BUG-30 — chained nameplate still "Unknown".**
- Fixes 02 hydrated the chained entry and its test passes, but the real
  Counter Phone → family-loan chain still renders "Unknown"
  (`verify31_c3/0036`). The test likely exercised a different enqueue path
  than the one production uses, or `talk_dock.gd` resolves the name from a
  field the hydration did not fill.
- Trace the actual production chain from the Counter Phone choice to the
  rendered nameplate, and fix at the general boundary (no event-ID or string
  special case). Assert the rendered nameplate text.

**BUG-31 — Lucky loan confirmation omits terms.**
- Fixes 02 covered the four lenders (Vic etc.), but Lucky's "Accept Offer"
  confirmation shows only generic voice and "Confirm: Accept Offer"
  (`verify31_c2/0078`); the $45 principal, two-favor repayment, 0% interest,
  and two-turn deadline are missing.
- Lucky's loan is an event-chain choice, not a lender record — a different
  path. Audit **every** path that creates debt or a repayment obligation
  (lenders, event choices, family loans, favors) and make offer, confirmation,
  and result show the real terms sourced from the same data that creates the
  obligation. Non-cash repayment (favors) must read naturally, not as "$0".
  Preserve authored voice beside the terms; change no terms.

### F5 — new bugs

**BUG-32 — Blackjack post-HIT count pulse not clickable.** (Major)
- Seed `CLAIM06-B2-FLAT-FINAL`: all 8 opening pulses hit correctly; a legal
  HIT draws a King; target becomes +1 but the new −1 pulse reuses resolved ID
  `blackjack:count:1121148:8` and has no registered `blackjack_count_icon`
  action (`claim06_b2/0175`–`0176`). Accurate play is scored as a miss.
- Suspected: `_sync_count_challenge_icons()` derives the serial from persisted
  `icon_serial`, and card tracking prefers rank/suit/deck identity over source
  position. Verify.
- Outcome: every newly exposed card (hit, double, split, dealer draw) gets a
  unique, clickable pulse; IDs never collide with resolved ones; save/Continue
  mid-hand keeps the IDs stable. Do not change surveillance Heat rules.
- Regression includes the exact seed path plus a split-hand case.

**BUG-33 — Run Content home overwritten.** (Major)
- Standard Run + Home: Motel Room → starts in Back Alley
  (`claim06_d2/0062`–`0064`, reproduced twice).
- Code confirms: `_challenge_with_home_selection()` sets `home_archetype_id`,
  then `start_foundation_run()` → `_challenge_with_meta_home_for_run()`
  (`scripts/ui/foundation_main.gd` ~15693) copies every
  `normal_run_start_modifiers()` key over the modifiers, including the profile
  home.
- Outcome: an explicit player home choice wins; the meta-profile home applies
  only when the choice is Random/absent. Other meta modifiers still apply.
- Regression through the real Start button path; replay Motel Room and one
  other home, and confirm Motel tenure objects exist on arrival.

**BUG-35 — Pinball needs a zero-ball LAUNCH to settle.** (Major)
- After the final bonus ball drains: `LEFT 0 LIVE 0`, feature still active,
  LAUNCH enabled; clicking LAUNCH settles and pays $22 (`claim06_b4/0049`–
  `0050`). Completion is only evaluated inside the next action step
  (`scripts/games/slots/pinball/pinball_feature.gd` ~202–254).
- Outcome: the feature settles on the simulation tick that drains the last
  ball; LAUNCH is disabled/hidden at zero balls; payout happens exactly once
  across tick/action/leave/save boundaries.
- Hot-path rule: the completion check in the tick must be zero-copy — no
  `duplicate()` or collection rebuild per frame (a prior slot watchdog
  deep-copying per frame cost 32 ms/frame).

**BUG-36 — Casino Craps take-down refunds cash as chips.** (Major)
- Bankroll $100000, chips 0: stage $15, point 6, take down $5 Place 6 →
  "5 returned", bankroll unchanged, chips 0 → 5 (`claim06_b5/0020`–`0021`).
- Code confirms: `_resolve_take_down()` in `scripts/games/craps.gd` (~758–812)
  sets `currency = "cash"` only for Street Craps, so the generic result path
  credits chips for Casino Craps.
- Outcome: refunds (take-down and interruption) go to the wallet that funded
  the wager. Prefer recording funding currency on each working bet at
  placement and refunding to it; if a bet predates that field, fall back to the
  current venue's actual wager currency. Add a save-shape migration + round
  trip if the bet record changes.
- Regression: cash-funded casino, chip-funded casino (Grand Casino), and
  street take-downs; interruption refund; save/Continue with a working bet.

### F6 — BUG-26 re-verify only

- The audit's command replay diverged before reaching the Back Alley
  `scenario::goods_lot` "Resolve the contested lot" panel. Reach it by any
  deterministic visible route (find a seed/phase that spawns it) and check the
  instruction appears once. Classify PASS or FAIL with evidence. If it fails,
  fix it only if the cause is in `environment_interaction_view_model.gd`
  copy de-duplication (Fixes 02's hunk); anything in placement/rendering
  geometry is out of scope — record it.

## 4. Engineering constraints

- Tabs, static typing for new variables/functions, local naming and idioms.
- Zero-copy per frame in draw/`_process`/tick paths.
- Idle liveness: Blackjack, Craps, and Pinball idle/animation counters must
  keep moving; a 0.000 timing is not a pass without the liveness check.
- All randomness through existing RNG streams; no outcome changes for valid
  seeds.
- Hidden cards/outcomes stay out of presentation state.
- Saved-state shape changes need a versioned migration and round-trip test.
- Shared-file discipline: `foundation_main.gd`, `coach_overlay.gd`,
  `talk_dock.gd`, `event_module.gd`, `craps.gd`, `blackjack.gd` already carry
  inherited edits. List every function you change in those files and mark
  Fixes 03 lines separately from inherited lines.

## 5. Gates after fixes

1. `powershell -File tools\validate_project.ps1`
2. `powershell -File tools\check_godot.ps1 -RequireGodot -Suite Smoke`
3. `-FoundationSuite games`, `-FoundationSuite systems`, `-FoundationSuite ui`
   (same flags as the predecessors; compare against their recorded inherited
   failures).
4. `playtest_fixes01_regressions`, `playtest_fixes02_regressions`, and your new
   Fixes 03 regressions — all green; Fixes 03 assertions red before / green
   after, both logs kept.
5. Targeted suites for Blackjack, Craps, Pinball/slots, Numbers, events/dialogue,
   lenders/debt, tutorial/coach, settings, run setup. Discover real suite names
   from the test runner; never invent a command that silently runs nothing.
6. Performance/liveness probes for Blackjack, Craps, and Pinball at 1280×720
   and small-screen, before/after, against `tools/perf06_budget_table.json`.
7. **Visible acceptance replay** (section 2 step 6) for all 12 fixed bugs, two
   fresh sessions each.
8. **No-regression replay:** re-run the audit's PASS routes for every bug whose
   files you touched (at minimum BUG-05, BUG-06, BUG-16, BUG-17, BUG-22,
   BUG-27, BUG-29 and any other PASS sharing a changed function). All must
   still pass visibly.
9. One Save → quit → relaunch → Continue pass covering: active tutorial stack
   (BUG-07), an accepted Lucky loan (BUG-31), and a Casino Craps working bet
   (BUG-36).

A gate failing identically in the inherited baseline is inherited; record it
and do not expand scope. Any new failure you cause must be resolved before
completion.

## 6. Deliverables

Write the fix report in the main checkout:

`D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_fixes03_postfix_2026-09-13.md`

Do not edit the audit report or the Fixes 01/02 reports. Structure:

1. **Header:** worktree, branch, HEAD, inherited fingerprint, final
   fingerprint, baseline gate results.
2. **Summary table:** one row per bug (13) — class, root cause
   `file:function:line`, fixed?, regression test, visible replay result
   (2/2), files changed, before/after PNG links.
3. **Why the prior fixes missed:** the one-line miss explanation for BUG-07,
   08, 09, 12, 19, 23, 30, 31, and whether the old test was kept, changed, or
   moved.
4. **Per-bug records:** replay, trace, red test, fix, green test, after
   evidence, deviations.
5. **Not fixed / owner decisions:** every non-VALID class with evidence.
6. **Held for spawn-slot work:** BUG-10, 34, 37 — unchanged, plus any new
   evidence you incidentally observed.
7. **Overlap notes:** functions changed in files already changed by Fixes
   01/02, with inherited vs Fixes 03 lines separated.
8. **Gates, performance, no-regression replay:** baseline vs final,
   inherited vs new.
9. **Changed files:** grouped by bug; harness/tooling separate.

Keep bug text plain and short — the owner reads this to decide, not to debug.
Long logs go in `.tmp/playtest_fixes03/` and are linked.

## 7. Completion

1. `git -C D:\Projects\Beat-The-House status` shows nothing from you except
   this prompt file and the fix report.
2. The fix worktree holds the combined uncommitted Fixes 01+02+03 diff, no
   staged files; reconcile against the report's changed-file list.
3. Quit every harness session; confirm no Godot or harness PowerShell process
   you started remains.
4. Append an execution record to the bottom of this file: date, HEAD,
   inherited and final fingerprints, report path, counts per class, fixed
   count with visible-replay confirmation, gates/perf, inherited failures,
   remaining owner decisions.
5. Change the top line to
   `Status: DONE — fixes uncommitted in shared fix worktree, awaiting independent re-audit`.

If BUG-07 cannot be fixed without breaking its original click-through
protection, stop after F1, set `Status: BLOCKED — BUG-07 needs owner decision`,
and document both behaviors with evidence. If a new gate failure cannot be
resolved in scope, leave everything uncommitted, set `Status: BLOCKED`, and
paste the failing output verbatim into the execution record.

## Execution record — 2026-09-13

- HEAD: `56de66598a2bcdbc3f171f090b48c361daf35563`
- Inherited fingerprint: `45add38e02d9de93e2ecae3f2092f32714ab5431`
- Final combined fingerprint: `b9d78d8d0bc676de82be656dff15f4e07143e06b`
- Report: `D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_fixes03_postfix_2026-09-13.md`
- Classes: 10 VALID; 3 VALID-DIFFERENT-CAUSE; 0 NOT REPRODUCIBLE; 0 NOT A BUG; 0 HARNESS ARTIFACT; 0 OWNER DECISION.
- Fixed/reverified: 13/13. All 12 product-fix findings passed visible replay twice; BUG-26 first failed the production projection, was fixed at the allowed view-model boundary, then passed 2/2.
- Regressions: Fixes 01/02/03 PASS with 0/0/0 failures. Slot/Pinball targeted PASS. Tutorial guardrail stress PASS across 1,622 irregular boundaries. Visible no-regression routes BUG-05/06/16/17/22/27/29 PASS.
- Broad gates: validation PASS; Smoke content TIMEOUT 240.043 s; games TIMEOUT 307.341 s; systems TIMEOUT 307.335 s; UI reaches only the inherited Path A missing-Apartment failure; full contracts fail only inherited/held placement, scenario, crew-golden and related fixture classes. A timeout is not reported as a pass.
- Performance: Blackjack, Craps and Slot resolve measurements are within checked-in budgets; liveness guard PASS. Overall probe retains the inherited late-Crew-dialogue access/coverage failure. Pinball lifecycle/zero-copy settlement passes the full Slot suite and two visible sessions; the foundation probe emits no distinct Pinball scenario row, so none is claimed.
- Held unchanged: BUG-10, BUG-34, BUG-37. Remaining in-scope owner decisions: none.
- Worktree: combined Fixes 01+02+03 changes remain uncommitted and unstaged. All playtest/Godot sessions quit; one stale quit-wrapper was observed and exited before completion.
