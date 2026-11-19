#!/usr/bin/env python3
"""Fresh guarded CRT capture or navigation after admitted source refresh."""
import sys
sys.dont_write_bytecode = True
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from bth_qa_storage import plan_layout, prepare_layout, validate_layout, StorageGuardError
from bth_qa_guarded_run import execute

GODOT = Path(r"D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe")
GODOT_SHA = "fc759f9d296fe54f09ab66d41df6ddd2d278493b0e71109f6688ef029ad271ae"
COPY_FILES = [
    "scripts/core/environment_base_semantic_records.gd",
    "scripts/core/environment_instance.gd",
    "scripts/core/environment_object_manifest.gd",
    "scripts/core/environment_placement.gd",
    "scripts/core/environment_slot_binder.gd",
    "scripts/tests/close01_slot_practice_room_check.gd",
    "scripts/tests/ui_scene/check_game_library_launchers.gd",
    "scripts/ui/environment_interaction_controller.gd",
    "scripts/ui/environment_interaction_view_model.gd",
    "scripts/ui/foundation_main.gd",
    "scripts/ui/meta_session_controller.gd",
    "scripts/ui/pixel_scene_canvas.gd",
    "scripts/core/home_practice_console.gd",
    "scripts/tests/crt_practice_cold_continue_check.gd",
    "scripts/tests/crt_practice_console_check.gd",
    "scripts/tests/ui_scene/capture_crt_console.gd",
    "scripts/tests/ui_scene/check_crt_console_navigation.gd",
    "scripts/tests/ui_scene/check_crt_room_entry.gd",
    "scripts/ui/crt_practice_menu.gd",
    "scripts/ui/crt_practice_screen.gdshader",
    "tools/crt_practice_cold_continue.py",
    "tools/crt_practice_web_pack.py",
    "tools/crt_practice_web_smoke.cjs"
]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-checkout", required=True)
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--navigation", action="store_true",
                        help="Run the fixed CRT navigation gate instead of the short capture")
    args = parser.parse_args()
    source = Path(args.source_checkout).resolve(strict=True)
    layout = plan_layout(root=r"E:\CodexQA\BTH", workspace=args.workspace, run_id=args.run_id)
    outputs = tuple({(layout.workspace / name).parent for name in COPY_FILES})
    validate_layout(layout, extra_write_paths=outputs)
    if digest(GODOT) != GODOT_SHA:
        raise ValueError("Approved pinned Godot executable identity differs.")
    inputs = {}
    for name in COPY_FILES:
        path = source / name
        if path.resolve(strict=True) != path or not path.is_file():
            raise ValueError("Source input is absent or aliased: " + name)
        inputs[name] = digest(path)
    layout = prepare_layout(layout)
    validate_layout(layout, prepared=True, extra_write_paths=outputs)
    for name in COPY_FILES:
        target = layout.workspace / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / name, target)
        if digest(target) != inputs[name]:
            raise ValueError("Authoritative refresh hash mismatch: " + name)
    (layout.evidence / "source-refresh.json").write_text(json.dumps({
        "source": str(source), "workspace": str(layout.workspace),
        "source_sha256": inputs, "scope": "Corrected CRT source; not deployment evidence."
    }, indent=2) + "\n", encoding="utf-8")
    command = [str(GODOT), "--path", str(layout.workspace), "--log-file",
               str(layout.evidence / "godot.log"), "--script",
               "res://scripts/tests/ui_scene/check_crt_console_navigation.gd" if args.navigation
               else "res://scripts/tests/ui_scene/capture_crt_console.gd"]
    result = execute(layout, command, timeout=300 if args.navigation else 150, cpu_rate=1200)
    image = layout.evidence / ("crt-default.png" if args.navigation else "crt-corrected-desktop-first.png")
    print(json.dumps({"exit_code": result.get("exit_code"), "active_at_release": result.get("active_at_release"),
                      "error": result.get("error"), "image": str(image), "image_exists": image.is_file(),
                      "job_receipt": str(layout.evidence / "job.json")}), flush=True)
    return 0 if result.get("exit_code") == 0 and result.get("active_at_release") == 0 and image.is_file() else 1

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except StorageGuardError as error:
        print(json.dumps({"status": "CAPTURE_STORAGE_REJECTED", **error.as_dict()}), file=sys.stderr)
        raise SystemExit(2)
