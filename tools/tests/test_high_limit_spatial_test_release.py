"""Synthetic no-I/O contracts for new HL release/certificate/guard composition.

Run only via the parent's admitted capped QA worker. These tests create no
files/directories, start no children, and make no network/engine calls.
"""
import sys
sys.dont_write_bytecode = True

from contextlib import redirect_stdout, redirect_stderr
from copy import deepcopy
import io
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, mock_open, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import grand_spatial_delivered_baseline as baseline
import high_limit_spatial_test_release_profile as release
import high_limit_spatial_test_build as build
import verify_high_limit_spatial_test_served as served
import high_limit_spatial_test_profile as policy


def caps_job(command):
    return {"schema": "bth.qa_guarded_run/v1", "exit_code": 0, "active_at_release": 0, "assigned_before_execution": True,
        "error": None, "cleanup_errors": [], "timed_out": False, "log_error": None, "log_truncated": False,
        "storage_gate_before_job": {"fixture": True}, "storage_gate_before_child": {"fixture": True}, "finished_epoch": 1.0,
        "limits": {"cpu_rate": 1200, "job_memory_limit_bytes": 2 * 1024 ** 3, "kill_on_close": True, "breakaway_allowed": False},
        "command": command}


def cfg_fixture():
    outer = "E:/CodexQA/BTH/workspaces/HL-RELEASE-FIXTURE"
    return {"schema": "bth.high_limit_test_build_inputs/v1", "environment": policy.ENVIRONMENT,
        "outer": outer, "workspace": outer + "/qa_source", "stage": outer + "/qa_source/.tmp/web-release-aaaaaaaa/stage",
        "archive": outer + "/source_inputs/source.tar", "run_prefix": "HL-RELEASE-FIXTURE", "source_commit": "a" * 40,
        "source_tree": "b" * 40, "approval_path": "D:/fixture/final-hl-go.json", "approval_sha256": "c" * 64,
        "art_package_sha256": policy.PACKAGE_SHA, "baseline_certificate_sha256": "d" * 64, "timeout": 1200,
        "engine": "D:/fixture/godot.exe", "native_library": "E:/fixture/native.wasm", "editor_native_library": "E:/fixture/editor.dll",
        "template": "D:/fixture/template.zip", "git": "C:/fixture/git.exe", "git_dir": "D:/fixture/repo.git", "node": "C:/fixture/node.exe"}


def attributes_fixture():
    return {**build.selected.attributes_bytes_policy(build.selected.BASELINE_ATTRIBUTES), "actual_extracted_bytes_verified": True}


class BaselineAuthorityTests(unittest.TestCase):
    def test_untrusted_delivery_index_stops_before_stage_validation(self):
        import publish_environment_art_test as publisher
        with patch.object(baseline, "sha", return_value="0" * 64), patch.object(publisher, "validate_payload") as payload:
            with self.assertRaises(ValueError):
                baseline.load_certificate()
            payload.assert_not_called()

    def test_mismatching_reference_hash_or_path_is_rejected(self):
        with patch.object(baseline, "sha", return_value="a" * 64):
            for record in ({"path": "E:/wrong.json", "sha256": "a" * 64}, {"path": "E:/expected.json", "sha256": "b" * 64}):
                with self.assertRaises(ValueError):
                    baseline.assert_ref(record, Path("E:/expected.json"))

    def test_default_tls_actual_stream_record_is_accepted(self):
        baseline.validate_stream_record({"status": "VERIFIED", "http_status": 200, "default_tls_validation": True,
            "bytes": 12, "sha256": "a" * 64, "url": "https://fixture/asset"}, 12, "a" * 64, "https://fixture/asset")

    def test_non_tls_wrong_length_hash_status_and_redirect_url_are_rejected(self):
        good = {"status": "VERIFIED", "http_status": 200, "default_tls_validation": True,
            "bytes": 12, "sha256": "a" * 64, "url": "https://fixture/asset"}
        for key, bad in (("default_tls_validation", False), ("bytes", 11), ("bytes", True), ("sha256", "b" * 64),
                ("status", "UNCHECKED"), ("http_status", 302), ("url", "https://other/asset")):
            with self.subTest(field=key), self.assertRaises(ValueError):
                baseline.validate_stream_record({**good, key: bad}, 12, "a" * 64, "https://fixture/asset")

    def test_certificate_loader_has_no_arbitrary_baseline_argument(self):
        with self.assertRaises(TypeError):
            baseline.load_certificate({"stage": "E:/arbitrary/stage", "baseline_qualified": True})


