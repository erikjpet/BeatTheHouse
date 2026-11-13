import copy
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

SPEC = importlib.util.spec_from_file_location("environment_art_checker", Path(__file__).resolve().parents[1] / "check_environment_art_pack.py")
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_png(path, width, height):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) +
                     chunk(b"IDAT", zlib.compress((b"\0" + b"\xff\xff\xff\xff" * width) * height)) + chunk(b"IEND", b""))


def manifest():
    return {
        "schema": checker.SCHEMA, "environment_id": "gas_station_casino", "board_size": [900, 430], "pixel_scale": 2,
        "background": {"texture": "background.png"},
        "animations": [
            {"type": "frames", "texture": "anim/frames.png", "rect": [0, 4, 8, 4], "frames": 4, "fps": 5},
            {"type": "pulse", "texture": "anim/pulse.png", "rect": [0, 0, 8, 4], "min_opacity": .55, "max_opacity": 1, "period": 1.6},
            {"type": "mover", "texture": "anim/mover.png", "size": [2, 2], "from": [-3, 5], "to": [10, 5], "duration": 2, "gap": .5, "clip": [0, 0, 12, 10], "still": "hide"},
            {"type": "scroll", "texture": "anim/scroll.png", "rect": [2, 1, 8, 4], "speed": [0, 4], "web_low_detail": False},
            {"type": "sweep", "texture": "anim/sweep.png", "origin": [739, 94], "from": [724, 190], "to": [796, 190], "period": 3.5, "blend": "add"},
        ],
        "counters": {"gas_station_staff_window": {"texture": "counters/front.png"}},
    }


class EnvironmentArtPackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.assets = Path(self.temp.name)
        self.data = manifest()
        self.counters = {"gas_station_staff_window": [532, 80, 104, 8]}
        for name, size in {"background.png": (1800, 860), "anim/frames.png": (64, 8), "anim/pulse.png": (16, 8),
                           "anim/mover.png": (4, 4), "anim/scroll.png": (16, 8), "anim/sweep.png": (128, 8),
                           "counters/front.png": (208, 16)}.items():
            write_png(self.assets / name, *size)

    def validate(self):
        return checker.validate_manifest(self.data, "gas_station_casino", self.assets, self.counters)

    def test_all_five_types_and_2x_sizes(self):
        self.assertEqual(self.validate(), {"environment_id": "gas_station_casino", "animations": 5, "counters": 1, "textures": 7})

    def test_empty_optional_layers(self):
        self.data.pop("animations")
        self.data.pop("counters")
        self.assertEqual(self.validate()["textures"], 1)

    def test_bleed_uses_expanded_counter_dimensions(self):
        self.data["counters"]["gas_station_staff_window"]["bleed"] = [1, 2, 3, 4]
        write_png(self.assets / "counters/front.png", 216, 28)
        self.assertEqual(self.validate()["counters"], 1)

    def test_all_loop_and_still_modes(self):
        for loop in ("loop", "pingpong", "once_hold"):
            for still in ("first", "hide", 0, 3):
                with self.subTest(loop=loop, still=still):
                    self.data["animations"][0].update(loop=loop, still=still)
                    self.validate()

    def test_framed_mover(self):
        self.data["animations"][2].update(frames=3, fps=4)
        write_png(self.assets / "anim/mover.png", 12, 4)
        self.validate()

    def test_partly_off_board_rect_is_valid(self):
        self.data["animations"][0]["rect"] = [-4, -2, 8, 4]
        self.validate()

    def test_full_rectangle_scroll_rule(self):
        self.data["animations"][3]["rect"] = [0, 42, 900, 34]
        write_png(self.assets / "anim/scroll.png", 16, 68)
        with self.assertRaisesRegex(checker.PackError, "16x68; expected 1800x68"):
            self.validate()

    def test_corrupt_png_crc(self):
        target = self.assets / "background.png"
        content = bytearray(target.read_bytes())
        content[29] ^= 1
        target.write_bytes(content)
        with self.assertRaisesRegex(checker.PackError, "CRC mismatch"):
            self.validate()

    def test_truncated_png(self):
        target = self.assets / "background.png"
        target.write_bytes(target.read_bytes()[:-2])
        with self.assertRaisesRegex(checker.PackError, "truncated"):
            self.validate()

    def test_surface_maps_distinguish_punchline_layers(self):
        root = Path(__file__).resolve().parents[2]
        self.assertEqual(checker.room_map_id(root, "punchline_club"), "small_underground_casino:club")
        self.assertEqual(checker.room_map_id(root, "punchline_back_room"), "small_underground_casino:back_room")
        self.assertIn("gas_station_staff_window", checker.counter_rectangles(root, "gas_station_casino"))


