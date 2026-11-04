# BTH061-PULLTABS-SAVE-001: collected ticket custody after Menu Save

Status: **Open; original ticket rollback remains unattributed.** The initial
investigation below was committed in 436a707f. The closer independent Grand
follow-up confirms and corrects a Web Save acknowledgment gap, with native and
Web acceptance. See [Grand Save boundary evidence](pull_tab_grand_save_boundary.md)
for current results, commit/NEXT association and exact-save limitation. The
original report remains preserved; the task is not Complete.

## Reported Web discrepancy and evidence custody

Grand's ordinary campaign `grand-fresh-r01` reported this sequence on NEXT source
`3fd56aebde05182a02a6babf096ae8b7fe430f7f`:

1. Buy one naturally priced $2 Moonlight Bars ticket. Cash remains $94, chips
   decrease from 15 to 13, and Heat remains 0.
2. Collect the purchased ticket. The live machine shows Ticket Pile 1/1 and an
   empty purchase tray. Open the menu, use Save while inside the machine, then
   close the browser session.
3. Cold Continue and machine re-entry retain $94/13 and the purchase debit, but
   show Ticket Pile 0/0 with the same ticket in the purchase tray.
4. Recollect the existing ticket, leave the machine and save from the floor.
   Cold re-entry preserves Ticket Pile 1/1. The subsequent ordinary loss and
   floor Save also survive cold re-entry without another debit or payout.

The original report is
`task-2/evidence/grand-r01-window-125/PULL-TABS-ONE-TICKET-COLD-ROUTE-REPORT.md`.
Its unchanged private copy is `task-14/evidence/original-report.md`, SHA-256
`1fb7bb2eeef86247643b5db9402095d0662abf2d5a1443c95198b5e9086c241d`.
Both task directories are under the local Codex workspace dated 2026-10-27 and
2026-11-03 respectively. Original screenshots and action logs remain in place.
The original Grand campaign has advanced beyond the reported collection boundary.
No original precollection save was imported or read for this investigation, and
no original campaign browser profile, ticket or RNG was edited, replayed, reset
or committed. The current checks therefore cannot attribute the original
Grand/chip-wallet discrepancy to a specific saved generation.

The case-121 Save screenshot shows the menu dismissed, the unopened Moonlight
Bars ticket #008 in Ticket Pile 1/1, an empty tray and $94/13. The command sequence
was collection, 350 ms wait, screenshot, menu, screenshot, Save, screenshot and
browser close. Its complete dispatch group took about 1.63 seconds. This is
visible evidence of the reported Save boundary, but does not by itself establish
the underlying installed browser-storage generation or a root cause.

## Source findings

Investigated source:
`8bdfdbedb98e37eaf781952439df3877b80b6c46` in an isolated checkout.

`PullTabsGame._collect_tray_surface_command()` moves the existing ticket from
the purchase tray to the play stack, writes machine state and the canonical
portable pile through `_write_machine_state()`, and returns
`environment_changed=true`. The Foundation host queues an autosave for that
boundary. Forced Menu Save checkpoints the live surface, waits for an earlier
save and writes the current run again. Source review has not identified an
omitted collection write or a need to replay purchase/debit logic.

Two boundaries warrant browser diagnosis if the native route continues passing:
the host's room-publication save barrier, and browser persistence after an
accepted virtual-filesystem write followed quickly by shutdown. These are
hypotheses, not confirmed causes. `DurableStore` validation proves the installed
file generation at its storage boundary; the present source has no explicit
JavaScript filesystem-sync acknowledgment for browser shutdown. The native
results below do not establish a browser-storage failure.

## Native full-host verification

The focused `scripts/tests/pull_tab_machine_save_check.gd` uses ordinary
Foundation start, travel, machine action, Menu Save and Continue APIs on a fresh
generated run, with isolated persistence. It is a headless native host check,
not a rendered Web replay or reproduction of the original Grand campaign.

