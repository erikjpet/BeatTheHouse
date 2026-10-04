#!/usr/bin/env python3
"""One-way authoring migration for environment slot schema v2.

This intentionally does not provide a runtime legacy-save adapter. It converts
the checked-in placement authority into four lifecycle-owned slot families and
keeps an explicit family-scoped preference map for generated objects.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
PLACEMENT_PATH = ROOT / "data" / "environments" / "placement_surfaces.json"
ARCHETYPE_PATH = ROOT / "data" / "environments" / "archetypes.json"
SCENARIO_PATH = ROOT / "data" / "environments" / "scenarios.json"
SEQUENCE_DIR = ROOT / "data" / "environments" / "scenario_sequences"
LEGACY_LEDGER_PATH = (
    ROOT / "docs" / "todo" / "environment_slot_family_manifest_legacy_mapping.json"
)
CONSOLIDATION_LEDGER_PATH = (
    ROOT / "docs" / "todo" / "environment_slot_consolidation_disposition.json"
)
CONSOLIDATION_SOURCE_REF = "c3d55ffb"

LEGACY_ORIGIN_FIELD = "__legacy_slot_ledger_origin"
CONSOLIDATION_ORIGIN_FIELD = "__consolidation_source_slot_ids"

FAMILIES = ("fixed", "event", "scenario", "exit")

# Rows retired after the complete 75-context runtime census.  Every entry was
# either unreachable legacy action-list geometry or merchandise capacity above
# the generator's authored maximum.  Keeping the list in the idempotent v2
# maintenance recipe prevents a later refresh from restoring dead placement
# markers that the owner would otherwise waste time positioning.
RETIRED_UNUSED_SLOT_IDS: dict[str, set[str]] = {
    "corner_store": {
        "fixed.drink", "fixed.item_shop_6", "fixed.item_shop_7", "fixed.item_shop_8",
        "fixed.lender_floor_1", "scenario.wall_item_2",
        "fixed.travel_right", "exit.travel_left", "exit.travel_right",
        "exit.safe_left",
    },
    "back_alley": {
        "fixed.random_game_1",
        "exit.door_left_upper", "exit.door_left_lower", "exit.right_lower",
    },
    "motel": {
        "fixed.event_hallway_fixture", "fixed.item_bed_left",
        "fixed.item_key_ledge", "fixed.event_wall_calendar",
        "fixed.item_shop_5", "fixed.item_front_desk", "fixed.lender_visitor",
        "fixed.patron_floor_right",
        "exit.door_left_middle", "exit.left_upper",
    },
    "bar": {
        "fixed.drink", "exit.travel_left", "exit.safe_left", "exit.safe_right",
    },
    "gas_station_casino": {
        "scenario.counter_patron_1",
        "scenario.behind_counter_person_1",
        "exit.door_left_middle", "exit.right_lower",
    },
    "small_underground_casino": {
        "fixed.staff_floor_left", "fixed.service_stage_left",
        "exit.door_right_lower", "exit.door_right_upper",
    },
    "small_underground_casino:club": {
        "fixed.service_left_table",
        "exit.door_right_lower", "exit.left_upper",
    },
    "small_underground_casino:casino": {
        "fixed.random_game_2", "fixed.service_left_table", "scenario.group_1",
        "exit.left_upper",
    },
    "small_underground_casino:back_room": {
        "scenario.surface_item_1", "exit.left_2",
    },
    "kitty_cat_lounge": {
        "fixed.item_shop_3", "exit.door_right_middle",
        "exit.door_right_upper", "exit.right_lower",
    },
    "delta_queen": {
        "fixed.event_table_1", "fixed.event_table_2",
        "fixed.item_shop_3", "fixed.item_shop_4",
        "fixed.item_shop_5", "fixed.item_shop_6", "fixed.item_shop_7",
        "exit.door_left_middle", "exit.left_lower", "exit.right_upper",
    },
    "beach": {
        "fixed.door_left_lower", "scenario.behind_counter_person_2",
        "exit.door_right_lower", "exit.left_upper",
    },
    "pawn_shop": {
        "fixed.item_shop_7", "fixed.item_shop_8",
        "exit.door_left_lower", "exit.left_upper", "exit.right_upper",
    },
    "grand_casino": {
        "fixed.drink", "fixed.event_floor_1", "fixed.event_wall_1",
        "exit.safe_left", "exit.safe_right",
    },
    "grand_casino_high_limit": {"exit.safe_right"},
    "grand_casino_back_room": {"exit.safe_left", "exit.safe_right"},
    "grand_casino_cage": {
        "scenario.surface_item_1", "exit.safe_left", "exit.safe_left_lower",
    },
    "motel_room": {
        "fixed.home_notice", "scenario.surface_item_1",
        "exit.travel_door", "exit.right_door",
    },
    "apartment": {
        "fixed.home_notice", "scenario.surface_item_1",
        "exit.travel_door", "exit.right_door",
    },
    "house": {
        "fixed.home_notice", "scenario.surface_item_1",
        "exit.left_door", "exit.right_door",
    },
}

# The runtime now emits one physical `travel:leave` row plus only genuine
# layer/local-room transitions.  This closed map replaces legacy world-map
# destination aliases and keeps action-list destinations attached to those
# tangible exits instead of manufacturing one marker per possible route.
CANONICAL_EXIT_AUTHORITY: dict[str, dict[str, dict[str, str]]] = {
    "corner_store": {
        "objects": {"travel:leave": "exit.safe_right"},
        "categories": {"travel_spots:0": "exit.safe_right"},
    },
    "back_alley": {
        "objects": {"travel:leave": "exit.right_upper"},
        "categories": {"travel_spots:0": "exit.right_upper"},
    },
    "motel": {
        "objects": {"travel:leave": "exit.door_curtain"},
        "categories": {
            "travel_spots:0": "exit.door_curtain",
            "runtime_object_manifest_entries:0": "exit.motel_room",
        },
    },
    "bar": {
        "objects": {"travel:leave": "exit.travel_right"},
        "categories": {"travel_spots:0": "exit.travel_right"},
    },
    "gas_station_casino": {
        "objects": {"travel:leave": "exit.left_upper"},
        "categories": {"travel_spots:0": "exit.left_upper"},
    },
    "small_underground_casino:club": {
        "objects": {
            "environment_layer:casino": "exit.door_side",
            "travel:leave": "exit.left_lower",
        },
        "categories": {
            "layer_spots:0": "exit.door_side",
            "travel_spots:0": "exit.left_lower",
        },
    },
    "small_underground_casino:casino": {
        "objects": {
            "environment_layer:back_room": "exit.door_guarded_lower",
            "environment_layer:club": "exit.door_left_lower",
            "travel:leave": "exit.guarded_upper",
        },
        "categories": {
            "layer_spots:0": "exit.door_left_lower",
            "layer_spots:1": "exit.door_guarded_lower",
            "travel_spots:0": "exit.guarded_upper",
        },
    },
    "small_underground_casino:back_room": {
        "objects": {
            "environment_layer:casino": "exit.layer_door",
            "travel:leave": "exit.left_1",
        },
        "categories": {
            "layer_spots:0": "exit.layer_door",
            "travel_spots:0": "exit.left_1",
        },
    },
    "jazz_club": {
        "objects": {"travel:leave": "exit.door_right_upper"},
        "categories": {"travel_spots:0": "exit.door_right_upper"},
    },
    "kitty_cat_lounge": {
        "objects": {"travel:leave": "exit.left_lower"},
        "categories": {"travel_spots:0": "exit.left_lower"},
    },
    "delta_queen": {
        "objects": {"travel:leave": "exit.door_right_middle"},
        "categories": {"travel_spots:0": "exit.door_right_middle"},
    },
    "beach": {
        "objects": {"travel:leave": "exit.right_upper"},
        "categories": {"travel_spots:0": "exit.right_upper"},
    },
    "pawn_shop": {
        "objects": {"travel:leave": "exit.door_right_lower"},
        "categories": {"travel_spots:0": "exit.door_right_lower"},
    },
    "grand_casino": {
        "objects": {
            "travel:grand_casino_back_room": "exit.travel_back_room",
            "travel:grand_casino_cage": "exit.travel_cage",
            "travel:grand_casino_high_limit": "exit.travel_high_limit",
            "travel:leave": "exit.travel_leave",
        },
        "categories": {
            "casino_door_spots:0": "exit.travel_high_limit",
            "casino_door_spots:1": "exit.travel_back_room",
            "casino_door_spots:2": "exit.travel_cage",
            "travel_spots:0": "exit.travel_leave",
        },
    },
    "grand_casino_high_limit": {
        "objects": {
            "travel:grand_casino": "exit.travel_left",
            "travel:grand_casino_cage": "exit.travel_right",
            "travel:leave": "exit.safe_left",
        },
        "categories": {
            "casino_door_spots:0": "exit.travel_left",
            "casino_door_spots:1": "exit.travel_right",
            "travel_spots:0": "exit.safe_left",
        },
    },
    "grand_casino_back_room": {
        "objects": {"travel:leave": "exit.travel_left"},
        "categories": {"travel_spots:0": "exit.travel_left"},
    },
    "grand_casino_cage": {
        "objects": {
            "travel:grand_casino": "exit.casino_floor_door",
            "travel:leave": "exit.travel_floor_door",
        },
        "categories": {
            "casino_door_spots:0": "exit.casino_floor_door",
            "travel_spots:0": "exit.travel_floor_door",
        },
    },
    "motel_room": {
        "objects": {"travel:leave": "exit.left_door"},
        "categories": {"travel_spots:0": "exit.left_door"},
    },
    "apartment": {
        "objects": {"travel:leave": "exit.left_door"},
        "categories": {"travel_spots:0": "exit.left_door"},
    },
    "house": {
        "objects": {"travel:leave": "exit.travel_door"},
        "categories": {"travel_spots:0": "exit.travel_door"},
    },
}

# Initial collision-free geometry for the owner placement pass.  These are
# deliberately modest source-layout corrections, not an artistic final pass.
# Exact scenario layouts clone this geometry and can then be repositioned
# independently through the in-game tool.
REVIEWED_SLOT_GEOMETRY: dict[str, dict[str, dict[str, Any]]] = {
    "corner_store": {
        "scenario.wall_item_2": {
            "pos": [486.0, 62.0],
            "hit_rect": [446.0, 38.0, 80.0, 48.0],
            "label_anchor": [486.0, 94.0],
            "support_id": "wall",
        },
    },
    "motel": {
        "fixed.item_shop_4": {
            "pos": [298.0, 100.0],
            "hit_rect": [262.0, 52.0, 72.0, 48.0],
            "label_anchor": [298.0, 46.0],
            "support_id": "lobby_key_ledge",
        },
        "scenario.doorway_1": {
            "pos": [859.0, 116.0],
            "hit_rect": [827.0, 80.0, 64.0, 72.0],
            "label_anchor": [859.0, 74.0],
            "support_id": "right_door",
        },
    },
    "bar": {
        "scenario.standing_person_1": {
            "pos": [526.0, 294.0],
            "hit_rect": [490.0, 214.0, 72.0, 80.0],
            "label_anchor": [526.0, 208.0],
            "support_id": "floor",
        },
    },
    "gas_station_casino": {
        "event.doorway_2": {
            "pos": [262.0, 120.0],
            "hit_rect": [226.0, 96.0, 72.0, 48.0],
            "label_anchor": [262.0, 90.0],
            "support_id": "round3_sill_door",
        },
        "scenario.doorway_1": {
            "pos": [350.0, 120.0],
            "hit_rect": [314.0, 96.0, 72.0, 48.0],
            "label_anchor": [350.0, 90.0],
            "support_id": "round3_sill_door",
        },
    },
    "kitty_cat_lounge": {
        "scenario.doorway_1": {
            "pos": [876.0, 180.0],
            "hit_rect": [852.0, 144.0, 48.0, 72.0],
            "label_anchor": [876.0, 218.0],
            "support_id": "right_exit",
        },
    },
    "delta_queen": {
        "scenario.wall_item_2": {
            "pos": [166.0, 24.0],
            "hit_rect": [126.0, 0.0, 80.0, 48.0],
            "label_anchor": [166.0, 8.0],
            "support_id": "wall",
        },
        "scenario.floor_fixture_1": {
            "pos": [284.0, 324.0],
            "hit_rect": [238.0, 260.0, 92.0, 64.0],
            "label_anchor": [284.0, 254.0],
            "support_id": "floor",
        },
    },
    "pawn_shop": {
        "scenario.shop_item_1": {
            "pos": [96.0, 184.0],
            "hit_rect": [60.0, 136.0, 72.0, 48.0],
            "label_anchor": [96.0, 130.0],
            "support_id": "estate_left_lower_shelf",
        },
        "scenario.shop_item_2": {
            "pos": [362.0, 176.0],
            "hit_rect": [326.0, 128.0, 72.0, 48.0],
            "label_anchor": [362.0, 122.0],
            "support_id": "estate_center_lower_shelf",
        },
        "scenario.surface_item_1": {
            "pos": [676.0, 104.0],
            "hit_rect": [640.0, 56.0, 72.0, 48.0],
            "label_anchor": [676.0, 50.0],
            "support_id": "estate_right_upper_shelf",
        },
        "scenario.surface_item_2": {
            "pos": [196.0, 184.0],
            "hit_rect": [160.0, 136.0, 72.0, 48.0],
            "label_anchor": [196.0, 130.0],
            "support_id": "estate_left_lower_shelf",
        },
    },
}

PULL_TABS_HOST_ACTION_IDS = (
    "game:pull_tabs",
    "game_hook:pull_tabs:ticket_redeemer",
    "dialogue:pull_tab_clerk",
)

# Reviewed maximum banks.  Active/aftermath replay is combined with source-add
# producers, delivery contact/package/hold state, recruitment actors, the Crew
# live table, and one injected-person reserve.  The result replaces the old
# 270-row catch-all scenario bank with 213 deliberate positions across all 21
# maps without treating producers outside the snapshot replay as exclusive.
SCENARIO_CAPACITY_TARGETS: dict[str, dict[str, int]] = {
    "corner_store": {"standing_person": 4, "doorway": 1, "wall_mounted": 2, "floor_fixture": 2, "surface_item": 1, "behind_counter_person": 1},
    "back_alley": {"standing_person": 4, "doorway": 1, "wall_mounted": 1, "floor_fixture": 3, "surface_item": 2, "ground_marker": 1},
    "motel": {"standing_person": 4, "behind_counter_person": 1, "floor_fixture": 3, "wall_mounted": 2, "doorway": 3, "hanging": 1, "surface_item": 1},
    "bar": {"floor_fixture": 4, "doorway": 1, "standing_person": 4, "surface_item": 2, "behind_counter_person": 2, "wall_mounted": 2, "seated_person": 2, "ground_marker": 1},
    "gas_station_casino": {"wall_mounted": 3, "standing_person": 5, "doorway": 3, "surface_item": 1, "ground_marker": 1, "behind_counter_person": 1, "floor_fixture": 2, "group": 2},
    "small_underground_casino": {"doorway": 1, "surface_item": 1, "floor_fixture": 1, "standing_person": 1, "wall_mounted": 1},
    "small_underground_casino:club": {"floor_fixture": 3, "standing_person": 4, "doorway": 2, "surface_item": 2, "group": 1, "ground_marker": 1, "wall_mounted": 1},
    "small_underground_casino:casino": {"floor_fixture": 3, "standing_person": 3, "doorway": 2, "seated_person": 1, "wall_mounted": 3, "surface_item": 1, "ground_marker": 1},
    "small_underground_casino:back_room": {"floor_fixture": 1, "standing_person": 1, "wall_mounted": 1},
    "jazz_club": {"standing_person": 3, "floor_fixture": 3, "doorway": 1, "wall_mounted": 2, "surface_item": 1, "seated_person": 1, "ground_marker": 1},
    "kitty_cat_lounge": {"standing_person": 3, "surface_item": 1, "floor_fixture": 3, "doorway": 2, "wall_mounted": 3, "seated_person": 1, "ground_marker": 1},
    "delta_queen": {"standing_person": 3, "floor_fixture": 3, "behind_counter_person": 1, "doorway": 1, "wall_mounted": 4, "group": 1, "surface_item": 2, "ground_marker": 1},
    "beach": {"floor_fixture": 4, "standing_person": 5, "doorway": 1, "surface_item": 2, "wall_mounted": 2, "behind_counter_person": 1, "ground_marker": 1},
    "pawn_shop": {"standing_person": 2, "doorway": 1, "wall_mounted": 2, "floor_fixture": 2, "surface_item": 2, "shop_item": 2},
    "grand_casino": {"surface_item": 1, "standing_person": 3, "doorway": 1, "wall_mounted": 3, "group": 1, "floor_fixture": 3, "ground_marker": 1},
    "grand_casino_high_limit": {"wall_mounted": 1, "floor_fixture": 2, "standing_person": 1},
    "grand_casino_back_room": {"floor_fixture": 2, "standing_person": 1, "wall_mounted": 1},
    "grand_casino_cage": {"floor_fixture": 2, "standing_person": 1, "wall_mounted": 1},
    "motel_room": {"floor_fixture": 1, "standing_person": 1, "wall_mounted": 1},
    "apartment": {"floor_fixture": 1, "standing_person": 1, "wall_mounted": 1},
    "house": {"floor_fixture": 1, "standing_person": 1, "wall_mounted": 1},
}

# Event rows are independent of the selected scenario.  These reviewed banks
# retain the established Crew/traveler/Numbers concurrency.  Jazz alone loses
# one obsolete counter row: rumor actions now live on the fixed bartender, so
# two simultaneous optional event clerks are no longer produced.
EVENT_CAPACITY_TARGETS: dict[str, dict[str, int]] = {
    "corner_store": {"behind_counter_person": 2, "floor_fixture": 1, "group": 1, "standing_person": 1, "ground_marker": 1},
    "back_alley": {"behind_counter_person": 1, "ground_marker": 1, "floor_fixture": 1, "standing_person": 6},
    "motel": {"behind_counter_person": 1, "surface_item": 1, "ground_marker": 1, "standing_person": 4, "doorway": 1},
    "bar": {"behind_counter_person": 1, "floor_fixture": 2, "standing_person": 5, "doorway": 1},
    "gas_station_casino": {"doorway": 2, "floor_fixture": 2, "surface_item": 1, "ground_marker": 1, "standing_person": 5},
    "small_underground_casino": {"floor_fixture": 2, "standing_person": 8, "wall_mounted": 1, "surface_item": 3, "doorway": 1},
    "small_underground_casino:club": {"floor_fixture": 1, "standing_person": 8},
    "small_underground_casino:casino": {"floor_fixture": 1, "behind_counter_person": 1, "seated_person": 1, "standing_person": 8},
    "small_underground_casino:back_room": {"surface_item": 4, "floor_fixture": 1, "doorway": 1, "standing_person": 6},
    "jazz_club": {"floor_fixture": 1, "standing_person": 3},
    "kitty_cat_lounge": {"floor_fixture": 1, "seated_person": 1, "doorway": 1, "standing_person": 6},
    "delta_queen": {"seated_person": 1, "doorway": 1, "behind_counter_person": 1, "floor_fixture": 2, "standing_person": 6},
    "beach": {"standing_person": 1},
    "pawn_shop": {"floor_fixture": 1, "standing_person": 3, "shop_item": 1, "surface_item": 1},
    "grand_casino": {"behind_counter_person": 2, "wall_mounted": 1, "floor_fixture": 1, "standing_person": 7},
    "grand_casino_high_limit": {"floor_fixture": 1, "standing_person": 6},
    "grand_casino_back_room": {"standing_person": 5},
    "grand_casino_cage": {},
    "motel_room": {},
    "apartment": {},
    "house": {},
}

BASELINE_POOL_FIELDS = {
    "game": "game_pool",
    "service": "service_pool",
    "item": "item_pool",
}

# `house_drink` is authored in each listed effective baseline pool, but the
# v1 placement data classified it as scenario-owned because scenarios can also
# add the same service. Keep that reusable scenario capacity and clone its
# venue-authored geometry into a distinct fixed slot for the baseline service.
HOUSE_DRINK_SCENARIO_CAPACITY = {
    "corner_store": "scenario.surface_item_1",
    "back_alley": "scenario.item_shop_1",
    "motel": "scenario.surface_item_2",
    "bar": "scenario.surface_item_1",
    "gas_station_casino": "scenario.floor_patron_1",
    "small_underground_casino:casino": "scenario.floor_group_1",
    "kitty_cat_lounge": "scenario.surface_item_2",
    "delta_queen": "scenario.floor_item_1",
    "grand_casino": "scenario.surface_item_1",
}
HOUSE_DRINK_OBJECT_ID = "service:house_drink"
HOUSE_DRINK_FIXED_SLOT_ID = "fixed.service_house_drink"

# Crew heist play is a scenario chain even though its public interaction is
# projected through event_ids.  It can follow the player through any Grand
# Casino room while live, so every effective room map must retain that lifecycle
# classification and offer shared scenario furniture capacity.
HEIST_LIVE_TABLE_OBJECT_ID = "event:heist_live_table"
HEIST_LIVE_TABLE_MAP_IDS = (
    "grand_casino",
    "grand_casino_high_limit",
    "grand_casino_back_room",
    "grand_casino_cage",
)

GENERIC_ROLE = {
    "standing_person": "standing_person",
    "behind_counter_person": "behind_counter_person",
    "seated_person": "seated_person",
    "group": "group",
    "floor_fixture": "floor_fixture",
    "ground_marker": "ground_marker",
    "surface_item": "surface_item",
    "shop_item": "shop_item",
    "wall_mounted": "wall_item",
    "hanging": "hanging_item",
    "doorway": "doorway",
}

# The one-way v1 recipe first reconstructs the already-reviewed v2 authority,
# whose repair functions still address its historical ids.  A final canonical
# pass below renames those intermediate rows and every reference atomically.
V1_INTERMEDIATE_ROLE = {
    "standing_person": "floor_patron",
    "behind_counter_person": "counter_patron",
    "seated_person": "seated_patron",
    "group": "floor_group",
    "floor_fixture": "floor_item",
    "ground_marker": "floor_marker",
    "surface_item": "surface_item",
    "shop_item": "item_shop",
    "wall_mounted": "wall_item",
    "hanging": "ceiling_item",
    "doorway": "doorway",
}


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, payload: Any) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def iter_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from iter_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_dicts(child)


def collect_scenario_sources(documents: list[Any] | None = None) -> dict[str, set[str]]:
    result = {
        "event": set(),
        "service": set(),
        "item": set(),
        "game": set(),
    }
    if documents is None:
        paths = [SCENARIO_PATH] + sorted(SEQUENCE_DIR.glob("*.json"))
        documents = [load_json(path) for path in paths if path.exists()]
    for document in documents:
        for node in iter_dicts(document):
            for field, family in (
                ("event_pool_add", "event"),
                ("service_add", "service"),
                ("item_offer_add", "item"),
                ("game_pool_add", "game"),
            ):
                values = node.get(field, [])
                if isinstance(values, list):
                    for item in values:
                        if isinstance(item, str) and item.strip():
                            result[family].add(item.strip())
                        elif isinstance(item, dict):
                            item_id = str(item.get("id", "")).strip()
                            if item_id:
                                result[family].add(item_id)
    return result


def required_events_by_map(archetypes: Any | None = None) -> dict[str, set[str]]:
    result: dict[str, set[str]] = defaultdict(set)
    if archetypes is None:
        archetypes = load_json(ARCHETYPE_PATH)
    for archetype in archetypes:
        if not isinstance(archetype, dict):
            continue
        archetype_id = str(archetype.get("id", "")).strip()
        result[archetype_id].update(str(v) for v in (archetype.get("required_event_ids", []) or []) if str(v).strip())
        layers = archetype.get("layers", {})
        if isinstance(layers, dict):
            for layer_id, layer in layers.items():
                if not isinstance(layer, dict):
                    continue
                key = f"{archetype_id}:{layer_id}"
                # Runtime layer authoring deep-merges over the parent. An
                # omitted field inherits; an explicit empty/null value clears.
                values = layer.get(
                    "required_event_ids",
                    archetype.get("required_event_ids", []),
                ) or []
                result[key].update(str(v) for v in values if str(v).strip())
    return result


def baseline_objects_by_map(archetypes: Any | None = None) -> dict[str, set[str]]:
    """Return game/service/item identities authored by each effective map."""

    result: dict[str, set[str]] = defaultdict(set)
    if archetypes is None:
        archetypes = load_json(ARCHETYPE_PATH)
    for archetype in archetypes:
        if not isinstance(archetype, dict):
            continue
        archetype_id = str(archetype.get("id", "")).strip()
        if not archetype_id:
            continue
        for prefix, field in BASELINE_POOL_FIELDS.items():
            for source_id in archetype.get(field, []) or []:
                clean_id = str(source_id).strip()
                if clean_id:
                    result[archetype_id].add(f"{prefix}:{clean_id}")
        layers = archetype.get("layers", {})
        if not isinstance(layers, dict):
            continue
        for layer_id, layer in layers.items():
            if not isinstance(layer, dict):
                continue
            map_id = f"{archetype_id}:{str(layer_id).strip()}"
            for prefix, field in BASELINE_POOL_FIELDS.items():
                # Layer authoring deep-merges over the archetype; an explicit
                # pool replaces its parent, while an omitted pool inherits it.
                values = layer.get(field, archetype.get(field, [])) or []
                for source_id in values:
                    clean_id = str(source_id).strip()
                    if clean_id:
                        result[map_id].add(f"{prefix}:{clean_id}")
    return result


def category_family(key: str) -> str:
    field = key.split(":", 1)[0]
    if field == "event_spots":
        return "event"
    if field in {"travel_spots", "casino_door_spots", "layer_spots"}:
        return "exit"
    if field.startswith("scenario_"):
        return "scenario"
    return "fixed"


def object_family(
    object_id: str,
    map_id: str,
    scenario_sources: dict[str, set[str]],
    required_events: dict[str, set[str]],
    baseline_objects: dict[str, set[str]],
) -> str:
    prefix, _, source_id = object_id.partition(":")
    if prefix in {"travel", "environment_layer", "casino_door"}:
        return "exit"
    # Baseline lifecycle wins over reuse by optional scenarios. A service,
    # game, or item may be scenario-addable elsewhere without becoming a
    # scenario object in a venue whose effective authored pool includes it.
    if object_id in baseline_objects.get(map_id, set()):
        return "fixed"
    if prefix == "event":
        if source_id in required_events.get(map_id, set()):
            return "fixed"
        if source_id in scenario_sources["event"]:
            return "scenario"
        return "event"
    if prefix == "service" and source_id in scenario_sources["service"]:
        return "scenario"
    if prefix == "item" and source_id in scenario_sources["item"]:
        return "scenario"
    if prefix == "game" and source_id in scenario_sources["game"]:
        return "scenario"
    if prefix == "scenario" or object_id.startswith("scenario::"):
        return "scenario"
    return "fixed"


def fixed_slot_id(old_id: str) -> str:
    suffix = old_id.split(".", 1)[1] if "." in old_id else old_id
    if suffix.startswith("shop_item_"):
        suffix = "item_shop_" + suffix.removeprefix("shop_item_")
    elif re.fullmatch(r"game_\d+", suffix):
        suffix = "random_game_" + suffix.removeprefix("game_")
    elif suffix.startswith("fixed_"):
        suffix = suffix.removeprefix("fixed_")
    return f"fixed.{suffix}"


def generic_slot_id(family: str, slot: dict[str, Any], counters: dict[tuple[str, str], int]) -> str:
    footprint = str(slot.get("footprint_class", "floor_fixture"))
    role = V1_INTERMEDIATE_ROLE.get(footprint, footprint or "object")
    key = (family, role)
    counters[key] += 1
    return f"{family}.{role}_{counters[key]}"


def unique_id(candidate: str, used: set[str]) -> str:
    if candidate not in used:
        used.add(candidate)
        return candidate
    ordinal = 2
    while f"{candidate}_{ordinal}" in used:
        ordinal += 1
    result = f"{candidate}_{ordinal}"
    used.add(result)
    return result


def translated_slot(
    source: dict[str, Any],
    family: str,
    new_id: str,
    clone_index: int,
    clone_count: int,
) -> dict[str, Any]:
    result = copy.deepcopy(source)
    result["id"] = new_id
    result["kind"] = family
    if clone_count <= 1 or clone_index == 0:
        return result
    # Small deterministic separation keeps split objects independently movable.
    offsets = ((18.0, 12.0), (-18.0, 12.0), (0.0, -18.0))
    dx, dy = offsets[(clone_index - 1) % len(offsets)]

    def move_pair(field: str) -> None:
        values = result.get(field)
        if isinstance(values, list) and len(values) >= 2:
            values[0] = max(0.0, min(900.0, float(values[0]) + dx))
            values[1] = max(0.0, min(430.0, float(values[1]) + dy))

    move_pair("pos")
    move_pair("label_anchor")
    rect = result.get("hit_rect")
    if isinstance(rect, list) and len(rect) >= 4:
        rect[0] = max(0.0, min(900.0 - float(rect[2]), float(rect[0]) + dx))
        rect[1] = max(0.0, min(430.0 - float(rect[3]), float(rect[1]) + dy))
    return result


def jazz_fixed_objects() -> list[dict[str, Any]]:
    return [
        {
            "object_id": "jazz_club:bartender",
            "presentation_id": "shopkeeper:merchant",
            "object_type": "character",
            "visual_type": "character",
            "render_key": "jazz_bartender",
            "label": "Bartender",
            "placement_class": "behind_counter_person",
            "exact_slot_id": "fixed.staff_bartender",
            "required": True,
            "action_ids": [
                "service:house_drink",
                "event:town_rumor_staff",
            ],
        },
        {
            "object_id": "jazz_club:musician_sax",
            "presentation_id": "musician:jazz_sax",
            "object_type": "character",
            "visual_type": "character",
            "render_key": "jazz_musician_sax",
            "label": "Sax Player",
            "placement_class": "standing_person",
            "exact_slot_id": "fixed.musician_sax",
            "required": True,
            "action_ids": ["service:jazz_sax_round"],
        },
        {
            "object_id": "jazz_club:musician_cello",
            "presentation_id": "musician:jazz_cello",
            "object_type": "character",
            "visual_type": "character",
            "render_key": "jazz_musician_cello",
            "label": "Cello Player",
            "placement_class": "standing_person",
            "exact_slot_id": "fixed.musician_cello",
            "required": True,
            "action_ids": ["service:jazz_cello_round"],
        },
        {
            "object_id": "jazz_club:musician_drummer",
            "presentation_id": "musician:jazz_drummer",
            "object_type": "character",
            "visual_type": "character",
            "render_key": "jazz_musician_drummer",
            "label": "Drummer",
            "placement_class": "standing_person",
            "exact_slot_id": "fixed.musician_drummer",
            "required": True,
            "action_ids": ["service:jazz_drummer_round"],
        },
        {
            "object_id": "jazz_club:band_tip_jar",
            "presentation_id": "service:jazz_band_tip_jar",
            "object_type": "fixture",
            "visual_type": "service",
            "render_key": "jazz_tip_jar",
            "label": "Band Tip Jar",
            "placement_class": "surface_item",
            "exact_slot_id": "fixed.tip_jar_band",
            "required": True,
            "action_ids": ["service:jazz_band_tip_jar"],
        },
        {
            "object_id": "jazz_club:band_stage",
            "presentation_id": "fixture:jazz_band_stage",
            "object_type": "fixture",
            "visual_type": "fixture",
            "render_key": "jazz_band_stage",
            "label": "Jazz Band",
            "placement_class": "ground_marker",
            "exact_slot_id": "fixed.band_stage",
            "required": True,
            "action_ids": ["service:listen_to_jazz"],
        },
    ]


def guaranteed_host_objects() -> dict[str, list[dict[str, Any]]]:
    """Named renderer-only people that are guaranteed room inventory.

    These declarations turn the long-lived backdrop characters into the same
    durable fixed-object manifest used by the Jazz Club band.  Action-bearing
    fixtures remain separate rows; these hosts are physical presentation
    inventory and do not silently absorb unrelated service actions.
    """

    def host(
        object_id: str,
        presentation_id: str,
        render_key: str,
        label: str,
        exact_slot_id: str,
        placement_class: str = "behind_counter_person",
        action_ids: tuple[str, ...] = (),
    ) -> dict[str, Any]:
        return {
            "object_id": object_id,
            "presentation_id": presentation_id,
            "object_type": "character",
            "visual_type": "character",
            "render_key": render_key,
            "label": label,
            "placement_class": placement_class,
            "exact_slot_id": exact_slot_id,
            "required": True,
            "action_ids": list(action_ids),
        }

    return {
        "corner_store": [
            host(
                "corner_store:shopkeeper",
                "shopkeeper:merchant",
                "fixed_host_mara",
                "Mara",
                "fixed.staff_shopkeeper",
                action_ids=("service:cashier_tip",),
            ),
            {
                "object_id": "corner_store:phone",
                "presentation_id": "event:call_brother_in_law",
                "object_type": "fixture",
                "visual_type": "fixture",
                "render_key": "phone",
                "label": "Store Phone",
                "placement_class": "surface_item",
                "exact_slot_id": "fixed.phone",
                "required": True,
                "action_ids": ["event:call_brother_in_law"],
            },
        ],
        "back_alley": [
            host("back_alley:merchant", "shopkeeper:merchant", "fixed_host_back_alley_merchant", "Alley Merchant", "fixed.staff_merchant"),
            host("back_alley:vince", "character:vince", "fixed_host_vince", "Vince", "fixed.patron_vince", "standing_person"),
            host("back_alley:lena", "character:lena", "fixed_host_lena", "Lena", "fixed.patron_lena", "standing_person"),
        ],
        "motel": [
            host("motel:front_desk_clerk", "shopkeeper:merchant", "fixed_host_motel_clerk", "Front Desk Clerk", "fixed.staff_front_desk"),
            host("motel:june", "character:june", "fixed_host_june", "June", "fixed.staff_june"),
            host("motel:marco", "character:marco", "fixed_host_marco", "Marco", "fixed.patron_marco", "standing_person"),
        ],
        "bar": [
            host("bar:bartender", "staff:bar_bartender", "fixed_host_rafi", "Rafi", "fixed.staff_bartender"),
            host("bar:dot", "character:dot", "fixed_host_dot", "Dot", "fixed.patron_dot", "standing_person"),
        ],
        "jazz_club": [
            host("jazz_club:dot", "character:dot", "fixed_host_dot", "Dot", "fixed.patron_dot", "standing_person"),
        ],
        "kitty_cat_lounge": [
            host("kitty_cat_lounge:bar_host", "staff:kitty_bar_host", "fixed_host_iris", "Iris", "fixed.staff_bar"),
            host("kitty_cat_lounge:dot", "character:dot", "fixed_host_dot", "Dot", "fixed.patron_dot", "seated_person"),
        ],
        "gas_station_casino": [
            host(
                "gas_station_casino:nell",
                "character:nell",
                "fixed_host_nell",
                "Nell",
                "fixed.staff_nell",
                action_ids=("event:town_rumor_staff",),
            ),
        ],
        "delta_queen": [
            host("delta_queen:right_table_dealer", "staff:delta_right_table_dealer", "fixed_host_sable", "Sable", "fixed.staff_right_table"),
            host("delta_queen:deck_boss", "staff:delta_deck_boss", "fixed_host_ox", "Ox", "fixed.staff_floor", "standing_person"),
        ],
        "small_underground_casino:club": [
            host("punchline:club_bouncer", "staff:punchline_bouncer", "fixed_host_ox", "Ox", "fixed.staff_floor_right", "standing_person"),
        ],
        "small_underground_casino:casino": [
            host("punchline:casino_dealer", "staff:underground_dealer", "fixed_host_sable", "Sable", "fixed.staff_dealer", "standing_person"),
            host("punchline:casino_bouncer", "character:ox", "fixed_host_ox", "Ox", "fixed.staff_floor_right", "standing_person"),
        ],
        "pawn_shop": [
            host(
                "pawn_shop:sal",
                "staff:pawn_counter_sal",
                "fixed_host_sal",
                "Sal",
                "fixed.staff_pawn_counter",
                action_ids=(
                    "shopkeeper:merchant",
                    "lender:sals_pawn_counter",
                    "meta_pawn_counter:sell",
                    "meta_sal:talk",
                ),
            ),
        ],
        "grand_casino": [
            host(
                "grand_casino:floor_host",
                "staff:grand_casino_host",
                "fixed_host_iris",
                "Iris",
                "fixed.staff_host",
                action_ids=("event:town_rumor_staff",),
            ),
        ],
        "grand_casino_cage": [
            host("grand_casino_cage:linda", "staff:grand_casino_linda", "fixed_host_linda", "Linda", "fixed.staff_linda", "behind_counter_person"),
        ],
    }


def _normalize_guaranteed_host_declarations(
    maps: dict[str, dict[str, Any]],
) -> None:
    """Refresh fixed host/action declarations for legacy or canonical slots."""

    canonical_host_slot_ids = {
        ("delta_queen", "fixed.staff_floor"): "fixed.staff_ox",
        ("small_underground_casino:club", "fixed.staff_floor_right"): "fixed.staff_ox",
        ("small_underground_casino:casino", "fixed.staff_floor_right"): "fixed.staff_ox",
    }
    for map_id, declarations in guaranteed_host_objects().items():
        map_data = maps[map_id]
        existing = {
            str(value.get("object_id", "")): value
            for value in map_data.get("fixed_objects", [])
            if isinstance(value, dict)
        }
        for source_declaration in declarations:
            declaration = copy.deepcopy(source_declaration)
            source_slot_id = str(declaration["exact_slot_id"])
            canonical_slot_id = canonical_host_slot_ids.get(
                (map_id, source_slot_id), source_slot_id
            )
            if _slot_by_id(map_data, canonical_slot_id) is not None:
                declaration["exact_slot_id"] = canonical_slot_id
            object_id = str(declaration["object_id"])
            if object_id in existing:
                existing[object_id].clear()
                existing[object_id].update(declaration)
            else:
                map_data.setdefault("fixed_objects", []).append(declaration)
            presentation_id = str(declaration["presentation_id"])
            exact_slot_id = str(declaration["exact_slot_id"])
            map_data.setdefault("fixed_object_slot_ids", {})[presentation_id] = exact_slot_id
            map_data.setdefault("object_family_ids", {})[presentation_id] = "fixed"

    # The cashier-tip action belongs to the guaranteed shopkeeper. Keep it on
    # Mara rather than projecting a second fixture or attaching it to the phone.
    _assign_object_slot(
        maps["corner_store"],
        "fixed",
        "service:cashier_tip",
        "fixed.staff_shopkeeper",
    )

    # Town rumor dialogue comes from the guaranteed Grand Casino floor host.
    # Keep the conditional action in event_ids, but do not mint a second staff
    # person or reserve event-family counter capacity for it.
    grand = maps["grand_casino"]
    rumor_action_id = "event:town_rumor_staff"
    _remove_object_slot_assignment(grand, rumor_action_id)
    grand.setdefault("object_family_ids", {})[rumor_action_id] = "fixed"


def add_jazz_slots(map_data: dict[str, Any]) -> None:
    fixed_slots = map_data["fixed_slots"]
    by_id = {str(slot.get("id", "")): slot for slot in fixed_slots}

    def take(old_candidates: tuple[str, ...], target: str, footprint: str, pos: tuple[float, float]) -> None:
        source = next((by_id.get(candidate) for candidate in old_candidates if candidate in by_id), None)
        if source is None:
            source = {
                "id": target,
                "kind": "fixed",
                "pos": list(pos),
                "footprint_class": footprint,
                "hit_rect": [pos[0] - 36.0, pos[1] - (80.0 if footprint == "standing_person" else 48.0), 72.0, 80.0 if footprint == "standing_person" else 48.0],
                "label_anchor": [pos[0], pos[1] - (86.0 if footprint == "standing_person" else 54.0)],
                "facing": "none",
                "priority": 10,
                "zone_id": "center",
                "support_id": "stage" if footprint != "behind_counter_person" else "bar",
                "walk_lane_ids": ["lane.public"] if footprint in {"standing_person", "behind_counter_person"} else [],
            }
            fixed_slots.append(source)
        old_id = str(source.get("id", ""))
        source["id"] = target
        source["kind"] = "fixed"
        source["footprint_class"] = footprint
        source["pos"] = [pos[0], pos[1]]
        height = 80.0 if footprint in {"standing_person", "behind_counter_person"} else 48.0
        source["hit_rect"] = [pos[0] - 36.0, pos[1] - height, 72.0, height]
        source["label_anchor"] = [pos[0], pos[1] - height - 6.0]
        if old_id and old_id != target:
            for field_name, preferences in map_data.items():
                if not field_name.endswith("_slot_ids") or not isinstance(preferences, dict):
                    continue
                for preference_key, preference_value in list(preferences.items()):
                    if preference_value == old_id:
                        preferences[preference_key] = target
        by_id.pop(old_id, None)
        by_id[target] = source

    take(("fixed.staff_bartender", "fixed.staff_bar"), "fixed.staff_bartender", "behind_counter_person", (742.0, 192.0))
    take(("fixed.musician_sax", "fixed.service_band_rail"), "fixed.musician_sax", "standing_person", (330.0, 236.0))
    take(("fixed.musician_cello",), "fixed.musician_cello", "standing_person", (430.0, 236.0))
    take(("fixed.musician_drummer", "fixed.service_stage"), "fixed.musician_drummer", "standing_person", (530.0, 236.0))
    take(("fixed.tip_jar_band",), "fixed.tip_jar_band", "surface_item", (620.0, 270.0))
    take(("fixed.band_stage", "fixed.event_listen_marker"), "fixed.band_stage", "ground_marker", (450.0, 354.0))

    fixed_map = map_data["fixed_object_slot_ids"]
    for action_id in (
        "service:house_drink",
        "service:jazz_sax_round",
        "service:jazz_cello_round",
        "service:jazz_drummer_round",
        "service:jazz_band_tip_jar",
        "service:listen_to_jazz",
        "event:town_rumor_staff",
    ):
        for family in FAMILIES:
            map_data.get(f"{family}_object_slot_ids", {}).pop(action_id, None)
    fixed_map["shopkeeper:merchant"] = "fixed.staff_bartender"

    object_families = map_data["object_family_ids"]
    for action_id in (
        "service:house_drink",
        "service:jazz_sax_round",
        "service:jazz_cello_round",
        "service:jazz_drummer_round",
        "service:jazz_band_tip_jar",
        "service:listen_to_jazz",
        "event:town_rumor_staff",
    ):
        object_families[action_id] = "fixed"
    object_families["shopkeeper:merchant"] = "fixed"
    map_data["fixed_objects"] = jazz_fixed_objects()


def _slot_by_id(map_data: dict[str, Any], slot_id: str) -> dict[str, Any] | None:
    for family in FAMILIES:
        for slot in map_data.get(f"{family}_slots", []):
            if isinstance(slot, dict) and str(slot.get("id", "")) == slot_id:
                return slot
    return None


def _move_slot_geometry(slot: dict[str, Any], dx: float, dy: float) -> None:
    for field in ("pos", "label_anchor"):
        values = slot.get(field)
        if isinstance(values, list) and len(values) >= 2:
            values[0] = max(0.0, min(900.0, float(values[0]) + dx))
            values[1] = max(0.0, min(430.0, float(values[1]) + dy))
    rect = slot.get("hit_rect")
    if isinstance(rect, list) and len(rect) >= 4:
        rect[0] = max(0.0, min(900.0 - float(rect[2]), float(rect[0]) + dx))
        rect[1] = max(0.0, min(430.0 - float(rect[3]), float(rect[1]) + dy))


def _slot_rect(slot: dict[str, Any]) -> tuple[float, float, float, float] | None:
    rect = slot.get("hit_rect")
    if not isinstance(rect, list) or len(rect) < 4:
        return None
    values = tuple(float(value) for value in rect[:4])
    if values[2] <= 0.0 or values[3] <= 0.0:
        return None
    return values


def _rects_overlap(
    left: tuple[float, float, float, float],
    right: tuple[float, float, float, float],
) -> bool:
    left_x, left_y, left_w, left_h = left
    right_x, right_y, right_w, right_h = right
    return (
        left_x < right_x + right_w
        and left_x + left_w > right_x
        and left_y < right_y + right_h
        and left_y + left_h > right_y
    )


def _rects_overlap_with_gap(
    left: tuple[float, float, float, float],
    right: tuple[float, float, float, float],
    gap: float = 8.0,
) -> bool:
    """Match the runtime layout contract's padding on both rectangles."""

    left_x, left_y, left_w, left_h = left
    right_x, right_y, right_w, right_h = right
    return _rects_overlap(
        (left_x - gap, left_y - gap, left_w + gap * 2.0, left_h + gap * 2.0),
        (right_x - gap, right_y - gap, right_w + gap * 2.0, right_h + gap * 2.0),
    )


