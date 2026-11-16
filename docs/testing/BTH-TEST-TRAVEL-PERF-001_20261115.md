# BTH-TEST-TRAVEL-PERF-001: shared travel slowdown investigation

Status: OPEN. No product fix or deployment is claimed.

Owner reports sustained animation slowdown on NEXT and TEST. Diagnostic source matches TEST cc270944 runtime (clean art cdf63c0a). Shared overlay, timeline, vehicle, entrance and avatar source matches main b91e949a after newline normalization. No owner saves used. Ordinary generated Back Alley to Gas taxi route was exercised through normal host travel controls in isolated native/headless profiles under the repository 12% CPU / 2 GiB guard. A synchronous loader diagnostic approximates no-thread loading only; this is not Web/WASM/GPU verification.

## Findings

- Natural animation completes at eight presentation seconds, roughly7.94 wall seconds after travel transaction. Pre-animation transaction is approximately3.2seconds under the cap.
- Pure overlay CPU averages0.36ms per advance; this does not reproduce sustained slowdown.
- Warm travel still has a roughly123-180ms native autosave hitch. Snapshot/world projection accounts for nearly all of it, not completion polling or art loading.
- These are actual cache misses: changed Back Alley and newly visited Gas. Cache-match optimization would not address them.
- Latest compilation43.7+67.4ms includes projection/input-copy50.6ms combined, separate source-copy17ms and encoding10ms. Timing varies with the CPU guard and is not a browser latency promise.

## Rejected candidate

A narrowly scoped native shallow-copy plus recursive mutable-leaf ownership candidate retained exact bytes in9 decoded historical room graphs. But the same real generated route snapshot was123.039ms versus122.804ms baseline, no material improvement. It remains only in the disposable diagnostic workspace. No product files in main or art branch were changed; no full hostile suite or deployment was justified for this rejected candidate.

Missing import-sidecar and mixed-indentation failures were diagnostic setup failures, not product failures; raw attempts remain preserved. Guarded runs reconciled zero remaining processes. Next: supported rendered/Web reproduction and measurement; preserve immutable snapshot ownership, validation, autosave durability and autonomous animation. Do not characterize the issue as fixed.

## Raw evidence hashes

Root: `E:/CodexQA/BTH/runs/`. Only proof and hashes are committed, not raw profiles or saves.

- `test-travel-perf-cold-20261115-02/evidence/profile.json` SHA-256 `796778c771c0c325ea30b1d6e9594e257dbb0d07166100063ef635c22cc1821f`
- `test-travel-perf-warm-20261115-01/evidence/profile.json` SHA-256 `460ef17f95a93366a2cf4e4d9d9675f5e055ed29405666097c93503cee62be06`
- `test-travel-perf-settled-cold-20261115-02/evidence/profile.json` SHA-256 `2f9e41294187dc310f4db4564a244c4bce02aca3c60b0f0bc2db1bb5bbe8b728`
- `test-travel-perf-pure-overlay-20261115-01/evidence/profile.json` SHA-256 `da30b8702518bc81ff3d172e6ae684090587be958c4359799a4d97f9b9d8588a`
- `test-travel-perf-save-attribution-20261115-01/evidence/profile.json` SHA-256 `4e2e6e1e8d9c0f82e9d9d49b5866f5acbd88086c6cf33b77317645afc3d3346b`
- `test-travel-perf-projection-attribution-20261115-01/evidence/profile.json` SHA-256 `f9843a3ab8a8030ea46ba9fb6f13210021e049495ed956771af7d1efae754b93`
- `test-travel-perf-compile-attribution-20261115-01/evidence/profile.json` SHA-256 `b2ca6e8efb936c3ce03567cdeb82f396da2ff4ec0ee00a3d69938267ac7593d3`
- `test-travel-perf-owned-diff-20261115-02/evidence/owned.json` SHA-256 `fcdb745438cc7b8df267c0ba23092d7394ed24b2a4cc2efca837688abcaf7b64`
- `test-travel-perf-owned-candidate-route-20261115-01/evidence/profile.json` SHA-256 `ebc839d2dcdb47ffcf63103d4b91649147673fc39e0bd7d638fbc3907f0d0a73`

## Rendered profiling and bounded cache-match optimization (2026-11-16)

The parent remains OPEN: sustained Web slowdown has not been reproduced or qualified. This is a measured partial save-hitch reduction, not a complete Web performance fix.

