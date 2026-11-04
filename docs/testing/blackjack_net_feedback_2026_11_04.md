# BTH061-BLACKJACK-NET-FEEDBACK-001

Status: Open. Implementation255bbfc53c69b3dd4dd4944fc98719e99c671376;
native and integrated cold accepted; exact NEXT receipt pending.

The Grand playtest records a five-chip Blackjack win: cash92 stays92,
chips13 to8 on Deal then18 after dealer bust23; the journal retains debit-5
and return+10. Floor Result and cold Continue incorrectly show Blackjack+0.
Original evidence: task-2/evidence/grand-r01-window-135/
POST-CLOSURE-LEGAL-BLACKJACK.md. No original campaign/save/profile was accessed
or replayed for this fix.

On source66cd97dd18c78350b0194f824186772b30039938, isolated synthetic fixed
shoes through normal host Deal/Stand reproduce incorrect floor round feedback:
win+10 (the return), loss+0 (no return), push+5 (returned stake), rather than
net+5/-5/0. New-host Continue repeats it. Cash, chips, RNG, table state and
history remain correct. Raw receipts are task-11/evidence/
blackjack-net-baseline-observations.json and blackjack-net-baseline.log.
The first harness run also has three invalid assertions against a nonexistent
slot-status key; normal Continue succeeds. Those assertions are corrected in
the focused test and are not product failures.

Leaving clears transient feedback. The floor and cold readers reconstruct the
result from history, retain settlement currency/credit but drop recorded
round_net_delta/outcome_bankroll_delta. Journal movement labels must remain
unchanged. Another candidate for the reported winning+0 is a later automatic
unwagered watch hand; that specific original sequence is not established by
the supplied screenshots/notes. A second synthetic run drives the production
round timer after that paid win, producing a genuine sat_out=true zero row.
New-host Continue then shows the exact reported Chip change+0 / Blackjack+0
while retaining chips18 and the original paid net+5 row. Receipt:
blackjack-net-watch-baseline-observations.json. The initial warm watch Back
sample remained on GAME because the presentation guard was still active;
that hidden floor sample is a harness timing failure, not floor acceptance.

The intended change is display-only: show the recorded Blackjack net first,
retain the distinct account movement, and preserve paid feedback across pure
zero-consequence watch rows. Explicit pushes remain zero. Do not infer net
from the wallet or replay a settlement. Preserve historical chip/cash units,
measured and unknown penalty semantics, fixed16:9 and touch/focus behavior.

## Native acceptance

The final179-check host run on255bbfc5 passes win/loss/push, normal Back,
official Save/new-host Continue, actual Result Label publication with net on
the first line, a genuine automatically dealt watch hand, and legacy net
metadata. Detached read-only controls cover surrender net-5/credit+5, cash,
explicit zero, malformed metadata, unknown units, retained watch consequences
and measured/unknown caught penalties. A separate existing penalty-consumer
check passes74 assertions. No financial authority, journal labels or save
projector changed. Both jobs exit0 with zero owned processes remaining.

Receipts: task-11/evidence/blackjack-net-qualified.json/.log and
blackjack-net-qualified-observations.json; blackjack-net-penalty-consumers
.json/.log. Godot reports the sandbox account's unavailable root certificate
store; no certificate/network operation is part of the native acceptance.
There are no script errors in the accepted run. The earlier fixed-final run's
exit0 is rejected because its malformed-null control logged script errors;
the safe conversion is covered by the final accepted run.

The unrelated Eye in the Sky decision correctly blocked the initial warm
watch Back. The final synthetic host disables action-triggered world cadence
from construction so ordinary economy/persistence remain active without an
unrelated event. No committed popup was dismissed or authority state edited.

Independent code review accepts the display-only patch and the intervening
main integration. The latter repairs canceled touch on visible fixed controls
under legacy portrait-named functions; it adds no portrait geometry or reflow.
Viewport policy and screen builders are unchanged. Initial merge review was
rejected automatically, then allowed after this specific read-only review.

Integrated sourcef3c3107e25d749e3d50981e3f4c6152a2fc12d57 passes52 engine-cold
checks in a separate process for win/loss/push, legacy net and paid-win then
automatic watch. All five official Continue paths restore correct net, units,
visible Label and exact protected money/RNG/clock/shoe/result/history signature.
Receipt: blackjack-net-integrated-cold.json/.log and
blackjack-net-integrated-cold-observations.json. Exit0, no script errors,
zero owned processes at release. Native synthetic hand acceptance and deployed
Web acceptance remain distinct.

## Publication blocker

The2026-11-04 push to erikjpet/BeatTheHouse main was rejected before execution
by automatic approval review: explicit publication approval was reported
missing, despite the standing authorization supplied in this delegation.
No push/deployment occurred. Local implementation255bbfc5, reviewed integration
f3c3107e and native evidence06021a2b are retained. Explicit approval was requested
asynchronously; it remains pending. The task stays Open.

Scratch next_blackjack_feedback.cjs prepares a fresh-context synthetic browser
storage fixture followed by ordinary Continue, with screenshots and strict
resource/error checks. A bounded diagnostic against oldb94f3938 reaches its
menu but times out during the subsequent input/capture at90seconds. The menu
shows Play rather than Continue, so fixture restoration and changed Web
behavior are unproven. The Job closes with zero owned processes. Do not count
that run as acceptance or as a deployed product regression. The requested fix
has not reached NEXT; exact identity, startup and changed Web feedback remain
pending publication.
