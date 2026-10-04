# Environment slot consolidation and counter rework

Status: **COMPLETE — HISTORICAL PRE-RELEASE-2 SNAPSHOT; SUPERSEDED FOR CURRENT
PLACEMENT AUTHORITY.** See `environment_scenario_slot_instance_rework.md` and
`../plans/environment_scenario_layout_breakdown.md` for the implemented
scenario-instance model and current 75-context guide.

Started: 2026-10-03

## Goal

Reduce misleading and unnecessary environment-slot capacity across every
production map while preserving every combination of physical objects that can
actually coexist. Keep the four lifecycle families (`fixed`, `event`,
`scenario`, and `exit`), make slot names describe their physical purpose, and
make the placement tool present one useful context at a time instead of every
empty slot at once.

The Jazz Club is the reference implementation. The same producer/concurrency
audit and migration rules apply to all 21 effective placement maps and all 55
environment scenarios.

## Locked decisions

- The canonical spelling is `scenario`.
- Fixed identities use specific names; reusable event and scenario slots use
  physical-class names.
- Interactions, tasks, services, and state changes attach to tangible room
  objects and do not receive independent placement slots.
- Runtime reserves remain only where a proven simultaneous state requires
  them, and are hidden in the normal placement view.
- The Pull-Tab/Lottery Clerk is not a separate physical room object. Pull Tabs
  are sold through the Jazz Club bartender/sales counter.
- Pull-tab redemption remains at that counter and retains all current payout,
  counterfeit, scrutiny, suspicion, and heat behavior.
- Suspicious redemptions add contextual counter conversation so the bartender
  reacts to the cashout instead of resolving it as an unvoiced system result.
- Legacy saves do not require migration. Existing exported placement reports
  do require an old-to-new slot-ID import ledger so owner-authored coordinates
  survive the data cleanup.
- The implementation finishes by publishing GitHub prerelease
  `v0.6.0-pre.2` with a downloadable Windows executable/package.

## Implementation plan

1. Capture a clean repository, slot-count, map/scenario-count, current release,
   and focused-test baseline.
2. Define the canonical slot vocabulary, occupant metadata, reserve metadata,
   action-host contract, and old-to-new migration-ledger format.
3. Build a producer and simultaneous-capacity matrix for every fixed object,
   ambient event, character chain, traveler, Crew/Numbers presence, delivery
   state, game hook, shop item, scenario phase/aftermath, and exit.
4. Give every authored slot one explicit disposition: keep, rename,
   reclassify, attach action, merge, runtime reserve, or remove.
5. Separate tangible room objects from abstract actions. Rebind tasks,
   opportunities, services, and state changes to their physical hosts.
6. Rework the Jazz Club as the reference environment, including corrected
   fixed identities, physically named reusable pools, one real exit, scenario
   phase/outcome mappings, and documented delivery reserves.
7. Rework the Pull Tabs counter flow: remove the independent clerk object,
   sell Pull Tabs as bartender/counter shop stock, keep counter redemption and
   the existing suspicious-cashout heat rules, and add bartender conversation
   for suspicious cashouts.
8. Apply the audited capacity and naming migration to every effective
   environment/layer without cross-family fallback or missing required
   objects.
9. Redesign manual slot placement around family/context tabs, active-object
   previews, occupant-first labels, hidden empty/reserve capacity, and
   context-aware overlap diagnostics.
10. Preserve owner positioning through an old-to-new slot-ID ledger and update
    packaged-build placement reports so renamed, merged, removed, and unmapped
    positions are reported explicitly.
11. Regenerate derived manifests/snapshots and run static, focused runtime,
    all-scenario, save/revisit, seed/concurrency, placement-tool, and report
    round-trip validation.
12. Update player/developer documentation and release notes, commit the exact
    verified tree, and push `main` to GitHub.
13. Export the verified Windows build, create and push tag
    `v0.6.0-pre.2`, and publish it as GitHub prerelease 2 with the downloadable
    Windows artifact and checksums.

## Acceptance criteria

- Required fixed objects appear on every generation and revisit.
- Every possible physical producer has a compatible same-family slot or an
  explicit tangible host.
- No live physical object shares a slot, crosses families, or silently falls
  into an incompatible class.
- Manual placement opens on one useful family/context and never floods the
  room with all empty capacity by default.
- Raw stable IDs remain available for reports and diagnostics, while the room
  view leads with occupant names and physical roles.
- Pull Tabs can be bought and redeemed from the bartender/sales counter, and
  suspicious cashouts preserve their mechanical consequences and produce a
  visible counter exchange.
- All 21 maps and 55 scenarios pass their placement/static/runtime coverage.
- A fresh packaged EXE exports a placement report that can be mapped back to
  committed slot IDs.
- `main`, tag `v0.6.0-pre.2`, the release source commit, and the attached
  Windows artifact all identify the same verified source tree.

## Completion record

- The final authority contains 659 positions across 21 maps: 214 `fixed`, 147
  `event`, 222 `scenario`, and 76 `exit`. This is 63 fewer positions than the
  722-position source layout while preserving every verified simultaneous
  claimant across all 55 scenarios.
- Every original position has an explicit ledger disposition: 365 kept, 230
  renamed, 109 merged, and 18 removed. Sixteen audited coexistence positions
  were introduced. The report translator preserves exact-target precedence
  and reports collisions, retired positions, and unmapped input.
- Pull Tabs are counter merchandise in all four venues: Rafi at the Bar, Nell
  at the Gas Station Casino, the Jazz Club bartender, and the Grand Casino host
  desk. Buy, help, and cashout actions attach to those hosts only. Suspicious
  cashouts retain the existing payout and Heat calculation and enqueue one
  contextual conversation without applying consequences twice.
- Manual placement opens on `fixed`, shows one family at a time, leads with the
  active occupant, identifies the current scenario/phase, hides unused and
  reserve capacity by default, and keeps occupied reserves visible. Exported
  packaged-build changes include all locked edits regardless of current view.
- The human-readable breakdown covers all 21 maps, all 55 scenario rows, and
  every one of the 659 stable IDs. Its placement authority SHA-256 is
  `E18795A6665699AA1C8C6A1B451E66C10357F496C1FA059848EA7B3598FCC5D0`.
- Static schema, migration, disposition-ledger, translation, manifest,
  grounding, stacking, placement-mode, counter, tutorial, UI, deterministic
  seed, project-validation, and release smoke gates pass on the completed tree.
- GitHub prerelease `v0.6.0-pre.2` is the Windows testing handoff for this
  completed implementation; final artistic repositioning remains the owner's
  intended follow-up and does not change the slot contract.
