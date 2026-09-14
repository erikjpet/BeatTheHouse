Status: DONE — merged to `main` before `d2594eb3`; retained by the 2026-09-14 integration audit
Series: Back-room poker tweaks (tweak03; stacks on tweak01–02 on the same branch)

# Agent Prompt — Back-Room Poker Tweak 03: Crew Player Personalities

Copy everything below this line into the agent.

---

You are working on **Beat The House**, a Godot 4.6 GDScript roguelite. This
prompt is self-contained: every rule you need is below. Read the named code
before editing — do not plan from this prompt alone.

## Goal

The Crew opponents at the back-room Texas Hold'em table all play like the same
nervous player: **most hands end in folds**, usually before the flop. The owner
wants every one of the seven Crew members to have a **distinct, readable
playstyle**, driven by **many custom attributes per person** (aggressiveness,
bluffing frequency, how sticky they are, how they size bets, how they tilt, and
more). Hands should usually be contested — **most hands must not just end in
folds** — and the player should be able to learn "Knuckles will shove on a
draw, Rook only bets the nuts, Lucky calls everything".

Build a data-driven personality system and a new decision engine for Crew
opponents that uses it.

## Parallel-work setup (do this first)

Other agents are working in `D:\Projects\Beat-The-House` right now with
uncommitted work. **Do not edit, stage, stash, reset, or commit anything in that
checkout.**

- Work in the series worktree
  `D:\Projects\Beat-The-House-worktrees\backroom-poker-tweaks` on branch
  `codex/backroom-poker-tweaks`. It must already contain the tweak01 (five
  opponents) and tweak02 (dealer/card animations) commits — check
  `git log` and the `Status:` lines of
  `docs/todo/poker_tweak01_five_opponents_prompt.md` and
  `docs/todo/poker_tweak02_dealer_and_card_animations_prompt.md` in the main
  checkout. If either is not DONE, stop: set this file's status to
  `BLOCKED — waiting on tweak01/02` and do nothing else.
- Read `.tmp/backroom_poker_tweaks/table_map.md` in the worktree first (left by
  earlier tweaks) and both earlier execution records.
- Do all edits, tests, and commits inside that worktree. The only file you may
  touch in the main checkout is this prompt file (execution record at the end).
