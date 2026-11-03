# BTH061-CREW-EXPIRED-HANDOFF

Associated fix commit: `b29d9b3985b5676aac2439f2f08aae359729a3e3`.
The current stability release task list tracks this ID. NEXT verification is a
separate release receipt; a local pass does not claim deployed Web gameplay.

## Failure and fidelity

The owner reached the Jazz Club as a Crew package appointment expired. The
delivery was missed, but a clickable `Handoff` remained and selecting it briefly
stalled play. On source `87a06b9a4acbe86b0f761d2cd0ab929f5584b716`, a synthetic
Jazz-target fixture reproduced a resolved, world-applied delivery with one miss,
no closed checkpoint, and a mounted actionable `crew::package_handoff`. It
survived refresh and Save/Continue in the manifest, renderer and layout authority.
The baseline test exited 1: 47 checks, 15 failures identifying those stale rows.

The fixture pins only the offer target to Jazz Club. It uses the authored Crew
event, real generated map, appointment schedule, travel installation, sequence
commands, UI dispatch and SaveService. UI rendering/save observers are isolated;
this is native production-API evidence, not a captured-player or visual Web
reproduction. Browser inventory capture failed during CUA initialization before
access, so the latest actual player save was not inspected or changed.

The baseline stale save and its profile/authority companions were copied and
SHA-256 verified before testing recovery. They remain private under task-10's
`.private/baseline-stale-profile`; no save, key or private payload is committed.
The custody receipt is `evidence/baseline-stale-custody.json` in task-10.

## Correction

Cleanup previously retained the latest delivery instance unconditionally, even
after offscreen settlement. It now retires that presentation only when the run
and Crew job are resolved, consequences are applied, and no closed checkpoint,
lifecycle retry, pending outcome or owner result requires recovery.

Activation reports cleaned owners so a sole retired owner triggers layout
recomposition. The known finalized primary scenario projection is supplied
explicitly while the trusted-rebuild flag remains set; the flag clears only
after successful sealing. This removes the stale actor/action while preserving
the room's authored objects. Normal readers and checkpoint rejection remain
strict. Economy, trust, obligations, penalties and appointment timing are unchanged.

## Focused verification

Pinned Godot: `4.6.stable.official.89cea1439`. All runtime jobs used private
save/profile/settings roots, a 5% aggregate CPU/2 GiB kill-on-close Job, explicit
deadlines and creation-handle assignment. Completed receipts record zero owned
processes at release.

`scripts/tests/crew_expired_handoff_check.gd`, with
`BTH_CREW_HANDOFF_CASE=all` and `BTH_CREW_HANDOFF_HOST_CATALOG=1`, passed **329
checks** on the fix commit after integration with main `5f01c8f0`:

- arrival at the closing minute and one minute late, plus mounted expiry after
  the normal host-refresh finalization boundary;
- legitimate handoff at exact opening and closing-minus-one, with original
  payout/Heat/trust/obligation behavior and exactly-once recovery;
- absence of the expired handoff in raw projection, manifest, sealed renderer,
  layout authority and actual Main catalog;
- all six tangible Recording Night scenario objects retained through cleanup,
  repeated refresh, ordinary/empty fact flushes and Save/Continue;
- cached stale UI action rejected without a retained input transaction or state
  mutation; two later process frames remain live;
- a genuine pending checkpoint is retained; a synthetic missing-checkpoint
  clone is rejected without losing its receipt or replaying settlement; the
  authentic receipt consumes once and repeated resume is an inactive no-op.

Command: pinned Godot `--headless --path source --script
res://scripts/tests/crew_expired_handoff_check.gd`, through task-10
`run_owned.py --timeout 180 integrated-jazz-boundaries` with the above environment.
Evidence: `evidence/integrated-jazz-boundaries.{json,log}`.

The separate `legacy` mode loads the authentic synthetic stale save produced by
the unfixed source in another process, finalizes it and saves/reloads the repaired
presentation without changing its already-applied delivery accounting. Its
result is **60 checks passed**, exit 0, recorded in
`evidence/integrated-legacy-cold.{json,log}`. The two final jobs total **389 checks**
and both close with zero owned processes. Preserved baseline hashes remain
unchanged after recovery testing.

After main advanced to `f3a2f0b1` with the Back Alley publication fixes, merge
`5e054f51b439028fd8417a0dc7bca97ca4e1d179` retained the original fix commit and
both task records. The same **329 + 60 checks passed again** on that integrated
runtime, with no script/check failures and zero owned processes after each job.
Receipts: `evidence/authorized-integration-jazz-boundaries.{json,log}` and
`evidence/authorized-integration-legacy-cold.{json,log}`. This specifically
qualifies the shared composed-layout helper's stronger publication validation.

