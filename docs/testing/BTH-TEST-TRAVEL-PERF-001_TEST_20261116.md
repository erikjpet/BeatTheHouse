# BTH-TEST-TRAVEL-PERF-001 shared cache-match optimization on TEST

Parent remains open. This branch applies only the reviewed two-runtime-file optimization and maintained regression from main7ce76838cec9397251aff8a1e6fc2e7d5a254992. No art assets, pipeline pins, save format, gameplay rules or animation scheduling change.

Main actual rendered native no-thread-save emulation showed immutable snapshot193.853 to157.870ms, worst sampled frame273.596 to239.199ms. Not WASM and not a complete fix of reported sustained Web slowdown. Exact original equality/numeric fallback is preserved; optional serialized receipt is budgeted and reclaimed before it can crowd out core/encoded caches.

Branch-equivalent isolated E source restored all9 previously instrumented files from exact art source before testing: inactive_storage_encoding_check95/95 plus exactJSON parity; animation_liveness_without_pointer_checkPASS. Existing main pressure36/36 and hostile274/274 retained. Main baseline/candidate samewire50/54 identical existing failures and save-navigation stale travel fixture are not claimed green.

No live browser verification. TEST publication pending following this commit; main/NEXT independently already servedca6c646f. Source branch codex/environment-art-layers; no unrelatedmain merge.

Raw evidence hashes:
- `E:/CodexQA/BTH/runs/perf-test-integration-20261116-01/evidence/source_identity.json` SHA256 `25f1962446ad92360b5d42394bfdfd9efdc248f6aa604c532be348948e16a4f4`
- `E:/CodexQA/BTH/runs/perf-test-contract-20261116-01/evidence/worker.log` SHA256 `03cdbe262c6bb8d2d24239cccaea7140b147efaeeedcac830bac0b1cbb214694`
- `E:/CodexQA/BTH/runs/perf-test-liveness-20261116-01/evidence/worker.log` SHA256 `e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b`
