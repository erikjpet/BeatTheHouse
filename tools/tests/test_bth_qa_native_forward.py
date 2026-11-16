"""Synthetic native admission contracts; no actual profiles or workers are opened.

Install beside test_bth_qa_storage.py before discovery.  Root executes this file
with the existing guard suites in an admitted capped E: QA worker.
"""
from copy import deepcopy
from dataclasses import replace
import hashlib
from pathlib import Path
import unittest
from unittest.mock import patch

import bth_qa_storage as g
import bth_qa_native_forward as n
import test_bth_qa_storage as base_tests


class FakeMutexAPI:
    def __init__(self):
        self.releases = 0
        self.closes = 0

    def ReleaseMutex(self, _handle):
        self.releases += 1
        return True

    def CloseHandle(self, _handle):
        self.closes += 1


class NativeForwardTests(unittest.TestCase):
    def setUp(self):
        base_tests.StorageGuardTests.setUp(self)
        self.workspace = Path(r"E:\CodexQA\BTH\workspaces\crew-ui-261116\source")
        self.origin = Path(r"E:\CodexQA\BTH\runs\crew-fresh-cj2-261116")
        self.custody = self.workspace / "evidence/crew-fresh-cj2-261116-native-custody.json"
        self.commit = "8f5379c511a97fa1ece47ef81ba9db248fd14363"
        self.records = {}
        self.identities = {}
        self.mutex_api = FakeMutexAPI()
        self.origin_hashes = dict(n.ORIGIN_HASHES)
        self.origin_metadata = {}
        self.file_hashes = {}
        self.real_origin_reader = n._origin_metadata
        for leaf in (self.workspace, self.custody.parent, self.origin,
                     *(self.origin / name for name in n.PERSISTENT_LEAVES)):
            for ancestor in (*reversed(leaf.parents), leaf):
                self.fs.entries[g._key(ancestor)] = "dir"
        for index, leaf in enumerate(n.PERSISTENT_LEAVES, 10):
            self.identities[g._key(self.origin / leaf)] = (9, index)
        for name in ("_leases", "_lease_profiles", "_lease_bindings", "_lease_layouts"):
            value = getattr(n, name)
            value.clear()
            self.addCleanup(value.clear)
        patches = {
            "_owned_json": self.owned_json,
            "_file_hash": self.file_hash,
            "_dir_identity": lambda path: self.identities[g._key(path)],
            "_current_head": lambda: self.commit,
            "_current_product_digest": lambda: n.PRODUCT_DIGEST,
            "_origin_metadata": lambda: (deepcopy(self.origin_metadata), dict(self.origin_hashes)),
            "_mutex_acquire": lambda _name: ((self.mutex_api, 1), None),
        }
        for name, value in patches.items():
            patcher = patch.object(n, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.records[g._key(self.custody)] = n.bootstrap_custody(self.commit)
        # Each negative starts from a baseline that the real admission accepts.
        self.plan()
        self.assertEqual(self.fs.writes, [])

    def good_job(self, output):
        return {
            "schema": "bth.qa_guarded_run/v1", "timeout_seconds": 180,
            "exit_code": 0, "active_at_release": 0, "timed_out": False,
            "assigned_before_execution": True, "cleanup_errors": [], "error": None,
            "log_error": None, "log_truncated": False,
            "limits": {"cpu_rate": 1200, "aggregate_job_cpu_percent": 12.0,
                       "job_memory_limit_bytes": 2147483648, "kill_on_close": True,
                       "breakaway_allowed": False, "active_processes": 0},
            "command": [str(n.GODOT), "--headless", "--path", str(self.workspace),
                        "--script", str(output.parent / "temp/native_forward.gd"), "--",
                        "--autosave-slot", n.SLOT,
                        "--evidence-output", str(output / "campaign-result.json")],
        }

    def owned_json(self, path):
        key = g._key(path)
        if key not in self.records:
            g._fail("native_receipt_missing", path, "synthetic receipt is absent")
        record = deepcopy(self.records[key])
        return record, hashlib.sha256(n.receipt_bytes(record)).hexdigest()

    def file_hash(self, path):
        key = g._key(path)
        if key in self.file_hashes:
            return self.file_hashes[key]
        if key in self.records:
            return hashlib.sha256(n.receipt_bytes(self.records[key])).hexdigest()
        return "e" * 64

    def plan(self, run="crew-native-unit-01", **overrides):
        args = dict(root=g.DEFAULT_ROOT, workspace=self.workspace, run_id=run,
                    expected_commit=self.commit, custody=self.custody)
        args.update(overrides)
        return g.plan_native_forward_layout(**args)

    def rejected(self, call, code=None):
        with self.assertRaises(g.StorageGuardError) as caught:
            call()
        if code is not None:
            self.assertEqual(caught.exception.code, code)
        return caught.exception

    def prepared(self, run="crew-native-unit-01"):
        return g.prepare_layout(self.plan(run))

    def release(self, layout):
        return g.release_native_forward_layout(layout, active_owned_processes=0)

    @staticmethod
    def good_campaign(previous=None):
        value = {"checks": 12, "failures": [], "facts": {
            "slot": n.SLOT, "final": {"cash": 161, "clock": 893},
            "final_save": {"slot_id": n.SLOT, "has_loadable": True,
                           "primary_exists": True, "primary_loadable": True,
                           "primary_corrupt": False}}}
        if previous is not None:
            value["native_forward"] = {
                "previous_case": previous["last_case"],
                "previous_campaign_sha256": previous["receipt_hashes"]["campaign"],
                "prior_state_matched": True, "save_completed": True,
                "closed": True, "completed": True, "inflight": None, "error": None}
        return value

    def begin_case(self, run="crew-native-unit-01"):
        layout = self.prepared(run)
        previous = deepcopy(self.records[g._key(self.custody)])
        archive = layout.evidence / "native-custody-before.json"
        self.records[g._key(archive)] = previous
        started = n.start_record(layout.native_binding, layout.run_id, layout.evidence, "e" * 64)
        self.records[g._key(self.custody)] = deepcopy(started)
        job = self.good_job(layout.evidence)
        campaign = self.good_campaign(previous)
        self.records[g._key(layout.evidence / "job.json")] = job
        self.records[g._key(layout.evidence / "campaign-result.json")] = campaign
        return layout, started, job, campaign

    def finish_case(self, layout, started, job, campaign):
        closed = n.close_record(layout.native_binding, started, job, campaign)
        self.records[g._key(layout.evidence / "state.json")] = closed["state"]
        self.records[g._key(self.custody)] = closed["custody"]
        self.release(layout)
        return closed

    def origin_documents(self):
        return {
            "storage-manifest.json": {"schema": "bth-qa-storage/v1", "prepared": True,
                "run_id": n.CAMPAIGN_ID,
                "paths": {**{name: str(self.origin / name) for name in g._LEAVES},
                          "workspace": str(self.workspace)}},
            "fresh-profile-origin.json": {"schema": "bth.crew_fresh_native/v1",
                "run_id": n.CAMPAIGN_ID, "autosave_slot": n.SLOT,
                "source_commit": n.ORIGIN_COMMIT, "historical_profiles_read": False,
                "profile_copy_performed": False, "profile_resume_performed": False,
                "empty_before_worker": {name: {"empty": True} for name in
                                        ("profile", "save_dir", "appdata", "localappdata")}},
            "fresh-launch-result.json": {"schema": "bth.crew_fresh_native_result/v1",
                "source_commit": n.ORIGIN_COMMIT, "source_commit_after": n.ORIGIN_COMMIT,
                "autosave_slot": n.SLOT, "closure_ok": True,
                "product_inputs_unchanged": True, "copied_script_unchanged": True,
                "product_inputs_before_sha256": n.PRODUCT_DIGEST,
                "product_inputs_after_sha256": n.PRODUCT_DIGEST,
                "worker_log_sha256": n.ORIGIN_HASHES["worker.log"]},
            "source-files.json": {"source_commit": n.ORIGIN_COMMIT,
                "product_inputs_before": {"tree_sha256": n.PRODUCT_DIGEST}},
            "job.json": self.good_job(self.origin / "evidence"),
            "campaign-result.json": self.good_campaign(),
        }

    def read_synthetic_origin(self, documents, bad_hash=None):
        def reader(path):
            self.assertEqual(path.parent, self.origin / "evidence")
            digest = "f" * 64 if path.name == bad_hash else n.ORIGIN_HASHES[path.name]
            return deepcopy(documents[path.name]), digest
        with patch.object(n, "_owned_json", side_effect=reader), patch.object(
                n, "_file_hash", side_effect=lambda path: n.ORIGIN_HASHES[path.name]):
            return self.real_origin_reader()

    def test_plan_is_read_only_and_records_actual_six_persistent_roots(self):
        with patch.object(Path, "open", side_effect=AssertionError("actual file I/O forbidden")):
            layout = self.plan()
        self.assertIsInstance(layout.native_binding, n.Cj2NativeBinding)
        self.assertIsNone(layout.resident_binding)
        self.assertEqual(layout.as_dict()["schema"], "bth-qa-storage/native-forward-v1")
        self.assertEqual(tuple(n.PERSISTENT_LEAVES),
                         ("profile", "save_dir", "appdata", "localappdata", "home", "cache"))
        for name in n.PERSISTENT_LEAVES:
            self.assertEqual(getattr(layout, name), self.origin / name)
            self.assertEqual(layout.as_dict()["paths"][name], str(self.origin / name))
        self.assertEqual(layout.expected_write_bytes + layout.reserve_bytes, 24 * g.GIB)
        self.assertEqual(self.fs.writes, [])

    def test_prepare_and_launch_never_create_or_copy_persistent_directories(self):
        layout = self.prepared()
        self.assertTrue(layout.prepared)
        self.assertFalse(any(g._inside(self.origin, Path(path)) for path in self.fs.writes))
        env = g.child_environment(layout, {"APPDATA": r"C:\old", "Temp": r"C:\old"})
        self.assertTrue(g.check_launch(layout, layout.workspace, env))
        self.assertEqual(env["BTH_SAVE_DIR"], str(self.origin / "save_dir"))
        self.assertEqual(env["APPDATA"], str(self.origin / "appdata"))
        self.assertEqual(env["LOCALAPPDATA"], str(self.origin / "localappdata"))
        self.assertEqual(env["TEMP"], str(layout.temp))
        self.release(layout)
        self.rejected(lambda: g.check_launch(layout, layout.workspace, env))

    def test_foreign_workspace_custody_case_or_commit_cannot_admit(self):
        for override in ({"root": r"C:\qa"},
                         {"workspace": self.workspace.parent / "foreign"},
                         {"custody": self.workspace / "evidence/foreign.json"},
                         {"run_id": n.CAMPAIGN_ID},
                         {"expected_commit": "b" * 40}):
            with self.subTest(override=override):
                self.rejected(lambda: self.plan(**override))
        self.assertEqual(self.fs.writes, [])

    def test_wrong_slot_foreign_origin_and_non_native_custody_rejected(self):
        record = self.records[g._key(self.custody)]
        for key, value in (
            ("autosave_slot", "CREW-FRESH-FOREIGN"), ("campaign_id", "foreign-campaign"),
            ("origin_run_root", str(self.origin.parent / "foreign")),
            ("workspace", str(self.workspace.parent / "foreign")),
            ("schema", "bth-qa-storage/resident-v1"), ("last_kind", "browser"),
            ("status", "CASE_IN_PROGRESS"), ("product_inputs_sha256", "f" * 64),
        ):
            with self.subTest(key=key):
                old = deepcopy(record)
                record[key] = value
                try:
                    self.rejected(self.plan)
                finally:
                    record.clear()
                    record.update(old)
        self.assertEqual(self.fs.writes, [])

    def test_wrong_persistent_path_or_directory_identity_rejected(self):
        record = self.records[g._key(self.custody)]
        for name in n.PERSISTENT_LEAVES:
            with self.subTest(leaf=name):
                old = record["persistent_paths"][name]
                record["persistent_paths"][name] = str(self.origin.parent / "foreign" / name)
                try:
                    self.rejected(self.plan)
                finally:
                    record["persistent_paths"][name] = old
        layout = self.plan()
        self.identities[g._key(self.origin / "appdata")] = (9, 9999)
        self.rejected(lambda: g.prepare_layout(layout))
        self.assertEqual(self.fs.writes, [])

    def test_recorded_directory_ids_require_actual_integer_identity_parts(self):
        record = self.records[g._key(self.custody)]
        for name in n.PERSISTENT_LEAVES:
            with self.subTest(leaf=name):
                old = record["directory_identities"][name][0]
                record["directory_identities"][name][0] = float(old)
                try:
                    self.rejected(self.plan, "native_custody_identity")
                finally:
                    record["directory_identities"][name][0] = old
        self.assertEqual(self.fs.writes, [])

    def test_product_drift_is_rejected_before_preparation(self):
        layout = self.plan()
        with patch.object(n, "_current_product_digest", return_value="f" * 64):
            self.rejected(lambda: g.prepare_layout(layout))
        with patch.object(n, "_current_head", return_value="b" * 40):
            self.rejected(lambda: g.prepare_layout(layout))
        self.assertEqual(self.fs.writes, [])

    def test_receipt_drift_and_acquire_time_race_leave_zero_writes(self):
        layout = self.plan()
        record = self.records[g._key(self.custody)]
        record["unrelated_note"] = "changed after planning"
        self.rejected(lambda: g.prepare_layout(layout))
        del record["unrelated_note"]
        layout = self.plan()
        def race(_name):
            record["unrelated_note"] = "changed during mutex acquisition"
            return (self.mutex_api, 1), None
        with patch.object(n, "_mutex_acquire", side_effect=race):
            self.rejected(lambda: g.prepare_layout(layout))
        self.assertEqual(self.fs.writes, [])
        self.assertFalse(n._leases)
        self.assertFalse(n._lease_profiles)

    def test_reparse_and_replaced_persistent_directory_fail_closed(self):
        for path in (self.origin / "save_dir", self.origin / "appdata", self.origin.parent):
            with self.subTest(path=path):
                key = g._key(path)
                old = self.fs.entries[key]
                self.fs.entries[key] = "reparse"
                try:
                    self.rejected(self.plan)
                finally:
                    self.fs.entries[key] = old
        self.assertEqual(self.fs.writes, [])

    def test_held_or_abandoned_mutex_never_creates_output(self):
        for primitive, diagnostic in (("resident_profile_busy", "native_profile_busy"),
                                      ("resident_lease_abandoned", "native_lease_abandoned")):
            with self.subTest(error=primitive), patch.object(n, "_mutex_acquire", return_value=(None, primitive)):
                self.rejected(lambda: g.prepare_layout(self.plan()), diagnostic)
        self.assertEqual(self.fs.writes, [])

    def test_recursive_ownership_and_active_or_untyped_release_rejected(self):
        one = self.prepared("crew-native-one")
        self.rejected(lambda: g.prepare_layout(self.plan("crew-native-two")))
        for active in (1, False, None):
            with self.subTest(active=active):
                self.rejected(lambda: g.release_native_forward_layout(one, active_owned_processes=active))
                self.assertIn(one.token, n._leases)
        self.release(one)
        self.assertNotIn(one.token, n._leases)

    def test_every_launch_revalidates_budget_metadata_environment_and_cwd(self):
        layout = self.prepared()
        env = g.child_environment(layout, {})
        self.fs.free = 23 * g.GIB
        self.rejected(lambda: g.check_launch(layout, layout.workspace, env), "insufficient_space")
        self.fs.free = 100 * g.GIB
        for key in ("TEMP", "APPDATA", "LOCALAPPDATA", "BTH_SAVE_DIR", "HOME"):
            with self.subTest(key=key):
                self.rejected(lambda: g.check_launch(layout, layout.workspace, dict(env, **{key: r"C:\spill"})))
                self.rejected(lambda: g.check_launch(layout, layout.workspace, dict(env, **{key: str(layout.run_root / "wrong")})))
        self.rejected(lambda: g.check_launch(layout, layout.workspace, dict(env, temp=str(layout.temp))), "duplicate_environment")
        self.rejected(lambda: g.check_launch(layout, layout.evidence, env), "cwd_mismatch")
        self.records[g._key(self.custody)]["status"] = "CASE_IN_PROGRESS"
        self.rejected(lambda: g.check_launch(layout, layout.workspace, env))
        self.release(layout)

    def test_fresh_and_browser_admission_cannot_be_relabeled_as_native(self):
        fresh = g.plan_layout(g.DEFAULT_ROOT, self.workspace, "fresh-unit-separate")
        self.assertEqual(fresh.as_dict()["schema"], "bth-qa-storage/v1")
        for name in n.PERSISTENT_LEAVES:
            with self.subTest(leaf=name):
                self.rejected(lambda: g.validate_layout(replace(fresh, **{name: self.origin / name})), "layout_mismatch")
        native = self.plan()
        self.rejected(lambda: g.validate_layout(replace(native, native_binding=None)), "layout_mismatch")
        self.rejected(lambda: g.validate_layout(replace(native, resident_binding=object())))
        self.rejected(lambda: g.plan_resident_layout(
            g.DEFAULT_ROOT, self.workspace, "browser-unit-separate",
            profile=self.origin / "profile", custody=self.custody,
            campaign_id=n.CAMPAIGN_ID, origin="http://127.0.0.1:8138", expected_commit=self.commit))

    def test_real_origin_validator_rejects_nonfresh_foreign_or_changed_evidence(self):
        documents = self.origin_documents()
        self.read_synthetic_origin(documents)
        origin = documents["fresh-profile-origin.json"]
        for key, value in (("run_id", "foreign"), ("autosave_slot", "CREW-FRESH-OTHER"),
                           ("source_commit", "b" * 40), ("historical_profiles_read", True),
                           ("profile_copy_performed", True), ("profile_resume_performed", True)):
            with self.subTest(key=key):
                old = origin[key]
                origin[key] = value
                try:
                    self.rejected(lambda: self.read_synthetic_origin(documents), "native_origin_identity")
                finally:
                    origin[key] = old
        for name in ("profile", "save_dir", "appdata", "localappdata"):
            with self.subTest(nonempty=name):
                origin["empty_before_worker"][name]["empty"] = False
                try:
                    self.rejected(lambda: self.read_synthetic_origin(documents), "native_origin_identity")
                finally:
                    origin["empty_before_worker"][name]["empty"] = True
        self.rejected(lambda: self.read_synthetic_origin(documents, "job.json"), "native_origin_changed")
        self.assertEqual(self.fs.writes, [])

    def test_bootstrap_cannot_reset_existing_clean_or_inprogress_custody(self):
        self.fs.entries[g._key(self.custody)] = "file"
        record = self.records[g._key(self.custody)]
        for status in ("CLEAN_CLOSED", "CASE_IN_PROGRESS"):
            with self.subTest(status=status):
                record["status"] = status
                before = deepcopy(record)
                with patch.object(n, "_current_head", side_effect=AssertionError("unexpected source read")), \
                     patch.object(n, "_origin_metadata", side_effect=AssertionError("unexpected metadata read")), \
                     patch.object(n, "_dir_identity", side_effect=AssertionError("unexpected profile identity read")):
                    self.rejected(lambda: n.bootstrap_custody(self.commit), "native_bootstrap_occupied")
                self.assertEqual(record, before)
        self.assertEqual(self.fs.writes, [])

    def test_start_requires_lease_exact_archive_case_output_and_script_hash(self):
        layout = self.plan()
        self.rejected(lambda: n.start_record(layout.native_binding, layout.run_id,
                                            layout.evidence, "e" * 64), "native_lease_required")
        layout = g.prepare_layout(layout)
        archive = layout.evidence / "native-custody-before.json"
        self.records[g._key(archive)] = deepcopy(self.records[g._key(self.custody)])
        for case, output, digest in (("crew-native-other", layout.evidence, "e" * 64),
                                     (layout.run_id, layout.temp, "e" * 64),
                                     (layout.run_id, layout.evidence, "not-a-hash")):
            with self.subTest(case=case, output=output, digest=digest):
                self.rejected(lambda: n.start_record(layout.native_binding, case, output, digest),
                              "native_case_identity")
        self.records[g._key(archive)]["altered"] = True
        self.rejected(lambda: n.start_record(layout.native_binding, layout.run_id,
                                            layout.evidence, "e" * 64), "native_chain_changed")
        self.release(layout)

    def test_successful_forward_closure_is_flat_honest_and_readmissible(self):
        layout, started, job, campaign = self.begin_case()
        self.assertEqual(started["status"], "CASE_IN_PROGRESS")
        self.rejected(lambda: g.check_launch(layout, layout.workspace,
                                            g.child_environment(layout, {})))
        closed = self.finish_case(layout, started, job, campaign)
        state = closed["state"]
        self.assertEqual(state["schema"], n.STATE_SCHEMA)
        self.assertEqual(state["previous_case"], n.CAMPAIGN_ID)
        self.assertFalse(state["profile_copy_performed"])
        for key in ("closed", "completed", "save_completed"):
            self.assertIs(state[key], True)
        self.assertIsNone(state["inflight"])
        self.assertIsNone(state["error"])
        self.assertEqual(closed["custody"]["status"], "CLEAN_CLOSED")
        next_layout = self.plan("crew-native-unit-02")
        self.assertEqual(next_layout.native_binding.last_case, layout.run_id)
        self.assertEqual(next_layout.native_binding.previous_campaign_sha256,
                         closed["custody"]["receipt_hashes"]["campaign"])
        self.assertFalse(any(g._inside(self.origin, Path(path)) for path in self.fs.writes))

    def test_failed_active_uncertain_or_type_forged_job_cannot_close(self):
        layout, started, job, campaign = self.begin_case()
        original = deepcopy(job)
        for key, value in (("exit_code", 1), ("exit_code", False),
                           ("active_at_release", 1), ("active_at_release", False),
                           ("timed_out", True), ("timed_out", None),
                           ("assigned_before_execution", False), ("cleanup_errors", ["failed"]),
                           ("cleanup_errors", None), ("error", ""),
                           ("log_truncated", True), ("log_error", ""),
                           ("schema", "browser-job"), ("timeout_seconds", 181),
                           ("timeout_seconds", False)):
            with self.subTest(key=key, value=value):
                job[key] = value
                try:
                    self.rejected(lambda: n.close_record(layout.native_binding, started, job, campaign),
                                  "native_job_not_closed")
                finally:
                    job.clear()
                    job.update(deepcopy(original))
        self.finish_case(layout, started, job, campaign)

    def test_native_closure_cannot_certify_weakened_or_contradictory_caps(self):
        layout, started, job, campaign = self.begin_case()
        limits = job["limits"]
        for key, value in (("cpu_rate", 1300), ("cpu_rate", 1200.0),
                           ("job_memory_limit_bytes", 3 * g.GIB),
                           ("job_memory_limit_bytes", float(2 * g.GIB)),
                           ("aggregate_job_cpu_percent", 13.0),
                           ("active_processes", 1), ("active_processes", False),
                           ("kill_on_close", False), ("breakaway_allowed", True)):
            with self.subTest(key=key, value=value):
                old = limits[key]
                limits[key] = value
                try:
                    self.rejected(lambda: n.close_record(layout.native_binding, started, job, campaign),
                                  "native_job_not_closed")
                finally:
                    limits[key] = old
        self.finish_case(layout, started, job, campaign)

    def test_job_command_must_use_exact_executable_source_slot_and_case_output(self):
        layout, started, job, campaign = self.begin_case()
        original = list(job["command"])
        variants = []
        for argument, wrong in (("--path", str(self.workspace.parent / "foreign")),
                                ("--autosave-slot", "CREW-FRESH-OTHER"),
                                ("--evidence-output", str(layout.temp / "other.json")),
                                ("--script", str(self.origin / "temp/old.gd"))):
            command = list(original)
            command[command.index(argument) + 1] = wrong
            variants.append(command)
        variants += [[r"C:\foreign\godot.exe", *original[1:]],
                     [value for value in original if value != "--headless"],
                     original + ["--autosave-slot", n.SLOT]]
        for command in variants:
            with self.subTest(command=command):
                job["command"] = command
                try:
                    self.rejected(lambda: n.close_record(layout.native_binding, started, job, campaign),
                                  "native_job_identity")
                finally:
                    job["command"] = list(original)
        self.finish_case(layout, started, job, campaign)

    def test_worker_requires_passing_same_slot_saved_result_and_explicit_forward_match(self):
        layout, started, job, campaign = self.begin_case()
        variants = []
        for key, value in (("checks", 0), ("checks", True), ("failures", ["failed"])):
            bad = deepcopy(campaign)
            bad[key] = value
            variants.append((bad, "native_campaign_not_saved"))
        for key, value in (("slot", "CREW-FRESH-OTHER"), ("final", {})):
            bad = deepcopy(campaign)
            bad["facts"][key] = value
            variants.append((bad, "native_campaign_not_saved"))
        for key, value in (("slot_id", "CREW-FRESH-OTHER"), ("has_loadable", False),
                           ("primary_exists", 1), ("primary_loadable", False),
                           ("primary_corrupt", True)):
            bad = deepcopy(campaign)
            bad["facts"]["final_save"][key] = value
            variants.append((bad, "native_campaign_not_saved"))
        for key, value in (("previous_case", "foreign"), ("previous_campaign_sha256", "f" * 64),
                           ("prior_state_matched", False), ("save_completed", False),
                           ("closed", False), ("completed", 1), ("inflight", False), ("error", "")):
            bad = deepcopy(campaign)
            bad["native_forward"][key] = value
            variants.append((bad, "native_forward_state_unproven"))
        for bad, diagnostic in variants:
            with self.subTest(diagnostic=diagnostic, value=bad):
                self.records[g._key(layout.evidence / "campaign-result.json")] = bad
                try:
                    self.rejected(lambda: n.close_record(layout.native_binding, started, job, bad), diagnostic)
                finally:
                    self.records[g._key(layout.evidence / "campaign-result.json")] = campaign
        self.finish_case(layout, started, job, campaign)

    def test_changed_worker_archive_or_owned_inprogress_record_cannot_close(self):
        layout, started, job, campaign = self.begin_case()
        supplied = deepcopy(job)
        supplied["exit_code"] = 1
        self.rejected(lambda: n.close_record(layout.native_binding, started, supplied, campaign),
                      "native_result_changed")
        script = Path(job["command"][job["command"].index("--script") + 1])
        self.file_hashes[g._key(script)] = "f" * 64
        self.rejected(lambda: n.close_record(layout.native_binding, started, job, campaign),
                      "native_script_changed")
        del self.file_hashes[g._key(script)]
        archive = self.records[g._key(layout.evidence / "native-custody-before.json")]
        archive["tampered"] = True
        self.rejected(lambda: n.close_record(layout.native_binding, started, job, campaign),
                      "native_chain_changed")
        del archive["tampered"]
        current = self.records[g._key(self.custody)]
        current["lease_token"] = "f" * 32
        self.rejected(lambda: n.close_record(layout.native_binding, started, job, campaign),
                      "native_inprogress_changed")
        current["lease_token"] = started["lease_token"]
        self.finish_case(layout, started, job, campaign)

    def test_changed_successor_receipt_log_or_predecessor_blocks_readmission(self):
        layout, started, job, campaign = self.begin_case()
        self.finish_case(layout, started, job, campaign)
        state = self.records[g._key(layout.evidence / "state.json")]
        state["completed"] = False
        self.rejected(lambda: self.plan("crew-native-unit-02"), "native_chain_changed")
        state["completed"] = True
        log = g._key(layout.evidence / "worker.log")
        self.file_hashes[log] = "f" * 64
        self.rejected(lambda: self.plan("crew-native-unit-02"), "native_chain_changed")
        del self.file_hashes[log]
        archive = self.records[g._key(layout.evidence / "native-custody-before.json")]
        archive["extra"] = "changed"
        self.rejected(lambda: self.plan("crew-native-unit-02"), "native_chain_changed")
        del archive["extra"]
        self.plan("crew-native-unit-02")

    def test_forged_binding_cannot_release_held_native_lease(self):
        layout = self.prepared()
        forged = replace(layout, native_binding=replace(layout.native_binding, mutex_name="Local\\foreign"))
        self.rejected(lambda: g.release_native_forward_layout(forged, active_owned_processes=0),
                      "native_lease_owner_mismatch")
        self.assertIn(layout.token, n._leases)
        self.release(layout)


class NativeWorkerAssignmentTests(unittest.TestCase):
    def worker(self):
        class Worker:
            _handle = 7
            resumed = False
            closed = False
            stdin = object()
            def resume(self):
                self.resumed = True
            def close(self):
                self.closed = True
        return Worker()

    def test_qualification_inputs_cannot_escape_or_relabel_other_runs(self):
        import crew_cj2_native_forward as adapter
        for run in (r'C:\owner', '..', r'crew-native-guards1\..\foreign', 'crew-fresh-cj2-261116', 'crew-native-syntax1-261116'):
            with self.subTest(run=run), self.assertRaises(AssertionError):
                adapter.verify_qualification(run, 'qualification.json')

    def test_qualification_requires_the_exact_source_set_and_full_hashes(self):
        import crew_cj2_native_forward as adapter
        good = {name: 'a' * 64 for name in adapter.QUALIFIED_SOURCES}
        self.assertEqual(adapter.qualified_sources({'source_files': good}), good)
        for bad in ({}, {'../foreign': 'a' * 64}, dict(good, **{'tools/bth_qa_storage.py': True}), dict(good, **{'tools/bth_qa_storage.py': 'a'})):
            with self.subTest(bad=bad), self.assertRaises(AssertionError):
                adapter.qualified_sources({'source_files': bad})

    def test_custody_callback_runs_only_after_assignment_before_resume(self):
        import crew_cj2_native_forward as adapter
        worker = self.worker()
        calls = []
        class Job:
            def contains(self, handle):
                calls.append(("assigned", handle))
                return True
        wrapped = adapter.assigned_worker(worker, Job(), lambda: calls.append(("custody", worker.resumed)))
        self.assertEqual(calls, [("assigned", 7), ("custody", False)])
        self.assertFalse(worker.resumed)
        self.assertIs(wrapped.stdin, worker.stdin)
        wrapped.resume()
        self.assertTrue(worker.resumed)

    def test_custody_failure_returns_owned_worker_and_prevents_resume(self):
        import crew_cj2_native_forward as adapter
        worker = self.worker()
        class Job:
            def contains(self, _handle): return True
        def reject(): raise OSError("custody write refused")
        wrapped = adapter.assigned_worker(worker, Job(), reject)
        with self.assertRaisesRegex(RuntimeError, "custody write refused"):
            wrapped.resume()
        self.assertFalse(worker.resumed)
        wrapped.close()
        self.assertTrue(worker.closed)

    def test_unassigned_child_cannot_install_custody(self):
        import crew_cj2_native_forward as adapter
        worker = self.worker()
        class Job:
            def contains(self, _handle): return False
        installed = []
        wrapped = adapter.assigned_worker(worker, Job(), lambda: installed.append(True))
        self.assertEqual(installed, [])
        with self.assertRaises(RuntimeError): wrapped.resume()
        self.assertFalse(worker.resumed)

    def test_already_resumed_child_cannot_install_custody(self):
        import crew_cj2_native_forward as adapter
        worker = self.worker()
        worker.resumed = True
        class Job:
            def contains(self, _handle): return True
        installed = []
        wrapped = adapter.assigned_worker(worker, Job(), lambda: installed.append(True))
        self.assertEqual(installed, [])
        with self.assertRaises(RuntimeError): wrapped.resume()


if __name__ == "__main__":
    unittest.main()