Seed `BTH061-STABILITY-B` travels normally to Roadside Bar. One ordinary purchase
of the $2 Lucky 7s row changes cash from $97 to $95. Its generated ticket has
serial `002-43186`, number `#015`, and identity
`002-43186:lucky_sevens:015`. It is an unopened generated loss; the test never
peels it or changes its ticket/RNG data. Collection produces one play-stack
ticket and an empty tray. The manual machine Save reports `Saved to Resume
Slot.` and dismisses the menu.

| Evidence label | Check | Result |
| --- | --- | --- |
| `native-exact-warm` | Machine Menu Save, saved-slot reload, warm host Continue, re-entry, repeated Collect, floor Menu Save and second slot reload | 18 checks, no failures, exit 0 |
| `native-exact-cold` | Separate-process slot reload and host Continue for both machine and floor saves; re-entry and repeated Collect | 14 checks, no failures, exit 0 |
| `pending-restore` | Existing synthetic pending-ticket restore shapes, authoritative portable state, source immutability and repeat restore | 52 checks, no failures, exit 0 |
| `winner-restore` | Existing deterministic generated model ticket purchase/collect/reveal/file/redemption, repeat redemption and restore | 12 checks, no failures, exit 0 |

The full-host snapshots compare ticket identity and pile contents, complete deal
stock, tickets sold, cash, chips, Heat and exact RNG state. The snapshot encodes
`rng_state` as `str(run.rng_state)` before JSON normalization so a 64-bit RNG
value cannot pass through floating-point rounding. Other JSON numeric fields
are normalized on both sides. Neither machine nor floor Save loses
collected custody in these native checks. Repeating Collect when the purchase
tray is empty causes no debit or other captured state change. The separate
winner regression preserves exactly-once redemption; it is a generated model
fixture, not a payout replay in the unopened host-test route.

All four bounded receipts record a private Windows Job assigned before execution,
2 GiB memory, explicit deadline, no timeout, exit 0 and **zero active owned
processes at release**. The exact-RNG warm/cold pair uses 3% aggregate CPU; the
existing pending/winner restore checks use 5%. Native logs retain a root-certificate-store
startup diagnostic. The offline checks complete successfully; that diagnostic
did not prevent the tested save/restore operations.

### Commands and retained local evidence

The recorded child commands use the pinned Godot executable
`D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe`
and run with the isolated source checkout as working directory:

```text
--headless --path . --script res://scripts/tests/pull_tab_machine_save_check.gd
--headless --path . --script res://scripts/tests/pull_tab_machine_save_check.gd -- --cold
--headless --path . --script res://scripts/tests/pull_tab_pending_restore_check.gd
--headless --path . --script res://scripts/tests/pull_tab_winner_restore_check.gd
```

`task-14/run_owned.py` supplies the Job, isolated distribution/profile/save paths,
deadline and cleanup receipt. The final exact-RNG matrix uses
`BTH_NATIVE_PRIVATE_CASE=pulltabs-exact`, `--cpu-rate 300`, a 180-second deadline
and the warm/cold evidence labels above. The existing restore checks use
`BTH_NATIVE_PRIVATE_CASE=pulltabs-regressions` and 60-second deadlines. Each
label has paired private `task-14/evidence/<label>.json` and `.log` files. A warm
run retains its expected-state receipt and two private save slots for the
separate cold run. These private state files remain outside the repository.
The wrapper refuses reused receipt labels; use fresh labels for any justified
rerun and preserve existing results.

Early exploratory outputs remain available and are classified separately:

- `native-repro-01` initially compared integer-valued fields against their JSON
  floating-point representation. Its printed saved ticket remained in the play
  pile; the equality assertion was a harness false red. `native-repro-02`
  normalized the comparison and passed the ordinary $2 machine-save route.
- `native-matrix-warm` passed the gameplay/save assertions but failed to write
  the harness's expected-state receipt to its initially chosen path. The receipt
  path was corrected before the accepted warm and final cold pair. This was not
  a product custody failure.
- `native-matrix-warm-02` and `native-matrix-cold-final` passed 18 and 14 checks
  at 5% CPU before the RNG snapshot was changed from a JSON number to an exact
  string. They remain historical passing custody checks; the `native-exact-*`
  pair supplies the final exact-RNG evidence.

