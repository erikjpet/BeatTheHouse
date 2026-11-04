# BTH061-BLACKJACK-NET-FEEDBACK-001

Status: Open. Implementation, acceptance and exact NEXT receipt pending.

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
