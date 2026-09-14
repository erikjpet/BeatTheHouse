Status: DONE (on codex/backroom-poker-tweaks, not merged)
Series: Back-room poker tweaks (tweak01 of an open-ended series; later tweaks stack on the same branch)

# Agent Prompt — Back-Room Poker Tweak 01: Five Opponents at the Table

Copy everything below this line into the agent.

---

You are working on **Beat The House**, a Godot 4.6 GDScript roguelite. This
prompt is self-contained: every rule you need is below. Read the named code
before editing — do not plan from this prompt alone.

## Goal

The Crew's back-room Texas Hold'em table currently seats the player plus
**three** Crew opponents. The owner wants **five** opponents (six hands at the
table). Every new table must seat five; the table must look good, play
correctly, stay deterministic, and stay fast.

This is also the **first of a series of owner tweaks** to this game. While you
make it, remove the hard-coded "three seats" assumptions so seat count and seat
geometry live in one place, and leave a short table map (below) that the next
tweak can build on.

## Parallel-work setup (do this first)

Other agents are working in `D:\Projects\Beat-The-House` right now (uncommitted
environment-slot work touching `run_state.gd`, `pixel_scene_canvas.gd`,
`environment_placement.gd` and more). **Do not edit, stage, stash, reset, or
commit anything in that checkout.**

- If the worktree `D:\Projects\Beat-The-House-worktrees\backroom-poker-tweaks`
  already exists, use it as-is (an earlier tweak created it; build on its
  branch).
- Otherwise create it from `main`:
  `git -C D:\Projects\Beat-The-House worktree add -b codex/backroom-poker-tweaks D:\Projects\Beat-The-House-worktrees\backroom-poker-tweaks main`
- Do all edits, tests, and commits inside that worktree. The only file you may
  touch in the main checkout is this prompt file (execution record at the end).