class BaselineClosedJobTests(unittest.TestCase):
    def setUp(self):
        self.e = baseline.RUNS / "BASELINE-FIXTURE" / "evidence"
        self.entry = "publish_environment_art_test.py"
        command = ["C:/fixture/python.exe", "-B", "D:/fixture/" + self.entry]
        self.job = {**caps_job(command), "storage_manifest": str(self.e / "storage-manifest.json"), "storage_manifest_sha256": "b" * 64}
        self.docs = {"job.json": self.job, "storage-manifest.json": {"schema": "bth-qa-storage/v1", "prepared": True,
            "paths": {"evidence": str(self.e), "workspace": str(baseline.WORKSPACE)}},
            "launch-claim.json": {"schema": "bth.qa_launch_claim/v1", "manifest_sha256": "b" * 64}}

    def authenticate(self):
        def fake_sha(path):
            name = Path(path).name
            if name == "job.json": return "a" * 64
            if name == "storage-manifest.json": return "b" * 64
            if name == "python.exe": return "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
            return baseline.HELPERS.get(name, "0" * 64)
        with patch.object(baseline.served, "plain", side_effect=lambda path: Path(path)), patch.object(baseline, "sha", side_effect=fake_sha), \
                patch.object(baseline, "read", side_effect=lambda path: self.docs[Path(path).name]):
            return baseline.authenticate_job(self.e, "a" * 64, self.entry)

    def test_actual_caps_command_storage_and_claim_shape_pass(self):
        self.assertEqual(self.authenticate()["exit_code"], 0)

    def test_nonzero_active_timeout_truncation_and_missing_assignment_fail(self):
        for key, value in (("active_at_release", 1), ("timed_out", True), ("log_truncated", True), ("assigned_before_execution", False)):
            old = self.job[key]
            self.job[key] = value
            with self.subTest(field=key), self.assertRaises(ValueError):
                self.authenticate()
            self.job[key] = old

    def test_memory_or_kill_on_close_policy_cannot_be_relaxed(self):
        for key, value in (("job_memory_limit_bytes", 3 * 1024 ** 3), ("kill_on_close", False), ("breakaway_allowed", True)):
            old = self.job["limits"][key]
            self.job["limits"][key] = value
            with self.assertRaises(ValueError):
                self.authenticate()
            self.job["limits"][key] = old

    def test_wrong_entrypoint_and_missing_claim_fail(self):
        original = self.job["command"][:]
        self.job["command"][2] = "D:/fixture/unrelated.py"
        with self.assertRaises(ValueError):
            self.authenticate()
        self.job["command"] = original
        self.docs["launch-claim.json"]["schema"] = "not-a-claim"
        with self.assertRaises(ValueError):
            self.authenticate()

    def test_workspace_evidence_or_manifest_hash_cannot_be_borrowed(self):
        for key in ("workspace", "evidence"):
            old = self.docs["storage-manifest.json"]["paths"][key]
            self.docs["storage-manifest.json"]["paths"][key] = "E:/another-campaign"
            with self.assertRaises(ValueError):
                self.authenticate()
            self.docs["storage-manifest.json"]["paths"][key] = old
        self.docs["launch-claim.json"]["manifest_sha256"] = "c" * 64
        with self.assertRaises(ValueError):
            self.authenticate()


