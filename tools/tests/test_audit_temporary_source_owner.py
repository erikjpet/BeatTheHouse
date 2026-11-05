"""Fault tests use retained fresh dummy roots; no native process is created.

Artifacts are deliberately not removed. Set BTH_AUDIT_OWNER_TEST_ROOT to retain
them in an explicit evidence directory; otherwise use a named TEMP parent.
"""

import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import audit_temporary_source_owner as owner


LIMITS = {"control_flags": 5, "cpu_rate": 1200,
          "aggregate_job_cpu_percent": 12, "job_memory_limit_bytes": 2147483648,
          "kill_on_close": True, "breakaway_allowed": False, "active_processes": 0}

# These are ordinary Python fakes, not altered/imported Windows Job classes.
# Every execution uses a fresh pinned fake run_stage006.py in a private root.
FAKE_SCOPE = '''
import time
class FakeApi:
    def CloseHandle(self, handle): return True
class FakeJob:
    def __init__(self):
        self.handle = object()
        self.api = FakeApi()
        self.count = 1
    def verify(self): return LIMITS.copy()
    def drain(self, timeout): self.count = 0
    def contains(self, handle): return True
    def active(self):
        if self.handle is None: raise RuntimeError('closed handle queried')
        return self.count
class FakeWorker:
    def __init__(self):
        self._handle = object()
        self._thread = None
        self.resumed = False
    def wait(self, timeout): return 0
    def close(self): self._handle = None
job = FakeJob()
worker = FakeWorker()
record = {'limits': LIMITS.copy(), 'assigned_before_execution': True, 'exit': 0}
reader = None
'''
NORMAL_FINISH = '''
job.drain(5)
worker.wait(5)
worker.close()
record.update(active_at_release=job.active(), finished_utc=time.time())
job.handle = None
'''


class TrackingIO(owner.FileIO):
    def __init__(self):
        self.phase = "preflight"
        self.events = []

    def write_receipt(self, path, receipt):
        self.phase = receipt["phase"]
        super().write_receipt(path, receipt)

    def journal(self, path, event):
        self.events.append(event.copy())
        super().journal(path, event)


