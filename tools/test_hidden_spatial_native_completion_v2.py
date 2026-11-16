"""Focused source-only regressions for honest Hidden continuation receipts."""
import sys
sys.dont_write_bytecode = True

import ast
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import hidden_spatial_native_completion_profile_v2 as policy


def thin_fixture():
    report = {
        "asset_or_manifest_modified": False, "checks": 51, "failures": [],
        "qa_only": True, "renderer": "actual EnvironmentArtRenderer",
        "glints": [
            {"id": "thin_bobbing_ribbon_" + str(i), "clean_offscreen_wrap": True,
             "actual_midpoint_pixels_differ": True, "reduce_motion_hidden": True,
             "speed": 10.0+2.0*i, "y": 87.0+18.0*i, "before_clock": 100.0,
             "after_clock": 100.002, "midpoint_clock": 50.0, "phase": 9.4,
             "duration": 108.0}
            for i in range(5)
        ],
    }
    if policy.thin_contract(report)["checks"] != 51:
        raise AssertionError("Unmutated original51 fixture must pass before mutation")
    return report


def allowed_bytecode_assignment(node, target):
    return (type(node) is ast.Assign and len(node.targets) == 1 and
            isinstance(target, ast.Attribute) and isinstance(target.value, ast.Name) and
            target.value.id == "sys" and target.attr == "dont_write_bytecode" and
            type(node.value) is ast.Constant and node.value.value is True)


class ThinQualifierTests(unittest.TestCase):
    def test_actual_pinned_report_schema_51(self):
        report = policy.guard.read_json(policy.old_evidence("thin-wrap") / "thin_wrap_probe.json")
        self.assertEqual(policy.guard.sha(policy.old_evidence("thin-wrap") / "thin_wrap_probe.json"),
                         policy.THIN_REPORT_SHA)
        result = policy.thin_contract(report)
        self.assertEqual(result["checks"], 51)
        self.assertEqual(result["entries"], 5)
        self.assertEqual(result["old_v4_supervisor_status"], "FAILED_UNCHANGED")
        self.assertTrue(result["old_phase_result_absent"])

    def test_later_246_revision_is_rejected(self):
        report = thin_fixture()
        report["checks"] = 246
        with self.assertRaisesRegex(ValueError, "51 checks"):
            policy.thin_contract(report)

    def test_wrong_count_is_rejected(self):
        for count in (50, 52, True, "51", None):
            with self.subTest(count=count):
                report = thin_fixture()
                report["checks"] = count
                with self.assertRaises(ValueError):
                    policy.thin_contract(report)

    def test_wrong_row_id_is_rejected(self):
        report = thin_fixture()
        report["glints"][0]["id"] = "long_pink_drift_0"
        with self.assertRaisesRegex(ValueError, "IDs/order"):
            policy.thin_contract(report)

    def test_reordered_rows_are_rejected(self):
        report = thin_fixture()
        report["glints"].reverse()
        with self.assertRaisesRegex(ValueError, "IDs/order"):
            policy.thin_contract(report)

    def test_missing_or_extra_rows_are_rejected(self):
        for change in (-1, 1):
            report = thin_fixture()
            report["glints"] = report["glints"][:-1] if change < 0 else report["glints"]+[report["glints"][0]]
            with self.assertRaises(ValueError):
                policy.thin_contract(report)

    def test_all_original_row_boolean_gates_remain(self):
        for key in ("clean_offscreen_wrap", "actual_midpoint_pixels_differ", "reduce_motion_hidden"):
            report = thin_fixture()
            report["glints"][2][key] = False
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "predicates"):
                policy.thin_contract(report)

    def test_fixed_speed_and_row_cannot_change(self):
        for key in ("speed", "y"):
            report = thin_fixture()
            report["glints"][1][key] += 1
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "family"):
                policy.thin_contract(report)

    def test_nonfinite_clock_is_rejected(self):
        for key in ("before_clock", "after_clock", "midpoint_clock", "phase", "duration"):
            report = thin_fixture()
            report["glints"][1][key] = float("nan")
            with self.subTest(key=key), self.assertRaises(ValueError):
                policy.thin_contract(report)

    def test_any_original_finding_is_rejected(self):
        for key in ("findings", "failures"):
            report = thin_fixture()
            report[key] = ["actual failure"]
            with self.subTest(key=key), self.assertRaises(ValueError):
                policy.thin_contract(report)

    def test_wrong_renderer_or_asset_mutation_is_rejected(self):
        for key, value in (("renderer", "synthetic"), ("asset_or_manifest_modified", True), ("qa_only", False)):
            report = thin_fixture()
            report[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                policy.thin_contract(report)

    def test_wrong_report_and_row_types_fail_closed(self):
        for report in (None, [], "51", {"checks": 51, "glints": [None]*5}):
            with self.subTest(report=report), self.assertRaises(ValueError):
                policy.thin_contract(report)

    def test_pinned_gd_has_exact_ten_checks_per_five_plus_one(self):
        path = policy.original.LEGACY / policy.THIN_SOURCE
        raw = path.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), policy.THIN_SOURCE_SHA)
        lines = raw.decode().splitlines()
        calls = [line for line in lines if line.lstrip().startswith("_check(")]
        self.assertEqual(len(calls), 11)
        self.assertEqual(sum(line.startswith("        _check(") for line in calls), 10)
        self.assertIn('_check(rows.size()==5,"all five thin bobbing ribbons checked")', raw.decode())


