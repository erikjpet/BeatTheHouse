# Roulette money reveal

The normal two-click red wager on source
`7508210fdb04d5267f4bb260801563131ed72ab0` settled a winning spin from
100000 to 100001 while the ball was still moving. The shared HUD already showed
100001 and its generic result said `Roulette lands 23 red`. The roulette module
had a display mask, but shared wallet rendering and applied-mutation feedback
bypassed it. This is a synthetic practice-state reproduction through the real
host and sealed action authority, not a capture of the reporting player's save.

Accepted actions still settle accounts, receipts and RNG synchronously once.
`hold_money_for_presentation` opts the host into a transient reveal hold;
`money_presentation_pending` in full/realtime surface projections owns release.
The shared hold projects cash/chips after the stake debit and defers net-change
feedback, generic result copy and outcome music. Unrelated account changes remain
additive. No settlement, RNG or save schema is deferred or changed.

Roulette retains its existing timing: wheel/ball through 5600 ms, croupier payout
through 7400 ms, and final result presentation at 9000 ms. The wallet/net badge
and generic outcome sound reveal at that final boundary. Existing table payout
visuals/sounds start only after landing. Patron result reactions wait for landing.
Reopening roulette treats the previously paid spin as presented, using a
module-local spin identity rather than changing its authority ledger or replaying
a timestamp from a prior process. Exit and Continue synchronize to actual money.

Focused commands (run on disposable isolated storage, with a private Windows Job
assigned before execution, 5% aggregate CPU and 2 GiB memory):

```text
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/roulette_money_reveal_check.gd
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/roulette_money_reveal_check.gd -- --cash
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/roulette_money_reveal_check.gd -- --continue-only
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/money_feedback_check.gd
```

The clock-controlled check uses normal bet/spin host actions, then samples
0/100/4499/5599/5600/7399/8999/9000/9100 ms. Seeded repeated spins cover wins and
losses; attempts to spin again during motion leave money/RNG unchanged. It checks
wallet, canvas refresh, text, net badge/audio counts, immediate authoritative
accounting, repeated presentation frames, real SaveService/host Continue, cold
Continue, exit and re-entry. `--cash` uses Bar practice; default uses Grand Casino
chips with cash funding. The fixture selects an authored practice room and does
not edit a live save or force a wheel outcome.

Private logs, runner receipts and baseline restoration hashes are retained in
`C:/Users/theep/Documents/Codex/2026-10-23/task/evidence/`. No player/profile files
are committed. Native tests and source review do not establish Web gameplay;
NEXT identity and visual verification are reported separately by the task.
