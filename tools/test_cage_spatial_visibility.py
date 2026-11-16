"""Read-only Cage visibility regressions, for parent's admitted capped test Job.

Only immutable retained input reads and small in-memory image mutations.
No outputs, directory creation, imported Pillow, engine or child launch.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import json
import unittest

import cage_spatial_visibility as visibility


def image(pixels, width=None):
    width = width or len(pixels)
    return visibility.PNGImage(width, len(pixels)//width,
                               bytes(channel for p in pixels for channel in p))


def word(pixel):
    return sum(channel << (8*i) for i, channel in enumerate(pixel))


class CageCompositeLawChecks(unittest.TestCase):
    def test_transparent_source_preserves_all_destination_bytes(self):
        destination = (17, 31, 91, 123)
        self.assertEqual(visibility.alpha_over_pixel(word(destination), word((255, 2, 3, 0))),
                         word(destination))

    def test_opaque_source_replaces_and_transparent_destination_keeps_source(self):
        source = (29, 77, 111, 128)
        self.assertEqual(visibility.alpha_over_pixel(word((91, 8, 3, 0)), word(source)),
                         word(source))
        self.assertEqual(visibility.alpha_over_pixel(word((91, 8, 3, 94)), word((1, 2, 3, 255))),
                         word((1, 2, 3, 255)))

    def test_two_partial_alpha_layers_follow_integer_straight_RGBA_law(self):
        self.assertEqual(visibility.alpha_over_pixel(word((0, 0, 255, 128)),
                                                    word((255, 0, 0, 128))),
                         word((170, 0, 85, 192)))

    def test_overlay_order_changes_RGB_and_opacity(self):
        transparent = image([(0, 0, 0, 0)])
        red, blue = image([(255, 0, 0, 128)]), image([(0, 0, 255, 128)])
        first = visibility.composite_rgba(visibility.composite_rgba(transparent, blue), red)
        second = visibility.composite_rgba(visibility.composite_rgba(transparent, red), blue)
        self.assertEqual(first.rgba, bytes((170, 0, 85, 192)))
        self.assertEqual(second.rgba, bytes((85, 0, 170, 192)))
        self.assertNotEqual(first, second)

    def test_visibility_counts_pixels_once_and_uses_max_RGB_channel(self):
        a = image([(10, 20, 30, 255), (40, 50, 60, 255)])
        b = image([(15, 40, 50, 255), (41, 50, 60, 255)])
        metrics = visibility.visibility_metrics(a, b, image([(0, 0, 0, 0)]*2))
        self.assertEqual(metrics["surviving_changed_pixels"], 2)
        self.assertEqual(metrics["maximum_channel_delta"], 20)
        self.assertEqual(metrics["raw_changed_pixels"], 2)

    def test_opaque_front_completely_hides_motion(self):
        a, b = image([(1, 2, 3, 255)]), image([(250, 70, 60, 255)])
        metrics = visibility.visibility_metrics(a, b, image([(7, 8, 9, 255)]))
        self.assertFalse(metrics["visible_pixel_change_under_conservative_overlay"])
        self.assertEqual(metrics["surviving_changed_pixels"], 0)
        self.assertEqual(metrics["maximum_channel_delta"], 0)
        self.assertEqual(metrics["raw_changed_pixels"], 1)

    def test_partial_front_preserves_rounding_and_conservative_survival(self):
        a, b = image([(100, 100, 100, 255)]), image([(200, 200, 200, 255)])
        metrics = visibility.visibility_metrics(a, b, image([(0, 0, 0, 128)]))
        self.assertEqual(metrics["surviving_changed_pixels"], 1)
        self.assertEqual(metrics["maximum_channel_delta"], 50)

    def test_fresh_glyph_guard_checks_raw_motion_even_when_opaque_front_hides_it(self):
        a = image([(1, 2, 3, 255), (1, 2, 3, 255)])
        b = image([(2, 2, 3, 255), (2, 2, 3, 255)])
        with self.assertRaisesRegex(ValueError, "outside5532"):
            visibility.visibility_metrics(a, b, image([(0, 0, 0, 255)]*2),
                                          allowed_changed_pixels={0})

    def test_nonopaque_art_target_or_dimension_mismatch_rejected(self):
        a, b = image([(1, 2, 3, 254)]), image([(1, 2, 3, 255)])
        with self.assertRaisesRegex(ValueError, "opaque"):
            visibility.visibility_metrics(a, b, image([(0, 0, 0, 0)]))
        with self.assertRaisesRegex(ValueError, "dimensions"):
            visibility.composite_rgba(a, image([(0, 0, 0, 0)]*2))


class CageFreshGlyphContractChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.candidate = visibility.Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-CAGETRIAL-20261116/candidate_sources/cage-spatial-r1-alpha-mask")
        cls.sign = visibility.decode_png(visibility._read(cls.candidate/visibility.SIGN))
        cls.master = visibility.decode_png(visibility._read(cls.candidate/visibility.BACKGROUND))

    def test_exact_fresh_sign_contract_is_glyph_only_not_old_rectangle(self):
        reader = visibility._Reader()
        support, proof = visibility._candidate_contract(self.candidate, reader)
        reader.finish()
        self.assertEqual(len(support), 5532)
        self.assertEqual(proof["retained_alpha46_native_texels"], 5532)
        self.assertEqual(proof["zero_alpha_native_texels"], 46436)
        self.assertEqual(proof["sign_sha256"], visibility.CANDIDATE_PINS[visibility.SIGN])
        self.assertEqual(sum(count for count, bounds in proof["four_connected_board_components"]), 1383)

    def test_one_outside_alpha_texel_or_lost_glyph_is_rejected(self):
        support, _ = visibility.glyph_contract(self.sign, self.master)
        point = min(support)
        x, y = point % 1800 - 668, point // 1800 - 72
        for offset, alpha in ((3, 1), ((y*464+x)*4+3, 0)):
            data = bytearray(self.sign.rgba)
            data[offset] = alpha
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                visibility.glyph_contract(visibility.PNGImage(464, 112, bytes(data)), self.master)

    def test_RGB_under_transparent_pixels_is_still_preserved(self):
        data = bytearray(self.sign.rgba)
        self.assertEqual(data[3], 0)
        data[0] = 254
        with self.assertRaisesRegex(ValueError, "RGB"):
            visibility.glyph_contract(visibility.PNGImage(464, 112, bytes(data)), self.master)


class CageRetainedInputContractChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.metadata = json.loads(visibility._read(visibility.HISTORICAL_CONTEXTS/"__none_metadata.json"))
        cls.motion = json.loads(visibility._read(visibility.HISTORICAL_MOTION/
                                                "grand_casino_cage_animation_probe.json"))

    def test_actual_historical36_rows_recomputed_from_all_authenticated_PNGs(self):
        # This intentionally invokes the full stdlib reproduction, not saved rows.
        proof = visibility.historical_visibility_contract()
        self.assertEqual(proof["status"], "PASS")
        self.assertTrue(proof["exact_reference_rows_equal"])
        self.assertEqual(proof["historical_authenticated_input_count"], 86)
        self.assertEqual(len(proof["input_hashes"]), 86)
        self.assertEqual(len(proof["mask_hashes"]), 11)
        self.assertEqual(proof["checks"], 36)
        self.assertEqual(sum(row["mode"] == "normal" for row in proof["rows"]), 20)
        self.assertEqual(sum(row["mode"] == "simulated_low_detail" for row in proof["rows"]), 16)
        self.assertEqual(proof["rows"][0]["surviving_changed_pixels"], 51968)
        self.assertFalse(proof["fresh_candidate_qualified"])

    def test_actual_motion82_contract_has20_native_and16_low_entries(self):
        entries = visibility.motion_contract(self.motion)
        self.assertEqual(len(entries), 20)
        self.assertEqual(len(visibility.LOW_IDS), 16)
        atm = next(row for row in entries if row["id"] == "atm_scan")
        self.assertEqual((atm["frame_count"], atm["frame_a"], atm["frame_b"]), (32, 0, 8))

    def test_missing_duplicate_or_extra_motion_identity_is_rejected(self):
        for mode in ("missing", "duplicate", "extra"):
            report = deepcopy(self.motion)
            if mode == "missing":
                report["entries"].pop()
            elif mode == "duplicate":
                report["entries"][-1] = deepcopy(report["entries"][0])
            else:
                report["entries"].append(deepcopy(report["entries"][0]))
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                visibility.motion_contract(report)

    def test_low_detail_flag_live_change_RM_and_nonfinite_clock_rejected(self):
        for mode in ("flag", "change", "RM", "clock"):
            report = deepcopy(self.motion)
            if mode == "flag":
                report["simulated_low_detail_entries"][-1]["included"] = True
            elif mode == "change":
                report["simulated_low_detail_entries"][0]["live_change"] = False
            elif mode == "RM":
                report["entries"][0]["reduce_motion_stable"] = False
            else:
                report["entries"][0]["clock_a"] = float("nan")
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                visibility.motion_contract(report)

    def test_actual_typed_map_requires_all_five_hosts_and_ten_exact_filenames(self):
        names = visibility.typed_mapping(self.metadata)
        self.assertEqual(len(names), 10)
        self.assertEqual(len(set(names)), 10)
        self.assertEqual(names[0], "__none_host_0_body.png")
        self.assertEqual(names[-1], "__none_host_4_adorn.png")

    def test_wrong_typed_host_geometry_or_path_cannot_silently_change_overlay(self):
        for mode in ("host", "geometry", "traversal", "missing"):
            value = deepcopy(self.metadata)
            if mode == "host":
                value["source_paint"]["objects"][0]["object"]["id"] = "invented"
            elif mode == "geometry":
                value["source_paint"]["geometry_equal"] = False
            elif mode == "traversal":
                value["source_paint"]["objects"][0]["body_png"] = "../outside.png"
            else:
                value["source_paint"]["objects"].pop()
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                visibility.typed_mapping(value)


if __name__ == "__main__":
    unittest.main()
