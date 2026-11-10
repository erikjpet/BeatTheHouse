"""Verify launch admission happens before any owned child is created."""
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bth_qa_guarded_run as runner
from bth_qa_storage import StorageGuardError


class Job:
    def __init__(self): self.closed = False
    def verify(self, *args): return {"kill_on_close": True, "cpu_rate": args[0]}
    def contains(self, handle): return True
    def active(self): return 0
    def drain(self, *args): pass
    def terminate(self): pass
    def close(self): self.closed = True


class Worker:
    def __init__(self, job, args, **kwargs):
        self.pid, self._handle, self.resumed = 123, object(), False
        self.stdin, self.stdout = io.StringIO(), io.StringIO("worker completed\n")
        self.closed = False
    def resume(self): self.resumed = True
    def poll(self): return 0 if self.resumed else None
    def wait(self, *args): return 0
    def close(self): self.closed = True


class GuardedRunTests(unittest.TestCase):
    def layout(self, directory):
        # These are test-owned temporary files; the storage policy is separately
        # exercised by the core tests. No real worker or E directory is created.
        root = Path(directory)
        manifest = root / "storage-manifest.json"
        manifest.write_text('{"test":true}', encoding="utf-8")
        return SimpleNamespace(workspace=root, evidence=root, manifest_path=manifest,
                               as_dict=lambda: {"test_owned_layout": True})

    def test_rejection_prevents_job_and_worker_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            layout, job_factory, worker_factory = self.layout(directory), Mock(), Mock()
            with patch.object(runner, "command_write_paths", return_value=()), patch.object(runner, "child_environment", return_value={}), patch.object(
                runner, "check_launch", side_effect=StorageGuardError("system_volume", "C:\\bad", "rejected")
            ):
                with self.assertRaises(StorageGuardError):
                    runner.execute(layout, ["worker"], job_factory=job_factory, worker_factory=worker_factory)
            job_factory.assert_not_called()
            worker_factory.assert_not_called()
            self.assertFalse((Path(directory) / "job.json").exists())

    def test_capacity_drop_at_final_gate_closes_job_without_child(self):
        with tempfile.TemporaryDirectory() as directory:
            layout, job, worker_factory = self.layout(directory), Job(), Mock()
            with patch.object(runner, "command_write_paths", return_value=()), patch.object(runner, "child_environment", return_value={}), patch.object(
                runner, "check_launch", side_effect=[None, StorageGuardError("insufficient_space", "E:\\QA", "full", 24, 2)]
            ):
                result = runner.execute(layout, ["worker"], job_factory=lambda: job, worker_factory=worker_factory)
            worker_factory.assert_not_called()
            self.assertTrue(job.closed)
            self.assertIn("insufficient_space", result["error"])
            self.assertEqual(result["active_at_release"], 0)

    def test_success_retains_owned_job_membership_and_zero_release(self):
        with tempfile.TemporaryDirectory() as directory:
            layout, job = self.layout(directory), Job()
            worker = Worker(job, [])
            gates = []
            def construct(*args, **kwargs):
                self.assertEqual(gates, ["checked", "checked"])
                self.assertEqual(kwargs["cwd"], str(layout.workspace))
                return worker
            with patch.object(runner, "command_write_paths", return_value=()), patch.object(runner, "child_environment", return_value={"TEMP": "guarded"}), patch.object(
                runner, "check_launch", side_effect=lambda *a, **kw: gates.append("checked")
            ):
                result = runner.execute(layout, ["worker"], job_factory=lambda: job, worker_factory=construct)
            self.assertEqual(result["exit_code"], 0)
            self.assertTrue(result["assigned_before_execution"])
            self.assertEqual(result["active_at_release"], 0)
            self.assertTrue(job.closed and worker.closed)
            self.assertEqual(json.loads((layout.evidence / "job.json").read_text())["exit_code"], 0)

    def test_occupied_evidence_blocks_worker_before_job_creation(self):
        for name in ("launch-claim.json", "worker.log", "job.json"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                layout, job_factory, worker_factory = self.layout(directory), Mock(), Mock()
                target = layout.evidence / name
                target.write_bytes(b"prior owned evidence")
                with patch.object(runner, "command_write_paths", return_value=()), patch.object(runner, "child_environment", return_value={}), patch.object(runner, "check_launch", return_value={}):
                    with self.assertRaises(StorageGuardError):
                        runner.execute(layout, ["worker"], job_factory=job_factory, worker_factory=worker_factory)
                job_factory.assert_not_called()
                worker_factory.assert_not_called()
                self.assertEqual(target.read_bytes(), b"prior owned evidence")

    def test_exclusive_claim_blocks_competing_launch_after_existence_check(self):
        with tempfile.TemporaryDirectory() as directory:
            layout, job_factory, worker_factory = self.layout(directory), Mock(return_value=Job()), Mock(side_effect=Worker)
            with patch.object(runner, "command_write_paths", return_value=()), patch.object(runner, "child_environment", return_value={}), patch.object(runner, "check_launch", return_value={}):
                runner.execute(layout, ["worker"], job_factory=job_factory, worker_factory=worker_factory)
                original = (layout.evidence / "job.json").read_bytes()
                # A stale/competing existence observation cannot bypass open(x).
                with patch.object(Path, "exists", return_value=False), self.assertRaises(FileExistsError):
                    runner.execute(layout, ["worker"], job_factory=job_factory, worker_factory=worker_factory)
            self.assertEqual(job_factory.call_count, 1)
            self.assertEqual(worker_factory.call_count, 1)
            self.assertEqual((layout.evidence / "job.json").read_bytes(), original)

    def test_cli_parses_options_before_explicit_worker_separator(self):
        layout = SimpleNamespace(as_dict=lambda: {"planned": True})
        with patch.object(runner, "plan_layout", return_value=layout) as plan, patch.object(
            runner, "validate_layout", return_value={}
        ), patch.object(runner, "prepare_layout") as prepare, contextlib.redirect_stdout(io.StringIO()):
            result = runner.main(["check", "--workspace", "E:\\QA\\workspace", "--run-id", "future-001"])
        self.assertEqual(result, 0)
        self.assertEqual(plan.call_args.kwargs["workspace"], "E:\\QA\\workspace")
        prepare.assert_not_called()

    def test_cli_rejects_extra_C_output_before_preparing(self):
        layout = SimpleNamespace(as_dict=lambda: {})
        with patch.object(runner, "plan_layout", return_value=layout), patch.object(
            runner, "validate_layout", side_effect=StorageGuardError("system_volume", "C:\\out", "rejected", 24, 1)
        ), patch.object(runner, "prepare_layout") as prepare, contextlib.redirect_stderr(io.StringIO()) as error:
            result = runner.main(["prepare", "--workspace", "E:\\QA\\workspace", "--run-id", "future-001", "--write-path", "C:\\out"])
        self.assertEqual(result, 2)
        prepare.assert_not_called()
        payload = json.loads(error.getvalue())
        self.assertEqual(payload["error"], "system_volume")
        self.assertEqual(payload["required_bytes"], 24)
        self.assertEqual(payload["available_bytes"], 1)

    def test_cli_command_output_rejection_prevents_preparation(self):
        layout = SimpleNamespace(as_dict=lambda: {})
        with patch.object(runner, "plan_layout", return_value=layout), patch.object(
            runner, "command_write_paths", side_effect=StorageGuardError("system_volume", "C:\\profile", "rejected")
        ), patch.object(runner, "prepare_layout") as prepare, contextlib.redirect_stderr(io.StringIO()):
            result = runner.main(["run", "--workspace", "E:\\QA\\workspace", "--run-id", "future-001",
                                  "--", "browser", "--user-data-dir=C:\\profile"])
        self.assertEqual(result, 2)
        prepare.assert_not_called()


if __name__ == "__main__": unittest.main()
