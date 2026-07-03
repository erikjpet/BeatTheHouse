# Grand Casino Endgame Design Lock

This document is the authoritative Grand Casino endgame contract for A1-A6,
B2, C1, C3, C5, D1, and D7. It is based on the current top-level README,
`data/environments/archetypes.json`, `scripts/core/run_state.gd`, and the live
boss events in `data/events/events.json`.

The Grand Casino supports two demo victory routes:

- `high_roller_cashout`: clean Players Card recognition at the host desk.
- `pit_boss_showdown`: Pit Boss Rourke calls the player to the back room, and
  the player survives the showdown.

Outside the Grand Casino, existing heat failure behavior remains unchanged:
heat at 100 still fails the run as `police_capture`.

## Narrative Frame

The Grand Casino is the boss floor: high-limit games, camera domes, velvet
ropes, and Pit Boss Rourke watching for edges. Rourke is not a generic police
capture. In this environment, enough heat with staff attention means the house
intervenes personally.

The heat route is the back-room route. Rourke or his staff notice the player,
stop the generic floor action, and call them away from the public tables. The
back room is a pressure scene: Rourke has a read, the player chooses how to
answer, and the final check determines whether they walk out with winnings or
the casino takes them out back.

The clean route is the Players Card route. A player who does not openly cheat,
keeps heat contained, and wins enough on the Grand Casino floor becomes valuable
instead of suspicious. The casino host issues a Players Card and lets them leave
with winnings.

## Canonical IDs

| Purpose | Canonical value |
| --- | --- |
| Grand Casino archetype | `grand_casino` |
| Grand Casino objective id | `grand_casino_demo_bankroll` |
| Showdown event id | `the_house_calls` |
| Players Card event id | `high_roller_cashout` |
| Showdown failure reason | `casino_taken_out_back` |
| Clean victory route | `high_roller_cashout` |
| Heat victory route | `pit_boss_showdown` |

`the_house_calls` already exists and remains the showdown event id. Future work
may change its payload from the current simple landmark choices into the
multi-beat showdown below, but it must not rename the event.

`high_roller_cashout` remains the clean event/action id for save compatibility,
but its player-facing fantasy is the Players Card review. It is also the clean
victory route name. This is intentional: when the event succeeds,
`demo_victory_route` and the clean event id should match.

## Tunable Objective Fields

These values are the initial tuning targets. They must be data-driven in the
Grand Casino `demo_objective` when A1 adds the dual-lane objective data. D3 and
D7 may retune values, but they must keep the ids and rule meanings.

| Field | Initial value | Meaning |
| --- | ---: | --- |
| `high_roller_target_bankroll` | 0 | Legacy compatibility field; the clean route is no longer gated by total bankroll. |
| `high_roller_net_winnings` | 10 | 0.3 release-tuned minimum net bankroll gained after entering the Grand Casino, measured after the Grand Casino travel buy-in is paid. |
| `high_roller_min_grand_casino_games` | 3 | Minimum settled wagered game results on the Grand Casino floor. |
| `high_roller_max_heat` | 30 | Maximum Grand Casino heat for clean cashout. |
| `showdown_heat_threshold` | 70 | Heat that triggers showdown when staff attention is present. |
| `forced_showdown_heat_threshold` | 95 | Heat that forces showdown even if no other attention source is currently true. |
| `showdown_base_success_chance` | 95 | 0.3 release-tuned starting chance for the final showdown check before heat/evidence/debt penalties. |
| `showdown_min_success_chance` | 5 | Lower clamp for the final check. |
| `showdown_max_success_chance` | 95 | Upper clamp for the final check. |

## Canonical State

The endgame state is stored as:

`narrative_flags["grand_casino_endgame_state"]`

Allowed values are:

- `pre-grand`
- `grand-incomplete`
- `high-roller-ready`
- `showdown-pending`
- `showdown-active`
- `victory`
- `failure`

When the flag is missing, code should derive it from current run state:

- `victory` if `run_status == RUN_STATUS_ENDED` and
  `narrative_flags["demo_victory"] == true`.
- `failure` if `run_status == RUN_STATUS_FAILED`.
- `pre-grand` if the current environment archetype is not `grand_casino`.
- `grand-incomplete` if the current environment archetype is `grand_casino` and
  no higher-priority Grand Casino endgame flag is active.

## State Machine

All transitions are evaluated after shared result application, travel, event
resolution, and save-load restore. `RunState` remains the source of truth.