class ContinuationCustodyTests(unittest.TestCase):
    def test_exact_22_old_receipts_are_pinned(self):
        self.assertEqual(len(policy.BASE_PHASES), 22)
        self.assertEqual(set(policy.BASE_PHASES), set(policy.BASE_RECEIPTS))
        self.assertEqual(policy.BASE_PHASES[-1], "long-wrap")
        self.assertNotIn("thin-wrap", policy.BASE_RECEIPTS)
        self.assertNotIn("acceptance-summary", policy.BASE_RECEIPTS)

    def test_failed_thin_full_evidence_is_pinned_separately(self):
        self.assertEqual(len(policy.THIN_EVIDENCE), 22)
        self.assertNotIn("phase-result.json", policy.THIN_EVIDENCE)
        self.assertEqual(sum(name.endswith(".png") for name in policy.THIN_EVIDENCE), 16)
        self.assertEqual(policy.THIN_EVIDENCE["job.json"], policy.THIN_JOB_SHA)
        self.assertEqual(policy.THIN_EVIDENCE["thin_wrap_probe.json"], policy.THIN_REPORT_SHA)

    def test_failed_phase_still_has_no_pass_receipt(self):
        self.assertFalse((policy.old_evidence("thin-wrap") / "phase-result.json").exists())

    def test_old_receipt_change_is_rejected_before_use(self):
        with patch.object(policy.guard, "sha", return_value="0"*64), \
             patch.object(policy.base, "previous") as previous:
            with self.assertRaisesRegex(ValueError, "old qualified phase receipt"):
                policy.authenticate_old({})
            previous.assert_not_called()

    def test_actual_old_png_inventory_is_authenticated(self):
        evidence = policy.old_evidence("source-paint")
        record = policy.guard.read_json(evidence / "phase-result.json")
        policy.verify_pngs(evidence, record["artifacts"]["generated_png_inventory"])
        self.assertEqual(len(record["artifacts"]["generated_png_inventory"]), 142)

    def test_changed_png_inventory_is_rejected(self):
        with patch.object(policy.base, "png_inventory", return_value=[{"sha256":"wrong"}]):
            with self.assertRaisesRegex(ValueError, "PNG hashes"):
                policy.verify_pngs(Path("unused"), [{"sha256":"original"}])

    def test_ordinary_exact_evidence_gate_is_present(self):
        source = Path(policy.__file__).read_text()
        self.assertIn("original.inventory_all(evidence, THIN_EVIDENCE) == THIN_EVIDENCE", source)
        self.assertIn('not (evidence / "phase-result.json").exists()', source)
        self.assertIn("inputs[\"source_config\"] == cfg", source)
        self.assertIn("base.command(cfg, \"thin-wrap\"", source)

    def test_source_identity_and_candidate_bindings_are_immutable(self):
        self.assertEqual(policy.SOURCE_FILES, 4049)
        self.assertEqual(policy.SOURCE_COMMIT, "8727e4481fd1ca2babe8c803c76d5e210f245f44")
        self.assertEqual(policy.IDENTITY_SHA, "a8be9f3ecd7916e0135df6fb6a2729890807389eee634fd445b57d1922d1f12c")
        self.assertEqual(policy.original.APPROVAL["package_sha256"],
                         "508b106419ef299aad27d92f4d54c5c4d1f7e6cf353dff546848ed290a273509")

    def test_no_old_game_code_or_library_mutation(self):
        source = Path(policy.__file__).read_text()
        tree = ast.parse(source)
        for node in ast.walk(tree):
            if isinstance(node, (ast.Assign, ast.AnnAssign, ast.AugAssign)):
                targets = node.targets if isinstance(node, ast.Assign) else [node.target]
                for target in targets:
                    if isinstance(target, ast.Attribute):
                        self.assertTrue(allowed_bytecode_assignment(node, target), ast.dump(target))
        self.assertNotIn("write_text(", source)
        self.assertNotIn("write_bytes(", source)
        self.assertNotIn("unlink(", source)
        self.assertNotIn("rmtree(", source)

    def test_old_library_hashes_are_actual(self):
        self.assertEqual(policy.guard.sha(Path(policy.base.__file__)), policy.BASE_RUNNER_SHA)
        self.assertEqual(policy.guard.sha(Path(policy.original.__file__)), policy.BASE_POLICY_SHA)

    def test_exact_remaining_engine_roster(self):
        self.assertEqual(policy.REMAINING_ENGINE_PHASES,
                         ("work-highstakes", "work-greased", "work-muscle", "effective-hits", "placement"))

    def test_all_six_original_unrun_roots_remain_absent(self):
        policy.require_old_not_run_absent()



