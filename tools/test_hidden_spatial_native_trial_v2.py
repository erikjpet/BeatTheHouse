"""Focused read-only tests for Hidden source transport and acceptance contracts.

Supplied, not run by the code author. Run later only in the admitted capped QA
campaign. No temporary directories, cleanup, deletion, helper/engine launch or
filesystem writes occur in these tests. Historical JSON fixtures remain read-only.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import hashlib
import json
from pathlib import Path, PurePosixPath
import stat
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import hidden_spatial_native_profile_v2 as policy
import hidden_spatial_native_trial_v2 as runner

PREVIOUS_TESTS_SHA = "6605f2e8005dee79200ae90cf8294c96e577679850bcf6734b8eeda90b9f5cc7"
RUNS = Path("E:/CodexQA/BTH/runs")
PREFIX = "BTH-ENVART-HIDDENR2-20261114-"


def retained(suffix, name):
    return json.loads((RUNS / (PREFIX + suffix) / "evidence" / name).read_bytes())


class Node:
    """In-memory ordinary tree; no filesystem fixture or cleanup."""
    def __init__(self, name, entries, digest="a"*64):
        self.name, self.entries, self.digest = name, entries, digest
    def __lt__(self, other):
        return self.name < other.name
    def is_dir(self):
        return self.name == "" or self.entries[self.name] == "dir"
    def iterdir(self):
        prefix = self.name + "/" if self.name else ""
        return iter(Node(n, self.entries) for n in self.entries
                    if n.startswith(prefix) and "/" not in n[len(prefix):])
    def relative_to(self, root):
        return PurePosixPath(self.name)
    def lstat(self):
        return SimpleNamespace(st_mode=stat.S_IFDIR if self.is_dir() else stat.S_IFREG)
    def __str__(self):
        return "memory-tree/" + self.name


class PhysicalClosureTests(unittest.TestCase):
    def check(self, entries, expected):
        root = Node("", entries)
        with patch.object(policy, "plain", side_effect=lambda p:p), patch.object(policy, "sha", side_effect=lambda p:p.digest):
            return policy.inventory_all(root, expected)
    def test_exact_payload_and_root_sentinel(self):
        result = self.check({"assets":"dir","assets/a.png":"file",".gdignore":"file"},
                            {"assets/a.png",".gdignore"})
        self.assertEqual(set(result), {"assets/a.png",".gdignore"})
    def test_nested_sentinel_rejected(self):
        with self.assertRaises(ValueError):
            self.check({"assets":"dir","assets/a.png":"file","assets/.gdignore":"file",".gdignore":"file"},
                       {"assets/a.png",".gdignore"})
    def test_unknown_empty_directory_rejected(self):
        with self.assertRaises(ValueError):
            self.check({"assets":"dir","assets/a.png":"file","unused":"dir"},
                       {"assets/a.png"})
    def test_missing_payload_rejected(self):
        with self.assertRaises(ValueError):
            self.check({"assets":"dir"}, {"assets/a.png"})
    def test_canonical_import_missing_fails_without_copy(self):
        with patch.object(policy,"plain",side_effect=FileNotFoundError("missing committed import")):
            with self.assertRaises(FileNotFoundError):
                policy.canonical_imports(Path("E:/read-only-unmaterialized-project"))


class SourceTransportTests(unittest.TestCase):
    def setUp(self):
        self.cfg = {"qa_root":"E:/CodexQA/BTH","run_prefix":"READ_ONLY_TEST_BINDING"}
    def test_only_full_quoted_historical_paths_translate(self):
        name = "tools/envart_hidden_effective_hits_r2.gd"
        original = (policy.LEGACY/name).read_bytes()
        active, operations = policy.transport_bytes(name,original,policy.literal_bindings(self.cfg))
        expected = original.replace(b"\r\n",b"\n")
        for op in operations:
            expected = expected.replace(('"'+op["original_literal"]+'"').encode(),
                                        ('"'+op["active_literal"]+'"').encode())
        self.assertEqual(active,expected)
        self.assertEqual(len(operations),3)
        self.assertIn(policy.LEGACY_CANVAS_SHA.encode(),active)
        self.assertIn(b'["highstakes","greased","muscle"]',active)
    def test_injected_literal_is_rejected(self):
        name = "tools/envart_hidden_initial_r2.gd"
        original = (policy.LEGACY/name).read_bytes()
        before = next(iter(policy.literal_bindings(self.cfg)[name]))
        for new in ('bad"\ncode','bad\\','bad\r','bad\0'):
            with self.subTest(new=repr(new)), self.assertRaises(ValueError):
                policy.transport_bytes(name,original,{name:{before:new}})
    def test_absent_literal_is_rejected(self):
        name = "tools/envart_hidden_initial_r2.gd"
        with self.assertRaises(ValueError):
            policy.transport_bytes(name,(policy.LEGACY/name).read_bytes(),{name:{"not a historical input":"res://new.json"}})
    def test_original_gd_byte_pin_is_enforced(self):
        name = "tools/envart_hidden_initial_r2.gd"
        with self.assertRaises(ValueError):
            policy.transport_bytes(name,(policy.LEGACY/name).read_bytes()+b"\n",{})
    def test_catalog_rebind_retains_every_case_command_and_assertion_field(self):
        original=json.loads((policy.LEGACY/policy.CATALOG_PATH).read_bytes())
        current={name:("a"*64) for name in original["source_files_sha256"]}
        current[original["source"]]=policy.CATALOG_SOURCE_SHA
        value=policy.rebind_catalog(original,current,"E:/read-only-authenticated-selected-source")
        self.assertEqual(value["cases"],original["cases"])
        self.assertEqual(value["source_branch_routes"],original["source_branch_routes"])
        self.assertEqual(value["scenarios"],original["scenarios"])
        self.assertEqual(policy.case_ids(value),policy.CASE_IDS)
        self.assertNotEqual(value["source_files_sha256"],original["source_files_sha256"])
    def test_changed_case_facts_or_bad_hash_metadata_rejected(self):
        original=json.loads((policy.LEGACY/policy.CATALOG_PATH).read_bytes())
        current=dict(original["source_files_sha256"])
        for changed in ("source", "counts", "hash"):
            mutated=deepcopy(original)
            hashes=dict(current)
            if changed=="source":
                hashes[original["source"]]="a"*64
            elif changed=="counts":
                mutated["counts"]["primary_cases"]=25
            else:
                hashes["scripts/core/run_state.gd"]="not-an-authenticated-sha256"
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                policy.rebind_catalog(mutated,hashes,"E:/read-only-project")


class RoomContractTests(unittest.TestCase):
    def test_initial_objects_are_distinct_from_typed_pairs(self):
        initial=retained("current4-01","hidden_r2_initial_metadata.json")
        result=policy.report_contract("contexts",initial,source_files=863)
        self.assertEqual(result,{"initial_objects":71,"selected_labels":71,"typed_pairs_in_this_report":0})
        paint=retained("source-paint01","hidden_source_paint.json")
        self.assertEqual(policy.report_contract("source-paint",paint)["typed_object_pairs"],71)
        with self.assertRaises((ValueError,KeyError)):
            policy.report_contract("source-paint",initial)
    def test_original_31_motion_63_checks(self):
        report=retained("probe01","hidden_animation_probe.json")
        self.assertEqual(policy.report_contract("motion",report)["native_entries"],31)
        mutated=deepcopy(report);mutated["checks"]=66
        with self.assertRaises(ValueError):
            policy.report_contract("motion",mutated)
        mutated=deepcopy(report);mutated["entries"]=mutated["entries"][:16]
        with self.assertRaises(ValueError):
            policy.report_contract("motion",mutated)
    def test_real_room_acceptance_counts(self):
        cases=[("current-rm","current-rm01","hidden_r2_current_rm_metadata.json"),
               ("full-composite","composite01","hidden_full_composite.json"),
               ("full-composite-rm","composite-rm01","hidden_full_composite_rm.json"),
               ("counter-replay","counter01","hidden_counter_replay.json"),
               ("floor-wrap","floor-wrap01","floor_wrap_probe.json"),
               ("long-wrap","long-wrap01","long_wrap_probe.json"),
               ("thin-wrap","thin-wrap02","thin_wrap_probe.json"),
               ("effective-hits","hits02","hidden_effective_hit_proof.json"),
               ("placement","placement01","hidden_placement_closing.json")]
        for phase,suffix,name in cases:
            with self.subTest(phase=phase):
                policy.report_contract(phase,retained(suffix,name),source_files=863)
    def test_all26_primary_cases_and_no_skip_alias(self):
        ids=[]
        for phase,suffix in (("work-highstakes","sequence-highstakes-01"),("work-greased","sequence-greased-01"),("work-muscle","sequence-muscle-01")):
            report=retained(suffix,"hidden_sequence_live_proof.json")
            ids += policy.report_contract(phase,report)["case_ids"]
            mutated=deepcopy(report)
            mutated["batch_scope"]["explicitly_skipped_case_ids"]=[report["completed"][0]]
            with self.subTest(phase=phase), self.assertRaises(ValueError):
                policy.report_contract(phase,mutated)
        self.assertEqual(ids,policy.CASE_IDS)
    def test_capture_uses_actual_31_inventory_32_core_frames(self):
        report=json.loads((RUNS/(PREFIX+"base01")/"evidence/frames/animation_capture.json").read_bytes())
        self.assertGreater(runner.capture_contract(report)["actual_clock_span"],11)
        mutated=deepcopy(report);mutated["frames"][1]["clock"]=mutated["frames"][0]["clock"]
        with self.assertRaises(ValueError):
            runner.capture_contract(mutated)
    def test_core_and_acceptance_are_separate_and_no_hidden_auto_chain(self):
        self.assertEqual(len(runner.CORE_PHASES),13)
        self.assertEqual(len(runner.ACCEPTANCE_PHASES),15)
        self.assertFalse(set(runner.CORE_PHASES)&set(runner.ACCEPTANCE_PHASES))
        self.assertEqual(runner.prerequisites("effective-hits"),["contexts",*policy.BATCH_SCENARIOS])
        self.assertEqual(set(runner.prerequisites("acceptance-summary")),
                         {"contexts","motion","liveness","capture",*runner.ACCEPTANCE_PHASES})
    def test_capture_default_is_float_and_worker_command_canonical(self):
        args=["plan"]
        for key,value in {"workspace":"E:/fixture","engine":"D:/fixture.exe","git":"D:/git.exe","git-dir":"D:/fixture.git",
                          "candidate-root":"E:/candidate","candidate-manifest":"E:/proof.json","review":"D:/review.json",
                          "source-commit":"a"*40,"source-tree":"b"*40,"run-prefix":"PURE_PARSE_FIXTURE"}.items():
            args+=["--"+key+"="+value]
        parsed=runner.parse_args(args)
        self.assertIs(type(parsed.capture_seconds),float)
        self.assertEqual(parsed.capture_seconds,20.0)
        self.assertEqual(len(policy.HELPERS),19)
        self.assertEqual(len(policy.CORE_HELPERS),5)



class CurrentRmSchemaRegressionTests(unittest.TestCase):
    """Source-specific RM canvas evidence must not masquerade as71 selections."""
    def fixture(self):
        return retained("current-rm01","hidden_r2_current_rm_metadata.json")

    def rejected(self, report, source_files=863):
        with self.assertRaises((ValueError,KeyError,TypeError)):
            policy.report_contract("current-rm",report,source_files=source_files)

    def test_actual_rm_schema_has71_canvas_labels_and_zero_selected_captures(self):
        report=self.fixture()
        self.assertTrue(all("selected_label_evidence" not in v for v in report["views"].values()))
        self.assertEqual(report["checks"],2126)
        self.assertEqual(policy.report_contract("current-rm",report,source_files=863),
            {"initial_objects":71,"actual_canvas_label_geometry":71,"selected_labels":0,
             "typed_pairs_in_this_report":0,"reduce_motion_enabled":True})

    def test_missing_or_wrong_typed_required_row_lists_are_rejected(self):
        paths=(("actual_canvas_evidence",),("actual_view","objects"),
               ("actual_view","object_layout","objects"))
        for path in paths:
            for mode in ("missing","dict","none","invalid_rows"):
                report=self.fixture();owner=report["views"]["__none"]
                for key in path[:-1]:
                    owner=owner[key]
                if mode=="missing":
                    del owner[path[-1]]
                else:
                    owner[path[-1]]={"dict":{},"none":None,"invalid_rows":[None]*12}[mode]
                with self.subTest(path=path,mode=mode):
                    self.rejected(report)

    def test_duplicate_mismatched_or_invented_canvas_records_are_rejected(self):
        for field in ("actual_canvas_evidence","objects","geometry","row_label","source_object","selected"):
            report=self.fixture();view=report["views"]["__none"]
            if field=="actual_canvas_evidence":
                view[field][-1]=deepcopy(view[field][0])
            elif field=="objects":
                view["actual_view"]["objects"][-1]=deepcopy(view["actual_view"]["objects"][0])
            elif field=="geometry":
                view["actual_view"]["object_layout"]["objects"][0]["id"]="invented:rm-geometry"
            elif field=="row_label":
                view["actual_canvas_evidence"][0]["label"]="Invented title"
            elif field=="source_object":
                view["actual_canvas_evidence"][0]["object"]["description"]="Unrelated source object"
            else:
                view["selected_label_evidence"]=[]
            with self.subTest(field=field):
                self.rejected(report)

    def test_actual_label_rectangles_and_source_layer_colour_are_typed(self):
        for field,value in (("x",True),("y",float("nan")),("w","92.6"),("w",0),
                            ("h",float("inf")),("h",-1),("missing_w",None),
                            ("body_draw_layer",False),("body_draw_layer",2),
                            ("type_color_rgba",[True,1,1,1]),("type_color_rgba",[0,1,1]),
                            ("label",123)):
            report=self.fixture();view=report["views"]["__none"];row=view["actual_canvas_evidence"][0]
            identifier=row["id"]
            geometry=next(r for r in view["actual_view"]["object_layout"]["objects"] if r["id"]==identifier)
            if field in ("x","y","w","h","missing_w"):
                for target in (geometry["label_rect"],row["geometry"][0]["label_rect"]):
                    if field=="missing_w":
                        del target["w"]
                    else:
                        target[field]=value
            elif field=="label":
                # Preserve source identity equality to isolate the strict string contract.
                owner=next(r for r in view["actual_view"]["objects"] if r["id"]==identifier)
                row["label"]=row["object"]["label"]=owner["label"]=value
            else:
                row[field]=value
            with self.subTest(field=field,value=value):
                self.rejected(report)

    def test_supported_rm_route_clock_and_frame_require_actual_types(self):
        changes=(("reduce_motion",False),("reduce_motion",1),("actual_rm_setting_route","synthetic"),
                 ("capture_clock",True),("capture_clock",float("nan")),("capture_clock",-1),
                 ("capture_process_frame",True),("capture_process_frame",0),
                 ("capture_process_frame","123"),("missing_rm",None),("missing_route",None))
        for field,value in changes:
            report=self.fixture();view=report["views"]["__none"]
            if field=="reduce_motion":
                view["actual_view"][field]=value
            elif field=="missing_rm":
                del view["actual_view"]["reduce_motion"]
            elif field=="missing_route":
                del view["actual_rm_setting_route"]
            else:
                view[field]=value
            with self.subTest(field=field,value=value):
                self.rejected(report)

    def test_original_source_assertion_count_and_findings_remain_gates(self):
        for source_files in (0,True,863.0,862):
            with self.subTest(source_files=source_files):
                self.rejected(self.fixture(),source_files)
        for field,value in (("checks",2125),("checks",True),("findings",["RM assertion failed"])):
            report=self.fixture();report[field]=value
            with self.subTest(field=field):
                self.rejected(report)

    def test_normal_contexts_still_require_all71_selected_captures(self):
        report=retained("current4-01","hidden_r2_initial_metadata.json")
        self.assertEqual(policy.report_contract("contexts",report,source_files=863),
            {"initial_objects":71,"selected_labels":71,"typed_pairs_in_this_report":0})
        del report["views"]["__none"]["selected_label_evidence"]
        with self.assertRaises((ValueError,KeyError)):
            policy.report_contract("contexts",report,source_files=863)


if __name__=="__main__":
    unittest.main()
