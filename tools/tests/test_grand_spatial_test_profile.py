"""In-memory regression cases; no fixture directories, jobs or network needed."""
import sys
sys.dont_write_bytecode = True

import copy
import hashlib
import json
from pathlib import Path
import struct
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import grand_spatial_test_profile as profile
import bar_spatial_test_build as build
import audit_pck_manifest


class GrandManifestContractTests(unittest.TestCase):
    def setUp(self):
        names = (["casino_light_" + str(i) for i in range(5)] + ["casino_sign_pulse"] +
                 ["casino_sparkle_" + str(i) for i in range(3)] + ["floor_glint_" + str(i) for i in range(7)])
        low = {"casino_light_1", "casino_light_2", "casino_light_3", "casino_sign_pulse",
               "floor_glint_0", "floor_glint_1", "floor_glint_2"}
        self.baseline = {"environment_id": "grand_casino", "animations": [
            {"id": name, "rect": [250, 124, 52, 8], "period": 0.9817477042468103,
             "phase": 0.0, "web_low_detail": name in low} for name in names]}
        self.original = json.dumps(self.baseline).encode()
        self.candidate = copy.deepcopy(self.baseline)
        self.candidate["animations"][0]["rect"][0] = 245

    def check(self, candidate, raw_hash=None):
        raw = json.dumps(candidate).encode()
        approval = {"grand_json_sha256": raw_hash or hashlib.sha256(raw).hexdigest()}
        with patch.object(profile, "plain", return_value=SimpleNamespace(read_bytes=lambda: self.original)), \
                patch.object(profile, "BASE_GRAND_JSON_SHA", hashlib.sha256(self.original).hexdigest()):
            return profile.check_json(raw, approval)

    def test_only_integer_lamp0_x_reanchor_is_accepted(self):
        result = self.check(self.candidate)
        self.assertEqual(result["animations"][0]["rect"], [245, 124, 52, 8])
        self.assertEqual(len(result["animations"]), 16)

    def test_float_equal_to_approved_integer_is_rejected(self):
        self.candidate["animations"][0]["rect"][0] = 245.0
        with self.assertRaises(ValueError):
            self.check(self.candidate)

    def test_integer_equal_to_low_detail_boolean_is_rejected(self):
        self.candidate["animations"][1]["web_low_detail"] = 1
        with self.assertRaises(ValueError):
            self.check(self.candidate)

    def test_other_rect_component_cannot_move(self):
        self.candidate["animations"][0]["rect"][1] += 1
        with self.assertRaises(ValueError):
            self.check(self.candidate)

    def test_period_cannot_change(self):
        self.candidate["animations"][3]["period"] += 0.01
        with self.assertRaises(ValueError):
            self.check(self.candidate)

    def test_animation_identity_cannot_change(self):
        self.candidate["animations"][2]["id"] = "a_new_lamp"
        with self.assertRaises(ValueError):
            self.check(self.candidate)

    def test_original_without_reanchor_is_rejected(self):
        with self.assertRaises(ValueError):
            self.check(self.baseline)

    def test_correct_semantics_with_unapproved_raw_hash_is_rejected(self):
        with self.assertRaises(ValueError):
            self.check(self.candidate, "1" * 64)


