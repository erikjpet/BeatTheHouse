"""Pure in-memory CLI and closed-receipt regressions; no QA/filesystem writes.

Run this file only in the parent's guarded test Job. No engine, process, temp
directory, existing campaign or profile is created by these tests.
"""
import sys
sys.dont_write_bytecode = True

from contextlib import ExitStack
from copy import deepcopy
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import private_crew_spatial_native_trial as runner
import private_crew_spatial_native_profile as policy


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


class Receipts:
    """Authentic schema shape, with bytes/hash custody exercised in memory."""
    def __init__(self, phase="source-identity", capture_seconds=20.0):
        root = Path("E:/CodexQA/BTH")
        workspace = root / "workspaces/BTH-ENV-SPATIAL-PRIVATETRIAL-20261116"
        self.cfg = {"schema": "bth.private_crew_spatial_inputs/v1", "qa_root": str(root), "workspace": str(workspace),
            "project": str(workspace / "qa_source"), "run_prefix": "private-closed-receipt-fixture",
            "source_commit": "a" * 40, "source_tree": "b" * 40, "source_scope": runner.selected.SCOPE,
            "capture_seconds": capture_seconds, "timeout": 1200, "position": "-32000,-32000",
            "engine": "D:/fixture/godot.exe", "git": "C:/fixture/git.exe", "git_dir": "D:/fixture/repository.git",
            "baseline_stage": "E:/fixture/qualified-stage", "native_extension_descriptor": "E:/fixture/native.gdextension",
            "editor_native_library": "E:/fixture/native.dll", "candidate_root": "E:/fixture/candidate",
            "candidate_manifest": "E:/fixture/assembly.json", "review": "D:/fixture/review.json",
            "baseline_auxiliary_files": {".gdignore": {"path": str(workspace / "source_baseline/.gdignore"), "bytes": 75,
                "sha256": "c" * 64, "modified_ns": 123456789, "file_id": 12345}}}
        self.cfg["archive"] = str(runner.guard.evidence_for(self.cfg, "archive") / "source.tar")
        self.files, self.phase = {}, phase
        self.evidence = runner.guard.evidence_for(self.cfg, phase)
        self.command = runner.command(self.cfg, phase, SimpleNamespace(evidence=self.evidence))
        self.manifest = {"schema": "bth-qa-storage/v1", "prepared": True, "paths": {
            "workspace": self.cfg["workspace"] if phase in runner.OUTER_PHASES else self.cfg["project"], "evidence": str(self.evidence)}}
        self.save("storage-manifest.json", self.manifest)
        manifest_sha = self.sha(self.evidence / "storage-manifest.json")
        self.save("launch-claim.json", {"schema": "bth.qa_launch_claim/v1", "manifest_sha256": manifest_sha})
        self.job = {"schema": "bth.qa_guarded_run/v1", "exit_code": 0, "active_at_release": 0,
            "assigned_before_execution": True, "error": None, "cleanup_errors": [], "timed_out": False,
            "log_error": None, "log_truncated": False, "finished_epoch": 1234.5,
            "storage_gate_before_job": {"admitted": True}, "storage_gate_before_child": {"admitted": True},
            "storage_manifest": str(self.evidence / "storage-manifest.json"), "storage_manifest_sha256": manifest_sha,
            "command": self.command, "limits": {"cpu_rate": 1200, "job_memory_limit_bytes": 2 * 1024 ** 3,
                "kill_on_close": True, "breakaway_allowed": False}}
        self.save("job.json", self.job)
        self.files[self.key(self.evidence / "worker.log")] = b"Authentic fixture worker: PASS\n"
        self.inputs = {"source_config": deepcopy(self.cfg), "source_config_sha256": runner.guard.fingerprint(self.cfg), "command": self.command}
        self.save("trial-inputs.json", self.inputs)
        names = {"worker-result.json"} if phase in runner.FILE_PHASES else set()
        if phase == "select":
            names |= {"selection.json", "closure.json"}
        if phase in runner.REPORT_NAMES:
            names.add(runner.REPORT_NAMES[phase])
        for name in names:
            self.save(name, {"fixture": name})
        self.result = {"schema": runner.PHASE_SCHEMA, "phase": phase, "status": "PASS",
            "source_config_sha256": runner.guard.fingerprint(self.cfg), "source_commit": self.cfg["source_commit"],
            "source_tree": self.cfg["source_tree"], "source_scope": self.cfg["source_scope"],
            "job_receipt": str(self.evidence / "job.json"), "job_sha256": self.sha(self.evidence / "job.json"),
            "log_sha256": self.sha(self.evidence / "worker.log"),
            "artifact_sha256": {name: self.sha(self.evidence / name) for name in names}, "artifacts": {},
            "baseline_auxiliary_files_before": deepcopy(self.cfg["baseline_auxiliary_files"]),
            "baseline_auxiliary_files_after": deepcopy(self.cfg["baseline_auxiliary_files"]), "baseline_auxiliary_files_unchanged": True}
        self.save("phase-result.json", self.result)

    @staticmethod
    def key(path):
        return str(Path(path))

    def save(self, name, value):
        self.files[self.key(self.evidence / name)] = encoded(value)

    def read_bytes(self, path):
        try:
            return self.files[self.key(path)]
        except KeyError:
            raise FileNotFoundError(str(path)) from None

    def read_json(self, path):
        return json.loads(self.read_bytes(path))

    def sha(self, path):
        return hashlib.sha256(self.read_bytes(path)).hexdigest()

    def reseal_job(self):
        self.save("job.json", self.job)
        self.result["job_sha256"] = self.sha(self.evidence / "job.json")
        self.save("phase-result.json", self.result)

    def mocked_io(self):
        mocked = ExitStack()
        mocked.enter_context(patch.object(runner.guard, "read_json", side_effect=self.read_json))
        mocked.enter_context(patch.object(runner.guard, "sha", side_effect=self.sha))
        mocked.enter_context(patch.object(Path, "read_text", autospec=True,
            side_effect=lambda path, *args, **kwargs: self.read_bytes(path).decode("utf-8")))
        return mocked

    def validate(self, cfg=None):
        with self.mocked_io():
            return runner.previous(self.cfg if cfg is None else cfg, self.phase)