def _move_slot_to(slot: dict[str, Any], pos: tuple[float, float]) -> None:
    """Move authored geometry to an absolute position without cumulative drift."""

    current = slot.get("pos")
    if not isinstance(current, list) or len(current) < 2:
        raise ValueError(f"slot {slot.get('id', '<unknown>')} lacks authored position")
    _move_slot_geometry(
        slot,
        float(pos[0]) - float(current[0]),
        float(pos[1]) - float(current[1]),
    )


def _move_slot_clear_of_fixed_geometry(
    map_data: dict[str, Any],
    target: dict[str, Any],
    retained_capacity_ids: tuple[str, ...] = (),
) -> None:
    """Move a provisional slot minimally so simultaneous capacity is distinct."""

    target_rect = _slot_rect(target)
    if target_rect is None:
        raise ValueError(f"{map_data.get('id', '<unknown>')}: provisional slot lacks hit geometry")
    target_id = str(target.get("id", ""))
    obstacle_slots = [
        slot
        for slot in map_data.get("fixed_slots", [])
        if isinstance(slot, dict) and str(slot.get("id", "")) != target_id
    ]
    for retained_id in retained_capacity_ids:
        retained = _slot_by_id(map_data, retained_id)
        if retained is None:
            raise ValueError(
                f"{map_data.get('id', '<unknown>')}: retained capacity {retained_id} is missing"
            )
        if retained not in obstacle_slots:
            obstacle_slots.append(retained)
    obstacles = [rect for slot in obstacle_slots if (rect := _slot_rect(slot)) is not None]
    if not any(_rects_overlap(target_rect, obstacle) for obstacle in obstacles):
        return

    source_x, source_y, width, height = target_rect
    gap = 8.0
    candidate_x = {source_x, 0.0, 900.0 - width}
    candidate_y = {source_y, 0.0, 430.0 - height}
    for obstacle_x, obstacle_y, obstacle_w, obstacle_h in obstacles:
        candidate_x.add(max(0.0, min(900.0 - width, obstacle_x - width - gap)))
        candidate_x.add(max(0.0, min(900.0 - width, obstacle_x + obstacle_w + gap)))
        candidate_y.add(max(0.0, min(430.0 - height, obstacle_y - height - gap)))
        candidate_y.add(max(0.0, min(430.0 - height, obstacle_y + obstacle_h + gap)))

    candidates: list[tuple[float, float, float, float, float]] = []
    for x in candidate_x:
        for y in candidate_y:
            candidate = (x, y, width, height)
            if any(_rects_overlap(candidate, obstacle) for obstacle in obstacles):
                continue
            dx = x - source_x
            dy = y - source_y
            candidates.append((dx * dx + dy * dy, abs(dy), abs(dx), x, y))
    if not candidates:
        raise ValueError(
            f"{map_data.get('id', '<unknown>')}: no non-overlapping fixed geometry remains for {target_id}"
        )
    _, _, _, chosen_x, chosen_y = min(candidates)
    _move_slot_geometry(target, chosen_x - source_x, chosen_y - source_y)


def _ensure_provisional_slot(
    map_data: dict[str, Any],
    family: str,
    slot_id: str,
    footprint_class: str,
    source_ids: tuple[str, ...],
    offset: tuple[float, float] = (0.0, 0.0),
    avoid_fixed_overlap: bool = False,
    retained_capacity_ids: tuple[str, ...] = (),
) -> None:
    """Add one deterministic family-local capacity slot without inventing geometry."""

    target = _slot_by_id(map_data, slot_id)
    if target is not None:
        target["kind"] = family
        target["footprint_class"] = footprint_class
        if avoid_fixed_overlap:
            _move_slot_clear_of_fixed_geometry(map_data, target, retained_capacity_ids)
        return
    source = None
    for source_id in source_ids:
        source = _slot_by_id(map_data, source_id)
        if source is not None:
            break
    if source is None:
        raise ValueError(f"{map_data.get('id', '<unknown>')}: cannot provision {slot_id}; no source geometry")
    target = copy.deepcopy(source)
    # A newly provisioned capacity row borrows geometry but is not the same
    # authored row for current-v2 disposition/import purposes.  Keep the
    # legacy-origin evidence (which explicitly tracks geometry ancestry), but
    # mark this row as introduced in the consolidation ledger.
    target.pop(CONSOLIDATION_ORIGIN_FIELD, None)
    target["id"] = slot_id
    target["kind"] = family
    target["footprint_class"] = footprint_class
    _move_slot_geometry(target, float(offset[0]), float(offset[1]))
    map_data.setdefault(f"{family}_slots", []).append(target)
    if avoid_fixed_overlap:
        _move_slot_clear_of_fixed_geometry(map_data, target, retained_capacity_ids)


def _assign_object_slot(map_data: dict[str, Any], family: str, object_id: str, slot_id: str) -> None:
    for other_family in FAMILIES:
        preferences = map_data.setdefault(f"{other_family}_object_slot_ids", {})
        if isinstance(preferences, dict):
            preferences.pop(object_id, None)
    map_data.setdefault(f"{family}_object_slot_ids", {})[object_id] = slot_id
    map_data.setdefault("object_family_ids", {})[object_id] = family


def _remove_object_slot_assignment(map_data: dict[str, Any], object_id: str) -> None:
    """Remove identity-local physical authority while retaining generic capacity."""

    for family in FAMILIES:
        preferences = map_data.setdefault(f"{family}_object_slot_ids", {})
        if isinstance(preferences, dict):
            preferences.pop(object_id, None)
    families = map_data.setdefault("object_family_ids", {})
    if isinstance(families, dict):
        families.pop(object_id, None)


def _remap_exit_preferences(
    map_data: dict[str, Any], source_slot_id: str, target_slot_id: str
) -> None:
    """Move every alias that owns one physical exit target as a unit."""

    object_preferences = map_data.setdefault("exit_object_slot_ids", {})
    if isinstance(object_preferences, dict):
        for object_id, slot_id in list(object_preferences.items()):
            if str(slot_id) == source_slot_id:
                _assign_object_slot(map_data, "exit", str(object_id), target_slot_id)
    category_preferences = map_data.setdefault("exit_category_slot_ids", {})
    if isinstance(category_preferences, dict):
        for category_id, slot_id in list(category_preferences.items()):
            if str(slot_id) == source_slot_id:
                category_preferences[str(category_id)] = target_slot_id


def _relocate_slot(
    map_data: dict[str, Any],
    source_slot_id: str,
    family: str,
    target_slot_id: str,
    footprint_class: str,
) -> dict[str, Any]:
    """Move one authored capacity row between families without losing geometry."""

    slot = _slot_by_id(map_data, source_slot_id)
    if slot is None:
        slot = _slot_by_id(map_data, target_slot_id)
    if slot is None:
        raise ValueError(
            f"{map_data.get('id', '<unknown>')}: cannot relocate missing slot {source_slot_id}"
        )
    for slot_family in FAMILIES:
        map_data[f"{slot_family}_slots"] = [
            value
            for value in map_data.get(f"{slot_family}_slots", [])
            if value is not slot
            and (
                not isinstance(value, dict)
                or str(value.get("id", "")) not in {source_slot_id, target_slot_id}
            )
        ]
    slot["id"] = target_slot_id
    slot["kind"] = family
    slot["footprint_class"] = footprint_class
    map_data.setdefault(f"{family}_slots", []).append(slot)
    return slot


def _move_category_preference(
    map_data: dict[str, Any], family: str, category_key: str, slot_id: str
) -> None:
    for other_family in FAMILIES:
        preferences = map_data.setdefault(f"{other_family}_category_slot_ids", {})
        if isinstance(preferences, dict):
            preferences.pop(category_key, None)
    map_data.setdefault(f"{family}_category_slot_ids", {})[category_key] = slot_id


def _set_person_slot_geometry(
    slot: dict[str, Any],
    pos: tuple[float, float],
    footprint_class: str,
    support_id: str,
    width: float = 72.0,
    height: float = 80.0,
) -> None:
    slot["pos"] = [float(pos[0]), float(pos[1])]
    slot["hit_rect"] = [float(pos[0]) - width / 2.0, float(pos[1]) - height, width, height]
    slot["label_anchor"] = [float(pos[0]), float(pos[1]) - height - 6.0]
    slot["footprint_class"] = footprint_class
    slot["support_id"] = support_id


def _retarget_scenario_preferences(
    map_data: dict[str, Any], stable_object_id: str, slot_id: str
) -> None:
    """Retarget every authored pose for one stable scenario object."""

    preferences = map_data.setdefault("scenario_slot_ids", {})
    if not isinstance(preferences, dict):
        raise ValueError(
            f"{map_data.get('id', '<unknown>')}: scenario_slot_ids must be an object"
        )
    matching_keys = [
        str(identity)
        for identity in preferences
        if str(identity).split("|", 1)[0] == stable_object_id
    ]
    if not matching_keys:
        raise ValueError(
            f"{map_data.get('id', '<unknown>')}: no scenario preferences match {stable_object_id}"
        )
    for identity in matching_keys:
        preferences[identity] = slot_id


def _normalize_multiseed_capacity_and_conflicts(
    maps: dict[str, dict[str, Any]],
) -> None:
    """Repair capacity/classification defects exposed by the full scenario sweep."""

    # Fence Night keeps its scenario furniture live while one of three
    # aftermath controls is added. Both are floor fixtures and therefore need
    # independent generic scenario capacity.
    back_alley = maps["back_alley"]
    _ensure_provisional_slot(
        back_alley,
        "scenario",
        "scenario.floor_item_2",
        "floor_fixture",
        ("scenario.floor_item_1",),
    )
    back_alley_floor_item_2 = _slot_by_id(back_alley, "scenario.floor_item_2")
    if back_alley_floor_item_2 is None:
        raise ValueError("back_alley: second scenario floor-fixture capacity is missing")
    _set_person_slot_geometry(
        back_alley_floor_item_2,
        (696.0, 286.0),
        "floor_fixture",
        "floor",
        92.0,
        64.0,
    )

    # Runtime merchandise is always classified as shop_item and consumes the
    # numbered fixed.item_shop_N row. These two stale legacy overrides forced
    # ordinary item offers into classes their shops intentionally do not own.
    for map_data in maps.values():
        class_overrides = map_data.setdefault("class_overrides", {})
        if not isinstance(class_overrides, dict):
            raise ValueError(
                f"{map_data.get('id', '<unknown>')}: class_overrides must be an object"
            )
        for object_id in list(class_overrides):
            if str(object_id).startswith("item:") and str(class_overrides[object_id]) != "shop_item":
                class_overrides.pop(object_id, None)

    # Keep the reviewed provisional room free of known scenario/ambient hit
    # conflicts. The targets remain generic, reusable scenario slots.
    _retarget_scenario_preferences(
        maps["bar"],
        "bar_darts_league_night_darts_scorer",
        "scenario.floor_patron_5",
    )
    _retarget_scenario_preferences(
        maps["kitty_cat_lounge"],
        "kitty_cat_lounge_amateur_night_amateur_signup",
        "scenario.surface_item_1",
    )
    _retarget_scenario_preferences(
        maps["gas_station_casino"],
        "gas_station_trucker_convoy_lead_driver",
        "scenario.floor_patron_5",
    )


def _normalize_conditional_people(maps: dict[str, dict[str, Any]]) -> None:
    """Keep optional Silas/scalper actors out of fixed baseline inventory."""

    silas_sources = {
        "motel": ("fixed.door_left_middle", "event.floor_patron_1"),
        "bar": ("fixed.travel_right", "event.floor_patron_2"),
        "small_underground_casino": ("fixed.staff_silas", "event.floor_patron_2"),
        "small_underground_casino:casino": ("fixed.staff_silas", "event.floor_patron_1"),
        "small_underground_casino:back_room": ("fixed.staff_numbers", "event.floor_patron_1"),
        "jazz_club": ("fixed.staff_silas", "event.floor_patron_1"),
        "kitty_cat_lounge": ("fixed.door_right_middle", "event.floor_patron_1"),
    }
    for map_id, (source_slot_id, event_slot_id) in silas_sources.items():
        map_data = maps[map_id]
        _relocate_slot(map_data, source_slot_id, "event", event_slot_id, "standing_person")
        _assign_object_slot(map_data, "event", "numbers:silas", event_slot_id)
        _move_category_preference(
            map_data,
            "event",
            "numbers_silas_spots:0",
            event_slot_id,
        )

    back_room_slot = _slot_by_id(
        maps["small_underground_casino:back_room"], "event.floor_patron_1"
    )
    if back_room_slot is None:
        raise ValueError("Punchline back room lost Silas event capacity")
    back_room_slot["footprint_class"] = "standing_person"

    gas_station = maps["gas_station_casino"]
    scalper_slot = _relocate_slot(
        gas_station,
        "fixed.patron_scalper",
        "event",
        "event.floor_patron_1",
        "standing_person",
    )
    # This is deliberately the original hand-authored scalper geometry.
    scalper_slot["support_id"] = str(scalper_slot.get("support_id", "stage"))
    _assign_object_slot(
        gas_station,
        "event",
        "dialogue:scratch_ticket_scalper",
        "event.floor_patron_1",
    )

    # Silas' Town itinerary can place him at the Punchline while the club layer
    # is active. The old category alias pointed at Ox's guaranteed fixed slot.
    club = maps["small_underground_casino:club"]
    _ensure_provisional_slot(
        club,
        "event",
        "event.floor_patron_1",
        "standing_person",
        ("fixed.staff_floor_right", "scenario.floor_patron_1"),
        (-120.0, 0.0),
    )
    _assign_object_slot(club, "event", "numbers:silas", "event.floor_patron_1")
    _move_category_preference(
        club,
        "event",
        "numbers_silas_spots:0",
        "event.floor_patron_1",
    )


def _normalize_numbers_book_capacity(maps: dict[str, dict[str, Any]]) -> None:
    """Give authority-gated Numbers books a dedicated fixed surface slot."""

    relocations = {
        "motel": "fixed.door_curtain",
        "small_underground_casino": "fixed.numbers_stage_center",
        "small_underground_casino:club": "fixed.numbers_right_table",
        "small_underground_casino:casino": "fixed.numbers_right_table",
    }
    for map_id, source_slot_id in relocations.items():
        map_data = maps[map_id]
        if _slot_by_id(map_data, "fixed.numbers_book") is None:
            _relocate_slot(
                map_data,
                source_slot_id,
                "fixed",
                "fixed.numbers_book",
                "surface_item",
            )

    corner = maps["corner_store"]
    _ensure_provisional_slot(
        corner,
        "fixed",
        "fixed.numbers_book",
        "surface_item",
        ("fixed.phone",),
        (120.0, 0.0),
    )

    for map_id in (
        "corner_store",
        "motel",
        "bar",
        "gas_station_casino",
        "small_underground_casino",
        "small_underground_casino:club",
        "small_underground_casino:casino",
    ):
        map_data = maps[map_id]
        _assign_object_slot(map_data, "fixed", "numbers:book", "fixed.numbers_book")
        _move_category_preference(
            map_data,
            "fixed",
            "numbers_spots:0",
            "fixed.numbers_book",
        )


def _normalize_home_storage_capacity(maps: dict[str, dict[str, Any]]) -> None:
    """Separate the home storage control from the first physical container."""

    positions = {
        "motel_room": (830.0, 358.0),
        "apartment": (820.0, 358.0),
        "house": (570.0, 358.0),
    }
    for map_id, pos in positions.items():
        map_data = maps[map_id]
        _ensure_provisional_slot(
            map_data,
            "fixed",
            "fixed.home_storage",
            "floor_fixture",
            ("fixed.home_container_1",),
        )
        slot = _slot_by_id(map_data, "fixed.home_storage")
        if slot is None:
            raise ValueError(f"{map_id}: home storage capacity is missing")
        _set_person_slot_geometry(
            slot,
            pos,
            "floor_fixture",
            "floor",
            92.0,
            64.0,
        )
        _assign_object_slot(map_data, "fixed", "home_storage:place", "fixed.home_storage")
        _move_category_preference(
            map_data,
            "fixed",
            "home_storage_spots:0",
            "fixed.home_storage",
        )
        # The legacy home storage control and the primary travel door share the
        # lower-right corner in the motel and apartment layouts.  Both rooms
        # already author a distinct left-hand exit, so keep storage where it is
        # and give travel its own exit-family target.
        if map_id in {"motel_room", "apartment"}:
            _assign_object_slot(map_data, "exit", "travel:leave", "exit.left_door")


def _normalize_required_fixed_events(maps: dict[str, dict[str, Any]]) -> None:
    """Promote always-selected archetype events out of scenario lifecycle."""

    grand = maps["grand_casino"]
    _ensure_provisional_slot(
        grand,
        "fixed",
        "fixed.event_audit_roster",
        "wall_mounted",
        ("scenario.wall_item_1",),
        (120.0, 0.0),
    )
    _assign_object_slot(
        grand,
        "fixed",
        "event:scenario_audit_roster",
        "fixed.event_audit_roster",
    )
    declaration = {
        "object_id": "grand_casino:audit_roster",
        "presentation_id": "event:scenario_audit_roster",
        "object_type": "event",
        "visual_type": "event",
        "render_key": "event",
        "label": "Audit Roster",
        "placement_class": "wall_mounted",
        "exact_slot_id": "fixed.event_audit_roster",
        "required": True,
        "action_ids": ["event:scenario_audit_roster"],
    }
    existing = next(
        (
            value
            for value in grand.setdefault("fixed_objects", [])
            if isinstance(value, dict)
            and str(value.get("object_id", "")) == declaration["object_id"]
        ),
        None,
    )
    if existing is None:
        grand["fixed_objects"].append(declaration)
    else:
        existing.clear()
        existing.update(declaration)


def _normalize_guaranteed_hosts(maps: dict[str, dict[str, Any]]) -> None:
    """Provision exact fixed slots and declarations for guaranteed room hosts."""

    named_people = {
        "motel": [
            ("fixed.staff_june", "behind_counter_person", ("scenario.counter_patron_1",), (558.0, 180.0), "lobby_table", 72.0, 72.0),
            ("fixed.patron_marco", "standing_person", ("fixed.patron_floor_right",), (716.0, 326.0), "floor", 72.0, 80.0),
        ],
        "back_alley": [
            ("fixed.patron_vince", "standing_person", ("scenario.floor_patron_2",), (388.0, 358.0), "floor", 72.0, 80.0),
            ("fixed.patron_lena", "standing_person", ("scenario.floor_patron_1",), (500.0, 358.0), "floor", 72.0, 80.0),
        ],
        "bar": [
            ("fixed.patron_dot", "standing_person", ("scenario.floor_patron_1",), (508.0, 376.0), "floor", 72.0, 80.0),
        ],
        "jazz_club": [
            ("fixed.patron_dot", "standing_person", ("scenario.floor_patron_2",), (364.0, 326.0), "floor", 72.0, 80.0),
        ],
        "kitty_cat_lounge": [
            ("fixed.patron_dot", "seated_person", ("event.seated_patron_1", "scenario.seated_patron_1"), (250.0, 234.0), "stage_mid", 68.0, 64.0),
        ],
        "gas_station_casino": [
            ("fixed.staff_nell", "behind_counter_person", ("scenario.counter_patron_1",), (600.0, 84.0), "staff_window", 72.0, 72.0),
        ],
        "small_underground_casino:casino": [
            ("fixed.staff_floor_right", "standing_person", ("scenario.floor_patron_1",), (628.0, 358.0), "floor", 72.0, 80.0),
        ],
    }
    for map_id, slots in named_people.items():
        map_data = maps[map_id]
        for slot_id, footprint, source_ids, pos, support_id, width, height in slots:
            _ensure_provisional_slot(map_data, "fixed", slot_id, footprint, source_ids)
            slot = _slot_by_id(map_data, slot_id)
            if slot is None:
                raise ValueError(f"{map_id}: fixed named-person capacity is missing {slot_id}")
            _set_person_slot_geometry(slot, pos, footprint, support_id, width, height)

    bar = maps["bar"]
    _ensure_provisional_slot(
        bar,
        "fixed",
        "fixed.staff_bartender",
        "behind_counter_person",
        ("event.counter_patron_1",),
    )
    bartender_slot = _slot_by_id(bar, "fixed.staff_bartender")
    if bartender_slot is None:
        raise ValueError("bar: fixed bartender capacity is missing")
    _set_person_slot_geometry(
        bartender_slot,
        (430.0, 218.0),
        "behind_counter_person",
        "bar_counter",
        72.0,
        72.0,
    )
    event_counter = _slot_by_id(bar, "event.counter_patron_1")
    if event_counter is None:
        raise ValueError("bar: event counter patron capacity is missing")
    _set_person_slot_geometry(
        event_counter,
        (310.0, 218.0),
        "behind_counter_person",
        "bar_counter",
        72.0,
        72.0,
    )

    delta = maps["delta_queen"]
    delta_floor = _slot_by_id(delta, "fixed.staff_floor")
    if delta_floor is None:
        _ensure_provisional_slot(
            delta,
            "fixed",
            "fixed.staff_floor",
            "standing_person",
            ("scenario.floor_patron_2", "event.floor_patron_1"),
        )
        delta_floor = _slot_by_id(delta, "fixed.staff_floor")
    if delta_floor is None:
        raise ValueError("delta_queen: fixed deck-boss capacity is missing")
    _set_person_slot_geometry(
        delta_floor,
        (496.0, 358.0),
        "standing_person",
        "floor",
    )

    grand = maps["grand_casino"]
    _ensure_provisional_slot(
        grand,
        "fixed",
        "fixed.staff_host",
        "behind_counter_person",
        ("event.counter_patron_1",),
    )
    grand_host = _slot_by_id(grand, "fixed.staff_host")
    if grand_host is None:
        raise ValueError("grand_casino: fixed host capacity is missing")
    _set_person_slot_geometry(
        grand_host,
        (450.0, 350.0),
        "behind_counter_person",
        "host_desk",
        44.0,
        72.0,
    )

    cage = maps["grand_casino_cage"]
    _ensure_provisional_slot(
        cage,
        "fixed",
        "fixed.staff_linda",
        "behind_counter_person",
        ("fixed.fixture_cage_1", "scenario.floor_patron_1"),
    )
    linda_slot = _slot_by_id(cage, "fixed.staff_linda")
    if linda_slot is None:
        raise ValueError("grand_casino_cage: fixed Linda capacity is missing")
    _set_person_slot_geometry(
        linda_slot,
        (500.0, 316.0),
        "behind_counter_person",
        "teller_counter",
        72.0,
        80.0,
    )

    _normalize_guaranteed_host_declarations(maps)


def _normalize_mixed_family_spacing(maps: dict[str, dict[str, Any]]) -> None:
    """Keep simultaneously active fixed/event objects outside the UI safety gap."""

    grand = maps["grand_casino"]
    host_desk = _slot_by_id(grand, "fixed.fixture_host_desk")
    house_calls = _slot_by_id(grand, "event.counter_patron_1")
    if host_desk is None or house_calls is None:
        raise ValueError("grand_casino: host-desk spacing capacity is incomplete")
    # Preserve the host's named fixed slot and move its two neighboring props
    # just enough to satisfy the runtime's eight-pixel padding on both sides.
    _move_slot_to(host_desk, (388.0, 366.0))
    _set_person_slot_geometry(
        house_calls,
        (512.0, 354.0),
        "behind_counter_person",
        "cocktail_service",
        44.0,
        72.0,
    )

    kitty = maps["kitty_cat_lounge"]
    rowdy_seat = _slot_by_id(kitty, "event.seated_patron_1")
    bar_dice = _slot_by_id(kitty, "fixed.random_game_2")
    champagne = _slot_by_id(kitty, "fixed.service_kitty_champagne")
    if rowdy_seat is None or bar_dice is None or champagne is None:
        raise ValueError("kitty_cat_lounge: mixed-family spacing capacity is incomplete")
    # Dot owns the middle stage seat every visit; the optional Rowdy Regular
    # therefore uses the distinct authored right seat.
    _set_person_slot_geometry(
        rowdy_seat,
        (358.0, 234.0),
        "seated_person",
        "stage_right",
        68.0,
        64.0,
    )
    # Bar Dice, merchandise, and champagne can all be live in the same room.
    # Stagger the two bar objects vertically while retaining their exact fixed
    # identities; final art placement remains editable in placement mode.
    _move_slot_to(bar_dice, (620.0, 174.0))
    bar_dice["support_id"] = "champagne_bar"
    bar_dice["zone_id"] = "right"
    _move_slot_to(champagne, (620.0, 242.0))
    champagne["support_id"] = "champagne_bar"
    champagne["zone_id"] = "right"

    back_alley = maps["back_alley"]
    back_alley_slots = {
        slot_id: _slot_by_id(back_alley, slot_id)
        for slot_id in (
            "fixed.staff_merchant",
            "fixed.patron_vince",
            "fixed.service_house_drink",
            "fixed.event_wall_notice",
            "event.counter_patron_1",
            "scenario.item_shop_1",
            "scenario.item_shop_2",
            "scenario.surface_item_1",
            "scenario.surface_item_2",
            "scenario.floor_marker_1",
            "scenario.floor_item_1",
            "scenario.floor_patron_1",
            "scenario.floor_patron_2",
            "scenario.wall_item_1",
        )
    }
    missing_back_alley = [
        slot_id for slot_id, slot in back_alley_slots.items() if slot is None
    ]
    if missing_back_alley:
        raise ValueError(
            "back_alley: mixed-family spacing capacity is incomplete: "
            + ", ".join(missing_back_alley)
        )

    # The merchant and optional counter actor use the front of the right-hand
    # crate.  Moving them down within that authored counter frees its top for
    # two scenario props without changing either actor's semantic support.
    _set_person_slot_geometry(
        back_alley_slots["fixed.staff_merchant"],
        (810.0, 208.0),
        "behind_counter_person",
        "right_crate_display",
        72.0,
        72.0,
    )
    _set_person_slot_geometry(
        back_alley_slots["event.counter_patron_1"],
        (690.0, 208.0),
        "behind_counter_person",
        "right_crate_display",
        72.0,
        72.0,
    )

    # Four scenario surface/item capacities and the guaranteed drink must all
    # coexist with the ordinary four-item shop row.  Spread them across the two
    # crate tops and the open end of the folding table.
    for slot_id, pos, support_id in (
        ("fixed.service_house_drink", (180.0, 88.0), "left_crate_upper"),
        ("scenario.item_shop_1", (92.0, 88.0), "left_crate_upper"),
        ("scenario.item_shop_2", (680.0, 88.0), "right_crate_upper"),
        ("scenario.surface_item_1", (570.0, 112.0), "folding_table_upper"),
        ("scenario.surface_item_2", (804.0, 88.0), "right_crate_upper"),
    ):
        slot = back_alley_slots[slot_id]
        _move_slot_to(slot, pos)
        slot["support_id"] = support_id

    # Guaranteed Vince and Lena occupy the lower floor row.  Scenario actors
    # use a higher provisional row, with the marker centered between them.
    # Nudge Vince below that row so the renderer's padded person footprints
    # remain distinct when Street Craps is active.
    _move_slot_to(back_alley_slots["fixed.patron_vince"], (388.0, 370.0))
    _set_person_slot_geometry(
        back_alley_slots["scenario.floor_patron_1"],
        (250.0, 260.0),
        "standing_person",
        "floor",
        72.0,
        80.0,
    )
    _set_person_slot_geometry(
        back_alley_slots["scenario.floor_patron_2"],
        (570.0, 260.0),
        "standing_person",
        "floor",
        72.0,
        80.0,
    )
    marker = back_alley_slots["scenario.floor_marker_1"]
    _move_slot_to(marker, (450.0, 260.0))
    marker["support_id"] = "floor"

    # Street Craps and the optional alley offer may coexist.  Preserve their
    # authored lower-floor row while retaining the runtime's safety padding.
    _move_slot_to(back_alley_slots["scenario.floor_item_1"], (736.0, 358.0))

    # Keep the two wall controls distinct from the table and scenario actors.
    _move_slot_to(back_alley_slots["fixed.event_wall_notice"], (150.0, 210.0))
    _move_slot_to(back_alley_slots["scenario.wall_item_1"], (150.0, 140.0))

    # The street lender owns the left stage position.  The authored right-hand
    # doorway is otherwise unused and is the correct independent travel target.
    _assign_object_slot(back_alley, "exit", "travel:leave", "exit.right_upper")