class SourceOwnerTests(unittest.TestCase):
    def setUp(self):
        parent = Path(os.environ.get("BTH_AUDIT_OWNER_TEST_ROOT",
                                     str(Path(tempfile.gettempdir()) / "bth-source-owner-012-tests")))
        parent.mkdir(parents=True, exist_ok=True)
        # Keep Windows source-stage paths below legacy MAX_PATH. Retain the full
        # test identity as evidence instead of embedding it in every path.
        prefix = "t-" + owner.sha256(self._testMethodName.encode())[:8] + "-"
        self.root = Path(tempfile.mkdtemp(prefix=prefix, dir=parent))
        (self.root / "case.txt").write_text(self._testMethodName, encoding="utf-8")
        self.repo = self.root / "audit-independent"
        self.proposal = self.root / "proposal"
        self.proposal.mkdir()
        (self.root / "evidence").mkdir()
        self.originals, self.candidates, self.targets = {}, {}, {}
        files = {}
        for index, relative in enumerate(sorted(owner.SOURCE_PATHS)):
            target = self.repo / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            original = f"original-{index}\r\n".encode()
            candidate = f"candidate-{index}\r\n".encode()
            target.write_bytes(original)
            (self.proposal / f"original-{index}.txt").write_bytes(original)
            (self.proposal / f"candidate-{index}.txt").write_bytes(candidate)
            self.originals[relative], self.candidates[relative] = original, candidate
            self.targets[relative] = target
            files[relative] = {"original_artifact": f"original-{index}.txt",
                               "candidate_artifact": f"candidate-{index}.txt",
                               "original_sha256": owner.sha256(original),
                               "candidate_sha256": owner.sha256(candidate)}
        self.first, self.second = sorted(owner.SOURCE_PATHS)
        self.manifest = self.proposal / "manifest.json"
        self.manifest.write_text(json.dumps({"files": files}), encoding="utf-8")
        self.spec = self.proposal / "spec.json"
        self.spec.write_text(json.dumps({"name": "dummy-stage", "family": "guards",
                                        "limit": 330, "task": owner.TASK_ID}), encoding="utf-8")
        self.runner = self.root / "run_stage006.py"
        self.set_runner()

    def set_runner(self, *, before_finish="", finish=NORMAL_FINISH, suffix=""):
        source = "LIMITS = " + repr(LIMITS) + "\n" + FAKE_SCOPE + before_finish + finish + suffix
        self.runner.write_text(source, encoding="utf-8")
        self.pin = owner.sha256(self.runner.read_bytes())

    def run_owner(self, io=None, *, expect_run=False):
        result = owner.run_owner(task_root=self.root, manifest_path=self.manifest,
                                 spec_path=self.spec, owner_name="dummy-owner",
                                 runner_sha256=self.pin, io=io)
        if expect_run:
            self.assertTrue(result["run_started"], result["errors"])
            self.assertTrue(all(s["applied"] for s in result["sources"].values()))
        return result

    def assert_originals(self):
        for relative, target in self.targets.items():
            self.assertEqual(target.read_bytes(), self.originals[relative])

    def assert_backups(self):
        for index, relative in enumerate(sorted(owner.SOURCE_PATHS)):
            self.assertEqual((self.root / "evidence/dummy-owner" / f"original-{index}.gd.txt").read_bytes(),
                             self.originals[relative])

    def test_success_journals_intent_before_replace_and_restores_exact_bytes(self):
        test = self

        class IntentIO(TrackingIO):
            def atomic_replace(self, path, data, **kwargs):
                if path in test.targets.values() and data in test.candidates.values():
                    events = (test.root / "evidence/dummy-owner/events.jsonl").read_text()
                    self_case = str(path.relative_to(test.repo)).replace("\\", "/")
                    test.assertTrue(any(e["kind"] == "apply_intent" and e["source"] == self_case
                                        for e in map(json.loads, events.splitlines())))
                    test.assert_backups()
                super().atomic_replace(path, data, **kwargs)

        result = self.run_owner(IntentIO(), expect_run=True)
        self.assertEqual(result["owner_exit"], 0)
        self.assertTrue(result["restoration_complete"])
        self.assertEqual(result["closure"]["evidence"], "pinned_runner_preclose_accounting")
        self.assert_originals()
        self.assert_backups()

    def test_partial_staging_write_never_changes_source_and_artifact_is_retained(self):
        test = self

        class PartialIO(TrackingIO):
            failed = False

            def write_new(self, path, data):
                if path.parent == test.targets[test.first].parent and not self.failed:
                    self.failed = True
                    with path.open("xb") as stream:
                        stream.write(data[:3])
                    raise OSError("injected partial staging write")
                super().write_new(path, data)

        result = self.run_owner(PartialIO())
        self.assertFalse(result["run_started"])
        self.assertEqual(result["owner_exit"], 1)
        self.assertTrue(result["restoration_complete"])
        self.assert_originals()
        self.assertTrue(list(self.targets[self.first].parent.glob("*.audit-owner-*.tmp")))

    def test_failure_after_atomic_apply_still_restores_using_intent(self):
        test = self

        class AfterReplaceIO(TrackingIO):
            def atomic_replace(self, path, data, **kwargs):
                super().atomic_replace(path, data, **kwargs)
                if path == test.targets[test.first] and data == test.candidates[test.first]:
                    raise OSError("after rename, before applied flag")

        result = self.run_owner(AfterReplaceIO())
        self.assertFalse(result["sources"][self.first]["applied"])
        self.assertTrue(result["sources"][self.first]["mutation_intended"])
        self.assertTrue(result["restoration_complete"])
        self.assert_originals()

    def test_post_apply_journal_failure_cannot_escape_restoration(self):
        class JournalIO(TrackingIO):
            def journal(self, path, event):
                if event["kind"] == "applied":
                    raise OSError("post-apply journal unavailable")
                super().journal(path, event)

        result = self.run_owner(JournalIO())
        self.assertFalse(result["run_started"])
        self.assertTrue(result["restoration_complete"])
        self.assertTrue(any("post-apply journal unavailable" in s for s in result["errors"]))
        self.assert_originals()

    def test_mutation_is_not_attempted_if_intent_journal_fails(self):
        class JournalIO(TrackingIO):
            def journal(self, path, event):
                raise OSError("intent unavailable")

        result = self.run_owner(JournalIO())
        self.assertFalse(any(s["applied"] for s in result["sources"].values()))
        self.assertFalse(result["run_started"])
        self.assert_originals()

    def test_malformed_job_json_cannot_discard_in_memory_closure(self):
        self.set_runner(before_finish="from pathlib import Path\np = Path(__file__).parent / 'evidence/dummy-stage/job.json'\np.parent.mkdir()\np.write_text('{bad json')\n")
        result = self.run_owner(expect_run=True)
        self.assertEqual(result["owner_exit"], 0)
        self.assertEqual((self.root / "evidence/dummy-stage/job.json").read_text(), "{bad json")
        self.assert_originals()

    def test_unreadable_job_json_path_is_not_a_restore_dependency(self):
        self.set_runner(before_finish="from pathlib import Path\n(Path(__file__).parent / 'evidence/dummy-stage/job.json').mkdir(parents=True)\n")
        result = self.run_owner(expect_run=True)
        self.assertEqual(result["owner_exit"], 0)
        self.assertTrue((self.root / "evidence/dummy-stage/job.json").is_dir())
        self.assert_originals()

    def test_first_target_restore_read_failure_still_restores_second(self):
        test = self

        class ReadFailureIO(TrackingIO):
            def read(self, path):
                if self.phase in ("closure", "restore") and path == test.targets[test.first]:
                    raise PermissionError("first source unavailable")
                return super().read(path)

        result = self.run_owner(ReadFailureIO(), expect_run=True)
        self.assertFalse(result["sources"][self.first]["restored"])
        self.assertTrue(result["sources"][self.second]["restored"])
        self.assertEqual(self.targets[self.first].read_bytes(), self.candidates[self.first])
        self.assertEqual(self.targets[self.second].read_bytes(), self.originals[self.second])

    def test_first_target_atomic_restore_failure_still_restores_second(self):
        test = self

        class RestoreFailureIO(TrackingIO):
            def atomic_replace(self, path, data, **kwargs):
                if path == test.targets[test.first] and data == test.originals[test.first]:
                    raise PermissionError("first restore rename denied")
                super().atomic_replace(path, data, **kwargs)

        result = self.run_owner(RestoreFailureIO(), expect_run=True)
        self.assertFalse(result["sources"][self.first]["restored"])
        self.assertTrue(result["sources"][self.second]["restored"])
        self.assertEqual(self.targets[self.second].read_bytes(), self.originals[self.second])

    def test_receipt_failures_do_not_skip_either_restore(self):
        class ReceiptFailureIO(TrackingIO):
            def write_receipt(self, path, receipt):
                if receipt["phase"] in ("closure", "restore", "finished"):
                    raise OSError("receipt disk failure")
                super().write_receipt(path, receipt)

        result = self.run_owner(ReceiptFailureIO(), expect_run=True)
        self.assertEqual(result["owner_exit"], 1)
        self.assertTrue(result["restoration_complete"])
        self.assert_originals()

    def test_unknown_concurrent_writer_is_preserved_while_second_restores(self):
        self.set_runner(before_finish=f"from pathlib import Path\nPath({str(self.targets[self.first])!r}).write_bytes(b'unknown writer')\n")
        result = self.run_owner(expect_run=True)
        state = result["sources"][self.first]
        self.assertFalse(state["restored"])
        self.assertEqual(self.targets[self.first].read_bytes(), b"unknown writer")
        self.assertEqual(Path(state["unexpected_artifact"]).read_bytes(), b"unknown writer")
        self.assertTrue(result["sources"][self.second]["restored"])

    def test_writer_during_restore_staging_is_refused_before_rename(self):
        test = self

        class WriterIO(TrackingIO):
            def write_new(self, path, data):
                super().write_new(path, data)
                if path.parent == test.targets[test.first].parent and data == test.originals[test.first]:
                    test.targets[test.first].write_bytes(b"writer during stage")

        result = self.run_owner(WriterIO(), expect_run=True)
        self.assertEqual(self.targets[self.first].read_bytes(), b"writer during stage")
        self.assertFalse(result["sources"][self.first]["restored"])
        self.assertTrue(result["sources"][self.second]["restored"])

    def test_live_owned_job_is_drained_and_queried_before_checked_close(self):
        self.set_runner(finish="raise RuntimeError('runner cleanup failed before accounting')\n")
        result = self.run_owner(expect_run=True)
        self.assertEqual(result["closure"]["evidence"], "live_owned_job_readback")
        self.assertEqual(result["closure"]["active_at_release"], 0)
        self.assertEqual(result["closure"]["handle_close"], "checked_success")
        self.assertTrue(result["restoration_complete"])
        self.assertEqual(result["owner_exit"], 1)
        self.assert_originals()

    def test_guard_readback_failure_still_drains_actual_scope_and_restores(self):
        self.set_runner(finish="job.verify = lambda: (_ for _ in ()).throw(OSError('guard query failed'))\nraise RuntimeError('failed runner')\n")
        result = self.run_owner(expect_run=True)
        self.assertTrue(result["closure"]["verified"])
        self.assertFalse(result["closure"]["guards_qualified"])
        self.assertEqual(result["owner_exit"], 1)
        self.assert_originals()

    def test_closure_failure_retains_candidates_and_never_claims_restore(self):
        self.set_runner(finish="job.drain = lambda timeout: (_ for _ in ()).throw(OSError('drain failed'))\nraise RuntimeError('failed runner')\n")
        result = self.run_owner(expect_run=True)
        self.assertFalse(result["closure"]["verified"])
        self.assertEqual(result["closure"]["handle_close"], "checked_success")
        self.assertIsNotNone(result.retained_namespace)
        self.assertFalse(result["restoration_complete"])
        for relative, target in self.targets.items():
            self.assertEqual(target.read_bytes(), self.candidates[relative])

    def test_closed_handle_without_preclose_readback_is_not_closure_proof(self):
        self.set_runner(finish="worker.close()\njob.handle = None\nraise RuntimeError('no accounting proof')\n")
        result = self.run_owner(expect_run=True)
        self.assertFalse(result["closure"]["verified"])
        self.assertFalse(result["restoration_complete"])

    def test_unbound_partial_constructor_is_not_proved_by_empty_job(self):
        self.set_runner(finish="worker = None\njob.count = 0\nraise RuntimeError('constructor cleanup uncertain')\n")
        result = self.run_owner(expect_run=True)
        self.assertFalse(result["closure"]["verified"])
        self.assertFalse(result["restoration_complete"])

    def test_runner_final_save_error_does_not_discard_preclose_accounting(self):
        self.set_runner(suffix="raise OSError('final job receipt failed')\n")
        result = self.run_owner(expect_run=True)
        self.assertTrue(result["closure"]["verified"])
        self.assertTrue(result["restoration_complete"])
        self.assertEqual(result["owner_exit"], 1)
        self.assert_originals()

    def test_runner_hash_mismatch_never_mutates_sources(self):
        self.runner.write_bytes(self.runner.read_bytes() + b"# changed after review\n")
        with self.assertRaisesRegex(owner.OwnerError, "hash mismatch"):
            self.run_owner()
        self.assert_originals()
        self.assertFalse((self.root / "evidence/dummy-owner").exists())

    def test_previous_owner_artifacts_are_never_overwritten(self):
        prior = self.root / "evidence/dummy-owner"
        prior.mkdir()
        sentinel = prior / "sentinel.txt"
        sentinel.write_bytes(b"historical")
        with self.assertRaisesRegex(owner.OwnerError, "Preserve all previous"):
            self.run_owner()
        self.assertEqual(sentinel.read_bytes(), b"historical")
        self.assert_originals()

    def test_exact_reviewed_triple_works_through_cli_with_fake_scope(self):
        relative = "scripts/core/scenario_engine.gd"
        target = self.repo / relative
        before, after = b"engine original\r\n", b"engine instrumented\r\n"
        target.write_bytes(before)
        (self.proposal / "engine-original.txt").write_bytes(before)
        (self.proposal / "engine-candidate.txt").write_bytes(after)
        manifest = json.loads(self.manifest.read_text())
        manifest["files"][relative] = {
            "original_artifact": "engine-original.txt", "candidate_artifact": "engine-candidate.txt",
            "original_sha256": owner.sha256(before), "candidate_sha256": owner.sha256(after)}
        self.manifest.write_text(json.dumps(manifest))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = owner.main(["--task-root", str(self.root), "--manifest", str(self.manifest),
                               "--spec", str(self.spec), "--owner-name", "dummy-owner",
                               "--runner-sha256", self.pin])
        result = json.loads(output.getvalue())
        self.assertEqual(code, 0)
        self.assertEqual(set(result["sources"]), owner.REVIEWED_SOURCE_SETS[1])
        self.assertTrue(all(s["applied"] and s["restored"] for s in result["sources"].values()))
        self.assertEqual(target.read_bytes(), before)
        self.assert_originals()

    def test_source_set_cannot_expand_beyond_explicit_reviewed_sets(self):
        manifest = json.loads(self.manifest.read_text())
        manifest["files"]["scripts/core/unreviewed.gd"] = {}
        self.manifest.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(owner.OwnerError, "reviewed two/three"):
            self.run_owner()
        self.assert_originals()

    def test_frozen_hardlink_to_any_live_target_is_rejected(self):
        alias = self.proposal / "live-alias.txt"
        os.link(self.targets[self.second], alias)
        manifest = json.loads(self.manifest.read_text())
        manifest["files"][self.first]["original_artifact"] = alias.name
        self.manifest.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(owner.OwnerError, "aliases a live target"):
            self.run_owner()
        self.assert_originals()

    def test_atomic_rename_failure_preserves_source_and_staged_artifact(self):
        actual_replace = owner.os.replace

        def fail_source_replace(source, destination):
            if Path(destination) == self.targets[self.first]:
                raise PermissionError("atomic rename denied")
            actual_replace(source, destination)

        with mock.patch.object(owner.os, "replace", side_effect=fail_source_replace):
            result = self.run_owner()
        self.assertFalse(result["run_started"])
        self.assertTrue(result["restoration_complete"])
        self.assertTrue(list(self.targets[self.first].parent.glob("*.audit-owner-*.tmp")))
        self.assert_originals()

    def test_restore_journal_failure_cannot_skip_physical_restoration(self):
        class RestoreJournalIO(TrackingIO):
            def journal(self, path, event):
                if event["kind"].startswith("restore"):
                    raise OSError("restore journal unavailable")
                super().journal(path, event)

        result = self.run_owner(RestoreJournalIO(), expect_run=True)
        self.assertTrue(result["restoration_complete"])
        self.assertEqual(result["owner_exit"], 1)
        self.assert_originals()

    def test_published_suspended_worker_recovers_missing_assignment_receipt(self):
        self.set_runner(finish="record.pop('assigned_before_execution')\nraise OSError('initial job save failed')\n")
        result = self.run_owner(expect_run=True)
        self.assertTrue(result["closure"]["verified"])
        self.assertTrue(result["closure"]["guards_qualified"])
        self.assertEqual(result["owner_exit"], 1)
        self.assert_originals()

    def test_unfinished_exact_worker_prevents_restore_even_if_job_is_empty(self):
        self.set_runner(finish="record.pop('assigned_before_execution')\njob.contains = lambda handle: False\nworker.wait = lambda timeout: (_ for _ in ()).throw(OSError('worker not finished'))\nworker.close = lambda: (_ for _ in ()).throw(OSError('refuse live worker'))\nraise RuntimeError('failed runner')\n")
        result = self.run_owner(expect_run=True)
        self.assertEqual(result["closure"]["active_at_release"], 0)
        self.assertFalse(result["closure"]["verified"])
        self.assertFalse(result["restoration_complete"])

    def test_changed_guard_values_fail_qualification_even_after_safe_restore(self):
        self.set_runner(before_finish="record['limits']['aggregate_job_cpu_percent'] = 15\n")
        result = self.run_owner(expect_run=True)
        self.assertTrue(result["closure"]["verified"])
        self.assertFalse(result["closure"]["guards_qualified"])
        self.assertEqual(result["owner_exit"], 1)
        self.assert_originals()

    def test_startup_failure_before_job_creation_restores_without_json(self):
        self.runner.write_text("raise OSError('startup failed before Job creation')\n")
        self.pin = owner.sha256(self.runner.read_bytes())
        result = self.run_owner(expect_run=True)
        self.assertEqual(result["closure"]["evidence"], "before_job_creation")
        self.assertTrue(result["restoration_complete"])
        self.assertEqual(result["owner_exit"], 1)
        self.assert_originals()

    def test_system_exit_preserves_scope_and_process_global_state(self):
        self.set_runner(suffix="import sys\nsys.path.append('fake stage addition')\nsys.dont_write_bytecode = not sys.dont_write_bytecode\nraise SystemExit(7)\n")
        old_argv, old_path, old_bytecode = list(sys.argv), list(sys.path), sys.dont_write_bytecode
        result = self.run_owner(expect_run=True)
        self.assertEqual(result["runner_exit"], 7)
        self.assertTrue(result["restoration_complete"])
        self.assertEqual(sys.argv, old_argv)
        self.assertEqual(sys.path, old_path)
        self.assertEqual(sys.dont_write_bytecode, old_bytecode)
        self.assert_originals()

    def test_concurrent_spec_edit_cannot_change_executed_snapshot(self):
        test = self
        expected = self.spec.read_bytes()
        self.set_runner(before_finish="import sys, json\nfrom pathlib import Path\nassert json.loads(Path(sys.argv[1]).read_bytes())['limit'] == 330\n")

        class SpecWriterIO(TrackingIO):
            def atomic_replace(self, path, data, **kwargs):
                super().atomic_replace(path, data, **kwargs)
                if path == test.targets[test.second] and data == test.candidates[test.second]:
                    changed = json.loads(test.spec.read_text())
                    changed["limit"] = 999
                    test.spec.write_text(json.dumps(changed))

        result = self.run_owner(SpecWriterIO(), expect_run=True)
        self.assertEqual(result["owner_exit"], 0)
        self.assertEqual(Path(result["executed_spec"]).read_bytes(), expected)
        self.assertEqual(json.loads(self.spec.read_text())["limit"], 999)
        self.assert_originals()

    def test_active_query_failure_still_attempts_kill_on_close_without_restore_claim(self):
        self.set_runner(finish="job.active = lambda: (_ for _ in ()).throw(OSError('accounting unavailable'))\nraise RuntimeError('failed runner')\n")
        result = self.run_owner(expect_run=True)
        self.assertFalse(result["closure"]["verified"])
        self.assertEqual(result["closure"]["handle_close"], "checked_success")
        self.assertFalse(result["restoration_complete"])

    def test_failed_close_is_reported_and_exact_namespace_retained(self):
        self.set_runner(finish="job.api.CloseHandle = lambda handle: False\nraise RuntimeError('failed runner')\n")
        result = self.run_owner(expect_run=True)
        self.assertTrue(result["closure"]["verified"])
        self.assertEqual(result["owner_exit"], 1)
        self.assertIsNotNone(result.retained_namespace["job"].handle)
        self.assertTrue(any("CloseHandle returned false" in e for e in result["errors"]))
        self.assert_originals()

    def test_unassigned_wait_failure_cannot_become_absence_by_clearing_handles(self):
        self.set_runner(finish="""
record.pop('assigned_before_execution')
job.contains = lambda handle: False
worker.wait = lambda timeout: (_ for _ in ()).throw(OSError('still alive outside Job'))
worker.close = lambda: setattr(worker, '_handle', None)
raise RuntimeError('failed unassigned worker')
""")
        result = self.run_owner(expect_run=True)
        self.assertEqual(result["closure"]["active_at_release"], 0)
        self.assertFalse(result["closure"]["verified"])
        self.assertFalse(result["closure"]["guards_qualified"])
        self.assertFalse(result["restoration_complete"])
        for relative, target in self.targets.items():
            self.assertEqual(target.read_bytes(), self.candidates[relative])

    def test_live_job_assignment_and_zero_accounting_prove_already_closed_worker_absent(self):
        self.set_runner(finish="""
worker.close()
worker.wait = lambda timeout: (_ for _ in ()).throw(OSError('creation handle already closed'))
raise OSError('runner cpu accounting failed before final record')
""")
        result = self.run_owner(expect_run=True)
        self.assertTrue(result["closure"]["verified"])
        self.assertTrue(result["closure"]["guards_qualified"])
        self.assertTrue(result["restoration_complete"])
        self.assertTrue(any("creation handle already closed" in s for s in result["errors"]))
        self.assertEqual(result["owner_exit"], 1)
        self.assert_originals()

    def test_exact_wait_without_assignment_does_not_qualify_native_scope(self):
        self.set_runner(finish="record.pop('assigned_before_execution')\njob.contains = lambda handle: False\nraise OSError('unassigned suspended worker was retained')\n")
        result = self.run_owner(expect_run=True)
        self.assertFalse(result["closure"]["verified"])
        self.assertFalse(result["closure"]["guards_qualified"])
        self.assertFalse(result["restoration_complete"])
        self.assertEqual(result["owner_exit"], 1)
        for relative, target in self.targets.items():
            self.assertEqual(target.read_bytes(), self.candidates[relative])


    def test_owned_180_recipe_preserves_pinned_snapshot_guards_and_restoration(self):
        spec = json.loads(self.spec.read_text())
        spec["limit"] = 180
        self.spec.write_text(json.dumps(spec), encoding="utf-8")
        expected = self.spec.read_bytes()
        self.set_runner(before_finish="import sys, json\nfrom pathlib import Path\nretained = json.loads(Path(sys.argv[1]).read_bytes())\nassert type(retained['limit']) is int and retained['limit'] == 180\n")
        test = self

        class SpecWriterIO(TrackingIO):
            def atomic_replace(self, path, data, **kwargs):
                super().atomic_replace(path, data, **kwargs)
                if path == test.targets[test.second] and data == test.candidates[test.second]:
                    changed = json.loads(test.spec.read_text())
                    changed["limit"] = 999
                    test.spec.write_text(json.dumps(changed), encoding="utf-8")

        result = self.run_owner(SpecWriterIO(), expect_run=True)
        self.assertEqual(result["owner_exit"], 0, result["errors"])
        self.assertTrue(result["closure"]["verified"])
        self.assertTrue(result["closure"]["guards_qualified"])
        self.assertEqual(result["closure"]["limits"], LIMITS)
        self.assertTrue(result["restoration_complete"])
        self.assertEqual(Path(result["executed_spec"]).read_bytes(), expected)
        self.assertEqual(json.loads(self.spec.read_text())["limit"], 999)
        self.assert_originals()
        self.assert_backups()

    def test_unreviewed_deadline_types_and_values_reject_before_mutation(self):
        rejected = [True, False, 180.0, 330.0, float("nan"), float("inf"),
                    None, "180", "330", 0, -1, 179, 181, 329, 331, 999,
                    [], [180], {}, {"limit": 180}]
        for limit in rejected:
            with self.subTest(limit=repr(limit)):
                spec = json.loads(self.spec.read_text())
                spec["limit"] = limit
                self.spec.write_text(json.dumps(spec), encoding="utf-8")
                tracking = TrackingIO()
                with self.assertRaisesRegex(owner.OwnerError, "exact integer 180 or 330"):
                    self.run_owner(tracking)
                self.assert_originals()
                self.assertEqual(tracking.events, [])
                self.assertFalse((self.root / "evidence/dummy-owner").exists())
                self.assertFalse((self.root / "evidence/dummy-stage").exists())

    def test_owned_deadlines_still_require_exact_guards_family(self):
        for limit in (180, 330):
            for family in ("content", "guards ", "Guards", None, False):
                with self.subTest(limit=limit, family=family):
                    spec = json.loads(self.spec.read_text())
                    spec.update(limit=limit, family=family)
                    self.spec.write_text(json.dumps(spec), encoding="utf-8")
                    with self.assertRaisesRegex(owner.OwnerError, "guards-family"):
                        self.run_owner()
                    self.assert_originals()
                    self.assertFalse((self.root / "evidence/dummy-owner").exists())

    def test_180_deadline_does_not_authorize_schema_receiver(self):
        spec = json.loads(self.spec.read_text())
        spec["limit"] = 180
        self.spec.write_text(json.dumps(spec), encoding="utf-8")
        manifest = json.loads(self.manifest.read_text())
        manifest["files"]["scripts/core/scenario_sequence_schema.gd"] = {}
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(owner.OwnerError, "reviewed two/three"):
            self.run_owner()
        self.assert_originals()
        self.assertFalse((self.root / "evidence/dummy-owner").exists())


if __name__ == "__main__":
    unittest.main()
