"""In-memory HL policy contracts. Source only until parent guarded execution."""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import high_limit_spatial_test_profile as policy


def raw(value):
    return json.dumps(value, separators=(",", ":")).encode()


def source_json():
    return {"environment_id": policy.ENVIRONMENT, "board_size": [900, 430], "pixel_scale": 2,
        "animations": [{"id": name, "rect": [250 + index * 100, 124, 52, 8], "period": 0.9817477042468103,
            "phase": 0.0, "web_low_detail": name in policy.LOW_IDS} for index, name in enumerate(policy.ANIMATION_IDS)]}


def changed_json():
    value = source_json()
    for index in range(5):
        value["animations"][index]["rect"][1] = 8
    return value


def baseline_fixture():
    hl_paths = [policy.ART + "anim/" + name + ".png" for name in policy.ANIMATION_IDS] + [
        policy.ART + "background.png", policy.ART + "counters/grand_table_left.png", policy.ART + "counters/grand_table_right.png"]
    pngs = hl_paths + ["assets/art/environments/retained/p%03d.png" % i for i in range(381)]
    jsons = [policy.HL_JSON, policy.INDEX_JSON] + ["data/art/environments/retained%02d.json" % i for i in range(19)]
    art = {name: "1" * 64 for name in pngs + jsons}
    textures = {".godot/imported/test%03d.ctex" % i: hashlib.sha256(("old" + str(i)).encode()).hexdigest() for i in range(400)}
    return {"source_commit": "a" * 40, "source_tree": "b" * 40, "art_source_files": art,
        "compiled_art_sha256": textures, "active_art_packages": {"bar": policy.BAR_SHA, "grand_casino": "2" * 64,
            policy.ENVIRONMENT: "3" * 64, **{"room%d" % i: "4" * 64 for i in range(17)}},
        "active_doorway_packages": {"door%d" % i: "5" * 64 for i in range(12)},
        "files": {"index.html": {"bytes": 1, "sha256": "1" * 64}, "index.pck": {"bytes": 2, "sha256": "2" * 64},
                  "index.js": {"bytes": 3, "sha256": "3" * 64}, "native.wasm": {"bytes": 4, "sha256": "4" * 64}},
        "channel": "test", "platform": "web", "engine_sha256": "6" * 64, "export_presets_sha256": "7" * 64,
        "native_library_path": "native.wasm", "native_library_sha256": "8" * 64, "template_sha256": "9" * 64,
        "persistence_core_sha256": "a" * 64, "test_args": ["--", "--bth-art-test"],
        "persistent_paths": ["/userfs/isolated-test"]}


def manifest_fixture(base):
    value = deepcopy(base)
    value["art_source_files"] = policy.expected_raw(base)
    value["active_art_packages"][policy.ENVIRONMENT] = policy.PACKAGE_SHA
    value["art_package_sha256"] = policy.PACKAGE_SHA
    for index, name in enumerate(list(base["compiled_art_sha256"])[:9]):
        value["compiled_art_sha256"][name] = hashlib.sha256(("new" + str(index)).encode()).hexdigest()
    return value


def declaration(base):
    return {"schema": policy.BASELINE_SCHEMA, "source_commit": base["source_commit"], "source_tree": base["source_tree"],
        **{key: "c" * 64 for key in ("manifest_sha256", "pck_sha256", "grand_approval_sha256", "grand_strict_pck_proof_sha256",
            "grand_served_proof_sha256", "grand_served_job_sha256")}, "uid_cache_sha256": policy.UID_SHA,
        "uid_map_sha256": policy.UID_MAP_SHA, "class_cache_sha256": policy.CLASS_SHA, "preserved_bar_seal": policy.BAR_SHA,
        "protected_room_seals": {key: value for key, value in base["active_art_packages"].items() if key != policy.ENVIRONMENT},
        "stage": "E:/CodexQA/BTH/workspaces/future-grand/stage",
        "grand_approval_path": "E:/CodexQA/BTH/runs/future-approval/evidence/approval.json",
        "grand_strict_pck_proof_path": "E:/CodexQA/BTH/runs/future-proof/evidence/pck.json",
        "grand_served_proof_path": "E:/CodexQA/BTH/runs/future-served/evidence/served.json"}


