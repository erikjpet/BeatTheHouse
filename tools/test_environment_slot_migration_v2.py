#!/usr/bin/env python3
"""Engine-free regression coverage for the slot-family migration recipe."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "migrate_environment_slots_v2.py"
SPEC = importlib.util.spec_from_file_location("environment_slot_migration_v2", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load migration module: {MODULE_PATH}")
MIGRATION = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MIGRATION)


class EnvironmentSlotMigrationV2Tests(unittest.TestCase):
    def _current_payload(self) -> dict:
        return json.loads(MIGRATION.PLACEMENT_PATH.read_text(encoding="utf-8"))

    def test_required_events_follow_layer_merge_semantics(self) -> None:
        archetypes = [{
            "id": "fixture",
            "required_event_ids": ["parent_door"],
            "layers": {
                "omitted": {},
                "empty": {"required_event_ids": []},
                "null": {"required_event_ids": None},
                "replacement": {"required_event_ids": ["layer_door"]},
            },
        }]
        required = MIGRATION.required_events_by_map(archetypes)
        self.assertEqual(required["fixture"], {"parent_door"})
        self.assertEqual(required["fixture:omitted"], {"parent_door"})
        self.assertEqual(required["fixture:empty"], set())
        self.assertEqual(required["fixture:null"], set())
        self.assertEqual(required["fixture:replacement"], {"layer_door"})

    def test_every_effective_required_event_has_fixed_exact_authority(self) -> None:
        payload = self._current_payload()
        maps = {str(value.get("id", "")): value for value in payload["maps"]}
        required = MIGRATION.required_events_by_map()
        claims = [
            (map_id, f"event:{event_id}")
            for map_id, event_ids in required.items()
            for event_id in sorted(event_ids)
        ]
        self.assertEqual(len(claims), 15)
        for map_id, object_id in claims:
            with self.subTest(map_id=map_id, object_id=object_id):
                map_data = maps[map_id]
                slot_id = map_data["fixed_object_slot_ids"].get(object_id, "")
                self.assertEqual(map_data["object_family_ids"].get(object_id), "fixed")
                self.assertTrue(slot_id.startswith("fixed."))
                self.assertNotIn(object_id, map_data["event_object_slot_ids"])
                self.assertNotIn(object_id, map_data["scenario_object_slot_ids"])
                self.assertNotIn(object_id, map_data["exit_object_slot_ids"])
                self.assertIn(slot_id, {slot["id"] for slot in map_data["fixed_slots"]})

    def test_casino_inherited_side_door_preserves_authored_geometry(self) -> None:
        payload = self._current_payload()
        casino = next(value for value in payload["maps"] if value["id"] == "small_underground_casino:casino")
        slot = next(value for value in casino["fixed_slots"] if value["id"] == "fixed.door_side_event")
        self.assertEqual(casino["fixed_object_slot_ids"]["event:side_door"], "fixed.door_side_event")
        self.assertEqual(slot["kind"], "fixed")
        self.assertEqual(slot["footprint_class"], "doorway")
        self.assertEqual(slot["pos"], [36, 160])
        self.assertEqual(slot["hit_rect"], [4, 124, 64, 72])
        self.assertEqual(slot["label_anchor"], [36, 118])
        self.assertEqual(slot["support_id"], "left_exit")

    def test_validator_rejects_cross_family_pointer_and_owner_disagreement(self) -> None:
        payload = self._current_payload()
        hostile_pointer = copy.deepcopy(payload)
        corner = next(value for value in hostile_pointer["maps"] if value["id"] == "corner_store")
        corner["fixed_object_slot_ids"]["event:call_brother_in_law"] = "event.behind_counter_person_1"
        corner["object_family_ids"]["event:call_brother_in_law"] = "fixed"
        with self.assertRaisesRegex(ValueError, "names non-fixed slot"):
            MIGRATION.validate(hostile_pointer)

        hostile_owner = copy.deepcopy(payload)
        casino = next(value for value in hostile_owner["maps"] if value["id"] == "small_underground_casino:casino")
        casino["object_family_ids"]["event:side_door"] = "event"
        with self.assertRaisesRegex(ValueError, "disagrees with object_family_ids"):
            MIGRATION.validate(hostile_owner)

    def test_reviewed_recipe_matches_fresh_conversion_and_is_idempotent(self) -> None:
        source_ref = MIGRATION._recorded_legacy_source_ref("check")
        source_bytes, legacy, _, archetypes, scenario_documents, _ = MIGRATION._legacy_source_bundle(source_ref)
        self.assertTrue(source_bytes)
        scenario_sources = MIGRATION.collect_scenario_sources(scenario_documents)
        required_events = MIGRATION.required_events_by_map(archetypes)
        baseline_objects = MIGRATION.baseline_objects_by_map(archetypes)
        converted, _ = MIGRATION.convert_legacy_payload(
            legacy,
            scenario_sources=scenario_sources,
            required_events=required_events,
            baseline_objects=baseline_objects,
        )
        current = self._current_payload()
        self.assertEqual(converted, current)
        current_bytes = MIGRATION._json_bytes(current)
        reserve_metadata = {
            (map_data["id"], slot["id"]): (
                slot["physical_role"],
                slot["runtime_reserve"],
                slot["reserve_reason"],
            )
            for map_data in current["maps"]
            for family in MIGRATION.FAMILIES
            for slot in map_data[f"{family}_slots"]
            if slot["runtime_reserve"]
        }
        self.assertTrue(reserve_metadata)
        refreshed = copy.deepcopy(current)
        MIGRATION.apply_capacity_repairs(refreshed)
        self.assertEqual(refreshed, current)
        self.assertEqual(MIGRATION._json_bytes(refreshed), current_bytes)
        MIGRATION.apply_capacity_repairs(refreshed)
        self.assertEqual(refreshed, current)
        self.assertEqual(MIGRATION._json_bytes(refreshed), current_bytes)
        self.assertEqual(
            {
                (map_data["id"], slot["id"]): (
                    slot["physical_role"],
                    slot["runtime_reserve"],
                    slot["reserve_reason"],
                )
                for map_data in refreshed["maps"]
                for family in MIGRATION.FAMILIES
                for slot in map_data[f"{family}_slots"]
                if slot["runtime_reserve"]
            },
            reserve_metadata,
        )

    def test_ledger_check_uses_recorded_commit_instead_of_head(self) -> None:
        original = MIGRATION.LEGACY_LEDGER_PATH
        try:
            with tempfile.TemporaryDirectory() as directory:
                fixture = Path(directory) / "ledger.json"
                fixture.write_text(
                    json.dumps({"source": {"git_commit": "immutable-legacy-commit"}}),
                    encoding="utf-8",
                )
                MIGRATION.LEGACY_LEDGER_PATH = fixture
                self.assertEqual(
                    MIGRATION._recorded_legacy_source_ref("check"),
                    "immutable-legacy-commit",
                )
        finally:
            MIGRATION.LEGACY_LEDGER_PATH = original


if __name__ == "__main__":
    unittest.main()