| From | Trigger | To | Required side effects |
| --- | --- | --- | --- |
| `pre-grand` | Current environment archetype becomes `grand_casino`. | `grand-incomplete` | Set `grand_casino_entry_bankroll` if missing for this visit, set counters to at least 0, clear stale ready/active flags. |
| `pre-grand` | Existing non-Grand terminal failure occurs. | `failure` | Preserve existing failure reason, usually `bankroll_zero`, `stranded`, or `police_capture`. |
| `grand-incomplete` | Clean route criteria are met with no blockers. | `high-roller-ready` | Set `grand_casino_high_roller_ready = true`, `high_roller_cashout_pending = true`, and ensure the Players Card review event `high_roller_cashout` can be selected. Do not auto-win. |
| `grand-incomplete` | Heat route trigger is met. | `showdown-pending` | Set showdown flags, set `demo_finale_event_id = "the_house_calls"`, set `the_house_calls_pending = true`, and prevent generic Grand Casino police capture. |
| `grand-incomplete` | Money target is met but clean blockers exist. | `showdown-pending` | Set `grand_casino_attention_high_roller_review = true`; dirty money routes to Rourke instead of the cage. |
| `grand-incomplete` | Player leaves the Grand Casino before any pending finale. | `pre-grand` | Store local heat through existing local suspicion helpers. Keep durable counters/evidence for re-entry. |
| `grand-incomplete` | Existing bankroll or stranded failure occurs. | `failure` | Preserve existing failure reason. |
| `high-roller-ready` | Player selects and resolves the Players Card review event `high_roller_cashout`. | `victory` | Complete demo objective with `demo_victory_route = "high_roller_cashout"`. |
| `high-roller-ready` | Player cheats, heat exceeds `high_roller_max_heat`, or heat route trigger fires before cashout. | `showdown-pending` | Clear `high_roller_cashout_pending`; set showdown flags. |
| `high-roller-ready` | Player leaves before selecting cashout. | `pre-grand` | Clear `high_roller_cashout_pending`. Re-evaluate clean criteria on re-entry. |
| `showdown-pending` | Player answers `the_house_calls`. | `showdown-active` | Lock travel/cashout, set `grand_casino_showdown_active = true`, advance to arrival beat. |
| `showdown-pending` | Heat reaches 100 while pending. | `showdown-pending` | Do not fail as `police_capture`; Rourke's call owns the terminal path. |
| `showdown-pending` | Existing bankroll failure occurs before the showdown opens. | `failure` | Preserve `bankroll_zero` unless the showdown has already started. |
| `showdown-active` | Final showdown check succeeds. | `victory` | Complete demo objective with `demo_victory_route = "pit_boss_showdown"`. |
| `showdown-active` | Final showdown check fails. | `failure` | `fail_run("casino_taken_out_back", message)`. |
| `victory` | Entered by either route. | `victory` | Terminal demo victory. The player leaves with winnings in narrative copy. |
| `failure` | Entered by any failure. | `failure` | Terminal failed run. |

## Clean Route Criteria

The clean route is available only in the Grand Casino and only when no showdown
is pending or active.

All of the following must be true:

- `bankroll - grand_casino_entry_bankroll >= high_roller_net_winnings`
- `grand_casino_games_played >= high_roller_min_grand_casino_games`
- `suspicion_level() <= high_roller_max_heat`
- `grand_casino_cheat_evidence != true`
- `grand_casino_watched_cheat_evidence != true`

Players Card blockers route to Rourke:

- If the money requirements are met but cheat evidence is true, transition to
  `showdown-pending`.
- If the money requirements are met but heat is above
  `high_roller_max_heat`, transition to `showdown-pending`.
- In both blocker cases, set `grand_casino_attention_high_roller_review = true`
  because the cage/host review is the concrete staff attention source.

A Grand Casino game counts when a successful game result is applied through
`GameModule.apply_result()` while the current environment archetype is
`grand_casino`, `result["game_id"]` is not empty, and the result represents a
settled wagered outcome. A settled wagered outcome has either `result["stake"] >
0`, `result["stake_cost"] > 0`, `result["deltas"]["stake_cost"] > 0`, or a
game-specific top-level stake-cost field such as `slot_stake_cost > 0`. Pure
surface navigation, holds, bet placement, clears, undo, and other UI-only
commands do not count. Count at most once per applied game result.

## Cheat Evidence

`grand_casino_cheat_evidence` is persistent for the run once set. Set it when a
Grand Casino game result has `action_kind == "cheat"` or when an active item
result is explicitly used as a cheating tool on the Grand Casino floor.

`grand_casino_watched_cheat_evidence` is the severe subset. Set it when any of
the following happens in the Grand Casino:

- A cheat result resolves while `pit_boss_watch_status(current_environment)`
  returns `{"active": true, "watched": true}`.
- A result or delta reports `pit_boss_heat_bonus > 0`.
- The showdown pressure choice `take_the_edge` is selected.

Risky or advantage actions that are not authored as `action_kind == "cheat"` do
not set cheat evidence by themselves. They still raise heat, can create staff
attention, and can block clean cashout by exceeding `high_roller_max_heat`.

## Staff Attention

Staff attention is required for the normal heat route. It is true if any source
below is true. This list is exhaustive.

| Source key | Persistent flag | Concrete source |
| --- | --- | --- |
| `rourke_watch` | none; derive each evaluation | `pit_boss_watch_status(current_environment).active == true` and `.watched == true`. |
| `watched_cheat` | `grand_casino_attention_watched_cheat` | `grand_casino_watched_cheat_evidence == true`. |
| `pit_boss_sweep` | `grand_casino_attention_pit_boss_sweep` | `pit_boss_sweep` resolved with `act_natural`. `lay_low` does not set it and may clear it. |
| `eye_in_the_sky` | `grand_casino_attention_eye_in_the_sky` | `eye_in_the_sky` is active/unresolved, or it resolved with `press_anyway`. `change_table` clears it. |
| `host` | `grand_casino_attention_host` | `comped_suite_offer` resolved with `take_comp`. `decline` does not set it. |
| `high_roller_review` | `grand_casino_attention_high_roller_review` | Money target is met but clean cashout is blocked by heat or cheat evidence. |
| `forced_heat` | `grand_casino_attention_forced_heat` | Heat reaches `forced_showdown_heat_threshold`. |

For diagnostics and save/load clarity, implementations should maintain:

- `grand_casino_staff_attention`: boolean aggregate.
- `grand_casino_staff_attention_sources`: array of active source keys.

The aggregate flag is derived from the source list and may be recomputed at any
time. Persistent source flags live in `narrative_flags`.

## Heat Route Triggers

The heat route is evaluated only while the current environment archetype is
`grand_casino` and the run is not terminal.

Normal heat trigger:

```text
suspicion_level() >= showdown_heat_threshold
and grand_casino_staff_attention == true
```

Forced heat trigger:

```text
suspicion_level() >= forced_showdown_heat_threshold
```

The forced trigger sets `grand_casino_attention_forced_heat = true` before
transitioning to `showdown-pending`.

When either heat trigger fires, the run must not instantly fail from generic
police capture. A1/A2 must ensure Grand Casino heat routing is evaluated before
`_evaluate_immediate_terminal_state()` or before the `GameModule.apply_result()`
post-suspicion police-capture check finalizes the run. This override applies
only to `grand_casino`.

## Showdown Encounter

The showdown uses the existing event id `the_house_calls`.

### Beat 1: Arrival

State enters `showdown-active`. Rourke calls the player away from the floor to
the back room. The arrival beat records:

- `grand_casino_showdown_attempt`
- `grand_casino_showdown_start_heat`
- `grand_casino_showdown_attention_sources`
- `grand_casino_showdown_trigger_reason`

The trigger reason is one of:

- `heat_attention`
- `forced_heat`
- `dirty_money`
- `manual_event_resume`

### Beat 2: Pressure Choice

The player chooses exactly one pressure response:

| Choice id | Modifier | Rule |
| --- | ---: | --- |
| `hold_steady` | +8 if no cheat evidence, -4 otherwise | The player lets the clean record speak. |
| `talk_down` | +4 | The player leans on host comps, table manners, and plausible luck. |
| `take_the_edge` | +16 before evidence penalties | The player tries one last edge in the back room. Set `grand_casino_watched_cheat_evidence = true` and `grand_casino_showdown_edge_taken = true`. |

Store the choice in:

`narrative_flags["grand_casino_showdown_pressure_choice"]`

### Beat 3: Final Check

Use a deterministic `RngStream` fork. Do not use engine-global random APIs.

```text
showdown_rng = run_state.create_rng("grand_casino_showdown").fork(
    "attempt:%d" % grand_casino_showdown_attempt
)
showdown_roll = showdown_rng.randi_range(1, 100)
success_chance = clampi(
    showdown_base_success_chance
    + pressure_choice_modifier
    + clean_play_modifier
    + item_modifier
    + prior_boss_event_modifier
    - heat_penalty
    - evidence_penalty
    - alcohol_debt_penalty,
    showdown_min_success_chance,
    showdown_max_success_chance
)
success = showdown_roll <= success_chance
```

Persist these values:

