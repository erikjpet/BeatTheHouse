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
import math
import struct
import re
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import kitty_spatial_native_trial as runner
import kitty_spatial_native_profile as policy
import kitty_spatial_native_pixels as pixels
import ast


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def native_clock_proof(raw_object=0.1,raw_route=0.2,diagnostic_object=None,diagnostic_route=None):
    """Synthetic explicit transport fixture; it proves no historical cause."""
    obj=raw_object if diagnostic_object is None else diagnostic_object
    route=raw_route if diagnostic_route is None else diagnostic_route
    pair={"object_clock":{"value":obj,"ieee754_hex_le":struct.pack("<d",raw_object).hex()},
          "route_clock":{"value":route,"ieee754_hex_le":struct.pack("<d",raw_route).hex()}}
    return {"schema":"bth.kitty_native_clock_proof/v1","encoding":"IEEE754_BINARY64_LITTLE_ENDIAN",
        "native":{name:deepcopy(pair) for name in ("expected","a","control","b")},
        "serialized":{name:{"object_clock":obj,"route_clock":route} for name in ("a","control","b")},
        "native_values_equal_raw_replay":True,
        "legacy_cross_representation_equal":obj==raw_object and route==raw_route,
        "json_numeric_values_are_diagnostics":True}


class Receipts:
    """Authentic schema shape, with bytes/hash custody exercised in memory."""
    def __init__(self, phase="source-identity", capture_seconds=20.0):
        root = Path("E:/CodexQA/BTH")
        workspace = root / "workspaces/BTH-ENV-SPATIAL-KITTYTRIAL2-20261116"
        self.cfg = {"schema": "bth.kitty_spatial_inputs/v1", "qa_root": str(root), "workspace": str(workspace),
            "project": str(workspace / "qa_source"), "run_prefix": "kitty-closed-receipt-fixture",
            "input_workspace":str(policy.RETAINED_INPUT_WORKSPACE),
            "input_workspace_access":"READ_ONLY_RETAINED_NO_PROFILE_MIGRATION",
            "source_commit": "a" * 40, "source_tree": "b" * 40, "source_scope": runner.selected.SCOPE,
            "capture_seconds": capture_seconds, "timeout": 1200, "position": "-32000,-32000",
            "engine": "D:/fixture/godot.exe", "git": "C:/fixture/git.exe", "git_dir": "D:/fixture/repository.git",
            "baseline_stage": "E:/fixture/qualified-stage", "native_extension_descriptor": "E:/fixture/native.gdextension",
            "editor_native_library": "E:/fixture/native.dll", "candidate_root": "E:/fixture/candidate",
            "candidate_manifest": "E:/fixture/assembly.json", "review": "D:/fixture/review.json",
            "baseline_auxiliary_files": {".gdignore": {"path": str(policy.RETAINED_INPUT_WORKSPACE / "source_baseline/.gdignore"), "bytes": 83,
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
        if phase in runner.PROBE_PHASES:
            names.add(runner.REPORT_NAMES["contexts"])
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
    def test_real_common_prior_then_full_kitty_chain_accepts_each_phase(self):
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

    def test_common_prepared_api_accepts_kitty_receipts_and_keeps_uid_custody(self):
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




class NewKittyProbeContractChecks(unittest.TestCase):
    @staticmethod
    def report(mode):
        cases={}
        for scenario,count in policy.CONTEXT_COUNTS.items():
            row={"schema":"bth.kitty_spatial_acceptance_case/v1","case":scenario,"mode":mode,"context":policy.ROOM,
                "findings":[],"checks":3,"production_snapshot_unchanged":True,"processing_remained_active":True,
                "browser_execution":False,"actual_object_count":count,
                "counter":{"id":"kitty_champagne_bar","geometry_equal":True,"dimensions_equal":True,"master_crop_RGBA_equal":True}}
            ids=[f"actual:{i}" for i in range(count)]
            row["actual_object_ids"]=ids
            row["native_target_binding"]={"source_api":"PixelSceneCanvas._active_scene_objects","native_object_count":count,
                "expected_object_count":count,"actual_object_ids":ids,"all_objects_are_unique_native_dictionaries":True,
                "all_position_and_size_are_native_Vector2":True,"native_objects_equal_native_view":True,
                "native_type_guard_before_json":True,"serialized_objects_used_as_paint_target":False,
                "serialized_objects_equal_replay":True}
            if mode in ("composite","composite-rm"):
                row["entries"]=[{"id":name,"identical_control_pixels":True,"actual_objects_layout_equal":True,
                    "object_route_label_clocks_equal":True,"reduce_motion_composite_stable":True,"visible_composite_change":True,
                    "actual_counter_retained":True,"counter_id":"kitty_champagne_bar","clock_proof":native_clock_proof()} for name in policy.ANIMATION_IDS]
            elif mode=="low-detail":
                row["actual_low_detail_browser_execution"]=False
                row["entries"]=[{"id":name,"web_low_detail":True,"identical_control_pixels":True,
                    "live_visible_change":True,"reduce_motion_stable":True,"native_and_simulated_low_pixels_equal":True,
                    "renderer_present_low_detail_argument":True} for name in policy.ANIMATION_IDS]
            elif mode=="placement":
                row.update(placement_enabled=True,geometry_equal=True,no_saved_override_or_drag=True,
                           clock_advanced_without_pointer=True,redraw_advanced_without_pointer=True)
            else:
                row.update(counter_count=1,counter_id="kitty_champagne_bar",geometry_equal=True,depth_uses_native_typed_objects=True)
            cases[scenario]=row
        return {"schema":"bth.kitty_spatial_acceptance/v1","mode":mode,"context":policy.ROOM,"catalog":list(policy.CATALOG),
            "case_order":list(policy.CATALOG),"cases":cases,"all_five_contexts_captured":True,"findings":[],
            "checks":sum(r["checks"] for r in cases.values()),"new_QA_acceptance":True,"original_observers_modified":False,
            "original_checks_are_separate":True,"production_guard_relaxed":False,"browser_execution":False,
            "later_lifecycle_work_save_revisit_coverage":False}

    def test_all_five_modes_require_exact_five_cases_and_27_entries(self):
        for mode in runner.PROBE_PHASES:
            report=self.report(mode)
            self.assertEqual(policy.report_contract(mode,report)["actual_initial_contexts"],5)
            bad=deepcopy(report);del bad["cases"][policy.CATALOG[-1]]
            with self.subTest(mode=mode),self.assertRaises(ValueError):
                policy.report_contract(mode,bad)

    def test_original_assertions_browser_and_work_scope_cannot_be_relaxed(self):
        for field,value in (("new_QA_acceptance",False),("original_observers_modified",True),
                ("original_checks_are_separate",False),("production_guard_relaxed",True),
                ("browser_execution",True),("later_lifecycle_work_save_revisit_coverage",True),
                ("all_five_contexts_captured",False),("checks",1)):
            report=self.report("composite");report[field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):
                policy.report_contract("composite",report)

    def test_populated_composite_controls_counter_and_processing_are_required(self):
        for field in ("identical_control_pixels","actual_objects_layout_equal","object_route_label_clocks_equal",
                      "visible_composite_change","actual_counter_retained"):
            report=self.report("composite");report["cases"]["__none"]["entries"][0][field]=False
            with self.subTest(field=field),self.assertRaises(ValueError):
                policy.report_contract("composite",report)
        for field in ("production_snapshot_unchanged","processing_remained_active"):
            report=self.report("composite");report["cases"]["__none"][field]=False
            with self.subTest(field=field),self.assertRaises(ValueError):
                policy.report_contract("composite",report)
        report=self.report("composite");report["cases"]["__none"]["counter"]["master_crop_RGBA_equal"]=False
        with self.assertRaises(ValueError):
            policy.report_contract("composite",report)

    def test_RM_composite_and_all26_default_low_detail_render_flags_are_required(self):
        report=self.report("composite-rm");report["cases"]["__none"]["entries"][0]["reduce_motion_composite_stable"]=False
        with self.assertRaises(ValueError):
            policy.report_contract("composite-rm",report)
        for field in ("web_low_detail","identical_control_pixels","live_visible_change","reduce_motion_stable",
                      "native_and_simulated_low_pixels_equal","renderer_present_low_detail_argument"):
            report=self.report("low-detail");report["cases"]["__none"]["entries"][0][field]=False
            with self.subTest(field=field),self.assertRaises(ValueError):
                policy.report_contract("low-detail",report)
        report=self.report("low-detail");report["cases"]["__none"]["actual_low_detail_browser_execution"]=True
        with self.assertRaises(ValueError):
            policy.report_contract("low-detail",report)

    def test_placement_requires_no_input_clock_redraw_and_unchanged_geometry(self):
        for field in ("placement_enabled","geometry_equal","no_saved_override_or_drag",
                      "clock_advanced_without_pointer","redraw_advanced_without_pointer"):
            report=self.report("placement");report["cases"]["__none"][field]=False
            with self.subTest(field=field),self.assertRaises(ValueError):
                policy.report_contract("placement",report)

    def test_depth_requires_one_original_right_counter_and_exact_initial_object_counts(self):
        for field,value in (("counter_count",2),("counter_id","invented"),("actual_object_count",3),("geometry_equal",False)):
            report=self.report("depth");report["cases"]["__none"][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):
                policy.report_contract("depth",report)

class ExternalObserverBoundaryChecks(unittest.TestCase):
    def test_inert_text_is_not_a_selected_GD_resource(self):
        for target,spec in policy.OBSERVER_SPECS.items():
            self.assertTrue(runner.selected.selected(target))
            self.assertFalse(runner.selected.selected(spec["artifact_relative"]))
            self.assertTrue(spec["artifact_relative"].endswith(".gd.txt"))
            self.assertFalse(spec["artifact_relative"].endswith(runner.selected.CODE_SUFFIXES))

    def test_every_raw_GD_and_UID_is_rejected_from_selected_source(self):
        base={"project.godot":{},"tools/existing_original.gd":{}}
        self.assertTrue(policy.observer_source_boundary(base)["all2_observer_GD_and_UID_targets_absent"])
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
        changed=deepcopy(original);changed["original_observers_modified"]=True
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
        self.assertEqual(len(result["files"]),3)
        self.assertTrue(result["two_GD_texts_and_provenance_bound_to_current_commit"])
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

    def test_sibling_Private_receipt_does_not_authorize_Kitty(self):
        fixture=Receipts()
        fixture.result["schema"]="bth.private_crew_spatial_trial_phase/v2"
        fixture.save("phase-result.json",fixture.result)
        with self.assertRaises(ValueError):
            fixture.validate()

    def test_installed_external_observer_binding_cannot_change_or_disappear(self):
        auxiliary={".gdignore":{"sha256":"a"*64}}
        overlay={"schema":"bth.kitty_qa_observer_overlay/v1","observers":{"one":"pinned"}}
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


class ExactNativeClockProofChecks(unittest.TestCase):
    def test_exact_native_binary64_proof_accepts_all_identical_controls(self):
        proof=native_clock_proof()
        self.assertIs(policy.check_clock_proof(proof),True)
        self.assertEqual(proof["native"]["expected"]["object_clock"]["ieee754_hex_le"],"9a9999999999b93f")
        self.assertTrue(proof["legacy_cross_representation_equal"])

    def test_finite_integer_JSON_diagnostics_are_numbers_not_booleans(self):
        self.assertIs(policy.check_clock_proof(native_clock_proof(4.0,8.0,4,8)),True)

    def test_explicit_rounded_diagnostics_can_disagree_with_authoritative_native_bits(self):
        proof=native_clock_proof(math.nextafter(0.1,math.inf),math.nextafter(0.2,math.inf),0.1,0.2)
        self.assertFalse(proof["legacy_cross_representation_equal"])
        self.assertIs(policy.check_clock_proof(proof),True)
        self.assertNotEqual(struct.pack("<d",proof["native"]["expected"]["object_clock"]["value"]).hex(),
                            proof["native"]["expected"]["object_clock"]["ieee754_hex_le"])

    def test_one_ULP_mismatch_in_any_native_frame_or_clock_is_rejected(self):
        for frame in ("a","control","b"):
            for clock in ("object_clock","route_clock"):
                proof=native_clock_proof()
                raw=struct.unpack("<d",bytes.fromhex(proof["native"][frame][clock]["ieee754_hex_le"]))[0]
                proof["native"][frame][clock]["ieee754_hex_le"]=struct.pack("<d",math.nextafter(raw,math.inf)).hex()
                with self.subTest(frame=frame,clock=clock),self.assertRaises(ValueError):
                    policy.check_clock_proof(proof)

    def test_serialized_and_native_diagnostic_fields_must_still_match_each_other(self):
        for frame in ("expected","a","control","b"):
            proof=native_clock_proof();proof["native"][frame]["object_clock"]["value"]=0.3
            with self.subTest(frame=frame),self.assertRaises(ValueError):
                policy.check_clock_proof(proof)
        for frame in ("a","control","b"):
            proof=native_clock_proof();proof["serialized"][frame]["route_clock"]=0.4
            with self.subTest(frame=frame),self.assertRaises(ValueError):
                policy.check_clock_proof(proof)

    def test_legacy_diagnostic_boolean_is_recomputed_and_never_used_as_acceptance(self):
        exact=native_clock_proof();exact["legacy_cross_representation_equal"]=False
        rounded=native_clock_proof(math.nextafter(0.1,math.inf),0.2,0.1,0.2)
        rounded["legacy_cross_representation_equal"]=True
        for proof in (exact,rounded):
            with self.assertRaises(ValueError):
                policy.check_clock_proof(proof)

    def test_clock_schema_encoding_and_claim_types_are_exact(self):
        for field,value in (("schema","bth.kitty_native_clock_proof/v0"),("encoding","BINARY32"),
                ("native_values_equal_raw_replay",False),("native_values_equal_raw_replay",1),
                ("json_numeric_values_are_diagnostics",False),("legacy_cross_representation_equal",1)):
            proof=native_clock_proof();proof[field]=value
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):
                policy.check_clock_proof(proof)

    def test_missing_extra_or_mistyped_clock_record_members_are_rejected(self):
        changes=[
            lambda p:p.pop("serialized"),
            lambda p:p.update(extra="not part of the contract"),
            lambda p:p["native"].pop("control"),
            lambda p:p["native"].update(extra=deepcopy(p["native"]["a"])),
            lambda p:p["native"]["a"].pop("route_clock"),
            lambda p:p["native"]["a"]["object_clock"].update(extra=0),
            lambda p:p["serialized"].pop("b"),
            lambda p:p["serialized"]["a"].update(extra=0),
            lambda p:p.update(native=[]),
            lambda p:p["native"].update(a=[]),
        ]
        for change in changes:
            proof=native_clock_proof();change(proof)
            with self.subTest(change=change),self.assertRaises(ValueError):
                policy.check_clock_proof(proof)

    def test_native_hex_format_endianness_and_finiteness_are_enforced(self):
        for bad in ("9A9999999999B93F","9a9999999999b93","0x9a9999999999b93f","zz"*8,
                    struct.pack(">d",0.1).hex(),struct.pack("<d",math.inf).hex(),struct.pack("<d",math.nan).hex(),None):
            proof=native_clock_proof();proof["native"]["b"]["object_clock"]["ieee754_hex_le"]=bad
            with self.subTest(bad=bad),self.assertRaises(ValueError):
                policy.check_clock_proof(proof)

    def test_native_and_serialized_diagnostic_types_reject_bool_text_and_nonfinite(self):
        for bad in (True,"0.1",None,[],math.inf,-math.inf,math.nan):
            for target in ("native","serialized"):
                proof=native_clock_proof()
                if target=="native":
                    proof["native"]["a"]["object_clock"]["value"]=bad
                else:
                    proof["serialized"]["a"]["object_clock"]=bad
                with self.subTest(bad=bad,target=target),self.assertRaises(ValueError):
                    policy.check_clock_proof(proof)

    def test_last_context_last_entry_requires_exact_native_proof(self):
        report=NewKittyProbeContractChecks.report("composite")
        entry=report["cases"][policy.CATALOG[-1]]["entries"][-1]
        entry["clock_proof"]["native"]["b"]["route_clock"]["ieee754_hex_le"]=struct.pack("<d",math.nextafter(0.2,math.inf)).hex()
        self.assertTrue(entry["object_route_label_clocks_equal"])
        with self.assertRaises(ValueError):
            policy.report_contract("composite",report)

    def test_missing_clock_proof_is_rejected_even_when_old_boolean_claims_pass(self):
        for mode in ("composite","composite-rm"):
            report=NewKittyProbeContractChecks.report(mode)
            report["cases"]["__none"]["entries"][0].pop("clock_proof")
            with self.subTest(mode=mode),self.assertRaises(ValueError):
                policy.report_contract(mode,report)

    def test_explicit_diagnostic_difference_is_allowed_in_complete_composites(self):
        for mode in ("composite","composite-rm"):
            report=NewKittyProbeContractChecks.report(mode)
            report["cases"]["__none"]["entries"][0]["clock_proof"]=native_clock_proof(
                math.nextafter(0.1,math.inf),math.nextafter(0.2,math.inf),0.1,0.2)
            self.assertFalse(report["cases"]["__none"]["entries"][0]["clock_proof"]["legacy_cross_representation_equal"])
            self.assertEqual(policy.report_contract(mode,report)["actual_initial_contexts"],5)



class KittyOriginalSourceContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contexts=policy.read_json(pixels.HISTORICAL_CONTEXT/"kitty_preart_metadata.json")
        cls.motion=policy.read_json(pixels.HISTORICAL_MOTION/"kitty_animation_probe.json")
        cls.capture=policy.read_json(Path("E:/CodexQA/BTH/runs/BTH-ENVART-KITTYTRIAL-20261115-r6-video-01/evidence/capture/animation_capture.json"))

    def test_original_contexts_exact_2N734_93_selected_186_masks(self):
        result=policy.report_contract("contexts",self.contexts,source_files=7215)
        self.assertEqual((result["checks"],result["initial_contexts"],result["object_occurrences"],result["typed_PNGs"]),(15164,5,93,186))
        self.assertEqual(result["selected_labels"],93)
        self.assertFalse(result["later_lifecycle_work_save_revisit"])

    def test_wrong_source_count_or_context_catalog_rejected(self):
        with self.assertRaises(ValueError):
            policy.report_contract("contexts",self.contexts,source_files=7214)
        for key in ("scenarios","direct_catalog"):
            bad=deepcopy(self.contexts);bad[key]=bad[key][:-1]
            with self.subTest(key=key),self.assertRaises(ValueError):
                policy.report_contract("contexts",bad,source_files=7215)

    def test_selected_typed_authority_and_no_findings_are_required(self):
        for change in ("selected","paint","geometry","authority","finding"):
            bad=deepcopy(self.contexts);view=bad["views"]["__none"]
            if change=="selected":view["selected_label_evidence"].pop()
            elif change=="paint":view["source_paint"]["objects"][0]["object"]["id"]="invented"
            elif change=="geometry":view["source_paint"]["geometry_equal"]=False
            elif change=="authority":view["live_authority"]["ok"]=False
            else:bad["findings"]=["failure"]
            with self.subTest(change=change),self.assertRaises(ValueError):
                policy.report_contract("contexts",bad,source_files=7215)

    def test_original_motion55_is_native27_not_rendered_low(self):
        result=policy.report_contract("motion",self.motion)
        self.assertEqual((result["checks"],result["native_entries"],result["default_low_detail_entries"]),(55,27,27))
        self.assertFalse(result["original_observer_rendered_low_detail"])
        self.assertFalse(result["browser_acceptance"])
        for field in ("live_visible_change","reduce_motion_stable"):
            bad=deepcopy(self.motion);bad["entries"][-1][field]=False
            with self.assertRaises(ValueError):
                policy.report_contract("motion",bad)

    def test_exact81_motion_PNG_saved_evidence_is_required(self):
        rows=[{"file":name+suffix+".png","dimensions":[1800,860]} for name in policy.ANIMATION_IDS
              for suffix in ("_live_a","_live_b","_reduced")]
        self.assertEqual(runner.motion_png_contract(rows)["exact_original_motion_PNG_count"],81)
        for change in ("missing_reduced","extra","duplicate","dimensions"):
            bad=deepcopy(rows)
            if change=="missing_reduced":bad.pop()
            elif change=="extra":bad.append({"file":"invented.png","dimensions":[1800,860]})
            elif change=="duplicate":bad[-1]=deepcopy(bad[0])
            else:bad[-1]["dimensions"]=[900,430]
            with self.subTest(change=change),self.assertRaises(ValueError):
                runner.motion_png_contract(bad)

    def test_five_original_GD_and_UID_provenance_unchanged(self):
        self.assertEqual(len(policy.HELPERS),5)
        self.assertEqual(policy.original_observers(),{**policy.HELPERS,**policy.PROVENANCE})
        for name in policy.HELPERS:
            original=(policy.LEGACY/name).read_bytes()
            active,operations=policy.transport_bytes(name,original,{})
            self.assertEqual(active,original.replace(b"\r\n",b"\n"))
            self.assertEqual(operations,[])

    def test_room30_index_separate_one536x96_counter_and_canonical_one(self):
        proof=policy.assembly_proof()
        self.assertEqual(len(proof["baseline"]["files"]),30)
        self.assertNotIn(policy.INDEX,proof["baseline"]["files"])
        self.assertEqual(policy.seal(proof["baseline"]["files"]),policy.BASELINE_SEAL)
        self.assertEqual(policy.seal(proof["output"]["files"]),policy.APPROVAL["package_sha256"])
        self.assertEqual({n for n,h in proof["output"]["files"].items() if h!=proof["baseline"]["files"][n]},
            {policy.ART+"background.png"})
        self.assertEqual(policy.COUNTERS,{"kitty_champagne_bar":(1168,380,536,96)})
        self.assertEqual(len(policy.IGNORE),83)
        self.assertEqual(hashlib.sha256(policy.IGNORE).hexdigest(),policy.IGNORE_SHA)
        self.assertEqual(list(policy.CANONICAL_IMPORTS),[policy.ART+"background.png.import"])
        self.assertEqual(policy.CANONICAL_IMPORTS[policy.ART+"background.png.import"],
            "7ecc922f12cf6d819ede3fed493b8bece7a15c43ed523f12d67a3217ef30a54a")

    def test_historical8second_capture_is_not_misrepresented_as_new20(self):
        self.assertEqual(self.capture["capture_seconds_requested"],8)
        self.assertEqual(self.capture["max_animation_cycle"],97)
        self.assertFalse(self.capture["reduce_motion"]["full_app_pixels_stable"])
        with self.assertRaises(ValueError):
            runner.capture_contract(self.capture)
        relabelled=deepcopy(self.capture);relabelled["capture_seconds_requested"]=20
        with self.assertRaises(ValueError):
            runner.capture_contract(relabelled)
        synthetic=self.twenty_second_clock_fixture()
        result=runner.capture_contract(synthetic)
        self.assertEqual((result["frames"],result["native_entries"]),(62,27))
        self.assertFalse(result["reduce_motion_fullapp_pixels_stable"])

    def twenty_second_clock_fixture(self):
        """Synthetic timestamp fixture only; no PNG or actual-source claim."""
        result=deepcopy(self.capture)
        result["capture_seconds_requested"]=20
        first=result["frames"][0]["clock"]
        for index,frame in enumerate(result["frames"]):
            frame["clock"]=first+20.125*index/(len(result["frames"])-1)
            frame["board900_clock"]=frame["clock"]
        result["actual_clock_span"]=result["frames"][-1]["clock"]-first
        return result

    def test_capture_clock_and_clone_and_arrival_negatives(self):
        for change in ("clock","span","inventory","clone","arrival","RM","cycle"):
            bad=self.twenty_second_clock_fixture()
            if change=="clock":bad["frames"][1]["clock"]=bad["frames"][0]["clock"]
            elif change=="span":bad["actual_clock_span"]+=1
            elif change=="inventory":bad["frames"][0]["animation_states"].pop()
            elif change=="clone":bad["board900_equivalence"][0]["objects_equal"]=False
            elif change=="arrival":bad["actual_arrival_wait"]["remaining_person_transits"]=1
            elif change=="RM":bad["reduce_motion"]["production_art_texture_pixels_stable"]=False
            else:bad["max_animation_cycle"]=1
            with self.subTest(change=change),self.assertRaises(ValueError):
                runner.capture_contract(bad)

    def test_actual_capture_completion_uses_timestamps_not_requested_fps(self):
        original=self.twenty_second_clock_fixture()
        self.assertTrue(runner.capture_contract(original)["actual_duration_completion_qualified"])
        for change in ("short","gap","scheduler_bool","scheduler_nonfinite","scheduler_outside"):
            bad=deepcopy(original)
            if change in ("short","gap"):
                span=19.5 if change=="short" else 30.0
                first=bad["frames"][0]["clock"]
                for index,frame in enumerate(bad["frames"]):
                    frame["clock"]=first+span*index/(len(bad["frames"])-1)
                    frame["board900_clock"]=frame["clock"]
                bad["actual_clock_span"]=bad["frames"][-1]["clock"]-first
            elif change=="scheduler_bool":bad["sample_fps"]=True
            elif change=="scheduler_nonfinite":bad["sample_fps"]=float("nan")
            else:bad["sample_fps"]=30
            with self.subTest(change=change),self.assertRaises(ValueError):
                runner.capture_contract(bad)

    def test21_phases_and_exact_writer_names_and_offscreen20(self):
        self.assertEqual(len(runner.PHASES),21)
        self.assertEqual(len(runner.CORE_PHASES),13)
        self.assertEqual(set(runner.PIXEL_PHASES),{"stage-material","conservative-occlusion"})
        self.assertFalse(set(runner.PIXEL_PHASES)&runner.ENGINE_PHASES)
        self.assertEqual(runner.REPORT_NAMES["contexts"],"kitty_preart_metadata.json")
        self.assertEqual(runner.REPORT_NAMES["motion"],"kitty_animation_probe.json")
        for phase in runner.PROBE_PHASES:
            self.assertEqual(runner.REPORT_NAMES[phase],"kitty_spatial_acceptance.json")
            self.assertIn("--kitty-mode="+phase,Receipts(phase).command)
        self.assertIn("--excerpt-seconds=20.0",Receipts("capture").command)
        self.assertIn("-32000,-32000",Receipts("capture").command)
        for phase in ("contexts","motion"):
            self.assertIn('"'+runner.REPORT_NAMES[phase]+'"',(policy.LEGACY/("tools/"+runner.SCRIPTS[phase])).read_text())
        hook=Path(policy.observer_inputs()["observers"]["tools/envart_kitty_spatial_acceptance.gd"]["artifact_path"]).read_text()
        self.assertIn('"kitty_spatial_acceptance.json"',hook)
        self.assertEqual(runner.prerequisites("conservative-occlusion"),["contexts","motion"])
        self.assertEqual(runner.prerequisites("stage-material"),["contexts","depth"])

class KittyNativeProducerChecks(unittest.TestCase):
    def source(self):
        return Path(policy.observer_inputs()["observers"]["tools/envart_kitty_spatial_probe.gd"]["artifact_path"]).read_text()

    def test_native_targets_and_clocks_precede_JSON(self):
        text=self.source()
        section=text[text.index("func _image("):text.index("func _float64_hex_le")]
        self.assertLess(section.index("_native_clock_pair("),section.index("_json("))
        self.assertLess(section.index("_native_object_binding("),section.index("_json("))
        self.assertIn('"native_objects":native_objects',section)
        self.assertIn('canvas.call("_active_scene_objects")',text)
        self.assertIn('typeof(position_value) == TYPE_VECTOR2',text)
        self.assertIn('typeof(size_value) == TYPE_VECTOR2',text)
        self.assertIn('actual["native_objects"]',text)

    def test_native_draw_capture_precedes_restore_and_has_no_tolerance(self):
        text=self.source()
        section=text[text.index("func _draw()"):text.index("func _draw_environment_art_animations")]
        self.assertLess(section.index("qa_last_native_objects = _active_scene_objects()"),section.index("flicker = normal_clock"))
        self.assertLess(section.index('qa_last_view["qa_draw_route_clock"]'),section.index("actor_route_time = normal_route"))
        proof=text[text.index("func _native_clock_proof("):text.index("func _clock_pair(")]
        self.assertIn('native_control["object_clock"]["value"] == native_a',proof)
        self.assertIn('native_b["route_clock"]["value"] == native_a',proof)
        self.assertNotIn("is_equal_approx",proof)
        self.assertNotIn("abs(",proof)

    def test_each_native_binding_flag_and_counter_depth_is_mandatory(self):
        for key in ("all_objects_are_unique_native_dictionaries","all_position_and_size_are_native_Vector2",
                "native_objects_equal_native_view","native_type_guard_before_json","serialized_objects_equal_replay"):
            report=NewKittyProbeContractChecks.report("depth")
            report["cases"]["__none"]["native_target_binding"][key]=False
            with self.subTest(key=key),self.assertRaises(ValueError):
                policy.report_contract("depth",report)
        report=NewKittyProbeContractChecks.report("depth")
        report["cases"]["__none"]["native_target_binding"]["serialized_objects_used_as_paint_target"]=True
        with self.assertRaises(ValueError):
            policy.report_contract("depth",report)
        report=NewKittyProbeContractChecks.report("depth")
        report["cases"]["__none"]["depth_uses_native_typed_objects"]=False
        with self.assertRaises(ValueError):
            policy.report_contract("depth",report)

    def test_exact_disjoint_fresh_and_retained_roles(self):
        fake={policy.RETAINED_INPUT_WORKSPACE:{"raw_source","source_baseline","candidate_sources"}}
        with patch.object(policy,"retained_input_root",return_value=policy.RETAINED_INPUT_WORKSPACE), \
                patch.object(Path,"exists",return_value=False):
            result=policy.workspace_roles(policy.QA_WORKSPACE,policy.RETAINED_INPUT_WORKSPACE)
            self.assertEqual(result["qa_workspace"],policy.QA_WORKSPACE)
            self.assertEqual(result["input_workspace"],policy.RETAINED_INPUT_WORKSPACE)
            for value in (policy.RETAINED_INPUT_WORKSPACE,policy.QA_WORKSPACE.parent/"sibling"):
                with self.assertRaises(ValueError):
                    policy.workspace_roles(value,policy.RETAINED_INPUT_WORKSPACE)

class KittyPixelAdapterChecks(unittest.TestCase):
    def test_historical_only_cli_requires_explicit_admitted_paths(self):
        prefix="E:/CodexQA/BTH/runs/parity-fixture"
        tokens=["--historical-reference-only","--root=E:/CodexQA/BTH",
            "--workspace=E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-KITTYPARITY-20261116",
            "--profile="+prefix+"/profile","--temp="+prefix+"/temp",
            "--evidence="+prefix+"/evidence","--out="+prefix+"/evidence/historical-parity.json"]
        args=pixels.parse_args(tokens)
        self.assertTrue(args.historical_reference_only)
        self.assertEqual(args.out.name,"historical-parity.json")
        for key,value in (("root",Path("C:/fallback")),("workspace",policy.QA_WORKSPACE),
                ("out",Path(prefix+"/unadmitted/historical-parity.json"))):
            bad=deepcopy(args);setattr(bad,key,value)
            with patch.object(pixels,"plain",side_effect=lambda path:Path(path)),patch.object(Path,"exists",return_value=False), \
                    patch.object(Path,"open",side_effect=AssertionError("No invalid output may open")), \
                    self.subTest(key=key),self.assertRaises(ValueError):
                pixels.historical_worker(bad)

    def test_historical_only_cli_stops_unprepared_manifest_without_writing(self):
        prefix="E:/CodexQA/BTH/runs/parity-fixture"
        args=SimpleNamespace(root=Path("E:/CodexQA/BTH"),
            workspace=Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-KITTYPARITY-20261116"),
            profile=Path(prefix+"/profile"),temp=Path(prefix+"/temp"),evidence=Path(prefix+"/evidence"),
            out=Path(prefix+"/evidence/historical-parity.json"))
        with patch.object(pixels,"plain",side_effect=lambda path:Path(path)),patch.object(Path,"exists",return_value=False), \
                patch.object(pixels,"read_json",return_value={"schema":"bth-qa-storage/v1","prepared":False}), \
                patch.object(Path,"open",side_effect=AssertionError("No invalid output may open")),self.assertRaises(ValueError):
            pixels.historical_worker(args)

    def test_exact_alpha_source_over_transparent_and_opaque_and_half(self):
        self.assertEqual(pixels.over((1,2,3,4),(100,120,140,0)),(1,2,3,4))
        self.assertEqual(pixels.over((1,2,3,4),(100,120,140,255)),(100,120,140,255))
        self.assertEqual(pixels.over((0,0,0,255),(255,255,255,128)),(128,128,128,255))
        self.assertEqual(pixels.over((0,0,0,0),(25,50,75,128)),(25,50,75,128))

    def test_sparse_change_enumeration_covers_alpha_and_shared_channels(self):
        a=bytes((1,2,3,4,5,6,7,8,9,10,11,12))
        b=bytes((1,2,3,5,5,6,7,8,10,11,12,13))
        self.assertEqual(list(pixels.changed_pairs(a,b)),[(0,(1,2,3,4),(1,2,3,5)),(2,(9,10,11,12),(10,11,12,13))])
        self.assertEqual(list(pixels.changed_pairs(a,a)),[])

    def test_sparse_layers_keep_original_unassociated_RGBA_rounding(self):
        a=(11,22,33,100);b=(66,77,88,80);c=(90,45,30,64)
        result=pixels.over(pixels.over(a,b),c)
        self.assertNotEqual(result,pixels.over(pixels.over(a,c),b))
        rgba=bytes((0,0,0,0,*b,12,13,14,0,*c))
        self.assertEqual(list(pixels.sparse_pixels(rgba)),[(1,b),(3,c)])

    def test_exact_rack_edge_has8_buffer_and_next_native_pixel_fails(self):
        self.assertTrue(pixels.verify_contact([(991,416)],set())["full_17x17_native_neighborhood_per_base_pixel_inside_actual_deck"])
        for point in ((992,416),(500,448),(500,399)):
            with self.subTest(point=point),self.assertRaises(ValueError):
                pixels.verify_contact([point],set())

    def test_preserved_curtain_hole_never_counts_as_material(self):
        with self.assertRaises(ValueError):
            pixels.verify_contact([(500,420)],{(508,428)})
        self.assertFalse(pixels.deck_material(500,456,set()))
        self.assertFalse(pixels.deck_material(1004,427,set()))

    def test_contact_predicate_keeps_all_bottom12_shadow_pixels(self):
        rgba=bytearray(1800*860*4)
        for x,y,alpha in ((500,430,64),(501,441,255),(502,429,255),(503,441,63)):
            rgba[(y*1800+x)*4+3]=alpha
        points,bottom=pixels.contact_pixels(bytes(rgba),1800,860)
        self.assertEqual(bottom,442)
        self.assertEqual(points,[(500,430),(501,441)])

    def test_historical_parity_is_required_before_fresh_pixel_phase(self):
        text=Path(runner.__file__).read_text()
        section=text[text.index("def occlusion_worker("):text.index("def stage_material_worker(")]
        self.assertLess(section.index("pixels.historical_parity("),section.index("pixels.occlusion("))
        body=Path(pixels.__file__).read_text()
        self.assertIn('result["rows"]==expected["rows"]',body)
        self.assertIn('result["mask_hashes"]==expected["mask_hashes"]',body)
        self.assertIn('len(rows)==135',body)
        self.assertNotIn("from PIL",body)
        self.assertNotIn("subprocess",body)

    def test_no_new_test_executes_a_child_or_creates_scratch(self):
        tree=ast.parse(Path(__file__).read_text())
        forbidden={"exec","eval","subprocess","Popen","mkdtemp","TemporaryDirectory","unlink","rmdir"}
        calls={node.func.id if isinstance(node.func,ast.Name) else node.func.attr for node in ast.walk(tree)
               if isinstance(node,ast.Call) and isinstance(node.func,(ast.Name,ast.Attribute))}
        self.assertFalse(calls&forbidden)

if __name__=="__main__":
    unittest.main()

