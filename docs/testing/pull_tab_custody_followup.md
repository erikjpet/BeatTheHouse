# BTH061-PULLTABS-SAVE-001: reconstructed custody paths

Status: **Open**. The additional custody investigation found no separate
ticket-transfer defect in the cases below. All 177 focused native assertions
and both rendered Web comparison arms pass. The original evidence remains
preserved; its missing generation is not requested or replayed.

The earlier [Save acknowledgment correction](pull_tab_grand_save_boundary.md)
remains associated with c43c95a9 and its verified NEXT delivery. This follow-up
adds a tested custody matrix and corrects the historical sequence; it changes no
production ticket, economy, RNG, authority or save-format code.

## Primary chronology correction

The original condensed report made the first machine Save appear to be followed
directly by the cold ticket inspection. Preserved action logs show an
**intermediate cold floor Save** before that inspection:

| Original boundary | Rendered Day 3 clock | Custody evidence |
| --- | --- | --- |
| Case121 Buy | 4:45 AM | One paid ticket in tray; cash94/chips13/Heat0 |
| Case121 Collect, machine Save | 8:00 AM | Unopened #008 in pile1/1; tray empty |
| Case122 cold Continue | 4:45 AM | Floor only; clock has already rolled back before focus or floor Save |
| Case122 unsuccessful machine/barrier focus attempts, then floor Save | 8:45 AM at Save | No successful machine entry and no Buy/Collect/Open/Peel before this second Save |
| Case123 cold Continue | 4:45 AM | Floor only; second acknowledged Save's newer clock also failed to survive |
| Case123 first machine inspection | 6:15 AM after navigation/review time | Ticket in tray, pile0/0; same cash/chips/Heat |

Both original close requests occur 164 ms after the respective Save-click API
return, with a post-Save screenshot between those boundaries. Buy-to-Collect is
132.828 seconds; the explicit 900 ms wait was a separate earlier command and
does not represent the entire tray dwell. No Open input occurs in case121's
recorded collection/Save group. Case123's later Open follows recollection; its
requested three-peel command was rejected before input with actions empty.

The sequence is therefore:

`machine Save -> cold floor Continue -> focus attempts -> floor Save -> second cold Continue -> first custody inspection`.

The evidence establishes **two cold clock rollbacks**, including one after a
floor Save without machine entry. It does not expose ticket custody between
those two saves or identify which primary/backup generation loaded. The first
machine Save cannot be isolated as the only possible loss boundary.

Primary logs remain read-only under the original task-2 evidence root:

| Log | SHA-256 |
| --- | --- |
| grand-r01-window-121/state.json | d294a26f0d0a5753fadb29a7fba4b378338d7a40495a188afa615c47be8b0f52 |
| grand-r01-window-122/state.json | ec70a2c0fb809628d08b91c59f269de478a637bd3f65315f9d85a38825aa33f8 |
| grand-r01-window-123/state.json | bfbd026fd5d2c36d3a8e3bd3f4c16cd7808902de66451968feeabbf1934d6b2b |

The fuller timestamp review remains local in task-14/custody-evidence-review.md.
No original campaign save, profile, authority companion or browser was accessed.

## Native custody matrix

New `scripts/tests/pull_tab_custody_restore_matrix_check.gd` uses the existing
independent Grand fixture. Each of four cases generates one naturally priced
$2 ticket through normal Buy, with its own seed, Gold card and unclaimed Blue
Bag. No outcome is selected, inspected to choose a seed, revealed or paid out.
Starting cash94/chips15/Heat0 becomes cash94/chips13/Heat0 once per case.

| Case ID | Boundary | Result |
| --- | --- | --- |
| BTH061-PULLTABS-SAVE-001-N01 / tray_reload | Save/reload the paid tray, collect it, then force machine Menu Save while an older tray-generation save job remains registered | Passed; no harness drain or frame yield before manual Save. Native disk I/O may already have finished, so this is registered-job overlap rather than a claim of active I/O. |
| BTH061-PULLTABS-SAVE-001-N02 / floor_reload | Collected machine Save, warm floor Load, intermediate floor Menu Save, final Continue and machine re-entry | Passed |
| BTH061-PULLTABS-SAVE-001-N03 / stale_location | Retain authoritative collected registry while reinstalling naturally captured, valid precollection current/world/Grand-room copies | Passed, authority valid, no skipped case. Explicit synthetic stale-copy model; no seal edits. Unopened UI has no reveal-writing checkpoint branch. |
| BTH061-PULLTABS-SAVE-001-N04 / readonly_views | Repeated surface/runtime/object/coach projections using precollection UI | Passed; canonical protected state and a deep copy of the entire raw current environment remain unchanged. |

Every final saved slot is checked again in a separate cold process and actual
host Continue/re-entry. Checks compare exact ticket ID once across all piles,
empty tray, stock/deals/tickets sold, cash/chips, Heat, string RNG, inventory,
Gold float bits, Blue Bag, modifiers, scenario and exact saved clock. Repeated
Collect on an empty tray is idempotent. Own generated envelopes are decoded
read-only: canonical custody is serialized once and player fields are stripped
from location copies.

