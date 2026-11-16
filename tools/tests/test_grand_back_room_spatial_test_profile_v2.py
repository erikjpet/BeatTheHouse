"""In-memory GBR pure contracts only; parent owns guarded test execution.

No file/profile/network/engine/child operations. Synthetic PCK fixtures replace
only constants in the new GBR module, never globals in a frozen prior module.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import unittest
from unittest.mock import patch
from contextlib import ExitStack

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import grand_back_room_spatial_test_profile_v2 as policy


def raw(value):
    return json.dumps(value, separators=(",", ":")).encode()


def original_json():
    return {"environment_id": policy.ENVIRONMENT, "board_size": [900, 430], "pixel_scale": 2,
        "animations": [{"id": name, "rect": [250 + index * 100, 124, 52, 8], "period": 0.9817477042468103,
            "phase": 0.625, "web_low_detail": name in policy.LOW_IDS} for index, name in enumerate(policy.ANIMATION_IDS)]}


def candidate_json():
    value = original_json()
    value["animations"][2]["rect"][0] = 448
    return value


def baseline_fixture():
    art = {**policy.BASE_PAYLOAD_SHAS,
        **{"assets/art/environments/retained/p%03d.png" % i: "1" * 64 for i in range(381)},
        **{"data/art/environments/retained%02d.json" % i: "2" * 64 for i in range(19)}}
    compiled = {row["compiled_target"]: row["baseline_compiled_sha256"] for row in policy.IMPORT_BINDINGS.values()}
    compiled.update({".godot/imported/retained%03d.ctex" % i: hashlib.sha256(("old" + str(i)).encode()).hexdigest() for i in range(391)})
    return {"art_source_files": art, "compiled_art_sha256": compiled,
        "active_art_packages": {**policy.PROTECTED_SEALS, policy.ENVIRONMENT: policy.BASE_ACTIVATION_SHA,
            **{"room%d" % i: "4" * 64 for i in range(16)}},
        "active_doorway_packages": {"door%d" % i: "5" * 64 for i in range(12)},
        "files": {"index.html": {"bytes": 1, "sha256": "1" * 64}, "index.pck": {"bytes": 2, "sha256": "2" * 64},
            "index.js": {"bytes": 3, "sha256": "3" * 64}, "native.wasm": {"bytes": 4, "sha256": "4" * 64}},
        "channel": "test", "platform": "web", "engine_sha256": "6" * 64, "export_presets_sha256": "7" * 64,
        "native_library_path": "native.wasm", "native_library_sha256": "8" * 64, "template_sha256": "9" * 64,
        "persistence_core_sha256": "a" * 64, "test_args": ["--", "--bth-art-test"], "persistent_paths": ["/userfs/isolated-test"]}


def manifest_fixture(base):
    value = deepcopy(base)
    value["art_source_files"] = policy.expected_raw(base)
    value["active_art_packages"][policy.ENVIRONMENT] = policy.PACKAGE_SHA
    value["art_package_sha256"] = policy.PACKAGE_SHA
    for index, row in enumerate(policy.IMPORT_BINDINGS.values()):
        value["compiled_art_sha256"][row["compiled_target"]] = hashlib.sha256(("new" + str(index)).encode()).hexdigest()
    return value


class TypedLampTests(unittest.TestCase):
    def check(self, candidate):
        return policy.check_json_semantics(raw(original_json()), raw(candidate))

    def test_exact_single_integer_x_move_passes(self):
        self.assertEqual(self.check(candidate_json()), candidate_json())

    def test_float_bool_string_missing_and_unmoved_x_fail(self):
        for value in (448.0, True, "448", None, 450):
            candidate = candidate_json()
            candidate["animations"][2]["rect"][0] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.check(candidate)

    def test_other_geometry_timing_phase_and_low_types_fail(self):
        changes = [lambda v: v["animations"][2]["rect"].__setitem__(1, 123),
            lambda v: v["animations"][0]["rect"].__setitem__(0, 248),
            lambda v: v["animations"][1].__setitem__("period", 1),
            lambda v: v["animations"][2].__setitem__("phase", 0.6250001),
            lambda v: v["animations"][2].__setitem__("web_low_detail", 1),
            lambda v: v.__setitem__("pixel_scale", 2.0)]
        for change in changes:
            candidate = candidate_json()
            change(candidate)
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.check(candidate)

    def test_missing_extra_reordered_or_renamed_animations_fail(self):
        values = []
        for action in (lambda v: v["animations"].pop(), lambda v: v["animations"].append(dict(v["animations"][0])),
                       lambda v: v["animations"].reverse(), lambda v: v["animations"][2].__setitem__("id", "other")):
            value = candidate_json()
            action(value)
            values.append(value)
        for value in values:
            with self.assertRaises(ValueError):
                self.check(value)

    def test_extra_field_and_changed_environment_or_board_type_fail(self):
        for value in (dict(candidate_json(), unexpected=True), dict(candidate_json(), environment_id="grand_casino"),
                      dict(candidate_json(), board_size=[900.0, 430])):
            with self.assertRaises(ValueError):
                self.check(value)

    def test_original_lamp_rect_must_be_typed_exact(self):
        original = original_json()
        original["animations"][2]["rect"][0] = 450.0
        with self.assertRaises(ValueError):
            policy.check_json_semantics(raw(original), raw(candidate_json()))

    def test_duplicate_json_keys_nan_and_infinity_fail(self):
        for value in (b'{"x":1,"x":2}', b'{"x":NaN}', b'{"x":Infinity}'):
            with self.assertRaises(ValueError):
                policy.json_value(value)

    def test_exact_hash_gate_rejects_a_synthetic_semantic_match(self):
        with self.assertRaises(ValueError):
            policy.check_json(raw(original_json()), raw(candidate_json()))


class SourceAndMetadataTests(unittest.TestCase):
    def setUp(self):
        self.base = baseline_fixture()

    def test_exact_reviewed21_and_full421_source_map_pass_without_authority(self):
        self.assertEqual(policy.package_seal(policy.PAYLOAD_SHAS), policy.PACKAGE_SHA)
        result = policy.check_source_hashes(self.base, policy.expected_raw(self.base))
        self.assertEqual(len(result["files"]), 21)
        self.assertFalse(result["art_approval"])
        self.assertFalse(result["baseline_qualified"])
        self.assertFalse(result["native_receipts_authenticated"])

    def test_missing_extra_or_changed_package_member_fails(self):
        good = dict(policy.PAYLOAD_SHAS)
        bad = [dict(good, unexpected="f" * 64), {name: value for name, value in good.items() if name != policy.INDEX_JSON},
               {**good, policy.INDEX_JSON: "f" * 64}]
        for value in bad:
            with self.assertRaises(ValueError):
                policy.candidate_hashes(self.base, value)

    def test_rejected_v1_or_arbitrary_background_fails(self):
        observed = dict(policy.PAYLOAD_SHAS)
        observed[policy.ART + "background.png"] = "f" * 64
        with self.assertRaises(ValueError):
            policy.candidate_hashes(self.base, observed)

    def test_original21_donor_and_membership_cannot_be_replaced(self):
        for name in (policy.GBR_JSON, policy.INDEX_JSON, policy.ART + "anim/floor_glint_0.png"):
            value = deepcopy(self.base)
            value["art_source_files"][name] = "f" * 64
            with self.assertRaises(ValueError):
                policy.payload_paths(value)
        value = deepcopy(self.base)
        value["art_source_files"][policy.ART + "extra.png"] = "f" * 64
        with self.assertRaises(ValueError):
            policy.payload_paths(value)

    def test_other_room_global_index_and_retained_gbr_png_cannot_change(self):
        for name in (policy.INDEX_JSON, "assets/art/environments/retained/p000.png", policy.ART + "anim/floor_glint_6.png"):
            value = policy.expected_raw(self.base)
            value[name] = "f" * 64
            with self.subTest(path=name), self.assertRaises(ValueError):
                policy.check_source_hashes(self.base, value)

    def test_missing_or_extra_full_inventory_source_fails(self):
        for change in (lambda v: v.pop("assets/art/environments/retained/p000.png"), lambda v: v.__setitem__("extra.png", "f" * 64)):
            value = policy.expected_raw(self.base)
            change(value)
            with self.assertRaises(ValueError):
                policy.check_source_hashes(self.base, value)

    def test_hl_grand_bar_and_original_gbr_baseline_seals_are_mandatory(self):
        for room in (*policy.PROTECTED_SEALS, policy.ENVIRONMENT):
            value = deepcopy(self.base)
            value["active_art_packages"][room] = "f" * 64
            with self.subTest(room=room), self.assertRaises(ValueError):
                policy.expected_raw(value)

    def test_exact_nine_canonical_imports_match_without_authority(self):
        result = policy.check_import_hashes(dict(policy.IMPORT_SHAS))
        self.assertTrue(result["canonical_imports_match"])
        self.assertFalse(result["baseline_qualified"])

    def test_extra_missing_changed_or_foreign_import_fails(self):
        changed = dict(policy.IMPORT_SHAS)
        changed[next(iter(changed))] = "f" * 64
        missing = dict(policy.IMPORT_SHAS)
        missing.pop(next(iter(missing)))
        for value in (changed, missing, {**policy.IMPORT_SHAS, "other.png.import": "f" * 64}):
            with self.assertRaises(ValueError):
                policy.check_import_hashes(value)


class ManifestDeltaTests(unittest.TestCase):
    def setUp(self):
        self.base = baseline_fixture()
        self.value = manifest_fixture(self.base)
        self.targets = {row["compiled_target"] for row in policy.IMPORT_BINDINGS.values()}

    def test_exact_inventory_matches_without_qualifying_baseline(self):
        self.assertFalse(policy.validate_manifest(self.value, self.base, self.targets)["baseline_qualified"])

    def test_hl_grand_bar_or_other_room_activation_cannot_change(self):
        for room in (*policy.PROTECTED_SEALS, "room0"):
            value = deepcopy(self.value)
            value["active_art_packages"][room] = "f" * 64
            with self.assertRaises(ValueError):
                policy.validate_manifest(value, self.base, self.targets)

    def test_doorway_change_and_wrong_channel_fail(self):
        value = deepcopy(self.value)
        value["active_doorway_packages"]["door0"] = "f" * 64
        with self.assertRaises(ValueError):
            policy.validate_manifest(value, self.base, self.targets)
        self.value["channel"] = "next"
        with self.assertRaises(ValueError):
            policy.validate_manifest(self.value, self.base, self.targets)

    def test_unreviewed_missing_extra_or_foreign_texture_change_fails(self):
        name = next(iter(self.targets))
        for mutation in (lambda v: v["compiled_art_sha256"].__setitem__(name, self.base["compiled_art_sha256"][name]),
                         lambda v: v["compiled_art_sha256"].__setitem__(".godot/imported/retained000.ctex", "f" * 64),
                         lambda v: v["compiled_art_sha256"].pop(name),
                         lambda v: v["compiled_art_sha256"].__setitem__(".godot/imported/foreign.ctex", "f" * 64)):
            value = deepcopy(self.value)
            mutation(value)
            with self.assertRaises(ValueError):
                policy.validate_manifest(value, self.base, self.targets)
        with self.assertRaises(ValueError):
            policy.validate_manifest(self.value, self.base, {".godot/imported/foreign.ctex", *list(self.targets)[:8]})

    def test_engine_native_template_persistence_and_web_payload_pins_fail_closed(self):
        for key in ("engine_sha256", "template_sha256", "native_library_sha256", "export_presets_sha256", "persistence_core_sha256"):
            value = deepcopy(self.value)
            value[key] = "f" * 64
            with self.assertRaises(ValueError):
                policy.validate_manifest(value, self.base, self.targets)
        for key, replacement in (("test_args", []), ("persistent_paths", ["/userfs/real-save"])):
            value = deepcopy(self.value)
            value[key] = replacement
            with self.assertRaises(ValueError):
                policy.validate_manifest(value, self.base, self.targets)
        self.value["files"]["index.js"]["bytes"] += 1
        with self.assertRaises(ValueError):
            policy.validate_manifest(self.value, self.base, self.targets)

    def test_added_or_removed_web_file_fails(self):
        for change in (lambda v: v["files"].pop("index.js"), lambda v: v["files"].__setitem__("extra", {})):
            value = deepcopy(self.value)
            change(value)
            with self.assertRaises(ValueError):
                policy.validate_manifest(value, self.base, self.targets)


def pck(payloads):
    data = bytearray(112)
    struct.pack_into("<4sIIII", data, 0, b"GDPC", 3, 4, 6, 0)
    struct.pack_into("<IQ", data, 20, 2, 112)
    records = []
    for name, value in sorted(payloads.items()):
        records.append((name, len(data) - 112, value))
        data.extend(value)
    struct.pack_into("<Q", data, 32, len(data))
    data.extend(struct.pack("<I", len(records)))
    for name, offset, value in records:
        encoded = ("res://" + name).encode() + b"\0"
        data.extend(struct.pack("<I", len(encoded)) + encoded + b"\0" * ((-len(encoded)) % 4))
        data.extend(struct.pack("<QQ", offset, len(value)) + hashlib.md5(value).digest() + struct.pack("<I", 0))
    return bytes(data)


class ActualPckDeltaTests(unittest.TestCase):
    def setUp(self):
        self.base = baseline_fixture()
        self.old = {name: ("oldctex" + str(i)).encode() for i, name in enumerate(self.base["compiled_art_sha256"])}
        self.bindings = deepcopy(policy.IMPORT_BINDINGS)
        for source, binding in self.bindings.items():
            raw_import = ('[remap]\npath="res://' + binding["compiled_target"] + '"\n').encode()
            self.old[source + ".import"] = raw_import
            binding["pck_import_sha256"] = policy.sha(raw_import)
            binding["baseline_compiled_sha256"] = policy.sha(self.old[binding["compiled_target"]])
        for name in self.base["art_source_files"]:
            if name.endswith(".json"):
                payload = raw(original_json()) if name == policy.GBR_JSON else b"{}"
                self.old[name] = payload
                self.base["art_source_files"][name] = policy.sha(payload)
        self.base["compiled_art_sha256"] = {name: policy.sha(self.old[name]) for name in self.base["compiled_art_sha256"]}
        self.base_payload = {name: self.base["art_source_files"][name] for name in policy.BASE_PAYLOAD_SHAS}
        self.new_payload = {**self.base_payload, **policy.PNG_SHAS, policy.GBR_JSON: policy.sha(raw(candidate_json()))}
        self.base_sha, self.new_sha = policy.package_seal(self.base_payload), policy.package_seal(self.new_payload)
        self.base["active_art_packages"][policy.ENVIRONMENT] = policy.BASE_ACTIVATION_SHA
        uid = bytearray(struct.pack("<I", 1605));mapping = {}
        for i in range(1605):
            name = "res://scripts/test_%04d.gd" % i;encoded = name.encode()
            uid.extend(struct.pack("<QI", i + 1, len(encoded)) + encoded);mapping[name] = str(i + 1)
        self.uid = bytes(uid)
        self.uid_map_sha = policy.sha(json.dumps(mapping, sort_keys=True, separators=(",", ":")).encode())
        self.old.update({".godot/uid_cache.bin": self.uid, ".godot/global_script_class_cache.cfg": b"class fixture",
            "scripts/original.gdc": b"original GDC", "scenes/main.scn": b"original SCN", "build_manifest.json": b"old identity"})
        for i in range(2107 - len(self.old)):
            self.old["data/runtime_fixture_%04d.json" % i] = b"{}"
        self.new = dict(self.old)
        for i, binding in enumerate(self.bindings.values()):
            self.new[binding["compiled_target"]] = ("newctex" + str(i)).encode()
        self.new[policy.GBR_JSON] = raw(candidate_json());self.new["build_manifest.json"] = b"new unqualified identity"
        self.manifest = deepcopy(self.base)
        self.manifest["art_source_files"].update(self.new_payload)
        self.manifest["active_art_packages"][policy.ENVIRONMENT] = self.new_sha
        self.manifest["art_package_sha256"] = self.new_sha
        self.manifest["compiled_art_sha256"] = {name: policy.sha(self.new[name]) for name in self.base["compiled_art_sha256"]}

    def verify(self, old_bytes=None, new_bytes=None):
        old = pck(self.old) if old_bytes is None else old_bytes
        new = pck(self.new) if new_bytes is None else new_bytes
        replacements = {"IMPORT_BINDINGS": self.bindings, "BASE_PAYLOAD_SHAS": self.base_payload, "PAYLOAD_SHAS": self.new_payload,
            "BASE_PACKAGE_SHA": self.base_sha, "PACKAGE_SHA": self.new_sha, "BASE_GBR_JSON_SHA": policy.sha(raw(original_json())),
            "GBR_JSON_SHA": policy.sha(raw(candidate_json())), "UID_SHA": policy.sha(self.uid), "UID_MAP_SHA": self.uid_map_sha,
            "CLASS_SHA": policy.sha(b"class fixture")}
        with ExitStack() as stack:
            for name, value in replacements.items():
                stack.enter_context(patch.object(policy, name, value))
            return policy.verify_pck_delta(old, new, self.base, self.manifest, policy.sha(old))

    def test_exact2107_payload_delta_matches_without_authority(self):
        result = self.verify()
        self.assertEqual(result["resources"], 2107)
        self.assertEqual(result["uid_bindings"], 1605)
        self.assertEqual(len(result["changed"]), 11)
        self.assertTrue(result["all_scn_gdc_bytes_equal"])
        self.assertFalse(result["baseline_qualified"])
        self.assertFalse(result["embedded_identity_authenticated"])
        self.assertFalse(result["art_approval"])

    def test_scn_gdc_uid_class_foreign_texture_and_remap_changes_fail(self):
        for name in ("scenes/main.scn", "scripts/original.gdc", ".godot/uid_cache.bin", ".godot/global_script_class_cache.cfg",
                     ".godot/imported/retained000.ctex", next(iter(self.bindings)) + ".import"):
            original = self.new[name];self.new[name] = b"unexpected change"
            with self.subTest(path=name), self.assertRaises(ValueError):
                self.verify()
            self.new[name] = original

    def test_added_removed_or_same_count_swapped_resource_fails(self):
        self.new["tools/new_observer.gdc"] = b"observer"
        with self.assertRaises(ValueError):self.verify()
        self.new.pop("tools/new_observer.gdc")
        original = self.new.pop("data/runtime_fixture_0000.json")
        with self.assertRaises(ValueError):self.verify()
        self.new["data/runtime_fixture_replaced.json"] = original
        with self.assertRaises(ValueError):self.verify()

    def test_missing_expected_texture_change_fails(self):
        target = next(iter(self.bindings.values()))["compiled_target"]
        self.new[target] = self.old[target]
        with self.assertRaises(ValueError):self.verify()

    def test_manifest_must_match_actual_old_and_new_ctex_payloads(self):
        name = ".godot/imported/retained000.ctex"
        self.base["compiled_art_sha256"][name] = self.manifest["compiled_art_sha256"][name] = "f" * 64
        with self.assertRaises(ValueError):self.verify()

    def test_payload_mutation_without_directory_md5_change_fails(self):
        old = pck(self.old);new = bytearray(pck(self.new));new[112] ^= 1
        with self.assertRaises(ValueError):self.verify(old_bytes=old, new_bytes=bytes(new))

    def test_mutable_or_truncated_input_cannot_be_accepted(self):
        for value in (bytearray(pck(self.new)), b"GDPC"):
            with self.assertRaises(ValueError):self.verify(new_bytes=value)


class NativeReviewDeclarationTests(unittest.TestCase):
    def test_component_result_cannot_override_nonqualification_flags(self):
        value = policy.component_result(baseline_qualified=True, art_approval=True,
            native_receipts_authenticated=True, embedded_identity_authenticated=True, schema="forged")
        self.assertEqual(value["schema"], policy.SCHEMA)
        for name in ("baseline_qualified", "art_approval", "native_receipts_authenticated", "embedded_identity_authenticated"):
            self.assertFalse(value[name])

    def value(self):
        return {"schema": "bth.grand_back_room_spatial_native_art_review/v1", "decision": "GO_FOR_TEST_BUILD",
            "task_id": policy.TASK_ID, "room": policy.ENVIRONMENT, "environment": policy.ENVIRONMENT,
            "production_activation_approved": True, "independent_reviewer": "Synthetic declaration, not actual GO",
            "approved_package_files_sha256": dict(policy.PAYLOAD_SHAS), "package_21_file_sha256": policy.PACKAGE_SHA,
            "grand_back_room_json_sha256": policy.GBR_JSON_SHA, "native_adapter_sha256": policy.NATIVE_ADAPTER_SHA,
            "native_policy_sha256": policy.NATIVE_POLICY_SHA, "selected_source_helper_sha256": policy.SELECTED_SOURCE_SHA,
            "source_commit": "a" * 40, "source_tree": "b" * 40,
            **{name: "c" * 64 for name in ("native_source_config_sha256", "native_identity_sha256", "native_capture_inputs_sha256",
                "native_contexts_sha256", "native_motion_sha256", "native_liveness_sha256", "native_capture_sha256")},
            "native_phase_receipts": {phase: {} for phase in ("source-identity", "tree", "baseline-tree", "select", "archive", "prepare", "install", "import",
                "identity", "contexts", "motion", "liveness", "capture")}}

    def test_even_matching_review_declaration_never_qualifies_baseline_or_native(self):
        result = policy.check_native_review_declaration(self.value())
        self.assertFalse(result["baseline_qualified"])
        self.assertFalse(result["native_receipts_authenticated"])
        self.assertFalse(result["art_approval"])

    def test_static_go_or_hl_shaped_phase_map_cannot_substitute(self):
        value = self.value();value["decision"] = "STATIC_GO_FOR_NATIVE_TRIAL"
        with self.assertRaises(ValueError):policy.check_native_review_declaration(value)
        value = self.value();value["native_phase_receipts"] = {phase: {} for phase in ("identity", "contexts", "motion", "liveness", "capture")}
        with self.assertRaises(ValueError):policy.check_native_review_declaration(value)

    def test_wrong_candidate_helper_activation_or_source_hash_fails(self):
        for key, wrong in (("package_21_file_sha256", "f" * 64), ("native_adapter_sha256", "f" * 64),
                           ("production_activation_approved", False), ("source_commit", "0" * 40)):
            value = self.value();value[key] = wrong
            with self.assertRaises(ValueError):policy.check_native_review_declaration(value)




class ActualDeliveredHLBaselineTests(unittest.TestCase):
    def actual_manifest(self):
        path = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLBUILD2-20261116/qa_source/.tmp/web-release-b35412ac/stage/build_manifest.json")
        data = path.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), "8fff3a29d0bfd41527324ace7fd55e56c4307c5027504fd30e84ca9b02e46810")
        return json.loads(data)

    def test_actual_activation_map_and_distinct_logical21_seal_are_preserved(self):
        baseline = self.actual_manifest()
        self.assertEqual(baseline["active_art_packages"][policy.ENVIRONMENT], policy.BASE_ACTIVATION_SHA)
        self.assertNotEqual(policy.BASE_ACTIVATION_SHA, policy.BASE_PACKAGE_SHA)
        self.assertEqual(len(policy.payload_paths(baseline)), 21)
        actual21 = {name: baseline["art_source_files"][name] for name in policy.payload_paths(baseline)}
        self.assertEqual(policy.package_seal(actual21), policy.BASE_PACKAGE_SHA)
        result = policy.check_source_hashes(baseline, policy.expected_raw(baseline))
        self.assertEqual(result["package_sha256"], policy.PACKAGE_SHA)
        self.assertFalse(result["baseline_qualified"])

    def test_substituting_the_logical21_seal_into_actual_activation_map_fails(self):
        baseline = self.actual_manifest()
        baseline["active_art_packages"][policy.ENVIRONMENT] = policy.BASE_PACKAGE_SHA
        with self.assertRaises(ValueError):
            policy.expected_raw(baseline)

    def test_changed_actual_logical_source_map_fails_even_with_correct_activation(self):
        for name in (policy.GBR_JSON, policy.INDEX_JSON, policy.ART + "anim/floor_glint_0.png"):
            baseline = self.actual_manifest()
            baseline["art_source_files"][name] = "f" * 64
            with self.subTest(path=name), self.assertRaises(ValueError):
                policy.expected_raw(baseline)


if __name__ == "__main__":
    unittest.main()
