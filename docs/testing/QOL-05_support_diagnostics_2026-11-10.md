# QOL-05 — Copy build and save diagnostics

Started from main **1874c946d0b379410f99c70104e2d798be1640c0**(QOL-04 receipt); NEXT d258f3dc14866f2e8bfd9ee35e3e707507acea95. Specification: [audit work order](../todo/BTH_0.6.1_audit_work_orders.md#qol-05--no-way-to-copy-version-and-save-diagnostics).

## Before

Command:
Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/qol05_support_diagnostics_check.gd
under approved E-root/capped Job, pinned4.6.stable.official.89cea1439.

Actual initial interface check:
```
QOL05_BEFORE {"available_buttons":["1280 x 720","Windowed","[X] VSync","[ ] Calmer Music","[ ] Play on small screen","[X] Coach tips","Reset tips","[X] Object labels and borders","Normal","[ ] High Contrast","Wavy Distortion","[ ] Reduce Motion","[ ] Environment placement mode","[ ] Environment slot placement mode","Game Library (Debug)","Environment Library (Debug)","Back","Restore Defaults","Apply"],"checks":4,"failures":["Settings offers Copy diagnostics","Desktop Settings offers Open save folder","Host assembles current safe diagnostics","Host routes desktop save-folder action"]}
```
Exact original interface source retained in before_interface_check.gd.txt. 4checks/4failures: both buttons and both host routes missing. Confirmed by actual built Settings control list, not just a source search.

## Change

Settings now has a Support section with Copy diagnostics and desktop-only Open save folder. Host gathers a fresh report at activation from BuildIdentity, OS platform, SaveService last-save/last-load outcomes and autosave failure code. New support_diagnostics.gd constructs only permitted scalar fields; it does not serialize source dictionaries or manifest wholesale. Slot IDs, file paths, messages, fingerprints, save bodies, money, seeds and preferences are absent. Status/code tokens reject paths/free text; build identity hashes are shape-checked. Whole raw errors or personal paths never enter the copied report.

Copy leaves live/draft settings untouched and reports feedback in Settings. New controls join the existing accessibility/focus/scroll layout. Folder action uses the actual active save directory only on desktop; a missing directory or system-open error produces a short next-action message. Native tests intercept final clipboard/system-shell boundaries; they do not overwrite the system clipboard or launch Explorer. Production writes to DisplayServer clipboard and calls OS.shell_open for the directory.

Changed production: scripts/ui/support_diagnostics.gd(new),settings_menu.gd,foundation_main.gd. No save/schema/version migration, rules/content, canvas scheduling or pause changes.

## After

Initial same interface check after compilation correction:4checks/0failures. The first implementation's token unicode value needed an explicit integer type; its parse failure and output are retained before correction. Expanded actual-Main contract tests privacy allowlists and synthetic private markers, actual current values, no mutation of outcomes/drafts, copy feedback, focus, responsive rows, platform gates, folder target and success/error/missing-directory paths.

Actual full check output:
```
QOL05_SAFE_REPORT {
  "autosave_failure_code": "disk_full",
  "build": {
    "export_sha256": "",
    "identity_source": "source_harness",
    "source_commit": "",
    "source_tree": "",
    "version": "0.6.0"
  },
  "last_load": {
    "backup_exists": true,
    "backup_loadable": true,
    "outcome": "loaded-backup",
    "primary_exists": true,
    "primary_loadable": false
  },
  "last_save": {
    "error": 19,
    "error_code": "rename_failed",
    "ok": false
  },
  "platform": "Windows",
  "schema": "beat_the_house.support_diagnostics/v1"
}
QOL05_SUPPORT_DIAGNOSTICS {"checks":42,"clipboard":"captured at final platform boundary; no system clipboard write in native test","failures":[],"folder":"system-open stub records actual path; Explorer launch not claimed"}
```
42checks/0failures; modal_focus_lifetime_check.gd14checks/0failures. No assertion was skipped or weakened. Native source-tree identity correctly reports source_harness with no embedded commit; exact embedded build identity will be verified on NEXT. Actual Explorer launch is not claimed.

Raw jobs/commands/stdout/storage manifests and pre-child launch gates retained in evidence/QOL-05_20261110/. Smoke4stages pass/7fail versus baseline4/7; content25/runtime16 exact old assertions. New normalized stderr categories: []. Performance9old failures versus baseline10; missing native Coin Pusher qualification remains inherited. Actual command: powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages. Exit1/no timeout/zero active processes. Baseline Python180/0.

## NEXT

Verified **d389abcf59c682ba02d378ec4c7ff4d94f20de25**, containing code **25822cff6d0f7debb2f9db688515a77f4655cc49**, tree1c507e9054f57478912937de58b2e7608fb2d27f, archive171ef3c3a353f7292989335d973ce4221c1efb6e106151d10a599f6bee500d58. Existing watcher promoted at2026-11-11T05:49:29Z,phasecurrent/errornull. Exact metadata/REF/HTML/JS/PCK/native GET hashes plus engine HEAD length/MIME/pins:10/10PASS; ordinary /dev/entry resolves to this identity.

Fresh approved browser profile; unmodified NEXT build, ordinary Settings/Copy/normal Daily Challenge/Menu Save/Load inputs. Startup/Settings clean; Support Copy diagnostics visible, desktop Open save folder absent on Web. Four actual button clicks copied valid reports with exact full commit/tree, version0.6.0-dev+d389abcf59c6, platformWeb, embedded_manifest identity. Actual reports in deployed_clipboard_reports.json; relevant raw values:
```
{"action_id": 2, "autosave_failure_code": "", "last_load": {"backup_exists": false, "backup_loadable": false, "outcome": "nothing-loadable", "primary_exists": false, "primary_loadable": false}, "last_save": {"error": 0, "error_code": "", "ok": true}}
{"action_id": 10, "autosave_failure_code": "save_start_failed", "last_load": {"backup_exists": false, "backup_loadable": false, "outcome": "nothing-loadable", "primary_exists": false, "primary_loadable": false}, "last_save": {"error": 12, "error_code": "temporary_open_failed", "ok": false}}
{"action_id": 16, "autosave_failure_code": "", "last_load": {"backup_exists": false, "backup_loadable": false, "outcome": "nothing-loadable", "primary_exists": false, "primary_loadable": false}, "last_save": {"error": 0, "error_code": "", "ok": true}}
{"action_id": 22, "autosave_failure_code": "", "last_load": {"backup_exists": true, "backup_loadable": false, "outcome": "loaded-primary", "primary_exists": true, "primary_loadable": true}, "last_save": {"error": 0, "error_code": "", "ok": true}}
```
Initial report saveOK/no load. In the normal disposable run, a declared own-profile temporary-write fault caused actual explicit Save to fail: error12/temporary_open_failed plus autosave save_start_failed. Second Copy reported those current values. Removed only that owned fault, retried actual Save successfully; third Copy reportsOK/error0/emptyfailurecode. Actual enabled Load restored the saved run with visible Run loaded result; fourth Copy reportsloaded-primary/primaryexists/loadabletrue/backupexists true. backup_loadablefalse is the actual returned load outcome field(the primary path did not require backup recovery), not a claim about every backup's validity. Last-load fields describe the last Load operation, so remain initial values before actual Load.

Every copy shows Diagnostics copied feedback. Screenshots00startup,01Settings,01wheel/02copy,07failedSave,09wheel/10copy,13saveRecovery/16copy,19loaded/22copy inspected. Report keys and omissions verified; no paths,slot IDs,free messages,seeds,money or save contents copied. Browser helper reads clipboard only immediately after its owned trusted Copy click, returns only expected-schema/current-SHA reports and suppresses unrelated clipboard text. Export hash is empty because the embedded manifest does not bind its own completed export-tree digest; exact serving hashes are independently verified above.

Four clipboardchecksPASS; pageerrors0,consolewarnings/errors0,jobexit0/no timeout/zero active processes after close. Fault removed before finish. Native42checks/0 plus modal14/0 remain. Native desktop folder target/success/error/missing-path routes are stub-tested; an actual Explorer launch is not claimed. No personal profile,script/scene/path override or item/scenario change.

Reconciliation before push:1683inherited errors across52existing tasks, no new AUD061/QOL-05 findings. Parent stays Open with10orders remaining.