The older `world_sequence_delivery_proof_contract.gd --delivery-reentry-only`
runtime could not construct its pre-existing triggered-event fixture (`Event is
no longer available`) before any checkpoint assertion. One bounded cadence-fixture
attempt did not repair it; that path was stopped and the tentative fixture
change removed. Its old retained-presentation expectation is updated, without
claiming a pass. The valid Jazz fixture supplies the focused recovery/rejection
evidence above. Earlier harness-only errors (reserved helper name and an
interaction-only task incorrectly counted as a visual) are retained in local
logs and corrected in the final test; they were not product failures.

## NEXT verification and closeout

Main push `29931ab9706df2dc45955f52fa1125fe77b78079` succeeded after the existing
approval blocker was addressed with new trusted human authorization. The
existing watcher promoted the newer descendant
`a8941ccf94b2916ba772e9f7a4752bde454f1731` at **2026-11-03 22:25:35 UTC**.
Its tree is `167c24db4a2e315548be98640cdd34b2a6cff2a4`; version is
`0.6.0-dev+a8941ccf94b2`. Ancestry proves it contains the fix. Crew delivery/core
and this regression script are unchanged from the pushed/tested version; the
superseding commit adds a separately owned terminal-table presentation change.
The 389 native checks above are attributed to their actual tested source, not
claimed as a fresh full native run on this later UI source.

Served `next.json`, `BUILD.json`, manifest, `REF`, `VERSION`, local current pointer
and actual HTTP NEXT-entry redirect agree with that SHA/tree. Six payload HEAD
requests return 200 with matching provenance sizes and correct WASM MIME.
Downloaded PCK SHA-256 is
`6af49d524eefaf585f14342bd9883646ddf367cd7eef5479be135bd737a30488`;
it matches exact-build provenance. Archive SHA-256 is
`7a9632509066c9c5100add4c85656b0345fe6affa88e88950baff117e68d8e0f`.
The pipeline's matching engine/native qualification is reused; no substitute
build, watcher restart, stable/itch publication or audience change occurred.

A fresh disposable Chromium context loaded this exact immutable build and
visibly reached the main menu with the matching version. All four engine/PCK/
native requests returned 200; no page errors occurred. One ordinary AudioContext
autoplay warning is retained. Browser/context closure completed, and the capped
job exited 0 with zero owned processes. This is basic visual Web startup, not
Web reproduction of the Jazz deadline race. The restricted-account browser
attempt timed out before navigation; its owned tree was closed and evidence
preserved before the successful check under the installed-browser account.

Task-10 release evidence:

- `evidence/next-a8941ccf94b2916ba772e9f7a4752bde454f1731-release.json`
- `evidence/next-a8941ccf94b2916ba772e9f7a4752bde454f1731-startup.json`
- corresponding startup screenshot, `web-next-a894-startup-r3.{json,log}`
- `evidence/final-qualification.json`, `publication-resumed.json` and preserved
  historical blocker/custody receipts

The implementation and NEXT verification are complete with the associated fix
commit above. The restored named task ledger additionally requires original
acceptance and records missing original fixtures as gaps. Accordingly,
`BTH061-CREW-EXPIRED-HANDOFF` (alias
`BTH-CREW-EXPIRED-JAZZ-HANDOFF-001`) remains Open only for original-player-state
acceptance: that latest save was inaccessible and untouched. Synthetic native
compatibility evidence and fresh Web startup do not assert that unobserved
player-state or deployed Web deadline-race gameplay acceptance.

A later promoted descendant, `e641f0c81af36c399d5fea5c1504963455f63cc2`
(tree `2e44862d148cf92ba256aa50daf23e5dd732b71e`, promotion **22:31:13 UTC**),
also passed the same served-identity/actual-redirect/REF/VERSION/six-payload/PCK
verification and reached a visible correct-version menu. Its served PCK
SHA-256 is `a8952f563fc74dc0c743411fd6965200ead39358c4c99d07ccc601b3eef017bb`;
version `0.6.0-dev+e641f0c81af3`. It retains the unchanged Crew core/regression
code and includes the separately owned fixed-HUD update. Browser/context closed
with no page errors and zero owned processes. However, this startup is **not
qualified**: final console review found one autoplay warning and eight error
lines, including `Identifier "CanvasLayer" not declared in the current scope`
at `foundation_hud_bar.gd:746`, type inference failure, failed HUD script load and
null `rp_child`. The raw smoke JSON's `passed=true` was a false positive because
its original gate checked JavaScript page errors but ignored console errors;
that local gate is corrected. The original raw evidence is preserved. The matching
`next-e641f0c81af36c399d5fea5c1504963455f63cc2-{release,startup}.json`, screenshot
and `web-next-e641-startup.{json,log}` preserve this later observation. The blocker
is tracked as `BTH061-HUD-001-WEB-CANVASLAYER` under the active HUD owner. The
earlier a8941ccf startup has only the autoplay warning and remains valid. No fresh
389-check native run or full HUD/gameplay certification is inferred for its
separately changed UI; the original-source qualification remains attributed above.
