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

The older `world_sequence_delivery_proof_contract.gd --delivery-reentry-only`
runtime could not construct its pre-existing triggered-event fixture (`Event is
no longer available`) before any checkpoint assertion. One bounded cadence-fixture
attempt did not repair it; that path was stopped and the tentative fixture
change removed. Its old retained-presentation expectation is updated, without
claiming a pass. The valid Jazz fixture supplies the focused recovery/rejection
evidence above. Earlier harness-only errors (reserved helper name and an
interaction-only task incorrectly counted as a visual) are retained in local
logs and corrected in the final test; they were not product failures.
