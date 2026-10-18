# Beat the House extended packaged-platform playtest

Date: 2026-09-20  
Scope: existing Windows/Web packages, upload archives, export configuration, and package/source boundaries. No artifact was rebuilt or published, and no product or data file was modified.

## Summary

- **New confirmed defects:** `EXT-PKG-003` — production PCKs disclose internal QA reports and native toolchain metadata; `EXT-PKG-004` — a loose Windows executable in the upload directory is missing its required native Coin Pusher DLL and silently falls back to the much slower GDScript solver.
- **Previously reported and still applicable:** `PKG-001` (development packages identify as the public 0.5.1 release) and `PKG-002` (unbound Windows/Web build snapshots). They are not recounted as new defects.
- Existing Windows and Web runtime evidence continues to pass clean startup, first-run tutorial transition, asset delivery, and broad Windows scenario sweeps. Extended runtime checks are recorded below.

## New confirmed defects

### EXT-PKG-003 — Production PCKs disclose internal QA reports and native toolchain metadata

- Classification: packaging / information disclosure
- Severity: **Medium**; release blocker unless deliberately accepted
- Frequency: **100%** in all three inspected current distribution payloads: `builds/web/index.pck`, the embedded PCK in `builds/windows/BeatTheHouse.exe`, and the embedded PCK in the executable inside `builds/itch/BeatTheHouse-windows.zip`
- Reproduced twice: yes. The Web PCK was enumerated and a leaked entry was byte-validated; both independent Windows executable payloads were then enumerated and contained the same six entries.

#### Reproduction

1. Parse the Godot PCK v3 directory in `builds/web/index.pck`.
2. Observe 1,148 entries, including three `reports/` files and three `native/coin_pusher/` build-metadata files.
3. Read `reports/foundation_bar_dice_pre_fix.json` from its PCK payload offset. Its SHA-256, `1e917b143986f976f6d2aecb652481d91808a09735ab93726df244d3f9aad695`, exactly matches the repository's internal report.
4. Parse the embedded PCK directories in the current Windows executable and in the archived Windows executable. Each has 1,076 entries and the identical six leaked files.

#### Leaked package entries

| Entry | Bytes | Exposure |
| --- | ---: | --- |
| `native/coin_pusher/build_profile.json` | 64 | Native build-profile settings |
| `native/coin_pusher/godot_web_release_build_profile.json` | 1,714 | Web release toolchain profile |
| `native/coin_pusher/toolchain.lock.json` | 2,742 | Exact compiler versions, upstream commits, archive URLs, and hashes |
| `reports/foundation_bar_dice_post_fix.json` | 576 | Internal fix-validation record |
| `reports/foundation_bar_dice_pre_fix.json` | 678 | Historical internal failure details |
| `reports/gdscript_load_check_blackjack_web.json` | 9,420 | Internal source/test/tool inventory (192 paths) |

The six files total 15,194 bytes per package. No credential, private key, or player data was found, but the reports disclose historical failure details (including Grand Casino persistence and Bar Dice stake-dispatch failures) and the toolchain files expose unnecessary development metadata.

#### Root cause

- `export_presets.cfg:8` and `export_presets.cfg:110` use `export_filter="all_resources"` for Windows and Web.
- The exclusion lists at `export_presets.cfg:10` and `export_presets.cfg:112` omit `reports/*`, `reports/**`, `native/*`, and `native/**`.
- `tools/export_itch.ps1:94-107` checks loose output files only for five player-save filenames. It never audits the packed directory or rejects development-only prefixes.
- `tools/export_itch.ps1:243-244` runs that narrow clean-output check and the native-library presence check, so a package can pass export validation while still containing internal reports and build metadata.

#### Player/operator impact

- Public packages expose internal failure history and implementation/toolchain details that players do not need.
- The leaked path inventory makes repository structure and test surface easier to map.
- The issue undermines the clean-distribution guarantee even though it does not expose save files.

#### Fix options (not implemented)

1. Exclude `reports/*`, `reports/**`, and native source/build metadata while explicitly retaining only the compiled native side libraries and the required `.gdextension` descriptor.
2. Add a post-export PCK manifest audit that rejects development-only prefixes and unexpected file types.
3. Keep the existing save-file check, but extend the release manifest policy to cover reports, toolchain locks, logs, test outputs, and credentials/secrets.

### EXT-PKG-004 — Loose itch Windows executable is missing its required native Coin Pusher DLL

- Classification: packaging / runtime dependency failure
- Severity: **High** for anyone using the loose executable; **Medium** repository/release-custody risk because the correct upload ZIP contains the DLL
- Frequency: **100%**, two complete isolated-profile runs
- Affected artifact: `builds/itch/BeatTheHouse.exe` (171,994,584 bytes; SHA-256 `1B3796FF37286B327753CA1134725BB481E3308D8A8521F24186CB44AC033F49`)

#### Reproduction

1. Launch the loose executable from `builds/itch` without copying in files from another build folder.
2. Run the packaged `coin_pusher` telemetry plan with a fresh isolated distribution profile.
3. Observe four startup errors: two failed dynamic-library opens, `GDExtension dynamic library not found`, and `Error loading extension`.
4. Observe every Coin Pusher scenario reporting `solver_backend="gdscript_v3"` instead of the required `native_v3`.
5. Repeat with another isolated profile. The dependency errors and fallback reproduce exactly.