class TypedLampContractTests(unittest.TestCase):
    def check(self, value):
        return policy.check_json_semantics(raw(source_json()), raw(value))

    def test_exact_five_integer_y_changes_pass(self):
        self.assertEqual(self.check(changed_json()), changed_json())

    def test_bool_float_and_string_y_are_rejected(self):
        for bad in (True, 8.0, "8"):
            value = changed_json()
            value["animations"][0]["rect"][1] = bad
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                self.check(value)

    def test_missing_one_of_five_moves_is_rejected(self):
        value = changed_json()
        value["animations"][4]["rect"][1] = 124
        with self.assertRaises(ValueError):
            self.check(value)

    def test_other_rect_timing_phase_flags_and_ids_cannot_change(self):
        mutations = [lambda v: v["animations"][0]["rect"].__setitem__(0, 249),
            lambda v: v["animations"][5].__setitem__("period", 1.0), lambda v: v["animations"][8].__setitem__("phase", 1.0),
            lambda v: v["animations"][1].__setitem__("web_low_detail", 1), lambda v: v["animations"][0].__setitem__("id", "other")]
        for mutate in mutations:
            value = changed_json()
            mutate(value)
            with self.subTest(mutation=mutate), self.assertRaises(ValueError):
                self.check(value)

    def test_extra_entry_or_field_is_rejected(self):
        for value in (dict(changed_json(), unexpected=True), dict(changed_json(), animations=changed_json()["animations"][:-1])):
            with self.assertRaises(ValueError):
                self.check(value)

    def test_duplicate_json_key_and_nan_are_rejected(self):
        for value in (b'{"id":1,"id":2}', b'{"number":NaN}'):
            with self.assertRaises(ValueError):
                policy.json_value(value)

    def test_public_hash_gate_cannot_accept_synthetic_semantic_match(self):
        with self.assertRaises(ValueError):
            policy.check_json(raw(source_json()), raw(changed_json()))


class ProtectedInventoryContractTests(unittest.TestCase):
    def setUp(self):
        self.base = baseline_fixture()
        self.manifest = manifest_fixture(self.base)
        self.targets = set(list(self.base["compiled_art_sha256"])[:9])

    def check(self):
        policy.validate_manifest(self.manifest, self.base, self.targets)

    def test_exact_hl_inventory_policy_passes(self):
        self.check()

    def test_raw_other_room_and_global_index_changes_are_rejected(self):
        for name in (policy.INDEX_JSON, "assets/art/environments/retained/p000.png"):
            value = deepcopy(self.manifest)
            value["art_source_files"][name] = "f" * 64
            with self.assertRaises(ValueError):
                policy.validate_manifest(value, self.base, self.targets)

    def test_delivered_grand_and_bar_seals_cannot_change(self):
        for name in ("grand_casino", "bar"):
            value = deepcopy(self.manifest)
            value["active_art_packages"][name] = "f" * 64
            with self.assertRaises(ValueError):
                policy.validate_manifest(value, self.base, self.targets)

    def test_doorway_and_engine_pins_cannot_change(self):
        for key in ("engine_sha256", "template_sha256", "native_library_sha256", "persistence_core_sha256"):
            value = deepcopy(self.manifest)
            value[key] = "f" * 64
            with self.assertRaises(ValueError):
                policy.validate_manifest(value, self.base, self.targets)
        self.manifest["active_doorway_packages"]["door0"] = "f" * 64
        with self.assertRaises(ValueError):
            self.check()

    def test_unreviewed_or_missing_texture_change_is_rejected(self):
        for index in (0, 9):
            value = deepcopy(self.manifest)
            name = list(self.base["compiled_art_sha256"])[index]
            value["compiled_art_sha256"][name] = self.base["compiled_art_sha256"][name] if index == 0 else "f" * 64
            with self.assertRaises(ValueError):
                policy.validate_manifest(value, self.base, self.targets)

    def test_web_payload_or_persistence_mount_cannot_change(self):
        self.manifest["files"]["index.js"]["bytes"] += 1
        with self.assertRaises(ValueError):
            self.check()
        self.manifest = manifest_fixture(self.base)
        self.manifest["persistent_paths"] = ["/userfs/ordinary-save"]
        with self.assertRaises(ValueError):
            self.check()

    def test_non_test_channel_is_rejected(self):
        self.manifest["channel"] = "next"
        with self.assertRaises(ValueError):
            self.check()

    def test_package_has_exact19_png_plus_json_and_index(self):
        paths = policy.payload_paths(self.base)
        self.assertEqual(len(paths), 21)
        self.assertEqual(sum(path.endswith(".png") for path in paths), 19)
        observed = {name: self.base["art_source_files"][name] for name in paths}
        observed.update(policy.PNG_SHAS)
        observed[policy.HL_JSON] = policy.HL_JSON_SHA
        # Its synthetic retained files must not impersonate the real21 seal.
        with self.assertRaises(ValueError):
            policy.candidate_hashes(self.base, observed)

    def test_canonical_imports_reject_missing_extra_or_changed_sidecars(self):
        self.assertFalse(policy.check_import_hashes(dict(policy.IMPORT_SHAS))["art_approval"])
        changed = dict(policy.IMPORT_SHAS)
        changed[next(iter(changed))] = "f" * 64
        missing = dict(policy.IMPORT_SHAS)
        del missing[next(iter(missing))]
        extra = {**policy.IMPORT_SHAS, "unrelated.png.import": "f" * 64}
        for value in (changed, missing, extra):
            with self.assertRaises(ValueError):
                policy.check_import_hashes(value)

    def test_actual_source_hashes_reject_unrelated_room_change(self):
        observed = policy.expected_raw(self.base)
        observed["assets/art/environments/retained/p000.png"] = "f" * 64
        with self.assertRaises(ValueError):
            policy.check_source_hashes(self.base, observed)