These outputs are not substituted for the accepted passing matrix and are not
deleted or presented as independent product regressions.

## Ordinary Web machine/floor-save checks

A fresh disposable persistent Chromium profile `pulltabs-03` uses the exact
served source `8bdfdbedb98e37eaf781952439df3877b80b6c46` assets. The normal input
route is Play, Skip Lessons, confirm, ordinary Play, map travel to Gas Casino,
then Pull Tabs. The generated campaign seed is `RUN-20261103-882300-003`. Travel
costs $6 and adds one Heat, leaving $94 and Heat 1 before the purchase.

Session `create-03` buys exactly one naturally priced $2 Moonlight Bars ticket
from displayed row 3, reducing cash to $92. The warm screenshots identify
ticket #021, serial `003-82607`. Collection shows that unopened ticket in Ticket
Pile 1/1 and an empty purchase tray. No Peel, Peek or Auto input is used.

The player opens Menu and clicks Save while inside the machine. The post-Save
screenshot shows the menu dismissed and Ticket Pile 1/1, $92 and Heat 1.
The collect/menu/Save/screenshot/close command takes 1.163 seconds; context close
starts 85 ms after the Save-click API returns, with the screenshot between those
boundaries. This supports visible Save acceptance, not merely input dispatch.

Session `cold-machine-01` reopens the same profile at the same origin and uses
ordinary Continue and machine re-entry. Its screenshot shows the same unopened
ticket in Ticket Pile 1/1, empty purchase tray, $92 and Heat 1. The reported
machine-save rollback does not reproduce in this fresh Gas/cash route.

That session then leaves the machine, saves from the floor, takes a post-Save
screenshot and closes. Close starts 118 ms after that Save-click API returns.
Session `cold-floor-01` subsequently uses ordinary Continue and machine re-entry;
its screenshot again shows the same unopened #021 in Ticket Pile 1/1, empty
tray, $92 and Heat 1. No further purchase, reveal or payout occurs, and that
session also closes through an explicit controller close request.

The controller uses normal mouse/key input and screenshots, with no game-state
evaluator, profile export/import, save inspection/editing, ticket changes or RNG
manipulation. It preserves commands, dispatch times, screenshots and closure
evidence under `task-14/evidence/web-pulltabs/sessions/<session>/`.
Session `create-03` is paired with the **`web-normal-cap`** Job receipt, not the
earlier failed receipt named `web-create-03`. The cold sessions use
`web-cold-machine` and `web-cold-floor`. All three completed sessions have
`completed=true`, bounded Job exit 0, no timeout, zero active owned processes at
release, and no page or console errors. Their Jobs use 12% aggregate CPU and
2 GiB memory.

Earlier 5% CPU browser attempts did not reach startup readiness within their
bounded observation: the first reached its 300-second limit; a later attempt
was stopped by its verified owned node process and Job drain, with zero owned
processes remaining. Normal 12% startup succeeded. These observations do not
establish CPU cap as the sole cause of the earlier startup wait. The controller
first waited for removal of `#status` and was broadened to recognize hidden DOM
visibility; the served shell's completed-startup path removes the overlay, so
no selector defect has been established. These are startup/harness limits,
not Pull Tabs custody failures.

## Initial investigation acceptance

This section records the first investigation's scope. The linked Grand
follow-up above supersedes its pending work where expressly tested.

The investigation and regression are committed in
`436a707f8ed1ca6b5464e083326d9d1fb6bb7de7`. Publication and exact NEXT verification
have a separate release receipt; this associated evidence commit is not a bug-fix
claim. Keep the original report **Open / ORIGINAL_GRAND_NOT_REPRODUCED**:
the original campaign's precollection state and its Grand chip-wallet route
have not been reproduced from a preserved failing generation. The passing
fresh current-build route does not explain why that earlier build/campaign
returned the ticket to its tray. A waited machine-save comparison remains
unperformed; the tested rapid-close route already preserves custody.

If the original failure is reproduced, correct its narrow confirmed cause and
rerun the material machine/floor and exactly-once boundaries. No product fix,
new NEXT deployment, original-campaign repair or task completion is claimed by
this report.