Actual native graphical control uses Windows Compatibility rendering on NVIDIA RTX4070Ti,1280x720. Normal Kitty invitation and travel-menu Grand route on an intact isolated generated profile passed10/10. Native phased-Web-save emulation preserves production phase algorithms, but native GDScript Z85 differs from Web JavaScriptBridge; this is not WASM evidence. A capture and two following frames were excluded from frame samples; wall time includes capture overhead. No owner saves were read or changed.

| Metric | Baseline | Optional receipt candidate |
| --- | ---: | ---: |
| Worst sampled frame |273.596ms|239.199ms|
| Save begin |262.175ms|227.282ms|
| Immutable snapshot |193.853ms|157.870ms|
| Animation wall time |8313.883ms|8234.515ms|

Snapshot improved about18.6%; animation wall difference is not asserted causal because capture/scheduling noise remains. Cold compilation and pack/validate/install work remain measurable. Earlier owned-copy optimization was rejected and is absent.

The patch keeps native equality and the original exact numeric refinement fallback. A nonempty original serialized receipt permits fast acceptance only; typed-container/reorder differences fall back. Receipt is optional, counted under the existing4MiB cache budget. Core-first admission can reclaim old receipts only after a successful single compile, retaining immutable core/encoded caches.

Pressure investigation found the initial receipt candidate displaced398356 encoded-cache bytes in a seven-room historical data-only fixture. The refined version restores all baseline admission and exact encoded outputs36/36: baseline3674612 bytes, refined4069848 including395236 optional bytes. Historical private-profile corruption is irrelevant to this data-only projection comparison; no gameplay or heist qualification is claimed.

Maintained final contract95/95 plus exact JSON byte parity passes. It includes actual runtime-built negative-zero fixtures (literal -0.0 was normalized by GDScript in an earlier failed probe), original/candidate int-float and scalar/packed32/64 rejection, typed/reorder fallback, release idempotence, exact accounting, failed-compile retention and pressure coverage. Original39 checks retained. Independent hostile/microbenchmark274/274 and populated route10/10 retained. Required final no-pointer animation liveness passes; owned-model snapshot passes.

Adjacent tests are NOT green: samewire precision atomic50/54 on both exact unchanged HEAD and candidate, identical four failures (size-limit reject modes0/1/2 and atomic install prior-generation assertion). Save-navigation durability fails identically on unchanged baseline/candidate because its synchronous travel helper immediately saves/enters before current travel arrival completes. No checks were removed or weakened. These preexisting adjacent findings remain outside this scoped optimization.

Independent review: /root/fix_test_travel_slowdown approved literal minimal product blocks and focused tests, subject to retained baseline comparison. Product files: persistent_environment_projection.gd and run_state.gd; test inactive_storage_projection_check.gd. No diagnostic wrappers, forced Web environment flags, art changes, save-schema changes, canvas scheduling changes or pipeline pins ship.

Raw evidence remains under E:/CodexQA/BTH/runs. Hashes below preserve bounded proof artifacts, not user or secret save material.

