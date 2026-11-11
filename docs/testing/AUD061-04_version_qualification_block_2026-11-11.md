# AUD061-04 — Version update blocked by existing exact-input qualification

Started from main854b12568d0a53ccb3c9dde9f14f5f99fc23bfbb (AUD12 delivered-report receipt); accepted NEXTbdaa9b337d3fae076a9ee623051acc2af2e6a7d9. [Work order](../todo/BTH_0.6.1_audit_work_orders.md#aud061-04--version-stamps-still-read-060-everywhere).

Disposition: **blocked before implementation**, following the user's step3 instruction to stop an order whose required change would break something the report did not account for. Mandatory version-stamp/exporter changes cannot pass the unchanged existing NEXT builder's current exact Git-object qualification. No partial replacement design, pin update, bypass, broken push or alternative deployment was made. The pipeline itself remains healthy for the currently qualified inputs.

## Before: reproduced current stamps

Source-only command, fresh guarded E profile:
`Godot_v4.6-stable_win64_console.exe --headless --path . --script res://.tmp/aud04_stamp_probe.gd`
Actual output:
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

{"checks":2,"failure_count":2,"failures":["project stamp is 0.6.0","source display is 0.6.0"],"project_version":"0.6.0","source_display":"0.6.0","source_probe_only":true}

```
2checks/2failures against requested0.6.1. Actual project config/version0.6.0; Windows file_version/product_version0.6.0.0; Android version/code9 and version/name0.6.0; iOS short_version/version0.6.0. BuildIdentity.DEVELOPMENT_VERSION literal0.6.0; export_itch Get-SourceIdentity line71 still writes0.6.0-dev+short. Its actual display_version returns manifest build_version. The immediately preceding exact browser startup visibly shows Version0.6.0-dev+bdaa9b337d3f; its verified screenshot is retained in AUD061-12 evidence. These findings reproduce; this is not a not-reproduced disposition.

## Concrete incompatibility

Read actual D:/Projects/site/scripts/build-bth-next-gdscript.ps1, not an assumed generic pipeline. Current qualifiedBaseb46fabb2853c312b67399606f59804eaefa62d47 guards native/addons plus project.godot and export_presets.cfg. Actual git ls-tree at qualifiedBase and current HEAD gives identical metadata blobs:
```
project.godot       7c80d4e964583372398be6da0ff504ff6074f395
export_presets.cfg  b9d92cd7c6b9a0e013fc5f33da611321babacd93
tools/export_itch.ps1 c2f40edc369191825862127271a515f884480fe9
```
The project/preset guard's sole reviewed difference is a specific Coin Pusher kernel object substitution. A project or preset stamp edit remains a mismatch after that substitution and triggers:
`Guarded native, addon, engine/template or unchanged exporter inputs changed; native reuse refused.`

Separately, reviewed exporter policy pins the entire export_itch.ps1 objectc2f40edc..., alongside four other exact exporter/GL-policy objects. The mandatory development-identity derivation changes that object and triggers:
`Web exporter/policy objects differ from the exact reviewed finding009 set.`

The retained read-only probe validates all three actual source blobs, computes in memory the three minimum required edits, and verifies each differs from its pin:6checks/0failures. Full current/prospective object hashes, immutable policy SHA256 and exact excerpt are in gate-evaluation.json. This is a counterfactual predicate/object evaluation, **not** a failed real build. No source file was edited to make a broken test commit. The exporter preview only proves the required literal change violates the whole-file pin; it is not a substituted or complete implementation of the requested work order.

## After and required unblock

No application version or display change was made: source remains0.6.0 and NEXT remains0.6.0-dev. Required0.6.1/Windows0.6.1.0/Android10, derived identity, cross-stamp checks and release+short-commit display remain open together, as the requested single change. README published-release links remain at0.6.0 under the owner's no-release instruction; no telemetry/build_version format, save/schema/version check, migration, package naming or content was altered.

Unblock requires a separately authorized, reviewed qualification of the exact0.6.1 project/preset/exporter inputs through the existing NEXT machinery, under unchanged native/template/resource/cap/reserve checks. The current user instruction explicitly forbids changing the pipeline guards in this run; silently updating pins or selecting the older full builder would violate it. Cold-import qualification alone cannot override these separate builder object checks. The user's stop-and-record rule takes precedence over applying a known incompatible version commit. There is no storage/trust/capacity problem to solve for this order.

No post-change Smoke is claimed because no production change exists. The unchanged runtime's latest Smoke remains4pass7fail versus baseline4/7, content25/runtime16 exact old sets, new stderr[], performance9versus baseline10; nativeQOL83/0/livenessPASS are prior unchanged-source results. The stamp probe intentionally exits1, and its full guarded job/raw output is retained; the read-only gate probe passes6assertions. The causal export investigation remains separately scoped to AUD061-12, not presented as this version blocker.

## NEXT

Pending ordinary delivery of this blocked-disposition report. The0.6.1 version change itself is **not delivered**; no existing guard was weakened to create that claim. Continue AUD061-05 and the requested proposed-candidate acceptance/coverage with this explicit release blocker recorded. No tag, release, manual upload or second deployment path.