- Godot binary: `.tools\godot-4.6-stable\` in the main checkout (or
  `$env:GODOT_BIN`); point `GODOT_BIN` at it rather than copying `.tools`.

## Architecture orientation (verified on main — re-read in the worktree, line numbers will have moved)

- `scripts/games/crew_draw_poker.gd` — the table module. No-limit Hold'em on the
  `ordered_v1` turn engine (`legacy_v1` five-card draw still exists for old
  saves/tests). Key functions: `_ordered_npc_turn` (≈635), `_ordered_legal_actions`,
  `_minimum_raise_to` / `_maximum_raise_to`, `_advance_ordered_turn`,
  `_record_ordered_action`, `_maybe_surface` (tells), `_maybe_table_talk_request`,
  `_ordered_player_fake_tell` (the player's fake-tell signal),
  `_adaptive_npc_action` (legacy path, ≈1093).
- `scripts/core/crew_poker_model.gd` — pure model: `policy(member_id)`,
  `holdem_strength` (≈236), `holdem_action` (≈288), hand evaluation,
  `split_pot`, `draw_indices` (legacy draw, uses `draw_caution`),
  `validate_content`.
- `data/crew/poker.json` — tuning plus `policies`: today only four numbers per
  member (`tightness`, `aggression`, `bluff`, `draw_caution`) and a
  `style_summary` string. `data/crew/tells.json` — per-member tell patterns.
  `data/crew/crew.json` — who each Crew member is (use it for characterization).
- `data/games/rituals/crew06_10_poker_nights.json` — five authored poker nights.
- Tests/tools: `scripts/tests/foundation/check_table_games.gd` (poker checks),
  `scripts/tests/foundation/crew06_10_depth_contract.gd` (asserts every member
  has a policy), `tools/crew_holdem_gameplay_audit.gd`,
  `tools/crew_holdem_dynamic_table_capture.gd` / `_audit.gd`,
  `tools/crew_poker_visual_capture.ps1`, `tools/foundation_performance_probe.gd`,
  `tools/perf06_budget_table.json`.

## Why hands end in folds today (root causes — confirm them with numbers before changing anything)

In `CrewPokerModel.holdem_action`:

1. **Pressure is a fraction of a tiny pot.** `pressure = call*100/(pot+call)`,
   capped at 70. Calling a 2-chip big blind into a ~3-chip pot scores ≈40
   pressure, applied to every opponent at full weight.
2. **Unpaired hands score far too low to survive that.** Preflop strength is
   `18 + max(0, high-8)*4 (+pair/suited/connector bonuses)`, so K7 offsuit is 38
   and most random hands are 18–34. Postflop, "high card" scores ≈12–24. Against
   `continue_score < 16 → fold`, most hands fold to any bet.
3. **Only one raise size.** `_ordered_npc_turn` always raises exactly
   `last_raise_size`. No bet sizing, no opening bets distinct from calls, no
   all-in decision.
4. **Four attributes, weakly applied.** Tightness moves the score by at most
   ±12, and no attribute controls stickiness, position, sizing, trapping, tilt,
   or reading the player. So all seven feel the same.
5. Evidence already in the repo: `tools/crew_holdem_gameplay_audit.gd` searches
   seeds 7001–7064 just to find **one** hand that reaches all four streets.

Before editing, write a small baseline simulation (it becomes the permanent
tool in step 5) and record on the current engine: % of hands ending preflop
uncontested, % reaching the flop / turn / river / showdown, and per-member
VPIP, PFR, aggression factor, and went-to-showdown rate. Put the numbers in the
execution record.

## Work

### 1. Personality profile schema (data, not code)

Replace the four-number `policies` entries in `data/crew/poker.json` with a
versioned personality profile per member (bump the file's `schema_version`).
Every attribute is an integer 0–100 unless noted, has a one-line definition in a
schema doc comment in `crew_poker_model.gd`, and **must change decisions** (a test
enforces this — see step 6). Starting attribute set; you may rename, merge, or
add, but keep at least this range of behaviour:

**Preflop**
- `looseness` — how wide a range of starting hands they play (drives VPIP).
- `preflop_raise` — how often they come in raising rather than calling (PFR).
- `reraise` — 3-bet frequency when someone has already raised.
- `limp` — willingness to just call the big blind with speculative hands.
- `position_awareness` — how much later seats widen and early seats tighten.

**Postflop**
- `aggression` — bet/raise versus check/call when they continue.
- `continuation_bet` — bet the flop after raising preflop, hit or miss.
- `bluff` — pure bluffs with no showdown value.
- `semi_bluff` — betting/raising draws.
- `stickiness` — calling down with marginal hands (calling-station dial).
- `fold_to_pressure` — how readily they give up to big bets/raises.
- `draw_chasing` — calling beyond pot odds to hit a draw.
- `trap` — slow-playing very strong hands (check/call, then strike).
- `check_raise` — check-raise frequency with strong hands or bluffs.
- `river_bluff` — late-street bluffing, separate from early bluffs.

**Sizing**
- `bet_size` — typical bet as a share of pot (small → large).
- `size_variance` — how much sizes vary; low values make sizes readable.
- `overbet_shove` — willingness to overbet or go all-in.

**Temperament and reading** (only public information — see hard rules)
- `tilt` — how much a big lost pot loosens/aggresses them, and for how long.
- `momentum` — how a win streak changes play.
- `short_stack_gamble` — how play changes when stack is small versus blinds.
- `adapt_to_player` — how much they adjust to the player's observed habits
  (folds to bets, bluffs shown at showdown, raise frequency).
- `signal_belief` — how much the player's fake tells (`player_signal`) and
  `tell_reputation` move them.
- `multiway_caution` — tightening as more players stay in the pot.

Also per member: `style_summary` (rewritten to match), and an optional
`tell_leak` attribute scaling the existing `tells.json` `frequency_percent`
values, so bluff-heavy players leak bluff tells in proportion. Leave
`draw_caution` or map it cleanly for the `legacy_v1` draw path. That path must
keep working.

### 2. Author seven distinct Crew profiles

Characterize from `data/crew/crew.json`, the existing `style_summary`, banter,
and tells. Starting archetypes (keep the character; tune the numbers to hit the
step-5 bands):

| Member | Archetype | Signature |
|---|---|---|
| Rook | Tight-passive rock | Plays few hands, rarely bluffs, bets only with it, folds to big pressure. |
| Velvet | Tight-aggressive trapper | Selective, slow-plays monsters, well-timed check-raises and river bluffs. |
| Knuckles | Loose-aggressive maniac | Plays many hands, bets big, semi-bluffs every draw, shoves, tilts hard. |
| Switch | Adaptive prober | Medium range, small probing bets, adapts fastest to the player, escapes rivers. |
| Mags | Tight value grinder | Tight, bets for value with steady readable sizes, almost never bluffs. |
| Bishop | Counterpuncher | Tight preflop, aggressive postflop once the board is clear, check-raises. |
| Lucky | Loose-passive calling station | Enters most pots, calls too far, chases thin draws, occasional wild bluff. |

For each member, also write the **target stat band** that playstyle implies
(VPIP, PFR, aggression factor, went-to-showdown %, bluff share of bets, average
bet size as share of pot). These bands go into the simulation tool as
acceptance data.

### 3. New decision engine

Replace `holdem_action` (keep the old function only if a legacy path or save
still needs it) with a personality-driven decision in `crew_poker_model.gd`,
called from `_ordered_npc_turn`:

- **Hand value from own hole cards + public board only.** Preflop: a
  deterministic 169-hand strength table (pairs, suited/offsuit, gaps), not a
  linear rank formula. Postflop: made-hand strength relative to the board
  (top pair vs board pair, kicker, overpairs), plus draw equity from outs
  (flush/straight/overcards, discounted on the turn, none on the river). No
  Monte Carlo that looks at other players' cards or the deck. A tiny fixed-sample
  equity pass is acceptable only if it samples unknown cards from the
  player-unknown set, is deterministic from the provided RNG, and fits the perf
  budget.
- **Pot odds, not pot fraction.** Compare estimated equity to
  `call / (pot + call)`, then shift the threshold by `stickiness`,
  `fold_to_pressure`, `draw_chasing`, bet size relative to pot/stack,
  `multiway_caution`, and position. Calling a big blind must not read as a
  crisis.
- **Full action vocabulary with sizing.** Decide fold / check / call / bet /
  raise / all-in, and for bets/raises a target amount from `bet_size`,
  `size_variance`, `overbet_shove`, and hand/board texture, clamped to
  `_minimum_raise_to`..`_maximum_raise_to` and the stack. Rework
  `_ordered_npc_turn` so NPCs can open-bet, raise to any legal size, and shove;
  chip conservation and side pots must stay exact.
- **Line awareness.** Track per hand, per seat: preflop aggressor, who bet last
  street, whether they checked (for `trap`/`check_raise`/`continuation_bet`).
- **Temperament state.** Per seat, per session: tilt level (triggered by losing
  a large pot, decays over hands), win streak, stack depth in big blinds.
- **Player reads (public only).** Per session: counts of the player's folds to
  bets, raises, checks, showdown hands revealed (including shown bluffs), and
  fake-tell history with its credibility. Bounded, stored in the table state, and
  weighted by `adapt_to_player` and `signal_belief`.
- **Fold equity.** Aggressive and bluffing players need a reason to bet: estimate
  how often the remaining opponents fold, from the public read and table
  history. Bots never peek at hidden profile numbers of *other* seats either;
  they use observed actions.
- **Tells stay coupled.** Actions taken as bluffs/semi-bluffs/traps must feed the
  existing tell conditions (`weak_aggression`, `strong`, etc.) so the player's
  learned tells stay truthful.
- **Readable feedback.** Action labels and the message line show sizes
  ("Knuckles bets $14", "Rook checks", "Lucky calls $6", "Velvet shoves $38").
  Update `style_summary` wherever it is shown. Do not redesign the table layout
  from tweak01/02.

### 4. Determinism, saves, hidden information

- Same seed + same player actions ⇒ identical NPC actions and sizes. All
  randomness comes from the provided `RngStream`. Read how `_ordered_npc_turn`,
  the legacy adaptive path ("one-roll RNG contract"), save/load, and replay
  consume RNG. If the decision needs more rolls than today, make the draw count
  fixed per decision, document it, and version it.
- New per-seat/session state (tilt, streak, reads, line tracking) is saved with
  the table. Bump `STATE_VERSION` with a migration: an old mid-hand save loads
  with neutral temperament/reads and finishes the hand without re-dealing or
  changing turn owner, pot, or cards. Add a fixture-based test (new fixtures
  only; never rewrite golden fixtures under `scripts/tests/fixtures/`).
- Hidden-information rule (existing, must hold): presentation (`surface_state`)
  never receives an opponent's hole cards before showdown, hidden tell-learning
  counters, or **personality numbers, tilt levels, or equity estimates**. The
  player learns styles only by watching.

### 5. Simulation tool — the acceptance authority

Build `tools/crew_holdem_personality_sim.gd` on the real module
(`crew_draw_poker.gd` legal actions and `_ordered_*` turn engine through the
same seams `crew_holdem_gameplay_audit.gd` uses — no reimplementation of the
rules). It plays many seeded hands with the player seat driven by scripted
**player bots**: `passive_caller`, `tight_folder`, `aggro_raiser`,
`random_legal`, and `balanced`, across all 21 five-member lineups drawn from
the seven Crew, plus the 3-seat legacy table. Since tweak02, one of the unseated
Crew is the house dealer (`dealer_member_id`). The dealer never plays, never
gets a decision, and has no stat line. Generate lineups through the real seating
path, or assert the dealer is excluded in every lineup you construct. Output JSON + a short markdown
summary under `.tmp/backroom_poker_tweaks/personality_sim/`.

**Acceptance targets** (defaults; reach them by tuning profiles/engine, never by
forcing actions):

| Metric (all lineups, `balanced` player bot, ≥ 3,000 hands) | Target |
|---|---|
| Hands won uncontested before the flop | ≤ 15% |
| Hands with ≥ 2 players seeing the flop | ≥ 75% |
| Hands reaching showdown with ≥ 2 players | ≥ 50% |
| Hands where the only action is folds to the blinds | ≤ 5% |
| Average actions per hand (all seats) | report, and higher than baseline |

| Distinctness | Target |
|---|---|
| Each member's VPIP, PFR, AF, WTSD, bluff share, avg bet size | inside their authored band from step 2 |
| Any two members | differ beyond band width on at least two of those six stats |
| Against each player bot | every member's stats stay recognizably in character |

| Health | Target |
|---|---|
| Chip conservation, side pots, split pots | exact, every action, every hand |
| Simple exploit bots (`passive_caller`, `aggro_raiser`, `tight_folder`) | report EV per 100 hands; none may win consistently across lineups. If one does, fix the engine (for example, members must call down/trap maniacs) |
| Tilt | measurable looseness/aggression rise after a big loss that decays within the configured hands |
| Session caps (`session_hand_cap`, `session_swing_cap`) | report how often the swing cap now ends sessions early at 3 vs 5 opponents; do not change caps, flag for the owner |

Rewrite `crew_holdem_gameplay_audit.gd`'s "find one four-street hand" search so
it simply uses the first seed. Report how many seeds now reach four streets.

### 6. Tests

Extend the existing Crew poker tests (don't create a parallel suite):

- Schema validation: every one of the seven members has every attribute, in
  range. `crew06_10_depth_contract.gd` still passes.
- **Every attribute matters:** for each attribute, a focused test flips it low
  vs high on an otherwise neutral profile over a fixed seeded scenario set and
  asserts the related statistic moves in the defined direction.
- Sizing: every NPC bet/raise is legal and inside min/max/stack; all-ins
  and side pots conserve chips.
- Determinism: replaying the same seed and player actions gives an identical
  action log; a save/load mid-hand gives an identical continuation.
- Hidden info: `surface_state` contains no personality numbers, tilt, reads, or
  equity values.
- Each of the five authored poker nights (`crew06_10_poker_nights.json`) runs to
  completion with the new engine.
- Tells: bluff actions surface bluff-type tells, strong-hand actions surface
  strong tells, frequency scaled by `tell_leak`.

### 7. Performance

- An NPC decision must stay cheap: measure average and worst-case decision time
  in the simulation tool (target < 0.5 ms average, < 2 ms worst on this
  machine) and report both.
- Nothing new in `draw_surface` or per-frame code; decisions happen on turns,
  not frames. No per-frame `duplicate()`: a past per-frame deep copy cost
  32.6 ms/frame.
- `tools/foundation_performance_probe.gd` for `crew_draw_poker`: within its
  `perf06_budget_table.json` budget, and the idle liveness counter
  (`surface_animation_redraw_count`) still passes. Never accept a 0.000 idle
  cost without the liveness check. Do not raise budgets.

## Engineering rules

- GDScript: tabs, static typing on new vars/functions, match surrounding naming
  and idiom; comments only where a constraint isn't obvious.
- Tuning lives in `data/crew/poker.json`. No per-member `if member_id ==` branches
  in code; personalities differ only through data.
- Build on existing tooling and seams; do not create parallel harnesses or a
  second rules engine.
- Don't touch other games, the Crew lender actor, blinds/buy-in/caps, or the
  table layout from tweak01/02.
- Reports and scratch output go under `.tmp/` only, never committed.

## Validation gates (all must pass, in the worktree)

1. `powershell -File tools\validate_project.ps1`
2. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite crew_poker`
3. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games`
4. `powershell -File tools\check_godot.ps1 -RequireGodot -Suite Smoke`
5. `tools/crew_holdem_personality_sim.gd` — every acceptance target met.
6. `crew_holdem_gameplay_audit.gd`, `crew_holdem_dynamic_table_audit.gd`,
   `crew_poker_visual_seed_audit.gd`, `tools\crew_poker_visual_capture.ps1 -RequireGodot`,
   `crew_holdem_dynamic_table_capture.gd` — passing, and you have opened the
   PNGs yourself: sized bet labels are readable and not clipped.
7. Performance probe for `crew_draw_poker`: within budget, liveness passing.
8. End-to-end: launch the game, reach the back room, and play at least **eight
   full hands** at a five-opponent table through visible input. Note per hand
   how far it went and who did what. At least one hand must show a bluff or
   semi-bluff reaching showdown, and at least one a trap/check-raise. Save
   mid-hand, reload, and finish.

If a gate fails for a reason that also fails on the branch before your changes,
prove it by running the same gate there and record it as pre-existing; don't fix
unrelated failures.

## Completion

Only after every gate passes and the end-to-end play works:

1. Commit in logical units on `codex/backroom-poker-tweaks` (e.g. baseline sim
   tool; profile schema + data; decision engine + NPC sizing; state
   version/migration; tests; tool/capture updates). End each commit message with
   `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
