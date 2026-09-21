# Beat the House packaged-platform playtest report

Date: 2026-09-20  
Tester: packaged-platform wave-two specialist  
Scope: existing `builds/windows`, `builds/web`, and upload archives under `builds/itch`; no rebuild, publish, or product-file modification

## Result summary

- Confirmed player-facing runtime defects in the tested Windows executable: **0**.
- Confirmed player-facing runtime defects in the tested Web directory: **0** during startup and the fresh-profile `PLAY` transition.
- Confirmed packaging/release defects: **2** (`PKG-001`, `PKG-002`). These are release/configuration findings, not current-source gameplay bugs.
- Windows clean-profile startup passed twice. The production executable opened the first-run tutorial, loaded all required content with zero validation errors, emitted no stderr, and shut down normally.
- Two Windows L0.2 package runs each completed 64 production telemetry scenarios across the menu, meta home, Corner Store, audio idle, all eleven game families, world map, and scripted long-play memory coverage. No runtime error was emitted. One Roulette post-spin draw sample exceeded the 5.0 ms native phase budget by 0.075 ms on the first run, then measured 3.212 ms on the complete repeat; it is not reproducible and is excluded as noise.
- The Web package served with the required COOP/COEP headers, removed its loading overlay, rendered its 1280 x 720 CSS canvas, produced no browser warning/error, accepted `PLAY`, and reached the first Apartment tutorial scene.
- Both platforms include exactly one native Coin Pusher side library. The current Windows and archived Windows native DLLs are byte-identical.

## Build identity under test

The repository documents `v0.5.1` as the immutable published release and current `main` as unreleased 0.6 development. The files tested here are local 0.6 playtest/export residues; they are **not** the published 0.5.1 artifacts and are not a release candidate.

| Artifact | Modified | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `builds/windows/BeatTheHouse.exe` | 2026-09-19 09:52 local | 172,034,040 | `2B1516E7E241C75B0DD5EDE10C15540C365B44F20846AB54BD88828276DF3199` |
| EXE inside `builds/itch/BeatTheHouse-windows.zip` | 2026-09-18 19:37 local | 171,998,344 | `3F2A059EDDBE148AEA6A150810257CD030511FAEB5686E3CA696DAB2401B8A89` |
| Loose `builds/itch/BeatTheHouse.exe` | 2026-09-18 18:00 local | 171,994,584 | `1B3796FF37286B327753CA1134725BB481E3308D8A8521F24186CB44AC033F49` |
| `builds/itch/BeatTheHouse-windows.zip` | 2026-09-18 19:37 local | 85,173,775 | `CB2C9DD36834B60985AA1DA8F73AB7F82DD8781D956AC49A1153FA22F02B7EB6` |
| `builds/itch/BeatTheHouse-web.zip` | 2026-09-17 20:18 local | 41,454,438 | `E6F9B12516F10FF21ED454AD338456DB2D5F04D6284063D1A11AB0D988A3C714` |
| `builds/web/index.pck` | 2026-09-17 20:18 local | 44,916,556 | `E7D1EF2B44799627284149B04038273D7A0D9222764C16AA9CAAEE52674DE33C` |
| Windows native Coin Pusher DLL | current and archived | 901,120 | `AB3E74AD695DD9E6527D05CF09370B56A7B3B80168724862757DE7711D837D69` |

For comparison, the immutable published 0.5.1 checklist records Web ZIP `4D137AB0...BF51` at 41,662,231 bytes and Windows ZIP `CE6E1531...6186` at 81,734,381 bytes. None of the local artifacts above matches those published files.

## Confirmed findings

### PKG-001 — Unreleased 0.6 packages identify themselves as published Version 0.5.1 and carry no embedded source identity

- Classification: packaging/release identity; do not count as a current-source gameplay bug.
- Severity: **High / release blocker**. If any tested local artifact is handed to a player or uploaded, its visible and operating-system identity collides with an immutable public release while its content is materially newer and different.
- Frequency: **100%** on all three inspected Windows executables and the tested Web start menu.
- Reproduction:
  1. Inspect the Windows file/product version of `builds/windows/BeatTheHouse.exe`, the EXE inside the Windows upload ZIP, or the loose itch EXE. Each reports `0.5.1`.
  2. Open `builds/web/index.html` through the production-compatible local server. The lower-right start-menu copy visibly says `Version 0.5.1`.
  3. Compare hashes and sizes with `docs/plans/0.5.1_release_checklist.md`; neither local upload ZIP matches the immutable published 0.5.1 artifact.
  4. Search the packages for a commit/tree/candidate manifest. No artifact-owned commit identity is present; performance telemetry accepts a caller-provided `bth_perf_source_commit`, so it cannot independently prove which source was exported.
