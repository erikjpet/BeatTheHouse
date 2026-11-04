# GRAND-VIDEO-POKER-NEW-UNIT-001

Owner: task-21, Fix Video Poker journal unit. Original observation is preserved
at `C:\Users\theep\Documents\Codex\2026-10-27\task-2\evidence\grand-r01-window-138\GRAND-VIDEO-POKER-NEW-UNIT-001.md`.
Its SHA-256 is `680558a221a2b728f72f3feb7f1c67c7c3e02559e3fe65cd5c3cb6c9fb769412`.

The original persistent Standard `grand-fresh-r01` campaign on NEXT
`66cd97dd18c78350b0194f824186772b30039938` lost one chip on an ordinary
Neon Jacks Draw. Chips moved18 to17, cash remained92, and the floor reported
`-1 chips`. A fresh-process Continue retained that single debit, but the new
journal row said `currency not recorded`. That observation establishes a
recording defect; it does not justify replaying or refunding the wager.
No original save, profile or authority key was read, copied or changed for this fix.

## Root cause and scope

Video Poker's Draw and Double Up story producers recorded only the legacy
`bankroll_delta` alias. Grand currency routing correctly changed the action's
account and embedded result, but it did not add the account to those story
rows. The journal deliberately refuses to infer historical game units from a
current wallet or venue.

Both producers now record `currency` using the same account predicate as
routing and `currency_delta` using their complete calculated net, including
zero. This metadata is emitted before the existing result is sealed. Accounting
instructions, paytables, RNG, money application, authority checks and save
readers are unchanged. Prior unstamped rows remain unchanged and ambiguous.

## Qualification

Baseline source66cd97dd plus the regression script reproduced the defect:
86checks,12 expected failures, all concerning missing metadata or its journal
label. The money application and Save checks passed. A preliminary run whose
test file changed during startup is retained locally but is excluded from this
identity-bound reproduction.

The corrected source passes396 focused checks:

| Check | Checks | Failures |
| --- | ---: | ---: |
| Chip producer: six sealed host Draws and six synthetic outcomes |130|0|
| Cash producer: six sealed host Draws and six synthetic outcomes |130|0|
| Separate-process official chip save loads |28|0|
| Separate-process official cash save loads |28|0|
| Existing journal recorded-currency/legacy reader check |80|0|

The guaranteed outcome matrix supplies explicit cards to the production
resolver/accounting helper: Draw+1/-1/0 and Double Up+5/-5/0 in each account.
It is synthetic. The twelve host Draws use normal Deal/Hold/Draw actions in
disposable practice rooms and the actual sealed host. Native execution is
headless and scripted; no visual native or browser play is claimed by it.

Every matrix outcome goes through official SaveService and a distinct-process
official load. Balances, clock, RNG and complete history match the first
official load. Reading the journal does not transact or consume RNG. Legacy
unstamped history retains its unknown unit. The chip-loss case retains cash92
and chips17 and renders `Chips -1`. No historical save migration or refund is
performed. Cheat Draw is not separately exercised; it uses the same producer.

Commands use the existing private Windows Job helpers via task21's
`run_owned.py`, pinned Godot4.6, isolated persistence roots,12% aggregate job
CPU cap,2GiB job memory cap and finite deadlines. Each check exited0 and
released its job with zero active processes. Logs retain the existing Windows
certificate-store diagnostic; it did not prevent these local checks.

The action-test command is
`godot --headless --audio-driver Dummy --path . --script res://scripts/tests/video_poker_journal_currency_check.gd`.
Add `-- --cash` for cash, `-- --cold` for the subsequent chip process, and
`-- --cash --cold` for the subsequent cash process. Preserve the same private
`BTH_VP_JOURNAL_TEST_ROOT`/save/profile roots between producer and cold process.
`--matrix-only` is used only for the bounded baseline reproduction.
The reader command substitutes `grand_journal_recorded_currency_check.gd`.

Exact commands, source/test hashes, results and cleanup are recorded in
[local checks](evidence/grand_video_poker_journal_currency/local_checks.json).
Main/NEXT delivery remains pending until the exact served receipt is obtained.
Original visual Web play is the observation above; deployed startup will be
reported separately from changed-behavior play acceptance.