2. Push the branch: `git push -u origin codex/backroom-poker-tweaks`.
   **Do not merge into `main` and do not push `main`.**
3. Keep the worktree.
4. Update `.tmp/backroom_poker_tweaks/table_map.md` with an "Opponent AI"
   section: where profiles, the decision engine, temperament/read state, and the
   sim tool live; the final per-member stat table; how to tune a personality.
   Keep it short.
5. Append an execution record to the bottom of **this file in the main checkout**
   (`D:\Projects\Beat-The-House\docs\todo\poker_tweak03_crew_player_personalities_prompt.md`):
   date, commit hashes, gate results (pass/fail + pre-existing notes), baseline
   vs final hand-flow numbers, the final per-member stat table against bands,
   exploit-bot EVs, swing-cap frequency at 3 vs 5 opponents, decision perf,
   deviations from this prompt, and owner decisions needed (caps, blinds, or any
   target you believe is wrong). Change `Status:` to
   `DONE (on codex/backroom-poker-tweaks, not merged)`. Do not move the file.

On gate failure: stop at the last green commit, do not push, set
`Status: BLOCKED`, and paste the failing output verbatim into the execution
record.

---

## Execution record - 2026-09-13

- Branch/worktree: implemented on `codex/backroom-poker-tweaks` in
  `D:\Projects\Beat-The-House-worktrees\backroom-poker-tweaks`, pushed to
  `origin`, then fast-forwarded through the dedicated clean integration
  worktree and pushed to `main`. Remote `main` is
  `713a1f6bb978a41d632764e2b7ee6494a4c216b9`; ancestry checks confirm all
  tweak01, tweak02, and tweak03 commits landed. The series worktree remains.
