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
import re
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import private_crew_spatial_native_trial_v3 as runner
import private_crew_spatial_native_profile_v3 as policy


PREVIOUS_TESTS_SHA = "64aecfbfaf2c4bb2b8c5ef44d878feebb856ed895e411805ed27ca72044c6507"


def native_target_binding():
    return {"native_source_api":"PixelSceneCanvas._active_scene_objects","native_position_type":"Vector2",
        "stable_id_unique":True,"expected_json_equal":True,"production_layout_equal":True,
        "coordinates_reconstructed":False}


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


class Receipts:
    """Authentic schema shape, with bytes/hash custody exercised in memory."""
    def __init__(self, phase="source-identity", capture_seconds=20.0):
        root = Path("E:/CodexQA/BTH")
        workspace = root / "workspaces/BTH-ENV-SPATIAL-PRIVATETRIAL2-20261116"
        input_workspace = root / "workspaces/BTH-ENV-SPATIAL-PRIVATETRIAL-20261116"
        self.cfg = {"schema": "bth.private_crew_spatial_inputs/v3", "qa_root": str(root), "workspace": str(workspace),
            "input_workspace": str(input_workspace), "input_workspace_access": "READ_ONLY_RETAINED_NO_PROFILE_MIGRATION",
            "project": str(workspace / "qa_source"), "run_prefix": "private-closed-receipt-fixture",
            "source_commit": "a" * 40, "source_tree": "b" * 40, "source_scope": runner.selected.SCOPE,
            "capture_seconds": capture_seconds, "timeout": 1200, "position": "-32000,-32000",
            "engine": "D:/fixture/godot.exe", "git": "C:/fixture/git.exe", "git_dir": "D:/fixture/repository.git",
            "baseline_stage": "E:/fixture/qualified-stage", "native_extension_descriptor": "E:/fixture/native.gdextension",
            "editor_native_library": "E:/fixture/native.dll", "candidate_root": "E:/fixture/candidate",
            "candidate_manifest": "E:/fixture/assembly.json", "review": "D:/fixture/review.json",
            "baseline_auxiliary_files": {".gdignore": {"path": str(input_workspace / "source_baseline/.gdignore"), "bytes": 75,
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
            "fixture":"CONSTRUCTED_PREGEN_MARKER_TRUST_PRIVATE_BASE_RECRUITMENT",
            "native_target_binding":native_target_binding()}
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



class ExternalObserverBoundaryChecks(unittest.TestCase):
    def test_inert_text_is_not_a_selected_GD_resource(self):
        for target,spec in policy.OBSERVER_SPECS.items():
            self.assertTrue(runner.selected.selected(target))
            self.assertFalse(runner.selected.selected(spec["artifact_relative"]))
            self.assertTrue(spec["artifact_relative"].endswith(".gd.txt"))
            self.assertFalse(spec["artifact_relative"].endswith(runner.selected.CODE_SUFFIXES))

    def test_every_raw_GD_and_UID_is_rejected_from_selected_source(self):
        base={"project.godot":{},"tools/existing_original.gd":{}}
        self.assertTrue(policy.observer_source_boundary(base)["all3_observer_GD_and_UID_targets_absent"])
        for target in policy.FRESH_HELPERS:
            for extra in (target,target+".uid"):
                with self.subTest(extra=extra),self.assertRaises(ValueError):
                    policy.observer_source_boundary({**base,extra:{}})
        for row in policy.OBSERVER_SPECS.values():
            with self.assertRaises(ValueError):
                policy.observer_source_boundary({**base,row["artifact_relative"]:{}})

    def test_exact_inert_inputs_do_not_read_or_require_untracked_raw_GD(self):
        real_plain=policy.plain
        raw={str(policy.OBSERVER_SOURCE_ROOT/name) for name in policy.FRESH_HELPERS}
        def guarded_plain(path,*args,**kwargs):
            if str(path) in raw:
                raise AssertionError("Untracked raw GD must not be read")
            return real_plain(path,*args,**kwargs)
        with patch.object(policy,"plain",side_effect=guarded_plain):
            inputs=policy.observer_inputs()
        self.assertFalse(inputs["raw_untracked_GD_files_read_or_required"])
        self.assertEqual(set(inputs["observers"]),set(policy.FRESH_HELPERS))
        self.assertEqual({name:row["sha256"] for name,row in inputs["observers"].items()},
                         {name:row["sha256"] for name,row in policy.OBSERVER_SPECS.items()})

    def test_missing_or_changed_provenance_is_rejected(self):
        with patch.object(policy,"sha",return_value="0"*64):
            with self.assertRaises(ValueError):
                policy.observer_inputs()
        original=policy.read_json(policy.OBSERVER_SOURCE_ROOT/policy.OBSERVER_PROVENANCE)
        changed=deepcopy(original);changed["functional_change"]=not original["functional_change"]
        self.assertNotEqual(changed,original)
        with patch.object(policy,"read_json",return_value=changed):
            with self.assertRaises(ValueError):
                policy.observer_inputs()

    @staticmethod
    def committed_records(inputs):
        data={row["artifact_relative"]:Path(row["artifact_path"]).read_bytes()
              for row in inputs["observers"].values()}
        data[policy.OBSERVER_PROVENANCE]=Path(inputs["provenance_path"]).read_bytes()
        return {name:{"mode":"100644","oid":hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest(),
                      "bytes":len(raw)} for name,raw in data.items()}

    def test_external_overlay_must_match_actual_current_Git_blobs(self):
        inputs=policy.observer_inputs()
        records=self.committed_records(inputs)
        result=policy.observer_git_binding(records,inputs)
        self.assertEqual(len(result["files"]),4)
        self.assertTrue(result["three_GD_texts_and_provenance_bound_to_current_commit"])
        name=next(iter(records))
        for mutation in ("missing","oid","bytes","mode"):
            changed=deepcopy(records)
            if mutation=="missing":
                del changed[name]
            elif mutation=="oid":
                changed[name]["oid"]="0"*40
            elif mutation=="bytes":
                changed[name]["bytes"]+=1
            else:
                changed[name]["mode"]="100755"
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):
                policy.observer_git_binding(changed,inputs)

    def test_v1_receipt_schema_does_not_authorize_v2(self):
        fixture=Receipts()
        fixture.result["schema"]="bth.private_crew_spatial_trial_phase/v1"
        fixture.save("phase-result.json",fixture.result)
        with self.assertRaises(ValueError):
            fixture.validate()

    def test_installed_external_observer_binding_cannot_change_or_disappear(self):
        auxiliary={".gdignore":{"sha256":"a"*64}}
        overlay={"schema":"bth.private_crew_qa_observer_overlay/v1","observers":{"one":"pinned"}}
        bindings={name:{"sha256":row["sha256"]} for name,row in policy.OBSERVER_SPECS.items()}
        git_binding={"scope":"FULL_TREE_RECORD_BINDING_ONLY_EXTERNAL_PAYLOAD_NOT_ARCHIVED","files":{"artifact":"pinned"}}
        prepared={"baseline_auxiliary_files":auxiliary,"fresh_acceptance_bindings":bindings,
            "external_qa_observers_absent_from_selected_source":True,
            "production_921code_900GD_161toolsGD_guards_unchanged":True,
            "external_qa_observer_git_binding":git_binding}
        installed={"baseline_auxiliary_files":auxiliary,"external_qa_observer_overlay":overlay,
            "external_qa_observer_git_binding":git_binding,"fresh_acceptance_bindings":bindings}
        cfg={"external_qa_observer_overlay":overlay}
        def check(first,second):
            with patch.object(runner,"previous",return_value={}),patch.object(runner,"verify_baseline",return_value=auxiliary), \
                    patch.object(runner.guard,"verify_prepared",return_value=(first,second)):
                return runner.verify_prepared(cfg)
        self.assertEqual(check(prepared,installed),(prepared,installed))
        for field in ("external_qa_observer_overlay","external_qa_observer_git_binding","fresh_acceptance_bindings"):
            bad=deepcopy(installed);bad.pop(field)
            with self.subTest(field=field),self.assertRaises(ValueError):
                check(prepared,bad)
        for field in ("external_qa_observers_absent_from_selected_source","production_921code_900GD_161toolsGD_guards_unchanged"):
            bad=deepcopy(prepared);bad[field]=False
            with self.subTest(field=field),self.assertRaises(ValueError):
                check(bad,installed)



class LuckyNativeTargetSourceChecks(unittest.TestCase):
    PROBE="tools/envart_private_spatial_probe.gd"

    @staticmethod
    def probe_source():
        inputs=policy.observer_inputs()
        record=inputs["observers"][LuckyNativeTargetSourceChecks.PROBE]
        data=Path(record["artifact_path"]).read_bytes()
        if hashlib.sha256(data).hexdigest()!=record["sha256"]:
            raise ValueError("Actual inert native-target observer hash differs")
        return data.decode("utf-8")

    @staticmethod
    def function(source,name):
        found=re.search(r"^func "+re.escape(name)+r"\(",source,re.M)
        if found is None:
            raise AssertionError("Required native-target function missing: "+name)
        tail=source[found.start():]
        end=tail.find("\nfunc ",1)
        return tail if end<0 else tail[:end]

    @staticmethod
    def compact(source):
        return re.sub(r"\s+","",source)

    def native_recovery_contract(self,source):
        value=self.compact(self.function(source,"_recover_lucky_native_target"))
        tokens=('ifstr(expected.get("id",""))!="event:recruitment_lucky":',
                'canvas.call("_active_scene_objects")',
                'ifnotnative_rowsisArray:',
                'ifrowisDictionaryandstr(row.get("id",""))=="event:recruitment_lucky":',
                'ifmatches.size()!=1:',
                'varnative_target:Dictionary=matches[0].duplicate(true)',
                'iftypeof(native_target.get("position"))!=TYPE_VECTOR2:',
                'if_json(native_target)!=expected:',
                'returnnative_target')
        positions=[]
        for token in tokens:
            self.assertIn(token,value)
            positions.append(value.index(token))
        self.assertEqual(positions,sorted(positions))
        self.assertEqual(value.count("return_native_target_failure("),5)
        self.assertNotIn("_check(",value)
        for banned in ("Vector2(","str_to_var(",".split(",".to_float("):
            self.assertNotIn(banned,value)
        failure=self.function(source,"_native_target_failure")
        self.assertIn('PRIVATE_LUCKY_NATIVE_TARGET_REQUIRED:',failure)
        self.assertIn("findings.append(diagnostic)",failure)
        self.assertIn("push_error(diagnostic)",failure)
        self.assertIn("return {}",failure)

    def test_actual_inert_probe_recovers_unique_native_id_vector_and_geometry(self):
        self.native_recovery_contract(self.probe_source())

    def test_missing_native_api_type_unique_id_or_identity_guard_is_rejected(self):
        source=self.probe_source()
        changes=(('canvas.call("_active_scene_objects")','canvas.call("current_view_snapshot")'),
                 ('if typeof(native_target.get("position")) != TYPE_VECTOR2:','if false:'),
                 ('if matches.size() != 1:','if false:'),
                 ('if _json(native_target) != expected:','if false:'))
        for before,after in changes:
            self.assertIn(before,source)
            with self.subTest(guard=before),self.assertRaises(AssertionError):
                self.native_recovery_contract(source.replace(before,after,1))

    def test_label_draw_rejects_wrong_id_or_string_position_before_geometry(self):
        source=self.probe_source()
        draw=source.split("class LabelPaintCanvas:",1)[1].split("\nvar checks",1)[0]
        value=self.compact(draw)
        guard=('ifstr(target.get("id",""))!="event:recruitment_lucky"or'
               'typeof(target.get("position"))!=TYPE_VECTOR2:')
        self.assertIn(guard,value)
        start=value.index(guard)
        geometry=value.index("_natural_model_rect_for_object(target)")
        glyph=value.index("_draw_object_label(")
        self.assertLess(start,geometry)
        self.assertLess(geometry,glyph)
        self.assertIn("push_error(",value[start:geometry])
        self.assertIn("return",value[start:geometry])

    def test_layout_and_native_target_failure_return_precede_assignment_and_pixels(self):
        source=self.probe_source()
        probe=self.compact(self.function(source,"run_probe"))
        recover=probe.index("_recover_lucky_native_target(typed,lucky[0])")
        geometry=probe.index('typed_view["object_layout"]==expected["object_layout"]andtyped_view["objects"]==expected["objects"]')
        failure=probe.index("ifnative_target.is_empty()ornotnative_layout_equal:")
        returned=probe.index("returnreport",failure)
        assignment=probe.index("typed.target=native_target")
        glyph=probe.index("varglyph:Image=")
        self.assertTrue(recover<geometry<failure<returned<assignment<glyph)
        self.assertIn('"native_target_binding_failed":true',probe[failure:assignment])
        self.assertNotIn("typed.target=lucky[0]",probe)
        self.assertLess(probe.index('typed.set("flicker",typed.object_clock)'),recover)
        self.assertLess(probe.index('typed.set("actor_route_time",typed.route_clock)'),recover)

    def test_recovery_uses_existing_production_native_render_and_geometry_apis(self):
        path=policy.OBSERVER_SOURCE_ROOT/"scripts/ui/pixel_scene_canvas.gd"
        production=path.read_text(encoding="utf-8")
        active=self.function(production,"_active_scene_objects")
        ordered=self.function(production,"_ordered_scene_objects")
        self.assertIn("func _active_scene_objects() -> Array:",active)
        self.assertIn("return active_scene_objects_cache",active)
        self.assertIn("return _ordered_scene_objects()",active)
        self.assertIn("foundation_scene_objects if uses_foundation_snapshot else scene_objects",ordered)
        self.assertIn("func _natural_model_rect_for_object(object_data: Dictionary) -> Rect2:",production)
        self.assertIn("func _draw_object_label(",production)
        self.assertIn('preload("res://scripts/ui/pixel_scene_canvas.gd")',self.probe_source())

    def test_existing_semantic_checks_and_processing_are_preserved(self):
        old=(policy.OBSERVER_SOURCE_ROOT/"review_artifacts/environment_art_sources/private-crew-native-observers/envart_private_spatial_probe.gd.txt").read_text()
        current=self.probe_source()
        checks=lambda value:[line.strip() for line in value.splitlines() if line.lstrip().startswith("_check(")]
        self.assertEqual(checks(current),checks(old))
        self.assertNotIn("set_process(false)",current)
        self.assertNotIn("set_physics_process(false)",current)
        self.assertIn("SubViewport.UPDATE_ALWAYS",current)
        self.assertIn('"coordinates_reconstructed":false',self.compact(current))

    @staticmethod
    def lucky_report():
        return {"schema":"bth.private_spatial_acceptance/v1","mode":"lucky-glyph",
            "context":"small_underground_casino:back_room","case":"C1_marker",
            "production_snapshot_unchanged":True,"processing_remained_active":True,
            "checks":5,"findings":[],"lucky_id":"event:recruitment_lucky",
            "actual_glyph_alpha_pixels":125,"actual_label_alpha_ge64_pixels":100,
            "actual_label_alpha_ge64_bright_master_pixels":3,"glyph_geometry_equal":True,
            "actual_native_glyph_png":"actual.png","clean_Base10_claim":False,
            "fixture":"CONSTRUCTED_PREGEN_MARKER_TRUST_PRIVATE_BASE_RECRUITMENT",
            "native_target_binding":native_target_binding()}

    def test_actual_native_binding_fields_are_required_and_strictly_typed(self):
        self.assertTrue(policy.report_contract("lucky-glyph",self.lucky_report())["new_probe"])
        changes=(("native_source_api","current_view_snapshot.objects"),("native_position_type","String"),
                 ("stable_id_unique",False),("stable_id_unique",1),
                 ("expected_json_equal",False),("expected_json_equal",1),
                 ("production_layout_equal",False),("production_layout_equal",1),
                 ("coordinates_reconstructed",True),("coordinates_reconstructed",0))
        for key,value in changes:
            report=self.lucky_report();report["native_target_binding"][key]=value
            with self.subTest(field=key,value=value),self.assertRaisesRegex(ValueError,"Lucky actual native"):
                policy.report_contract("lucky-glyph",report)

    def test_positive_pixel_counts_cannot_replace_missing_native_binding(self):
        for field in (None,*native_target_binding()):
            report=self.lucky_report()
            if field is None:
                del report["native_target_binding"]
            else:
                del report["native_target_binding"][field]
            with self.subTest(missing=field),self.assertRaisesRegex(ValueError,"Lucky actual native"):
                policy.report_contract("lucky-glyph",report)


class PrivateReadOnlyInputRoleChecks(unittest.TestCase):
    def test_exact_new_qa_and_original_input_roots_are_separate(self):
        roles=policy.workspace_roles(policy.QA_WORKSPACE,policy.RETAINED_INPUT_WORKSPACE)
        self.assertEqual(roles["qa_workspace"],Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-PRIVATETRIAL2-20261116"))
        self.assertEqual(roles["input_workspace"],Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-PRIVATETRIAL-20261116"))
        self.assertFalse(roles["qa_workspace"].is_relative_to(roles["input_workspace"]))
        self.assertFalse(roles["input_workspace"].is_relative_to(roles["qa_workspace"]))

    def test_swapped_nested_c_or_arbitrary_roles_are_rejected(self):
        pairs=((policy.RETAINED_INPUT_WORKSPACE,policy.RETAINED_INPUT_WORKSPACE),
               (policy.RETAINED_INPUT_WORKSPACE,policy.QA_WORKSPACE),
               (policy.QA_WORKSPACE,policy.QA_WORKSPACE),
               (policy.RETAINED_INPUT_WORKSPACE/"qa_source",policy.RETAINED_INPUT_WORKSPACE),
               (Path("C:/fixture"),policy.RETAINED_INPUT_WORKSPACE),
               (Path("E:/CodexQA/BTH/workspaces/arbitrary"),policy.RETAINED_INPUT_WORKSPACE))
        for qa,retained in pairs:
            with self.subTest(qa=qa,input=retained),self.assertRaises(ValueError):
                policy.workspace_roles(qa,retained)

    def test_input_readers_cannot_follow_new_qa_as_baseline_or_candidate_root(self):
        calls=(lambda:policy.baseline_auxiliary(policy.QA_WORKSPACE),
               lambda:policy.baseline_state(policy.QA_WORKSPACE),
               lambda:policy.source_contract(policy.QA_WORKSPACE,{}),
               lambda:policy.candidate(Path("E:/unused"),policy.QA_WORKSPACE,Path("E:/unused-proof"),Path("E:/unused-review"),{}))
        for number,call in enumerate(calls):
            with self.subTest(reader=number),self.assertRaises(ValueError):
                call()

    def test_closed_receipt_fixture_keeps_sentinel_path_under_readonly_inputs(self):
        fixture=Receipts()
        self.assertEqual(fixture.cfg["schema"],"bth.private_crew_spatial_inputs/v3")
        self.assertEqual(fixture.cfg["input_workspace_access"],"READ_ONLY_RETAINED_NO_PROFILE_MIGRATION")
        self.assertNotEqual(fixture.cfg["workspace"],fixture.cfg["input_workspace"])
        self.assertEqual(fixture.cfg["baseline_auxiliary_files"][".gdignore"]["path"],
                         str(Path(fixture.cfg["input_workspace"])/"source_baseline/.gdignore"))


if __name__ == "__main__":
    unittest.main()