- `grand_casino_showdown_roll`
- `grand_casino_showdown_success_chance`
- `grand_casino_showdown_margin` as `success_chance - showdown_roll`
- `grand_casino_showdown_success`

The final check modifiers are exact:

| Modifier | Formula |
| --- | --- |
| `heat_penalty` | `clampi(int(floor(float(maxi(0, suspicion_level() - high_roller_max_heat)) / 5.0)) * 2, 0, 28)` |
| `evidence_penalty` | 20 if `grand_casino_watched_cheat_evidence`, else 10 if `grand_casino_cheat_evidence`, else 0. |
| `clean_play_modifier` | +10 if no cheat evidence and heat is at or below `high_roller_max_heat`; +4 if no cheat evidence but heat is higher; otherwise 0. |
| `item_modifier` | Sum item modifiers below, then clamp from -24 to +10. |
| `alcohol_debt_penalty` | Sum alcohol and debt penalties below, then clamp from 0 to 24. |
| `prior_boss_event_modifier` | Sum boss-event modifiers below, then clamp from -12 to +10. |

Item modifier details:

| Item or item state | Modifier |
| --- | ---: |
| `cheap_sunglasses` in inventory | +4 |
| `card_counters_notes` in inventory and no cheat evidence | +4 |
| `scratch_pad` in inventory and no cheat evidence | +2 |
| `creased_luck_card` in inventory | +2 |
| `lucky_keychain` in inventory | +2 |
| Each held contraband item among `marked_cards`, `foil_sleeve`, `weighted_keyring` | -6 each, max -18 |
| Each held or Grand-Casino-used surveillance item among `xray_glasses`, `tab_detector`, `tarot_card` | -8 each, max -16 |

Alcohol and debt penalties:

| Input | Penalty |
| --- | ---: |
| `drunk_level` 0-10 | 0 |
| `drunk_level` 11-25 | 3 |
| `drunk_level` 26-45 | 6 |
| `drunk_level` 46-70 | 10 |
| `drunk_level` 71+ | 14 |
| `alcoholic_level - drunk_level >= 30` | +4 |
| `alcoholic_level - drunk_level >= 60` | +8 instead of +4 |
| Each open debt entry | +3 each, max +9 |

Prior boss-event modifiers:

| Flag | Modifier |
| --- | ---: |
| `grand_casino_event_pit_boss_sweep_lay_low` | +4 |
| `grand_casino_event_pit_boss_sweep_act_natural` | -3 |
| `grand_casino_event_eye_in_the_sky_change_table` | +5 |
| `grand_casino_event_eye_in_the_sky_press_anyway` | -8 |
| `grand_casino_event_comped_suite_offer_decline` | +3 |
| `grand_casino_event_comped_suite_offer_take_comp` | -4 |

### Beat 4: Outcome

Success:

- Set `grand_casino_endgame_state = "victory"`.
- Complete `grand_casino_demo_bankroll`.
- Set `demo_victory = true`.
- Set `demo_victory_route = "pit_boss_showdown"`.
- Set `demo_finale_completed = true`.
- Clear `demo_finale_pending`, `the_house_calls_pending`,
  `grand_casino_showdown_pending`, and `grand_casino_showdown_active`.
- Log a `demo_victory` story entry with `finale_event_id = "the_house_calls"`
  and `finale_branch = "pit_boss_showdown"`.
- Player-facing outcome: Rourke cannot prove enough to keep the winnings; the
  player leaves the Grand Casino with cash.

Failure:

- Set `grand_casino_endgame_state = "failure"`.
- Set `grand_casino_showdown_success = false`.
- Clear pending/active showdown flags.
- Call `fail_run("casino_taken_out_back", message)`.
- Log a `demo_finale_result` story entry with
  `finale_event_id = "the_house_calls"` and
  `finale_branch = "casino_taken_out_back"`.
- Player-facing outcome: the casino takes the player out back and the run ends.

## High-Roller Cashout

The clean route uses `high_roller_cashout`.

When the clean criteria become true, the Grand Casino does not immediately end
the run. It exposes a deliberate host interaction:

- Event/action id: `high_roller_cashout`
- Pending flag: `high_roller_cashout_pending`
- State flag: `grand_casino_high_roller_ready`

Resolving the Players Card review:

- Sets `grand_casino_endgame_state = "victory"`.
- Completes `grand_casino_demo_bankroll`.
- Sets `demo_victory = true`.
- Sets `demo_victory_route = "high_roller_cashout"`.
- Clears `high_roller_cashout_pending` and `grand_casino_high_roller_ready`.
- Logs a `demo_victory` story entry with
  `finale_event_id = "high_roller_cashout"` and
  `finale_branch = "high_roller_cashout"`.
