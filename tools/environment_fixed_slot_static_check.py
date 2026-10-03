#!/usr/bin/env python3
"""Fast, engine-free authority check for rw06_1 fixed room slots."""

from __future__ import annotations

import copy
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

import rw06_1_author_fixed_slots as SlotAuthoring
import rw06_1_apply_hand_authored_slots as HandAuthoredSlots


CLASSES = {
    "standing_person", "behind_counter_person", "seated_person", "group",
    "floor_fixture", "ground_marker", "surface_item", "shop_item", "wall_mounted",
    "hanging", "doorway",
}
KINDS = {"base", "stage", "exit"}
V2_FAMILIES = ("fixed", "event", "scenario", "exit")
HOUSE_DRINK_FIXED_MAPS = (
    "corner_store",
    "back_alley",
    "motel",
    "bar",
    "gas_station_casino",
    "small_underground_casino:casino",
    "kitty_cat_lounge",
    "delta_queen",
    "grand_casino",
)
CREW_BACK_ROOM_FIXED_SLOTS = {
    "event:crew_job_board": ("fixed.event_job_board", "surface_item"),
    "event:crew_mags_bench": ("fixed.event_mags_bench", "surface_item"),
    "event:crew_planning_table": ("fixed.event_planning_table", "surface_item"),
    "event:crew_practice_rig": ("fixed.event_practice_rig", "floor_fixture"),
    "event:crew_rook_ride": ("fixed.event_rook_ride", "doorway"),
    "event:numbers_desk": ("fixed.event_numbers_desk", "surface_item"),
}
FACINGS = {"left", "right", "front", "back", "none"}
SLOT_FIELDS = {
    "id", "kind", "pos", "footprint_class", "hit_rect", "label_anchor",
    "facing", "priority", "zone_id", "support_id", "walk_lane_ids",
}
V2_SLOT_FIELDS = SLOT_FIELDS | {
    "occupancy_required", "physical_role", "occupant_ids",
    "runtime_reserve", "reserve_reason",
}
V2_GENERIC_ROLE = {
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
V2_SCENARIO_CAPACITY_TARGETS = {
    "corner_store": {"standing_person": 4, "doorway": 1, "wall_mounted": 3, "floor_fixture": 2, "surface_item": 1, "behind_counter_person": 1},
    "back_alley": {"standing_person": 4, "doorway": 1, "wall_mounted": 1, "floor_fixture": 3, "surface_item": 2, "ground_marker": 1},
    "motel": {"standing_person": 4, "behind_counter_person": 1, "floor_fixture": 3, "wall_mounted": 2, "doorway": 3, "hanging": 1, "surface_item": 1},
    "bar": {"floor_fixture": 4, "doorway": 1, "standing_person": 4, "surface_item": 2, "behind_counter_person": 2, "wall_mounted": 2, "seated_person": 2, "ground_marker": 1},
    "gas_station_casino": {"wall_mounted": 3, "standing_person": 5, "doorway": 3, "surface_item": 1, "ground_marker": 1, "behind_counter_person": 2, "floor_fixture": 2, "group": 2},
    "small_underground_casino": {"doorway": 1, "surface_item": 1, "floor_fixture": 1, "standing_person": 1, "wall_mounted": 1},
    "small_underground_casino:club": {"floor_fixture": 3, "standing_person": 4, "doorway": 2, "surface_item": 2, "group": 1, "ground_marker": 1, "wall_mounted": 1},
    "small_underground_casino:casino": {"floor_fixture": 3, "standing_person": 3, "doorway": 2, "seated_person": 1, "wall_mounted": 3, "surface_item": 1, "group": 1, "ground_marker": 1},
    "small_underground_casino:back_room": {"surface_item": 1, "floor_fixture": 1, "standing_person": 1, "wall_mounted": 1},
    "jazz_club": {"standing_person": 3, "floor_fixture": 3, "doorway": 1, "wall_mounted": 2, "surface_item": 1, "seated_person": 1, "ground_marker": 1},
    "kitty_cat_lounge": {"standing_person": 3, "surface_item": 1, "floor_fixture": 3, "doorway": 2, "wall_mounted": 3, "seated_person": 1, "ground_marker": 1},
    "delta_queen": {"standing_person": 3, "floor_fixture": 3, "behind_counter_person": 1, "doorway": 1, "wall_mounted": 4, "group": 1, "surface_item": 2, "ground_marker": 1},
    "beach": {"floor_fixture": 4, "standing_person": 5, "doorway": 1, "surface_item": 2, "wall_mounted": 2, "behind_counter_person": 2, "ground_marker": 1},
    "pawn_shop": {"standing_person": 2, "doorway": 1, "wall_mounted": 2, "floor_fixture": 2, "surface_item": 2, "shop_item": 2},
    "grand_casino": {"surface_item": 1, "standing_person": 3, "doorway": 1, "wall_mounted": 3, "group": 1, "floor_fixture": 3, "ground_marker": 1},
    "grand_casino_high_limit": {"wall_mounted": 1, "floor_fixture": 2, "standing_person": 1},
    "grand_casino_back_room": {"floor_fixture": 2, "standing_person": 1, "wall_mounted": 1},
    "grand_casino_cage": {"surface_item": 1, "floor_fixture": 2, "standing_person": 1, "wall_mounted": 1},
    "motel_room": {"floor_fixture": 1, "standing_person": 1, "surface_item": 1, "wall_mounted": 1},
    "apartment": {"floor_fixture": 1, "standing_person": 1, "surface_item": 1, "wall_mounted": 1},
    "house": {"floor_fixture": 1, "standing_person": 1, "surface_item": 1, "wall_mounted": 1},
}
V2_EVENT_CAPACITY_TARGETS = {
    "corner_store": {"behind_counter_person": 2, "floor_fixture": 1, "group": 1, "standing_person": 1, "ground_marker": 1},
    "back_alley": {"behind_counter_person": 1, "ground_marker": 1, "floor_fixture": 1, "standing_person": 6},
    "motel": {"behind_counter_person": 1, "surface_item": 3, "ground_marker": 1, "standing_person": 4, "doorway": 1},
    "bar": {"behind_counter_person": 1, "floor_fixture": 2, "standing_person": 5, "doorway": 1},
    "gas_station_casino": {"doorway": 2, "floor_fixture": 2, "surface_item": 1, "ground_marker": 1, "standing_person": 5},
    "small_underground_casino": {"floor_fixture": 2, "standing_person": 8, "wall_mounted": 1, "surface_item": 3, "doorway": 1},
    "small_underground_casino:club": {"floor_fixture": 1, "standing_person": 8},
    "small_underground_casino:casino": {"floor_fixture": 1, "behind_counter_person": 1, "seated_person": 1, "standing_person": 8},
    "small_underground_casino:back_room": {"surface_item": 4, "floor_fixture": 1, "doorway": 1, "standing_person": 6},
    "jazz_club": {"floor_fixture": 1, "standing_person": 3},
    "kitty_cat_lounge": {"floor_fixture": 1, "seated_person": 1, "doorway": 1, "standing_person": 6},
    "delta_queen": {"seated_person": 1, "doorway": 1, "behind_counter_person": 1, "floor_fixture": 2, "wall_mounted": 1, "surface_item": 1, "standing_person": 6},
    "beach": {},
    "pawn_shop": {"floor_fixture": 1, "standing_person": 3, "shop_item": 1, "surface_item": 1},
    "grand_casino": {"behind_counter_person": 2, "wall_mounted": 1, "floor_fixture": 1, "standing_person": 7},
    "grand_casino_high_limit": {"floor_fixture": 1, "standing_person": 6},
    "grand_casino_back_room": {"standing_person": 5},
    "grand_casino_cage": {},
    "motel_room": {},
    "apartment": {},
    "house": {},
}
PULL_TABS_HOST_ACTION_IDS = {
    "game:pull_tabs",
    "game_hook:pull_tabs:ticket_redeemer",
    "dialogue:pull_tab_clerk",
}
MAP_SLOT_FIELDS = ("base_slots", "stage_slots", "exit_slots")
EPSILON = 0.01
MIN_INTERACTIVE_TARGET = (44.0, 44.0)
# ScenarioLayoutResolver.WALK_LANE is immutable production access authority.
# Keep this literal synchronized so the engine-free exact replay rejects the
# same obstacle geometry before a seeded room finalization reaches Godot.
MANDATORY_PLAYER_ACCESS_LANE = (16.0, 378.0, 868.0, 36.0)
CONCRETE_SCENARIO_ART_KEYS = {
    "counter_phone", "jammed_machine", "motel_door", "paper_note", "payphone",
    "room_display", "room_hazard", "room_refreshment", "room_seating",
    "room_signal", "room_storage", "room_surface", "room_vehicle",
    "security_camera", "side_door", "trunk_offer",
}
ABSTRACT_SCENARIO_ROLES = {
    "barrier", "decision_route", "exit", "game_lane",
    "ledger", "primary_task", "route",
    "route_hazard", "route_marker", "task_station", "task_zone",
}
ABSTRACT_SCENARIO_ID_TOKENS = {
    "barrier", "choice", "ledger", "marker", "route", "seal", "task",
    "trace", "work_zone", "zone",
}
COUNTER_FOREGROUND_ART_IDS = {
    "back_alley_crate_display", "bar_main_counter", "beach_towel_stall",
    "corner_store_register", "delta_right_table", "gas_station_staff_window",
    "grand_host_station", "jazz_bar", "kitty_champagne_bar",
    "motel_lobby_table", "motel_merchandise_counter", "pawn_counter",
    "pawn_estate_shelf", "punchline_right_table",
}


class Check:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)