class ClosedReceiptChecks(unittest.TestCase):
    def test_real_common_prior_then_full_private_chain_accepts_each_phase(self):
        for phase in runner.PHASES:
            with self.subTest(phase=phase):
                fixture = Receipts(phase)
                self.assertEqual(fixture.validate()["phase"], phase)

    def reject_result(self, field, value, phase="source-identity"):
        fixture = Receipts(phase)
        fixture.result[field] = value
        fixture.save("phase-result.json", fixture.result)
        with self.assertRaises((ValueError, FileNotFoundError)):
            fixture.validate()

    def test_grand_schema_rejected(self):
        self.reject_result("schema", "bth.grand_spatial_trial_phase/v1")

    def test_wrong_phase_rejected(self):
        self.reject_result("phase", "tree")

    def test_nonpass_rejected(self):
        self.reject_result("status", "FAIL")

    def test_sibling_config_rejected(self):
        fixture = Receipts()
        cfg = deepcopy(fixture.cfg)
        cfg["position"] = "0,0"
        with self.assertRaises(ValueError):
            fixture.validate(cfg)

    def test_wrong_source_commit_rejected(self):
        self.reject_result("source_commit", "d" * 40)

    def test_wrong_source_tree_rejected(self):
        self.reject_result("source_tree", "e" * 40)

    def test_wrong_source_scope_rejected(self):
        self.reject_result("source_scope", "FULL_REPOSITORY_ARCHIVE")

    def test_wrong_config_hash_rejected(self):
        self.reject_result("source_config_sha256", "0" * 64)

    def test_wrong_job_hash_rejected(self):
        self.reject_result("job_sha256", "0" * 64)

    def test_wrong_job_path_rejected(self):
        self.reject_result("job_receipt", "E:/another-run/job.json")

    def test_missing_claim_rejected(self):
        fixture = Receipts()
        del fixture.files[fixture.key(fixture.evidence / "launch-claim.json")]
        with self.assertRaises(FileNotFoundError):
            fixture.validate()

    def test_wrong_claim_hash_rejected(self):
        fixture = Receipts()
        fixture.save("launch-claim.json", {"manifest_sha256": "0" * 64})
        with self.assertRaises(ValueError):
            fixture.validate()

    def test_bad_closed_job_fields_rejected_even_with_matching_job_hash(self):
        changes = [("exit_code", 1), ("active_at_release", 1), ("assigned_before_execution", False),
            ("error", "worker error"), ("cleanup_errors", ["cleanup failed"]), ("timed_out", True),
            ("log_truncated", True), ("log_error", "log failure"), ("storage_gate_before_job", {}), ("storage_gate_before_child", {})]
        for field, value in changes:
            with self.subTest(field=field):
                fixture = Receipts()
                fixture.job[field] = value
                fixture.reseal_job()
                with self.assertRaises(ValueError):
                    fixture.validate()

    def test_bad_caps_rejected_even_with_matching_job_hash(self):
        for field, value in (("cpu_rate", 1500), ("job_memory_limit_bytes", 3 * 1024 ** 3), ("kill_on_close", False), ("breakaway_allowed", True)):
            with self.subTest(field=field):
                fixture = Receipts()
                fixture.job["limits"][field] = value
                fixture.reseal_job()
                with self.assertRaises(ValueError):
                    fixture.validate()

    def test_error_log_rejected_even_with_matching_log_hash_and_exit_zero(self):
        for line in (b"ERROR: invalid color\n", b"SCRIPT ERROR: observer failed\n"):
            with self.subTest(line=line):
                fixture = Receipts()
                fixture.files[fixture.key(fixture.evidence / "worker.log")] = line
                fixture.result["log_sha256"] = fixture.sha(fixture.evidence / "worker.log")
                fixture.save("phase-result.json", fixture.result)
                with self.assertRaises(ValueError):
                    fixture.validate()

    def test_changed_and_missing_artifacts_rejected(self):
        for mode in ("changed", "missing", "undeclared"):
            with self.subTest(mode=mode):
                fixture = Receipts("select")
                path = fixture.key(fixture.evidence / "selection.json")
                if mode == "changed":
                    fixture.files[path] += b" "
                elif mode == "missing":
                    del fixture.files[path]
                else:
                    del fixture.result["artifact_sha256"]["selection.json"]
                    fixture.save("phase-result.json", fixture.result)
                with self.assertRaises((ValueError, FileNotFoundError)):
                    fixture.validate()

    def test_auxiliary_before_after_and_flag_rejected(self):
        for field in ("baseline_auxiliary_files_before", "baseline_auxiliary_files_after", "baseline_auxiliary_files_unchanged"):
            with self.subTest(field=field):
                self.reject_result(field, False if field.endswith("unchanged") else {})

    def test_command_mismatch_rejected_with_matching_job_hash(self):
        fixture = Receipts()
        fixture.job["command"] = ["C:/fixture/unexpected.exe"]
        fixture.reseal_job()
        with self.assertRaises(ValueError):
            fixture.validate()

    def test_manifest_workspace_mismatch_rejected(self):
        fixture = Receipts()
        fixture.manifest["paths"]["workspace"] = "E:/wrong-workspace"
        fixture.save("storage-manifest.json", fixture.manifest)
        digest = fixture.sha(fixture.evidence / "storage-manifest.json")
        fixture.job["storage_manifest_sha256"] = digest
        fixture.save("launch-claim.json", {"manifest_sha256": digest})
        fixture.reseal_job()
        with self.assertRaises(ValueError):
            fixture.validate()

    def test_common_prepared_api_accepts_private_receipts_and_keeps_uid_custody(self):
        fixture, install = Receipts("prepare"), Receipts("install")
        project = Path(fixture.cfg["project"])
        source, uid = project / "scripts/fixture.gd", project / "scripts/fixture.gd.uid"
        fixture.files[fixture.key(source)], fixture.files[fixture.key(uid)] = b"baseline code", b"canonical uid"
        prepared = {"files": {"scripts/fixture.gd": fixture.sha(source), "scripts/fixture.gd.uid": fixture.sha(uid)}}
        prepared_path = project / "qa_reference/prepared-source.json"
        fixture.files[fixture.key(prepared_path)] = encoded(prepared)
        fixture.result["artifacts"] = {"prepared_identity_sha256": fixture.sha(prepared_path)}
        fixture.save("phase-result.json", fixture.result)
        fixture.files[fixture.key(source)] = b"approved QA candidate code fixture"
        installed = {"files": {"scripts/fixture.gd": fixture.sha(source)}}
        installed_path = project / "qa_reference/candidate-install.json"
        fixture.files[fixture.key(installed_path)] = encoded(installed)
        install.result["artifacts"] = {"candidate_install_sha256": fixture.sha(installed_path), "record": installed}
        install.save("phase-result.json", install.result)
        fixture.files.update(install.files)
        with fixture.mocked_io(), patch.object(Path, "exists", autospec=True,
                side_effect=lambda path: fixture.key(path) in fixture.files):
            observed_prepared, observed_installed = runner.guard.verify_prepared(fixture.cfg)
            self.assertEqual(observed_prepared, prepared)
            self.assertEqual(observed_installed, installed)
            fixture.files[fixture.key(uid)] = b"unexpected uid rebind"
            with self.assertRaisesRegex(ValueError, "canonical UID custody changed"):
                runner.guard.verify_prepared(fixture.cfg)