class ReleaseAdmissionTests(unittest.TestCase):
    def test_static_native_trial_go_stops_before_baseline_or_native_auth(self):
        path = SimpleNamespace(stat=lambda: SimpleNamespace(st_size=100))
        value = {"schema": policy.APPROVAL_SCHEMA, "environment_id": policy.ENVIRONMENT, "verdict": "STATIC_GO_FOR_NATIVE_TRIAL"}
        with patch.object(release.served, "plain", return_value=path), patch.object(release, "sha", return_value="a" * 64), \
                patch.object(release, "read", return_value=value), patch.object(release, "baseline") as base, patch.object(release, "authenticate_native") as native:
            with self.assertRaises(ValueError):
                release.load_approval(Path("D:/fixture/static.json"), "a" * 64)
            base.assert_not_called()
            native.assert_not_called()

    def test_wrong_approval_bytes_are_rejected(self):
        path = SimpleNamespace(stat=lambda: SimpleNamespace(st_size=100))
        with patch.object(release.served, "plain", return_value=path), patch.object(release, "sha", return_value="b" * 64), patch.object(release, "read") as read:
            with self.assertRaises(ValueError):
                release.load_approval(Path("D:/fixture/final.json"), "a" * 64)
            read.assert_not_called()

    def test_selected_scope_digest_and_tar_sha_must_be_embedded_exactly(self):
        value = {"source_archive_scope": build.selected.SCOPE, "full_repository_archive": False,
            "source_selection_sha256": "a" * 64, "source_archive_sha256": "b" * 64, "source_attributes_policy": attributes_fixture()}
        release.validate_selected_identity(value, dict(value))
        for key, bad in (("source_archive_scope", "FULL_ARCHIVE"), ("full_repository_archive", True),
                         ("source_selection_sha256", "c" * 64), ("source_archive_sha256", "c" * 64)):
            with self.subTest(field=key), self.assertRaises(ValueError):
                release.validate_selected_identity(value, {**value, key: bad})

    def test_missing_or_zero_selected_provenance_is_rejected(self):
        value = {"source_archive_scope": build.selected.SCOPE, "full_repository_archive": False,
            "source_selection_sha256": "0" * 64, "source_archive_sha256": "b" * 64, "source_attributes_policy": attributes_fixture()}
        with self.assertRaises(ValueError):
            release.validate_selected_identity(value, dict(value))
        with self.assertRaises(ValueError):
            release.validate_selected_identity(value, {})

    def test_actual_attribute_bytes_cannot_be_substituted_or_add_runtime_directives(self):
        value = {"source_archive_scope": build.selected.SCOPE, "full_repository_archive": False,
            "source_selection_sha256": "a" * 64, "source_archive_sha256": "b" * 64, "source_attributes_policy": attributes_fixture()}
        with patch.object(release, "sha", return_value="051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625"):
            release.validate_selected_identity(value, deepcopy(value), build.selected.BASELINE_ATTRIBUTES)
            with self.assertRaises(ValueError):
                release.validate_selected_identity(value, deepcopy(value), build.selected.BASELINE_ATTRIBUTES + b"\n/runtime/* export-ignore\n")
        for key in ("source_bytes_substituted", "runtime_paths_or_export_directives_changed"):
            bad = deepcopy(value)
            bad["source_attributes_policy"][key] = True
            with self.assertRaises(ValueError):
                release.validate_selected_identity(bad, deepcopy(bad))


