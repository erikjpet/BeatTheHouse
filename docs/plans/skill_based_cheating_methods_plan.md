# Skill-Based Cheating Methods Plan

Status: **IMPLEMENTED DESIGN LOCK** for the unreleased 0.4.0 candidate.
Symbol names and shared result contracts remain authoritative; numeric line
references in the source-check section are historical and should not be used
for navigation after later architecture work.
Date: 2026-07-01

This document defines the shared skill-cheat contract for Act 1. It is a
design-only plan: no gameplay code changes are implied here. T2.2-T2.5 implement
the four Phase 1 cheats against this contract, and T2.6 audits every existing
cheat/advantage action for the same reporting shape.

## Source Check

The plan was cross-checked against these current implementation points:

- `scripts/games/blackjack.gd:4188` starts the count challenge, `:4406` syncs
  icons, and `:4489` finalizes the challenge.
- `scripts/games/blackjack.gd:745` finalizes an unanswered count before
  settlement; `:772` selects `legal`, `risky`, or `cheat`; `:803` records the
  pit-boss fields.
- `scripts/core/game_module.gd:68` builds cheat action rows with
  security/pit-boss pressure; `:311` defines the current skill action kinds;
  `:386` normalizes skill-cheat result fields; `:471` applies result deltas and
  calls Grand Casino result recording.
- `scripts/core/run_state.gd:409` applies alcohol heat scaling; `:473` exposes
  `security_risk_bonus`; `:492` exposes `security_action_pressure`; `:733`
  records Grand Casino game evidence; `:1462` exposes `pit_boss_watch_status`.
- `docs/plans/grand_casino_endgame_design.md:155` defines cheat evidence, and
  `:173` defines staff attention sources.
- Current non-blackjack cheats are immediate or ad hoc: video poker
  `mark_holds`, bar dice `loaded_toss`/`palmed_swap`, roulette
  `read_wheel_bias`/`roulette_nudge`, baccarat `read_baccarat_shoe`, pull-tab
  detector/tarot/x-ray paths, and slot `nudge`.

## 1. Shared Skill-Cheat Contract

A skill cheat is a multi-step player interaction that creates an edge through a
timing, memory, or observation check. It must be readable before commitment,
graded after input, and reported through shared security and story fields.

The allowed `action_kind` values are the existing shared values:

| Value | Meaning | Grand Casino evidence |
| --- | --- | --- |
| `cheat` | A forbidden or concealed move. | Sets `grand_casino_cheat_evidence`; if watched or heat-bonused, also sets watched-cheat evidence. |
| `risky` | Legal play that draws heat through behavior or attention. | Does not set cheat evidence by itself, but can create watched-risky attention and block clean cashout by heat. |
| `advantage` | A legal skill read or table edge. | Does not set cheat evidence by itself, but still uses the skill contract when heat/reward is reported. |

Phase 1 cheats all resolve as `action_kind == "cheat"` because they conceal a
move from the house. Later legal tells can use `advantage`, and visible social
pressure decisions can use `risky`.

### State Machine Pattern

Each skill cheat copies the blackjack count-challenge pattern:

1. Arm the cheat from a surface action or cheat action.
2. Write a serializable challenge dictionary into `ui_state` or the game table
   state.
3. Draw timed icons, markers, or memory prompts through the game surface.
4. Register hit regions through existing surface hit-region helpers.
5. Sync challenge state during surface refresh without consuming global RNG.
6. Finalize on player input, timeout, settle, or leaving the surface.
7. Apply a graded result through `GameModule.build_action_result()` and
   `GameModule.apply_result()`.

Challenge state must survive save/load where it is stored in durable game state.
When a challenge is only UI-local, implementation tasks must either finalize or
discard it on resolve, then prove a save/load round trip cannot leave a broken
surface. No challenge may store Object references, Node references, callables, or
unserializable resources.

### Common Result Shape

