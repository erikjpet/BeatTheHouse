# game06_4 machine-games consumer contract

Status: UNREVIEWED contract-only consumer candidate

Frozen vocabulary base: `a2760d81` (`game_ritual/1`)

Scope: Slot and Video Poker consumer bindings only. This document does not
change the shared ritual vocabulary, slot math, generators, paytables, video
poker paytables, detection math, or environment ownership.

## 1. Code-reality inventory

### Slot logical group

| Existing authority | Symbol/seam | Binding constraint |
| --- | --- | --- |
| `scripts/games/slot.gd` | `surface_state`, `surface_realtime_state_patch`, `surface_action_command` | Ritual projection is prepared at action boundaries. The realtime patch remains presentation-only and may not deep-copy machine state. |
| `scripts/games/slot.gd` | `resolve_with_context`, `wager_cost_for_context`, `minimum_wager_return_for_context` | These remain the sole wager and outcome authority. A ritual handler adapts their accepted result; it never recomputes reels or payout. |
| `scripts/games/slot.gd` | `checkpoint_surface_ui_state`, `_settle_completed_presentation` | Mid-spin and feature presentation checkpoints remain durable without replaying coin-out, bonus awards, or audio. |
| `scripts/games/slot.gd` | `surface_needs_auto_tick`, `surface_auto_action_command`, environment runtime methods | Autoplay, bonus progression, and watchdog activity remain boundary-driven. No ritual callback is added per frame. |
| `scripts/games/slots/slot_machine_state.gd` | selected bet, credits, coin-in/out, active bonus, animation identity | Canonical machine state is authoritative. Ritual state stores references and receipts, never a second reel grid or bonus journal. |
| `scripts/games/slots/slot_resolver.gd` and family resolvers | spin, nudge, bonus result | Seed/RTP authority is unchanged and consumes RNG exactly once through the existing resolver. |
| `scripts/games/slots/slot_presentation.gd`, `slot_renderer.gd` | cabinet/reel/feature presentation | These consume the prepared ritual projection. Draw paths may read but never duplicate authoritative state. |

### Video Poker logical group

| Existing authority | Symbol/seam | Binding constraint |
| --- | --- | --- |
| `scripts/games/video_poker.gd` | surface state/action and resolve paths | Deal/draw/hold/double-up authority remains here. Ritual handlers adapt accepted commands without changing card order or paytable evaluation. |
| `scripts/games/video_poker_renderer.gd` | `_draw_authored_cabinet`, `_draw_paytable`, `_draw_hands`, `_draw_controls` | The shipped authored cabinet remains the visual base. Ritual objects add semantic state; they do not replace cabinet geometry. |
| `scripts/games/video_poker_renderer.gd` | per-card `video_poker_hold` exact hits | Each card region binds to one semantic hold action. Keyboard/controller focus paths target the identical card index. |
| `scripts/games/video_poker_renderer.gd` | draw sequence and `drawn_indices` | Replacement staging follows the authoritative result order and never redraws held positions as changed. |
| paytable/result evaluation in `video_poker.gd` | hand label, multiplier, credits | Result facts copy the existing evaluated line and credit delta; projection never evaluates a hand. |

### Coin Pusher V3 reference classification

The cabinet body, dominant physical playfield, machine-local audio, visible money
path, persistent mechanical state, and room reaction are general machine
presence. Coin physics, pusher timing, token collision, prize shelves, and drop
zones are Coin Pusher-specific. Any frame-driven authority or physics vocabulary
is accidental to this consumer and must not enter the shared ritual.

## 2. Shared invariants for both consumers

- Cash and credits are different units. Conversion is explicit and receipted.
- Only existing rules/resolver code may debit, credit, pay, or consume RNG.
- A rejected pointer gesture creates no debit, result, fact, accepted receipt,
  phase change, or durable animation identity.
- Presentation may accelerate, but receipt order, authoritative duration
  boundaries, result order, and outcome are unchanged.
- Every energy tier changes an actor, cabinet object, or interactable gate.
- All authored pointer paths have keyboard, controller, and reduced-motion
  equivalents targeting the same semantic action.
- Persistent state stores authoritative references and receipts. Renderer
  snapshots, hover, pointer paths, interpolation, and pulse values never restore
  as authority.
- Unadopted machines retain their existing behavior and rendering.

## 3. Slot ritual

Ritual id: `slot.machine_session`

Phases:

1. `credits` — buy-in/cash-out, denomination and bet selection, spin permitted.
2. `commitment` — exact selected credit wager is confirmed and locked.
3. `activation` — handle/button press accepted; authoritative resolver runs once.
4. `outcome_staging` — authored reel stops expose the already-fixed result.
5. `feature` — existing bonus family progression, if any, remains resolver-owned.
6. `payout_or_handpay` — coin-out is readable; threshold lockup summons attendant.
7. `credits` — acknowledgement completes settlement without paying again.

Terminal interruption uses the existing environment/session exit boundary and
must preserve active bonus and committed credits.

### Slot commitment and actions

`pending_items` contains exactly one `wager.spin` credit item. `working_items`
contains the confirmed wager until its result receipt exists. `item_resolutions`
copies the existing coin-in, coin-out, free-spin use, and feature award fields.

| Action | Existing authority | Availability |
| --- | --- | --- |
| `credit.buy_in` | existing cash/credit conversion boundary | `credits`, funds available, machine not locked |
| `credit.cash_out` | existing cash/credit conversion boundary | `credits`, no committed wager or active feature |
| `commit.correct` | selected bet/denomination state | `credits` only |
| `commit.confirm` | selected bet and wager-cost functions | `credits`; moves exact credits at risk |
| `play.activate` | `resolve_with_context("spin", …)` | `commitment` only |
| `play.nudge` | existing nudge offer and detection path | only when the shipped offer says ready |
| `feature.advance` | existing bonus action resolver | `feature`, exact declared next action |
| `resolution.acknowledge` | no rules call | `payout_or_handpay` after durable result receipt |

Tactile verb `activate_primary` is `hold` for the cabinet button or `drag` for an
authored handle. Incomplete release returns focus and cannot resolve. Held repeat
may enqueue only after the prior result acknowledgement and cannot overlap a
feature or hand-pay lockup.

### Slot actors and objects

Actors: `attendant.primary`, up to two bounded `neighbour.*`, and an optional
`security.observer` projected from existing heat/suspicion only.

Objects: `cabinet.body`, `cabinet.glass`, `cabinet.belly_art`,
`cabinet.button_deck`, `cabinet.credit_meter`, `cabinet.denomination`,
`cabinet.tower_light`, `cabinet.money_path`, `cabinet.reels`, and the existing
family-specific feature apparatus. Every interactive object has an authored
design-space hit region, z layer, minimum touch target, and text-safety region.

Cabinet states are `attract`, `idle`, `play`, `feature`, and `lockup`. Tower-light
states are `off`, `service`, `feature`, `handpay`, and `security`. A hand-pay tier
must set the tower light, lock the activation target, and make the attendant
visible; music alone cannot satisfy it.

### Slot facts

- `machine.credits_changed`
- `machine.commitment_accepted`
- `machine.activation_started`
- `machine.result_completed`
- `machine.feature_entered`
- `machine.feature_completed`
- `machine.handpay_required`
- `machine.cheat_attempted`
- `machine.cheat_resolved`
- `machine.session_ended`

Facts copy public existing result fields only and never expose future stops,
resolver journals, RNG state, or hidden bonus outcomes.

## 4. Video Poker ritual

Ritual id: `video_poker.machine_session`

Phases:

1. `credits` — conversion, denomination and credit wager selection.
2. `commitment` — exact wager confirmed.
3. `initial_deal` — five authoritative cards staged in dealt order.
4. `hold_selection` — independent card holds may be toggled.
5. `draw` — one accepted draw replaces only unheld indices.
6. `result_read` — exact existing paytable row and credit result highlighted.
7. `double_up` — only when the shipped result offers it; existing authority.
8. `payout_or_handpay` — readable settlement/lockup.
9. `credits` — acknowledgement, with no repeated award.

### Video Poker actions

`commit.correct` changes credits/bet and denomination only before deal.
`commit.confirm` locks the exact wager. `play.deal` calls the existing deal
authority once. `card.hold` targets `card.0` through `card.4` during
`hold_selection`; it changes only the hold set. `play.draw` calls existing draw
authority once. `double_up.choose` remains bound to existing double-up inputs.
`resolution.acknowledge` returns to credits without evaluating or paying again.

The renderer's five current exact card hit regions become declared semantic
regions. Pointer, keyboard and controller paths all submit the same `card.hold`
with the same index. Reduced motion removes travel/flip delay but preserves the
initial/dealt/drawn distinction and paytable-line highlight.

### Video Poker actors and objects