class PositiveHLCommandTests(unittest.TestCase):
    def setUp(self): self.cfg = cfg_fixture()

    def test_actual_phase_count_and_positive_sequence(self):
        self.assertEqual(len(build.PHASES), 15)
        self.assertEqual(build.PHASES[:6], ("source-identity", "tree", "baseline-tree", "select", "archive", "extract"))
        self.assertEqual(build.PHASES[7:10], ("identity", "identity-scope", "import"))

    def test_archive_is_exact_selected_paths_with_explicit_umask(self):
        command = build.command(self.cfg, "archive")
        at = command.index("archive")
        self.assertIn("tar.umask=0022", command[:at])
        self.assertEqual(command[at + 3:], [self.cfg["source_commit"], *build.selected.PATHS])
        self.assertEqual(len(build.selected.PATHS), 21)
        self.assertNotIn(".", command[at + 3:])
        self.assertEqual(Path(build.selected.__file__).name, "bth_qa_selected_source_v2.py")

    def test_tree_and_baseline_tree_remain_distinct_guarded_inputs(self):
        self.assertEqual(build.command(self.cfg, "tree")[-1], self.cfg["source_commit"])
        self.assertEqual(build.command(self.cfg, "baseline-tree")[-1], build.selected.BASE_COMMIT)

    def test_inner_layout_never_declares_outer_tar_writable(self):
        for phase in build.PHASES:
            paths = build.write_paths(self.cfg, phase)
            if phase not in build.OUTER:
                self.assertNotIn(Path(self.cfg["archive"]), paths)
                self.assertTrue(all(path.is_relative_to(Path(self.cfg["workspace"])) for path in paths))

    def test_file_worker_uses_only_new_hl_entrypoint_and_outer_argument(self):
        command = build.command(self.cfg, "finalize")
        self.assertEqual(command[1], "-B")
        self.assertEqual(Path(command[2]).name, "high_limit_spatial_test_build.py")
        self.assertEqual(command[command.index("--workspace") + 1], self.cfg["outer"])
        self.assertNotIn("--environment", command)

    def test_import_and_export_bind_actual_project_and_stage(self):
        for phase in ("import", "export"):
            command = build.command(self.cfg, phase)
            self.assertEqual(command[command.index("--path") + 1], self.cfg["workspace"])
        self.assertEqual(build.command(self.cfg, "export")[-1], str(Path(self.cfg["stage"]) / "index.html"))

    def test_identity_uses_fixed_hl_seal_and_full_commit_tree(self):
        command = build.command(self.cfg, "identity")
        self.assertEqual(command[command.index("--art-package-sha256") + 1], policy.PACKAGE_SHA)
        self.assertEqual(command[command.index("--source-commit") + 1], self.cfg["source_commit"])
        self.assertEqual(command[command.index("--source-tree") + 1], self.cfg["source_tree"])

    def test_unknown_phase_has_no_fallback(self):
        with self.assertRaises(ValueError):
            build.command(self.cfg, "publish-main")


class ImportPolicyCleanupTests(unittest.TestCase):
    def run_import(self, existing=False):
        cfg = cfg_fixture()
        layout = SimpleNamespace(workspace=Path(cfg["workspace"]), evidence=Path("E:/CodexQA/BTH/runs/import-fixture/evidence"))
        flags = [True] if existing else [False, True]
        with patch.object(build, "config", return_value=cfg), patch.object(build, "plan_layout", return_value=layout), \
                patch.object(build, "validate_layout"), patch.object(build, "prepare_layout", return_value=layout), \
                patch.object(build, "previous"), patch.object(build, "approval_for", return_value={}), patch.object(build, "snapshot_pins"), \
                patch.object(build, "write"), patch.object(build, "execute", side_effect=RuntimeError("simulated launch gate rejection")) as execute, \
                patch.object(Path, "exists", side_effect=flags), patch.object(Path, "open", mock_open()) as opened, \
                patch.object(Path, "read_bytes", return_value=build.common.IMPORT_POLICY), patch.object(Path, "rename") as renamed, \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            args = ["import"]
            for key in ("workspace", "stage", "approval-json", "engine", "native-library", "editor-native-library", "template", "git", "git-dir", "node",
                        "source-commit", "source-tree", "run-prefix", "approval-sha256"):
                name = key.replace("-", "_")
                value = cfg["outer"] if name == "workspace" else cfg["approval_path"] if name == "approval_json" else cfg[name]
                args += ["--" + key, str(value)]
            result = build.main(args)
            return result, execute.call_count, opened.call_count, renamed.call_count

    def test_owned_import_policy_is_retained_in_evidence_after_launch_rejection(self):
        result, executed, opened, renamed = self.run_import()
        self.assertEqual((result, executed, opened, renamed), (1, 1, 1, 1))

    def test_preexisting_import_policy_is_not_changed_or_renamed(self):
        result, executed, opened, renamed = self.run_import(existing=True)
        self.assertEqual((result, executed, opened, renamed), (1, 0, 0, 0))


