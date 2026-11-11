# Beat the House 0.6.1 — pre-release audit and work orders

Audit date: 2026-11-10
Audited source: `main` at `85d38b96a3c2b1d47020dd6e5a6c4bb12605ca0f`
Compared against: `v0.6.0` (`a095414b`) and `v0.6.1-pre.1` (`b2a9cef8`)
Engine: Godot 4.6-stable (`89cea1439`)

This document was written for hand-off to a worker agent. It changes nothing in
the repository. Every item is a self-contained work order: what is wrong, where,
why it matters to a player, what to change and why, what to test, and when it
counts as done. All file and line references are valid for the audited commit
above; if `main` has moved, re-locate by the quoted code or function name.

---

## 0. How to use this document

### Owner decisions (2026-11-11) — read these first

1. **Save data does not need to be preserved.** The game is in active
   development. Carrying saves, settings or home progression from one version
   to the next is not a goal, and neither is protecting an in-progress run
   from being replaced. This overrides the original severity of several items.
   The Index and each item's severity line carry the current ranking.
2. **Reproduce before fixing.** No finding here was confirmed at runtime. The
   worker reproduces each one first, and reports back instead of changing code
   if it does not reproduce.

What decision 1 changes:

| Item | Before | Now | What is left to do |
| --- | --- | --- | --- |
| AUD061-13 Web save folder move | Blocker | **Closed — reset accepted** | No migration. Optional one-line release note. Ignore the "Change required if migrating" steps. |
| AUD061-06 0.6.0 save fixtures | Blocker | **Dropped** | Nothing. Do not capture 0.6.0 saves or add upgrade tests. |
| AUD061-07 Save version check | High | **Dropped** | Nothing for now. |
| AUD061-15 Crew key / portability | Medium | **Low** | Only item 2 (repair a wrong-sized key file). Skip the rest. |
| AUD061-03 Perf harness | Blocker | **Low, deferred** | After 0.6.1. Needs an opt-in marker, because the perf tooling itself runs plans on distribution exports. |
| AUD061-08 Flush on tab close | High | **Low** | Optional. |
| AUD061-14 Ignored save results | Medium | **Low** | Optional. |
| QOL-01 New-run confirm | Medium | **Low** | Optional. |
| `BTH061-012` (in AUD061-17) | Gate | **Not a gate** | Skip the 0.6-save compatibility half; final packaging still applies. |

What it does **not** change: AUD061-01 and AUD061-02 stay. They are not about
keeping old data. They are about the game ceasing to save at all and then
refusing to close, which blocks testing and play regardless of how disposable
the data is. With save data disposable, the right fix for 01 is the simple
one: delete stale rollback files and carry on.

### Verdict

**0.6.1 is not ready to tag, but the list is short.** Three items block the
tag: the game cannot be closed while a save fails (AUD061-02), the version
stamps still read 0.6.0 (AUD061-04), and the pre-release tag is not the
candidate (AUD061-05). AUD061-01 should be fixed with 02. After that it is
qualification work (AUD061-11, -12, -17). Part B is small fixes. Part C is
structural work for after the release. Part D lists what was checked and found
clean. Part F is quality of life.

### Is this everything the game needs?

No single document can claim that, and this one does not. Be clear with the
worker about what it is:

- **Complete for:** save and exit safety, release identity, shipping-build
  gates, Web data continuity, and code-structure health. These were read end
  to end.
- **Partial for quality of life:** Part F comes from a static read of menus,
  settings, messages and input handling. Nobody played the build for this
  audit, so feel, pacing, readability and layout problems that only show up in
  play are not in here. The project's own playtest gates (AUD061-17) are where
  those get found.
- **Not covered:** game-rule and payout correctness, balance, art, audio mix,
  scenario and item content (the last two are under the user pause).

### What this audit did and did not do

Done:

- Read end to end: `save_service.gd`, `durable_store.gd`, `run_save_codec.gd`,
  `web_save_durability_bridge.gd`, `persistence_paths.gd`, `rng_stream.gd`,
  `build_identity.gd`, `crew_turn_model.gd` (private save), and the lifecycle,
  exit, autosave and Main Menu paths in `foundation_main.gd`.
- Diffed runtime code and data against `v0.6.0` and `v0.6.1-pre.1`.
- Scanned all 224 production scripts (234,854 lines) for metrics, global RNG
  use, unchecked file opens, per-frame deep copies and ignored save results.
- Parsed every `data/**/*.json` and checked sibling lists for duplicate ids.
- Ran `gdlint` over `scripts/core`, `scripts/ui`, `scripts/games`.
- Ran `python -m unittest discover -s tools/tests` and the documented ledger
  reconciliation command.

Not done — treat these as open:

- **No Godot runtime check was executed.** Running the engine binary was
  refused in the audit sandbox. The Smoke suite, the animation-liveness check
  and runtime reproduction of every finding were not run. Findings are from
  reading the code. **Each work order's first step is to reproduce it.**
- No Windows or Web export was built.
- Game-rule and payout correctness were only spot-checked (Roulette straight
  35:1, Baccarat banker commission, Blackjack 3:2 with whole-dollar floor all
  read as intended). The eleven game modules were not audited line by line.
- Rendering and canvas code, the scenario engine, Crew and delivery systems,
  the world map and the native Coin Pusher C++ were not reviewed beyond
  metrics and the specific lines cited.

### Rules the worker must follow (from `AGENTS.md`)

1. Before implementing any item, register its ID in
   `docs/todo/bth_task_ledger.json` and in the named ledger in
   `docs/plans/0.6.1_stability_release_plan.md`. The `AUD061-*` IDs below are
   stable and can be used as-is. Keep parent objective and implementation
   batch separate; a finished batch does not close its parent.
2. Never mark an item Complete without an associated commit and its acceptance
   evidence. Run the reconciliation command in
   `docs/todo/bth_task_ledger_checks.md` at each checkpoint.
3. Do not disable canvas processing, remove autonomous redraws, or tie redraws
   to input. After touching canvas scheduling or performance code, run
   `godot --headless --path . --script res://scripts/tests/animation_liveness_without_pointer_check.gd`.
4. New QA workspaces go through `tools/bth_qa_storage.py` and
   `tools/bth_qa_guarded_run.py` on the approved non-C volume.
5. Item and scenario work is under a user-requested pause. Nothing in this
   document asks for item or scenario changes.

### Severity scale

| Level | Meaning |
| --- | --- |
| **Blocker** | Must be fixed or explicitly decided before `v0.6.1` is tagged. |
| **High** | Real player-facing risk; fix in 0.6.1 unless it destabilises the RC. |
| **Medium** | Worth fixing in 0.6.1 if cheap; otherwise first patch after. |
| **Low** | Hygiene. Schedule freely. |

### Index

| ID | Sev | Area | One-line summary | Effort |
| --- | --- | --- | --- | --- |
| AUD061-01 | High | Persistence | Leftover `.rollback` file blocks all later saves permanently | S |
| AUD061-02 | Blocker | Exit path | Game cannot be closed while a save fails | S |
| AUD061-03 | Low (deferred) | Shipping gates | Performance harness reachable in shipped builds | M |
| AUD061-13 | Closed | Web persistence | 0.6.1 Web build moves the save folder — reset accepted by owner | — |
| AUD061-04 | Blocker | Release identity | Version stamps still read 0.6.0 everywhere | S |
| AUD061-05 | Blocker | Release identity | Pre-release tag is not the candidate; changelog incomplete | S |
| AUD061-06 | Dropped | Compatibility | No save fixture from the published 0.6.0 build — not needed | — |
| AUD061-07 | Dropped | Persistence | Save/codec version never checked on load — not needed now | — |
| AUD061-08 | Low | Lifecycle | No save flush on background, tab hide or tab close | S |
| AUD061-09 | Medium | Persistence | Explicit Save reports an older save's failure without trying | S |
| AUD061-14 | Low | Persistence | Six call sites ignore a failed profile/meta/settings save | S |
| AUD061-10 | Low | Economy | Crew heist payouts bypass `change_bankroll` | S |
| AUD061-15 | Low | Crew save | Private capsule key: repair a wrong-sized key file only | S |
| AUD061-16 | Low | Shipping gates | Test-only fault switches live in shipping classes | S |
| AUD061-11 | High | Qualification | Fixes on `main` with deployed acceptance still open | M |
| AUD061-12 | High | Build pipeline | Web export failed twice at 49% with no root cause | M |
| AUD061-17 | High | Qualification | The plan's own coverage gates 003–011 are still pending or partial | M–L |
| QOL-01 | Low | Start screen | START NEW RUN replaces a saved run with no confirmation | S |
| QOL-02 | Medium | HUD | A failed autosave looks the same as a healthy one | S |
| QOL-03 | Low | Messages | Internal wording shown to players | S |
| QOL-04 | Low | Display | Loaded numbers can render as `2.0` | S |
| QOL-05 | Low | Support | No way to copy version and save diagnostics | S |
| QOL-06 | Later | Input | No controls reference; no key rebinding | M |
| QOL-07 | Later | Games | Rebet exists in three games only | S–M |
| QOL-08 | Later | Pacing | No faster-table or skip-animation option | M |
| QOL-09 | Later | Saves | One save slot; no manual slots | M |
| QOL-10 | Later | Text | No localisation layer | L |
| STR-01 | — | Structure | Two god objects carry the game | L |
| STR-02 | — | Structure | State is untyped dictionaries | L |
| STR-03 | — | Structure | Integrity hashes depend on JSON number types | M |
| STR-04 | — | Structure | Save format is heavier than needed; `eval` on Web | M |
| STR-05 | — | Structure | Threaded save relies on an unenforced immutability rule | M |
| STR-06 | — | Structure | RNG is a 31-bit Lehmer generator | M |
| STR-07 | — | Process | 449 tests, no CI, Windows-only runner | M |
| STR-08 | — | Process | Ledger and repository weight | M |
| STR-09 | — | Hygiene | Lint findings and disabled limits | S |
| STR-10 | — | Distribution | Unsigned Windows build; stale mobile presets | S–M |

Effort: S = under a day, M = one to three days, L = multi-week, staged.

### How ready each task is

"Ready" means the problem, the location, the change and the tests are all on
the page: the worker reproduces, implements and tests. Nothing here was run,
so "ready" still starts with reproducing.

| Task | Type | Ready to implement? |
| --- | --- | --- |
| AUD061-02 | Code | **Yes.** Entry points, dialog pattern and confirmed path are specified. |
| AUD061-01 | Code | **Yes.** One branch plus three test cases. |
| AUD061-04 | Code + release | **Yes.** Every stamp location is listed, including the export tool and what the menu displays. Final asset renaming and checksums stay an owner step. |
| AUD061-05 | Release process | Yes, once code is frozen. The changelog needs a read of `git log v0.6.0..`. |
| AUD061-09 | Code | **Yes.** |
| AUD061-10 | Code | **Yes.** Three lines, argument specified. |
| AUD061-14 | Code | **Yes.** Six call sites listed. Optional. |
| AUD061-16 | Code | **Yes**, with one search to do first (stated in the task). Optional. |
| AUD061-15 | Code | **Yes** for item 2 only. Optional. |
| AUD061-08 | Code | Yes. Optional. The Web part needs a browser to verify. |
| AUD061-03 | Code + tooling | Yes, but deferred. Read its constraint first. |
| QOL-01, -02, -03, -05 | Code | **Yes.** |
| QOL-04 | Code sweep | Fix specified; the places are found by looking at each game screen after Continue. |
| AUD061-12 | Investigation | **No.** Root cause unknown. Procedure given, answer not. |
| AUD061-11 | Test run | Procedure only. Results are unknown until run. |
| AUD061-17 | Test run | Procedure only. This is where new problems get found. |
| STR-01 … STR-10 | Design direction | **No.** Evidence and a staged approach, not step-by-step orders. Each needs its own plan first. Not for 0.6.1. |
| QOL-06 … QOL-10 | Ideas | **No.** One-paragraph proposals. Not for 0.6.1. |