Actors match Slot: attendant, bounded neighbours, optional security observer.
Objects are `cabinet.body`, `cabinet.glass`, `cabinet.belly_art`,
`cabinet.button_deck`, `cabinet.credit_meter`, `cabinet.denomination`,
`cabinet.tower_light`, `cabinet.money_path`, `cabinet.playfield`,
`cabinet.paytable`, and `card.0` through `card.4`.

The existing authored cabinet variants remain content. Ritual states select
bounded semantic appearance/functional states and never branch on a paytable in
shared code.

### Video Poker facts

- `machine.credits_changed`
- `machine.commitment_accepted`
- `video_poker.initial_deal_completed`
- `video_poker.holds_changed`
- `video_poker.draw_completed`
- `video_poker.result_completed`
- `machine.handpay_required`
- `machine.cheat_attempted`
- `machine.cheat_resolved`
- `machine.session_ended`

## 5. Persistence and replay

Both games serialize ritual id/version, legal phase, exact pending/working credit
items, authoritative machine/result references, actor/object semantic states,
energy tier, handler state, and command/result/fact/operation receipts. They do
not serialize prepared cabinet geometry, renderer caches, hover, pointer travel,
flip/reel interpolation, pulse, audio playback position, or future results.

Restore cases required before implementation acceptance:

- Slot: committed pre-spin, mid-spin staging, feature entry, every active bonus
  family boundary, lockup, hand-pay, and settled result before acknowledgement.
- Video Poker: committed pre-deal, initial-deal completion, each hold-set shape,
  pre-draw, post-draw result, double-up, lockup, hand-pay, and settlement.

Every restore rebuilds projection from validated authority and suppresses
already-receipted payout, award, dialogue, audio, and room-reaction effects.

## 6. Required proof matrix

1. Existing RTP/paytable and generator tests pass byte-for-byte for every slot
   family and video-poker cabinet.
2. Ten seeded native/Web traces match authoritative result, receipt order,
   feature sequence, replaced-card indices, and final credits.
3. Reject double-spin, double-pay, hold-after-draw, overlapping held repeat,
   incomplete gesture, inaccessible target, and action-out-of-phase without
   credit or state mutation.
4. Conservation covers buy-in, spin/deal, free play, feature award, double-up,
   cash-out, lockup, hand-pay, and mid-feature exit.
5. Per-frame probes show no new deep copy/allocation path in Slot realtime patch
   or Video Poker draw. Idle liveness must be nonzero and within budget.
6. Every energy tier proves an actor/object/interactable change and correct
   downshift when heat or win energy falls.
7. Visual captures cover all prompt states, accessibility modes, cabinet
   variants, denominations, and both hand-pay/lockup paths.

The executable declarations at `slot_machine_ritual_contract()` and
`video_poker_ritual_contract()` are built directly on accepted vocabulary head
`a2760d81`. They import no shared executable ritual runtime and preserve the
existing resolver, RNG, paytable, detection, and rendering authorities. The
focused `game06_4_machine_ritual_contract.gd` fixture binds closed top-level and
phase shapes, action registration, side-effect-free pointer rejection, input
equivalence, material energy tiers, sealed-host handler authority, persistence,
and byte-equal otherwise-identical observers without authentic capability.

Native, Web, full RTP, performance, accessibility, save/restore, and visual
evidence remain Integrator-owned gates. This WIP is not an acceptance verdict.

## 7. Row-local live adoption

The Slot surface now prepares a bounded ritual projection only during ordinary
surface rebuilds. Its realtime patch remains the existing scalar presentation
patch and does not copy the projection or machine. The projection consumes the
authoritative selected credit bet, bankroll, animation id, bonus state, payout,
celebration tier, and suspicion to drive visible cabinet, tower-light,
validator, attendant, neighbour, energy, and staged-result states. A cabinet
handle drag reaches the same shipped `slot_spin` command as the button; an
incomplete pull returns without an action or debit.

Video Poker prepares the corresponding projection from its existing machine,
UI hand, flip, result, paytable, credit, denomination, and pit-watch state. The
authored renderer consumes it for tower/validator/actor state and explicit
replacement/paytable-read staging. Existing per-card exact hold targets and the
DEAL/DRAW deck remain the tactile authority, so held and drawn indices remain
identical to the shipped resolver inputs/result. Neither renderer owns or
persists an outcome.

Both projections reconstruct from the existing saved machine and surface UI
state. They add no second ledger, future-result field, RNG use, wall-clock
authority, paytable branch, detection rule, or per-frame deep copy.
