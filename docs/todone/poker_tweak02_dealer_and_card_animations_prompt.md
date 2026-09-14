Status: DONE (on codex/backroom-poker-tweaks, not merged)
Series: Back-room poker tweaks (tweak02; stacks on tweak01 on the same branch)

# Agent Prompt — Back-Room Poker Tweak 02: Crew Dealer and Card Animations

Copy everything below this line into the agent.

---

You are working on **Beat The House**, a Godot 4.6 GDScript roguelite. This
prompt is self-contained: every rule you need is below. Read the named code
before editing — do not plan from this prompt alone.

## Goal

The Crew's back-room Texas Hold'em table has the player plus five Crew opponents
(tweak01). Cards and chips currently just appear. The owner wants:

1. **A sixth Crew member as the table's dealer.** The dealer doesn't play a hand.
   They sit at the **lower right of the table, beside the pot** (owner's choice),
   with the deck and the muck/burn pile. **Every card comes from the dealer.**
2. **Card and chip animations** so the table visibly deals, burns, folds, collects
   and pays out.

## Precondition — check before doing anything

This tweak edits the same files as tweak01 and builds on its seat layout.

- Open `D:\Projects\Beat-The-House\docs\todo\poker_tweak01_five_opponents_prompt.md`.
  Its first line must read `Status: DONE`. If it says READY, BLOCKED, or anything
  else, **stop**: change this file's first line to
  `Status: WAITING — tweak01 not DONE (<its status>)` and end.
- Read tweak01's execution record at the bottom of that file and
  `.tmp/backroom_poker_tweaks/table_map.md` in the worktree (below). Where
  anything in this prompt disagrees with what tweak01 actually built, trust the
  code and record the difference.

## Parallel-work setup

Other agents are working in `D:\Projects\Beat-The-House` right now. **Do not edit,
stage, stash, reset, or commit anything in that checkout.**

- Work in the existing worktree `D:\Projects\Beat-The-House-worktrees\backroom-poker-tweaks`
  on branch `codex/backroom-poker-tweaks` (tweak01 created both). Run
  `git status` and `git log --oneline -8` there first. Uncommitted changes you
  didn't make → stop and report; don't discard them.
- Do all edits, tests, and commits inside that worktree. The only file you may
  touch in the main checkout is this prompt file (status line + execution record).
- Godot: `$env:GODOT_BIN`, or the main checkout's `.tools\godot-4.6-stable\` binary.

## Architecture orientation

- Games render on a 900×430 design board. `scripts/ui/foundation_main.gd` hosts
  the run; each game is a module under `scripts/games/` that builds a
  `surface_state(...)` dictionary (via `GameModule.surface_spec`) and draws it in
  `draw_surface(...)`. The canvas is `scripts/ui/game_surface_canvas.gd`.
  Content and tuning are data-driven from `data/**/*.json`.
- Back-room poker:
  - `scripts/games/crew_draw_poker.gd` — module (no-limit Hold'em on the
    `ordered_v1` engine; `legacy_v1` five-card draw remains for old saves/tests).
    `draw_surface` calls `_draw_room`, `_draw_seats`, `_draw_shared_board`,
    `_draw_betting_chips`, `_draw_player`, `_draw_observation`, `_draw_controls`.
    After tweak01 the seats come from one seat-layout table.
  - `scripts/core/crew_poker_model.gd` — pure rules/policy/tell model.
  - `data/crew/poker.json` — tuning, `opponent_count`, seven member policies, banter.
  - `data/crew/tells.json`, `data/games/rituals/crew06_10_poker_nights.json`
    (five nights; `persistence.transient` already lists `animation_progress`).
  - `scripts/games/table_game_visuals.gd` — shared room/table/character drawing
    (`_draw_table_character` poses: idle/watching/snitch/covered; `CONSOLE_Y = 342`).
  - `scripts/games/playing_card_renderer.gd` — `draw_card(surface, card, rect, options)`.
  - `scripts/core/crew_state_model.gd` — `MEMBER_IDS` (seven Crew members).
  - Surface audio: the poker module already declares the `crew_cards` profile with
    cues `card_deal`, `card_fold`, `card_check`, `chips_place`
    (`data/audio/surface_sfx_manifest.json`).
- **Existing animation system to reuse (read it first):**
  - `GameModule.surface_animation_channel(id, active_id, duration_msec, started_msec, extra)`
    in `scripts/core/game_module.gd`; the canvas tracks channels and exposes
    `surface_animation_active(channel)`, `surface_elapsed(channel)`,
    `surface_animation_progress(channel)`. Under reduce motion,
    `surface_animation_active` returns false and elapsed jumps to the end.
  - `surface_realtime_state_refresh` should be true only while an animation is live.
  - Blackjack deal animation, the most complete reference: in `scripts/games/blackjack.gd`,
    `_deal_animation_event` (card, zone, hand_index, card_index, from, to, delay,
    duration, scale), `_initial_deal_animation_events`, `_mark_deal_animation`,
    `_draw_deal_animation` (eased flight with lift and shadow),
    `_card_waiting_for_deal_animation` (resting card hidden until its flight lands),
    `_surface_deal_animation_events` plus a per-animation-id draw cache, and the
    `surface_presentation_time_msec` / `surface_time_msec` presentation clock.
    Baccarat (`scripts/games/baccarat.gd`) shows a deal channel followed by a payout channel.
  - Blackjack's visual capture, `tools/blackjack_table_visual_capture.gd`, shows
    how to capture frames at chosen animation times.
- Hidden-information rule (existing, must hold): presentation never receives an
  opponent's hole cards before showdown, or any hidden tell-learning counter.
  **Animation events count as presentation.**

## Work

### 1. The dealer

- **Who deals:** after the five opponents are seated (tweak01's residents-first
  rule), pick the dealer with a seeded pick from the Crew members who aren't
  seated. Same seed gives the same dealer. Store it in table state as
  `dealer_member_id`. If fewer than six Crew are available (tests or odd
  fixtures), shrink the opponents before losing the dealer, and never go below
  tweak01's two-opponent minimum. Write down the rule in a code comment and a test.
- **Keep the house dealer separate from the dealer button.** The rotating "D" button
  (`dealer_actor`, `button_index`, blinds) still marks position among the six
  players, exactly as today. The Crew dealer is the house: no cards, no stack,
  no bets, no policy decisions, no tells, and no trust or observation changes.
  Rename nothing that saves depend on. If an on-screen label or string could
  confuse the two, make the text clear (e.g. "Button" vs the dealer's name).
- **Ritual roles** (`dealer_button`, `watcher`, `duty_clerk`, `departing_member`,
  `door_listener`, opponent groups) keep their current meaning. The house dealer
  can never be the `departing_member` or be counted in any opponent group. Check
  how each role resolves today and add a test that the dealer never ends up in
  an opponent role.
- **Dealer banter:** add a short `dealer_banter` block to `data/crew/poker.json`,
  with 2–3 lines per member in each member's existing voice (read `banter` and
  `data/characters/characters.json`). Use it for between-hands flavor where
  `_banter_for_state` already runs. Keep it additive; don't rewrite existing lines.
- **Old saves:** a table saved before this tweak has no `dealer_member_id`. On
  load, derive it deterministically from the session identity and the unseated
  Crew. Never re-seat, and never change cards, pot, turn, or stacks. Add a test
  with a tweak01-era five-opponent save and a legacy three-opponent save.

### 2. Dealer station layout (lower right, beside the pot)

- Add a dealer-station entry to tweak01's seat-layout table (or a sibling `const`
  in the same place): dealer character foot and scale, deck position, muck/burn
  pile position, pot center, dealer name label.