class NumericCliChecks(unittest.TestCase):
    @staticmethod
    def common():
        return ["plan", "--workspace=E:/fixture/workspace", "--engine=D:/fixture/godot.exe", "--git=C:/fixture/git.exe",
            "--git-dir=D:/fixture/repository.git", "--candidate-root=E:/fixture/candidate", "--candidate-manifest=E:/fixture/assembly.json",
            "--review=D:/fixture/review.json", "--source-commit=" + "a" * 40, "--source-tree=" + "b" * 40, "--run-prefix=cli-fixture"]

    def test_default_and_explicit_numeric_values_have_identical_types(self):
        default = runner.parse_args(self.common())
        explicit = runner.parse_args(self.common() + ["--capture-seconds=20", "--timeout=1200"])
        self.assertIs(type(default.capture_seconds), float)
        self.assertIs(type(explicit.capture_seconds), float)
        self.assertIs(type(default.timeout), int)
        self.assertEqual(vars(default), vars(explicit))

    def test_actual_worker_argument_roundtrip_keeps_entire_config_fingerprint(self):
        args = runner.parse_args(self.common())
        fixture = Receipts("select", args.capture_seconds)
        command = runner.command(fixture.cfg, "select", SimpleNamespace(evidence=fixture.evidence))
        worker = runner.parse_args(command[3:])
        worker_cfg = deepcopy(fixture.cfg)
        worker_cfg.update(capture_seconds=worker.capture_seconds, timeout=worker.timeout, position=worker.position)
        self.assertEqual(runner.guard.fingerprint(fixture.cfg), runner.guard.fingerprint(worker_cfg))
        self.assertEqual(fixture.validate(worker_cfg)["status"], "PASS")

    def test_old_integer_default_reproduces_real_prior_fingerprint_failure(self):
        fixture = Receipts(capture_seconds=20)
        worker_cfg = deepcopy(fixture.cfg)
        worker_cfg["capture_seconds"] = 20.0
        self.assertNotEqual(runner.guard.fingerprint(fixture.cfg), runner.guard.fingerprint(worker_cfg))
        with self.assertRaisesRegex(ValueError, "Prior exact guarded phase is not qualified"):
            fixture.validate(worker_cfg)



