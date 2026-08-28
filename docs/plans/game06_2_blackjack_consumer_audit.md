# game06_2 Blackjack consumer audit

Status: UNREVIEWED pre-implementation audit  
Base: `a2760d816c781e711ff0923c296f97b786662453`  
Scope: row-local successor only; `scripts/games/blackjack.gd` and row-local tests/docs

This map freezes the shipped consumers that the Blackjack depth pass must keep
compatible. It was written before any edit to the Blackjack module or its
settlement path. The accepted `game_ritual/1` vocabulary is an additive,
game-owned projection contract: the row must not import a rejected `game06_1`
runtime, change shared consumers, or move outcome, wager, heat, tutorial, crew,
or save authority out of the existing owners.

## Authoritative money and result consumers

| Consumer | Existing fields/actions consumed | Compatibility obligation |
| --- | --- | --- |
| `scripts/core/run_state.gd::_grand_casino_result_wager_funding_amount` | `game_id`, `action_id`, bankroll delta; Blackjack funds only `blackjack_place_bet` | Placement remains the one funding boundary. A later settlement result must not be mistaken for another stake withdrawal or receive replacement funding. |
| `scripts/core/run_state.gd::record_grand_casino_game_result` | `ok`, `game_id`, `action_kind`, pit-boss heat inputs, wager presence | Accepted Blackjack results retain the same result meanings. Rejected/staging-only ritual input must not count as a wager, game, cheat, heat event, or settlement. |
| `scripts/core/run_state.gd::_grand_casino_result_has_wager` | Blackjack settlement evidence including nonempty `blackjack_hand_results` | Exactly one terminal hand result continues to be the settled-wager signal; phase/presentation records are not settlement evidence. |
| `scripts/core/run_state.gd` cheat/backoff paths | `player_cheat_used`, `blackjack_cheat_caught`, `dealer_caught_cheat`, `blackjack_tutorial_peek_reprieve`, `blackjack_table_barred`, dealer identity and suspicion/heat deltas | Preserve names and meanings. Dealer/pit visual states reflect these authoritative values and never create or suppress them. |
| `scripts/tests/foundation/check_core_content.gd` grand-casino result checks | `blackjack_place_bet` does not increment settled game count; terminal `play_basic` does; win/loss advances Players Card progress | New phase/action ids may be projected, but the established placement and terminal result boundaries remain externally observable and unchanged. |

Per-hand settlement remains itemized through `blackjack_hand_results`. Each
record's stake/result/payout semantics, plus aggregate `blackjack_main_delta`,
must continue to conserve bankroll exactly across ordinary, blackjack, bust,
push, split, double, and surrender outcomes. Any new readable labels such as
available, pending, at-risk, returned, payout, net, or reason are derived from
those game-owned records; they are not a second money ledger.

## Tutorial and interaction consumers

`data/tutorial/lessons.json`, `scripts/tests/foundation/check_core_content.gd`,
and `scripts/tests/tutorial_dialogue_trigger_cadence_check.gd` bind this chain:

| Boundary | Required stable action/state |
| --- | --- |
| first deal and finish | `blackjack_deal`; `hands_played`, `hand_active`, `between_hands`; `blackjack_hit`, `blackjack_stand` |
| raise and raised deal | `surface_stake_up` or `blackjack_chip`, followed by `blackjack_deal` |
| lookaway and peek | `blackjack_distraction` (including the `drink_pass` anchored variant), `lookaway_started`, `blackjack_peek`, `peek_used` |
| count start and card marking | `blackjack_count_toggle`, `counting_enabled`, `count_started`, `blackjack_deal`, `blackjack_count_icon`, `count_all_selected` |
| count completion and exit | `tutorial_count_completed`, `count_perfect`, `hands_played`, `between_hands`, plus `surface_back` |

These ids and predicates remain stable. Tactile place/cut/wave/tap gestures,
keyboard/controller equivalents, reduced-motion staging, and explicit ritual
phases must feed the same semantic actions. An incomplete, blocked, inaccessible,
or wrong-phase gesture returns without bankroll change, RNG consumption, phase
advance, fact publication, game-count change, or tutorial completion.

## Crew, cheat, and patron consumers