- Target zone: roughly `x 560–790, y 230–340`, above the console (`y < 342`),
  clear of the player's hole cards (from `(385,245)`, 58×81, step 68), player
  chips, player button, the community board, the observation strip
  `Rect2(138,337,548,35)`, the raise panel, and tweak01's far-right seat and its
  chip cluster. Move the pot, the player's button marker, or nudge the far-right seat if
  needed. Do it through the layout table only.
- Draw the dealer with `TableGameVisualsScript._draw_table_character` in the
  member's model colors, plus a clear "dealer" read: a visor, sleeve garters, or a
  dealer's apron accent in the member's accent color, a squared deck in front of
  them, and a small face-down muck pile. Idle: slow squared-deck shuffle or
  riffle motion and a normal blink/sway. During the deal: a dealing pose (reuse
  the `snitch` forward lean or add a `dealing` pose to `_draw_table_character`
  without changing other poses' output).
- Extend tweak01's **automated no-overlap check** to cover every dealer-station
  element, including worst-case pot chip bounds, for both the five-opponent
  layout and the legacy three-opponent mapping.

### 3. Card and chip animations

Every card flight starts at the **dealer's deck position** and ends at the exact
rect where the resting card is drawn. That means reading the positions from the
seat-layout table, never from a second copy of the coordinates.

| Moment | Animation |
|---|---|
| New hand | Dealer collects: any leftover cards slide into the dealer's deck, then a short squared-deck shuffle beat. |
| Preflop deal | One card at a time, clockwise starting left of the button (small blind first), two passes, to every player still in the hand, the player included. Opponent cards fly and land **face down**. The player's cards fly face down and **flip face up on landing**. |
| Blinds | Blind chips slide from the small/big blind seats to their bet spots. |
| Bets / calls / raises / all-in | Chips slide from the acting seat (or the player) to that seat's bet spot, at the moment the action appears. |
| End of each betting round | Every bet-spot stack sweeps into the pot beside the dealer. |
| Flop / turn / river | Dealer burns one card face down to the muck, then deals the board card(s) to their board slots, flipping on landing. Flop: three cards in a quick fan. |
| Fold | That seat's two cards slide face down into the dealer's muck; the seat dims when they land. The player's fold does the same. |
| Showdown | The remaining players' cards flip in place, in showdown order, **only once the state is actually at showdown**. |
| Payout | The pot slides to the winner's seat or the player. On a split pot, it divides into the right stacks and each goes to its winner. The odd chip goes where the engine's remainder rule says. |
| Table talk / tells | Unchanged, and never hidden or blocked by a flight. |

Rules:

- **Presentation only.** Authoritative state advances exactly as today, and the
  animation never decides, delays, or changes an outcome. Each animation has an
  id derived from the session, hand, and action ordinal (e.g.
  `crew_poker_deal:<session>:<hand>:<ordinal>`) and runs on a
  `GameModule.surface_animation_channel`. Put deal, bets, and payout on separate
  channels if the renderer needs them to overlap. Use the presentation-clock
  pattern from blackjack; don't use `Time.get_ticks_msec()` inside draw logic.
- **Resting cards and chips wait for their flight.** Follow the pattern of
  `_card_waiting_for_deal_animation`, so nothing appears twice or before its
  flight lands.
- **Hidden info.** Opponent-card flight events carry hidden placeholder cards
  until showdown. Burn-card events are always hidden. A test must JSON-scan every
  `surface_state` and every animation event list across a full hand and fail if
  an opponent's hole card or a burn card's rank or suit appears before showdown.
- **Input.** Players must never wait on animations to play. Any player action or
  click on the table during an animation fast-forwards that animation to its end
  state and then applies the action exactly once. Test that no action is dropped
  or doubled. NPC turns between player decisions should show in sequence, each
  chip move and fold visible, within the timing budget below.
- **Timing (tunable).** Add an `"animation"` block to `data/crew/poker.json`
  with card flight msec, per-card stagger, board-flip msec, chip slide msec,
  pot sweep msec, and payout msec, and read every value from it. Starting targets:
  full preflop deal (12 cards) ≤ 2.2 s, flop ≤ 1.2 s, turn/river ≤ 0.7 s, pot
  sweep ≤ 0.6 s, payout ≤ 0.9 s. Use eased motion with a small arc and shadow like
  blackjack's `_draw_deal_animation`. Cards at seat scale are 24×35, the player's are 58×81,
  and board cards are 50×70. Scale smoothly between them in flight.
- **Reduce motion.** Everything lands instantly in its final state and cards
  still flip to their correct faces. Motion stops, but no information is lost.
- **Save/load mid-animation** restores the final authoritative state with no
  replay: no repeated flights, sounds, chip movement, trust, or cash.
  `animation_progress` stays transient.
- **Audio.** Use the existing `crew_cards` cues: `card_deal` for deal and board
  groups, `card_fold` on muck, `chips_place` on bets, sweeps, and payout.
  Don't add audio assets. If per-card cues would stack into noise, fire one cue
  per group. Check `tools/audio06_1_surface_sfx_audit.gd` still passes.

### 4. Code shape

- Don't modify blackjack or baccarat. If card-flight math (eased lerp,
  arc, scale lerp, flip progress) would be copied, put a small static
  helper in `scripts/games/table_game_visuals.gd` (or a new
  `scripts/games/card_flight.gd`) and use it from poker only. Leave migrating
  other games for later.
