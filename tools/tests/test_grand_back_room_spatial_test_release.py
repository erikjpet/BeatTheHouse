"""GBR release contracts; synthetic and read-only archive/delivery regressions.

Run only via the parent's admitted capped QA worker. These tests create no
files/directories, start no children, and make no network/engine calls. The
retained-archive case validates real E paths/capacity without preparing a Layout.
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
import high_limit_spatial_delivered_baseline as baseline
import grand_back_room_spatial_test_release_profile as release
import grand_back_room_spatial_test_build as build
import verify_grand_back_room_spatial_test_served as served
import grand_back_room_spatial_test_profile_v2 as policy


def caps_job(command):
    return {"schema": "bth.qa_guarded_run/v1", "exit_code": 0, "active_at_release": 0, "assigned_before_execution": True,
        "error": None, "cleanup_errors": [], "timed_out": False, "log_error": None, "log_truncated": False,
        "storage_gate_before_job": {"fixture": True}, "storage_gate_before_child": {"fixture": True}, "finished_epoch": 1.0,
        "limits": {"cpu_rate": 1200, "job_memory_limit_bytes": 2 * 1024 ** 3, "kill_on_close": True, "breakaway_allowed": False},
        "command": command}


def cfg_fixture():
    outer = "E:/CodexQA/BTH/workspaces/GBR-RELEASE-FIXTURE"
    return {"schema": "bth.grand_back_room_test_build_inputs/v1", "environment": policy.ENVIRONMENT,
        "outer": outer, "workspace": outer + "/qa_source", "stage": outer + "/qa_source/.tmp/web-release-aaaaaaaa/stage",
        "archive": outer + "/source_inputs/source.tar", "run_prefix": "GBR-RELEASE-FIXTURE", "source_commit": "a" * 40,
        "source_tree": "b" * 40, "approval_path": "D:/fixture/final-gbr-go.json", "approval_sha256": "c" * 64,
        "art_package_sha256": policy.PACKAGE_SHA, "baseline_certificate_sha256": "d" * 64, "timeout": 1200,
        "engine": "D:/fixture/godot.exe", "native_library": "E:/fixture/native.wasm", "editor_native_library": "E:/fixture/editor.dll",
        "template": "D:/fixture/template.zip", "git": "C:/fixture/git.exe", "git_dir": "D:/fixture/repo.git", "node": "C:/fixture/node.exe"}


def attributes_fixture():
    return {**build.selected.attributes_bytes_policy(build.selected.BASELINE_ATTRIBUTES), "actual_extracted_bytes_verified": True}


class BaselineAuthorityTests(unittest.TestCase):
    def test_untrusted_delivery_index_stops_before_stage_validation(self):
        with patch.object(baseline, "sha", return_value="0" * 64), patch.object(baseline, "hl") as qualifier:
            with self.assertRaises(ValueError):
                baseline.load_certificate()
            qualifier.qualify_stage.assert_not_called()

    def test_missing_delivery_index_cannot_become_a_baseline(self):
        with patch.object(baseline, "sha", side_effect=FileNotFoundError("no actual delivery index")), patch.object(baseline, "hl") as qualifier:
            with self.assertRaises(FileNotFoundError):
                baseline.load_certificate()
            qualifier.qualify_stage.assert_not_called()

    def test_mismatching_reference_hash_or_path_is_rejected(self):
        # The exported assert_ref is a frozen ancestor's pure function. Exercise
        # its real read-only delivered-index path rather than patch old globals.
        target=baseline.DELIVERY
        for record in ({"path": "E:/wrong.json", "sha256": baseline.DELIVERY_SHA},
                       {"path": str(target), "sha256": "0" * 64}):
            with self.assertRaises(ValueError):
                baseline.assert_ref(record,target)

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
        self.e = baseline.RUNS / "BASELINE-FIXTURE-publish" / "evidence"
        self.entry = "publish_environment_art_test.py"
        command = ["C:/fixture/python.exe", "-B", "D:/fixture/" + self.entry]
        self.expected_command=command[:]
        self.job = {**caps_job(command[:]), "storage_manifest": str(self.e / "storage-manifest.json"), "storage_manifest_sha256": "b" * 64}
        self.docs = {"job.json": self.job, "storage-manifest.json": {"schema": "bth-qa-storage/v1", "prepared": True,
            "expected_write_bytes":4*1024**3,"reserve_bytes":20*1024**3,
            "paths": {"evidence": str(self.e), "workspace": str(baseline.WORKSPACE),"run_root":str(self.e.parent)}},
            "launch-claim.json": {"schema": "bth.qa_launch_claim/v1", "manifest_sha256": "b" * 64}}

    def authenticate(self):
        def fake_sha(path):
            name = Path(path).name
            if name == "job.json": return "a" * 64
            if name == "storage-manifest.json": return "b" * 64
            if name == "python.exe": return "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
            return baseline.HELPERS.get(name, "0" * 64)
        with patch.object(baseline, "served",SimpleNamespace(plain=lambda path:Path(path))), \
                patch.object(baseline,"PREFIX","BASELINE-FIXTURE"),patch.object(baseline,"COMMANDS",{"publish":self.expected_command}), \
                patch.object(baseline, "sha", side_effect=fake_sha), \
                patch.object(baseline, "read", side_effect=lambda path: self.docs[Path(path).name]):
            return baseline.authenticate_job(self.e, "a" * 64, self.entry)

    def test_actual_caps_command_storage_and_claim_shape_pass(self):
        self.assertEqual(self.authenticate()["exit_code"], 0)

    def test_nonzero_active_timeout_truncation_and_missing_assignment_fail(self):
        for key, value in (("exit_code",1),("active_at_release", 1), ("timed_out", True), ("log_truncated", True),
                           ("assigned_before_execution", False),("error","failure"),("cleanup_errors",["failure"])):
            old = self.job[key]
            self.job[key] = value
            with self.subTest(field=key), self.assertRaises(ValueError):
                self.authenticate()
            self.job[key] = old

    def test_memory_or_kill_on_close_policy_cannot_be_relaxed(self):
        for key, value in (("cpu_rate",2400),("job_memory_limit_bytes", 3 * 1024 ** 3), ("kill_on_close", False), ("breakaway_allowed", True)):
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
        for key in ("workspace", "evidence","run_root"):
            old = self.docs["storage-manifest.json"]["paths"][key]
            self.docs["storage-manifest.json"]["paths"][key] = "E:/another-campaign"
            with self.assertRaises(ValueError):
                self.authenticate()
            self.docs["storage-manifest.json"]["paths"][key] = old
        self.docs["launch-claim.json"]["manifest_sha256"] = "c" * 64
        with self.assertRaises(ValueError):
            self.authenticate()

    def test_storage_budget_and_reserve_cannot_be_omitted_or_lowered(self):
        manifest=self.docs["storage-manifest.json"]
        for key in ("expected_write_bytes","reserve_bytes"):
            old=manifest[key]
            for value in (None,0,old-1):
                manifest[key]=value
                with self.subTest(field=key,value=value),self.assertRaises(ValueError):
                    self.authenticate()
            manifest[key]=old

    def test_wrong_baseline_phase_has_no_command_fallback(self):
        self.e=baseline.RUNS/"BASELINE-FIXTURE-export"/"evidence"
        with self.assertRaises(ValueError):
            self.authenticate()


class ActualDeliveredObservationWindowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import hashlib
        entries=((baseline.RUNS/(baseline.PREFIX+"-before")/"evidence/before.json",
                  "e3a8ffa442dc59fe8c773eabe74e4ad2516716ba0911dbb6fb5667562a82132f"),
                 (baseline.RUNS/(baseline.PREFIX+"-served")/"evidence/served.json",
                  "fab304ee748827a6bbec53b989284bb9df586fadbaa58e054f43b01d98610ce8"),
                 (baseline.DELIVERY,"b4650bd3538419c0242b58429d1eb84da0a75abc239ff03f659ed8b1d1552261"))
        values=[]
        for path,expected in entries:
            data=path.read_bytes()
            if hashlib.sha256(data).hexdigest()!=expected:
                raise AssertionError("Actual immutable delivery-window fixture changed: "+str(path))
            values.append(json.loads(data))
        cls.before,cls.report,cls.delivery=values

    def test_actual_nested_lane_window_passes_without_certificate_or_job_launch(self):
        self.assertNotEqual(self.before["started_utc"],self.before["state"]["started_utc"])
        self.assertNotEqual(self.report["finished_utc"],self.report["state"]["finished_utc"])
        baseline.validate_historical_window(self.before,self.report,self.delivery)

    def test_worker_timestamps_cannot_replace_actual_lane_window(self):
        delivery=deepcopy(self.delivery)
        delivery["served_verification"]["observation_window_start"]=self.before["started_utc"]
        delivery["served_verification"]["observation_window_end"]=self.report["finished_utc"]
        with self.assertRaises(ValueError):
            baseline.validate_historical_window(self.before,self.report,delivery)

    def test_either_changed_nested_lane_timestamp_is_rejected(self):
        for owner,key in (("before","started_utc"),("report","finished_utc")):
            before,report=deepcopy(self.before),deepcopy(self.report)
            (before if owner=="before" else report)["state"][key]="different observation window"
            with self.subTest(boundary=key),self.assertRaises(ValueError):
                baseline.validate_historical_window(before,report,self.delivery)

    def test_changed_next_state_or_unmanaged_test_launcher_is_rejected(self):
        values=[]
        changed=deepcopy(self.report);changed["state"]["next"]={"unexpected":"different NEXT"};values.append(changed)
        changed=deepcopy(self.report);changed["state"]["test"]["managed_launcher"]=False;values.append(changed)
        changed=deepcopy(self.report);changed["state"]["test"]["source_commit"]="0"*40;values.append(changed)
        changed=deepcopy(self.report);changed["next_preservation"]["unchanged"]=False;values.append(changed)
        changed=deepcopy(self.report);changed["next_preservation"]["source_commit"]="0"*40;values.append(changed)
        for report in values:
            with self.assertRaises(ValueError):
                baseline.validate_historical_window(self.before,report,self.delivery)


class ReleaseAdmissionTests(unittest.TestCase):
    def test_static_native_trial_go_stops_before_baseline_or_native_auth(self):
        path = SimpleNamespace(stat=lambda: SimpleNamespace(st_size=100))
        value = {"schema": release.APPROVAL_SCHEMA, "environment_id": policy.ENVIRONMENT, "verdict": "STATIC_GO_FOR_NATIVE_TRIAL"}
        with patch.object(release,"served",SimpleNamespace(plain=lambda value:path)), patch.object(release, "sha", return_value="a" * 64), \
                patch.object(release, "read", return_value=value), patch.object(release, "baseline") as base, patch.object(release, "authenticate_native") as native:
            with self.assertRaises(ValueError):
                release.load_approval(Path("D:/fixture/static.json"), "a" * 64)
            base.assert_not_called()
            native.assert_not_called()

    def test_wrong_approval_bytes_are_rejected(self):
        path = SimpleNamespace(stat=lambda: SimpleNamespace(st_size=100))
        with patch.object(release,"served",SimpleNamespace(plain=lambda value:path)), patch.object(release, "sha", return_value="b" * 64), patch.object(release, "read") as read:
            with self.assertRaises(ValueError):
                release.load_approval(Path("D:/fixture/final.json"), "a" * 64)
            read.assert_not_called()

    def test_final_schema_without_helper_references_stops_before_baseline(self):
        path=SimpleNamespace(stat=lambda:SimpleNamespace(st_size=100))
        value={"schema":release.APPROVAL_SCHEMA,"environment_id":policy.ENVIRONMENT,"verdict":"GO_FOR_TEST_BUILD"}
        with patch.object(release,"served",SimpleNamespace(plain=lambda value:path)),patch.object(release,"sha",return_value="a"*64), \
                patch.object(release,"read",return_value=value),patch.object(release,"baseline") as base,patch.object(release,"authenticate_native") as native:
            with self.assertRaises(ValueError):
                release.load_approval(Path("D:/fixture/final-gbr.json"),"a"*64)
            base.assert_not_called()
            native.assert_not_called()

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


class PositiveGBRCommandTests(unittest.TestCase):
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

    def test_file_worker_uses_only_new_gbr_entrypoint_and_outer_argument(self):
        command = build.command(self.cfg, "finalize")
        self.assertEqual(command[1], "-B")
        self.assertEqual(Path(command[2]).name, "grand_back_room_spatial_test_build.py")
        self.assertEqual(command[command.index("--workspace") + 1], self.cfg["outer"])
        self.assertNotIn("--environment", command)

    def test_import_and_export_bind_actual_project_and_stage(self):
        for phase in ("import", "export"):
            command = build.command(self.cfg, phase)
            self.assertEqual(command[command.index("--path") + 1], self.cfg["workspace"])
        self.assertEqual(build.command(self.cfg, "export")[-1], str(Path(self.cfg["stage"]) / "index.html"))

    def test_identity_uses_fixed_gbr_seal_and_full_commit_tree(self):
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
            build_verify_evidence=Path("E:/CodexQA/BTH/runs/GBR-VERIFY/evidence"), request_timeout=30)
        self.inputs = {"python": "C:/fixture/python.exe", "python_sha256": "a" * 64, "entrypoint": "D:/fixture/verify_grand_back_room_spatial_test_served.py",
            "helpers": {"verify_grand_back_room_spatial_test_served.py": "b" * 64}}
        self.command = [self.inputs["python"], "-B", self.inputs["entrypoint"], "snapshot-before"]
        for key in ("stage", "source_commit", "source_tree", "art_package_sha256", "approval_json", "approval_sha256", "build_verify_evidence"):
            self.command += ["--" + key.replace("_", "-"), str(getattr(self.args, key))]
        self.e = Path("E:/CodexQA/BTH/runs/GBR-BEFORE/evidence")
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
        primitive=SimpleNamespace(plain=lambda path:Path(path),small_file=lambda path:docs[Path(path).name],
                                  parse_json=served.common.parse_json,digest=served.common.digest)
        with patch.object(served,"common",primitive), \
                patch.object(served.release, "sha", side_effect=self.fake_sha):
            return served.authenticate_before_job(self.e / "before.json", self.args, self.layout, self.before, self.inputs)

    def test_exact_gbr_before_command_caps_storage_claim_pass(self):
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




class GBROutputBoundaryTests(unittest.TestCase):
    def test_archive_is_the_only_phase_declaring_tar_writable(self):
        cfg = cfg_fixture()
        for phase in build.PHASES:
            with self.subTest(phase=phase):
                self.assertEqual(Path(cfg["archive"]) in build.write_paths(cfg, phase), phase == "archive")
        self.assertEqual(build.write_paths(cfg, "extract"), (Path(cfg["workspace"]),))
        for phase in ("source-identity", "tree", "baseline-tree", "select"):
            self.assertEqual(build.write_paths(cfg, phase), ())
        with self.assertRaises(ValueError):
            build.write_paths(cfg, "not-a-phase")

    def test_actual_retained_tar_v1_rejects_v2_extract_admits_without_mutation(self):
        import hashlib
        import uuid
        import bth_qa_storage as storage
        import high_limit_spatial_test_build as frozen_v1
        outer = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLBUILD-20261116")
        archive = outer / "source_inputs/source.tar"
        self.assertTrue(archive.is_file(), "Retained actual v1 archive is required; never create a fixture copy")
        def observe():
            h = hashlib.sha256()
            with archive.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    h.update(chunk)
            st = archive.stat()
            return h.hexdigest(), st.st_size, st.st_mtime_ns, st.st_ino
        before = observe()
        self.assertEqual(before[0], "312495500ecf1c9827ff5108b9b1150acd7e42e895473898754ad254bdcaea87")
        self.assertEqual(before[1], 228444160)
        cfg = {**cfg_fixture(), "outer": str(outer), "workspace": str(outer / "qa_source"),
            "archive": str(archive), "stage": str(outer / "qa_source/.tmp/web-release-f54d7b50/stage")}
        run_id = "BTH-HL-V2-READONLY-" + uuid.uuid4().hex[:20]
        layout = storage.plan_layout(Path("E:/CodexQA/BTH"), outer, run_id)
        self.assertFalse(layout.prepared)
        self.assertEqual(layout.expected_write_bytes, 4 * 1024 ** 3)
        self.assertEqual(layout.reserve_bytes, 20 * 1024 ** 3)
        self.assertFalse(layout.run_root.exists())
        with self.assertRaises(storage.StorageGuardError) as caught:
            storage.validate_layout(layout, extra_write_paths=frozen_v1.write_paths(cfg, "extract"))
        self.assertEqual(caught.exception.code, "not_directory")
        self.assertTrue(build.selected.same_path(caught.exception.target, archive))
        observations = storage.validate_layout(layout, extra_write_paths=build.write_paths(cfg, "extract"))
        self.assertTrue(observations)
        self.assertEqual(before, observe())
        self.assertFalse(layout.run_root.exists())

    def test_gbr_phase_and_inputs_versions_are_explicit(self):
        self.assertEqual(build.SCHEMA, "bth.grand_back_room_test_build_phase/v1")
        self.assertEqual(cfg_fixture()["schema"], "bth.grand_back_room_test_build_inputs/v1")
        self.assertEqual(release.SERVED_SCHEMA, "bth.grand_back_room_spatial_test_served/v1")
        self.assertEqual(release.APPROVAL_SCHEMA,"bth.grand_back_room_spatial_test_approval/v1")


class GBRAuthorityReferencesTests(unittest.TestCase):
    def references(self):
        return {key: {"path": str(release.NATIVE_TOOLS / name), "sha256": release.sha(release.NATIVE_TOOLS / name)}
            for key, name in (("profile", "grand_back_room_spatial_test_release_profile.py"),
                ("build_entrypoint", "grand_back_room_spatial_test_build.py"),
                ("served_entrypoint", "verify_grand_back_room_spatial_test_served.py"),
                ("baseline_loader","high_limit_spatial_delivered_baseline.py"),
                ("pure_policy","grand_back_room_spatial_test_profile_v2.py"))}

    def test_actual_gbr_approval_helper_references_match(self):
        refs = self.references()
        self.assertEqual(release.authenticate_release_policy_refs({"release_policy": refs}), refs)

    def test_hl_approval_references_cannot_authorize_gbr(self):
        refs = self.references()
        for key in refs:
            bad = deepcopy(refs)
            bad[key]["path"] = str(release.NATIVE_TOOLS / {
                "profile":"high_limit_spatial_test_release_profile_v2.py",
                "build_entrypoint":"high_limit_spatial_test_build_v2.py",
                "served_entrypoint":"verify_high_limit_spatial_test_served_v2.py",
                "baseline_loader":"grand_spatial_delivered_baseline.py",
                "pure_policy":"grand_back_room_spatial_test_profile.py"}[key])
            with self.subTest(reference=key), self.assertRaises(ValueError):
                release.authenticate_release_policy_refs({"release_policy": bad})

    def test_missing_or_wrong_hash_gbr_reference_is_rejected(self):
        for value in ({}, {"release_policy": {}}, {"release_policy": {**self.references(), "profile": {
                "path": str(release.NATIVE_TOOLS / "grand_back_room_spatial_test_release_profile.py"), "sha256": "0" * 64}}}):
            with self.assertRaises((ValueError, KeyError)):
                release.authenticate_release_policy_refs(value)

    def test_each_of_five_approval_references_is_mandatory(self):
        refs=self.references()
        self.assertEqual(set(refs),{"profile","build_entrypoint","served_entrypoint","baseline_loader","pure_policy"})
        for key in refs:
            bad=deepcopy(refs);bad.pop(key)
            with self.subTest(reference=key),self.assertRaises(ValueError):
                release.authenticate_release_policy_refs({"release_policy":bad})

    def test_hl_before_entrypoint_cannot_authenticate_gbr(self):
        fixture = ServedBeforeCustodyTests()
        fixture.setUp()
        fixture.command[2] = "D:/fixture/verify_high_limit_spatial_test_served_v2.py"
        with self.assertRaises(ValueError):
            fixture.authenticate()

    def test_closed_build_verifier_rejects_hl_input_schema_before_module_loading(self):
        e = release.delivered.RUNS / "GBR-VERIFY-FIXTURE/evidence"
        cfg = {**cfg_fixture(), "schema": "bth.high_limit_test_build_inputs/v1"}
        loader=SimpleNamespace(util=Mock())
        with patch.object(release,"served",SimpleNamespace(plain=lambda p:Path(p))), patch.object(release, "read", return_value=cfg), \
                patch.object(release,"importlib",loader):
            with self.assertRaises(ValueError):
                release.authenticate_build_verify(e, {})
            loader.util.spec_from_file_location.assert_not_called()


class NativePhaseAuthorityTests(unittest.TestCase):
    def test_all_thirteen_native_phase_names_remain_required(self):
        self.assertEqual(tuple(release.NATIVE_PHASES),("source-identity","tree","baseline-tree","select","archive","prepare",
            "install","import","identity","contexts","motion","liveness","capture"))

    def test_missing_or_extra_native_phase_reference_stops_before_loading(self):
        good={name:{} for name in release.NATIVE_PHASES}
        values=[None,{}, {**good,"foreign":{}}]
        for name in good:
            bad=deepcopy(good);bad.pop(name);values.append(bad)
        loader=SimpleNamespace(util=Mock())
        with patch.object(release,"importlib",loader):
            for value in values:
                with self.subTest(value=value),self.assertRaises(ValueError):
                    release.authenticate_native({"native_phase_receipts":value})
            loader.util.spec_from_file_location.assert_not_called()

    def test_wrong_declared_native_runner_or_policy_stops_before_loading(self):
        good={"native_phase_receipts":{name:{} for name in release.NATIVE_PHASES},
              "native_adapter_sha256":policy.NATIVE_ADAPTER_SHA,"native_policy_sha256":policy.NATIVE_POLICY_SHA}
        loader=SimpleNamespace(util=Mock())
        with patch.object(release,"importlib",loader):
            for key in ("native_adapter_sha256","native_policy_sha256"):
                with self.subTest(field=key),self.assertRaises(ValueError):
                    release.authenticate_native({**good,key:"0"*64})
            loader.util.spec_from_file_location.assert_not_called()


class GBRClosedWorkerReceiptTests(unittest.TestCase):
    def check(self, use_v1_command=False):
        cfg, phase = cfg_fixture(), "verify"
        e = build.evidence(cfg, phase)
        command = build.command(cfg, phase)
        if use_v1_command:
            command[2] = "D:/fixture/high_limit_spatial_test_build_v2.py"
        docs = {"build-inputs.json": cfg,
            "storage-manifest.json": {"prepared": True, "paths": {"workspace": cfg["workspace"], "evidence": str(e)}},
            "launch-claim.json": {"manifest_sha256": "d" * 64},
            "job.json": {**caps_job(command), "storage_manifest": str(e / "storage-manifest.json"), "storage_manifest_sha256": "d" * 64},
            "phase-result.json": {"schema": build.SCHEMA, "phase": phase, "status": "PASS", "config_sha256": build.selected.digest(cfg),
                "job_sha256": "a" * 64, "log_sha256": "b" * 64, "artifact_sha256": {"worker-result.json": "c" * 64}}}
        hashes = {"job.json": "a" * 64, "worker.log": "b" * 64, "worker-result.json": "c" * 64, "storage-manifest.json": "d" * 64}
        with patch.object(build, "read", side_effect=lambda p: docs[Path(p).name]), \
                patch.object(build, "sha", side_effect=lambda p: hashes[Path(p).name]):
            return build.previous(cfg, phase)

    def test_exact_closed_gbr_worker_command_passes(self):
        self.assertEqual(self.check()["phase"], "verify")

    def test_closed_hl_worker_command_cannot_authenticate_gbr(self):
        with self.assertRaises(ValueError):
            self.check(use_v1_command=True)


if __name__ == "__main__":
    unittest.main()
