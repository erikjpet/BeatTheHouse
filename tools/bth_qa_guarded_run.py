#!/usr/bin/env python3
"""Prepare/check future QA storage and run one explicit resource-capped worker.

This entrypoint never moves old workspaces, profiles or saves. Its child must be
storage-aware: use the manifest paths (and explicit browser profile arguments).
It is not a filesystem sandbox for arbitrary hardcoded writes inside a worker.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import threading
import time

from bth_qa_storage import (StorageGuardError, plan_layout, prepare_layout,
                            validate_layout, child_environment, check_launch)
from bth_qa_command_paths import command_write_paths

GIB = 1024 ** 3


def execute(layout, command, *, timeout=120, cpu_rate=1200, extra_write_paths=(),
            job_factory=None, worker_factory=None):
    """Run only after the supplied prepared layout passes the actual launch gate."""
    if not command or not 1 <= timeout <= 1200 or not 1 <= cpu_rate <= 1500:
        raise ValueError("Explicit worker, timeout1-1200 and CPU rate1-1500 required")
    extra_write_paths = tuple(extra_write_paths) + command_write_paths(layout, command)
    env = child_environment(layout, os.environ)
    pre_job_gate = check_launch(layout, cwd=layout.workspace, env=env, extra_write_paths=extra_write_paths)
    if job_factory is None or worker_factory is None:
        # Import the maintained helpers only after storage admission. Disabling
        # bytecode applies to this supervisor and the child environment.
        helpers = Path(r"D:\Projects\site\scripts\bth_cpu_job")
        if not (helpers / "cpu_job.py").is_file():
            raise ValueError("Maintained capped Job helpers are unavailable; no uncapped fallback")
        sys.path.insert(0, str(helpers))
        from cpu_job import CpuCappedJob
        from native_proof_worker import SuspendedWorker
        job_factory = job_factory or (lambda: CpuCappedJob(cpu_rate, 2 * GIB))
        worker_factory = worker_factory or SuspendedWorker
    record = {"schema": "bth.qa_guarded_run/v1", "command": list(command),
              "storage_manifest": str(layout.manifest_path),
              "storage_manifest_sha256": hashlib.sha256(layout.manifest_path.read_bytes()).hexdigest(),
              "storage": layout.as_dict(), "timeout_seconds": timeout,
              "storage_gate_before_job": pre_job_gate,
              "error": None, "cleanup_errors": [], "log_truncated": False}
    with ExitStack() as owned:
        for name in ("launch-claim.json", "worker.log", "job.json"):
            if (layout.evidence / name).exists():
                raise StorageGuardError("occupied_launch", layout.evidence / name,
                                        "prepared runs are single-use; choose a fresh run ID")
        # Claim and reserve every output synchronously before creating a Job or
        # child. open(x) also closes the competing-launch race after exists().
        claim = owned.enter_context((layout.evidence / "launch-claim.json").open("x", encoding="utf-8"))
        json.dump({"schema": "bth.qa_launch_claim/v1", "manifest_sha256": record["storage_manifest_sha256"],
                   "claimed_epoch": time.time()}, claim)
        claim.flush()
        output = owned.enter_context((layout.evidence / "worker.log").open("xb"))
        receipt = owned.enter_context((layout.evidence / "job.json").open("x", encoding="utf-8"))
        json.dump({"status": "LAUNCH_PENDING", **record}, receipt)
        receipt.flush()
        job = worker = reader = None
        try:
            job = job_factory()
            record["limits"] = job.verify(cpu_rate, 2 * GIB)
            # Final gate immediately before the suspended child constructor.
            record["storage_gate_before_child"] = check_launch(
                layout, cwd=layout.workspace, env=env, extra_write_paths=extra_write_paths)
            worker = worker_factory(job, command, cwd=str(layout.workspace), env=env)
            record["pid"] = worker.pid
            record["assigned_before_execution"] = job.contains(worker._handle) and not worker.resumed
            if not record["assigned_before_execution"]:
                raise RuntimeError("Worker was not assigned to its owned Job before execution")
            worker.stdin.close()

            def drain():
                try:
                    remaining = 16 * 1024 ** 2
                    for line in worker.stdout:
                        encoded = line.encode("utf-8", errors="replace")
                        output.write(encoded[:remaining])
                        if len(encoded) > remaining:
                            record["log_truncated"] = True
                        remaining = max(0, remaining - len(encoded))
                    output.flush()
                except BaseException as exc:
                    record["log_error"] = str(exc)

            reader = threading.Thread(target=drain, daemon=True)
            reader.start()
            worker.resume()
            deadline = time.monotonic() + timeout
            while worker.poll() is None and time.monotonic() < deadline:
                time.sleep(.05)
            record["timed_out"] = worker.poll() is None
            if record["timed_out"]:
                job.terminate()
            record["exit_code"] = worker.wait(5)
        except BaseException as exc:
            record["error"] = str(exc)
        finally:
            if job is not None:
                try:
                    if worker is not None and worker.poll() is None:
                        job.terminate()
                        worker.wait(5)
                    job.drain(5)
                    record["active_at_release"] = job.active()
                except BaseException as exc:
                    record["cleanup_errors"].append(str(exc))
                if reader is not None:
                    reader.join(5)
                    if reader.is_alive():
                        record["cleanup_errors"].append("Owned stdout reader did not finish")
                try:
                    if worker is not None:
                        worker.close()
                except BaseException as exc:
                    record["cleanup_errors"].append(str(exc))
                finally:
                    try:
                        job.close()  # Maintained kill-on-close; never detach.
                    except BaseException as exc:
                        record["cleanup_errors"].append(str(exc))
            record["finished_epoch"] = time.time()
            receipt.seek(0)
            json.dump(record, receipt, indent=2)
            receipt.write("\n")
            receipt.truncate()
            receipt.flush()
    return record


def main(argv=None):
    tokens = list(sys.argv[1:] if argv is None else argv)
    split = tokens.index("--") if "--" in tokens else len(tokens)
    command = tokens[split + 1:] if split < len(tokens) else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("check", "prepare", "run"))
    parser.add_argument("--root", default=r"E:\CodexQA\BTH")
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--expected-write-gib", type=int, default=4)
    parser.add_argument("--reserve-gib", type=int, default=20)
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--cpu-rate", type=int, default=1200)
    parser.add_argument("--write-path", action="append", default=[])
    args = parser.parse_args(tokens[:split])
    try:
        if args.action != "run" and command:
            raise ValueError("check/prepare do not execute commands")
        if args.action == "run" and not command:
            raise ValueError("run requires an explicit worker after --")
        if args.action == "run" and (not 1 <= args.timeout <= 1200 or not 1 <= args.cpu_rate <= 1500):
            raise ValueError("Timeout1-1200 and CPU rate1-1500 required before preparation")
        layout = plan_layout(root=args.root, workspace=args.workspace, run_id=args.run_id,
                             expected_write_bytes=args.expected_write_gib * GIB,
                             reserve_bytes=args.reserve_gib * GIB)
        outputs = tuple(args.write_path) + (command_write_paths(layout, command) if command else ())
        capacity = validate_layout(layout, extra_write_paths=outputs)
        if args.action == "check":
            print(json.dumps({"status": "PREFLIGHT_PASS_NO_WRITES", "storage": layout.as_dict(),
                              "capacity_before_preparation": capacity}))
            return 0
        layout = prepare_layout(layout)
        if args.action == "prepare":
            print(json.dumps({"status": "PREPARED_NO_WORKER", "storage": layout.as_dict(),
                              "capacity_before_preparation": capacity}))
            return 0
        result = execute(layout, command, timeout=args.timeout, cpu_rate=args.cpu_rate,
                         extra_write_paths=outputs)
        print(json.dumps(result))
        return 0 if (result.get("exit_code") == 0 and result.get("active_at_release") == 0
                     and not result["error"] and not result["cleanup_errors"]
                     and not result.get("log_error") and not result.get("timed_out")) else 1
    except StorageGuardError as exc:
        print(json.dumps({"status": "STORAGE_OR_LAUNCH_REJECTED", **exc.as_dict()}), file=sys.stderr)
        return 2
    except (ValueError, OSError, RuntimeError) as exc:
        print(json.dumps({"status": "STORAGE_OR_LAUNCH_REJECTED", "error": str(exc)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
