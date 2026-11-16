# BTH-TEST-TRAVEL-PERF-001 shared cache-match optimization on TEST

Parent remains open. This branch applies only the reviewed two-runtime-file optimization and maintained regression from main7ce76838cec9397251aff8a1e6fc2e7d5a254992. No art assets, pipeline pins, save format, gameplay rules or animation scheduling change.

Main actual rendered native no-thread-save emulation showed immutable snapshot193.853 to157.870ms, worst sampled frame273.596 to239.199ms. Not WASM and not a complete fix of reported sustained Web slowdown. Exact original equality/numeric fallback is preserved; optional serialized receipt is budgeted and reclaimed before it can crowd out core/encoded caches.

Branch-equivalent isolated E source restored all9 previously instrumented files from exact art source before testing: inactive_storage_encoding_check95/95 plus exactJSON parity; animation_liveness_without_pointer_checkPASS. Existing main pressure36/36 and hostile274/274 retained. Main baseline/candidate samewire50/54 identical existing failures and save-navigation stale travel fixture are not claimed green.

No live browser verification. TEST publication pending following this commit; main/NEXT independently already servedca6c646f. Source branch codex/environment-art-layers; no unrelatedmain merge.

Raw evidence hashes:
- `E:/CodexQA/BTH/runs/perf-test-integration-20261116-01/evidence/source_identity.json` SHA256 `25f1962446ad92360b5d42394bfdfd9efdc248f6aa604c532be348948e16a4f4`
- `E:/CodexQA/BTH/runs/perf-test-contract-20261116-01/evidence/worker.log` SHA256 `03cdbe262c6bb8d2d24239cccaea7140b147efaeeedcac830bac0b1cbb214694`
- `E:/CodexQA/BTH/runs/perf-test-liveness-20261116-01/evidence/worker.log` SHA256 `e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b`

## Delivery receipt

TEST exact source0ef525e012df485bc3312e0d2ea89e3aa05b4d55, tree8a5724b78ab680a527e860864db89f0ad05be2c3, published by existing verified publisher. Later branch documentation commits are not claimed as exported. Current pointer and manifest match; actual HTTPS-served PCK SHA2569493981a218457dc8f678cc772f64b60173583e66d86fa389cd541d05c914f99 matches finalized artifact. TEST mount remains web_0_6_1_art_test, separate from normal saves. NEXT remainsca6c646f1170f99122efbfde9e7f7be2749ec626.

Strict PCK comparison to prior TESTcc270944 finds exactly three changed entries: bound build_manifest.json, scripts/core/persistent_environment_projection.gdc and scripts/core/run_state.gdc. No additions/removals. All421 raw art files and400 imported textures unchanged; engine/native tuple unchanged. No pipeline pins or validation checks weakened.

Actual browser startup/gameplay not run because isolated profile unavailable. Native95/95 and rendered prior controls are not Web qualification; sustained slowdown parent remains open. Owned capped jobs ended active_at_release0. First served-check attempt used absent PowerShell path and failed before execution; retry used observed installed executable, succeeded.

- `E:/CodexQA/BTH/runs/perf-test-finalize-20261116-01/evidence/pck-diff.json` SHA256 `0a025c1bfddbf122079ba86d7f050302ace8c146b5765adcf01523bf6b8bb863`
- `E:/CodexQA/BTH/runs/perf-test-publish-20261116-01/evidence/publication.json` SHA256 `8230637550f7c8dcb839606069691bbd6bfb8e6ae8becdc5a0f919b0d0fabf43`
- `E:/CodexQA/BTH/runs/perf-test-served-20261116-02/evidence/served.json` SHA256 `d7bd428dca8433cf83fb79f2197e0da70e44f453b82f1e4b4f7f12f7f0f7ca0a`