class PrivateSourceContractChecks(unittest.TestCase):
    BASE = Path("E:/CodexQA/BTH/runs/BTH-ENVART-PRIVATETRIAL-20261115-r4-base-01/evidence")
    LIFE = Path("E:/CodexQA/BTH/runs/BTH-ENVART-PRIVATETRIAL-20261115-r4-lifecycle-01/evidence")
    MOTION = Path("E:/CodexQA/BTH/runs/BTH-ENVART-PRIVATETRIAL-20261115-r4-motion-01/evidence/motion")

    def test_real_private_Base_counts_do_not_admit_Hidden_or_Grand(self):
        report=json.loads((self.BASE/"private_preart_metadata.json").read_bytes())
        result=policy.report_contract("contexts",report,source_files=7157)
        self.assertEqual(result["initial_contexts"],1)
        self.assertEqual(result["initial_objects"],10)
        self.assertEqual(result["typed_host_pairs"],6)
        self.assertFalse(result["work_outcome_coverage"])
        changed=deepcopy(report);changed["views"]["invented_private_scenario"]={}
        with self.assertRaises(ValueError):
            policy.report_contract("contexts",changed,source_files=7157)
        with self.assertRaises(ValueError):
            policy.report_contract("contexts",report,source_files=7156)

    def test_real_private_7entry_15check_motion_is_required(self):
        report=json.loads((self.MOTION/"private_animation_probe.json").read_bytes())
        self.assertEqual(policy.report_contract("motion",report)["native_entries"],7)
        for count in (63,66):
            bad=deepcopy(report);bad["checks"]=count
            with self.subTest(count=count),self.assertRaises(ValueError):
                policy.report_contract("motion",bad)
        bad=deepcopy(report);bad["entries"][0]["reduce_motion_stable"]=False
        with self.assertRaises(ValueError):
            policy.report_contract("motion",bad)

    def test_real_five_lifecycle_cases_are_distinct_from_Base_and_work(self):
        report=json.loads((self.LIFE/"private_lifecycle_result.json").read_bytes())
        result=policy.report_contract("lifecycle",report)
        self.assertEqual(result["Base_plus_lifecycle_typed_PNGs"],50)
        self.assertEqual(result["constructed_cases"],5)
        self.assertFalse(result["UI_earned_work_save_revisit"])
        self.assertIn("NOT REACHED",result["C3"])
        bad=deepcopy(report);bad["cases"]=bad["cases"][:-1]
        with self.assertRaises(ValueError):
            policy.report_contract("lifecycle",bad)
        bad=deepcopy(report);bad["cases"][0]["source_character_paint"]["geometry_equal"]=False
        with self.assertRaises(ValueError):
            policy.report_contract("lifecycle",bad)

    def test_original_seven_GD_bytes_are_pinned_and_not_rewritten(self):
        self.assertEqual(len(policy.CORE_HELPERS),5)
        self.assertEqual(len(policy.HELPERS),7)
        self.assertEqual(policy.literal_bindings({"qa_root":"E:/fixture","run_prefix":"READONLY"}),{})
        for name in policy.HELPERS:
            original=(policy.LEGACY/name).read_bytes()
            active,operations=policy.transport_bytes(name,original,{})
            self.assertEqual(active,original.replace(b"\r\n",b"\n"))
            self.assertEqual(operations,[])
        name=next(iter(policy.HELPERS))
        with self.assertRaises(ValueError):
            policy.transport_bytes(name,(policy.LEGACY/name).read_bytes()+b"\n",{})

    def test_no_counter_or_wrong_room_import_in_policy(self):
        self.assertEqual(policy.COUNTERS,{})
        self.assertEqual(list(policy.CANONICAL_IMPORTS),[policy.ART+"background.png.import"])
        self.assertEqual(policy.LOW_IDS,policy.ANIMATION_IDS)
        self.assertEqual(len(policy.LOW_IDS),7)
        self.assertEqual(policy.LAYER,"back_room")
        self.assertEqual(policy.ARCHETYPE,"small_underground_casino")

    def test_50_historical_masks_cannot_stand_in_for_Base_Lucky_glyph(self):
        report={"schema":"bth.private_spatial_acceptance/v1","mode":"lucky-glyph",
            "context":"small_underground_casino:back_room","case":"C1_marker",
            "production_snapshot_unchanged":True,"processing_remained_active":True,
            "checks":5,"findings":[],"lucky_id":"event:recruitment_lucky",
            "actual_glyph_alpha_pixels":125,"actual_label_alpha_ge64_pixels":100,
            "actual_label_alpha_ge64_bright_master_pixels":3,"glyph_geometry_equal":True,
            "actual_native_glyph_png":"actual.png","clean_Base10_claim":False,
            "fixture":"CONSTRUCTED_PREGEN_MARKER_TRUST_PRIVATE_BASE_RECRUITMENT"}
        self.assertTrue(policy.report_contract("lucky-glyph",report)["new_probe"])
        for key,value in (("actual_glyph_alpha_pixels",0),("actual_label_alpha_ge64_pixels",0),
                          ("lucky_id","crew_lucky"),("case","__none"),("case","C2_associate_0"),
                          ("clean_Base10_claim",True)):
            bad=deepcopy(report);bad[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):
                policy.report_contract("lucky-glyph",bad)

    def test_core_acceptance_work_scope_are_explicit_separate_phases(self):
        self.assertEqual(len(runner.CORE_PHASES),13)
        self.assertFalse(set(runner.CORE_PHASES)&set(runner.ACCEPTANCE_PHASES))
        self.assertEqual(runner.prerequisites("work-coverage"),["lifecycle"])
        self.assertIn("work-coverage",runner.prerequisites("acceptance-summary"))
        for phase in ("composite","composite-rm","depth","placement","lucky-glyph"):
            self.assertIn(phase,runner.ENGINE_PHASES)
            fixture=Receipts(phase)
            self.assertIn("--private-mode="+phase,fixture.command)
        self.assertNotIn("work-coverage",runner.ENGINE_PHASES)


if __name__ == "__main__":
    unittest.main()