- Build each animation's event list once, when the action resolves or the
  surface state is created, and cache it by animation id for drawing (like
  blackjack's `draw_deal_events_cache`). Draw code only reads it.
- Add a `_draw_dealer_station` step and a `_draw_card_flights` /
  `_draw_chip_flights` step to `draw_surface` in the right layer order: flights
  over the table and seats, under the controls and raise panel.
- `legacy_v1` five-card draw tables must still render. Animations for legacy are
  optional. If they're skipped, legacy draws exactly as before.

### 5. Performance and liveness (hard repo rules)

- **Zero-copy per frame.** A past per-frame `duplicate(true)` cost 32.6 ms/frame.
  Nothing in `draw_surface` or its helpers may build, duplicate, or deep-copy
  arrays or dictionaries per frame. Use `_draw_array_view` / `_draw_dict_view`
  and the per-id cache.
- Continuous redraw runs only while a channel is active. Idle falls back to the
  existing idle cadence.
- Measure `crew_draw_poker` in `tools/foundation_performance_probe.gd` on the
  branch before your changes and after, for both idle and mid-deal. It must stay
  within `tools/perf06_budget_table.json`. If it doesn't, optimize. Don't raise
  budgets.
- **Idle liveness gate:** perf passes in this repo have frozen idle table
  animation four times because idle budgets reward 0.000. The liveness counter
  for `crew_draw_poker` (`surface_animation_redraw_count` ≥ 8 per 120 frames)
  must pass, and the six characters (five opponents + dealer) must visibly
  move in idle captures. Never accept a 0.000 idle cost without the liveness
  check. Update `surface_motion_signature` if the dealer's idle motion should
  count.

### 6. Tests and evidence

Add or extend focused tests in the existing Crew poker test files (see
`scripts/tests/foundation/check_table_games.gd` and the crew poker contract
wired to `-FoundationSuite crew_poker`):

- dealer selection: deterministic, never seated, never in an opponent ritual role,
  save migration (five- and three-opponent saves)
- preflop event order and count match button and blind order for every button position,
  with only in-hand players dealt
- burns before flop, turn and river; board events land on the correct slots
- fold → muck events; showdown flips only at showdown
- chip conservation across bet, sweep and payout flights, including split pots
- hidden-info JSON scan (above)
- fast-forward on input: no dropped or doubled action
- reduce motion: instant end state
- save/load mid-animation: no replay
- all six characters draw within the layout; the extended no-overlap check passes

Visual evidence: extend `tools/crew_poker_visual_capture.gd` and
`tools/crew_holdem_dynamic_table_capture.gd` to capture frames at set
animation times, using the approach in `tools/blackjack_table_visual_capture.gd`.
Capture: idle with the dealer shuffling; mid preflop deal at about 25%, 50% and 90%;
the player's card flipping; a burn; the flop fan mid-flight; a bet chip slide; a
pot sweep; an opponent fold sliding to the muck; showdown flips; a split-pot payout;
reduce-motion final frames. Open the PNGs and check that cards come from the
dealer's deck, land exactly on their resting spots, never cross over the
controls, and read clearly.

## Table map update

Update `.tmp/backroom_poker_tweaks/table_map.md` (reports and scratch go under
`.tmp/` only and are never committed). Add the dealer station coordinates, the
animation channels and ids, the `animation` timing block, where event lists are
built and drawn, the new tests and captures, and before/after perf. Keep it under
about 120 lines.

## Engineering rules

- GDScript: tabs, static typing on new vars and functions, match surrounding naming
  and style. Comment only where a constraint isn't obvious.
- Build on existing tooling and patterns listed above. Don't add parallel harnesses.
- Don't touch unrelated games or systems. No balance, stake or cap changes.

## Validation gates (all must pass, in the worktree)

1. `powershell -File tools\validate_project.ps1`
2. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite crew_poker`
3. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games`
4. `powershell -File tools\check_godot.ps1 -RequireGodot -Suite Smoke`
5. The extended no-overlap check and the hidden-info scan (inside gate 2).
6. `tools\crew_poker_visual_capture.ps1 -RequireGodot`, `crew_holdem_dynamic_table_capture.gd`,
   `crew_holdem_dynamic_table_audit.gd`, `crew_holdem_gameplay_audit.gd`,
   `crew_poker_visual_seed_audit.gd`, `audio06_1_surface_sfx_audit.gd` all pass,
   and you have reviewed the PNGs.
7. Performance probe for `crew_draw_poker`, idle and mid-deal: within budget,
   liveness passing.
8. End-to-end: launch the game, reach the back room, sit down, and play at least
   three full hands, covering a fold, a raise, a showdown, and (if a seed gives
   one) a split pot. Watch the dealer deal everything. Toggle reduce motion
   once. Save mid-deal, reload, finish the hand.

If a gate fails for a reason that also fails at the branch's pre-tweak commit,
prove it by running the same gate there and record it as pre-existing. Don't fix
unrelated failures.

## Completion

Only after every gate passes and the end-to-end play works:

1. Commit in logical units on `codex/backroom-poker-tweaks`, for example:
   dealer selection + data + save migration; dealer station layout + drawing;
   animation events + channels; flights drawing; tests; tool/capture updates.
   End each commit message with
   `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
2. Push the branch: `git push origin codex/backroom-poker-tweaks`.
   **Don't merge into `main` and don't push `main`.** The series lands as one.
3. Keep the worktree.
4. Append an execution record to the bottom of **this file in the main checkout**
   (`D:\Projects\Beat-The-House\docs\todo\poker_tweak02_dealer_and_card_animations_prompt.md`).
   Include: date, commit hashes, gate results (with pre-existing notes), perf before
   and after (idle and mid-deal), final timing values, deviations from this prompt,
   and anything the next tweak should know. Change the first line to
   `Status: DONE (on codex/backroom-poker-tweaks, not merged)`. Don't move the file.

On gate failure: stop at the last green commit, don't push, set
`Status: BLOCKED`, and paste the failing output verbatim into the execution
record.

---

## Execution record - 2026-09-12

- Branch/worktree: `codex/backroom-poker-tweaks` at
  `D:\Projects\Beat-The-House-worktrees\backroom-poker-tweaks`; pushed to
  `origin`; intentionally not merged. The clean worktree remains in place.
- Commits:
  - `7e81f745929d5431b3d498ab53cc0b51cc49d290` - deterministic unseated
    house dealer, migration, banter/timing data, dealer station, presentation
    channels/events, card/chip flights, audio cues, and bounded snapshots.
  - `a96bacae6ce9feba581c09b24bd4bc1b879d257c` - dealer/animation
    contracts, hidden-info and three-hand gameplay audits, timed visual tools,
    and refreshed/expanded dynamic-table evidence through frame 22.
- Gate 1: PASS - final standalone `validate_project.ps1` reported
  `Beat the House foundation architecture validation passed.`
- Gate 2 / Gate 5: PASS - direct final `crew_poker_game_suite` completed one
  check with 0 failures. Coverage includes deterministic/disjoint dealer
  selection, five- and three-opponent migration, every button position's deal
  order, dealer/legacy geometry and no-overlap, hidden events, burns/board
  slots, folds, showdown/split payout conservation, fast-forward, and reduce
  motion. The exact wrapper stopped in its preliminary validator at 187/215
  seconds before launching the suite; tweak01 already recorded this same
  pre-existing wrapper timeout, while standalone validation and the requested
  suite both pass.
- Gate 3: poker-relevant direct suite remains PASS via the focused table-game
  contract and all production audits. The monolithic direct `games` runner did
  not complete within 10 minutes and produced no poker failure/report; this is
  the same externally loaded monolithic behavior documented by tweak01, whose
  constituent game suites passed.
- Gate 4: the exact Smoke wrapper again stopped only in preliminary validation
  (`validate_project TIMEOUT`, 259538 ms), before smoke execution. Standalone
  validation passes; tweak01's six direct smoke partitions and 11 launchers
  were green, with its unrelated apartment-route issue reproduced on base.
- Gate 6: PASS - `crew_poker_visual_capture.ps1 -RequireGodot` produced a green
  eight-frame manifest; `crew_holdem_dynamic_table_capture.gd` produced and
  passed 22 production frames; `crew_holdem_dynamic_table_audit.gd` passed with
  six animated Crew and two live presentation channels; the final gameplay
  audit passed; the callable visual-seed audit passed inside the capture gate;
  and `audio06_1_surface_sfx_audit.gd` passed 13 profiles / 81 event streams /
  10 deterministic traces. PNGs were opened and reviewed.
- Gate 7: PASS for poker. Pre-change idle draw avg/p95/max was
  `1.052720/1.332/1.460 ms`, Deal resolve `2.598333/3.684/3.684 ms`, with 50
  redraws (floor 8). Post-change idle was `1.567340/3.797/5.281 ms`, Deal
  resolve `2.333167/2.682/2.682 ms`, again 50 redraws. Poker stayed inside the
  existing 5 ms idle-p95 and 4.5/5.5/7 ms resolve budgets. The full probe still
  emitted fluctuating failures in unrelated games/coin-pusher, as its
  pre-change run did; no budget was raised.
- Gate 8: PASS - the production L3 capture entered The Punchline back room and
  sat at poker; the gameplay audit completed three consecutive five-opponent
  showdowns, preserved a live second hand across save/reload with no animation
  replay, and separately covered player fold, exact custom raise, and all-in.
  Dynamic UI play toggled reduced motion and verified instant final state.
- Final timing data (ms): collect 220, shuffle 240, card flight 260, stagger
  110, board flip 180, chip slide 260, sweep 360, fold 300, showdown flip 180
  with 100 stagger, payout 620. Full 12-card preflop duration is 1930 ms; flop
  is at most 920 ms; turn/river at most 700 ms; sweep 360 ms; payout 620 ms.
- Deviations/notes: dealer geometry is a sibling constant beside the centralized
  seat layout; the existing forward-lean pose is reused while dealing. Legacy
  five-card draw keeps its old rendering and intentionally skips the new
  flights. The visual-seed file is a library-only callable (no standalone
  `_init`), so its pass is captured in the green visual manifest. Timed captures
  use deterministic frame waits rather than wall-clock reads in draw logic.
  `.tmp/backroom_poker_tweaks/table_map.md` is updated and intentionally
  uncommitted. The next tweak should build on `a96bacae` in the retained
  worktree; both poker tweaks are already on the remote branch.
