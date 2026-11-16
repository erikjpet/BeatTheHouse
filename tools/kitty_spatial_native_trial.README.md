# Kitty native campaign handoff

Source preparation is frozen and independently reviewed. Native engine execution
has not been authorized or performed by this worker. The parent owns each fresh
guarded launch, runtime slot, final visual review, source commit and TEST delivery.

## Completed prerequisites

- The parent ran `test_kitty_spatial_native_trial.py` through the maintained
  capped guard: **75 loaded tests passed in1.791s**, Job16716, exit0/active0.
  Evidence: `E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-KITTY-NATIVE-20261116-tests01/evidence`.
  `job.json` SHA256 `3a24cec73bf6880829575fff9c62362a565c006b55c0c09a80363acf32367765`;
  `worker.log` `e1ead4e9ae7a84cddd7cefb612aae37ff570b4734b3750cdfa44661a43a35111`.
  The74 statically counted test methods are not substituted for the actual loader count75.
- The parent ran the historical-only pixel worker: **all135 cases matched the
  original Pillow10.3 changed-pixel counts and maximum deltas**, all191 mask
  hashes and all source files unchanged; Job33864, exit0/active0. No fresh
  candidate/current QA inputs were read. Evidence:
  `E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-KITTY-PARITY-20261116-reference01/evidence`.
  `historical-parity.json` `92fb21db89dcd0089a81bbc48b95c45ea3b6b8893200434edf7e76bdeafb0c1f`;
  `job.json` `e62e0df2e797dd14d72b3d8fbe8ed0c01755e42dd7a1e60ce34e2e8a338dd3a5`;
  `worker.log` `b79b00c694bded3579135c51988bb5a0d6ccbcb8e631d267203867abbdc2c0e2`.
- Independent source reviewer `/root/audit_spatial_handoff` gave STATIC CODE GO
  for the exact four Python files below. This is not native or final art approval.

| Frozen file under tools/ | SHA256 |
|---|---|
| kitty_spatial_native_profile.py | df8966a354390bf60c5725fd74142d5f781499fc1ba02aeb78de81a2b04a5762 |
| kitty_spatial_native_trial.py | 05c15ffd86a7c3932103a0172b81d9c4cca998ae0b244574295b30b3e031c25d |
| kitty_spatial_native_pixels.py | 723ad86e8f8403c07c8f71b00f8a163c06bb40ab8ed50e5e7613d66b85187f68 |
| test_kitty_spatial_native_trial.py | ef8e5a06dfb793fbaecea1c9909eee5acefef4e8048d8ce1a34ccb5342a45728 |

The separate inert observer folder is
`review_artifacts/environment_art_sources/kitty-native-observers/`:
probe `3fd7922e854e32b267f5dbb0aa9449546de3fcfb9ad2871ff3488e5f7a3501e4`,
hook `5bd7e0ed72be61d8e7a971b720c509ec9c86cd579ed836733692be045d8e1f9e`,
provenance `c979fa2910b84ca7572a6587e1b8f12d760ab8530a4e1e3c608a87760745d1cd`,
README `b750ceacba291f2a5cd45b16ae331fb9ffc496ea197fc2e4456249642fe139b3`.
Only the two authenticated `.gd.txt` payloads are materialized as QA `.gd`, after
the unchanged051 selected-source proof and exact full-tree Git-blob binding.
No new raw GD/UID enters the selected source; no ignore workaround is used.

## Roles and identity

- Retained input workspace, read-only:
  `E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-KITTYTRIAL-20261116`.
  Its exact members are `raw_source`, `source_baseline`, `candidate_sources`.
- Fresh native QA workspace:
  `E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-KITTYTRIAL2-20261116`;
  prepared project `qa_source`. Each phase has its own fresh admitted run/evidence,
  profile and temp directories. Occupied IDs and partial outputs are retained.
- Room-only30 baseline `017faffa1f02256046add9e21c2aae3358e2b9508eec15cbac942050f449cfb2`;
  candidate `ba8a2c2ab3e812673cb9ad39b84c22a2a9769171282eb3ff7f357ba5f226d06e`.
  Index is a separate unchanged control `11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24`.
  Static native-only review `ebb0acf227f15b39842af495a103e92ec9ac990f4887c936c9d7b593c82ceb6e`.
  Canonical background sidecar `7ecc922f12cf6d819ede3fed493b8bece7a15c43ed523f12d67a3217ef30a54a`
  must be committed; the runner never copies it from an older workspace.
- Use the parent's **future full committed source SHA/tree containing this tool
  checkpoint, the inert sources/provenance and canonical sidecar**. The earlier
  metadata-only629f1f69d64fc8b4f747421dfed4abdd4abec929 commit does not contain
  this complete checkpoint. No advancing branch name or historical source label
  substitutes for those required40-character values.

