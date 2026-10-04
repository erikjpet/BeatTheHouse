#!/usr/bin/env python3
"""Regression tests for compact, scenario-scoped environment placement.

These tests deliberately exercise the checked-in authorities and the generator
instead of duplicating a hand-maintained list of scenario props.  The catalog
defines 20 reachable base contexts, one non-runtime template map, and 55
scenario contexts; the generated companion file must cover that matrix exactly,
use compact context-local banks, and replay every reachable sequence snapshot
without falling back to runtime reserves.
"""

from __future__ import annotations

import copy
import json
import math
import re
import sys
import unittest
from collections import defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOLS_ROOT))

import author_scenario_slot_layouts as Authoring  # noqa: E402
import environment_fixed_slot_static_check as StaticCheck  # noqa: E402


COMPACT_SLOT_ID = re.compile(r"^scenario\.([a-z][a-z0-9_]*)_([1-9][0-9]*)$")
FAMILIES = ("fixed", "event", "scenario", "exit")


def values(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def mapping(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


class ScenarioSlotLayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.placement = json.loads(Authoring.PLACEMENT_PATH.read_text(encoding="utf-8"))
        cls.catalog = json.loads(Authoring.SCENARIO_PATH.read_text(encoding="utf-8"))
        cls.archetypes = json.loads(
            (ROOT / "data" / "environments" / "archetypes.json").read_text(
                encoding="utf-8"
            )
        )
        cls.payload = json.loads(Authoring.OUTPUT_PATH.read_text(encoding="utf-8"))
        cls.maps = {
            str(row.get("id", "")): row
            for row in values(cls.placement.get("maps"))
            if isinstance(row, dict)
        }
        cls.layouts = {
            (str(row.get("map_id", "")), str(row.get("scenario_id", ""))): row
            for row in values(cls.payload.get("layouts"))
            if isinstance(row, dict)
        }
        cls.expected_pairs = {
            (map_id, scenario_id)
            for map_id, scenario_id, _row in Authoring.scenario_rows()
        }

    def test_checked_in_authority_is_current_and_covers_all_75_contexts(self) -> None:
        generated = Authoring.build_payload()
        self.assertEqual(
            generated,
            self.payload,
            "scenario_slot_layouts.json is stale; run author_scenario_slot_layouts.py",
        )
        self.assertEqual(Authoring.encoded(generated), Authoring.OUTPUT_PATH.read_bytes())

        map_ids = set(self.maps)
        self.assertEqual(len(map_ids), 21)
        self.assertEqual(len(self.expected_pairs), 55)
        self.assertEqual(set(self.layouts), self.expected_pairs)
        self.assertEqual(self.payload.get("layout_count"), 55)
        base_layout_ids = set(values(self.payload.get("base_layout_ids")))
        template_map_ids = set(values(self.payload.get("template_map_ids")))
        self.assertEqual(len(base_layout_ids), 20)
        self.assertEqual(template_map_ids, {"small_underground_casino"})
        self.assertTrue(base_layout_ids.isdisjoint(template_map_ids))
        self.assertEqual(base_layout_ids | template_map_ids, map_ids)
        self.assertEqual(
            set(values(self.payload.get("maps_with_catalog_scenarios"))),
            {map_id for map_id, _scenario_id in self.expected_pairs},
        )
        for pair, layout in self.layouts.items():
            map_id, scenario_id = pair
            self.assertEqual(layout.get("layout_id"), f"{map_id}::{scenario_id}")
            self.assertIn(map_id, map_ids)

    def test_every_layout_uses_compact_context_local_slot_banks(self) -> None:
        allowed_tokens = {
            Authoring.clean_slug(Authoring.ROLE_SLOT_TOKEN.get(role, role))
            for role in StaticCheck.CLASSES
        }
        total_slots = 0
        total_semantic_positions = 0
        global_slot_ids: set[str] = set()

        for (map_id, scenario_id), layout in sorted(self.layouts.items()):
            with self.subTest(layout=layout.get("layout_id")):
                slots = [
                    slot
                    for slot in values(layout.get("scenario_slots"))
                    if isinstance(slot, dict)
                ]
                audit = mapping(layout.get("audit"))
                self.assertGreaterEqual(len(slots), 1)
                self.assertLessEqual(
                    len(slots),
                    12,
                    "manual placement regressed to a large per-scenario marker bank",
                )
                self.assertEqual(audit.get("slot_count"), len(slots))
                semantic_count = int(audit.get("semantic_position_count", -1))
                reused_count = int(audit.get("reused_semantic_position_count", -1))
                self.assertGreaterEqual(semantic_count, len(slots))
                self.assertEqual(reused_count, semantic_count - len(slots))

                reserve_ids = {
                    str(slot.get("id", ""))
                    for slot in values(self.maps[map_id].get("scenario_slots"))
                    if isinstance(slot, dict) and bool(slot.get("runtime_reserve", False))
                }
                ids: set[str] = set()
                ordinals: dict[str, list[int]] = defaultdict(list)
                for slot in slots:
                    slot_id = str(slot.get("id", ""))
                    match = COMPACT_SLOT_ID.fullmatch(slot_id)
                    self.assertIsNotNone(match, f"{slot_id} is not a compact local slot id")
                    if match is None:
                        continue
                    token, ordinal_text = match.groups()
                    placement_class = str(slot.get("footprint_class", ""))
                    expected_token = Authoring.clean_slug(
                        Authoring.ROLE_SLOT_TOKEN.get(placement_class, placement_class)
                    )
                    self.assertIn(token, allowed_tokens)
                    self.assertEqual(token, expected_token)
                    ordinal = int(ordinal_text)
                    ordinals[token].append(ordinal)
                    self.assertNotIn(slot_id, ids)
                    self.assertNotIn(slot_id, reserve_ids)
                    ids.add(slot_id)
                    self.assertEqual(slot.get("kind"), "scenario")
                    self.assertEqual(slot.get("scenario_id"), scenario_id)
                    self.assertIs(slot.get("scenario_instance"), True)
                    self.assertIs(slot.get("runtime_reserve"), False)
                    self.assertEqual(slot.get("scenario_role"), placement_class)
                    self.assertEqual(slot.get("scenario_ordinal"), ordinal)
                    self.assertIn(placement_class, StaticCheck.CLASSES)
                    self.assertTrue(StaticCheck.slot_meets_interactive_minimum(slot))
                    for field, size in (("pos", 2), ("hit_rect", 4), ("label_anchor", 2)):
                        numbers = values(slot.get(field))
                        self.assertEqual(len(numbers), size)
                        self.assertTrue(all(isinstance(number, (int, float)) and math.isfinite(float(number)) for number in numbers))
                    self.assertTrue(
                        values(slot.get("scenario_position_keys"))
                        or values(slot.get("scenario_object_ids")),
                        f"{slot_id} has no exact scenario claimant",
                    )
                    occupant_labels = [
                        str(label).strip()
                        for label in values(slot.get("scenario_occupant_labels"))
                        if str(label).strip()
                    ]
                    self.assertTrue(
                        occupant_labels,
                        f"{map_id}::{scenario_id} {slot_id} has no owner-facing occupant label",
                    )
                    self.assertEqual(occupant_labels, sorted(set(occupant_labels)))
                    self.assertIn(occupant_labels[0], str(slot.get("physical_role", "")))
                for token, role_ordinals in ordinals.items():
                    highest = max(role_ordinals)
                    expected_ordinals = [
                        ordinal
                        for ordinal in range(1, highest + 1)
                        if f"scenario.{token}_{ordinal}" not in reserve_ids
                    ]
                    self.assertEqual(
                        sorted(role_ordinals),
                        expected_ordinals,
                        f"{map_id}::{scenario_id} {token} ordinals have a gap that is not a runtime reserve",
                    )
                total_slots += len(slots)
                total_semantic_positions += semantic_count
                global_slot_ids.update(ids)

        self.assertEqual(total_slots, int(self.payload.get("scenario_slot_count", -1)))
        self.assertLess(total_slots, total_semantic_positions)
        self.assertEqual(
            total_semantic_positions - total_slots,
            sum(
                int(mapping(layout.get("audit")).get("reused_semantic_position_count", 0))
                for layout in self.layouts.values()
            ),
        )
        self.assertLess(
            len(global_slot_ids),
            total_slots,
            "slot ids became globally unique instead of compact and context-local",
        )

    def test_reachable_fixed_and_exit_banks_have_no_dead_rows(self) -> None:
        reachable_maps = set(values(self.payload.get("base_layout_ids")))
        for map_id in sorted(reachable_maps):
            map_data = self.maps[map_id]
            referenced_ids = {
                str(slot_id)
                for family in FAMILIES
                for suffix in ("object_slot_ids", "category_slot_ids")
                for slot_id in mapping(
                    map_data.get(f"{family}_{suffix}")
                ).values()
            }
            for family in ("fixed", "exit"):
                for slot in values(map_data.get(f"{family}_slots")):
                    if not isinstance(slot, dict):
                        continue
                    slot_id = str(slot.get("id", ""))
                    live = (
                        slot_id in referenced_ids
                        or bool(values(slot.get("occupant_ids")))
                        or bool(slot.get("occupancy_required", False))
                        or bool(slot.get("runtime_reserve", False))
                    )
                    self.assertTrue(
                        live,
                        f"{map_id} retains unused {family} placement row {slot_id}",
                    )
                    if family == "exit":
                        self.assertIn(
                            slot_id,
                            set(mapping(map_data.get("exit_object_slot_ids")).values())
                            | set(mapping(map_data.get("exit_category_slot_ids")).values()),
                            f"{map_id} exit {slot_id} is not reachable from a runtime exit",
                        )

    def test_reviewed_shop_capacity_matches_generator_ceiling(self) -> None:
        archetypes = {
            str(row.get("id", "")): row
            for row in values(self.archetypes)
            if isinstance(row, dict)
        }
        expected = {
            "corner_store": 5,
            "motel": 4,
            "kitty_cat_lounge": 2,
            "delta_queen": 2,
            "pawn_shop": 6,
        }
        for map_id, ceiling in expected.items():
            with self.subTest(map_id=map_id):
                map_data = self.maps[map_id]
                slots = [
                    str(slot.get("id", ""))
                    for slot in values(map_data.get("fixed_slots"))
                    if isinstance(slot, dict)
                    and re.fullmatch(r"fixed\.item_shop_[1-9][0-9]*", str(slot.get("id", "")))
                ]
                self.assertEqual(len(slots), ceiling)
                category_ids = {
                    str(key): str(value)
                    for key, value in mapping(
                        map_data.get("fixed_category_slot_ids")
                    ).items()
                    if str(key).startswith("item_spots:")
                }
                self.assertEqual(len(category_ids), ceiling)
                self.assertEqual(
                    len(values(mapping(archetypes[map_id].get("layout")).get("item_spots"))),
                    ceiling,
                )

    def test_exact_mappings_are_closed_and_separate_from_runtime_reserves(self) -> None:
        for (map_id, scenario_id), layout in sorted(self.layouts.items()):
            with self.subTest(layout=layout.get("layout_id")):
                slots = {
                    str(slot.get("id", "")): slot
                    for slot in values(layout.get("scenario_slots"))
                    if isinstance(slot, dict)
                }
                reserves = {
                    str(slot.get("id", ""))
                    for slot in values(self.maps[map_id].get("scenario_slots"))
                    if isinstance(slot, dict) and bool(slot.get("runtime_reserve", False))
                }
                self.assertTrue(set(slots).isdisjoint(reserves))

                semantic_preferences = mapping(layout.get("scenario_instance_slot_ids"))
                object_preferences = mapping(layout.get("scenario_instance_object_slot_ids"))
                object_families = mapping(layout.get("scenario_instance_object_family_ids"))
                self.assertEqual(set(object_families), set(object_preferences))
                self.assertTrue(all(family == "scenario" for family in object_families.values()))
                for field, preferences in (
                    ("scenario_instance_slot_ids", semantic_preferences),
                    ("scenario_instance_object_slot_ids", object_preferences),
                ):
                    for claimant, slot_id_value in preferences.items():
                        slot_id = str(slot_id_value)
                        self.assertIn(slot_id, slots, f"{field}.{claimant} is not local")
                        self.assertNotIn(slot_id, reserves)

                for object_id, slot_id_value in object_preferences.items():
                    target = slots[str(slot_id_value)]
                    self.assertIn(object_id, values(target.get("scenario_object_ids")))

                listed_positions: dict[str, str] = {}
                for slot_id, slot in slots.items():
                    for position_key_value in values(slot.get("scenario_position_keys")):
                        position_key = str(position_key_value).strip()
                        if not position_key:
                            continue
                        self.assertNotIn(position_key, listed_positions)
                        listed_positions[position_key] = slot_id
                        if not position_key.startswith("route::"):
                            self.assertEqual(semantic_preferences.get(position_key), slot_id)

                    source_id = str(slot.get("source_slot_id", ""))
                    source_slots = {
                        str(source.get("id", "")): source
                        for family in FAMILIES
                        for source in values(self.maps[map_id].get(f"{family}_slots"))
                        if isinstance(source, dict)
                    }
                    self.assertIn(source_id, source_slots)
                    if bool(slot.get("provisional_geometry", False)):
                        self.assertEqual(slot.get("support_id"), "manual_placement_required")
                    else:
                        source = source_slots[source_id]
                        self.assertEqual(source.get("kind"), "scenario")
                        self.assertIs(source.get("runtime_reserve"), False)
                        self.assertEqual(
                            source.get("footprint_class"),
                            slot.get("footprint_class"),
                        )

                for route in values(layout.get("actor_routes")):
                    self.assertIsInstance(route, dict)
                    if not isinstance(route, dict):
                        continue
                    start_id = str(route.get("start_slot_id", ""))
                    end_id = str(route.get("end_slot_id", ""))
                    self.assertIn(start_id, slots)
                    self.assertIn(end_id, slots)
                    self.assertNotEqual(start_id, end_id)
                    self.assertEqual(
                        slots[start_id].get("footprint_class"),
                        route.get("footprint_class"),
                    )
                    self.assertEqual(
                        slots[end_id].get("footprint_class"),
                        route.get("footprint_class"),
                    )

    def test_conditional_chain_and_recruitment_objects_are_scenario_owned(self) -> None:
        expected_owners: dict[str, set[tuple[str, str]]] = defaultdict(set)
        expected_classes: dict[tuple[str, str, str], str] = {}
        for pair, declarations in Authoring.CONDITIONAL_SCENARIO_OBJECTS.items():
            for declaration in declarations:
                object_id = str(declaration["object_id"])
                expected_owners[object_id].add(pair)
                expected_classes[(pair[0], pair[1], object_id)] = str(
                    declaration["placement_class"]
                )

        actual_owners: dict[str, set[tuple[str, str]]] = defaultdict(set)
        for pair, layout in self.layouts.items():
            object_preferences = mapping(layout.get("scenario_instance_object_slot_ids"))
            object_families = mapping(layout.get("scenario_instance_object_family_ids"))
            slots = {
                str(slot.get("id", "")): slot
                for slot in values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
            }
            for object_id in expected_owners:
                if object_id not in object_preferences:
                    continue
                actual_owners[object_id].add(pair)
                self.assertEqual(object_families.get(object_id), "scenario")
                target = slots[str(object_preferences[object_id])]
                self.assertEqual(
                    target.get("footprint_class"),
                    expected_classes[(pair[0], pair[1], object_id)],
                )
                self.assertIn(object_id, values(target.get("scenario_object_ids")))
        self.assertEqual(dict(actual_owners), dict(expected_owners))

    def test_every_reachable_snapshot_uses_exact_local_capacity(self) -> None:
        snapshots = Authoring.snapshots_by_scenario()
        self.assertEqual(set(snapshots), self.expected_pairs)
        replayed = 0
        for pair in sorted(self.expected_pairs):
            map_id, scenario_id = pair
            layout = self.layouts[pair]
            local_slot_ids = {
                str(slot.get("id", ""))
                for slot in values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
            }
            effective = StaticCheck._v2_effective_scenario_map(
                self.maps[map_id], scenario_id, self.layouts
            )
            for snapshot in snapshots[pair]:
                replayed += 1
                result = StaticCheck._v2_bind_scenario_snapshot(effective, snapshot)
                repeated = StaticCheck._v2_bind_scenario_snapshot(effective, snapshot)
                with self.subTest(layout=f"{map_id}::{scenario_id}", replay=replayed):
                    self.assertEqual(result, repeated)
                    self.assertEqual(result.get("errors"), [])
                    self.assertEqual(result.get("missing_count"), 0)
                    self.assertEqual(result.get("conflict_count"), 0)
                    for binding in mapping(result.get("bindings")).values():
                        if not isinstance(binding, dict) or binding.get("mode") != "room":
                            continue
                        if binding.get("slot_family") == "scenario":
                            self.assertIn(
                                str(binding.get("slot_id", "")),
                                local_slot_ids,
                                "catalog scenario visual fell into a runtime-reserve slot",
                            )
            self.assertTrue(snapshots[pair], f"{map_id}::{scenario_id} has no replay")
        self.assertGreater(replayed, 55)

    def test_corrupt_exact_mapping_fails_closed_in_replay(self) -> None:
        selected: tuple[dict[str, Any], dict[str, Any], str] | None = None
        snapshots = Authoring.snapshots_by_scenario()
        for pair in sorted(self.expected_pairs):
            map_id, scenario_id = pair
            effective = StaticCheck._v2_effective_scenario_map(
                self.maps[map_id], scenario_id, self.layouts
            )
            preferences = mapping(effective.get("scenario_instance_slot_ids"))
            for snapshot in snapshots[pair]:
                for semantic in snapshot:
                    if not isinstance(semantic, dict):
                        continue
                    entry = Authoring.visual_entry(effective, semantic)
                    if entry is None or str(entry.get("route_id", "")):
                        continue
                    position_key = str(entry.get("position_key", ""))
                    if position_key in preferences:
                        selected = (effective, semantic, position_key)
                        break
                if selected is not None:
                    break
            if selected is not None:
                break
        self.assertIsNotNone(selected)
        if selected is None:
            return
        effective, semantic, position_key = selected
        corrupt = copy.deepcopy(effective)
        corrupt["scenario_instance_slot_ids"][position_key] = "scenario.missing_99"
        result = StaticCheck._v2_bind_scenario_snapshot(corrupt, [semantic])
        self.assertEqual(result.get("missing_count"), 1)
        self.assertTrue(result.get("errors"))
        self.assertNotIn(
            "scenario.missing_99",
            {
                str(slot.get("id", ""))
                for slot in values(corrupt.get("scenario_slots"))
                if isinstance(slot, dict)
            },
        )


if __name__ == "__main__":
    unittest.main()
