"""In-memory regressions and read-only checks of the actual frozen Bar PNGs."""
import importlib.util
from pathlib import Path
import struct
import sys
import unittest
import zlib


TOOLS = Path(__file__).resolve().parents[1]
ROOT = TOOLS.parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))
SPEC = importlib.util.spec_from_file_location("bar_spatial_candidate_check", TOOLS / "bar_spatial_candidate_check.py")
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def memory_png(width, height, scanlines, color=2, interlace=0, transparency=None):
    """Build decoder input bytes in memory only; no PNG files are created."""
    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data +
                struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    content = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color, 0, 0, interlace))
    if transparency is not None:
        content += chunk(b"tRNS", transparency)
    return content + chunk(b"IDAT", zlib.compress(scanlines)) + chunk(b"IEND", b"")


class PNGDecoderTests(unittest.TestCase):
    def test_rgb_all_five_filters_reconstruct_the_same_pixels(self):
        # Two 2-pixel rows: [10,20,30,40,50,60], [15,25,35,65,75,85].
        encoded = {
            0: ([10, 20, 30, 40, 50, 60], [15, 25, 35, 65, 75, 85]),
            1: ([10, 20, 30, 30, 30, 30], [15, 25, 35, 50, 50, 50]),
            2: ([10, 20, 30, 40, 50, 60], [5, 5, 5, 25, 25, 25]),
            3: ([10, 20, 30, 35, 40, 45], [10, 15, 20, 38, 38, 38]),
            4: ([10, 20, 30, 30, 30, 30], [5, 5, 5, 25, 25, 25]),
        }
        expected = bytes((10, 20, 30, 255, 40, 50, 60, 255, 15, 25, 35, 255, 65, 75, 85, 255))
        for filter_type, rows in encoded.items():
            with self.subTest(filter=filter_type):
                raw = b"".join(bytes((filter_type,)) + bytes(row) for row in rows)
                self.assertEqual(checker.decode_png(memory_png(2, 2, raw)).rgba, expected)

    def test_rgba_keeps_partial_alpha(self):
        image = checker.decode_png(memory_png(2, 1, bytes((0, 10, 20, 30, 1, 40, 50, 60, 254)), color=6))
        self.assertEqual(image.rgba, bytes((10, 20, 30, 1, 40, 50, 60, 254)))
        self.assertEqual(checker.check_master(image, (2, 1))["nonopaque_pixel_count"], 2)

    def test_rgb_transparency_is_not_silently_treated_as_opaque(self):
        image = checker.decode_png(memory_png(1, 1, b"\0\x0a\x14\x1e", transparency=struct.pack(">HHH", 10, 20, 30)))
        self.assertEqual(image.rgba[-1], 0)

    def test_crc_corruption_is_rejected(self):
        data = bytearray(memory_png(1, 1, b"\0\x01\x02\x03"))
        data[-1] ^= 1
        with self.assertRaisesRegex(ValueError, "CRC"):
            checker.decode_png(bytes(data))

    def test_interlaced_input_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "non-interlaced"):
            checker.decode_png(memory_png(1, 1, b"\0\x01\x02\x03", interlace=1))

    def test_extra_inflated_data_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "byte count"):
            checker.decode_png(memory_png(1, 1, b"\0\x01\x02\x03extra"))


class ActualBarCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        art = ROOT / "assets/art/environments/bar"
        cls.master = checker.decode_png((art / "background.png").read_bytes())
        cls.counter = checker.decode_png((art / "counters/bar_main_counter.png").read_bytes())
        cls.balls = {name: checker.decode_png((art / entry["texture"]).read_bytes())
                     for name, entry in checker.BALLS.items()}

    def test_all_96_actual_frames_fit_full_visible_felt(self):
        frames = 0
        for name, entry in checker.BALLS.items():
            result = checker.check_ball_atlas(self.balls[name], entry["rect"], checker.BASELINE_FELT)
            self.assertTrue(result["ok"], name)
            self.assertEqual(result["failing_pixel_count"], 0)
            self.assertTrue(all(count > 0 for count in result["nonzero_alpha_pixel_counts"]))
            frames += result["frames"]
        self.assertEqual(frames, 96)

    def test_near_edge_shortened_to_y232_rejects_actual_ball1_pixels(self):
        clipped = ((612, 200), (808, 200), (808, 232), (612, 232))
        first = checker.check_ball_atlas(self.balls["pool_ball_0"], checker.BALLS["pool_ball_0"]["rect"], clipped)
        second = checker.check_ball_atlas(self.balls["pool_ball_1"], checker.BALLS["pool_ball_1"]["rect"], clipped)
        self.assertTrue(first["ok"])
        self.assertFalse(second["ok"])
        self.assertGreater(second["failing_pixel_count"], 0)
        self.assertEqual(len(second["failures"]), second["failing_pixel_count"])
        self.assertEqual({pixel["frame"] for pixel in second["failures"]}, set(range(48)))
        self.assertTrue(all(pixel["alpha"] > 0 and pixel["board_center"][1] > 232
                            for pixel in second["failures"]))

    def test_owner_requested_second_ball_clearance_is_preserved(self):
        result = checker.check_required_clearance(checker.BASELINE_FELT)
        self.assertTrue(result["ok"])
        self.assertEqual(result["board_rect"], [744, 226, 24, 12])

    def test_visible_ball_fit_does_not_waive_requested_felt_margin(self):
        tight = ((612, 200), (808, 200), (808, 237), (612, 237))
        ball = checker.check_ball_atlas(self.balls["pool_ball_1"], checker.BALLS["pool_ball_1"]["rect"], tight)
        self.assertTrue(ball["ok"])
        clearance = checker.check_required_clearance(tight)
        self.assertFalse(clearance["ok"])
        self.assertGreater(clearance["failing_native_pixel_count"], 0)

    def test_only_a_bbox_cannot_reject_transparent_corners(self):
        # One actual opaque native texel in an otherwise transparent 2x2 tile.
        image = checker.PNGImage(2, 2, bytes((255, 255, 255, 1)) + bytes(12))
        polygon = ((0, 0), (.5, 0), (.5, .5), (0, .5))
        result = checker.check_ball_atlas(image, (0, 0, 1, 1), polygon, frames=1)
        self.assertTrue(result["ok"])
        self.assertEqual(result["checked_pixel_count"], 1)

    def test_partial_alpha_pixel_outside_felt_is_rejected(self):
        image = checker.PNGImage(2, 2, bytes(12) + bytes((255, 255, 255, 1)))
        polygon = ((0, 0), (.5, 0), (.5, .5), (0, .5))
        result = checker.check_ball_atlas(image, (0, 0, 1, 1), polygon, frames=1)
        self.assertFalse(result["ok"])
        self.assertEqual(result["failures"][0]["alpha"], 1)
        self.assertEqual(result["failures"][0]["frame_pixel"], [1, 1])

    def test_outside_region_shifted_dive_landmark_is_rejected(self):
        changed = bytearray(self.master.rgba)
        # Move the existing DIVE sign strip two native pixels, in memory only.
        for y in range(70, 125):
            for x in range(1242, 1380):
                target = (y * self.master.width + x) * 4
                source = (y * self.master.width + x - 2) * 4
                changed[target:target + 4] = self.master.rgba[source:source + 4]
        candidate = checker.PNGImage(self.master.width, self.master.height, bytes(changed))
        result = checker.check_changed_region(self.master, candidate)
        self.assertFalse(result["ok"])
        self.assertGreater(result["outside_region_changed_pixel_count"], 0)
        self.assertEqual(sum(end - start for _y, start, end in result["outside_region_changed_runs"]),
                         result["outside_region_changed_pixel_count"])

    def test_envelope_boundaries_are_exact_and_half_open(self):
        for x, y, allowed in ((1196, 376, True), (1643, 591, True),
                              (1195, 376, False), (1644, 591, False), (1196, 592, False)):
            with self.subTest(x=x, y=y):
                changed = bytearray(self.master.rgba)
                index = (y * self.master.width + x) * 4
                changed[index] ^= 255
                candidate = checker.PNGImage(self.master.width, self.master.height, bytes(changed))
                result = checker.check_changed_region(self.master, candidate)
                self.assertEqual(result["ok"], allowed)
                self.assertEqual(result["changed_pixel_count"], 1)

    def test_active_counter_is_exact_same_master_crop(self):
        result = checker.check_counter_crop(self.master, self.counter)
        self.assertTrue(result["ok"])
        self.assertEqual(result["size"], [1096, 112])
        self.assertEqual(result["mismatch_count"], 0)

    def test_master_rejects_even_one_nonopaque_pixel(self):
        changed = bytearray(self.master.rgba)
        changed[3] = 254
        result = checker.check_master(checker.PNGImage(self.master.width, self.master.height, bytes(changed)))
        self.assertFalse(result["ok"])
        self.assertEqual(result["nonopaque_pixel_count"], 1)
        self.assertEqual(result["nonopaque_runs"], [[0, 0, 1]])

    def test_candidate_mode_requires_its_own_polygon(self):
        with self.assertRaisesRegex(ValueError, "requires its own"):
            checker.validate_candidate(ROOT, ROOT / "assets/art/environments/bar/background.png")


class PolygonTests(unittest.TestCase):
    def test_polygon_self_intersection_is_rejected(self):
        with self.assertRaises(ValueError):
            checker.normalize_polygon(((1, 1), (4, 4), (1, 4), (4, 1)))

    def test_complete_texel_rejects_a_concave_notch(self):
        polygon = checker.normalize_polygon(((0, 0), (2, 0), (2, 2), (1.2, 2),
                                             (1.1, .8), (1, 2), (0, 2)))
        self.assertTrue(all(checker.point_in_polygon(p, polygon)
                            for p in ((.5, .5), (1.5, .5), (1.5, 1.5), (.5, 1.5))))
        self.assertFalse(checker.pixel_in_polygon(.5, .5, 1, polygon))


if __name__ == "__main__":
    unittest.main()