## Exact future command shape

The parent supplies `$SourceCommit`, `$SourceTree`, `$RunPrefix`, `$Git` and
`$GitDir` from its actual committed checkout/tool inventory. `$RunPrefix` must be
fresh. Set `$Phase` to `plan` for the read-only admission/command plan first.

```powershell
$Python = 'C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe'
$ArtRoot = 'D:/Projects/Beat-The-House/.tmp/environment-art-layers'
$Runner = $ArtRoot + '/tools/kitty_spatial_native_trial.py'
$KittyArgs = @(
 '--qa-root=E:/CodexQA/BTH',
 '--workspace=E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-KITTYTRIAL2-20261116',
 '--engine=D:/Projects/Beat-The-House/.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe',
 ('--git=' + $Git), ('--git-dir=' + $GitDir),
 '--baseline-stage=E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116/.tmp/web-release-7b284648/stage',
 '--native-extension-descriptor=E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116/addons/coin_pusher_native/coin_pusher_native.gdextension',
 '--editor-native-library=E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116/addons/coin_pusher_native/bin/coin_pusher_native_v3_10.windows.template_debug.x86_64.nothreads.dll',
 '--candidate-root=E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-KITTYTRIAL-20261116/candidate_sources/kitty-spatial-r1-assembled-v3',
 '--candidate-manifest=E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-KITTYTRIAL-20261116-v3-assemble01/evidence/kitty-spatial-r1-assembly-v3.json',
 ('--review=' + $ArtRoot + '/docs/testing/kitty_spatial_r1_static_review_v3_20261116.json'),
 ('--source-commit=' + $SourceCommit), ('--source-tree=' + $SourceTree),
 ('--run-prefix=' + $RunPrefix), '--capture-seconds=20', '--position=-32000,-32000', '--timeout=1200'
)
& $Python -B $Runner $Phase @KittyArgs
```

Engine phases additionally require the parent's explicit `--engine-go` grant.
Do not add it to a general unattended loop. The adapter itself plans/prepares
storage before writes and executes each phase sequentially through the maintained
12% CPU/2GiB Job,4GiB expected writes+20GiB reserve, assignment-before-resume,
closed-zero/cleanup/timeout/log/error gates. No drive or interpreter fallback.

## Twenty-one phases

`source-identity -> tree -> baseline-tree -> select -> archive -> prepare -> install -> import -> identity`
then `contexts`, `motion`, `liveness`, and `capture` after all three.
The five engine diagnostics `composite`, `composite-rm`, `low-detail`, `depth`,
`placement` each depend on identity. File-only `conservative-occlusion` depends
on contexts+motion and repeats exact historical135 parity before fresh135;
`stage-material` depends on contexts+depth. `acceptance-summary` requires all
core result phases and all seven added diagnostics. Run one phase at a time.

Original contracts: five cases13/22/20/19/19,93 selections/186 typed PNGs,
`2*N+734` checks; native27 motion/55 checks and exact81 saved PNGs. Original
motion did not render low-detail; the new native simulated-low check does.
New composites retain the536x96 counter and verify exact native binary64
object/route clocks before JSON. Native `Vector2` object dictionaries are
recovered before transport and never replaced with serialized paint targets.
Stage proof reconstructs67,776 actual donor pixels and checks four fresh bounded
body+shadow bases, bottom12 alpha>=64 rows, with full8px material neighborhoods.

Capture retains every original fullapp1280x720 frame, diagnostic900x430 clone,
1800x860 art-only frame and five controls, all hashes and actual timestamps.
Actual20s completion is bounded by the unchanged helper's final sample cutoff;
requested scheduler Hz is not a measured or invented playback frame rate.
The maximum authored cycle is97s; this is an excerpt. Fullapp Reduce Motion
stability is recorded as observed, separately from art-texture stability.

## Historical-only parity CLI

For a separately prepared **fresh** parent-owned capped run, use
`kitty_spatial_native_pixels.py --historical-reference-only` with explicit
`--root`, `--workspace=E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-KITTYPARITY-20261116`,
`--profile`, `--temp`, `--evidence` matching that run's manifest and
`--out=<that evidence>/historical-parity.json`. Launch only via the maintained
guard; the worker requires its actual launch claim/pending Job, canonicalPython,
current cwd/environment and exact4+20 layout. It creates no directory/child and
uses exclusive output creation. Pass the evidence **directory** as any extra
write path, never the existing report file. The completed reference01 run above
must not be reused or overwritten. Parent closed-Job qualification remains required.

No phase grants final art approval, open-hours/later lifecycle/work/save/revisit,
browser/whole97s-cycle acceptance, activation or TEST delivery. Those remain
explicit parent/director gates; all existing source art, gameplay anchors,
27 timings and original assertions stay unchanged.