class BaselineTrustContractTests(unittest.TestCase):
    def setUp(self):
        self.base = baseline_fixture()
        self.value = declaration(self.base)

    def test_well_formed_declaration_never_grants_baseline_trust(self):
        result = policy.check_baseline_declaration(self.value)
        self.assertFalse(result["baseline_qualified"])
        self.assertEqual(result["status"], "DECLARATION_ONLY_NOT_BASELINE_QUALIFICATION")

    def test_missing_actual_future_hash_or_zero_placeholder_is_rejected(self):
        for key in ("pck_sha256", "manifest_sha256", "grand_served_proof_sha256", "grand_strict_pck_proof_sha256"):
            value = deepcopy(self.value)
            value[key] = "0" * 64
            with self.assertRaises(ValueError):
                policy.check_baseline_declaration(value)

    def test_arbitrary_uid_cache_or_missing_delivered_grand_is_rejected(self):
        value = deepcopy(self.value)
        value["uid_cache_sha256"] = "f" * 64
        with self.assertRaises(ValueError):
            policy.check_baseline_declaration(value)
        value = deepcopy(self.value)
        del value["protected_room_seals"]["grand_casino"]
        with self.assertRaises(ValueError):
            policy.check_baseline_declaration(value)

    def test_c_output_or_parent_path_is_rejected(self):
        for path in ("C:/tmp/stage", "E:/CodexQA/BTH/../outside"):
            value = deepcopy(self.value)
            value["stage"] = path
            with self.assertRaises(ValueError):
                policy.check_baseline_declaration(value)

    def test_static_native_trial_approval_cannot_authorize_test(self):
        with self.assertRaises(ValueError):
            policy.check_approval_declaration({"schema": policy.APPROVAL_SCHEMA, "environment_id": policy.ENVIRONMENT,
                "verdict": "STATIC_GO_FOR_NATIVE_TRIAL"}, self.base)

    def test_even_complete_final_declaration_does_not_authenticate_receipts(self):
        value = {"schema": policy.APPROVAL_SCHEMA, "environment_id": policy.ENVIRONMENT, "verdict": "GO_FOR_TEST_BUILD",
            "approved_png_sha256": policy.PNG_SHAS, "high_limit_json_sha256": policy.HL_JSON_SHA,
            "high_limit_package_sha256": policy.PACKAGE_SHA, "baseline": self.value,
            "reviewer": "unit fixture; not actual approval", "evidence": ["fixture://not-acceptance"],
            "source_commit": "d" * 40, "source_tree": "e" * 40,
            **{key: "f" * 64 for key in ("native_identity_sha256", "native_contexts_sha256", "native_motion_sha256",
                "native_liveness_sha256", "native_capture_sha256", "final_art_review_sha256")}}
        result = policy.check_approval_declaration(value, self.base)
        self.assertFalse(result["baseline_qualified"])
        self.assertFalse(result["native_receipts_authenticated"])


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