- Player/operator impact:
  - Bug reports and saves cannot be reliably attributed to a source boundary.
  - A local 0.6 playtest build can be mistaken for the published 0.5.1 release in screenshots, Windows Properties, or an upload channel.
  - Support cannot distinguish the three different Windows binaries because all share the same product/version identity.
- Root cause:
  - `project.godot:19` holds `config/version="0.5.1"` for the unreleased development line.
  - `export_presets.cfg:26-27` stamps the Windows file and product versions as `0.5.1`.
  - `scripts/ui/foundation_main.gd:17384-17389` renders that project setting directly as the player-visible version.
  - `tools/export_itch.ps1:46-52,194` reads the same value, and its packaging phase records a console hash but does not place a source/version manifest inside the artifact.
  - The README says the retained 0.5.1 stamp is intentional until `release06_1`; the defect arises because runnable/exported 0.6 artifacts exist without an equally visible development identity or a packaging guard.
- Fix options (not implemented):
  1. Stamp playtest exports as `0.6.0-dev+<short-commit>` and display that identity in the menu while preserving the published release tag.
  2. Embed a machine-readable manifest containing version, commit, tree, dirty-state digest, engine hash, export-preset hash, platform, and native-library hash; make telemetry read it rather than trusting a caller string.
  3. Refuse packaging/upload when the version equals an immutable published tag but the exact source tree and artifact hashes do not match that tag's release record.

### PKG-002 — The Windows upload ZIP, loose itch executable, current Windows folder, and Web folder are different unbound build snapshots

- Classification: package custody/platform skew; do not count as a current-source gameplay bug.
- Severity: **High / release blocker** for distribution, **Medium** for internal playtesting.
- Frequency: **100%** of integrity comparisons.
- Reproduction:
  1. Extract `builds/itch/BeatTheHouse-windows.zip` and hash its executable.
  2. Hash `builds/windows/BeatTheHouse.exe` and `builds/itch/BeatTheHouse.exe`.
  3. Observe three different sizes and SHA-256 values, even though all claim Version 0.5.1.
  4. The Web PCK is dated 2026-09-17 while the current Windows executable is dated 2026-09-19. Eighteen commits have commit timestamps after the Web PCK and seven after the current Windows EXE. Because no embedded manifest exists, the exact included boundary cannot be proven.
  5. The archive's native Coin Pusher DLL does match the current Windows DLL, demonstrating that a matching dependency does not establish a matching game payload.
- Player/operator impact:
  - Uploading `BeatTheHouse-windows.zip` would not distribute the executable that was just smoke-tested from `builds/windows`.
  - Web and Windows test notes may describe different code, including fixes committed between their timestamps (tutorial flow, frozen Pinball/Coin Pusher sessions, travel recovery, casino interactions, Blackjack settlement, scenario-save recovery, and later performance work).
  - A pass on one platform cannot qualify the other artifact.
- Root cause:
  - `builds/` is ignored at `.gitignore:19`, so multiple opaque products persist outside source control and custody review.
  - `tools/export_itch.ps1:252-258` archives the current output directory but does not require an artifact manifest, compare the resulting archive payload back to a named candidate, or quarantine older loose executables.
  - Exporting Windows and Web is independent; no common-candidate assertion binds the two directories and ZIPs as a release pair.
- Fix options (not implemented):
  1. Export both platforms into a new versioned staging directory keyed by commit/tree, then package only from that immutable staging root.
  2. Generate and verify a cross-platform manifest; require the same candidate commit/tree in both products and compare every archived file hash with the staged directory before upload.
  3. Remove loose ambiguous executables from the upload directory and name internal artifacts with version, platform, and short commit. Keep only one candidate set at a time or quarantine superseded builds.

## Runtime evidence

### Windows clean-profile startup (two runs)