---

# Part A — Release items

## AUD061-01 — A leftover `.rollback` file blocks every later save, permanently

> **Owner decision 2026-11-11:** now **High**, fixed together with AUD061-02. Save data is disposable, so the change below is the simple version: delete the stale file and carry on.

**Severity:** High. **Area:** `scripts/core/durable_store.gd`.
**Affects:** run saves, settings, profile inventory, meta collection and
developer placement — everything written through `DurableStore.write_json`.

### What is wrong

`write_json` installs a new file in several rename steps. While it works it
parks the old backup under `<file>.bak.rollback`, or an unreadable primary
under `<file>.rollback`. At the start of every write it checks for those two
names, and if either exists it refuses to write:

```gdscript
# durable_store.gd:73-76 (current code)
for rollback_path in [backup_rollback_absolute, invalid_primary_rollback_absolute]:
    if FileAccess.file_exists(rollback_path):
        _remove_if_exists(temp_absolute)
        return _result(false, ERR_ALREADY_IN_USE, "stale_transaction_rollback", OUTCOME_NONE)
```

Nothing anywhere removes or recovers a stale rollback file. A repository-wide
search finds `.rollback` only in this file. So once one exists, every save
fails with `stale_transaction_rollback` for the life of the install.

### How a stale file gets left behind

1. **Process kill, crash or power loss mid-install.** The window runs from the
   backup rename (`:85`) to the cleanup (`:160`). It includes re-hashing the
   installed file, so it is milliseconds wide and it opens on every autosave.
2. **Cleanup delete fails and nobody notices.** After a *successful* save the
   two rollback files are removed, and the result is thrown away:

   ```gdscript
   # durable_store.gd:160-161 (current code)
   _remove_if_exists(backup_rollback_absolute)
   _remove_if_exists(invalid_primary_rollback_absolute)
   ```

   On Windows a just-renamed file is often held briefly by antivirus or the
   search indexer. The delete fails, `write_json` still reports success, and
   the *next* save is the one that fails — forever.
3. **Restore fails part-way.** `_restore_install_generations` (`:250-283`)
   can return an error while leaving a rollback name on disk.

### Player impact

Autosave stops working for good. The player sees "Autosave failed" and every
manual Save fails. Settings and home progression stop persisting too. A restart
does not help. Combined with AUD061-02 the game cannot be closed normally.
Fixing it by hand means finding and deleting a hidden file in the user data
folder.

### Reproduce first

1. In a scratch profile, save once so `foundation_ui_autosave.json` and its
   `.bak` exist.
2. Create an empty file `foundation_ui_autosave.json.bak.rollback` beside it.
3. Take any action that autosaves, or press Save. Expect
   `stale_transaction_rollback` and "Autosave failed".
4. Repeat with `foundation_ui_autosave.json.rollback`.
5. Repeat for `settings.json.bak.rollback` and change a setting.

### Change required

Save data is disposable (owner decision), so the fix is the simple one.

1. **Replace the refusal with cleanup.** At `durable_store.gd:73-76`, instead
   of returning `stale_transaction_rollback`, delete each stale rollback file
   and continue with the write. Only return an error if a stale file exists
   and cannot be deleted; use a distinct error code (`stale_rollback_undeletable`).

   *Why:* the refusal protects nothing and turns one bad moment into a
   permanent failure.
2. **Check the cleanup deletes** at `:160-161`. If a delete fails, retry once.
   If it still fails, keep reporting success for this save (the new primary is
   installed and valid); step 1 will clear the leftover on the next write.
3. **Do not change** the rename order, the validator contract, or the
   `reuse_validated_image` digest logic.

Nothing else is needed. Do not add read-side recovery or promote rollback
files back to primary.

### Tests to add

Extend `scripts/tests/health06_1_durable_store_contract.gd` with cases that
start from:

- valid primary + stale `.bak.rollback` → write succeeds, stale file gone;
- valid primary + stale `.rollback` → write succeeds, stale file gone;
- no primary + stale `.bak.rollback` → write succeeds, stale file gone.

All existing cases in that file must still pass.

### Acceptance

- The "Reproduce first" steps now save normally and the stale file is removed.
- Existing durable-store contract passes.

### Risk

Low. One branch in one static function.

---

## AUD061-02 — The game cannot be closed while a save fails

**Severity:** Blocker. **Area:** `scripts/ui/foundation_main.gd`.

### What is wrong

Quit is handled manually (`get_tree().auto_accept_quit = false`, `:778`). Window
close calls `exit_game()` (`:1012-1013`), which returns early when the leaving
save fails:

```gdscript
# foundation_main.gd:19373-19381 (current code)
func exit_game() -> void:
    if _web_manual_save_pending:
        return
    _drain_event_response_before_exit()
    if not _save_foundation_run_before_leaving("Autosaved before exit."):
        return
    ...
    get_tree().quit()
```

`_save_foundation_run_before_leaving` (`:19253-19284`) returns `false` on any
save failure and shows "Could not save the run. Your run is still open; choose
Save to retry." `return_to_main_menu()` (`:19287-19296`) has the same guard.
There is no second path. A second click on the window close button does the
same thing again.

Other ways the same guard returns `false`, each of which also traps the player:

- `_settle_terminal_meta_before_replacement()` fails (`:19255`);
- the current game is not "save ready" and the save is forced (`:6995-6998`,
  "Save waits for the live machine to settle.");
- a room publication check is pending (`:7038-7041`);
- the previous background save failed (`:7042-7047`, see AUD061-09).

### Player impact

When storage is full, a file is locked, or AUD061-01 has triggered, the window
close button, Exit and Main Menu all do nothing but show a message. The player
has to kill the process from the task manager. That is worse than the data
loss the guard was added to prevent, because the save was going to fail anyway.

