# BTH-CRAPS-JOURNAL-CURRENCY-001

Broad observed this on NEXT
`3a9056120879fdabb91098e8612fb38e36a594db`: one ordinary Grand Field10 wager
naturally rolled1+6, losing ten chips. Cash remained155 and chips25 became15
once. Cold Continue retained that accounting, but the new journal receipt said
`Recorded change -10 (currency not recorded)`. A subsequent Video Poker chip
receipt on the same build displayed its recorded unit correctly.

Original report:
`C:/Users/theep/Documents/Codex/2026-10-26/task/evidence/qa-BTH-CRAPS-JOURNAL-CURRENCY-001.json`.
No original profile, save, key, dice state or outcome was read, changed or
replayed for this fix. The existing correct ten-chip loss is not refunded or
rewritten. Work uses the isolated `source-craps` checkout based on that exact
deployed source; the separately denied Bar Dice publication is excluded from
its ancestry and outgoing diff.

## Root cause and change

New Craps roll receipts recorded the legacy `bankroll_delta` alias without its
unit. Pass-dice and Street dispersal had the same omission. Paid take-down
receipts recorded a chip leg but omitted their cash leg, so a cash refund could
display only `Chips +0`. The journal deliberately refuses to infer historical
game units from a current venue or wallet; its reader is correct.

Seven added story fields fix these four producers only:

- Roll records the action-time wager currency and its existing complete net.
  Non-Street currency uses `GameModule.presentation_currency_for_game()`, the
  same Grand routing predicate, including recognized generated-ID fallback.
  Street retains its explicit cash contract.
- Pass dice records the same unit and intentional zero net.
- Take-down records the actual cash refund leg alongside its existing chip
  leg, preserving mixed funding as separate units.
- Street dispersal records its cash refund.

Roll net includes the pending wager debit, gross credits and existing modifiers.
It excludes any separate automatic chip-purchase cash movement. Already-paid
working stakes are not debited again: their later loss can correctly have zero
current-wallet net, and a paid10 winning line can return20. Refund legs are not
summed into one currency or counted again through the legacy alias. No wallet,
funding, rules, RNG, authority, shared routing, reader or save-codec instruction
changes. Old unstamped rows remain unknown. No item/scenario or portrait,
viewport, touch/focus or animation work is included.

## Qualification

Both before fixtures ran on unchanged3a product source. The roll baseline had
336 checks with exactly32 expected metadata/label failures; all304 other
accounting, RNG-total, working-stake and persistence checks passed. The separate
refund/pass/Street baseline had63 checks with exactly16 expected metadata
failures; all47 wallet/provenance/read-only checks passed. No setup failure is
counted as reproduction or qualification.

The corrected source passes **645 focused assertions**:

| Test | Checks | Scope |
| --- | ---: | --- |
| New roll producer and normal Host sample |380|Cash and chips: Field loss/win, world zero net, paid line/continuation/return/seven-out;14 matrix and2 Host saves with fresh official loads |
| Independent-process official cold reads |106|All16 saved cases: both wallets, root RNG, clock, complete history/table/working stakes and stable journal lines |
| New refund/pass/Street producer check |63|Cash12, chips12, mixed cash7/chips5 refunds; four zero pass contexts; actual Street refund10; immutable reads and old unknown row |
| Existing journal recorded-currency reader |80|Known, zero, mixed, malformed and legacy unknown-unit contracts |
| Existing consumed-draft check |16|No implicit rebet or duplicate wager consumption |
| Total |**645**|Focused native checks, not a full suite or visual Web play |

The deterministic outcome matrix selects disposable RNG seeds using the existing
rules helper, then calls the actual resolver and money application. It does not
replace result/story dictionaries or replay player dice. Its Grand Field-loss
case preserves155 cash and changes25 chips to15, producing `Chips -10`.
The zero cases explicitly render `Chips +0` or `Bankroll +0`. Paid working
stakes retain their actual current-action net rather than profit-only or
repeated-stake amounts. Both ordinary Host samples stage Field10 through normal
chip/bet/throw surface handlers and naturally win10: cash155 becomes165 with
chips25 unchanged, or Grand chips25 becomes35 with cash155 unchanged. Those
Host actions are scripted native API inputs, not rendered/OS-pointer or Web
acceptance claims.

All16 cases use official SaveService and a new-process official load, with
references taken after the first official JSON numeric transport. Entire
history/table and guarded values match without tolerances or dropped fields.
Repeated journal formatting changes no state. A seeded old unstamped Craps row
remains byte/value unchanged within each boundary and still displays
`Recorded change -7 (currency not recorded)` after Save/cold. No historical unit
repair, migration, reward, refund or extra original roll is performed.

The supplemental producer test establishes real paid funding provenance before
take-down, including mixed cash/chips. Street uses its existing supported sweep
hook to exercise the actual pre-roll refund producer without a new outcome.
This is synthetic boundary setup, not scenario implementation or player-state
modification.

All qualified workers use the maintained5% CPU /2GiB kill-on-close Job runner,
exit0 without timeout and leave zero owned processes. The existing native
sandbox certificate-store diagnostic is retained; no network/trust change was
used. The local class/import cache was copied read-only from the exact deployed
3a source, with each imported raw asset verified against the new checkout. This
cache preparation is not a fresh cold-import or runtime qualification claim.

## Reproduction and evidence

Native entry points (the maintained local wrapper supplies private save,
profile, metadata and distribution roots):

```text
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/craps_journal_currency_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/craps_journal_currency_check.gd -- --cold
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/craps_refund_journal_currency_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/grand_journal_recorded_currency_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/craps_consumed_draft_check.gd
```

The producer/cold pair retains the same private root. No original capture or
browser-profile input is accepted. Local evidence root:
`C:/Users/theep/Documents/Codex/2026-11-03/task-6/evidence/`.
Baseline prefixes: `craps-journal-roll-baseline` and
`craps-refund-journal-baseline`. Qualified prefixes:
`craps-journal-final-producer`, `craps-journal-final-cold`,
`craps-refund-journal-final`, `craps-adjacent-reader` and
`craps-adjacent-draft`. Each retains its command/output log and bounded Job
receipt; new tests and reader also retain structured result JSON. Saves and
authority companions remain private and are not committed or uploaded.

## Release status

The task remains Open until its scoped tested commit is associated and exact
NEXT identity/basic startup is verified. Item and scenario work remain paused;
stable/itch and hosting audience are unchanged. Previously denied Bar Dice
commits remain separate from this checkout and requested change.