Every skill-cheat result must expose the same facts at payload level and in the
matching `deltas["story_log"]` entry. `GameModule.normalize_skill_cheat_contract`
already mirrors many of these into `skill_cheat_contract`, `skill_watched`,
`watched`, `skill_suspicion_delta`, `skill_payoff_delta`, and
`skill_story_context`; implementations should still provide the explicit fields
below for clarity and tests.

| Field | Type | Required rule |
| --- | --- | --- |
| `action_kind` | String | One of `cheat`, `risky`, `advantage`; Phase 1 uses `cheat`. |
| `skill_outcome` | String | Stable id for the result: examples `perfect`, `good`, `partial`, `miss`, `blown`, or game-prefixed equivalents. |
| `skill_grade` | String | Player-facing grade bucket. May match `skill_outcome` when no extra taxonomy is needed. |
| `skill_accuracy` | float/int | Normalized 0-100 score or signed distance metric for memory/observation checks. |
| `skill_margin_msec` | int | Signed timing distance when the check is timing-based; omit or set 0 for pure memory checks. |
| `suspicion_delta` | int | Final heat delta after item, alcohol, security, and pit-boss adjustments. |
| `base_suspicion_delta` | int | Pre-pressure heat, when available. |
| `pit_boss_watched` | bool | Directly from `RunState.pit_boss_watch_status(environment).watched`. |
| `pit_boss_heat_bonus` | int | Directly from the same watch status when active. |
| `skill_security_pressure_checked` | bool | True whenever `security_action_pressure` was evaluated or intentionally checked as zero. |
| `security_message` | String | Message returned by `security_action_pressure`, if any. |
| `skill_story_context` | Dictionary | Durable compact context for diagnostics, Grand Casino review, and test probes. |

`skill_story_context` must include at least:

```gdscript
{
	"game_id": get_id(),
	"action_id": action_id,
	"action_kind": action_kind,
	"skill_outcome": skill_outcome,
	"skill_grade": skill_grade,
	"suspicion_delta": suspicion_delta,
	"bankroll_delta": bankroll_delta,
	"watched": pit_boss_watched,
	"pit_boss_heat_bonus": pit_boss_heat_bonus,
}
```

Game-specific fields belong inside `skill_story_context` or explicit
game-prefixed result fields, not as replacements for the shared fields.

### Heat And Security Routing

For every skill-cheat resolution:

1. Start with the data-defined base heat from `data/games/games.json` or a local
   tunable.
2. Add applicable item modifiers, including `cheat_suspicion_delta` and any
   game-specific skill-cheat keys.
3. Add `run_state.security_risk_bonus(action_kind)`.
4. Add `pit_boss_heat_bonus` from `run_state.pit_boss_watch_status(environment)`.
5. Apply `run_state.alcohol_adjusted_suspicion_delta(raw_heat)` for positive
   heat.
6. Call `run_state.security_action_pressure(action_kind, stake, run_state.suspicion_level() + suspicion_delta)`.
7. Add any returned `bankroll_delta`, `message`, and `ended` fields to the
   result.

Even a clean perfect grade should report that pressure was checked. It may have
`suspicion_delta == 0`, but the story context must still show whether the table
was watched.

### Surface Contract

Every skill cheat must surface risk and reward before the resolving input:

- The cheat action row or native surface button shows base heat and any active
  security/pit-boss summary.
- The surface shows a visible skill affordance: a timing meter, timed pulse,
  reaction target, or observation/memory icon row.
- Selected/armed state appears in `native_selected_surface_actions` or the
  game's equivalent selected-action path.
- Result UI shows the grade, payoff effect, and heat consequence.
- Mouse and touch use the same hit regions.

### Determinism Contract

Skill checks may use real elapsed milliseconds for player input grading, as the
blackjack count icons do, but generated prompts, target windows, and hidden
outcome candidates must be deterministic from `RngStream` forks or stable hashes
of run/table/challenge ids. Never call `randomize()`, `randf()`, or `randi()`.

## 2. Phase 1 Cheats

### T2.2 Video Poker: Holdout Timing Window

