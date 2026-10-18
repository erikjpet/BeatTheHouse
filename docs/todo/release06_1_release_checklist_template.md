Status: PARKED COMPANION TEMPLATE - populate only from `rw06_4`; not independently claimable
Board row: existing `rw06_4` (no new row)
Destination: `docs/plans/0.6_release_checklist.md`

> **RW06 EXECUTION NOTE (2026-09-24):** `rw06_4_release_gate_ship_prompt.md`
> supersedes this template's large matrix for 0.6.0 release-week execution.
> Populate the final record only from rw06_4's slim exact-candidate gates.
> Mark native/Web parity, the full 11-game campaign, broad balance and soaks
> B/C plus aggregate analysis `DEFERRED TO 0.6.1`; do not rerun or imply them.
> Soak A remains required. Q-003 forbids agent upload/publish: record zip
> handoff and the owner's later upload confirmation instead.

# Beat the House 0.6.0 Release Checklist - Template

Do not populate this from a development or playtest build. Required finished-
build inputs are: one clean candidate commit; final version fields and feature
counts; the exact slim gate required by rw06_4; final
Web/Windows artifact identities and hashes; hands-on results; approved
limitations, screenshots and public copy.

## Status and release identity

- Status: `DRAFT | SOURCE APPROVED | COPY APPROVED | PACKAGE APPROVED | HANDED OFF | OWNER UPLOADED | RELEASED`
- Date:
- Owner:
- Version: `0.6.0`
- Candidate commit:
- Supported targets:
- Engine/tool identity:

Record identity agreement for `project.godot`, supported export presets, the UI
version render, README, CHANGELOG, artifact names, public copy and tag.

## Included scope and verified counts

List only features present in the exact candidate. Give the command or source
for every count. Cover the living town, Crew path, new games, depth programs,
meta/teaching/audio work and post-playtest changes that actually shipped.

## Post-playtest closure

| Area | Accepted head/report | Result |
| --- | --- | --- |
| Triage and owner dispositions | | |
| Blocking `fix06_*` rows | | |
| `balance06_2` before/after | DEFERRED TO 0.6.1 | |
| `cleanup06_1` | DEFERRED TO 0.6.1 | |
| `voice06_1` | DEFERRED TO 0.6.1 | |

## Exact-source gate matrix

| Gate | Exact command/build | Result | Evidence/timestamp |
| --- | --- | --- | --- |
| Project validation | | | |
| Foundation systems/UI | | | |
| Determinism | | | |
| Native/Web parity | DEFERRED TO 0.6.1 | | |
| Performance + nonzero liveness floors | | | |
| Accessibility/visual | | | |
| Save/migration | | | |
| Soak/stability | | | |
| End-to-end route play | | | |

## Accepted limitations and deferrals

List each owner-approved `DEFERRED TO 0.6.1` finding with its roadmap id, evidence,
impact and approval date. Unknowns are blockers, not limitations.

## Owner gates - never infer or combine

| Gate | Exact scope/hash | Owner wording/date | State |
| --- | --- | --- | --- |
| Final source approval (required before packaging) | | | WAITING |
| Release-copy approval | | | WAITING |
| Packaged-artifact approval (after hashes and hands-on play) | | | WAITING |
| Artifact handoff / owner upload confirmation | | | WAITING |

## Packaging, publication and reconciliation

Record artifact filenames, sizes and SHA-256 hashes; the owner's later upload
confirmation; annotated `v0.6.0` tag target; public-page checks; and final
source/artifact/tag agreement. Agents never upload or publish. Leave these
empty until the corresponding owner gate or owner action actually occurs.