| Consumer | Binding seam | Compatibility obligation |
| --- | --- | --- |
| `data/crew/plays.json` | Blackjack Spotter / Big Player pairing, costs, detection, windows, count tolerance/confidence | Keep the shipped pairing and tuning authoritative; ritual actors may display readiness/attention but cannot grant crew authority. |
| `scripts/core/crew_play_model.gd` | active status, Spotter detection/backoff, Big Player warm state | Read-only projection only. No row-local actor or energy state writes crew lifecycle. |
| `scripts/tests/foundation/crew_heist_contract.gd::_settled_blackjack_result` | nonempty `blackjack_hand_results`; cheat evidence via `player_cheat_used`, `blackjack_cheat_caught`, `dealer_caught_cheat`, normalized `action_kind`, `skill_outcome`, `skill_grade` | Preserve terminal evidence and nonterminal peek setup fields. A neighbour reaction never authorizes or resolves a cheat. |
| `tools/blackjack_seed_audit.gd` | `blackjack_patron_action_events` and seeded patron/dealer behavior | Neighbours are visible bounded actors, but seeded game rules remain the only source of their authoritative actions. |

## Surface, persistence, and audit consumers

| Consumer/probe | Existing contract to re-prove |
| --- | --- |
| `scripts/tests/foundation/check_table_games.gd` | Rules, surface actions, split/double/surrender, cheats, table state, and save behavior remain compatible. |
| `tools/blackjack_seed_audit.gd` | Ten-seed gameplay, audio action coverage, count challenge, normal/split/double/surrender money conservation, RTP/fairness, cheats, patrons, terminal hand/dealer projection. |
| `tools/blackjack_heat_backoff_probe.gd` | Heat thresholds, bar/backoff persistence, dealer consequence, and crew-payback event remain authoritative and restorable. |
| `tools/blackjack_terminal_presentation_probe.gd` | A placed wager resolves into a stable terminal presentation without a second charge or settlement. |
| surface save/exit seams | Every accepted action boundary may save. Restore selects a legal Blackjack phase and rebuilds derived actors/objects/hits without rerolling, repaying, republishing facts, or replaying one-shot audio/dialogue. Pointer paths and animation progress remain transient. |

The module's existing `surface_action_command`, `surface_pointer_command`,
`surface_state`, `surface_spec`, `draw_surface`, checkpoint, and result APIs are
the compatibility shell. The row may prepare a closed Blackjack-owned ritual
definition/projection inside that shell, but cannot require shared runtime or
canvas changes.

## Accepted ritual mapping for this row

The row maps to the accepted Family 1 contract as:

- phases: `wagering -> initial_deal -> player_turn -> dealer_procedure -> settlement -> wagering`;
- actors: dealer, bounded neighbours, and pit/security attention, all visibly
  projected with game-owned bounded states and no outcome authority;
- objects: shoe, wager/chips, player hands, dealer hand/hole-card region, and
  discard rack, with visible/functional state changes;
- commitments: place/correct/remove-one/undo/clear/repeat/re-bet/confirm only
  where the shipped Blackjack rules support them, with available/pending/at-risk/
  returned/payout/net totals derived from the one money authority;
- gestures: semantic place/cut/wave/tap/reveal or hold inputs with keyboard,
  controller, and reduced-motion equivalents that reach identical authoritative
  actions;
- energy: every tier materially changes an actor, object, or interactable, while
  heat/pit state remains a visible consequence of existing authoritative heat;
- persistence: authoritative table/hand/wager/phase/result refs and receipts are
  serialized by existing game/environment ownership; prepared geometry, input
  paths, and animation are derived or transient.

## Reproof matrix before review

The successor head is not review-ready until row-local evidence proves:

1. every phase and legal transition, plus rejection of out-of-phase and invalid
   gesture input without charge, RNG, or advance;
2. exact per-hand accounting/reasons and no double deal, double charge, or
   double settlement, including split/double/surrender;
3. all tutorial action/state seams above;
4. crew/cheat/backoff/patron fields and authority boundaries above;
5. save/restore at each action boundary without one-shot replay;
6. ten seeded traces with isolated neighbours and unchanged authoritative
   outcomes;
7. each energy tier visibly changes a non-text/non-music scene participant,
   with reduced-motion and non-color-only equivalents;
8. existing Blackjack probes and relevant foundation suites, plus visual,
   accessibility, performance/liveness, native/Web, and RTP gates required by
   the row prompt.