Current state: `mark_holds` immediately arms an ideal-card holdout and resolves
on draw. It reports `skill_outcome = "holdout_card"` and shared heat fields, but
there is no timing skill check.

Target: turn `mark_holds` into a visible palm timing challenge during the draw.
The player still chooses/marks holds, then must click or press during a palm
window as the draw animation opens the replacement-card gap.

Challenge state:

- `holdout_challenge.challenge_id`
- `opening_hand`, `holds`, `target_card`, `target_slot`
- `started_msec`, `perfect_msec`, `good_window_msec`, `close_window_msec`
- `input_msec`, `margin_msec`, `skill_grade`
- `pit_boss_watched_start`, `base_heat`

Grades:

| Grade | Effect | Heat |
| --- | --- | --- |
| `perfect` | Apply the best valid holdout card and allow full paytable evaluation. | Reduced heat; still records watched state. |
| `good` | Apply the holdout card with normal heat. | Base heat. |
| `partial` | Apply a lower-value improvement or only preserve suggested holds. | Base heat plus small penalty. |
| `miss` | No holdout card; draw resolves normally. | Heat for suspicious movement. |
| `blown` | No card; direct caught/tell result. | High heat and stronger watched penalty. |

Items and alcohol:

- Existing `timing_bracelet` may widen `video_poker_holdout_perfect_msec` and
  `video_poker_holdout_close_msec` through family-scoped item effects.
- `holdout_wax` is the explicit contraband hook for machine/card concealment
  on the holdout challenge.
- Positive heat must still pass through `alcohol_adjusted_suspicion_delta`.
  Drunken timing may shrink windows or increase meter speed via tunables.
- Grand Casino watched results must set the shared `pit_boss_watched` and
  `pit_boss_heat_bonus` fields so `record_grand_casino_game_result()` creates
  the correct evidence.

### T2.3 Bar Dice: Controlled-Roll Timing Meter

Current state: `loaded_toss` and `palmed_swap` directly alter dice before
settlement, then report heat and skill outcome. They do not ask the player to
perform a controlled throw.

Target: make `loaded_toss` the controlled-roll skill cheat. The player arms the
loaded toss, sees a throw meter sweep across desired die faces, and releases in
the target band. `palmed_swap` remains a cheat action but T2.6 must make its
reporting match the shared contract if T2.3 does not upgrade it.

Challenge state:

- `controlled_roll.challenge_id`
- `desired_face`, `desired_die_index`, `dice_before`
- `meter_started_msec`, `meter_period_msec`
- `perfect_window_msec`, `good_window_msec`, `input_msec`
- `skill_grade`, `face_result`, `patron_snitch_pressure`

Grades:

| Grade | Effect | Heat |
| --- | --- | --- |
| `perfect` | Force the desired Ship/Captain/Crew face or best cargo face. | Reduced heat. |
| `good` | Improve one die toward the desired face. | Base heat. |
| `partial` | Reroll with a positive bias, not a forced face. | Base heat. |
| `miss` | Honest roll result, but the move is noticeable. | Moderate heat. |
| `blown` | Bad throw tell; no benefit. | High heat plus patron/pit-boss pressure. |

Items and alcohol:

- Existing `weighted_keyring` supports dice cheats but is obvious contraband;
  it can improve face control while increasing or preserving watched risk.
- New or existing timing items may widen `bar_dice_controlled_roll_*_msec`
  windows.
- Patron snitch pressure already exists in the surface; use it as readable
  risk, then fold it into heat or `skill_story_context`.
- Alcohol should shrink the timing band and still scale heat through the
  existing RunState helper.

### T2.4 Roulette: Past-Post Reaction Window

Current state: roulette supports reading wheel bias and nudging the wheel before
the ball drops. It does not model a past-post move after "no more bets."

Target: add a past-post cheat that opens only after no-more-bets and before
payout. The player reacts to the visible final rotor/ball result and tries to
place or move one chip in a short post-result window. This is a reaction check,
not a pre-spin nudge.

Challenge state:

- `past_post_challenge.challenge_id`
- `spin_id`, `winning_number`, `allowed_targets`
- `no_more_bets_msec`, `window_start_msec`, `window_end_msec`
- `input_target`, `input_msec`, `reaction_msec`
- `skill_grade`, `chip_value`, `base_heat`

Grades:

| Grade | Effect | Heat |
| --- | --- | --- |
| `perfect` | Add or move one chip to the exact winning number or a bounded neighbor payout. | High base heat reduced by grade. |
| `good` | Add or move one chip to a nearby inside bet with reduced payout cap. | Base heat. |
| `partial` | Add an outside bet that can still pay if valid. | Base heat plus small penalty. |
| `miss` | No bet change; suspicious reach. | Moderate heat. |
| `blown` | Dealer catches the late chip. | High heat and likely watched-cheat evidence. |

Items and alcohol:

- Existing `foil_sleeve` and `chip_slide_wax` widen the reaction window or lower
  heat.
- Drunk state should slow or blur reaction affordances, then heat is adjusted by
  `alcohol_adjusted_suspicion_delta`.
- Grand Casino staff attention is especially strict: a watched `perfect` still
  sets cheat evidence because the action kind is `cheat`.

### T2.5 Baccarat: Edge-Sort Observation Memory

Current state: `read_baccarat_shoe` immediately reads shoe tempo for heat. It
does not ask the player to observe and remember edge cues across hands.

Target: add an edge-sort observation/memory cheat across shoe hands. The surface
shows subtle card-back orientation or shoe-cut cues when cards leave the shoe.
The player must remember cue sequences and use them before a later bet.

Challenge state:

- `edge_sort_challenge.challenge_id`
- `shoe_id`, `hand_index_start`, `observed_cues`
- `cue_icons`, `hidden_answer`, `memory_prompt`
- `answers`, `correct_count`, `miss_count`
- `edge_prediction`, `confidence`, `skill_grade`

Grades:

| Grade | Effect | Heat |
| --- | --- | --- |
| `perfect` | Strong next-hand prediction or side-bet hint within a cap. | Low-to-base heat. |
| `good` | Main-bet lean only. | Base heat. |
| `partial` | Ambiguous lean with lower confidence. | Base heat plus small penalty. |
| `miss` | No useful edge; suspicious stare. | Moderate heat. |
| `blown` | Dealer notices the card-back study. | High heat and watched evidence if applicable. |

Items and alcohol:

- Existing `marked_cards` and `edge_sort_loupe` improve cue readability but
  should count as contraband for Grand Casino showdown penalties.
- `card_counters_notes` and `scratch_pad` may help memory only when not already
  dirty in the Grand Casino, matching the Grand Casino showdown item logic.
- Alcohol should increase memory prompt difficulty and heat.

## 3. Items, Alcohol, And Grand Casino Staff Attention

Items use the current `ItemEffect` modifier pipeline. Unknown non-delta effect
keys are already preserved as passive modifiers, so implementation tasks may add
specific keys without changing the item framework.

Use these effect-key families:

| Key family | Use |
| --- | --- |
| `cheat_suspicion_delta` | Global heat modifier for cheat action contexts. |
| `<game>_<cheat>_perfect_msec` | Widens perfect timing windows. |
| `<game>_<cheat>_close_msec` | Widens good/close timing windows. |
| `<game>_<cheat>_heat_delta` | Cheat-specific heat modifier. |
| `<game>_<cheat>_attempts` | Adds bounded retries when the surface supports retries. |
| `<game>_<cheat>_memory_tolerance` | Allows one extra remembered cue error. |

T2.7 implemented these concrete item mappings:

| Cheat | Support items | Concrete modifier shape |
| --- | --- | --- |
| Video Poker holdout | `holdout_wax` | Widens perfect/good/close palm windows, reduces holdout heat, offsets drunk timing shrink. |
| Bar Dice controlled roll | `weighted_keyring`, `dice_calipers` | Widens perfect/good/close release windows, slows the meter, reduces controlled-roll heat. |
| Roulette past-post | `foil_sleeve`, `chip_slide_wax` | Widens perfect/good reaction windows, extends payout-lock window, reduces past-post heat, offsets drunk timing shrink. |
| Baccarat edge sort | `marked_cards`, `scratch_pad`, `card_counters_notes`, `edge_sort_loupe` | Reduces required cue count, adds memory tolerance, reduces edge-sort heat, offsets drunk memory penalty. |

Contraband may help the player, but it must not erase the narrative risk:

- Contraband can widen a window, improve a grade, reduce base heat, or grant one
  retry.
- Contraband held in the Grand Casino still worsens the showdown item modifier
  through existing `marked_cards`, `foil_sleeve`, and `weighted_keyring`
  penalties.
- Any active item explicitly used as a cheating tool on the Grand Casino floor
  should set the relevant `grand_casino_used_<item_id>` flag when the item is in
  the surveillance family (`xray_glasses`, `tab_detector`, `tarot_card`) or when
  T2.7 defines a new active cheat-support item.

Alcohol has two jobs:

- Skill feel: timing windows shrink or meters speed up; memory/observation
  challenges reveal fewer cues or increase answer count.
- Security consequence: positive heat always goes through
  `RunState.alcohol_adjusted_suspicion_delta()`.

Grand Casino attention must remain RunState-owned:

- Skill-cheat implementations set result fields only.
- `GameModule.apply_result()` calls `RunState.record_grand_casino_game_result()`.
- A `cheat` result in the Grand Casino sets `grand_casino_cheat_evidence`.
- If `pit_boss_watched` is true or `pit_boss_heat_bonus > 0`, the same result
  sets `grand_casino_watched_cheat_evidence` and
  `grand_casino_attention_watched_cheat`.

## 4. Tunable Stubs

All values in this section are tunable. Implementation tasks may encode them as
consts first, but should keep names stable so balance work can move them to data
without contract churn.

| Tunable | Initial target |
| --- | ---: |
| `video_poker_holdout_perfect_msec` | 80 |
| `video_poker_holdout_good_msec` | 210 |
| `video_poker_holdout_close_msec` | 340 |
| `video_poker_holdout_base_heat` | 14 |
| `video_poker_holdout_blown_heat_bonus` | 10 |
| `bar_dice_controlled_roll_perfect_msec` | 90 |
| `bar_dice_controlled_roll_good_msec` | 230 |
| `bar_dice_controlled_roll_meter_period_msec` | 1300 |
| `bar_dice_controlled_roll_base_heat` | 10 |
| `bar_dice_controlled_roll_blown_heat_bonus` | 12 |
| `roulette_past_post_perfect_msec` | 120 |
| `roulette_past_post_good_msec` | 260 |
| `roulette_past_post_window_msec` | 700 |
| `roulette_past_post_base_heat` | 18 |
| `roulette_past_post_blown_heat_bonus` | 16 |
| `baccarat_edge_sort_cue_count` | 4 |
| `baccarat_edge_sort_memory_tolerance` | 0 |
| `baccarat_edge_sort_base_heat` | 8 |
| `baccarat_edge_sort_blown_heat_bonus` | 10 |
| `skill_cheat_drunk_window_penalty_percent` | 20 |
| `skill_cheat_drunk_memory_extra_cues` | 1 |
| `skill_cheat_pit_boss_summary_max_chars` | 42 |

Clamp rules:

- Perfect windows should never exceed good windows.
- Item-modified timing windows should not exceed 2x base width.
- A perfect result may reduce base heat to zero outside the Grand Casino, but
  watched state is still recorded.
- A blown result must have positive heat unless a specific item consumes itself
  to absorb it, as Cooler's Cufflinks already does for blackjack peeks.

## 5. Test Matrix For T2.2-T2.7

Each implementation task must add or update focused tests in the narrowest
existing suite, then run the task's DONE gate.

