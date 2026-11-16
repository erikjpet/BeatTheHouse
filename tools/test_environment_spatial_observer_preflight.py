"""Read-only actual archived positives plus focused in-memory negative controls.

Parent guarded execution only. No engine, child, temp, profile or evidence write.
Mocks replace only this new module's read boundary, never frozen room globals.
"""
import sys
sys.dont_write_bytecode=True
from copy import deepcopy
import ast
import json
import math
from pathlib import Path
import unittest
from unittest.mock import patch

import environment_spatial_observer_preflight as gate

CATALOG=gate.SOURCE_ROOT/"review_artifacts/environment_art_sources/environment-spatial-observer-preflight/catalog.json"

class ObserverPreflightChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=json.loads(CATALOG.read_text())
        cls.cases={row["case_id"]:row for row in cls.catalog["cases"]}
        # A mismatched real archive stops setup before any negative can pass.
        cls.positive_results={row["case_id"]:gate.preflight_case(row,gate.validator_from_catalog(row))
            for row in cls.catalog["cases"] if row["status"]=="PINNED_ACTUAL_ARCHIVE"}

    def invoke(self,spec=None,payload_changes=None):
        spec=deepcopy(self.cases["kitty-original-contexts"] if spec is None else spec)
        self.assertIn(spec["case_id"],self.positive_results)
        callback=gate.validator_from_catalog(spec)
        real=gate.read_ref
        replacements={str(spec[name]["path"]):data for name,data in (payload_changes or {}).items()}
        with patch.object(gate,"read_ref",side_effect=lambda ref:replacements.get(str(ref["path"]),None)
                if str(ref["path"]) in replacements else real(ref)):
            return gate.preflight_case(spec,callback)

    def report_bytes(self,spec=None):
        spec=self.cases["kitty-original-contexts"] if spec is None else spec
        return json.loads(gate.read_ref(spec["report"]))

    def test_all17_actual_archived_positives_use_unchanged_room_validators(self):
        cases=[row for row in self.catalog["cases"] if row["status"]=="PINNED_ACTUAL_ARCHIVE"]
        self.assertEqual(len(cases),17)
        for spec in cases:
            with self.subTest(case=spec["case_id"]):
                result=self.positive_results[spec["case_id"]]
                self.assertEqual(result["status"],"SERIALIZED_CONTRACT_POSITIVE_PASS")
                self.assertTrue(result["all_input_bytes_unchanged"])
                self.assertFalse(result["native_runtime_executed"])
                self.assertFalse(result["engine_admission_granted"])

    def test_actual_private_five_report_shapes_include_no_guessed_schema(self):
        for phase in ("contexts","motion","capture","lifecycle"):
            spec=self.cases["private-v3-"+phase]
            self.assertIsNone(spec["actual_schema"])
            self.assertNotIn("schema",self.report_bytes(spec))
        self.assertEqual(self.cases["private-v3-lucky-glyph"]["actual_schema"],"bth.private_spatial_acceptance/v1")

    def test_actual_write_names_are_bound_to_producers_and_jobs(self):
        for key,value in (("actual_written_filename","guessed_metadata.json"),
                ("producer_write_witness",'FileAccess.open("guessed_metadata.json",FileAccess.WRITE)'),
                ("producer_script_argument","res://tools/other_room.gd")):
            spec=deepcopy(self.cases["kitty-original-contexts"]);spec[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):
                self.invoke(spec)

    def test_wrong_schema_including_invented_null_is_rejected(self):
        for value in (None,"bth.invented/v1"):
            report=self.report_bytes();report["schema"]=value
            with self.subTest(value=value),self.assertRaises(ValueError):
                self.invoke(payload_changes={"report":json.dumps(report).encode()})

    def test_wrong_original_full_count_catalog_and_findings_are_rejected(self):
        for change in ("checks","catalog","finding"):
            report=self.report_bytes()
            if change=="checks":report["checks"]-=1
            elif change=="catalog":report["direct_catalog"].pop()
            else:report["findings"]=["original observer failure"]
            with self.subTest(change=change),self.assertRaises(ValueError):
                self.invoke(payload_changes={"report":json.dumps(report).encode()})

    def test_wrong_source_N_is_not_normalized_to_a_prior_room_count(self):
        spec=deepcopy(self.cases["kitty-original-contexts"])
        spec["validator"]["kwargs"]["source_files"]=7214
        with self.assertRaises(ValueError):
            self.invoke(spec)

    def test_serialized_Vector2_stays_string_and_is_not_a_native_target(self):
        result=self.invoke()
        observed=result["serialized_shapes"][0]
        self.assertEqual((observed["type"],observed["observed_count"]),("string",93))
        self.assertFalse(observed["native_type_inferred_from_JSON"])
        self.assertFalse(result["native_type_or_cross_representation_float_identity_inferred"])
        report=self.report_bytes()
        report["views"]["__none"]["actual_view"]["objects"][0]["position"]=[1,2]
        with self.assertRaises(ValueError):
            self.invoke(payload_changes={"report":json.dumps(report).encode()})

    def test_native_witness_declaration_does_not_become_Python_native_proof(self):
        result=self.invoke(self.cases["private-v3-lucky-glyph"])
        self.assertFalse(result["native_type_or_cross_representation_float_identity_inferred"])
        self.assertFalse(result["fresh_campaign_acceptance_or_art_or_TEST_approval"])

    def test_cross_boundary_numbers_are_exact_serialized_values_without_epsilon(self):
        self.assertNotEqual(gate.canonical(20),gate.canonical(20.0))
        self.assertNotEqual(gate.canonical(0.1),gate.canonical(math.nextafter(0.1,math.inf)))
        self.assertEqual(gate.canonical({"x":0.1,"y":"(1,2)"}),gate.canonical({"y":"(1,2)","x":0.1}))
        for value in (float("nan"),float("inf")):
            with self.assertRaises(ValueError):
                gate.canonical(value)

    def test_wrong_report_producer_or_validator_hash_is_rejected(self):
        for key in ("report","producer","job","log"):
            spec=deepcopy(self.cases["kitty-original-contexts"]);spec[key]["sha256"]="0"*64
            with self.subTest(key=key),self.assertRaises(ValueError):
                self.invoke(spec)
        spec=deepcopy(self.cases["kitty-original-contexts"]);spec["validator"]["source"]["sha256"]="0"*64
        with self.assertRaises(ValueError):
            self.invoke(spec)

    def test_no_foreign_or_wrapped_validator_callable(self):
        spec=self.cases["kitty-original-contexts"]
        with self.assertRaises(ValueError):
            gate.preflight_case(spec,lambda report:True)
        wrong=deepcopy(spec);wrong["validator"]["function"]="capture_contract"
        with self.assertRaises((ValueError,AttributeError)):
            self.invoke(wrong)

    def test_closed_job_state_caps_cleanup_and_complete_logs_required(self):
        spec=self.cases["kitty-original-contexts"]
        original=json.loads(gate.read_ref(spec["job"]))
        for key,value in (("exit_code",1),("active_at_release",1),("timed_out",True),("error","failure"),
                ("cleanup_errors",["failure"]),("log_truncated",True),("log_error","drain failed"),("assigned_before_execution",False)):
            job=deepcopy(original);job[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):
                self.invoke(payload_changes={"job":json.dumps(job).encode()})
        for key,value in (("cpu_rate",1500),("job_memory_limit_bytes",4*1024**3),("kill_on_close",False),("breakaway_allowed",True)):
            job=deepcopy(original);job["limits"][key]=value
            with self.subTest(limit=key),self.assertRaises(ValueError):
                self.invoke(payload_changes={"job":json.dumps(job).encode()})

    def test_ERROR_even_with_exit_zero_is_rejected(self):
        for log in (b"ERROR: invalid Color\n",b"SCRIPT ERROR: Invalid call\n"):
            with self.subTest(log=log),self.assertRaises(ValueError):
                self.invoke(payload_changes={"log":log})

    def test_actual_project_and_unique_path_script_pair_are_required(self):
        original=json.loads(gate.read_ref(self.cases["kitty-original-contexts"]["job"]))
        for change in ("foreign_project","duplicate_path","duplicate_script"):
            job=deepcopy(original);command=job["command"]
            if change=="foreign_project":command[command.index("--path")+1]=str(gate.QA_ROOT/"workspaces/BTH-ENVART-DELTA-TRIAL-20261115")
            elif change=="duplicate_path":command.extend(["--path",command[command.index("--path")+1]])
            else:command.extend(["--script",command[command.index("--script")+1]])
            with self.subTest(change=change),self.assertRaises((ValueError,OSError)):
                self.invoke(payload_changes={"job":json.dumps(job).encode()})

    def test_exact_bytes_are_rechecked_after_the_positive_validator(self):
        spec=self.cases["kitty-original-contexts"]
        callback=gate.validator_from_catalog(spec);real=gate.read_ref;reads={}
        def changing(ref):
            name=str(ref["path"]);reads[name]=reads.get(name,0)+1
            data=real(ref)
            return data+b" " if name==str(spec["report"]["path"]) and reads[name]>1 else data
        with patch.object(gate,"read_ref",side_effect=changing),self.assertRaises(ValueError):
            gate.preflight_case(spec,callback)

    def test_pending_or_fixture_is_not_an_actual_positive(self):
        callback=gate.validator_from_catalog(self.cases["kitty-original-contexts"])
        for key,value in (("status","NOT_YET_PRODUCED"),("fixture",True)):
            spec=deepcopy(self.cases["kitty-original-contexts"]);spec[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):
                gate.preflight_case(spec,callback)

    def test_requested_positive_subset_keeps_fresh_cases_unproved(self):
        result=gate.preflight_room(self.catalog,"kitty",["kitty-original-motion"])
        self.assertEqual(result["status"],"REQUESTED_ARCHIVE_POSITIVES_PASS")
        self.assertFalse(result["entire_catalog_room_scope_requested"])
        self.assertEqual(result["unproved_cases"][0]["status"],"NOT_YET_PRODUCED")
        self.assertFalse(result["native_execution_or_engine_admission"])
        result=gate.preflight_room(self.catalog,"kitty",["kitty-spatial-fresh-native"])
        self.assertEqual(result["status"],"INCOMPLETE_SCOPE")
        self.assertEqual(result["positive_cases"],[])

    def test_missing_duplicate_or_foreign_requested_cases_rejected(self):
        for requested in ([],["missing"],["kitty-original-motion"]*2,["private-v3-motion"]):
            with self.subTest(requested=requested),self.assertRaises(ValueError):
                gate.preflight_room(self.catalog,"kitty",requested)

    def test_JSON_shapes_have_exact_cardinality_and_no_bool_number_coercion(self):
        rule={"path":["rows","*","value"],"type":"number","count":2,"representation":"SERIALIZED_JSON_ONLY"}
        self.assertEqual(gate.shape_contract({"rows":[{"value":1},{"value":2.0}]},[rule])[0]["observed_count"],2)
        for report in ({"rows":[]},{"rows":[{"value":True},{"value":2}]},{"rows":[{"wrong":1},{"value":2}]}):
            with self.assertRaises(ValueError):
                gate.shape_contract(report,[rule])

    def test_shared_negative_controls_run_after_actual_positive_and_reject_noop(self):
        spec=self.cases["kitty-original-contexts"]
        callback=gate.validator_from_catalog(spec)
        result=gate.positive_then_controls(spec,callback,[{"name":"wrong_total","path":["checks"],"value":-1},
            {"name":"wrong_native_JSON_shape","path":["views","__none","actual_view","objects",0,"position"],"value":[1,2]}])
        self.assertEqual(len(result["negative_controls"]),2)
        self.assertTrue(all(row["rejected"] for row in result["negative_controls"]))
        self.assertTrue(result["controls_are_in_memory_fixtures_not_native_evidence"])
        with self.assertRaises(ValueError):
            gate.positive_then_controls(spec,callback,[{"name":"noop","path":["checks"],"value":15164}])
        bad=deepcopy(spec);bad["validator"]["kwargs"]["source_files"]=1
        with self.assertRaises(ValueError):
            gate.positive_then_controls(bad,callback,[{"name":"wrong_total","path":["checks"],"value":-1}])

    def test_only_source_or_QA_artifacts_not_profiles_or_C_drive(self):
        with self.assertRaises((ValueError,OSError)):
            gate.read_ref({"path":"C:/Windows/System32/cmd.exe","sha256":"0"*64})
        with self.assertRaises((ValueError,OSError)):
            gate.read_ref({"path":"E:/CodexQA/BTH/runs/not-a-profile/profile/user.save","sha256":"0"*64})

    def test_preflight_calls_original_validator_before_shape_checks(self):
        tree=ast.parse(Path(gate.__file__).read_text())
        function=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=="serialized_contract")
        source=ast.get_source_segment(Path(gate.__file__).read_text(),function)
        self.assertLess(source.index("result=validator("),source.index("observed=shape_contract("))
        calls={n.func.id if isinstance(n.func,ast.Name) else n.func.attr for n in ast.walk(tree)
            if isinstance(n,ast.Call) and isinstance(n.func,(ast.Name,ast.Attribute))}
        self.assertFalse(calls&{"Popen","execute","prepare_layout","mkdir","unlink","rmdir","open"})

if __name__=="__main__":
    unittest.main()
