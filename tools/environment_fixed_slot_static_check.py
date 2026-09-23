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
import rw06_1_apply_hand_authored_slots as HandAuthoredSlots


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
MIN_INTERACTIVE_TARGET = (44.0, 44.0)


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
    if placement_class in {"behind_counter_person", "surface_item"}:
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
    if placement_class in {"behind_counter_person", "surface_item"}:
        for counter in values(map_data.get("counters")):
            if not isinstance(counter, dict) or str(counter.get("id", "")) != support_id:
                continue
            allowed = [str(item) for item in values(counter.get("classes"))]
            return (not allowed or placement_class in allowed) \
                and float(counter.get("x0", 0.0)) - EPSILON <= bounds[0] \
                and bounds[0] + bounds[2] <= float(counter.get("x1", 0.0)) + EPSILON \
                and abs(position[1] - float(counter.get("top_y", 0.0))) <= EPSILON
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
    position_routes = map_data.get("scenario_position_route_ids", {}) if isinstance(map_data.get("scenario_position_route_ids"), dict) else {}
    entries: list[tuple[int, str, str, bool, str, bool, str]] = []
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
        placement_class = SlotAuthoring.classify_with_override(
            semantic,
            "actor" if actor else "scene_object",
            identity,
            str(class_overrides.get(identity, class_overrides.get(stable_id, ""))),
        )
        position_key = SlotAuthoring.scenario_position_key(stable_id, semantic)
        route_id = str(semantic.get("route_id", "")) or str(position_routes.get(position_key, ""))
        safe_exit = bool(semantic.get("safe_exit", False))
        # Production promotes every required exit to the doorway footprint class
        # before binding, regardless of the semantic object's visual category.
        if safe_exit:
            placement_class = "doorway"
        rank = 0 if safe_exit else 1 if route_id else 2
        entries.append((rank, identity, placement_class, safe_exit, route_id, bool(semantic.get("_slot_hidden", False)), position_key))
    entries.sort(key=lambda entry: (entry[0], entry[1]))
    occupied: set[str] = set()
    bindings: dict[str, dict[str, str]] = {}
    hidden_identities: set[str] = set()
    for _rank, identity, placement_class, safe_exit, route_id, hidden, position_key in entries:
        if hidden:
            hidden_identities.add(identity)
        selected: dict[str, Any] | None = None
        route = routes.get(route_id, {}) if route_id else {}
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
            bindings[identity] = {"mode": "overflow", "slot_id": "", "placement_class": placement_class}
        else:
            bindings[identity] = {
                "mode": "room",
                "slot_id": str(selected.get("id", "")),
                "placement_class": placement_class,
                "route_id": route_id,
                "end_slot_id": str(route.get("end_slot_id", "")) if route_id else "",
            }
        if safe_exit:
            check.require(bindings[identity]["mode"] == "room", f"{map_id}.{identity}: required safe exit overflowed")
        if route_id:
            check.require(bool(route), f"{map_id}.{identity}: route {route_id} has no authored slot/lane record")
            check.require(bindings[identity]["mode"] == "room", f"{map_id}.{identity}: routed actor failed closed into overflow")
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
    # Independently replay exact label authority for this reachable composition.
    # A label may touch its own object, but never another active normal/expanded
    # target or another active label. Persistent base slots are unrelated hits.
    semantic_by_identity = {
        str(semantic.get("identity", "")): semantic
        for semantic in snapshot
        if isinstance(semantic, dict)
    }
    room_authority: list[tuple[str, tuple[float, float, float, float], tuple[float, float, float, float], tuple[float, float, float, float]]] = []
    for identity, binding in bindings.items():
        if binding["mode"] != "room":
            continue
        slot = slot_by_id.get(binding["slot_id"], {})
        hit = rect(slot.get("hit_rect"))
        semantic = semantic_by_identity.get(identity, {})
        label = SlotAuthoring.placement_label(semantic)
        if hit is None or not label.strip():
            continue
        room_authority.append((identity, hit, expanded(hit, (900.0, 430.0)), label_rect(slot, label, (900.0, 430.0))))
    base_hits = [
        (str(slot.get("id", "")), parsed)
        for slot in values(map_data.get("base_slots"))
        if isinstance(slot, dict) and (parsed := rect(slot.get("hit_rect"))) is not None
    ]
    for index, (identity, _hit, _small_hit, label_bounds) in enumerate(room_authority):
        for other_identity, other_hit, other_small_hit, other_label in room_authority[index + 1:]:
            check.require(not intersects(label_bounds, other_label), f"{map_id}.{identity}/{other_identity}: active label rectangles overlap")
            check.require(not intersects(label_bounds, other_hit), f"{map_id}.{identity}: label overlaps unrelated normal target {other_identity}")
            check.require(not intersects(label_bounds, other_small_hit), f"{map_id}.{identity}: label overlaps unrelated expanded target {other_identity}")
            check.require(not intersects(other_label, _hit), f"{map_id}.{other_identity}: label overlaps unrelated normal target {identity}")
            check.require(not intersects(other_label, _small_hit), f"{map_id}.{other_identity}: label overlaps unrelated expanded target {identity}")
        for base_slot_id, base_hit in base_hits:
            check.require(not intersects(label_bounds, base_hit), f"{map_id}.{identity}: label overlaps persistent base target {base_slot_id}")
            check.require(not intersects(label_bounds, expanded(base_hit, (900.0, 430.0))), f"{map_id}.{identity}: label overlaps persistent expanded base target {base_slot_id}")
    check.require(len(bindings) == len(entries), f"{map_id}: scenario binding silently omitted a visual")
    return bindings, room_count, overflow_count, action_count