- Godot binary: `.tools\godot-4.6-stable\` in the main checkout (or `$env:GODOT_BIN`).
  If the worktree lacks `.tools`, set `$env:GODOT_BIN` to the main checkout's
  binary rather than copying it.

## Architecture orientation

- Games render on a 900×430 design board. `scripts/ui/foundation_main.gd` hosts
  the run; each game is a module under `scripts/games/` that produces a
  `surface_state(...)` dictionary and draws it in `draw_surface(...)`.
  Content and tuning are data-driven from `data/**/*.json`.
- Back-room poker:
  - `scripts/games/crew_draw_poker.gd` — the module (≈2,400 lines; despite the
    name it is no-limit Hold'em on the `ordered_v1` turn engine; `legacy_v1`
    five-card draw still exists for old saves/tests).
  - `scripts/core/crew_poker_model.gd` — pure rules/policy/tell model.
  - `data/crew/poker.json` — tuning, including `"opponent_count": [3, 3]`, seven
    member policies, banter. `data/crew/tells.json` — per-member tells.
  - `data/games/rituals/crew06_10_poker_nights.json` — the five authored nights.
  - `scripts/games/table_game_visuals.gd` — shared room/table/character drawing
    (`CONSOLE_Y = 342`, `TABLE_BOTTOM = 334`, felt polygon, `_draw_table_character`).
  - `scripts/core/crew_state_model.gd` — `MEMBER_IDS` (7 Crew members) and the
    Layer-3 resident projection.
- Hidden-information rule (existing, must hold): presentation never receives an
  opponent's hole cards before showdown or any hidden tell-learning counter.

## Where "three" is baked in today (verified — re-read before editing)

1. `crew_draw_poker.gd` `generate_environment_state` (≈lines 49–60): tops up
   candidates from the roster only when residents `< 3`; clamps min/max/count to
   `3`.
2. `data/crew/poker.json`: `"opponent_count": [3, 3]`.
3. `crew_draw_poker.gd` constants `SEAT_LEFT_POSITION / SEAT_CENTER_POSITION /
   SEAT_RIGHT_POSITION` (≈lines 25–27) and `_draw_seats` (≈line 2029):
   `range(mini(3, ...))`, ternary seat picking, and `index == 1` special-casing
   for the center seat's action label.
4. `_chip_layout` (≈line 2111): three hard-coded `seat_centers`.
5. Tests/tools asserting three:
   - `scripts/tests/foundation/check_table_games.gd` ≈1254 and ≈1271
     ("two or three residents").
   - `tools/crew_poker_visual_seed_audit.gd` ≈105 (`generated_members.size() == 3`).
   - `tools/crew_holdem_dynamic_table_capture.gd` ≈34 and
     `tools/crew_holdem_dynamic_table_audit.gd` ≈42 (`animated_crew_count != 3`,
     `seats.size() != 3`).
6. Grep again for anything else (`size() == 3`, `size() != 3`, `mini(3`,
   `[3, 3]`, `"three"` in poker-related tests/tools/UI text) before you finish.

**Out of scope, do not change:** the Crew *lender* environment actor that shows
three Crew members in rooms (`compile_run_menu_and_game_flows.gd` ≈4011/4022).
That is a different object and stays at three.

## Work

### 1. One source of truth for seat count and seat layout

- Replace the three seat constants and the `seat_centers` array with a single
  seat-layout table (a `const` Array of Dictionaries in `crew_draw_poker.gd`
  is fine) indexed by seat, each entry holding everything a seat needs: block
  origin, character foot, hole-card origin, action-label rect + font size,
  whether the label carries the name, dealer-button center, bet-chip center.
- Add `const MAX_OPPONENT_SEATS := 5` (or derive it from the table's size) and
  use it everywhere `3` was used as a seat bound. Old 3-member tables must still
  draw: map a table with N < 5 members onto a sensible subset of the five seats
  (e.g. 3 → far-left/center/far-right) through the same table, not a separate
  code path.
- `_draw_seats`, `_chip_layout`, and the button marker must read only from that
  table. No per-index `if` branches left in drawing code.
- Keep drawing zero-copy per frame: the layout table is a `const`; do not build
  or `duplicate()` arrays/dictionaries inside `draw_surface` or its helpers.

### 2. Seat geometry for six at the table

Starting proposal (block origin = what `SEAT_*_POSITION` means today; current
local offsets are character foot `+42,+53`, two cards at `+91,+14` stepping 27px,
24×35; label below at `+69`):

| seat | position | origin | bet chips |
|---|---|---|---|
| 0 | far left, rail side | (18, 176) | (232, 256) |
| 1 | upper left | (150, 96) | (272, 188) |
| 2 | top center (today's center) | (408, 78) | (390, 145) |
| 3 | upper right | (604, 96) | (630, 188) |
| 4 | far right, rail side | (736, 176) | (700, 256) |

Unchanged anchors you must not collide with: header band y < 82; community
board `Rect2(305,158, 5×59−9, 70)`; player hole cards from (385,245), 58×81,
step 68; player chips (350,280); pot chips (590,270, up to 6 stacks); player
button (522,292); observation strip `Rect2(138,337,548,35)`; console/controls
y ≥ 342; raise selector panel.

Treat the table as a proposal — adjust until it passes:

- **Automated no-overlap check (new, keep it for future tweaks):** add a
  function in the Crew poker foundation contract (or `check_table_games.gd`
  where the poker checks live) that computes, for 5 seats *and* for the 3-seat
  legacy mapping, every seat's character bounding box (use
  `_draw_table_character`'s geometry at the seat's scale range 0.66–0.84),
  card rects, label rect, button marker circle bounds, and worst-case chip
  cluster bounds (`_chip_cluster_bounds` at the largest possible per-round
  contribution), and asserts: no seat element overlaps another seat's elements,
  the board, player cards/chips/button, pot bounds, observation strip, or the
  console; everything stays inside 0..900 × 82..342.
- **Visual evidence:** run the existing capture
  (`tools/crew_poker_visual_capture.ps1 -RequireGodot`, output under
  `.tmp/crew_poker_visual_qa/`) and `tools/crew_holdem_dynamic_table_capture.gd`
  after updating them for five seats. Open the PNGs yourself and check idle,
  preflop with blinds posted, a multiway raise with all six contributing chips,
  a fold (dimmed seat), table-talk active on an outer seat, portrait-tell beat,
  all-in label, showdown with five revealed hands, and the raise panel open.
  Names, action labels, and cards must be readable, not clipped by the rail or
  screen edge.
- Talk dock / table-talk anchoring must still point at the correct seat for
  seats 0 and 4.

### 3. Seating rules

- `data/crew/poker.json`: `"opponent_count": [5, 5]`.
- `generate_environment_state`: seat count = seeded pick inside the configured
  bounds, clamped to `2..MAX_OPPONENT_SEATS` and to available Crew. Candidate
  order: **L3 residents first** (all of them if ≤ 5, a seeded pick of 5 if
  more), then fill remaining chairs from the rest of `CrewStateModel.MEMBER_IDS`
  by a seeded pick. Same seed ⇒ identical members and seat order.
- Seat order around the table must be stable for a session (the betting engine
  uses it for button/blind rotation).
- Verify every one of the seven members has a policy, banter, and tells
  (`data/crew/tells.json`) so any five can sit. If one lacks data, author it in
  the existing house style (look at the other six) rather than excluding them.

### 4. Game logic with six hands

Read the `ordered_v1` engine (`_ordered_legal_actions`, turn order, button
rotation, blinds, `_minimum_raise_to` / `_maximum_raise_to`, round closure,
side-pot/all-in handling, showdown, heads-up check ≈line 698) and prove it is
genuinely N-player, not quietly 4-player:

- Button, small blind, big blind, and first-to-act rotate correctly through all
  six positions over a session (player included), preflop and postflop.
- Round closure after a raise requires every still-active seat to act again.
- Chip conservation holds every action: sum of stacks + pot constant.
- Shoe: 6×2 hole + burns + 5 board cards never over-draws; deterministic per seed.
- Showdown with 3+ tied/split pots divides exactly; any remainder rule is
  deterministic and documented in code.
- Table talk caps (`table_talk_max_per_hand`, cooldown) and observation queue
  still behave with five speakers; tells from five members never overwrite each
  other in the visible queue.
- Each of the five authored nights (`crew06_10_poker_nights.json`) still runs:
  actor groups such as `resident_opponents` / `pressure_opponents` resolve with
  five members and any "departing member"/"door listener" beats pick a valid seat.
- Add/extend focused tests for each bullet above in the existing Crew poker test
  files; run `tools/crew_holdem_gameplay_audit.gd` with its fixtures moved to
  five opponents.

### 5. Saves and old tables

- `STATE_VERSION` is 3. A table saved with three members (idle or mid-hand)
  must load and play to completion **as a three-member table** — never re-seat
  or add chairs mid-session, never change cards, pot, or turn owner. Only a
  newly generated table/new night gets five. If you need a version bump to make
  that unambiguous, bump it with a migration and a test using an existing
  3-member fixture under `scripts/tests/fixtures/` (do not rewrite
  golden fixtures; add new ones if needed).
- Hidden-information check still passes for five seats (no hole cards or tell
  counters in `surface_state` before showdown).

### 6. Performance and liveness (hard repo rules)

- **Zero-copy per frame.** A past per-frame `duplicate(true)` in a watchdog cost
  32.6 ms/frame. Nothing added to `draw_surface`/`_draw_*` may allocate or deep-copy
  collections per frame; `_draw_array_view` / `_draw_dict_view` exist for this.
- Five animated characters instead of three raises idle draw cost. Measure
  `crew_draw_poker` in `tools/foundation_performance_probe.gd` before (on `main`)
  and after; report both numbers. It must stay inside its budget in
  `tools/perf06_budget_table.json`. If it doesn't, optimize the new drawing —
  do not raise the budget.
- **Idle liveness gate:** perf work in this repo has frozen idle table animation
  four separate times because idle budgets reward 0.000. The probe's liveness
  counter for `crew_draw_poker` (`surface_animation_redraw_count`, ≥8 per 120
  frames) must still pass, and all five characters must visibly blink/sway in
  the idle capture. Never accept a 0.000 idle cost without the liveness check.
- Reduce-motion mode still freezes motion without hiding seats or tells.

## Table map for future tweaks

Write `.tmp/backroom_poker_tweaks/table_map.md` (reports and scratch output go
under `.tmp/` only, never committed) containing: the final seat-layout table
with coordinates; the remaining free regions of the board; where seat count,
seating rules, betting tuning, banter/tells, and night rituals live (file +
function); which tests/tools/captures cover each; and the before/after perf
numbers. Keep it under ~80 lines — it is the orientation doc the next tweak's
agent reads first.

## Engineering rules

- GDScript: tabs, static typing on new vars/functions, match surrounding naming
  and idiom; comments only where a constraint isn't obvious from the code.
- Build on existing tooling (`crew_poker_visual_capture`, `crew_holdem_*`
  tools, foundation contracts); do not create parallel harnesses.
- Don't touch unrelated games or systems. No balance changes to stakes/caps in
  this tweak — but **do** report, from the gameplay audit, the pot-size and
  session-swing distribution at 3 vs 5 opponents so the owner can decide whether
  `session_swing_cap` / blinds need a follow-up tweak.

## Validation gates (all must pass, in the worktree)

1. `powershell -File tools\validate_project.ps1`
2. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite crew_poker`
3. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games`
4. `powershell -File tools\check_godot.ps1 -RequireGodot -Suite Smoke`
5. The new no-overlap check (inside gate 2).
6. `tools\crew_poker_visual_capture.ps1 -RequireGodot`, `crew_holdem_dynamic_table_capture.gd`,
   `crew_holdem_dynamic_table_audit.gd`, `crew_holdem_gameplay_audit.gd`,
   `crew_poker_visual_seed_audit.gd` — all updated for five and passing, PNGs
   reviewed by you.
7. Performance probe for `crew_draw_poker`: within budget, liveness passing.
8. End-to-end: launch the game, reach the back room, sit at the table, play at
   least two full hands to showdown with five opponents, save mid-hand, reload,
   finish the hand.

If a gate fails for a reason that also fails on untouched `main`, prove it by
running the same gate on `main` and record it as pre-existing; don't fix
unrelated failures.

## Completion

Only after every gate passes and the end-to-end play works:

1. Commit in logical units on `codex/backroom-poker-tweaks` (e.g. seat-layout
   refactor; five-seat seating + data; engine/test hardening; tool/capture
   updates). End each commit message with
   `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
2. Push the branch: `git push -u origin codex/backroom-poker-tweaks`.
   **Do not merge into `main` and do not push `main`** — more poker tweaks will
   stack on this branch and it lands as one series.
3. Keep the worktree; do not remove it.
4. Append an execution record to the bottom of **this file in the main checkout**
   (`D:\Projects\Beat-The-House\docs\todo\poker_tweak01_five_opponents_prompt.md`):
   date, commit hashes, gate results (pass/fail + pre-existing notes), perf
   before/after, the 3-vs-5 pot/swing numbers, deviations from this prompt, and
   anything the next tweak should know. Change `Status: READY` to
   `Status: DONE (on codex/backroom-poker-tweaks, not merged)`. Do not move the
   file.

On gate failure: stop at the last green commit, do not push, set
`Status: BLOCKED`, and paste the failing output verbatim into the execution
record.

---

## Execution record - 2026-09-12

- Branch/worktree: `codex/backroom-poker-tweaks` at
  `D:\Projects\Beat-The-House-worktrees\backroom-poker-tweaks`; pushed to
  `origin`; intentionally not merged. The worktree remains in place.
- Commits:
  - `044c44f75a1453527b5409412ebe5ce6689d34ce` - five-opponent seating,
    centralized layout/focus geometry, UI anchoring, and payout conservation.
  - `7857280269ecb2f83f2c075d94d474c8675d19a0` - foundation/gameplay audits,
    production visual tools, and 13 refreshed dynamic-table captures.
- Gate 1: PASS - `validate_project.ps1` reported
  `Beat the House foundation architecture validation passed.`
- Gate 2: PASS for `crew_poker_game_suite` (0 failures), including the new
  five-seat and legacy-three-seat worst-case no-overlap contract. The composite
  wrapper also reports 19 unrelated `content` failures; the same 19 reproduce
  on a detached worktree at untouched base `56de6659`.
- Gate 3: PASS across the poker-relevant constituent suites: game activation,
  surface/table/bar-dice contracts, video-poker/game-module/cross-game math,
  slot smoke, and native coin-pusher checks. The monolithic `games` wrapper did
  not complete within 15 minutes while other agents' Godot playtests saturated
  the host; its `content` failures are the same baseline-only set from Gate 2.
- Gate 4: PASS across all six direct smoke runtime partitions, all 11 game
  launchers (including Back-Room Poker), Dave bus, and roulette audio. The UI
  compile partition's missing apartment tutorial route reproduces verbatim on
  untouched base. The exact wrapper's preliminary validator exceeded its fixed
  120-second timeout under the same external load.
- Gate 5: PASS - direct final Crew poker foundation contract, 0 failures.
- Gate 6: PASS - production visual seed audit, capture manifest, wrapper
  contract, 13-frame dynamic capture, dynamic audit, and gameplay audit. Four
  production and 13 dynamic PNGs were manually reviewed for six-way chips,
  outer-seat talk/tell/fold/all-in states, raise panels, and five-hand showdown.
- Gate 7: PASS. Main baseline poker idle draw avg/p95/max was
  `0.6024/0.883/0.981 ms`, resolve `1.3874/1.469/1.530 ms`, with 50 redraws.
  Five-opponent poker was `0.645857/0.700/0.749 ms`, resolve
  `1.837146/1.908/1.927 ms`, with 49 redraws. Existing budgets remain green and
  redraw liveness remains above the floor of 8. Unrelated baccarat/coin-pusher
  probe noise was not used to change budgets.
- Gate 8: PASS - two consecutive five-opponent hands reached showdown through
  production actions; a mid-second-hand save/reload preserved five members,
  cards, pot, and turn state, then completed the hand.
- Gameplay distribution (24 completed sessions each): 3 opponents pot
  min/median/p95/max `5/5/17/24`, session swing `-8/-2/5/9`; 5 opponents pot
  `5/5/13/17`, session swing `-6/-2/5/7`. No blind, stake, or cap tuning changed.
- Deviations/notes: the proposed top-center geometry was adjusted to keep its
  name/action label and cards clear; the final coordinates are in
  `.tmp/backroom_poker_tweaks/table_map.md` (65 lines, intentionally uncommitted).
  Exact monolithic Gate 3/4 wrappers were replaced with their serial constituent
  suites only because concurrent, unrelated Godot sessions repeatedly exhausted
  the wrappers' fixed wall-clock limits; no authored poker assertion failed.
