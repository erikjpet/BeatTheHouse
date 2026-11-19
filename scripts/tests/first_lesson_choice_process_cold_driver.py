import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
godot = sys.argv[1]
if not os.environ.get("BTH_SAVE_DIR") or not os.environ.get("BTH_QA_EVIDENCE_DIR"):
    raise SystemExit("Guarded QA storage environment is required")
for phase in ("write", "cold"):
    env = os.environ.copy()
    env["BTH_FIRST_LESSON_PHASE"] = phase
    command = [godot, "--headless", "--path", str(root), "--script", "res://scripts/tests/first_lesson_choice_process_cold_check.gd"]
    completed = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=38)
    print(completed.stdout, end="")
    print(completed.stderr, end="", file=sys.stderr)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)