The guard itself is right: 0.6.1 added it deliberately ("Keeps the current run
open when its final save fails"). What is missing is the way out.

### Reproduce first

1. Start a run. Force saving to fail: use the existing debug switch
   `DurableStore.set_debug_force_write_failure(true)`, or create a stale
   rollback file as in AUD061-01.
2. Click the window close button. Nothing closes.
3. Choose Exit, then Main Menu, from the Run Menu. Neither leaves.

### Change required

1. **Add a confirmed "leave without saving" path.** When
   `_save_foundation_run_before_leaving` fails during `exit_game()` or
   `return_to_main_menu()`, show a modal with two choices: *Keep playing*
   (default, focused) and *Quit without saving* / *Leave without saving*. State
   plainly that progress since the last successful save will be lost and name
   when that was if known.

   *Why:* the player, not the game, should decide whether to lose progress to
   get out. Silent refusal removes the choice.
2. **Make a repeated native close request decisive.** If the modal is already
   open and another `NOTIFICATION_WM_CLOSE_REQUEST` arrives, treat it as
   *Quit without saving*. A user hammering the close button should never be
   stuck.
3. **Route the modal through the existing modal focus scope**
   (`modal_focus_scope`) so keyboard and gamepad can reach both buttons, and so
   it does not collide with an open event choice popup.
4. **Join in-flight work before quitting.** On the "without saving" path still
   run `_drain_script_prewarm_requests_for_shutdown()` and wait for any async
   save task, exactly as `_exit_tree()` does (`:1016-1027`), then quit. Do not
   skip thread joins.
5. **Tutorial and meta-session branches stay as they are.** They already
   return `true` or have their own completion logic.
6. **Do not** remove the guard, auto-quit after N failures, or discard without
   asking.

### Where the pieces go

- **Dialog.** Build one `ConfirmationDialog` next to the existing
  `save_delete_confirmation` (`foundation_screen_builder.gd:251-256`) and wire
  it the same way. That dialog is the working example of title, text, OK
  button text, `confirmed` signal and `host.add_child`. Name it
  `leave_without_saving_confirmation`; add the member next to
  `save_delete_confirmation` in `foundation_main.gd`.
- **Which action is pending.** Store what the player was trying to do
  (`"exit"` or `"main_menu"`) in one member when the dialog opens, and read it
  in the `confirmed` handler.
- **Entry points to change.** Exactly two: `exit_game()` (`:19373`) and
  `return_to_main_menu()` (`:19287`). In each, where the current code does
  `if not _save_foundation_run_before_leaving(...): return`, open the dialog
  before returning. Callers: window close (`:1013`), the Exit Game button
  (`foundation_screen_builder.gd:74`), and the Main Menu routes at `:19125`,
  `:19175`, `:19183`. `:19175` uses the boolean result; keep returning `false`
  when the dialog opens.
- **The confirmed path.** Give both functions an internal variant that skips
  the save call and runs the rest of the existing body unchanged. For
  `return_to_main_menu` that is everything from `_clear_run_audio_caches()` at
  `:19297` onward. For `exit_game` it is `_reset_game_surface_runtime_state()`,
  `_set_active_game_binding()`, `get_tree().quit()`. Before quitting, do what
  `_exit_tree()` does at `:1016-1027`.
- **Repeated close.** In `_notification` (`:1012`), if the dialog is already
  visible when `NOTIFICATION_WM_CLOSE_REQUEST` arrives, take the confirmed
  path.
- **Do not show the dialog** when the function returned early because
  `_web_manual_save_pending` is set (`:19374`, `:19288`); that is a save in
  progress, not a failed one.
- **Message.** The existing "Could not save the run…" message (`:19282`)
  stays; the dialog adds the choice.

### Tests to add

- Contract check: with a forced write failure, `exit_game()` opens the confirm
  modal and does not quit; choosing *Quit without saving* quits; choosing
  *Keep playing* closes the modal and leaves the run intact and dirty.
- Same for `return_to_main_menu()`: *Leave without saving* reaches the start
  screen with `run_state == null`; the previous loadable save is still on disk
  and Continue loads it.
- Second close request while the modal is open quits.
- Existing `bar_dice_shutdown_save_task_check.gd` and the save-failure checks
  from the 2026-10-18 durability work still pass.

### Acceptance

- With saving forced to fail, the player can always leave in at most two
  deliberate actions.
- With saving healthy, behavior is unchanged: no new prompt.

### Risk

Low to medium. Touches the exit path, which has many guards. Keep the change
to the two public entry points and one new modal.

---

## AUD061-03 — The performance harness is reachable in shipped builds and overwrites the player's run

> **Owner decision 2026-11-11:** now **Low, deferred until after 0.6.1.** Losing a run no longer matters. What is left is that a public build can be made to run a scripted plan from a URL. Read "Important constraint" below before touching it; the obvious fix breaks the perf tooling.

**Severity:** Low, deferred. **Area:** `scripts/ui/perf_telemetry_overlay.gd`,
`scripts/ui/foundation_main.gd`.

### What is wrong

The telemetry overlay is loaded whenever a `bth_perf*` token appears in the
user command-line arguments or, on Web, in the page URL query:

```gdscript
# foundation_main.gd:1240-1244 (current code)
func _perf_telemetry_requested() -> bool:
    for arg_value in OS.get_cmdline_user_args():
        if str(arg_value).find("bth_perf") != -1:
            return true
    return OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search", true)).find("bth_perf") != -1
```

`PerfTelemetryOverlay.runtime_enabled()` (`:236-240`) and `_runtime_options()`
(`:3890-3897`) apply the same inputs. Neither checks `distribution_build`.

`configure()` then dispatches on `bth_perf_plan` (`:271-289`) to scripted
plans. Several of them drive the real application object:

- `_run_lb3_plan` calls `app.start_foundation_run("LB3-FIRST-RUN")` (`:2202`)
  and later `app.call("_autosave_foundation_run", "LB3 Autosave.", false)`
  (`:2251`) — the normal autosave, to the normal slot.
- `_run_la1_plan` does the same: `app.start_foundation_run("LA1-WEB-CORE")`
  (`:2357`), then the normal autosave (`:2371`).
- Other plans call `run_state.fail_run("performance_probe", …)` (`:1419`), set
  `run_state.bankroll` directly (`:1033`), install fixtures, and may auto-quit.

Only the Grand Casino save/restore phase swaps to private slots
(`perf06_grand_restore`, `perf06_grand_terminal`, `:1399-1450`).

### Player impact

Opening the public Web build with `?bth_perf_plan=lb3` starts a scripted run
and autosaves it over the player's in-progress run. A shared or mistyped link
is enough. One backup generation survives the first overwrite and is rotated
away by the second autosave. The same works on desktop with
`-- bth_perf_plan=lb3`. The plans also write report files into user data.

### Reproduce first

1. Export or run a build with the `distribution_build` feature (or set
   `BTH_FORCE_DISTRIBUTION_BUILD=1`).
2. Start a run, play a few actions, let it autosave, return to the menu.
3. Relaunch with `-- bth_perf_plan=lb3` (Web: append `?bth_perf_plan=lb3`).
4. After the plan finishes, relaunch normally and press Continue. The run is
   the scripted `LB3-FIRST-RUN`, not the player's.

### Important constraint found on a second pass

The project's own performance tooling runs these plans **against a normal Web
export**. `tools/web_perf_smoke.ps1` builds through `tools/export_itch.ps1`
with the standard `Web` preset (which carries `distribution_build`) and opens
`?bth_perf=1&bth_perf_plan=<plan>&bth_perf_auto_quit=1` (`:86`, `:111`). Its
plan list is `l02`, `grand_casino`, `coin_pusher`, `secure_entropy`,
`distribution_fresh_start` (`:13`). `tools/perf06_native_runtime_matrix.ps1`
does the equivalent on a Windows export (`:54-73`).

So **"refuse plans when `distribution_build` is set" would break the perf
budget tooling.** Do not implement that.

### Change required

With save data disposable this is **Low** and can wait until after 0.6.1. If
it is taken, the design is an explicit opt-in that a release package never
carries:

1. Add an optional boolean field `perf_harness` to the embedded build manifest
   (`res://build_manifest.json`, read by `scripts/core/build_identity.gd`).
   It is not in `REQUIRED_FIELDS`, so existing manifests stay valid.
2. In `tools/export_itch.ps1`, add a `-PerfHarness` switch that writes
   `perf_harness = true` into the manifest it embeds. Make `-PerfHarness`
   throw when combined with `-Push`, the same way `-NoPackage` does (`:272`).
3. Have `tools/web_perf_smoke.ps1` and `tools/perf06_native_runtime_matrix.ps1`
   pass `-PerfHarness` when they export.
4. In `PerfTelemetryOverlay.runtime_enabled()` (`:236-240`) and
   `FoundationMain._perf_telemetry_requested()` (`:1240-1244`): when
   `BuildIdentity._distribution_build()` is true and the manifest does not
   have `perf_harness == true`, ignore `bth_perf_plan`. Passive `bth_perf=1`
   telemetry with no plan may stay. Source runs are unaffected.

   *Why:* test automation stays available to the tooling and stops being
   reachable from a URL on the build players get.
5. **Do not** remove the overlay, change what plans measure, or change the
   report format.

Note for whoever owns perf evidence: a perf export then differs from the
release export by that one manifest field, so their export hashes differ.
If "measured on the exact release bytes" is a requirement, raise that before
implementing instead of working around it.

### Tests to add

- Contract: distribution feature forced on, no `perf_harness` in the manifest
  → `runtime_enabled()` is false for a plan token.
- Contract: same with `perf_harness: true` → plan runs.
- `tools/web_perf_export_mode_contract_test.ps1` and
  `tools/perf06_required_matrix_contract_test.ps1` still pass after the tool
  change.

### Acceptance

- A release export ignores `bth_perf_plan`.
- `web_perf_smoke.ps1 -Plan l02` still produces a report.

### Risk

Medium for its size, because it touches the export tool and two perf tools.
That is why it is deferred, not because the code change is hard.

---

## AUD061-04 — Version stamps still read 0.6.0 everywhere

**Severity:** Blocker. **Area:** release metadata.

### What is wrong

Nothing in the tree says 0.6.1 except the changelog heading. A 0.6.1 build
would identify itself as 0.6.0.

| Location | Current value |
| --- | --- |
| `project.godot:19` | `config/version="0.6.0"` |
| `export_presets.cfg:26-27` | Windows `file_version` / `product_version` `0.6.0.0` |
| `export_presets.cfg:65-66` | Android `version/code=9`, `version/name="0.6.0"` |
| `export_presets.cfg:95-96` | iOS `short_version` / `version` `0.6.0` |
| `scripts/core/build_identity.gd:8` | `const DEVELOPMENT_VERSION := "0.6.0"` |
| `scripts/tests/fixsweep06_1_packaging_runtime_contract.gd:14-16` | asserts `"0.6.0"` |
| `tools/game_documentation_check.ps1:84-90` | asserts `0.6.0` stamps |
| `README.md:20-54` | download links and "Published release" row point at `v0.6.0` |
| `tools/export_itch.ps1:71` | `$buildVersion = "0.6.0-dev+$short"` — **hard-coded** |
| `tools/fixsweep06_1_packaging_contract_test.ps1:83` | asserts the literal `0.6.0-dev+` |

The last row matters most. Exported builds do not show the project setting.
They show the `build_version` from the embedded manifest
(`build_identity.gd:48-55`), and the export tool writes `0.6.0-dev+<commit>`
into it regardless of the project version. Every build this tool produces,
including the current pre-release, identifies itself as a 0.6.0 development
build.

The `v0.6.1-pre.1` tag also carries `config/version="0.6.0"`.

### Player impact

The in-game version, the Windows file properties and bug reports all say
0.6.0. Support cannot tell the two releases apart, and store or updater logic
keyed on the version sees no update.

### Change required

1. One commit that bumps every stamp in the table to 0.6.1 (Windows
   `0.6.1.0`), increments Android `version/code` to 10, and updates the two
   checks to expect the new value.
2. Make `BuildIdentity.DEVELOPMENT_VERSION` read
   `ProjectSettings.get_setting("application/config/version")` instead of
   repeating the literal.

   *Why:* the duplicate constant is one more place to forget next time.
3. Make the two checks compare the stamps to each other (project setting ==
   every export preset == `BuildIdentity.display_version()` in a source run)
   rather than to a hard-coded literal, so they do not need editing per
   release.
4. Update the README links and the "Published release" row **only when the
   release assets exist**; until then they should keep pointing at `v0.6.0`.
5. In `tools/export_itch.ps1:71`, derive the development identity from the
   project version: `"$projectVersion-dev+$short"`. The script already has
   `Get-ProjectVersion`; call it before `Get-SourceIdentity` or pass the value
   in. Update line `:278`, which names `0.6.0-dev+*` literally.
6. **Release builds come from `tools/export_itch.ps1`** (confirmed by the
   owner, 2026-11-11). Three consequences the worker must handle:

   - **What the game shows.** The manifest the tool embeds carries two
     values: `build_version` (`0.6.0-dev+<commit>`, `:379`) and
     `release_version` (the project version, `:380`). The game reads only
     `build_version` (`build_identity.gd:48-51`; the menu label is
     `foundation_main.gd:20858-20859`). Nothing in the game reads
     `release_version`. So a released build's menu reads
     "Version 0.6.0-dev+<commit>", and after the bump in step 5 it will read
     "Version 0.6.1-dev+<commit>".
   - **Change:** make `BuildIdentity.display_version()` return the manifest's
     `release_version` followed by the short commit, for example
     `0.6.1 (1a2b3c4d5e6f)`, when the manifest is valid and has a
     `release_version`; fall back to `build_version` otherwise. Leave
     `telemetry_identity()` and `build_version` itself alone, since the
     packaging and perf tools key on them.

     *Why:* players and bug reports should see the release number; the
     commit stays visible so two builds of the same version can still be
     told apart.
   - **A third literal.** `tools/fixsweep06_1_packaging_contract_test.ps1:83`
     asserts that the text `0.6.0-dev+` appears in the export tool. Update it
     with step 5 or it fails.
   - **Package names.** The tool writes
     `BeatTheHouse-<build_version>-windows-<commit>-<dirty>.zip` and the
     matching `-web-` file (`:432-433`). The published 0.6.0 assets are named
     `BeatTheHouse-0.6.0-windows-x64.zip`, `…-web.zip`, `…-source.zip` and
     `SHA256SUMS.txt` (`README.md:30-33`). Nothing in the repository does
     that renaming or writes the checksum file, so it appears to be done by
     hand at upload. Leave it as an owner step unless asked to automate it;
     do not change the tool's file naming, because the staging and manifest
     checks depend on it.

### Acceptance

- `git grep -n '0\.6\.0'` over `project.godot`, `export_presets.cfg`,
  `scripts/core`, `scripts/tests`, `tools/*.ps1` returns only intentional
  historical references.
- A source run shows 0.6.1; an export shows the manifest's build version.

### Risk

Low. Do this **after** the code freeze so the RC is built once.

---

## AUD061-05 — The pre-release tag is not the candidate; the changelog is incomplete

> **Task type: release process, no code. Depends on the code freeze.**

**Severity:** Blocker. **Area:** release process.

### What is wrong

- `v0.6.1-pre.1` points at `b2a9cef8` (2026-11-06). `main` is 134 files ahead
  of it. Runtime code changed after the tag: `scripts/games/video_poker.gd`
  (+534 lines, incremental hint work), `scripts/core/run_state.gd`,
  `scripts/games/roulette.gd`, `scripts/games/coin_pusher.gd`,
  `coin_pusher_live_session.gd`, `scenario_sequence_schema.gd`,
  `event_module.gd`, and `developer_placement_overrides.json`. Whatever was
  qualified on pre.1 does not cover those.
- Since `v0.6.0`, 145 runtime files changed (+16,992 / −3,735) across
  `scripts/core`, `scripts/ui`, `scripts/games`, `data`, `scenes`. Data changes
  include `characters.json`, `lenders.json`, `events.json` (87 changed lines),
  `items.json` (+20), `tutorial/lessons.json`, `placement_surfaces.json`,
  `scenario_slot_layouts.json`, four scenario-sequence packages, a new
  `character_offers.json`, and removal of `rituals/crew06_10_poker_nights.json`.
- `CHANGELOG.md:5-14` lists three fixes for 0.6.1.

### Player impact

Players and the owner cannot tell what changed. More importantly, "tested" and
"shipped" refer to different commits.

### Change required

1. Declare a code freeze on `main` once Part A code items are merged.
2. Cut `v0.6.1-rc.1` from the frozen commit. All qualification evidence must
   name that exact SHA.
3. Write the real 0.6.1 changelog from `git log v0.6.0..<rc>` grouped by what
   a player notices: save and exit reliability, per-game fixes (Roulette warm
   reveal, Video Poker hints, Bar Dice restore and labels, Coin Pusher drop
   price and input, Blackjack risk notice, Crew handoff), tutorial, travel,
   performance. The stability plan's task list is the source.
4. Any commit after the RC tag means a new RC and a re-run of the gate.

### Acceptance

- The final tag equals the last RC commit, plus at most the version-stamp and
  changelog commit if the gate is re-run on it.
- Every player-visible change since 0.6.0 has a changelog line.

---

# Part B — Should fix in 0.6.1

## AUD061-08 — No save flush on background, tab hide or tab close

> **Owner decision 2026-11-11:** now **Low**, optional.

**Severity:** Low, optional.
**Area:** `foundation_main.gd`.

### What is wrong

Autosaves are debounced. A normal action is queued and written up to 1.5 s
later; environment-runtime changes up to 6 s later:

```gdscript
# foundation_main.gd:71-75 (current code)
const AUTOSAVE_INTERACTION_DEBOUNCE_MSEC := 250
const AUTOSAVE_GAME_INTERACTION_DEBOUNCE_MSEC := 400
const AUTOSAVE_MAX_DEFER_MSEC := 1500
const ENVIRONMENT_RUNTIME_AUTOSAVE_DEBOUNCE_MSEC := 4000
const ENVIRONMENT_RUNTIME_AUTOSAVE_MAX_DEFER_MSEC := 6000
```

The lifecycle handler (`:989-999`) only pauses simulation on focus-out and
application-paused. It does not flush the pending save. There is no Web
`visibilitychange`, `pagehide` or `beforeunload` hook anywhere in the project
(searched scripts, tools and export presets; `html/head_include` is empty).

On a no-threads Web build the save itself is also spread over four frames
(`save_service.gd:117-184`), so even a started save needs several frames to
land, and then the browser needs to sync IndexedDB.

### Player impact

Closing or switching away from the tab right after a result can lose that
result: a win is not recorded, or a paid bet is recorded without its outcome.
On mobile, the OS may kill a backgrounded app with the same effect. The 0.6.1
fix for "Preserves paid Coin Pusher drops … when … closing the game" covers
the Exit button, not tab close.

### Change required

1. On `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT`
   and `NOTIFICATION_APPLICATION_PAUSED`: if `pending_autosave` is set or an
   async save is in flight, write synchronously now (the same call the Exit
   path uses) and, on Web, request a storage sync through
   `WebSaveDurabilityBridge`.
2. On Web, register `visibilitychange` (when `document.hidden` becomes true)
   and `pagehide` listeners through `JavaScriptBridge.create_callback`, and
   run the same flush from them. Keep a reference to the callback object or it
   will be collected.

   *Why `pagehide` and not `beforeunload`:* `beforeunload` is unreliable on
   mobile browsers and blocks the back/forward cache.
3. Respect the existing rules: do not flush when
   `current_game.foundation_save_ready(...)` is false, when a room publication
   check blocks saving, or in practice/meta sessions. The existing
   `_autosave_foundation_run(status, true)` already encodes these.
4. The flush must not block for long. It is one synchronous save; on Web that
   is the four phases run back to back, which `wait_for_async_save()` already
   supports.
5. **Do not** change the debounce constants or animation scheduling. This item
   adds a flush at a lifecycle boundary and nothing else.

### Tests to add

- Contract: queue an autosave, send focus-out, assert the save is on disk
  without advancing frames.
- Web capture: take an action, hide the tab within 200 ms, reload, Continue;
  the action is present.
- Animation-liveness check still passes (focus-out handling is adjacent to
  pause logic).

---

## AUD061-09 — An explicit Save reports an older save's failure without trying

**Severity:** Medium. **Area:** `save_service.gd`, `foundation_main.gd`.

### What is wrong

Both layers return early if the *previous* background save failed:

```gdscript
# save_service.gd:53-56 (current code)
if async_save_in_flight():
    var async_error := wait_for_async_save()
    if async_error != OK:
        return async_error
```

```gdscript
# foundation_main.gd:7042-7047 (current code)
if synchronous and save_service.async_save_in_flight():
    var pending_error := save_service.wait_for_async_save()
    if pending_error != OK:
        _record_autosave_failure(pending_error, "async_wait_failed", autosave_inflight_generation)
        autosave_inflight_generation = 0
        return false
```

`clear_run` (`save_service.gd:364-367`) has the same shape.

### Player impact

The player presses Save (or Exit) and is told it failed, when the failure
belongs to an earlier background attempt that may have been transient. The
current state was never attempted. Through AUD061-02 this also blocks exit.

### Change required

1. After draining a failed async save, **continue** to the synchronous write.
   Record the older failure for diagnostics but let the result of the new
   write decide the return value.
2. In `clear_run`, a failed in-flight save is not a reason to keep the file.
   Drain, ignore the error, and remove.
3. Keep the drain itself; the worker must finish before the main thread
   writes.

### Tests to add

- Force the async save to fail once, then call `save_run` → the synchronous
  write runs and succeeds.
- Force both to fail → failure is reported with the *second* error.

---

## AUD061-14 — Six call sites ignore a failed profile, meta or settings save

> **Owner decision 2026-11-11:** now **Low**, optional.

**Severity:** Low, optional. **Area:** `foundation_main.gd`.

### What is wrong

`ProfileInventory.save()`, `MetaCollectionService.save()` and
`UserSettings.save()` all return an `Error`. These callers discard it:

| Line | Function | What is saved |
| --- | --- | --- |
| `:9494` | `_record_scratch_ticket_discovery` | profile inventory |
| `:10220` | home type selection handler | settings |
| `:19808` | `_on_reset_coach_tips_requested` | profile inventory |
| `:19818` | `_on_coach_lesson_seen` | profile inventory |
| `:20196` | `buy_meta_home_upgrade` | meta collection, after a purchase |
| `:20320` | `_toggle_meta_item_pack` | meta collection |

### Player impact

The most visible case is `buy_meta_home_upgrade`: the purchase succeeds in
memory, the screen updates, the save fails, and the upgrade is gone on the
next launch with no warning. The others silently lose a setting or a "seen"
flag. With AUD061-01 active, all of these fail every time.

### Change required

1. Check the return value at each site.
2. For purchases and pack/unpack: on failure, show a clear message that the
   change is not saved yet and keep a retry pending (the service already holds
   the new state in memory, so a later successful save will persist it).
   Prefer retry over rollback; rolling back a purchase after showing it is
   more confusing.
3. For settings and coach flags: log once and retry on the next change; no
   modal.
4. Consider one helper (`_persist_or_warn(store, context)`) so the six sites
   behave the same.

---

## AUD061-10 — Crew heist payouts bypass `change_bankroll`

**Severity:** Low. **Area:** `scripts/core/crew_run_facade.gd`.

### What is wrong

Three places write the bankroll directly:

- `:1082` `_run.bankroll -= paid` (abort cost)
- `:1387` `_run.bankroll += payout` (whale exit)
- `:1798` `_run.bankroll += payout` (getaway resolution)

Everywhere else goes through `RunState.change_bankroll` (`run_state.gd:6108`),
which wraps the write in a money-change batch and calls `_refresh_economy`,
recomputing `economic_state` (insolvent / distressed) and the bankroll-zero
failure check. The property setter (`:339-347`) still fires the money-changed
signal, so the HUD updates, but the economy refresh is skipped.

### Player impact

Small. `economic_state` can be stale until the next ordinary money change. The
abort cost is capped at `bankroll - 1`, so it cannot hit zero.

### Change required

Replace the three direct writes with `change_bankroll(delta, true)`.

Pass `true` for `defer_bankroll_zero` at all three. Without it,
`_refresh_economy` (`run_state.gd:17987-18001`) calls `fail_run` the moment
the balance is zero. At `:1387` and `:1798` the code has just set
`grand_casino_chips = 0`, so a zero payout on an empty wallet would end the
run from inside heist resolution, which does not happen today. With `true`
the balance is marked insolvent and the normal terminal check handles it
afterwards, keeping the current timing.

### Tests to add

One assertion per site that `economic_state` matches the new balance
immediately after the heist resolves.

---

## AUD061-15 — The Crew private capsule is bound to a per-install key; saves are not portable

> **Owner decision 2026-11-11:** now **Low**. Portability does not matter. Do item 2 only (replace a key file of the wrong size so saving the capsule is not permanently disabled). Skip items 1, 3, 4 and 6.

**Severity:** Low. **Area:** `scripts/core/crew_turn_model.gd`,
`crew_run_facade.gd`, `run_state.gd`.

### What is wrong

Hidden Crew state (grievance ledger and heist "turned" state) is stored in
each save as an AES-CBC + HMAC capsule. The key is a 32-byte file created per
install:

```gdscript
# crew_turn_model.gd:26 (current code)
const PRIVATE_KEY_PATH := "user://.crew_host_authority_v1"
```

Three consequences:

1. **A save moved without the key loses its Crew state.** On load, a capsule
   that fails to authenticate goes to `_crew_private_restore_failed`
   (`crew_run_facade.gd:2458-2472`): the grievance ledger is cleared and an
   active heist is marked aborted. That covers copying a save to another PC,
   restoring a backup after reinstall, any cloud sync that carries the save
   but not the dot-file, and a browser that keeps one and drops the other.
2. **A damaged key file is never repaired.** `_private_install_key`
   (`:370-404`) regenerates only when the file does not exist. If it exists
   with a size other than 32 bytes, the function returns empty every time, and
   every save is written with `private_authority_error`:

   ```gdscript
   # crew_turn_model.gd:390-394 (current code)
   if FileAccess.file_exists(PRIVATE_KEY_PATH):
       DirAccess.remove_absolute(temporary_path)
       var raced := FileAccess.get_file_as_bytes(PRIVATE_KEY_PATH)
       if raced.size() != 32:
           return PackedByteArray()
   ```
3. **The key sits outside the distribution root.** It is at the top of
   `user://`, not under `PersistencePaths.distribution_root()`. Development
   and distribution profiles, and both Web epochs, share one key. That happens
   to help AUD061-13 migration, but it is by accident, and test harnesses that
   isolate a profile root do not isolate the key.

A side cost: every save carries a fixed 65,536-byte encrypted block of random
padding (`PRIVATE_SAVE_PLAIN_BYTES`, `:17`), by design, so save size does not
reveal the grievance count. It is incompressible, so every save is at least
about 80 KB after encoding, which is written on every autosave on Web.

### Player impact

Crew progress in an active run is silently reset when the save and key part
ways. The player sees an aborted heist with no explanation they can act on.

### Change required

1. **Decide and document the portability rule.** If saves are meant to be
   portable (Steam Cloud is the obvious case), the key must travel with them or
   the scheme must not depend on a machine secret. If not, say so in the
   player-facing notes and make sure any cloud sync includes the key file.
2. **Repair a wrong-sized key file.** If the file exists with the wrong size,
   move it aside and generate a new one. Existing capsules will fail once
   (same as today) instead of failing forever.
3. **Tell the player** when a private restore fails: one line on Continue that
   Crew history from this save could not be restored on this device. The
   narrative flags `crew_private_authority_error` /
   `crew_heist_private_restore_error` already mark the case.
4. **Make the path test-isolatable**: honor an environment override like the
   other stores do (`BTH_META_COLLECTION_PATH` etc.), so QA profiles do not
   share a key with the developer's own install.
5. **Do not** change the capsule format or the key derivation for 0.6.1; that
   would break every existing capsule. Items 2–4 are safe.
6. For later: reconsider the 64 KB fixed padding. A few fixed size classes
   would hide the count equally well at a fraction of the size.

### Tests to add

- Wrong-sized key file → replaced; subsequent pack/unpack round-trips.
- Save loaded with a different key → run loads, heist aborted, message shown,
  next save succeeds.
- AUD061-06 fixtures include an active heist captured with its key.

---

## AUD061-16 — Test-only fault switches live in shipping classes

**Severity:** Low. **Area:** `durable_store.gd`, `run_save_codec.gd`,
`foundation_main.gd`.

### What is wrong

Static variables that force failures are compiled into release builds and are
not gated by build type:

- `DurableStore.debug_force_write_failure`, `debug_force_rename_failure`,
  `debug_fail_transition` (`durable_store.gd:16-18`)
- `RunSaveCodec.debug_storage_byte_limit_override`,
  `debug_force_compression_failure` (`run_save_codec.gd:82-83`)
- `script_prewarm_force_start_error_for_test` in `foundation_main.gd`

Nothing in shipping code sets them, so there is no live defect. The risk is a
future caller, or the performance harness (AUD061-03), flipping one in a
player's build.

### Change required

Gate the **read sites** so the switches have no effect in a shipped build:

| Read site | Switch |
| --- | --- |
| `durable_store.gd:38` | `debug_force_write_failure` |
| `durable_store.gd:116` | `debug_force_rename_failure` |
| `durable_store.gd:246-247` (`_debug_transition_fails`) | `debug_fail_transition` |
| `run_save_codec.gd:158` | `debug_storage_byte_limit_override` |
| `run_save_codec.gd:164` | `debug_force_compression_failure` |
| `foundation_main.gd:1072` | `script_prewarm_force_start_error_for_test` |

Use `not PersistencePaths.distribution_build()` as the condition, not
`OS.is_debug_build()`. Some checks may run against a release-template export
that is not a distribution build, and those must keep working. Before
merging, search `tools/` for any script that sets one of these switches while
running a distribution export; if one exists, leave that switch alone and
report it. Keep names and signatures; tests depend on them.

---

## AUD061-11 — Fixes on `main` whose deployed acceptance is still open

> **Task type: test run, no code. Run the recorded acceptance for each row on the release candidate and record the result. A failure becomes a new, separately diagnosed task.**

**Severity:** High (qualification, not code). **Area:** ledger.

### What is wrong

These fixes are already on `main` and will ship in 0.6.1, but their ledger
entries record acceptance that has not been obtained on a deployed build:

| Ledger ID | Recorded status |
| --- | --- |
| `BTH-GAME-RETURN-001` | native 594 pass; deployed Web acceptance open |
| `BTH061-CREW-EXPIRED-HANDOFF` | native 594 pass; deployed Web acceptance open |
| `BTH061-AUDIT-SHOWDOWN-META-CHOICE-FIX-031` | deployed, native 57 pass; rendered Web acceptance open |
| `BTH061-AUDIT-TERMINAL-META-PERSISTENCE-026` | local fix, 343 checks pass; NEXT pending |
| `BTH061-006` | eleven-game Continue coverage pending |
| `BTH-PERF-20261104-001/-002/-003` | scoped fixes; normal-play acceptance open |
| `BTH061-BAR-DICE-REVEAL-RESTORE-001`, `…-COVER-DISPLAY-001` | fix on main; NEXT finishing |

Two of them are blocked on a browser certificate trust step
(`BTH-LAN-TLS-TRUST-001`), which is an owner approval, not engineering work.

### Change required

For each row, on the frozen RC: run the recorded acceptance, record pass or
fail with the RC SHA, and close or re-open accordingly. Where acceptance needs
an approval the worker cannot give, report that as the blocker and stop.
`BTH061-006` (unfinished play across all eleven games survives Continue) is the
one to prioritise; it overlaps AUD061-06.

---

## AUD061-12 — The Web export failed twice at 49% with no root cause

> **Task type: investigation. The cause is not known and this document does not supply one. The deliverable is a root cause and a fix or a bounded, explained workaround. Needs the Windows export environment.**

**Severity:** High. **Area:** build pipeline.

### What is wrong

Per the ledger:

- `BTH-NEXT-ALLOC-001`: a Web PCK export failed at 49% near the 2 GiB job
  memory cap. Private re-exports of the same input succeeded with and without
  a GC change, so the cause is not established.
- `BTH-BARDICE-WARM-PROGRESSION-001`: a later export failed at 49% with a
  stack overflow.
- `BTH-NEXT-DISK-RESERVE-001`: promotion is currently blocked because the
  shared disk reserve guard is not met.

### Why it matters for release

The release Web build has to come from a clean, repeatable export. An
intermittent failure at the same percentage suggests one specific resource or
import step. Shipping a build that happened to succeed on retry leaves the
cause in place for the next patch.

### Change required

1. Identify what the exporter is processing at 49% (verbose export log; the
   resource list order is deterministic).
2. Reproduce under the same memory cap with that resource isolated.
3. Either fix the input (an oversized or pathological asset) or record a
   bounded, explained workaround.
4. Resolve the disk reserve through the approved storage workflow. Do not
   delete retained evidence or change the guard.
5. Do the RC export twice from the same commit and compare package manifests
   (`tools/audit_pck_manifest.py`).

---

## AUD061-17 — The plan's own coverage gates are still pending or partial

> **Task type: test run, no code. Running these checks is the work. Failures become new tasks; they are not pre-diagnosed here.**

> **Owner decision 2026-11-11:** `BTH061-012`'s 0.6-save compatibility half is **not a gate**. `-005` (money conservation), `-006` (resume in the same build) and `-007` (closing time and interruptions) still are: they test that the current build works, not that old data survives.

**Severity:** High (qualification, not code). **Area:**
`docs/plans/0.6.1_stability_release_plan.md`, prioritized task list.

### What is wrong

The release plan defines its own gate ("Before 0.6.1 ships, resolve confirmed
crashes, lost/duplicated progress or money, broken required progression and
critical save incompatibilities"). The coverage tasks that would establish
that are recorded as not finished:

| Plan ID | Recorded status | What it covers |
| --- | --- | --- |
| `BTH061-003` | High / partial | Coin Pusher persistence across all three cabinets and exit routes |
| `BTH061-004` | High / coverage in progress | Normal-input seed batches across Clean, Rourke/Cheat, Crew/Count routes |
| `BTH061-005` | High / coverage pending | Cash, chip and inventory conservation through wager, payout, refund, purchase, travel, save |
| `BTH061-006` | High / coverage pending | Resume unfinished play in all eleven games |
| `BTH061-007` | High / coverage pending | Closing time, interruptions and terminal cleanup mid-game |
| `BTH061-008` | P2 / coverage pending | Interaction and readability on Windows and Web layouts |
| `BTH061-009` | P2 / measurement pending | Performance baselines on the shipped build |
| `BTH061-010` | P2 / conditional | Optimise the largest measured costs |
| `BTH061-011` | P2 / coverage pending | Audio and resource retention over repeated room and game changes |
| `BTH061-012` | Required / partial | 0.6 save compatibility and final packaging (see AUD061-06) |

### Why it matters

These are the checks that find the problems a code read cannot: lost money,
a game that will not resume, a room with no exit. `005`, `006` and `007` are
the ones that map directly onto the release gate's wording.

### Change required

1. Run `BTH061-005`, `-006`, `-007` and `-012` on the frozen RC and record
   results against its SHA. Treat a failure in any of them as a blocker.
2. Run `-003`, `-004`, `-008`, `-011` to the extent time allows and record
   what was and was not covered.
3. `-009` and `-010` are measurement and optimisation; they do not gate the
   release unless a measurement shows a regression from 0.6.0.
4. This is also where quality-of-life problems that need real play get found.
   Log each one with a stable ID; Part F lists the ones visible from the code.

---

# Part C — Structural weaknesses and improvements (after 0.6.1)

None of these should be attempted before the release. They are the reasons the
bug rate is what it is, and where sustained effort will pay off.

## STR-01 — Two god objects carry the game

**Evidence**

| File | Lines | Functions | Member vars |
| --- | --- | --- | --- |
| `scripts/ui/foundation_main.gd` | 24,760 | 1,313 | 503 |
| `scripts/core/run_state.gd` | 18,134 | 1,012 | 116 |
| `scripts/ui/pixel_scene_canvas.gd` | 11,173 | 542 | 169 |
| `scripts/games/blackjack.gd` | 8,930 | 385 | 4 |

24 functions exceed 200 lines and 183 exceed 100. The longest:
`FoundationMain._travel_to` (390 lines, `:8406`),
`Blackjack.surface_state` (344), `VideoPoker._resolve_draw` (329),
`EnvironmentSlotBinder.bind_base_records` (309),
`FoundationMain._resolve_game_action` (288, `:14211`).

**Why it is weak.** `FoundationMain` owns screens, input, autosave, travel,
game hosting, meta sessions, developer placement, audio caches and lifecycle.
With 503 fields, any function can depend on any state, so a fix in one area
regularly breaks another. The ledger's long tail of "X stays stale until menu
refresh" and "controls remain locked after Y" entries is the symptom.

**Improvement, staged**

1. *Autosave/exit controller.* Move the autosave fields (`pending_autosave*`,
   `autosave_*_generation`, failure and retry state) and the functions
   `_autosave_foundation_run` … `_record_autosave_failure`,
   `_save_foundation_run_before_leaving`, `exit_game` into one class with a
   narrow interface. It is the most self-contained seam and the one this
   audit found defects in. Existing save contract tests give it a safety net.
2. *Travel controller.* `_travel_to` and its helpers.
3. *Game-surface host.* `_resolve_game_action`, surface UI state, settle and
   checkpoint logic.
4. *Developer placement.* The `_on_developer_*` handlers (`:19456-19704`) are
   already cohesive and are editor tooling, not gameplay.
5. For `run_state.gd`: economy and debt; scenario semantic inventory
   (`:3537-5012`); Crew restore and save; persistence projection.

Rule for each step: move code without changing behavior, keep the public
method names as thin forwards for one release, land one seam at a time.

## STR-02 — State is untyped dictionaries

**Evidence.** In production code: 36,097 string-keyed `.get("…")` lookups,
2,347 `Variant` annotations, 2,358 `duplicate(true)` deep copies, 478 untyped
local declarations.

**Why it is weak.** A misspelled key returns the default with no error, so a
typo shows up as a wrong value far from its cause. Shape is documented only by
usage. Deep copies are the only defence against aliasing, and they cost real
time on Web where everything is single-threaded.

**Improvement**

1. Put the keys of the most-shared records behind constants (`keys.gd` exists;
   extend it) and add a lint rule or check that forbids new raw string keys
   for those records.
2. Introduce small typed classes for the hottest records first: wallet and
   debt entries, game result, surface state envelope.
3. Where a dictionary is read-only after construction, mark it with
   `make_read_only()` and stop copying it. This also turns STR-05's convention
   into an enforced rule.
4. Profile deep copies on a late-run Web session and remove the ones on
   per-action paths.

## STR-03 — Integrity hashes depend on JSON number types

**Evidence.** JSON has one number type; Godot parses every number as float.
Several systems hash or sign typed values, so a round-trip through JSON breaks
them. The codebase compensates in three different ways:

- wrapping integers as `{"__bth_exact_int64": "123"}` on encode for selected
  roots (`run_save_codec.gd:16-17`, `:656-672`);
- a custom parser, `storage_numeric_json.gd` (428 lines);
- a hand-written text scanner that finds Blackjack ledgers in raw save text
  and rewrites bare integer tokens before parsing (`:249-342`).

The ledger shows the class recurring: `…-CODEC-SIGNED-ZERO-022`,
`…-PROJECTION-NUMERIC-IDENTITY-023`, `…-MEMO-TYPE-SAFETY-014`.

**Why it is weak.** Each new signed structure needs its own exception, and a
miss fails late and far from the cause. The text rewriter in particular
depends on a key name appearing in raw text.

**Improvement.** Canonicalise before hashing instead of preserving types
through storage: define one canonical form (integers as integers when
integral, fixed float formatting, sorted keys), apply it to both the value
being signed and the value being verified, and the storage format stops
mattering. Migrate one authority at a time, accepting both hashes for a
release. Also pin a catalog digest in scenario patches (see AUD061-06).

## STR-04 — The save format is heavier than it needs to be

**Evidence.** A save is: snapshot → encoded dictionary → JSON text → zstd →
Z85 text → wrapped in an outer JSON envelope → pretty-printed with tabs
(`durable_store.gd:43`). It is then validated up to three times (temporary
file, old primary, installed file), each involving a hash and often a
decompress. On Web the Z85 step is run by building a JavaScript source string
with the whole save embedded and passing it to `eval`:

```gdscript
# run_save_codec.gd:357 (current code)
var fast: Variant = JavaScriptBridge.eval(WEB_Z85_ENCODE + "(" + JSON.stringify(Marshalls.raw_to_base64(source)) + "," + JSON.stringify(Z85_ALPHABET) + ")")
```

**Why it is weak.** The Z85 layer exists only because the container is JSON
text. It adds 25% size and a pass over every byte. The `eval` route needs the
hosting page to allow `unsafe-eval`, parses a multi-megabyte literal per save,
and base64-encodes first, so the data is copied several times on the main
thread. The 32 MiB cap (`MAX_STORAGE_BYTES`) hints at how large saves can get.

The inputs are escaped correctly; this is a cost and portability concern, not
an injection hole.

**Improvement**

1. Write the compressed bytes as a binary file with a small fixed header
   (magic, format version, sizes, SHA-256). No Z85, no outer JSON, no `eval`.
2. Keep reading the current format indefinitely.
3. If the JSON envelope must stay for now, replace `eval` with a function
   installed once and called through `JavaScriptBridge.get_interface`, passing
   a typed array.
4. Measure before and after on a late-run Web save; the perf harness has
   plans for exactly this.

## STR-05 — Threaded save relies on an unenforced immutability rule

**Evidence.** `begin_save_run` hands the worker a snapshot that deliberately
shares scenario records with the main thread:

```gdscript
# save_service.gd:92-95 (current code)
# Seeded scenario definitions are immutable content. The worker may share those
# records while encoding; recursively copying them on the input thread made an
# otherwise asynchronous late-run save pause every active cabinet frame.
var runtime_snapshot := run_state.to_save_snapshot_for_encoding()
```

`town_network.gd:160-163` notes that "runtime scenario preparation can
normalize nested authored records", which is the kind of mutation that would
break the assumption.

**Why it is weak.** If any code path mutates one of those shared records while
the worker iterates it, the result is a corrupted save or a crash that will
not reproduce.

**Improvement.** Call `make_read_only()` on the shared definitions when they
are stored in the town network. A stray write then fails loudly in
development. Add a stress check that mutates game state every frame during
repeated async saves and verifies each saved generation loads.

## STR-06 — RNG is a 31-bit Lehmer generator

**Evidence.** `rng_stream.gd`: multiplier 48271, modulus 2^31−1 (MINSTD),
range reduction by modulo (`:42-43`), seed normalisation by `abs(value) %
MODULUS` (`:92-96`).

**Assessment.** Determinism is well disciplined — no production code calls the
engine's global RNG — and this generator is adequate for a seeded
single-player game. Its limits:

- State is 31 bits, so one stream can produce at most about 2.1 billion
  distinct sequences. An eight-deck shoe has vastly more orderings; most are
  unreachable.
- Modulo reduction is slightly biased; negligible for small ranges.
- `abs()` of the minimum 64-bit integer is negative, giving a negative state.
  Seeds come from text hashing so it is unlikely, but it is unguarded.
- `derive_seed` (`:100-106`) mixes with XOR and multiply; adequate, not strong.

**Improvement.** Do not touch this in 0.6.x: changing the generator changes
every seed's outcome and invalidates saved RNG state. For 0.7, add a generator
version to the run snapshot, introduce a 64-bit generator (PCG or xoshiro)
with unbiased range reduction for new runs, and keep MINSTD for loading old
ones. Guard the `abs()` edge now; it is a one-line clamp that changes no
existing seed.

## STR-07 — 449 tests and no automation

**Evidence.** 449 test scripts, 160,172 lines. The runner is
`tools/check_godot.ps1` plus helpers — Windows PowerShell only. There is no CI
configuration in the repository. `python -m unittest discover -s tools/tests`
ran 180 tests on Linux with 7 failures, 18 errors and 13 skipped, all in
`test_bth_qa_storage`, `test_bth_qa_resident` and `test_bth_qa_atomic_receipt`
(drive-letter and `st_file_attributes` assumptions).

**Why it is weak.** The suite only runs when someone remembers to run it, on
one machine. The cost shows in the ledger as "inherited failure" triage
entries: tests that were already failing when someone next looked.

**Improvement**

1. A minimal CI job on a Windows runner: import, parse-all, Smoke suite,
   animation-liveness check, `tools/tests`. Fail the build on any of them.
2. Mark the Windows-only Python tests with `skipUnless(os.name == "nt")` so a
   non-Windows run is green or skipped, not red.
3. Record suite duration; the ledger notes a content-validation timeout
   (`BTH061-AUDIT-CONTENT-TIMEOUT-006`).
4. Longer term, a Linux headless job for the pure-logic suites. Godot headless
   runs them; only the PowerShell wrapper is Windows-bound.

## STR-08 — Process and repository weight

**Evidence**

- Ledger: 305 objectives, 195 open (65 current, 130 historical). 31 of the 65
  current open items are under the user-requested pause.
- The documented reconciliation command reports 1,594 errors against the
  committed snapshots. 1,030 are `RUNTIME_FUTURE_*` — artefacts of pinning
  `--now` to 2026-11-04 while the inventory has later timestamps. Run without
  `--now` it reports 884.
- `bth_task_ledger.json` is 30,718 lines; the runtime inventory 22,607.
- Working tree is 849 MB; 743 files under `docs/archive`, review artifacts and
  evidence inventories in source control.

**Why it is weak.** A check that always reports four-digit errors stops being
read. Real gaps are hidden among recorded-and-accepted ones.

**Improvement**

1. Refresh the pinned check time in `bth_task_ledger_checks.md` and its
   example report whenever the snapshots are refreshed, so the documented
   command reflects the committed data.
2. Add a baseline mode to the checker: accept a recorded set of known
   findings and report only new ones.
3. Review the 130 historical open objectives once; close, supersede or fold
   each into a current item.
4. Move bulky evidence and archived documents out of the main repository (a
   separate repository or release assets), keeping hashes and pointers.

These are the user's calls; nothing here authorises changing ledger state.

## STR-09 — Lint

**Evidence.** All 224 production scripts parse under gdtoolkit. `gdlint`
reports 448 findings: 293 `max-returns`, 111 `unused-argument`, 37
`class-variable-name`, 4 `function-variable-name`, 3 `duplicated-load`.
`.gdlintrc` disables file-length, method-count, argument-count and line-length
limits (`max-file-lines: 50000`, `max-line-length: 1000`) and
`private-method-call`.

**Improvement**

1. Fix the 3 `duplicated-load` in
   `scripts/core/persistent_environment_projection.gd:74,86`.
2. Review the 111 unused arguments: prefix intentional ones with `_`; the rest
   are either dead parameters or bugs where a value was meant to be used
   (for example `pinball_feature.gd:146` takes an `rng` it never reads —
   confirm that is intended in a seeded game).
3. The 37 class-variable-name findings are lazy-loaded script holders named
   like constants (`GameSurfaceCanvasScript`); either allow the pattern in the
   config or rename.
4. Re-enable `private-method-call` once cross-class calls to underscore
   methods (`RunSaveCodecScript._validated_storage_source`,
   `JsonCoerceScript._valid_sha256`, `_copy_dict`, …) are given public names.
5. Add `gdlint` to CI once the count is zero or baselined.

## STR-10 — Distribution

- **Windows executable is unsigned** (`export_presets.cfg:21`,
  `codesign/enable=false`). Players get a SmartScreen warning. Sign it.
- **Android and iOS presets are stale** (version code 9, 0.6.0) while
  `project.godot:18` still describes the game as "built for Steam, Android,
  and iOS", and the changelog says the mobile presets are blocked on signing.
  Either update the description or bring the presets current. Note that
  AUD061-08 matters far more on mobile.
- **Fixed 1280×720, non-resizable window** (`project.godot:28-29`). Fullscreen
  and resolution options exist in settings, so this is a default, not a
  limitation; worth confirming on high-DPI displays.

---

# Part D — Checked and found sound

So nobody re-audits these without cause:

- **Atomic save design.** Write temp → validate → rotate → install → validate
  → clean up, with rollback on each failure. Correct apart from AUD061-01.
- **Autosave failure handling.** Per-generation failure attribution,
  exponential backoff for transient errors, a visible status message
  (`foundation_main.gd:7195-7245`).
- **Determinism.** No production script calls `randi`, `randf`, `randomize`
  or `rand_from_seed`. `RandomNumberGenerator` appears only in two non-gameplay
  helpers in `foundation_main.gd`: the main-menu background picker (`:9279`) and
  the developer random-environment loader (`:11887`); `Crypto` only for the private
  capsule and a telemetry self-test.
- **File handling.** No `FileAccess.open` result is used without a null check.
- **Per-frame code.** No `_process`, `_physics_process` or `_draw` contains a
  deep copy; only one exceeds 60 lines.
- **Data files.** Every `data/**/*.json` parses; no duplicate ids among
  sibling records.
- **Web `eval` inputs.** Save data passed to `JavaScriptBridge.eval` is
  JSON-escaped; no injection path was found (cost concerns are in STR-04).
- **Web durability bridge.** Refuses unknown engine versions rather than
  guessing at engine internals; times out at 15 s.
- **Bankroll.** A property with a setter; apart from the three writes in
  AUD061-10 and two developer/test paths, changes go through `change_bankroll`.
- **Export filters.** Tests, tools, docs, review artifacts, native sources,
  logs and key files are excluded from all four presets.
- **Private capsule cryptography.** Encrypt-then-MAC, per-save IV, separate
  derived keys, constant-time comparison, binding to public heist state.

---

# Part F — Quality of life

From a static read of the start screen, settings, HUD, messages and input
handling. Not from play. QOL-01 to QOL-05 are small and worth taking in 0.6.1;
QOL-06 onward are for a later version and are listed so they are not lost.

What already exists, so the worker does not rebuild it: resolution, window
mode and vsync; master, music and SFX volume with a calm-audio option; UI
scale, text size, high contrast and reduce motion; drunk-effect mode; coach
tips with reset; object labels and borders; small-screen play; Abandon Run in
the Run Menu; Copy Seed on the run report; a confirm before deleting a saved
run; a recovery message when a backup save is used; tutorial skip; Rebet in
Blackjack, Baccarat and Roulette.

## QOL-01 — START NEW RUN replaces a saved run with no confirmation

> **Owner decision 2026-11-11:** now **Low**, optional.

**Severity:** Low, optional. **Area:** start screen, Run Setup.

### What is wrong

The main button is safe: with a save present it reads CONTINUE and loads it
(`foundation_main.gd:19044-19047`, `:20829-20831`). But Run Setup has its own
button that always starts a fresh run:

```gdscript
# foundation_screen_builder.gd:218 (current code)
host.run_config_start_button = host._button("START NEW RUN", host._portrait_menu_callback(Callable(host, "_on_start_pressed")))
```

`_on_start_pressed` (`foundation_main.gd:19033-19041`) does not check for an
existing save, and the button is only ever disabled when the run UI failed to
build (`:9723-9726`). The start screen even tells the player "Saved run ready.
Run Setup can delete it or configure the next run." (`:20823`). Deleting a
save asks "Delete the current saved run? This cannot be undone."
(`foundation_screen_builder.gd:251-253`); starting over it does not ask.

There is one save slot, so the new run's first autosave pushes the old run to
the backup file and the second removes it.

### Player impact

One click in Run Setup destroys an in-progress run. A player who opened Run
Setup to look at the seed or challenges can do it by accident.

### Reproduce first

Start a run, play, return to Main Menu. Open Run Setup, press START NEW RUN.
Confirm no prompt appears and that after two actions Continue no longer
offers the old run.

### Change required

1. In `_on_start_pressed`, when `_has_foundation_save()` is true, show a
   confirmation before starting: "Start a new run? Your saved run will be
   replaced." with *Keep saved run* as the default.
2. Reuse the pattern of `save_delete_confirmation` so focus, keyboard and
   touch behave the same.
3. Do not ask when no loadable save exists, or for the mandatory tutorial run.
4. The same guard applies to any other path that reaches
   `start_foundation_run` from the menu while a save exists
   (`start_generated_foundation_run`, `start_meta_quick_run`); check each
   caller (`:3869`, `:8450`, `:19163`, `:19173`, `:19996`). Run-report
   "New Run" after a finished run needs no prompt.

### Acceptance

- With a saved run, START NEW RUN asks first; cancel leaves the save intact.
- Without one, behavior is unchanged.

## QOL-02 — A failed autosave looks the same as a healthy one

**Severity:** Medium. **Take in 0.6.1** (pairs with AUD061-01/02).
**Area:** `scripts/ui/foundation_hud_view_model.gd`.

### What is wrong

The HUD shows one "save" status icon. Its state does not change when saving is
failing; only the tooltip text does, cut to 24 characters:

```gdscript
# foundation_hud_view_model.gd:360 (current code)
return "Autosave %s · %s" % [("on" if has_save else "pending").capitalize(), hud_short("current run" if status.is_empty() else status, 24, player_facing_text)]
```

While autosave is blocked the tooltip reads roughly "Autosave On · Autosave
failed. Retry fr…". It still says "On", and tooltips do not exist on touch.

### Player impact

A player can play for an hour with every save failing and only find out when
they try to leave. That is the worst moment to learn it.

### Change required

1. Pass the failure state (`autosave_retry_blocked`, or a non-OK
   `autosave_last_error`) into the HUD view model as its own field instead of
   inferring from text.
2. Give the save icon a distinct warning treatment in that state (the HUD
   already has an `alert` / `danger` icon style used for pit boss and
   pressure) and a tooltip that leads with the problem: "Not saving — open
   Run Menu to retry".
3. Show a one-time message when autosave first becomes blocked, and clear the
   warning when a save succeeds.
4. Do not add a modal; play should not be interrupted.

## QOL-03 — Internal wording shown to players

**Severity:** Low. **Area:** messages.

These strings can reach the player and use the code's vocabulary:

| Location | Text |
| --- | --- |
| `foundation_main.gd:12375` | "Room object authority is invalid." |
| `run_state.gd:7962` | "The Players Card tier sequence is invalid." |
| `meta_collection_service.gd:759` | "The terminal collection receipt is invalid." |
| `meta_collection_service.gd:762` | "The terminal collection intent is invalid." |
| `crew_run_facade.gd:371` | "The table host rejected an incomplete play transaction." |
| `foundation_main.gd:6997` | "Save waits for the live machine to settle." |
| `foundation_main.gd:7040` | "Room check pending; existing save retained." |

### Change required

Rewrite each to say what happened and what the player can do, in the game's
voice. For example: "That can't be used right now." / "Finish the current
spin, then save." Keep the original text in a log line for support. A sweep
for other `"message":` strings containing *authority, projection, publication,
envelope, transaction, receipt, intent* will find any others; the search used
here found only these.

## QOL-04 — Loaded numbers can render as `2.0`

**Severity:** Low. **Area:** rendering of saved values.

`QA-UX-005` fixed Craps die labels showing `2.0` and `5.0` after Continue,
because numbers read back from JSON are floats and were passed to string
conversion directly. That fix covered two renderers. The cause applies to any
saved integer drawn as text after a load. This is the display side of STR-03.

### Change required

1. Add one shared formatter for whole-number display and use it wherever a
   saved value is drawn (die faces, counts, card ranks, chip stacks, timers).
2. During AUD061-06 and AUD061-17 testing, watch every game screen after
   Continue for a trailing `.0`.

## QOL-05 — No way to copy version and save diagnostics

**Severity:** Low. **Area:** support.

There is no player-facing way to report what build they run or why a save
failed. The only clipboard actions are Copy Seed on the run report
(`foundation_main.gd:19212-19217`) and a developer placement export.

### Change required

Add a "Copy diagnostics" button in Settings that copies: build version and
identity (`BuildIdentity`), platform, the last save and load outcomes
(`SaveService.last_save_outcome`, `last_load_outcome`), and the autosave
failure code. No personal data, no save contents. On desktop, also offer
"Open save folder". This makes AUD061-01-class reports diagnosable.

## QOL-06 to QOL-10 — For a later version

- **QOL-06 Controls.** Input uses only the built-in `ui_*` actions plus
  hard-coded keys (F1, F2, F5, F9, 1–4). There is no controls reference
  screen and no rebinding. Add a read-only controls page first; rebinding
  needs named input actions, which is a larger change.
- **QOL-07 Rebet.** Present in Blackjack (`blackjack_repeat_bet`), Baccarat
  (`baccarat_rebet`) and Roulette. Check the other wagering games in play and
  add an equivalent where a player re-enters the same bet every round.
- **QOL-08 Pacing.** Reduce Motion exists, and the bag-opening reel has Skip.
  There is no faster-table or skip-animation option for repeated hands. Any
  such option must not change outcomes, timing-graded inputs or animation
  liveness (see `AGENTS.md`).
- **QOL-09 Save slots.** One autosave slot. A second slot, or "keep previous
  run", would remove the QOL-01 risk at the root.
- **QOL-10 Localisation.** No translation layer is used (no `tr()` calls); all
  text is in code and data. Not needed for 0.6.1; decide before the amount of
  text grows further.

---

# Part E — Recommended order of work

Reflects the owner decisions at the top of this document.

1. **AUD061-02**, with **AUD061-01** (simple version) in the same change.
   Reproduce both first.
2. **AUD061-16** if wanted (optional).
3. **AUD061-09, -10**, **QOL-02, -03, -04, -05** — small, independent fixes.
4. **AUD061-12** — settle the Web export before the RC is built.
5. Code freeze. **AUD061-04** version bump and **AUD061-05** changelog.
6. Tag `v0.6.1-rc.1`. Run on that exact commit: Smoke, animation-liveness,
   RTP/economy audits (`tools/craps_rtp_audit`, `tools/cross_economy_audit`),
   Windows and Web exports twice with manifest comparison. Close
   **AUD061-11** and run the **AUD061-17** gates `-005`, `-006`, `-007`.
7. Tag `v0.6.1`.
8. After release: Part C, starting with STR-07 (CI) because it protects
   everything after it, then STR-01 step 1; then QOL-06 to QOL-10.

Optional, any time, only if cheap: AUD061-08, -14, -15 (item 2), QOL-01.

Deferred until after 0.6.1: AUD061-03 (needs an export-tool change).

Not to be done: AUD061-06, AUD061-07, AUD061-13 migration (Appendix B).

---

# Appendix — Commands and raw results

```text
git diff --stat v0.6.0 HEAD                    1,012 files, +289,086 / -33,139 (all paths)
git diff --shortstat v0.6.0 HEAD -- scripts/core scripts/ui scripts/games data scenes
                                               145 files, +16,992 / -3,735
git diff --stat v0.6.1-pre.1 HEAD              134 files, +33,093 / -272
gdlint scripts/core scripts/ui scripts/games   448 problems, 0 parse errors
python3 -m unittest discover -s tools/tests    180 run; 7 failures, 18 errors, 13 skipped (Linux)
python3 tools/check_bth_task_ledger.py --owners docs/todo/bth_task_owner_snapshot.json \
    --runtimes docs/todo/bth_runtime_inventory_20261104.json --group current --now <checked_at>
                                               exit 1; 161 objectives, 9 batches, 1,594 errors
(same, without --now)                          exit 1; 884 errors
```

Production code size: 224 scripts, 234,854 lines, 11,738 functions.
Test code size: 449 scripts, 160,172 lines.

---

# Appendix B — Closed by owner decision (record only, do not work on)

These three were closed on 2026-11-11 because save data does not need to be
preserved. They stay here so the behavior is documented.

## AUD061-13 — The 0.6.1 Web build moves the save folder; every 0.6.0 Web player's data is orphaned

> **Owner decision 2026-11-11:** **closed — reset accepted.** Do not migrate. The only optional action is a one-line release note that Web progress from 0.6.0 does not carry over. Everything under "Change required if migrating" is void. Kept here as a record of the behavior.

**Severity:** Blocker (needs an explicit owner decision).
**Area:** `scripts/core/persistence_paths.gd`.

### What is wrong

In `v0.6.0`, every distribution build stored data under one root:

```gdscript
# v0.6.0 persistence_paths.gd (published code)
const DISTRIBUTION_ROOT := "user://distribution"
...
return DISTRIBUTION_ROOT if distribution_build() else ""
```

On `main`, Web builds use a new root:

```gdscript
# persistence_paths.gd:14, 26-32 (current code)
const WEB_DISTRIBUTION_ROOT := "user://distribution/web_0_6_1"
...
return WEB_DISTRIBUTION_ROOT if OS.has_feature("web") else DISTRIBUTION_ROOT
```

The comment above the constant explains the intent: browser storage outlives
uploads, so pre-release Web builds had left data in the shared root, and the
new "epoch" makes "the first launch clean". There is no migration from the old
root, and the 0.6.1 changelog does not mention it.

The paths affected are everything routed through `PersistencePaths`: the run
autosave, `settings.json`, `profile_inventory.json`, `meta_collection.json`.
(`scripts/tests/roulette_sealed_pending_check.gd:266-269` lists the four.)

### Player impact

A player who played the published 0.6.0 Web build will open 0.6.1 and find no
Continue, default settings, an empty home and collection, and tutorial state
reset. Their data still exists in the browser but nothing reads it. Windows
players are not affected.

This may be acceptable — it may even be what the owner wants — but it must be a
decision, not a side effect, and it must be announced.

### Decide first

The owner chooses one:

- **Migrate** (recommended): 0.6.0 Web players keep their progress.
- **Reset on purpose**: say so in the changelog and release notes.

### Change required if migrating

1. On Web distribution builds, at the first persistence access, if the new
   root has **no** loadable file for a given store and the old root
   (`user://distribution`) has one, copy that store's primary and `.bak` into
   the new root. Do it per store, not all-or-nothing.
2. Validate before trusting. Run each copied file through its normal validator
   (`SaveService._payload_dictionary_loadable`, `_settings_payload_valid`,
   `_profile_payload_valid`, `_meta_payload_valid`). Discard a copy that fails.

   *Why:* the old root also holds leftovers from pre-release Web builds — the
   very data the epoch was introduced to avoid. Validation plus the 0.6.0 →
   0.6.1 save gate (AUD061-06) is what makes importing it safe.
3. Copy, do not move. Leave the old root intact so a failed import can be
   retried by a later patch.
4. Record that migration ran (a small marker file in the new root) so it
   happens once and a player who deliberately starts fresh is not re-imported.
5. Force a browser storage sync after the copy, using the existing
   `WebSaveDurabilityBridge`, so the import survives an immediate tab close.
6. Developer placement data should **not** be imported.

### Change required if resetting on purpose

1. Add a changelog and release-note line: Web saves, settings and home
   progression from 0.6.0 do not carry over to 0.6.1.
2. Rename the root to something that will not need changing again for 0.6.2
   (for example `web_0_6_line`), or document in the constant's comment that it
   must **not** be bumped per release. As written, the name `web_0_6_1` invites
   the next person to bump it to `web_0_6_2` and wipe players again.

### Tests to add

- Contract (migrate): given a valid 0.6.0-layout tree under
  `user://distribution` and an empty new root, first access yields a loadable
  run, settings, profile and meta in the new root; a second launch does not
  re-import; an invalid old file is skipped without blocking the others.
- Contract (both): Windows distribution root is unchanged.
- Manual on Web: play the published 0.6.0 build, then load the 0.6.1 candidate
  on the same origin and confirm the chosen behavior.

### Acceptance

- The owner's decision is recorded, and the build and changelog match it.
- The root name will not cause another reset at the next patch.

### Risk

Medium if migrating, because imported saves cross a version boundary; that is
why this item depends on AUD061-06.

---

## AUD061-06 — No save fixture from the published 0.6.0 build

> **Owner decision 2026-11-11:** **dropped.** Old saves do not need to load. Do not capture 0.6.0 saves or add upgrade tests. Kept as a record; the scenario-patch behavior described here is still worth knowing when changing scenario data.

**Severity:** Blocker. **Area:** save compatibility.

### What is wrong

The persistence layer changed substantially since 0.6.0 and there is no test
that loads a save made by the build players actually have.

- Since `v0.6.0`: `run_state.gd` +1,976 lines, `run_save_codec.gd` +342,
  `save_service.gd` +276, `durable_store.gd` +44. `CODEC_VERSION` and
  `SAVE_VERSION` are both still `2`.
- New load-time behavior was added for old saves, for example the Blackjack
  ledger integer rewriter (`run_save_codec.gd:249-342`) and the
  `StorageNumericJson` parser.
- Saved runs store each town node's seeded scenario definition as a **patch
  against the shipped catalog**, not as a full copy:

  ```gdscript
  # run_save_codec.gd:582-592 (current code)
  static func _decode_seeded_scenario_definition(entry: Dictionary) -> Dictionary:
      var scenario_id := str(entry.get(SCENARIO_DEFINITION_REF_KEY, "")).strip_edges()
      var definition := _catalog_scenario_definition(scenario_id).duplicate(true)
      if definition.is_empty():
          return {}
      if entry.has(SCENARIO_DEFINITION_PATCH_KEY):
          ...apply patch to the *current* catalog definition...
  ```

  `v0.6.0` used the same encoding. Four catalog packages changed since then:
  `env06_7_bars_road.json`, `env06_7_queen_public.json`,
  `env06_7_roadside_shelter.json`, `env06_7_underground_lounge.json`. A 0.6.0
  save resumed in 0.6.1 therefore gets a definition that is neither the old
  one nor the new one: new catalog base plus an old patch. The codec comment
  at `:571-573` notes that sequence signatures are type-sensitive and a bad
  definition only fails later, when a room tries to mount it. If a scenario id
  were removed from the catalog, the definition decodes to `{}`.
- Existing migration fixtures cover 0.3.0 and 0.3.3
  (`scripts/tests/fixtures/run_state_0_3_*.json`), 0.5.1
  (`fixtures/integ06_1/v0_5_1/`), and three **mid-0.6 development** captures
  from commit `31e434c4` (`fixtures/integ06_1/mid_0_6/`), exercised by
  `scripts/tests/foundation/integ06_1_v051_migration_smoke.gd`. None was
  produced by the published `v0.6.0` build.
- One compatibility snapshot exists, for Gala Night only
  (`scenario_engine.gd:19`).
- The release plan already tracks this as **`BTH061-012`** ("Required before
  release / partial, final packaging pending"). It records that genuine 0.6 Web
  and Windows saves loaded on candidate `ead6856` (2026-10-18), and that
  profile and meta inventory compatibility is still to be qualified. That
  evidence is manual, tied to a commit three weeks older than `main`, and
  predates both the later persistence changes and the Web save-root change in
  AUD061-13. It should be folded into this item, not treated as closing it.

### Player impact

Unknown, which is the problem. The plausible failures are a Continue that
loads but breaks when the player travels to a node whose scenario changed, a
Blackjack hand whose ledger no longer validates, or a run rejected as corrupt.

### Change required

1. **Produce real 0.6.0 saves.** Using the published `v0.6.0` Windows and Web
   builds (not a source checkout), capture saves in these states at minimum:
   - fresh run, first room;
   - mid-hand Blackjack with an authority ledger in progress;
   - mid-game in Roulette, Bar Dice (Reveal pending), Pull Tabs (ticket in
     tray), Coin Pusher (coins on the bed), Video Poker (held cards), Slots
     (feature active), Craps (point set), Baccarat, Scratch Tickets, Crew
     poker;
   - active debt with a lender whose terms changed in `lenders.json`;
   - a pending seeded scenario on a town node for **each** of the four changed
     packages;
   - an active Crew heist (exercises the private capsule, see AUD061-15);
   - a late-run save, large;
   - a completed-run (terminal) save with rewards pending;
   - `settings.json`, `profile_inventory.json`, `meta_collection.json` with a
     furnished home.
2. **Add them as a `v0_6_0` fixture class** beside the existing ones, with the
   same provenance sidecar format the `integ06_1` fixtures use (build
   identity, capture state, SHA-256). Follow `AGENTS.md` QA storage rules when
   capturing.
3. **Extend the migration smoke** so each fixture is loaded, the run reaches a
   playable room, one legal action is taken in the saved game, the run is
   saved and loaded again, and — for the scenario fixtures — the player
   travels to the node and the scenario mounts.
4. **Fix what it finds.** If a changed scenario package breaks a 0.6.0
   definition, add a compatibility snapshot the way Gala Night has one, rather
   than reverting the content.
5. **Longer term (not for 0.6.1):** store a digest of the catalog definition
   with each patch so the loader can tell "catalog changed under this save"
   from "definition is corrupt". Tracked under STR-03/STR-04.

### Acceptance

- Every 0.6.0 fixture loads and plays on the RC, on native and Web.
- One manual Continue on Windows and one on Web from a real 0.6.0 profile.
- If AUD061-13 migrates Web data, the Web fixtures are loaded through the
  migration path.

### Risk

This item may uncover real defects late. Start it early, in parallel with the
code fixes.

---

## AUD061-07 — Save and codec versions are never checked on load

> **Owner decision 2026-11-11:** **dropped** for now. Revisit when saves start to matter.

**Severity:** High. **Area:** `save_service.gd`, `run_save_codec.gd`.

### What is wrong

`SAVE_VERSION := 2` (`save_service.gd:9`) is written into every payload
(`:273`, `:457`) and never read. `_run_data_from_payload` (`:465-482`) checks
only the schema string. `RunSaveCodec.decode` (`:98-108`) treats a missing or
non-positive codec version as legacy and **every** positive value as current:

```gdscript
# run_save_codec.gd:98-101 (current code)
static func decode(saved_state: Dictionary) -> Dictionary:
    if int(saved_state.get(CODEC_KEY, 0)) <= 0:
        var legacy: Variant = _restore_exact_integer_markers(saved_state)
        return legacy as Dictionary if typeof(legacy) == TYPE_DICTIONARY else {}
```

### Player impact

A save written by a newer build (0.6.2, 0.7) loads into an older one with no
warning and is then re-saved in the old shape, quietly dropping or corrupting
whatever the newer format added. This happens whenever a player rolls back, or
a browser serves a cached older build against newer stored data.

### Change required

1. In `_run_data_from_payload` and in `_payload_dictionary_loadable`, read
   `payload.version`. If it is greater than `SAVE_VERSION`, report the
   generation as **present but unsupported**, not as corrupt.
2. In `RunSaveCodec.decode`, return an explicit "unsupported codec" result
   when `CODEC_KEY > CODEC_VERSION`.
3. Carry a distinct outcome through `last_load_outcome` (for example
   `"newer-version"`) and show a specific message on the start screen: the
   save was made by a newer version; update the game. Do **not** offer to
   overwrite it without a confirm.
4. Make sure a newer-version primary is never rotated into `.bak` and then
   overwritten by an autosave from the old build. The simplest rule: when the
   slot holds an unsupported newer generation, a new run saves to that slot
   only after explicit confirmation.

   *Why:* the durable store treats "not loadable" as "safe to replace". A
   newer save is not loadable here but is the player's real progress.
5. Adding the check costs nothing today because all existing saves are
   version 2 or legacy.

### Tests to add

- Payload with `version: 3` → reported unsupported, not loaded, not replaced
  by an autosave.
- Storage with `run_save_codec_version: 3` → same.
- All existing legacy fixtures still load.