- Player-facing outcome: the host issues the Grand Casino Players Card and the
  player leaves with winnings.

## Narrative Flags

All new persistent state should live in `narrative_flags` unless a later task
adds a typed RunState field with explicit save/load migration. Current
`RunState.to_payload()` and `RunState.from_payload()` already preserve
`narrative_flags`.

Required flags:

| Flag | Type | Meaning |
| --- | --- | --- |
| `grand_casino_endgame_state` | String | Canonical state-machine state. |
| `grand_casino_entry_bankroll` | int | Bankroll when this Grand Casino visit began, after the Grand Casino travel buy-in is paid. |
| `grand_casino_games_played` | int | Settled wagered Grand Casino results. |
| `grand_casino_net_winnings` | int | `bankroll - grand_casino_entry_bankroll`. |
| `grand_casino_cheat_evidence` | bool | Any Grand Casino cheat evidence. |
| `grand_casino_watched_cheat_evidence` | bool | Cheat evidence seen while watched or with pit-boss heat bonus. |
| `grand_casino_staff_attention` | bool | Aggregate staff-attention status. |
| `grand_casino_staff_attention_sources` | Array[String] | Active attention source keys. |
| `grand_casino_high_roller_ready` | bool | Players Card review is available. |
| `high_roller_cashout_pending` | bool | Players Card review event/action can be selected. |
| `grand_casino_showdown_pending` | bool | Rourke has called the player, but showdown UI is not active. |
| `grand_casino_showdown_active` | bool | Showdown encounter is currently resolving. |
| `grand_casino_showdown_attempt` | int | 1-based attempt count. |
| `grand_casino_showdown_trigger_reason` | String | Heat, forced heat, dirty money, or resume trigger. |
| `grand_casino_showdown_pressure_choice` | String | Selected pressure response. |
| `grand_casino_showdown_edge_taken` | bool | Player chose `take_the_edge`. |
| `grand_casino_showdown_roll` | int | Deterministic final roll. |
| `grand_casino_showdown_success_chance` | int | Final clamped success chance. |
| `grand_casino_showdown_margin` | int | `success_chance - roll`. |
| `grand_casino_showdown_success` | bool | Final showdown outcome. |
| `demo_victory_route` | String | `high_roller_cashout` or `pit_boss_showdown`. |

Required compatibility flags:

- `demo_finale_ready`
- `demo_finale_pending`
- `demo_finale_event_id`
- `demo_finale_completed`
- `the_house_calls_pending`

Required attention flags:

- `grand_casino_attention_watched_cheat`
- `grand_casino_attention_pit_boss_sweep`
- `grand_casino_attention_eye_in_the_sky`
- `grand_casino_attention_host`
- `grand_casino_attention_high_roller_review`
- `grand_casino_attention_forced_heat`

Required boss-event outcome flags:

- `grand_casino_event_pit_boss_sweep_lay_low`
- `grand_casino_event_pit_boss_sweep_act_natural`
- `grand_casino_event_eye_in_the_sky_change_table`
- `grand_casino_event_eye_in_the_sky_press_anyway`
- `grand_casino_event_comped_suite_offer_take_comp`
- `grand_casino_event_comped_suite_offer_decline`

## RunState Helper Cross-Check

The design is implementable against current `run_state.gd` helpers:

- `demo_objective_status()` already returns objective id, type, target bankroll,
  completion, finale id, and finale pending state. A1 should extend the Grand
  Casino objective status with the dual-lane fields above while preserving the
  existing `grand_casino_demo_bankroll` id.
- `evaluate_environment_objective_state()` already centralizes data-authored
  objective completion. A1 should replace the current single bankroll-target
  finale behavior for `grand_casino` with the state-machine routing defined
  here.
- `pit_boss_watch_status()` already provides `active`, `watched`,
  `cheat_heat_bonus`, `base_cheat_heat_bonus`, and player-facing summary.
  The `watched` result is the `rourke_watch` staff-attention source.
- `security_action_pressure()` already escalates risky/cheat results at high
  heat and marks `ended` at 100. A2 must add the Grand Casino override before
  generic `police_capture` wins, while leaving non-Grand environments unchanged.
- `apply_demo_finale_result()` already completes demo victory through
  `demo_finale` payloads and logs finale results. A3 can extend it or route the
  showdown surface through equivalent RunState-owned methods, but success and
  failure must use the canonical route and failure ids above.
- `narrative_flags` and `story_log` already round trip through save payloads,
  so the required flags can be preserved without inventing a parallel save
  structure.