def values(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def point(value: Any) -> tuple[float, float] | None:
    if not isinstance(value, list) or len(value) != 2 or not all(finite_number(item) for item in value):
        return None
    return float(value[0]), float(value[1])


def rect(value: Any) -> tuple[float, float, float, float] | None:
    if not isinstance(value, list) or len(value) != 4 or not all(finite_number(item) for item in value):
        return None
    return tuple(float(item) for item in value)  # type: ignore[return-value]


def encloses(outer: tuple[float, float, float, float], inner: tuple[float, float, float, float]) -> bool:
    return (inner[0] >= outer[0] - EPSILON and inner[1] >= outer[1] - EPSILON
            and inner[0] + inner[2] <= outer[0] + outer[2] + EPSILON
            and inner[1] + inner[3] <= outer[1] + outer[3] + EPSILON)


def intersects(left: tuple[float, float, float, float], right: tuple[float, float, float, float]) -> bool:
    return (min(left[0] + left[2], right[0] + right[2]) > max(left[0], right[0]) + EPSILON
            and min(left[1] + left[3], right[1] + right[3]) > max(left[1], right[1]) + EPSILON)


def expanded(bounds: tuple[float, float, float, float], board: tuple[float, float]) -> tuple[float, float, float, float]:
    # ArtContracts.ENVIRONMENT_OBJECT_HIT_SIZE; this checker must model the
    # exact production small-screen collision authority.
    width, height = max(104.0, bounds[2]), max(76.0, bounds[3])
    center_x, center_y = bounds[0] + bounds[2] / 2.0, bounds[1] + bounds[3] / 2.0
    return (
        min(max(0.0, center_x - width / 2.0), board[0] - width),
        min(max(0.0, center_y - height / 2.0), board[1] - height),
        width,
        height,
    )


def slot_meets_interactive_minimum(slot: dict[str, Any]) -> bool:
    bounds = rect(slot.get("hit_rect"))
    return bounds is not None and bounds[2] >= MIN_INTERACTIVE_TARGET[0] and bounds[3] >= MIN_INTERACTIVE_TARGET[1]


def label_rect(slot: dict[str, Any], label: str, board: tuple[float, float]) -> tuple[float, float, float, float]:
    anchor = point(slot.get("label_anchor")) or (0.0, 0.0)
    raw_width = len(label.strip()) * 5.8 + 12.0
    width = min(max(48.0, raw_width), 126.0)
    height = 26.0 if raw_width > 126.0 else 15.0
    return (
        min(max(0.0, anchor[0] - width / 2.0), board[0] - width),
        min(max(0.0, anchor[1] - height), board[1] - height),
        width,
        height,
    )


def polyline_projection(
    points: list[tuple[float, float]],
    target: tuple[float, float],
) -> tuple[tuple[float, float], float, float] | None:
    """Return nearest point, distance along the polyline, and gap to it."""
    best: tuple[tuple[float, float], float, float] | None = None
    traversed = 0.0
    for start, end in zip(points, points[1:]):
        dx, dy = end[0] - start[0], end[1] - start[1]
        length_squared = dx * dx + dy * dy
        if length_squared <= EPSILON * EPSILON:
            continue
        length = math.sqrt(length_squared)
        weight = max(0.0, min(1.0, ((target[0] - start[0]) * dx + (target[1] - start[1]) * dy) / length_squared))
        projected = start[0] + dx * weight, start[1] + dy * weight
        gap = math.dist(target, projected)
        distance_along = traversed + length * weight
        if best is None or (gap, distance_along) < (best[2], best[1]):
            best = projected, distance_along, gap
        traversed += length
    return best


def named_supports(map_data: dict[str, Any]) -> dict[str, set[str]]:
    return {
        "counter": {str(item.get("id", "")) for item in values(map_data.get("counters")) if isinstance(item, dict)},
        "seat": {str(item.get("id", "")) for item in values(map_data.get("seats")) if isinstance(item, dict)},
        "doorway": {str(item.get("id", "")) for item in values(map_data.get("doorways")) if isinstance(item, dict)},
    }


def expected_support_kind(placement_class: str) -> str:
    if placement_class in {"standing_person", "group", "floor_fixture", "ground_marker"}:
        return "floor"
    if placement_class in {"behind_counter_person", "surface_item", "shop_item"}:
        return "counter"
    if placement_class == "seated_person":
        return "seat"
    if placement_class == "wall_mounted":
        return "wall"
    if placement_class == "hanging":
        return "ceiling"
    return "doorway"


def slot_has_physical_support(
    map_data: dict[str, Any],
    slot: dict[str, Any],
) -> bool:
    placement_class = str(slot.get("footprint_class", ""))
    bounds = rect(slot.get("hit_rect"))
    position = point(slot.get("pos"))
    support_id = str(slot.get("support_id", ""))
    if bounds is None or position is None or placement_class not in CLASSES:
        return False
    expected_contact = SlotAuthoring.contact_for_rect(bounds, placement_class)
    if math.dist(expected_contact, position) > EPSILON:
        return False
    if placement_class in SlotAuthoring.GROUNDED_CLASSES:
        floor = map_data.get("floor", {}) if isinstance(map_data.get("floor"), dict) else {}
        band_field = "stage_bands" if support_id == "stage" else "bands" if support_id == "floor" else ""
        contact_range = values(floor.get("contact_y"))
        if not band_field or support_id == "floor" and (len(contact_range) < 2 or not (float(contact_range[0]) - EPSILON <= position[1] <= float(contact_range[1]) + EPSILON)):
            return False
        return any(encloses(raw, bounds) for value in values(floor.get(band_field)) if (raw := rect(value)) is not None)
    if placement_class in {"behind_counter_person", "surface_item", "shop_item"}:
        for counter in values(map_data.get("counters")):
            if not isinstance(counter, dict) or str(counter.get("id", "")) != support_id:
                continue
            allowed = [str(item) for item in values(counter.get("classes"))]
            top_y = float(counter.get("top_y", 0.0))
            front_y = float(counter.get("front_y", top_y))
            vertical_contact = (
                top_y + EPSILON < position[1] <= front_y + EPSILON
                if placement_class == "behind_counter_person"
                else abs(position[1] - top_y) <= EPSILON
            )
            support_class = "surface_item" if placement_class == "shop_item" else placement_class
            return (not allowed or support_class in allowed) \
                and float(counter.get("x0", 0.0)) - EPSILON <= bounds[0] \
                and bounds[0] + bounds[2] <= float(counter.get("x1", 0.0)) + EPSILON \
                and vertical_contact
        return False
    if placement_class == "seated_person":
        return any(
            isinstance(seat, dict) and str(seat.get("id", "")) == support_id
            and (seat_point := point(seat.get("point"))) is not None
            and math.dist(seat_point, position) <= EPSILON
            for seat in values(map_data.get("seats"))
        )
    if placement_class in {"wall_mounted", "hanging"}:
        surface = map_data.get("wall" if placement_class == "wall_mounted" else "ceiling", {})
        if not isinstance(surface, dict):
            return False
        regions: list[tuple[str, tuple[float, float, float, float]]] = []
        if placement_class == "wall_mounted":
            for mount in values(surface.get("mounts")):
                if isinstance(mount, dict) and (mount_bounds := rect(mount.get("bounds"))) is not None:
                    regions.append((str(mount.get("id", "wall_mount")), mount_bounds))
        surface_bounds = rect(surface.get("bounds"))
        if surface_bounds is not None:
            regions.append(("wall" if placement_class == "wall_mounted" else "ceiling", surface_bounds))
        exclusions = [parsed for item in values(surface.get("exclusions")) if (parsed := rect(item.get("bounds") if isinstance(item, dict) else item)) is not None]
        named_region = next((region for identity, region in regions if identity == support_id and identity not in {"wall", "ceiling"}), None)
        if named_region is not None:
            # Named mounts are the positive authority for art deliberately cut
            # out of the generic wall plane (TV, ATM, framed print, and similar).
            return encloses(named_region, bounds)
        return any(identity == support_id and encloses(region, bounds) for identity, region in regions) \
            and not any(intersects(bounds, exclusion) for exclusion in exclusions)
    if placement_class == "doorway":
        return any(
            isinstance(doorway, dict) and str(doorway.get("id", "")) == support_id
            and (door_bounds := rect(doorway.get("bounds"))) is not None
            and encloses(door_bounds, bounds)
            for doorway in values(map_data.get("doorways"))
        )
    return False


def all_slots(map_data: dict[str, Any]) -> list[dict[str, Any]]:
    return [slot for field in MAP_SLOT_FIELDS for slot in values(map_data.get(field)) if isinstance(slot, dict)]


def ordered_slots(map_data: dict[str, Any], field: str) -> list[dict[str, Any]]:
    return sorted(
        (slot for slot in values(map_data.get(field)) if isinstance(slot, dict)),
        key=lambda slot: (int(slot.get("priority", 0)), str(slot.get("id", ""))),
    )


def scenario_semantic_is_abstract(stable_id: str, semantic: dict[str, Any]) -> bool:
    if str(semantic.get("role", "")).strip().lower() in ABSTRACT_SCENARIO_ROLES:
        return True
    normalized = stable_id.strip().lower()
    return any(
        normalized == token
        or normalized.startswith(f"{token}_")
        or normalized.endswith(f"_{token}")
        or f"_{token}_" in normalized
        for token in ABSTRACT_SCENARIO_ID_TOKENS
    )


def scenario_visual_art_key(
    map_data: dict[str, Any],
    semantic: dict[str, Any],
    actor: bool,
    safe_exit: bool,
) -> str:
    if actor:
        return ""
    if safe_exit:
        return "side_door"
    identity = str(semantic.get("identity", ""))
    stable_id = str(semantic.get("stable_object_id", identity.removeprefix("scenario::"))).strip()
    if scenario_semantic_is_abstract(stable_id, semantic):
        return ""
    position_key = SlotAuthoring.scenario_position_key(stable_id, semantic)
    preferences = map_data.get("scenario_slot_ids", {}) if isinstance(map_data.get("scenario_slot_ids"), dict) else {}
    if position_key not in preferences and stable_id not in preferences and identity not in preferences:
        return ""
    art_keys = map_data.get("scenario_art_keys", {}) if isinstance(map_data.get("scenario_art_keys"), dict) else {}
    art_key = str(art_keys.get(stable_id, art_keys.get(identity, ""))).strip()
    return art_key if art_key in CONCRETE_SCENARIO_ART_KEYS else ""


def scenario_visual_requires_room_slot(
    map_data: dict[str, Any],
    semantic: dict[str, Any],
    actor: bool,
    safe_exit: bool,
) -> bool:
    return actor or safe_exit or bool(scenario_visual_art_key(map_data, semantic, actor, safe_exit))


def simulate_scenario_binding(
    check: Check,
    map_data: dict[str, Any],
    snapshot: list[dict[str, Any]],
) -> tuple[dict[str, dict[str, str]], int, int, int]:
    """Mirrors EnvironmentSlotBinder preferred/priority/id selection."""
    map_id = str(map_data.get("id", "<missing>"))
    stage_slots = ordered_slots(map_data, "stage_slots")
    exit_slots = ordered_slots(map_data, "exit_slots")
    slot_by_id = {str(slot.get("id", "")): slot for slot in stage_slots + exit_slots}
    routes = {
        str(route.get("id", "")): route
        for route in values(map_data.get("actor_routes"))
        if isinstance(route, dict)
    }
    preferences = map_data.get("scenario_slot_ids", {}) if isinstance(map_data.get("scenario_slot_ids"), dict) else {}
    authored_overflow_ids = {
        str(identity)
        for identity in values(map_data.get("scenario_overflow_ids"))
        if isinstance(identity, str)
    }
    class_overrides = map_data.get("class_overrides", {}) if isinstance(map_data.get("class_overrides"), dict) else {}
    position_routes = map_data.get("scenario_position_route_ids", {}) if isinstance(map_data.get("scenario_position_route_ids"), dict) else {}
    entries: list[tuple[int, str, str, bool, bool, str, bool, str, bool, str]] = []
    interactions: dict[str, dict[str, Any]] = {}
    for semantic in snapshot:
        identity = str(semantic.get("identity", ""))
        interaction = semantic.get("_slot_interaction", {}) if isinstance(semantic.get("_slot_interaction"), dict) else {}
        if interaction:
            interactions[identity] = interaction
        if bool(semantic.get("_slot_interaction_only", False)) or bool(semantic.get("_slot_nonvisual", False)) or not identity.startswith("scenario::"):
            continue
        stable_id = identity.removeprefix("scenario::")
        actor = bool(semantic.get("_slot_actor", False))
        position_key = SlotAuthoring.scenario_position_key(stable_id, semantic)
        route_id = str(semantic.get("route_id", "")) or str(position_routes.get(position_key, ""))
        safe_exit = bool(semantic.get("safe_exit", False))
        physical = scenario_visual_requires_room_slot(map_data, semantic, actor, safe_exit)
        art_key = scenario_visual_art_key(map_data, semantic, actor, safe_exit)
        placement_class = ""
        if physical:
            classified = copy.deepcopy(semantic)
            if art_key:
                classified["icon_key"] = art_key
            placement_class = SlotAuthoring.classify_with_override(
                classified,
                "actor" if actor else "scene_object",
                identity,
                str(class_overrides.get(identity, class_overrides.get(stable_id, ""))),
            )
        # Production promotes every required exit to the doorway footprint class
        # before binding, regardless of the semantic object's visual category.
        if safe_exit:
            placement_class = "doorway"
        rank = 0 if safe_exit else 1 if route_id else 2
        entries.append((rank, identity, placement_class, actor, safe_exit, route_id, bool(semantic.get("_slot_hidden", False)), position_key, physical, art_key))
    entries.sort(key=lambda entry: (entry[0], entry[1]))
    occupied: set[str] = set()
    bindings: dict[str, dict[str, str]] = {}
    hidden_identities: set[str] = set()
    for _rank, identity, placement_class, actor, safe_exit, route_id, hidden, position_key, physical, art_key in entries:
        if hidden:
            hidden_identities.add(identity)
        selected: dict[str, Any] | None = None
        route = routes.get(route_id, {}) if route_id else {}
        stable_id = identity.removeprefix("scenario::")
        semantic = next((item for item in snapshot if str(item.get("identity", "")) == identity), {})
        if not physical:
            bindings[identity] = {"mode": "attached", "slot_id": "", "placement_class": "", "overflow_reason": "", "art_key": ""}
            continue
        if stable_id in authored_overflow_ids:
            check.require(False, f"{map_id}.{identity}: removed scenario overflow authority is still authored")
            bindings[identity] = {"mode": "missing", "slot_id": "", "placement_class": placement_class, "overflow_reason": "", "art_key": art_key}
            continue
        if route_id:
            start_id = str(route.get("start_slot_id", ""))
            end_id = str(route.get("end_slot_id", ""))
            start = slot_by_id.get(start_id, {})
            end = slot_by_id.get(end_id, {})
            lane_ids = [str(item) for item in values(route.get("lane_ids"))]
            known_lanes = {str(item.get("id", "")) for item in values(map_data.get("walk_lanes")) if isinstance(item, dict)}
            if (route and start and end and start_id != end_id
                    and str(start.get("footprint_class", "")) == placement_class
                    and str(end.get("footprint_class", "")) == placement_class
                    and slot_meets_interactive_minimum(start)
                    and slot_meets_interactive_minimum(end)
                    and start_id not in occupied and end_id not in occupied
                    and lane_ids and all(lane_id in known_lanes for lane_id in lane_ids)):
                selected = start
                occupied.update({start_id, end_id})
        else:
            pool = exit_slots if safe_exit else stage_slots
            stable_id = identity.removeprefix("scenario::")
            preferred_id = str(preferences.get(position_key, preferences.get(stable_id, preferences.get(identity, ""))))
            candidates: list[dict[str, Any]] = []
            if preferred_id in slot_by_id and slot_by_id[preferred_id] in pool:
                candidates.append(slot_by_id[preferred_id])
            if not safe_exit or not preferred_id:
                candidates.extend(slot for slot in pool if slot not in candidates)
            for slot in candidates:
                slot_id = str(slot.get("id", ""))
                if (str(slot.get("footprint_class", "")) == placement_class
                        and slot_id not in occupied
                        and slot_meets_interactive_minimum(slot)):
                    selected = slot
                    occupied.add(slot_id)
                    break
        if selected is None:
            bindings[identity] = {"mode": "missing", "slot_id": "", "placement_class": placement_class, "overflow_reason": "", "art_key": art_key}
            check.require(False, f"{map_id}.{identity}: physical visual has no compatible authored room slot")
        else:
            bindings[identity] = {
                "mode": "room",
                "slot_id": str(selected.get("id", "")),
                "placement_class": placement_class,
                "route_id": route_id,
                "end_slot_id": str(route.get("end_slot_id", "")) if route_id else "",
                "overflow_reason": "",
                "art_key": art_key,
            }
        if safe_exit and physical:
            check.require(bindings[identity]["mode"] == "room", f"{map_id}.{identity}: required safe exit has no room slot")
        if route_id and physical:
            check.require(bool(route), f"{map_id}.{identity}: route {route_id} has no authored slot/lane record")
            check.require(bindings[identity]["mode"] == "room", f"{map_id}.{identity}: routed actor has no room slot")
        else:
            stable_id = identity.removeprefix("scenario::")
            preferred_id = str(preferences.get(position_key, preferences.get(stable_id, preferences.get(identity, ""))))
            if preferred_id:
                preferred = slot_by_id.get(preferred_id, {})
                check.require(bool(preferred), f"{map_id}.{identity}: preferred slot {preferred_id} is missing")
                check.require(not preferred or str(preferred.get("footprint_class", "")) == placement_class, f"{map_id}.{identity}: preferred slot {preferred_id} is incompatible with {placement_class}")
        if selected is not None:
            check.require(slot_meets_interactive_minimum(selected), f"{map_id}.{identity}: room target is below the 44x44 interactive minimum")

    room_count = sum(1 for binding in bindings.values() if binding["mode"] == "room")
    overflow_count = sum(1 for binding in bindings.values() if binding["mode"] == "overflow")
    action_count = 0
    for identity, interaction in interactions.items():
        actions = values(interaction.get("available_actions"))
        input_actions = values(interaction.get("input_actions"))
        for action in actions:
            check.require(isinstance(action, dict) and bool(str(action.get("id", ""))), f"{map_id}.{identity}: malformed authored action")
        check.require(all(isinstance(item, str) and item for item in input_actions), f"{map_id}.{identity}: malformed input action")
        action_count += len(actions)
        presentation_identity = str(interaction.get("presentation_object_id", identity))
        if not actions:
            continue
        if identity in hidden_identities or presentation_identity in hidden_identities:
            check.errors.append(f"{map_id}.{identity}: hidden-only interaction exposes authored actions")
            continue
        if presentation_identity.startswith("scenario::"):
            check.require(presentation_identity in bindings, f"{map_id}.{identity}: actions have no room or attached-object presentation")
        else:
            check.require(bool(values(map_data.get("base_slots"))), f"{map_id}.{identity}: base action has no visible host authority")
    # Label placement is resolved from final drawn rectangles at runtime. The
    # pixel-scene label contract checks those resolved rectangles; authored
    # label anchors are intentionally not treated as final collision authority.
    check.require(len(bindings) == len(entries), f"{map_id}: scenario binding silently omitted a visual")
    return bindings, room_count, overflow_count, action_count


def conservative_base_label_scenario_census(
    check: Check,
    maps_by_id: dict[str, dict[str, Any]],
    replay_rows: list[tuple[str, list[dict[str, Any]], dict[str, dict[str, str]]]],
    expected_scenario_ids: set[str],
    board: tuple[float, float],
) -> dict[str, Any]:
    """Inventory the fixed base/stage planes for every legal phase.

    Base inventory occupants vary by seed and by randomized category.  The
    production renderer bounds every non-empty room label to 126x26, so this
    final labels now move around other live targets, so this draft records
    conservative conflicts for reporting only. Exact runtime contracts remain
    the collision authority.
    """
    pair_tests = 0
    snapshot_count = 0
    scenario_authority_count = 0
    base_slot_observations = 0
    legal_scenarios_seen: set[str] = set()
    conflicts: dict[tuple[str, str, str, str], set[str]] = {}
    base_base_pair_tests = 0
    base_base_conflicts: list[tuple[str, str, str, str]] = []
    base_slot_count = 0
    mandatory_lane_obstacle_checks = 0
    mandatory_lane_obstacle_states: set[tuple[str, str, str, str]] = set()
    mandatory_lane_overflow_states: set[tuple[str, str, str, str]] = set()

    def record_conflict(
        map_id: str,
        base_slot_id: str,
        scenario_slot_id: str,
        kind: str,
        state: str,
    ) -> None:
        conflicts.setdefault((map_id, base_slot_id, scenario_slot_id, kind), set()).add(state)

    # Deliberately stronger-than-runtime envelope: pair every reusable base slot
    # at maximum renderer-bounded label size, including capacity/fallback slots
    # that may be mutually exclusive. Exact legal witnesses may replace this
    # draft if the conservative geometry cannot remain locally associated.
    for map_id, map_data in sorted(maps_by_id.items()):
        base_slots = [slot for slot in values(map_data.get("base_slots")) if isinstance(slot, dict)]
        base_slot_count += len(base_slots)
        parsed: list[tuple[str, tuple[float, float, float, float], tuple[float, float, float, float], tuple[float, float, float, float]]] = []
        for base_slot in base_slots:
            base_slot_id = str(base_slot.get("id", ""))
            base_hit = rect(base_slot.get("hit_rect"))
            base_anchor = point(base_slot.get("label_anchor"))
            check.require(bool(base_slot_id), f"{map_id}: base label census found an unnamed slot")
            check.require(base_hit is not None, f"{map_id}.{base_slot_id}: label-capable base slot has no target")
            check.require(base_anchor is not None, f"{map_id}.{base_slot_id}: label-capable base slot has no label anchor")
            if not base_slot_id or base_hit is None or base_anchor is None:
                continue
            base_label_bounds = label_rect(base_slot, "M" * 64, board)
            horizontal_gap = max(
                base_label_bounds[0] - (base_hit[0] + base_hit[2]),
                base_hit[0] - (base_label_bounds[0] + base_label_bounds[2]),
                0.0,
            )
            vertical_gap = max(
                base_label_bounds[1] - (base_hit[1] + base_hit[3]),
                base_hit[1] - (base_label_bounds[1] + base_label_bounds[3]),
                0.0,
            )
            check.require(
                math.hypot(horizontal_gap, vertical_gap) <= 32.0 + EPSILON,
                f"{map_id}.{base_slot_id}: maximum base label is not visually associated with its target within 32px",
            )
            parsed.append((base_slot_id, base_hit, expanded(base_hit, board), base_label_bounds))
        for index, (left_id, left_hit, left_small, left_label) in enumerate(parsed):
            for right_id, right_hit, right_small, right_label in parsed[index + 1:]:
                tests = (
                    ("maximum labels overlap", left_label, right_label),
                    ("left maximum label vs right normal target", left_label, right_hit),
                    ("left maximum label vs right expanded target", left_label, right_small),
                    ("right maximum label vs left normal target", right_label, left_hit),
                    ("right maximum label vs left expanded target", right_label, left_small),
                )
                base_base_pair_tests += len(tests)
                for kind, left_bounds, right_bounds in tests:
                    if intersects(left_bounds, right_bounds):
                        base_base_conflicts.append((map_id, left_id, right_id, kind))

    for map_id, snapshot, bindings in replay_rows:
        map_data = maps_by_id.get(map_id, {})
        slots_by_id = {str(slot.get("id", "")): slot for slot in all_slots(map_data)}
        base_slots = [slot for slot in values(map_data.get("base_slots")) if isinstance(slot, dict)]
        scenario_id, phase_id = snapshot_tags(snapshot)
        check.require(bool(scenario_id) and "|" not in scenario_id, f"{map_id}: legal phase snapshot has ambiguous scenario ownership {scenario_id!r}")
        check.require(scenario_id in expected_scenario_ids, f"{map_id}: phase snapshot references unauthorized scenario {scenario_id!r}")
        if scenario_id:
            legal_scenarios_seen.add(scenario_id)
        snapshot_count += 1
        semantic_by_identity = {
            str(semantic.get("identity", "")): semantic
            for semantic in snapshot
            if isinstance(semantic, dict)
        }
        scenario_authority: list[tuple[str, str, tuple[float, float, float, float], tuple[float, float, float, float], tuple[float, float, float, float] | None]] = []
        for identity, binding in bindings.items():
            semantic = semantic_by_identity.get(identity, {})
            role = str(semantic.get("role", "")).strip().lower()
            if binding.get("mode") != "room":
                if role in {"obstacle", "barrier", "blockade"}:
                    mandatory_lane_overflow_states.add((map_id, scenario_id, phase_id, identity))
                    check.require(
                        not str(binding.get("slot_id", "")),
                        f"{map_id}.{scenario_id}/{phase_id}:{identity} overflow obstacle retained room geometry",
                    )
                continue
            scenario_slot_id = str(binding.get("slot_id", ""))
            scenario_slot = slots_by_id.get(scenario_slot_id, {})
            scenario_hit = rect(scenario_slot.get("hit_rect"))
            check.require(scenario_hit is not None, f"{map_id}.{identity}: bound scenario slot {scenario_slot_id} has no target")
            if scenario_hit is None:
                continue
            scenario_label = SlotAuthoring.placement_label(semantic_by_identity.get(identity, {}))
            scenario_label_bounds = label_rect(scenario_slot, scenario_label, board) if scenario_label.strip() else None
            scenario_small_hit = expanded(scenario_hit, board)
            if role in {"obstacle", "barrier", "blockade"}:
                mandatory_lane_obstacle_checks += 2
                mandatory_lane_obstacle_states.add((map_id, scenario_id, phase_id, identity))
                check.require(
                    not intersects(scenario_hit, MANDATORY_PLAYER_ACCESS_LANE),
                    f"{map_id}.{scenario_id}/{phase_id}:{identity} blocks the mandatory player access lane in normal layout",
                )
                check.require(
                    not intersects(scenario_small_hit, MANDATORY_PLAYER_ACCESS_LANE),
                    f"{map_id}.{scenario_id}/{phase_id}:{identity} blocks the mandatory player access lane in expanded small-screen layout",
                )
            scenario_authority.append((
                identity,
                scenario_slot_id,
                scenario_hit,
                scenario_small_hit,
                scenario_label_bounds,
            ))
        scenario_authority_count += len(scenario_authority)
        state = f"{scenario_id}/{phase_id}"
        for base_slot in base_slots:
            base_slot_id = str(base_slot.get("id", ""))
            base_hit = rect(base_slot.get("hit_rect"))
            base_anchor = point(base_slot.get("label_anchor"))
            check.require(bool(base_slot_id), f"{map_id}: base label census found an unnamed slot")
            check.require(base_hit is not None, f"{map_id}.{base_slot_id}: label-capable base slot has no target")
            check.require(base_anchor is not None, f"{map_id}.{base_slot_id}: label-capable base slot has no label anchor")
            if not base_slot_id or base_hit is None or base_anchor is None:
                continue
            base_slot_observations += 1
            # 64 non-space glyphs exceed both production width/wrap thresholds,
            # yielding the renderer's exact maximum 126x26 label authority.
            base_label_bounds = label_rect(base_slot, "M" * 64, board)
            base_small_hit = expanded(base_hit, board)
            for identity, scenario_slot_id, scenario_hit, scenario_small_hit, scenario_label_bounds in scenario_authority:
                pair_tests += 2
                if intersects(base_label_bounds, scenario_hit):
                    record_conflict(map_id, base_slot_id, scenario_slot_id, "base label vs scenario normal target", f"{state}:{identity}")
                if intersects(base_label_bounds, scenario_small_hit):
                    record_conflict(map_id, base_slot_id, scenario_slot_id, "base label vs scenario expanded target", f"{state}:{identity}")
                if scenario_label_bounds is None:
                    continue
                pair_tests += 3
                if intersects(base_label_bounds, scenario_label_bounds):
                    record_conflict(map_id, base_slot_id, scenario_slot_id, "base label vs scenario label", f"{state}:{identity}")
                if intersects(scenario_label_bounds, base_hit):
                    record_conflict(map_id, base_slot_id, scenario_slot_id, "scenario label vs base normal target", f"{state}:{identity}")
                if intersects(scenario_label_bounds, base_small_hit):
                    record_conflict(map_id, base_slot_id, scenario_slot_id, "scenario label vs base expanded target", f"{state}:{identity}")

    check.require(
        legal_scenarios_seen == expected_scenario_ids,
        "conservative base/scenario label census did not cover the exact legal scenario catalog "
        f"(missing={sorted(expected_scenario_ids - legal_scenarios_seen)} extra={sorted(legal_scenarios_seen - expected_scenario_ids)})",
    )
    check.require(snapshot_count > 0, "conservative base/scenario label census enumerated no legal phase snapshots")
    check.require(base_slot_observations > 0, "conservative base/scenario label census observed no label-capable base slots")
    check.require(scenario_authority_count > 0, "conservative base/scenario label census observed no bound scenario targets")
    check.require(pair_tests > 0, "conservative base/scenario label census performed no pair tests")
    check.require(mandatory_lane_obstacle_checks > 0, "exact scenario replay performed no mandatory-lane obstacle checks")
    all_mandatory_lane_obstacle_states = mandatory_lane_obstacle_states | mandatory_lane_overflow_states
    check.require(
        any(
            map_id == "gas_station_casino"
            and scenario_id == "gas_station_tour_bus_stop"
            and identity == "scenario::gas_station_tour_bus_stop_restroom_queue"
            for map_id, scenario_id, _phase_id, identity in all_mandatory_lane_obstacle_states
        ),
        "seed 063 regression: Gas Station tour-bus restroom queue was not covered by exact mandatory-lane replay",
    )
    check.require(
        bool(mandatory_lane_overflow_states),
        "scenario replay found no geometry-free barrier actions attached to visible hosts",
    )
    return {
        "snapshots": snapshot_count,
        "legal_scenarios": len(legal_scenarios_seen),
        "base_slot_observations": base_slot_observations,
        "scenario_authorities": scenario_authority_count,
        "pair_tests": pair_tests,
        "conflict_count": len(conflicts),
        "base_slots": base_slot_count,
        "base_base_pair_tests": base_base_pair_tests,
        "base_base_conflicts": len(base_base_conflicts),
        "mandatory_lane_obstacle_checks": mandatory_lane_obstacle_checks,
        "mandatory_lane_obstacle_states": len(mandatory_lane_obstacle_states),
        "mandatory_lane_overflow_states": len(mandatory_lane_overflow_states),
    }


def snapshot_tags(snapshot: list[dict[str, Any]]) -> tuple[str, str]:
    scenario_ids = sorted({str(item.get("_slot_scenario_id", "")) for item in snapshot if str(item.get("_slot_scenario_id", ""))})
    phase_ids = sorted({str(item.get("_slot_phase_id", "")) for item in snapshot if str(item.get("_slot_phase_id", ""))})
    return (
        scenario_ids[0] if len(scenario_ids) == 1 else "|".join(scenario_ids),
        phase_ids[0] if len(phase_ids) == 1 else "|".join(phase_ids),
    )


def summarize_scenarios(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for row in rows:
        grouped.setdefault((str(row["map_id"]), str(row["scenario_id"])), []).append(row)
    result: list[dict[str, Any]] = []
    for (map_id, scenario_id), snapshots in sorted(grouped.items()):
        peak = max(
            snapshots,
            key=lambda item: (
                int(item["physical_room_count"]),
                int(item["overflow_count"]),
                str(item["phase_id"]),
            ),
        )
        binding_count = sum(int(item["binding_count"]) for item in snapshots)
        overflow_count = sum(int(item["overflow_count"]) for item in snapshots)
        physical_room_count = sum(int(item["physical_room_count"]) for item in snapshots)
        action_list_count = sum(int(item["action_list_count"]) for item in snapshots)
        physical_spill_count = sum(int(item["physical_spill_count"]) for item in snapshots)
        result.append({
            "map_id": map_id,
            "scenario_id": scenario_id,
            "snapshot_count": len(snapshots),
            "binding_count": binding_count,
            "physical_room_count": physical_room_count,
            "action_list_count": action_list_count,
            "physical_spill_count": physical_spill_count,
            "overflow_count": overflow_count,
            "overflow_rate": overflow_count / max(1, binding_count),
            "peak": peak,
        })
    return result


def day2_sample_report(active_summaries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    requested = {
        "corner_store": "corner_store_aftermath",
        "bar": "bar_dead_tuesday",
        "grand_casino": "grand_casino_audit_night",
    }
    result: list[dict[str, Any]] = []
    for map_id, requested_scenario in requested.items():
        room = [item for item in active_summaries if item["map_id"] == map_id]
        requested_rows = [item for item in room if item["scenario_id"] == requested_scenario]
        peak_binding_count = max((int(item["peak"]["physical_room_count"]) for item in room), default=0)
        room_peak_ties = sorted(
            (item for item in room if int(item["peak"]["physical_room_count"]) == peak_binding_count),
            key=lambda item: str(item["scenario_id"]),
        )
        selected = next(
            (item for item in room_peak_ties if item["scenario_id"] == requested_scenario),
            room_peak_ties[0] if room_peak_ties else {},
        )
        result.append({
            "map_id": map_id,
            "requested_scenario_id": requested_scenario,
            "requested_scenario": requested_rows[0] if requested_rows else {},
            "room_peak_binding_count": peak_binding_count,
            "room_peak_physical_count": peak_binding_count,
            "room_peak_scenarios": room_peak_ties,
            "selected_sample": selected,
            "selection_reason": (
                "requested scenario is tied for the true active-room peak"
                if selected and selected.get("scenario_id") == requested_scenario
                else "requested scenario is below the true active-room peak; selected first peak scenario by id"
            ),
        })
    return result


def contact_sheet_report(
    active_summaries: list[dict[str, Any]],
    archetypes: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    """Selects one honest peak composition for each of the 18 player rooms.

    Layered scenarios are grouped under their owning archetype so the contact
    sheet remains an 18-room review, while the physical map/layer used for the
    capture stays explicit.  A room with no legal scenario is captured with its
    complete generated base inventory instead of inventing a scenario.
    """
    day2_preferences = {
        "corner_store": "corner_store_delivery_day",
        "bar": "bar_dead_tuesday",
        "grand_casino": "grand_casino_audit_night",
    }
    result: list[dict[str, Any]] = []
    for archetype_id in sorted(archetypes):
        room = [
            item for item in active_summaries
            if str(item.get("map_id", "")).split(":", 1)[0] == archetype_id
        ]
        if not room:
            result.append({
                "archetype_id": archetype_id,
                "map_id": archetype_id,
                "layer_id": "",
                "scenario_id": "",
                "phase_id": "base_inventory",
                "binding_count": 0,
                "physical_room_count": 0,
                "action_list_count": 0,
                "physical_spill_count": 0,
                "overflow_count": 0,
                "day2_sample": False,
                "selection_reason": "room has no legal scenario; capture complete generated base inventory",
            })
            continue
        peak_binding_count = max(int(item["peak"]["physical_room_count"]) for item in room)
        ties = sorted(
            (item for item in room if int(item["peak"]["physical_room_count"]) == peak_binding_count),
            key=lambda item: (str(item["scenario_id"]), str(item["map_id"])),
        )
        preferred_id = day2_preferences.get(archetype_id, "")
        selected = next(
            (item for item in ties if str(item.get("scenario_id", "")) == preferred_id),
            ties[0],
        )
        map_id = str(selected["map_id"])
        peak = selected["peak"]
        result.append({
            "archetype_id": archetype_id,
            "map_id": map_id,
            "layer_id": map_id.split(":", 1)[1] if ":" in map_id else "",
            "scenario_id": str(selected["scenario_id"]),
            "phase_id": str(peak["phase_id"]),
            "binding_count": int(peak["binding_count"]),
            "physical_room_count": int(peak["physical_room_count"]),
            "action_list_count": int(peak["action_list_count"]),
            "physical_spill_count": int(peak["physical_spill_count"]),
            "overflow_count": int(peak["overflow_count"]),
            "day2_sample": archetype_id in day2_preferences,
            "selection_reason": (
                "requested day-2 scenario is tied for the room peak"
                if preferred_id and str(selected["scenario_id"]) == preferred_id
                else "first scenario/map by id among the true room-peak ties"
            ),
        })
    return result


def validate_map(check: Check, map_data: dict[str, Any], archetype: dict[str, Any], board: tuple[float, float]) -> None:
    map_id = str(map_data.get("id", "<missing>"))
    check.require(map_data.get("slot_schema_version") == 1, f"{map_id}: slot_schema_version must be 1")
    overflow_value = map_data.get("scenario_overflow_ids")
    check.require(isinstance(overflow_value, list), f"{map_id}: scenario_overflow_ids must be an array")
    overflow_ids = overflow_value if isinstance(overflow_value, list) else []
    valid_overflow_ids = [
        identity
        for identity in overflow_ids
        if isinstance(identity, str)
        and bool(identity)
        and identity == identity.strip()
        and not identity.startswith("scenario::")
    ]
    check.require(
        len(valid_overflow_ids) == len(overflow_ids),
        f"{map_id}: scenario_overflow_ids must contain only non-empty unprefixed stable identities",
    )
    check.require(
        valid_overflow_ids == sorted(set(valid_overflow_ids)),
        f"{map_id}: scenario_overflow_ids must be sorted and duplicate-free",
    )
    art_value = map_data.get("scenario_art_keys")
    check.require(isinstance(art_value, dict), f"{map_id}: scenario_art_keys must be an object")
    art_keys = art_value if isinstance(art_value, dict) else {}
    preferences = map_data.get("scenario_slot_ids", {}) if isinstance(map_data.get("scenario_slot_ids"), dict) else {}
    for stable_id, art_key in art_keys.items():
        clean_id = str(stable_id)
        check.require(
            isinstance(stable_id, str) and bool(clean_id) and clean_id == clean_id.strip()
            and not clean_id.startswith("scenario::") and "|" not in clean_id,
            f"{map_id}.scenario_art_keys contains malformed stable identity {stable_id!r}",
        )
        check.require(
            isinstance(art_key, str) and art_key in CONCRETE_SCENARIO_ART_KEYS,
            f"{map_id}.scenario_art_keys.{clean_id} names unsupported concrete renderer {art_key!r}",
        )
        check.require(
            clean_id in preferences or f"scenario::{clean_id}" in preferences
            or any(str(key).startswith(f"{clean_id}|") for key in preferences),
            f"{map_id}.scenario_art_keys.{clean_id} has no exact scenario_slot_ids authority",
        )
    check.require(
        all(stable_id in art_keys for stable_id in valid_overflow_ids),
        f"{map_id}: scenario_overflow_ids contains a nonphysical/action-list identity",
    )
    slots = all_slots(map_data)
    check.require(bool(values(map_data.get("base_slots"))), f"{map_id}: no base slots")
    check.require(bool(values(map_data.get("stage_slots"))), f"{map_id}: no stage slots")
    check.require(len(values(map_data.get("exit_slots"))) >= 2, f"{map_id}: fewer than two exit slots")
    slot_by_id: dict[str, dict[str, Any]] = {}
    supports = named_supports(map_data)
    counters_by_id = {
        str(counter.get("id", "")): counter
        for counter in values(map_data.get("counters"))
        if isinstance(counter, dict) and str(counter.get("id", ""))
    }
    zones = archetype.get("semantic_zones", {}) if isinstance(archetype.get("semantic_zones"), dict) else {}
    board_rect = (0.0, 0.0, board[0], board[1])
    for field in MAP_SLOT_FIELDS:
        expected_kind = field.removesuffix("_slots")
        for slot in values(map_data.get(field)):
            if not isinstance(slot, dict):
                check.errors.append(f"{map_id}.{field}: slot must be an object")
                continue
            slot_id = str(slot.get("id", ""))
            check.require(set(slot) == SLOT_FIELDS, f"{map_id}.{slot_id}: slot record is not closed")
            check.require(bool(slot_id) and slot_id not in slot_by_id, f"{map_id}: duplicate/empty slot id {slot_id!r}")
            slot_by_id[slot_id] = slot
            placement_class = str(slot.get("footprint_class", ""))
            check.require(slot.get("kind") == expected_kind and expected_kind in KINDS, f"{map_id}.{slot_id}: kind/collection mismatch")
            check.require(placement_class in CLASSES, f"{map_id}.{slot_id}: invalid footprint_class")
            check.require(str(slot.get("facing", "")) in FACINGS, f"{map_id}.{slot_id}: invalid facing")
            check.require(isinstance(slot.get("priority"), int) and int(slot.get("priority", -1)) >= 0, f"{map_id}.{slot_id}: invalid priority")
            hit = rect(slot.get("hit_rect"))
            anchor = point(slot.get("label_anchor"))
            position = point(slot.get("pos"))
            check.require(hit is not None and hit[2] > 0 and hit[3] > 0 and encloses(board_rect, hit), f"{map_id}.{slot_id}: invalid hit_rect")
            check.require(anchor is not None and 0 <= anchor[0] <= board[0] and 0 <= anchor[1] <= board[1], f"{map_id}.{slot_id}: invalid label_anchor")
            check.require(position is not None and 0 <= position[0] <= board[0] and 0 <= position[1] <= board[1], f"{map_id}.{slot_id}: invalid pos")
            zone_id = str(slot.get("zone_id", ""))
            check.require(bool(zone_id), f"{map_id}.{slot_id}: missing semantic zone id")
            support_kind = expected_support_kind(placement_class)
            support_id = str(slot.get("support_id", ""))
            if support_kind == "floor":
                check.require(support_id in {"floor", "stage"}, f"{map_id}.{slot_id}: invalid floor support {support_id}")
            elif support_kind in {"wall", "ceiling"}:
                check.require(support_id == support_kind or bool(support_id), f"{map_id}.{slot_id}: invalid {support_kind} support")
            else:
                check.require(support_id in supports[support_kind], f"{map_id}.{slot_id}: unknown {support_kind} support {support_id}")
            lane_ids = values(slot.get("walk_lane_ids"))
            check.require(all(isinstance(item, str) and item for item in lane_ids), f"{map_id}.{slot_id}: invalid walk_lane_ids")

    lanes: dict[str, dict[str, Any]] = {}
    for lane in values(map_data.get("walk_lanes")):
        if not isinstance(lane, dict):
            check.errors.append(f"{map_id}: walk lane must be an object")
            continue
        lane_id = str(lane.get("id", ""))
        check.require(bool(lane_id) and lane_id not in lanes, f"{map_id}: duplicate/empty walk lane {lane_id!r}")
        lanes[lane_id] = lane
        points = values(lane.get("points"))
        check.require(len(points) >= 2 and all(point(item) is not None for item in points), f"{map_id}.{lane_id}: invalid lane points")
        check.require(str(lane.get("direction", "")) in {"both", "forward", "reverse"}, f"{map_id}.{lane_id}: invalid direction")
    entry_lanes = {lane_id for lane_id, lane in lanes.items() if lane.get("entry") is True}
    check.require(bool(entry_lanes), f"{map_id}: no entry walk lane")
    for slot in slots:
        slot_id = str(slot.get("id", ""))
        for lane_id in values(slot.get("walk_lane_ids")):
            check.require(lane_id in lanes, f"{map_id}.{slot_id}: unknown lane {lane_id}")
        if slot.get("kind") == "exit":
            check.require(bool(set(values(slot.get("walk_lane_ids"))) & entry_lanes), f"{map_id}.{slot_id}: exit has no reachable entry lane")

    # The slot catalog is a union of mutually exclusive base rolls, scenario
    # phases, and fallback capacity. Pairwise static overlap is therefore not a
    # legal-live-state assertion; the multi-seed finalizer and renderer guard
    # validate the actual compositions instead.

    for preference_field in ("object_slot_ids", "category_slot_ids", "scenario_slot_ids"):
        preferences = map_data.get(preference_field, {})
        check.require(isinstance(preferences, dict), f"{map_id}: {preference_field} must be an object")
        if isinstance(preferences, dict):
            expected_kinds = {"stage", "exit"} if preference_field == "scenario_slot_ids" else {"base"}
            for identity, slot_id in preferences.items():
                slot = slot_by_id.get(str(slot_id), {})
                check.require(bool(str(identity)) and bool(slot), f"{map_id}.{preference_field}: {identity} names unknown slot {slot_id}")
                check.require(not slot or slot.get("kind") in expected_kinds, f"{map_id}.{preference_field}: {identity} names an invalid slot kind")
    position_route_preferences = map_data.get("scenario_position_route_ids", {})
    check.require(isinstance(position_route_preferences, dict), f"{map_id}: scenario_position_route_ids must be an object")

    for route in values(map_data.get("actor_routes")):
        if not isinstance(route, dict):
            check.errors.append(f"{map_id}: actor route must be an object")
            continue
        route_id = str(route.get("id", ""))
        start_id, end_id = str(route.get("start_slot_id", "")), str(route.get("end_slot_id", ""))
        start, end = slot_by_id.get(start_id, {}), slot_by_id.get(end_id, {})
        check.require(bool(route_id) and start_id != end_id and bool(start) and bool(end), f"{map_id}.{route_id}: invalid route endpoints")
        check.require(not start or start.get("kind") == "stage", f"{map_id}.{route_id}: start is not a stage slot")
        check.require(not end or end.get("kind") == "stage", f"{map_id}.{route_id}: end is not a stage slot")
        check.require(not start or not end or start.get("footprint_class") == end.get("footprint_class") == route.get("footprint_class"), f"{map_id}.{route_id}: route class mismatch")
        route_lanes = values(route.get("lane_ids"))
        check.require(bool(route_lanes) and all(str(item) in lanes for item in route_lanes), f"{map_id}.{route_id}: unknown/empty lane path")
        start_lanes = {str(item) for item in values(start.get("walk_lane_ids"))}
        end_lanes = {str(item) for item in values(end.get("walk_lane_ids"))}
        route_lane_ids = [str(item) for item in route_lanes]
        check.require(bool(start_lanes & set(route_lane_ids)), f"{map_id}.{route_id}: start endpoint has no route-lane attachment")
        check.require(bool(end_lanes & set(route_lane_ids)), f"{map_id}.{route_id}: end endpoint has no route-lane attachment")
        check.require(not route_lane_ids or route_lane_ids[0] in start_lanes, f"{map_id}.{route_id}: first lane is not attached to the start endpoint")
        check.require(not route_lane_ids or route_lane_ids[-1] in end_lanes, f"{map_id}.{route_id}: last lane is not attached to the end endpoint")
        check.require(len(route_lane_ids) == len(set(route_lane_ids)), f"{map_id}.{route_id}: lane path repeats a lane")
        valid_route_lanes = [lanes[lane_id] for lane_id in route_lane_ids if lane_id in lanes]
        for left_lane, right_lane in zip(valid_route_lanes, valid_route_lanes[1:]):
            left_points = [parsed for item in values(left_lane.get("points")) if (parsed := point(item)) is not None]
            right_points = [parsed for item in values(right_lane.get("points")) if (parsed := point(item)) is not None]
            endpoint_gap = min(
                (math.dist(left_point, right_point) for left_point in (left_points[0], left_points[-1]) for right_point in (right_points[0], right_points[-1])),
                default=math.inf,
            )
            check.require(endpoint_gap <= EPSILON, f"{map_id}.{route_id}: consecutive authored lanes do not connect")
        start_position, end_position = point(start.get("pos")), point(end.get("pos"))
        if valid_route_lanes and start_position is not None and end_position is not None:
            first_points = [parsed for item in values(valid_route_lanes[0].get("points")) if (parsed := point(item)) is not None]
            last_points = [parsed for item in values(valid_route_lanes[-1].get("points")) if (parsed := point(item)) is not None]
            start_projection = polyline_projection(first_points, start_position)
            end_projection = polyline_projection(last_points, end_position)
            check.require(start_projection is not None and start_projection[2] <= max(board), f"{map_id}.{route_id}: start endpoint has no finite connector to its first lane")
            check.require(end_projection is not None and end_projection[2] <= max(board), f"{map_id}.{route_id}: end endpoint has no finite connector to its last lane")
            check.require(
                math.dist(start_position, end_position) > EPSILON,
                f"{map_id}.{route_id}: distinct slot ids resolve to the same physical endpoint",
            )
        check.require(str(route.get("reduced_motion_slot_id", "")) in {start_id, end_id}, f"{map_id}.{route_id}: invalid reduced-motion endpoint")
    route_ids = {str(route.get("id", "")) for route in values(map_data.get("actor_routes")) if isinstance(route, dict)}
    if isinstance(position_route_preferences, dict):
        for state_key, route_id in position_route_preferences.items():
            check.require(bool(str(state_key)) and str(route_id) in route_ids, f"{map_id}.scenario_position_route_ids: {state_key} names unknown route {route_id}")


def validate_single_json_slot_extension(
    check: Check,
    maps_by_id: dict[str, dict[str, Any]],
    archetypes: dict[str, dict[str, Any]],
    board: tuple[float, float],
) -> None:
    """Prove a hand-authored slot is valid without regenerating slot arrays."""
    source = maps_by_id.get("corner_store", {})
    check.require(bool(source), "single-JSON-slot regression requires corner_store")
    if not source:
        return
    extended = copy.deepcopy(source)
    extra_slot = {
        "id": "stage.wall_mounted.modularity_probe",
        "kind": "stage",
        "pos": [334.0, 34.0],
        "footprint_class": "wall_mounted",
        "hit_rect": [302.0, 14.0, 64.0, 40.0],
        "label_anchor": [334.0, 18.0],
        "facing": "front",
        "priority": 999,
        "zone_id": "room",
        "support_id": "wall",
        "walk_lane_ids": [],
    }
    original_stage_slots = values(source.get("stage_slots"))
    check.require(
        all(str(slot.get("id", "")) != extra_slot["id"] for slot in original_stage_slots if isinstance(slot, dict)),
        "single-JSON-slot regression id unexpectedly exists in authored data",
    )
    extended["stage_slots"] = copy.deepcopy(original_stage_slots) + [extra_slot]
    extension_check = Check()
    validate_map(extension_check, extended, archetypes.get("corner_store", {}), board)
    check.require(
        not extension_check.errors,
        "single JSON stage-slot edit was rejected by the authored-data validator: " + "; ".join(extension_check.errors),
    )
    check.require(
        len(values(source.get("stage_slots"))) + 1 == len(values(extended.get("stage_slots"))),
        "single-JSON-slot regression mutated the source map instead of its in-memory copy",
    )


def scenario_visual_ids(scenario: dict[str, Any]) -> set[str]:
    identities: set[str] = set()

    def visit(value: Any, parents: tuple[str, ...] = ()) -> None:
        if isinstance(value, dict):
            stable_id = value.get("stable_object_id")
            semantic_kind = str(value.get("semantic_kind", ""))
            family = str(value.get("family", ""))
            context = " ".join(parents + (family, semantic_kind)).lower()
            if isinstance(stable_id, str) and stable_id and any(token in context for token in ("scene", "actor", "visual")):
                identities.add(stable_id)
            for key, child in value.items():
                visit(child, parents + (str(key),))
        elif isinstance(value, list):
            for child in value:
                visit(child, parents)

    visit(scenario)
    return identities


def validate_map_v2(
    check: Check,
    map_data: dict[str, Any],
    archetype: dict[str, Any],
    board: tuple[float, float],
) -> None:
    """Validate the four-family placement authority without a Godot launch."""
    map_id = str(map_data.get("id", "")).strip()
    check.require(bool(map_id), "placement map id is empty")
    check.require(int(map_data.get("slot_schema_version", 0)) == 2, f"{map_id}: slot_schema_version must be 2")
    check.require(bool(archetype), f"{map_id}: archetype declaration is missing")

    slots_by_id: dict[str, dict[str, Any]] = {}
    slots_by_family: dict[str, dict[str, dict[str, Any]]] = {}
    for family in V2_FAMILIES:
        field = f"{family}_slots"
        raw_slots = map_data.get(field)
        check.require(isinstance(raw_slots, list), f"{map_id}: {field} must be an array")
        family_slots: dict[str, dict[str, Any]] = {}
        canonical_ordinals: dict[str, int] = {}
        for index, value in enumerate(values(raw_slots)):
            check.require(isinstance(value, dict), f"{map_id}.{field}[{index}] must be an object")
            if not isinstance(value, dict):
                continue
            slot_id = str(value.get("id", "")).strip()
            prefix = slot_id.split(".", 1)[0] if "." in slot_id else ""
            check.require(bool(slot_id), f"{map_id}.{field}[{index}] has no id")
            check.require(prefix == family, f"{map_id}.{slot_id}: id prefix must be {family}.")
            check.require(str(value.get("kind", "")) == family, f"{map_id}.{slot_id}: kind must be {family}")
            check.require(slot_id not in slots_by_id, f"{map_id}: duplicate slot id {slot_id}")
            check.require(
                set(value) == V2_SLOT_FIELDS,
                f"{map_id}.{slot_id}: v2 slot record is not closed; "
                f"missing={sorted(V2_SLOT_FIELDS - set(value))} "
                f"extra={sorted(set(value) - V2_SLOT_FIELDS)}",
            )
            placement_class = str(value.get("footprint_class", ""))
            check.require(placement_class in CLASSES, f"{map_id}.{slot_id}: invalid footprint_class {placement_class}")
            if family in {"event", "scenario"} and placement_class in V2_GENERIC_ROLE:
                role = V2_GENERIC_ROLE[placement_class]
                canonical_ordinals[role] = canonical_ordinals.get(role, 0) + 1
                expected_slot_id = f"{family}.{role}_{canonical_ordinals[role]}"
                check.require(
                    slot_id == expected_slot_id,
                    f"{map_id}.{slot_id}: canonical id must be {expected_slot_id}",
                )
            check.require(str(value.get("facing", "")) in FACINGS, f"{map_id}.{slot_id}: invalid facing")
            check.require(
                isinstance(value.get("priority"), int) and not isinstance(value.get("priority"), bool),
                f"{map_id}.{slot_id}: priority must be an integer",
            )
            position = point(value.get("pos"))
            bounds = rect(value.get("hit_rect"))
            label = point(value.get("label_anchor"))
            check.require(position is not None, f"{map_id}.{slot_id}: invalid pos")
            check.require(bounds is not None, f"{map_id}.{slot_id}: invalid hit_rect")
            check.require(label is not None, f"{map_id}.{slot_id}: invalid label_anchor")
            if position is not None:
                check.require(
                    0.0 <= position[0] <= board[0] and 0.0 <= position[1] <= board[1],
                    f"{map_id}.{slot_id}: pos leaves board",
                )
            if bounds is not None:
                check.require(bounds[2] > 0.0 and bounds[3] > 0.0, f"{map_id}.{slot_id}: hit_rect must have positive size")
                check.require(encloses((0.0, 0.0, board[0], board[1]), bounds), f"{map_id}.{slot_id}: hit_rect leaves board")
            # Labels may intentionally sit just outside the board edge so the
            # developer overlay does not cover the target it annotates.
            check.require(isinstance(value.get("walk_lane_ids", []), list), f"{map_id}.{slot_id}: walk_lane_ids must be an array")
            check.require(
                isinstance(value.get("occupancy_required"), bool),
                f"{map_id}.{slot_id}: occupancy_required must be an explicit boolean",
            )
            check.require(
                isinstance(value.get("physical_role"), str)
                and bool(str(value.get("physical_role", "")).strip()),
                f"{map_id}.{slot_id}: physical_role must be a non-empty string",
            )
            occupant_ids = value.get("occupant_ids")
            check.require(
                isinstance(occupant_ids, list)
                and all(isinstance(item, str) and item.strip() for item in occupant_ids),
                f"{map_id}.{slot_id}: occupant_ids must contain non-empty strings",
            )
            if isinstance(occupant_ids, list):
                check.require(
                    occupant_ids == sorted(set(occupant_ids)),
                    f"{map_id}.{slot_id}: occupant_ids must be sorted and unique",
                )
            runtime_reserve = value.get("runtime_reserve")
            reserve_reason = value.get("reserve_reason")
            check.require(
                isinstance(runtime_reserve, bool),
                f"{map_id}.{slot_id}: runtime_reserve must be an explicit boolean",
            )
            check.require(
                isinstance(reserve_reason, str),
                f"{map_id}.{slot_id}: reserve_reason must be a string",
            )
            if isinstance(runtime_reserve, bool) and isinstance(reserve_reason, str):
                check.require(
                    runtime_reserve == bool(reserve_reason.strip()),
                    f"{map_id}.{slot_id}: reserve_reason must be non-empty exactly when runtime_reserve is true",
                )
            family_slots[slot_id] = value
            slots_by_id[slot_id] = value
        slots_by_family[family] = family_slots

    for family, targets in (
        ("event", V2_EVENT_CAPACITY_TARGETS.get(map_id, {})),
        ("scenario", V2_SCENARIO_CAPACITY_TARGETS.get(map_id, {})),
    ):
        actual: dict[str, int] = {}
        for slot in slots_by_family.get(family, {}).values():
            placement_class = str(slot.get("footprint_class", ""))
            actual[placement_class] = actual.get(placement_class, 0) + 1
        expected = {
            placement_class: count
            for placement_class, count in targets.items()
            if count > 0
        }
        check.require(
            actual == expected,
            f"{map_id}: {family} capacity matrix drift; "
            f"expected={expected} actual={actual}",
        )

    for legacy_field in ("base_slots", "stage_slots", "object_slot_ids", "category_slot_ids"):
        check.require(legacy_field not in map_data, f"{map_id}: legacy field {legacy_field} is forbidden in slot schema v2")

    for family in V2_FAMILIES:
        for suffix in ("object_slot_ids", "category_slot_ids"):
            field = f"{family}_{suffix}"
            preferences = map_data.get(field)
            check.require(isinstance(preferences, dict), f"{map_id}: {field} must be an object")
            if not isinstance(preferences, dict):
                continue
            for claimant, preferred_slot_value in preferences.items():
                preferred_slot = str(preferred_slot_value)
                check.require(bool(str(claimant).strip()), f"{map_id}.{field}: empty claimant")
                check.require(
                    preferred_slot in slots_by_family[family],
                    f"{map_id}.{field}.{claimant}: {preferred_slot} is not a {family} slot",
                )

    scenario_preferences = map_data.get("scenario_slot_ids")
    check.require(isinstance(scenario_preferences, dict), f"{map_id}: scenario_slot_ids must be an object")
    if isinstance(scenario_preferences, dict):
        for claimant, preferred_slot_value in scenario_preferences.items():
            preferred_slot = str(preferred_slot_value)
            check.require(
                preferred_slot in slots_by_family["scenario"],
                f"{map_id}.scenario_slot_ids.{claimant}: {preferred_slot} is not a scenario slot",
            )

    family_declarations = map_data.get("object_family_ids")
    check.require(isinstance(family_declarations, dict), f"{map_id}: object_family_ids must be an object")
    if isinstance(family_declarations, dict):
        for object_id, family_value in family_declarations.items():
            check.require(bool(str(object_id).strip()), f"{map_id}.object_family_ids contains an empty object id")
            check.require(
                str(family_value) in V2_FAMILIES,
                f"{map_id}.object_family_ids.{object_id}: invalid family {family_value}",
            )

    fixed_objects = map_data.get("fixed_objects")
    check.require(isinstance(fixed_objects, list), f"{map_id}: fixed_objects must be an array")
    fixed_object_ids: set[str] = set()
    required_fixed_slots: set[str] = set()
    if isinstance(fixed_objects, list):
        for index, value in enumerate(fixed_objects):
            check.require(isinstance(value, dict), f"{map_id}.fixed_objects[{index}] must be an object")
            if not isinstance(value, dict):
                continue
            object_id = str(value.get("object_id", "")).strip()
            presentation_id = str(value.get("presentation_id", "")).strip()
            exact_slot = str(value.get("exact_slot_id", value.get("slot_id", ""))).strip()
            placement_class = str(value.get("placement_class", "")).strip()
            check.require(bool(object_id), f"{map_id}.fixed_objects[{index}] has no object_id")
            check.require(object_id not in fixed_object_ids, f"{map_id}: duplicate fixed object {object_id}")
            check.require(bool(presentation_id), f"{map_id}.{object_id}: presentation_id is empty")
            check.require(str(value.get("family", "fixed")) == "fixed", f"{map_id}.{object_id}: fixed declaration has non-fixed family")
            check.require(isinstance(value.get("required"), bool), f"{map_id}.{object_id}: required must be boolean")
            check.require(exact_slot in slots_by_family["fixed"], f"{map_id}.{object_id}: exact fixed slot {exact_slot} is missing")
            if exact_slot in slots_by_family["fixed"]:
                check.require(
                    placement_class == str(slots_by_family["fixed"][exact_slot].get("footprint_class", "")),
                    f"{map_id}.{object_id}: placement class does not match {exact_slot}",
                )
            action_ids = value.get("action_ids")
            check.require(isinstance(action_ids, list), f"{map_id}.{object_id}: action_ids must be an array")
            if isinstance(action_ids, list):
                check.require(
                    all(isinstance(action_id, str) and action_id.strip() for action_id in action_ids),
                    f"{map_id}.{object_id}: action_ids contain an invalid value",
                )
                check.require(len(action_ids) == len(set(action_ids)), f"{map_id}.{object_id}: action_ids must be unique")
            fixed_object_ids.add(object_id)
            if bool(value.get("required", False)) and exact_slot:
                required_fixed_slots.add(exact_slot)

    for slot_id, slot in slots_by_id.items():
        check.require(
            bool(slot.get("occupancy_required", False)) == (slot_id in required_fixed_slots),
            f"{map_id}.{slot_id}: occupancy_required must match an exact required fixed declaration",
        )


def _v2_interaction_navigates_environment(interaction: dict[str, Any]) -> bool:
    for flag in ("navigation_exit", "navigates_environment", "travel_exit"):
        if interaction.get(flag) is True:
            return True
    destination_keys = (
        "destination_archetype", "destination_environment_id", "destination_layer_id",
        "target_environment_id", "target_layer_id",
    )
    if any(str(interaction.get(key, "")).strip() for key in destination_keys):
        return True
    navigation_handlers = {
        "travel", "travel_to_environment", "change_environment", "change_layer",
        "enter_layer", "leave_environment",
    }
    for action in values(interaction.get("available_actions")):
        if not isinstance(action, dict):
            continue
        if str(action.get("handler", "")).strip() in navigation_handlers:
            return True
        inputs = action.get("inputs", {}) if isinstance(action.get("inputs"), dict) else {}
        if any(str(inputs.get(key, "")).strip() for key in destination_keys):
            return True
    return False


def _v2_scenario_art_key(
    map_data: dict[str, Any],
    semantic: dict[str, Any],
    actor: bool,
    safe_exit: bool,
    navigation_exit: bool,
) -> str:
    if actor:
        return ""
    if safe_exit or navigation_exit:
        return "side_door"
    identity = str(semantic.get("identity", "")).strip()
    stable_id = str(semantic.get("stable_object_id", identity.removeprefix("scenario::"))).strip()
    if scenario_semantic_is_abstract(stable_id, semantic):
        return ""
    art_keys = map_data.get("scenario_art_keys", {}) if isinstance(map_data.get("scenario_art_keys"), dict) else {}
    authored_payload_key = str(semantic.get("icon_key", "")).strip()
    art_key = str(art_keys.get(stable_id, art_keys.get(identity, authored_payload_key))).strip()
    return art_key if art_key in CONCRETE_SCENARIO_ART_KEYS else ""


def _v2_scenario_preference(
    map_data: dict[str, Any],
    family: str,
    identity: str,
    stable_id: str,
    position_key: str,
) -> tuple[str, bool]:
    if family == "scenario":
        semantic_preferences = map_data.get("scenario_slot_ids", {}) \
            if isinstance(map_data.get("scenario_slot_ids"), dict) else {}
        for key in (position_key, stable_id, identity):
            if key and key in semantic_preferences:
                return str(semantic_preferences.get(key, "")).strip(), False
    object_preferences = map_data.get(f"{family}_object_slot_ids", {}) \
        if isinstance(map_data.get(f"{family}_object_slot_ids"), dict) else {}
    for key in (position_key, stable_id, identity):
        if key and key in object_preferences:
            return str(object_preferences.get(key, "")).strip(), family == "exit"
    return "", False


def _v2_route_has_authored_geometry(
    map_data: dict[str, Any],
    start_slot: dict[str, Any],
    lane_ids: list[str],
) -> bool:
    """Mirror the binder's closed, connected authored-lane requirement."""
    if not lane_ids:
        return False
    lanes = {
        str(lane.get("id", "")): lane
        for lane in values(map_data.get("walk_lanes"))
        if isinstance(lane, dict) and str(lane.get("id", ""))
    }
    start_rect = rect(start_slot.get("hit_rect"))
    if start_rect is None:
        return False
    approach = point(start_slot.get("pos")) or (
        start_rect[0] + start_rect[2] / 2.0,
        start_rect[1] + start_rect[3] / 2.0,
    )
    polyline: list[tuple[float, float]] = []
    for lane_id in lane_ids:
        lane = lanes.get(lane_id, {})
        lane_points = [parsed for raw in values(lane.get("points")) if (parsed := point(raw)) is not None]
        if len(lane_points) < 2 or len(lane_points) != len(values(lane.get("points"))):
            return False
        direction = str(lane.get("direction", "both"))
        if direction == "reverse":
            lane_points.reverse()
        elif direction == "both":
            prior = approach if not polyline else polyline[-1]
            if math.dist(prior, lane_points[-1]) < math.dist(prior, lane_points[0]):
                lane_points.reverse()
        if polyline and math.dist(polyline[-1], lane_points[0]) > EPSILON:
            return False
        for lane_point in lane_points:
            if not polyline or math.dist(polyline[-1], lane_point) > EPSILON:
                polyline.append(lane_point)
    return len(polyline) >= 2


def _v2_bind_scenario_snapshot(
    map_data: dict[str, Any],
    snapshot: list[dict[str, Any]],
) -> dict[str, Any]:
    """Engine-free replay of the production v2 scenario-slot decisions."""
    map_id = str(map_data.get("id", "<missing>"))
    family_slots = {
        family: ordered_slots(map_data, f"{family}_slots")
        for family in ("scenario", "exit")
    }
    slot_by_id = {
        str(slot.get("id", "")): slot
        for slots in family_slots.values()
        for slot in slots
    }
    routes = {
        str(route.get("id", "")): route
        for route in values(map_data.get("actor_routes"))
        if isinstance(route, dict) and str(route.get("id", ""))
    }
    position_routes = map_data.get("scenario_position_route_ids", {}) \
        if isinstance(map_data.get("scenario_position_route_ids"), dict) else {}
    class_overrides = map_data.get("class_overrides", {}) \
        if isinstance(map_data.get("class_overrides"), dict) else {}
    errors: list[str] = []
    entries: list[dict[str, Any]] = []
    bindings: dict[str, dict[str, Any]] = {}
    seen_visual_ids: set[str] = set()
    authored_action_count = 0
    for semantic in snapshot:
        if not isinstance(semantic, dict):
            errors.append(f"{map_id}: scenario snapshot contains a non-object record")
            continue
        interaction = semantic.get("_slot_interaction", {}) \
            if isinstance(semantic.get("_slot_interaction"), dict) else {}
        if not bool(semantic.get("_slot_nonvisual", False)):
            authored_action_count += sum(
                1 for action in values(interaction.get("available_actions"))
                if isinstance(action, dict) and str(action.get("id", "")).strip()
            )
        if bool(semantic.get("_slot_interaction_only", False)) \
                or bool(semantic.get("_slot_nonvisual", False)):
            continue
        identity = str(semantic.get("identity", "")).strip()
        if not identity.startswith("scenario::") or not bool(semantic.get("present", True)):
            continue
        if identity in seen_visual_ids:
            errors.append(f"{map_id}.{identity}: duplicate scenario visual identity")
            continue
        seen_visual_ids.add(identity)
        stable_id = identity.removeprefix("scenario::")
        actor = bool(semantic.get("_slot_actor", False))
        safe_exit = bool(interaction.get("safe_exit", semantic.get("safe_exit", False)))
        navigation_exit = _v2_interaction_navigates_environment(interaction)
        slot_family = "exit" if navigation_exit else "scenario"
        art_key = _v2_scenario_art_key(map_data, semantic, actor, safe_exit, navigation_exit)
        if not (actor or safe_exit or navigation_exit or art_key):
            bindings[identity] = {
                "mode": "attached", "slot_id": "", "slot_family": "",
                "placement_class": "", "art_key": "", "reserved_slot_ids": [],
            }
            continue
        classified = copy.deepcopy(semantic)
        if art_key:
            classified["icon_key"] = art_key
        placement_class = SlotAuthoring.classify_with_override(
            classified,
            "actor" if actor else "scene_object",
            identity,
            str(class_overrides.get(identity, class_overrides.get(stable_id, ""))),
        )
        if safe_exit:
            placement_class = "doorway"
        position_key = SlotAuthoring.scenario_position_key(stable_id, semantic)
        route_id = str(semantic.get("route_id", "")).strip() \
            or str(position_routes.get(position_key, "")).strip()
        entries.append({
            "identity": identity,
            "stable_id": stable_id,
            "semantic": semantic,
            "position_key": position_key,
            "slot_family": slot_family,
            "placement_class": placement_class,
            "route_id": route_id,
            "art_key": art_key,
            "rank": 0 if slot_family == "exit" else 1 if route_id else 2,
        })
    entries.sort(key=lambda entry: (int(entry["rank"]), str(entry["identity"])))

    occupied: dict[str, str] = {}
    reservation_claims: list[tuple[str, str]] = []
    for entry in entries:
        identity = str(entry["identity"])
        family = str(entry["slot_family"])
        placement_class = str(entry["placement_class"])
        route_id = str(entry["route_id"])
        selected: dict[str, Any] | None = None
        reserved_slot_ids: list[str] = []
        if route_id:
            route = routes.get(route_id, {})
            start_id = str(route.get("start_slot_id", ""))
            end_id = str(route.get("end_slot_id", ""))
            start_slot = slot_by_id.get(start_id, {})
            end_slot = slot_by_id.get(end_id, {})
            lane_ids = [str(value) for value in values(route.get("lane_ids"))]
            route_geometry_valid = bool(route) and family == "scenario" \
                and start_id != end_id \
                and str(start_slot.get("kind", "")) == "scenario" \
                and str(end_slot.get("kind", "")) == "scenario" \
                and str(start_slot.get("footprint_class", "")) == placement_class \
                and str(end_slot.get("footprint_class", "")) == placement_class \
                and slot_meets_interactive_minimum(start_slot) \
                and slot_meets_interactive_minimum(end_slot) \
                and _v2_route_has_authored_geometry(map_data, start_slot, lane_ids)
            if not route_geometry_valid:
                errors.append(
                    f"{map_id}.{identity}: route {route_id} has invalid, incompatible, "
                    "or disconnected authored scenario endpoints"
                )
            elif start_id not in occupied and end_id not in occupied:
                selected = start_slot
                reserved_slot_ids = [start_id, end_id]
        else:
            preference, exact = _v2_scenario_preference(
                map_data,
                family,
                identity,
                str(entry["stable_id"]),
                str(entry["position_key"]),
            )
            candidate_slots = family_slots.get(family, [])
            if family == "exit" and preference:
                preferred_slot = slot_by_id.get(preference, {})
                preferred_class = str(preferred_slot.get("footprint_class", ""))
                if preferred_class in CLASSES:
                    placement_class = preferred_class
                    entry["placement_class"] = placement_class
            preferred = next((
                slot for slot in candidate_slots
                if str(slot.get("id", "")) == preference
                and str(slot.get("footprint_class", "")) == placement_class
                and str(slot.get("id", "")) not in occupied
                and slot_meets_interactive_minimum(slot)
            ), None)
            if preferred is not None:
                selected = preferred
            elif not exact:
                selected = next((
                    slot for slot in candidate_slots
                    if str(slot.get("footprint_class", "")) == placement_class
                    and str(slot.get("id", "")) not in occupied
                    and slot_meets_interactive_minimum(slot)
                ), None)
            if selected is not None:
                reserved_slot_ids = [str(selected.get("id", ""))]
        if selected is None:
            bindings[identity] = {
                "mode": "missing", "slot_id": "", "slot_family": family,
                "placement_class": placement_class, "art_key": str(entry["art_key"]),
                "route_id": route_id, "reserved_slot_ids": [],
            }
            errors.append(
                f"{map_id}.{identity}: no free compatible authored "
                f"{family}.{placement_class} slot"
            )
            continue
        for slot_id in reserved_slot_ids:
            reservation_claims.append((slot_id, identity))
            occupied[slot_id] = identity
        bindings[identity] = {
            "mode": "room",
            "slot_id": str(selected.get("id", "")),
            "slot_family": family,
            "placement_class": placement_class,
            "art_key": str(entry["art_key"]),
            "route_id": route_id,
            "reserved_slot_ids": reserved_slot_ids,
        }

    claims_by_slot: dict[str, set[str]] = {}
    for slot_id, identity in reservation_claims:
        claims_by_slot.setdefault(slot_id, set()).add(identity)
    conflicting_slots = {
        slot_id: sorted(identities)
        for slot_id, identities in claims_by_slot.items()
        if len(identities) > 1
    }
    for slot_id, identities in sorted(conflicting_slots.items()):
        errors.append(f"{map_id}.{slot_id}: conflicting scenario reservations {identities}")
    room_count = sum(1 for binding in bindings.values() if binding["mode"] == "room")
    missing_count = sum(1 for binding in bindings.values() if binding["mode"] == "missing")
    attached_count = sum(1 for binding in bindings.values() if binding["mode"] == "attached")
    return {
        "bindings": bindings,
        "room_count": room_count,
        "missing_count": missing_count,
        "attached_count": attached_count,
        "authored_action_count": authored_action_count,
        "reservation_count": len(reservation_claims),
        "conflict_count": len(conflicting_slots),
        "errors": errors,
    }


def _v2_snapshot_rows(
    check: Check,
    maps_by_id: dict[str, dict[str, Any]],
    snapshot_maps: dict[str, list[list[dict[str, Any]]]],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for map_id, snapshots in sorted(snapshot_maps.items()):
        map_data = maps_by_id.get(map_id, {})
        check.require(bool(map_data), f"scenario phase inventory references missing v2 map {map_id}")
        for snapshot in snapshots:
            scenario_id, phase_id = snapshot_tags(snapshot)
            first = _v2_bind_scenario_snapshot(map_data, snapshot)
            repeated = _v2_bind_scenario_snapshot(map_data, snapshot)
            check.require(
                first == repeated,
                f"{map_id}.{scenario_id}/{phase_id}: v2 scenario binding is not deterministic",
            )
            for error in first["errors"]:
                check.require(False, f"{scenario_id}/{phase_id}: {error}")
            check.require(
                int(first["missing_count"]) == 0,
                f"{map_id}.{scenario_id}/{phase_id}: v2 scenario capacity is short by "
                f"{first['missing_count']} physical slot(s)",
            )
            check.require(
                int(first["conflict_count"]) == 0,
                f"{map_id}.{scenario_id}/{phase_id}: v2 scenario binding retained "
                f"{first['conflict_count']} slot conflict(s)",
            )
            missing_identities = sorted(
                identity for identity, binding in first["bindings"].items()
                if str(binding.get("mode", "")) == "missing"
            )
            rows.append({
                "map_id": map_id,
                "scenario_id": scenario_id,
                "phase_id": phase_id,
                "binding_count": int(first["room_count"]) + int(first["missing_count"]),
                "room_count": int(first["room_count"]),
                "physical_room_count": int(first["room_count"]),
                # The report retains its historical overflow field name. Under
                # v2, any value here is a fail-closed missing-capacity result;
                # there is no overflow presentation plane.
                "overflow_count": int(first["missing_count"]),
                "action_list_count": int(first["attached_count"]),
                "physical_spill_count": int(first["missing_count"]),
                "overflow_identities": missing_identities,
                "authored_action_count": int(first["authored_action_count"]),
                "reservation_count": int(first["reservation_count"]),
                "conflict_count": int(first["conflict_count"]),
            })
    return rows


def _v2_iter_dict_nodes(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _v2_iter_dict_nodes(child)
    elif isinstance(value, list):
        for child in value:
            yield from _v2_iter_dict_nodes(child)


def _v2_validate_source_add_claimants(
    check: Check,
    scenario_catalog: dict[str, Any],
    maps_by_id: dict[str, dict[str, Any]],
) -> int:
    """Prove every source-added physical object has compatible scenario capacity."""
    source_fields = {
        "event_pool_add": "event",
        "service_add": "service",
        "item_offer_add": "item",
        "game_pool_add": "game",
    }
    physical_claimants: set[tuple[str, str, str]] = set()
    pawn_item_offers: set[str] = set()
    for map_id, scenarios in scenario_catalog.items():
        map_data = maps_by_id.get(str(map_id), {})
        scenario_slots = {
            str(slot.get("id", "")): slot
            for slot in values(map_data.get("scenario_slots"))
            if isinstance(slot, dict)
        }
        available_classes = {
            str(slot.get("footprint_class", ""))
            for slot in scenario_slots.values()
        }
        for scenario in values(scenarios):
            if not isinstance(scenario, dict):
                continue
            scenario_id = str(scenario.get("id", ""))
            for node in _v2_iter_dict_nodes(scenario):
                for field, prefix in source_fields.items():
                    additions = node.get(field)
                    if not isinstance(additions, list):
                        continue
                    for raw in additions:
                        source_id = (
                            raw.strip()
                            if isinstance(raw, str)
                            else str(raw.get("id", "")).strip()
                            if isinstance(raw, dict)
                            else ""
                        )
                        if not source_id:
                            continue
                        object_id = f"{prefix}:{source_id}"
                        declared_family = str(
                            map_data.get("object_family_ids", {}).get(object_id, "")
                        )
                        exact_slot_id = str(
                            map_data.get("scenario_object_slot_ids", {}).get(
                                object_id, ""
                            )
                        )
                        override = str(
                            map_data.get("class_overrides", {}).get(object_id, "")
                        )
                        placement_class = (
                            "shop_item"
                            if field == "item_offer_add"
                            else override
                            if override in CLASSES
                            else str(
                                scenario_slots.get(exact_slot_id, {}).get(
                                    "footprint_class", ""
                                )
                            )
                        )
                        is_scenario_physical = (
                            declared_family == "scenario"
                            or field in {"item_offer_add", "game_pool_add"}
                        ) and declared_family != "fixed"
                        if not is_scenario_physical or placement_class not in CLASSES:
                            continue
                        physical_claimants.add((str(map_id), scenario_id, object_id))
                        check.require(
                            placement_class in available_classes,
                            f"{map_id}.{scenario_id}: source-added {object_id} "
                            f"has no scenario.{placement_class} capacity",
                        )
                        if str(map_id) == "pawn_shop" and field == "item_offer_add":
                            pawn_item_offers.add(object_id)
    check.require(
        pawn_item_offers == {"item:false_bottom_cup", "item:roadside_map"},
        "pawn_shop: Estate Lot Day must claim both authored shop-item offers",
    )
    check.require(
        V2_SCENARIO_CAPACITY_TARGETS["pawn_shop"].get("shop_item")
        == len(pawn_item_offers),
        "pawn_shop: scenario shop-item bank must match its two simultaneous offers",
    )
    return len(physical_claimants)


def main_v2(
    root: Path,
    report_path: Path,
    placement: dict[str, Any],
    archetypes_list: list[Any],
    scenario_catalog: dict[str, Any],
) -> int:
    """Run the v2 authority check while preserving the established report API."""
    check = Check()
    board_raw = point(placement.get("board_size"))
    check.require(placement.get("schema_version") == 3, "placement_surfaces.json schema_version must be 3")
    check.require(placement.get("slot_schema_version") == 2, "placement_surfaces.json slot_schema_version must be 2")
    check.require(board_raw is not None and board_raw[0] > 0 and board_raw[1] > 0, "invalid placement board_size")
    board = board_raw or (900.0, 430.0)
    archetypes = {str(item.get("id", "")): item for item in archetypes_list if isinstance(item, dict)}
    maps = values(placement.get("maps"))
    maps_by_id = {str(item.get("id", "")): item for item in maps if isinstance(item, dict)}
    check.require(len(archetypes) == 18, f"expected 18 room archetypes, found {len(archetypes)}")
    check.require(len(maps_by_id) == 21, f"expected 21 physical placement maps, found {len(maps_by_id)}")
    check.require(len(maps_by_id) == len(maps), "placement map ids must be unique/non-empty")
    for archetype_id in archetypes:
        check.require(archetype_id in maps_by_id, f"archetype {archetype_id} has no placement map")
    expected_layers = {"small_underground_casino:club", "small_underground_casino:casino", "small_underground_casino:back_room"}
    check.require(expected_layers.issubset(maps_by_id), "Small Underground Casino layer maps are incomplete")
    for map_id, map_data in maps_by_id.items():
        archetype_id = str(map_data.get("archetype_id", map_id.split(":", 1)[0]))
        validate_map_v2(check, map_data, archetypes.get(archetype_id, {}), board)

    jazz = maps_by_id.get("jazz_club", {})
    jazz_fixed = {
        str(item.get("object_id", "")): item
        for item in values(jazz.get("fixed_objects"))
        if isinstance(item, dict)
    }
    required_jazz_slots = {
        "jazz_club:bartender": "fixed.staff_bartender",
        "jazz_club:musician_sax": "fixed.musician_sax",
        "jazz_club:musician_cello": "fixed.musician_cello",
        "jazz_club:musician_drummer": "fixed.musician_drummer",
        "jazz_club:band_tip_jar": "fixed.tip_jar_band",
        "jazz_club:band_stage": "fixed.band_stage",
    }
    for object_id, slot_id in required_jazz_slots.items():
        declaration = jazz_fixed.get(object_id, {})
        check.require(bool(declaration), f"jazz_club: missing required fixed declaration {object_id}")
        check.require(bool(declaration.get("required", False)), f"jazz_club: {object_id} must be required")
        check.require(str(declaration.get("exact_slot_id", "")) == slot_id, f"jazz_club: {object_id} must use {slot_id}")
    jazz_action_ids = {
        str(action_id)
        for declaration in jazz_fixed.values()
        for action_id in values(declaration.get("action_ids"))
    }
    for action_id in {
        "service:house_drink", "service:jazz_sax_round", "service:jazz_cello_round",
        "service:jazz_drummer_round", "service:jazz_band_tip_jar", "service:listen_to_jazz",
    }:
        check.require(action_id in jazz_action_ids, f"jazz_club: fixed hosts do not attach {action_id}")
    check.require(
        len(values(jazz.get("fixed_slots"))) == 9
        and len(values(jazz.get("event_slots"))) == 4
        and len(values(jazz.get("scenario_slots"))) == 12
        and len(values(jazz.get("exit_slots"))) == 1,
        "jazz_club: reviewed fixed/event/scenario/exit counts must be 9/4/12/1",
    )
    check.require(
        {
            str(slot.get("id", ""))
            for slot in values(jazz.get("exit_slots"))
            if isinstance(slot, dict)
        } == {"exit.door_right_upper"},
        "jazz_club: only the real right-upper travel exit may remain",
    )

    retired_pull_tabs_slots = {
        "bar": {"fixed.ticket_redeemer", "fixed.random_game_3"},
        "gas_station_casino": {
            "fixed.service_lottery_desk", "fixed.service_refreshment_shelf",
            "fixed.random_game_2", "fixed.event_control_rail",
        },
        "jazz_club": {
            "fixed.pulltab_game", "fixed.event_pull_tabs_sign",
            "fixed.random_game_1", "fixed.service_bar",
        },
        "grand_casino": {"fixed.ticket_redeemer", "fixed.game_machine_5"},
    }
    for map_id, retired_ids in retired_pull_tabs_slots.items():
        map_data = maps_by_id.get(map_id, {})
        fixed_ids = {
            str(slot.get("id", ""))
            for slot in values(map_data.get("fixed_slots"))
            if isinstance(slot, dict)
        }
        check.require(
            fixed_ids.isdisjoint(retired_ids),
            f"{map_id}: retained standalone Pull Tabs capacity {sorted(fixed_ids & retired_ids)}",
        )
        declarations = [
            declaration
            for declaration in values(map_data.get("fixed_objects"))
            if isinstance(declaration, dict)
        ]
        check.require(
            all(
                not set(str(value) for value in values(declaration.get("action_ids")))
                & PULL_TABS_HOST_ACTION_IDS
                for declaration in declarations
            ),
            f"{map_id}: Pull Tabs actions must be merged by runtime only",
        )
        for action_id in PULL_TABS_HOST_ACTION_IDS:
            check.require(
                map_data.get("object_family_ids", {}).get(action_id) == "fixed"
                and all(
                    action_id not in map_data.get(f"{family}_object_slot_ids", {})
                    for family in V2_FAMILIES
                ),
                f"{map_id}: {action_id} must be fixed-owned without standalone geometry",
            )

    required_host_slots = {
        "corner_store": {"corner_store:shopkeeper": "fixed.staff_shopkeeper"},
        "back_alley": {"back_alley:merchant": "fixed.staff_merchant"},
        "motel": {"motel:front_desk_clerk": "fixed.staff_front_desk"},
        "bar": {"bar:bartender": "fixed.staff_bartender"},
        "kitty_cat_lounge": {"kitty_cat_lounge:bar_host": "fixed.staff_bar"},
        "gas_station_casino": {"gas_station_casino:nell": "fixed.staff_nell"},
        "delta_queen": {
            "delta_queen:right_table_dealer": "fixed.staff_right_table",
            "delta_queen:deck_boss": "fixed.staff_floor",
        },
        "small_underground_casino:club": {"punchline:club_bouncer": "fixed.staff_floor_right"},
        "small_underground_casino:casino": {"punchline:casino_dealer": "fixed.staff_dealer"},
        "pawn_shop": {"pawn_shop:sal": "fixed.staff_pawn_counter"},
        "grand_casino": {"grand_casino:floor_host": "fixed.staff_host"},
        "grand_casino_cage": {"grand_casino_cage:linda": "fixed.staff_linda"},
    }
    for map_id, expectations in required_host_slots.items():
        declarations = {
            str(item.get("object_id", "")): item
            for item in values(maps_by_id.get(map_id, {}).get("fixed_objects"))
            if isinstance(item, dict)
        }
        for object_id, slot_id in expectations.items():
            declaration = declarations.get(object_id, {})
            check.require(bool(declaration), f"{map_id}: missing guaranteed host declaration {object_id}")
            check.require(str(declaration.get("exact_slot_id", "")) == slot_id, f"{map_id}: {object_id} must use {slot_id}")
            check.require(bool(declaration.get("required", False)), f"{map_id}: {object_id} must be required")

    grand = maps_by_id.get("grand_casino", {})
    check.require(
        grand.get("fixed_object_slot_ids", {}).get("casino_fixture:host_desk")
        == "fixed.fixture_host_desk",
        "grand_casino: runtime game actions must use the tangible host desk",
    )
    grand_categories = {
        str(key): str(value)
        for key, value in grand.get("fixed_category_slot_ids", {}).items()
        if str(key).startswith("game_spots:")
    }
    check.require(
        grand_categories == {
            "game_spots:0": "fixed.game_machine_1",
            "game_spots:1": "fixed.game_machine_2",
            "game_spots:2": "fixed.game_machine_3",
            "game_spots:3": "fixed.game_machine_4",
            "game_spots:4": "fixed.game_table_left",
            "game_spots:5": "fixed.game_table_right",
        },
        "grand_casino: six game categories must skip the retired Pull Tabs machine",
    )
    expected_game_categories = {
        "bar": {
            "game_spots:0": "fixed.random_game_1",
            "game_spots:1": "fixed.random_game_2",
        },
        "gas_station_casino": {
            "game_spots:0": "fixed.random_game_1",
            "game_spots:1": "fixed.game_scratch_tickets",
        },
    }
    for map_id, expected in expected_game_categories.items():
        actual = {
            str(key): str(value)
            for key, value in maps_by_id.get(map_id, {}).get(
                "fixed_category_slot_ids", {}
            ).items()
            if str(key).startswith("game_spots:")
        }
        check.require(
            actual == expected,
            f"{map_id}: physical game category bank drift; "
            f"expected={expected} actual={actual}",
        )
    for object_id in ("game:coin_pusher", "game:slot", "game:video_poker"):
        check.require(
            maps_by_id.get("gas_station_casino", {}).get(
                "fixed_object_slot_ids", {}
            ).get(object_id) == "fixed.random_game_1",
            f"gas_station_casino: {object_id} must share fixed.random_game_1",
        )
    expected_game_spots = {
        "bar": [[136, 202], [322, 202]],
        "gas_station_casino": [[482, 254], [578, 160]],
        "jazz_club": [],
    }
    for map_id, expected in expected_game_spots.items():
        check.require(
            values(archetypes.get(map_id, {}).get("layout", {}).get("game_spots"))
            == expected,
            f"{map_id}: layout game_spots must match its non-counter physical games",
        )
    check.require(
        values(archetypes.get("grand_casino", {}).get("layout", {}).get("game_spots"))
        == [[85, 150], [220, 150], [355, 150], [525, 150], [825, 150], [600, 260]],
        "grand_casino: layout must expose the six non-Pull-Tabs physical game positions",
    )
    descriptive_fixed_ids = {
        "back_alley": {"lender:street_lender": "fixed.lender_street_lender"},
        "pawn_shop": {"lender:sals_pawn_counter": "fixed.lender_sals_pawn_counter"},
        "beach": {"service:beach_sand_pile": "fixed.service_beach_sand_pile"},
        "kitty_cat_lounge": {"event:grand_casino_invite": "fixed.event_grand_casino_invite"},
        "delta_queen": {"event:grand_casino_invite": "fixed.event_grand_casino_invite"},
    }
    for map_id, object_targets in descriptive_fixed_ids.items():
        map_data = maps_by_id.get(map_id, {})
        fixed_ids = {
            str(slot.get("id", ""))
            for slot in values(map_data.get("fixed_slots"))
            if isinstance(slot, dict)
        }
        for object_id, slot_id in object_targets.items():
            check.require(
                map_data.get("fixed_object_slot_ids", {}).get(object_id) == slot_id
                and slot_id in fixed_ids,
                f"{map_id}: {object_id} must use descriptive fixed id {slot_id}",
            )

    silas_maps = (
        "motel", "bar", "small_underground_casino",
        "small_underground_casino:club",
        "small_underground_casino:casino",
        "small_underground_casino:back_room", "jazz_club",
        "kitty_cat_lounge",
    )
    for map_id in silas_maps:
        map_data = maps_by_id.get(map_id, {})
        slot_id = str(
            map_data.get("event_object_slot_ids", {}).get("numbers:silas", "")
        )
        event_slots = {
            str(slot.get("id", "")): slot
            for slot in values(map_data.get("event_slots"))
            if isinstance(slot, dict)
        }
        check.require(map_data.get("object_family_ids", {}).get("numbers:silas") == "event", f"{map_id}: Silas must be event-owned")
        check.require(
            slot_id.startswith("event.standing_person_")
            and event_slots.get(slot_id, {}).get("footprint_class") == "standing_person",
            f"{map_id}: Silas must use canonical event standing-person capacity",
        )

    gas = maps_by_id.get("gas_station_casino", {})
    gas_nell = next(
        (
            declaration
            for declaration in values(gas.get("fixed_objects"))
            if isinstance(declaration, dict) and declaration.get("object_id") == "gas_station_casino:nell"
        ),
        {},
    )
    check.require(
        "event:town_rumor_staff" in values(gas_nell.get("action_ids")),
        "gas_station_casino: Nell must host the town-rumor action",
    )
    check.require(
        gas.get("object_family_ids", {}).get("dialogue:scratch_ticket_scalper") == "event"
        and gas.get("event_object_slot_ids", {}).get("dialogue:scratch_ticket_scalper") == "event.standing_person_5",
        "gas_station_casino: scratch-ticket scalper must use optional event.standing_person_5",
    )
    for home_id in ("motel_room", "apartment", "house"):
        home = maps_by_id.get(home_id, {})
        check.require(
            home.get("fixed_object_slot_ids", {}).get("home_storage:place") == "fixed.home_storage"
            and home.get("fixed_category_slot_ids", {}).get("home_storage_spots:0") == "fixed.home_storage"
            and home.get("fixed_category_slot_ids", {}).get("home_container_spots:0") != "fixed.home_storage",
            f"{home_id}: home storage must not alias the first container",
        )
    grand = maps_by_id.get("grand_casino", {})
    check.require(
        grand.get("object_family_ids", {}).get("event:scenario_audit_roster") == "fixed"
        and grand.get("fixed_object_slot_ids", {}).get("event:scenario_audit_roster") == "fixed.event_audit_roster",
        "grand_casino: required audit roster must be fixed-owned",
    )
    for map_id, count in {"grand_casino": 7, "grand_casino_high_limit": 6, "grand_casino_back_room": 5}.items():
        event_slots = {
            str(slot.get("id", "")): slot
            for slot in values(maps_by_id.get(map_id, {}).get("event_slots"))
            if isinstance(slot, dict)
        }
        for ordinal in range(1, count + 1):
            slot_id = f"event.standing_person_{ordinal}"
            check.require(
                event_slots.get(slot_id, {}).get("footprint_class") == "standing_person"
                and event_slots.get(slot_id, {}).get("occupancy_required") is False,
                f"{map_id}: missing optional Grand living-floor capacity {slot_id}",
            )

    for map_id in HOUSE_DRINK_FIXED_MAPS:
        map_data = maps_by_id.get(map_id, {})
        fixed_slots = {
            str(slot.get("id", "")): slot
            for slot in values(map_data.get("fixed_slots"))
            if isinstance(slot, dict)
        }
        drink_slot = fixed_slots.get("fixed.service_house_drink", {})
        check.require(
            map_data.get("object_family_ids", {}).get("service:house_drink") == "fixed"
            and map_data.get("fixed_object_slot_ids", {}).get("service:house_drink") == "fixed.service_house_drink"
            and drink_slot.get("footprint_class") == "surface_item",
            f"{map_id}: house drink must retain fixed surface-item capacity",
        )
        check.require(
            map_data.get("class_overrides", {}).get("service:house_drink") == "surface_item",
            f"{map_id}: house drink must be classified as a surface_item",
        )

    corner_store = maps_by_id.get("corner_store", {})
    corner_event_slots = {
        str(slot.get("id", "")): slot
        for slot in values(corner_store.get("event_slots"))
        if isinstance(slot, dict)
    }
    late_shift_slot = corner_event_slots.get("event.behind_counter_person_1", {})
    town_rumor_slot = corner_event_slots.get("event.behind_counter_person_2", {})
    late_shift_rect = rect(late_shift_slot.get("hit_rect"))
    town_rumor_rect = rect(town_rumor_slot.get("hit_rect"))
    check.require(
        corner_store.get("object_family_ids", {}).get("event:late_shift_discount") == "event"
        and corner_store.get("object_family_ids", {}).get("event:town_rumor_staff") == "event"
        and corner_store.get("event_object_slot_ids", {}).get("event:late_shift_discount") == "event.behind_counter_person_1"
        and corner_store.get("event_object_slot_ids", {}).get("event:town_rumor_staff") == "event.behind_counter_person_2"
        and late_shift_slot.get("footprint_class") == "behind_counter_person"
        and town_rumor_slot.get("footprint_class") == "behind_counter_person"
        and late_shift_rect is not None
        and town_rumor_rect is not None
        and not intersects(late_shift_rect, town_rumor_rect),
        "corner_store: late-shift discount and town-rumor staff require distinct non-overlapping behind-counter event capacity",
    )

    back_room = maps_by_id.get("small_underground_casino:back_room", {})
    back_room_fixed_slots = {
        str(slot.get("id", "")): slot
        for slot in values(back_room.get("fixed_slots"))
        if isinstance(slot, dict)
    }
    for object_id, (slot_id, placement_class) in CREW_BACK_ROOM_FIXED_SLOTS.items():
        slot = back_room_fixed_slots.get(slot_id, {})
        check.require(
            back_room.get("object_family_ids", {}).get(object_id) == "fixed"
            and back_room.get("fixed_object_slot_ids", {}).get(object_id) == slot_id
            and slot.get("footprint_class") == placement_class,
            f"small_underground_casino:back_room: required fixture {object_id} must use {slot_id}",
        )

    casino = maps_by_id.get("small_underground_casino:casino", {})
    casino_event_slots = {
        str(slot.get("id", "")): slot
        for slot in values(casino.get("event_slots"))
        if isinstance(slot, dict)
    }
    rowdy_slot = casino_event_slots.get("event.seated_person_1", {})
    casino_seats = {
        str(seat.get("id", "")): point(seat.get("point"))
        for seat in values(casino.get("seats"))
        if isinstance(seat, dict)
    }
    check.require(
        casino.get("object_family_ids", {}).get("event:rowdy_regular") == "event"
        and casino.get("event_object_slot_ids", {}).get("event:rowdy_regular") == "event.seated_person_1"
        and rowdy_slot.get("footprint_class") == "seated_person"
        and rowdy_slot.get("support_id") == "left_card_seat"
        and point(rowdy_slot.get("pos")) == casino_seats.get("left_card_seat"),
        "small_underground_casino:casino: rowdy regular must have authored seated event capacity",
    )

    for map_id, map_data in maps_by_id.items():
        scenario_reserves = [
            slot
            for slot in values(map_data.get("scenario_slots"))
            if isinstance(slot, dict) and bool(slot.get("runtime_reserve"))
        ]
        roles = [str(slot.get("physical_role", "")) for slot in scenario_reserves]
        for required_role in (
            "Runtime contact reserve",
            "Delivery hold reserve",
            "Delivery package reserve",
        ):
            check.require(
                roles.count(required_role) == 1,
                f"{map_id}: must expose exactly one {required_role}",
            )
    for map_id, slot_id in (
        ("bar", "scenario.seated_person_2"),
        ("beach", "scenario.standing_person_5"),
    ):
        slot = next(
            (
                value
                for value in values(maps_by_id.get(map_id, {}).get("scenario_slots"))
                if isinstance(value, dict) and value.get("id") == slot_id
            ),
            {},
        )
        check.require(
            slot.get("physical_role") == "Recruitment contact reserve"
            and slot.get("runtime_reserve") is True,
            f"{map_id}: {slot_id} must retain recruitment reserve metadata",
        )
    for map_id in (
        "grand_casino", "grand_casino_high_limit",
        "grand_casino_back_room", "grand_casino_cage",
    ):
        crew_reserves = [
            slot
            for slot in values(maps_by_id.get(map_id, {}).get("scenario_slots"))
            if isinstance(slot, dict)
            and slot.get("physical_role") == "Crew live-table reserve"
            and slot.get("footprint_class") == "floor_fixture"
            and slot.get("runtime_reserve") is True
        ]
        check.require(
            len(crew_reserves) == 1,
            f"{map_id}: must expose one Crew live-table floor reserve",
        )

    source_add_claimants = _v2_validate_source_add_claimants(
        check, scenario_catalog, maps_by_id
    )

    active_snapshots = SlotAuthoring.collect_active_phase_snapshots(root)
    complete_snapshots = SlotAuthoring.collect_active_phase_snapshots(root, include_aftermath=True)
    active_rows = _v2_snapshot_rows(check, maps_by_id, active_snapshots)
    complete_rows = _v2_snapshot_rows(check, maps_by_id, complete_snapshots)
    active_summaries = summarize_scenarios(active_rows)
    complete_summaries = summarize_scenarios(complete_rows)
    check.require(len(active_summaries) == 55, f"active scenario inventory must cover 55 map/scenario pairs, found {len(active_summaries)}")
    check.require(len(complete_summaries) == 55, f"complete scenario inventory must cover 55 map/scenario pairs, found {len(complete_summaries)}")

    exact_seed_manifest = json.loads((root / "tools/fixtures/rw06_1_environment_exact_seed_manifest.json").read_text(encoding="utf-8"))
    historical_seeds = values(exact_seed_manifest.get("expectations"))
    legal_combinations = values(exact_seed_manifest.get("legal_room_combinations"))
    scenario_count = sum(len(values(room_scenarios)) for room_scenarios in scenario_catalog.values())
    fixed_slot_count = sum(len(values(map_data.get("fixed_slots"))) for map_data in maps_by_id.values())
    active_bindings = sum(int(row["binding_count"]) for row in active_rows)
    complete_bindings = sum(int(row["binding_count"]) for row in complete_rows)
    active_overflow = sum(int(row["overflow_count"]) for row in active_rows)
    complete_overflow = sum(int(row["overflow_count"]) for row in complete_rows)
    active_conflicts = sum(int(row["conflict_count"]) for row in active_rows)
    complete_conflicts = sum(int(row["conflict_count"]) for row in complete_rows)
    active_nonphysical = sum(int(row["action_list_count"]) for row in active_rows)
    active_physical_room = sum(int(row["physical_room_count"]) for row in active_rows)
    authored_actions = sum(int(row["authored_action_count"]) for row in complete_rows)
    active_reservations = sum(int(row["reservation_count"]) for row in active_rows)
    fixed_scenario_observations = sum(
        len(values(maps_by_id.get(str(row["map_id"]), {}).get("fixed_slots")))
        for row in active_rows
    )
    fixed_scenario_pair_tests = sum(
        len(values(maps_by_id.get(str(row["map_id"]), {}).get("fixed_slots")))
        * int(row["physical_room_count"])
        for row in active_rows
    )
    fixed_declaration_conflicts = 0
    fixed_pair_tests = 0
    for map_data in maps_by_id.values():
        fixed_slots = values(map_data.get("fixed_slots"))
        fixed_pair_tests += len(fixed_slots) * max(0, len(fixed_slots) - 1) // 2
        declaration_counts: dict[str, int] = {}
        for declaration in values(map_data.get("fixed_objects")):
            if not isinstance(declaration, dict):
                continue
            slot_id = str(declaration.get("exact_slot_id", declaration.get("slot_id", ""))).strip()
            if slot_id:
                declaration_counts[slot_id] = declaration_counts.get(slot_id, 0) + 1
        fixed_declaration_conflicts += sum(
            count * (count - 1) // 2
            for count in declaration_counts.values()
            if count > 1
        )
    check.require(active_overflow == 0, f"active v2 scenario replay found {active_overflow} missing physical slot binding(s)")
    check.require(complete_overflow == 0, f"complete v2 scenario replay found {complete_overflow} missing physical slot binding(s)")
    check.require(active_conflicts == 0, f"active v2 scenario replay found {active_conflicts} conflicting slot reservation(s)")
    check.require(complete_conflicts == 0, f"complete v2 scenario replay found {complete_conflicts} conflicting slot reservation(s)")
    check.require(fixed_declaration_conflicts == 0, f"fixed declarations contain {fixed_declaration_conflicts} duplicate exact-slot claim(s)")
    counts = {
        "maps": len(maps_by_id),
        "archetypes": len(archetypes),
        "scenarios": scenario_count,
        "legal_hosts": len(active_summaries),
        "authored_visuals": active_bindings,
        "active_snapshots": len(active_rows),
        "active_bindings": active_bindings,
        "active_overflow": active_overflow,
        "active_overflow_rate": active_overflow / max(1, active_bindings),
        "active_nonphysical": active_nonphysical,
        "active_nonphysical_room": 0,
        "active_physical_room": active_physical_room,
        "complete_snapshots": len(complete_rows),
        "complete_bindings": complete_bindings,
        "complete_overflow": complete_overflow,
        "authored_actions": authored_actions,
        "historical_exact_seeds": len(historical_seeds),
        "historical_legal_room_combinations": len(legal_combinations),
        "fixed_scenario_snapshots": len(active_rows),
        "fixed_scenario_legal_scenarios": len(active_summaries),
        "fixed_scenario_fixed_slot_observations": fixed_scenario_observations,
        "fixed_scenario_authorities": active_reservations,
        "fixed_scenario_pair_tests": fixed_scenario_pair_tests,
        "fixed_scenario_conflicts": active_conflicts,
        "fixed_label_slots": fixed_slot_count,
        "fixed_fixed_pair_tests": fixed_pair_tests,
        "fixed_fixed_conflicts": fixed_declaration_conflicts,
        "mandatory_lane_obstacle_checks": len(active_rows),
        "mandatory_lane_obstacle_states": len(active_rows),
        "mandatory_lane_overflow_states": 0,
        "scenario_source_add_claimants": source_add_claimants,
        "event_slot_count": sum(
            len(values(map_data.get("event_slots")))
            for map_data in maps_by_id.values()
        ),
        "scenario_slot_count": sum(
            len(values(map_data.get("scenario_slots")))
            for map_data in maps_by_id.values()
        ),
    }
    report = {
        "tool": "environment_fixed_slot_static_check",
        "passed": not check.errors,
        "error_count": len(check.errors),
        "counts": counts,
        "day2_samples": day2_sample_report(active_summaries),
        "contact_sheet": contact_sheet_report(active_summaries, archetypes),
        "active_scenarios": active_summaries,
        "complete_scenarios": complete_summaries,
        "errors": check.errors,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if check.errors:
        print("ENVIRONMENT_FIXED_SLOT_STATIC_CHECK FAIL", file=sys.stderr)
        for error in check.errors:
            print(f" - {error}", file=sys.stderr)
        return 1
    print(
        "ENVIRONMENT_FIXED_SLOT_STATIC_CHECK PASS "
        f"schema=v2 maps={len(maps_by_id)} archetypes={len(archetypes)} "
        f"scenarios={scenario_count} families={len(V2_FAMILIES)} "
        f"active_snapshots={len(active_rows)} report={report_path}"
    )
    return 0


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    report_path = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else root / ".tmp/rw06_1/static/slot_report.json"
    check = Check()
    placement_path = root / "data/environments/placement_surfaces.json"
    archetype_path = root / "data/environments/archetypes.json"
    scenario_catalog_path = root / "data/environments/scenarios.json"
    placement = json.loads(placement_path.read_text(encoding="utf-8"))
    archetypes_list = json.loads(archetype_path.read_text(encoding="utf-8"))
    scenario_catalog = json.loads(scenario_catalog_path.read_text(encoding="utf-8"))
    if int(placement.get("slot_schema_version", 0)) == 2:
        return main_v2(root, report_path, placement, archetypes_list, scenario_catalog)
    exact_seed_manifest = json.loads((root / "tools/fixtures/rw06_1_environment_exact_seed_manifest.json").read_text(encoding="utf-8"))
    event_catalog = json.loads((root / "data/events/events.json").read_text(encoding="utf-8"))
    scenario_resolver_source = (root / "scripts/core/scenario_layout_resolver.gd").read_text(encoding="utf-8")
    walk_lane_match = re.search(
        r"(?m)^const\s+WALK_LANE\s*:=\s*Rect2\(\s*"
        r"([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*,\s*"
        r"([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*\)\s*$",
        scenario_resolver_source,
    )
    production_walk_lane = tuple(float(item) for item in walk_lane_match.groups()) if walk_lane_match else None
    board_raw = point(placement.get("board_size"))
    check.require(placement.get("schema_version") == 2, "placement_surfaces.json schema_version must be 2")
    check.require(placement.get("slot_schema_version") == 1, "placement_surfaces.json slot_schema_version must be 1")
    check.require(
        production_walk_lane == MANDATORY_PLAYER_ACCESS_LANE,
        "static mandatory-player-lane authority diverges from ScenarioLayoutResolver.WALK_LANE",
    )
    check.require(board_raw is not None and board_raw[0] > 0 and board_raw[1] > 0, "invalid placement board_size")
    board = board_raw or (900.0, 430.0)
    archetypes = {str(item.get("id", "")): item for item in archetypes_list if isinstance(item, dict)}
    maps = values(placement.get("maps"))
    maps_by_id = {str(item.get("id", "")): item for item in maps if isinstance(item, dict)}
    check.require(len(archetypes) == 18, f"expected 18 room archetypes, found {len(archetypes)}")
    check.require(len(maps_by_id) == 21, f"expected 21 physical placement maps, found {len(maps_by_id)}")
    check.require(len(maps_by_id) == len(maps), "placement map ids must be unique/non-empty")
    for archetype_id in archetypes:
        check.require(archetype_id in maps_by_id, f"archetype {archetype_id} has no placement map")
    expected_layers = {"small_underground_casino:club", "small_underground_casino:casino", "small_underground_casino:back_room"}
    check.require(expected_layers.issubset(maps_by_id), "Small Underground Casino layer maps are incomplete")
    for map_id, map_data in maps_by_id.items():
        archetype_id = str(map_data.get("archetype_id", map_id.split(":", 1)[0]))
        check.require(archetype_id in archetypes, f"{map_id}: unknown archetype {archetype_id}")
        validate_map(check, map_data, archetypes.get(archetype_id, {}), board)

    # Q-007 fixes the authored fixture groups while leaving the concrete game,
    # item, and event instances free to vary by seed.  These two day-2 rooms are
    # serialized from literal art-reviewed coordinates, never from the retired
    # packing/search authorer.
    for map_id in sorted(HandAuthoredSlots.HAND_SLOTS):
        replayed = copy.deepcopy(maps_by_id.get(map_id, {}))
        check.require(bool(replayed), f"hand-authored serializer references missing map {map_id}")
        if replayed:
            HandAuthoredSlots.apply_layout(replayed)
            check.require(
                replayed == maps_by_id.get(map_id, {}),
                f"{map_id}: placement_surfaces.json is stale against its literal hand-authored slot table",
            )
    hand_author_source = (root / "tools/rw06_1_apply_hand_authored_slots.py").read_text(encoding="utf-8")
    check.require("HAND_SLOTS" in hand_author_source, "hand-authored slot serializer has no literal coordinate table")
    for forbidden in ("import rw06_1_author_fixed_slots", "supported_rect_candidates(", "candidate_rects(", "itertools.product("):
        check.require(forbidden not in hand_author_source, f"hand-authored slot serializer contains forbidden search dependency {forbidden}")

    bar_map = maps_by_id.get("bar", {})
    bar_base_slots = {
        str(slot.get("id", "")): slot
        for slot in values(bar_map.get("base_slots"))
        if isinstance(slot, dict)
    }
    bar_categories = bar_map.get("category_slot_ids", {}) if isinstance(bar_map.get("category_slot_ids"), dict) else {}
    bar_game_slot_ids = [str(bar_categories.get(f"game_spots:{index}", "")) for index in range(3)]
    check.require(
        len(set(bar_game_slot_ids)) == 3
        and all(
            slot_id.startswith("base.game_")
            and bar_base_slots.get(slot_id, {}).get("footprint_class") == "surface_item"
            and bar_base_slots.get(slot_id, {}).get("support_id") == "bar_counter"
            for slot_id in bar_game_slot_ids
        ),
        "bar: three game categories must use three distinct named counter slots",
    )
    bar_object_preferences = bar_map.get("object_slot_ids", {}) if isinstance(bar_map.get("object_slot_ids"), dict) else {}
    check.require(
        not any(str(identity).startswith("game:") for identity in bar_object_preferences),
        "bar: concrete game identities must remain seed-random rather than pinned to slots",
    )
    bar_overrides = bar_map.get("class_overrides", {}) if isinstance(bar_map.get("class_overrides"), dict) else {}
    check.require(
        all(str(bar_overrides.get(f"game:{game_id}", "")) == "surface_item" for game_id in values(archetypes.get("bar", {}).get("game_pool"))),
        "bar: every random game-pool member must classify as a counter-supported surface item",
    )

    store_map = maps_by_id.get("corner_store", {})
    store_base_slots = {
        str(slot.get("id", "")): slot
        for slot in values(store_map.get("base_slots"))
        if isinstance(slot, dict)
    }
    store_categories = store_map.get("category_slot_ids", {}) if isinstance(store_map.get("category_slot_ids"), dict) else {}
    store_item_slot_ids = [str(store_categories.get(f"item_spots:{index}", "")) for index in range(5)]
    store_preferences = store_map.get("object_slot_ids", {}) if isinstance(store_map.get("object_slot_ids"), dict) else {}
    check.require(
        len(set(store_item_slot_ids)) == 5
        and all(slot_id.startswith("base.shop_item_") for slot_id in store_item_slot_ids)
        and all(store_base_slots.get(slot_id, {}).get("footprint_class") == "shop_item" for slot_id in store_item_slot_ids),
        "corner_store: five item categories must use five distinct named shop-item slots",
    )
    check.require(
        all(str(store_base_slots.get(slot_id, {}).get("support_id", "")).startswith("shop_display_") for slot_id in store_item_slot_ids),
        "corner_store: visible offers must stay aligned to the dedicated shop display rows",
    )
    check.require(
        store_preferences.get("shopkeeper:merchant") == "base.staff_shopkeeper"
        and store_base_slots.get("base.staff_shopkeeper", {}).get("footprint_class") == "behind_counter_person"
        and store_preferences.get("event:call_brother_in_law") == "base.fixed_phone"
        and store_base_slots.get("base.fixed_phone", {}).get("support_id") == "left_checkout_counter"
        and store_preferences.get("service:house_drink") == "base.fixed_drink"
        and str(store_base_slots.get("base.fixed_drink", {}).get("support_id", "")).startswith("cooler_"),
        "corner_store: shopkeeper, fixed phone, and drink must remain on their named art fixtures",
    )
    store_staff_bindings = {
        "shopkeeper:merchant": ("base.staff_shopkeeper", "Shopkeeper"),
        "event:late_shift_discount": ("base.staff_dialogue", "Late Shift Discount"),
        "event:scenario_delivery_day_stock": ("base.staff_dialogue_2", "Fresh Off the Truck"),
    }
    store_staff_authority: list[tuple[str, tuple[float, float, float, float], tuple[float, float, float, float], tuple[float, float, float, float]]] = []
    for identity, (expected_slot_id, label) in store_staff_bindings.items():
        staff_slot = store_base_slots.get(expected_slot_id, {})
        staff_hit = rect(staff_slot.get("hit_rect"))
        check.require(
            store_preferences.get(identity) == expected_slot_id
            and staff_slot.get("footprint_class") == "behind_counter_person"
            and staff_slot.get("support_id") == "register"
            and staff_hit is not None,
            f"corner_store: {identity} must retain its distinct named behind-register slot",
        )
        if staff_hit is not None:
            store_staff_authority.append((identity, staff_hit, expanded(staff_hit, board), label_rect(staff_slot, label, board)))
    check.require(
        len({slot_id for slot_id, _label in store_staff_bindings.values()}) == 3,
        "corner_store: shopkeeper and both simultaneous dialogue events must use three distinct slots",
    )
    for index, (identity, hit, small_hit, label_bounds) in enumerate(store_staff_authority):
        for other_identity, other_hit, other_small_hit, other_label in store_staff_authority[index + 1:]:
            check.require(not intersects(hit, other_hit), f"corner_store: {identity}/{other_identity} normal staff targets overlap")
            check.require(not intersects(small_hit, other_small_hit), f"corner_store: {identity}/{other_identity} 104x76 staff targets overlap")
            check.require(not intersects(label_bounds, other_label), f"corner_store: {identity}/{other_identity} staff labels overlap")
            check.require(not intersects(label_bounds, other_hit) and not intersects(label_bounds, other_small_hit), f"corner_store: {identity} label overlaps {other_identity} target")
            check.require(not intersects(other_label, hit) and not intersects(other_label, small_hit), f"corner_store: {other_identity} label overlaps {identity} target")

    # Every Delivery Day phase uses the same authored safe-exit family. Keep the
    # persistent left-travel label clear of every mapped delivery exit target,
    # and keep every delivery-exit label clear of the persistent travel target.
    store_all_slots = {
        str(slot.get("id", "")): slot
        for slot in all_slots(store_map)
        if isinstance(slot, dict)
    }
    store_scenario_preferences = store_map.get("scenario_slot_ids", {}) if isinstance(store_map.get("scenario_slot_ids"), dict) else {}
    delivery_exit_slot_ids = sorted({
        str(slot_id)
        for identity, slot_id in store_scenario_preferences.items()
        if str(identity).split("|", 1)[0] == "delivery_exit"
        and store_all_slots.get(str(slot_id), {}).get("footprint_class") == "doorway"
    })
    travel_left = store_base_slots.get("base.travel_left", {})
    travel_hit = rect(travel_left.get("hit_rect"))
    check.require(bool(delivery_exit_slot_ids), "corner_store: Delivery Day has no fixed doorway state")
    check.require(travel_hit is not None, "corner_store: persistent left travel target is missing")
    if travel_hit is not None:
        travel_small = expanded(travel_hit, board)
        travel_label = label_rect(travel_left, "Leave", board)
        for exit_slot_id in delivery_exit_slot_ids:
            exit_slot = store_all_slots.get(exit_slot_id, {})
            exit_hit = rect(exit_slot.get("hit_rect"))
            if exit_hit is None:
                continue
            exit_small = expanded(exit_hit, board)
            exit_label = label_rect(exit_slot, "Delivery Exit", board)
            check.require(not intersects(travel_label, exit_hit) and not intersects(travel_label, exit_small), f"corner_store: left-travel label overlaps Delivery exit state {exit_slot_id}")
            check.require(not intersects(exit_label, travel_hit) and not intersects(exit_label, travel_small), f"corner_store: Delivery exit state {exit_slot_id} label overlaps left-travel target")

    # Delivery Day's catalog event is presented by a clerk behind the Corner
    # Store counter. Production sees the catalog placement hint, while the
    # sealed semantic replay intentionally retains only its stable event id.
    # The independently authored room override must make both paths agree.
    events_by_id = {
        str(item.get("id", "")): item
        for item in values(event_catalog)
        if isinstance(item, dict)
    }
    delivery_event_id = "scenario_delivery_day_stock"
    delivery_object_id = f"event:{delivery_event_id}"
    delivery_event = events_by_id.get(delivery_event_id, {})
    delivery_map = maps_by_id.get("corner_store", {})
    delivery_speaker = delivery_event.get("speaker", {}) if isinstance(delivery_event.get("speaker"), dict) else {}
    delivery_hint = {
        "visual_prop": str(delivery_event.get("environment_prop", "")),
        "icon_key": str(delivery_event.get("icon_key", "")),
        "role": str(delivery_speaker.get("role", "")),
    }
    hinted_delivery_class = SlotAuthoring.classify(
        delivery_hint,
        "event",
        delivery_object_id,
        str(delivery_hint.get("visual_prop", "")),
    )
    delivery_overrides = delivery_map.get("class_overrides", {}) if isinstance(delivery_map.get("class_overrides"), dict) else {}
    replayed_delivery_class = SlotAuthoring.classify_with_override(
        {},
        "event",
        delivery_object_id,
        str(delivery_overrides.get(delivery_object_id, "")),
    )
    delivery_base_slots = {
        str(slot.get("id", "")): slot
        for slot in values(delivery_map.get("base_slots"))
        if isinstance(slot, dict)
    }
    check.require(
        hinted_delivery_class == "behind_counter_person",
        "corner_store: Delivery Day catalog hint must classify its event as behind_counter_person",
    )
    check.require(
        replayed_delivery_class == hinted_delivery_class,
        "corner_store: compact Delivery Day event replay diverges from its catalog-hinted production class",
    )
    delivery_preferred_slot = str(delivery_map.get("object_slot_ids", {}).get(delivery_object_id, "")) if isinstance(delivery_map.get("object_slot_ids"), dict) else ""
    check.require(
        delivery_preferred_slot == "base.staff_dialogue_2"
        and delivery_base_slots.get(delivery_preferred_slot, {}).get("footprint_class") == replayed_delivery_class,
        "corner_store: Delivery Day event replay has no distinct compatible fixed base slot",
    )

    grand_map = maps_by_id.get("grand_casino", {})
    grand_base_slots = {
        str(slot.get("id", "")): slot
        for slot in values(grand_map.get("base_slots"))
        if isinstance(slot, dict)
    }
    grand_categories = grand_map.get("category_slot_ids", {}) if isinstance(grand_map.get("category_slot_ids"), dict) else {}
    grand_machine_ids = [str(grand_categories.get(f"game_spots:{index}", "")) for index in range(5)]
    grand_machine_slots = [grand_base_slots.get(slot_id, {}) for slot_id in grand_machine_ids]
    grand_machine_positions = [point(slot.get("pos")) for slot in grand_machine_slots]
    grand_machine_hits = [rect(slot.get("hit_rect")) for slot in grand_machine_slots]
    check.require(
        grand_machine_ids == [f"base.game_machine_{index}" for index in range(1, 6)]
        and len(set(grand_machine_ids)) == 5
        and all(slot.get("footprint_class") == "wall_mounted" and slot.get("support_id") == "wall" for slot in grand_machine_slots)
        and all(position is not None for position in grand_machine_positions)
        and len({position[1] for position in grand_machine_positions if position is not None}) == 1
        and all(hit is not None for hit in grand_machine_hits)
        and all(
            grand_machine_positions[index] is not None
            and grand_machine_positions[index + 1] is not None
            and grand_machine_positions[index + 1][0] > grand_machine_positions[index][0]
            and grand_machine_hits[index] is not None
            and grand_machine_hits[index + 1] is not None
            and not intersects(
                expanded(grand_machine_hits[index], board),
                expanded(grand_machine_hits[index + 1], board),
            )
            for index in range(4)
        ),
        "grand_casino: five generated machine positions must remain an aligned, expanded-target-safe named row",
    )
    grand_table_ids = [str(grand_categories.get(f"game_spots:{index}", "")) for index in range(5, 7)]
    check.require(
        grand_table_ids == ["base.game_table_left", "base.game_table_right"]
        and grand_base_slots.get(grand_table_ids[0], {}).get("footprint_class") == "surface_item"
        and grand_base_slots.get(grand_table_ids[0], {}).get("support_id") == "left_table_felt"
        and grand_base_slots.get(grand_table_ids[1], {}).get("footprint_class") == "surface_item"
        and grand_base_slots.get(grand_table_ids[1], {}).get("support_id") == "right_table_felt",
        "grand_casino: both generated card-table positions must remain tied to the visible left/right table art",
    )
    grand_preferences = grand_map.get("object_slot_ids", {}) if isinstance(grand_map.get("object_slot_ids"), dict) else {}
    check.require(
        not any(str(identity).startswith("game:") for identity in grand_preferences),
        "grand_casino: concrete game identities must remain seed-random rather than pinned to machine/table slots",
    )
    grand_overrides = grand_map.get("class_overrides", {}) if isinstance(grand_map.get("class_overrides"), dict) else {}
    check.require(
        all(str(grand_overrides.get(identity, "")) == "wall_mounted" for identity in (
            "game:slot", "game:slot:2", "game:slot:3", "game:video_poker", "game:pull_tabs"
        ))
        and all(str(grand_overrides.get(identity, "")) == "surface_item" for identity in ("game:blackjack", "game:craps")),
        "grand_casino: random machine/table identities must retain their art-compatible placement classes",
    )

    for auxiliary_id, expected_game_ids in {
        "grand_casino_high_limit": [f"base.game_table_{index}" for index in range(1, 5)],
        "grand_casino_back_room": ["base.game_table_left", "base.game_table_right"],
    }.items():
        auxiliary = maps_by_id.get(auxiliary_id, {})
        auxiliary_slots = {
            str(slot.get("id", "")): slot
            for slot in values(auxiliary.get("base_slots"))
            if isinstance(slot, dict)
        }
        auxiliary_categories = auxiliary.get("category_slot_ids", {}) if isinstance(auxiliary.get("category_slot_ids"), dict) else {}
        actual_game_ids = [str(auxiliary_categories.get(f"game_spots:{index}", "")) for index in range(len(expected_game_ids))]
        check.require(
            actual_game_ids == expected_game_ids
            and len(set(actual_game_ids)) == len(actual_game_ids)
            and all(
                auxiliary_slots.get(slot_id, {}).get("footprint_class") == "surface_item"
                and str(auxiliary_slots.get(slot_id, {}).get("support_id", "")).endswith("table")
                for slot_id in actual_game_ids
            ),
            f"{auxiliary_id}: generated games must retain distinct named art-backed table slots",
        )
    cage_map = maps_by_id.get("grand_casino_cage", {})
    cage_slots = {
        str(slot.get("id", "")): slot
        for slot in values(cage_map.get("base_slots"))
        if isinstance(slot, dict)
    }
    cage_categories = cage_map.get("category_slot_ids", {}) if isinstance(cage_map.get("category_slot_ids"), dict) else {}
    cage_item_ids = [str(cage_categories.get(f"item_spots:{index}", "")) for index in range(4)]
    check.require(
        cage_item_ids == [f"base.shop_item_{index}" for index in range(1, 5)]
        and len(set(cage_item_ids)) == 4
        and all(cage_slots.get(slot_id, {}).get("footprint_class") == "shop_item" for slot_id in cage_item_ids),
        "grand_casino_cage: four generated item positions must retain distinct named case/counter slots",
    )

    pawn_map = maps_by_id.get("pawn_shop", {})
    pawn_slots = {
        str(slot.get("id", "")): slot
        for slot in values(pawn_map.get("base_slots"))
        if isinstance(slot, dict)
    }
    pawn_preferences = pawn_map.get("object_slot_ids", {}) if isinstance(pawn_map.get("object_slot_ids"), dict) else {}
    shelf_slot_ids = [str(pawn_preferences.get(f"item:sal_shelf_{index}", "")) for index in range(6)]
    check.require(
        len(set(shelf_slot_ids)) == 6
        and all(pawn_slots.get(slot_id, {}).get("footprint_class") == "shop_item" for slot_id in shelf_slot_ids),
        "pawn_shop: Sal's six generated shelf offers must prefer six distinct fixed shop-item slots",
    )
    merchant_slot_id = str(pawn_preferences.get("shopkeeper:merchant", ""))
    counter_slot_id = str(pawn_preferences.get("meta_pawn_counter:sell", ""))
    check.require(
        bool(merchant_slot_id)
        and bool(counter_slot_id)
        and merchant_slot_id != counter_slot_id
        and pawn_slots.get(merchant_slot_id, {}).get("footprint_class") == "behind_counter_person"
        and pawn_slots.get(counter_slot_id, {}).get("footprint_class") == "behind_counter_person",
        "pawn_shop: generated Sal and the sell counter must prefer distinct fixed behind-counter slots",
    )

    # Round 3 reuses the highway-sill authority for the second concrete doorway.
    # The graveyard door and ordinary side door can therefore coexist while
    # abstract travel verbs continue to share the retained left-door route.
    gas_map = maps_by_id.get("gas_station_casino", {})
    gas_base_slots = {
        str(slot.get("id", "")): slot
        for slot in values(gas_map.get("base_slots"))
        if isinstance(slot, dict)
    }
    gas_stage_slots = {
        str(slot.get("id", "")): slot
        for slot in values(gas_map.get("stage_slots"))
        if isinstance(slot, dict)
    }
    gas_exit_slots = {
        str(slot.get("id", "")): slot
        for slot in values(gas_map.get("exit_slots"))
        if isinstance(slot, dict)
    }
    gas_preferences = gas_map.get("object_slot_ids", {}) if isinstance(gas_map.get("object_slot_ids"), dict) else {}
    gas_categories = gas_map.get("category_slot_ids", {}) if isinstance(gas_map.get("category_slot_ids"), dict) else {}
    gas_scenario_preferences = gas_map.get("scenario_slot_ids", {}) if isinstance(gas_map.get("scenario_slot_ids"), dict) else {}
    gas_travel_occupants = {
        "travel:back_alley",
        "travel:corner_store",
        "travel:delta_queen",
        "travel:grand_casino",
        "travel:kitty_cat_lounge",
        "travel:leave",
    }
    gas_travel_indexes = {f"travel_spots:{index}" for index in range(7)}
    check.require(
        "base.door_right_middle" not in gas_base_slots
        and gas_base_slots.get("base.door_left_middle", {}).get("footprint_class") == "doorway"
        and gas_base_slots.get("base.service_highway_sill", {}).get("footprint_class") == "doorway"
        and not any(str(slot_id) == "base.door_right_middle" for slot_id in gas_preferences.values())
        and not any(str(slot_id) == "base.door_right_middle" for slot_id in gas_categories.values()),
        "gas_station_casino: Round 3 sill doorway and retained left doorway must remain distinct",
    )
    check.require(
        str(gas_preferences.get("event:scenario_graveyard_maintenance", "")) == "base.service_highway_sill"
        and str(gas_preferences.get("event:side_door", "")) == "base.door_left_middle"
        and all(str(gas_preferences.get(identity, "")) == "base.door_left_middle" for identity in gas_travel_occupants)
        and all(str(gas_categories.get(key, "")) == "base.door_left_middle" for key in gas_travel_indexes),
        "gas_station_casino: physical doors must be distinct while abstract travel retains its shared route",
    )
    check.require(
        gas_stage_slots.get("stage.event_right_door", {}).get("footprint_class") == "doorway"
        and set(gas_exit_slots) == {"exit.left_upper", "exit.right_lower"},
        "gas_station_casino: scenario right-door and both independent safe-exit authorities must survive the base simplification",
    )
    restroom_queue_preference = "gas_station_tour_bus_stop_restroom_queue||right|"
    restroom_queue_slot_id = str(gas_scenario_preferences.get(restroom_queue_preference, ""))
    restroom_queue_hit = rect(gas_stage_slots.get(restroom_queue_slot_id, {}).get("hit_rect"))
    check.require(
        restroom_queue_slot_id == "stage.event_foreground_marker"
        and restroom_queue_hit is not None
        and not intersects(restroom_queue_hit, MANDATORY_PLAYER_ACCESS_LANE)
        and not intersects(expanded(restroom_queue_hit, board), MANDATORY_PLAYER_ACCESS_LANE),
        "seed 063 regression: apartment-to-Gas tour-bus restroom queue must clear the mandatory lane in normal and expanded layouts",
    )

    # Round 3 reuses the former floor-staff authority as the second physical
    # wall target. The calendar gets that dedicated mount; mutually exclusive
    # scenario notices retain wall_1 and the captain's card stays on its table.
    delta_map = maps_by_id.get("delta_queen", {})
    delta_base_slots = {
        str(slot.get("id", "")): slot
        for slot in values(delta_map.get("base_slots"))
        if isinstance(slot, dict)
    }
    delta_exit_slots = {
        str(slot.get("id", "")): slot
        for slot in values(delta_map.get("exit_slots"))
        if isinstance(slot, dict)
    }
    delta_preferences = delta_map.get("object_slot_ids", {}) if isinstance(delta_map.get("object_slot_ids"), dict) else {}
    delta_categories = delta_map.get("category_slot_ids", {}) if isinstance(delta_map.get("category_slot_ids"), dict) else {}
    delta_wall_occupants = {
        "event:grand_casino_invite",
        "event:scenario_engine_trouble_repairs",
        "event:scenario_whale_aboard_vouch",
    }
    check.require(
        "base.event_wall_2" not in delta_base_slots
        and delta_base_slots.get("base.event_wall_1", {}).get("footprint_class") == "wall_mounted"
        and delta_base_slots.get("base.staff_floor", {}).get("footprint_class") == "wall_mounted"
        and delta_base_slots.get("base.event_table_1", {}).get("footprint_class") == "surface_item"
        and not any(str(slot_id) == "base.event_wall_2" for slot_id in delta_preferences.values())
        and not any(str(slot_id) == "base.event_wall_2" for slot_id in delta_categories.values()),
        "delta_queen: Round 3 second wall target must reuse the collision-proven staff-floor authority",
    )
    check.require(
        all(str(delta_preferences.get(identity, "")) == "base.event_wall_1" for identity in delta_wall_occupants)
        and str(delta_preferences.get("item:payment_calendar", "")) == "base.staff_floor"
        and str(delta_preferences.get("event:scenario_captains_invitational_card", "")) == "base.event_table_1"
        and str(delta_categories.get("item_spots:2", "")) == "base.event_table_1",
        "delta_queen: physical calendar, scenario notices, and captain-card routes must remain exact",
    )
    check.require(
        set(delta_exit_slots) == {"exit.left_lower", "exit.right_upper"},
        "delta_queen: both independent safe exits must survive the wall-capacity simplification",
    )

    # Jazz keeps its guaranteed counter staff and one authored travel doorway.
    # Every generated travel index shares that doorway; abstract actions attach
    # to the visible host instead of occupying a second presentation plane.
    jazz_map = maps_by_id.get("jazz_club", {})
    jazz_base_slots = {
        str(slot.get("id", "")): slot
        for slot in values(jazz_map.get("base_slots"))
        if isinstance(slot, dict)
    }
    jazz_exit_slots = {
        str(slot.get("id", "")): slot
        for slot in values(jazz_map.get("exit_slots"))
        if isinstance(slot, dict)
    }
    jazz_preferences = jazz_map.get("object_slot_ids", {}) if isinstance(jazz_map.get("object_slot_ids"), dict) else {}
    jazz_categories = jazz_map.get("category_slot_ids", {}) if isinstance(jazz_map.get("category_slot_ids"), dict) else {}
    jazz_travel_indexes = {f"travel_spots:{index}" for index in range(5)}
    check.require(
        "base.door_right_middle" not in jazz_base_slots
        and len(jazz_base_slots) >= 9
        and jazz_base_slots.get("base.door_right_upper", {}).get("footprint_class") == "doorway"
        and jazz_base_slots.get("base.staff_bar", {}).get("footprint_class") == "behind_counter_person"
        and not any(str(slot_id) == "base.door_right_middle" for slot_id in jazz_preferences.values())
        and not any(str(slot_id) == "base.door_right_middle" for slot_id in jazz_categories.values()),
        "jazz_club: removed middle doorway must stay absent while counter staff remains fixed",
    )
    check.require(
        str(jazz_preferences.get("travel:leave", "")) == "base.door_right_upper"
        and all(str(jazz_categories.get(key, "")) == "base.door_right_upper" for key in jazz_travel_indexes),
        "jazz_club: travel identity and all five travel indexes must use the retained upper doorway",
    )
    check.require(
        set(jazz_exit_slots) == {"exit.left_middle", "exit.left_upper"},
        "jazz_club: both independent left safe exits must survive the doorway simplification",
    )

    scenario_defs: dict[str, dict[str, Any]] = {}
    for source in sorted((root / "data/environments/scenario_sequences").glob("*.json")):
        package = json.loads(source.read_text(encoding="utf-8"))
        for scenario in values(package.get("scenarios")):
            if isinstance(scenario, dict):
                scenario_defs[str(scenario.get("scenario_id", ""))] = scenario
    catalog_rows = [(host, row) for host, rows in scenario_catalog.items() for row in values(rows) if isinstance(row, dict)]
    check.require(len(scenario_defs) == 55, f"expected 55 scenario sequences, found {len(scenario_defs)}")
    check.require(len(catalog_rows) == 55, f"expected 55 legal scenario hosts, found {len(catalog_rows)}")
    scenario_visual_count = 0
    legal_visual_ids_by_map: dict[str, set[str]] = {}
    for host, row in catalog_rows:
        scenario_id = str(row.get("id", ""))
        check.require(scenario_id in scenario_defs, f"{host}: missing sequence {scenario_id}")
        layer_id = str(row.get("layer_id", ""))
        map_id = f"{host}:{layer_id}" if layer_id and f"{host}:{layer_id}" in maps_by_id else host
        map_data = maps_by_id.get(map_id, {})
        check.require(bool(map_data), f"{scenario_id}: legal host map {map_id} is missing")
        visual_ids = scenario_visual_ids(scenario_defs.get(scenario_id, {}))
        legal_visual_ids_by_map.setdefault(map_id, set()).update(visual_ids)
        scenario_visual_count += len(visual_ids)
        verbs = values(scenario_defs.get(scenario_id, {}).get("authoring", {}).get("player_verbs"))
        check.require(bool(verbs) and all(isinstance(verb, str) and verb for verb in verbs), f"{scenario_id}: authored actions are not statically enumerable")
        mutations = row.get("mutations", {}) if isinstance(row.get("mutations"), dict) else {}
        for field in ("next_archetypes_add", "rare_next_archetypes_add"):
            for destination in values(mutations.get(field)):
                check.require(str(destination) in archetypes, f"{scenario_id}: offered destination {destination} is not installable")

    actual_scenario_overflow_ids = {
        (map_id, str(stable_id))
        for map_id, map_data in maps_by_id.items()
        for stable_id in values(map_data.get("scenario_overflow_ids"))
        if isinstance(stable_id, str)
    }
    for map_id, stable_id in sorted(actual_scenario_overflow_ids):
        check.require(
            stable_id in legal_visual_ids_by_map.get(map_id, set()),
            f"{map_id}.scenario_overflow_ids names unknown legal scenario visual {stable_id}",
        )

    active_snapshots = SlotAuthoring.collect_active_phase_snapshots(root)
    complete_snapshots = SlotAuthoring.collect_active_phase_snapshots(root, include_aftermath=True)
    active_snapshot_count = 0
    active_binding_count = 0
    active_overflow_count = 0
    complete_snapshot_count = 0
    complete_binding_count = 0
    complete_overflow_count = 0
    authored_action_count = 0
    complete_rows: list[dict[str, Any]] = []
    active_rows: list[dict[str, Any]] = []
    complete_overflow_occurrences: dict[tuple[str, str], int] = {}
    active_overflow_occurrences: dict[tuple[str, str], int] = {}
    active_overflow_phases: dict[tuple[str, str], set[tuple[str, str]]] = {}
    active_nonphysical_count = 0
    active_nonphysical_room_count = 0
    active_physical_room_count = 0
    complete_binding_replays: list[tuple[str, list[dict[str, Any]], dict[str, dict[str, str]]]] = []
    for map_id, snapshots in complete_snapshots.items():
        map_data = maps_by_id.get(map_id, {})
        check.require(bool(map_data), f"scenario phase inventory references missing map {map_id}")
        for snapshot in snapshots:
            complete_snapshot_count += 1
            first = simulate_scenario_binding(check, map_data, snapshot)
            repeated = simulate_scenario_binding(check, map_data, snapshot)
            check.require(first[0] == repeated[0], f"{map_id}: preferred/priority/id binding is not deterministic")
            complete_binding_count += first[1] + first[2]
            complete_overflow_count += first[2]
            authored_action_count += first[3]
            complete_binding_replays.append((map_id, snapshot, first[0]))
            scenario_id, phase_id = snapshot_tags(snapshot)
            for identity, binding in first[0].items():
                if binding["mode"] == "overflow":
                    key = (map_id, identity)
                    complete_overflow_occurrences[key] = complete_overflow_occurrences.get(key, 0) + 1
            complete_rows.append({
                "map_id": map_id,
                "scenario_id": scenario_id,
                "phase_id": phase_id,
                "binding_count": first[1] + first[2],
                "room_count": first[1],
                "physical_room_count": first[1],
                "overflow_count": first[2],
                "action_list_count": sum(
                    1 for binding in first[0].values()
                    if binding["mode"] == "overflow" and binding.get("overflow_reason") == "action_list_authored"
                ),
                "physical_spill_count": sum(
                    1 for binding in first[0].values()
                    if binding["mode"] == "overflow" and binding.get("overflow_reason") == "physical_spill"
                ),
                "overflow_identities": sorted(identity for identity, binding in first[0].items() if binding["mode"] == "overflow"),
            })
    for map_id, snapshots in active_snapshots.items():
        map_data = maps_by_id.get(map_id, {})
        for snapshot in snapshots:
            active_snapshot_count += 1
            _bindings, room_count, overflow_count, _actions = simulate_scenario_binding(check, map_data, snapshot)
            active_binding_count += room_count + overflow_count
            active_overflow_count += overflow_count
            scenario_id, phase_id = snapshot_tags(snapshot)
            semantic_by_identity = {
                str(semantic.get("identity", "")): semantic
                for semantic in snapshot
                if isinstance(semantic, dict)
            }
            for identity, binding in _bindings.items():
                semantic = semantic_by_identity.get(identity, {})
                actor = bool(semantic.get("_slot_actor", False))
                safe_exit = bool(semantic.get("safe_exit", False))
                physical = scenario_visual_requires_room_slot(
                    map_data,
                    semantic,
                    actor,
                    safe_exit,
                )
                if physical and binding["mode"] == "room":
                    active_physical_room_count += 1
                    if not actor and not safe_exit:
                        check.require(
                            bool(str(binding.get("art_key", ""))),
                            f"{map_id}.{identity}: physical scene object has no sealed concrete art authority",
                        )
                if not physical:
                    active_nonphysical_count += 1
                    if binding["mode"] == "room":
                        active_nonphysical_room_count += 1
                    check.require(
                        binding["mode"] == "attached" and not str(binding.get("slot_id", "")),
                        f"{map_id}.{identity}: abstract/nonphysical scenario record consumed room geometry",
                    )
                    check.require(
                        not binding.get("overflow_reason"),
                        f"{map_id}.{identity}: nonphysical scenario record retained removed overflow authority",
                    )
                if binding["mode"] != "overflow":
                    continue
                key = (map_id, identity)
                active_overflow_occurrences[key] = active_overflow_occurrences.get(key, 0) + 1
                active_overflow_phases.setdefault(key, set()).add((scenario_id, phase_id))
                check.require(
                    not str(binding.get("slot_id", "")),
                    f"{map_id}.{identity}: overflow presentation retained room geometry",
                )
                if physical:
                    check.require(
                        binding.get("overflow_reason") == "physical_spill"
                        and identity.removeprefix("scenario::") in set(values(map_data.get("scenario_overflow_ids"))),
                        f"{map_id}.{identity}: physical spill lacks explicit stable-id overflow authority",
                    )
                if bool(semantic.get("visible", True)) and not bool(semantic.get("_slot_hidden", False)):
                    check.require(
                        bool(str(semantic.get("label", "")).strip())
                        and bool(str(semantic.get("description", "")).strip()),
                        f"{map_id}.{identity}: visible informational overflow row lost its player-facing label or summary",
                    )
            active_rows.append({
                "map_id": map_id,
                "scenario_id": scenario_id,
                "phase_id": phase_id,
                "binding_count": room_count + overflow_count,
                "room_count": room_count,
                "physical_room_count": room_count,
                "overflow_count": overflow_count,
                "action_list_count": sum(
                    1 for binding in _bindings.values()
                    if binding["mode"] == "attached"
                ),
                "physical_spill_count": sum(
                    1 for binding in _bindings.values()
                    if binding["mode"] == "overflow" and binding.get("overflow_reason") == "physical_spill"
                ),
                "overflow_identities": sorted(identity for identity, binding in _bindings.items() if binding["mode"] == "overflow"),
            })
    active_overflow_rate = active_overflow_count / max(1, active_binding_count)
    # Abstract scenario actions attach to visible people or fixtures. Physical
    # visuals require authored geometry; the removed overflow plane must stay
    # empty in every reachable phase.
    check.require(active_nonphysical_count > 0, "scenario census found no abstract/nonphysical action-list records")
    check.require(active_nonphysical_room_count == 0, f"{active_nonphysical_room_count} abstract/nonphysical records consumed room slots")
    check.require(active_physical_room_count > 0, "scenario census found no physical in-room records")
    check.require(active_overflow_count == 0, f"active scenario census retained {active_overflow_count} removed overflow records")
    check.require(authored_action_count > 0, "scenario phase simulation enumerated no authored actions")
    base_scenario_census = conservative_base_label_scenario_census(
        check,
        maps_by_id,
        complete_binding_replays,
        set(scenario_defs),
        board,
    )

    manifest_rows = values(exact_seed_manifest.get("expectations"))
    legal_room_combinations = values(exact_seed_manifest.get("legal_room_combinations"))
    check.require(exact_seed_manifest.get("schema_version") == 1, "exact-seed manifest schema_version must be 1")
    check.require(len(manifest_rows) == 22, f"historical UIENV exact-seed manifest must contain 22 rows, found {len(manifest_rows)}")
    check.require(len(legal_room_combinations) == 1, f"historical UIENV legal-room fixture must contain one row, found {len(legal_room_combinations)}")
    seed_ids = [str(item.get("seed", "")) for item in manifest_rows if isinstance(item, dict)]
    check.require(len(set(seed_ids)) == 22 and all(seed_ids), "historical UIENV exact-seed identities must be unique and non-empty")
    event_ids = {str(item.get("id", "")) for item in values(event_catalog) if isinstance(item, dict)}
    marker_owners: dict[str, list[tuple[str, str]]] = {}
    for host, row in catalog_rows:
        mutations = row.get("mutations", {}) if isinstance(row.get("mutations"), dict) else {}
        for marker in values(mutations.get("event_pool_add")):
            marker_owners.setdefault(str(marker), []).append((str(host), str(row.get("id", ""))))
    for expectation in manifest_rows:
        if not isinstance(expectation, dict):
            check.errors.append("historical UIENV exact-seed manifest contains a non-object row")
            continue
        seed = str(expectation.get("seed", ""))
        destination = str(expectation.get("destination", ""))
        scenario_id = str(expectation.get("scenario_id", ""))
        marker = str(expectation.get("required_marker", ""))
        required_object = str(expectation.get("required_object", ""))
        required_interaction = str(expectation.get("required_interaction", ""))
        check.require(destination in maps_by_id, f"{seed}: exact-seed destination {destination} has no slot map")
        check.require(scenario_id in scenario_defs, f"{seed}: exact-seed scenario {scenario_id} has no sequence")
        check.require(marker in event_ids, f"{seed}: exact-seed marker {marker} is not an event")
        check.require(marker_owners.get(marker, []) == [(destination, scenario_id)], f"{seed}: marker {marker} does not uniquely identify {destination}/{scenario_id}")
        if required_object:
            check.require(required_object in event_ids, f"{seed}: required base object {required_object} is not an event")
        matching_snapshots = [
            snapshot
            for snapshot in complete_snapshots.get(destination, [])
            if any(str(item.get("_slot_scenario_id", "")) == scenario_id for item in snapshot)
        ]
        check.require(bool(matching_snapshots), f"{seed}: no reachable snapshots for {destination}/{scenario_id}")
        interaction_bindings: list[str] = []
        for snapshot in matching_snapshots:
            if not any(str(item.get("identity", "")) == required_interaction for item in snapshot):
                continue
            bindings, _room, _overflow, _actions = simulate_scenario_binding(check, maps_by_id.get(destination, {}), snapshot)
            if required_interaction in bindings:
                interaction_bindings.append(str(bindings[required_interaction]["mode"]))
        check.require(bool(interaction_bindings), f"{seed}: required interaction {required_interaction} never receives room/overflow authority")

    # Exact seeds can traverse a legal room before reaching their manifest's
    # final destination. Preserve the first repaired pre-destination composition
    # explicitly: the generated town-rumor staff label and Delivery Day's live
    # manifest gate must be checked together, including both target-size modes.
    for combination in legal_room_combinations:
        if not isinstance(combination, dict):
            check.errors.append("historical UIENV legal-room fixture contains a non-object row")
            continue
        seed = str(combination.get("seed", ""))
        destination = str(combination.get("destination", ""))
        scenario_id = str(combination.get("scenario_id", ""))
        phase_id = str(combination.get("phase_id", ""))
        base_event_id = str(combination.get("base_event_id", ""))
        base_identity = f"event::event:{base_event_id}"
        base_slot_id = str(combination.get("base_slot_id", ""))
        scenario_identity = str(combination.get("scenario_identity", ""))
        check.require(seed in seed_ids, f"{seed}: legal-room fixture is not attached to a historical exact seed")
        check.require(destination in maps_by_id, f"{seed}: legal-room destination {destination} has no slot map")
        check.require(scenario_id in scenario_defs, f"{seed}: legal-room scenario {scenario_id} has no sequence")
        check.require(base_event_id in events_by_id, f"{seed}: legal-room base event {base_event_id} is missing")
        map_data = maps_by_id.get(destination, {})
        slots_by_id = {str(slot.get("id", "")): slot for slot in all_slots(map_data)}
        base_slot = slots_by_id.get(base_slot_id, {})
        base_hit = rect(base_slot.get("hit_rect"))
        base_label = str(events_by_id.get(base_event_id, {}).get("display_name", ""))
        check.require(bool(base_slot), f"{seed}: legal-room base slot {base_slot_id} is missing")
        check.require(base_hit is not None, f"{seed}: legal-room base slot {base_slot_id} has no target")
        check.require(bool(base_label), f"{seed}: legal-room base identity {base_identity} has no label")
        matching_snapshots = [
            snapshot
            for snapshot in complete_snapshots.get(destination, [])
            if any(
                str(item.get("_slot_scenario_id", "")) == scenario_id
                and str(item.get("_slot_phase_id", "")) == phase_id
                and str(item.get("identity", "")) == scenario_identity
                for item in snapshot
            )
        ]
        check.require(bool(matching_snapshots), f"{seed}: legal-room fixture found no {scenario_id}/{phase_id} snapshot containing {scenario_identity}")
        checked_snapshots = 0
        for snapshot in matching_snapshots:
            bindings, _room, _overflow, _actions = simulate_scenario_binding(check, map_data, snapshot)
            scenario_binding = bindings.get(scenario_identity, {})
            semantic = next((item for item in snapshot if str(item.get("identity", "")) == scenario_identity), {})
            physical = scenario_visual_requires_room_slot(
                map_data,
                semantic,
                bool(semantic.get("_slot_actor", False)),
                bool(semantic.get("safe_exit", False)),
            )
            if not physical:
                check.require(
                    scenario_binding.get("mode") == "attached"
                    and not scenario_binding.get("slot_id")
                    and not scenario_binding.get("placement_class"),
                    f"{seed}: legal-room abstract identity {scenario_identity} did not retain attached-object authority",
                )
                check.require(
                    bool(str(semantic.get("label", "")).strip())
                    and bool(str(semantic.get("description", "")).strip()),
                    f"{seed}: legal-room abstract identity {scenario_identity} lost its accessible label or summary",
                )
                if base_hit is not None and base_label:
                    checked_snapshots += 1
                continue
            check.require(scenario_binding.get("mode") == "room", f"{seed}: legal-room physical scenario identity {scenario_identity} did not receive a room slot")
            scenario_slot_id = str(scenario_binding.get("slot_id", ""))
            scenario_slot = slots_by_id.get(scenario_slot_id, {})
            scenario_hit = rect(scenario_slot.get("hit_rect"))
            scenario_label = SlotAuthoring.placement_label(semantic)
            check.require(scenario_hit is not None, f"{seed}: legal-room scenario slot {scenario_slot_id} has no target")
            check.require(bool(scenario_label), f"{seed}: legal-room scenario identity {scenario_identity} has no label")
            if base_hit is None or scenario_hit is None or not base_label or not scenario_label:
                continue
            checked_snapshots += 1
            base_label_bounds = label_rect(base_slot, base_label, board)
            scenario_label_bounds = label_rect(scenario_slot, scenario_label, board)
            base_small_hit = expanded(base_hit, board)
            scenario_small_hit = expanded(scenario_hit, board)
            prefix = f"{seed}: legal {destination}/{scenario_id}/{phase_id} {base_identity}@{base_slot_id} vs {scenario_identity}@{scenario_slot_id}"
            check.require(not intersects(base_label_bounds, scenario_label_bounds), f"{prefix}: labels overlap")
            check.require(not intersects(base_label_bounds, scenario_hit), f"{prefix}: base label overlaps scenario normal target")
            check.require(not intersects(base_label_bounds, scenario_small_hit), f"{prefix}: base label overlaps scenario expanded target")
            check.require(not intersects(scenario_label_bounds, base_hit), f"{prefix}: scenario label overlaps base normal target")
            check.require(not intersects(scenario_label_bounds, base_small_hit), f"{prefix}: scenario label overlaps base expanded target")
        check.require(checked_snapshots > 0, f"{seed}: legal-room fixture did not validate a complete label/target composition")

    binder_source = (root / "scripts/core/environment_slot_binder.gd").read_text(encoding="utf-8")
    instance_source = (root / "scripts/core/environment_instance.gd").read_text(encoding="utf-8")
    resolver_source = (root / "scripts/core/scenario_layout_resolver.gd").read_text(encoding="utf-8")
    placement_source = (root / "scripts/core/environment_placement.gd").read_text(encoding="utf-8")
    canvas_source = (root / "scripts/ui/pixel_scene_canvas.gd").read_text(encoding="utf-8")
    meta_source = (root / "scripts/ui/meta_session_controller.gd").read_text(encoding="utf-8")
    capture_source = (root / "tools/environment_layout_screenshots.gd").read_text(encoding="utf-8")
    check.require(not any(token in binder_source for token in ("randf(", "randi(", "randomize(", "Time.")), "slot binder must not use RNG/wall clock")
    check.require("EnvironmentSlotBinderScript.bind_base_layout" in instance_source, "generated base inventory does not use fixed-slot binder")
    ensure_source = instance_source.split("static func ensure_generated_layout", 1)[-1].split("static func _grounding_signature", 1)[0]
    check.require("_ground_authored_object_rects(" not in ensure_source, "generated layout still invokes runtime grounding")
    check.require(
        "current_slot_map_digest" in ensure_source
        and 'layout.get("slot_map_digest", "")' in ensure_source,
        "generated-layout cache does not invalidate against the current authored slot-map digest",
    )
    queue_source = resolver_source.split("static func _resolve_visual_queue", 1)[-1].split("static func _validate_visual_access", 1)[0]
    check.require("bind_scenario_visuals" in queue_source and "_collision_safe_rect" not in queue_source, "scenario queue still performs runtime coordinate search")
    scenario_binding_source = binder_source.split("static func bind_scenario_visuals", 1)[-1].split("static func slot_map_digest", 1)[0]
    slot_digest_source = binder_source.split("static func slot_map_digest", 1)[-1].split("static func _scenario_overflow_policy", 1)[0]
    art_policy_source = binder_source.split("static func _validate_scenario_art_policy", 1)[-1].split("static func _scenario_overflow_policy", 1)[0]
    check.require(
        "_validate_scenario_art_policy" in scenario_binding_source
        and "scenario_visual_requires_room_slot" in scenario_binding_source
        and "_scenario_overflow_policy" in scenario_binding_source
        and "Scenario physical spill is no longer supported" in scenario_binding_source
        and "_warn_missing_slot" in scenario_binding_source
        and "safe_exit" in scenario_binding_source
        and "route_id" in scenario_binding_source,
        "scenario semantic presentation is not sealed into attached-action and authored-room paths",
    )
    check.require(
        '"scenario_art_keys": _dict(surface_map.get("scenario_art_keys", {}))' in slot_digest_source
        and '"scenario_overflow_ids": _array(surface_map.get("scenario_overflow_ids", []))' in slot_digest_source,
        "scenario art/overflow authority is absent from the deterministic slot-map digest",
    )
    check.require(
        "CONCRETE_SCENARIO_ART_KEYS" in art_policy_source
        and "unknown authored identity" in art_policy_source
        and "has no exact authored slot preference" in art_policy_source,
        "scenario concrete-art runtime policy does not fail closed against exact stable-id and slot authority",
    )
    selected_action_source = canvas_source.split("func _selected_info_has_action_button", 1)[-1].split("func keyboard_reachable_object_ids", 1)[0]
    selected_snapshot_source = canvas_source.split("func _selected_info_action_snapshot_list", 1)[-1].split("func _selected_info_badge_entries_for_rect", 1)[0]
    selected_mouse_source = canvas_source.split("func _activate_selected_info_action_at_local_position", 1)[-1].split("func _activate_selected_info_action_by_index", 1)[0]
    selected_entry_source = canvas_source.split("func _activate_selected_info_action_entry", 1)[-1].split("func keyboard_reachable_object_ids", 1)[0]
    check.require(
        '"enabled": not bool(object_data.get("disabled", false))' in selected_action_source
        and 'not bool(action_data.get("disabled", false))' in selected_action_source
        and 'not bool(first_action.get("disabled", false))' in selected_action_source
        and 'object_data.get("confirm_action_id", "")' in selected_action_source
        and "_selected_info_action_is_visible" in selected_action_source,
        "selected-info action entries no longer derive visible fail-closed enabled authority from object/action state",
    )
    check.require(
        '"enabled": bool(action_entry.get("enabled", false))' in selected_snapshot_source
        and 'not bool(action_entry.get("enabled", false))' in selected_mouse_source
        and 'not bool(action_entry.get("enabled", false))' in selected_entry_source,
        "selected-info snapshots or mouse/keyboard activation no longer reject missing/disabled enabled authority",
    )
    interaction_controller_source = (root / "scripts/ui/environment_interaction_controller.gd").read_text(encoding="utf-8")
    check.require(
        "_attach_action_only_records" in interaction_controller_source
        and "attached_room_actions" in interaction_controller_source,
        "abstract scenario actions are not attached to visible room objects",
    )
    check.require(
        "EnvironmentSlotBinderScript.authored_route_points" in queue_source,
        "scenario actors do not slice their route between authored lane endpoint projections",
    )
    transit_source = canvas_source.split("func _person_transit_route", 1)[-1].split("func _apply_person_transit_to_scene_object", 1)[0]
    check.require(
        "EnvironmentSlotBinderScript.authored_route_points" in transit_source
        and 'lane.get("points"' not in transit_source,
        "person arrivals/departures do not use the shared shortest authored-lane slice",
    )
    draw_source = canvas_source.split("func _draw()", 1)[-1].split("func _draw_developer_placement_outline", 1)[0]
    scene_objects_source = canvas_source.split("func _draw_scene_objects", 1)[-1].split("func _draw_scene_object_body", 1)[0]
    counter_foreground_source = canvas_source.split("func _draw_counter_foreground_art", 1)[-1].split("func _draw_hotspot_hint", 1)[0]
    check.require(
        0 <= draw_source.find("_draw_authored_counter_foregrounds()") < draw_source.find("_draw_scene_life()")
        and "_draw_room_foreground_occluders(behind_counter)" in scene_objects_source
        and scene_objects_source.find("_draw_scene_object_body(object_value as Dictionary)")
        < scene_objects_source.find("_draw_room_foreground_occluders(behind_counter)"),
        "behind-counter people are not sandwiched between the authored fixture base and exact foreground replay",
    )
    check.require(
        all(f'"{art_id}"' in counter_foreground_source for art_id in COUNTER_FOREGROUND_ART_IDS)
        and "_:" in counter_foreground_source
        and "return false" in counter_foreground_source
        and "_draw_counter_person_occlusion" not in canvas_source,
        "counter foreground renderer is not a closed authored-art replay or the old generic occluder survived",
    )
    for token in (
        "static func _ground_authored_object_rects",
        "static func _resolve_active_object_rect_collisions",
        "static func _first_noncolliding_object_rect",
        "static func _fallback_grid_object_rects",
        "static func _first_available_object_rect",
    ):
        check.require(token not in instance_source, f"superseded base-layout search survived deletion: {token}")
    for token in (
        "static func _resolve_visual(",
        "static func _collision_safe_rect",
        "static func _bounded_collision_candidates",
        "static func _fine_collision_candidates",
        "static func _coarse_collision_candidates",
    ):
        check.require(token not in resolver_source, f"superseded scenario-layout search survived deletion: {token}")
    for token in (
        "static func authored_or_local_rect",
        "static func supported_rect_candidates",
        "static func class_default_rect",
        "static func _local_support_candidates",
        "static func grounded_rect",
        "static func candidate_rects",
        "static func _ordered_values",
    ):
        check.require(token not in placement_source, f"superseded placement candidate search survived deletion: {token}")
    surface_body = placement_source.split("static func surface_map(environment", 1)[-1].split("static func surface_map_by_id", 1)[0]
    check.require("_with_developer_slots" not in surface_body, "developer placement overrides leak into shipping surface_map")
    check.require("static func authoring_surface_map" in placement_source, "developer placement has no isolated authoring API")
    record_binding_source = binder_source.split("static func bind_base_records", 1)[-1].split("static func bind_scenario_visuals", 1)[0]
    check.require(
        "slot_binding_source_id" in record_binding_source
        and '"slot_binding_source_id": "item:sal_shelf_%d" % index' in meta_source
        and '"slot_binding_source_id": "shopkeeper:merchant"' in meta_source,
        "pawn-shop actionable aliases do not reuse their generated fixed-slot bindings",
    )
    home_meta_source = meta_source.split("func _home_interactable_objects", 1)[-1].split("func _pawn_interactable_objects", 1)[0]
    check.require(
        '"slot_binding_source_id": "home_container:%s" % container_id' in home_meta_source
        and home_meta_source.count('"placement_class": "floor_fixture"') >= 1
        and home_meta_source.count('"placement_class": "wall_mounted"') >= 1
        and home_meta_source.count('"placement_class": "surface_item"') >= 1
        and home_meta_source.count('"placement_class": "doorway"') >= 1,
        "home meta controls do not carry exact generated aliases and explicit named-slot classes",
    )
    authority_validation_source = binder_source.split("static func validate_base_layout_authority", 1)[-1].split("static func bind_base_records", 1)[0]
    override_index = authority_validation_source.find('surface_map.get("class_overrides", {})')
    record_class_index = authority_validation_source.find('record.has("placement_class")')
    closed_class_index = authority_validation_source.find("_closed_semantic_placement_class")
    mismatch_index = authority_validation_source.find("placement class does not match production classification")
    check.require(
        -1 < override_index < record_class_index < closed_class_index < mismatch_index,
        "base slot authority must prefer authored class overrides and still reject a mismatched persisted binding",
    )
    capture_resolver_source = capture_source.split("func _rw06_1_resolve_capture_state", 1)[-1].split("func _rw06_1_reachable_phase_states", 1)[0]
    capture_trace_source = capture_source.split("func _rw06_1_reachable_phase_states", 1)[-1].split("func _rw06_1_apply_trace_command", 1)[0]
    capture_prepare_source = capture_source.split("func _rw06_1_prepare_scenario_peak", 1)[-1].split("func _rw06_1_resolve_capture_state", 1)[0]
    check.require(
        "ScenarioSequenceRuntimeScript.public_projection(state, definition, true)" in capture_resolver_source
        and "ScenarioEngineScript.sequence_projection" not in capture_resolver_source,
        "contact-sheet capture must project successful traced states through the exact prevalidated commit seam",
    )
    check.require(
        'condition_type == "always"' in capture_trace_source
        and "ScenarioSequenceRuntimeScript.STATUS_ACTIVE" in capture_trace_source,
        "contact-sheet trace must treat terminal automatic branches as already evaluated",
    )
    check.require(
        'reachable.get("errors"' in capture_prepare_source
        and 'resolved.get("errors"' in capture_prepare_source
        and 'reachable.get("explored_state_count"' in capture_prepare_source,
        "contact-sheet capture must retain traversal and layout diagnostics",
    )
    capture_pair_source = capture_source.split("func _rw06_1_capture_pair", 1)[-1].split("func _rw06_1_clear_player_view_artifacts", 1)[0]
    cleanliness_source = capture_source.split("func _rw06_1_player_view_cleanliness", 1)[-1].split("func _rw06_1_remove_stale_contact_artifacts", 1)[0]
    check.require(
        'root.get_viewport().get_texture().get_image()' in capture_pair_source
        and '"capture_source": "production_root_viewport_texture"' in capture_pair_source
        and '"post_processed": false' in capture_pair_source
        and ".resize(" not in capture_pair_source,
        "contact-sheet source images must be saved directly from the production viewport without post-processing",
    )
    for assertion_name in (
        "production_environment_canvas",
        "direct_root_viewport",
        "developer_placement_mode_disabled",
        "developer_placement_panel_hidden",
        "developer_hit_preview_absent",
        "telemetry_absent",
        "coach_root_hidden",
        "coach_panel_hidden",
        "coach_focus_layer_hidden",
        "coach_snapshot_hidden",
        "selection_absent",
        "hover_absent",
        "hit_annotations_absent",
        "camera_debug_focus_absent",
    ):
        check.require(f'"{assertion_name}"' in cleanliness_source, f"contact-sheet player-view gate is missing {assertion_name}")
    check.require(
        "if player_view_failure:" in capture_source
        and "capture_rows.clear()" in capture_source
        and '"fail_closed_zero_rows"' in capture_source
        and "_rw06_1_remove_contact_source_images(selections)" in capture_source,
        "a dirty player-view source must invalidate and remove the entire owner-review capture set",
    )
    q008_capture_source = capture_source.split("func _run_rw06_1_q008", 1)[-1].split("func _rw06_1_q008_selections", 1)[0]
    q008_selection_source = capture_source.split("func _rw06_1_q008_selections", 1)[-1].split("func _rw06_1_capture_normal_source", 1)[0]
    marker_capture_source = capture_source.split("func _run_rw06_1_slot_markers", 1)[-1].split("func _rw06_1_prepare_base_map", 1)[0]
    marker_source_capture = capture_source.split("func _rw06_1_capture_slot_markers", 1)[-1].split("func _rw06_1_empty_room_snapshot", 1)[0]
    check.require(
        'argument == "--rw06-1-q008"' in capture_source
        and '"columns": 3, "rows": 2' in q008_capture_source
        and '"normal_only": true' in q008_capture_source
        and '"production_root_viewport_texture"' in q008_capture_source
        and "physical_room_count" in q008_selection_source
        and 'static_report.get("active_scenarios", [])' in q008_selection_source,
        "Q-008 owner-review capture is not a strict 3x2 normal-only base/physical-peak proof",
    )
    check.require(
        'argument == "--rw06-1-slot-markers"' in capture_source
        and 'surface_data.get("maps", [])' in marker_capture_source
        and '"empty_room_interactable_count": 0' in marker_capture_source
        and "SlotMarkerOverlay.new()" in marker_source_capture
        and "root.remove_child(overlay)" in marker_source_capture
        and '"capture_only_overlay_removed"' in marker_source_capture,
        "all-map empty-room numbered slot-marker capture is missing or does not clean up its capture-only overlay",
    )

    # Authored JSON is continuing authority. The migration helper remains a
    # reproducibility tool, but acceptance must allow one valid slot to be added
    # directly without regenerating every room's slot arrays.
    validate_single_json_slot_extension(check, maps_by_id, archetypes, board)
    active_summaries = summarize_scenarios(active_rows)
    complete_summaries = summarize_scenarios(complete_rows)
    contact_sheet = contact_sheet_report(active_summaries, archetypes)
    check.require(len(contact_sheet) == 18, f"contact-sheet manifest must cover 18 rooms, found {len(contact_sheet)}")
    check.require(
        len({str(item.get("archetype_id", "")) for item in contact_sheet}) == 18,
        "contact-sheet manifest room ids are empty or duplicated",
    )
    check.require(
        [str(item.get("archetype_id", "")) for item in contact_sheet if bool(item.get("day2_sample", False))]
        == ["bar", "corner_store", "grand_casino"],
        "contact-sheet day-2 manifest must select bar, corner_store, and grand_casino",
    )
    report = {
        "tool": "environment_fixed_slot_static_check",
        "passed": not check.errors,
        "error_count": len(check.errors),
        "counts": {
            "maps": len(maps_by_id),
            "archetypes": len(archetypes),
            "scenarios": len(scenario_defs),
            "legal_hosts": len(catalog_rows),
            "authored_visuals": scenario_visual_count,
            "active_snapshots": active_snapshot_count,
            "active_bindings": active_binding_count,
            "active_overflow": active_overflow_count,
            "active_overflow_rate": active_overflow_rate,
            "active_nonphysical": active_nonphysical_count,
            "active_nonphysical_room": active_nonphysical_room_count,
            "active_physical_room": active_physical_room_count,
            "complete_snapshots": complete_snapshot_count,
            "complete_bindings": complete_binding_count,
            "complete_overflow": complete_overflow_count,
            "authored_actions": authored_action_count,
            "historical_exact_seeds": len(manifest_rows),
            "historical_legal_room_combinations": len(legal_room_combinations),
            "base_scenario_snapshots": int(base_scenario_census.get("snapshots", 0)),
            "base_scenario_legal_scenarios": int(base_scenario_census.get("legal_scenarios", 0)),
            "base_scenario_base_slot_observations": int(base_scenario_census.get("base_slot_observations", 0)),
            "base_scenario_authorities": int(base_scenario_census.get("scenario_authorities", 0)),
            "base_scenario_pair_tests": int(base_scenario_census.get("pair_tests", 0)),
            "base_scenario_conflicts": int(base_scenario_census.get("conflict_count", 0)),
            "base_label_slots": int(base_scenario_census.get("base_slots", 0)),
            "base_base_pair_tests": int(base_scenario_census.get("base_base_pair_tests", 0)),
            "base_base_conflicts": int(base_scenario_census.get("base_base_conflicts", 0)),
            "mandatory_lane_obstacle_checks": int(base_scenario_census.get("mandatory_lane_obstacle_checks", 0)),
            "mandatory_lane_obstacle_states": int(base_scenario_census.get("mandatory_lane_obstacle_states", 0)),
            "mandatory_lane_overflow_states": int(base_scenario_census.get("mandatory_lane_overflow_states", 0)),
        },
        "day2_samples": day2_sample_report(active_summaries),
        "contact_sheet": contact_sheet,
        "active_scenarios": active_summaries,
        "complete_scenarios": complete_summaries,
        "errors": check.errors,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if check.errors:
        print("ENVIRONMENT_FIXED_SLOT_STATIC_CHECK FAIL", file=sys.stderr)
        for error in check.errors:
            print(f" - {error}", file=sys.stderr)
        return 1
    print(
        "ENVIRONMENT_FIXED_SLOT_STATIC_CHECK PASS "
        f"maps={len(maps_by_id)} archetypes={len(archetypes)} scenarios={len(scenario_defs)} "
        f"legal_hosts={len(catalog_rows)} authored_visuals={scenario_visual_count} "
        f"active_snapshots={active_snapshot_count} active_bindings={active_binding_count} "
        f"active_overflow={active_overflow_count} active_overflow_rate={active_overflow_rate:.4f} "
        f"complete_snapshots={complete_snapshot_count} complete_bindings={complete_binding_count} "
        f"complete_overflow={complete_overflow_count} authored_actions={authored_action_count} "
        f"historical_exact_seeds={len(manifest_rows)} base_scenario_pair_tests={base_scenario_census.get('pair_tests', 0)} "
        f"base_scenario_conflicts={base_scenario_census.get('conflict_count', 0)} "
        f"base_base_pair_tests={base_scenario_census.get('base_base_pair_tests', 0)} "
        f"base_base_conflicts={base_scenario_census.get('base_base_conflicts', 0)} "
        f"mandatory_lane_obstacle_checks={base_scenario_census.get('mandatory_lane_obstacle_checks', 0)} "
        f"report={report_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
