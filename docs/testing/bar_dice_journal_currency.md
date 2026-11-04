# BTH-BARDICE-JOURNAL-CURRENCY-001

The R07 observation `R07-BARDICE-JOURNAL-CURRENCY-RELATED-878` on deployed
`f3058b6daab820e9d747c4c4aabc2d983e9ae32e` records correct accounting:
100 start minus3 fare minus one5 cash hand equals92. Cold retains92 and one
Bar Dice result row, but that row says `Recorded change -5 (currency not recorded)`.
This is a related producer omission in the existing journal-currency family,
not a duplicate-charge or wallet-loss report. Original evidence:
`E:/CodexQA/BTH/Broad/r07-20261104/evidence/qa-r07-bardice-journal-currency-observation-878.json`,
SHA256 `4dba4102d0bf819e4d4279407f8f84be7e6fafab9d96b924fa8907ee0985b461`.
The supplied observation and screenshot were read only. No original profile,
save, key, hidden RNG, dice or paid outcome was read, copied, replayed or repaired.

## Cause and correction

Two Bar Dice producers omit units from new monetary story rows: the common
round settlement and Press. GameModule records the routed unit in its outer
result and persisted last result, but ordinary story rows remain unstamped.
The journal reader correctly refuses to infer historical units from the current
wallet or room. That reader and its historical policy are unchanged.

The correction is four metadata additions in `scripts/games/bar_dice.gd`:
each producer records `GameModule.presentation_currency_for_game` as `currency`
and its existing local `bankroll_delta` as `currency_delta`. Bar Dice uses cash
at Bar and chips at Grand. The round amount already includes existing effects
and security adjustments. Press records the current action's plus/minus risk,
not the accumulated prior hand result. Fields are unconditional, including a
true zero if an existing supported effect produces it; carry normally costs
the ante and is not a zero result.

No wallet, routing, stake, payout, RNG, security arithmetic, authority, reader,
save schema, animation, viewport, touch/focus, item or scenario code changes.
The prior surface-clock fix remains intact. Old unstamped rows stay unknown.

## Reproduction and focused checks

The isolated local branch is based on public
`9d20b10345db553816ad1a0d0502d3ef368e0998`. The native baseline performs one
generated cash stake5 hand through the existing sealed Foundation Host ritual
and authentic settlement application. It reproduces cash97 to92, chips25
unchanged, one settled round and one new row. Of34 assertions, exactly two
fail: recorded unit/current amount and the journal label. Other accounting,
replay and authority guards pass. This matches the reported public monetary
terms; it is not the original R07 save or a replay of that hand.

The corrected source passes **299 assertions**:

| Stage | Checks | Scope |
| --- | ---: | --- |
| Producer and official Save/fresh load |256|Eight cash/Grand-chip round-loss, round-win, Press-loss and Press-win cases; authentic settlement, full-state duplicate/forged/direct-apply guards, immutable legacy unknown row and exact new money labels |
| Independent cold process |43|All eight official saves retain complete table/authority/history, wallets, root RNG, clocks, debt and inventory; repeated readers do not transact or settle again |

Cash loss remains97 to92 with chips25. Grand loss keeps cash97 and changes
chips25 to20; the new labels are respectively `Bankroll -5` and `Chips -5`.
A clean win nets8. Press loss records-8 when the accumulated hand net becomes0;
Press win records+8 when accumulated net becomes16. Each accepted action adds
one row; exact replay changes no protected state. An old unstamped-7 row is
retained exactly and remains unknown through both codecs and cold reads.

The test selects small bounded fresh synthetic seeds with uncommitted model
commands, then creates new fixtures and executes the retained cases through
ordinary sealed Host intent APIs and authentic apply receipts. It does not
inject dice, outcomes or seals. Host-outcome assertions catch disagreement with
the model probe. This is a scripted production Host/API check, not renderer,
OS-pointer, normal-menu Continue, Web or deployed gameplay acceptance.

The eight cases do not freshly qualify carry, cheat/security outcomes, true
zero, automatic chip funding or HMAC tampering. Those paths share the unchanged
producer arithmetic, while source review verifies unconditional metadata after
the existing final net calculation. No paused item/scenario fixture was added
to force a zero. No broader unchanged suite was rerun.