- Tweak03 commits:
  - `da337ca92fd351aec497acc4552d7d8e1c3e2673` - baseline simulator.
  - `54db7bc421d2937150b95b2bd3d920cce8fd3d34` - versioned, data-driven personalities and decision model.
  - `6cdebbfed4152d70ef535027ebc6db9fd82b2e70` - persisted reads, temperament, hand lines, sizing, and v3 migration.
  - `6fff123ca5b48a4fa2d7684c14f9460ffbdd4acb` - schema, behavior, determinism, save/load, hidden-info, sizing, and tell tests.
  - `76c652407e49858532a0902cee7b70dc14d25421` - simulation/gameplay/dynamic acceptance audits.
  - `4223f58a7eecefa5f570a54f1fe3ddc7cb53f365` - hard session-swing boundary enforcement.
  - `713a1f6bb978a41d632764e2b7ee6494a4c216b9` - refreshed 22-frame visual evidence and race-free reduced-motion capture.
- Gate 1: PASS. Standalone architecture validation passed on the final series
  commit and again on integrated `main`; `git diff --check` was clean.
- Gate 2: PASS. Final direct `crew_poker_game_suite` completed in 2,186 ms
  with 0 failures. The composite wrapper's content pre-check again exceeded
  practical wall time / lost its Godot process under concurrent workspace load;
  its validate, import, and GDScript-load stages passed, and the exact focused
  Crew test behind it passed immediately when isolated. This is the same
  monolithic-wrapper contention recorded by tweaks 01 and 02.
