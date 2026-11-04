#!/usr/bin/env python3
"""Focused engine-free tests for the v2 scenario slot replay."""

from __future__ import annotations

import sys
import unittest
import copy
import json
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
        surface = map_data([slot("scenario.standing_person_1", "standing_person", 1, 100.0)])
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
            slot("scenario.standing_person_1", "standing_person", 1, 100.0),
            slot("scenario.standing_person_2", "standing_person", 2, 180.0),
        ])
        surface["scenario_slot_ids"] = {
            "actor_a": "scenario.standing_person_1",
            "actor_b": "scenario.standing_person_1",
        }
        snapshot = [actor("scenario::actor_a"), actor("scenario::actor_b")]
        first = SlotCheck._v2_bind_scenario_snapshot(surface, snapshot)
        repeated = SlotCheck._v2_bind_scenario_snapshot(surface, snapshot)
        self.assertEqual(first, repeated)
        self.assertEqual(first["missing_count"], 0)
        self.assertEqual(
            {binding["slot_id"] for binding in first["bindings"].values()},
            {"scenario.standing_person_1", "scenario.standing_person_2"},
        )

    def test_route_reserves_both_scenario_endpoints(self) -> None:
        surface = map_data([
            slot("scenario.standing_person_1", "standing_person", 1, 100.0),
            slot("scenario.standing_person_2", "standing_person", 2, 300.0),
        ])
        surface["walk_lanes"] = [{
            "id": "public_lane", "direction": "both",
            "points": [[100.0, 200.0], [300.0, 200.0]],
        }]
        surface["actor_routes"] = [{
            "id": "cross_room",
            "start_slot_id": "scenario.standing_person_1",
            "end_slot_id": "scenario.standing_person_2",
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
            ["scenario.standing_person_1", "scenario.standing_person_2"],
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


class ReviewedCurrentSlotAuthorityTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        root = TOOLS_ROOT.parent
        placement = json.loads((root / "data/environments/placement_surfaces.json").read_text(encoding="utf-8"))
        cls.maps = {row["id"]: row for row in placement["maps"]}
        cls.archetypes = {row["id"]: row for row in json.loads((root / "data/environments/archetypes.json").read_text(encoding="utf-8"))}
        cls.layouts = json.loads((root / "data/environments/scenario_slot_layouts.json").read_text(encoding="utf-8"))["layouts"]

    def errors_for(self, surface: dict[str, Any]) -> list[str]:
        check = SlotCheck.Check()
        archetype_id = surface.get("archetype_id", surface["id"].split(":", 1)[0])
        SlotCheck.validate_map_v2(check, surface, self.archetypes[archetype_id], (900.0, 430.0))
        return check.errors

    def test_current_reviewed_maps_preserve_their_full_authority(self) -> None:
        for map_id in ("corner_store", "gas_station_casino", "small_underground_casino:casino", "jazz_club", "kitty_cat_lounge", "delta_queen", "pawn_shop", "grand_casino", "grand_casino_cage"):
            with self.subTest(map_id=map_id):
                self.assertEqual(self.errors_for(self.maps[map_id]), [])

    def test_unknown_named_slot_is_not_a_generic_exception(self) -> None:
        surface = copy.deepcopy(self.maps["corner_store"])
        next(row for row in surface["event_slots"] if row["id"] == "event.lucky_recruitment")["id"] = "event.some_other_recruit"
        self.assertTrue(any("canonical id" in error for error in self.errors_for(surface)))

    def test_sal_supported_order_does_not_admit_changed_or_duplicate_occupants(self) -> None:
        for occupants in (
            ["event:chain06_sal_trail_one"],
            ["event:chain06_sal_trail_one", "event:chain06_sal_trail_two", "event:chain06_sal_trail_three", "event:unexpected_note"],
            ["event:chain06_sal_trail_one", "event:chain06_sal_trail_two", "event:chain06_sal_trail_three", "event:chain06_sal_trail_one"],
        ):
            with self.subTest(occupants=occupants):
                surface = copy.deepcopy(self.maps["kitty_cat_lounge"])
                next(row for row in surface["event_slots"] if row["id"] == "event.sal_address_note")["occupant_ids"] = occupants
                self.assertTrue(self.errors_for(surface))

    def test_unreviewed_prop_reserve_and_capacity_loss_remain_rejected(self) -> None:
        surface = copy.deepcopy(self.maps["gas_station_casino"])
        note = next(row for row in surface["event_slots"] if row["id"] == "event.surface_item_1")
        note["runtime_reserve"] = True
        note["reserve_reason"] = "Unreviewed generic capacity."
        self.assertTrue(any("non-person event" in error for error in self.errors_for(surface)))
        surface["event_slots"].remove(note)
        self.assertTrue(any("capacity matrix drift" in error for error in self.errors_for(surface)))

    def test_moved_punchline_props_trace_exact_reserved_source_owners(self) -> None:
        source = next(row for row in self.maps["small_underground_casino:club"]["scenario_slots"] if row["id"] == "scenario.floor_fixture_3")
        for scenario_id in ("punchline_open_mic_night", "punchline_raid_jitters"):
            with self.subTest(scenario_id=scenario_id):
                layout = next(row for row in self.layouts if row["scenario_id"] == scenario_id)
                local = next(row for row in layout["scenario_slots"] if row["id"] == "scenario.local_floor_fixture_4")
                self.assertNotEqual(local["pos"], source["pos"])
                self.assertTrue(SlotCheck._v2_scenario_source_matches(local, source))
                unrelated = copy.deepcopy(local)
                unrelated["scenario_object_ids"] = ["scenario::unrelated_prop"]
                self.assertFalse(SlotCheck._v2_scenario_source_matches(unrelated, source))
                unrelated["scenario_object_ids"] = []
                self.assertFalse(SlotCheck._v2_scenario_source_matches(unrelated, source))
                wrong_class = dict(source, footprint_class="wall_mounted")
                self.assertFalse(SlotCheck._v2_scenario_source_matches(local, wrong_class))
                self.assertFalse(SlotCheck._v2_scenario_source_matches(local, {}))


if __name__ == "__main__":
    unittest.main()