| Area | Required checks |
| --- | --- |
| Determinism | Same seed and same scripted inputs produce the same challenge prompts, grades, bankroll delta, heat delta, and story context. |
| State machine | Arm, input, timeout, finalize, and resolve paths all leave no stale selected action or broken challenge state. |
| Save/load | Save during an armed challenge and after a finalized challenge; reload either resumes safely or finalizes/discards by documented rule. |
| Result contract | Result has `skill_cheat_contract`, `action_kind`, `skill_outcome`, `skill_grade`, `skill_story_context`, `skill_watched`, `pit_boss_watched`, and `pit_boss_heat_bonus` where applicable. |
| Security routing | `security_risk_bonus`, `pit_boss_watch_status`, alcohol heat scaling, and `security_action_pressure` all affect the final result as expected. |
| Grand Casino | Watched `cheat` sets watched-cheat evidence; unwatched `cheat` sets ordinary cheat evidence; `risky`/`advantage` do not set cheat evidence by themselves. |
| Items | At least one positive item modifier and one heat/risk modifier are visible in surface state and reflected in the final result. |
| Alcohol | Drunk state changes difficulty and scales positive heat. |
| UI | Mouse/touch hit regions, native selected actions, surface copy text, and result text fit existing validator limits. |
| RNG hygiene | Grep/tests prove no `randomize()`, `randf()`, or `randi()` usage is added. |

Per-task focus:

| Task | Extra required checks |
| --- | --- |
| T2.2 Video Poker | `mark_holds` no longer grants the card without a graded holdout challenge; double-up remains unavailable after cheated wins. |
| T2.3 Bar Dice | Controlled roll changes exactly the intended die behavior by grade; `palmed_swap` remains contract-compliant. |
| T2.4 Roulette | Past-post opens only after no-more-bets and before payout; late input cannot alter already-paid results. |
| T2.5 Baccarat | Edge-sort memory persists across shoe hands and resets on shoe replacement. |
| T2.6 Contract Audit | All seven games' cheat/advantage/risky actions use the shared fields and security path; legacy game-prefixed fields remain only as supplemental diagnostics. |

## 6. T2.6 Enforcement Notes

T2.6 should audit these current gaps after T2.2-T2.5 land:

- Video poker and bar dice already set some shared skill fields, but must gain
  actual graded checks and complete `skill_story_context`.
- Roulette and baccarat currently report heat/watch data for immediate read
  cheats; they need explicit `skill_outcome`, `skill_grade`, and contract tests.
- Pull tabs have several cheat-like paths (`tab_detector_scan`, detector-aided
  buys, suspicious redemption) and should report the shared fields whenever the
  action kind is `cheat`.
- Slot nudge already has a coin-chain timing grade; T2.6 should map
  `slot_nudge_skill_outcome` into `skill_outcome`/`skill_grade` at the shared
  contract layer while preserving slot-specific diagnostics.
- Blackjack count challenge remains the reference implementation, but it should
  also be audited for the same `skill_grade`/`skill_story_context` expectations
  so the contract is truly cross-game.

T2.6 implementation note:

- Pull Tabs intentionally remains a simple detector/tarot advantage surface, not
  a timing or memory challenge. `tab_detector_scan`, detector-aided purchases,
  and suspicious redemptions still receive the shared skill-cheat fields whenever
  they report `action_kind: cheat`; tarot remains an `active_item` helper unless
  a later task turns it into an explicit cheat action.
- Slot nudge remains owned by the slot resolver because its skill expression is
  reel/coin-chain timing rather than a separate challenge dialog. The resolver
  preserves `slot_nudge_skill_outcome` and also maps that grade into the generic
  `skill_outcome`, `skill_grade`, `skill_accuracy`, and `skill_story_context`
  fields before shared result normalization.
- Immediate read cheats (`read_baccarat_shoe`, `read_wheel_bias`) are allowed to
  use deterministic observation outcomes instead of multi-step grading, but they
  must still provide the full result shape, risk copy, watched state, and Grand
  Casino evidence hooks through the shared normalizer.
