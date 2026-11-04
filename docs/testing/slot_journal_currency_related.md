# BTH-CRAPS-JOURNAL-CURRENCY-001-SLOT

Related Slot producer subitem under the existing journal-currency investigation.
The denied Craps publication remains held; this work is isolated on the local
`source-slot` branch based on public
`3a9056120879fdabb91098e8612fb38e36a594db`. No denied Craps or Bar Dice commit
is included in its ancestry, and neither older checkout was changed. The
requested scope is local investigation, correction, testing and report. No push
or publication is attempted.

Original evidence:
`C:/Users/theep/Documents/Codex/2026-10-26/task/evidence/qa-JOURNAL-currency-slot753-related.json`.
Broad's ordinary Sunset Gas Heritage BET2 spin changed cash134 to132 once with
no payout. Cold Continue retained the outcome, cabinet and balance, but the new
Slot receipt said `Recorded change -2 (currency not recorded)`. No original
profile, key, private RNG, cabinet or outcome was read, copied, changed or
replayed for this follow-up.

## Cause and scoped correction

Three Slot resolver producers emit monetary story rows without a recorded
unit: normal spins, offscreen spins and bonus steps. The existing compactor
removes zero `bankroll_delta` values, so merely adding a currency name would
still leave some zero-net rows without a numeric amount. A separate existing
First Night adjustment replaces the final new spin's net after resolution;
the new metadata must follow that already-authored adjustment.

Slot uses **cash in every supported context, including Grand**. It is absent
from `RunState.GRAND_CASINO_CHIP_GAME_IDS`; adding chip routing would change
accounting. Exactly seven metadata additions preserve the current contract:

- Normal and offscreen receipts record `currency: cash` and their existing
  `bankroll_delta` as `currency_delta`.
- Bonus-step receipts record cash and the actual current-step award, including
  zero deferred steps.
- The existing First Night rewrite assigns the same `friendly_net` to the new
  receipt's `currency_delta` when it updates `bankroll_delta`.

The compactor already retains `currency_delta: 0`; it is unchanged. Wallets,
chip policy, payouts, stake costs, free-spin accounting, RNG, bonus rules,
tutorial rewards, item effects, scheduling, UI and save readers are unchanged.
Old unstamped rows retain their unknown unit. The tutorial edit only keeps the
new receipt field aligned with an existing net rewrite; item/scenario work
remains paused.

Offscreen metadata does not create more history. Existing same-room background
application logs its returned receipt; remote stored-Grand processing records
routine spin statistics and journals only its existing feature-trigger path.
This patch does not expand either policy. Collect is unsupported in this Slot
contract, and handpay acknowledgement does not pay the result again; neither
requires a new monetary receipt producer.

## Focused qualification

The unchanged producer baseline ran247 checks:56 expected metadata/label
failures and191 other passes. The Host baseline reproduced one natural
Heritage BET2 no-payout spin at134 to132 cash with chips25 untouched and one
receipt. Two metadata assertions failed as expected; a third selector-only
machine-equality expectation was a fixture mistake, since normal MIN selection
rewrites cabinet controls. That assertion was limited to unchanged economy,
RNG, clock and history. Full machine equality over reading, Save and cold
remains strict. This setup issue is excluded from product failure claims.

The corrected source passes **476 focused native assertions**:

| Check | Checks | Scope |
| --- | ---: | --- |
| New producer boundary test |247|20 controlled normal/offscreen cases across Gas/Grand, paid loss/win/zero and free spins; authored Buffalo bonus steps, tutorial rewrite, legacy and immutable-read controls |
| New ordinary Host producer test |60|Gas and Grand each perform one natural Heritage BET2 spin, normal manual MIN/SPIN handlers, official Save and fresh official load |
| Independent cold process |29|Both saves preserve full history, all six cabinets, active binding, wallets, RNG and clocks; repeated journal reads do not transact |
| Existing journal recorded-currency reader |80|Known, zero, mixed, malformed and historical unknown-unit contracts |
| Existing production-host autoplay accounting |60|Bounded natural Host callbacks, funding/confirmation/cancel accounting and no instrumented production code |
| Total |**476**|Focused qualification, not a full suite or visual Web acceptance |

Both Host samples naturally lose the2 cash stake once:134 becomes132 and
chips25 remain25, including Grand. The new line is `Bankroll -2`. The old
synthetic unstamped Slot row remains exact and continues to say
`Recorded change -7 (currency not recorded)`. The practice seed and funding
context are explicitly synthetic and do not inspect or replay the original
player's reels.

Producer boundary inputs deliberately specify net values to the actual typed
normal/offscreen result builders. They do not qualify reel RNG or apply a
player wallet. The actual authored Buffalo hold-and-spin family runs seven
steps: six zero-credit deferred steps and one final award7; a repeated completed
step creates no extra award or story. The existing tutorial adjustment renders
its final net6 consistently. These are bounded existing producer contracts,
not new bonus, item or scenario implementation.

The Host producer and independent cold stages use official SaveService. Exact
wire-value fingerprints preserve every guarded field and all cabinet/history
data, with no tolerances or original-state substitution. Native Host actions
are scripted surface-handler calls, not drawn GUI, OS-pointer or Web play.
All qualified jobs use the maintained5% CPU /2GiB kill-on-close runner, exit0
without timeout and leave zero owned processes. Existing native sandbox
certificate-store diagnostics are retained; no trust setting changed.

The initial adjacent autoplay invocation stopped before Host creation because
its required `BTH32_PRIVATE_ROOT` was not supplied. The rerun uses its unchanged
private-root contract and passes60/60. No product or test was changed to bypass
that containment guard; the earlier setup receipt remains separate.

## Commands and evidence

Use the maintained local bounded wrapper with an explicit fresh private case.
The Host producer and cold process must share their isolated root; actual
capture/browser-profile inputs are empty. Entry points:

```text
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/slot_journal_producer_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/slot_journal_host_cold_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/slot_journal_host_cold_check.gd -- --cold
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/grand_journal_recorded_currency_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/slot_autoplay_bankroll_actual_host_check.gd
```

Local evidence root:
`C:/Users/theep/Documents/Codex/2026-11-03/task-6/evidence/`.
Qualified prefixes are `slot-journal-producer-final`,
`slot-journal-host-final-producer`, `slot-journal-host-final-cold`,
`slot-journal-adjacent-reader` and `slot-journal-adjacent-autoplay-final`.
Each has a structured result and bounded Job/log receipt. Baseline and setup
receipts remain separate. Public import-cache preparation is recorded in
`slot-native-cache-bootstrap.json`; it reuses exact deployed3a assets/classes,
not original profiles, and is not a fresh cold-import qualification.

## Delivery status

The related subitem remains Open for review/acceptance after its isolated local
fix commit is associated. No main push or NEXT verification is requested or
attempted by this follow-up. The denied Craps and Bar Dice work remains
untouched, and no source history is guessed or repaired.
