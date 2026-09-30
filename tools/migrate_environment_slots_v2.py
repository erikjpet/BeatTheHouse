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

LEGACY_ORIGIN_FIELD = "__legacy_slot_ledger_origin"

FAMILIES = ("fixed", "event", "scenario", "exit")

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
    role = GENERIC_ROLE.get(footprint, footprint or "object")
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
            "action_ids": ["service:house_drink", "event:town_rumor_staff"],
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
        {
            "object_id": "jazz_club:pulltab_game",
            "presentation_id": "game:pull_tabs",
            "object_type": "game",
            "visual_type": "game",
            "render_key": "pull_tabs",
            "label": "Pull Tabs",
            "placement_class": "wall_mounted",
            "exact_slot_id": "fixed.pulltab_game",
            "required": True,
            "action_ids": ["game:pull_tabs"],
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
            host("corner_store:shopkeeper", "shopkeeper:merchant", "fixed_host_mara", "Mara", "fixed.staff_shopkeeper"),
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
                "action_ids": ["service:cashier_tip", "event:call_brother_in_law"],
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
            host("pawn_shop:sal", "staff:pawn_counter_sal", "fixed_host_sal", "Sal", "fixed.staff_pawn_counter"),
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
    take(("fixed.pulltab_game", "fixed.event_pull_tabs_sign"), "fixed.pulltab_game", "wall_mounted", (688.0, 48.0))

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
    fixed_map["game:pull_tabs"] = "fixed.pulltab_game"

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
    object_families["game:pull_tabs"] = "fixed"
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

    declarations_by_map = guaranteed_host_objects()
    for map_id, declarations in declarations_by_map.items():
        map_data = maps[map_id]
        existing = {
            str(value.get("object_id", "")): value
            for value in map_data.get("fixed_objects", [])
            if isinstance(value, dict)
        }
        for declaration in declarations:
            object_id = str(declaration["object_id"])
            if object_id in existing:
                existing[object_id].clear()
                existing[object_id].update(copy.deepcopy(declaration))
            else:
                map_data.setdefault("fixed_objects", []).append(copy.deepcopy(declaration))
            presentation_id = str(declaration["presentation_id"])
            exact_slot_id = str(declaration["exact_slot_id"])
            map_data.setdefault("fixed_object_slot_ids", {})[presentation_id] = exact_slot_id
            map_data.setdefault("object_family_ids", {})[presentation_id] = "fixed"

    # The cashier-tip action is intentionally hosted by the guaranteed store
    # phone object rather than projected as a second physical fixture.
    _assign_object_slot(
        maps["corner_store"],
        "fixed",
        "service:cashier_tip",
        "fixed.phone",
    )

    # Town rumor dialogue comes from the guaranteed Grand Casino floor host.
    # Keep the conditional action in event_ids, but do not mint a second staff
    # person or reserve event-family counter capacity for it.
    grand = maps["grand_casino"]
    rumor_action_id = "event:town_rumor_staff"
    _remove_object_slot_assignment(grand, rumor_action_id)
    grand.setdefault("object_family_ids", {})[rumor_action_id] = "fixed"


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
        "fixed.pulltab_game",
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

    pulltab = slots["fixed.pulltab_game"]
    pulltab["pos"] = [688.0, 24.0]
    pulltab["label_anchor"] = [688.0, 56.0]


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
        "pawn_shop": 3,
    }
    standing_positions = {
        "motel": [(450.0, 424.0), (208.0, 424.0), (144.0, 424.0), (408.0, 334.0)],
        "jazz_club": [(746.0, 366.0), (810.0, 350.0), (236.0, 258.0)],
        "kitty_cat_lounge": [(704.0, 294.0), (450.0, 278.0), (78.0, 254.0), (78.0, 172.0), (244.0, 170.0), (450.0, 148.0)],
        "delta_queen": [(400.0, 282.0), (686.0, 278.0), (750.0, 278.0), (532.0, 258.0), (322.0, 246.0), (258.0, 246.0)],
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
                64.0,
                82.0,
            )

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
            for slot in values:
                slot_id = str(slot.get("id", ""))
                assert slot_id.startswith(f"{family}."), f"{map_id} malformed {slot_id}"
                assert slot.get("kind") == family, f"{map_id} kind mismatch {slot_id}"
                assert slot_id not in seen, f"{map_id} duplicate {slot_id}"
                assert isinstance(slot.get("occupancy_required"), bool), f"{map_id} {slot_id} lacks explicit occupancy_required"
                seen.add(slot_id)
                slots_by_family[family].add(slot_id)
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
            ("fixed.staff_host", "event.counter_patron_1"),
        ),
        "kitty_cat_lounge": (
            ("fixed.patron_dot", "event.seated_patron_1"),
            ("fixed.random_game_2", "fixed.item_shop_1"),
            ("fixed.random_game_2", "fixed.service_kitty_champagne"),
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
        "motel": (
            ("fixed.item_counter_phone", "fixed.lender_motel_friend"),
            ("scenario.doorway_3", "exit.left_upper"),
        ),
        "bar": (("event.floor_patron_1", "event.doorway_1"),),
        "kitty_cat_lounge": (("event.doorway_1", "fixed.staff_merchant"),),
        "delta_queen": (("event.doorway_1", "fixed.staff_merchant"),),
        "grand_casino": (("fixed.service_house_drink", "exit.travel_cage"),),
        "grand_casino_cage": (("fixed.fixture_cage_1", "fixed.staff_linda"),),
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

    for map_id, slot_ids in _runtime_person_capacity_targets().items():
        map_data = maps[map_id]
        for slot_id in slot_ids:
            slot = _slot_by_id(map_data, slot_id)
            expected_family = slot_id.split(".", 1)[0]
            assert slot is not None, f"{map_id} missing runtime person capacity {slot_id}"
            assert slot.get("kind") == expected_family and slot.get("footprint_class") == "standing_person", f"{map_id} malformed runtime person capacity {slot_id}"
            assert not bool(slot.get("occupancy_required", True)), f"{map_id} runtime person capacity {slot_id} must be optional"
            target_rect = _slot_rect(slot)
            assert target_rect is not None, f"{map_id} runtime person capacity {slot_id} lacks geometry"
            for family in FAMILIES:
                for other in map_data.get(f"{family}_slots", []) or []:
                    if not isinstance(other, dict) or str(other.get("id", "")) == slot_id:
                        continue
                    other_rect = _slot_rect(other)
                    assert other_rect is None or not _rects_overlap(target_rect, other_rect), f"{map_id} runtime person capacity {slot_id} overlaps {other.get('id', '<unknown>')}"
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
    assert back_alley.get("scenario_object_slot_ids", {}).get("game:craps") == "scenario.floor_item_1", "back_alley Street Craps slot drift"
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
            "scenario.floor_patron_5",
        ),
        "kitty_cat_lounge": (
            "kitty_cat_lounge_amateur_night_amateur_signup",
            "scenario.surface_item_1",
        ),
        "gas_station_casino": (
            "gas_station_trucker_convoy_lead_driver",
            "scenario.floor_patron_5",
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
        "scenario.seated_patron_1",
        "scenario.seated_patron_2",
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
    for map_id, retained_slot_id in HOUSE_DRINK_SCENARIO_CAPACITY.items():
        map_data = maps[map_id]
        assert map_data.get("object_family_ids", {}).get(HOUSE_DRINK_OBJECT_ID) == "fixed", f"{map_id} house drink family drift"
        assert map_data.get("fixed_object_slot_ids", {}).get(HOUSE_DRINK_OBJECT_ID) == HOUSE_DRINK_FIXED_SLOT_ID, f"{map_id} house drink slot drift"
        retained_slot = _slot_by_id(map_data, retained_slot_id)
        target_slot = _slot_by_id(map_data, HOUSE_DRINK_FIXED_SLOT_ID)
        assert retained_slot is not None and retained_slot.get("kind") == "scenario", f"{map_id} lost reusable scenario capacity {retained_slot_id}"
        assert target_slot is not None and target_slot.get("kind") == "fixed" and target_slot.get("footprint_class") == "surface_item", f"{map_id} malformed fixed house-drink capacity"
        assert map_data.get("class_overrides", {}).get(HOUSE_DRINK_OBJECT_ID) == "surface_item", f"{map_id} house drink class override drift"
        target_rect = _slot_rect(target_slot)
        assert target_rect is not None, f"{map_id} fixed house-drink capacity lacks geometry"
        simultaneous_slots = [
            slot
            for slot in map_data.get("fixed_slots", [])
            if isinstance(slot, dict) and str(slot.get("id", "")) != HOUSE_DRINK_FIXED_SLOT_ID
        ] + [retained_slot]
        for simultaneous_slot in simultaneous_slots:
            simultaneous_rect = _slot_rect(simultaneous_slot)
            assert simultaneous_rect is None or not _rects_overlap(target_rect, simultaneous_rect), f"{map_id} fixed house-drink geometry overlaps {simultaneous_slot.get('id', '<unknown>')}"
    expected_assignments = {
        "motel": {
            "lender:motel_friend": ("fixed", "fixed.lender_motel_friend", "standing_person"),
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "numbers:silas": ("event", "event.floor_patron_1", "standing_person"),
            "event:chain06_nico_weekly_door": ("event", "event.doorway_1", "doorway"),
        },
        "gas_station_casino": {
            "game:scratch_tickets": ("fixed", "fixed.game_scratch_tickets", "floor_fixture"),
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "dialogue:scratch_ticket_scalper": ("event", "event.floor_patron_1", "standing_person"),
        },
        "bar": {
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "numbers:silas": ("event", "event.floor_patron_2", "standing_person"),
        },
        "small_underground_casino": {
            "game:slot": ("fixed", "fixed.game_slot", "floor_fixture"),
            "game:video_poker": ("fixed", "fixed.game_video_poker", "floor_fixture"),
            "numbers:silas": ("event", "event.floor_patron_2", "standing_person"),
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "service:punchline_two_drink_minimum": ("fixed", "fixed.service_two_drink_minimum", "surface_item"),
            "event:crew_job_board": ("event", "event.wall_item_1", "wall_mounted"),
            "event:crew_mags_bench": ("event", "event.surface_item_3", "surface_item"),
            "event:crew_planning_table": ("event", "event.surface_item_1", "surface_item"),
            "event:crew_practice_rig": ("event", "event.floor_item_2", "floor_fixture"),
            "event:crew_rook_ride": ("event", "event.doorway_1", "doorway"),
            "event:numbers_desk": ("event", "event.surface_item_2", "surface_item"),
            "event:scenario_greased_week_window": ("scenario", "scenario.wall_item_1", "wall_mounted"),
        },
        "small_underground_casino:back_room": {
            "environment_layer:ambient": ("fixed", "fixed.ambient_rook", "standing_person"),
            "numbers:silas": ("event", "event.floor_patron_1", "standing_person"),
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
            "numbers:silas": ("event", "event.floor_patron_1", "standing_person"),
        },
        "small_underground_casino:casino": {
            "numbers:book": ("fixed", "fixed.numbers_book", "surface_item"),
            "numbers:silas": ("event", "event.floor_patron_1", "standing_person"),
            "event:rowdy_regular": ("event", "event.seated_patron_1", "seated_person"),
            "travel:leave": ("exit", "exit.guarded_upper", "doorway"),
        },
        "kitty_cat_lounge": {
            "numbers:silas": ("event", "event.floor_patron_1", "standing_person"),
            "service:kitty_champagne": ("fixed", "fixed.service_kitty_champagne", "surface_item"),
            "event:side_door": ("event", "event.doorway_1", "doorway"),
        },
        "delta_queen": {
            "event:rowdy_regular": ("event", "event.floor_patron_1", "standing_person"),
        },
        "jazz_club": {
            "numbers:silas": ("event", "event.floor_patron_1", "standing_person"),
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
        for expected in declarations:
            object_id = str(expected["object_id"])
            declaration = by_id.get(object_id)
            assert declaration is not None, f"{map_id} missing guaranteed host {object_id}"
            assert declaration == expected, f"{map_id} guaranteed host {object_id} drift"
            slot_id = str(expected["exact_slot_id"])
            slot = _slot_by_id(map_data, slot_id)
            assert slot is not None and slot.get("kind") == "fixed", f"{map_id} guaranteed host {object_id} lacks fixed capacity"
            assert bool(slot.get("occupancy_required", False)), f"{map_id} guaranteed host {object_id} slot is optional"

    for map_id, object_id, presentation_id, slot_id in (
        ("jazz_club", "jazz_club:pulltab_game", "game:pull_tabs", "fixed.pulltab_game"),
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

    for map_id, count in {
        "grand_casino": 7,
        "grand_casino_high_limit": 6,
        "grand_casino_back_room": 5,
    }.items():
        map_data = maps[map_id]
        for ordinal in range(1, count + 1):
            slot_id = f"event.floor_patron_{ordinal}"
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
            slot_id = f"event.floor_patron_{ordinal}"
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
            slot_id = f"event.floor_patron_{ordinal}"
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
    args = parser.parse_args()

    selected_modes = int(args.check) + int(args.refresh_reviewed_v2) + int(bool(args.legacy_ledger))
    if selected_modes > 1:
        parser.error("--check, --refresh-reviewed-v2, and --legacy-ledger are mutually exclusive")
    if args.legacy_source_ref and args.legacy_ledger != "generate":
        parser.error("--legacy-source-ref is valid only with --legacy-ledger generate")
    if args.legacy_ledger:
        run_legacy_ledger(args.legacy_ledger, args.legacy_source_ref)
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
