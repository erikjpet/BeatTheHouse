# BTH-15 / BTH-17 item rework scope recovery

Recovered 2026-11-04. Owner: Resume item improvements, thread
`01a1a3e7-10b6-71d9-919c-3afe91d860ce`.

Both parent tasks remain **Open**. There are **zero intentional holds**.
The status is active requirements/design recovery. A scope-recording commit
does not implement either replacement effect or satisfy product acceptance.

## Evidence and decisions

Erik's current instruction is: "there's no intentional holds, zero intentional
holds." It supersedes the inherited `HELD_USER_HANDS_ON` classification.

BTH-15 is Lucky Penny; BTH-17 is Ledger Pencil. The existing named registry and
OPS-07 closeout audit retain those mappings but supply no original design
specification for either item. The closeout audit's "Explicit user hands-on hold"
is a derived assertion.

Its origin was recovered from **Finish near-complete tasks**, thread
`01a19d8e-241f-74bf-8d62-cb2617a700f1`, turn
`01a19d8e-2bda-77d5-a839-e441d14ea0a2`. The quoted user direction was:
"Don't lose the scope of that, but um, know that that is something that I am
going to be more hands on in the implementation of that along with the item
updates". Hands-on involvement does not establish a hold, and the current
zero-holds correction removes any ambiguity.

The original Lucky Penny conversation was recovered from **Audit all item
descriptions**, thread `01a17f25-e94b-729f-a0c3-70db41ef90fa`, turn
`01a17f5c`. The user said to "flag that for rework" and expected many items to
need a complete rework. The contemporaneous handoff specifies a full effect and
description rework, with replacement design undecided. It explicitly did not
select or authorize a particular replacement mechanic. That is unfinished work,
not an intentional hold.

The exact original Ledger Pencil redesign decision has not yet been recovered.
Its stable item-update task is retained. Do not infer its approved mechanic from
the Lucky Penny conversation or from the currently implemented data.

## Current behavior retained as the baseline

Source inspection: `ecdccee418c2297a0fb864d00c902a4c159dfd5c`.
Both item definitions were independently checked unchanged on remote main
`0ae2d2ceaa6e5b04b77e6bb3ea687f1f0e9f5f47`.

- Lucky Penny has `scratch_penalty_shields: 1`. New paid ticket purchases
  stamp `lucky_penny_assist`; `_reserve_penalty_shields` lowers the scratch
  sweep threshold from 0.80 to 0.79 for one assist. The current code does not
  protect a prize or consume a penalty hit. Its name is not evidence of payout
  insurance.
- Ledger Pencil has `win_chance: 1` and `loss_reduction: 1`.
  Instant Coffee adds another odds point; Cashout Envelope adds another loss
  reduction point. Effects depend on each game's consumers. These data keys
  must not be described as universal prize or odds changes across every game.

The generated ordinary help currently says "Scratch Penalty Shields +1" and
"Better Odds +1. Loss Cushion +1" without disclosing these consumer limits.
Truthful help is part of acceptance, but a wording-only patch does not fulfill
the Lucky Penny effect rework.

| Current game consumer | Ledger Pencil behavior |
| --- | --- |
| Bar Dice | Losing-result assistance and Press odds; loss cushion on a negative main result. |
| Video Poker | Legal losing-draw rescue and cushion on a negative combined hand result. |
| Blackjack | Main-hand loss cushion only; no generic odds reader. |
| Slots | Zero-payout loss cushion; generic odds are explicitly ignored. |
| Generic GameModule | Chance roll and loss cushion on the generic action path. |
| Other current games | No readers for these two generic keys were found. |

The historical categorized item audit includes Craps in its loss-cushion claim.
Current inspected Craps source has no `loss_reduction` reader; retain the old
artifact as dated evidence instead of treating it as current qualification.

`ledger_pencil_meta` (collection itemdef1002) is a distinct identity with the
same displayed name, potency-adjusted cushion and resonance odds bonus.
Determine explicitly whether the rework covers that item too.

Relevant files: `data/items/items.json`, `scripts/core/item_effect.gd`,
`scripts/games/scratch_tickets.gd`, and the individual game resolvers.
No item data, game effects, RNG, saves, prices, UI or input behavior changed in
this recovery work.

## Concrete design choices still to resolve

These are proposals for a decision, not recovered user approvals.

| Parent | Option A | Option B | Remaining specification |
| --- | --- | --- | --- |
| BTH-15 | Make Lucky Penny an explicit scratch completion aid, with a noticeable and accurately described reveal benefit. | Make Lucky Penny actual prize-risk protection, defining which loss/penalty exists and when a shield is consumed. | Choose the mechanic, magnitude, trigger, eligible ticket types, per-ticket/per-run lifetime, stacking, acquisition price, and behavior for already purchased/saved tickets. |
| BTH-17 | Make Ledger Pencil a loss-management item with explicit eligible games and a capped loss cushion. | Make Ledger Pencil an information/planning tool, defining the exact public information or action it supplies. | Recover the original scope first; choose mechanic, eligible games, amount/use limit, Coffee/Envelope synergy behavior, price, and old-save policy. |

The next owner action is to recover the Ledger Pencil decision and resolve
these material design choices. Continue independent scope, source and acceptance
preparation while the choice is pending. Do not silently choose a new economy
or mark either parent complete.

## Required delivery and acceptance

For each parent, retain the original item ID and original requirements; record
the chosen design in the same task. Implement the selected effect and matching
description/help together. Keep partial implementation and acceptance as
subitems of the parent.

Focused regressions must cover the chosen trigger and boundaries, unaffected
games, stacking and synergies, owned/equipped state, and appropriate saved-ticket
or old-save compatibility. Where the effect changes money or RNG, verify those
exact changes, once-only consumption, and Save/cold Continue as relevant. Use
disposable state. Preserve fixed 16:9 layout, touch and focus behavior; there is
no portrait-specific app work in this scope.

Closure requires the associated implementation commit, focused passing tests,
verified main/NEXT artifact identity and the originally required behavior
acceptance. Source inspection, a tracking commit or deployment alone is not
completion.

## Validation of this tracking correction

The correction changes only the two task rows and the obsolete general hold
policy in the existing ledger, plus this scope record. Stable IDs, Open status
and all unrelated task rows are preserved. No gameplay runtime or additional
watcher was launched for this documentation-only change.