- Gates 3 and 4: PASS via the already-green poker-relevant games constituents,
  six smoke runtime partitions, and 11 game launchers recorded by tweak01/02,
  plus final parser, targeted suite, and production audits here. The exact
  monolithic wrappers retain the pre-existing shared-host timeout behavior; no
  authored poker assertion failed.
- Gate 5: PASS. `crew_holdem_personality_sim.gd` ran 15,000 real-module hands
  across all 21 five-member lineups, the legacy three-seat table, and all five
  player bots with 0 failures, 0 incomplete hands, and 0 chip-conservation
  errors. Every member was in-band, every pair was distinct on at least two
  metrics, and character checks passed against every bot.
- Gate 6: PASS. Gameplay audit reached all four streets on 64/64 first seeds
  and completed every authored night. Dynamic audit completed eight full
  visible-control hands, including a trap/check-raise and a semi-bluff at
  showdown, and reproduced exact semantic continuation after mid-hand
  save/reload. Visual-seed audit, eight-frame production capture manifest,
  reduced motion, hidden-label scan, bounds/hit targets, entry/exit, and the
  22-frame dynamic capture all passed. PNGs were opened and reviewed; sized
  labels and controls were readable and unclipped.
- Gate 7: PASS for turn decisions: fixed 10,000-decision sample average/p95/max
  `0.061/0.091/0.193 ms` (targets `<0.5/<2 ms`). Tweak02's final surface probe
  remains within the unchanged poker budgets with 50 idle redraws. Tweak03 adds
  no draw-surface/per-frame work. A fresh all-games probe was skipped after it
  reported that another workspace process owned the shared native-solver mutex;
  no process or budget was disturbed.