Both final5%CPU/2GiB kill-on-close jobs exit0, without timeout/error and with
zero owned processes at release. Baseline exits1 for the two expected assertions
and also closes cleanly. Fresh launch nonces, start/finish timestamps, original
process handles assigned before execution and Job cleanup receipts identify
these runs. Only lifecycle metadata was added to the local maintained wrapper;
resource caps and worker/cleanup behavior are unchanged. Native certificate-store
diagnostics are retained in logs; no trust settings changed. Saves, authority
companions and full protected references remain private and uncommitted.

```text
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/bar_dice_journal_currency_check.gd -- --baseline
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/bar_dice_journal_currency_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/bar_dice_journal_currency_check.gd -- --cold
```

Use the maintained owned runner with a fresh explicit disposable private case;
the final producer/cold stages share their isolated roots. Evidence root:
`C:/Users/theep/Documents/Codex/2026-11-03/task-6/evidence/`.
Prefixes are `bardice-journal-baseline`, `bardice-journal-final-producer` and
`bardice-journal-final-cold`; each has structured result, Job and log receipts.
The source-safe summary `bar_dice_journal_currency_20261104.json` retains counts,
public case results and hashes. No original profile or raw authority/RNG data
is included. Independent source/test review found no blocking findings.

## Tracking and delivery

The stable ID is present in both structured and readable ledgers. The manual
reconciliation baseline has no finding for this task; it reports51 existing
errors elsewhere in ownership, scope and runtime evidence. Those unrelated
items and the eight explicit user pauses are preserved. Final reconciliation
results and the exact implementation association are recorded at closeout.
The local fix/test/commit request is concrete and native-qualified. The parent
item remains Open for acceptance; publication or NEXT verification is not
claimed by this follow-up, and no denied operation was retried.

Implementation commit: `1e38b7885db21c5bee1d19a897c129ddf680b1f6`. Both ledger views associate
that exact tested fix. The task remains Open for acceptance, with no factual
blocker in the completed local fix/test/commit scope. Final manual reconciliation
reports51 current-group and517 all-group errors outside this task, zero findings
for this ID, and all three owned native jobs closed with matching launch nonces.
No publication action, prior denied retry or NEXT acceptance is claimed.

## Authorized main/NEXT follow-through

A later trusted delegation carries the user approval to push finished work to
NEXT and specifically authorizes publishing fix `1e38b7885db21c5bee1d19a897c129ddf680b1f6`.
The earlier local-only status above is historical. Both ledgers now require
deployment acceptance and keep this task Open. Native299 evidence and the
independent exact-source/receipt/outgoing review remain qualified; no gameplay
change or new native rerun is needed for this tracking update.

At this observation the watcher reports: `Insufficient shared disk reserve for export: 13115047936 bytes free; 13958643712 required (service reserve + safety margin + export budget); retaining NEXT`.
This is a factual export-admission gate, not a publication denial or permission
hold. The existing reserve,10% watcher/2GiB Job limits, last good NEXT, profiles
and retained pipeline evidence remain unchanged. This follow-through has not
run pipeline cleanup, a duplicate watcher, a manual substitute build or a
guard/trust change.
Actual push results and subsequent exact deployed identity/startup are recorded
in task-6 evidence; no build/deployment success is inferred from a main push.

### Publication confirmed; acceptance remains Open

The normal push succeeded from public9d20b1034 to
`c0e94c361ca2000c229f815eb628d1bacf45d9c8`, tree
`b59c578b7fb927634659a3461d9383b6352b9aec`. It contains exact implementation
`1e38b7885db21c5bee1d19a897c129ddf680b1f6`, the tracking association and authorized
release update. No publication denial or retry occurred in this follow-through.
The four product metadata additions and test source remain exactly the
independently reviewed native299 inputs.

At publication NEXT still servesf3058b6daab820e9d747c4c4aabc2d983e9ae32e. The
watcher reports13,115,047,936bytes free versus13,958,643,712required, retaining
that prior NEXT. Both ledgers record published source separately from pending
deployment. Follow the actual promoted SHA/tree and verify assets/startup only
when normal admission allows; no deployed Bar Dice journal acceptance is
claimed. Subsequent documentation-only tracking commits do not change the
qualified runtime input and do not substitute for deployment proof.
