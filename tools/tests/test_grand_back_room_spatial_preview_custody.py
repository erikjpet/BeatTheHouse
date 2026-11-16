"""Focused diagnostic-custody regressions; root alone executes these in a Job.

Fixtures are synthetic bytes or SHA-pinned historical read-only evidence.
Every rejection starts from an accepted positive in the same test's setUp.
No image/fixture file, child, engine, profile, temp directory or network is made.
These contracts never establish composition, visual, native-suite or release GO.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
from contextlib import redirect_stderr
import ast
import hashlib
import io
import json
import math
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gbr_composition_preview_profile as policy
import gbr_composition_preview as runner

WIDTH, HEIGHT = 1800, 860
PIXELS = WIDTH * HEIGHT


def image(width, height, pixel=(41, 25, 19, 255)):
    return SimpleNamespace(width=width, height=height, rgba=bytes(pixel) * (width * height))


def rectangle(mask, x, y, width, height, value=1):
    for row in range(y, y + height):
        mask[row * WIDTH + x:row * WIDTH + x + width] = bytes([value]) * width


def copied_image(value):
    return SimpleNamespace(width=value.width, height=value.height, rgba=bytearray(value.rgba))


def write_pixel(value, x, y, rgba):
    at = (y * value.width + x) * 4
    value.rgba[at:at + 4] = bytes(rgba)


def row_document():
    return {"schema": "bth.native_row_runs/v1", "canvas": [1800, 860],
        "coordinates": "absolute_native_xy", "runs": [[4, 8, 12], [5, 8, 12], [8, 14, 18], [9, 14, 18]]}


class StrictJSONTests(unittest.TestCase):
    def setUp(self):
        positive = policy.parse_json(b'{"finite":[1e308,-1e308],"text":"1e999","flag":true}')
        self.assertTrue(all(math.isfinite(v) for v in positive["finite"]))
        self.assertEqual(positive["text"], "1e999")
        self.assertIs(positive["flag"], True)

    def test_finite_large_json_number_is_not_mistaken_for_overflow(self):
        self.assertEqual(policy.parse_json(b'{"value":1e308}')["value"], 1e308)

    def test_overflow_and_explicit_nonfinite_numbers_are_rejected(self):
        for raw in (b'{"value":1e999}', b'{"value":-1e999}', b'{"nested":[{"x":1e999}]}',
                    b'{"value":NaN}', b'{"value":Infinity}', b'{"value":-Infinity}'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                policy.parse_json(raw)

    def test_duplicate_keys_are_not_silently_replaced(self):
        self.assertEqual(policy.parse_json(b'{"x":1,"y":2}'), {"x": 1, "y": 2})
        for raw in (b'{"x":1,"x":2}', b'{"nested":{"x":1,"x":2}}'):
            with self.assertRaises(ValueError):
                policy.parse_json(raw)


class NativeMaskTests(unittest.TestCase):
    def setUp(self):
        self.valid = row_document()
        mask = policy.row_mask(self.valid)
        self.assertEqual(len(mask), PIXELS)
        self.assertEqual(sum(mask), 16)
        self.assertTrue(all(mask[4 * WIDTH + x] == 1 for x in range(8, 12)))
        self.assertEqual(mask[4 * WIDTH + 7], 0)
        self.assertEqual(mask[4 * WIDTH + 12], 0)

    def test_explicit_native_coordinates_preserve_known_pixels(self):
        mask = policy.row_mask(self.valid)
        self.assertEqual(mask[9 * WIDTH + 17], 1)
        self.assertEqual(mask[9 * WIDTH + 18], 0)

    def test_board_canvas_and_serialized_coordinate_claims_are_rejected(self):
        for field, wrong in (("canvas", [900, 430]), ("coordinates", "board_xy"),
                             ("coordinates", "(1800, 860)"), ("schema", "native/vector2")):
            value = deepcopy(self.valid); value[field] = wrong
            with self.subTest(field=field, wrong=wrong), self.assertRaises(ValueError):
                policy.row_mask(value)

    def test_bool_float_and_numeric_text_are_not_native_integer_coordinates(self):
        for column in range(3):
            for wrong in (True, 4.0, "4"):
                value = deepcopy(self.valid); value["runs"][0][column] = wrong
                with self.subTest(column=column, wrong=wrong), self.assertRaises(ValueError):
                    policy.row_mask(value)

    def test_out_of_canvas_empty_and_reversed_runs_are_rejected(self):
        for wrong in ([-1, 8, 12], [860, 8, 12], [4, -1, 12], [4, 8, 1801], [4, 8, 8], [4, 12, 8]):
            value = deepcopy(self.valid); value["runs"] = [wrong]
            with self.subTest(run=wrong), self.assertRaises(ValueError):
                policy.row_mask(value)

    def test_unsorted_overlapping_or_unmerged_adjacent_runs_are_rejected(self):
        for runs in ([[5, 8, 12], [4, 8, 12]], [[4, 8, 12], [4, 10, 14]],
                     [[4, 8, 10], [4, 10, 12]], [[4, 8, 12], [4, 8, 12]]):
            value = deepcopy(self.valid); value["runs"] = runs
            with self.subTest(runs=runs), self.assertRaises(ValueError):
                policy.row_mask(value)

    def test_unknown_fields_cannot_change_the_coordinate_contract(self):
        value = {**self.valid, "native_Vector2": True}
        with self.assertRaises(ValueError):
            policy.row_mask(value)


class ReplayFixture:
    """Independent hand-drawn apron/two posts with exposed floor and under-table hole."""
    def __init__(self):
        self.master = image(WIDTH, HEIGHT)
        self.bleed = [0, 0, 0, 56]
        self.physical = bytearray(PIXELS)
        self.parts = [(164, 516, 544, 24), (200, 540, 24, 160), (640, 540, 24, 160)]
        for rect in self.parts:
            rectangle(self.physical, *rect)
        self.negative = {name: bytearray(PIXELS) for name in ("floor", "under_table", "office")}
        rectangle(self.negative["floor"], 300, 690, 80, 10)
        rectangle(self.negative["under_table"], 260, 560, 330, 100)
        rectangle(self.negative["office"], 800, 640, 20, 20)
        self.replay = image(544, 184, (0, 0, 0, 0))
        self.replay = copied_image(self.replay)
        for x, y, width, height in self.parts:
            for yy in range(y, y + height):
                at = ((yy - 516) * 544 + x - 164) * 4
                self.replay.rgba[at:at + width * 4] = bytes((41, 25, 19, 255)) * width

    def check(self):
        return policy.check_replay_rgba(self.master, self.replay, "grand_table_left",
            self.bleed, self.physical, self.negative)


class ReplayMaterialTests(unittest.TestCase):
    def setUp(self):
        self.f = ReplayFixture()
        result = self.f.check()
        self.assertEqual(result["grown_rect_native"], [164, 516, 544, 184])
        self.assertEqual(result["solid_pixels"], 544 * 24 + 2 * 24 * 160)
        self.assertTrue(result["rgb_matches_master"])
        self.assertTrue(result["nn2_exact"])
        self.assertEqual(result["negative_opaque_pixels"], {"floor": 0, "under_table": 0, "office": 0})

    def test_furniture_is_solid_and_open_floor_stays_transparent(self):
        result = self.f.check()
        self.assertGreater(result["transparent_pixels"], 0)
        self.assertGreater(result["negative_intersections"]["floor"], 0)
        self.assertGreater(result["negative_intersections"]["under_table"], 0)
        self.assertEqual(result["negative_intersections"]["office"], 0)

    def test_partial_alpha_cannot_hide_in_a_furniture_pixel(self):
        for alpha in (1, 128, 254):
            changed = copied_image(self.f.replay)
            write_pixel(changed, 36, 40, (41, 25, 19, alpha))
            with self.subTest(alpha=alpha), self.assertRaises(ValueError):
                policy.check_replay_rgba(self.f.master, changed, "grand_table_left",
                    self.f.bleed, self.f.physical, self.f.negative)

    def test_zero_alpha_with_hidden_rgb_is_rejected(self):
        write_pixel(self.f.replay, 100, 100, (41, 25, 19, 0))
        with self.assertRaises(ValueError):
            self.f.check()

    def test_registered_solid_rgb_must_match_the_actual_master(self):
        write_pixel(self.f.replay, 36, 40, (42, 25, 19, 255))
        with self.assertRaises(ValueError):
            self.f.check()

    def test_actual_alpha_cannot_erase_reviewed_support_or_add_floor(self):
        for x, y, pixel in ((36, 40, (0, 0, 0, 0)), (100, 100, (41, 25, 19, 255))):
            changed = copied_image(self.f.replay); write_pixel(changed, x, y, pixel)
            with self.subTest(x=x, y=y), self.assertRaises(ValueError):
                policy.check_replay_rgba(self.f.master, changed, "grand_table_left",
                    self.f.bleed, self.f.physical, self.f.negative)

    def test_opaque_office_intersection_is_rejected(self):
        rectangle(self.f.negative["office"], 200, 550, 2, 2)
        with self.assertRaises(ValueError):
            self.f.check()

    def test_semantic_negatives_must_be_nonempty_and_intersect_local_floor(self):
        for name, mask in (("office", bytearray(PIXELS)), ("floor", bytearray(PIXELS)),
                           ("under_table", bytearray(PIXELS))):
            negative = dict(self.f.negative); negative[name] = mask
            with self.subTest(mask=name), self.assertRaises(ValueError):
                policy.check_replay_rgba(self.f.master, self.f.replay, "grand_table_left",
                    self.f.bleed, self.f.physical, negative)
        for name in ("floor", "under_table"):
            negative = dict(self.f.negative); outside = bytearray(PIXELS)
            rectangle(outside, 1500, 700, 2, 2); negative[name] = outside
            with self.subTest(local_intersection=name), self.assertRaises(ValueError):
                policy.check_replay_rgba(self.f.master, self.f.replay, "grand_table_left",
                    self.f.bleed, self.f.physical, negative)

    def test_nonbinary_or_non_nn2_physical_mask_is_rejected(self):
        for value in (0, 255):
            mask = bytearray(self.f.physical); mask[516 * WIDTH + 164] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                policy.check_replay_rgba(self.f.master, self.f.replay, "grand_table_left",
                    self.f.bleed, mask, self.f.negative)

    def test_solid_component_outside_registered_crop_is_not_silently_clipped(self):
        rectangle(self.f.physical, 164, 514, 2, 2)
        with self.assertRaises(ValueError):
            self.f.check()

    def test_png_size_and_render_only_bleed_must_agree(self):
        for bleed in ([0, 0, 0, 55], [2, 0, 0, 56], [0, 0, 0, 171], [-1, 0, 0, 56]):
            with self.subTest(bleed=bleed), self.assertRaises(ValueError):
                policy.check_replay_rgba(self.f.master, self.f.replay, "grand_table_left",
                    bleed, self.f.physical, self.f.negative)

    def test_floor_cannot_be_hidden_by_an_opaque_registered_rectangle(self):
        physical = bytearray(PIXELS); rectangle(physical, 164, 516, 544, 184)
        replay = image(544, 184)
        with self.assertRaises(ValueError):
            policy.check_replay_rgba(self.f.master, replay, "grand_table_left",
                self.f.bleed, physical, self.f.negative)


class MasterBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.original = image(WIDTH, HEIGHT)
        self.master = copied_image(self.original)
        self.edit = bytearray(PIXELS)
        rectangle(self.edit, 200, 520, 2, 2)
        for y in (520, 521):
            for x in (200, 201):
                write_pixel(self.master, x, y, (43, 27, 21, 255))
        self.assertEqual(policy.check_master(self.original, self.master, self.edit),
            {"changed_pixels": 4, "outside_edit_union_exact": True})

    def test_registered_change_has_exact_outside_pixels(self):
        self.assertEqual(policy.check_master(self.original, self.master, self.edit)["changed_pixels"], 4)

    def test_unapproved_background_pixel_cannot_change(self):
        write_pixel(self.master, 1000, 700, (50, 27, 21, 255))
        with self.assertRaises(ValueError):
            policy.check_master(self.original, self.master, self.edit)

    def test_transparent_master_and_unchanged_old_master_are_rejected(self):
        write_pixel(self.master, 200, 520, (43, 27, 21, 254))
        with self.assertRaises(ValueError):
            policy.check_master(self.original, self.master, self.edit)
        with self.assertRaises(ValueError):
            policy.check_master(self.original, self.original, self.edit)


class ManifestSourceTests(unittest.TestCase):
    def setUp(self):
        raw = (policy.PROJECT / policy.MANIFEST).read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),
            "cc8553a5856289c7fe6b42754db43b4bd02d07e5c793ca1fea54e7655eca103d")
        self.original = json.loads(raw)
        self.candidate = deepcopy(self.original)
        for entry in self.candidate["counters"].values():
            entry["bleed"] = [0, 0, 0, 57]
        self.positive = policy.check_manifest(self.original, self.candidate)
        self.assertEqual(self.positive["grand_table_left"]["grown_rect_native"], [164, 516, 544, 186])

    def test_only_two_render_bleeds_change_and_game_authority_stays_original(self):
        self.assertEqual(set(self.positive), set(policy.RAW_RECTS))
        self.assertEqual(self.original["counters"]["grand_table_left"], {"texture": "counters/grand_table_left.png"})
        self.assertEqual(len(self.candidate["animations"]), 16)

    def test_added_raw_rect_or_changed_texture_is_rejected(self):
        for field, value in (("rect", [82, 258, 272, 93]), ("texture", "counters/other.png")):
            changed = deepcopy(self.candidate); changed["counters"]["grand_table_left"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                policy.check_manifest(self.original, changed)

    def test_bool_float_negative_and_wrong_length_bleeds_are_rejected(self):
        for bleed in ([False, 0, 0, 57], [0.0, 0, 0, 57], [0, 0, 0, -1], [0, 0, 57],
                      [0, 0, 0, float("nan")], [0, 0, 0, 1000]):
            changed = deepcopy(self.candidate); changed["counters"]["grand_table_left"]["bleed"] = bleed
            with self.subTest(bleed=bleed), self.assertRaises(ValueError):
                policy.check_manifest(self.original, changed)

    def test_motion_timing_material_or_low_flag_change_is_rejected(self):
        for field, value in (("period", 999), ("texture", "anim/other.png"),
                             ("web_low_detail", not self.original["animations"][0].get("web_low_detail", True))):
            changed = deepcopy(self.candidate); changed["animations"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                policy.check_manifest(self.original, changed)

    def test_extra_counter_or_missing_native_motion_is_rejected(self):
        for kind in ("counter", "motion"):
            changed = deepcopy(self.candidate)
            if kind == "counter":
                changed["counters"]["new_counter"] = {"texture": "counters/new.png", "bleed": [0, 0, 0, 57]}
            else:
                changed["animations"].pop()
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.check_manifest(self.original, changed)

    def test_out_of_board_expansion_is_rejected(self):
        changed = deepcopy(self.candidate); changed["counters"]["grand_table_left"]["bleed"] = [83, 0, 0, 57]
        with self.assertRaises(ValueError):
            policy.check_manifest(self.original, changed)


def custody_shape():
    refs = {name: {"path": "E:/unit-readonly/" + name + ".json", "sha256": "1" * 64}
        for name in ("assembly_proof", "assembly_job", "assembler", "recipe", "material_review", "raw_preservation")}
    return {"schema": policy.SCHEMA, "task_id": policy.TASK, "room": policy.ROOM,
        "verdict": "ADMIT_DIAGNOSTIC_RENDER_ONLY", "authority": "/root", "limits": deepcopy(policy.LIMITS),
        "source_base": {"commit": policy.BASE_SOURCE, "tree": policy.BASE_TREE}, **refs,
        "candidate": {"root": "E:/unit-readonly/candidate", "files": {"fixture.png": "2" * 64}, "seal": "3" * 64},
        "assembly_command": ["C:/fixture/python.exe", "-B", "D:/fixture/assembly.py"],
        "driver_helpers": {"gbr_composition_preview.py": "4" * 64}}


class CustodyDeclarationTests(unittest.TestCase):
    def setUp(self):
        self.value = custody_shape()
        result = policy.check_custody_declaration(self.value)
        self.assertIs(result["custody_shape_only"], True)
        self.assertIs(result["visual_acceptance"], False)
        self.assertIs(result["formal_native_acceptance"], False)
        self.assertIs(result["release_approval"], False)

    def test_shape_is_not_authenticated_real_candidate_or_visual_acceptance(self):
        self.assertEqual(self.value["source_base"], {"commit": policy.BASE_SOURCE, "tree": policy.BASE_TREE})
        self.assertFalse(policy.check_custody_declaration(self.value)["TEST_updated"])

    def test_caller_cannot_promote_preview_to_visual_native_or_release_go(self):
        for field in ("visual_acceptance", "formal_native_acceptance", "release_approval", "TEST_updated"):
            changed = deepcopy(self.value); changed["limits"][field] = True
            with self.subTest(field=field), self.assertRaises(ValueError):
                policy.check_custody_declaration(changed)

    def test_wrong_authority_room_source_or_verdict_is_rejected(self):
        for field, value in (("authority", "/foreign"), ("room", "grand_casino"),
                             ("verdict", "GO_FOR_TEST_BUILD"), ("source_base", {"commit": "5" * 40, "tree": policy.BASE_TREE})):
            changed = deepcopy(self.value); changed[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                policy.check_custody_declaration(changed)

    def test_missing_actual_refs_candidate_or_argv_is_rejected(self):
        for field in ("assembly_proof", "assembly_job", "assembler", "recipe", "material_review",
                      "raw_preservation", "candidate", "assembly_command", "driver_helpers"):
            changed = deepcopy(self.value); changed.pop(field)
            with self.subTest(field=field), self.assertRaises(ValueError):
                policy.check_custody_declaration(changed)

    def test_zero_or_short_input_hash_is_rejected(self):
        for digest in ("0" * 64, "1" * 63, "fixture"):
            changed = deepcopy(self.value); changed["assembly_proof"]["sha256"] = digest
            with self.assertRaises(ValueError):
                policy.check_custody_declaration(changed)


class HistoricalContextContractTests(unittest.TestCase):
    def setUp(self):
        path = policy.CONTEXT_EVIDENCE / "grand_casino_back_room_preart_metadata.json"
        raw = path.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), policy.CONTEXT_SHA)
        self.report = json.loads(raw)
        identity_path = policy.ROOT / "workspaces/BTH-ENV-SPATIAL-GBRTRIAL-20261116/qa_source/grandback_spatial_source_identity.json"
        identity_raw = identity_path.read_bytes()
        self.assertEqual(hashlib.sha256(identity_raw).hexdigest(),
            "2794328aaef0818cd7ccee0774343eab50642f43ea17ad93afed9c05a9506c4d")
        self.source_files = len(json.loads(identity_raw)["files"])
        self.assertEqual(self.source_files, 3964)
        result = policy.check_context_report(self.report, self.source_files)
        self.assertEqual((result["checks"], result["populated_objects"]), (7969, 3))
        self.assertFalse(result["formal_native_acceptance"])
        self.assertFalse(result["visual_acceptance"])

    def test_historical_report_contract_is_not_fresh_candidate_authority(self):
        result = policy.check_context_report(self.report, self.source_files)
        self.assertEqual(result["scope"], "GBR_BASE_COMPOSITION_ONLY")
        self.assertFalse(result["release_approval"])

    def test_source_count_and_incomplete_checks_cannot_relabel_old_base(self):
        with self.assertRaises(ValueError):
            policy.check_context_report(self.report, self.source_files + 1)
        changed = deepcopy(self.report); changed["checks"] -= 1
        with self.assertRaises(ValueError):
            policy.check_context_report(changed, self.source_files)

    def test_failures_missing_selected_objects_or_pending_arrival_are_rejected(self):
        values = []
        changed = deepcopy(self.report); changed["findings"] = ["fixture finding"]; values.append(changed)
        changed = deepcopy(self.report); changed["views"]["__none"]["selected_label_evidence"].pop(); values.append(changed)
        changed = deepcopy(self.report); changed["views"]["__none"]["arrival"]["remaining_person_transits"] = 1; values.append(changed)
        for changed in values:
            with self.assertRaises(ValueError):
                policy.check_context_report(changed, self.source_files)

    def test_duplicate_actual_object_cannot_hide_behind_same_three_id_set(self):
        changed = deepcopy(self.report)
        objects = changed["views"]["__none"]["actual_view"]["objects"]
        objects.append(deepcopy(objects[0]))
        with self.assertRaises(ValueError):
            policy.check_context_report(changed, self.source_files)

    def test_resolved_hit_or_label_geometry_cannot_move(self):
        for field in ("interaction_rect", "label_rect"):
            changed = deepcopy(self.report)
            changed["views"]["__none"]["actual_view"]["object_layout"]["objects"][0][field]["x"] += 1
            with self.subTest(field=field), self.assertRaises(ValueError):
                policy.check_context_report(changed, self.source_files)

    def test_serialized_position_or_size_cannot_be_promoted_to_native_vectors(self):
        for section in ("actual_view", "source_paint"):
            for field, value in (("position", [0.755556, 0.518605]), ("size", [72.0, 48.0]),
                                 ("fixed_slot_geometry", "true")):
                changed = deepcopy(self.report)
                row = changed["views"]["__none"][section]["objects"][0]
                obj = row if section == "actual_view" else row["object"]
                obj[field] = value
                with self.subTest(section=section, field=field), self.assertRaises(ValueError):
                    policy.check_context_report(changed, self.source_files)



def cfg_fixture():
    outer = policy.ROOT / "workspaces/BTH-ENV-SPATIAL-GBRPREVIEW-UNIT"
    return {"schema": runner.INPUT_SCHEMA, "workspace": str(outer), "qa_root": str(policy.ROOT),
        "project": str(outer / "qa_source"), "run_prefix": "GBR-PREVIEW-UNIT",
        "source_commit": policy.BASE_SOURCE, "source_tree": policy.BASE_TREE,
        "source_scope": runner.selected.SCOPE, "full_repository_archive": False,
        "custody_path": str(policy.PROJECT / "docs/testing/__test_missing_gbr_preview_custody__.json"),
        "custody_sha256": "1" * 64, "custody_control_sha256": {}, "candidate_root": "E:/unit-candidate",
        "candidate_files": {}, "candidate_seal": "2" * 64, "baseline_files": {},
        "archive": str(policy.ROOT / "runs/GBR-PREVIEW-UNIT-archive/evidence/source.tar"),
        "timeout": 1200, "position": "-32000,-32000", "python_sha256": runner.PYTHON_SHA,
        "engine": "D:/fixture/Godot_v4.6-stable_win64_console.exe", "git": "C:/fixture/git.exe",
        "git_dir": "D:/fixture/repository.git", "git_sha256": "3" * 64,
        "baseline_stage": str(runner.selected.BASE_STAGE),
        "native_extension_descriptor": "E:/fixture/coin_pusher_native.gdextension",
        "editor_native_library": "E:/fixture/native-debug.dll", "helpers": {},
        "original_helpers": {}, "original_provenance": {}, "limits": deepcopy(policy.LIMITS)}


class ClosedReceipt:
    """Fresh own-schema complete bytes; mutations rebind hashes to target actual gates."""
    def __init__(self, phase="identity"):
        self.cfg, self.phase = cfg_fixture(), phase
        self.e = runner.evidence(self.cfg, phase)
        self.log = "Bounded preview fixture: PASS\n"
        self.manifest = {"schema": "bth-qa-storage/v1", "prepared": True,
            "expected_write_bytes": 4 * 1024 ** 3, "reserve_bytes": 20 * 1024 ** 3,
            "paths": {"workspace": self.cfg["workspace"] if phase in runner.OUTER_PHASES else self.cfg["project"],
                      "evidence": str(self.e), "run_root": str(self.e.parent)}}
        self.claim = {"schema": "bth.qa_launch_claim/v1", "manifest_sha256": self.sha(self.e / "storage-manifest.json")}
        command = runner.command(self.cfg, phase)
        self.job = {"schema": "bth.qa_guarded_run/v1", "pid": 12345, "exit_code": 0,
            "active_at_release": 0, "assigned_before_execution": True, "finished_epoch": 1234.5,
            "error": None, "cleanup_errors": [], "timed_out": False, "log_error": None, "log_truncated": False,
            "storage_gate_before_job": {"admitted": True}, "storage_gate_before_child": {"admitted": True},
            "limits": {"cpu_rate": 1200, "job_memory_limit_bytes": 2 * 1024 ** 3,
                       "kill_on_close": True, "breakaway_allowed": False},
            "command": command, "storage_manifest": str(self.e / "storage-manifest.json"),
            "storage_manifest_sha256": self.claim["manifest_sha256"]}
        self.inputs = {"source_config": deepcopy(self.cfg), "source_config_sha256": runner.selected.digest(self.cfg),
            "command": deepcopy(command), "engine_campaign_admission": phase in runner.ENGINE_PHASES}
        required = {"worker-result.json"} if phase in runner.FILE_PHASES else set()
        if phase == "select":
            required |= {"selection.json", "closure.json"}
        if phase == "contexts":
            required |= {"grand_casino_back_room_preart_metadata.json", "preview-output-inventory.json"}
        self.artifacts = {n: {"fixture": n} for n in required}
        self.result = {"schema": runner.SCHEMA, "phase": phase, "status": "PASS",
            "source_config_sha256": runner.selected.digest(self.cfg), "source_commit": self.cfg["source_commit"],
            "source_tree": self.cfg["source_tree"], "job_receipt": str(self.e / "job.json"),
            "job_sha256": "", "log_sha256": "", "artifact_sha256": {}, "limits": deepcopy(policy.LIMITS)}
        self.bind_hashes()

    @staticmethod
    def encoded(value):
        return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()

    def docs(self):
        return {"phase-result.json": self.result, "job.json": self.job, "trial-inputs.json": self.inputs,
                "storage-manifest.json": self.manifest, "launch-claim.json": self.claim, **self.artifacts}

    def sha(self, path):
        name = Path(path).name
        if name == "worker.log":
            raw = self.log.encode()
        elif name == "storage-manifest.json":
            raw = self.encoded(self.manifest)
        else:
            raw = self.encoded(self.docs()[name])
        return hashlib.sha256(raw).hexdigest()

    def bind_hashes(self):
        self.result["job_sha256"] = self.sha(self.e / "job.json")
        self.result["log_sha256"] = self.sha(self.e / "worker.log")
        self.result["artifact_sha256"] = {n: self.sha(self.e / n) for n in self.artifacts}

    def bind_manifest(self):
        value = self.sha(self.e / "storage-manifest.json")
        self.job["storage_manifest_sha256"] = value
        self.claim["manifest_sha256"] = value
        self.bind_hashes()

    def check(self):
        with patch.object(runner, "read", side_effect=lambda p: deepcopy(self.docs()[Path(p).name])), \
             patch.object(runner, "sha", side_effect=self.sha), \
             patch.object(Path, "read_text", return_value=self.log):
            return runner.previous(self.cfg, self.phase)


class OwnClosedReceiptTests(unittest.TestCase):
    def setUp(self):
        self.f = ClosedReceipt()
        self.assertEqual(self.f.check()["status"], "PASS")

    def test_valid_own_file_and_context_phase_artifact_catalogs_pass_custody_only(self):
        for phase in ("select", "identity", "contexts"):
            fixture = ClosedReceipt(phase)
            result = fixture.check()
            self.assertEqual(result["phase"], phase)
            self.assertFalse(result["limits"]["formal_native_acceptance"])
            self.assertFalse(result["limits"]["visual_acceptance"])

    def test_old_native_schema_or_source_cannot_qualify_new_preview(self):
        for field, value in (("schema", "bth.grand_back_room_spatial_trial_phase/v1"),
                             ("source_commit", "a9c02a9557abfd644b27f36be392d354fc70c6ef"),
                             ("source_tree", "edcf685c282567daa2bb82a6ba49d818e5950ed6"),
                             ("source_config_sha256", "5" * 64), ("phase", "contexts")):
            fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
            fixture.result[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                fixture.check()

    def test_wrong_own_entrypoint_or_phase_argv_fails_even_with_rebound_job_hash(self):
        for column, value in ((2, "D:/fixture/grand_back_room_spatial_native_trial_v2.py"), (3, "install")):
            fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
            fixture.job["command"][column] = value
            fixture.inputs["command"] = deepcopy(fixture.job["command"])
            fixture.bind_hashes()
            with self.subTest(column=column), self.assertRaises(ValueError):
                fixture.check()

    def test_assignment_closed_zero_log_and_cleanup_are_mandatory(self):
        for field, value in (("assigned_before_execution", False), ("active_at_release", 1), ("exit_code", 1),
                             ("timed_out", True), ("log_truncated", True), ("log_error", "drain failed"),
                             ("cleanup_errors", ["fixture"]), ("error", "fixture")):
            fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
            fixture.job[field] = value; fixture.bind_hashes()
            with self.subTest(field=field), self.assertRaises(ValueError):
                fixture.check()

    def test_cpu_memory_kill_close_and_no_breakaway_remain_exact(self):
        for field, value in (("cpu_rate", 2400), ("job_memory_limit_bytes", 3 * 1024 ** 3),
                             ("kill_on_close", False), ("breakaway_allowed", True)):
            fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
            fixture.job["limits"][field] = value; fixture.bind_hashes()
            with self.subTest(field=field), self.assertRaises(ValueError):
                fixture.check()

    def test_wrong_storage_claim_or_budget_cannot_borrow_closed_job(self):
        for field, value in (("schema", "wrong"), ("manifest_sha256", "6" * 64)):
            fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
            fixture.claim[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                fixture.check()
        for field in ("expected_write_bytes", "reserve_bytes"):
            fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
            fixture.manifest[field] -= 1; fixture.bind_manifest()
            with self.subTest(budget=field), self.assertRaises(ValueError):
                fixture.check()

    def test_workspace_evidence_and_run_root_cannot_be_siblings(self):
        for field in ("workspace", "evidence", "run_root"):
            fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
            fixture.manifest["paths"][field] = "E:/CodexQA/BTH/runs/borrowed"
            fixture.bind_manifest()
            with self.subTest(path=field), self.assertRaises(ValueError):
                fixture.check()

    def test_source_input_or_admission_bit_mismatch_cannot_reuse_positive(self):
        for field, value in (("source_config", {}), ("source_config_sha256", "7" * 64),
                             ("engine_campaign_admission", True)):
            fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
            fixture.inputs[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                fixture.check()

    def test_error_lines_are_rejected_even_with_exit_zero_and_rebound_log(self):
        for log in ("ERROR: fixture failed\n", "SCRIPT ERROR: fixture failed\n"):
            fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
            fixture.log = log; fixture.bind_hashes()
            with self.subTest(log=log), self.assertRaises(ValueError):
                fixture.check()

    def test_missing_or_changed_phase_artifact_is_not_just_a_pass_label(self):
        fixture = ClosedReceipt("contexts"); self.assertEqual(fixture.check()["status"], "PASS")
        fixture.result["artifact_sha256"].pop("preview-output-inventory.json")
        with self.assertRaises(ValueError):
            fixture.check()
        fixture = ClosedReceipt(); self.assertEqual(fixture.check()["status"], "PASS")
        fixture.artifacts["worker-result.json"] = {"modified": True}
        with self.assertRaises(ValueError):
            fixture.check()

    def test_caller_cannot_promote_receipt_limits(self):
        self.f.result["limits"]["visual_acceptance"] = True
        with self.assertRaises(ValueError):
            self.f.check()


class OwnCommandBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.cfg = cfg_fixture()
        self.assertEqual(tuple(runner.PHASES), ("source-identity", "tree", "baseline-tree", "select", "archive",
            "prepare", "install", "import", "identity", "liveness", "contexts"))
        self.assertEqual(len(runner.PHASES), 11)
        self.assertEqual(runner.FILE_PHASES, {"select", "prepare", "install", "identity"})
        self.assertEqual(runner.ENGINE_PHASES, {"import", "liveness", "contexts"})

    def test_archive_declares_only_parent_not_file_and_prepare_only_fresh_project(self):
        self.assertEqual(runner.write_paths(self.cfg, "archive"), (Path(self.cfg["archive"]).parent,))
        self.assertNotIn(Path(self.cfg["archive"]), runner.write_paths(self.cfg, "archive"))
        self.assertEqual(runner.write_paths(self.cfg, "prepare"), (Path(self.cfg["project"]),))
        for phase in ("source-identity", "tree", "baseline-tree", "select"):
            self.assertEqual(runner.write_paths(self.cfg, phase), ())

    def test_no_capture_export_release_or_old_suite_fallback_exists(self):
        for phase in ("capture", "export", "publish", "sequence", "acceptance-summary"):
            with self.subTest(phase=phase), self.assertRaises(ValueError):
                runner.command(self.cfg, phase)
            with self.assertRaises(ValueError):
                runner.write_paths(self.cfg, phase)

    def test_file_worker_argv_binds_new_driver_custody_source_and_workspace(self):
        for phase in runner.FILE_PHASES:
            argv = runner.command(self.cfg, phase)
            self.assertEqual(Path(argv[2]).name, "gbr_composition_preview.py")
            self.assertEqual(argv[3:5], [phase, "--worker"])
            self.assertIn("--custody-json=" + self.cfg["custody_path"], argv)
            self.assertIn("--source-commit=" + policy.BASE_SOURCE, argv)
            self.assertIn("--source-tree=" + policy.BASE_TREE, argv)
            self.assertIn("--workspace=" + self.cfg["workspace"], argv)

    def test_cold_import_and_original_liveness_use_exact_project(self):
        self.assertEqual(runner.command(self.cfg, "import"), [self.cfg["engine"], "--headless", "--path",
            self.cfg["project"], "--editor", "--import"])
        live = runner.command(self.cfg, "liveness")
        self.assertEqual(live[live.index("--path") + 1], self.cfg["project"])
        self.assertEqual(live[live.index("--script") + 1],
            "res://scripts/tests/animation_liveness_without_pointer_check.gd")

    def test_contexts_use_actual_original_base_producer_offscreen(self):
        argv = runner.command(self.cfg, "contexts")
        self.assertEqual(argv[argv.index("--script") + 1], "res://tools/envart_grandback_preart_metadata.gd")
        self.assertEqual(argv[argv.index("--position") + 1], "-32000,-32000")
        self.assertEqual(argv[argv.index("--path") + 1], self.cfg["project"])
        self.assertNotIn("--headless", argv)


def cli_fixture(phase="plan"):
    cfg = cfg_fixture()
    argv = [phase]
    keys = ("workspace", "qa_root", "engine", "git", "git_dir", "baseline_stage", "native_extension_descriptor",
        "editor_native_library", "source_commit", "source_tree", "run_prefix", "custody_sha256")
    for key in keys:
        argv += ["--" + key.replace("_", "-"), str(cfg[key])]
    argv += ["--custody-json", cfg["custody_path"]]
    return argv


class AdmissionBeforeWritesTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(policy.check_custody_declaration(custody_shape())["custody_shape_only"])
        self.missing = Path(cfg_fixture()["custody_path"])
        self.assertFalse(self.missing.exists(), "This test never creates its deliberately missing custody document")

    def test_absent_real_custody_is_rejected_before_any_layout_write_or_child(self):
        # Valid shape alone cannot substitute for a real hash-bound artifact.
        with patch.object(runner, "plan_layout") as planned, patch.object(runner, "prepare_layout") as prepared, \
             patch.object(runner, "execute") as executed, patch.object(runner, "write") as written, \
             redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(cli_fixture()), 1)
            planned.assert_not_called(); prepared.assert_not_called()
            executed.assert_not_called(); written.assert_not_called()

    def test_internal_engine_worker_mode_stops_before_loading_layout(self):
        cfg = cfg_fixture()
        self.assertEqual(Path(runner.command(cfg, "select")[2]).name, "gbr_composition_preview.py")
        with patch.object(runner, "config", return_value=cfg), patch.object(runner, "read") as read_layout, \
             patch.object(runner, "execute") as executed, redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main([*cli_fixture("contexts"), "--worker"]), 1)
            read_layout.assert_not_called(); executed.assert_not_called()



def material_fixture(layout):
    typed = {oid: {"body": {"path": "E:/unit/body.png", "sha256": "1" * 64},
                   "adorn": {"path": "E:/unit/adorn.png", "sha256": "2" * 64}} for oid in policy.OBJECT_IDS}
    return {"coordinate_system": {"board": [900, 430], "native": [1800, 860], "pixel_scale": 2},
        "counters": {name: {} for name in policy.RAW_RECTS},
        "floor_band": {"native_y": [604, 616], "outside_approved_union_exact": True, "source_material_rows": [366, 367]},
        "master": {"opaque": True, "outside_edit_union_exact": True, "every_change_sourced": True, "changed_pixels": 4},
        "paint_contacts": {"controls_unchanged": True, "native_layout": deepcopy(layout), "typed_paint_masks": typed,
            "support_required_masks": {n: {} for n in ("game:blackjack", "game:craps")},
            "support_surface_masks": {n: {} for n in ("game:blackjack", "game:craps")}},
        "motion_controls": {"native_count": 16, "low_count": 7, "ordered_ids": list(policy.ANIMATION_IDS),
            "original_rows_equal": True, "animation_pngs_equal": True},
        "protected_controls": {"all_equal": True, "files": ["office", "header"],
            "before": {"office": "3" * 64, "header": "4" * 64},
            "after": {"office": "3" * 64, "header": "4" * 64}}}


class MaterialWitnessTests(unittest.TestCase):
    def setUp(self):
        path = policy.CONTEXT_EVIDENCE / "grand_casino_back_room_preart_metadata.json"
        raw = path.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), policy.CONTEXT_SHA)
        self.layout = json.loads(raw)["views"]["__none"]["actual_view"]["object_layout"]
        self.material = material_fixture(self.layout)
        result = policy.check_material_contract(self.material, self.layout)
        self.assertTrue(result["material_contract_declaration_only"])
        self.assertFalse(result["visual_acceptance"])

    def test_exact_material_declaration_does_not_authenticate_artifacts_or_visuals(self):
        result = policy.check_material_contract(self.material, self.layout)
        self.assertFalse(result["formal_native_acceptance"])
        self.assertFalse(result["release_approval"])

    def test_unsourced_master_or_changed_floor_band_cannot_be_declared_accepted(self):
        for section, field, wrong in (("master", "every_change_sourced", False),
                                     ("master", "outside_edit_union_exact", False),
                                     ("master", "changed_pixels", 0), ("floor_band", "native_y", [604, 614]),
                                     ("floor_band", "source_material_rows", [])):
            changed = deepcopy(self.material); changed[section][field] = wrong
            with self.subTest(section=section, field=field), self.assertRaises(ValueError):
                policy.check_material_contract(changed, self.layout)

    def test_native_layout_and_full_typed_pairs_cannot_be_replaced_by_serialized_claims(self):
        changed = deepcopy(self.material)
        changed["paint_contacts"]["native_layout"] = json.dumps(self.layout)
        with self.assertRaises(ValueError):
            policy.check_material_contract(changed, self.layout)
        for field in ("typed_paint_masks", "support_required_masks", "support_surface_masks"):
            changed = deepcopy(self.material); changed["paint_contacts"][field].pop(next(iter(changed["paint_contacts"][field])))
            with self.subTest(field=field), self.assertRaises(ValueError):
                policy.check_material_contract(changed, self.layout)

    def test_changed_motion_or_protected_source_control_is_rejected(self):
        for field, wrong in (("native_count", 15), ("low_count", 7.0),
                             ("original_rows_equal", False), ("animation_pngs_equal", False)):
            changed = deepcopy(self.material); changed["motion_controls"][field] = wrong
            with self.subTest(field=field), self.assertRaises(ValueError):
                policy.check_material_contract(changed, self.layout)
        changed = deepcopy(self.material); changed["protected_controls"]["after"]["office"] = "5" * 64
        with self.assertRaises(ValueError):
            policy.check_material_contract(changed, self.layout)


class ContactFixture:
    def __init__(self):
        self.support, self.surface, self.physical = (bytearray(PIXELS) for _ in range(3))
        rectangle(self.support, 400, 430, 4, 2)
        rectangle(self.surface, 390, 420, 80, 80)
        rectangle(self.physical, 380, 410, 100, 100)
        self.body = image(WIDTH, HEIGHT, (0, 0, 0, 0))
        self.body = copied_image(self.body)
        for y in (430, 431):
            for x in range(400, 404):
                write_pixel(self.body, x, y, (180, 60, 20, 255))
        self.master = copied_image(image(WIDTH, HEIGHT))
        for y in range(420, 500):
            at = (y * WIDTH + 390) * 4
            self.master.rgba[at:at + 80 * 4] = bytes((10, 100, 30, 255)) * 80
        self.contact = [428, 496]

    def check(self):
        return policy.check_contact_masks(self.support, self.surface, self.body.rgba,
            self.physical, self.contact, master_rgba=self.master.rgba)


class ActualContactMaskTests(unittest.TestCase):
    def setUp(self):
        self.f = ContactFixture()
        result = self.f.check()
        self.assertEqual(result["support_pixels"], 8)
        self.assertTrue(result["actual_contact_supported"])

    def test_opaque_body_and_saved_native_contact_have_actual_felt(self):
        self.assertEqual(self.f.check()["surface_pixels"], 6400)

    def test_omitting_opaque_game_paint_or_using_shadow_alpha_is_rejected(self):
        self.f.support[430 * WIDTH + 400] = 0
        with self.assertRaises(ValueError):
            self.f.check()
        fixture = ContactFixture(); fixture.check()
        write_pixel(fixture.body, 400, 430, (180, 60, 20, 63))
        with self.assertRaises(ValueError):
            fixture.check()

    def test_unreviewed_opaque_body_pixel_or_surface_outside_furniture_is_rejected(self):
        write_pixel(self.f.body, 100, 100, (180, 60, 20, 255))
        with self.assertRaises(ValueError):
            self.f.check()
        fixture = ContactFixture(); fixture.check()
        rectangle(fixture.surface, 100, 100, 2, 2)
        with self.assertRaises(ValueError):
            fixture.check()

    def test_surface_declaration_must_match_actual_green_furniture_material(self):
        write_pixel(self.f.master, 400, 430, (41, 25, 19, 255))
        with self.assertRaises(ValueError):
            self.f.check()

    def test_board_float_text_or_unsupported_saved_contact_is_rejected(self):
        for contact in ([214, 248], [428.0, 496.0], [True, 496], ["428", 496], [900, 700]):
            fixture = ContactFixture(); fixture.check(); fixture.contact = contact
            with self.subTest(contact=contact), self.assertRaises(ValueError):
                fixture.check()


class ImportLinksFixture:
    """Read actual pinned source PNG bytes; all cache/metadata stand-ins stay in memory."""
    def __init__(self):
        self.cfg = cfg_fixture()
        self.root = Path(self.cfg["project"])
        expected = {policy.ART + "background.png": "46492785829f659c5869d91a6510d424ea4977e6921b1ece7de1225aa804e6ca",
            policy.ART + "counters/grand_table_left.png": "9a96841d98e0f5ee53d15563c94881f3ce34ab4569182f7009f6b0609c4dafac",
            policy.ART + "counters/grand_table_right.png": "de3a5e82cce15772a929306eb423aaf44b96ff3302cf8c73aec1eb12b7dc0964"}
        self.data, self.paths = {}, {}
        self.cfg["candidate_files"] = dict(expected)
        for index, name in enumerate(sorted(policy.PNG_CHANGES)):
            raw = (policy.FIXED_SOURCE / name).read_bytes()
            if hashlib.sha256(raw).hexdigest() != expected[name]:
                raise AssertionError("Pinned historical source PNG changed: " + name)
            source = self.root / name
            imported = self.root / (name + ".import")
            rel = ".godot/imported/fixture_%d.ctex" % index
            texture = self.root / rel
            self.data[source] = raw
            self.data[imported] = ('path="res://' + rel + '"\nsource_file="res://' + name + '"\n').encode()
            self.data[texture] = b"SYNTHETIC-CACHE-FIXTURE-NOT-A-REAL-COMPILED-IMAGE" * 2
            self.data[texture.with_suffix(".md5")] = ('source_md5="' + hashlib.md5(raw).hexdigest() + '"\n').encode()
            self.paths[name] = (source, imported, texture)
        self.relative_name = runner.selected.relative_name

    def plain(self, path, **kwargs):
        path = Path(path)
        if kwargs.get("file") and path not in self.data:
            raise FileNotFoundError(str(path))
        return path

    def check(self):
        # Replace the NEW runner's namespace reference, never frozen selected globals.
        namespace = SimpleNamespace(plain=self.plain, relative_name=self.relative_name)
        with patch.object(runner, "selected", namespace), \
             patch.object(runner, "sha", side_effect=lambda p: hashlib.sha256(self.data[Path(p)]).hexdigest()), \
             patch.object(Path, "read_bytes", side_effect=lambda *args: self.data[Path(args[0])], autospec=True), \
             patch.object(Path, "read_text", side_effect=lambda p, **kwargs: self.data[Path(p)].decode(), autospec=True), \
             patch.object(Path, "stat", side_effect=lambda p, **kwargs: SimpleNamespace(st_size=len(self.data[Path(p)])), autospec=True):
            return runner.import_links(self.cfg)


class ColdImportAndLinkageTests(unittest.TestCase):
    def setUp(self):
        self.f = ImportLinksFixture()
        self.links = self.f.check()
        self.assertEqual(set(self.links), set(policy.PNG_CHANGES))
        for name, row in self.links.items():
            self.assertEqual(row["source_sha256"], self.f.cfg["candidate_files"][name])
        with patch.object(Path, "exists", return_value=False):
            runner.require_cold_import(self.f.cfg)

    def test_all_three_actual_source_pngs_bind_source_md5_and_compiled_hashes(self):
        self.assertEqual(len(self.f.check()), 3)

    def test_preexisting_import_cache_is_rejected_without_cleanup(self):
        with patch.object(Path, "exists", return_value=True), self.assertRaises(ValueError):
            runner.require_cold_import(self.f.cfg)

    def test_wrong_source_png_or_stale_md5_cannot_pass_linkage(self):
        name = sorted(self.f.paths)[0]
        source, imported, texture = self.f.paths[name]
        self.f.data[source] += b"changed"
        with self.assertRaises(ValueError):
            self.f.check()
        fixture = ImportLinksFixture(); fixture.check()
        source, imported, texture = fixture.paths[name]
        fixture.data[texture.with_suffix(".md5")] = b'source_md5="00000000000000000000000000000000"\n'
        with self.assertRaises(ValueError):
            fixture.check()

    def test_foreign_or_ambiguous_source_import_remap_is_rejected(self):
        name = sorted(self.f.paths)[0]
        for text in ('path="res://assets/foreign.ctex"\nsource_file="res://' + name + '"\n',
                     'path="res://.godot/imported/fixture_0.ctex"\nsource_file="res://assets/foreign.png"\n',
                     'path="res://.godot/imported/fixture_0.ctex"\npath="res://.godot/imported/other.ctex"\nsource_file="res://' + name + '"\n'):
            fixture = ImportLinksFixture(); fixture.check()
            fixture.data[fixture.paths[name][1]] = text.encode()
            with self.subTest(text=text), self.assertRaises(ValueError):
                fixture.check()

    def test_identity_rechecks_compiled_bytes_after_source_identity_was_closed(self):
        cfg = self.f.cfg
        identity = {"files": {"scripts/fixture.gd": "6" * 64}, "candidate_import_links": self.links}
        result = {"artifacts": {"identity_sha256": "7" * 64, "capture_inputs_sha256": "8" * 64}}
        def digest(path):
            return "7" * 64 if Path(path).name == "gbr_composition_preview_identity.json" else "8" * 64
        with patch.object(runner, "previous", return_value=result), patch.object(runner, "sha", side_effect=digest), \
             patch.object(runner, "read", return_value=identity), patch.object(runner, "identity_files", return_value=identity["files"]), \
             patch.object(runner, "verify_prepared"), patch.object(runner, "import_links", return_value=self.links) as links:
            self.assertIs(runner.verify_identity(cfg), identity)
            wrong = deepcopy(self.links); wrong[next(iter(wrong))]["compiled_sha256"] = "9" * 64
            links.return_value = wrong
            with self.assertRaises(ValueError):
                runner.verify_identity(cfg)


class SourceGateWiringTests(unittest.TestCase):
    def setUp(self):
        self.driver = ast.parse(Path(runner.__file__).read_text(encoding="utf-8"))
        self.profile = ast.parse(Path(policy.__file__).read_text(encoding="utf-8"))

    @staticmethod
    def function(tree, name):
        return next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == name)

    @staticmethod
    def calls(function):
        result = {}
        for node in ast.walk(function):
            if not isinstance(node, ast.Call):
                continue
            name = node.func.id if isinstance(node.func, ast.Name) else node.func.attr if isinstance(node.func, ast.Attribute) else None
            if name is not None:
                result[name] = min(result.get(name, node.lineno), node.lineno)
        return result

    def test_actual_historical_positive_material_contacts_and_cold_cache_gates_are_wired(self):
        main_calls = self.calls(self.function(self.driver, "main"))
        self.assertLess(main_calls["config"], main_calls["plan_layout"])
        self.assertLess(main_calls["require_cold_import"], main_calls["prepare_layout"])
        config_calls = self.calls(self.function(self.driver, "config"))
        self.assertIn("archived_context_control", config_calls)
        admission_calls = self.calls(self.function(self.profile, "load_admission"))
        self.assertIn("check_material_contract", admission_calls)
        self.assertIn("check_contact_masks", admission_calls)
        self.assertIn("check_floor_masks", admission_calls)
        self.assertIn("check_donor_ledger", admission_calls)

    def test_real_historical_positive_uses_its_own_identity_and_never_grants_visual_go(self):
        actual = policy.archived_context_control()
        self.assertEqual((actual["source_files"], actual["checks"]), (3964, 7969))
        self.assertTrue(actual["positive_control_only"])
        self.assertFalse(actual["visual_acceptance"])
        self.assertFalse(actual["formal_native_acceptance"])



class FloorDepthFixture:
    def __init__(self):
        self.original = image(WIDTH, HEIGHT)
        self.master = copied_image(self.original)
        self.physical = {key: bytearray(PIXELS) for key in policy.RAW_RECTS}
        self.band = {key: bytearray(PIXELS) for key in policy.RAW_RECTS}
        self.office = bytearray(PIXELS)
        rectangle(self.office, 800, 640, 20, 20)
        for key, x in (("grand_table_left", 200), ("grand_table_right", 1200)):
            rectangle(self.physical[key], x, 600, 24, 40)
            rectangle(self.band[key], x, 604, 24, 12)

    def check(self):
        return policy.check_floor_masks(self.original, self.master, self.physical, self.office, self.band)


class OfficeAndFloorBandTests(unittest.TestCase):
    def setUp(self):
        self.f = FloorDepthFixture()
        value = self.f.check()
        self.assertEqual(value["office_original_pixels"], 400)
        self.assertEqual(value["band_solid_pixels"], {"grand_table_left": 288, "grand_table_right": 288})
        self.assertIs(value["floor_616_join_visual_acceptance"], False)

    def test_exact_office_and_real_leg_band_intersections_do_not_approve_join_visuals(self):
        self.assertTrue(self.f.check()["office_rgb_exact"])

    def test_office_cannot_be_repainted_or_occluded_even_with_matching_replay_rgb(self):
        write_pixel(self.f.master, 800, 640, (42, 25, 19, 255))
        with self.assertRaises(ValueError):
            self.f.check()
        fixture = FloorDepthFixture(); fixture.check()
        rectangle(fixture.physical["grand_table_left"], 800, 640, 2, 2)
        with self.assertRaises(ValueError):
            fixture.check()

    def test_missing_leg_intersection_extra_floor_or_row616_cannot_be_hidden_by_mask(self):
        for x, y, value in ((200, 604, 0), (300, 604, 1), (200, 616, 1)):
            fixture = FloorDepthFixture(); fixture.check()
            fixture.band["grand_table_left"][y * WIDTH + x] = value
            with self.subTest(x=x, y=y), self.assertRaises(ValueError):
                fixture.check()


class DonorFixture:
    def __init__(self):
        self.raw = copied_image(image(1815, 867, (7, 53, 29, 255)))
        self.original = image(WIDTH, HEIGHT)
        self.master = copied_image(self.original)
        self.edit = bytearray(PIXELS)
        write_pixel(self.raw, 800, 400, (10, 80, 35, 255))
        write_pixel(self.raw, 100, 520, (60, 20, 9, 255))
        write_pixel(self.raw, 102, 522, (70, 24, 11, 255))
        self.ledger = {"schema": "bth.native_block_donors/v1", "block": [2, 2],
            "ordered_last_write_wins": True,
            "columns": ["target_x", "target_y", "width", "height", "source", "source_x", "source_y", "component"],
            "rows": [[400, 500, 2, 2, "raw", 800, 400, "clean_floor_corridor"],
                     [402, 500, 2, 2, "raw", 100, 520, "furniture:apron"],
                     [400, 500, 2, 2, "raw", 102, 522, "furniture:edge"]]}
        rectangle(self.edit, 400, 500, 4, 2)
        # Hand-specified expected final colors: the THIRD donor wins first block.
        for y in (500, 501):
            for x in (400, 401):
                write_pixel(self.master, x, y, (70, 24, 11, 255))
            for x in (402, 403):
                write_pixel(self.master, x, y, (60, 20, 9, 255))

    def check(self):
        return policy.check_donor_ledger(self.ledger, self.raw, self.original, self.master, self.edit)


class DonorCustodyTests(unittest.TestCase):
    def setUp(self):
        self.f = DonorFixture()
        result = self.f.check()
        self.assertEqual((result["rows"], result["donor_covered_pixels"]), (3, 8))
        self.assertTrue(result["actual_RGBA_recomposed"])
        self.assertIs(result["recipe_transform_independently_rederived"], False)

    def test_ordered_overwrite_reconstructs_actual_pixels_not_recipe_claim(self):
        self.assertEqual(self.f.check()["donor_covered_pixels"], 8)

    def test_ledger_gap_or_wrong_last_writer_cannot_claim_master_identity(self):
        self.f.ledger["rows"].pop(1)
        with self.assertRaises(ValueError):
            self.f.check()
        fixture = DonorFixture(); fixture.check()
        fixture.ledger["rows"][-1][5:7] = [800, 400]
        with self.assertRaises(ValueError):
            fixture.check()

    def test_stale_raw_or_changed_unsourced_master_pixel_is_rejected(self):
        write_pixel(self.f.raw, 100, 520, (61, 20, 9, 255))
        with self.assertRaises(ValueError):
            self.f.check()
        fixture = DonorFixture(); fixture.check()
        write_pixel(fixture.master, 1000, 700, (70, 24, 11, 255))
        with self.assertRaises(ValueError):
            fixture.check()

    def test_clean_floor_cannot_borrow_table_or_unadmitted_raw_corridor(self):
        for column, value in ((0, 0), (1, 328), (5, 100), (6, 700), (7, "unreviewed-floor")):
            fixture = DonorFixture(); fixture.check()
            fixture.ledger["rows"][0][column] = value
            with self.subTest(column=column, value=value), self.assertRaises(ValueError):
                fixture.check()

    def test_serialized_coordinates_wrong_block_or_foreign_source_are_rejected(self):
        for column, value in ((0, True), (1, 501), (2, 4), (3, 1), (4, "original"), (5, 800.0), (6, "400")):
            fixture = DonorFixture(); fixture.check()
            fixture.ledger["rows"][0][column] = value
            with self.subTest(column=column, value=value), self.assertRaises(ValueError):
                fixture.check()


if __name__ == "__main__":
    unittest.main()