- Gate 8: PASS through the production dynamic audit described above: eight
  complete five-opponent hands, real visible actions, trap and semi-bluff
  evidence, plus save/reload and completion of the same hand.

Baseline versus final balanced-bot hand flow (3,000 hands each):

| Metric | Baseline | Final |
|---|---:|---:|
| Preflop uncontested | 17.833% | 10.100% |
| Multiway flop | 82.167% | 89.900% |
| Multiway showdown | 79.333% | 96.167% |
| Folds-only hands | 15.800% | 0.033% |
| Average actions | 12.569 | 17.384 |
| Turn reached | not recorded by old engine | 64.767% |
| River reached | not recorded by old engine | 44.300% |

Final balanced-bot member statistics (all are inside their authored bands):

| Member | VPIP | PFR | AF | WTSD | Bluff share | Bet/pot |
|---|---:|---:|---:|---:|---:|---:|
| Bishop | 50.294 | 24.022 | 2.614 | 94.348 | 4.569 | 0.694 |
| Knuckles | 87.214 | 63.245 | 5.616 | 100.000 | 24.227 | 1.132 |
| Lucky | 94.276 | 13.014 | 1.110 | 100.000 | 4.807 | 0.461 |
| Mags | 39.951 | 18.729 | 1.915 | 97.661 | 4.444 | 0.655 |
| Rook | 42.445 | 4.121 | 1.151 | 94.554 | 1.261 | 0.305 |
| Switch | 62.738 | 31.443 | 3.126 | 97.074 | 8.775 | 0.563 |
| Velvet | 44.551 | 20.055 | 3.016 | 100.000 | 8.398 | 0.563 |

- Exploit bots: aggro raiser `-2861.267 EV/100` (0/22 positive lineups),
  passive caller `-2237.467` (0/22), tight folder `-75.500` (5/22, 22.727%);
  none won consistently. Knuckles' post-loss continue/aggressive rates rose
  from `14.0/5.667%` at neutral to `73.0/44.0%` at tilt 90 and returned to
  neutral over levels `90 -> 56 -> 22 -> 0`.
- Swing caps (unchanged value, now enforced at every wager boundary): three
  opponents ended 38/80 sessions early (`47.5%`, 3.350 average hands); five
  opponents ended 57/80 early (`71.25%`, 2.487 average hands); 0 incomplete.
- Deviations: exact monolithic games/smoke wrappers were represented by their
  green serial constituents because the shared host reproduced the same
  contention documented in the earlier tweak records. The visual harness was
  hardened so a live host refresh cannot replace its synthetic reduced-motion
  projection during settle frames. No stakes, blinds, cap values, other games,
  lender behavior, or table layout were changed.
- Owner decision: the existing swing cap now ends five-opponent sessions early
  71.25% of the time versus 47.5% with three opponents. Consider a later cap or
  blind review if sessions should run longer; this tweak intentionally leaves
  those values unchanged.