class ActualPckPayloadContractTests(unittest.TestCase):
    def setUp(self):
        self.base = baseline_fixture()
        self.old = {name: ("old" + str(index)).encode() for index, name in enumerate(self.base["compiled_art_sha256"])}
        self.base["art_source_files"][policy.HL_JSON] = policy.sha(raw(source_json()))
        for name in self.base["art_source_files"]:
            if name.endswith(".json"):
                data = raw(source_json()) if name == policy.HL_JSON else b"{}"
                self.old[name] = data
                self.base["art_source_files"][name] = policy.sha(data)
        for source, target in zip(policy.PNG_SHAS, list(self.base["compiled_art_sha256"])[:9]):
            self.old[source + ".import"] = ('[remap]\npath="res://' + target + '"\n').encode()
        uid = bytearray(struct.pack("<I", 1605))
        mapping = {}
        for index in range(1605):
            path = "res://scripts/f%04d.gd" % index
            encoded = path.encode()
            uid.extend(struct.pack("<QI", index + 1, len(encoded)) + encoded)
            mapping[path] = str(index + 1)
        self.uid = bytes(uid)
        self.mapping_sha = policy.sha(json.dumps(mapping, sort_keys=True, separators=(",", ":")).encode())
        self.old.update({".godot/uid_cache.bin": self.uid, ".godot/global_script_class_cache.cfg": b"class fixture",
            "build_manifest.json": b"old identity", "scripts/run.gdc": b"compiled original", "scenes/main.scn": b"scene original"})
        self.manifest = manifest_fixture(self.base)
        self.new = dict(self.old)
        for index, name in enumerate(list(self.base["compiled_art_sha256"])[:9]):
            self.new[name] = ("new" + str(index)).encode()
        self.new[policy.HL_JSON] = raw(changed_json())
        self.manifest["art_source_files"][policy.HL_JSON] = policy.sha(self.new[policy.HL_JSON])
        self.new["build_manifest.json"] = b"new identity"

    def verify(self):
        old, new = pck(self.old), pck(self.new)
        with patch.object(policy, "UID_SHA", policy.sha(self.uid)), patch.object(policy, "UID_MAP_SHA", self.mapping_sha), \
                patch.object(policy, "CLASS_SHA", policy.sha(b"class fixture")), \
                patch.object(policy, "BASE_HL_JSON_SHA", policy.sha(raw(source_json()))), \
                patch.object(policy, "HL_JSON_SHA", policy.sha(raw(changed_json()))):
            return policy.verify_pck_delta(old, new, self.base, self.manifest, policy.sha(old))

    def test_actual_payload_delta_matches_nine_targets_json_and_identity(self):
        result = self.verify()
        self.assertEqual(len(result["changed"]), 11)
        self.assertFalse(result["baseline_qualified"])
        self.assertTrue(result["all_scn_gdc_bytes_equal"])
        self.assertFalse(result["embedded_identity_authenticated"])

    def test_scn_gdc_uid_class_or_unrelated_texture_change_is_rejected(self):
        for name in ("scenes/main.scn", "scripts/run.gdc", ".godot/uid_cache.bin", ".godot/global_script_class_cache.cfg",
                     list(self.base["compiled_art_sha256"])[10]):
            original = self.new[name]
            self.new[name] = b"unexpected changed resource"
            with self.subTest(resource=name), self.assertRaises(ValueError):
                self.verify()
            self.new[name] = original

    def test_added_resource_is_rejected(self):
        self.new["tools/new_observer.gdc"] = b"new UID observer"
        with self.assertRaises(ValueError):
            self.verify()

    def test_missing_expected_texture_change_is_rejected(self):
        name = next(iter(self.base["compiled_art_sha256"]))
        self.new[name] = self.old[name]
        with self.assertRaises(ValueError):
            self.verify()


if __name__ == "__main__":
    unittest.main()
