# Pull Tabs and Vault Drop save closeout, 10 November 2026

## Result and disposition

Current supported reconstructions pass on source `2e3b88103d010562788793c17efbcc2f4c91c39b` plus the test-only provenance additions below. No independent production correction was established. **Both original parent investigations remain Open.** Passing equivalent fixtures cannot recover or identify absent historical generations.

- `BTH061-PULLTABS-SAVE-001`: preserve the original two cold clock rollbacks and corrected machine Save -> cold floor -> floor Save -> second cold sequence. Primary/backup/load fingerprints and custody between the original Saves were not captured. Current custody, overlap, machine/floor Save and cold Continue cases pass.
- `BTH061-VAULTDROP-SAVE-001`: preserve the original R04 cold rollback observation. Its original screenshot/receipt did **not** capture Saved or a pending/success acknowledgment. The hidden refusal feedback was independently fixed by `85c1782b`; the original Save branch and generations remain unknown. Do not rename this evidence as a proven acknowledged-save rollback.

The missing personal saves are unavailable historical evidence, not a pending request to the user. No original save/profile/key was read, copied, restored, refunded or replayed.

## What changed

Only three test files change. `save_generation_provenance.gd` records primary/backup existence, size and SHA-256, exact snapshot fingerprint, clock/accounting/custody, most recent load outcome and host dirty/inflight/completed counters. The host counters are in-memory scheduling counters, not durable generation identifiers. A Save-stage load result refers to the service's most recent prior load; first-load stages record the actual new load result.

The existing Pull Tabs custody and Vault feedback checks now retain those observations at Save returns, before load, immediately after the first fresh-service load, and immediately after host Continue. They assert no load-time file rewrite and `loaded-primary` for these known-good generated checkpoints. The optional evidence directory is supplied by the guarded launcher. This does not add telemetry to the shipped game or modify SaveService, browser persistence, ticket authority, physics, economy or RNG.

## Focused current checks

- Pull Tabs: **129 warm + 70 separate-process cold assertions**, zero failures or skips. Four independent $2 purchases, one per existing fixture case. Registered older tray-generation overlap, machine/floor saves, canonical versus current-room custody, valid stale-room copy restoration, read-only views and empty repeat Collect remain covered. All cold checkpoints restored cash 94/chips 13/Heat 0, exact clock 3120, exact ticket identity once, empty tray and protected RNG/Card/Bag/stock state.
- Vault Drop: **57 warm + 15 separate-process cold assertions**, zero failures. Independent naturally generated Corner Store Vault, one normal pointer Drop, visible unsettled refusal with unchanged disk/live state, normal Leave settlement, successful floor Save and fresh-service/host Continue. The settled checkpoint restored cash 96/chips 0/Heat 0 and exact clock 744, RNG and full settled machine/tray state. The existing busy-storage refusal/retry/load/new-run checks also pass.
- Web durability adapter: **16 CLI contracts**, zero failures. The adapter blob is unchanged from `c43c95a9`; the relocated test differs only in its source lookup path. This is not a newly rendered Web gameplay pass.
- Every first cold fresh-service load and host Continue reported `loaded-primary`. Their primary and backup fingerprints matched the byte copies preserved before first cold launch. No unexplained fallback or raw/canonical divergence was found. When primary is valid, SaveService intentionally does not parse backup; `backup_loadable:false` is not proof of corruption.

Commands, executed through the storage-aware capped supervisor:

```text
godot --headless --path <isolated-worktree> --script res://scripts/tests/pull_tab_custody_restore_matrix_check.gd
godot --headless --path <isolated-worktree> --script res://scripts/tests/pull_tab_custody_restore_matrix_check.gd -- --cold
godot --headless --path <isolated-worktree> --script res://scripts/tests/vault_drop_save_feedback_check.gd
godot --headless --path <isolated-worktree> --script res://scripts/tests/vault_drop_save_feedback_check.gd -- --cold
node tools/web_save_durability_bridge_check.cjs
```

## Evidence custody and runtime identity

All new workspace, profile, temp, persistence, evidence and declared outputs were admitted under `E:\CodexQA\BTH` before setup and before each child launch. The native supervisor used an 8% aggregate CPU/2 GiB kill-on-close Job, assigned before execution, with no breakaway. All children exited 0, no timeout/error, and zero owned processes at release. The separate CLI contract Job used 3%/2 GiB and drained to 0. Defaults of 4 GiB expected writes + 20 GiB reserve were retained.

The first native run used the older existing debug DLL `9ed33e21...`; its successful results are retained as compatibility evidence only. A concrete runtime identity mismatch justified one repeat. Before that repeat, all 11 available native source/build/toolchain files from the existing accepted candidate matched this source byte-for-byte. The qualified rerun used debug DLL `184bfde4d9697b397f347dc9ab35b8915f59a7d3ca54c8849c7c59914d53f17b`, with release companion `858934c0...`, and Godot `4.6.stable.official.89cea1439`. No native rebuild or new parity campaign is claimed.

Fresh agent-owned saves and authority companions were copied and hashed **before** their first separate-process cold load. First cold load observations were retained before re-entry or another Save. Raw fixture saves, companions, custody copies, logs and storage ownership manifests stay outside Git. The [machine-readable receipt](save_rollback_closeout_20261110.json) records source/runtime/test hashes, all five first-cold generation fingerprints, commands, results, custody-receipt hashes and Job summaries.

## What remains unknown

These are the existing independent synthetic/normal-host fixtures, not the original advanced campaign or a new rendered Web test. The Pull matrix disables continuous clock progression and includes one explicit valid-stale-copy fault model. It does not replay the original 132.828-second dwell or failed focus attempts. The Vault test refuses Save immediately while unsettled and then saves after normal Leave; it does not identify which branch the original 13.416-second attempt reached. Prior rendered Web comparison and feedback evidence remain scoped to their original builds in [Pull custody](pull_tab_custody_followup.md) and [Vault feedback](vault_drop_save_feedback.md).

Further production changes need new causal evidence: a current post-ack cold regression, raw/canonical custody divergence or unexplained backup load. Preserve the exact build/origin/slot, acknowledgment state, first-cold state, both generation fingerprints and `SaveService.last_load_result()` **before another Save**. Do not replay a purchase, reselect an outcome, or ask for the gone original save. This finite current-path qualification is complete; neither original parent is falsely marked fixed or closed.
