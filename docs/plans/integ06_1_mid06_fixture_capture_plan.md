# integ06_1 mid-0.6 historical fixture capture plan

Status: **READY TO RUN — no owner-authored mid-0.6 saves were found**

This plan closes the constructible half of the mid-0.6 migration requirement
without relabeling generated validation output as player evidence. The fixtures
are produced by the historical `FoundationMain` and `SaveService` after only
player-reachable actions. Each sidecar identifies the historical commit, tree,
main-scene blob, FoundationMain blob, SaveService blob, capture-driver hash,
save hash, seed, and exact public action trace.

## Exhaustive recovery result

The recovery pass inspected every local and remote ref head, every registered
worktree, `D:\bth-0.6-integrated-copy`, `stash@{0}`, and all 112 unreachable
commits reported by `git fsck --unreachable --no-reflogs`. No owner-authored
mid-0.6 save inventory was present. The matching files were limited to:

- the admitted v0.5.1 fixtures under
  `scripts/tests/fixtures/integ06_1/v0_5_1`;
- historical 0.3 test fixtures; and
- harness-generated files under validation `user_data/.../saves` directories.

The repository also contained 2,484 unreachable blob objects. Searching each
blob in a new process was not a bounded operation, so those bare blobs were not
promoted as evidence. Every unreachable commit was searched; none contained an
owner save. The lone stash contains only an earlier, superseded edit of the
historical fixture driver.

## Reviewed capture boundaries

| Milestone | Historical commit | Why this exact tree | Player-reachable state |
|---|---|---|---|
| pre-game-depth | `31e434c412ba8bdeda03bee86db1f8b4d899c962` | first parent of accepted game ritual merge `5a2b1e1a6782a13308585e1a974adeeb86be0647` | seed `INTEG06-1-MID06-PRE-GAME-009`; travel by its generated public route to Gas Station Casino, open its generated Slot, execute a public spin, and require persisted `spin_count >= 1` plus a result |
| pre-environment-depth | `5a2b1e1a6782a13308585e1a974adeeb86be0647` | first parent of accepted dynamic-scenario merge `03fee92d4fa63b7eeb60833fe9649a84fae48816` | travel through Motel to Bar, publicly roll and settle Bar Dice, and require persisted `rounds_played >= 1` plus a result |
| pre-world-depth | `f1ebe9a729253e4ee3d4d99702a019d9328edbaf` | first parent of accepted world-adapter merge `95c6aaf502087eed21f8970a1f244a6196ef6b56` | seed `INTEG06-1-MID06-PRE-GAME-009`; travel through the public Gas Station tip route to the Crew lender and accept its real loan, preserving active Crew debt at Corner Store before the world adapters existed |

All three commits genuinely retain `config/version="0.5.1"` in their own
`project.godot`. The milestone and exact commit/tree hashes, rather than that
unchanged marketing version string, identify these mid-0.6 development
boundaries. They are not described as owner builds.

## Capture command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/integ06_1_generate_mid06_fixtures.ps1 `
  -OutputDirectory scripts/tests/fixtures/integ06_1/mid_0_6 `
  -CaptureTimeoutSeconds 180 `
  -KeepHistoricalArchive
```

`tools/integ06_1_generate_mid06_fixtures.ps1` rejects every commit outside the
three reviewed boundaries. Its shared generator archives the historical runtime
closure, imports it into a clean data root, injects the hash-recorded driver,
runs each case independently, and copies only the historical SaveService output
and provenance sidecar into the fixture directory. With
`-KeepHistoricalArchive`, every temporary custody directory is preserved and
its complete file path/size/SHA-256 inventory is written inside that directory;
the fixture sidecar records the custody path and inventory hash.

After capture, run the final-candidate migration driver against all three files,
assert legal/playable state plus promised 0.6 migrations, resave each through
the final SaveService, reload, and require stable normalized state. Until that
command has run and the generated files have passed the final-candidate matrix,
mid-0.6 migration remains **NOT PROVEN**.