class GrandApprovalContractTests(unittest.TestCase):
    def setUp(self):
        self.value = {"schema": profile.SCHEMA, "environment_id": profile.ENVIRONMENT,
            "verdict": "GO_FOR_TEST_BUILD", "baseline_source_commit": profile.BASE_COMMIT,
            "baseline_manifest_sha256": profile.BASE_MANIFEST_SHA, "reviewer": "in-memory test reviewer",
            "evidence": ["fixture://independent-native-review"],
            "approved_png_sha256": {profile.ROOT + "background.png": "2" * 64},
            "grand_json_sha256": "3" * 64, "grand_package_sha256": "4" * 64}

    def load(self):
        raw = json.dumps(self.value)
        virtual = SimpleNamespace(is_file=lambda: True, stat=lambda: SimpleNamespace(st_size=len(raw)),
                                  read_text=lambda **_kwargs: raw)
        old = {"art_source_files": {name: "1" * 64 for name in profile.IMPORT_SHAS}}
        with patch.object(profile, "plain", return_value=virtual), \
                patch.object(profile, "sha", return_value="9" * 64), \
                patch.object(profile, "baseline", return_value=old):
            return profile.load_approval(Path("virtual-approval.json"), "9" * 64)

    def test_actual_reviewed_subset_is_accepted(self):
        self.assertEqual(self.load()["approved_png_sha256"], self.value["approved_png_sha256"])

    def test_high_limit_prefix_is_not_public_grand_scope(self):
        self.value["approved_png_sha256"] = {"assets/art/environments/grand_casino_high_limit/background.png": "2" * 64}
        with self.assertRaises(ValueError):
            self.load()

    def test_unchanged_png_cannot_be_called_approved_changed(self):
        self.value["approved_png_sha256"][profile.ROOT + "background.png"] = "1" * 64
        with self.assertRaises(ValueError):
            self.load()

    def test_pending_review_cannot_start_a_build(self):
        self.value["verdict"] = "PENDING_INDEPENDENT_REVIEW_NOT_APPROVED"
        with self.assertRaises(ValueError):
            self.load()

    def test_placeholder_hash_cannot_start_a_build(self):
        self.value["grand_json_sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            self.load()


class GrandPckDeltaContractTests(unittest.TestCase):
    @staticmethod
    def uid_bytes(count=1605, reverse=False):
        rows = []
        for index in range(count):
            path = ("res://fixed_source_%d.gd" % index).encode()
            rows.append(struct.pack("<QI", index + 1, len(path)) + path)
        if reverse:
            rows.reverse()
        return struct.pack("<I", count) + b"".join(rows)

    def setUp(self):
        self.old = {"build_manifest.json": b"old identity", profile.GRAND_JSON: b"old JSON",
                    "approved.ctex": b"old approved texture", "retained.ctex": b"retained texture",
                    ".godot/uid_cache.bin": self.uid_bytes(),
                    ".godot/global_script_class_cache.cfg": b"fixed classes",
                    "scenes/main.scn": b"fixed scene", "scripts/run.gdc": b"fixed GDC"}
        self.new = dict(self.old)
        self.new.update({"build_manifest.json": b"new identity", profile.GRAND_JSON: b"approved JSON",
                         "approved.ctex": b"approved texture"})

    def verify(self):
        old_blob, new_blob = b"baseline PCK", b"candidate PCK"
        def path_reader(path):
            data = old_blob if Path(path) == profile.BASE_STAGE / "index.pck" else new_blob
            return SimpleNamespace(read_bytes=lambda: data)
        def directory(blob):
            entries = self.old if blob == old_blob else self.new
            return {"pack_offset": 0, "entries": [{"path": name} for name in entries]}
        def payload(blob, _directory, entry):
            return (self.old if blob == old_blob else self.new)[entry["path"]]
        with patch.object(profile, "plain", side_effect=path_reader), \
                patch.object(profile, "BASE_PCK_SHA", hashlib.sha256(old_blob).hexdigest()), \
                patch.object(profile, "compiled_targets", return_value={"approved.ctex"}), \
                patch.object(profile, "check_json", return_value={}), \
                patch.object(audit_pck_manifest, "find_directory", side_effect=directory), \
                patch.object(build, "pck_entry_bytes", side_effect=payload):
            return profile.verify_qualified_pck(Path("candidate.pck"), {"approved_png_sha256": {"approved.png": "2" * 64}})

    def test_exact_identity_json_and_approved_ctex_delta_passes(self):
        proof = self.verify()
        self.assertEqual(set(proof["changed"]), {"build_manifest.json", profile.GRAND_JSON, "approved.ctex"})
        self.assertEqual(proof["uid_bindings"], 1605)

    def test_scene_change_is_rejected(self):
        self.new["scenes/main.scn"] = b"changed scene"
        with self.assertRaises(ValueError):
            self.verify()

    def test_gdc_change_is_rejected(self):
        self.new["scripts/run.gdc"] = b"changed GDC"
        with self.assertRaises(ValueError):
            self.verify()

    def test_unreviewed_texture_change_is_rejected(self):
        self.new["retained.ctex"] = b"unreviewed texture"
        with self.assertRaises(ValueError):
            self.verify()

    def test_missing_approved_ctex_change_is_rejected(self):
        self.new["approved.ctex"] = self.old["approved.ctex"]
        with self.assertRaises(ValueError):
            self.verify()

    def test_byte_changed_uid_cache_with_same_map_is_rejected(self):
        self.new[".godot/uid_cache.bin"] = self.uid_bytes(reverse=True)
        self.assertEqual(build.decode_uid_cache(self.old[".godot/uid_cache.bin"]), build.decode_uid_cache(self.new[".godot/uid_cache.bin"]))
        with self.assertRaises(ValueError):
            self.verify()

    def test_wrong_complete_uid_count_is_rejected(self):
        self.old[".godot/uid_cache.bin"] = self.uid_bytes(1604)
        self.new[".godot/uid_cache.bin"] = self.old[".godot/uid_cache.bin"]
        with self.assertRaises(ValueError):
            self.verify()


class ExistingBarFixtureRegressionTests(unittest.TestCase):
    @unittest.skipUnless((profile.BASE_STAGE / "build_manifest.json").is_file(), "Retained qualified Windows E fixture is unavailable")
    def test_default_bar_linkage_still_qualifies_retained_7b(self):
        prior = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-TEST-WEB-20261114/.tmp/web-release-0ef525e0/stage/build_manifest.json")
        baseline = json.loads(prior.read_text(encoding="utf-8-sig"))
        result = build.stage_links(profile.BASE_SOURCE, profile.BASE_STAGE, baseline)
        self.assertFalse(build.grand_profile(None))
        self.assertFalse(build.grand_profile({}))
        self.assertEqual(len(result[3]), 421)
        self.assertEqual(len(result[4]), 400)
        self.assertIsInstance(result[6], str)
        self.assertEqual(result[3][build.BAR_BACKGROUND], "a870d3652a72d3ebb5067fe9e46b412f3c2a5b938a40e4c3b2cf72e0be7a2408")


if __name__ == "__main__":
    unittest.main()
