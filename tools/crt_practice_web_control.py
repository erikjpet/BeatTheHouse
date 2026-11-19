#!/usr/bin/env python3
"""Atomically submit one bounded UI command to an existing fresh Web QA run."""
import sys
sys.dont_write_bytecode = True
import argparse
import json
import os
from pathlib import Path
import re
from bth_qa_storage import Layout, validate_layout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--sequence", required=True, type=int)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,95}", args.run_id) or not 1 <= args.sequence <= 40:
        raise ValueError("Exact fresh run ID and sequence 1..40 required")
    manifest = Path(r"E:\CodexQA\BTH\runs") / args.run_id / "evidence" / "storage-manifest.json"
    data = json.loads(manifest.read_text(encoding="utf-8-sig"))
    if data.get("schema") != "bth-qa-storage/v1" or not data.get("prepared") or data["run_id"] != args.run_id:
        raise ValueError("Prepared run manifest identity differs")
    fields = ("root", "workspace", "run_root", "profile", "temp", "evidence", "appdata", "localappdata", "home", "cache", "save_dir", "pycache")
    layout = Layout(**{key: Path(data["paths"][key]) for key in fields}, run_id=data["run_id"],
                    token=data["token"], expected_write_bytes=data["expected_write_bytes"],
                    reserve_bytes=data["reserve_bytes"], prepared=True)
    control = layout.evidence / "control"
    if layout.manifest_path != manifest or not control.is_dir():
        raise ValueError("The admitted Web worker has not created its control directory")
    command = json.load(sys.stdin)
    if not re.fullmatch(r"[a-z0-9-]{1,36}", command.get("label", "")) or not isinstance(command.get("actions"), list) or len(command["actions"]) > 25:
        raise ValueError("Bounded command shape required; the worker validates each action")
    destination = control / f"command-{args.sequence:02}.json"
    temporary = destination.with_suffix(".pending")
    validate_layout(layout, prepared=True, extra_write_paths=(control,))
    if destination.exists() or temporary.exists():
        raise ValueError("Command sequence already occupied; no overwrite")
    with temporary.open("x", encoding="utf-8") as output:
        json.dump(command, output)
        output.write("\n")
    os.replace(temporary, destination)
    print(json.dumps({"command": str(destination), "label": command["label"]}))


if __name__ == "__main__":
    main()