def _normalize_exit_spacing(maps: dict[str, dict[str, Any]]) -> None:
    """Keep live navigation controls clear of independent room objects."""

    for map_id, source_slot_id, target_slot_id in (
        ("beach", "exit.door_right_lower", "exit.right_upper"),
        ("pawn_shop", "exit.door_left_lower", "exit.door_right_lower"),
        ("corner_store", "exit.travel_left", "exit.safe_right"),
        ("gas_station_casino", "exit.door_left_middle", "exit.left_upper"),
        ("kitty_cat_lounge", "exit.door_right_middle", "exit.left_lower"),
    ):
        _remap_exit_preferences(maps[map_id], source_slot_id, target_slot_id)

    punchline = maps["small_underground_casino"]
    _remap_exit_preferences(punchline, "exit.door_right_upper", "exit.left_upper")
    _remap_exit_preferences(punchline, "exit.door_right_lower", "exit.left_lower")
    rook_ride_door = _slot_by_id(punchline, "event.doorway_1")
    if rook_ride_door is None:
        raise ValueError("small_underground_casino: crew ride doorway is missing")
    # The fixed side-door event, Rook's ride, and Leave are independent live
    # objects.  Put Rook at the otherwise unused upper side-door aperture while
    # the two navigation controls use the authored left exits.
    _move_slot_to(rook_ride_door, (846.0, 168.0))
    rook_ride_door["support_id"] = "side_door"
    rook_ride_door["zone_id"] = "right"

    club = maps["small_underground_casino:club"]
    _remap_exit_preferences(club, "exit.door_right_lower", "exit.left_lower")
    club_side_door = _slot_by_id(club, "exit.door_side")
    if club_side_door is None:
        raise ValueError("small_underground_casino:club: side-door exit is missing")
    _move_slot_to(club_side_door, (36.0, 118.0))
    club_side_door["support_id"] = "left_exit"
    club_side_door["zone_id"] = "left"

    casino = maps["small_underground_casino:casino"]
    _remap_exit_preferences(casino, "exit.left_upper", "exit.guarded_upper")


def _normalize_direct_interaction_spacing(maps: dict[str, dict[str, Any]]) -> None:
    """Separate independently actionable controls found by the full contract run."""

    motel = maps["motel"]
    motel_phone = _slot_by_id(motel, "fixed.item_counter_phone")
    motel_safe_exit = _slot_by_id(motel, "scenario.doorway_3")
    bar_rowdy = _slot_by_id(maps["bar"], "event.floor_patron_1")
    kitty_side_door = _slot_by_id(maps["kitty_cat_lounge"], "event.doorway_1")
    delta_side_door = _slot_by_id(maps["delta_queen"], "event.doorway_1")
    grand_drink = _slot_by_id(maps["grand_casino"], "fixed.service_house_drink")
    linda = _slot_by_id(maps["grand_casino_cage"], "fixed.staff_linda")
    required = {
        "motel counter phone": motel_phone,
        "motel scenario safe exit": motel_safe_exit,
        "bar rowdy regular": bar_rowdy,
        "Kitty side door": kitty_side_door,
        "Delta side door": delta_side_door,
        "Grand house drink": grand_drink,
        "Grand cage Linda": linda,
    }
    missing = [label for label, slot in required.items() if slot is None]
    if missing:
        raise ValueError("direct-interaction spacing capacity is incomplete: " + ", ".join(missing))

    _move_slot_to(motel_phone, (566.0, 286.0))
    _set_person_slot_geometry(
        motel_safe_exit,
        (40.0, 128.0),
        "doorway",
        "left_door",
        64.0,
        72.0,
    )
    _set_person_slot_geometry(
        bar_rowdy,
        (102.0, 414.0),
        "standing_person",
        "floor",
        64.0,
        82.0,
    )
    _move_slot_to(kitty_side_door, (859.0, 300.0))
    _move_slot_to(delta_side_door, (32.0, 238.0))
    _move_slot_to(grand_drink, (810.0, 222.0))
    _set_person_slot_geometry(
        linda,
        (500.0, 340.0),
        "behind_counter_person",
        "teller_counter",
    )


def _normalize_guaranteed_host_spacing(maps: dict[str, dict[str, Any]]) -> None:
    """Separate scenario capacity cloned from newly guaranteed fixed hosts."""

    motel_counter = _slot_by_id(maps["motel"], "scenario.counter_patron_1")
    gas_counter = _slot_by_id(
        maps["gas_station_casino"], "scenario.counter_patron_1"
    )
    apartment_item = _slot_by_id(maps["apartment"], "scenario.floor_item_1")
    apartment_patron = _slot_by_id(maps["apartment"], "scenario.floor_patron_1")
    club_ambient = _slot_by_id(
        maps["small_underground_casino:club"], "fixed.ambient_stage"
    )
    casino_patron = _slot_by_id(
        maps["small_underground_casino:casino"], "scenario.floor_patron_1"
    )
    back_room_patron = _slot_by_id(
        maps["small_underground_casino:back_room"], "scenario.floor_patron_1"
    )
    required = {
        "motel scenario counter": motel_counter,
        "gas-station scenario counter": gas_counter,
        "apartment scenario item": apartment_item,
        "apartment scenario patron": apartment_patron,
        "club ambient stage": club_ambient,
        "casino scenario patron": casino_patron,
        "back-room scenario patron": back_room_patron,
    }
    missing = [name for name, slot in required.items() if slot is None]
    if missing:
        raise ValueError(
            "guaranteed-host spacing capacity is incomplete: " + ", ".join(missing)
        )

    _set_person_slot_geometry(
        motel_counter,
        (434.0, 236.0),
        "behind_counter_person",
        "reception_annex",
        72.0,
        72.0,
    )
    motel_counter["facing"] = "left"
    _set_person_slot_geometry(
        gas_counter,
        (724.0, 84.0),
        "behind_counter_person",
        "pull_tab_window",
        72.0,
        72.0,
    )

    _set_person_slot_geometry(
        apartment_item,
        (700.0, 270.0),
        "floor_fixture",
        "floor",
        92.0,
        64.0,
    )
    _set_person_slot_geometry(
        apartment_patron,
        (170.0, 250.0),
        "standing_person",
        "floor",
        72.0,
        80.0,
    )

    _set_person_slot_geometry(
        club_ambient,
        (546.0, 252.0),
        "floor_fixture",
        "stage",
        92.0,
        64.0,
    )
    _set_person_slot_geometry(
        casino_patron,
        (660.0, 252.0),
        "standing_person",
        "floor",
        72.0,
        80.0,
    )
    _set_person_slot_geometry(
        back_room_patron,
        (700.0, 252.0),
        "standing_person",
        "floor",
        72.0,
        80.0,
    )


def _normalize_jazz_spacing(maps: dict[str, dict[str, Any]]) -> None:
    """Keep every guaranteed Jazz host clear of scenario-owned capacity."""

    jazz = maps["jazz_club"]
    required_ids = (
        "fixed.staff_bartender",
        "fixed.random_game_1",
        "fixed.band_stage",
        "fixed.musician_sax",
        "fixed.musician_cello",
        "fixed.musician_drummer",
        "fixed.tip_jar_band",
        "fixed.item_shop_1",
        "fixed.item_shop_2",
        "fixed.patron_dot",
        "event.counter_patron_1",
        "event.floor_item_1",
        "event.floor_patron_1",
        "scenario.floor_item_1",
        "scenario.floor_item_2",
        "scenario.floor_item_3",
        "scenario.floor_item_4",
        "scenario.floor_marker_1",
        "scenario.floor_marker_2",
        "scenario.floor_patron_1",
        "scenario.floor_patron_2",
        "scenario.surface_item_1",
        "scenario.surface_item_2",
        "scenario.surface_item_3",
        "scenario.doorway_1",
        "exit.left_upper",
        "exit.left_middle",
    )
    slots = {slot_id: _slot_by_id(jazz, slot_id) for slot_id in required_ids}
    missing = [slot_id for slot_id, slot in slots.items() if slot is None]
    if missing:
        raise ValueError("jazz_club: spacing capacity is incomplete: " + ", ".join(missing))

    for slot_id, pos, support_id in (
        ("fixed.musician_sax", (140.0, 236.0), "band_service_rail"),
        ("fixed.musician_cello", (304.0, 236.0), "stage"),
        ("fixed.musician_drummer", (468.0, 236.0), "stage"),
    ):
        _set_person_slot_geometry(
            slots[slot_id], pos, "standing_person", support_id, 72.0, 80.0
        )

    _set_person_slot_geometry(
        slots["fixed.staff_bartender"],
        (710.0, 192.0),
        "behind_counter_person",
        "bar",
        72.0,
        80.0,
    )
    _set_person_slot_geometry(
        slots["event.counter_patron_1"],
        (838.0, 236.0),
        "behind_counter_person",
        "bar",
        72.0,
        72.0,
    )
    _set_person_slot_geometry(
        slots["fixed.band_stage"],
        (116.0, 326.0),
        "ground_marker",
        "floor",
        72.0,
        48.0,
    )
    for slot_id, pos in (
        ("scenario.floor_patron_2", (490.0, 326.0)),
        ("scenario.floor_patron_1", (616.0, 326.0)),
        ("event.floor_patron_1", (744.0, 326.0)),
    ):
        _set_person_slot_geometry(
            slots[slot_id], pos, "standing_person", "floor", 72.0, 80.0
        )

    for slot_id, pos in (
        ("scenario.surface_item_1", (112.0, 150.0)),
        ("scenario.surface_item_2", (230.0, 150.0)),
        ("scenario.surface_item_3", (358.0, 150.0)),
        ("fixed.tip_jar_band", (494.0, 150.0)),
    ):
        _move_slot_to(slots[slot_id], pos)
        slots[slot_id]["support_id"] = "band_service_rail"

    for slot_id, pos in (
        ("fixed.random_game_1", (252.0, 414.0)),
        ("fixed.item_shop_1", (337.0, 404.0)),
        ("fixed.item_shop_2", (487.0, 404.0)),
        ("event.floor_item_1", (572.0, 414.0)),
        ("scenario.floor_item_1", (62.0, 414.0)),
        ("scenario.floor_item_2", (157.0, 414.0)),
        ("scenario.floor_item_3", (667.0, 414.0)),
        ("scenario.floor_item_4", (837.0, 414.0)),
        ("scenario.floor_marker_2", (412.0, 414.0)),
        ("scenario.floor_marker_1", (752.0, 414.0)),
    ):
        _move_slot_to(slots[slot_id], pos)

    _move_slot_to(slots["scenario.doorway_1"], (36.0, 76.0))
    _move_slot_to(slots["exit.left_upper"], (36.0, 160.0))
    _move_slot_to(slots["exit.left_middle"], (36.0, 244.0))

def _normalize_grand_living_floor_capacity(maps: dict[str, dict[str, Any]]) -> None:
    """Author optional generic event capacity for the complete living-floor cast."""

    capacities = {
        # Main Floor can select three ordinary events in addition to Rourke and
        # all three deterministic rivals.
        "grand_casino": 7,
        # High Limit can select two ordinary events; Back Room selects one.
        "grand_casino_high_limit": 6,
        "grand_casino_back_room": 5,
    }
    positions = {
        "grand_casino": [(156.0 + float(index) * 104.0, 414.0) for index in range(7)],
        "grand_casino_high_limit": [(162.0 + float(index) * 120.0, 414.0) for index in range(6)],
        "grand_casino_back_room": [(210.0 + float(index) * 120.0, 414.0) for index in range(5)],
    }
    for map_id, count in capacities.items():
        map_data = maps[map_id]
        source_ids = (
            "event.floor_patron_1",
            "scenario.floor_patron_1",
            "scenario.floor_patron_2",
            "fixed.patron_floor_1",
            "fixed.patron_bishop",
        )
        for ordinal in range(1, count + 1):
            slot_id = f"event.floor_patron_{ordinal}"
            _ensure_provisional_slot(
                map_data,
                "event",
                slot_id,
                "standing_person",
                source_ids,
            )
            slot = _slot_by_id(map_data, slot_id)
            if slot is None:
                raise ValueError(f"{map_id}: missing living-floor capacity {slot_id}")
            _set_person_slot_geometry(
                slot,
                positions[map_id][ordinal - 1],
                "standing_person",
                "floor",
            )


def _normalize_shared_event_person_capacity(maps: dict[str, dict[str, Any]]) -> None:
    """Reserve enough event-family floor space for Crew plus ambient actors.

    Crew residency, town travellers, and ordinary ambient events are independent
    runtime owners.  The binder therefore needs simultaneous generic capacity;
    a single preferred slot is not a declaration that these systems are
    mutually exclusive.
    """

    capacities = {
        "back_alley": 6,
        "gas_station_casino": 5,
        "bar": 5,
        "small_underground_casino": 8,
        "small_underground_casino:club": 8,
        "small_underground_casino:casino": 8,
        "small_underground_casino:back_room": 6,
    }
    for map_id, count in capacities.items():
        map_data = maps[map_id]
        source_ids = (
            "event.floor_patron_1",
            "event.floor_patron_2",
            "scenario.floor_patron_1",
            "scenario.floor_patron_2",
            "fixed.patron_crew",
        )
        for ordinal in range(1, count + 1):
            slot_id = f"event.floor_patron_{ordinal}"
            _ensure_provisional_slot(
                map_data,
                "event",
                slot_id,
                "standing_person",
                source_ids,
            )
            slot = _slot_by_id(map_data, slot_id)
            if slot is None:
                raise ValueError(f"{map_id}: missing shared event-person capacity {slot_id}")
            x = 100.0 if count == 1 else 100.0 + (760.0 * float(ordinal - 1) / float(count - 1))
            _set_person_slot_geometry(
                slot,
                (x, 414.0),
                "standing_person",
                "floor",
                64.0,
                82.0,
            )


def _normalize_public_event_capacity(maps: dict[str, dict[str, Any]]) -> None:
    """Reserve independent capacity for every ambient producer in public rooms.

    Scenario mutations, town-rumor staff, Numbers, travelers, Crew, and ordinary
    random events are selected independently.  A single legacy patron hotspot
    therefore cannot represent the maximum live event inventory.  These rows
    are intentionally provisional and remain invisible while empty; the room
    movement tool is the final authority for their hand-authored positions.
    """

    standing_capacity = {
        "motel": 4,
        "jazz_club": 3,
        "kitty_cat_lounge": 6,
        "delta_queen": 6,
        "beach": 1,
        "pawn_shop": 3,
    }
    standing_positions = {
        "motel": [(450.0, 424.0), (208.0, 424.0), (144.0, 424.0), (408.0, 334.0)],
        "jazz_club": [(746.0, 366.0), (810.0, 350.0), (236.0, 258.0)],
        "kitty_cat_lounge": [(704.0, 294.0), (450.0, 278.0), (78.0, 254.0), (78.0, 172.0), (244.0, 170.0), (450.0, 148.0)],
        "delta_queen": [(400.0, 282.0), (686.0, 278.0), (750.0, 278.0), (532.0, 258.0), (322.0, 246.0), (258.0, 246.0)],
        "beach": [(788.0, 406.0)],
        "pawn_shop": [(392.0, 414.0), (528.0, 414.0), (592.0, 414.0)],
    }
    for map_id, count in standing_capacity.items():
        map_data = maps[map_id]
        source_ids = (
            "event.floor_patron_1",
            "scenario.floor_patron_1",
            "fixed.patron_floor_right",
            "fixed.staff_floor",
            "fixed.door_left_lower",
            "fixed.service_beach_sand_pile",
        )
        for ordinal in range(1, count + 1):
            slot_id = f"event.floor_patron_{ordinal}"
            _ensure_provisional_slot(
                map_data,
                "event",
                slot_id,
                "standing_person",
                source_ids,
            )
            slot = _slot_by_id(map_data, slot_id)
            if slot is None:
                raise ValueError(f"{map_id}: missing public event-person capacity {slot_id}")
            _set_person_slot_geometry(
                slot,
                standing_positions[map_id][ordinal - 1],
                "standing_person",
                "floor",
                72.0 if map_id == "beach" else 64.0,
                80.0 if map_id == "beach" else 82.0,
            )
            if map_id == "beach":
                slot["facing"] = "right"
                slot["physical_role"] = "Delivery handoff contact"
                slot["zone_id"] = "foreground"
                slot["walk_lane_ids"] = ["lane.public"]
                slot["priority"] = 10

    motel = maps["motel"]
    _ensure_provisional_slot(
        motel,
        "event",
        "event.doorway_1",
        "doorway",
        ("scenario.doorway_1", "exit.room_door"),
        (-96.0, 0.0),
    )
    _assign_object_slot(
        motel,
        "event",
        "event:chain06_nico_weekly_door",
        "event.doorway_1",
    )
    motel_doorway = _slot_by_id(motel, "event.doorway_1")
    if motel_doorway is None:
        raise ValueError("motel: missing weekly-rates event doorway capacity")
    _set_person_slot_geometry(
        motel_doorway,
        (786.0, 148.0),
        "doorway",
        "hallway_door",
        64.0,
        72.0,
    )

    jazz_club = maps["jazz_club"]
    _ensure_provisional_slot(
        jazz_club,
        "event",
        "event.counter_patron_2",
        "behind_counter_person",
        ("event.counter_patron_1", "fixed.staff_bartender"),
        (-96.0, 0.0),
    )
    jazz_counter = _slot_by_id(jazz_club, "event.counter_patron_2")
    if jazz_counter is None:
        raise ValueError("jazz_club: missing second event counter capacity")
    _set_person_slot_geometry(
        jazz_counter,
        (558.0, 236.0),
        "behind_counter_person",
        "bar",
        72.0,
        72.0,
    )

    pawn_shop = maps["pawn_shop"]
    _ensure_provisional_slot(
        pawn_shop,
        "event",
        "event.surface_item_1",
        "surface_item",
        ("scenario.surface_item_1", "event.item_shop_1"),
        (-104.0, 0.0),
    )
    _assign_object_slot(
        pawn_shop,
        "event",
        "event:chain06_sal_estate_item",
        "event.surface_item_1",
    )
    pawn_surface = _slot_by_id(pawn_shop, "event.surface_item_1")
    if pawn_surface is None:
        raise ValueError("pawn_shop: missing estate-item event surface capacity")
    _set_person_slot_geometry(
        pawn_surface,
        (532.0, 118.0),
        "surface_item",
        "display_counter",
        72.0,
        48.0,
    )


