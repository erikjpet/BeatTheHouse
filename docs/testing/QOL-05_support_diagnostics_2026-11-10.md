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

Pending finished code/ledger commits, existing-pipeline promotion and actual deployed copy/clipboard/field inspection. No Web copy success is claimed yet.
