#!/usr/bin/env python3
"""Fast, engine-free authority check for rw06_1 fixed room slots."""

from __future__ import annotations

import copy
import json
import math
import sys
from pathlib import Path
from typing import Any

import rw06_1_author_fixed_slots as SlotAuthoring


CLASSES = {
    "standing_person", "behind_counter_person", "seated_person", "group",
    "floor_fixture", "ground_marker", "surface_item", "wall_mounted",
    "hanging", "doorway",
}
KINDS = {"base", "stage", "exit"}
FACINGS = {"left", "right", "front", "back", "none"}
SLOT_FIELDS = {
    "id", "kind", "pos", "footprint_class", "hit_rect", "label_anchor",
    "facing", "priority", "zone_id", "support_id", "walk_lane_ids",
}
MAP_SLOT_FIELDS = ("base_slots", "stage_slots", "exit_slots")
EPSILON = 0.01


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
    width, height = max(44.0, bounds[2]), max(44.0, bounds[3])
    center_x, center_y = bounds[0] + bounds[2] / 2.0, bounds[1] + bounds[3] / 2.0
    return (
        min(max(0.0, center_x - width / 2.0), board[0] - width),
        min(max(0.0, center_y - height / 2.0), board[1] - height),
        width,
        height,
    )


def label_rect(slot: dict[str, Any], board: tuple[float, float]) -> tuple[float, float, float, float]:
    bounds = rect(slot.get("hit_rect")) or (0.0, 0.0, 0.0, 0.0)
    anchor = point(slot.get("label_anchor")) or (0.0, 0.0)
    width = max(88.0, min(132.0, bounds[2] + 24.0))
    return (
        min(max(0.0, anchor[0] - width / 2.0), board[0] - width),
        max(0.0, anchor[1] - 18.0),
        width,
        18.0,
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
    if placement_class in {"behind_counter_person", "surface_item"}:
        return "counter"
    if placement_class == "seated_person":
        return "seat"
    if placement_class == "wall_mounted":
        return "wall"
    if placement_class == "hanging":
        return "ceiling"
    return "doorway"


def all_slots(map_data: dict[str, Any]) -> list[dict[str, Any]]:
    return [slot for field in MAP_SLOT_FIELDS for slot in values(map_data.get(field)) if isinstance(slot, dict)]


def ordered_slots(map_data: dict[str, Any], field: str) -> list[dict[str, Any]]:
    return sorted(
        (slot for slot in values(map_data.get(field)) if isinstance(slot, dict)),
        key=lambda slot: (int(slot.get("priority", 0)), str(slot.get("id", ""))),
    )


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
    class_overrides = map_data.get("class_overrides", {}) if isinstance(map_data.get("class_overrides"), dict) else {}
    entries: list[tuple[int, str, str, bool, str, bool]] = []
    interactions: dict[str, dict[str, Any]] = {}
    for semantic in snapshot:
        identity = str(semantic.get("identity", ""))
        interaction = semantic.get("_slot_interaction", {}) if isinstance(semantic.get("_slot_interaction"), dict) else {}
        if interaction:
            interactions[identity] = interaction
        if bool(semantic.get("_slot_interaction_only", False)) or not identity.startswith("scenario::"):
            continue
        stable_id = identity.removeprefix("scenario::")
        actor = bool(semantic.get("_slot_actor", False))
        placement_class = SlotAuthoring.classify(
            semantic,
            "actor" if actor else "scene_object",
            identity,
            str(class_overrides.get(identity, class_overrides.get(stable_id, ""))),
        )
        route_id = str(semantic.get("route_id", ""))
        safe_exit = bool(semantic.get("safe_exit", False))
        # Production promotes every required exit to the doorway footprint class
        # before binding, regardless of the semantic object's visual category.
        if safe_exit:
            placement_class = "doorway"
        rank = 0 if safe_exit else 1 if route_id else 2
        entries.append((rank, identity, placement_class, safe_exit, route_id, bool(semantic.get("_slot_hidden", False))))
    entries.sort(key=lambda entry: (entry[0], entry[1]))
    occupied: set[str] = set()
    bindings: dict[str, dict[str, str]] = {}
    hidden_identities: set[str] = set()
    for _rank, identity, placement_class, safe_exit, route_id, hidden in entries:
        if hidden:
            hidden_identities.add(identity)
        selected: dict[str, Any] | None = None
        route = routes.get(route_id, {}) if route_id else {}
        if route_id and route:
            start_id = str(route.get("start_slot_id", ""))
            end_id = str(route.get("end_slot_id", ""))
            start = slot_by_id.get(start_id, {})
            end = slot_by_id.get(end_id, {})
            if (start and end and str(start.get("footprint_class", "")) == placement_class
                    and start_id not in occupied and end_id not in occupied):
                selected = start
                occupied.update({start_id, end_id})
        else:
            pool = exit_slots if safe_exit else stage_slots
            stable_id = identity.removeprefix("scenario::")
            preferred_id = str(preferences.get(stable_id, preferences.get(identity, "")))
            candidates = ([slot_by_id[preferred_id]] if preferred_id in slot_by_id and slot_by_id[preferred_id] in pool else []) + pool
            for slot in candidates:
                slot_id = str(slot.get("id", ""))
                if str(slot.get("footprint_class", "")) == placement_class and slot_id not in occupied:
                    selected = slot
                    occupied.add(slot_id)
                    break
        if selected is None:
            bindings[identity] = {"mode": "overflow", "slot_id": "", "placement_class": placement_class}
        else:
            bindings[identity] = {
                "mode": "room",
                "slot_id": str(selected.get("id", "")),
                "placement_class": placement_class,
            }
        if safe_exit:
            check.require(bindings[identity]["mode"] == "room", f"{map_id}.{identity}: required safe exit overflowed")
        if route_id:
            check.require(bool(route), f"{map_id}.{identity}: route {route_id} has no authored slot/lane record")
            check.require(bindings[identity]["mode"] in {"room", "overflow"}, f"{map_id}.{identity}: routed actor has no binding")

    room_count = sum(1 for binding in bindings.values() if binding["mode"] == "room")
    overflow_count = len(bindings) - room_count
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
            check.require(presentation_identity in bindings, f"{map_id}.{identity}: actions have no slot or overflow presentation")
        else:
            # Base interactions are bound by the same deterministic base binder;
            # the static map only needs at least one compatible base class because
            # exhaustion is explicitly represented by the shared overflow list.
            check.require(bool(values(map_data.get("base_slots"))), f"{map_id}.{identity}: base action has no base-slot/overflow authority")
    check.require(len(bindings) == len(entries), f"{map_id}: scenario binding silently omitted a visual")
    return bindings, room_count, overflow_count, action_count


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
                int(item["binding_count"]),
                int(item["overflow_count"]),
                str(item["phase_id"]),
            ),
        )
        binding_count = sum(int(item["binding_count"]) for item in snapshots)
        overflow_count = sum(int(item["overflow_count"]) for item in snapshots)
        result.append({
            "map_id": map_id,
            "scenario_id": scenario_id,
            "snapshot_count": len(snapshots),
            "binding_count": binding_count,
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
        peak_binding_count = max((int(item["peak"]["binding_count"]) for item in room), default=0)
        room_peak_ties = sorted(
            (item for item in room if int(item["peak"]["binding_count"]) == peak_binding_count),
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
                "overflow_count": 0,
                "day2_sample": False,
                "selection_reason": "room has no legal scenario; capture complete generated base inventory",
            })
            continue
        peak_binding_count = max(int(item["peak"]["binding_count"]) for item in room)
        ties = sorted(
            (item for item in room if int(item["peak"]["binding_count"]) == peak_binding_count),
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
    slots = all_slots(map_data)
    check.require(bool(values(map_data.get("base_slots"))), f"{map_id}: no base slots")
    check.require(bool(values(map_data.get("stage_slots"))), f"{map_id}: no stage slots")
    check.require(len(values(map_data.get("exit_slots"))) >= 2, f"{map_id}: fewer than two exit slots")
    slot_by_id: dict[str, dict[str, Any]] = {}
    supports = named_supports(map_data)
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
            if hit is not None:
                if zone_id == "room":
                    check.require(encloses(board_rect, hit), f"{map_id}.{slot_id}: leaves room zone")
                else:
                    zone = zones.get(zone_id, {}) if isinstance(zones, dict) else {}
                    zone_bounds = rect(zone.get("bounds")) if isinstance(zone, dict) else None
                    check.require(zone_bounds is not None and encloses(zone_bounds, hit), f"{map_id}.{slot_id}: not enclosed by semantic zone {zone_id}")
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

    for left_index, left in enumerate(slots):
        left_hit = rect(left.get("hit_rect"))
        if left_hit is None:
            continue
        for right in slots[left_index + 1:]:
            right_hit = rect(right.get("hit_rect"))
            if right_hit is None:
                continue
            pair = f"{map_id}: {left.get('id')} / {right.get('id')}"
            check.require(not intersects(left_hit, right_hit), f"{pair}: normal hit rectangles overlap")
            left_expanded, right_expanded = expanded(left_hit, board), expanded(right_hit, board)
            check.require(not intersects(left_expanded, right_expanded), f"{pair}: expanded hit rectangles overlap")
            left_label, right_label = label_rect(left, board), label_rect(right, board)
            check.require(not intersects(left_label, right_label), f"{pair}: labels overlap")
            check.require(not intersects(left_label, right_hit) and not intersects(left_hit, right_label), f"{pair}: label overlaps another hit target")
            check.require(
                not intersects(left_label, right_expanded) and not intersects(left_expanded, right_label),
                f"{pair}: label overlaps another expanded small-screen hit target",
            )

    for preference_field in ("object_slot_ids", "category_slot_ids", "scenario_slot_ids"):
        preferences = map_data.get(preference_field, {})
        check.require(isinstance(preferences, dict), f"{map_id}: {preference_field} must be an object")
        if isinstance(preferences, dict):
            expected_kinds = {"stage", "exit"} if preference_field == "scenario_slot_ids" else {"base"}
            for identity, slot_id in preferences.items():
                slot = slot_by_id.get(str(slot_id), {})
                check.require(bool(str(identity)) and bool(slot), f"{map_id}.{preference_field}: {identity} names unknown slot {slot_id}")
                check.require(not slot or slot.get("kind") in expected_kinds, f"{map_id}.{preference_field}: {identity} names an invalid slot kind")

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
            check.require(start_projection is not None and start_projection[2] <= EPSILON, f"{map_id}.{route_id}: start endpoint is not geometrically attached to its first lane")
            check.require(end_projection is not None and end_projection[2] <= EPSILON, f"{map_id}.{route_id}: end endpoint is not geometrically attached to its last lane")
            if len(valid_route_lanes) == 1 and start_projection is not None and end_projection is not None:
                sliced_distance = abs(end_projection[1] - start_projection[1])
                check.require(sliced_distance > EPSILON, f"{map_id}.{route_id}: endpoint projections do not define a traversable lane slice")
                if map_id == "back_alley" and route_id == "base::world:bar":
                    check.require(
                        math.dist(start_projection[0], (452.0, 358.0)) <= EPSILON
                        and math.dist(end_projection[0], (752.0, 358.0)) <= EPSILON
                        and abs(sliced_distance - 300.0) <= EPSILON,
                        "back_alley.base::world:bar must slice lane.public directly from x=452 to x=752 (300px) without backtracking",
                    )
        check.require(str(route.get("reduced_motion_slot_id", "")) in {start_id, end_id}, f"{map_id}.{route_id}: invalid reduced-motion endpoint")


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
        "pos": [274.0, 34.0],
        "footprint_class": "wall_mounted",
        "hit_rect": [242.0, 14.0, 64.0, 40.0],
        "label_anchor": [274.0, 18.0],
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
    exact_seed_manifest = json.loads((root / "tools/fixtures/rw06_1_environment_exact_seed_manifest.json").read_text(encoding="utf-8"))
    event_catalog = json.loads((root / "data/events/events.json").read_text(encoding="utf-8"))
    board_raw = point(placement.get("board_size"))
    check.require(placement.get("schema_version") == 2, "placement_surfaces.json schema_version must be 2")
    check.require(placement.get("slot_schema_version") == 1, "placement_surfaces.json slot_schema_version must be 1")
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
    for host, row in catalog_rows:
        scenario_id = str(row.get("id", ""))
        check.require(scenario_id in scenario_defs, f"{host}: missing sequence {scenario_id}")
        layer_id = str(row.get("layer_id", ""))
        map_id = f"{host}:{layer_id}" if layer_id and f"{host}:{layer_id}" in maps_by_id else host
        map_data = maps_by_id.get(map_id, {})
        check.require(bool(map_data), f"{scenario_id}: legal host map {map_id} is missing")
        visual_ids = scenario_visual_ids(scenario_defs.get(scenario_id, {}))
        scenario_visual_count += len(visual_ids)
        verbs = values(scenario_defs.get(scenario_id, {}).get("authoring", {}).get("player_verbs"))
        check.require(bool(verbs) and all(isinstance(verb, str) and verb for verb in verbs), f"{scenario_id}: authored actions are not statically enumerable")
        mutations = row.get("mutations", {}) if isinstance(row.get("mutations"), dict) else {}
        for field in ("next_archetypes_add", "rare_next_archetypes_add"):
            for destination in values(mutations.get(field)):
                check.require(str(destination) in archetypes, f"{scenario_id}: offered destination {destination} is not installable")

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
            scenario_id, phase_id = snapshot_tags(snapshot)
            complete_rows.append({
                "map_id": map_id,
                "scenario_id": scenario_id,
                "phase_id": phase_id,
                "binding_count": first[1] + first[2],
                "room_count": first[1],
                "overflow_count": first[2],
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
            active_rows.append({
                "map_id": map_id,
                "scenario_id": scenario_id,
                "phase_id": phase_id,
                "binding_count": room_count + overflow_count,
                "room_count": room_count,
                "overflow_count": overflow_count,
                "overflow_identities": sorted(identity for identity, binding in _bindings.items() if binding["mode"] == "overflow"),
            })
    active_overflow_rate = active_overflow_count / max(1, active_binding_count)
    # "Rare" is an explicit data budget: at least nine of every ten active-phase
    # visuals must fit authored room slots. Aftermath may use overflow more often
    # because it is persistent evidence, not a live task composition.
    check.require(active_overflow_rate <= 0.10, f"active-phase overflow is not rare: {active_overflow_count}/{active_binding_count} ({active_overflow_rate:.1%})")
    # The release-week authoring has enough generic capacity for every common
    # live phase. Keep that stronger result so a concentrated room regression
    # cannot hide behind the global ten-percent ceiling. The complete census
    # (including aftermath) still exercises overflow and action reachability.
    check.require(active_overflow_count == 0, f"common active phases must fit authored room slots; saw {active_overflow_count} overflow bindings")
    check.require(authored_action_count > 0, "scenario phase simulation enumerated no authored actions")

    manifest_rows = values(exact_seed_manifest.get("expectations"))
    check.require(exact_seed_manifest.get("schema_version") == 1, "exact-seed manifest schema_version must be 1")
    check.require(len(manifest_rows) == 22, f"historical UIENV exact-seed manifest must contain 22 rows, found {len(manifest_rows)}")
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

    binder_source = (root / "scripts/core/environment_slot_binder.gd").read_text(encoding="utf-8")
    instance_source = (root / "scripts/core/environment_instance.gd").read_text(encoding="utf-8")
    resolver_source = (root / "scripts/core/scenario_layout_resolver.gd").read_text(encoding="utf-8")
    placement_source = (root / "scripts/core/environment_placement.gd").read_text(encoding="utf-8")
    canvas_source = (root / "scripts/ui/pixel_scene_canvas.gd").read_text(encoding="utf-8")
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
    for item in contact_sheet:
        check.require(int(item.get("overflow_count", -1)) == 0, f"contact-sheet peak {item.get('archetype_id', '')} overflows")
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
            "complete_snapshots": complete_snapshot_count,
            "complete_bindings": complete_binding_count,
            "complete_overflow": complete_overflow_count,
            "authored_actions": authored_action_count,
            "historical_exact_seeds": len(manifest_rows),
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
        f"historical_exact_seeds={len(manifest_rows)} report={report_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