- `test-travel-perf-rendered-host-20261115-02/evidence/worker.log` SHA256 `6b9ca99e651850f32bd0271eb71b88b4b3eedd5a5878dde150b8779529aa02ef`
- `test-travel-perf-rendered-host-20261115-02/evidence/profile.json` SHA256 `6d793cac1f36b4ba9c7c489e48c9ab925e200021d5494657de51dc46985ec456`
- `test-travel-perf-rendered-host-20261115-02/evidence/job.json` SHA256 `929fd3c3192dba17834b29eb35cece2691184e48e245b338d8bd472973d9b62a`
- `test-travel-perf-rendered-websave-20261115-01/evidence/worker.log` SHA256 `b344fa0a3d9aa660a8c6ecd2bedc7bcd5d609035476150bd17b415500b11fba3`
- `test-travel-perf-rendered-websave-20261115-01/evidence/profile.json` SHA256 `2ada61e5dab400736d98b85d80468bc0ed05cf1b879c37068876a2f8d8f97718`
- `test-travel-perf-rendered-websave-20261115-01/evidence/job.json` SHA256 `3b3267db5ba609782c745ab332b89e18a625aeb61e0800fdc57e258635c55200`
- `test-travel-perf-rendered-match-candidate-20261115-01/evidence/worker.log` SHA256 `a6b3d6accd3b817cade509d2b31339369b60f4da786d534c6b382ee31f800ffa`
- `test-travel-perf-rendered-match-candidate-20261115-01/evidence/profile.json` SHA256 `a06d94d6279b84bfaf1d762b9cfbc8b508f598e53c2d3421ecaab070d95dcd07`
- `test-travel-perf-rendered-match-candidate-20261115-01/evidence/job.json` SHA256 `6c0b08a49186bca8f34eed7a2381bab0c4c7b77d6d0865e1abf15c16b966ca06`
- `test-travel-perf-match-candidate-20261115-03/evidence/worker.log` SHA256 `f03880660a3db292c67bcf491a29624c322ca2890905e0845973a43b3d1d4883`
- `test-travel-perf-match-candidate-20261115-03/evidence/job.json` SHA256 `2dc2e68f7c697ba1c88eaa67fc5a54c0ca01c28ef0efc870da7fa4f4342d5363`
- `perf-match-pressure-20261115-01/evidence/worker.log` SHA256 `5f2223d0f07c9547b606aeb10fb479c39ebccc18ef86617ea0719e6e8bee1bd5`
- `perf-match-pressure-20261115-01/evidence/job.json` SHA256 `d62e8c08eb6b7d0b0d192adfd725d28425ac9b252ba96a087f743dd2d542a7ee`
- `perf-match-reclaim-pressure-20261115-01/evidence/worker.log` SHA256 `22fdc493ca0527221452fdcd7ae6a069e244c1c010eddf0a1a4ff84e1bd99003`
- `perf-match-reclaim-pressure-20261115-01/evidence/job.json` SHA256 `94a563e67190acefba8a1e3ae3b8b171af0e25c2bbf08a4415be9e7cf6205b79`
- `perf-match-final-contract-20261115-01/evidence/worker.log` SHA256 `9851d154ee2c2bb31b5e7312ec30bed289fd18f768b477dcda66670481704b61`
- `perf-match-final-contract-20261115-01/evidence/job.json` SHA256 `cb6457e10ddf72b483487052997a42a1ff3ac7d8d864486e13e88e90fb61965e`
- `perf-match-final-liveness-20261116-01/evidence/worker.log` SHA256 `e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b`
- `perf-match-final-liveness-20261116-01/evidence/job.json` SHA256 `54d06bd2e89f8872b2818ea5919b3d9d175baf526daf1ddb0703f84c4b3ba46b`
- `native-private-save-float-samewire-atomic-final-20261116-01/evidence/worker.log` SHA256 `1d02bbb9a5729e6e6047e926dd41f3bc183bf36ed0705603d7d7b314e1654549`
- `native-private-save-float-samewire-atomic-final-20261116-01/evidence/job.json` SHA256 `d737a27428dcd97b9d9c4024c0793d2377504ea6346606cd22b063557b81df7f`
- `native-private-save-float-samewire-atomic-base-20261116-01/evidence/worker.log` SHA256 `1d02bbb9a5729e6e6047e926dd41f3bc183bf36ed0705603d7d7b314e1654549`
- `native-private-save-float-samewire-atomic-base-20261116-01/evidence/job.json` SHA256 `741f05b4259e525f62a8c4706ffdec1f5db6defc7c192f6152d937bcfd59e586`
- `perf-match-durable-baseline-20261115-01/evidence/worker.log` SHA256 `5b42c363e5bbbe7e1fa1bb5e9db99b14ef3eef47263ec1e92b6768e204f56bab`
- `perf-match-durable-baseline-20261115-01/evidence/job.json` SHA256 `f5deb562c2786671f46c9bbda07cda99e2cce8cea1e2fc2ab8dbc09ef0c75bf1`
- `perf-match-durable-20261115-01/evidence/worker.log` SHA256 `0327eee8ee03a69de832c71c9c5de7e30c4b0da6065229c90cd9f2111453807b`
- `perf-match-durable-20261115-01/evidence/job.json` SHA256 `9a7e73e9332bea533888b6365af920037afc86797cf57e0d0e8131990f970087`

Manual reconciliation: next-bugfinder-ledger-20261116-62 reports225 objectives/54 batches,109 preexisting errors/0 warnings; no findings for this performance objective. This is not a global clean-backlog claim. All bounded jobs recorded active_at_release0; no new watcher or runtime was launched.