| Artifact/run | Backend | Raw 300-body contract | Raw solver tick p95 |
| --- | --- | --- | ---: |
| Current `builds/windows` package | `native_v3` | observed | 4.315 ms |
| Loose itch EXE, run 1 | `gdscript_v3` | **not observed** | 40.265 ms |
| Loose itch EXE, run 2 | `gdscript_v3` | **not observed** | 40.944 ms |

The fallback is approximately 9.4 times slower at this stress boundary. The game remains able to execute the plan, which makes this especially easy to miss: it degrades rather than failing closed. The authored ceiling-refusal contract also reports `observed=false` in both loose-EXE runs because the required native backend is absent.

#### Root cause

- The embedded `addons/coin_pusher_native/coin_pusher_native.gdextension` descriptor points Windows release builds to the external file `res://addons/coin_pusher_native/bin/coin_pusher_native_v3_10.windows.template_release.x86_64.nothreads.dll`.
- `builds/itch` contains the loose executable but no adjacent DLL. Godot therefore cannot load `CoinPusherNativeCore`, and `scripts/games/coin_pusher/coin_pusher_solver.gd:460-470,558-564` deliberately falls back to `gdscript_v3` when that class is unavailable.
- `tools/export_itch.ps1:163-179` correctly rejects the current Windows output directory unless exactly one native DLL exists.
- However, `tools/export_itch.ps1:182-193,251-256` packages from `builds/windows` into a named ZIP and only replaces that ZIP in `builds/itch`; it does not clean or quarantine stale loose distribution-like artifacts already in the upload directory.

#### Player/operator impact

- Double-clicking or sharing this apparently complete, 0.5.1-labelled executable produces a degraded build with startup errors.
- Coin Pusher runs without the required native solver and misses the production performance contract by roughly an order of magnitude under the 300-body fixture.
- A tester could unknowingly validate the wrong backend because gameplay falls back instead of stopping with a player-visible dependency failure.

#### Fix options (not implemented)

1. Remove or quarantine loose executable residue from `builds/itch`; allow only the named upload archives (and an explicit manifest) in that directory.
2. Add a preflight that audits the distribution directory for executable-looking artifacts not owned by the current package operation.
3. If a standalone folder is intentionally produced, copy the executable and DLL together and validate the exact pair by launching the Coin Pusher native-backend contract.
4. Make distribution builds fail clearly when a required native extension is absent rather than silently shipping the GDScript fallback.

## Previously reported defects, not recounted

- `PKG-001`: the tested 0.6-development artifacts display and stamp `0.5.1`, the immutable public-release identity, and embed no trustworthy source candidate manifest.
- `PKG-002`: the current Windows folder, Windows upload ZIP, loose itch executable, and Web folder are different build snapshots with no common candidate binding.

Both remain release blockers. Their reproductions, artifact hashes, and root causes are in `reports/playtest_2026-09-20/packaged_platform.md`.

## Extended runtime and boundary checks

### Passed

- The Windows distribution executable completed two clean-profile launches, reached the first tutorial from `PLAY`, loaded all required content, wrote no stderr, and closed normally.
- Two packaged Windows L0.2 sweeps completed 64 scenarios each across the main menu, meta home, Corner Store, all eleven game families, travel, audio idle, and scripted long-play memory.
- A one-off Roulette draw p95 of 5.075 ms against a 5.0 ms budget did not reproduce (3.212 ms on the complete repeat) and remains excluded as measurement noise.
- The Web package booted under a production-compatible local server with the required COOP/COEP headers, removed the loading overlay, drew the main menu, and reached the Apartment tutorial through `PLAY` without a console warning or error.
- Every requested Web runtime resource returned HTTP 200, including the main PCK/WASM, side WASM, icon, audio worklets, and native Coin Pusher WASM.
- The Web upload ZIP's 11 distributable entries are byte-identical to the corresponding current `builds/web` files. Godot `.import` sidecars are correctly absent.
- The current and archived Windows native Coin Pusher DLLs are byte-identical.
- The Web PCK contains only the Web audio variants; no desktop music/SFX payload was found.
- Window resizing is intentionally disabled in `scripts/core/user_settings.gd:223-250`; windowed, exclusive-fullscreen, and borderless modes are explicit supported settings rather than an accidental resize failure.

### Excluded / limitations

- Browser `file://` launch is not a supported deployment mode for this Godot Web build; local HTTP with cross-origin isolation is the supported offline-development boundary and passed.
- The Web export is not configured as a PWA, so post-install offline caching was not treated as a requirement.
- A Windows graphics-control helper could not attach to the game window because it reported inconsistent window ownership. Process responsiveness, package telemetry, normal launch, and normal window close were verified independently; the helper failure is not counted as a game defect.

## Evidence

- `.tmp/playtest_extended/packaged_platform/pck_leak_manifest.md`
- `.tmp/playtest_extended/packaged_platform/current_windows_coin_pusher_1.json`
- `.tmp/playtest_extended/packaged_platform/loose_itch_coin_pusher_1.json`
- `.tmp/playtest_extended/packaged_platform/loose_itch_coin_pusher_1.stderr.txt`
- `.tmp/playtest_extended/packaged_platform/loose_itch_coin_pusher_2.json`
- `.tmp/playtest_extended/packaged_platform/loose_itch_coin_pusher_2.stderr.txt`
- `.tmp/playtest_2026-09-20/packaged_platform/integrity/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_dist_1/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_dist_2/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_l02/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_l02_repro/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_visual/`
- `.tmp/playtest_2026-09-20/packaged_platform/web_runtime/`

No bug was fixed.