def conservative_base_label_scenario_census(
    check: Check,
    maps_by_id: dict[str, dict[str, Any]],
    replay_rows: list[tuple[str, list[dict[str, Any]], dict[str, dict[str, str]]]],
    expected_scenario_ids: set[str],
    board: tuple[float, float],
) -> dict[str, Any]:
    """Prove the fixed base/stage planes are disjoint for every legal phase.

    Base inventory occupants vary by seed and by randomized category.  The
    production renderer bounds every non-empty room label to 126x26, so this
    conservative draft treats every authored base slot as if it carried that
    maximum rectangle.  That deliberately over-approximates base occupancy and
    includes mutually exclusive/fallback-capacity slots; it is a stronger
    authoring envelope, not a claim that every base combination is reachable.
    Scenario authority remains exact: only catalog-authorized, reachable phase
    snapshots and their actual deterministic bindings are compared.
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
            if binding.get("mode") != "room":
                continue
            scenario_slot_id = str(binding.get("slot_id", ""))
            scenario_slot = slots_by_id.get(scenario_slot_id, {})
            scenario_hit = rect(scenario_slot.get("hit_rect"))
            check.require(scenario_hit is not None, f"{map_id}.{identity}: bound scenario slot {scenario_slot_id} has no target")
            if scenario_hit is None:
                continue
            scenario_label = SlotAuthoring.placement_label(semantic_by_identity.get(identity, {}))
            scenario_label_bounds = label_rect(scenario_slot, scenario_label, board) if scenario_label.strip() else None
            scenario_authority.append((
                identity,
                scenario_slot_id,
                scenario_hit,
                expanded(scenario_hit, board),
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
    for map_id, left_id, right_id, kind in base_base_conflicts:
        check.errors.append(
            f"{map_id}: conservative maximum base labels {left_id}/{right_id} conflict: {kind}"
        )
    for (map_id, base_slot_id, scenario_slot_id, kind), states in sorted(conflicts.items()):
        examples = sorted(states)
        suffix = f"; examples={examples[:4]}" if examples else ""
        if len(examples) > 4:
            suffix += f" (+{len(examples) - 4} more legal states)"
        check.errors.append(
            f"{map_id}: conservative maximum label at {base_slot_id} conflicts with {scenario_slot_id}: {kind}{suffix}"
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
            if hit is not None and position is not None and placement_class in CLASSES:
                check.require(slot_has_physical_support(map_data, slot), f"{map_id}.{slot_id}: geometry/contact is not physically supported by {support_id}")

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
            # Slot inventory is a union across mutually exclusive base rolls and
            # scenario phases. Label rectangles depend on the concrete text and
            # are checked against each reachable composition below.

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
        and all(store_base_slots.get(slot_id, {}).get("footprint_class") == "surface_item" for slot_id in store_item_slot_ids),
        "corner_store: five item categories must use five distinct named shop-item slots",
    )
    check.require(
        all(str(store_base_slots.get(slot_id, {}).get("support_id", "")).startswith("shelf_row_") for slot_id in store_item_slot_ids[:4]),
        "corner_store: the four visible shelf offers must stay aligned to the left shelf rows",
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
    check.require(
        grand_machine_ids == [f"base.game_machine_{index}" for index in range(1, 6)]
        and len(set(grand_machine_ids)) == 5
        and all(slot.get("footprint_class") == "wall_mounted" and slot.get("support_id") == "wall" for slot in grand_machine_slots)
        and all(position is not None and position[1] == 80.0 for position in grand_machine_positions)
        and all(
            grand_machine_positions[index] is not None
            and grand_machine_positions[index + 1] is not None
            and grand_machine_positions[index + 1][0] - grand_machine_positions[index][0] >= 104.0
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
        and all(cage_slots.get(slot_id, {}).get("footprint_class") == "surface_item" for slot_id in cage_item_ids),
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
        and all(pawn_slots.get(slot_id, {}).get("footprint_class") == "surface_item" for slot_id in shelf_slot_ids),
        "pawn_shop: Sal's six generated shelf offers must prefer six distinct fixed surface-item slots",
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

    # The conservative maximum-label proof leaves one authenticated doorway in
    # the Gas Station base plane. All generated travel choices remain distinct
    # semantic records; deterministic binding places the first compatible
    # record in-room and sends the rest to the geometry-free action list.
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
    gas_doorway_occupants = {
        "event:scenario_graveyard_maintenance",
        "event:side_door",
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
        and len(gas_base_slots) == 7
        and gas_base_slots.get("base.door_left_middle", {}).get("footprint_class") == "doorway"
        and not any(str(slot_id) == "base.door_right_middle" for slot_id in gas_preferences.values())
        and not any(str(slot_id) == "base.door_right_middle" for slot_id in gas_categories.values()),
        "gas_station_casino: removed right base doorway must stay absent and unreferenced",
    )
    check.require(
        all(str(gas_preferences.get(identity, "")) == "base.door_left_middle" for identity in gas_doorway_occupants)
        and all(str(gas_categories.get(key, "")) == "base.door_left_middle" for key in gas_travel_indexes),
        "gas_station_casino: every base-doorway identity and travel index must use the retained left doorway",
    )
    check.require(
        gas_stage_slots.get("stage.event_right_door", {}).get("footprint_class") == "doorway"
        and set(gas_exit_slots) == {"exit.left_upper", "exit.right_lower"},
        "gas_station_casino: scenario right-door and both independent safe-exit authorities must survive the base simplification",
    )

    # Delta Queen's second base wall slot has no locally-associated 126x26
    # label domain beside wall_1 and event_table_1. Keep the complete displaced
    # occupant set closed here so a future catalog addition cannot silently
    # depend on the removed geometry.
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
        "item:payment_calendar",
    }
    check.require(
        "base.event_wall_2" not in delta_base_slots
        and delta_base_slots.get("base.event_wall_1", {}).get("footprint_class") == "wall_mounted"
        and delta_base_slots.get("base.event_table_1", {}).get("footprint_class") == "surface_item"
        and not any(str(slot_id) == "base.event_wall_2" for slot_id in delta_preferences.values())
        and not any(str(slot_id) == "base.event_wall_2" for slot_id in delta_categories.values()),
        "delta_queen: removed second wall slot must stay absent and unreferenced",
    )
    check.require(
        all(str(delta_preferences.get(identity, "")) == "base.event_wall_1" for identity in delta_wall_occupants)
        and str(delta_preferences.get("event:scenario_captains_invitational_card", "")) == "base.event_table_1"
        and str(delta_categories.get("item_spots:2", "")) == "base.event_table_1",
        "delta_queen: wall occupants and event_table_1 identity/index remaps must remain exact",
    )
    check.require(
        set(delta_exit_slots) == {"exit.left_lower", "exit.right_upper"},
        "delta_queen: both independent safe exits must survive the wall-capacity simplification",
    )

    # Jazz keeps its guaranteed counter staff and one authored travel doorway.
    # Every generated travel index shares that doorway and excess records keep
    # their independent action authority in overflow.
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
        and len(jazz_base_slots) == 9
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
            check.require(scenario_binding.get("mode") == "room", f"{seed}: legal-room scenario identity {scenario_identity} did not receive a room slot")
            scenario_slot_id = str(scenario_binding.get("slot_id", ""))
            scenario_slot = slots_by_id.get(scenario_slot_id, {})
            scenario_hit = rect(scenario_slot.get("hit_rect"))
            semantic = next((item for item in snapshot if str(item.get("identity", "")) == scenario_identity), {})
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
        f"base_base_conflicts={base_scenario_census.get('base_base_conflicts', 0)} report={report_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
