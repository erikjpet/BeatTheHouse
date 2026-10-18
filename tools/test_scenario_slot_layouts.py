#!/usr/bin/env python3
"""Regression tests for compact, scenario-scoped environment placement.

These tests deliberately exercise the checked-in authorities and the generator
instead of duplicating a hand-maintained list of scenario props.  The catalog
defines 20 reachable base contexts, one non-runtime template map, and 55
scenario contexts; the generated companion file must cover that matrix exactly,
use compact context-local banks for tangible objects, keep abstract controls
attached to their room hosts, and replay every reachable sequence snapshot
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
GENERIC_FIXED_ROLES = {
    "Standing person",
    "Counter staff",
    "Seated person",
    "Group",
    "Floor prop",
    "Floor marker",
    "Counter or table item",
    "Shop item",
    "Wall item",
    "Hanging item",
    "Doorway / exit",
    "Game fixture",
}
RETIRED_VAGUE_SCENARIO_LABELS = {
    "Auth Station",
    "Auth Station Abandoned",
    "Lookout Marker",
    "Lookout Marker Abandoned",
    "Suspect Object",
    "Suspect Object Abandoned",
    "Serial Station",
    "Hold Object",
    "Hold Object Abandoned",
}


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
        cls.snapshots = Authoring.snapshots_by_scenario()

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
            Authoring.clean_slug(
                f"local_{Authoring.ROLE_SLOT_TOKEN.get(role, role)}"
            )
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
                    16,
                    "manual placement regressed to a large per-scenario marker bank",
                )
                self.assertEqual(audit.get("slot_count"), len(slots))
                expected_attached_controls = {
                    str(semantic.get("identity", "")).removeprefix("scenario::")
                    for snapshot in self.snapshots[(map_id, scenario_id)]
                    for semantic in snapshot
                    if isinstance(semantic, dict)
                    and str(semantic.get("identity", "")).startswith("scenario::")
                    and str(semantic.get("role", "")).strip().lower()
                    in Authoring.ATTACHED_CONTROL_ROLES
                }
                self.assertEqual(
                    set(values(audit.get("action_only_ids"))),
                    expected_attached_controls,
                    "the attached-control audit does not match reachable semantics",
                )
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
                        f"local_{Authoring.ROLE_SLOT_TOKEN.get(placement_class, placement_class)}"
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
                    self.assertTrue(
                        set(occupant_labels).isdisjoint(RETIRED_VAGUE_SCENARIO_LABELS),
                        f"{map_id}::{scenario_id} {slot_id} restored a retired vague manual-placement label",
                    )
                    self.assertEqual(
                        len(occupant_labels),
                        len({label.casefold() for label in occupant_labels}),
                        f"{map_id}::{scenario_id} {slot_id} repeats an owner-facing role with capitalization drift",
                    )
                    self.assertIn(occupant_labels[0], str(slot.get("physical_role", "")))
                    zone_ids = [
                        str(zone_id).strip()
                        for zone_id in values(slot.get("scenario_zone_ids"))
                        if str(zone_id).strip()
                    ]
                    self.assertEqual(zone_ids, sorted(set(zone_ids)))
                    self.assertLessEqual(
                        len(zone_ids),
                        1,
                        f"{map_id}::{scenario_id} {slot_id} crosses authored zones",
                    )
                for token, role_ordinals in ordinals.items():
                    self.assertEqual(
                        sorted(role_ordinals),
                        list(range(1, len(role_ordinals) + 1)),
                        f"{map_id}::{scenario_id} {token} ordinals are not contiguous",
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

    def test_reachable_shared_and_source_banks_have_no_dead_rows(self) -> None:
        reachable_maps = set(values(self.payload.get("base_layout_ids")))
        source_ids_by_map: dict[str, set[str]] = defaultdict(set)
        for layout in self.layouts.values():
            map_id = str(layout.get("map_id", ""))
            for slot in values(layout.get("scenario_slots")):
                if not isinstance(slot, dict):
                    continue
                source_id = str(slot.get("source_slot_id", "")).strip()
                if source_id:
                    source_ids_by_map[map_id].add(source_id)
        catalog_maps = {map_id for map_id, _scenario_id in self.layouts}
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
            for family in FAMILIES:
                for slot in values(map_data.get(f"{family}_slots")):
                    if not isinstance(slot, dict):
                        continue
                    slot_id = str(slot.get("id", ""))
                    live = (
                        slot_id in referenced_ids
                        or bool(values(slot.get("occupant_ids")))
                        or bool(slot.get("occupancy_required", False))
                        or bool(slot.get("runtime_reserve", False))
                        or slot_id in source_ids_by_map[map_id]
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

    def test_named_fixed_objects_have_owner_facing_slot_roles(self) -> None:
        for map_id in sorted(set(values(self.payload.get("base_layout_ids")))):
            for slot in values(self.maps[map_id].get("fixed_slots")):
                if not isinstance(slot, dict) or not values(slot.get("occupant_ids")):
                    continue
                slot_id = str(slot.get("id", ""))
                if slot_id.startswith("fixed.item_shop_"):
                    # Numbered shelves intentionally host changing stock IDs.
                    continue
                self.assertNotIn(
                    str(slot.get("physical_role", "")),
                    GENERIC_FIXED_ROLES,
                    f"{map_id} {slot_id} hides a named occupant behind a generic label",
                )

    def test_manual_tabs_are_unique_named_and_reasonably_bounded(self) -> None:
        """Keep the owner pass compact even as future content is added."""
        reachable_maps = set(values(self.payload.get("base_layout_ids")))
        catalog_maps = {map_id for map_id, _scenario_id in self.layouts}
        for map_id in sorted(reachable_maps):
            map_data = self.maps[map_id]
            slots_by_family: dict[str, list[dict[str, Any]]] = {}
            for family in ("fixed", "event", "exit"):
                slots_by_family[family] = [
                    slot
                    for slot in values(map_data.get(f"{family}_slots"))
                    if isinstance(slot, dict)
                ]
            slots_by_family["scenario"] = [
                slot
                for slot in values(map_data.get("scenario_slots"))
                if isinstance(slot, dict)
                and (
                    map_id not in catalog_maps
                    or bool(slot.get("runtime_reserve", False))
                )
            ]
            base_slots = [
                slot for family_slots in slots_by_family.values() for slot in family_slots
            ]
            ids = [str(slot.get("id", "")) for slot in base_slots]
            rects = [tuple(float(value) for value in values(slot.get("hit_rect"))) for slot in base_slots]
            self.assertEqual(len(ids), len(set(ids)), f"{map_id} repeats a base slot id")
            self.assertEqual(len(rects), len(set(rects)), f"{map_id} repeats base slot geometry")
            self.assertLessEqual(
                len(base_slots),
                30,
                f"{map_id} exceeds the reviewed total base-layout capacity",
            )
            for family, family_slots in slots_by_family.items():
                self.assertLessEqual(
                    len(family_slots),
                    15,
                    f"{map_id} {family} tab exceeds the reviewed marker ceiling",
                )
                for slot in family_slots:
                    self.assertTrue(str(slot.get("physical_role", "")).strip())

        for (map_id, scenario_id), layout in sorted(self.layouts.items()):
            local_slots = [
                slot
                for slot in values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
            ]
            reserve_count = sum(
                1
                for slot in values(self.maps[map_id].get("scenario_slots"))
                if isinstance(slot, dict) and bool(slot.get("runtime_reserve", False))
            )
            self.assertLessEqual(
                len(local_slots) + reserve_count,
                20,
                f"{map_id}::{scenario_id} exceeds the reviewed scenario-tab ceiling",
            )

    def test_each_manual_context_has_unique_physical_geometry(self) -> None:
        for (map_id, scenario_id), layout in sorted(self.layouts.items()):
            shared = [
                slot
                for family in ("fixed", "event", "exit")
                for slot in values(self.maps[map_id].get(f"{family}_slots"))
                if isinstance(slot, dict)
            ]
            shared.extend(
                slot
                for slot in values(self.maps[map_id].get("scenario_slots"))
                if isinstance(slot, dict) and bool(slot.get("runtime_reserve", False))
            )
            active = shared + [
                slot
                for slot in values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
            ]
            local = active[len(shared) :]
            owners: dict[tuple[float, float, float, float], str] = {}
            for slot in active:
                bounds = tuple(float(value) for value in values(slot.get("hit_rect")))
                self.assertEqual(len(bounds), 4)
                slot_id = str(slot.get("id", ""))
                self.assertNotIn(
                    bounds,
                    owners,
                    f"{map_id}::{scenario_id} places {slot_id} exactly on {owners.get(bounds, '')}",
                )
                owners[bounds] = slot_id
            for index, slot in enumerate(local):
                slot_id = str(slot.get("id", ""))
                bounds = [float(value) for value in values(slot.get("hit_rect"))]
                for other in shared:
                    self.assertFalse(
                        Authoring._rect_intersects(
                            bounds,
                            [float(value) for value in values(other.get("hit_rect"))],
                        ),
                        f"{map_id}::{scenario_id} partially overlaps shared target: {slot_id}",
                    )
                for other in local[index + 1 :]:
                    self.assertFalse(
                        Authoring._rect_intersects(
                            bounds,
                            [float(value) for value in values(other.get("hit_rect"))],
                        ),
                        f"{map_id}::{scenario_id} partially overlaps local targets: "
                        f"{slot_id}/{other.get('id', '')}",
                    )

    def test_retired_unreachable_source_markers_and_mappings_are_absent(self) -> None:
        retired = {
            "corner_store": {"scenario.behind_counter_person_1"},
            "small_underground_casino:club": {"event.floor_fixture_1"},
            "small_underground_casino:casino": {
                "event.floor_fixture_1",
                "event.seated_person_1",
            },
            "small_underground_casino:back_room": {
                "event.surface_item_1",
                "event.surface_item_2",
                "event.surface_item_3",
                "event.surface_item_4",
                "event.floor_fixture_1",
                "event.doorway_1",
            },
        }
        for map_id, retired_ids in retired.items():
            serialized = json.dumps(self.maps[map_id], sort_keys=True)
            for slot_id in retired_ids:
                self.assertNotIn(f'"{slot_id}"', serialized)
        casino = self.maps["small_underground_casino:casino"]
        for object_id in (
            "event:scenario_new_muscle_door",
            "event:scenario_greased_week_window",
        ):
            self.assertNotIn(object_id, mapping(casino.get("scenario_object_slot_ids")))
            self.assertNotIn(object_id, mapping(casino.get("object_family_ids")))
            self.assertNotIn(object_id, mapping(casino.get("class_overrides")))
            self.assertTrue(
                all(
                    object_id not in values(slot.get("occupant_ids"))
                    for slot in values(casino.get("scenario_slots"))
                    if isinstance(slot, dict)
                )
            )

    def test_every_reachable_visual_label_is_preserved_for_manual_placement(self) -> None:
        for pair, snapshots in self.snapshots.items():
            map_id, scenario_id = pair
            surface = Authoring.effective_map(self.maps[map_id], scenario_id)
            layout = self.layouts[pair]
            preferences = mapping(layout.get("scenario_instance_slot_ids"))
            slots = {
                str(slot.get("id", "")): slot
                for slot in values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
            }
            for snapshot in snapshots:
                for semantic in snapshot:
                    if not isinstance(semantic, dict):
                        continue
                    entry = Authoring.visual_entry(surface, semantic)
                    if entry is None or str(entry.get("route_id", "")):
                        continue
                    position_key = str(entry.get("position_key", ""))
                    slot_id = str(preferences.get(position_key, ""))
                    if not slot_id:
                        continue
                    self.assertIn(
                        str(entry.get("label", "")).casefold(),
                        {
                            str(label).casefold()
                            for label in values(
                                slots[slot_id].get("scenario_occupant_labels")
                            )
                        },
                        f"{map_id}::{scenario_id} lost label for {position_key}",
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
                art_keys = mapping(layout.get("scenario_instance_art_keys"))
                object_families = mapping(layout.get("scenario_instance_object_family_ids"))
                object_classes = mapping(layout.get("scenario_instance_object_class_ids"))
                self.assertEqual(set(object_families), set(object_preferences))
                self.assertEqual(set(object_classes), set(object_preferences))
                self.assertTrue(all(family == "scenario" for family in object_families.values()))
                self.assertEqual(
                    len(art_keys),
                    int(mapping(layout.get("audit")).get("concrete_art_key_count", -1)),
                )
                for position_key, art_key in art_keys.items():
                    self.assertIn(art_key, StaticCheck.CONCRETE_SCENARIO_ART_KEYS)
                    self.assertIn(
                        position_key,
                        semantic_preferences,
                        f"{position_key} has art but no exact scenario position",
                    )
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
                    self.assertEqual(
                        object_classes.get(object_id), target.get("footprint_class")
                    )

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
                    reduced_id = str(route.get("reduced_motion_slot_id", ""))
                    if reduced_id:
                        self.assertIn(reduced_id, {start_id, end_id})
                        self.assertIn(reduced_id, slots)

    def test_reviewed_exact_art_class_and_labels_override_legacy_semantics(self) -> None:
        """Keep owner-facing exact props tied to their reviewed physical noun."""
        generated = Authoring.build_payload()
        layouts = {
            (str(row.get("map_id", "")), str(row.get("scenario_id", ""))): row
            for row in values(generated.get("layouts"))
            if isinstance(row, dict)
        }
        seen_art: set[str] = set()
        seen_class: set[str] = set()
        seen_label: set[str] = set()
        for pair, snapshots in self.snapshots.items():
            map_id, scenario_id = pair
            surface = Authoring.effective_map(self.maps[map_id], scenario_id)
            layout = layouts[pair]
            preferences = mapping(layout.get("scenario_instance_slot_ids"))
            art_keys = mapping(layout.get("scenario_instance_art_keys"))
            slots = {
                str(slot.get("id", "")): slot
                for slot in values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
            }
            for snapshot in snapshots:
                for semantic in snapshot:
                    if not isinstance(semantic, dict):
                        continue
                    identity = str(semantic.get("identity", ""))
                    stable_id = str(
                        semantic.get(
                            "stable_object_id",
                            identity.removeprefix("scenario::"),
                        )
                    ).strip()
                    if stable_id not in (
                        set(Authoring.SCENARIO_ART_STABLE_OVERRIDES)
                        | set(Authoring.EXACT_PLACEMENT_CLASS_OVERRIDES)
                        | set(Authoring.EXACT_SCENARIO_LABEL_OVERRIDES)
                    ):
                        continue
                    entry = Authoring.visual_entry(surface, semantic)
                    self.assertIsNotNone(entry, stable_id)
                    if entry is None:
                        continue
                    position_key = str(entry.get("position_key", ""))
                    slot_id = str(preferences.get(position_key, ""))
                    self.assertIn(slot_id, slots, position_key)
                    slot = slots[slot_id]
                    if stable_id in Authoring.SCENARIO_ART_STABLE_OVERRIDES:
                        seen_art.add(stable_id)
                        self.assertEqual(
                            art_keys.get(position_key),
                            Authoring.SCENARIO_ART_STABLE_OVERRIDES[stable_id],
                            position_key,
                        )
                    if stable_id in Authoring.EXACT_PLACEMENT_CLASS_OVERRIDES:
                        seen_class.add(stable_id)
                        self.assertEqual(
                            slot.get("footprint_class"),
                            Authoring.EXACT_PLACEMENT_CLASS_OVERRIDES[stable_id],
                            position_key,
                        )
                    if stable_id in Authoring.EXACT_SCENARIO_LABEL_OVERRIDES:
                        seen_label.add(stable_id)
                        expected_label = Authoring.EXACT_SCENARIO_LABEL_OVERRIDES[stable_id]
                        # Placement mode reads the live occupant label before it
                        # falls back to generated slot metadata, so both sources
                        # must stay aligned.
                        self.assertEqual(semantic.get("label"), expected_label)
                        self.assertIn(
                            expected_label,
                            values(slot.get("scenario_occupant_labels")),
                        )

        self.assertEqual(seen_art, set(Authoring.SCENARIO_ART_STABLE_OVERRIDES))
        self.assertEqual(seen_class, set(Authoring.EXACT_PLACEMENT_CLASS_OVERRIDES))
        self.assertEqual(seen_label, set(Authoring.EXACT_SCENARIO_LABEL_OVERRIDES))

    def test_action_only_events_never_create_manual_markers(self) -> None:
        generated = Authoring.build_payload()
        generated_layouts = {
            (str(row.get("map_id", "")), str(row.get("scenario_id", ""))): row
            for row in values(generated.get("layouts"))
            if isinstance(row, dict)
        }
        seen_claimants: set[str] = set()
        generated_action_hosts: dict[tuple[str, str], dict[str, str]] = {}
        for pair, layout in generated_layouts.items():
            seen_claimants.update(
                str(object_id)
                for object_id in mapping(
                    layout.get("scenario_instance_object_slot_ids")
                )
            )
            for slot in values(layout.get("scenario_slots")):
                if not isinstance(slot, dict):
                    continue
                seen_claimants.update(
                    str(object_id)
                    for object_id in values(slot.get("scenario_object_ids"))
                )
            action_hosts = {
                str(action_id): str(host_id)
                for action_id, host_id in mapping(
                    layout.get("scenario_instance_action_host_ids")
                ).items()
            }
            if action_hosts:
                generated_action_hosts[pair] = action_hosts

            surface = Authoring.effective_map(self.maps[pair[0]], pair[1])
            placed_ids = {
                str(identity)
                for slot in values(surface.get("fixed_slots"))
                + values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
                for field in ("occupant_ids", "scenario_object_ids")
                for identity in values(slot.get(field))
            }
            for action_id, host_id in action_hosts.items():
                self.assertNotEqual(action_id, host_id)
                self.assertIn(host_id, placed_ids, f"{pair}: unplaced host {host_id}")

        flattened_authority = {
            action_id
            for action_hosts in Authoring.EXACT_ACTION_HOST_IDS.values()
            for action_id in action_hosts
        }
        self.assertEqual(len(flattened_authority), 49)
        self.assertEqual(
            flattened_authority,
            set(Authoring.ACTION_ONLY_BASE_OBJECT_IDS),
        )
        self.assertEqual(
            set(Authoring.EXACT_ACTION_LABELS),
            set(Authoring.ACTION_ONLY_BASE_OBJECT_IDS),
        )
        generated_event_action_hosts = {
            pair: {
                action_id: host_id
                for action_id, host_id in action_hosts.items()
                if action_id.startswith("event:")
            }
            for pair, action_hosts in generated_action_hosts.items()
            if any(action_id.startswith("event:") for action_id in action_hosts)
        }
        self.assertEqual(generated_event_action_hosts, Authoring.EXACT_ACTION_HOST_IDS)
        self.assertTrue(
            Authoring.ACTION_ONLY_BASE_OBJECT_IDS.isdisjoint(seen_claimants),
            "an action attached to a tangible host became a duplicate manual marker",
        )

        event_rows = {
            str(row.get("id", "")): row
            for row in json.loads(
                (ROOT / "data" / "events" / "events.json").read_text(
                    encoding="utf-8"
                )
            )
            if isinstance(row, dict)
        }
        expected_hosts = {
            action_id: host_id
            for action_hosts in Authoring.EXACT_ACTION_HOST_IDS.values()
            for action_id, host_id in action_hosts.items()
        }
        for action_id in sorted(Authoring.ACTION_ONLY_BASE_OBJECT_IDS):
            row = event_rows[action_id.removeprefix("event:")]
            self.assertEqual(
                row.get("display_name"),
                Authoring.EXACT_ACTION_LABELS[action_id],
            )
            self.assertEqual(
                row.get("slot_binding_source_id"),
                expected_hosts[action_id],
            )

    def test_attached_services_use_existing_hosts_without_manual_markers(self) -> None:
        generated = Authoring.build_payload()
        generated_layouts = {
            (str(row.get("map_id", "")), str(row.get("scenario_id", ""))): row
            for row in values(generated.get("layouts"))
            if isinstance(row, dict)
        }
        generated_service_hosts: dict[tuple[str, str], dict[str, str]] = {}
        seen_claimants: set[str] = set()
        for pair, layout in generated_layouts.items():
            object_preferences = mapping(
                layout.get("scenario_instance_object_slot_ids")
            )
            seen_claimants.update(str(object_id) for object_id in object_preferences)
            for slot in values(layout.get("scenario_slots")):
                if isinstance(slot, dict):
                    seen_claimants.update(
                        str(object_id)
                        for object_id in values(slot.get("scenario_object_ids"))
                    )
            service_hosts = {
                str(action_id): str(host_id)
                for action_id, host_id in mapping(
                    layout.get("scenario_instance_action_host_ids")
                ).items()
                if str(action_id).startswith("service:")
            }
            if service_hosts:
                generated_service_hosts[pair] = service_hosts

        self.assertEqual(
            generated_service_hosts,
            Authoring.EXACT_ATTACHED_SERVICE_HOST_IDS,
        )
        attached_service_ids = {
            service_id
            for service_hosts in Authoring.EXACT_ATTACHED_SERVICE_HOST_IDS.values()
            for service_id in service_hosts
        }
        self.assertEqual(
            attached_service_ids,
            {"service:house_drink", "service:punchline_cover_charge"},
        )
        self.assertTrue(attached_service_ids.isdisjoint(seen_claimants))
        self.assertTrue(
            attached_service_ids.isdisjoint(Authoring.ACTION_ONLY_BASE_OBJECT_IDS)
        )

        bringer_pair = (
            "small_underground_casino:club",
            "punchline_bringer_show",
        )
        bringer_surface = Authoring.effective_map(
            self.maps[bringer_pair[0]], bringer_pair[1]
        )
        fixed_service_stage = next(
            (
                slot
                for slot in values(bringer_surface.get("fixed_slots"))
                if isinstance(slot, dict)
                and slot.get("id") == "fixed.service_stage"
            ),
            {},
        )
        self.assertIn(
            "service:punchline_two_drink_minimum",
            values(fixed_service_stage.get("occupant_ids")),
        )
        self.assertEqual(
            mapping(bringer_surface.get("fixed_object_slot_ids")).get(
                "service:punchline_two_drink_minimum"
            ),
            "fixed.service_stage",
        )

    def test_tangible_event_markers_match_runtime_object_semantics(self) -> None:
        generated = Authoring.build_payload()
        generated_layouts = {
            (str(row.get("map_id", "")), str(row.get("scenario_id", ""))): row
            for row in values(generated.get("layouts"))
            if isinstance(row, dict)
        }
        event_rows = {
            str(row.get("id", "")): row
            for row in json.loads(
                (ROOT / "data" / "events" / "events.json").read_text(
                    encoding="utf-8"
                )
            )
            if isinstance(row, dict)
        }
        categories: dict[str, int] = defaultdict(int)
        for (map_id, scenario_id, object_id), spec in sorted(
            Authoring.EXACT_TANGIBLE_EVENT_MARKERS.items()
        ):
            category = str(spec["category"])
            categories[category] += 1
            row = event_rows[object_id.removeprefix("event:")]
            self.assertEqual(row.get("display_name"), spec["label"], object_id)
            self.assertEqual(
                row.get("environment_prop"), spec["environment_prop"], object_id
            )
            runtime_semantic = mapping(Authoring.base_semantics().get(object_id))
            self.assertEqual(runtime_semantic.get("display_name"), spec["label"])
            self.assertEqual(
                runtime_semantic.get("environment_prop"), spec["environment_prop"]
            )
            self.assertFalse(str(row.get("slot_binding_source_id", "")).strip())
            speaker = mapping(row.get("speaker"))
            if category == "A":
                self.assertFalse(
                    bool(speaker.get("environment_actor", False)),
                    f"{object_id} object marker was overridden by its dialogue speaker",
                )
            else:
                self.assertTrue(speaker, f"{object_id} lacks named actor metadata")
                expected_environment_actor = bool(
                    spec.get("environment_actor", True)
                )
                self.assertEqual(
                    bool(speaker.get("environment_actor", False)),
                    expected_environment_actor,
                    f"{object_id} has the wrong room-actor requirement",
                )

            layout = generated_layouts[(map_id, scenario_id)]
            object_slots = mapping(layout.get("scenario_instance_object_slot_ids"))
            object_classes = mapping(layout.get("scenario_instance_object_class_ids"))
            self.assertIn(object_id, object_slots)
            self.assertEqual(object_classes.get(object_id), spec["placement_class"])
            slots = {
                str(slot.get("id", "")): slot
                for slot in values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
            }
            target = slots[str(object_slots[object_id])]
            self.assertEqual(target.get("footprint_class"), spec["placement_class"])
            self.assertIn(spec["label"], values(target.get("scenario_occupant_labels")))
            self.assertIn(object_id, values(target.get("scenario_object_ids")))
            effective = StaticCheck._v2_effective_scenario_map(
                self.maps[map_id], scenario_id, generated_layouts
            )
            self.assertEqual(
                mapping(effective.get("class_overrides")).get(object_id),
                spec["placement_class"],
            )

        self.assertEqual(dict(categories), {"A": 7, "B": 8})
        tangible_ids = {
            object_id
            for _map_id, _scenario_id, object_id in Authoring.EXACT_TANGIBLE_EVENT_MARKERS
        }
        self.assertTrue(tangible_ids.isdisjoint(Authoring.ACTION_ONLY_BASE_OBJECT_IDS))

    def test_source_add_audit_skips_only_exact_action_aliases(self) -> None:
        generated = Authoring.build_payload()
        generated_layouts = {
            (str(row.get("map_id", "")), str(row.get("scenario_id", ""))): row
            for row in values(generated.get("layouts"))
            if isinstance(row, dict)
        }
        check = StaticCheck.Check()
        physical_count = StaticCheck._v2_validate_source_add_claimants(
            check, self.catalog, self.maps, generated_layouts
        )
        self.assertEqual(check.errors, [])
        # Eleven catalog additions are tangible. The remaining source-added
        # records include the reviewed event aliases plus the two Punchline
        # purchase services that attach to existing room hosts.
        self.assertEqual(physical_count, 11)

        delivery = generated_layouts[("corner_store", "corner_store_delivery_day")]
        self.assertEqual(
            mapping(delivery.get("scenario_instance_action_host_ids")).get(
                "event:scenario_delivery_day_stock"
            ),
            "scenario::delivery_clerk",
        )
        self.assertNotIn(
            "event:scenario_delivery_day_stock",
            mapping(delivery.get("scenario_instance_object_slot_ids")),
        )

    def test_attached_controls_are_not_physical_but_game_lane_is(self) -> None:
        self.assertEqual(
            Authoring.ATTACHED_CONTROL_ROLES,
            StaticCheck.ATTACHED_SCENARIO_CONTROL_ROLES,
        )
        attached_count = 0
        game_lane_count = 0
        reused_same_zone = 0
        for pair, snapshots in self.snapshots.items():
            layout = self.layouts[pair]
            preferences = mapping(layout.get("scenario_instance_slot_ids"))
            slots = values(layout.get("scenario_slots"))
            for slot in slots:
                if not isinstance(slot, dict):
                    continue
                if len(values(slot.get("scenario_position_keys"))) > 1 \
                        and len(values(slot.get("scenario_zone_ids"))) == 1:
                    reused_same_zone += 1
            for snapshot in snapshots:
                for semantic in snapshot:
                    if not isinstance(semantic, dict):
                        continue
                    identity = str(semantic.get("identity", ""))
                    if not identity.startswith("scenario::"):
                        continue
                    stable_id = identity.removeprefix("scenario::")
                    position_key = Authoring.SlotAuthoring.scenario_position_key(
                        stable_id, semantic
                    )
                    role = str(semantic.get("role", "")).strip().lower()
                    if role in Authoring.ATTACHED_CONTROL_ROLES:
                        attached_count += 1
                        self.assertNotIn(position_key, preferences)
                        self.assertNotIn(stable_id, preferences)
                        self.assertNotIn(identity, preferences)
                    elif role == "game_lane":
                        game_lane_count += 1
                        self.assertIn(position_key, preferences)
        self.assertGreater(attached_count, 0)
        self.assertGreater(game_lane_count, 0)
        self.assertGreater(
            reused_same_zone,
            0,
            "zone separation accidentally disabled valid same-zone reuse",
        )

        # Even a stale exact mapping cannot turn an attached task control into
        # physical authority; the static replay mirrors the runtime gate.
        map_id, scenario_id = "bar", "bar_dead_tuesday"
        effective = StaticCheck._v2_effective_scenario_map(
            self.maps[map_id], scenario_id, self.layouts
        )
        control = next(
            semantic
            for snapshot in self.snapshots[(map_id, scenario_id)]
            for semantic in snapshot
            if isinstance(semantic, dict)
            and str(semantic.get("role", "")).strip().lower()
            in Authoring.ATTACHED_CONTROL_ROLES
        )
        corrupt = copy.deepcopy(effective)
        local_slot_id = str(values(self.layouts[(map_id, scenario_id)].get("scenario_slots"))[0]["id"])
        identity = str(control.get("identity", ""))
        stable_id = identity.removeprefix("scenario::")
        position_key = Authoring.SlotAuthoring.scenario_position_key(stable_id, control)
        corrupt["scenario_instance_slot_ids"][position_key] = local_slot_id
        replay = StaticCheck._v2_bind_scenario_snapshot(corrupt, [control])
        self.assertEqual(replay.get("errors"), [])
        self.assertEqual(
            mapping(replay.get("bindings")).get(identity, {}).get("mode"),
            "attached",
        )

    def test_zone_mismatch_adds_only_required_coloring_conflicts(self) -> None:
        nodes = {
            "left": {"placement_class": "surface_item", "zone_id": "left"},
            "right": {"placement_class": "surface_item", "zone_id": "right"},
            "left_alternative": {
                "placement_class": "surface_item",
                "zone_id": "left",
            },
            "other_class": {
                "placement_class": "standing_person",
                "zone_id": "right",
            },
        }
        conflicts: dict[str, set[str]] = defaultdict(set)
        Authoring.add_zone_mismatch_conflicts(nodes, conflicts)
        self.assertIn("right", conflicts["left"])
        self.assertNotIn("left_alternative", conflicts["left"])
        self.assertNotIn("other_class", conflicts["left"])
        colors = Authoring._color_graph(
            ["left", "left_alternative", "right"], conflicts, 2
        )
        self.assertIsNotNone(colors)
        if colors is not None:
            self.assertEqual(colors["left"], colors["left_alternative"])
            self.assertNotEqual(colors["left"], colors["right"])

    def test_obstruction_relocation_matches_runtime_small_screen_clearance(self) -> None:
        self.assertEqual(Authoring.SMALL_SCREEN_TARGET, (104.0, 76.0))
        self.assertEqual(
            Authoring._expanded_hit_rect([8.0, 290.0, 44.0, 44.0]),
            [0.0, 274.0, 104.0, 76.0],
            "small-screen expansion must clamp inside the 900x430 room like runtime",
        )

        occupied = [72.0, 270.0, 44.0, 80.0]
        obstruction = {
            "id": "scenario.local_floor_fixture_1",
            "priority": 1,
            "hit_rect": [8.0, 322.0, 44.0, 44.0],
            "_scenario_obstruction": True,
        }
        Authoring.clear_obstruction_conflicts(
            [obstruction],
            {
                "id": "synthetic_obstruction_room",
                "fixed_slots": [{"hit_rect": occupied}],
                "event_slots": [],
                "exit_slots": [],
                "scenario_slots": [],
            },
        )
        relocated = [float(value) for value in values(obstruction.get("hit_rect"))]
        expanded = Authoring._expanded_hit_rect(relocated)
        self.assertFalse(
            Authoring._rect_intersects(relocated, Authoring.MANDATORY_ACCESS_LANE)
        )
        self.assertFalse(
            Authoring._rect_intersects(expanded, Authoring.MANDATORY_ACCESS_LANE)
        )
        self.assertFalse(Authoring._rect_contains_center(expanded, occupied))
        self.assertNotIn("_scenario_obstruction", obstruction)
        self.assertIs(obstruction.get("provisional_geometry"), True)
        self.assertEqual(obstruction.get("support_id"), "manual_placement_required")

        # Preserve the two exact compositions that exposed the bug in the full
        # room sweep: a low restroom marker and a barrier beside a moved auditor.
        cases = [
            (
                "gas_station_casino",
                "gas_station_tour_bus_stop",
                "gas_station_tour_bus_stop_restroom_queue||right|",
                "",
            ),
            (
                "grand_casino",
                "grand_casino_audit_night",
                "grand_casino_audit_night_audit_barrier|grand_work_object_left|center|",
                "grand_casino_audit_night_lead_auditor|grand_work_actor_right|center|grand_casino_audit_night_work_1_relocate_lead_auditor",
            ),
        ]
        for map_id, scenario_id, obstruction_key, target_key in cases:
            layout = self.layouts[(map_id, scenario_id)]
            preferences = mapping(layout.get("scenario_instance_slot_ids"))
            slots = {
                str(slot.get("id", "")): slot
                for slot in values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
            }
            obstacle_rect = [
                float(value)
                for value in values(slots[str(preferences[obstruction_key])].get("hit_rect"))
            ]
            obstacle_expanded = Authoring._expanded_hit_rect(obstacle_rect)
            with self.subTest(layout=f"{map_id}::{scenario_id}"):
                self.assertFalse(
                    Authoring._rect_intersects(
                        obstacle_expanded, Authoring.MANDATORY_ACCESS_LANE
                    )
                )
                if target_key:
                    target_rect = [
                        float(value)
                        for value in values(slots[str(preferences[target_key])].get("hit_rect"))
                    ]
                    self.assertFalse(
                        Authoring._rect_contains_center(obstacle_expanded, target_rect)
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
        snapshots = self.snapshots
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
            local_slots = {
                str(slot.get("id", "")): slot
                for slot in values(layout.get("scenario_slots"))
                if isinstance(slot, dict)
            }
            always_present_ids = set(
                str(slot_id)
                for slot_id in mapping(
                    layout.get("scenario_instance_object_slot_ids")
                ).values()
            )
            shared_rects = Authoring._shared_occupied_rects(
                Authoring.effective_map(self.maps[map_id], scenario_id)
            )
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
                    active_local_ids = set(always_present_ids)
                    for binding in mapping(result.get("bindings")).values():
                        if not isinstance(binding, dict) or binding.get("mode") != "room":
                            continue
                        if binding.get("slot_family") == "scenario":
                            reserved_ids = {
                                str(slot_id)
                                for slot_id in values(binding.get("reserved_slot_ids"))
                            }
                            self.assertTrue(reserved_ids.issubset(local_slot_ids))
                            active_local_ids.update(reserved_ids)
                    active_slots = [local_slots[slot_id] for slot_id in sorted(active_local_ids)]
                    for index, slot in enumerate(active_slots):
                        rect = [float(value) for value in values(slot.get("hit_rect"))]
                        self.assertTrue(
                            all(
                                not Authoring._rect_intersects(rect, shared_rect)
                                for shared_rect in shared_rects
                            )
                        )
                        for other in active_slots[index + 1 :]:
                            self.assertFalse(
                                Authoring._rect_intersects(
                                    rect,
                                    [
                                        float(value)
                                        for value in values(other.get("hit_rect"))
                                    ],
                                ),
                                f"{map_id}::{scenario_id} replay has intersecting "
                                f"targets {slot.get('id', '')}/{other.get('id', '')}",
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
