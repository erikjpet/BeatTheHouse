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
