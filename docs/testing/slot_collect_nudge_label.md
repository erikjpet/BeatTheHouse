# BTH-SLOT-COLLECT-001: Slot Collect label dispatched a cheat

The Grand playtest on NEXT `ecdccee418c2297a0fb864d00c902a4c159dfd5c`
settled a $2 loss, then displayed **COLLECT** over the `slot_nudge` target.
One press committed Nudge, added 42 Heat and closed Players Card eligibility
for that run. The original campaign and settled outcomes are preserved.

The native presentation/command regression reproduced the same label-to-action
mismatch on main `adb75dbe7f97e2b96279fbf401f7d7b8913072b3`: the coin-chain
renderer selected the Collect text while the module returned `nudge`,
`action_kind: cheat`, and immediate resolution for the outstanding offer.
Slot has no legal Collect command; its normal payouts settle with the spin.

The cabinet now labels both coin-chain and legacy offers **NUDGE / CHEAT**.
Its status panel warns about Heat/catch risk and that nudging at Grand closes
Cards for this run. The same action and hit rectangle remain in place. No
resolver, wager, RNG, authority, save, Card consequence or historical outcome
was changed. Normal buttons keep their existing single-line presentation.

## Focused checks

`scripts/tests/slot_nudge_label_contract.gd` checks rendered labels and their
registered hit targets together, both offer styles, ordinary Spin/bet/Auto,
legal handpay acknowledgement, separate legal/cheat bindings, rejection of
`collect`/`slot_collect`, and command construction without cash/Heat mutation.
It fails against the baseline and passes with the renderer fix.

`scripts/tests/slot_nudge_native_input_check.gd` uses the maintained native
MainScene/input probe and a fresh production-generated Grand fixture. It
submits normal mouse or touch events to the cabinet, searches at most 40
natural $2 spins for a zero-payout loss with an offer, and checks Enter does
not silently submit a cheat. It creates no fabricated offer or trusted result.

Run the phases in separate processes with the same disposable storage for
each pointer type, through the maintained capped Windows Job runner:

```text
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/slot_nudge_label_contract.gd
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/slot_nudge_native_input_check.gd -- --produce --storage-key mouse
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/slot_nudge_native_input_check.gd -- --cold --storage-key mouse
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/slot_nudge_native_input_check.gd -- --verify-settled --storage-key mouse
```

Repeat the three staged commands with `touch` and a different fresh storage
root. `BTH_SLOT_NUDGE_TEST_ROOT` must contain Godot's isolated user-data
directory before the script will instantiate MainScene. Use isolated save,
profile, settings and collection paths; never point this probe at player data.
Existing test slots and receipts are retained rather than replaced.

The fresh mouse and touch routes each reached the offer on natural spin 14:
cash $972, 13 chips, coin-in $28, coin-out $0, Heat 0 and Cards eligible.
After normal Save and process-cold Continue, one explicitly labeled Nudge
committed once with no additional stake or cash/chip change, Heat +12 and
Card closure. This fresh fixture is not the original watched +42-Heat run.
The settled cold stage checks economy, RNG, counters and Card closure without
replaying the action or settlement.

The existing `slot_nudge_risk_preview_check.gd` separately checks the unchanged
Heat calculation, including the watched +42 case and item/security modifiers.
This is a synthetic projection/resolver contract, not a replay of player data.

These native runs exercise Godot canvas input and the authentic Foundation
sealed host in headless mode. Their recorded labels are not pixel screenshots
or physical-device/Web gameplay qualification. NEXT artifact identity and Web
startup are recorded separately by release verification. Isolated Windows
runs retain the certificate-store warning in their logs; no TLS bypass is used.