Results on source d7954274 plus this uncommitted test: **warm119/cold58**, no
failures or skips. Receipts `custody-matrix-native-warm` and
`custody-matrix-native-cold` confirm exit0, no timeout, zero owned processes,
3% aggregate CPU and2GiB. Main integration subsequently changes only the closed
venue-retirement branch of RunGenerator; the active Grand branch exercised here
is unchanged. That integration is not presented as a fresh test run.

Commands, with mandatory isolated user/profile/distribution roots as recorded by
task-14/run_owned.py:

```text
godot --headless --path . --script res://scripts/tests/pull_tab_custody_restore_matrix_check.gd
godot --headless --path . --script res://scripts/tests/pull_tab_custody_restore_matrix_check.gd -- --cold
```

## Rendered Web comparison

Both arms use official immutable f2992a978de1c1f55b3e0d4eda47b107d2d69d86 engine
and PCK bytes. PCK SHA-256:
`cb8e7ee528b16a552f6f504f9a32c62250e77f974caa89f6bb878c7b23c62c8c`.
A local loopback wrapper imports only this investigation's own previously
generated **pre-purchase** Grand Audit fixture and four fresh companions at
first boot. Cold sessions do not reimport. This is real Web/WASM/IndexedDB with
ordinary input and screenshots, not a claim of an earned campaign route or
unaltered live-NEXT-origin play. No ticket or post-purchase outcome is imported.

Each fresh profile buys one $2 row normally, Collects, waits350ms, and uses
machine Menu Save. A visual menu-dismissal condition takes the full success
screenshot and starts context close immediately. Both new-collection saves
close in the same millisecond that their acknowledgment screenshot returns.

| Case ID | Comparison arm | Observed result |
| --- | --- | --- |
| BTH061-PULLTABS-SAVE-001-R01 | Long tray dwell193.883s, newly collected machine Save/ack/immediate close; cold Continue without machine entry, elapsed floor Save/ack/immediate close; second cold Continue and machine entry | Machine Save9:15AM -> cold9:15AM; floor Save9:45AM -> second cold9:45AM. Same unopened #009/001-64422, pile1/1, empty tray, cash94/chips13/Heat0. |
| BTH061-PULLTABS-SAVE-001-R02 | Matched Buy-to-Collect dwell131.842s (0.986s shorter than original), newly collected machine Save/ack/immediate close; intermediate cold Continue/close with **no floor Save**; second cold Continue and machine entry | Save7:15AM -> both cold floors7:15AM. Same unopened #009/001-64422, pile1/1, empty tray, cash94/chips13/Heat0. |

R01 tests the missing intermediate Save boundary with a longer-than-original
dwell. R02 is its no-intermediate-Save discriminator and closely matches the
historical wall-clock dwell. Original failed focus attempts and full prior
campaign history are not recreated. Clocks advance normally; the Web HUD rounds
to15-minute marks, while native comparisons above use exact clock values.

Six sessions are retained under task-14/evidence/web-grand-custody/sessions:
`custody-r01-create-01`, `custody-r01-cold-floor-01`,
`custody-r01-cold-entry-01`, `custody-r02-create-01`,
`custody-r02-cold-no-save-01`, `custody-r02-cold-entry-01`.
Their `custody-r01-web-*` / `custody-r02-web-*` receipts confirm exit0, no timeout,
zero owned processes and closed loopback servers. Page/console error lists are
empty. Browser jobs use12% aggregate CPU/2GiB, with at most one browser and one
3% native job from this task concurrently. No Peel, Peek, Auto, second purchase
within an arm, duplicate debit, payout or RNG/ticket manipulation occurs.

## Source tracing and conclusion

Read-only review at d7954274 traces Collect through the generic surface command,
immediate machine plus canonical registry write, autosave queue and refresh.
It does not enter sealed-action, redemption or action-turn rollback handling.
Room publication handles geometry/manifest and can reject a Save; rejected
forced Save retains the menu rather than successfully dismissing it. Deferred
refreshes check identity and refresh presentation. Venue-cycle rollback captures
the live, already-collected run synchronously. No reviewed path reinstalls a
precollection whole-run snapshot after accepted Collect.

The corrected original sequence and the earlier reproduced clock regressions
are consistent with restoration of an older saved generation containing the
paid, uncollected ticket. This is an inference supporting the already-corrected
browser persistence boundary, not file-level proof of the original loaded
generation. These additional cases found **no confirmed independent custody
defect**, so no speculative production change is made.

**BTH061-PULLTABS-SAVE-001 remains Open.** Preserve the original ticket observation,
the corrected two-Save chronology and the attribution limit. Passing new cases
or committing their evidence does not close the parent task.

Investigation commit association and publication receipt follow integration.