Production path: existing `builds/windows/BeatTheHouse.exe`, `distribution_build` behavior, isolated `BTH_DISTRIBUTION_DATA_ROOT`, compatibility renderer, package-owned `distribution_fresh_start` plan.

| Run | Fresh profile | PLAY ready | Tutorial started | PLAY to tutorial | Content validation | stderr |
| --- | --- | --- | --- | ---: | ---: | ---: |
| `windows_dist_1` | yes | yes | yes | 2,955 ms | 0 errors / 0 warnings | 0 bytes |
| `windows_dist_2` | yes | yes | yes | 2,787 ms | 0 errors / 0 warnings | 0 bytes |

The package loaded 18 environment archetypes, 11 games, 88 items, 159 events, 46 characters, 32 dialogues, 66 tutorial lessons, and all other required packs. A separate normal headed launch exposed a responsive `Beat the House` window and closed cleanly through `CloseMainWindow`; force termination was not required and stderr remained empty.

### Windows broad packaged L0.2 (two runs)

- Each run completed 64 scenarios, including every casino/table family, Pinball feature play, Slot autoplay, world map, room transition, audio quiet idle, and scripted long-play memory.
- Both runs emitted zero stderr and zero content-validation errors.
- The first run's only current-budget miss was Roulette `post_spin` draw p95 5.075 ms versus 5.0 ms. The complete repeat measured 3.212 ms; no defect is filed.
- Representative first-run values: Blackjack active frame p95 22.580 ms; Bar Dice active 11.402 ms; Video Poker active 15.233 ms; Pinball feature session 15.979 ms; scripted long-play memory 6.944 ms.

### Web package smoke

- Served `builds/web` at `http://127.0.0.1:18733/` with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.
- Loading overlay was removed after startup; browser console contained no warnings or errors.
- Canvas CSS size was 1280 x 720; backing size was 1600 x 900 under the browser's 1.25 device scale.
- Main menu was visually complete and showed `Version 0.5.1`.
- Clicking `PLAY` reached Day 1, 12:00 PM, in the Apartment tutorial with Pal's coach prompt and interactive room objects visible. No console warning/error appeared.
- The package includes `coin_pusher_native_v3_10.web.template_release.wasm32.nothreads.wasm`; the successful engine start produced no extension-load error. Direct Web Coin Pusher behavioral play was not completed in this short custody check.

## Archive and dependency integrity passes

- Both upload ZIPs expanded successfully.
- The Web ZIP contains 11 root distributable files and is byte-for-byte identical to the corresponding current `builds/web` distributable files. Three Godot `.import` sidecars exist only in the working output and are correctly absent from the ZIP.
- The Windows ZIP contains exactly the executable and one native Coin Pusher DLL.
- No ZIP entry is a player save, profile, settings file, test, tool, documentation tree, or temporary file.
- Windows and Web exports both declare `distribution_build`.
- Native solver inventory is present on both target platforms.
- All Windows binaries are unsigned, matching `export_presets.cfg` (`codesign/enable=false`). This is a distribution trust/reputation risk but was not counted as a bug because signing is explicitly disabled and no signing requirement was supplied for this playtest build.

## Exclusions and non-bugs

- The published 0.5.1 release itself was not downloaded or retested; its recorded hashes are used only as an identity comparison.
- The tested local packages are not treated as evidence about current dirty source gameplay. Their missing source manifests prevent exact attribution.
- Known fixes committed after artifact timestamps are not counted as reproduced package gameplay bugs unless observed directly. The Web smoke did not attempt save/resume Pinball, Punchline layer entry, late scenario saves, or extended Coin Pusher play.
- Windows graphics-control attachment returned an inconsistent ownership error even though Windows reported the game window as responsive. Normal launch/close and headless production-runtime evidence completed; the helper failure is not a game defect.
- The transient 0.075 ms Roulette budget edge failed to reproduce and is excluded.

## Evidence paths

- `.tmp/playtest_2026-09-20/packaged_platform/integrity/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_dist_1/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_dist_2/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_l02/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_l02_repro/`
- `.tmp/playtest_2026-09-20/packaged_platform/windows_visual/`
- `.tmp/playtest_2026-09-20/packaged_platform/web_runtime/`

No game, data, export, or tracked source file was modified, and no bug was fixed.