INVALID = {
    "schema": lambda d: d.update(schema="wrong"),
    "id": lambda d: d.update(environment_id="bar"),
    "board": lambda d: d.update(board_size=[901, 430]),
    "scale": lambda d: d.update(pixel_scale=1),
    "bool_scale": lambda d: d.update(pixel_scale=True),
    "missing_background": lambda d: d.pop("background"),
    "missing_texture": lambda d: d["background"].update(texture="missing.png"),
    "traversal": lambda d: d["background"].update(texture="../background.png"),
    "absolute_path": lambda d: d["background"].update(texture="C:/background.png"),
    "unknown_type": lambda d: d["animations"][0].update(type="neon"),
    "zero_frames": lambda d: d["animations"][0].update(frames=0),
    "fractional_frames": lambda d: d["animations"][0].update(frames=1.5),
    "uneven_strip": lambda d: d["animations"][0].update(frames=3),
    "wrong_frame_size": lambda d: d["animations"][0].update(rect=[0, 4, 9, 4]),
    "negative_fps": lambda d: d["animations"][0].update(fps=-2),
    "off_board": lambda d: d["animations"][0].update(rect=[901, 4, 8, 4]),
    "nonfinite_rect": lambda d: d["animations"][0].update(rect=[float("nan"), 4, 8, 4]),
    "zero_rect": lambda d: d["animations"][0].update(rect=[0, 4, 0, 4]),
    "bad_loop": lambda d: d["animations"][0].update(loop="forever"),
    "bad_still": lambda d: d["animations"][0].update(still=4),
    "bad_blend": lambda d: d["animations"][0].update(blend="screen"),
    "opacity": lambda d: d["animations"][0].update(opacity=1.1),
    "nonfinite_phase": lambda d: d["animations"][0].update(phase=float("inf")),
    "detail_flag": lambda d: d["animations"][0].update(web_low_detail="false"),
    "pulse_bounds": lambda d: d["animations"][1].update(min_opacity=1.1),
    "pulse_period": lambda d: d["animations"][1].update(period=0),
    "mover_duration": lambda d: d["animations"][2].update(duration=0),
    "mover_gap": lambda d: d["animations"][2].update(gap=-1),
    "mover_clip": lambda d: d["animations"][2].update(clip=[901, 0, 2, 2]),
    "scroll_speed": lambda d: d["animations"][3].update(speed=[0, float("inf")]),
    "sweep_origin": lambda d: d["animations"][4].update(origin=[0]),
    "sweep_period": lambda d: d["animations"][4].update(period=0),
    "unknown_counter": lambda d: d["counters"].update(not_in_this_room={"texture": "counters/front.png"}),
    "bad_bleed": lambda d: d["counters"]["gas_station_staff_window"].update(bleed=[0, -1, 0, 0]),
}


for name, mutate in INVALID.items():
    def test(self, mutate=mutate):
        mutate(self.data)
        with self.assertRaises(checker.PackError):
            self.validate()
    setattr(EnvironmentArtPackTests, "test_reject_" + name, test)


if __name__ == "__main__":
    unittest.main()