class ServedBeforeCustodyTests(unittest.TestCase):
    def setUp(self):
        cfg = cfg_fixture()
        self.args = SimpleNamespace(stage=Path(cfg["stage"]), source_commit=cfg["source_commit"], source_tree=cfg["source_tree"],
            art_package_sha256=policy.PACKAGE_SHA, approval_json=Path(cfg["approval_path"]), approval_sha256=cfg["approval_sha256"],
            build_verify_evidence=Path("E:/CodexQA/BTH/runs/HL-VERIFY/evidence"), request_timeout=30)
        self.inputs = {"python": "C:/fixture/python.exe", "python_sha256": "a" * 64, "entrypoint": "D:/fixture/verify_high_limit_spatial_test_served.py",
            "helpers": {"verify_high_limit_spatial_test_served.py": "b" * 64}}
        self.command = [self.inputs["python"], "-B", self.inputs["entrypoint"], "snapshot-before"]
        for key in ("stage", "source_commit", "source_tree", "art_package_sha256", "approval_json", "approval_sha256", "build_verify_evidence"):
            self.command += ["--" + key.replace("_", "-"), str(getattr(self.args, key))]
        self.e = Path("E:/CodexQA/BTH/runs/HL-BEFORE/evidence")
        self.storage = {"schema": "bth-qa-storage/v1", "prepared": True, "paths": {"workspace": cfg["workspace"], "evidence": str(self.e), "run_root": str(self.e.parent)}}
        self.raw_storage = json.dumps(self.storage).encode()
        fingerprint = served.common.digest(self.raw_storage)
        self.job = {**caps_job(self.command), "storage_manifest": str(self.e / "storage-manifest.json"), "storage_manifest_sha256": fingerprint}
        self.claim = {"schema": "bth.qa_launch_claim/v1", "manifest_sha256": fingerprint}
        self.before = {"storage_manifest_sha256": fingerprint, "launcher_receipt_policy": {"job_receipt": str(self.e / "job.json")}}
        self.layout = SimpleNamespace(workspace=Path(cfg["workspace"]))

    def fake_sha(self, path): return "a" * 64 if Path(path).name == "python.exe" else "b" * 64

    def authenticate(self):
        docs = {"job.json": json.dumps(self.job).encode(), "storage-manifest.json": self.raw_storage, "launch-claim.json": json.dumps(self.claim).encode()}
        with patch.object(served.common, "plain", side_effect=lambda path: Path(path)), \
                patch.object(served.common, "small_file", side_effect=lambda path: docs[Path(path).name]), \
                patch.object(served.release, "sha", side_effect=self.fake_sha):
            return served.authenticate_before_job(self.e / "before.json", self.args, self.layout, self.before, self.inputs)

    def test_exact_hl_before_command_caps_storage_claim_pass(self):
        self.authenticate()

    def test_wrong_entrypoint_or_phase_is_rejected(self):
        for index, value in ((2, "D:/fixture/unrelated.py"), (3, "verify-after")):
            old = self.command[index]
            self.command[index] = value
            with self.assertRaises(ValueError):
                self.authenticate()
            self.command[index] = old

    def test_missing_or_wrong_launch_claim_is_rejected(self):
        for value in ({}, {"schema": "wrong", "manifest_sha256": self.job["storage_manifest_sha256"]},
                      {"schema": "bth.qa_launch_claim/v1", "manifest_sha256": "c" * 64}):
            self.claim = value
            with self.assertRaises(ValueError):
                self.authenticate()

    def test_source_approval_build_flags_cannot_be_borrowed_or_duplicated(self):
        for flag in ("--source-commit", "--approval-sha256", "--build-verify-evidence"):
            index = self.command.index(flag) + 1
            old = self.command[index]
            self.command[index] = "not-the-requested-input"
            with self.assertRaises(ValueError):
                self.authenticate()
            self.command[index] = old
        self.command += ["--source-commit", self.args.source_commit]
        with self.assertRaises(ValueError):
            self.authenticate()

    def test_wrong_manifest_evidence_workspace_or_job_path_is_rejected(self):
        for key in ("workspace", "evidence", "run_root"):
            old = self.storage["paths"][key]
            self.storage["paths"][key] = "E:/borrowed"
            self.raw_storage = json.dumps(self.storage).encode()
            with self.assertRaises(ValueError):
                self.authenticate()
            self.storage["paths"][key] = old
            self.raw_storage = json.dumps(self.storage).encode()
        self.job["storage_manifest"] = "E:/borrowed/storage-manifest.json"
        with self.assertRaises(ValueError):
            self.authenticate()


if __name__ == "__main__":
    unittest.main()