class StrongOriginalRevisionTests(unittest.TestCase):
    def test_all_actual_remaining_successful_history_contracts(self):
        values = policy.authenticate_successful_history()
        self.assertEqual(values["thin-strong"]["contract"]["checks"], 246)
        self.assertEqual(values["effective-hits"]["contract"]["checks"], 9461)
        self.assertEqual(values["effective-hits"]["contract"]["hit_samples"], 4620)
        self.assertEqual([values[p]["contract"]["primary_cases"] for p in policy.original.BATCH_SCENARIOS], [8,9,9])
        self.assertEqual(values["placement"]["contract"]["checks"], 9)

    def test_actual_4049_identity_and_22_receipts_accept(self):
        cfg = policy.authenticate_base()
        result = policy.authenticate_old(cfg)
        self.assertEqual(len(result["old_pass_receipts"]), 22)
        self.assertEqual(result["old_supervisor_failure"]["supervisor_status"], "FAILED_UNCHANGED")
        self.assertEqual(result["thin_contract"]["checks"], 51)

    def test_actual_246_report_has_40_native_frames_56_pngs(self):
        path = policy.ROOT/"runs/BTH-ENVART-HIDDENR2-20261114-thin-wrap02/evidence/thin_wrap_probe.json"
        result = policy.strong_thin_contract(policy.guard.read_json(path))
        self.assertEqual(result["native_bob_frames"], 40)
        self.assertEqual(len(result["expected_pngs"]), 56)

    def test_stronger_thin_rejects_wrong_native_frame(self):
        path = policy.ROOT/"runs/BTH-ENVART-HIDDENR2-20261114-thin-wrap02/evidence/thin_wrap_probe.json"
        report = policy.guard.read_json(path)
        self.assertEqual(policy.strong_thin_contract(report)["checks"],246)
        report["glints"][0]["bob"]["samples"][0]["native_frame_index"] = 7
        with self.assertRaisesRegex(ValueError, "native atlas-frame"):
            policy.strong_thin_contract(report)

    def test_stronger_thin_rejects_no_vertical_bob(self):
        path = policy.ROOT/"runs/BTH-ENVART-HIDDENR2-20261114-thin-wrap02/evidence/thin_wrap_probe.json"
        report = policy.guard.read_json(path)
        self.assertEqual(policy.strong_thin_contract(report)["checks"],246)
        report["glints"][2]["bob"]["centroid_y_span_pixels"] = 0
        with self.assertRaisesRegex(ValueError, "vertical-bob"):
            policy.strong_thin_contract(report)

    def test_hits_original_json_roundtrip_scope_accepts_pre_differences(self):
        path = policy.ROOT/"runs/BTH-ENVART-HIDDENR2-20261114-hits02/evidence/hidden_effective_hit_proof.json"
        report = policy.guard.read_json(path)
        self.assertTrue(all(row["layout_evidence"]["pre_serialization_differences"] for row in report["contexts"]))
        self.assertTrue(all(not row["layout_evidence"]["post_serialization_differences"] for row in report["contexts"]))
        result = policy.remaining_contract("effective-hits",report)
        self.assertFalse(result["raw_current_prior_bitwise_equality_claimed"])
        self.assertEqual(result["hit_samples"], 4620)

    def test_hits_filtered_diagnostic_is_rejected(self):
        path = policy.ROOT/"runs/BTH-ENVART-HIDDENR2-20261114-hits02/evidence/hidden_effective_hit_proof.json"
        report = policy.guard.read_json(path)
        self.assertEqual(policy.remaining_contract("effective-hits",report)["checks"],9461)
        report["batch_scope"]["requested_case"] = "__none"
        with self.assertRaisesRegex(ValueError, "unfiltered"):
            policy.remaining_contract("effective-hits",report)

    def test_hits_prior_geometry_failure_is_rejected(self):
        path = policy.ROOT/"runs/BTH-ENVART-HIDDENR2-20261114-hits02/evidence/hidden_effective_hit_proof.json"
        report = policy.guard.read_json(path)
        self.assertEqual(policy.remaining_contract("effective-hits",report)["checks"],9461)
        report["contexts"][0]["prior_layout_equal"] = False
        with self.assertRaises(ValueError):
            policy.remaining_contract("effective-hits",report)

    def test_hits_ordered_candidate_change_is_rejected(self):
        path = policy.ROOT/"runs/BTH-ENVART-HIDDENR2-20261114-hits02/evidence/hidden_effective_hit_proof.json"
        report = policy.guard.read_json(path)
        self.assertEqual(policy.remaining_contract("effective-hits",report)["checks"],9461)
        report["contexts"][0]["hit_samples"][0]["pack_hit_ids"] = ["wrong"]
        with self.assertRaisesRegex(ValueError, "ordered hit"):
            policy.remaining_contract("effective-hits",report)

    def test_both_transports_reverse_to_exact_original_bytes(self):
        for phase in ("thin-strong", "effective-hits"):
            with self.subTest(phase=phase):
                active, proof = policy.transported_observer(phase,policy.RUN_PREFIX)
                for operation in reversed(proof["operations"]):
                    active = active.replace(b'"'+operation["active_literal"].encode()+b'"',
                                            b'"'+operation["original_literal"].encode()+b'"')
                self.assertEqual(hashlib.sha256(active).hexdigest(),proof["original_sha256"])
                self.assertTrue(proof["nonliteral_bytes_unchanged"])
                self.assertTrue(proof["assertions_and_normalization_unchanged"])
                self.assertFalse(proof["project_source_written"])

    def test_transport_only_hits_has_three_quoted_operations(self):
        thin, thin_proof = policy.transported_observer("thin-strong",policy.RUN_PREFIX)
        hits, hit_proof = policy.transported_observer("effective-hits",policy.RUN_PREFIX)
        self.assertEqual(thin_proof["operations"], [])
        self.assertEqual(hashlib.sha256(thin).hexdigest(),thin_proof["original_sha256"])
        self.assertEqual(len(hit_proof["operations"]),3)
        self.assertIn(policy.old_evidence("contexts").as_posix().encode(),hits)
        self.assertIn((policy.ROOT/"runs"/(policy.RUN_PREFIX+"-work-")).as_posix().encode(),hits)
        self.assertNotIn((policy.ROOT/"runs"/(policy.BASE_PREFIX+"-work-")).as_posix().encode(),hits)

    def test_wrong_fresh_transport_prefix_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "fresh continuation prefix"):
            policy.transported_observer("effective-hits",policy.BASE_PREFIX)

    def test_changed_transport_catalog_is_rejected(self):
        with patch.object(policy.guard,"sha",return_value="0"*64):
            with self.assertRaisesRegex(ValueError, "transport catalog"):
                policy.transport_catalog()

    def test_old_pass_receipt_appearance_is_rejected(self):
        class Present:
            def __truediv__(self, name):
                return self
            def exists(self):
                return True
        with self.assertRaisesRegex(ValueError,"without PASS receipt"):
            policy.require_old_failure_absent(Present())


class SeparateControllerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import hidden_spatial_native_completion_v2 as completion
        cls.runner = completion
        cls.old = policy.guard.read_json(policy.old_evidence("identity")/"trial-inputs.json")["source_config"]

    def test_exact_eight_explicit_phases(self):
        self.assertEqual(self.runner.PHASES,
            ("thin-qualify","thin-strong","work-highstakes","work-greased","work-muscle",
             "effective-hits","placement","completion-summary"))
        self.assertEqual(len(self.runner.ENGINE_PHASES),6)
        self.assertEqual(self.runner.FILE_PHASES,{"thin-qualify","completion-summary"})

    def test_commands_keep_original_project_and_fresh_outputs(self):
        cfg = {"base_config":self.old,"run_prefix":policy.RUN_PREFIX,"timeout":1200}
        for phase in self.runner.ENGINE_PHASES:
            evidence = self.runner.evidence_for(cfg,phase)
            cmd = self.runner.command(cfg,phase,evidence)
            self.assertEqual(cmd[cmd.index("--path")+1],str(policy.PROJECT))
            self.assertIn("--out="+str(evidence),cmd)
            self.assertFalse(any(token.startswith("--hidden-hit-case=") for token in cmd))
            if phase in ("thin-strong","effective-hits"):
                self.assertEqual(cmd[cmd.index("--script")+1],str(self.runner.observer_path(evidence,phase)))

    def test_qualifier_never_launches_engine(self):
        with patch.object(self.runner,"verify_readonly",return_value={"custody":"pinned"}), \
             patch.object(policy.guard,"execute") as execute:
            value = self.runner.qualify_worker({})
            execute.assert_not_called()
        self.assertFalse(value["engine_restarted"])
        self.assertFalse(value["stronger246_coverage_inferred"])
        self.assertFalse(value["old_phase_result_written"])

    def test_summary_honestly_counts_extra_observation(self):
        records = {p:{"artifacts":{"contract":{}}} for p in self.runner.PHASES[:-1]}
        for phase, scenario in policy.original.BATCH_SCENARIOS.items():
            records[phase]["artifacts"]["contract"]["case_ids"] = [n for n in policy.original.CASE_IDS if n.startswith(scenario+"__")]
        cfg = {"run_prefix":policy.RUN_PREFIX,"controller_sha256":"c"*64}
        with patch.object(self.runner,"previous",side_effect=lambda cfg,p:records[p]), \
             patch.object(self.runner,"verify_readonly"), patch.object(policy.guard,"sha",return_value="a"*64):
            result = self.runner.summary_worker(cfg)
        self.assertEqual(result["total_observations_including_extra"],30)
        self.assertEqual(result["nominal_original_phases_including_summary"],29)
        self.assertEqual(result["old_pass_observations"],22)
        self.assertEqual(result["qualified_existing_51_observations"],1)
        self.assertEqual(result["fresh_stronger_246_extra_observations"],1)
        self.assertEqual(result["fresh_original_remaining_engine_observations"],5)
        self.assertFalse(result["old_failed_supervisor_receipt_created"])
        self.assertFalse(result["art_approval"])
        self.assertTrue(result["controller_not_in_runtime_source_commit"])

    def test_all_new_receipts_have_distinct_schema_and_new_prefix(self):
        self.assertNotEqual(policy.PHASE_SCHEMA,policy.base.PHASE_SCHEMA)
        cfg = {"run_prefix":policy.RUN_PREFIX}
        for p in self.runner.PHASES:
            path = self.runner.evidence_for(cfg,p)
            self.assertIn(policy.RUN_PREFIX,str(path))
            self.assertNotIn(policy.BASE_PREFIX,str(path))

    def test_launch_requires_storage_prepare_and_engine_admission(self):
        source = Path(self.runner.__file__).read_text()
        main = next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=="main")
        body = ast.get_source_segment(source,main)
        self.assertLess(body.index("guard.prepare_layout(layout)"),body.index("materialize_observer(cfg,phase,layout)"))
        self.assertLess(body.index("guard.prepare_layout(layout)"),body.index("guard.execute(layout,cmd"))
        self.assertIn("with base.engine_admission(args.engine_go):",body)
        self.assertIn("cpu_rate=1200",body)
        self.assertIn("job[\"limits\"][\"kill_on_close\"] is True",body)
        self.assertIn("job[\"limits\"][\"breakaway_allowed\"] is False",body)

    def test_no_controller_library_patches_cleanup_or_old_writes(self):
        source = Path(self.runner.__file__).read_text()
        for token in ("base.main(", "unlink(", "rmtree(", "shutil.", "os.replace(", "os.rename("):
            self.assertNotIn(token,source)
        tree = ast.parse(source)
        for node in ast.walk(tree):
            if isinstance(node,ast.Assign):
                for target in node.targets:
                    if isinstance(target,ast.Attribute):
                        self.assertTrue(allowed_bytecode_assignment(node,target), ast.dump(target))
        self.assertIn('with path.open("xb") as handle:',source)
        self.assertIn('guard.write_new(layout.evidence/"phase-result.json",receipt)',source)
        self.assertNotIn('guard.write_new(policy.old_evidence(',source)

    def test_engine_phase_admission_is_not_implicit_in_plan(self):
        args = self.runner.parse_args(["plan","--run-prefix",policy.RUN_PREFIX])
        self.assertFalse(args.engine_go)
        self.assertFalse(args.worker)
        for phase in self.runner.PHASES:
            self.assertEqual(self.runner.prerequisites(phase),self.runner.PHASES[:self.runner.PHASES.index(phase)])



    def test_actual_config_pins_external_controller_separately(self):
        args = self.runner.parse_args(["plan","--run-prefix",policy.RUN_PREFIX])
        cfg = self.runner.config(args)
        self.assertEqual(cfg["runtime_source_files"],4049)
        self.assertEqual(cfg["runtime_identity_sha256"],policy.IDENTITY_SHA)
        self.assertEqual(cfg["source_commit"],policy.SOURCE_COMMIT)
        self.assertTrue(cfg["controller_is_not_in_runtime_source_commit"])
        self.assertEqual(cfg["transport_catalog_sha256"],policy.TRANSPORT_CATALOG_SHA)
        self.assertNotEqual(cfg["run_prefix"],cfg["base_config"]["run_prefix"])

    def _closed_fixture(self):
        phase = "work-highstakes"
        cfg = {"base_config":self.old,"run_prefix":policy.RUN_PREFIX,"timeout":1200,
               "controller_sha256":"c"*64,"old_custody":{}}
        evidence = self.runner.evidence_for(cfg,phase)
        command = self.runner.command(cfg,phase,evidence)
        manifest = {"schema":"bth-qa-storage/v1","prepared":True,"expected_write_bytes":4*1024**3,
                    "reserve_bytes":20*1024**3,"paths":{"workspace":str(policy.PROJECT),"evidence":str(evidence)}}
        job = {"schema":"bth.qa_guarded_run/v1","finished_epoch":1794842870.3586524,
               "exit_code":0,"active_at_release":0,"assigned_before_execution":True,
               "error":None,"cleanup_errors":[],"timed_out":False,"log_error":None,"log_truncated":False,
               "storage_gate_before_job":{"owned":True},"storage_gate_before_child":{"owned":True},
               "limits":{"cpu_rate":1200,"job_memory_limit_bytes":2*1024**3,"kill_on_close":True,"breakaway_allowed":False},
               "command":command,"timeout_seconds":1200,"storage":manifest,
               "storage_manifest":str(evidence/"storage-manifest.json"),"storage_manifest_sha256":"a"*64}
        inputs = {"source_config":cfg,"source_config_sha256":policy.guard.fingerprint(cfg),
                  "command":command,"engine_campaign_admission":True}
        record = {"schema":policy.PHASE_SCHEMA,"phase":phase,"status":"PASS",
                  "source_config_sha256":policy.guard.fingerprint(cfg),"controller_sha256":"c"*64,
                  "runtime_source_commit":policy.SOURCE_COMMIT,"runtime_source_tree":policy.SOURCE_TREE,
                  "old_supervisor_status":"FAILED_UNCHANGED","old_phase_result_written":False,
                  "job_sha256":"a"*64,"log_sha256":"a"*64,"custody_before":{},"custody_after":{},
                  "artifact_sha256":{"report.json":"b"*64}}
        values = {"job.json":job,"phase-result.json":record,"trial-inputs.json":inputs,
                  "storage-manifest.json":manifest,"launch-claim.json":{"manifest_sha256":"a"*64}}
        self.assertTrue(policy.selected.qualified_job(job), "Unmutated real-schema Job fixture must qualify")
        self.assertEqual(self._read_closed(cfg,phase,values)["status"], "PASS")
        return cfg, phase, values

    def _read_closed(self, cfg, phase, values):
        with patch.object(policy.guard,"read_json",side_effect=lambda p:values[Path(p).name]), \
             patch.object(policy.guard,"sha",return_value="a"*64), \
             patch.object(Path,"read_text",return_value=""), \
             patch.object(self.runner,"payload_inventory",return_value={"report.json":"b"*64}):
            return self.runner.previous(cfg,phase)

    def test_new_closed_receipt_requires_real_job_closure(self):
        cfg,phase,values = self._closed_fixture()
        self.assertEqual(self._read_closed(cfg,phase,values)["status"],"PASS")
        values["job.json"]["active_at_release"] = 1
        with self.assertRaises(ValueError):
            self._read_closed(cfg,phase,values)

    def test_new_receipt_rejects_weakened_caps_or_kill_policy(self):
        for key,value in (("cpu_rate",1500),("job_memory_limit_bytes",4*1024**3),
                          ("kill_on_close",False),("breakaway_allowed",True)):
            cfg,phase,values = self._closed_fixture()
            values["job.json"]["limits"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self._read_closed(cfg,phase,values)

    def test_new_receipt_rejects_source_or_controller_identity_change(self):
        for key in ("runtime_source_commit","controller_sha256"):
            cfg,phase,values = self._closed_fixture()
            values["phase-result.json"][key] = "0"*64
            with self.subTest(key=key), self.assertRaises(ValueError):
                self._read_closed(cfg,phase,values)

    def test_new_receipt_rejects_mutated_old_status_or_artifact(self):
        for key,value in (("old_supervisor_status","PASS"),("old_phase_result_written",True),
                          ("artifact_sha256",{"report.json":"changed"})):
            cfg,phase,values = self._closed_fixture()
            values["phase-result.json"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self._read_closed(cfg,phase,values)

    def test_new_receipt_rejects_missing_explicit_engine_admission(self):
        cfg,phase,values = self._closed_fixture()
        values["trial-inputs.json"]["engine_campaign_admission"] = False
        with self.assertRaises(ValueError):
            self._read_closed(cfg,phase,values)



class SerializedThinWitnessTests(unittest.TestCase):
    def valid_report(self):
        report = policy.guard.read_json(policy.STRONG_THIN_WITNESS)
        self.assertEqual(policy.strong_thin_contract(report)["checks"],246)
        return report

    def test_actual_raw_double_and_serialized_witness_are_distinct(self):
        report = self.valid_report()
        spec = policy.guard.read_json(policy.PROJECT/policy.original.MANIFEST)
        source = next(row for row in spec["animations"] if row["id"]=="thin_bobbing_ribbon_0")
        self.assertNotEqual(source["fps"],report["glints"][0]["source_manifest_entry"]["fps"])
        self.assertNotEqual(source["opacity"],report["glints"][0]["source_manifest_entry"]["opacity"])
        self.assertEqual(policy.guard.sha(policy.PROJECT/policy.original.MANIFEST),policy.MANIFEST_SHA)

    def test_raw_double_substitution_cannot_replace_serialized_source_entry(self):
        report = self.valid_report()
        spec = policy.guard.read_json(policy.PROJECT/policy.original.MANIFEST)
        raw = next(row for row in spec["animations"] if row["id"]==report["glints"][0]["id"])
        self.assertNotEqual(raw["fps"],report["glints"][0]["source_manifest_entry"]["fps"])
        report["glints"][0]["source_manifest_entry"]["fps"] = raw["fps"]
        with self.assertRaisesRegex(ValueError,"source/wrap/RM"):
            policy.strong_thin_contract(report)

    def test_bob_source_fps_uses_exact_serialized_witness(self):
        report = self.valid_report()
        original = report["glints"][0]["bob"]["source_fps"]
        report["glints"][0]["bob"]["source_fps"] = original+1e-14
        self.assertNotEqual(report["glints"][0]["bob"]["source_fps"],original)
        with self.assertRaisesRegex(ValueError,"vertical-bob"):
            policy.strong_thin_contract(report)

    def test_bob_source_phase_uses_exact_serialized_witness(self):
        report = self.valid_report()
        original = report["glints"][2]["bob"]["source_phase"]
        report["glints"][2]["bob"]["source_phase"] = original+1e-13
        self.assertNotEqual(report["glints"][2]["bob"]["source_phase"],original)
        with self.assertRaisesRegex(ValueError,"vertical-bob"):
            policy.strong_thin_contract(report)

    def test_witness_requires_exact_current_raw_manifest_hash(self):
        self.assertEqual(len(policy.serialized_thin_witness()),5)
        actual = policy.guard.sha
        manifest = policy.PROJECT/policy.original.MANIFEST
        with patch.object(policy.guard,"sha",side_effect=lambda p:"0"*64 if Path(p)==manifest else actual(p)):
            with self.assertRaisesRegex(ValueError,"current raw manifest hash"):
                policy.serialized_thin_witness()

    def test_witness_payload_hash_change_is_rejected(self):
        self.assertEqual(len(policy.serialized_thin_witness()),5)
        actual = policy.guard.sha
        with patch.object(policy.guard,"sha",side_effect=lambda p:"0"*64 if Path(p)==policy.STRONG_THIN_WITNESS else actual(p)):
            with self.assertRaisesRegex(ValueError,"serialized7192 witness"):
                policy.serialized_thin_witness()

    def test_witness_requires_exact_original_observer_and_godot(self):
        self.assertEqual(len(policy.serialized_thin_witness()),5)
        actual = policy.guard.sha
        source = policy.original.LEGACY/policy.transport_catalog()["transports"]["thin-strong"]["source"]
        for target in (source,policy.GODOT_CONSOLE):
            with self.subTest(target=str(target)), patch.object(policy.guard,"sha",side_effect=lambda p:"0"*64 if Path(p)==target else actual(p)):
                with self.assertRaisesRegex(ValueError,"Original865 observer and exact Godot"):
                    policy.serialized_thin_witness()

    def test_serialized_source_fields_cannot_be_removed(self):
        report = self.valid_report()
        self.assertIn("opacity",report["glints"][0]["source_manifest_entry"])
        del report["glints"][0]["source_manifest_entry"]["opacity"]
        with self.assertRaisesRegex(ValueError,"source/wrap/RM"):
            policy.strong_thin_contract(report)

    def test_ast_attribute_exception_is_only_exact_bytecode_true(self):
        node = ast.parse("sys.dont_write_bytecode = True").body[0]
        self.assertTrue(allowed_bytecode_assignment(node,node.targets[0]))
        for source in ("sys.dont_write_bytecode = False","sys.dont_write_bytecode = 1",
                       "base.command = replacement","guard.execute = replacement",
                       "policy.RUN_PREFIX = replacement","sys.other = True",
                       "sys.dont_write_bytecode = base.command = True"):
            node = ast.parse(source).body[0]
            with self.subTest(source=source):
                self.assertFalse(allowed_bytecode_assignment(node,node.targets[0]))

    def test_serialized_comparison_has_no_epsilon_or_type_coercion(self):
        self.assertTrue(policy.serialized_equal({"value":1.78253536262923},{"value":1.78253536262923}))
        self.assertFalse(policy.serialized_equal({"value":1.78253536262923},{"value":1.7825353626292277}))
        self.assertFalse(policy.serialized_equal({"value":8.0},{"value":8}))
        with self.assertRaises(ValueError):
            policy.serialized_equal({"value":float("nan")},{"value":float("nan")})


if __name__ == "__main__":
    unittest.main()
