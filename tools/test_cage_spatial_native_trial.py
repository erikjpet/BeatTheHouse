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

import cage_spatial_native_trial as runner
import cage_spatial_native_profile as policy


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


class Receipts:
    """Authentic schema shape, with bytes/hash custody exercised in memory."""
    def __init__(self, phase="source-identity", capture_seconds=8.0):
        root = Path("E:/CodexQA/BTH")
        workspace = root / "workspaces/BTH-ENV-SPATIAL-CAGETRIAL-20261116"
        self.cfg = {"schema": "bth.cage_spatial_inputs/v1", "qa_root": str(root), "workspace": str(workspace),
            "project": str(workspace / "qa_source"), "run_prefix": "cage-closed-receipt-fixture",
            "source_commit": "a" * 40, "source_tree": "b" * 40, "source_scope": runner.selected.SCOPE,
            "capture_seconds": capture_seconds, "timeout": 1200, "position": "-32000,-32000",
            "engine": "D:/fixture/godot.exe", "git": "C:/fixture/git.exe", "git_dir": "D:/fixture/repository.git",
            "baseline_stage": "E:/fixture/qualified-stage", "native_extension_descriptor": "E:/fixture/native.gdextension",
            "editor_native_library": "E:/fixture/native.dll", "candidate_root": "E:/fixture/candidate",
            "candidate_manifest": "E:/fixture/assembly.json", "review": "D:/fixture/review.json",
            "baseline_auxiliary_files": {".gdignore": {"path": str(workspace / "source_baseline/.gdignore"), "bytes": 76,
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
        names=runner.artifact_names(phase)
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
    def test_real_common_prior_then_full_cage_chain_accepts_each_phase(self):
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

    def test_common_prepared_api_accepts_cage_receipts_and_keeps_uid_custody(self):
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
        explicit = runner.parse_args(self.common() + ["--capture-seconds=8", "--timeout=1200"])
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
        changed=deepcopy(original);changed["production_guard_relaxed"]=True
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

    def test_v1_receipt_schema_does_not_authorize_v2(self):
        fixture=Receipts()
        fixture.result["schema"]="bth.private_crew_spatial_trial_phase/v2"
        fixture.save("phase-result.json",fixture.result)
        with self.assertRaises(ValueError):
            fixture.validate()

    def test_installed_external_observer_binding_cannot_change_or_disappear(self):
        auxiliary={".gdignore":{"sha256":"a"*64}}
        overlay={"schema":"bth.cage_qa_observer_overlay/v1","observers":{"one":"pinned"}}
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


class CageOriginalContractChecks(unittest.TestCase):
    BASE=Path("E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-contexts-01/evidence")
    MOTION=Path("E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-motion-01/evidence")
    STOCK=Path("E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-stock-states-01/evidence")
    CAPTURE=Path("E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-video-01/evidence/capture")
    EMPTY=Path("E:/CodexQA/BTH/runs/BTH-ENVART-INTEGRATION-20261114-cage-empty-contract-02/evidence")

    def test_actual_Base_is_five_objects_ten_typed_PNGs_and_2N_plus54(self):
        report=json.loads((self.BASE/runner.REPORT_NAMES["contexts"]).read_bytes())
        result=policy.report_contract("contexts",report,source_files=7393)
        self.assertEqual((result["objects"],result["typed_PNGs"]),(5,10))
        self.assertFalse(result["reached_stock_or_lifecycle"])
        self.assertEqual(len(runner.context_png_names(report)),26)
        with self.assertRaises(ValueError):
            policy.report_contract("contexts",report,source_files=7392)
        bad=deepcopy(report);bad["views"]["invented_Gala"]={}
        with self.assertRaises(ValueError):
            policy.report_contract("contexts",bad,source_files=7393)
        bad=deepcopy(report);bad["views"]["__none"]["source_background"]["records"].pop()
        with self.assertRaises(ValueError):
            runner.context_png_names(bad)

    def test_actual_20normal16low82checks_and_RM_required(self):
        report=json.loads((self.MOTION/runner.REPORT_NAMES["motion"]).read_bytes())
        result=policy.report_contract("motion",report)
        self.assertEqual(result["checks"],82)
        self.assertEqual(result["actual_renderer_low_membership"],16)
        bad=deepcopy(report);bad["checks"]=66
        with self.assertRaises(ValueError):
            policy.report_contract("motion",bad)
        bad=deepcopy(report);bad["entries"][0]["reduce_motion_stable"]=False
        with self.assertRaises(ValueError):
            policy.report_contract("motion",bad)

    def test_actual_stock_fixture_is_twelve_not_reached_shop(self):
        report=json.loads((self.STOCK/runner.REPORT_NAMES["stock-states"]).read_bytes())
        result=policy.report_contract("stock-states",report)
        self.assertEqual(result["checks"],12)
        self.assertFalse(result["naturally_reached_stock_transactions_or_lifecycle"])
        for mutation in ("count","row","state"):
            bad=deepcopy(report)
            if mutation=="count":bad["checks"]=52
            elif mutation=="row":bad["rows"].pop()
            else:bad["rows"][0]["state"]="invented_stocked_shop"
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):
                policy.report_contract("stock-states",bad)

    def test_actual_EMPTY52_remains_distinct_from_stock12(self):
        report=json.loads((self.EMPTY/runner.REPORT_NAMES["empty-compat"]).read_bytes())
        self.assertEqual(policy.report_contract("empty-compat",report)["checks"],52)
        bad=deepcopy(report);bad["rendered_label_pixels"].pop()
        with self.assertRaises(ValueError):
            policy.report_contract("empty-compat",bad)

    def test_original_five_core_plus_stock_transport_changes_only_quoted_path(self):
        self.assertEqual((len(policy.CORE_HELPERS),len(policy.HELPERS)),(5,6))
        bindings=policy.literal_bindings({"qa_root":"E:/CodexQA/BTH","run_prefix":"cage-fixture"})
        self.assertEqual(set(bindings),{"tools/envart_cage_stock_states.gd"})
        for name in policy.HELPERS:
            original=(policy.LEGACY/name).read_bytes()
            active,operations=policy.transport_bytes(name,original,bindings)
            if name.endswith("stock_states.gd"):
                old,new=next(iter(bindings[name].items()))
                self.assertEqual(active,original.replace(b"\r\n",b"\n").replace(b'"'+old.encode()+b'"',b'"'+new.encode()+b'"'))
                self.assertEqual(len(operations),1)
            else:
                self.assertEqual(active,original.replace(b"\r\n",b"\n"));self.assertEqual(operations,[])
        name=next(iter(policy.HELPERS))
        with self.assertRaises(ValueError):
            policy.transport_bytes(name,(policy.LEGACY/name).read_bytes()+b"\n",bindings)

    def test_EMPTY_exact_CRLF_or_LF_never_replaced(self):
        raw=(policy.OBSERVER_SOURCE_ROOT/policy.EMPTY_TEST).read_bytes()
        for data in (raw,raw.replace(b"\r\n",b"\n")):
            with patch.object(policy,"plain",side_effect=Path),patch.object(Path,"read_bytes",return_value=data):
                row=policy.empty_test_contract(Path("E:/fixture"))
                self.assertFalse(row["source_replaced"]);self.assertFalse(row["UID_replaced"])
        with patch.object(policy,"plain",side_effect=Path),patch.object(Path,"read_bytes",return_value=raw+b"\n"):
            with self.assertRaises(ValueError):
                policy.empty_test_contract(Path("E:/fixture"))

    def test_custody_tab_and_final_LF_are_not_space_or_no_final_LF(self):
        values={"b":"2"*64,"a":"1"*64}
        exact=("a\t"+"1"*64+"\n"+"b\t"+"2"*64+"\n").encode()
        self.assertEqual(policy.seal(values),hashlib.sha256(exact).hexdigest())
        self.assertNotEqual(policy.seal(values),hashlib.sha256(exact[:-1]).hexdigest())
        self.assertNotEqual(policy.seal(values),hashlib.sha256(exact.replace(b"\t",b" ")).hexdigest())

    def test_actual_capture_requires_all32_ATM_frames_20_16_and_both_RM_surfaces(self):
        report=json.loads((self.CAPTURE/"animation_capture.json").read_bytes())
        result=runner.capture_contract(report)
        self.assertEqual(result["frames"],62)
        self.assertTrue(result["all32_ATM_frames_actually_observed"])
        self.assertFalse(result["full_floor_cycle_recorded"])
        for mutation in ("missing_ATM","low_membership","fullapp_RM","wrong_clock","clone_mismatch"):
            bad=deepcopy(report)
            if mutation=="missing_ATM":
                for frame in bad["frames"]:frame["animation_states"][1]["frame"]=0
            elif mutation=="low_membership":bad["animation_inventory"][-1]["web_low_detail"]=True
            elif mutation=="fullapp_RM":bad["reduce_motion"]["full_app_pixels_stable"]=False
            elif mutation=="wrong_clock":bad["actual_clock_span"]+=.1
            else:bad["board900_equivalence"][0]["objects_equal"]=False
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):
                runner.capture_contract(bad)

    def test_separate_phases_and_fixed_room_layer_are_explicit(self):
        self.assertEqual(len(runner.CORE_PHASES),13)
        self.assertEqual(len(runner.PHASES),23)
        self.assertFalse(set(runner.CORE_PHASES)&set(runner.ACCEPTANCE_PHASES))
        self.assertEqual((policy.ARCHETYPE,policy.LAYER),("grand_casino_cage",""))
        self.assertEqual(runner.prerequisites("stock-states"),["contexts"])
        self.assertIn("visibility-reference",runner.prerequisites("visibility"))
        self.assertNotIn("visibility",runner.ENGINE_PHASES)
        for phase in runner.FRESH_PROBE_PHASES:
            fixture=Receipts(phase)
            self.assertIn("--cage-mode="+phase,fixture.command)
            self.assertIn(runner.REPORT_NAMES["contexts"],runner.artifact_names(phase))
        self.assertIn("res://"+policy.EMPTY_TEST,Receipts("empty-compat").command)

    def test_missing_inherited_core_JSON_rejected_even_when_probe_report_is_intact(self):
        fixture=Receipts("composite")
        del fixture.result["artifact_sha256"][runner.REPORT_NAMES["contexts"]]
        fixture.save("phase-result.json",fixture.result)
        with self.assertRaises(ValueError):fixture.validate()


def probe_report(mode="composite"):
    contacts=[{"id":name,"kind":kind,"alpha_gt0":0,"alpha_ge64":0}
              for name in policy.HOST_IDS for kind in ("body","adorn")]
    result={"schema":"bth.cage_spatial_acceptance/v1","context":policy.ROOM,"case":"__none","mode":mode,
        "findings":[],"checks":1,"production_snapshot_unchanged":True,"processing_remained_active":True,
        "glyph_contact":{"selected_alpha46_texels":5532,"other_nonzero_alpha_values":0,
            "all_ten_source_contacts_zero":True,"fresh_typed_masks":contacts},
        "low_membership_count":16,"png_files":["fresh_%02d.png"%i for i in range(1 if mode=="depth-glyph" else 40)]}
    if mode=="depth-glyph":
        result["depth"]={"actual_command_order_valid":True,"Linda_before_counter":True,"body_count":5,
                         "adornment_count":5,"actual_geometry_equal":True}
    else:
        result["entries"]=[{"id":name,"identical_control_pixels":True,"actual_objects_layout_equal":True,
            "object_route_label_clocks_equal":True,"visible_composite_change":mode!="composite-rm" and (mode!="low-detail" or name in policy.LOW_IDS),
            "expected_change":mode!="composite-rm" and (mode!="low-detail" or name in policy.LOW_IDS)} for name in policy.ANIMATION_IDS]
    return result


class ActualProbeEvidenceChecks(unittest.TestCase):
    def test_contact_is_actual_alpha_not_label_or_body_rectangle(self):
        for mode in runner.FRESH_PROBE_PHASES:
            report=probe_report(mode)
            self.assertEqual(policy.report_contract(mode,report)["fresh_typed_masks"],10)
            for mutation in ("contact","empty_glyph","missing_mask","snapshot"):
                bad=deepcopy(report)
                if mutation=="contact":bad["glyph_contact"]["fresh_typed_masks"][0]["alpha_gt0"]=1
                elif mutation=="empty_glyph":bad["glyph_contact"]["selected_alpha46_texels"]=0
                elif mutation=="missing_mask":bad["glyph_contact"]["fresh_typed_masks"].pop()
                else:bad["production_snapshot_unchanged"]=False
                with self.subTest(mode=mode,mutation=mutation),self.assertRaises(ValueError):
                    policy.report_contract(mode,bad)

    def test_rm_and_low_membership_cannot_pass_as_normal_motion(self):
        for mode in ("composite-rm","low-detail"):
            bad=probe_report(mode);bad["entries"][-1]["visible_composite_change"]=True
            with self.assertRaises(ValueError):policy.report_contract(mode,bad)
        bad=probe_report();bad["entries"][0]["identical_control_pixels"]=False
        with self.assertRaises(ValueError):policy.report_contract("composite",bad)
        bad=probe_report("depth-glyph");bad["depth"]["Linda_before_counter"]=False
        with self.assertRaises(ValueError):policy.report_contract("depth-glyph",bad)

    def test_core26_plus_probe40_or1_must_be_exact_disjoint_union(self):
        core=json.loads((CageOriginalContractChecks.BASE/runner.REPORT_NAMES["contexts"]).read_bytes())
        base=runner.context_png_names(core)
        for mode in runner.FRESH_PROBE_PHASES:
            probe=probe_report(mode)
            for mutation in ("none","missing_core","extra","probe_only","shared_name"):
                current=deepcopy(probe)
                names=base|set(current["png_files"])
                if mutation=="missing_core":names.remove(next(iter(base)))
                elif mutation=="extra":names.add("unexpected.png")
                elif mutation=="probe_only":names=set(current["png_files"])
                elif mutation=="shared_name":
                    current["png_files"][0]=next(iter(base))
                    names=base|set(current["png_files"])
                evidence=Path("E:/fixture/evidence")
                def read(path):
                    return core if Path(path).name==runner.REPORT_NAMES["contexts"] else current
                with patch.object(Path,"read_text",return_value="PASS"),patch.object(runner.guard,"read_json",side_effect=read), \
                     patch.object(runner.guard,"sha",return_value="a"*64),patch.object(runner,"previous",return_value={"artifacts":{"source_files":7393}}), \
                     patch.object(runner,"png_inventory",return_value=[{"file":name} for name in names]):
                    if mutation=="none":
                        result=runner.result_for({"source_commit":"b"*40},mode,SimpleNamespace(evidence=evidence))
                        self.assertEqual(result["inherited_core_companion"]["original_PNGs"],26)
                    else:
                        with self.assertRaises(ValueError):
                            runner.result_for({"source_commit":"b"*40},mode,SimpleNamespace(evidence=evidence))


if __name__ == "__main__":
    unittest.main()