def _normalize_delivery_wall_capacity(maps: dict[str, dict[str, Any]]) -> None:
    """Give every reachable room a reusable scenario wall control slot."""

    missing_wall_sources = {
        "back_alley": ("fixed.event_wall_notice", "scenario.surface_item_1"),
        "small_underground_casino:back_room": ("fixed.event_job_board", "scenario.surface_item_1"),
        "grand_casino_back_room": ("fixed.game_table_left", "scenario.floor_item_1"),
        "grand_casino_cage": ("fixed.fixture_cage_2", "scenario.surface_item_1"),
        "motel_room": ("fixed.home_notice", "scenario.surface_item_1"),
        "apartment": ("fixed.home_notice", "scenario.surface_item_1"),
        "house": ("fixed.home_notice", "scenario.surface_item_1"),
    }
    for ordinal, (map_id, source_ids) in enumerate(missing_wall_sources.items()):
        map_data = maps[map_id]
        _ensure_provisional_slot(
            map_data,
            "scenario",
            "scenario.wall_item_1",
            "wall_mounted",
            source_ids,
        )
        slot = _slot_by_id(map_data, "scenario.wall_item_1")
        if slot is None:
            raise ValueError(f"{map_id}: missing delivery wall capacity")
        x = 180.0 + float(ordinal % 4) * 170.0
        y = 188.0 + float(ordinal // 4) * 18.0
        slot["pos"] = [x, y]
        slot["hit_rect"] = [x - 40.0, y - 24.0, 80.0, 48.0]
        slot["label_anchor"] = [x, y - 30.0]
        slot["footprint_class"] = "wall_mounted"
        slot["support_id"] = "wall"


def _runtime_person_capacity_targets() -> dict[str, tuple[str, ...]]:
    """One generic scenario actor reserve per room."""

    scenario_targets = {
        "corner_store": "scenario.floor_patron_4",
        "back_alley": "scenario.floor_patron_3",
        "motel": "scenario.floor_patron_5",
        "bar": "scenario.floor_patron_5",
        "gas_station_casino": "scenario.floor_patron_5",
        "small_underground_casino": "scenario.floor_patron_3",
        "small_underground_casino:club": "scenario.floor_patron_4",
        "small_underground_casino:casino": "scenario.floor_patron_5",
        "small_underground_casino:back_room": "scenario.floor_patron_2",
        "jazz_club": "scenario.floor_patron_3",
        "kitty_cat_lounge": "scenario.floor_patron_4",
        "delta_queen": "scenario.floor_patron_3",
        "beach": "scenario.floor_patron_4",
        "pawn_shop": "scenario.floor_patron_2",
        "grand_casino": "scenario.floor_patron_3",
        "grand_casino_high_limit": "scenario.floor_patron_2",
        "grand_casino_back_room": "scenario.floor_patron_2",
        "grand_casino_cage": "scenario.floor_patron_2",
        "motel_room": "scenario.floor_patron_2",
        "apartment": "scenario.floor_patron_2",
        "house": "scenario.floor_patron_2",
    }
    return {map_id: (slot_id,) for map_id, slot_id in scenario_targets.items()}


def _normalize_runtime_person_capacity(maps: dict[str, dict[str, Any]]) -> None:
    """Reserve scenario capacity for injected chain actors and objects."""

    for map_id, slot_ids in _runtime_person_capacity_targets().items():
        map_data = maps[map_id]
        for slot_id in slot_ids:
            family = slot_id.split(".", 1)[0]
            _ensure_provisional_slot(
                map_data,
                family,
                slot_id,
                "standing_person",
                (
                    "scenario.floor_patron_1",
                    "event.floor_patron_1",
                    "fixed.patron_floor_right",
                    "fixed.staff_floor",
                ),
            )

    # Dave is a speaking traveler, so both mutually exclusive Gas Station beats
    # need standing-person event capacity.  The legacy surface/doorway
    # preferences are incompatible with his rendered class and make the binder
    # fall back to event.floor_patron_1, whose hit target overlaps the Road Crew
    # foreman's authored scenario slot.
    gas_station = maps["gas_station_casino"]
    for object_id in (
        "event:chain06_dave_same_bus",
        "event:chain06_dave_last_stop",
    ):
        _assign_object_slot(
            gas_station,
            "event",
            object_id,
            "event.floor_patron_2",
        )

    # These contacts are authored by their active scenarios. Raw event_ids lose
    # that provenance, so preserve the scenario family without pinning either
    # actor to one scenario's exact geometry.
    for map_id, object_id in (
        ("bar", "event:recruitment_knuckles"),
        ("beach", "event:recruitment_lucky"),
    ):
        map_data = maps[map_id]
        _remove_object_slot_assignment(map_data, object_id)
        map_data.setdefault("object_family_ids", {})[object_id] = "scenario"

    # The Crew's live table is a chain-owned physical table, not an ambient
    # event speaker.  Its catalog event remains the public interaction surface,
    # while placement draws from the same generic scenario furniture inventory
    # as every other chain object in the room.
    for map_id in HEIST_LIVE_TABLE_MAP_IDS:
        map_data = maps[map_id]
        _remove_object_slot_assignment(map_data, HEIST_LIVE_TABLE_OBJECT_ID)
        map_data.setdefault("object_family_ids", {})[HEIST_LIVE_TABLE_OBJECT_ID] = "scenario"
        map_data.setdefault("class_overrides", {})[HEIST_LIVE_TABLE_OBJECT_ID] = "floor_fixture"
        if not any(
            isinstance(slot, dict)
            and slot.get("kind") == "scenario"
            and slot.get("footprint_class") == "floor_fixture"
            for slot in map_data.get("scenario_slots", [])
        ):
            raise ValueError(f"{map_id}: missing shared scenario floor-fixture capacity for The Live Table")


def _normalize_runtime_person_spacing(maps: dict[str, dict[str, Any]]) -> None:
    """Place provisional runtime actors in clear room space, deterministically."""

    for map_id, slot_ids in _runtime_person_capacity_targets().items():
        map_data = maps[map_id]
        target_ids = set(slot_ids)
        obstacles: list[tuple[float, float, float, float]] = []
        for family in FAMILIES:
            for slot in map_data.get(f"{family}_slots", []) or []:
                if not isinstance(slot, dict) or str(slot.get("id", "")) in target_ids:
                    continue
                rect = _slot_rect(slot)
                if rect is not None:
                    obstacles.append(rect)

        for slot_id in slot_ids:
            slot = _slot_by_id(map_data, slot_id)
            if slot is None:
                raise ValueError(f"{map_id}: missing runtime person capacity {slot_id}")
            # Use one stable room-center anchor rather than the slot's prior
            # provisional geometry so fresh conversion and repeated migration
            # choose byte-identical locations.
            source_x = 450.0
            source_y = 250.0
            candidates: list[tuple[float, float, float, float, float]] = []
            for y in range(80, 431, 4):
                for x in range(36, 865, 4):
                    candidate = (float(x - 36), float(y - 80), 72.0, 80.0)
                    if any(_rects_overlap(candidate, obstacle) for obstacle in obstacles):
                        continue
                    dx = float(x) - source_x
                    dy = float(y) - source_y
                    candidates.append((dx * dx + dy * dy, abs(dy), abs(dx), float(x), float(y)))
            if not candidates:
                raise ValueError(f"{map_id}: no clear geometry remains for {slot_id}")
            _, _, _, chosen_x, chosen_y = min(candidates)
            _set_person_slot_geometry(
                slot,
                (chosen_x, chosen_y),
                "standing_person",
                "floor",
            )
            slot["occupancy_required"] = False
            rect = _slot_rect(slot)
            if rect is None:
                raise ValueError(f"{map_id}: runtime person capacity {slot_id} lacks geometry")
            obstacles.append(rect)


def _normalize_reviewed_output_order(maps: dict[str, dict[str, Any]]) -> None:
    """Keep the reviewed v2 row order stable on fresh and repeated migration.

    Several capacity repairs were added after the first one-way conversion.
    This compact tail ordering makes a fresh conversion serialize identically
    to the reviewed authority instead of depending on repair introduction time.
    Slot order is runtime-significant because it is the deterministic fallback
    order when otherwise-equivalent capacity is selected.
    """

    fixed_tails = {
        "corner_store": ("fixed.service_house_drink", "fixed.numbers_book"),
        "back_alley": (
            "fixed.service_house_drink",
            "fixed.patron_vince",
            "fixed.patron_lena",
        ),
        "motel": (
            "fixed.item_shop_5",
            "fixed.service_house_drink",
            "fixed.numbers_book",
            "fixed.staff_june",
            "fixed.patron_marco",
        ),
        "bar": (
            "fixed.numbers_book",
            "fixed.service_house_drink",
            "fixed.staff_bartender",
            "fixed.patron_dot",
        ),
        "gas_station_casino": (
            "fixed.game_scratch_tickets",
            "fixed.numbers_book",
            "fixed.service_house_drink",
            "fixed.staff_nell",
        ),
        "small_underground_casino:casino": (
            "fixed.door_side_event",
            "fixed.service_house_drink",
            "fixed.numbers_book",
            "fixed.staff_floor_right",
        ),
        "kitty_cat_lounge": (
            "fixed.item_shop_3",
            "fixed.service_kitty_champagne",
            "fixed.service_house_drink",
            "fixed.patron_dot",
        ),
        "grand_casino": (
            "fixed.service_house_drink",
            "fixed.staff_host",
            "fixed.event_audit_roster",
        ),
    }
    event_tails = {
        "motel": ("event.floor_patron_1",),
        "bar": ("event.floor_patron_2",),
        "gas_station_casino": ("event.floor_patron_1",),
        "small_underground_casino": ("event.floor_patron_2",),
        "small_underground_casino:casino": ("event.floor_patron_1",),
        "small_underground_casino:back_room": ("event.floor_patron_1",),
        "jazz_club": ("event.floor_patron_1",),
        "kitty_cat_lounge": ("event.floor_patron_1",),
    }
    scenario_tails = {
        # These two capacities are both post-conversion repairs. Keep their
        # order independent of whether the input is legacy schema v1 or an
        # already-normalized v2 authority.
        "bar": ("scenario.floor_patron_5", "scenario.seated_patron_2"),
    }

    def move_to_tail(map_data: dict[str, Any], family: str, slot_ids: tuple[str, ...]) -> None:
        values = [
            slot
            for slot in map_data.get(f"{family}_slots", []) or []
            if isinstance(slot, dict)
        ]
        by_id = {str(slot.get("id", "")): slot for slot in values}
        missing = [slot_id for slot_id in slot_ids if slot_id not in by_id]
        if missing:
            raise ValueError(
                f"{map_data.get('id', '<unknown>')}: reviewed {family} order lacks {missing}"
            )
        selected = set(slot_ids)
        map_data[f"{family}_slots"] = [
            slot for slot in values if str(slot.get("id", "")) not in selected
        ] + [by_id[slot_id] for slot_id in slot_ids]

    for map_id, slot_ids in fixed_tails.items():
        move_to_tail(maps[map_id], "fixed", slot_ids)
    for map_id, slot_ids in event_tails.items():
        move_to_tail(maps[map_id], "event", slot_ids)
    for map_id, slot_ids in scenario_tails.items():
        move_to_tail(maps[map_id], "scenario", slot_ids)

    back_alley = maps["back_alley"]
    for route in back_alley.get("actor_routes", []) or []:
        if not isinstance(route, dict) or str(route.get("id", "")) != "base::world:bar":
            continue
        route["start_slot_id"] = "scenario.floor_patron_1"
        route["end_slot_id"] = "scenario.floor_patron_2"
        route["reduced_motion_slot_id"] = "scenario.floor_patron_2"

    gas_house_drink = _slot_by_id(maps["gas_station_casino"], "fixed.service_house_drink")
    if gas_house_drink is None:
        raise ValueError("gas_station_casino: reviewed house-drink capacity is missing")
    _move_slot_to(gas_house_drink, (846.0, 148.0))

    grand_objects = maps["grand_casino"].get("fixed_objects", [])
    if isinstance(grand_objects, list):
        priority = {
            "grand_casino:floor_host": 0,
            "grand_casino:audit_roster": 1,
        }
        grand_objects.sort(
            key=lambda value: priority.get(
                str(value.get("object_id", "")) if isinstance(value, dict) else "",
                len(priority),
            )
        )


def _normalize_slot_occupancy_metadata(payload: dict[str, Any]) -> None:
    """Make empty capacity optional and exact guaranteed declarations explicit."""

    for map_data in payload.get("maps", []):
        if not isinstance(map_data, dict):
            continue
        for family in FAMILIES:
            for slot in map_data.get(f"{family}_slots", []):
                if isinstance(slot, dict):
                    slot["occupancy_required"] = False
        for declaration in map_data.get("fixed_objects", []):
            if not isinstance(declaration, dict) or not bool(declaration.get("required", True)):
                continue
            slot_id = str(declaration.get("exact_slot_id", ""))
            slot = _slot_by_id(map_data, slot_id)
            if slot is None:
                raise ValueError(
                    f"{map_data.get('id', '<unknown>')}: required declaration names missing {slot_id}"
                )
            slot["occupancy_required"] = True


def _fixed_object_by_id(
    map_data: dict[str, Any], object_id: str
) -> dict[str, Any] | None:
    return next(
        (
            value
            for value in map_data.get("fixed_objects", []) or []
            if isinstance(value, dict) and str(value.get("object_id", "")) == object_id
        ),
        None,
    )


def _rename_slot_and_references(
    map_data: dict[str, Any], source_slot_id: str, target_slot_id: str
) -> None:
    """Rename one authored row and every local authority reference atomically."""

    source = _slot_by_id(map_data, source_slot_id)
    target = _slot_by_id(map_data, target_slot_id)
    if source is None:
        if target is not None:
            return
        raise ValueError(
            f"{map_data.get('id', '<unknown>')}: cannot rename missing "
            f"{source_slot_id}"
        )
    if target is not None and target is not source:
        raise ValueError(
            f"{map_data.get('id', '<unknown>')}: rename target already exists "
            f"{target_slot_id}"
        )
    source["id"] = target_slot_id
    for family in FAMILIES:
        for suffix in ("object_slot_ids", "category_slot_ids"):
            preferences = map_data.get(f"{family}_{suffix}", {})
            if not isinstance(preferences, dict):
                continue
            for claimant, slot_id in list(preferences.items()):
                if str(slot_id) == source_slot_id:
                    preferences[claimant] = target_slot_id
    preferences = map_data.get("scenario_slot_ids", {})
    if isinstance(preferences, dict):
        for claimant, slot_id in list(preferences.items()):
            if str(slot_id) == source_slot_id:
                preferences[claimant] = target_slot_id
    for route in map_data.get("actor_routes", []) or []:
        if not isinstance(route, dict):
            continue
        for field in ("start_slot_id", "end_slot_id", "reduced_motion_slot_id"):
            if str(route.get(field, "")) == source_slot_id:
                route[field] = target_slot_id
    for declaration in map_data.get("fixed_objects", []) or []:
        if (
            isinstance(declaration, dict)
            and str(declaration.get("exact_slot_id", "")) == source_slot_id
        ):
            declaration["exact_slot_id"] = target_slot_id


def _normalize_descriptive_fixed_ids(maps: dict[str, dict[str, Any]]) -> None:
    renames = {
        "corner_store": {
            "fixed.event_group_1": "fixed.crew_group",
        },
        "back_alley": {
            "fixed.door_left_upper": "fixed.lender_street_lender",
            "fixed.patron_crew": "fixed.crew_group",
            "fixed.event_wall_notice": "fixed.home_upgrade",
        },
        "pawn_shop": {
            "fixed.door_left_lower": "fixed.lender_sals_pawn_counter",
        },
        "beach": {
            "fixed.door_right_lower": "fixed.service_beach_sand_pile",
        },
        "kitty_cat_lounge": {
            "fixed.random_game_1": "fixed.event_grand_casino_invite",
            "fixed.patron_group_center": "fixed.crew_group",
        },
        "delta_queen": {
            "fixed.event_wall_1": "fixed.event_grand_casino_invite",
            "fixed.event_deck_walk": "fixed.service_deck_walk",
            "fixed.patron_front_left": "fixed.crew_group",
            "fixed.staff_floor": "fixed.staff_ox",
        },
        "small_underground_casino:club": {
            "fixed.staff_floor_right": "fixed.staff_ox",
        },
        "small_underground_casino:casino": {
            "fixed.staff_floor_right": "fixed.staff_ox",
        },
        "grand_casino_cage": {
            "fixed.fixture_cage_1": "fixed.fixture_cage_counter",
            "fixed.fixture_cage_2": "fixed.fixture_cage_atm",
        },
    }
    for map_id, map_renames in renames.items():
        for source_slot_id, target_slot_id in map_renames.items():
            if (
                map_id == "pawn_shop"
                and source_slot_id == "fixed.door_left_lower"
                and _slot_by_id(maps[map_id], source_slot_id) is None
                and _slot_by_id(maps[map_id], "fixed.staff_pawn_counter") is not None
            ):
                # Sal's reviewed single-host consolidation has already replaced
                # both legacy lender/merchant positions with the named counter.
                continue
            if (
                map_id == "back_alley"
                and source_slot_id == "fixed.event_wall_notice"
                and _slot_by_id(maps[map_id], source_slot_id) is None
            ):
                # A short-lived consolidated authority retired this live Meta
                # Home row. The capacity normalizer below recreates the named
                # target when neither legacy nor canonical row is present.
                continue
            if (
                _slot_by_id(maps[map_id], source_slot_id) is None
                and _slot_by_id(maps[map_id], target_slot_id) is not None
            ):
                # The reviewed-v2 refresh is idempotent: a canonical target may
                # already exist even though its legacy descriptive id does not.
                continue
            if (
                map_id == "kitty_cat_lounge"
                and source_slot_id == "fixed.random_game_1"
                and _slot_by_id(maps[map_id], target_slot_id) is not None
            ):
                # A short-lived maintenance authority reused random_game_1 for
                # Kitty's machine capacity after the invite had already been
                # renamed. The fixed-game normalizer below resolves that row.
                continue
            _rename_slot_and_references(
                maps[map_id], source_slot_id, target_slot_id
            )

def _normalize_back_alley_meta_home_capacity(
    maps: dict[str, dict[str, Any]],
) -> None:
    """Restore the physical controls used when Back Alley is the Meta Home."""

    back_alley = maps["back_alley"]
    container_positions = ((124.0, 358.0), (620.0, 358.0), (730.0, 358.0))
    for ordinal, position in enumerate(container_positions, start=1):
        slot_id = f"fixed.home_container_{ordinal}"
        _ensure_provisional_slot(
            back_alley,
            "fixed",
            slot_id,
            "floor_fixture",
            ("fixed.service_house_drink", "fixed.item_shop_1"),
        )
        slot = _slot_by_id(back_alley, slot_id)
        if slot is None:
            raise ValueError(f"back_alley: missing Meta Home container slot {slot_id}")
        _set_person_slot_geometry(
            slot,
            position,
            "floor_fixture",
            "floor",
            92.0,
            64.0,
        )
        slot["physical_role"] = f"Meta Home container {ordinal}"
        slot["priority"] = 10 + ordinal * 5
        slot["zone_id"] = ("left", "center", "right")[ordinal - 1]
        _move_category_preference(
            back_alley,
            "fixed",
            f"home_container_spots:{ordinal - 1}",
            slot_id,
        )

    _ensure_provisional_slot(
        back_alley,
        "fixed",
        "fixed.home_upgrade",
        "wall_mounted",
        ("fixed.item_shop_1", "fixed.service_house_drink"),
    )
    upgrade = _slot_by_id(back_alley, "fixed.home_upgrade")
    if upgrade is None:
        raise ValueError("back_alley: missing Meta Home upgrade slot")
    _set_person_slot_geometry(
        upgrade,
        (650.0, 120.0),
        "wall_mounted",
        "wall",
        80.0,
        48.0,
    )
    upgrade["physical_role"] = "Meta Home upgrade sign"
    upgrade["priority"] = 10
    upgrade["zone_id"] = "right"
    _assign_object_slot(
        back_alley,
        "fixed",
        "meta_upgrade:home",
        "fixed.home_upgrade",
    )
    _move_category_preference(
        back_alley,
        "fixed",
        "home_upgrade_spots:0",
        "fixed.home_upgrade",
    )

    # A fresh legacy conversion retains these rows in their historical
    # positions, while a reviewed-v2 recovery appends them. Give both paths one
    # canonical order because slot order is deterministic fallback authority.
    meta_slot_ids = tuple(
        [f"fixed.home_container_{ordinal}" for ordinal in range(1, 4)]
        + ["fixed.home_upgrade"]
    )
    fixed_slots = [
        slot
        for slot in back_alley.get("fixed_slots", []) or []
        if isinstance(slot, dict)
    ]
    fixed_by_id = {str(slot.get("id", "")): slot for slot in fixed_slots}
    back_alley["fixed_slots"] = [
        slot for slot in fixed_slots if str(slot.get("id", "")) not in meta_slot_ids
    ] + [fixed_by_id[slot_id] for slot_id in meta_slot_ids]

    # Knuckles is a standing scenario actor. Bar seating heuristics are valid
    # for ordinary patrons but must not change this named recruitment contact.
    bar_fight = maps["bar"].setdefault("scenario_overrides", {}).setdefault(
        "bar_fight_night", {}
    )
    bar_fight.setdefault("class_overrides", {})[
        "event:recruitment_knuckles"
    ] = "standing_person"


def _normalize_scenario_instance_classes(
    maps: dict[str, dict[str, Any]],
) -> None:
    """Keep one stable physical footprint when a scene object's state changes."""

    for map_id, stable_id, placement_class in (
        ("pawn_shop", "private_appraisal", "surface_item"),
        (
            "small_underground_casino:club",
            "punchline_raid_jitters_clear_bins",
            "floor_fixture",
        ),
    ):
        maps[map_id].setdefault("class_overrides", {})[
            stable_id
        ] = placement_class

    # The raw Punchline parent is a source template, but keeping its live fixed
    # rows in deterministic reviewed order makes fresh legacy conversion
    # byte-identical to maintenance refreshes and keeps human diffs readable.
    # fixed.staff_floor_left is only a geometry donor earlier in a fresh legacy
    # conversion and is retired after its live derivatives have been authored.
    punchline = maps["small_underground_casino"]
    punchline_order = {
        "fixed.door_right_lower": 0,
    }
    punchline["fixed_slots"] = sorted(
        punchline.get("fixed_slots", []) or [],
        key=lambda slot: punchline_order.get(
            str(slot.get("id", "")) if isinstance(slot, dict) else "", 2
        ),
    )


def _normalize_fixed_game_authority(maps: dict[str, dict[str, Any]]) -> None:
    """Name guaranteed games exactly and keep variable pools ID-independent."""

    guaranteed_renames = {
        "corner_store": {
            "fixed.random_game_1": "fixed.game_coin_pusher",
        },
        "beach": {
            "fixed.random_game_1": "fixed.game_slot",
        },
        "pawn_shop": {
            "fixed.random_game_1": "fixed.game_slot",
        },
        "small_underground_casino:back_room": {
            "fixed.random_game_1": "fixed.game_crew_draw_poker",
        },
        "delta_queen": {
            "fixed.random_game_1": "fixed.game_blackjack",
            "fixed.random_game_2": "fixed.game_video_poker",
            "fixed.random_game_3": "fixed.game_roulette",
        },
    }
    for map_id, renames in guaranteed_renames.items():
        for source_slot_id, target_slot_id in renames.items():
            _rename_slot_and_references(
                maps[map_id], source_slot_id, target_slot_id
            )

    # The hidden Punchline casino generates exactly two games from a three-game
    # pool.  Both positions are floor fixtures owned by ordinal capacity.  The
    # former surface-item middle row caused Blackjack to fall through to the
    # Numbers Book; it is now retired rather than treated as game capacity.
    casino = maps["small_underground_casino:casino"]
    if _slot_by_id(casino, "fixed.random_game_3") is not None:
        _rename_slot_and_references(
            casino, "fixed.random_game_3", "fixed.game_floor_2"
        )
    elif _slot_by_id(casino, "fixed.game_floor_2") is None:
        # Maintenance recovery for the short-lived reviewed authority that had
        # already removed random_game_3: promote the doomed middle row, then
        # normalize it to the canonical second floor fixture below.
        _rename_slot_and_references(
            casino, "fixed.random_game_2", "fixed.game_floor_2"
        )
    _rename_slot_and_references(
        casino, "fixed.random_game_1", "fixed.game_floor_1"
    )
    second_floor = _slot_by_id(casino, "fixed.game_floor_2")
    if second_floor is None:
        raise ValueError(
            "small_underground_casino:casino: missing second floor-game capacity"
        )
    second_floor.update({
        "pos": [468.0, 70.0],
        "footprint_class": "floor_fixture",
        "physical_role": "Game floor position 2",
        "hit_rect": [422.0, 6.0, 92.0, 64.0],
        "label_anchor": [407.0, 26.0],
        "facing": "none",
        "priority": 130,
        "zone_id": "room",
        "support_id": "stage",
        "walk_lane_ids": [],
        "occupancy_required": False,
    })
    casino_objects = casino.setdefault("fixed_object_slot_ids", {})
    for object_id in ("game:slot", "game:blackjack", "game:video_poker"):
        casino_objects.pop(object_id, None)
        casino.setdefault("object_family_ids", {})[object_id] = "fixed"
        casino.setdefault("class_overrides", {})[object_id] = "floor_fixture"
    casino_categories = casino.setdefault("fixed_category_slot_ids", {})
    for category_id in list(casino_categories):
        if category_id.startswith(("game_spots:", "service_spots:", "lender_spots:")):
            casino_categories.pop(category_id, None)
    casino_categories.update({
        "game_spots:0": "fixed.game_floor_1",
        "game_spots:1": "fixed.game_floor_2",
        "service_spots:0": "fixed.service_house_drink",
        "lender_spots:0": "fixed.lender_group_1",
        "lender_spots:1": "fixed.lender_person_1",
    })
    _rename_slot_and_references(
        casino, "fixed.crew_group", "fixed.lender_group_1"
    )
    _rename_slot_and_references(
        casino, "fixed.staff_street_lender", "fixed.lender_person_1"
    )
    for object_id in ("lender:the_crew", "lender:street_lender"):
        casino_objects.pop(object_id, None)
    casino_order = {
        "fixed.staff_dealer": 0,
        "fixed.game_floor_1": 1,
        "fixed.game_floor_2": 2,
        "fixed.lender_person_1": 3,
        "fixed.lender_group_1": 4,
    }
    casino["fixed_slots"] = sorted(
        casino.get("fixed_slots", []) or [],
        key=lambda slot: casino_order.get(
            str(slot.get("id", "")) if isinstance(slot, dict) else "", 100
        ),
    )

    # Kitty has one machine footprint and two table footprints.  Which game ID
    # uses those positions is intentionally determined by the generated pool,
    # not by object-specific placement authority.
    kitty = maps["kitty_cat_lounge"]
    for source_slot_id in ("fixed.game_table_left", "fixed.game_roulette"):
        if _slot_by_id(kitty, source_slot_id) is not None:
            _rename_slot_and_references(
                kitty, source_slot_id, "fixed.table_game_1"
            )
    _rename_slot_and_references(
        kitty, "fixed.random_game_2", "fixed.table_game_2"
    )
    for source_slot_id in ("fixed.random_game_3", "fixed.random_game_1"):
        if _slot_by_id(kitty, source_slot_id) is not None:
            _rename_slot_and_references(
                kitty, source_slot_id, "fixed.machine_game_1"
            )
    kitty_objects = kitty.setdefault("fixed_object_slot_ids", {})
    for object_id in ("game:roulette", "game:slot", "game:bar_dice"):
        kitty_objects.pop(object_id, None)
    kitty_categories = kitty.setdefault("fixed_category_slot_ids", {})
    for category_id in list(kitty_categories):
        if category_id.startswith(("game_spots:", "game_hook_spots:", "service_spots:")):
            kitty_categories.pop(category_id, None)
    kitty_categories.update({
        "game_spots:0": "fixed.table_game_1",
        "game_spots:1": "fixed.machine_game_1",
        "game_spots:2": "fixed.table_game_2",
        "service_spots:0": "fixed.service_kitty_champagne",
        "service_spots:2": "fixed.service_house_drink",
    })

    # Delta always generates all three named games.  Their exact object
    # mappings are the complete authority, so stale ordinal/service aliases are
    # removed instead of pointing unrelated content at game geometry.
    delta_categories = maps["delta_queen"].setdefault(
        "fixed_category_slot_ids", {}
    )
    for category_id in list(delta_categories):
        if category_id.startswith(
            ("game_spots:", "game_hook_spots:", "service_spots:", "lender_spots:")
        ):
            delta_categories.pop(category_id, None)

    # Convention Crowd used to reclassify Video Poker as a floor fixture,
    # forcing it out of its guaranteed machine slot and into an unrelated
    # event fixture. Keep the machine's base classification in every scenario.
    grand_overrides = maps["grand_casino"].get("scenario_overrides", {})
    if isinstance(grand_overrides, dict):
        convention = grand_overrides.get("grand_casino_convention_crowd", {})
        if isinstance(convention, dict):
            class_overrides = convention.get("class_overrides", {})
            if isinstance(class_overrides, dict):
                class_overrides.pop("game:video_poker", None)
                if not class_overrides:
                    convention.pop("class_overrides", None)

    # The club service is physically owned by the guaranteed stage.  Its old
    # second table row never received an occupant.
    club_categories = maps["small_underground_casino:club"].setdefault(
        "fixed_category_slot_ids", {}
    )
    club_categories["service_spots:0"] = "fixed.service_stage"

    # These ordinal service routes are action-only or empty in production.
    # Their actions already attach to tangible staff/musician hosts, so keeping
    # the aliases would misleadingly advertise extra physical service objects.
    for map_id in ("back_alley", "corner_store", "pawn_shop", "jazz_club"):
        categories = maps[map_id].setdefault("fixed_category_slot_ids", {})
        for category_id in list(categories):
            if str(category_id).startswith("service_spots:"):
                categories.pop(category_id, None)


def _retire_unreachable_slots(maps: dict[str, dict[str, Any]]) -> None:
    """Remove reviewed dead rows and every ordinal category alias to them."""

    unknown_maps = set(RETIRED_UNUSED_SLOT_IDS) - set(maps)
    if unknown_maps:
        raise ValueError(
            f"retired placement rows name missing maps: {sorted(unknown_maps)}"
        )
    for map_id, retired_ids in RETIRED_UNUSED_SLOT_IDS.items():
        map_data = maps[map_id]
        removable_ids: set[str] = set()
        for slot_id in retired_ids:
            slot = _slot_by_id(map_data, slot_id)
            if slot is None:
                continue
            slot_kind = str(slot.get("kind", ""))
            if slot_kind == "scenario":
                placement_class = str(slot.get("footprint_class", ""))
                class_count = sum(
                    1
                    for candidate in map_data.get("scenario_slots", []) or []
                    if isinstance(candidate, dict)
                    and str(candidate.get("footprint_class", ""))
                    == placement_class
                )
                target_count = int(
                    SCENARIO_CAPACITY_TARGETS[map_id].get(placement_class, 0)
                )
                if (
                    class_count <= target_count
                    and (
                        bool(list(slot.get("occupant_ids", []) or []))
                        or bool(slot.get("occupancy_required", False))
                        or bool(slot.get("runtime_reserve", False))
                    )
                ):
                    # Scenario ids are compact ordinals. After a reviewed row
                    # is removed, a retained live/reserve row can inherit the
                    # same spelling; do not retire that survivor on refresh.
                    continue
            # Legacy exit rows can still carry obsolete world-map destination
            # labels even though production no longer creates those physical
            # objects. CANONICAL_EXIT_AUTHORITY above is the closed proof for
            # retiring them; non-exit rows must remain completely unclaimed.
            if (
                (
                    str(slot.get("kind", "")) != "exit"
                    and bool(list(slot.get("occupant_ids", []) or []))
                )
                or bool(slot.get("occupancy_required", False))
                or bool(slot.get("runtime_reserve", False))
            ):
                raise ValueError(
                    f"{map_id}: refusing to retire live/reserved slot {slot_id}"
                )
            for family in FAMILIES:
                object_preferences = map_data.get(
                    f"{family}_object_slot_ids", {}
                )
                if isinstance(object_preferences, dict) and slot_id in {
                    str(value) for value in object_preferences.values()
                }:
                    raise ValueError(
                        f"{map_id}: refusing to retire object-mapped slot {slot_id}"
                    )
            if any(
                isinstance(declaration, dict)
                and str(declaration.get("exact_slot_id", "")) == slot_id
                for declaration in map_data.get("fixed_objects", []) or []
            ):
                raise ValueError(
                    f"{map_id}: refusing to retire declared fixed slot {slot_id}"
                )
            removable_ids.add(slot_id)

        for family in FAMILIES:
            field = f"{family}_slots"
            map_data[field] = [
                slot
                for slot in map_data.get(field, []) or []
                if not isinstance(slot, dict)
                or str(slot.get("id", "")) not in removable_ids
            ]
            category_preferences = map_data.get(
                f"{family}_category_slot_ids", {}
            )
            if isinstance(category_preferences, dict):
                for claimant, slot_id in list(category_preferences.items()):
                    if str(slot_id) in removable_ids:
                        category_preferences.pop(claimant, None)

        semantic_preferences = map_data.get("scenario_slot_ids", {})
        if isinstance(semantic_preferences, dict):
            for claimant, slot_id in list(semantic_preferences.items()):
                if str(slot_id) in removable_ids:
                    semantic_preferences.pop(claimant, None)


def _normalize_exit_authority(maps: dict[str, dict[str, Any]]) -> None:
    """Keep only exits that production can create in each playable room."""

    unknown_maps = set(CANONICAL_EXIT_AUTHORITY) - set(maps)
    if unknown_maps:
        raise ValueError(
            f"canonical exit authority names missing maps: {sorted(unknown_maps)}"
        )

    # Maintenance recovery for a short-lived review that treated the Grand
    # Casino's UI-synthesized world-map Leave controls as dead merely because
    # the manifest-only generation host does not emit them. The real
    # interaction view model uses all three slots.
    grand_leave_slots = {
        "grand_casino_high_limit": {
            "id": "exit.safe_left",
            "pos": [36.0, 278.0],
            "hit_rect": [4.0, 242.0, 64.0, 72.0],
            "label_anchor": [36.0, 236.0],
            "priority": 10,
            "support_id": "left_exit",
        },
        "grand_casino_back_room": {
            "id": "exit.travel_left",
            "pos": [36.0, 390.0],
            "hit_rect": [4.0, 354.0, 64.0, 72.0],
            "label_anchor": [36.0, 348.0],
            "priority": 40,
            "support_id": "left_exit",
        },
        "grand_casino_cage": {
            "id": "exit.travel_floor_door",
            "pos": [847.0, 160.0],
            "hit_rect": [815.0, 124.0, 64.0, 72.0],
            "label_anchor": [847.0, 118.0],
            "priority": 70,
            "support_id": "floor_door",
        },
    }
    for map_id, geometry in grand_leave_slots.items():
        map_data = maps[map_id]
        slot_id = str(geometry["id"])
        slot = _slot_by_id(map_data, slot_id)
        if slot is None:
            slot = {"id": slot_id}
            map_data.setdefault("exit_slots", []).append(slot)
        slot.update({
            "kind": "exit",
            "pos": list(geometry["pos"]),
            "footprint_class": "doorway",
            "physical_role": "Travel exit",
            "occupant_ids": ["travel:leave"],
            "runtime_reserve": False,
            "reserve_reason": "",
            "hit_rect": list(geometry["hit_rect"]),
            "label_anchor": list(geometry["label_anchor"]),
            "facing": "front",
            "priority": int(geometry["priority"]),
            "zone_id": "room",
            "support_id": str(geometry["support_id"]),
            "walk_lane_ids": ["lane.public"],
            "occupancy_required": False,
        })
    grand_exit_order = {
        "grand_casino_high_limit": [
            "exit.travel_left", "exit.travel_right", "exit.safe_left",
        ],
        "grand_casino_back_room": ["exit.travel_left"],
        "grand_casino_cage": [
            "exit.casino_floor_door", "exit.travel_floor_door",
        ],
    }
    for map_id, slot_ids in grand_exit_order.items():
        order = {slot_id: index for index, slot_id in enumerate(slot_ids)}
        maps[map_id]["exit_slots"] = sorted(
            maps[map_id].get("exit_slots", []) or [],
            key=lambda slot: order.get(
                str(slot.get("id", "")) if isinstance(slot, dict) else "",
                len(order),
            ),
        )

    # Owning a motel room adds a second, runtime-authored doorway alongside the
    # ordinary leave action. It is conditional rather than dead capacity, so
    # retain one clearly named reserve instead of the three ambiguous legacy
    # motel exits. Fresh legacy conversion renames the reviewed room-door row;
    # maintenance refreshes can deterministically recover it from the scenario
    # doorway geometry after a short-lived authority removed every spare exit.
    motel = maps["motel"]
    if _slot_by_id(motel, "exit.motel_room") is None:
        if _slot_by_id(motel, "exit.room_door") is not None:
            _rename_slot_and_references(
                motel, "exit.room_door", "exit.motel_room"
            )
        else:
            _ensure_provisional_slot(
                motel,
                "exit",
                "exit.motel_room",
                "doorway",
                ("scenario.doorway_3", "exit.door_curtain"),
            )
    motel_room_exit = _slot_by_id(motel, "exit.motel_room")
    if motel_room_exit is None:
        raise ValueError("motel: missing conditional motel-room entrance")
    motel_room_exit.update({
        "pos": [303.0, 168.0],
        "kind": "exit",
        "footprint_class": "doorway",
        "physical_role": "Owned motel-room entrance",
        "occupant_ids": [],
        "runtime_reserve": True,
        "reserve_reason": (
            "Active motel-room ownership adds a return door beside the normal "
            "travel exit."
        ),
        "hit_rect": [271.0, 132.0, 64.0, 72.0],
        "label_anchor": [303.0, 126.0],
        "facing": "right",
        "priority": 20,
        "zone_id": "room",
        "support_id": "room_door",
        "walk_lane_ids": ["lane.public"],
        "occupancy_required": False,
    })

    for map_id, authority in CANONICAL_EXIT_AUTHORITY.items():
        map_data = maps[map_id]
        objects = dict(authority["objects"])
        categories = dict(authority["categories"])
        authored_ids = {
            str(slot.get("id", ""))
            for slot in map_data.get("exit_slots", []) or []
            if isinstance(slot, dict)
        }
        missing = (set(objects.values()) | set(categories.values())) - authored_ids
        if missing:
            raise ValueError(
                f"{map_id}: canonical exit authority names missing slots "
                f"{sorted(missing)}"
            )
        map_data["exit_object_slot_ids"] = objects
        map_data["exit_category_slot_ids"] = categories
        family_ids = map_data.setdefault("object_family_ids", {})
        if not isinstance(family_ids, dict):
            raise ValueError(f"{map_id}: object_family_ids must be an object")
        for object_id, family in list(family_ids.items()):
            if str(family) == "exit":
                family_ids.pop(object_id, None)
        for object_id in objects:
            family_ids[object_id] = "exit"


def _normalize_reviewed_slot_geometry(maps: dict[str, dict[str, Any]]) -> None:
    """Apply the audited non-overlapping starting geometry."""

    for map_id, slots in REVIEWED_SLOT_GEOMETRY.items():
        map_data = maps.get(map_id)
        if map_data is None:
            raise ValueError(f"reviewed geometry names missing map {map_id}")
        for slot_id, geometry in slots.items():
            slot = _slot_by_id(map_data, slot_id)
            if slot is None:
                raise ValueError(
                    f"{map_id}: reviewed geometry names missing slot {slot_id}"
                )
            for field in ("pos", "hit_rect", "label_anchor"):
                slot[field] = list(geometry[field])
            slot["support_id"] = str(geometry["support_id"])

    gas_station = maps["gas_station_casino"]
    sill = next(
        (
            doorway
            for doorway in gas_station.get("doorways", []) or []
            if isinstance(doorway, dict)
            and str(doorway.get("id", "")) == "round3_sill_door"
        ),
        None,
    )
    if sill is None:
        raise ValueError("gas_station_casino: round3_sill_door is missing")
    sill["bounds"] = [226.0, 96.0, 160.0, 48.0]


def _attach_actions_to_fixed_host(
    map_data: dict[str, Any], host_object_id: str, action_ids: tuple[str, ...]
) -> None:
    """Attach abstract interactions to one guaranteed tangible room object."""

    declaration = _fixed_object_by_id(map_data, host_object_id)
    if declaration is None:
        raise ValueError(
            f"{map_data.get('id', '<unknown>')}: missing fixed action host {host_object_id}"
        )
    actions = [str(value) for value in declaration.get("action_ids", []) or []]
    for action_id in action_ids:
        if action_id not in actions:
            actions.append(action_id)
        _remove_object_slot_assignment(map_data, action_id)
        map_data.setdefault("object_family_ids", {})[action_id] = "fixed"
        class_overrides = map_data.get("class_overrides", {})
        if isinstance(class_overrides, dict):
            class_overrides.pop(action_id, None)
        positions = map_data.get("object_slot_positions", {})
        if isinstance(positions, dict):
            positions.pop(action_id, None)
    declaration["action_ids"] = actions


def _retire_pull_tabs_standalone_rows(maps: dict[str, dict[str, Any]]) -> None:
    """Put Pull Tabs, redemption, and help on each venue's staffed counter."""

    retired_slot_ids = {
        "bar": (
            "fixed.ticket_redeemer",
            "fixed.random_game_3",
        ),
        "gas_station_casino": (
            "fixed.service_lottery_desk",
            "fixed.service_refreshment_shelf",
            "fixed.random_game_2",
            "fixed.event_control_rail",
        ),
        "jazz_club": (
            "fixed.pulltab_game",
            "fixed.event_pull_tabs_sign",
            "fixed.random_game_1",
            "fixed.service_bar",
        ),
        "grand_casino": (
            "fixed.ticket_redeemer",
            "fixed.game_machine_5",
        ),
    }
    dynamic_actions = {
        "bar": PULL_TABS_HOST_ACTION_IDS,
        "gas_station_casino": (
            *PULL_TABS_HOST_ACTION_IDS,
            "game_hook:scratch_tickets:scratch_ticket_clerk",
        ),
        "jazz_club": PULL_TABS_HOST_ACTION_IDS,
        "grand_casino": PULL_TABS_HOST_ACTION_IDS,
    }
    for map_id, action_ids in dynamic_actions.items():
        map_data = maps[map_id]
        for action_id in action_ids:
            _remove_object_slot_assignment(map_data, action_id)
            map_data.setdefault("object_family_ids", {})[action_id] = "fixed"
            if isinstance(map_data.get("class_overrides"), dict):
                map_data["class_overrides"].pop(action_id, None)
            if isinstance(map_data.get("object_slot_positions"), dict):
                map_data["object_slot_positions"].pop(action_id, None)

    for map_id, map_data in maps.items():
        if map_id not in retired_slot_ids:
            continue
        retired_ids = set(retired_slot_ids[map_id])
        map_data["fixed_slots"] = [
            slot
            for slot in map_data.get("fixed_slots", []) or []
            if not isinstance(slot, dict)
            or str(slot.get("id", "")) not in retired_ids
        ]
        for family in FAMILIES:
            for suffix in ("object_slot_ids", "category_slot_ids"):
                preferences = map_data.get(f"{family}_{suffix}", {})
                if not isinstance(preferences, dict):
                    continue
                for claimant in list(preferences):
                    if str(preferences.get(claimant, "")) in retired_ids:
                        preferences.pop(claimant, None)

        # These category aliases represented the two synthetic Pull Tabs hook
        # rows. Gas keeps hook 0 because that row belongs to Scratch Tickets.
        categories = map_data.get("fixed_category_slot_ids", {})
        if isinstance(categories, dict):
            for category_id in list(categories):
                if str(category_id).startswith("game_hook_spots:"):
                    categories.pop(category_id, None)

    jazz = maps["jazz_club"]
    jazz["fixed_objects"] = [
        value
        for value in jazz.get("fixed_objects", []) or []
        if not isinstance(value, dict)
        or str(value.get("object_id", "")) != "jazz_club:pulltab_game"
    ]
    retired_exits = {"exit.left_upper", "exit.left_middle"}
    jazz["exit_slots"] = [
        slot
        for slot in jazz.get("exit_slots", []) or []
        if not isinstance(slot, dict) or str(slot.get("id", "")) not in retired_exits
    ]
    for suffix in ("object_slot_ids", "category_slot_ids"):
        preferences = jazz.get(f"exit_{suffix}", {})
        if not isinstance(preferences, dict):
            continue
        for claimant in list(preferences):
            if str(preferences.get(claimant, "")) in retired_exits:
                preferences.pop(claimant, None)

    bar_categories = maps["bar"].get("fixed_category_slot_ids", {})
    if isinstance(bar_categories, dict):
        for category_id in list(bar_categories):
            if str(category_id).startswith("game_spots:"):
                bar_categories.pop(category_id, None)
        bar_categories.update({
            "game_spots:0": "fixed.random_game_1",
            "game_spots:1": "fixed.random_game_2",
        })

    gas = maps["gas_station_casino"]
    for object_id in ("game:coin_pusher", "game:slot", "game:video_poker"):
        _assign_object_slot(gas, "fixed", object_id, "fixed.random_game_1")
        gas.setdefault("class_overrides", {})[object_id] = "floor_fixture"
    gas_categories = gas.get("fixed_category_slot_ids", {})
    if isinstance(gas_categories, dict):
        for category_id in list(gas_categories):
            if str(category_id).startswith("game_spots:"):
                gas_categories.pop(category_id, None)
        gas_categories.update({
            "game_spots:0": "fixed.random_game_1",
            "game_spots:1": "fixed.game_scratch_tickets",
        })

    # Grand's fifth machine was the standalone Pull Tabs fixture.  Keep the
    # four machine rows, then close the category sequence over the two table
    # rows so Blackjack and Craps retain deterministic physical geometry.
    grand_categories = maps["grand_casino"].get("fixed_category_slot_ids", {})
    if isinstance(grand_categories, dict):
        for category_id in list(grand_categories):
            if str(category_id).startswith("game_spots:"):
                grand_categories.pop(category_id, None)
        for ordinal, slot_id in enumerate(
            (
                "fixed.game_machine_1",
                "fixed.game_machine_2",
                "fixed.game_machine_3",
                "fixed.game_machine_4",
                "fixed.game_table_left",
                "fixed.game_table_right",
            )
        ):
            grand_categories[f"game_spots:{ordinal}"] = slot_id


def _scenario_capacity_plan(
    map_data: dict[str, Any],
) -> tuple[set[str], dict[str, str | None]]:
    """Return retained ids and the deterministic old-id disposition map."""

    map_id = str(map_data.get("id", ""))
    targets = SCENARIO_CAPACITY_TARGETS.get(map_id)
    if targets is None:
        raise ValueError(f"{map_id}: scenario consolidation target is missing")
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    slots = [
        slot
        for slot in map_data.get("scenario_slots", []) or []
        if isinstance(slot, dict)
    ]
    for slot in slots:
        grouped[str(slot.get("footprint_class", ""))].append(slot)

    forced_ids: set[str] = set(_runtime_person_capacity_targets().get(map_id, ()))
    keep_ids: set[str] = set()
    mapping: dict[str, str | None] = {}
    for placement_class, class_slots in grouped.items():
        target_count = int(targets.get(placement_class, 0))
        if target_count > len(class_slots):
            raise ValueError(
                f"{map_id}: scenario target needs {target_count} {placement_class} rows, "
                f"but only {len(class_slots)} exist"
            )
        selected = list(class_slots[:target_count])
        for forced_id in sorted(forced_ids):
            forced_slot = next(
                (
                    slot
                    for slot in class_slots
                    if str(slot.get("id", "")) == forced_id
                ),
                None,
            )
            if forced_slot is None or forced_slot in selected or target_count <= 0:
                continue
            replace_index = next(
                (
                    index
                    for index in range(len(selected) - 1, -1, -1)
                    if str(selected[index].get("id", "")) not in forced_ids
                ),
                None,
            )
            if replace_index is None:
                raise ValueError(f"{map_id}: cannot retain forced reserve {forced_id}")
            selected[replace_index] = forced_slot
        selected.sort(key=lambda slot: class_slots.index(slot))
        selected_ids = [str(slot.get("id", "")) for slot in selected]
        keep_ids.update(selected_ids)
        for index, slot in enumerate(class_slots):
            slot_id = str(slot.get("id", ""))
            mapping[slot_id] = (
                slot_id
                if slot_id in keep_ids
                else selected_ids[index % len(selected_ids)]
                if selected_ids
                else None
            )
    return keep_ids, mapping


def _rewrite_scenario_slot_references(
    map_data: dict[str, Any], mapping: dict[str, str | None]
) -> None:
    for field in (
        "scenario_object_slot_ids",
        "scenario_category_slot_ids",
        "scenario_slot_ids",
    ):
        preferences = map_data.get(field, {})
        if not isinstance(preferences, dict):
            continue
        for claimant in list(preferences):
            old_slot_id = str(preferences.get(claimant, ""))
            if old_slot_id not in mapping:
                continue
            target = mapping[old_slot_id]
            if target:
                preferences[claimant] = target
            else:
                preferences.pop(claimant, None)

    current_slots = {
        str(slot.get("id", "")): slot
        for slot in map_data.get("scenario_slots", []) or []
        if isinstance(slot, dict)
    }
    retained_by_class: dict[str, list[str]] = defaultdict(list)
    keep_ids = {target for target in mapping.values() if target}
    for slot in map_data.get("scenario_slots", []) or []:
        if not isinstance(slot, dict):
            continue
        slot_id = str(slot.get("id", ""))
        if slot_id in keep_ids:
            retained_by_class[str(slot.get("footprint_class", ""))].append(slot_id)

    for route in map_data.get("actor_routes", []) or []:
        if not isinstance(route, dict):
            continue
        original: dict[str, str] = {}
        for field in ("start_slot_id", "end_slot_id", "reduced_motion_slot_id"):
            old_slot_id = str(route.get(field, "")).strip()
            original[field] = old_slot_id
            if old_slot_id in mapping:
                target = mapping[old_slot_id]
                if target:
                    route[field] = target
                else:
                    route.pop(field, None)
        start_id = str(route.get("start_slot_id", ""))
        end_id = str(route.get("end_slot_id", ""))
        if start_id and start_id == end_id:
            old_start = current_slots.get(original.get("start_slot_id", ""), {})
            placement_class = str(old_start.get("footprint_class", ""))
            alternative = next(
                (
                    slot_id
                    for slot_id in retained_by_class.get(placement_class, [])
                    if slot_id != start_id
                ),
                "",
            )
            if not alternative:
                raise ValueError(
                    f"{map_data.get('id', '<unknown>')}: route {route.get('id', '')} "
                    "lost a distinct scenario endpoint"
                )
            route["end_slot_id"] = alternative


def _normalize_event_capacity_consolidation(
    maps: dict[str, dict[str, Any]],
) -> None:
    """Apply the reviewed ambient-event bank and merge retired aliases."""

    if set(maps) != set(EVENT_CAPACITY_TARGETS):
        raise ValueError("event consolidation target coverage drift")
    for map_id, map_data in maps.items():
        grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for slot in map_data.get("event_slots", []) or []:
            if isinstance(slot, dict):
                grouped[str(slot.get("footprint_class", ""))].append(slot)
        mapping: dict[str, str | None] = {}
        keep_ids: set[str] = set()
        for placement_class, class_slots in grouped.items():
            target_count = int(EVENT_CAPACITY_TARGETS[map_id].get(placement_class, 0))
            if target_count > len(class_slots):
                raise ValueError(
                    f"{map_id}: event target needs {target_count} {placement_class} rows, "
                    f"but only {len(class_slots)} exist"
                )
            selected_ids = [
                str(slot.get("id", "")) for slot in class_slots[:target_count]
            ]
            keep_ids.update(selected_ids)
            for index, slot in enumerate(class_slots):
                slot_id = str(slot.get("id", ""))
                mapping[slot_id] = (
                    slot_id
                    if slot_id in keep_ids
                    else selected_ids[index % len(selected_ids)]
                    if selected_ids
                    else None
                )
        for field in ("event_object_slot_ids", "event_category_slot_ids"):
            preferences = map_data.get(field, {})
            if not isinstance(preferences, dict):
                continue
            for claimant in list(preferences):
                source_id = str(preferences.get(claimant, ""))
                if source_id not in mapping:
                    continue
                target_id = mapping[source_id]
                if target_id:
                    preferences[claimant] = target_id
                else:
                    preferences.pop(claimant, None)
        slots_by_id = {
            str(slot.get("id", "")): slot
            for slot in map_data.get("event_slots", []) or []
            if isinstance(slot, dict)
        }
        for source_id, target_id in mapping.items():
            if not target_id or source_id == target_id:
                continue
            source = slots_by_id.get(source_id, {})
            target = slots_by_id.get(target_id, {})
            source_origins = source.get(CONSOLIDATION_ORIGIN_FIELD, [])
            target_origins = target.get(CONSOLIDATION_ORIGIN_FIELD, [])
            if (
                (CONSOLIDATION_ORIGIN_FIELD in source
                 or CONSOLIDATION_ORIGIN_FIELD in target)
                and isinstance(source_origins, list)
                and isinstance(target_origins, list)
            ):
                target[CONSOLIDATION_ORIGIN_FIELD] = sorted(
                    set(str(value) for value in [*target_origins, *source_origins])
                )
        map_data["event_slots"] = [
            slot
            for slot in map_data.get("event_slots", []) or []
            if isinstance(slot, dict) and str(slot.get("id", "")) in keep_ids
        ]
        actual: dict[str, int] = defaultdict(int)
        for slot in map_data["event_slots"]:
            actual[str(slot.get("footprint_class", ""))] += 1
        expected = {
            placement_class: count
            for placement_class, count in EVENT_CAPACITY_TARGETS[map_id].items()
            if count > 0
        }
        if dict(actual) != expected:
            raise ValueError(
                f"{map_id}: consolidated event bank differs: "
                f"expected={expected} actual={dict(actual)}"
            )


def _normalize_scenario_capacity_consolidation(
    maps: dict[str, dict[str, Any]],
) -> None:
    """Apply the reviewed physical-class bank across all 21 effective maps."""

    if set(maps) != set(SCENARIO_CAPACITY_TARGETS):
        raise ValueError(
            "scenario consolidation coverage drift: "
            f"maps={sorted(set(maps) - set(SCENARIO_CAPACITY_TARGETS))} "
            f"targets={sorted(set(SCENARIO_CAPACITY_TARGETS) - set(maps))}"
        )
    for map_id, map_data in maps.items():
        grouped_ids: dict[str, list[str]] = defaultdict(list)
        for slot in map_data.get("scenario_slots", []) or []:
            if isinstance(slot, dict):
                grouped_ids[str(slot.get("footprint_class", ""))].append(
                    str(slot.get("id", ""))
                )
        canonical = any(
            slot_id.startswith("scenario.standing_person_")
            or slot_id.startswith("scenario.floor_fixture_")
            for slot_ids in grouped_ids.values()
            for slot_id in slot_ids
        )
        for placement_class, target_count in SCENARIO_CAPACITY_TARGETS[map_id].items():
            while len(grouped_ids.get(placement_class, [])) < target_count:
                sources = tuple(grouped_ids.get(placement_class, []))
                if not sources:
                    raise ValueError(
                        f"{map_id}: cannot provision {placement_class} without source geometry"
                    )
                role_table = GENERIC_ROLE if canonical else V1_INTERMEDIATE_ROLE
                role = role_table[placement_class]
                slot_id = f"scenario.{role}_{len(grouped_ids[placement_class]) + 1}"
                _ensure_provisional_slot(
                    map_data,
                    "scenario",
                    slot_id,
                    placement_class,
                    sources,
                    (18.0 * len(grouped_ids[placement_class]), 12.0),
                )
                introduced = _slot_by_id(map_data, slot_id)
                if introduced is not None and CONSOLIDATION_ORIGIN_FIELD in introduced:
                    introduced[CONSOLIDATION_ORIGIN_FIELD] = []
                grouped_ids[placement_class].append(slot_id)
        keep_ids, mapping = _scenario_capacity_plan(map_data)
        _rewrite_scenario_slot_references(map_data, mapping)
        slots_by_id = {
            str(slot.get("id", "")): slot
            for slot in map_data.get("scenario_slots", []) or []
            if isinstance(slot, dict)
        }
        for source_id, target_id in mapping.items():
            if not target_id or source_id == target_id:
                continue
            source = slots_by_id.get(source_id, {})
            target = slots_by_id.get(target_id, {})
            source_origins = source.get(CONSOLIDATION_ORIGIN_FIELD, [])
            target_origins = target.get(CONSOLIDATION_ORIGIN_FIELD, [])
            if (
                (CONSOLIDATION_ORIGIN_FIELD in source
                 or CONSOLIDATION_ORIGIN_FIELD in target)
                and isinstance(source_origins, list)
                and isinstance(target_origins, list)
            ):
                target[CONSOLIDATION_ORIGIN_FIELD] = sorted(
                    set(str(value) for value in [*target_origins, *source_origins])
                )
        map_data["scenario_slots"] = [
            slot
            for slot in map_data.get("scenario_slots", []) or []
            if isinstance(slot, dict) and str(slot.get("id", "")) in keep_ids
        ]
        actual: dict[str, int] = defaultdict(int)
        for slot in map_data["scenario_slots"]:
            actual[str(slot.get("footprint_class", ""))] += 1
        expected = {
            placement_class: count
            for placement_class, count in SCENARIO_CAPACITY_TARGETS[map_id].items()
            if count > 0
        }
        if dict(actual) != expected:
            raise ValueError(
                f"{map_id}: consolidated scenario bank differs: "
                f"expected={expected} actual={dict(actual)}"
            )


def _physical_role(slot: dict[str, Any], declaration_label: str = "") -> str:
    if declaration_label:
        return declaration_label
    slot_id = str(slot.get("id", ""))
    placement_class = str(slot.get("footprint_class", ""))
    if "musician_" in slot_id:
        return "Musician"
    if "tip_jar" in slot_id:
        return "Tip jar"
    if "band_stage" in slot_id:
        return "Performance stage"
    if ".item_shop_" in slot_id:
        return "Shop item"
    if slot_id.startswith("fixed.home_container_"):
        return f"Home container {slot_id.rsplit('_', 1)[-1]}"
    if slot_id.startswith("fixed.home_item_"):
        return f"Home item {slot_id.rsplit('_', 1)[-1]}"
    if slot_id.startswith("fixed.random_game_"):
        return "Random game"
    if slot_id.startswith("fixed.game_machine_"):
        return "Random game machine"
    if slot_id.startswith(("fixed.game_table_", "fixed.game_floor_")):
        return "Random game table"
    if slot_id.startswith(("fixed.machine_game_", "fixed.table_game_")):
        return "Random game fixture"
    if slot_id == "exit.motel_room":
        return "Owned motel-room entrance"
    if slot_id.startswith("exit."):
        return "Travel exit"
    semantic_roles = {
        "fixed.crew_group": "The Crew",
        "fixed.lender_floor_1": "Visiting lender",
        "fixed.lender_visitor": "Visiting lender",
        "fixed.lender_street_lender": "Street lender",
        "fixed.lender_motel_friend": "Motel friend lender",
        "fixed.lender_person_1": "Individual lender",
        "fixed.lender_group_1": "Lender group",
        "fixed.lender_sals_pawn_counter": "Sal's lender counter",
        "fixed.staff_street_lender": "Street lender",
        "fixed.staff_merchant": "Merchant",
        "fixed.patron_bishop": "Bishop",
        "fixed.item_counter_phone": "Counter phone",
        "fixed.numbers_book": "Numbers book",
        "fixed.service_house_drink": "House drink service",
        "fixed.service_two_drink_minimum": "Two-drink minimum service",
        "fixed.service_stage": "Two-drink minimum service",
        "fixed.service_stage_left": "Two-drink minimum service",
        "fixed.service_kitty_champagne": "Champagne service",
        "fixed.service_deck_walk": "Riverboat deck walk",
        "fixed.service_beach_sand_pile": "Beach sand pile",
        "fixed.game_coin_pusher": "Coin pusher",
        "fixed.game_scratch_tickets": "Scratch ticket display",
        "fixed.game_video_poker": "Video poker machine",
        "fixed.game_slot": "Slot machine",
        "fixed.game_blackjack": "Blackjack table",
        "fixed.game_roulette": "Roulette table",
        "fixed.game_crew_draw_poker": "Crew draw-poker table",
        "fixed.door_right_lower": "Side door",
        "fixed.door_side_event": "Side door",
        "fixed.ambient_stage": "Comedy-club stage",
        "fixed.ambient_rook": "Rook",
        "fixed.event_planning_table": "Crew planning table",
        "fixed.event_numbers_desk": "Numbers desk",
        "fixed.event_job_board": "Crew job board",
        "fixed.event_mags_bench": "Mags' bench",
        "fixed.event_practice_rig": "Crew practice rig",
        "fixed.event_rook_ride": "Rook's ride",
        "fixed.event_grand_casino_invite": "Grand Casino invitation",
        "fixed.fixture_host_desk": "Casino host desk",
        "fixed.fixture_cage_counter": "Cashier cage counter",
        "fixed.fixture_cage_atm": "Cage ATM",
        "fixed.home_trade_up": "Home trade-up station",
        "fixed.home_tenure": "Home tenure status",
        "fixed.home_sleep": "Bed and sleep control",
        "fixed.home_upgrade": "Home upgrade board",
        "fixed.home_storage": "Home storage",
    }
    if slot_id in semantic_roles:
        return semantic_roles[slot_id]
    roles = {
        "standing_person": "Standing person",
        "behind_counter_person": "Counter staff",
        "seated_person": "Seated person",
        "group": "Group",
        "floor_fixture": "Floor prop",
        "ground_marker": "Floor marker",
        "surface_item": "Counter or table item",
        "shop_item": "Shop item",
        "wall_mounted": "Wall item",
        "hanging": "Hanging item",
        "doorway": "Doorway / exit",
    }
    return roles.get(placement_class, "Physical placement")


def _normalize_slot_authoring_metadata(payload: dict[str, Any]) -> None:
    """Give every slot a concise role, claimant list, and reserve contract."""

    maps = {
        str(map_data.get("id", "")): map_data
        for map_data in payload.get("maps", []) or []
        if isinstance(map_data, dict)
    }
    for map_id, map_data in maps.items():
        canonical_ids = _uses_canonical_reusable_slot_ids(
            {"maps": [map_data]}
        )
        occupants: dict[str, set[str]] = defaultdict(set)
        labels: dict[str, str] = {}
        for family in FAMILIES:
            preferences = map_data.get(f"{family}_object_slot_ids", {})
            if isinstance(preferences, dict):
                for object_id, slot_id in preferences.items():
                    occupants[str(slot_id)].add(str(object_id))
        preferences = map_data.get("scenario_slot_ids", {})
        if isinstance(preferences, dict):
            for identity, slot_id in preferences.items():
                stable_id = str(identity).split("|", 1)[0].strip()
                if stable_id:
                    occupants[str(slot_id)].add(stable_id)
        for route in map_data.get("actor_routes", []) or []:
            if not isinstance(route, dict):
                continue
            route_id = str(route.get("id", "")).strip()
            for field in ("start_slot_id", "end_slot_id", "reduced_motion_slot_id"):
                slot_id = str(route.get(field, "")).strip()
                if slot_id and route_id:
                    occupants[slot_id].add(f"route:{route_id}")
        for declaration in map_data.get("fixed_objects", []) or []:
            if not isinstance(declaration, dict):
                continue
            slot_id = str(declaration.get("exact_slot_id", ""))
            for field in ("object_id", "presentation_id"):
                occupant_id = str(declaration.get(field, "")).strip()
                if occupant_id:
                    occupants[slot_id].add(occupant_id)
            label = str(declaration.get("label", "")).strip()
            if label:
                labels[slot_id] = label

        # On the one-way conversion pass the reviewed reserve targets still use
        # the v1-intermediate ids.  A maintenance refresh sees canonical ids,
        # so carry the already-authored semantic reserve marker instead of
        # trying to address the retired ``floor_patron`` spelling again.
        runtime_people = (
            {
                str(slot.get("id", ""))
                for slot in map_data.get("scenario_slots", []) or []
                if isinstance(slot, dict)
                and (
                    str(slot.get("physical_role", ""))
                    == "Runtime contact reserve"
                    or str(slot.get("reserve_reason", "")).startswith(
                        "Injected chain, traveler, or delivery contact"
                    )
                )
            }
            if canonical_ids
            else set(_runtime_person_capacity_targets().get(map_id, ()))
        )
        scenario_wall_ids = [
            str(slot.get("id", ""))
            for slot in map_data.get("scenario_slots", []) or []
            if isinstance(slot, dict)
            and str(slot.get("footprint_class", "")) == "wall_mounted"
        ]
        delivery_wall_id = scenario_wall_ids[-1] if scenario_wall_ids else ""
        scenario_floor_ids = [
            str(slot.get("id", ""))
            for slot in map_data.get("scenario_slots", []) or []
            if isinstance(slot, dict)
            and str(slot.get("footprint_class", "")) == "floor_fixture"
        ]
        heist_floor_id = (
            scenario_floor_ids[-1]
            if map_id in HEIST_LIVE_TABLE_MAP_IDS and scenario_floor_ids
            else ""
        )
        delivery_floor_id = (
            scenario_floor_ids[-2]
            if heist_floor_id and len(scenario_floor_ids) >= 2
            else scenario_floor_ids[-1]
            if scenario_floor_ids
            else ""
        )
        beach_recruitment_id = (
            "scenario.floor_patron_5" if map_id == "beach" and not canonical_ids else ""
        )
        event_exact_ids = {
            str(slot_id)
            for slot_id in (
                map_data.get("event_object_slot_ids", {}).values()
                if isinstance(map_data.get("event_object_slot_ids"), dict)
                else []
            )
        }
        event_category_ids = {
            str(slot_id)
            for slot_id in (
                map_data.get("event_category_slot_ids", {}).values()
                if isinstance(map_data.get("event_category_slot_ids"), dict)
                else []
            )
        }
        for family in FAMILIES:
            for slot in map_data.get(f"{family}_slots", []) or []:
                if not isinstance(slot, dict):
                    continue
                slot_id = str(slot.get("id", ""))
                previous_role = str(slot.get("physical_role", "")).strip()
                reserve_reason = (
                    str(slot.get("reserve_reason", ""))
                    if bool(slot.get("runtime_reserve", False))
                    else ""
                )
                if slot_id in runtime_people:
                    reserve_reason = (
                        "Injected chain, traveler, or delivery contact can coexist "
                        "with the authored scenario cast."
                    )
                elif family == "scenario" and slot_id == delivery_wall_id:
                    reserve_reason = (
                        "Runtime delivery or chain state can add a held wall object "
                        "beside the authored scenario inventory."
                    )
                elif family == "scenario" and slot_id == heist_floor_id:
                    reserve_reason = (
                        "The Crew's live table can follow the player into this room "
                        "beside authored scenario objects."
                    )
                elif family == "scenario" and slot_id == delivery_floor_id:
                    reserve_reason = (
                        "Runtime delivery state can add a package or floor prop "
                        "beside the authored scenario inventory."
                    )
                elif (
                    map_id == "bar"
                    and family == "scenario"
                    and slot_id in {
                        "scenario.seated_patron_2",
                        "scenario.seated_person_2",
                    }
                ):
                    reserve_reason = (
                        "Knuckles recruitment can coexist with the Fight Night seated actor."
                    )
                elif (
                    map_id == "beach"
                    and family == "scenario"
                    and slot_id == beach_recruitment_id
                ):
                    reserve_reason = (
                        "Lucky recruitment can coexist with the Festival scenario cast."
                    )
                elif (
                    family == "event"
                    and slot_id not in event_exact_ids
                    and slot_id not in event_category_ids
                ):
                    reserve_reason = (
                        "Independent ambient traveler, Crew, or Numbers presence may "
                        "coexist with mapped room events."
                    )
                physical_role = _physical_role(slot, labels.get(slot_id, ""))
                if slot_id in runtime_people:
                    physical_role = "Runtime contact reserve"
                elif slot_id == delivery_wall_id and family == "scenario":
                    physical_role = "Delivery hold reserve"
                elif slot_id == heist_floor_id and family == "scenario":
                    physical_role = "Crew live-table reserve"
                elif slot_id == delivery_floor_id and family == "scenario":
                    physical_role = "Delivery package reserve"
                elif reserve_reason and (
                    (
                        map_id == "bar"
                        and slot_id in {
                            "scenario.seated_patron_2",
                            "scenario.seated_person_2",
                        }
                    )
                    or (map_id == "beach" and slot_id == beach_recruitment_id)
                ):
                    physical_role = "Recruitment contact reserve"
                elif reserve_reason and previous_role:
                    # Preserve semantic roles whose first-pass target was
                    # selected before canonical ids were assigned (notably the
                    # Beach recruitment reserve).
                    physical_role = previous_role
                slot["physical_role"] = physical_role
                slot["occupant_ids"] = sorted(occupants.get(slot_id, set()))
                slot["runtime_reserve"] = bool(reserve_reason)
                slot["reserve_reason"] = reserve_reason


def _normalize_reusable_slot_ids(payload: dict[str, Any]) -> None:
    """Rename event/scenario pools by physical role and rewrite all references."""

    for map_data in payload.get("maps", []) or []:
        if not isinstance(map_data, dict):
            continue
        family_mappings: dict[str, dict[str, str]] = {}
        for family in ("event", "scenario"):
            counters: dict[str, int] = defaultdict(int)
            mapping: dict[str, str] = {}
            for slot in map_data.get(f"{family}_slots", []) or []:
                if not isinstance(slot, dict):
                    continue
                old_slot_id = str(slot.get("id", ""))
                placement_class = str(slot.get("footprint_class", ""))
                role = GENERIC_ROLE.get(placement_class)
                if not role:
                    raise ValueError(
                        f"{map_data.get('id', '<unknown>')}.{old_slot_id}: "
                        f"no canonical role for {placement_class}"
                    )
                counters[role] += 1
                new_slot_id = f"{family}.{role}_{counters[role]}"
                mapping[old_slot_id] = new_slot_id
                slot["id"] = new_slot_id
                slot["kind"] = family
            if len(set(mapping.values())) != len(mapping):
                raise ValueError(
                    f"{map_data.get('id', '<unknown>')}: duplicate canonical {family} ids"
                )
            family_mappings[family] = mapping
            for suffix in ("object_slot_ids", "category_slot_ids"):
                preferences = map_data.get(f"{family}_{suffix}", {})
                if not isinstance(preferences, dict):
                    continue
                for claimant, old_slot_id_value in list(preferences.items()):
                    old_slot_id = str(old_slot_id_value)
                    if old_slot_id in mapping:
                        preferences[claimant] = mapping[old_slot_id]

        scenario_mapping = family_mappings["scenario"]
        preferences = map_data.get("scenario_slot_ids", {})
        if isinstance(preferences, dict):
            for claimant, old_slot_id_value in list(preferences.items()):
                old_slot_id = str(old_slot_id_value)
                if old_slot_id in scenario_mapping:
                    preferences[claimant] = scenario_mapping[old_slot_id]
        for route in map_data.get("actor_routes", []) or []:
            if not isinstance(route, dict):
                continue
            for field in ("start_slot_id", "end_slot_id", "reduced_motion_slot_id"):
                old_slot_id = str(route.get(field, "")).strip()
                if old_slot_id in scenario_mapping:
                    route[field] = scenario_mapping[old_slot_id]


def _remove_slot_rows_and_references(
    map_data: dict[str, Any], slot_ids: set[str]
) -> None:
    """Retire reviewed rows after their live claimants have been rehomed."""

    for family in FAMILIES:
        slot_field = f"{family}_slots"
        map_data[slot_field] = [
            slot
            for slot in map_data.get(slot_field, []) or []
            if not isinstance(slot, dict)
            or str(slot.get("id", "")) not in slot_ids
        ]
        for suffix in ("object_slot_ids", "category_slot_ids"):
            preferences = map_data.get(f"{family}_{suffix}", {})
            if not isinstance(preferences, dict):
                continue
            for claimant, slot_id in list(preferences.items()):
                if str(slot_id) in slot_ids:
                    preferences.pop(claimant, None)

    scenario_preferences = map_data.get("scenario_slot_ids", {})
    if isinstance(scenario_preferences, dict):
        for claimant, slot_id in list(scenario_preferences.items()):
            if str(slot_id) in slot_ids:
                scenario_preferences.pop(claimant, None)


def _normalize_reviewed_shared_authority(
    maps: dict[str, dict[str, Any]],
) -> None:
    """Apply the final shared-slot audit findings in canonical slot names."""

    motel = maps["motel"]
    motel_positions = motel.setdefault("object_slot_positions", {})
    motel_classes = motel.setdefault("class_overrides", {})
    for object_id in (
        "event:chain06_dave_same_bus",
        "event:chain06_dave_last_stop",
    ):
        # These are mutually exclusive appearances by the same speaking traveler,
        # so they share one standing-person event position rather than masquerading
        # as two independent counter props.
        _assign_object_slot(
            motel, "event", object_id, "event.standing_person_1"
        )
        motel_classes[object_id] = "standing_person"
        motel_positions.pop(object_id, None)

    delta = maps["delta_queen"]
    delta_assignments = {
        "event:chain06_cass_first_contact": (
            "event.standing_person_1",
            "standing_person",
        ),
        "event:chain06_dave_same_bus": (
            "event.standing_person_2",
            "standing_person",
        ),
        "event:rowdy_regular": (
            "event.seated_person_1",
            "seated_person",
        ),
    }
    delta_positions = delta.setdefault("object_slot_positions", {})
    delta_classes = delta.setdefault("class_overrides", {})
    for object_id, (slot_id, placement_class) in delta_assignments.items():
        _assign_object_slot(delta, "event", object_id, slot_id)
        delta_classes[object_id] = placement_class
        delta_positions.pop(object_id, None)
    for override in delta.get("scenario_overrides", {}).values():
        if not isinstance(override, dict):
            continue
        class_overrides = override.get("class_overrides", {})
        if isinstance(class_overrides, dict):
            class_overrides.pop("event:rowdy_regular", None)
        object_positions = override.get("object_slot_positions", {})
        if isinstance(object_positions, dict):
            object_positions.pop("event:rowdy_regular", None)

    # World travel is a doorway in both rooms. The old surface/person classes
    # made the manual editor describe the destination as the wrong kind of thing.
    exit_repairs = {
        "motel": (
            "exit.door_curtain",
            "curtain_passage",
        ),
        "bar": (
            "exit.travel_right",
            "right_exit",
        ),
    }
    for map_id, (slot_id, support_id) in exit_repairs.items():
        slot = _slot_by_id(maps[map_id], slot_id)
        if slot is None:
            raise ValueError(f"{map_id}: missing reviewed travel exit {slot_id}")
        slot["footprint_class"] = "doorway"
        slot["physical_role"] = "Travel doorway"
        slot["support_id"] = support_id
        slot["facing"] = "front"
        slot["walk_lane_ids"] = ["lane.public"]

    pawn = maps["pawn_shop"]
    pawn_action_ids = (
        "shopkeeper:merchant",
        "lender:sals_pawn_counter",
        "meta_pawn_counter:sell",
        "meta_sal:talk",
    )
    _attach_actions_to_fixed_host(pawn, "pawn_shop:sal", pawn_action_ids)
    duplicate_pawn_slots = {
        "fixed.staff_merchant",
        "fixed.lender_sals_pawn_counter",
    }
    _remove_slot_rows_and_references(pawn, duplicate_pawn_slots)
    fixed_categories = pawn.get("fixed_category_slot_ids", {})
    if isinstance(fixed_categories, dict):
        for category_id in list(fixed_categories):
            if str(category_id).startswith(
                ("shopkeeper_spots:", "lender_spots:", "pawn_counter_spots:")
            ):
                fixed_categories.pop(category_id, None)


def _normalize_slot_field_order(payload: dict[str, Any]) -> None:
    order = (
        "id", "kind", "pos", "footprint_class", "physical_role",
        "occupant_ids", "runtime_reserve", "reserve_reason", "hit_rect",
        "label_anchor", "facing", "priority", "zone_id", "support_id",
        "walk_lane_ids", "occupancy_required",
    )
    for map_data in payload.get("maps", []) or []:
        if not isinstance(map_data, dict):
            continue
        for family in FAMILIES:
            for slot in map_data.get(f"{family}_slots", []) or []:
                if not isinstance(slot, dict):
                    continue
                if not slot.get(CONSOLIDATION_ORIGIN_FIELD):
                    slot.pop(CONSOLIDATION_ORIGIN_FIELD, None)
                reordered = {field: slot[field] for field in order if field in slot}
                reordered.update(
                    (field, value)
                    for field, value in slot.items()
                    if field not in reordered
                )
                slot.clear()
                slot.update(reordered)


def _uses_canonical_reusable_slot_ids(payload: dict[str, Any]) -> bool:
    return any(
        isinstance(slot, dict)
        and (
            str(slot.get("id", "")).startswith("event.standing_person_")
            or str(slot.get("id", "")).startswith("scenario.floor_fixture_")
        )
        for map_data in payload.get("maps", []) or []
        if isinstance(map_data, dict)
        for family in ("event", "scenario")
        for slot in map_data.get(f"{family}_slots", []) or []
    )


def _apply_slot_consolidation(payload: dict[str, Any]) -> None:
    maps = {
        str(map_data.get("id", "")): map_data
        for map_data in payload.get("maps", []) or []
        if isinstance(map_data, dict)
    }
    _retire_pull_tabs_standalone_rows(maps)
    _normalize_descriptive_fixed_ids(maps)
    _normalize_back_alley_meta_home_capacity(maps)
    _normalize_scenario_instance_classes(maps)
    _normalize_fixed_game_authority(maps)
    _normalize_exit_authority(maps)
    _retire_unreachable_slots(maps)
    # Fixed host declarations are authoritative even after the file has
    # reached canonical reusable-slot form. Reapply only the declarations here;
    # their legacy geometry provisioning has already been consolidated.
    _normalize_guaranteed_host_declarations(maps)
    beach_event_people = [
        slot
        for slot in maps["beach"].get("event_slots", []) or []
        if isinstance(slot, dict)
        and str(slot.get("footprint_class", "")) == "standing_person"
    ]
    if not beach_event_people:
        # Crew Favor can choose any reachable public venue, including Beach.
        # Canonical reviewed files therefore need one shared event-person row
        # even though Beach has no ordinary random-event pool of its own.
        _ensure_provisional_slot(
            maps["beach"],
            "event",
            "event.standing_person_1",
            "standing_person",
            ("fixed.service_beach_sand_pile",),
        )
    beach_delivery_slot = next(
        (
            slot
            for slot in maps["beach"].get("event_slots", []) or []
            if isinstance(slot, dict)
            and str(slot.get("footprint_class", "")) == "standing_person"
        ),
        None,
    )
    if beach_delivery_slot is None:
        raise ValueError("beach: delivery/event person capacity is missing")
    _set_person_slot_geometry(
        beach_delivery_slot,
        (788.0, 406.0),
        "standing_person",
        "floor",
        72.0,
        80.0,
    )
    beach_delivery_slot["facing"] = "right"
    beach_delivery_slot["physical_role"] = "Delivery handoff contact"
    beach_delivery_slot["zone_id"] = "foreground"
    beach_delivery_slot["walk_lane_ids"] = ["lane.public"]
    beach_delivery_slot["priority"] = 10
    _normalize_event_capacity_consolidation(maps)
    _normalize_scenario_capacity_consolidation(maps)
    _normalize_slot_occupancy_metadata(payload)
    _normalize_slot_authoring_metadata(payload)
    _normalize_reusable_slot_ids(payload)
    _normalize_reviewed_shared_authority(maps)
    reviewed_maps = {
        "maps": [
            maps[map_id]
            for map_id in (
                "motel",
                "bar",
                "delta_queen",
                "pawn_shop",
                "small_underground_casino",
            )
        ]
    }
    _normalize_slot_occupancy_metadata(reviewed_maps)
    _normalize_slot_authoring_metadata(reviewed_maps)
    # Reviewed coordinates are expressed in the canonical reusable IDs. Apply
    # them after a fresh legacy conversion has completed that deterministic
    # rename, while remaining byte-idempotent for already canonical v2 data.
    _normalize_reviewed_slot_geometry(maps)
    _normalize_slot_field_order(payload)


def _normalize_baseline_fixed_slots(payload: dict[str, Any]) -> None:
    """Give mapped baseline objects fixed lifecycle ownership and capacity."""

    baseline_objects = baseline_objects_by_map()
    maps = {
        str(map_data.get("id", "")): map_data
        for map_data in payload.get("maps", [])
        if isinstance(map_data, dict)
    }
    mapped_house_drink_maps: set[str] = set()
    for map_id, map_data in maps.items():
        is_mapped = any(
            HOUSE_DRINK_OBJECT_ID in map_data.get(f"{family}_object_slot_ids", {})
            for family in FAMILIES
        )
        if HOUSE_DRINK_OBJECT_ID in baseline_objects.get(map_id, set()) and is_mapped:
            mapped_house_drink_maps.add(map_id)
    expected_maps = set(HOUSE_DRINK_SCENARIO_CAPACITY)
    if mapped_house_drink_maps != expected_maps:
        raise ValueError(
            "mapped baseline house-drink venues changed; review fixed provisioning: "
            f"expected={sorted(expected_maps)} actual={sorted(mapped_house_drink_maps)}"
        )

    for map_id, retained_slot_id in HOUSE_DRINK_SCENARIO_CAPACITY.items():
        map_data = maps[map_id]
        retained_slot = _slot_by_id(map_data, retained_slot_id)
        if retained_slot is None:
            # A fresh v1 conversion can classify the sole claimant as fixed
            # before a scenario clone exists. Recreate that reusable capacity
            # from the exact authored slot rather than relabeling/removing it.
            prior_slot_id = next(
                (
                    str(map_data.get(f"{family}_object_slot_ids", {}).get(HOUSE_DRINK_OBJECT_ID, ""))
                    for family in FAMILIES
                    if HOUSE_DRINK_OBJECT_ID in map_data.get(f"{family}_object_slot_ids", {})
                ),
                "",
            )
            prior_slot = _slot_by_id(map_data, prior_slot_id)
            if prior_slot is None:
                raise ValueError(f"{map_id}: baseline house drink has no authored source geometry")
            _ensure_provisional_slot(
                map_data,
                "scenario",
                retained_slot_id,
                str(prior_slot.get("footprint_class", "surface_item")),
                (prior_slot_id,),
            )
            retained_slot = _slot_by_id(map_data, retained_slot_id)
        if retained_slot is None or retained_slot.get("kind") != "scenario":
            raise ValueError(
                f"{map_id}: baseline house-drink repair lost reusable scenario capacity {retained_slot_id}"
            )
        _ensure_provisional_slot(
            map_data,
            "fixed",
            HOUSE_DRINK_FIXED_SLOT_ID,
            "surface_item",
            (retained_slot_id,),
            avoid_fixed_overlap=True,
            retained_capacity_ids=(retained_slot_id,),
        )
        _assign_object_slot(
            map_data,
            "fixed",
            HOUSE_DRINK_OBJECT_ID,
            HOUSE_DRINK_FIXED_SLOT_ID,
        )
        class_overrides = map_data.setdefault("class_overrides", {})
        if not isinstance(class_overrides, dict):
            raise ValueError(f"{map_id}: class_overrides must be an object")
        class_overrides[HOUSE_DRINK_OBJECT_ID] = "surface_item"


def _normalize_fixed_item_slots(payload: dict[str, Any]) -> None:
    """Normalize generated merchandise onto numbered fixed capacity rows."""

    for map_data in payload.get("maps", []):
        if not isinstance(map_data, dict):
            continue
        fixed_slots = [slot for slot in map_data.get("fixed_slots", []) if isinstance(slot, dict)]
        shop_slot_ids = sorted(
            str(slot.get("id", ""))
            for slot in fixed_slots
            if str(slot.get("footprint_class", "")) == "shop_item"
        )
        item_preferences = map_data.setdefault("fixed_object_slot_ids", {})
        category_preferences = map_data.setdefault("fixed_category_slot_ids", {})
        if not isinstance(item_preferences, dict) or not isinstance(category_preferences, dict):
            continue
        item_ids = sorted(str(key) for key in item_preferences if str(key).startswith("item:"))
        if not shop_slot_ids:
            if item_ids:
                raise ValueError(f"{map_data.get('id', '<unknown>')}: fixed items require at least one authored shop slot")
            continue

        used: set[str] = set()
        pending: list[str] = []
        for object_id in item_ids:
            slot_id = str(item_preferences.get(object_id, ""))
            slot = _slot_by_id(map_data, slot_id)
            if slot is not None and slot.get("kind") == "fixed" and slot.get("footprint_class") == "shop_item" and slot_id not in used:
                used.add(slot_id)
            else:
                pending.append(object_id)
        free = [slot_id for slot_id in shop_slot_ids if slot_id not in used]
        numeric_ids = [
            int(match.group(1))
            for slot_id in shop_slot_ids
            if (match := re.fullmatch(r"fixed\.item_shop_(\d+)", slot_id)) is not None
        ]
        next_ordinal = max(numeric_ids, default=0) + 1
        template_id = shop_slot_ids[0]
        for pending_index, object_id in enumerate(pending):
            if free:
                slot_id = free.pop(0)
            else:
                slot_id = f"fixed.item_shop_{next_ordinal}"
                next_ordinal += 1
                # A compact deterministic fan keeps every new shelf target
                # independently movable while retaining its venue-authored base.
                dx = float(((pending_index % 5) - 2) * 28)
                dy = float((pending_index // 5 + 1) * 24)
                _ensure_provisional_slot(map_data, "fixed", slot_id, "shop_item", (template_id,), (dx, dy))
            _assign_object_slot(map_data, "fixed", object_id, slot_id)

        # The durable object manifest assigns generated stock by live ordinal,
        # so identity-specific coordinates are no longer placement authority.
        # Retain lifecycle ownership in object_family_ids and make every row
        # explicitly consume fixed.item_shop_1..N.
        for object_id in item_ids:
            item_preferences.pop(object_id, None)
        shop_slot_ids = sorted(
            str(slot.get("id", ""))
            for slot in map_data.get("fixed_slots", [])
            if isinstance(slot, dict) and str(slot.get("footprint_class", "")) == "shop_item"
        )
        numeric_shop_slots = sorted(
            (
                (int(match.group(1)), slot_id)
                for slot_id in shop_slot_ids
                if (match := re.fullmatch(r"fixed\.item_shop_(\d+)", slot_id)) is not None
            ),
            key=lambda value: value[0],
        )
        for category_key in list(category_preferences):
            if str(category_key).startswith("item_spots:"):
                category_preferences.pop(category_key, None)
        for ordinal, (_, slot_id) in enumerate(numeric_shop_slots):
            category_preferences[f"item_spots:{ordinal}"] = slot_id


def apply_capacity_repairs(payload: dict[str, Any]) -> None:
    """Normalize known v2 capacity/provenance repairs on every migration run.

    These are deliberately provisional placements cloned from the venue's
    existing geometry. They make strict family ownership complete while leaving
    final visual placement to the in-game authoring tool.
    """

    if _uses_canonical_reusable_slot_ids(payload):
        _apply_slot_consolidation(payload)
        return

    maps = {
        str(map_data.get("id", "")): map_data
        for map_data in payload.get("maps", [])
        if isinstance(map_data, dict)
    }

    corner_store = maps["corner_store"]
    # Town rumor staff can be injected after the room's ordinary random events
    # are selected. Delivery-day seeds can therefore contain it alongside Late
    # Shift Discount, and both are physical behind-register event objects. Reuse
    # the otherwise-unclaimed auxiliary clerk geometry as a second event-family
    # slot instead of letting the late injection invalidate the sealed layout.
    _ensure_provisional_slot(
        corner_store,
        "event",
        "event.counter_patron_2",
        "behind_counter_person",
        ("fixed.staff_aux",),
    )
    corner_store["fixed_slots"] = [
        slot
        for slot in corner_store.get("fixed_slots", [])
        if not isinstance(slot, dict) or str(slot.get("id", "")) != "fixed.staff_aux"
    ]
    _assign_object_slot(
        corner_store,
        "event",
        "event:town_rumor_staff",
        "event.counter_patron_2",
    )

    motel = maps["motel"]
    _ensure_provisional_slot(
        motel,
        "fixed",
        "fixed.lender_motel_friend",
        "standing_person",
        ("fixed.patron_floor_right",),
        (-92.0, 0.0),
    )
    _assign_object_slot(motel, "fixed", "lender:motel_friend", "fixed.lender_motel_friend")
    # The brother-in-law is reached through the fixed counter phone. It is not
    # a second physical person standing in the motel room.
    _remove_object_slot_assignment(motel, "lender:brother_in_law")

    gas_station = maps["gas_station_casino"]
    _ensure_provisional_slot(
        gas_station,
        "fixed",
        "fixed.game_scratch_tickets",
        "floor_fixture",
        ("fixed.random_game_2",),
        (-96.0, 0.0),
    )
    _assign_object_slot(gas_station, "fixed", "game:scratch_tickets", "fixed.game_scratch_tickets")
    _ensure_provisional_slot(
        gas_station,
        "fixed",
        "fixed.numbers_book",
        "surface_item",
        ("fixed.service_lottery_desk",),
        (-200.0, 0.0),
    )
    _assign_object_slot(gas_station, "fixed", "numbers:book", "fixed.numbers_book")

    bar = maps["bar"]
    _ensure_provisional_slot(
        bar,
        "fixed",
        "fixed.numbers_book",
        "surface_item",
        ("fixed.ticket_redeemer",),
        (120.0, 0.0),
    )
    _assign_object_slot(bar, "fixed", "numbers:book", "fixed.numbers_book")
    # Fight Night can install the scenario swing-bet patron at the same time as
    # Knuckles' scenario-owned recruitment actor. Both resolve as seated people,
    # so the room needs two independent scenario-family seats rather than one
    # preferred hotspot shared by mutually live objects. This provisional upper
    # booth position is deliberately clear of the rest of the authored Bar
    # geometry and can be refined with placement mode later.
    _ensure_provisional_slot(
        bar,
        "scenario",
        "scenario.seated_patron_2",
        "seated_person",
        ("scenario.seated_patron_1",),
    )
    second_bar_scenario_seat = _slot_by_id(bar, "scenario.seated_patron_2")
    if second_bar_scenario_seat is None:
        raise ValueError("bar: second Fight Night scenario seat is missing")
    _set_person_slot_geometry(
        second_bar_scenario_seat,
        (600.0, 120.0),
        "seated_person",
        "provisional_booth",
        68.0,
        64.0,
    )

    punchline = maps["small_underground_casino"]
    _ensure_provisional_slot(
        punchline,
        "fixed",
        "fixed.game_video_poker",
        "floor_fixture",
        ("event.floor_item_1", "scenario.floor_item_1"),
        (18.0, 12.0),
    )
    _ensure_provisional_slot(
        punchline,
        "fixed",
        "fixed.service_two_drink_minimum",
        "surface_item",
        ("fixed.service_stage_left",),
        (36.0, 0.0),
    )
    _ensure_provisional_slot(
        punchline,
        "event",
        "event.surface_item_1",
        "surface_item",
        ("fixed.service_stage_left",),
        (-36.0, 12.0),
    )
    _ensure_provisional_slot(
        punchline,
        "event",
        "event.surface_item_2",
        "surface_item",
        ("fixed.numbers_stage_center",),
        (36.0, 12.0),
    )
    _ensure_provisional_slot(
        punchline,
        "event",
        "event.surface_item_3",
        "surface_item",
        ("scenario.surface_item_3", "fixed.service_stage_left"),
        (18.0, 12.0),
    )
    _ensure_provisional_slot(
        punchline,
        "event",
        "event.floor_item_2",
        "floor_fixture",
        ("event.floor_item_1",),
        (-152.0, 180.0),
    )
    _ensure_provisional_slot(
        punchline,
        "event",
        "event.doorway_1",
        "doorway",
        ("fixed.door_right_lower", "exit.door_right_lower"),
        (18.0, 12.0),
    )
    _assign_object_slot(punchline, "fixed", "game:video_poker", "fixed.game_video_poker")
    _assign_object_slot(
        punchline,
        "fixed",
        "service:punchline_two_drink_minimum",
        "fixed.service_two_drink_minimum",
    )
    for object_id, slot_id in {
        "event:crew_job_board": "event.wall_item_1",
        "event:crew_mags_bench": "event.surface_item_3",
        "event:crew_planning_table": "event.surface_item_1",
        "event:crew_practice_rig": "event.floor_item_2",
        "event:crew_rook_ride": "event.doorway_1",
        "event:numbers_desk": "event.surface_item_2",
    }.items():
        _assign_object_slot(punchline, "event", object_id, slot_id)

    casino = maps["small_underground_casino:casino"]
    # The casino layer omits required_event_ids and therefore inherits the
    # Punchline's guaranteed side door. Early v2 refreshes treated that omitted
    # field as an empty list and left the door in optional event capacity. Move
    # the existing authored row without changing any of its geometry. A fresh
    # v1 conversion already names this fixed.door_side_event, so the guard also
    # keeps the repair byte-idempotent.
    if _slot_by_id(casino, "fixed.door_side_event") is None:
        _relocate_slot(
            casino,
            "event.doorway_1",
            "fixed",
            "fixed.door_side_event",
            "doorway",
        )
    _assign_object_slot(
        casino,
        "fixed",
        "event:side_door",
        "fixed.door_side_event",
    )

    back_room = maps["small_underground_casino:back_room"]
    # These retain their event-catalog identities for gameplay dispatch, but
    # the back-room layer requires all six fixtures on every generation.
    for object_id, slot_id in {
        "event:crew_job_board": "fixed.event_job_board",
        "event:crew_mags_bench": "fixed.event_mags_bench",
        "event:crew_planning_table": "fixed.event_planning_table",
        "event:crew_practice_rig": "fixed.event_practice_rig",
        "event:crew_rook_ride": "fixed.event_rook_ride",
        "event:numbers_desk": "fixed.event_numbers_desk",
    }.items():
        _assign_object_slot(back_room, "fixed", object_id, slot_id)
    _ensure_provisional_slot(
        back_room,
        "fixed",
        "fixed.ambient_rook",
        "standing_person",
        ("scenario.floor_patron_1", "event.floor_patron_1"),
        avoid_fixed_overlap=True,
    )
    _assign_object_slot(back_room, "fixed", "environment_layer:ambient", "fixed.ambient_rook")

    club = maps["small_underground_casino:club"]
    _ensure_provisional_slot(
        club,
        "fixed",
        "fixed.ambient_stage",
        "floor_fixture",
        ("scenario.floor_item_1", "event.floor_item_1"),
    )
    # The ambient comic is a persistent room fixture, not navigation. The real
    # layer transition remains independently and explicitly exit-owned.
    _assign_object_slot(club, "fixed", "environment_layer:ambient", "fixed.ambient_stage")
    _assign_object_slot(club, "exit", "environment_layer:casino", "exit.door_side")

    kitty = maps["kitty_cat_lounge"]
    _ensure_provisional_slot(
        kitty,
        "fixed",
        "fixed.item_shop_3",
        "shop_item",
        ("fixed.item_shop_1",),
        (-120.0, 0.0),
    )
    _ensure_provisional_slot(
        kitty,
        "fixed",
        "fixed.service_kitty_champagne",
        "surface_item",
        ("fixed.random_game_2",),
        (-60.0, 48.0),
    )
    _ensure_provisional_slot(
        kitty,
        "event",
        "event.doorway_1",
        "doorway",
        ("scenario.doorway_1", "exit.door_right_upper"),
        (0.0, 48.0),
    )
    _assign_object_slot(kitty, "fixed", "item:foil_sleeve", "fixed.item_shop_3")
    _assign_object_slot(
        kitty,
        "fixed",
        "service:kitty_champagne",
        "fixed.service_kitty_champagne",
    )
    _assign_object_slot(kitty, "event", "event:side_door", "event.doorway_1")

    delta_queen = maps["delta_queen"]
    _ensure_provisional_slot(
        delta_queen,
        "event",
        "event.floor_patron_1",
        "standing_person",
        ("event.seated_patron_1", "scenario.floor_patron_1"),
        (72.0, 0.0),
    )
    _assign_object_slot(delta_queen, "event", "event:rowdy_regular", "event.floor_patron_1")

    back_alley = maps["back_alley"]
    # Craps is absent from the Back Alley baseline and exists only while the
    # Street Craps scenario owns it. Keep the game on generic scenario furniture
    # capacity instead of letting the legacy game_spots category classify it as
    # a fixed room object.
    _assign_object_slot(back_alley, "scenario", "game:craps", "scenario.floor_item_1")
    back_alley.setdefault("class_overrides", {})["game:craps"] = "floor_fixture"

    _ensure_provisional_slot(
        punchline,
        "fixed",
        "fixed.game_slot",
        "floor_fixture",
        ("fixed.game_video_poker",),
        (-120.0, 0.0),
    )
    _ensure_provisional_slot(
        punchline,
        "fixed",
        "fixed.staff_silas",
        "standing_person",
        ("fixed.staff_floor_left",),
        (104.0, 0.0),
    )
    _ensure_provisional_slot(
        punchline,
        "scenario",
        "scenario.wall_item_1",
        "wall_mounted",
        ("event.wall_item_1",),
        (18.0, 12.0),
    )
    _assign_object_slot(punchline, "fixed", "game:slot", "fixed.game_slot")
    _assign_object_slot(punchline, "fixed", "numbers:silas", "fixed.staff_silas")
    _assign_object_slot(
        punchline,
        "scenario",
        "event:scenario_greased_week_window",
        "scenario.wall_item_1",
    )

    casino = maps["small_underground_casino:casino"]
    # Rowdy Regular is optional ambient content and its authored presentation
    # is seated, so it needs event-family capacity independent of scenarios.
    _ensure_provisional_slot(
        casino,
        "event",
        "event.seated_patron_1",
        "seated_person",
        ("scenario.seated_patron_1",),
        (-346.0, 0.0),
    )
    casino_event_seat = _slot_by_id(casino, "event.seated_patron_1")
    if casino_event_seat is None:
        raise ValueError("small_underground_casino:casino: seated event capacity is missing")
    casino_event_seat["support_id"] = "left_card_seat"
    _assign_object_slot(casino, "event", "event:rowdy_regular", "event.seated_patron_1")
    _assign_object_slot(casino, "exit", "travel:leave", "exit.left_upper")

    _normalize_conditional_people(maps)
    _normalize_numbers_book_capacity(maps)
    _normalize_home_storage_capacity(maps)
    _normalize_required_fixed_events(maps)
    _normalize_guaranteed_hosts(maps)
    _normalize_grand_living_floor_capacity(maps)
    _normalize_shared_event_person_capacity(maps)
    _normalize_public_event_capacity(maps)
    _normalize_delivery_wall_capacity(maps)
    _normalize_runtime_person_capacity(maps)
    _normalize_multiseed_capacity_and_conflicts(maps)
    _normalize_fixed_item_slots(payload)
    _normalize_baseline_fixed_slots(payload)
    _normalize_slot_occupancy_metadata(payload)
    _normalize_mixed_family_spacing(maps)
    _normalize_guaranteed_host_spacing(maps)
    _normalize_jazz_spacing(maps)
    _normalize_exit_spacing(maps)
    _normalize_direct_interaction_spacing(maps)
    _normalize_reviewed_output_order(maps)
    _normalize_runtime_person_spacing(maps)
    _apply_slot_consolidation(payload)


def migrate_map(
    map_data: dict[str, Any],
    scenario_sources: dict[str, set[str]],
    required_events: dict[str, set[str]],
    baseline_objects: dict[str, set[str]],
    trace_legacy_origins: bool = False,
) -> dict[str, Any]:
    result = copy.deepcopy(map_data)
    map_id = str(result.get("id", ""))
    old_object = result.pop("object_slot_ids", {})
    old_category = result.pop("category_slot_ids", {})
    scenario_preferences = result.get("scenario_slot_ids", {})
    if not isinstance(old_object, dict):
        old_object = {}
    if not isinstance(old_category, dict):
        old_category = {}
    if not isinstance(scenario_preferences, dict):
        scenario_preferences = {}

    slots_by_old: dict[str, dict[str, Any]] = {}
    source_kind: dict[str, str] = {}
    source_collection: dict[str, str] = {}
    ordered_old_ids: list[str] = []
    for field, default_family in (
        ("base_slots", "fixed"),
        ("stage_slots", "scenario"),
        ("exit_slots", "exit"),
    ):
        values = result.pop(field, [])
        if not isinstance(values, list):
            continue
        for slot in values:
            if not isinstance(slot, dict):
                continue
            slot_id = str(slot.get("id", "")).strip()
            if not slot_id:
                continue
            if slot_id in slots_by_old:
                raise ValueError(f"{map_id}: duplicate legacy slot id {slot_id}")
            slots_by_old[slot_id] = slot
            source_kind[slot_id] = default_family
            source_collection[slot_id] = field
            ordered_old_ids.append(slot_id)

    claims: dict[str, set[str]] = defaultdict(set)
    object_families: dict[str, str] = {}
    for object_id, slot_id in old_object.items():
        family = object_family(
            str(object_id),
            map_id,
            scenario_sources,
            required_events,
            baseline_objects,
        )
        object_families[str(object_id)] = family
        claims[str(slot_id)].add(family)
        prefix, _, source_id = str(object_id).partition(":")
        if prefix in scenario_sources and source_id in scenario_sources[prefix]:
            # Keep reusable scenario-family geometry even when the same
            # identity is baseline-owned in this venue. The final object stays
            # fixed; this additional claim only preserves the reviewed generic
            # scenario capacity created by the original one-way conversion.
            claims[str(slot_id)].add("scenario")
    for category_id, slot_id in old_category.items():
        claims[str(slot_id)].add(category_family(str(category_id)))
    for slot_id in scenario_preferences.values():
        claims[str(slot_id)].add("scenario")

    # Required catalog events are fixed even when they lack an exact preference.
    for event_id in sorted(required_events.get(map_id, set())):
        object_families[f"event:{event_id}"] = "fixed"
    for source_id in sorted(scenario_sources["event"]):
        key = f"event:{source_id}"
        if key in old_object:
            object_families[key] = "scenario"

    family_slots: dict[str, list[dict[str, Any]]] = {family: [] for family in FAMILIES}
    old_to_new: dict[tuple[str, str], str] = {}
    used_ids: set[str] = set()
    counters: dict[tuple[str, str], int] = defaultdict(int)

    for old_id in ordered_old_ids:
        slot = slots_by_old[old_id]
        families = set(claims.get(old_id, set()))
        default_family = source_kind[old_id]
        if not families:
            families.add(default_family)
        elif default_family in {"scenario", "exit"}:
            # Stage and existing exit capacity remains available for its intended
            # family even when exact preferences mention another lifecycle.
            families.add(default_family)
        ordered_families = [family for family in FAMILIES if family in families]
        for index, family in enumerate(ordered_families):
            if family == "fixed":
                candidate = fixed_slot_id(old_id)
            elif family == "exit" and old_id.startswith("exit."):
                candidate = old_id
            elif family == "exit":
                suffix = old_id.split(".", 1)[1] if "." in old_id else old_id
                candidate = f"exit.{suffix}"
            else:
                candidate = generic_slot_id(family, slot, counters)
            new_id = unique_id(candidate, used_ids)
            translated = translated_slot(slot, family, new_id, index, len(ordered_families))
            if trace_legacy_origins:
                translated[LEGACY_ORIGIN_FIELD] = {
                    "map_id": map_id,
                    "collection": source_collection[old_id],
                    "slot_id": old_id,
                }
            family_slots[family].append(translated)
            old_to_new[(old_id, family)] = new_id

    object_maps: dict[str, dict[str, str]] = {family: {} for family in FAMILIES}
    for object_id, old_slot_id in old_object.items():
        family = object_families[str(object_id)]
        target = old_to_new.get((str(old_slot_id), family))
        if target:
            object_maps[family][str(object_id)] = target

    category_maps: dict[str, dict[str, str]] = {family: {} for family in FAMILIES}
    for category_id, old_slot_id in old_category.items():
        family = category_family(str(category_id))
        target = old_to_new.get((str(old_slot_id), family))
        if target:
            category_maps[family][str(category_id)] = target

    migrated_scenario_preferences: dict[str, str] = {}
    for identity, old_slot_id in scenario_preferences.items():
        target = old_to_new.get((str(old_slot_id), "scenario"))
        if target:
            migrated_scenario_preferences[str(identity)] = target

    for route in result.get("actor_routes", []):
        if not isinstance(route, dict):
            continue
        for field in ("start_slot_id", "end_slot_id", "reduced_motion_slot_id"):
            old_slot_id = str(route.get(field, "")).strip()
            if not old_slot_id:
                continue
            target = old_to_new.get((old_slot_id, "scenario"))
            if target:
                route[field] = target

    result["slot_schema_version"] = 2
    result["fixed_slots"] = family_slots["fixed"]
    result["event_slots"] = family_slots["event"]
    result["scenario_slots"] = family_slots["scenario"]
    result["exit_slots"] = family_slots["exit"]
    result["fixed_object_slot_ids"] = object_maps["fixed"]
    result["event_object_slot_ids"] = object_maps["event"]
    result["scenario_object_slot_ids"] = object_maps["scenario"]
    result["exit_object_slot_ids"] = object_maps["exit"]
    result["fixed_category_slot_ids"] = category_maps["fixed"]
    result["event_category_slot_ids"] = category_maps["event"]
    result["scenario_category_slot_ids"] = category_maps["scenario"]
    result["exit_category_slot_ids"] = category_maps["exit"]
    result["object_family_ids"] = object_families
    result["scenario_slot_ids"] = migrated_scenario_preferences
    if map_id == "jazz_club":
        add_jazz_slots(result)
    else:
        result.setdefault("fixed_objects", [])
    return result


def validate(
    payload: dict[str, Any],
    *,
    baseline_objects: dict[str, set[str]] | None = None,
    required_events: dict[str, set[str]] | None = None,
    reviewed_authority: bool = True,
) -> None:
    assert payload.get("slot_schema_version") == 2
    assert payload.get("schema_version") == 3
    maps = payload.get("maps", [])
    assert isinstance(maps, list) and len(maps) == 21
    if baseline_objects is None:
        baseline_objects = baseline_objects_by_map()
    if required_events is None:
        required_events = required_events_by_map()
    for map_data in maps:
        map_id = str(map_data.get("id", "<unknown>"))
        seen: set[str] = set()
        slots_by_family: dict[str, set[str]] = {}
        for family in FAMILIES:
            field = f"{family}_slots"
            values = map_data.get(field)
            assert isinstance(values, list), f"{map_id} missing {field}"
            slots_by_family[family] = set()
            canonical_ordinals: dict[str, int] = defaultdict(int)
            for slot in values:
                slot_id = str(slot.get("id", ""))
                assert slot_id.startswith(f"{family}."), f"{map_id} malformed {slot_id}"
                assert slot.get("kind") == family, f"{map_id} kind mismatch {slot_id}"
                assert slot_id not in seen, f"{map_id} duplicate {slot_id}"
                if family in {"event", "scenario"}:
                    placement_class = str(slot.get("footprint_class", ""))
                    role = GENERIC_ROLE.get(placement_class, "")
                    assert role, f"{map_id} {slot_id} has no canonical role for {placement_class}"
                    canonical_ordinals[role] += 1
                    expected_id = f"{family}.{role}_{canonical_ordinals[role]}"
                    assert slot_id == expected_id, (
                        f"{map_id} non-canonical {family} id {slot_id}; "
                        f"expected {expected_id}"
                    )
                assert isinstance(slot.get("occupancy_required"), bool), f"{map_id} {slot_id} lacks explicit occupancy_required"
                assert isinstance(slot.get("physical_role"), str) and str(slot.get("physical_role", "")).strip(), f"{map_id} {slot_id} lacks physical_role"
                occupant_ids = slot.get("occupant_ids")
                assert isinstance(occupant_ids, list), f"{map_id} {slot_id} occupant_ids must be an array"
                assert all(isinstance(value, str) and value.strip() for value in occupant_ids), f"{map_id} {slot_id} has invalid occupant_ids"
                assert occupant_ids == sorted(set(occupant_ids)), f"{map_id} {slot_id} occupant_ids must be sorted and unique"
                assert isinstance(slot.get("runtime_reserve"), bool), f"{map_id} {slot_id} lacks runtime_reserve"
                assert isinstance(slot.get("reserve_reason"), str), f"{map_id} {slot_id} lacks reserve_reason"
                assert bool(slot.get("runtime_reserve")) == bool(str(slot.get("reserve_reason", "")).strip()), f"{map_id} {slot_id} reserve metadata is inconsistent"
                seen.add(slot_id)
                slots_by_family[family].add(slot_id)
        for family, targets in (
            ("event", EVENT_CAPACITY_TARGETS[map_id]),
            ("scenario", SCENARIO_CAPACITY_TARGETS[map_id]),
        ):
            actual = defaultdict(int)
            for slot in map_data.get(f"{family}_slots", []) or []:
                if isinstance(slot, dict):
                    actual[str(slot.get("footprint_class", ""))] += 1
            expected = {
                placement_class: count
                for placement_class, count in targets.items()
                if count > 0
            }
            assert dict(actual) == expected, (
                f"{map_id} {family} bank drift: "
                f"expected={expected} actual={dict(actual)}"
            )
        required_declared_slots = {
            str(declaration.get("exact_slot_id", ""))
            for declaration in map_data.get("fixed_objects", [])
            if isinstance(declaration, dict) and bool(declaration.get("required", True))
        }
        for family in FAMILIES:
            for slot in map_data.get(f"{family}_slots", []):
                slot_id = str(slot.get("id", ""))
                assert bool(slot.get("occupancy_required", False)) == (slot_id in required_declared_slots), f"{map_id} {slot_id} occupancy requirement drift"
        for legacy in ("base_slots", "stage_slots", "object_slot_ids", "category_slot_ids"):
            assert legacy not in map_data, f"{map_id} retained {legacy}"
        object_families = map_data.get("object_family_ids", {})
        if not isinstance(object_families, dict):
            raise ValueError(f"{map_id}: object_family_ids is not an object")
        for object_id, family_value in object_families.items():
            family = str(family_value)
            if family not in FAMILIES:
                raise ValueError(f"{map_id}: object_family_ids[{object_id}] names invalid family {family}")
        mapped_object_owners: dict[str, list[str]] = defaultdict(list)
        for family in FAMILIES:
            for field in (f"{family}_object_slot_ids", f"{family}_category_slot_ids"):
                values = map_data.get(field, {})
                assert isinstance(values, dict), f"{map_id} invalid {field}"
                for claimant, slot_id_value in values.items():
                    slot_id = str(slot_id_value)
                    if not slot_id.startswith(f"{family}.") or slot_id not in slots_by_family[family]:
                        raise ValueError(
                            f"{map_id}: {field}[{claimant}] names non-{family} slot {slot_id}"
                        )
                    if field == f"{family}_object_slot_ids":
                        mapped_object_owners[str(claimant)].append(family)
        for object_id, owners in sorted(mapped_object_owners.items()):
            if len(owners) != 1:
                raise ValueError(f"{map_id}: {object_id} has multiple exact slot-family owners {owners}")
            family = owners[0]
            if object_families.get(object_id) != family:
                raise ValueError(
                    f"{map_id}: {object_id} exact owner {family} disagrees with "
                    f"object_family_ids={object_families.get(object_id)!r}"
                )
        mapped_object_ids = set(mapped_object_owners)
        for object_id in sorted(mapped_object_ids & baseline_objects.get(map_id, set())):
            owners = [
                family
                for family in FAMILIES
                if object_id in map_data.get(f"{family}_object_slot_ids", {})
            ]
            assert owners == ["fixed"], f"{map_id} baseline {object_id} is not exclusively fixed-owned"
            assert map_data.get("object_family_ids", {}).get(object_id) == "fixed", f"{map_id} baseline {object_id} family drift"
        for required_event_id in sorted(required_events.get(map_id, set())):
            object_id = f"event:{required_event_id}"
            owners = mapped_object_owners.get(object_id, [])
            if owners != ["fixed"]:
                raise ValueError(
                    f"{map_id}: required {object_id} is not exclusively exact-mapped as fixed: {owners}"
                )
            slot_id = str(map_data.get("fixed_object_slot_ids", {}).get(object_id, ""))
            if slot_id not in slots_by_family["fixed"] or object_families.get(object_id) != "fixed":
                raise ValueError(
                    f"{map_id}: required {object_id} lacks matching fixed slot-family authority"
                )
        fixed_item_slots: set[str] = set()
        for object_id, slot_id in map_data.get("fixed_object_slot_ids", {}).items():
            if not str(object_id).startswith("item:"):
                continue
            slot = _slot_by_id(map_data, str(slot_id))
            assert slot is not None and slot.get("kind") == "fixed" and slot.get("footprint_class") == "shop_item", f"{map_id} fixed item {object_id} lacks a fixed shop slot"
            assert str(slot_id) not in fixed_item_slots, f"{map_id} fixed items share exact shop slot {slot_id}"
            fixed_item_slots.add(str(slot_id))
        numeric_shop_slots = sorted(
            str(slot.get("id", ""))
            for slot in map_data.get("fixed_slots", [])
            if isinstance(slot, dict) and re.fullmatch(r"fixed\.item_shop_\d+", str(slot.get("id", "")))
        )
        numeric_shop_slots.sort(key=lambda slot_id: int(slot_id.rsplit("_", 1)[1]))
        for ordinal, slot_id in enumerate(numeric_shop_slots):
            assert map_data.get("fixed_category_slot_ids", {}).get(f"item_spots:{ordinal}") == slot_id, f"{map_id} item row {ordinal} does not target {slot_id}"
        for slot_id in map_data.get("scenario_slot_ids", {}).values():
            assert str(slot_id).startswith("scenario."), f"{map_id} scenario preference {slot_id}"
            assert slot_id in seen, f"{map_id} scenario preference missing {slot_id}"
        for route in map_data.get("actor_routes", []):
            if not isinstance(route, dict):
                continue
            for field in ("start_slot_id", "end_slot_id", "reduced_motion_slot_id"):
                slot_id = str(route.get(field, "")).strip()
                if slot_id:
                    assert slot_id.startswith("scenario."), f"{map_id} actor route {field} must use scenario slots: {slot_id}"
                    assert slot_id in seen, f"{map_id} actor route {field} names missing slot {slot_id}"
        _assert_final_slot_references_exist(map_data)

    maps = {str(map_data.get("id", "")): map_data for map_data in maps if isinstance(map_data, dict)}

    padded_spacing_pairs = {
        "grand_casino": (
            ("fixed.fixture_host_desk", "fixed.staff_host"),
            ("fixed.staff_host", "event.behind_counter_person_1"),
        ),
        "kitty_cat_lounge": (
            ("fixed.patron_dot", "event.seated_person_1"),
            ("fixed.table_game_2", "fixed.item_shop_1"),
            ("fixed.table_game_2", "fixed.service_kitty_champagne"),
            ("fixed.item_shop_1", "fixed.service_kitty_champagne"),
        ),
    }
    for map_id, slot_pairs in padded_spacing_pairs.items():
        map_data = maps[map_id]
        for first_id, second_id in slot_pairs:
            first = _slot_by_id(map_data, first_id)
            second = _slot_by_id(map_data, second_id)
            assert first is not None and second is not None, f"{map_id} spacing pair is incomplete: {first_id}, {second_id}"
            first_rect = _slot_rect(first)
            second_rect = _slot_rect(second)
            assert first_rect is not None and second_rect is not None, f"{map_id} spacing pair lacks geometry: {first_id}, {second_id}"
            assert not _rects_overlap_with_gap(first_rect, second_rect), f"{map_id} padded geometry overlaps: {first_id}, {second_id}"

    direct_spacing_pairs = {
        "motel": (("fixed.item_counter_phone", "fixed.lender_motel_friend"),),
        "bar": (("event.standing_person_1", "event.doorway_1"),),
        "kitty_cat_lounge": (("event.doorway_1", "fixed.staff_merchant"),),
        "delta_queen": (("event.doorway_1", "fixed.staff_merchant"),),
        "grand_casino": (("fixed.service_house_drink", "exit.travel_cage"),),
        "grand_casino_cage": (("fixed.fixture_cage_counter", "fixed.staff_linda"),),
    }
    for map_id, slot_pairs in direct_spacing_pairs.items():
        map_data = maps[map_id]
        for first_id, second_id in slot_pairs:
            first = _slot_by_id(map_data, first_id)
            second = _slot_by_id(map_data, second_id)
            assert first is not None and second is not None, f"{map_id} direct spacing pair is incomplete: {first_id}, {second_id}"
            first_rect = _slot_rect(first)
            second_rect = _slot_rect(second)
            assert first_rect is not None and second_rect is not None, f"{map_id} direct spacing pair lacks geometry: {first_id}, {second_id}"
            assert not _rects_overlap(first_rect, second_rect), f"{map_id} direct interaction geometry overlaps: {first_id}, {second_id}"

    for map_id, retired_ids in RETIRED_UNUSED_SLOT_IDS.items():
        map_data = maps[map_id]
        # Event/scenario ids are canonical ordinals, so a retained later row may
        # legitimately compact into the same spelling after the named source row
        # is removed. Fixed/exit ids are stable identities and must disappear.
        stable_retired_ids = {
            slot_id
            for slot_id in retired_ids
            if slot_id.split(".", 1)[0] in {"fixed", "exit"}
        }
        remaining_ids = {
            str(slot.get("id", ""))
            for family in FAMILIES
            for slot in map_data.get(f"{family}_slots", []) or []
            if isinstance(slot, dict)
        }
        assert remaining_ids.isdisjoint(stable_retired_ids), (
            f"{map_id} retained unreachable placement rows "
            f"{sorted(remaining_ids & stable_retired_ids)}"
        )

    # Focused proof for the rows identified by the final shared-slot census.
    # The retained Gas Station clerk donor is canonically renumbered to _1, so
    # distinguish it from the retired empty _1 row by its reviewed support and
    # claimant instead of relying on the pre-consolidation ordinal spelling.
    reviewed_absences = {
        "motel": {"event.surface_item_2", "event.surface_item_3"},
        "delta_queen": {"event.wall_item_1", "event.surface_item_1"},
        "small_underground_casino": {"fixed.service_stage_left"},
        "pawn_shop": {
            "fixed.staff_merchant",
            "fixed.lender_sals_pawn_counter",
        },
    }
    for map_id, retired_ids in reviewed_absences.items():
        remaining_ids = {
            str(slot.get("id", ""))
            for family in FAMILIES
            for slot in maps[map_id].get(f"{family}_slots", []) or []
            if isinstance(slot, dict)
        }
        assert remaining_ids.isdisjoint(retired_ids), (
            f"{map_id} retained reviewed duplicate/dead rows "
            f"{sorted(remaining_ids & retired_ids)}"
        )

    if reviewed_authority:
        gas_counter_slots = [
            slot
            for slot in maps["gas_station_casino"].get("scenario_slots", []) or []
            if isinstance(slot, dict)
            and str(slot.get("footprint_class", "")) == "behind_counter_person"
        ]
        assert len(gas_counter_slots) == 1, (
            "gas_station_casino must retain only the Night Clerk geometry donor"
        )
        assert str(gas_counter_slots[0].get("support_id", "")) == "staff_window_left" \
            and "gas_station_graveyard_shift_night_clerk" in {
                str(value) for value in gas_counter_slots[0].get("occupant_ids", []) or []
            }, "gas_station_casino retained the empty pull-tab-window scenario row"

    for map_id, slot_id, support_id in (
        ("motel", "exit.door_curtain", "curtain_passage"),
        ("bar", "exit.travel_right", "right_exit"),
    ):
        slot = _slot_by_id(maps[map_id], slot_id)
        assert slot is not None \
            and slot.get("footprint_class") == "doorway" \
            and slot.get("support_id") == support_id, (
                f"{map_id} {slot_id} must be a doorway on {support_id}"
            )

    pawn = maps["pawn_shop"]
    sal = _fixed_object_by_id(pawn, "pawn_shop:sal")
    pawn_actions = {
        "shopkeeper:merchant",
        "lender:sals_pawn_counter",
        "meta_pawn_counter:sell",
        "meta_sal:talk",
    }
    assert sal is not None and pawn_actions.issubset(
        {str(value) for value in sal.get("action_ids", []) or []}
    ), "pawn_shop Sal host is missing consolidated shop/lender/sell/talk actions"
    for action_id in pawn_actions:
        assert pawn.get("object_family_ids", {}).get(action_id) == "fixed" \
            and all(
                action_id not in pawn.get(f"{family}_object_slot_ids", {})
                for family in FAMILIES
            ), f"pawn_shop {action_id} retained standalone placement authority"
    assert not any(
        str(category_id).startswith(
            ("shopkeeper_spots:", "lender_spots:", "pawn_counter_spots:")
        )
        for category_id in pawn.get("fixed_category_slot_ids", {})
    ), "pawn_shop retained shadow category aliases for the consolidated Sal host"

    motel = maps["motel"]
    assert "lender:brother_in_law" not in motel.get("object_family_ids", {}), "motel phone-only brother-in-law gained a physical family"
    assert all(
        "lender:brother_in_law" not in motel.get(f"{family}_object_slot_ids", {})
        for family in FAMILIES
    ), "motel phone-only brother-in-law gained an exact physical slot"

    grand = maps["grand_casino"]
    rumor_action_id = "event:town_rumor_staff"
    grand_host = next(
        (
            declaration
            for declaration in grand.get("fixed_objects", [])
            if isinstance(declaration, dict)
            and declaration.get("object_id") == "grand_casino:floor_host"
        ),
        None,
    )
    assert grand_host is not None and rumor_action_id in grand_host.get("action_ids", []), "grand_casino rumor action lost its fixed floor host"
    assert grand.get("object_family_ids", {}).get(rumor_action_id) == "fixed", "grand_casino rumor action family drift"
    assert all(
        rumor_action_id not in grand.get(f"{family}_object_slot_ids", {})
        for family in FAMILIES
    ), "grand_casino rumor action minted an independent physical slot"

    for map_id in SCENARIO_CAPACITY_TARGETS:
        map_data = maps[map_id]
        runtime_slots = [
            slot
            for slot in map_data.get("scenario_slots", []) or []
            if isinstance(slot, dict)
            and slot.get("physical_role") == "Runtime contact reserve"
        ]
        assert len(runtime_slots) == 1, (
            f"{map_id} must expose exactly one canonical runtime-person reserve"
        )
        slot = runtime_slots[0]
        slot_id = str(slot.get("id", ""))
        assert slot.get("kind") == "scenario" and slot.get("footprint_class") == "standing_person", f"{map_id} malformed runtime person capacity {slot_id}"
        assert bool(slot.get("runtime_reserve")), f"{map_id} runtime person capacity {slot_id} is not reserved"
        assert not bool(slot.get("occupancy_required", True)), f"{map_id} runtime person capacity {slot_id} must be optional"
        target_rect = _slot_rect(slot)
        assert target_rect is not None, f"{map_id} runtime person capacity {slot_id} lacks geometry"
    for map_id, object_id in (
        ("bar", "event:recruitment_knuckles"),
        ("beach", "event:recruitment_lucky"),
    ):
        map_data = maps[map_id]
        assert map_data.get("object_family_ids", {}).get(object_id) == "scenario", f"{map_id} {object_id} scenario family drift"
        assert all(
            object_id not in map_data.get(f"{family}_object_slot_ids", {})
            for family in FAMILIES
        ), f"{map_id} {object_id} must use shared scenario capacity"

    for map_id in HEIST_LIVE_TABLE_MAP_IDS:
        map_data = maps[map_id]
        assert map_data.get("object_family_ids", {}).get(HEIST_LIVE_TABLE_OBJECT_ID) == "scenario", f"{map_id} live-table scenario family drift"
        assert map_data.get("class_overrides", {}).get(HEIST_LIVE_TABLE_OBJECT_ID) == "floor_fixture", f"{map_id} live-table furniture classification drift"
        assert all(
            HEIST_LIVE_TABLE_OBJECT_ID not in map_data.get(f"{family}_object_slot_ids", {})
            for family in FAMILIES
        ), f"{map_id} live table must use shared scenario capacity"
        assert any(
            isinstance(slot, dict)
            and slot.get("kind") == "scenario"
            and slot.get("footprint_class") == "floor_fixture"
            and not bool(slot.get("occupancy_required", True))
            for slot in map_data.get("scenario_slots", [])
        ), f"{map_id} lacks optional scenario furniture capacity for The Live Table"

    back_alley = maps["back_alley"]
    assert back_alley.get("object_family_ids", {}).get("game:craps") == "scenario", "back_alley Street Craps family drift"
    assert back_alley.get("scenario_object_slot_ids", {}).get("game:craps") == "scenario.floor_fixture_1", "back_alley Street Craps slot drift"
    assert back_alley.get("class_overrides", {}).get("game:craps") == "floor_fixture", "back_alley Street Craps fixture classification drift"
    assert all(
        "game:craps" not in back_alley.get(f"{family}_object_slot_ids", {})
        for family in FAMILIES
        if family != "scenario"
    ), "back_alley Street Craps claims cross-family capacity"
    back_alley_floor_fixtures = [
        slot
        for slot in back_alley.get("scenario_slots", [])
        if isinstance(slot, dict)
        and slot.get("kind") == "scenario"
        and slot.get("footprint_class") == "floor_fixture"
        and not bool(slot.get("occupancy_required", True))
    ]
    assert len(back_alley_floor_fixtures) >= 2, "back_alley lacks Fence Night scenario floor-fixture capacity"

    for map_id, map_data in maps.items():
        for object_id, placement_class in map_data.get("class_overrides", {}).items():
            assert not str(object_id).startswith("item:") or placement_class == "shop_item", f"{map_id} generated item {object_id} overrides the closed shop_item class"

    reviewed_scenario_preferences = {
        "bar": (
            "bar_darts_league_night_darts_scorer",
            "scenario.standing_person_4",
        ),
        "kitty_cat_lounge": (
            "kitty_cat_lounge_amateur_night_amateur_signup",
            "scenario.surface_item_1",
        ),
        "gas_station_casino": (
            "gas_station_trucker_convoy_lead_driver",
            "scenario.standing_person_5",
        ),
    }
    for map_id, (stable_object_id, expected_slot_id) in reviewed_scenario_preferences.items():
        preferences = maps[map_id].get("scenario_slot_ids", {})
        matching = {
            str(slot_id)
            for identity, slot_id in preferences.items()
            if str(identity).split("|", 1)[0] == stable_object_id
        }
        assert matching == {expected_slot_id}, f"{map_id} {stable_object_id} preference drift: {sorted(matching)}"

    bar = maps["bar"]
    fight_night_seat_ids = (
        "scenario.seated_person_1",
        "scenario.seated_person_2",
    )
    fight_night_seats = [_slot_by_id(bar, slot_id) for slot_id in fight_night_seat_ids]
    assert all(slot is not None for slot in fight_night_seats), "bar lacks two-seat Fight Night scenario capacity"
    assert all(
        slot.get("kind") == "scenario"
        and slot.get("footprint_class") == "seated_person"
        and not bool(slot.get("occupancy_required", True))
        for slot in fight_night_seats
        if slot is not None
    ), "bar Fight Night seats must be optional scenario seated-person capacity"
    first_fight_seat_rect = _slot_rect(fight_night_seats[0])
    second_fight_seat_rect = _slot_rect(fight_night_seats[1])
    assert first_fight_seat_rect is not None and second_fight_seat_rect is not None, "bar Fight Night seats lack geometry"
    assert not _rects_overlap(first_fight_seat_rect, second_fight_seat_rect), "bar Fight Night scenario seats overlap"

    mapped_house_drink_maps = {
        map_id
        for map_id, map_data in maps.items()
        if HOUSE_DRINK_OBJECT_ID in baseline_objects.get(map_id, set())
        and any(
            HOUSE_DRINK_OBJECT_ID in map_data.get(f"{family}_object_slot_ids", {})
            for family in FAMILIES
        )
    }
    assert mapped_house_drink_maps == set(HOUSE_DRINK_SCENARIO_CAPACITY), "baseline house-drink venue coverage drift"
    for map_id in HOUSE_DRINK_SCENARIO_CAPACITY:
        map_data = maps[map_id]
        assert map_data.get("object_family_ids", {}).get(HOUSE_DRINK_OBJECT_ID) == "fixed", f"{map_id} house drink family drift"
        assert map_data.get("fixed_object_slot_ids", {}).get(HOUSE_DRINK_OBJECT_ID) == HOUSE_DRINK_FIXED_SLOT_ID, f"{map_id} house drink slot drift"
        target_slot = _slot_by_id(map_data, HOUSE_DRINK_FIXED_SLOT_ID)
        assert target_slot is not None and target_slot.get("kind") == "fixed" and target_slot.get("footprint_class") == "surface_item", f"{map_id} malformed fixed house-drink capacity"
        assert map_data.get("class_overrides", {}).get(HOUSE_DRINK_OBJECT_ID) == "surface_item", f"{map_id} house drink class override drift"
        target_rect = _slot_rect(target_slot)
        assert target_rect is not None, f"{map_id} fixed house-drink capacity lacks geometry"
        simultaneous_slots = [
            slot
            for slot in map_data.get("fixed_slots", [])
            if isinstance(slot, dict) and str(slot.get("id", "")) != HOUSE_DRINK_FIXED_SLOT_ID
        ]
        for simultaneous_slot in simultaneous_slots:
            simultaneous_rect = _slot_rect(simultaneous_slot)
            assert simultaneous_rect is None or not _rects_overlap(target_rect, simultaneous_rect), f"{map_id} fixed house-drink geometry overlaps {simultaneous_slot.get('id', '<unknown>')}"
    expected_assignments = {
        "motel": {
            "lender:motel_friend": ("fixed", "fixed.lender_motel_friend", "standing_person"),
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "numbers:silas": ("event", "event.standing_person_4", "standing_person"),
            "event:chain06_nico_weekly_door": ("event", "event.doorway_1", "doorway"),
        },
        "gas_station_casino": {
            "game:scratch_tickets": ("fixed", "fixed.game_scratch_tickets", "floor_fixture"),
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "dialogue:scratch_ticket_scalper": ("event", "event.standing_person_5", "standing_person"),
        },
        "bar": {
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "numbers:silas": ("event", "event.standing_person_5", "standing_person"),
        },
        "motel": {
            "event:chain06_dave_same_bus": ("event", "event.standing_person_1", "standing_person"),
            "event:chain06_dave_last_stop": ("event", "event.standing_person_1", "standing_person"),
        },
        "small_underground_casino": {
            "game:slot": ("fixed", "fixed.game_slot", "floor_fixture"),
            "game:video_poker": ("fixed", "fixed.game_video_poker", "floor_fixture"),
            "numbers:silas": ("event", "event.standing_person_8", "standing_person"),
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "service:punchline_two_drink_minimum": ("fixed", "fixed.service_two_drink_minimum", "surface_item"),
            "event:crew_job_board": ("event", "event.wall_item_1", "wall_mounted"),
            "event:crew_mags_bench": ("event", "event.surface_item_3", "surface_item"),
            "event:crew_planning_table": ("event", "event.surface_item_1", "surface_item"),
            "event:crew_practice_rig": ("event", "event.floor_fixture_2", "floor_fixture"),
            "event:crew_rook_ride": ("event", "event.doorway_1", "doorway"),
            "event:numbers_desk": ("event", "event.surface_item_2", "surface_item"),
            "event:scenario_greased_week_window": ("scenario", "scenario.wall_item_1", "wall_mounted"),
        },
        "small_underground_casino:back_room": {
            "environment_layer:ambient": ("fixed", "fixed.ambient_rook", "standing_person"),
            "numbers:silas": ("event", "event.standing_person_6", "standing_person"),
            "event:crew_job_board": ("fixed", "fixed.event_job_board", "surface_item"),
            "event:crew_mags_bench": ("fixed", "fixed.event_mags_bench", "surface_item"),
            "event:crew_planning_table": ("fixed", "fixed.event_planning_table", "surface_item"),
            "event:crew_practice_rig": ("fixed", "fixed.event_practice_rig", "floor_fixture"),
            "event:crew_rook_ride": ("fixed", "fixed.event_rook_ride", "doorway"),
            "event:numbers_desk": ("fixed", "fixed.event_numbers_desk", "surface_item"),
        },
        "small_underground_casino:club": {
            "environment_layer:ambient": ("fixed", "fixed.ambient_stage", "floor_fixture"),
            "environment_layer:casino": ("exit", "exit.door_side", "doorway"),
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "numbers:silas": ("event", "event.standing_person_1", "standing_person"),
        },
        "small_underground_casino:casino": {
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "numbers:silas": ("event", "event.standing_person_8", "standing_person"),
            "event:rowdy_regular": ("event", "event.seated_person_1", "seated_person"),
            "travel:leave": ("exit", "exit.guarded_upper", "doorway"),
        },
        "kitty_cat_lounge": {
            "numbers:silas": ("event", "event.standing_person_6", "standing_person"),
            "service:kitty_champagne": ("fixed", "fixed.service_kitty_champagne", "surface_item"),
            "event:side_door": ("event", "event.doorway_1", "doorway"),
        },
        "delta_queen": {
            "event:chain06_cass_first_contact": ("event", "event.standing_person_1", "standing_person"),
            "event:chain06_dave_same_bus": ("event", "event.standing_person_2", "standing_person"),
            "event:rowdy_regular": ("event", "event.seated_person_1", "seated_person"),
        },
        "jazz_club": {
            "numbers:silas": ("event", "event.standing_person_3", "standing_person"),
        },
        "corner_store": {
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
        },
        "pawn_shop": {
            "event:chain06_sal_estate_item": ("event", "event.surface_item_1", "surface_item"),
        },
        "grand_casino": {
            "event:scenario_audit_roster": ("fixed", "fixed.event_audit_roster", "wall_mounted"),
        },
        "motel_room": {
            "home_storage:place": ("fixed", "fixed.home_storage", "floor_fixture"),
        },
        "apartment": {
            "home_storage:place": ("fixed", "fixed.home_storage", "floor_fixture"),
        },
        "house": {
            "home_storage:place": ("fixed", "fixed.home_storage", "floor_fixture"),
        },
    }
    for map_id, assignments in expected_assignments.items():
        map_data = maps[map_id]
        for object_id, (family, slot_id, footprint_class) in assignments.items():
            assert map_data.get("object_family_ids", {}).get(object_id) == family, f"{map_id} {object_id} family drift"
            assert map_data.get(f"{family}_object_slot_ids", {}).get(object_id) == slot_id, f"{map_id} {object_id} slot drift"
            slot = _slot_by_id(map_data, slot_id)
            assert slot is not None, f"{map_id} missing repaired slot {slot_id}"
            assert slot.get("kind") == family and slot.get("footprint_class") == footprint_class, f"{map_id} malformed repaired slot {slot_id}"

    for map_id, declarations in guaranteed_host_objects().items():
        map_data = maps[map_id]
        by_id = {
            str(value.get("object_id", "")): value
            for value in map_data.get("fixed_objects", [])
            if isinstance(value, dict)
        }
        canonical_host_slot_ids = {
            ("delta_queen", "fixed.staff_floor"): "fixed.staff_ox",
            ("small_underground_casino:club", "fixed.staff_floor_right"): "fixed.staff_ox",
            ("small_underground_casino:casino", "fixed.staff_floor_right"): "fixed.staff_ox",
        }
        for legacy_expected in declarations:
            expected = copy.deepcopy(legacy_expected)
            legacy_slot_id = str(expected.get("exact_slot_id", ""))
            expected["exact_slot_id"] = canonical_host_slot_ids.get(
                (map_id, legacy_slot_id), legacy_slot_id
            )
            object_id = str(expected["object_id"])
            declaration = by_id.get(object_id)
            assert declaration is not None, f"{map_id} missing guaranteed host {object_id}"
            assert declaration == expected, f"{map_id} guaranteed host {object_id} drift"
            slot_id = str(expected["exact_slot_id"])
            slot = _slot_by_id(map_data, slot_id)
            assert slot is not None and slot.get("kind") == "fixed", f"{map_id} guaranteed host {object_id} lacks fixed capacity"
            assert bool(slot.get("occupancy_required", False)), f"{map_id} guaranteed host {object_id} slot is optional"

    for map_id, object_id, presentation_id, slot_id in (
        ("grand_casino", "grand_casino:audit_roster", "event:scenario_audit_roster", "fixed.event_audit_roster"),
    ):
        map_data = maps[map_id]
        declaration = next(
            (
                value
                for value in map_data.get("fixed_objects", [])
                if isinstance(value, dict) and str(value.get("object_id", "")) == object_id
            ),
            None,
        )
        assert declaration is not None, f"{map_id} missing required fixed declaration {object_id}"
        assert declaration.get("presentation_id") == presentation_id and declaration.get("exact_slot_id") == slot_id, f"{map_id} required fixed declaration {object_id} drift"
        assert bool(declaration.get("required", False)), f"{map_id} fixed declaration {object_id} must be required"
        slot = _slot_by_id(map_data, slot_id)
        assert slot is not None and bool(slot.get("occupancy_required", False)), f"{map_id} required fixed declaration {object_id} lacks required capacity"

    pull_tabs_retired_slots = {
        "bar": {"fixed.ticket_redeemer", "fixed.random_game_3"},
        "gas_station_casino": {
            "fixed.service_lottery_desk",
            "fixed.service_refreshment_shelf",
            "fixed.random_game_2",
            "fixed.event_control_rail",
        },
        "jazz_club": {
            "fixed.pulltab_game", "fixed.event_pull_tabs_sign",
            "fixed.random_game_1",
            "fixed.service_bar",
        },
        "grand_casino": {"fixed.ticket_redeemer", "fixed.game_machine_5"},
    }
    for map_id, retired_ids in pull_tabs_retired_slots.items():
        map_data = maps[map_id]
        fixed_ids = {
            str(slot.get("id", ""))
            for slot in map_data.get("fixed_slots", []) or []
            if isinstance(slot, dict)
        }
        assert fixed_ids.isdisjoint(retired_ids), (
            f"{map_id} retained standalone Pull Tabs capacity "
            f"{sorted(fixed_ids & retired_ids)}"
        )
        declarations = [
            declaration
            for declaration in map_data.get("fixed_objects", []) or []
            if isinstance(declaration, dict)
        ]
        assert all(
            not set(str(value) for value in declaration.get("action_ids", []) or [])
            & set(PULL_TABS_HOST_ACTION_IDS)
            for declaration in declarations
        ), f"{map_id} hard-codes Pull Tabs actions on a fixed declaration"
        for action_id in PULL_TABS_HOST_ACTION_IDS:
            assert map_data.get("object_family_ids", {}).get(action_id) == "fixed", (
                f"{map_id} {action_id} lost fixed runtime-host ownership"
            )
            assert all(
                action_id not in map_data.get(f"{family}_object_slot_ids", {})
                for family in FAMILIES
            ), f"{map_id} {action_id} retained a standalone physical mapping"
            assert action_id not in map_data.get("class_overrides", {}), (
                f"{map_id} {action_id} retained a physical class override"
            )
            assert action_id not in map_data.get("object_slot_positions", {}), (
                f"{map_id} {action_id} retained a legacy position override"
            )
    jazz = maps["jazz_club"]
    assert all(
        str(value.get("object_id", "")) != "jazz_club:pulltab_game"
        for value in jazz.get("fixed_objects", []) or []
        if isinstance(value, dict)
    ), "jazz_club retained its standalone Pull Tabs declaration"
    assert {
        str(slot.get("id", ""))
        for slot in jazz.get("exit_slots", []) or []
        if isinstance(slot, dict)
    } == {"exit.door_right_upper"}, "jazz_club must retain only its real travel exit"
    grand_game_categories = {
        key: value
        for key, value in maps["grand_casino"].get(
            "fixed_category_slot_ids", {}
        ).items()
        if str(key).startswith("game_spots:")
    }
    assert grand_game_categories == {
        "game_spots:0": "fixed.game_machine_1",
        "game_spots:1": "fixed.game_machine_2",
        "game_spots:2": "fixed.game_machine_3",
        "game_spots:3": "fixed.game_machine_4",
        "game_spots:4": "fixed.game_table_left",
        "game_spots:5": "fixed.game_table_right",
    }, "grand_casino game category rows no longer match its six physical games"
    grand = maps["grand_casino"]
    convention_override = grand.get("scenario_overrides", {}).get(
        "grand_casino_convention_crowd", {}
    )
    assert grand.get("class_overrides", {}).get("game:video_poker") == "wall_mounted", (
        "grand_casino Video Poker must retain its machine classification"
    )
    assert "game:video_poker" not in convention_override.get("class_overrides", {}), (
        "Convention Crowd must not reclassify Video Poker as a floor fixture"
    )
    assert _slot_by_id(grand, "fixed.event_floor_1") is None, (
        "grand_casino retained the unused event floor fixture"
    )
    assert "casino_fixture_spots:1" not in grand.get("fixed_category_slot_ids", {}), (
        "grand_casino retained the unused second casino-fixture alias"
    )
    assert {
        key: value
        for key, value in maps["bar"].get("fixed_category_slot_ids", {}).items()
        if str(key).startswith("game_spots:")
    } == {
        "game_spots:0": "fixed.random_game_1",
        "game_spots:1": "fixed.random_game_2",
    }, "bar game categories must expose only its two non-Pull-Tabs games"
    assert {
        key: value
        for key, value in maps["gas_station_casino"].get(
            "fixed_category_slot_ids", {}
        ).items()
        if str(key).startswith("game_spots:")
    } == {
        "game_spots:0": "fixed.random_game_1",
        "game_spots:1": "fixed.game_scratch_tickets",
    }, "gas_station_casino game categories must expose optional game plus Scratch"
    for object_id in ("game:coin_pusher", "game:slot", "game:video_poker"):
        assert maps["gas_station_casino"].get("fixed_object_slot_ids", {}).get(
            object_id
        ) == "fixed.random_game_1", (
            f"gas_station_casino {object_id} must share the optional game row"
        )

    descriptive_fixed_ids = {
        "corner_store": {
            "lender:the_crew": "fixed.crew_group",
        },
        "back_alley": {
            "lender:street_lender": "fixed.lender_street_lender",
            "lender:the_crew": "fixed.crew_group",
        },
        "beach": {
            "service:beach_sand_pile": "fixed.service_beach_sand_pile",
        },
        "kitty_cat_lounge": {
            "event:grand_casino_invite": "fixed.event_grand_casino_invite",
            "lender:the_crew": "fixed.crew_group",
        },
        "delta_queen": {
            "event:grand_casino_invite": "fixed.event_grand_casino_invite",
            "lender:the_crew": "fixed.crew_group",
            "service:riverboat_deck_walk": "fixed.service_deck_walk",
            "staff:delta_deck_boss": "fixed.staff_ox",
        },
        "small_underground_casino:club": {
            "staff:punchline_bouncer": "fixed.staff_ox",
        },
        "small_underground_casino:casino": {
            "character:ox": "fixed.staff_ox",
        },
    }
    for map_id, object_targets in descriptive_fixed_ids.items():
        map_data = maps[map_id]
        for object_id, slot_id in object_targets.items():
            assert map_data.get("fixed_object_slot_ids", {}).get(object_id) == slot_id, (
                f"{map_id} {object_id} must use descriptive fixed id {slot_id}"
            )
            assert _slot_by_id(map_data, slot_id) is not None, (
                f"{map_id} is missing descriptive fixed row {slot_id}"
            )

    guaranteed_game_ids = {
        "corner_store": {"game:coin_pusher": "fixed.game_coin_pusher"},
        "pawn_shop": {"game:slot": "fixed.game_slot"},
        "small_underground_casino:back_room": {
            "game:crew_draw_poker": "fixed.game_crew_draw_poker",
        },
        "delta_queen": {
            "game:blackjack": "fixed.game_blackjack",
            "game:roulette": "fixed.game_roulette",
            "game:video_poker": "fixed.game_video_poker",
        },
    }
    for map_id, expected in guaranteed_game_ids.items():
        actual = maps[map_id].get("fixed_object_slot_ids", {})
        for object_id, slot_id in expected.items():
            assert actual.get(object_id) == slot_id, (
                f"{map_id} guaranteed {object_id} must use {slot_id}"
            )
            assert _slot_by_id(maps[map_id], slot_id) is not None
    assert maps["beach"].get("fixed_category_slot_ids", {}).get(
        "game_spots:0"
    ) == "fixed.game_slot", "beach guaranteed Slot must use fixed.game_slot"

    casino = maps["small_underground_casino:casino"]
    assert {
        key: value
        for key, value in casino.get("fixed_category_slot_ids", {}).items()
        if key.startswith(("game_spots:", "service_spots:", "lender_spots:"))
    } == {
        "game_spots:0": "fixed.game_floor_1",
        "game_spots:1": "fixed.game_floor_2",
        "service_spots:0": "fixed.service_house_drink",
        "lender_spots:0": "fixed.lender_group_1",
        "lender_spots:1": "fixed.lender_person_1",
    }, "Punchline casino pooled fixed authority drift"
    for object_id in (
        "game:slot", "game:blackjack", "game:video_poker",
        "lender:the_crew", "lender:street_lender",
    ):
        assert object_id not in casino.get("fixed_object_slot_ids", {}), (
            f"Punchline casino {object_id} must stay ID-independent"
        )
    for slot_id in ("fixed.game_floor_1", "fixed.game_floor_2"):
        slot = _slot_by_id(casino, slot_id)
        assert slot is not None and slot.get("footprint_class") == "floor_fixture", (
            f"Punchline casino {slot_id} must be floor-game capacity"
        )
    individual_lender = _slot_by_id(casino, "fixed.lender_person_1")
    assert individual_lender is not None \
        and individual_lender.get("footprint_class") == "behind_counter_person" \
        and individual_lender.get("physical_role") == "Individual lender", (
            "Punchline casino individual lender position is mislabeled"
        )

    assert "service_spots:0" not in maps["back_alley"].get(
        "fixed_category_slot_ids", {}
    ), "back_alley retained an action-only service alias"
    assert not any(
        str(key).startswith("service_spots:")
        for key in maps["corner_store"].get("fixed_category_slot_ids", {})
    ), "corner_store retained an action-only service alias"
    assert "service_spots:0" not in maps["pawn_shop"].get(
        "fixed_category_slot_ids", {}
    ), "pawn_shop retained an action-only service alias"
    assert not any(
        str(key).startswith("service_spots:")
        for key in maps["jazz_club"].get("fixed_category_slot_ids", {})
    ), "jazz_club retained action-only music-service aliases"

    for map_id, slot_id in (
        ("grand_casino_high_limit", "exit.safe_left"),
        ("grand_casino_back_room", "exit.travel_left"),
        ("grand_casino_cage", "exit.travel_floor_door"),
    ):
        map_data = maps[map_id]
        assert map_data.get("exit_object_slot_ids", {}).get("travel:leave") == slot_id, (
            f"{map_id} lost its UI-synthesized world-map Leave exit"
        )
        assert map_data.get("exit_category_slot_ids", {}).get(
            "travel_spots:0"
        ) == slot_id, f"{map_id} lost its Leave exit category authority"

    kitty = maps["kitty_cat_lounge"]
    assert {
        key: value
        for key, value in kitty.get("fixed_category_slot_ids", {}).items()
        if key.startswith(("game_spots:", "game_hook_spots:", "service_spots:"))
    } == {
        "game_spots:0": "fixed.table_game_1",
        "game_spots:1": "fixed.machine_game_1",
        "game_spots:2": "fixed.table_game_2",
        "service_spots:0": "fixed.service_kitty_champagne",
        "service_spots:2": "fixed.service_house_drink",
    }, "Kitty pooled game/service authority drift"
    for object_id in ("game:roulette", "game:slot", "game:bar_dice"):
        assert object_id not in kitty.get("fixed_object_slot_ids", {}), (
            f"Kitty {object_id} must stay ID-independent"
        )
    assert {
        str(_slot_by_id(kitty, slot_id).get("footprint_class", ""))
        for slot_id in (
            "fixed.table_game_1", "fixed.table_game_2", "fixed.machine_game_1",
        )
        if _slot_by_id(kitty, slot_id) is not None
    } == {"surface_item", "floor_fixture"}, "Kitty game footprint bank drift"

    delta_categories = maps["delta_queen"].get("fixed_category_slot_ids", {})
    assert not any(
        str(key).startswith(
            ("game_spots:", "game_hook_spots:", "service_spots:", "lender_spots:")
        )
        for key in delta_categories
    ), "Delta exact fixed objects must not retain shadow category aliases"

    for map_id, count in {
        "grand_casino": 7,
        "grand_casino_high_limit": 6,
        "grand_casino_back_room": 5,
    }.items():
        map_data = maps[map_id]
        for ordinal in range(1, count + 1):
            slot_id = f"event.standing_person_{ordinal}"
            slot = _slot_by_id(map_data, slot_id)
            assert slot is not None, f"{map_id} missing living-floor capacity {slot_id}"
            assert slot.get("kind") == "event" and slot.get("footprint_class") == "standing_person", f"{map_id} malformed living-floor capacity {slot_id}"
            assert not bool(slot.get("occupancy_required", True)), f"{map_id} living-floor capacity {slot_id} must be optional"

    for map_id, count in {
        "back_alley": 6,
        "gas_station_casino": 5,
        "bar": 5,
        "small_underground_casino": 8,
        "small_underground_casino:club": 8,
        "small_underground_casino:casino": 8,
        "small_underground_casino:back_room": 6,
    }.items():
        event_rects: list[tuple[str, tuple[float, float, float, float]]] = []
        for ordinal in range(1, count + 1):
            slot_id = f"event.standing_person_{ordinal}"
            slot = _slot_by_id(maps[map_id], slot_id)
            assert slot is not None, f"{map_id} missing shared event-person capacity {slot_id}"
            assert slot.get("kind") == "event" and slot.get("footprint_class") == "standing_person", f"{map_id} malformed shared event-person capacity {slot_id}"
            assert not bool(slot.get("occupancy_required", True)), f"{map_id} shared event-person capacity {slot_id} must be optional"
            slot_rect = _slot_rect(slot)
            assert slot_rect is not None, f"{map_id} shared event-person capacity {slot_id} lacks geometry"
            for other_id, other_rect in event_rects:
                assert not _rects_overlap(slot_rect, other_rect), f"{map_id} shared event-person capacity {slot_id} overlaps {other_id}"
            event_rects.append((slot_id, slot_rect))

    for map_id, count in {
        "motel": 4,
        "jazz_club": 3,
        "kitty_cat_lounge": 6,
        "delta_queen": 6,
        "pawn_shop": 3,
    }.items():
        for ordinal in range(1, count + 1):
            slot_id = f"event.standing_person_{ordinal}"
            slot = _slot_by_id(maps[map_id], slot_id)
            assert slot is not None, f"{map_id} missing public event-person capacity {slot_id}"
            assert slot.get("kind") == "event" and slot.get("footprint_class") == "standing_person", f"{map_id} malformed public event-person capacity {slot_id}"
            assert not bool(slot.get("occupancy_required", True)), f"{map_id} public event-person capacity {slot_id} must be optional"

    for map_id, map_data in maps.items():
        scenario_wall_slots = [
            slot
            for slot in map_data.get("scenario_slots", [])
            if isinstance(slot, dict) and slot.get("footprint_class") == "wall_mounted"
        ]
        assert scenario_wall_slots, f"{map_id} lacks reusable scenario wall capacity"


def convert_legacy_payload(
    payload: dict[str, Any],
    *,
    capture_legacy_trace: bool = False,
    scenario_sources: dict[str, set[str]] | None = None,
    required_events: dict[str, set[str]] | None = None,
    baseline_objects: dict[str, set[str]] | None = None,
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    """Run the one-way v1 -> v2 conversion used by both production and evidence.

    The optional trace is transient audit metadata. It rides through the same
    migration and capacity-repair functions so cloned/relocated geometry keeps
    its legacy origin, then is removed before validation and serialization.
    """

    if int(payload.get("slot_schema_version", 0)) == 2:
        raise ValueError("legacy conversion requires a pre-slot-schema-v2 payload")
    if scenario_sources is None:
        scenario_sources = collect_scenario_sources()
    if required_events is None:
        required_events = required_events_by_map()
    if baseline_objects is None:
        baseline_objects = baseline_objects_by_map()
    converted = copy.deepcopy(payload)
    converted["schema_version"] = 3
    converted["slot_schema_version"] = 2
    converted["maps"] = [
        migrate_map(
            map_data,
            scenario_sources,
            required_events,
            baseline_objects,
            capture_legacy_trace,
        )
        for map_data in payload.get("maps", [])
    ]
    apply_capacity_repairs(converted)
    traced = copy.deepcopy(converted) if capture_legacy_trace else None
    for node in iter_dicts(converted):
        node.pop(LEGACY_ORIGIN_FIELD, None)
    validate(
        converted,
        baseline_objects=baseline_objects,
        required_events=required_events,
        reviewed_authority=False,
    )
    return converted, traced


def _json_bytes(payload: Any) -> bytes:
    return (json.dumps(payload, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def _sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _resolved_git_commit(ref: str) -> str:
    revision = subprocess.run(
        ["git", "rev-parse", "--verify", f"{ref}^{{commit}}"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=True,
    )
    if revision.returncode != 0:
        message = revision.stderr.strip()
        raise RuntimeError(f"cannot resolve legacy source ref {ref!r}: {message}")
    return revision.stdout.strip()


def _git_blob(revision: str, relative_path: str) -> bytes:
    source = subprocess.run(
        ["git", "show", f"{revision}:{relative_path}"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if source.returncode != 0:
        message = source.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"cannot read pinned legacy input {relative_path} from {revision}: {message}"
        )
    return source.stdout


def _json_blob(payload: bytes, label: str) -> Any:
    try:
        return json.loads(payload.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RuntimeError(f"pinned legacy input {label} is not valid UTF-8 JSON") from error


def _recorded_legacy_source_ref(mode: str, explicit_ref: str = "") -> str:
    if mode == "generate" and explicit_ref.strip():
        return explicit_ref.strip()
    if not LEGACY_LEDGER_PATH.exists():
        raise RuntimeError(
            "legacy ledger has no recorded source; generate it with "
            "--legacy-ledger generate --legacy-source-ref <pre-migration-commit>"
        )
    ledger = load_json(LEGACY_LEDGER_PATH)
    if not isinstance(ledger, dict):
        raise RuntimeError("legacy ledger root is not an object")
    source = ledger.get("source", {})
    if not isinstance(source, dict):
        raise RuntimeError("legacy ledger source metadata is missing")
    recorded = str(source.get("git_commit", "")).strip()
    if not recorded:
        raise RuntimeError("legacy ledger does not record an immutable source commit")
    return recorded


def _legacy_source_bundle(
    source_ref: str,
) -> tuple[bytes, dict[str, Any], str, Any, list[Any], list[dict[str, str]]]:
    revision = _resolved_git_commit(source_ref)
    placement_relative = PLACEMENT_PATH.relative_to(ROOT).as_posix()
    source_bytes = _git_blob(revision, placement_relative)
    payload = _json_blob(source_bytes, placement_relative)
    if not isinstance(payload, dict) or int(payload.get("slot_schema_version", 0)) == 2:
        raise RuntimeError(
            f"pinned placement authority at {revision} is not the pre-migration slot payload"
        )

    archetype_relative = ARCHETYPE_PATH.relative_to(ROOT).as_posix()
    scenario_relative = SCENARIO_PATH.relative_to(ROOT).as_posix()
    sequence_relative = SEQUENCE_DIR.relative_to(ROOT).as_posix()
    listing = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", revision, "--", sequence_relative],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=True,
    )
    if listing.returncode != 0:
        raise RuntimeError(
            f"cannot enumerate pinned scenario sequences at {revision}: {listing.stderr.strip()}"
        )
    sequence_paths = sorted(
        path.strip()
        for path in listing.stdout.splitlines()
        if path.strip().endswith(".json")
    )
    classification_paths = [archetype_relative, scenario_relative, *sequence_paths]
    classification_blobs = {
        path: _git_blob(revision, path)
        for path in classification_paths
    }
    archetypes = _json_blob(classification_blobs[archetype_relative], archetype_relative)
    scenario_documents = [
        _json_blob(classification_blobs[path], path)
        for path in [scenario_relative, *sequence_paths]
    ]
    evidence = [
        {"path": path, "sha256": _sha256(classification_blobs[path])}
        for path in classification_paths
    ]
    return source_bytes, payload, revision, archetypes, scenario_documents, evidence


def _first_payload_difference(expected: Any, actual: Any, path: str = "$") -> str:
    if type(expected) is not type(actual):
        return f"{path}: type {type(expected).__name__} != {type(actual).__name__}"
    if isinstance(expected, dict):
        expected_keys = set(expected)
        actual_keys = set(actual)
        if expected_keys != actual_keys:
            missing = sorted(expected_keys - actual_keys)
            extra = sorted(actual_keys - expected_keys)
            return f"{path}: missing keys={missing} extra keys={extra}"
        for key in sorted(expected):
            difference = _first_payload_difference(expected[key], actual[key], f"{path}.{key}")
            if difference:
                return difference
        return ""
    if isinstance(expected, list):
        if len(expected) != len(actual):
            return f"{path}: length {len(expected)} != {len(actual)}"
        for index, (expected_value, actual_value) in enumerate(zip(expected, actual)):
            difference = _first_payload_difference(
                expected_value,
                actual_value,
                f"{path}[{index}]",
            )
            if difference:
                return difference
        return ""
    if expected != actual:
        return f"{path}: {expected!r} != {actual!r}"
    return ""


def _map_scope(map_data: dict[str, Any]) -> dict[str, Any]:
    layer_id = str(map_data.get("layer_id", "")).strip()
    return {
        "map_id": str(map_data.get("archetype_id", map_data.get("id", ""))),
        "layer_id": layer_id or None,
        "effective_map_id": str(map_data.get("id", "")),
    }


def _legacy_route_claimants(map_data: dict[str, Any], slot_id: str) -> list[dict[str, Any]]:
    claimants: list[dict[str, Any]] = []
    for route_index, route in enumerate(map_data.get("actor_routes", []) or []):
        if not isinstance(route, dict):
            continue
        for field in ("start_slot_id", "end_slot_id", "reduced_motion_slot_id"):
            if str(route.get(field, "")) == slot_id:
                claimants.append(
                    {
                        "route_id": str(route.get("id", "")),
                        "route_index": route_index,
                        "field": field,
                    }
                )
    return claimants


def _legacy_claimants(
    map_data: dict[str, Any],
    slot_id: str,
    scenario_sources: dict[str, set[str]],
    required_events: dict[str, set[str]],
    baseline_objects: dict[str, set[str]],
) -> dict[str, Any]:
    map_id = str(map_data.get("id", ""))
    old_object = map_data.get("object_slot_ids", {})
    old_category = map_data.get("category_slot_ids", {})
    scenario_preferences = map_data.get("scenario_slot_ids", {})
    exact = []
    if isinstance(old_object, dict):
        exact = [
            {
                "object_id": str(object_id),
                "classified_family": object_family(
                    str(object_id),
                    map_id,
                    scenario_sources,
                    required_events,
                    baseline_objects,
                ),
            }
            for object_id, claimed_slot_id in old_object.items()
            if str(claimed_slot_id) == slot_id
        ]
    categories = []
    if isinstance(old_category, dict):
        categories = [
            {
                "category_id": str(category_id),
                "classified_family": category_family(str(category_id)),
            }
            for category_id, claimed_slot_id in old_category.items()
            if str(claimed_slot_id) == slot_id
        ]
    scenarios = []
    if isinstance(scenario_preferences, dict):
        scenarios = sorted(
            str(identity)
            for identity, claimed_slot_id in scenario_preferences.items()
            if str(claimed_slot_id) == slot_id
        )
    return {
        "exact": sorted(exact, key=lambda value: value["object_id"]),
        "category": sorted(categories, key=lambda value: value["category_id"]),
        "scenario": scenarios,
        "route": _legacy_route_claimants(map_data, slot_id),
    }


def _final_slot_index(map_data: dict[str, Any]) -> dict[str, tuple[str, dict[str, Any]]]:
    result: dict[str, tuple[str, dict[str, Any]]] = {}
    map_id = str(map_data.get("id", ""))
    for family in FAMILIES:
        for slot in map_data.get(f"{family}_slots", []) or []:
            if not isinstance(slot, dict):
                continue
            slot_id = str(slot.get("id", ""))
            if not slot_id:
                raise ValueError(f"{map_id}: final slot lacks an id")
            if slot_id in result:
                raise ValueError(f"{map_id}: duplicate final slot id {slot_id}")
            result[slot_id] = (family, slot)
    return result


def _final_route_claimants(map_data: dict[str, Any], slot_id: str) -> list[dict[str, Any]]:
    return _legacy_route_claimants(map_data, slot_id)


def _final_claimants(
    map_data: dict[str, Any], family: str, slot_id: str
) -> dict[str, Any]:
    exact_preferences = map_data.get(f"{family}_object_slot_ids", {})
    category_preferences = map_data.get(f"{family}_category_slot_ids", {})
    scenario_preferences = map_data.get("scenario_slot_ids", {})
    exact = []
    if isinstance(exact_preferences, dict):
        exact = sorted(
            str(identity)
            for identity, claimed_slot_id in exact_preferences.items()
            if str(claimed_slot_id) == slot_id
        )
    categories = []
    if isinstance(category_preferences, dict):
        categories = sorted(
            str(identity)
            for identity, claimed_slot_id in category_preferences.items()
            if str(claimed_slot_id) == slot_id
        )
    scenarios = []
    if isinstance(scenario_preferences, dict):
        scenarios = sorted(
            str(identity)
            for identity, claimed_slot_id in scenario_preferences.items()
            if str(claimed_slot_id) == slot_id
        )
    return {
        "exact": exact,
        "category": categories,
        "scenario": scenarios,
        "route": _final_route_claimants(map_data, slot_id),
    }


def _action_attachment_index(map_data: dict[str, Any]) -> dict[str, list[dict[str, str]]]:
    result: dict[str, list[dict[str, str]]] = defaultdict(list)
    declarations = [
        declaration
        for declaration in map_data.get("fixed_objects", []) or []
        if isinstance(declaration, dict)
    ]
    declarations.sort(key=lambda value: str(value.get("object_id", "")))
    for declaration in declarations:
        object_id = str(declaration.get("object_id", ""))
        presentation_id = str(declaration.get("presentation_id", ""))
        slot_id = str(declaration.get("exact_slot_id", ""))
        for action_id in sorted(str(value) for value in declaration.get("action_ids", []) or []):
            result[action_id].append(
                {
                    "action_id": action_id,
                    "host_object_id": object_id,
                    "host_presentation_id": presentation_id,
                    "final_slot_id": slot_id,
                }
            )
    return dict(result)


def _slot_action_attachments(
    attachment_index: dict[str, list[dict[str, str]]], slot_id: str
) -> list[dict[str, str]]:
    result = [
        copy.deepcopy(attachment)
        for attachments in attachment_index.values()
        for attachment in attachments
        if attachment["final_slot_id"] == slot_id
    ]
    return sorted(
        result,
        key=lambda value: (value["action_id"], value["host_object_id"]),
    )


def _assert_final_slot_references_exist(map_data: dict[str, Any]) -> None:
    map_id = str(map_data.get("id", ""))
    slots = _final_slot_index(map_data)
    for family in FAMILIES:
        for field in (f"{family}_object_slot_ids", f"{family}_category_slot_ids"):
            preferences = map_data.get(field, {})
            if not isinstance(preferences, dict):
                raise ValueError(f"{map_id}: {field} is not an object")
            for claimant, slot_id_value in preferences.items():
                slot_id = str(slot_id_value)
                if slot_id not in slots:
                    raise ValueError(f"{map_id}: {field}[{claimant}] names missing {slot_id}")
                if slots[slot_id][0] != family:
                    raise ValueError(
                        f"{map_id}: {field}[{claimant}] names {slots[slot_id][0]} slot {slot_id}"
                    )
    scenario_preferences = map_data.get("scenario_slot_ids", {})
    if isinstance(scenario_preferences, dict):
        for claimant, slot_id_value in scenario_preferences.items():
            slot_id = str(slot_id_value)
            if slot_id not in slots or slots[slot_id][0] != "scenario":
                raise ValueError(f"{map_id}: scenario claimant {claimant} names missing {slot_id}")
    for route in map_data.get("actor_routes", []) or []:
        if not isinstance(route, dict):
            continue
        for field in ("start_slot_id", "end_slot_id", "reduced_motion_slot_id"):
            slot_id = str(route.get(field, "")).strip()
            if slot_id and (slot_id not in slots or slots[slot_id][0] != "scenario"):
                raise ValueError(f"{map_id}: route {field} names missing {slot_id}")
    for declaration in map_data.get("fixed_objects", []) or []:
        if not isinstance(declaration, dict):
            continue
        slot_id = str(declaration.get("exact_slot_id", ""))
        if slot_id not in slots or slots[slot_id][0] != "fixed":
            raise ValueError(
                f"{map_id}: fixed object {declaration.get('object_id', '')} names missing {slot_id}"
            )


def _geometry_evidence(
    legacy_slot: dict[str, Any] | None,
    final_slot: dict[str, Any],
) -> dict[str, Any]:
    fields = ("pos", "hit_rect", "label_anchor")
    if legacy_slot is None:
        return {
            "status": "provisional",
            "reason": "introduced by reviewed capacity repair; no legacy slot origin",
            "legacy": None,
            "final": {field: copy.deepcopy(final_slot.get(field)) for field in fields},
        }
    preserved = all(legacy_slot.get(field) == final_slot.get(field) for field in fields)
    return {
        "status": "preserved" if preserved else "provisional",
        "reason": (
            "legacy coordinate fields preserved exactly"
            if preserved
            else "reviewed migration split, relocation, or capacity repair changed geometry"
        ),
        "legacy": {field: copy.deepcopy(legacy_slot.get(field)) for field in fields},
        "final": {field: copy.deepcopy(final_slot.get(field)) for field in fields},
    }


def _coexistence_decision(
    claimants: dict[str, Any],
    final_slots: list[dict[str, Any]],
    action_attachments: list[dict[str, str]],
) -> dict[str, Any]:
    claimant_count = sum(len(claimants[field]) for field in ("exact", "category", "scenario", "route"))
    if not final_slots:
        return {
            "decision": "retired_by_reviewed_capacity_repair",
            "independent_claimants_can_coexist": None,
        }
    if len(final_slots) > 1:
        return {
            "decision": "split_or_cloned_into_distinct_family_local_capacity",
            "independent_claimants_can_coexist": True,
        }
    if action_attachments:
        return {
            "decision": "actions_attach_to_one_guaranteed_physical_host",
            "independent_claimants_can_coexist": True,
        }
    if claimant_count > 1:
        return {
            "decision": "shared_only_as_aliases_or_mutually_exclusive_capacity",
            "independent_claimants_can_coexist": False,
        }
    return {
        "decision": "single_family_capacity",
        "independent_claimants_can_coexist": None,
    }


def build_legacy_mapping_ledger(
    source_bytes: bytes,
    legacy_payload: dict[str, Any],
    source_revision: str,
    final_bytes: bytes,
    final_payload: dict[str, Any],
    traced_payload: dict[str, Any],
    scenario_sources: dict[str, set[str]],
    required_events: dict[str, set[str]],
    baseline_objects: dict[str, set[str]],
    classification_inputs: list[dict[str, str]],
) -> dict[str, Any]:
    legacy_maps = {
        str(map_data.get("id", "")): map_data
        for map_data in legacy_payload.get("maps", [])
        if isinstance(map_data, dict)
    }
    traced_maps = {
        str(map_data.get("id", "")): map_data
        for map_data in traced_payload.get("maps", [])
        if isinstance(map_data, dict)
    }
    if set(legacy_maps) != set(traced_maps):
        raise ValueError("legacy/final map coverage differs while building mapping evidence")

    origins: dict[tuple[str, str, str], list[tuple[str, dict[str, Any]]]] = defaultdict(list)
    introduced: list[tuple[dict[str, Any], str, dict[str, Any]]] = []
    final_family_counts = {family: 0 for family in FAMILIES}
    required_count = 0
    capacity_count = 0
    for map_id, final_map in traced_maps.items():
        _assert_final_slot_references_exist(final_map)
        for family in FAMILIES:
            for slot in final_map.get(f"{family}_slots", []) or []:
                if not isinstance(slot, dict):
                    continue
                final_family_counts[family] += 1
                if bool(slot.get("occupancy_required", False)):
                    required_count += 1
                else:
                    capacity_count += 1
                origin = slot.get(LEGACY_ORIGIN_FIELD)
                if isinstance(origin, dict):
                    origin_key = (
                        str(origin.get("map_id", "")),
                        str(origin.get("collection", "")),
                        str(origin.get("slot_id", "")),
                    )
                    origins[origin_key].append((family, slot))
                else:
                    introduced.append((final_map, family, slot))

    rows: list[dict[str, Any]] = []
    geometry_counts = {"preserved": 0, "provisional": 0}
    retired_count = 0
    split_count = 0
    collection_counts = {"base_slots": 0, "stage_slots": 0, "exit_slots": 0}
    for map_data in legacy_payload.get("maps", []):
        if not isinstance(map_data, dict):
            continue
        map_id = str(map_data.get("id", ""))
        final_map = traced_maps[map_id]
        attachment_index = _action_attachment_index(final_map)
        for collection, default_family in (
            ("base_slots", "fixed"),
            ("stage_slots", "scenario"),
            ("exit_slots", "exit"),
        ):
            for legacy_slot in map_data.get(collection, []) or []:
                if not isinstance(legacy_slot, dict):
                    continue
                collection_counts[collection] += 1
                legacy_slot_id = str(legacy_slot.get("id", ""))
                claimants = _legacy_claimants(
                    map_data,
                    legacy_slot_id,
                    scenario_sources,
                    required_events,
                    baseline_objects,
                )
                descendants = sorted(
                    origins.get((map_id, collection, legacy_slot_id), []),
                    key=lambda value: (FAMILIES.index(value[0]), str(value[1].get("id", ""))),
                )
                final_slots = []
                for family, slot in descendants:
                    geometry = _geometry_evidence(legacy_slot, slot)
                    geometry_counts[geometry["status"]] += 1
                    slot_id = str(slot.get("id", ""))
                    final_slots.append(
                        {
                            "family": family,
                            "id": slot_id,
                            "footprint_class": str(slot.get("footprint_class", "")),
                            "support_id": str(slot.get("support_id", "")),
                            "occupancy": {
                                "required": bool(slot.get("occupancy_required", False)),
                                "mode": (
                                    "required"
                                    if bool(slot.get("occupancy_required", False))
                                    else "capacity"
                                ),
                            },
                            "claimants": _final_claimants(final_map, family, slot_id),
                            "action_to_object_attachments": _slot_action_attachments(
                                attachment_index,
                                slot_id,
                            ),
                            "geometry": geometry,
                        }
                    )
                claimant_attachments = sorted(
                    (
                        copy.deepcopy(attachment)
                        for claimant in claimants["exact"]
                        for attachment in attachment_index.get(claimant["object_id"], [])
                    ),
                    key=lambda value: (value["action_id"], value["host_object_id"]),
                )
                if not final_slots:
                    retired_count += 1
                if len(final_slots) > 1:
                    split_count += 1
                rows.append(
                    {
                        **_map_scope(map_data),
                        "old": {
                            "collection": collection,
                            "id": legacy_slot_id,
                            "default_family": default_family,
                            "footprint_class": str(legacy_slot.get("footprint_class", "")),
                            "support_id": str(legacy_slot.get("support_id", "")),
                        },
                        "claimants": claimants,
                        "coexistence": _coexistence_decision(
                            claimants,
                            final_slots,
                            claimant_attachments,
                        ),
                        "action_to_object_attachments": claimant_attachments,
                        "final_slots": final_slots,
                    }
                )

    introduced_rows = []
    for final_map, family, slot in sorted(
        introduced,
        key=lambda value: (
            str(value[0].get("id", "")),
            FAMILIES.index(value[1]),
            str(value[2].get("id", "")),
        ),
    ):
        attachment_index = _action_attachment_index(final_map)
        slot_id = str(slot.get("id", ""))
        geometry = _geometry_evidence(None, slot)
        geometry_counts[geometry["status"]] += 1
        introduced_rows.append(
            {
                **_map_scope(final_map),
                "family": family,
                "id": slot_id,
                "footprint_class": str(slot.get("footprint_class", "")),
                "support_id": str(slot.get("support_id", "")),
                "occupancy": {
                    "required": bool(slot.get("occupancy_required", False)),
                    "mode": (
                        "required"
                        if bool(slot.get("occupancy_required", False))
                        else "capacity"
                    ),
                },
                "claimants": _final_claimants(final_map, family, slot_id),
                "action_to_object_attachments": _slot_action_attachments(
                    attachment_index,
                    slot_id,
                ),
                "geometry": geometry,
            }
        )

    final_slot_count = sum(final_family_counts.values())
    traced_final_count = sum(len(values) for values in origins.values())
    if traced_final_count + len(introduced_rows) != final_slot_count:
        raise ValueError("final slot provenance accounting is incomplete")
    action_attachment_count = sum(
        len(declaration.get("action_ids", []) or [])
        for map_data in traced_maps.values()
        for declaration in map_data.get("fixed_objects", []) or []
        if isinstance(declaration, dict)
    )
    return {
        "schema_version": 1,
        "evidence": "one_way_environment_slot_family_manifest_migration",
        "source": {
            "git_ref": source_revision,
            "git_commit": source_revision,
            "path": PLACEMENT_PATH.relative_to(ROOT).as_posix(),
            "sha256": _sha256(source_bytes),
            "schema_version": legacy_payload.get("schema_version"),
            "slot_schema_version": legacy_payload.get("slot_schema_version", 1),
            "classification_inputs": classification_inputs,
        },
        "final": {
            "path": PLACEMENT_PATH.relative_to(ROOT).as_posix(),
            "sha256": _sha256(final_bytes),
            "schema_version": final_payload.get("schema_version"),
            "slot_schema_version": final_payload.get("slot_schema_version"),
        },
        "counts": {
            "maps": len(legacy_maps),
            "legacy_slot_rows": len(rows),
            "legacy_slots_by_collection": collection_counts,
            "legacy_slots_with_multiple_final_slots": split_count,
            "legacy_slots_retired": retired_count,
            "final_slots": final_slot_count,
            "final_slots_by_family": final_family_counts,
            "final_slots_with_legacy_origin": traced_final_count,
            "introduced_final_slots": len(introduced_rows),
            "required_final_slots": required_count,
            "capacity_final_slots": capacity_count,
            "preserved_geometry_links": geometry_counts["preserved"],
            "provisional_geometry_links": geometry_counts["provisional"],
            "action_to_object_attachments": action_attachment_count,
        },
        "legacy_slots": rows,
        "introduced_final_slots": introduced_rows,
    }


def legacy_ledger_payload(mode: str, explicit_source_ref: str = "") -> dict[str, Any]:
    source_ref = _recorded_legacy_source_ref(mode, explicit_source_ref)
    (
        source_bytes,
        legacy_payload,
        source_revision,
        archetypes,
        scenario_documents,
        classification_inputs,
    ) = _legacy_source_bundle(source_ref)
    scenario_sources = collect_scenario_sources(scenario_documents)
    required_events = required_events_by_map(archetypes)
    baseline_objects = baseline_objects_by_map(archetypes)
    converted, traced = convert_legacy_payload(
        legacy_payload,
        capture_legacy_trace=True,
        scenario_sources=scenario_sources,
        required_events=required_events,
        baseline_objects=baseline_objects,
    )
    if traced is None:
        raise RuntimeError("legacy trace was not captured")
    final_bytes = PLACEMENT_PATH.read_bytes()
    final_payload = load_json(PLACEMENT_PATH)
    difference = _first_payload_difference(converted, final_payload)
    if difference:
        raise RuntimeError(
            "pinned legacy source converted through the production migration path differs from "
            f"the working placement authority: {difference}"
        )
    return build_legacy_mapping_ledger(
        source_bytes,
        legacy_payload,
        source_revision,
        final_bytes,
        final_payload,
        traced,
        scenario_sources,
        required_events,
        baseline_objects,
        classification_inputs,
    )


def run_legacy_ledger(mode: str, explicit_source_ref: str = "") -> None:
    expected = legacy_ledger_payload(mode, explicit_source_ref)
    expected_bytes = _json_bytes(expected)
    if mode == "generate":
        LEGACY_LEDGER_PATH.write_bytes(expected_bytes)
        print(
            "generated reviewed legacy slot ledger: "
            f"{expected['counts']['legacy_slot_rows']} rows, "
            f"{expected['counts']['introduced_final_slots']} introduced final slots"
        )
        return
    if not LEGACY_LEDGER_PATH.exists():
        raise RuntimeError(f"legacy slot ledger is missing: {LEGACY_LEDGER_PATH}")
    actual_bytes = LEGACY_LEDGER_PATH.read_bytes()
    if actual_bytes != expected_bytes:
        raise RuntimeError(
            "legacy slot ledger is stale or non-deterministic; regenerate with "
            "--legacy-ledger generate"
        )
    print(
        "reviewed legacy slot ledger valid: "
        f"{expected['counts']['legacy_slot_rows']} rows, "
        f"{expected['counts']['final_slots']} final slots"
    )


def _consolidation_source_ref(mode: str, explicit_ref: str = "") -> str:
    if mode == "generate" and explicit_ref.strip():
        return explicit_ref.strip()
    if CONSOLIDATION_LEDGER_PATH.exists():
        ledger = load_json(CONSOLIDATION_LEDGER_PATH)
        if isinstance(ledger, dict) and isinstance(ledger.get("source"), dict):
            recorded = str(ledger["source"].get("git_commit", "")).strip()
            if recorded:
                return recorded
    return CONSOLIDATION_SOURCE_REF


def _slot_rows(payload: dict[str, Any]) -> list[tuple[str, str, dict[str, Any]]]:
    rows: list[tuple[str, str, dict[str, Any]]] = []
    for map_data in payload.get("maps", []) or []:
        if not isinstance(map_data, dict):
            continue
        map_id = str(map_data.get("id", ""))
        for family in FAMILIES:
            for slot in map_data.get(f"{family}_slots", []) or []:
                if isinstance(slot, dict):
                    rows.append((map_id, family, slot))
    return rows


def build_consolidation_disposition_ledger(
    source_bytes: bytes,
    source_payload: dict[str, Any],
    source_revision: str,
    final_bytes: bytes,
    final_payload: dict[str, Any],
) -> dict[str, Any]:
    traced = copy.deepcopy(source_payload)
    source_keys: list[tuple[str, str, str]] = []
    for map_id, family, slot in _slot_rows(traced):
        slot_id = str(slot.get("id", ""))
        source_keys.append((map_id, family, slot_id))
        slot[CONSOLIDATION_ORIGIN_FIELD] = [slot_id]
    if len(source_keys) != len(set(source_keys)):
        raise ValueError("consolidation source contains duplicate slot rows")

    apply_capacity_repairs(traced)
    clean = copy.deepcopy(traced)
    for node in iter_dicts(clean):
        node.pop(CONSOLIDATION_ORIGIN_FIELD, None)
    if clean != final_payload:
        difference = _first_payload_difference(final_payload, clean)
        raise RuntimeError(
            "current-v2 consolidation recipe does not reproduce the working "
            f"placement authority: {difference}"
        )

    targets_by_origin: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    final_index: dict[tuple[str, str], dict[str, Any]] = {}
    introduced: list[dict[str, Any]] = []
    for map_id, family, slot in _slot_rows(traced):
        slot_id = str(slot.get("id", ""))
        final_index[(map_id, slot_id)] = slot
        origins = slot.get(CONSOLIDATION_ORIGIN_FIELD, [])
        clean_origins = sorted(set(str(value) for value in origins)) \
            if isinstance(origins, list) else []
        if not clean_origins:
            introduced.append({
                "map_id": map_id,
                "family": family,
                "slot_id": slot_id,
                "footprint_class": str(slot.get("footprint_class", "")),
                "reason": "introduced explicit coexistence reserve",
            })
        for source_id in clean_origins:
            targets_by_origin[(map_id, source_id)].append(slot)

    source_maps = {
        str(map_data.get("id", "")): map_data
        for map_data in source_payload.get("maps", []) or []
        if isinstance(map_data, dict)
    }
    target_origin_sets: dict[tuple[str, str], list[str]] = {}
    for map_id, _family, slot in _slot_rows(traced):
        origins = slot.get(CONSOLIDATION_ORIGIN_FIELD, [])
        target_origin_sets[(map_id, str(slot.get("id", "")))] = sorted(
            set(str(value) for value in origins)
        ) if isinstance(origins, list) else []

    rows: list[dict[str, Any]] = []
    disposition_counts: dict[str, int] = defaultdict(int)
    for map_id, family, source_slot in _slot_rows(source_payload):
        source_id = str(source_slot.get("id", ""))
        targets = targets_by_origin.get((map_id, source_id), [])
        if len(targets) > 1:
            raise ValueError(
                f"{map_id}.{source_id}: one source slot maps to multiple final slots"
            )
        target = targets[0] if targets else None
        if target is None:
            disposition = "remove"
            target_id: str | None = None
            target_family: str | None = None
            collision_sources: list[str] = []
            reason = "physical row retired; no coordinate is imported"
        else:
            target_id = str(target.get("id", ""))
            target_family = str(target.get("kind", ""))
            collision_sources = target_origin_sets.get((map_id, target_id), [])
            if len(collision_sources) > 1:
                disposition = "merge"
                reason = "mutually exclusive capacity shares one retained physical row"
            elif source_id == target_id and family == target_family:
                disposition = "keep"
                reason = "slot identity and geometry row retained"
            else:
                disposition = "rename"
                reason = "slot renamed to its canonical physical role"
        disposition_counts[disposition] += 1
        rows.append({
            "map_id": map_id,
            "source_family": family,
            "source_slot_id": source_id,
            "source_footprint_class": str(source_slot.get("footprint_class", "")),
            "source_position": copy.deepcopy(source_slot.get("pos")),
            "disposition": disposition,
            "target_family": target_family,
            "target_slot_id": target_id,
            "collision": {
                "has_collision": len(collision_sources) > 1,
                "source_slot_ids": collision_sources,
                "policy": (
                    "prefer_exact_target_then_source_order"
                    if len(collision_sources) > 1 else "none"
                ),
            },
            "reason": reason,
        })
    rows.sort(key=lambda value: (
        value["map_id"],
        FAMILIES.index(value["source_family"]),
        value["source_slot_id"],
    ))

    final_rows = _slot_rows(final_payload)
    map_counts: dict[str, dict[str, Any]] = {}
    for map_id in sorted(source_maps):
        before = {
            family: sum(
                1 for row_map, row_family, _slot in _slot_rows(source_payload)
                if row_map == map_id and row_family == family
            )
            for family in FAMILIES
        }
        after = {
            family: sum(
                1 for row_map, row_family, _slot in final_rows
                if row_map == map_id and row_family == family
            )
            for family in FAMILIES
        }
        map_counts[map_id] = {
            "before": before,
            "after": after,
            "before_total": sum(before.values()),
            "after_total": sum(after.values()),
        }
    return {
        "schema_version": 1,
        "purpose": "current-v2 environment slot consolidation and placement-report import",
        "source": {
            "path": PLACEMENT_PATH.relative_to(ROOT).as_posix(),
            "git_commit": source_revision,
            "sha256": _sha256(source_bytes),
            "slot_count": len(source_keys),
        },
        "target": {
            "path": PLACEMENT_PATH.relative_to(ROOT).as_posix(),
            "sha256": _sha256(final_bytes),
            "slot_count": len(final_rows),
        },
        "counts": {
            "source_slots": len(source_keys),
            "target_slots": len(final_rows),
            "introduced_target_slots": len(introduced),
            **{
                f"{disposition}_source_slots": count
                for disposition, count in sorted(disposition_counts.items())
            },
        },
        "per_map_counts": map_counts,
        "introduced_target_slots": sorted(
            introduced,
            key=lambda value: (value["map_id"], value["family"], value["slot_id"]),
        ),
        "slot_dispositions": rows,
    }


def consolidation_ledger_payload(
    mode: str, explicit_source_ref: str = ""
) -> dict[str, Any]:
    source_ref = _consolidation_source_ref(mode, explicit_source_ref)
    source_revision = _resolved_git_commit(source_ref)
    relative = PLACEMENT_PATH.relative_to(ROOT).as_posix()
    source_bytes = _git_blob(source_revision, relative)
    source_payload = _json_blob(source_bytes, relative)
    if not isinstance(source_payload, dict) or int(source_payload.get("slot_schema_version", 0)) != 2:
        raise RuntimeError(
            f"pinned consolidation source at {source_revision} is not slot schema v2"
        )
    final_bytes = PLACEMENT_PATH.read_bytes()
    final_payload = _json_blob(final_bytes, relative)
    if not isinstance(final_payload, dict):
        raise RuntimeError("working placement authority is not an object")
    return build_consolidation_disposition_ledger(
        source_bytes,
        source_payload,
        source_revision,
        final_bytes,
        final_payload,
    )


def run_consolidation_ledger(mode: str, explicit_source_ref: str = "") -> None:
    expected = consolidation_ledger_payload(mode, explicit_source_ref)
    expected_bytes = _json_bytes(expected)
    if mode == "generate":
        CONSOLIDATION_LEDGER_PATH.write_bytes(expected_bytes)
        print(
            "generated current-v2 consolidation ledger: "
            f"{expected['counts']['source_slots']} source rows -> "
            f"{expected['counts']['target_slots']} target rows"
        )
        return
    if not CONSOLIDATION_LEDGER_PATH.exists():
        raise RuntimeError(
            f"consolidation disposition ledger is missing: {CONSOLIDATION_LEDGER_PATH}"
        )
    if CONSOLIDATION_LEDGER_PATH.read_bytes() != expected_bytes:
        raise RuntimeError(
            "consolidation disposition ledger is stale or non-deterministic; "
            "regenerate with --consolidation-ledger generate"
        )
    print(
        "current-v2 consolidation ledger valid: "
        f"{expected['counts']['source_slots']} source rows -> "
        f"{expected['counts']['target_slots']} target rows"
    )


def translate_placement_report(input_path: Path, output_path: Path) -> None:
    if not CONSOLIDATION_LEDGER_PATH.exists():
        raise RuntimeError("consolidation disposition ledger is missing")
    ledger = load_json(CONSOLIDATION_LEDGER_PATH)
    if not isinstance(ledger, dict):
        raise RuntimeError("consolidation disposition ledger is invalid")
    rows = ledger.get("slot_dispositions", [])
    row_index = {
        (str(row.get("map_id", "")), str(row.get("source_slot_id", ""))): row
        for row in rows
        if isinstance(row, dict)
    }
    payload = load_json(input_path)
    if not isinstance(payload, dict) or int(payload.get("schema_version", 0)) != 2:
        raise RuntimeError("placement report must use schema_version 2")
    rooms = payload.get("rooms", {})
    if not isinstance(rooms, dict):
        raise RuntimeError("placement report rooms must be an object")

    translated_rooms: dict[str, Any] = {}
    diagnostics: dict[str, Any] = {}
    total_removed = 0
    total_unmapped = 0
    total_collisions = 0
    for room_id, room_value in sorted(rooms.items(), key=lambda value: str(value[0])):
        room_key = str(room_id)
        room = room_value if isinstance(room_value, dict) else {}
        positions = room.get("slot_positions", {})
        if not isinstance(positions, dict):
            positions = {}
        candidates: dict[str, list[tuple[str, Any, dict[str, Any]]]] = defaultdict(list)
        removed: list[str] = []
        unmapped: list[str] = []
        for source_slot_id, position in sorted(positions.items(), key=lambda value: str(value[0])):
            source_id = str(source_slot_id)
            row = row_index.get((room_key, source_id))
            if row is None:
                unmapped.append(source_id)
                continue
            target_value = row.get("target_slot_id")
            target_id = (
                target_value.strip()
                if isinstance(target_value, str)
                else ""
            )
            if not target_id:
                removed.append(source_id)
                continue
            candidates[target_id].append((source_id, copy.deepcopy(position), row))
        translated_positions: dict[str, Any] = {}
        collisions: list[dict[str, Any]] = []
        for target_id, values in sorted(candidates.items()):
            values.sort(key=lambda value: (value[0] != target_id, value[0]))
            chosen_id, chosen_position, _chosen_row = values[0]
            translated_positions[target_id] = chosen_position
            if len(values) > 1:
                collisions.append({
                    "target_slot_id": target_id,
                    "chosen_source_slot_id": chosen_id,
                    "ignored_source_slot_ids": [value[0] for value in values[1:]],
                    "policy": "prefer_exact_target_then_source_order",
                })
        if translated_positions:
            translated_rooms[room_key] = {"slot_positions": translated_positions}
        if removed or unmapped or collisions:
            diagnostics[room_key] = {
                "removed_source_slot_ids": removed,
                "unmapped_source_slot_ids": unmapped,
                "merge_collisions": collisions,
            }
        total_removed += len(removed)
        total_unmapped += len(unmapped)
        total_collisions += len(collisions)

    output = {
        "schema_version": 2,
        "rooms": translated_rooms,
        "migration_report": {
            "ledger_source_commit": str(ledger.get("source", {}).get("git_commit", "")),
            "ledger_target_sha256": str(ledger.get("target", {}).get("sha256", "")),
            "removed_positions": total_removed,
            "unmapped_positions": total_unmapped,
            "merge_collisions": total_collisions,
            "rooms": diagnostics,
        },
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_json(output_path, output)
    print(
        f"translated placement report: rooms={len(translated_rooms)} "
        f"removed={total_removed} unmapped={total_unmapped} "
        f"collisions={total_collisions} output={output_path}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Validate an already migrated file without rewriting it")
    parser.add_argument(
        "--refresh-reviewed-v2",
        action="store_true",
        help=(
            "Apply the reviewed idempotent v2 repair recipe to the current file; "
            "maintenance-only because it may update provisional geometry"
        ),
    )
    parser.add_argument(
        "--legacy-ledger",
        choices=("generate", "check"),
        help=(
            "Generate or verify the one-way pinned legacy-slot mapping evidence; "
            "never rewrites placement_surfaces.json"
        ),
    )
    parser.add_argument(
        "--legacy-source-ref",
        default="",
        help=(
            "Immutable pre-migration git ref used only when generating the ledger; "
            "otherwise generation reuses its checked-in recorded commit"
        ),
    )
    parser.add_argument(
        "--consolidation-ledger",
        choices=("generate", "check"),
        help=(
            "Generate or verify the complete current-v2 slot disposition ledger; "
            "never rewrites placement_surfaces.json"
        ),
    )
    parser.add_argument(
        "--consolidation-source-ref",
        default="",
        help=(
            "Immutable current-v2 git ref used only when generating the "
            "consolidation ledger"
        ),
    )
    parser.add_argument(
        "--translate-placement-report",
        nargs=2,
        metavar=("INPUT", "OUTPUT"),
        help=(
            "Translate a schema-v2 placement report through the checked-in "
            "consolidation disposition ledger"
        ),
    )
    args = parser.parse_args()

    selected_modes = (
        int(args.check)
        + int(args.refresh_reviewed_v2)
        + int(bool(args.legacy_ledger))
        + int(bool(args.consolidation_ledger))
        + int(bool(args.translate_placement_report))
    )
    if selected_modes > 1:
        parser.error(
            "--check, --refresh-reviewed-v2, --legacy-ledger, "
            "--consolidation-ledger, and --translate-placement-report are mutually exclusive"
        )
    if args.legacy_source_ref and args.legacy_ledger != "generate":
        parser.error("--legacy-source-ref is valid only with --legacy-ledger generate")
    if args.consolidation_source_ref and args.consolidation_ledger != "generate":
        parser.error(
            "--consolidation-source-ref is valid only with "
            "--consolidation-ledger generate"
        )
    if args.legacy_ledger:
        run_legacy_ledger(args.legacy_ledger, args.legacy_source_ref)
        return 0
    if args.consolidation_ledger:
        run_consolidation_ledger(
            args.consolidation_ledger,
            args.consolidation_source_ref,
        )
        return 0
    if args.translate_placement_report:
        translate_placement_report(
            Path(args.translate_placement_report[0]).resolve(),
            Path(args.translate_placement_report[1]).resolve(),
        )
        return 0

    payload = load_json(PLACEMENT_PATH)
    if args.refresh_reviewed_v2:
        if int(payload.get("slot_schema_version", 0)) != 2:
            raise RuntimeError("--refresh-reviewed-v2 requires an already migrated slot schema v2 file")
        refreshed = copy.deepcopy(payload)
        apply_capacity_repairs(refreshed)
        validate(refreshed)
        write_json(PLACEMENT_PATH, refreshed)
        print(f"refreshed reviewed slot schema v2 repairs across {len(refreshed['maps'])} maps")
        return 0
    if args.check:
        validate(payload)
        print(f"slot schema v2 valid: {len(payload['maps'])} maps")
        return 0

    if int(payload.get("slot_schema_version", 0)) == 2:
        validate(payload)
        print("placement surfaces already use slot schema v2; no changes written")
        return 0

    converted, _ = convert_legacy_payload(payload)
    write_json(PLACEMENT_PATH, converted)
    print(f"migrated {len(converted['maps'])} placement maps to slot schema v2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
