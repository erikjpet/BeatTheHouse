# BTH-15 / BTH-17 factual item help

## Scope

This is an independent presentation repair under the two open item requests.
It does not select or complete either replacement effect design.

- `BTH-15-FACTUAL-HELP-001`: describe Lucky Penny's existing purchase-time
  scratch cleanup aid without promising prize protection.
- `BTH-17-FACTUAL-HELP-001`: describe ordinary Ledger Pencil's actual consumers
  without the inventory's incorrect All games claim.

The earlier `QA-ITEM-022` / `LEDGER022` report documents the concrete Ledger
mismatch at build `197310ac6f57eec52eaf3012117b2bdb9828d0db`: carried Ledger
Pencil advertised All games / Loss Cushion +1, but a normal single Red Roulette
loss charged all 22 currency units, taking cash from 227 to 205. Its expected
contract explicitly allows truthful scope/help instead of a speculative economy
change. A later Blackjack comparison observed wager 9 settling net -8 with the
existing cushion, and explicitly did not approve a redesign.

Those receipts are retained locally as
`qa-item022-ledger-pencil-roulette-loss-cushion-review.json` and
`qa-item022-blackjack265-comparison.json`. No original private profile was opened,
altered, replayed or uploaded for this repair. The relationship between this QA
report and the original BTH-17 user redesign wording is not assumed.

## Resulting help

Ledger Pencil now says Selected games. Its detailed copy distinguishes
Bar Dice and Video Poker odds assistance, the existing game-specific caps,
and the loss cushion in Slots, Blackjack main hands, Bar Dice main outcomes and
Video Poker. Roulette and the other games without these consumers are explicitly
excluded from that claim. Coffee and Envelope combinations remain displayed.

Lucky Penny now explains 79% coating removal instead of 80% per scratch region
on tickets bought while carried. Its copy describes the purchase-time stamp:
assisted tickets keep the aid after storage, sale or pawn; previously purchased
tickets do not acquire it retroactively. It explains that ticket odds and prizes
are unchanged.

The ordinary items receive authored purchase summaries, compact/full effects,
instructions and affinity labels. RunActionService retains generated text for
definitions without authored copy. The separate `ledger_pencil_meta` and
Players Card retain their own help and effects. Affinity IDs and glyph IDs are
unchanged; the new affinity text is presentation only.

No effect dictionary, synergy, price, domain, acquisition rule, game resolver,
save schema, economic outcome, input handler or scheduling code changed.
All 89 item definitions compare exactly to the baseline after removing the ten
new presentation fields on these two ordinary items.

## Verification

Tested the same three production-file base blobs present on remote main
`1c201c9e341ac6f3e068c4d498fd00bf7298880e`:

- `data/items/items.json`: `b6f499f94591ad654b2b22b17619e13b1328f836`
- `scripts/core/attribute_badges.gd`: `030b260ed759436156cf954bc6bd186469d46db7`
- `scripts/core/run_action_service.gd`: `60ac05618dfa5a44c47a1191a46410a7312a5ffb`

Commands (using an owned 5% CPU / 2 GiB Job and disposable storage):

```text
Godot --headless --path . --script res://scripts/tests/item_factual_help_check.gd
ITEM_FACTUAL_HELP checks=53 failures=0

Godot --headless --path . --script res://scripts/tests/players_card_help_check.gd
PLAYERS_CARD_HELP checks=25 failures=0

git diff --check
PASS
```

The 53 focused native checks cover offer/inventory/card consistency, authored
and generated fallback text, exact effect dictionaries and modifier totals,
synergies, the separate collection Ledger, a rendered fixed 1280x720 detail
panel with scroll and focus/touch-close controls, and unchanged full run/RNG
state after read-only inspection. They perform no wagers.

The adjacent 25 checks cover Home/run Players Card help priority, exact
prestige modifiers and read-only state. Both workers exited 0 with owned Job
active processes 0 at release.

An initial setup attempt failed on missing local import metadata/extension
configuration and an uninitialized test catalog. Its log and timeout receipt
were preserved. Normal editor import and catalog initialization corrected the
harness; no product change was made to accommodate those setup failures.
Godot also logged its environment's root-certificate-store diagnostic; the
checks passed without bypassing TLS or certificate validation.

This is synthetic native UI evidence, not a new natural-game outcome or
deployed Web playtest. NEXT identity and any remaining browser acceptance are
recorded separately. No whole-game suite or unchanged economic flow was rerun.

## Remaining parent scope

BTH-15 remains Open for its full effect/description rework. All six original
audit turns were inspected: the user requested accurate descriptions, noticeable
item value and a Lucky Penny rework; no replacement mechanic was selected.

BTH-17 remains Open. The related Ledger scope mismatch is now concrete, but its
original user redesign wording remains unrecovered. The primary implementation
thread was searched through recent November 1 turns; that is not an exhaustive
October history search. The original ChatGPT coordinator returned no available
turns through the accessible history tool.

The material choices are whether to preserve the existing consumer boundaries
or expand/rework the game effects, and what replacement Lucky Penny effect is
wanted. The earlier information/planning proposal was an unapproved idea, not
a recovered Ledger requirement. There are zero intentional holds.

This help batch and its future acceptance remain subitems. Neither a passing
native check nor this batch's NEXT delivery closes either parent.

## Observed NEXT dependency

At 2026-11-04 00:47:45 UTC, the existing watcher rejected main
`de9459035149d41727e25893d9f7380938428214` with
`Asset/importer/settings inputs changed; cold-import qualification required`.
The last good served NEXT remained
`adb75dbe7f97e2b96279fbf401f7d7b8913072b3`.
This qualification gate is a separate pipeline dependency; this help repair
does not change assets/importers/settings or bypass the gate. Main commitment,
native tests and NEXT deployment remain separate states.
