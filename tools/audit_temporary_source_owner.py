"""Own an explicitly reviewed temporary-source diagnostic; never launch on import.

The caller supplies the SHA256 of the reviewed, unchanged run_stage006.py. Its
Job/worker construction order is part of that review. Execute it in a retained
namespace, so a failed receipt write cannot discard the actual owned Job or its
pre-close accounting. Disk job.json is deliberately not a closure authority.

Only the reviewed two/three manifest-listed receivers are writable. Originals and
all failed staging/journal artifacts are retained. Atomic replacement prevents
partial source writes; byte checks refuse observed concurrent writers. As with
the original diagnostic, the parent must reserve these sources against other
writers: stdlib rename is not a cross-process compare-and-swap operation.

BTH061-AUDIT-SOURCE-OWNER-012. No cleanup, process discovery, or broad stop.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import sys
import time
from typing import Any
import uuid


TASK_ID = "BTH061-AUDIT-SOURCE-OWNER-012"
SOURCE_PATHS = {"scripts/core/run_state.gd", "scripts/core/run_generator.gd"}
REVIEWED_SOURCE_SETS = (SOURCE_PATHS, SOURCE_PATHS | {"scripts/core/scenario_engine.gd"})
ANY_CONTENT = object()


class OwnerError(RuntimeError):
    pass


class OwnerReceipt(dict):
    """JSON-compatible result retaining exact handles on unresolved API paths."""

    retained_namespace: dict[str, Any] | None = None


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inside(path: Path, root: Path) -> Path:
    resolved = path.resolve()
    if not resolved.is_relative_to(root.resolve()) or resolved == root.resolve():
        raise OwnerError(f"Path escaped its owned root: {path}")
    return resolved


def describe(error: BaseException) -> str:
    return f"{type(error).__name__}: {error}"


class FileIO:
    """Small I/O boundary also used to inject failures in private-file tests."""

    def read(self, path: Path) -> bytes:
        return path.read_bytes()

    def write_new(self, path: Path, data: bytes) -> None:
        with path.open("xb") as stream:
            if stream.write(data) != len(data):
                raise OSError(f"Short write: {path}")
            stream.flush()
            os.fsync(stream.fileno())
        if self.read(path) != data:
            raise OwnerError(f"New artifact readback mismatch: {path}")

    def atomic_replace(self, path: Path, data: bytes, *, expected: Any = ANY_CONTENT,
                       mode: int | None = None) -> None:
        # Same parent means the replacement is on the same filesystem/volume.
        stage = path.with_name(f".{path.name}.audit-owner-{uuid.uuid4().hex}.tmp")
        self.write_new(stage, data)
        if mode is not None:
            stage.chmod(mode)
        if expected is not ANY_CONTENT and self.read(path) != expected:
            raise OwnerError(f"Concurrent source bytes; refused replacement: {path}")
        os.replace(stage, path)
        if self.read(path) != data:
            raise OwnerError(f"Replacement readback mismatch: {path}")

    def journal(self, path: Path, event: dict[str, Any]) -> None:
        data = (json.dumps(event, sort_keys=True) + "\n").encode("utf-8")
        with path.open("ab") as stream:
            if stream.write(data) != len(data):
                raise OSError("Short journal append")
            stream.flush()
            os.fsync(stream.fileno())

    def write_receipt(self, path: Path, receipt: dict[str, Any]) -> None:
        self.atomic_replace(path, (json.dumps(receipt, indent=2) + "\n").encode())


def guards_match(limits: Any) -> bool:
    return isinstance(limits, dict) and all((
        limits.get("control_flags") == 5,
        limits.get("cpu_rate") == 1200,
        limits.get("aggregate_job_cpu_percent") == 12,
        limits.get("job_memory_limit_bytes") == 2147483648,
        limits.get("kill_on_close") is True,
        limits.get("breakaway_allowed") is False,
    ))


def close_owned_scope(namespace: dict[str, Any], started: bool) -> dict[str, Any]:
    """Prove process absence before restoring; keep qualification errors separate.

    An unbound worker after a constructor failure may hide an unassigned creation
    handle. Job accounting alone cannot qualify that path. Never reopen by PID.
    """
    result: dict[str, Any] = {"verified": False, "guards_qualified": False, "errors": []}
    if not started or "job" not in namespace:
        # In the hash-pinned reviewed runner, Job assignment precedes every
        # SuspendedWorker construction. No Job binding means no child launch.
        result.update(verified=True, guards_qualified=True, evidence="before_job_creation")
        return result
    job = namespace["job"]
    worker = namespace.get("worker")
    record = namespace.get("record", {})
    if not isinstance(record, dict):
        record = {}
    assigned = record.get("assigned_before_execution") is True
    constructor_unresolved = "worker" in namespace and worker is None
    if not getattr(job, "handle", None):
        finished = record.get("finished_utc")
        valid_finish = (type(finished) in (int, float) and math.isfinite(finished)
                        and finished > 0)
        worker_closed = (worker is not None and getattr(worker, "_handle", None) is None
                         and getattr(worker, "_thread", None) is None)
        # The pinned runner updates this record AFTER drain/wait/worker.close,
        # while the exact Job handle is still queryable, then calls job.close.
        result.update(
            verified=(type(record.get("active_at_release")) is int
                      and record["active_at_release"] == 0 and valid_finish
                      and assigned and worker_closed),
            guards_qualified=guards_match(record.get("limits")),
            evidence="pinned_runner_preclose_accounting",
            active_at_release=record.get("active_at_release"), finished_utc=finished,
            limits=record.get("limits"),
            handle_close="runner_attempted; existing close does not check Win32 BOOL",
        )
    else:
        result["evidence"] = "live_owned_job_readback"
        if worker is not None and not assigned:
            try:
                # A receipt can fail between construction and record.update.
                # Recover only the exact still-suspended creation handle.
                assigned = (getattr(worker, "resumed", True) is False
                            and job.contains(worker._handle))
            except BaseException as error:
                result["errors"].append("assignment readback: " + describe(error))
        try:
            result["limits"] = job.verify()
            result["guards_qualified"] = guards_match(result["limits"])
        except BaseException as error:
            result["errors"].append("guard readback: " + describe(error))
        # A guard qualification failure must not skip cleanup of this exact Job.
        try:
            job.drain(5)
        except BaseException as error:
            result["errors"].append("owned drain: " + describe(error))
        if worker is not None:
            try:
                worker.wait(5)
            except BaseException as error:
                result["errors"].append("worker wait: " + describe(error))
            try:
                worker.close()
            except BaseException as error:
                result["errors"].append("worker cleanup: " + describe(error))
        reader = namespace.get("reader")
        if reader is not None:
            try:
                reader.join(5)
            except BaseException as error:
                result["errors"].append("reader cleanup: " + describe(error))
        try:
            active = job.active()  # read on the still-live exact owned handle
            result.update(active_at_release=active, finished_utc=time.time())
            result["verified"] = (type(active) is int and active == 0
                                  and not constructor_unresolved
                                  and (assigned or "worker" not in namespace))
        except BaseException as error:
            result["errors"].append("owned closure readback: " + describe(error))
        # Always attempt kill-on-close on this exact retained Job, including a
        # failed drain/readback. A close attempt is NOT an active-zero proof.
        try:
            if job.api.CloseHandle(job.handle):
                job.handle = None
                result["handle_close"] = "checked_success"
            else:
                result["errors"].append("Owned Job CloseHandle returned false")
        except BaseException as error:
            result["errors"].append("owned handle release: " + describe(error))
        if worker is not None and getattr(worker, "_handle", None) is not None:
            # Kill-on-close may now have finished the exact retained worker.
            # Retry only its handles; never discover/reopen another process.
            for action in (lambda: worker.wait(5), worker.close):
                try:
                    action()
                except BaseException as error:
                    result["errors"].append("post-close worker cleanup: " + describe(error))
        if worker is not None and not assigned:
            result["guards_qualified"] = False
            result["errors"].append("No assignment-before-execution proof")
    if constructor_unresolved:
        result["errors"].append("Unresolved worker construction/assignment; no creation handle")
    if not result["verified"]:
        result["errors"].append("No verified native closure; temporary sources retained")
    if not result["guards_qualified"]:
        result["errors"].append("Guard qualification does not match 12%/2GiB/kill/no-breakaway")
    return result


def run_owner(*, task_root: Path, manifest_path: Path, spec_path: Path,
              owner_name: str, runner_sha256: str, io: FileIO | None = None) -> dict[str, Any]:
    """Run only the caller's hash-pinned reviewed runner. Return in-memory receipt.

    I/O failures remain failures even when restoration succeeds. Source restore
    never relies on a receipt/journal read. Nothing is removed on any path.
    """
    io = io or FileIO()
    root = task_root.resolve()
    repo = inside(root / "audit-independent", root)
    proposal = inside(manifest_path, root)
    spec_path = inside(spec_path, root)
    runner = inside(root / "run_stage006.py", root)
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", owner_name):
        raise OwnerError("Invalid fresh owner name")
    if not re.fullmatch(r"[a-fA-F0-9]{64}", runner_sha256):
        raise OwnerError("A reviewed runner SHA256 is required")
    runner_bytes = io.read(runner)
    if sha256(runner_bytes) != runner_sha256.lower():
        raise OwnerError("Reviewed runner hash mismatch; no sources changed")
    runner_code = compile(runner_bytes, str(runner), "exec")
    manifest_bytes, spec_bytes = io.read(proposal), io.read(spec_path)
    manifest, spec = json.loads(manifest_bytes), json.loads(spec_bytes)
    if set(manifest["files"]) not in REVIEWED_SOURCE_SETS:
        raise OwnerError("Manifest must name an exact reviewed two/three receiver set")
    if (not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", spec["name"])
            or spec.get("family") != "guards"
            or type(spec.get("limit")) is not int
            or spec["limit"] not in (180, 330)):
        raise OwnerError("Expected a guards-family owned recipe with exact integer 180 or 330 seconds")
    evidence = inside(root / "evidence", root)
    owner = inside(evidence / owner_name, evidence)
    if owner_name == spec["name"]:
        raise OwnerError("Owner and native output must have different fresh names")
    if owner.exists() or inside(evidence / spec["name"], evidence).exists():
        raise OwnerError("Preserve all previous owner/job artifacts; choose fresh names")
    targets = [inside(repo / relative, repo) for relative in manifest["files"]]
    prepared = []
    for relative, item in manifest["files"].items():
        target = inside(repo / relative, repo)
        original = inside(proposal.parent / item["original_artifact"], proposal.parent)
        candidate = inside(proposal.parent / item["candidate_artifact"], proposal.parent)
        # Artifacts must never alias writable live sources (including hardlinks).
        if any(path.samefile(live) for path in (original, candidate) for live in targets):
            raise OwnerError("Frozen artifact aliases a live target")
        before, after = io.read(original), io.read(candidate)
        if (io.read(target) != before or sha256(before) != item["original_sha256"]
                or sha256(after) != item["candidate_sha256"]):
            raise OwnerError("Original/candidate identity mismatch: " + relative)
        prepared.append((relative, target, before, after, stat.S_IMODE(target.stat().st_mode)))
    owner.mkdir(parents=True, exist_ok=False)
    receipt: OwnerReceipt = OwnerReceipt({
        "schema": "bth.temporary_source_owner/v1", "task": TASK_ID,
        "started_utc": time.time(), "runner_sha256": sha256(runner_bytes),
        "manifest_sha256": sha256(manifest_bytes), "spec_sha256": sha256(spec_bytes),
        "job_name": spec["name"], "sources": {}, "errors": [], "run_started": False,
        "restoration_complete": False,
    })
    owned_spec = owner / "executed-spec.json"
    io.write_new(owned_spec, spec_bytes)
    receipt["executed_spec"] = str(owned_spec)
    for index, (relative, _, before, after, _) in enumerate(prepared):
        backup = owner / f"original-{index}.gd.txt"
        io.write_new(backup, before)  # all verified raw originals precede mutation
        receipt["sources"][relative] = {
            "original_sha256": sha256(before), "candidate_sha256": sha256(after),
            "retained_original": str(backup), "mutation_intended": False,
            "applied": False, "restored": False,
        }
    journal = owner / "events.jsonl"
    io.write_new(journal, b"")

    def persist(phase: str) -> bool:
        receipt["phase"] = phase
        try:
            io.write_receipt(owner / "owner.json", receipt)
            return True
        except BaseException as error:
            receipt["errors"].append(f"receipt {phase}: " + describe(error))
            return False

    def event(kind: str, relative: str, *, required: bool = False) -> None:
        try:
            io.journal(journal, {"kind": kind, "source": relative, "utc": time.time()})
        except BaseException as error:
            receipt["errors"].append(f"journal {kind}: " + describe(error))
            if required:
                raise OwnerError("Required intent/apply journal failed") from error

    namespace: dict[str, Any] = {"__name__": "__main__", "__file__": str(runner)}
    old_argv, old_path, old_bytecode = list(sys.argv), list(sys.path), sys.dont_write_bytecode
    runner_exit = 1
    try:
        if not persist("prepared"):
            raise OwnerError("Initial owner receipt failed; no mutation authorized")
        for relative, target, before, after, mode in prepared:
            state = receipt["sources"][relative]
            # Intent is in memory BEFORE journaling, durably journaled BEFORE
            # atomic replacement, so even a post-replace exception is covered.
            state["mutation_intended"] = True
            event("apply_intent", relative, required=True)
            if not persist("apply_intent"):
                raise OwnerError("Intent receipt failed")
            io.atomic_replace(target, after, expected=before, mode=mode)
            state["applied"] = True
            event("applied", relative, required=True)
            if not persist("applied"):
                raise OwnerError("Post-apply receipt failed")
        # Recheck exact runner bytes immediately before execution. Compile only
        # the already pinned bytes; never reread/execute mutable runner text.
        if io.read(runner) != runner_bytes or io.read(owned_spec) != spec_bytes:
            raise OwnerError("Runner or retained spec changed after preparation")
        receipt["run_started"] = True
        if not persist("run_started"):
            receipt["run_started"] = False
            raise OwnerError("Run-start receipt failed; runner was not invoked")
        # The unchanged runner reopens its config. Give it the retained exact
        # bytes, so a concurrent edit to the caller's spec cannot change guards.
        sys.argv = [str(runner), str(owned_spec)]
        try:
            exec(runner_code, namespace)
            runner_exit = 0
        except SystemExit as error:
            runner_exit = error.code if type(error.code) is int else (0 if error.code is None else 1)
        except BaseException as error:
            receipt["errors"].append("runner: " + describe(error))
    except BaseException as error:
        receipt["errors"].append("owner apply/run: " + describe(error))
    finally:
        sys.argv, sys.path[:], sys.dont_write_bytecode = old_argv, old_path, old_bytecode
        try:
            closure = close_owned_scope(namespace, receipt["run_started"])
        except BaseException as error:
            closure = {"verified": False, "guards_qualified": False,
                       "errors": ["closure inspection: " + describe(error)]}
        receipt["closure"] = closure
        receipt["errors"].extend(closure["errors"])
        record = namespace.get("record")
        if isinstance(record, dict):
            # Only stable JSON scalars are copied; a malformed record must not
            # make the restoration loop depend on successful serialization.
            native_exit = record.get("exit")
            receipt["native_exit"] = native_exit if type(native_exit) is int else None
        persist("closure")
        for index, (relative, target, before, after, mode) in enumerate(prepared):
            state = receipt["sources"][relative]
            try:
                current = io.read(target)
                if current == before:
                    state["restored"] = True
                elif not state["mutation_intended"] or current != after:
                    preserved = owner / f"unexpected-{index}-{uuid.uuid4().hex}.gd.txt"
                    io.write_new(preserved, current)
                    state["unexpected_artifact"] = str(preserved)
                    raise OwnerError("Unknown concurrent source bytes; refused overwrite")
                elif not closure["verified"]:
                    state["restore_blocked"] = "No verified native closure"
                else:
                    # Logging is best effort here: failure cannot prevent an
                    # otherwise safe restore or skip the next independent one.
                    event("restore_intent", relative)
                    io.atomic_replace(target, before, expected=after, mode=mode)
                    state["restored"] = io.read(target) == before
                    if not state["restored"]:
                        raise OwnerError("Original readback mismatch after restore")
                    event("restored", relative)
            except BaseException as error:
                receipt["errors"].append("restore " + relative + ": " + describe(error))
            finally:
                persist("restore")
        receipt["restoration_complete"] = all(s["restored"] for s in receipt["sources"].values())
        receipt.update(finished_utc=time.time(), runner_exit=runner_exit)
        receipt["owner_exit"] = (0 if runner_exit == 0 and receipt["restoration_complete"]
                                 and not receipt["errors"] else 1)
        persist("finished")
    receipt["owner_exit"] = (0 if runner_exit == 0 and receipt["restoration_complete"]
                             and not receipt["errors"] else 1)
    if (not receipt["closure"]["verified"] or getattr(namespace.get("job"), "handle", None)
            or getattr(namespace.get("worker"), "_handle", None)
            or getattr(namespace.get("worker"), "_thread", None)):
        receipt.retained_namespace = namespace
    return receipt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--owner-name", required=True)
    parser.add_argument("--runner-sha256", required=True)
    args = parser.parse_args(argv)
    try:
        result = run_owner(task_root=args.task_root, manifest_path=args.manifest,
                           spec_path=args.spec, owner_name=args.owner_name,
                           runner_sha256=args.runner_sha256)
    except BaseException as error:
        print(json.dumps({"task": TASK_ID, "preflight_error": describe(error)}), file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return result["owner_exit"]


if __name__ == "__main__":
    raise SystemExit(main())
