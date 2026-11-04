# BTH061-BLACKJACK-NET-FEEDBACK-001

Status: Complete against the original criteria. Implementation
255bbfc53c69b3dd4dd4944fc98719e99c671376 is committed, published and native/cold
qualified. Exact NEXT `ee02497f` is verified with independent changed-feedback
acceptance. Supplemental Web push coverage remains explicitly unverified below.

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

## Authorized publication follow-through

The owner subsequently approved pushing all finished work to NEXT. That new
approval resolves the publication permission blocker above; no bypass is used.
Current main9894795b is integrated ated9242d6b572db568a971e8e65276f6a667ba680.
The ledger conflict retained every concurrent row and this stable task ID.
Independent runtime review finds no net/accounting conflict or fixed16:9 change.

Oned9242d6 the full179 host checks and52 separate-process cold checks pass
again. The concurrent Blackjack deal-action dimming contract also passes17
checks. No script errors, all exit0 and zero owned processes remain. Receipts:
blackjack-net-current-main-host, blackjack-net-current-main-cold,
blackjack-net-stand-animation-compat (.json/.log); corresponding raw host/cold
observations are retained. Exact NEXT and synthetic Web Continue are pending.

## Exact NEXT acceptance

Published main/NEXT source: `ee02497f95183b61155b4a1357cc9346bf0815af`.
Tree: `40a3f4890045c734c6817436d03d46151bb5aa24`.
Promoted 2026-11-04T15:51:44Z by the existing watcher, without manual deployment,
stable/itch publication or audience changes. The source/tree, clean manifest,
archive/provenance, live redirect, version, six served runtime assets and MIME
match. Direct served PCK SHA256:
b4a26bdc809a69940aa7dca066dd1abdc46e0b9469de7ca6738284b81ae0e529.
Receipt: task-11/evidence/next-ee02497f95183b61155b4a1357cc9346bf0815af-release.json.

Fresh disposable 1280x720 Web contexts install only the exact official synthetic
native Save and its matching generated signing companion before engine boot,
then use ordinary Continue. No original profile access, paid Web command or
post-boot state edit occurs. This verifies restored projection on Web;
the normal paid hands and financial authority are tested natively above.

Independent visual review accepts these actual floor screenshots:

| Fixture | Visible first line | Separate account credit | Wallet |
| --- | --- | --- | --- |
| Paid win followed by genuine automatic watch | Blackjack net: +5 chips. | Chip change: +10 chips. | Cash $92 / chips 18 |
| Losing hand | Blackjack net: -5 chips. | Chip change: +0 chips. Heat +1 | Cash $92 / chips 8 |

All three Result lines fit the existing panel, with no clipping or dollar
wording on chip results. Both captures have no page, console or request errors;
loaded resources match the exact SHA, contexts/browsers close and owned jobs
exit 0 with zero processes remaining. Evidence files share prefix
next-ee02497f95183b61155b4a1357cc9346bf0815af-blackjack-feedback-
win_sitout or loss (.json, -menu.png, -continued.png). Owned-job receipts:
web-blackjack-net-ee-win-load45 and web-blackjack-net-ee-loss-prewarm45.

The initial path diagnostic installed files outside the actual Web user://
directory. The corrected path is /userfs/godot/app_userdata/Beat the House.
Initial 10/45-second input budgets were also insufficient in some cold loads.
The accepted loss run allows 45 seconds of ordinary menu UI prewarming (campaign
clock paused) and 75 seconds for Continue inside a 180-second owned job, retaining
the 5% aggregate CPU cap and 2 GiB memory limit. No application code or guards are
changed to make the load finish.

Supplemental Web push remains UNVERIFIED: both bounded ordinary Continue
attempts timed out before a floor screenshot, without page/console errors.
Final context/browser cleanup completes and zero owned processes remain.
Receipts: web-blackjack-net-ee-push and
web-blackjack-net-ee-push-prewarm45. Native normal Deal/Stand/Back/Save and
separate-process Continue verify push net 0 / credit 5 / chips 13 and exact protected
state. The Web timeout does not establish wrong feedback and is not counted
as a pass. Different synthetic seeds also create different generated rooms,
so it does not isolate a losing/pushing-result formatter regression.

The independent acceptance reviewer confirms that the original requirements
are met: committed fix, win/loss/push and save/cold correctness, preserved
accounting and exact NEXT with changed behavior exercised. All-three-Web-case
coverage was supplemental, not an original acceptance gate. The task closes
with that explicit limitation; no all-three-Web or original-save replay claim.

Concurrent main `f3058b6d` retains exact matching blobs for FoundationMain,
GameModule, Blackjack, its action authority, FoundationActionViewModel and
RunState versus the visually accepted `ee02497f`. Receipt:
blackjack-net-current-lineage.json. This is compatibility evidence; actual
visual acceptance identity remains the exact `ee02497f` build above.
