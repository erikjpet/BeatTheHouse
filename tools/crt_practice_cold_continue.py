#!/usr/bin/env python3
"""Sequential engine-cold CRT acceptance inside an already guarded fresh Job.

Launch this worker only through bth_qa_guarded_run.py. It creates no Job, changes
no caps, and never copies profiles/saves. Windows children inherit the existing
Job because no breakaway flags are used. Each engine must close successfully
before the next starts. Every output is under the admitted evidence directory.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess
import time

from bth_qa_storage import Layout, check_launch, validate_layout


def _in_job(handle):
    present = ctypes.c_int()
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.IsProcessInJob.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_int)]
    kernel.IsProcessInJob.restype = ctypes.c_int
    if not kernel.IsProcessInJob(handle, None, ctypes.byref(present)):
        raise ctypes.WinError(ctypes.get_last_error())
    return bool(present.value)


def _layout_from_manifest():
    run_root = Path(os.environ["BTH_QA_RUN_DIR"])
    manifest = run_root / "evidence" / "storage-manifest.json"
    data = json.loads(manifest.read_text(encoding="utf-8-sig"))
    if data.get("schema") != "bth-qa-storage/v1" or not data.get("prepared"):
        raise ValueError("Only an already prepared fresh QA layout is admitted")
    names = ("root", "workspace", "run_root", "profile", "temp", "evidence", "appdata",
             "localappdata", "home", "cache", "save_dir", "pycache")
    layout = Layout(**{name: Path(data["paths"][name]) for name in names},
                    run_id=data["run_id"], token=data["token"],
                    expected_write_bytes=data["expected_write_bytes"],
                    reserve_bytes=data["reserve_bytes"], prepared=True)
    if layout.run_root != run_root or layout.manifest_path != manifest:
        raise ValueError("Manifest does not identify this guarded run")
    return layout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Existing approved pinned Godot executable")
    parser.add_argument("--timeout-per-phase", type=int, default=240)
    args = parser.parse_args()
    if os.name != "nt" or not 1 <= args.timeout_per_phase <= 500:
        raise ValueError("Windows and bounded phase timeout 1..500 seconds required")
    layout = _layout_from_manifest()
    evidence = layout.evidence
    outputs = [evidence / "crt-cold-supervisor.json", evidence / "crt-cold-expected.json"]
    for phase in ("producer", "cold"):
        outputs.extend((evidence / f"crt-cold-{phase}.stdout.log",
                        evidence / f"crt-cold-{phase}.godot.log"))
    # The guard admits writable directories; individual receipts become files
    # after the first write. Keep the exact evidence parent admitted at every
    # launch instead of resubmitting those existing files as directories.
    # Gate before the first output write and again immediately before each child.
    validate_layout(layout, prepared=True, extra_write_paths=(evidence,))
    env = dict(os.environ)  # Retain exactly the supervisor's admitted child env.
    check_launch(layout, cwd=layout.workspace, env=env, extra_write_paths=(evidence,))
    if not _in_job(ctypes.c_void_p(-1)):
        raise RuntimeError("Worker is not contained by the inherited guarded Job")
    executable = Path(args.godot)
    if not executable.is_absolute() or not executable.is_file():
        raise ValueError("Pinned Godot must be an existing absolute file")
    receipt_path = outputs[0]
    if receipt_path.exists() or (evidence / "crt-cold-expected.json").exists():
        raise ValueError("Cold acceptance evidence is single-use; use a fresh guarded run")
    receipt = {"schema": "bth.crt_engine_cold_supervisor/v1", "inherited_job": True,
               "storage_manifest": str(layout.manifest_path), "phases": [],
               "scope": "Two sequential Godot processes, same fresh admitted QA layout; no copy/migration"}
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    for phase in ("producer", "cold"):
        stdout_path = evidence / f"crt-cold-{phase}.stdout.log"
        godot_log = evidence / f"crt-cold-{phase}.godot.log"
        command = [str(executable), "--headless", "--path", str(layout.workspace),
                   "--log-file", str(godot_log), "--script",
                   "res://scripts/tests/crt_practice_cold_continue_check.gd", "--", f"--{phase}"]
        record = {"phase": phase, "command": command, "started_epoch": time.time()}
        # Reconcile actual cwd/environment/output paths immediately before Popen.
        validate_layout(layout, prepared=True, extra_write_paths=(evidence,))
        record["launch_gate"] = check_launch(layout, cwd=layout.workspace, env=env,
                                             extra_write_paths=(evidence,))
        with stdout_path.open("xb") as output:
            child = subprocess.Popen(command, cwd=str(layout.workspace), env=env,
                                     stdin=subprocess.DEVNULL, stdout=output,
                                     stderr=subprocess.STDOUT, creationflags=0)
            record["pid"] = child.pid
            try:
                record["inherited_job"] = _in_job(child._handle)
                if not record["inherited_job"]:
                    raise RuntimeError("Godot child did not inherit guarded Job containment")
                record["exit_code"] = child.wait(timeout=args.timeout_per_phase)
            except BaseException:
                if child.poll() is None:
                    child.kill()  # Only this worker's known child.
                child.wait(timeout=10)
                raise
            finally:
                record["finished_epoch"] = time.time()
                record["closed"] = child.poll() is not None
                receipt["phases"].append(record)
                receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"phase": phase, "exit_code": record["exit_code"],
                          "closed": record["closed"], "stdout": str(stdout_path)}), flush=True)
        if record["exit_code"] != 0 or not record["closed"]:
            return 1
        if phase == "producer" and not (evidence / "crt-cold-expected.json").is_file():
            raise RuntimeError("Producer closed without its expected-identity receipt")
    receipt["complete"] = True
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
