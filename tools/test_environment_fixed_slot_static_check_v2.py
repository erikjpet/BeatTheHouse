#!/usr/bin/env python3
"""Focused engine-free tests for the v2 scenario slot replay."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from typing import Any


TOOLS_ROOT = Path(__file__).resolve().parent
if str(TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOLS_ROOT))

import environment_fixed_slot_static_check as SlotCheck  # noqa: E402


def slot(slot_id: str, placement_class: str, priority: int, x: float) -> dict[str, Any]:
    family = slot_id.split(".", 1)[0]
    return {
        "id": slot_id,
        "kind": family,
        "pos": [x + 24.0, 200.0],
        "footprint_class": placement_class,
        "hit_rect": [x, 140.0, 48.0, 60.0],
        "label_anchor": [x + 24.0, 132.0],
        "facing": "front",
        "priority": priority,
        "zone_id": "center",
        "support_id": "floor" if placement_class != "doorway" else "door",
        "walk_lane_ids": [],
        "occupancy_required": False,
    }


def map_data(
    scenario_slots: list[dict[str, Any]],
    exit_slots: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return {
        "id": "test_room",
        "scenario_slots": scenario_slots,
        "exit_slots": exit_slots or [],
        "scenario_slot_ids": {},
        "scenario_object_slot_ids": {},
        "exit_object_slot_ids": {},
        "scenario_art_keys": {},
        "scenario_position_route_ids": {},
        "class_overrides": {},
        "actor_routes": [],
        "walk_lanes": [],
    }


def actor(identity: str, **extra: Any) -> dict[str, Any]:
    row = {
        "identity": identity,
        "stable_object_id": identity.removeprefix("scenario::"),
        "_slot_actor": True,
        "placement_class": "standing_person",
        "_slot_scenario_id": "test_scenario",
        "_slot_phase_id": "active",
        "_slot_interaction": {},
    }
    row.update(extra)
    return row


class V2ScenarioSlotReplayTest(unittest.TestCase):
    def test_capacity_shortfall_fails_closed(self) -> None:
        surface = map_data([slot("scenario.floor_patron_1", "standing_person", 1, 100.0)])
        result = SlotCheck._v2_bind_scenario_snapshot(surface, [
            actor("scenario::actor_a"),
            actor("scenario::actor_b"),
        ])
        self.assertEqual(result["room_count"], 1)
        self.assertEqual(result["missing_count"], 1)
        self.assertTrue(result["errors"])

        check = SlotCheck.Check()
        rows = SlotCheck._v2_snapshot_rows(check, {"test_room": surface}, {"test_room": [[
            actor("scenario::actor_a"),
            actor("scenario::actor_b"),
        ]]})
        self.assertEqual(rows[0]["overflow_count"], 1)
        self.assertTrue(check.errors)

    def test_preference_contention_uses_deterministic_family_fallback(self) -> None:
        surface = map_data([
            slot("scenario.floor_patron_1", "standing_person", 1, 100.0),
            slot("scenario.floor_patron_2", "standing_person", 2, 180.0),
        ])
        surface["scenario_slot_ids"] = {
            "actor_a": "scenario.floor_patron_1",
            "actor_b": "scenario.floor_patron_1",
        }
        snapshot = [actor("scenario::actor_a"), actor("scenario::actor_b")]
        first = SlotCheck._v2_bind_scenario_snapshot(surface, snapshot)
        repeated = SlotCheck._v2_bind_scenario_snapshot(surface, snapshot)
        self.assertEqual(first, repeated)
        self.assertEqual(first["missing_count"], 0)
        self.assertEqual(
            {binding["slot_id"] for binding in first["bindings"].values()},
            {"scenario.floor_patron_1", "scenario.floor_patron_2"},
        )

    def test_route_reserves_both_scenario_endpoints(self) -> None:
        surface = map_data([
            slot("scenario.floor_patron_1", "standing_person", 1, 100.0),
            slot("scenario.floor_patron_2", "standing_person", 2, 300.0),
        ])
        surface["walk_lanes"] = [{
            "id": "public_lane", "direction": "both",
            "points": [[100.0, 200.0], [300.0, 200.0]],
        }]
        surface["actor_routes"] = [{
            "id": "cross_room",
            "start_slot_id": "scenario.floor_patron_1",
            "end_slot_id": "scenario.floor_patron_2",
            "lane_ids": ["public_lane"],
        }]
        result = SlotCheck._v2_bind_scenario_snapshot(surface, [
            actor("scenario::moving_actor", route_id="cross_room"),
        ])
        self.assertEqual(result["room_count"], 1)
        self.assertEqual(result["missing_count"], 0)
        self.assertEqual(result["reservation_count"], 2)
        self.assertEqual(
            result["bindings"]["scenario::moving_actor"]["reserved_slot_ids"],
            ["scenario.floor_patron_1", "scenario.floor_patron_2"],
        )

    def test_safe_exit_stays_scenario_but_navigation_uses_exit(self) -> None:
        surface = map_data(
            [slot("scenario.doorway_1", "doorway", 1, 100.0)],
            [slot("exit.travel_1", "doorway", 1, 300.0)],
        )
        safe_exit = {
            "identity": "scenario::safe_exit",
            "stable_object_id": "safe_exit",
            "placement_class": "doorway",
            "_slot_scenario_id": "test_scenario",
            "_slot_phase_id": "active",
            "_slot_interaction": {"safe_exit": True},
        }
        navigation = {
            "identity": "scenario::navigation_exit",
            "stable_object_id": "navigation_exit",
            "placement_class": "doorway",
            "_slot_scenario_id": "test_scenario",
            "_slot_phase_id": "active",
            "_slot_interaction": {
                "available_actions": [{"id": "leave", "handler": "travel"}],
            },
        }
        result = SlotCheck._v2_bind_scenario_snapshot(surface, [safe_exit, navigation])
        self.assertEqual(result["missing_count"], 0)
        self.assertEqual(result["bindings"]["scenario::safe_exit"]["slot_family"], "scenario")
        self.assertEqual(result["bindings"]["scenario::navigation_exit"]["slot_family"], "exit")

    def test_abstract_action_does_not_consume_physical_capacity(self) -> None:
        surface = map_data([])
        abstract = {
            "identity": "scenario::primary_task",
            "stable_object_id": "primary_task",
            "role": "primary_task",
            "_slot_scenario_id": "test_scenario",
            "_slot_phase_id": "active",
            "_slot_interaction": {
                "available_actions": [{"id": "inspect", "handler": "scenario_action"}],
            },
        }
        result = SlotCheck._v2_bind_scenario_snapshot(surface, [abstract])
        self.assertEqual(result["room_count"], 0)
        self.assertEqual(result["missing_count"], 0)
        self.assertEqual(result["attached_count"], 1)
        self.assertEqual(result["bindings"]["scenario::primary_task"]["mode"], "attached")


if __name__ == "__main__":
    unittest.main()
