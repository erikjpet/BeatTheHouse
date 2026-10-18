Status: PARKED COMPANION TEMPLATE - populate only from `rw06_4`; not independently claimable
Board row: existing `rw06_4` (no new row)
Destination: `docs/plans/0.6_pre_release_audit.md`

> **RW06 EXECUTION NOTE (2026-09-24):** For 0.6.0 release week, audit only the
> slim exact-candidate gate in `rw06_4_release_gate_ship_prompt.md`. Record the
> superseded parity/full 11-game/broad-balance/soaks B-C/aggregate fields as
> `DEFERRED TO 0.6.1`; do not convert them back into release blockers. Soak A
> and every rw06_4 gate remain mandatory.

# Beat the House 0.6 Pre-Release Audit - Template

Required finished-build inputs: one clean committed source; current roadmap,
board and closure reports; fresh exact-source gates; unresolved/deferred
findings; version state; owner-gate state; package/publication state. Historical
green reports never override a current failure.

## Audit identity

- Date:
- Audited commit and branch:
- Audited working tree state:
- Engine/tool identity:
- Version identity:

## Verdict

**`READY FOR OWNER SOURCE APPROVAL | NOT READY`**

State the most important evidence and blockers plainly. This audit may block a
release; it cannot waive a gate or approve on the owner's behalf.

## Commitment audit

| Promised area | Status | Exact evidence / remaining work |
| --- | --- | --- |
| Living town | | |
| Crew path | | |
| Games and depth programs | | |
| Meta, teaching, SFX and voice | | |
| Triage/fixes/tuning/cleanup | | |
| Version and public records | | |

## Fresh exact-source gates

| Check | Exact command/build | Result | Evidence |
| --- | --- | --- | --- |
| | | | |

Include every rw06_4 slim gate: validation, Smoke, zero-failure Contract,
three-ending replay, migration, determinism, soak A, idle-liveness, packaged
audits and packaged manual smoke. List the superseded larger matrix separately
as deferred rather than silently omitting it.

## Findings and owner decisions

- Open release blockers:
- Owner-approved `DEFERRED TO 0.6.1` limitations:
- Pending design decisions:
- Source/copy/package/handoff and owner-upload gate state:

## Binding gap-closure plan

For every `NOT READY` item, name owner, exact next action, invalidated evidence
and rerun matrix. No historical package, approval or tag carries across a source
change.
