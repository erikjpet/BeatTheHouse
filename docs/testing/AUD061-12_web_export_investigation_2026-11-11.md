# AUD061-12 — Bounded Web-export investigation

Started from main413ebe822b557f8997b6b7a78e2bc56e153ea40d (QOL-01 accepted-delivery receipt); remote/accepted NEXT054ab4a0d63cf1399180ebbc087097484637ece1. [Work order](../todo/BTH_0.6.1_audit_work_orders.md#aud061-12--the-web-export-failed-twice-at-49-with-no-root-cause).

Disposition: **not reproduced in these bounded attempts; historical causal root remains unresolved**. No runtime, asset, exporter, native/template, guard, cap, reserve or GC fix was made. The exact-RC export pair must still be run after candidate freeze; the current-source pair below is explicitly pre-RC. Original BTH-NEXT-ALLOC-001 remains open; none of the successes below closes its causal acceptance.

## Before: actual retained failures

Raw original logs are copied unchanged in historical_logs/ with SHA256 in boundary_facts.json. Allocation source0c71fdad33ebdcdecb4aa78e9e7dc9e3f6d0bd80, original logfile0c71fdad...-1793747088766527000.log ends:
```
[  49% ] savepack | Storing File: res://.godot/exported/133200997/export-1909ed950b1fa9020d96f3c52e9856db-coin_pusher_export_parity.scn
ERROR: Parameter "mem" is null.
   at: alloc_static (core/os/memory.cpp:114)
CrashHandlerException: Program crashed with signal 11
Godot web export failed with exit -1073741819.
```
The intervening symbol-less backtrace is retained in full, not elided from the copied log. Distinct stack source345f94149609e828c76c7a9df6b2cffaff5862b9, logfile345f9414...-1793808589489629100.log ends at the same completed-scene marker followed by `Stack overflow.` These are separate observed signatures; a common cause is not established.

The marker is emitted after file data, padding and digest are stored in Godot4.6, so its path alone does not identify the failing operation. [Primary exporter source](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/editor/export/editor_export_platform.cpp), _save_pack_file lines264–320. Current verbose pack A next logs Loading resource: res://scenes/main.tscn and res://scripts/ui/foundation_main.gd. Successful exact NEXT054ab4a0 next records generated main.scn at49%. Thus main-scene/script loading or transformation is the next boundary candidate, an inference from current ordering rather than a proven historical failing instruction. The last parity scene itself is a small Node plus runner-script reference, not evidence of an oversized Coin Pusher world.

## Commands, storage and unchanged limits

All experiments use maintained bth_qa_storage planning/preparation and bth_qa_guarded_run, fresh E-only profiles/temp/evidence, assignment before execution,12%CPU/2GiB aggregate Job limits and cleanup/reconciliation. The existing pipeline retains its own10%CPU/2GiB limits. Pinned Godot4.6.stable.official.89cea1439. Exact argument arrays, manifests, pre-child gates and full stdout/stderr are in the copied job.json/worker.txt files. No private package was published or substituted for NEXT.

Current isolated resource command:
`Godot_v4.6-stable_win64_console.exe --headless --path <admitted current workspace> --script res://.tmp/aud12_resource_isolation.gd [-- main]`.
Two current-source full private exports, fresh profile for each:
`Godot_v4.6-stable_win64_console.exe --headless --path <admitted current workspace> --export-pack Web <guarded-evidence>/private-web.pck --verbose`.
Both use source413ebe82 with only excluded ledger/docs registration dirty; no production edit. Each output is retained under its original E run path.

Two independently admitted, shared-object Git clones contain the exact historical0c71/345f tracked trees; no old user data/profile/save was copied. Each cold import matches the existing import-only policy: recovery-mode editor import with parallel imports disabled and worker_pool/max_threads=1. Verified own override.cfg bytes are retained, and that one owned file was removed before normal export. Tracked-source git status is empty in both checkouts after the experiments.

Historical commands:
`Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --recovery-mode --editor --path <admitted historical workspace> --import --quit`
then normal `--headless --path <same workspace> --export-pack Web <evidence>/historical-*.pck --verbose` in a separate process. The historical main scene also receives the same isolated-resource command.

The exact historical tools/export_itch_helpers.ps1 Invoke-TypedConsoleProcess was additionally exercised inside PowerShell with its512MiB managed-heap limit and the same2GiB outer Job. It calls only the private pack operation; no staging, SDK, native/template build or deployment function. One allocation trial uses the prior generated scene cache. For cold typed trials of both sources, that own fresh-QA .godot/exported directory was retained intact at .godot/exported.qa-retained-before-cold-typed after resolved source/target checks, so scene output is regenerated. No evidence, build, profile or save was deleted. No forced GC call was introduced.

One initial historical-import launch was correctly rejected before a child existed:
`command_path_mismatch: E:\CodexQA\BTH\workspaces\aud12-historical-20261111\allocation: --path must equal admitted workspace E:\CodexQA\BTH\workspaces\aud12-historical-20261111`.
The fresh corrected admission used the actual checkout as workspace. Both the rejected declaration and corrected gates are retained. No different drive or guard/security change was used.

## After: actual results

Four resource cases, eight load/binary-save/single-resource-PCK cycles each: current parity40/0, current main40/0, exact allocation-source main40/0, exact stack-source main40/0; **160checks/0failures**. Current parity binary757bytes, single-resource package972bytes. Main isolated binaries893bytes and packages1076bytes in all three tested trees. These exercise real script dependency loading and serialization; they are not EditorExportPlugin dependency transformation or launchable Web packages. Full Editor export is exercised separately below.

**Seven full private PCK exports completed**, all exit0/no timeout/active0: two current-source, two historical bare exports, allocation warm typed, allocation cold typed, stack cold typed. All seven pass tools/audit_pck_manifest.py's current resource allowlist. Every actual resource payload checksum was verified as well:1165entries in each current package;1177 in each allocation package;1161 in each stack package. Per-package size/hash/full manifest and verified-payload counts are retained. Both historical imports exit0 and both tracked-source status checks emit no changes.

Allocation cold typed wrapper reports before private25726976bytes/managed7134784bytes/heap limit536870912; after private40173568bytes/managed11070088bytes/exit0. Stack cold typed before private25632768bytes/managed7130472bytes/heap limit536870912; after private40349696bytes/managed10719584bytes/exit0. The aggregate Job limit was2GiB throughout. These are observed wrapper snapshots, not peak Godot or failure-time aggregate memory measurements, and do not reproduce the full original site builder envelope.

Current same-source manifest comparison: both47,240,548bytes/1165paths. Package SHA A be493554fde336256249728bac7733a1254a56de255dab16e18c71f6722d4330; B ddb2f680e0aa7652ac076ad413741f8ae9d911b042be92f59bee1efcc1a47358. **Not byte-identical.** All other1164 resource payloads match. The only changed entry is generated .godot/global_script_class_cache.cfg,41633bytes. Its218class entries have different list ordering, but the complete class-name→all-fields map is identical, with no added/removed/changed classes. Raw cache files and parsed comparisons are retained; the initial same-list-order comparison correctly reported false, followed by the explicit class-map comparison true. No runtime-equivalence claim beyond those verified data comparisons is substituted for an actual package test.

No shipping code changed for this investigation. The immediately preceding final runtime Smoke is reused, not claimed as newly run here:4pass7fail versus baseline4/7, exact content25/runtime16 old sets, normalized new errors[], performance9 inherited categories versus baseline10. Native QOL-01 real-input83/0 and no-pointer livenessPASS remain scoped to that unchanged production source. Baseline Python180/0 is historical, not rerun by this document-only investigation.

## What this does and does not rule out

These attempts did not reproduce a deterministic parity/main load, serialization or private Editor PCK failure in the tested current and exact historical trees under the recorded memory limit, including cold generated-scene output and the typed console helper. A tiny last-completed scene is not a demonstrated pathological asset. Success of historical input also prevents treating later game-code changes as the established fix.

They do not rule out intermittent Godot compiler/resource state, original failure-time live memory, full site-wrapper/native-registration context or machine scheduling effects. The historical allocation and stack signatures remain distinct. No causally supported GC mitigation, engine fix or asset change is established. Existing memory telemetry is diagnostic evidence only. A retained failing reproduction with useful memory/stack evidence is still needed for the original causal objective; no speculative runtime or structural redesign was substituted.

Current capacity is not blocking promotion: exact NEXT054ab4a0 receipt reports D free34,486,329,344bytes versus required12,019,158,283, admittedtrue; archive_retained_on_d=false under the existing E ephemeral workflow. QA pack A launch records E available336,376,864,768bytes against4GiB expected writes plus20GiB reserve. No retained evidence was pruned and no reserve changed. This records current admitted state, not a claim that this audit authored the prior storage repair.

## NEXT and remaining qualification

Existing pipeline currently serves accepted054ab4a0 with no error; its prior exact-asset/startup receipt is in QOL-01. This investigation report's commit is pending its ordinary combined main push and exact NEXT verification. There is no newly claimed game fix to demonstrate in Web.

The requested **two exports from the final frozen RC** and manifest comparison remain explicit final-qualification work after AUD061-04/05 dispositions. These pre-RC successes do not satisfy that exact-SHA requirement. The bounded investigation batch may finish with this not-reproduced disposition once its report deploys; the full AUD061-12 parent remains open for the causal/RC limitations stated here. Full original failure logs, raw commands,7retained private packages,160-check outputs, manifests and admission failure are preserved. No tag, release, manual publish, migration, item/scenario change or additional watcher was created.
