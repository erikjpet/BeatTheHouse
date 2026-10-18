#!/usr/bin/env python3

import copy
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("environment_placement_report.py")
SPEC = importlib.util.spec_from_file_location("environment_placement_report", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class PlacementReportTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        data = self.root / "data/environments"
        data.mkdir(parents=True)
        base_ids = [f"room_{index:02d}" for index in range(20)]
        maps = []
        layouts = []
        for index, room in enumerate(base_ids):
            maps.append({
                "id": room,
                "fixed_slots": [{"id": "fixed.anchor"}],
                "event_slots": [],
                "exit_slots": [],
                "scenario_slots": [{"id": "scenario.reserve", "runtime_reserve": True}],
            })
            scenario_count = 3 if index < 15 else 2
            for scenario_index in range(scenario_count):
                scenario = f"scenario_{scenario_index}"
                layouts.append({
                    "layout_id": f"{room}::{scenario}",
                    "map_id": room,
                    "scenario_id": scenario,
                    "scenario_slots": [{"id": "scenario.actor"}],
                })
        self.surfaces = {"schema_version": 3, "slot_schema_version": 2, "maps": maps}
        self.scenarios = {
            "schema_version": 1,
            "slot_schema_version": 2,
            "base_layout_ids": base_ids,
            "layout_count": 55,
            "layouts": layouts,
        }
        self._write(data / "placement_surfaces.json", self.surfaces)
        self._write(data / "scenario_slot_layouts.json", self.scenarios)
        self._git("init", "-q")
        self._git("config", "user.email", "test@example.invalid")
        self._git("config", "user.name", "Placement Test")
        self._git("add", ".")
        self._git("commit", "-qm", "authority")
        commit = self._git("rev-parse", "HEAD")
        tree = self._git("rev-parse", "HEAD^{tree}")
        shared, scenarios = MODULE.expected_authority(self.root)
        rooms = {}
        slot_count = 0
        for room in base_ids:
            shared_positions = {slot: [10, 20] for slot in shared[room]}
            slot_count += len(shared_positions)
            scenario_layouts = {}
            for scenario, slots in scenarios[room].items():
                positions = {slot: [30.5, 40] for slot in slots}
                slot_count += len(positions)
                scenario_layouts[scenario] = {"saved": True, "slot_positions": positions}
            rooms[room] = {"base_saved": True, "slot_positions": shared_positions, "scenario_layouts": scenario_layouts}
        coverage = {
            "expected_base_layout_count": 20,
            "expected_scenario_layout_count": 55,
            "expected_layout_count": 75,
            "saved_base_layout_count": 20,
            "saved_scenario_layout_count": 55,
            "saved_layout_count": 75,
            "missing_base_layout_ids": [],
            "missing_scenario_layout_ids": [],
            "missing_layout_ids": [],
            "next_missing_layout_id": "",
            "unexpected_layout_ids": [],
            "complete": True,
        }
        metadata = {
            "schema": MODULE.REPORT_SCHEMA,
            "report_scope": "effective_reviewed_authority",
            "source_commit": commit,
            "source_tree": tree,
            "placement_surfaces_sha256": self._hash(data / "placement_surfaces.json"),
            "scenario_slot_layouts_sha256": self._hash(data / "scenario_slot_layouts.json"),
            "effective_room_count": 20,
            "effective_slot_count": slot_count,
        }
        self.report = {"schema_version": 3, "rooms": rooms, "coverage": coverage, "report_metadata": metadata}
        self.report_path = self.root / "report.json"
        self._write(self.report_path, self.report)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _git(self, *args: str) -> str:
        return subprocess.check_output(["git", *args], cwd=self.root, text=True).strip()

    @staticmethod
    def _write(path: Path, value: dict) -> None:
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

    @staticmethod
    def _hash(path: Path) -> str:
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def _mutated(self, change) -> Path:
        value = copy.deepcopy(self.report)
        change(value)
        path = self.root / "mutated.json"
        self._write(path, value)
        return path

    def test_valid_report_produces_deterministic_authority_preview(self) -> None:
        authority, summary = MODULE.validate_report(self.report_path, self.root)
        self.assertTrue(summary["ok"])
        self.assertTrue(summary["dry_run"])
        self.assertEqual(summary["total_layouts"], 75)
        self.assertEqual(set(authority), {"schema_version", "rooms"})
        output = self.root / "validated-preview.json"
        MODULE._write_explicit(output, authority)
        self.assertEqual(json.loads(output.read_text()), authority)

    def test_rejects_hash_coverage_slot_and_provenance_tampering(self) -> None:
        cases = [
            lambda v: v["report_metadata"].__setitem__("placement_surfaces_sha256", "0" * 64),
            lambda v: v["coverage"].__setitem__("saved_layout_count", 74),
            lambda v: v["rooms"]["room_00"]["slot_positions"].pop("fixed.anchor"),
            lambda v: v["rooms"]["room_00"]["slot_positions"].__setitem__("fixed.anchor", [True, 2]),
            lambda v: v["report_metadata"].__setitem__("source_tree", "0" * 40),
        ]
        for change in cases:
            with self.subTest(change=change):
                with self.assertRaises(MODULE.ReportError):
                    MODULE.validate_report(self._mutated(change), self.root)


if __name__ == "__main__":
    unittest.main()
