# Art TEST storage isolation acceptance

Status: PASS for internal storage isolation only. Current-art acceptance and TEST publication remain pending.

Source11a82efb626d7eba1eac2e3f684a83ec9bd17660 contains TEST safety commit a74a270715cfc8d9dfa0cf33305d8f706289d0e2. The safety artifact deliberately uses a historical, superseded art checkpoint and must not be published.

## Actual browser evidence

- Exported distribution game booted at1280x720 and1600x900 with no Godot/page errors.
- The actual IDBFS database is /userfs/godot/app_userdata/Beat the House/distribution/web_0_6_1_art_test. The ordinary /userfs database is not mounted by TEST.
- A real gameplay autosave was created, then an X-Ray Glasses pickup persisted through two reloads and Continue. Inventory visibly retained one item.
- Exact autosave SHA256 across reloads: f125acfd67d4ad7719519efff55814373a685872720664ab1a22deea317893d0.
- A synthetic normal /userfs sentinel, all normal records, version21 schema and timestamp index remained byte/canonically unchanged. Normal canonical digest remained f208a52699885fa278f040e94db33fe9a8ccead8eaab429dcded76b66737cdd1. Fully instrumented gameplay/reload/Continue phases observed zero normal readwrite transactions.
- Only fresh owned E: profiles and fake saves were used. No personal profiles/saves were read, copied or migrated.

Test HTML SHA2563f28ce07797df999a8339b1634a79eb1aa720f2598d4f48b0fd87d64e9b7fc69. PCK SHA256fd09ed763f5f505f982fdf3f5b1b143e9135d9ba5bd3354914177e27fab54bc1. The ordinary-root export HTML was moved outside the served QA directory before boot. Existing WebGL mitigation and PCK manifest checks passed.

## Resource and diagnostic limits

Every actual worker retained assignment-before-resume,12% aggregate CPU and configured2,147,483,648-byte aggregate Job memory limit, kill-on-close enabled and breakaway disabled. Browser aggregate peak was2,214,346,752 bytes. The unexplained66,863,104-byte peak overshoot is retained as a resource observation; this does not establish cap-enforcement failure and no cap was raised. Chromium also logged a startup network-service restart.

After successful proof and close requests, remaining owned browser/server processes were terminated and drained to0 with no cleanup errors. Their final exit1 is owned termination, not a normal browser exit0. Separate bounded diagnostics retain an installed-Chrome debugging refusal, an unintended nested-wrapper timeout, and one reload-observer loss corrected by a fully instrumented second reload. None is hidden as a passing test.

Original report SHA256e41afd54677582c7533a09c8a18c7e06a8d660fe47fd063e5f331f69be8a9988. Evidence campaign BTH-ENVART-STORAGE03; detailed save/reload/Continue probes5,7,8,9 and viewport/final probes10,11. Original report and receipts remain in admitted E: QA evidence.

This proof accepts the unchanged TEST root/launcher behavior. Before release, build the latest exact audited art commit, verify served TEST bytes and visible composition, and retain the separate persistent mount. Main/NEXT and current site audience remain unchanged.

Manual reconciliation after storage acceptance:0 current assigned-scope findings;1524 retained historical/global findings. Reconciliation SHA2560bb862b5239f66cb2a468efe0e8e83444c1694445debf8e6b8ce58b6addfa204. New source/core behavior is unchanged from the already-passed13 Godot core checks and234 Python suite.
