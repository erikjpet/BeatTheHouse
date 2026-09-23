#!/usr/bin/env python3
"""One-time deterministic authoring migration for rw06_1 fixed room slots.

The generated JSON is shipping source data.  This tool is never called by the
game: production consumes only the authored slot records and id preferences.
Legacy coordinates remain in the file for the developer placement preview,
but they are not runtime placement authority after rw06_1.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
from typing import Any, Iterable


BOARD_W = 900.0
BOARD_H = 430.0
CLASSES = (
    "standing_person",
    "behind_counter_person",
    "seated_person",
    "group",
    "floor_fixture",
    "ground_marker",
    "surface_item",
    "wall_mounted",
    "hanging",
    "doorway",
)
PERSON_CLASSES = {"standing_person", "behind_counter_person", "seated_person", "group"}
GROUNDED_CLASSES = {"standing_person", "group", "floor_fixture", "ground_marker"}
SLOT_SIZE = {
    "standing_person": (72.0, 80.0),
    "behind_counter_person": (72.0, 72.0),
    "seated_person": (68.0, 64.0),
    "group": (104.0, 78.0),
    "floor_fixture": (92.0, 64.0),
    "ground_marker": (72.0, 48.0),
    "surface_item": (72.0, 48.0),
    "wall_mounted": (80.0, 48.0),
    "hanging": (72.0, 32.0),
    "doorway": (64.0, 72.0),
}
BASE_CAP = {
    "standing_person": 1,
    "behind_counter_person": 1,
    "seated_person": 1,
    "group": 1,
    "floor_fixture": 3,
    "ground_marker": 1,
    "surface_item": 3,
    "wall_mounted": 2,
    "hanging": 1,
    "doorway": 2,
}
STAGE_CAP = {
    "standing_person": 4,
    "behind_counter_person": 2,
    "seated_person": 2,
    "group": 1,
    "floor_fixture": 3,
    "ground_marker": 2,
    "surface_item": 3,
    "wall_mounted": 2,
    "hanging": 1,
    "doorway": 0,
}
LABEL_W = 88.0
LABEL_H = 15.0
WALK_LANE_RECT = (16.0, 378.0, 868.0, 36.0)
EXIT_COLOR_OFFSET = 1000

COUNTER_PERSON_TOKENS = ("bartender", "cashier", "clerk", "dealer", "shopkeeper", "staff", "teller", "vendor")
PERSON_TOKENS = ("actor", "bouncer", "captain", "crew", "driver", "guard", "host", "landlord", "mate", "observer", "patron", "person", "regular", "runner", "staff")
SEATED_TOKENS = ("audience", "booth", "chair", "seated", "stool")
GROUP_TOKENS = ("crowd", "drivers", "group", "sheltering", "the crew")
WALL_TOKENS = ("board", "bracket", "calendar", "camera", "clock", "easel", "gauge", "lamp", "menu", "notice", "panel", "poster", "scoreboard", "screen", "seal", "sign", "signal")
HANGING_TOKENS = ("banner", "hanging", "speaker rig", "string light")
DOOR_TOKENS = ("door", "exit", "gangway", "leave")
GROUND_TOKENS = ("chalk", "lane", "mark", "spill", "tape")
SURFACE_TOKENS = ("basket", "card", "case", "desk", "drink", "glass", "item", "ledger", "manifest", "note", "provenance", "table", "ticket", "tray", "watch")
PERSON_EVENT_PROPS = ("bar_patron", "casino_host", "clerk_counter", "clerk_talk", "host_station", "patron", "pit_boss", "rowdy_patron", "staff")
WALL_EVENT_PROPS = ("security_camera",)
DOOR_EVENT_PROPS = ("motel_door", "side_door")
SURFACE_EVENT_PROPS = ("card_table", "paper_note", "room_refreshment", "table")
GROUND_EVENT_PROPS = ("room_barrier", "room_fixture", "room_hazard", "room_route", "room_seating", "room_storage", "room_trace", "room_vehicle", "street_sign")
WALL_PRESENTATION_PROPS = ("room_display", "room_signal")

CATEGORY_CLASS = {
    "game_spots": "floor_fixture",
    "event_spots": "floor_fixture",
    "item_spots": "surface_item",
    "shopkeeper_spots": "behind_counter_person",
    "game_hook_spots": "surface_item",
    "travel_spots": "doorway",
    "casino_door_spots": "doorway",
    "casino_fixture_spots": "floor_fixture",
    "service_spots": "surface_item",
    "lender_spots": "standing_person",
    "layer_spots": "doorway",
    "numbers_spots": "surface_item",
    "numbers_silas_spots": "standing_person",
    "home_tenure_spots": "wall_mounted",
    "home_sleep_spots": "floor_fixture",
    "home_storage_spots": "floor_fixture",
    "home_container_spots": "surface_item",
    "home_bag_spots": "surface_item",
    "home_upgrade_spots": "wall_mounted",
    "home_trade_up_spots": "surface_item",
    "pawn_counter_spots": "behind_counter_person",
}

# These scenario visuals have intentionally non-default physical semantics.
# Their authored class travels in placement_surfaces.json and is consumed by
# the same production override path as every other fixed-slot classification.
SCENARIO_CLASS_OVERRIDES = {
    "back_alley": {
        "cruiser_beam": "ground_marker",
        "three_traces": "ground_marker",
        "goods_lot": "surface_item",
    },
}


def values(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def rect(value: Any) -> tuple[float, float, float, float]:
    if not isinstance(value, list) or len(value) < 4:
        return (0.0, 0.0, 0.0, 0.0)
    return tuple(float(value[i]) for i in range(4))  # type: ignore[return-value]


def point(value: Any) -> tuple[float, float] | None:
    if isinstance(value, list) and len(value) >= 2:
        return (float(value[0]), float(value[1]))
    if isinstance(value, dict) and "x" in value and "y" in value:
        return (float(value["x"]), float(value["y"]))
    return None


def _polyline_projection_with_distance(
    points: list[tuple[float, float]],
    target: tuple[float, float],
) -> tuple[tuple[float, float], float] | None:
    best: tuple[tuple[float, float], float] | None = None
    best_distance_squared = float("inf")
    traversed = 0.0
    for start, end in zip(points, points[1:]):
        dx, dy = end[0] - start[0], end[1] - start[1]
        length_squared = dx * dx + dy * dy
        if length_squared <= 0.000001:
            continue
        length = math.sqrt(length_squared)
        weight = max(
            0.0,
            min(1.0, ((target[0] - start[0]) * dx + (target[1] - start[1]) * dy) / length_squared),
        )
        projected = (start[0] + dx * weight, start[1] + dy * weight)
        distance_squared = (
            (target[0] - projected[0]) ** 2
            + (target[1] - projected[1]) ** 2
        )
        distance_along = traversed + length * weight
        if (
            distance_squared < best_distance_squared - 0.000001
            or abs(distance_squared - best_distance_squared) <= 0.000001
            and (best is None or distance_along < best[1])
        ):
            best_distance_squared = distance_squared
            best = (projected, distance_along)
        traversed += length
    return best


def _polyline_slice_points(
    points: list[tuple[float, float]],
    start_point: tuple[float, float],
    start_distance: float,
    end_point: tuple[float, float],
    end_distance: float,
) -> list[tuple[float, float]]:
    vertex_distances = [0.0]
    for start, end in zip(points, points[1:]):
        vertex_distances.append(vertex_distances[-1] + math.dist(start, end))
    result = [start_point]
    indexes = (
        range(1, len(points) - 1)
        if start_distance <= end_distance
        else range(len(points) - 2, 0, -1)
    )
    for index in indexes:
        distance = vertex_distances[index]
        inside = (
            distance > start_distance + 0.001 and distance < end_distance - 0.001
            if start_distance <= end_distance
            else distance < start_distance - 0.001 and distance > end_distance + 0.001
        )
        if inside and result[-1] != points[index]:
            result.append(points[index])
    if result[-1] != end_point:
        result.append(end_point)
    return result


def intersects(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> bool:
    return a[0] < b[0] + b[2] and a[0] + a[2] > b[0] and a[1] < b[1] + b[3] and a[1] + a[3] > b[1]


def encloses(outer: tuple[float, float, float, float], inner: tuple[float, float, float, float]) -> bool:
    return inner[0] >= outer[0] - 0.01 and inner[1] >= outer[1] - 0.01 and inner[0] + inner[2] <= outer[0] + outer[2] + 0.01 and inner[1] + inner[3] <= outer[1] + outer[3] + 0.01


def rect_at_contact(contact: tuple[float, float], size: tuple[float, float], placement_class: str) -> tuple[float, float, float, float]:
    if placement_class in {"wall_mounted", "hanging", "doorway"}:
        return (contact[0] - size[0] / 2.0, contact[1] - size[1] / 2.0, size[0], size[1])
    return (contact[0] - size[0] / 2.0, contact[1] - size[1], size[0], size[1])


def contact_for_rect(bounds: tuple[float, float, float, float], placement_class: str) -> tuple[float, float]:
    if placement_class in {"wall_mounted", "hanging", "doorway"}:
        return (bounds[0] + bounds[2] / 2.0, bounds[1] + bounds[3] / 2.0)
    return (bounds[0] + bounds[2] / 2.0, bounds[1] + bounds[3])


def expanded(bounds: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    width = max(44.0, bounds[2])
    height = max(44.0, bounds[3])
    center = (bounds[0] + bounds[2] / 2.0, bounds[1] + bounds[3] / 2.0)
    x = min(max(0.0, center[0] - width / 2.0), BOARD_W - width)
    y = min(max(0.0, center[1] - height / 2.0), BOARD_H - height)
    return (x, y, width, height)


def reservation(bounds: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    # Slot inventory is a union across mutually exclusive scenarios and random
    # base selections. Reserve physical click geometry here; exact authored label
    # rectangles are validated against every reachable composition downstream.
    return expanded(bounds)


def authored_label_rect(
    bounds: tuple[float, float, float, float],
    contact: tuple[float, float],
    label: str | None,
) -> tuple[float, float, float, float]:
    """Mirror EnvironmentSlotBinder.label_rect_from_slot exactly.

    ``None`` is a deliberate conservative authority for dynamic base records:
    those labels come from runtime catalogs, so the slot must remain valid for
    the renderer's largest bounded label rather than one migration-time sample.
    """
    if label is not None and not label.strip():
        return (0.0, 0.0, 0.0, 0.0)
    raw_width = 127.0 if label is None else len(label.strip()) * 5.8 + 12.0
    width = min(max(48.0, raw_width), 126.0)
    height = 26.0 if raw_width > 126.0 else 15.0
    anchor_y = max(8.0, bounds[1] - 6.0)
    return (
        min(max(0.0, contact[0] - width / 2.0), BOARD_W - width),
        min(max(0.0, anchor_y - height), BOARD_H - height),
        width,
        height,
    )


def candidate_authority(
    candidate: dict[str, Any],
    label: str | None,
) -> tuple[tuple[float, float, float, float], ...]:
    hit = reservation(candidate["rect"])
    label_bounds = authored_label_rect(candidate["rect"], candidate["contact"], label)
    return (hit,) if label_bounds[2] <= 0.0 or label_bounds[3] <= 0.0 else (hit, label_bounds)


def authority_intersects(
    left: Iterable[tuple[float, float, float, float]],
    right: Iterable[tuple[float, float, float, float]],
) -> bool:
    return any(intersects(left_rect, right_rect) for left_rect in left for right_rect in right)


def placement_label(semantic: dict[str, Any]) -> str:
    visual = str(semantic.get("label", "")).strip()
    interaction = semantic.get("_slot_interaction", {})
    interaction_label = (
        str(interaction.get("label", "")).strip()
        if isinstance(interaction, dict)
        else ""
    )
    return interaction_label if len(interaction_label) > len(visual) else visual


def base_record_label(identity: str, semantic: dict[str, Any]) -> str:
    for field in ("display_name", "label", "public_label", "name"):
        value = str(semantic.get(field, "")).strip()
        if value:
            return value
    stable_id = identity.split(":", 1)[-1].split(":", 1)[0]
    return stable_id.replace("_", " ").strip().title()


def tokens(text: str, wanted: Iterable[str]) -> bool:
    clean = " " + text.lower() + " "
    for separator in "_:-/.,;()[]":
        clean = clean.replace(separator, " ")
    clean = " ".join(clean.split())
    return any(f" {token.replace('_', ' ').lower().strip()} " in f" {clean} " for token in wanted)


def classify(data: dict[str, Any], object_type: str, object_id: str, visual_prop: str = "") -> str:
    """Mirror EnvironmentPlacement.classify, including visual-prop precedence."""
    explicit = str(data.get("placement_class", "")).strip()
    if explicit in CLASSES:
        return explicit
    clean_type = object_type.strip().lower()
    clean_prop = visual_prop.strip().lower()
    if not clean_prop:
        clean_prop = str(data.get("visual_prop", data.get("environment_prop", ""))).strip().lower()
    role = str(data.get("role", "")).strip().lower()
    person_text = " ".join(str(data.get(key, "")) for key in ("actor_id", "character_id", "npc_id", "speaker_id", "role", "pose", "appearance")) + " " + object_id + " " + clean_prop
    person_object = clean_type in {"actor", "character", "lender", "merchant", "npc", "scenario_actor", "shopkeeper", "numbers_silas"} or role in {"bartender", "casino_host", "clerk", "dealer", "guard", "host", "lender", "merchant", "musician", "patron", "person", "pit_boss", "shopkeeper", "staff", "teller", "vendor"} or clean_prop in PERSON_EVENT_PROPS or any(str(data.get(key, "")).strip() for key in ("actor_id", "character_id", "npc_id", "speaker_id")) or object_id.lower() == "numbers:silas"
    if person_object:
        if role in {"bartender", "clerk", "dealer", "merchant", "shopkeeper", "teller", "vendor"} or tokens(person_text, COUNTER_PERSON_TOKENS):
            return "behind_counter_person"
        if tokens(person_text, SEATED_TOKENS):
            return "seated_person"
        if tokens(person_text, GROUP_TOKENS):
            return "group"
        return "standing_person"
    text = " ".join((object_id, clean_type, clean_prop, str(data.get("label", "")), role, str(data.get("icon_key", data.get("appearance", "")))))
    if object_id.lower().endswith("_safe_exit"):
        return "doorway"
    if role == "exit" and tokens(text, ("marked lane", "clear exit", "public aisle")):
        return "ground_marker"
    if role in {"exit", "doorway"}:
        return "doorway"
    if role == "task_zone":
        return "ground_marker"
    if role == "decision_route":
        return "surface_item"
    if role in {"task_station", "display", "notice", "sign", "wall"} or clean_prop in WALL_PRESENTATION_PROPS:
        return "wall_mounted"
    if role in {"route_marker", "ground_marker"} or clean_prop == "room_route" and role != "task_station":
        return "ground_marker"
    if role == "barrier" and "bulkhead" in text.lower():
        return "wall_mounted"
    if object_id == "event:parking_lot_tip":
        return "ground_marker"
    if role in {"vehicle", "obstacle", "barrier", "blockade", "utility", "furniture", "game_station"} or role == "door" and tokens(text, ("gate",)):
        return "floor_fixture"
    if clean_prop in {"card_table", "table"}:
        return "floor_fixture"
    if clean_type in {"travel", "layer", "casino_door"} or clean_prop in DOOR_EVENT_PROPS or tokens(text, DOOR_TOKENS):
        return "doorway"
    if tokens(text, HANGING_TOKENS):
        return "hanging"
    if tokens(text, GROUND_TOKENS):
        return "ground_marker"
    if clean_prop in WALL_EVENT_PROPS or clean_prop in WALL_PRESENTATION_PROPS or tokens(text, WALL_TOKENS):
        return "wall_mounted"
    if clean_type == "event" and tokens(text, ("discount sticker",)):
        return "wall_mounted"
    if clean_prop in SURFACE_EVENT_PROPS or tokens(text, SURFACE_TOKENS):
        return "surface_item"
    if role == "arrangement" and "floor_prop" in object_id.lower():
        return "ground_marker"
    if role in {"arrangement", "evidence", "refreshment"} or clean_prop in {"room_refreshment", "paper_note"}:
        return "surface_item"
    if clean_prop in GROUND_EVENT_PROPS:
        return "floor_fixture"
    if clean_prop in PERSON_EVENT_PROPS or clean_type == "event" and tokens(text, COUNTER_PERSON_TOKENS + PERSON_TOKENS):
        if clean_prop in {"clerk_talk", "staff"}:
            return "standing_person"
        if tokens(person_text, COUNTER_PERSON_TOKENS) or clean_prop in {"clerk_counter", "host_station"}:
            return "behind_counter_person"
        if tokens(person_text, SEATED_TOKENS):
            return "seated_person"
        if tokens(person_text, GROUP_TOKENS):
            return "group"
        return "standing_person"
    if clean_type in {"lender", "numbers_silas"}:
        if "pawn_counter" in object_id.lower():
            return "behind_counter_person"
        return "standing_person"
    if clean_type == "shopkeeper":
        return "behind_counter_person"
    if clean_type in {"game", "game_hook"}:
        return "floor_fixture" if tokens(text, ("coin pusher", "pull tab", "pull tabs", "scratch ticket", "scratch tickets", "slot", "video poker")) else "surface_item"
    if clean_type == "service" and tokens(text, ("deck walk", "relax", "ride", "sand pile", "shuttle", "walk", "burlesque show", "floor show", "stage show")):
        return "floor_fixture"
    if clean_type in {"item", "drink", "numbers", "service"}:
        return "surface_item"
    return "floor_fixture"


def classify_with_override(
    data: dict[str, Any],
    object_type: str,
    object_id: str,
    override: str = "",
) -> str:
    classified = copy.deepcopy(data)
    if override in CLASSES:
        classified["placement_class"] = override
    return classify(
        classified,
        object_type,
        object_id,
        str(data.get("prop", data.get("icon_key", ""))),
    )


def collect_semantics(root: Path) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}

    def visit(value: Any) -> None:
        if isinstance(value, dict):
            stable_id = value.get("stable_object_id")
            if isinstance(stable_id, str) and stable_id:
                target = result.setdefault(stable_id, {})
                for key, item in value.items():
                    if key not in {"operations", "scene_ops", "interaction_ops", "actor_ops"} and not isinstance(item, (list, dict)):
                        target[key] = item
                for payload_field in ("data", "actor", "object", "interaction"):
                    payload = value.get(payload_field)
                    if isinstance(payload, dict):
                        target.update({key: item for key, item in payload.items() if not isinstance(item, (list, dict))})
                if str(value.get("family", "")) == "actor_ops" or isinstance(value.get("actor"), dict):
                    target["_slot_actor"] = True
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    for source in sorted((root / "data/environments/scenario_sequences").glob("*.json")):
        visit(json.loads(source.read_text(encoding="utf-8")))
    return result


def collect_base_semantics(root: Path) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    catalogs = (
        ("event", root / "data/events/events.json"),
        ("game", root / "data/games/games.json"),
        ("item", root / "data/items/items.json"),
        ("service", root / "data/services/services.json"),
    )
    for prefix, source in catalogs:
        for record in values(json.loads(source.read_text(encoding="utf-8"))):
            if isinstance(record, dict) and str(record.get("id", "")):
                result[f"{prefix}:{record['id']}"] = copy.deepcopy(record)
    return result


def _phase_operations(container: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for field in ("scene_ops", "interaction_ops", "actor_ops", "transition_ops", "service_ops", "game_ops", "route_ops"):
        result.extend(item for item in values(container.get(field)) if isinstance(item, dict))
    result.extend(item for item in values(container.get("operations")) if isinstance(item, dict))
    return result


def _apply_phase_operations(
    state: dict[str, dict[str, dict[str, Any]]],
    container: dict[str, Any],
) -> None:
    for operation in _phase_operations(container):
        family = str(operation.get("family", ""))
        verb = str(operation.get("op", ""))
        if family == "transition_ops":
            continue
        owner = str(operation.get("owner_namespace", "scenario"))
        stable_id = str(operation.get("stable_object_id", ""))
        identity = f"{owner}::{stable_id}"
        if not stable_id or family not in state:
            continue
        collection = state[family]
        payload_field = "actor" if family == "actor_ops" else "interaction" if family == "interaction_ops" else "object"
        payload = copy.deepcopy(operation.get(payload_field, {})) if isinstance(operation.get(payload_field), dict) else {}
        if family == "interaction_ops" and verb not in {"add", "remove"}:
            overlay = payload
            overlay.update({"owner_namespace": owner, "stable_object_id": stable_id})
            for field in ("mode", "target_owner_namespace", "target_stable_object_id", "enabled", "disabled_reason", "source_id", "available_actions", "input_actions"):
                if field in operation:
                    overlay[field] = copy.deepcopy(operation[field])
            if verb == "gate" and not bool(overlay.get("enabled", False)):
                overlay["available_actions"] = []
                overlay["input_actions"] = []
            collection[identity] = overlay
            continue
        if verb in {"remove", "despawn"}:
            collection.pop(identity, None)
            continue
        if verb in {"spawn", "add", "replace"}:
            payload.update({"owner_namespace": owner, "stable_object_id": stable_id})
            if family == "actor_ops":
                payload["_slot_actor"] = True
            collection[identity] = payload
            continue
        current = collection.setdefault(identity, {"owner_namespace": owner, "stable_object_id": stable_id})
        if family == "actor_ops":
            current["_slot_actor"] = True
        if verb in {"move", "set_position"}:
            before = {
                "anchor_id": str(current.get("anchor_id", "")),
                "zone_id": str(current.get("zone_id", "")),
                "authored_position_route_id": str(current.get("authored_position_route_id", "")),
            }
            current["anchor_id"] = str(operation.get("anchor_id", current.get("anchor_id", "")))
            current["zone_id"] = str(operation.get("zone_id", current.get("zone_id", "")))
            if family == "actor_ops" and verb == "set_position":
                current["authored_position_route_id"] = str(operation.get("receipt_id", ""))
            after = {
                "anchor_id": str(current.get("anchor_id", "")),
                "zone_id": str(current.get("zone_id", "")),
                "authored_position_route_id": str(current.get("authored_position_route_id", "")),
            }
            if family == "actor_ops" and before != after:
                current["_slot_route_from"] = before
        elif verb == "reveal":
            current["visible"] = True
        elif verb == "hide":
            current["visible"] = False
        elif verb == "enable":
            current["enabled"] = True
            current["disabled_reason"] = ""
        elif verb == "disable":
            current["enabled"] = False
            current["disabled_reason"] = str(operation.get("disabled_reason", "Unavailable."))
        elif verb == "set_state":
            current["state"] = str(operation.get("state", ""))
        elif verb == "set_appearance":
            current["appearance"] = str(operation.get("appearance", ""))
        elif verb == "set_route":
            current["route_id"] = str(operation.get("route_id", ""))
        elif verb == "set_pose":
            current["pose"] = str(operation.get("pose", ""))
        elif verb == "set_behavior":
            current["behavior"] = str(operation.get("behavior", "idle"))
        elif verb == "gate":
            current["enabled"] = bool(operation.get("enabled", False))
            current["disabled_reason"] = "" if current["enabled"] else str(operation.get("disabled_reason", "Unavailable."))
            if family == "interaction_ops" and not current["enabled"]:
                current["available_actions"] = []
                current["input_actions"] = []
        elif verb == "retarget":
            current["source_id"] = str(operation.get("source_id", current.get("source_id", "")))
        elif verb == "set_modifier":
            current["modifier"] = copy.deepcopy(operation.get("modifier", {}))
        elif verb == "open":
            current["enabled"] = True
            current["disabled_reason"] = ""
        elif verb == "close":
            current["enabled"] = False
            current["disabled_reason"] = str(operation.get("disabled_reason", "Route closed."))


def _effective_interactions(
    raw_interactions: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    """Apply authored overlays to the exact interaction identity they target.

    Runtime preserves overlay identities for ownership/cleanup, then projects
    their gate, retarget, replace, or augment semantics onto the target. Slot
    authoring needs that effective state: the four delivery-day gates, for
    example, control the event interaction rather than inventing four spatial
    overlay controls.
    """
    effective: dict[str, dict[str, Any]] = {}
    overlays: list[dict[str, Any]] = []
    for identity, interaction in sorted(raw_interactions.items()):
        mode = str(interaction.get("mode", "add"))
        target_owner = str(interaction.get("target_owner_namespace", ""))
        target_stable = str(interaction.get("target_stable_object_id", ""))
        if mode in {"gate", "retarget", "replace", "augment"} and target_owner and target_stable:
            overlays.append(copy.deepcopy(interaction))
        else:
            effective[identity] = copy.deepcopy(interaction)
    for overlay in overlays:
        target_owner = str(overlay.get("target_owner_namespace", ""))
        target_stable = str(overlay.get("target_stable_object_id", ""))
        target_identity = f"{target_owner}::{target_stable}"
        target = effective.setdefault(target_identity, {
            "owner_namespace": target_owner,
            "stable_object_id": target_stable,
            "presentation_object_id": target_identity,
        })
        mode = str(overlay.get("mode", ""))
        if mode == "replace":
            replacement = copy.deepcopy(overlay.get("interaction", {})) if isinstance(overlay.get("interaction"), dict) else {}
            replacement.update({
                "owner_namespace": target_owner,
                "stable_object_id": target_stable,
                "presentation_object_id": target_identity,
            })
            target = replacement
            effective[target_identity] = target
        elif mode == "gate":
            target["enabled"] = bool(overlay.get("enabled", False))
            target["disabled_reason"] = "" if target["enabled"] else str(overlay.get("disabled_reason", "Unavailable."))
            if not target["enabled"]:
                target["available_actions"] = []
                target["input_actions"] = []
        elif mode == "retarget":
            target["source_id"] = str(overlay.get("source_id", target.get("source_id", "")))
        elif mode == "augment":
            target.setdefault("available_actions", [])
            target["available_actions"].extend(copy.deepcopy(values(overlay.get("available_actions"))))
        target.setdefault("_slot_overlay_receipts", []).append(str(overlay.get("stable_object_id", "")))
    return effective


def collect_active_phase_snapshots(
    root: Path,
    include_aftermath: bool = False,
) -> dict[str, list[list[dict[str, Any]]]]:
    """Returns every reachable active phase, grouped by its legal physical map.

    These snapshots are authoring input only.  They let slot counts be tuned to
    actual simultaneous composition instead of the union of every object ever
    mentioned by a scenario.
    """
    catalog = json.loads((root / "data/environments/scenarios.json").read_text(encoding="utf-8"))
    legal_hosts: dict[str, tuple[str, str]] = {}
    for host_id, rows in catalog.items():
        for row in values(rows):
            if isinstance(row, dict):
                legal_hosts[str(row.get("id", ""))] = (str(host_id), str(row.get("layer_id", "")))
    result: dict[str, list[list[dict[str, Any]]]] = {}
    for source in sorted((root / "data/environments/scenario_sequences").glob("*.json")):
        package = json.loads(source.read_text(encoding="utf-8"))
        for scenario in values(package.get("scenarios")):
            if not isinstance(scenario, dict):
                continue
            scenario_id = str(scenario.get("scenario_id", ""))
            host_id, layer_id = legal_hosts.get(scenario_id, ("", ""))
            if not host_id:
                continue
            map_id = f"{host_id}:{layer_id}" if layer_id else host_id
            sequence = scenario.get("sequence", {}) if isinstance(scenario.get("sequence"), dict) else {}
            phase_graph = sequence.get("phase_graph", {}) if isinstance(sequence.get("phase_graph"), dict) else {}
            phases = {
                str(phase.get("id", "")): phase
                for phase in values(phase_graph.get("phases"))
                if isinstance(phase, dict) and str(phase.get("id", ""))
            }
            seen: set[tuple[str, str]] = set()

            def append_snapshot(
                phase_id: str,
                state: dict[str, dict[str, dict[str, Any]]],
            ) -> None:
                snapshot: list[dict[str, Any]] = []
                visuals = {**state["scene_ops"], **state["actor_ops"]}
                raw_interactions = state["interaction_ops"]
                interactions = _effective_interactions(raw_interactions)
                for identity, semantic in sorted(visuals.items()):
                    entry = copy.deepcopy(semantic)
                    entry["identity"] = identity
                    entry["_slot_scenario_id"] = scenario_id
                    entry["_slot_phase_id"] = phase_id
                    entry["_slot_interaction"] = copy.deepcopy(interactions.get(identity, {}))
                    entry["_slot_hidden"] = not bool(entry.get("visible", True))
                    entry["safe_exit"] = bool(entry["_slot_interaction"].get("safe_exit", False))
                    snapshot.append(entry)
                for identity, interaction in sorted(interactions.items()):
                    if identity in visuals:
                        continue
                    snapshot.append({
                        "identity": identity,
                        "_slot_scenario_id": scenario_id,
                        "_slot_phase_id": phase_id,
                        "_slot_interaction": copy.deepcopy(interaction),
                        "_slot_interaction_only": True,
                        "safe_exit": bool(interaction.get("safe_exit", False)),
                    })
                for identity, overlay in sorted(raw_interactions.items()):
                    if str(overlay.get("mode", "add")) not in {"gate", "retarget", "replace", "augment"}:
                        continue
                    snapshot.append({
                        **copy.deepcopy(overlay),
                        "identity": identity,
                        "_slot_scenario_id": scenario_id,
                        "_slot_phase_id": phase_id,
                        "_slot_nonvisual": True,
                        "_slot_collection": "interaction_overlay_ops",
                    })
                for family in ("service_ops", "game_ops", "route_ops"):
                    for identity, semantic in sorted(state[family].items()):
                        entry = copy.deepcopy(semantic)
                        entry.update({
                            "identity": identity,
                            "_slot_scenario_id": scenario_id,
                            "_slot_phase_id": phase_id,
                            "_slot_nonvisual": True,
                            "_slot_collection": family,
                        })
                        snapshot.append(entry)
                result.setdefault(map_id, []).append(snapshot)

            def walk(
                phase_id: str,
                state: dict[str, dict[str, dict[str, Any]]],
                path: tuple[str, ...],
            ) -> None:
                if phase_id in path or phase_id not in phases:
                    return
                next_state = copy.deepcopy(state)
                _apply_phase_operations(next_state, phases[phase_id])
                signature = (phase_id, json.dumps(next_state, sort_keys=True, separators=(",", ":")))
                if signature in seen:
                    return
                seen.add(signature)
                append_snapshot(phase_id, next_state)
                for branch in values(phases[phase_id].get("branches")):
                    if not isinstance(branch, dict):
                        continue
                    if str(branch.get("next_phase", "")):
                        walk(str(branch["next_phase"]), next_state, path + (phase_id,))
                    outcome = str(branch.get("outcome", ""))
                    if include_aftermath and outcome:
                        aftermath_state = copy.deepcopy(next_state)
                        cleanup = sequence.get("cleanup", {}) if isinstance(sequence.get("cleanup"), dict) else {}
                        aftermaths = sequence.get("aftermath", {}) if isinstance(sequence.get("aftermath"), dict) else {}
                        _apply_phase_operations(aftermath_state, cleanup)
                        aftermath = aftermaths.get(outcome, {}) if isinstance(aftermaths.get(outcome), dict) else {}
                        _apply_phase_operations(aftermath_state, aftermath)
                        append_snapshot(f"aftermath:{outcome}", aftermath_state)

            walk(str(phase_graph.get("initial_phase", "")), {
                "scene_ops": {}, "interaction_ops": {}, "actor_ops": {},
                "service_ops": {}, "game_ops": {}, "route_ops": {},
            }, ())
    return result


def stage_class_targets(map_data: dict[str, Any], snapshots: list[list[dict[str, Any]]]) -> dict[str, int]:
    if not snapshots:
        return {
            placement_class: 1
            for placement_class in ("standing_person", "floor_fixture", "surface_item")
        }
    class_overrides = map_data.get("class_overrides", {}) if isinstance(map_data.get("class_overrides"), dict) else {}
    demands: list[dict[str, int]] = []
    maximum_active = 0
    route_actor_present = False
    for snapshot in snapshots:
        demand = {placement_class: 0 for placement_class in CLASSES}
        for semantic in snapshot:
            if bool(semantic.get("_slot_interaction_only", False)) or bool(semantic.get("_slot_nonvisual", False)):
                continue
            if bool(semantic.get("safe_exit", False)):
                continue
            identity = str(semantic.get("identity", ""))
            stable_id = identity.removeprefix("scenario::")
            object_type = "actor" if bool(semantic.get("_slot_actor", False)) else "scene_object"
            placement_class = classify_with_override(
                semantic,
                object_type,
                identity,
                str(class_overrides.get(identity, class_overrides.get(stable_id, ""))),
            )
            demand[placement_class] += 1
            if str(semantic.get("route_id", "")) or isinstance(semantic.get("_slot_route_from"), dict):
                # A routed actor reserves a distinct authored endpoint too.
                demand[placement_class] += 1
                route_actor_present = True
        demands.append(demand)
        maximum_active = max(maximum_active, sum(demand.values()))
    allocated = {
        placement_class: max(demand[placement_class] for demand in demands)
        for placement_class in CLASSES
    }
    if route_actor_present:
        allocated["standing_person"] = max(allocated["standing_person"], 2)
    return {placement_class: count for placement_class, count in allocated.items() if count > 0}


def scenario_position_key(stable_id: str, semantic: dict[str, Any]) -> str:
    return "|".join((
        stable_id,
        str(semantic.get("anchor_id", "")).strip(),
        str(semantic.get("zone_id", "")).strip(),
        str(semantic.get("authored_position_route_id", "")).strip(),
    ))


def semantic_contact(archetype: dict[str, Any], semantic: dict[str, Any], fallback: tuple[float, float] | None) -> tuple[float, float] | None:
    anchors = archetype.get("semantic_anchors", {}) if isinstance(archetype.get("semantic_anchors"), dict) else {}
    zones = archetype.get("semantic_zones", {}) if isinstance(archetype.get("semantic_zones"), dict) else {}
    anchor = anchors.get(str(semantic.get("anchor_id", "")), {})
    if isinstance(anchor, dict):
        positioned = point(anchor.get("position"))
        if positioned is not None:
            return positioned
    zone = zones.get(str(semantic.get("zone_id", "")), {})
    if isinstance(zone, dict):
        bounds = rect(zone.get("bounds"))
        if bounds[2] > 0 and bounds[3] > 0:
            return (bounds[0] + bounds[2] / 2.0, bounds[1] + bounds[3] / 2.0)
    return fallback


def scenario_state_graph(
    map_data: dict[str, Any],
    archetype: dict[str, Any],
    snapshots: list[list[dict[str, Any]]],
) -> tuple[
    dict[str, dict[str, Any]],
    dict[str, set[str]],
    dict[str, tuple[str, str]],
    dict[str, tuple[str, str]],
]:
    overrides = map_data.get("class_overrides", {}) if isinstance(map_data.get("class_overrides"), dict) else {}
    positions = map_data.get("scenario_object_slot_positions", {}) if isinstance(map_data.get("scenario_object_slot_positions"), dict) else {}
    states: dict[str, dict[str, Any]] = {}
    conflicts: dict[str, set[str]] = {}
    movements: dict[str, tuple[str, str]] = {}
    authored_routes: dict[str, tuple[str, str]] = {}

    def ensure(stable_id: str, semantic: dict[str, Any], placement_class: str) -> str:
        preference_key = scenario_position_key(stable_id, semantic)
        key = preference_key
        existing = states.get(key)
        if existing is not None and str(existing.get("placement_class", "")) != placement_class:
            # The production position key deliberately describes location, not
            # presentation class.  If a scenario reuses that location identity
            # for physically incompatible visuals, color them independently and
            # omit the ambiguous preference downstream so the class pool binds.
            key = f"{preference_key}|@class={placement_class}"
        fallback = desired_rect_top_left(positions.get(stable_id), placement_class)
        if key not in states:
            states[key] = {
                "stable_id": stable_id,
                "preference_key": preference_key,
                "semantic": copy.deepcopy(semantic),
                "placement_class": placement_class,
                "wanted": semantic_contact(archetype, semantic, fallback),
                "label": placement_label(semantic),
            }
        else:
            next_label = placement_label(semantic)
            if len(next_label) > len(str(states[key].get("label", ""))):
                states[key]["label"] = next_label
        conflicts.setdefault(key, set())
        return key

    for snapshot in snapshots:
        active: list[str] = []
        classes: dict[str, str] = {}
        movement_starts: list[tuple[str, str]] = []
        for semantic in snapshot:
            if bool(semantic.get("_slot_interaction_only", False)) or bool(semantic.get("_slot_nonvisual", False)):
                continue
            identity = str(semantic.get("identity", ""))
            if not identity.startswith("scenario::") or bool(semantic.get("safe_exit", False)):
                continue
            stable_id = identity.removeprefix("scenario::")
            actor = bool(semantic.get("_slot_actor", False))
            placement_class = classify_with_override(
                semantic,
                "actor" if actor else "scene_object",
                identity,
                str(overrides.get(identity, overrides.get(stable_id, ""))),
            )
            authored_route_id = str(semantic.get("route_id", "")).strip() if actor else ""
            if authored_route_id:
                route_keys = authored_routes.get(authored_route_id)
                if route_keys is None:
                    route_keys = (
                        f"__route__|{authored_route_id}|start",
                        f"__route__|{authored_route_id}|end",
                    )
                    wanted = semantic_contact(
                        archetype,
                        semantic,
                        desired_rect_top_left(positions.get(stable_id), placement_class),
                    )
                    for route_key in route_keys:
                        states[route_key] = {
                            "stable_id": stable_id,
                            "preference_key": "",
                            "semantic": copy.deepcopy(semantic),
                            "placement_class": placement_class,
                            "wanted": wanted,
                            "label": placement_label(semantic),
                            "synthetic_route_endpoint": True,
                        }
                        conflicts.setdefault(route_key, set())
                    conflicts[route_keys[0]].add(route_keys[1])
                    conflicts[route_keys[1]].add(route_keys[0])
                    authored_routes[authored_route_id] = route_keys
                else:
                    existing_class = str(states.get(route_keys[0], {}).get("placement_class", ""))
                    if existing_class != placement_class:
                        raise ValueError(
                            f"{map_data.get('id')}.{authored_route_id}: route is shared by "
                            f"incompatible {existing_class}/{placement_class} actors"
                        )
                    next_label = placement_label(semantic)
                    for route_key in route_keys:
                        if len(next_label) > len(str(states[route_key].get("label", ""))):
                            states[route_key]["label"] = next_label
                active.extend(route_keys)
                classes[route_keys[0]] = placement_class
                classes[route_keys[1]] = placement_class
                continue
            key = ensure(stable_id, semantic, placement_class)
            active.append(key)
            classes[key] = placement_class
            route_from = semantic.get("_slot_route_from")
            if actor and isinstance(route_from, dict):
                from_semantic = copy.deepcopy(route_from)
                from_semantic["label"] = placement_label(semantic)
                from_key = ensure(stable_id, from_semantic, placement_class)
                if from_key != key:
                    previous = movements.get(key)
                    if previous is not None and previous[0] != from_key:
                        raise ValueError(f"{map_data.get('id')}.{key}: position target has multiple route starts")
                    movements[key] = (from_key, key)
                    movement_starts.append((from_key, placement_class))
        for index, left in enumerate(active):
            for right in active[index + 1:]:
                if left != right:
                    conflicts[left].add(right)
                    conflicts[right].add(left)
        for from_key, placement_class in movement_starts:
            for other in active:
                if from_key != other:
                    conflicts[from_key].add(other)
                    conflicts[other].add(from_key)
    return states, conflicts, movements, authored_routes


def color_scenario_states(states: dict[str, dict[str, Any]], conflicts: dict[str, set[str]]) -> dict[str, int]:
    colors: dict[str, int] = {}
    remaining = set(states)
    while remaining:
        node = min(
            remaining,
            key=lambda key: (-len({colors[n] for n in conflicts.get(key, set()) if n in colors}), -len(conflicts.get(key, set())), key),
        )
        unavailable = {colors[neighbor] for neighbor in conflicts.get(node, set()) if neighbor in colors}
        color = 0
        while color in unavailable:
            color += 1
        colors[node] = color
        remaining.remove(node)
    return colors


def support_candidates(map_data: dict[str, Any], placement_class: str) -> list[dict[str, Any]]:
    width, height = SLOT_SIZE[placement_class]
    output: list[dict[str, Any]] = []

    def add(contact: tuple[float, float], support_id: str) -> None:
        bounds = rect_at_contact(contact, (width, height), placement_class)
        if bounds[0] < -0.01 or bounds[1] < -0.01 or bounds[0] + bounds[2] > BOARD_W + 0.01 or bounds[1] + bounds[3] > BOARD_H + 0.01:
            return
        key = tuple(round(value, 3) for value in bounds)
        if any(existing["key"] == key for existing in output):
            return
        output.append({"contact": contact, "rect": bounds, "support_id": support_id, "key": key})

    if placement_class in GROUNDED_CLASSES:
        floor = map_data.get("floor", {})
        contact_range = values(floor.get("contact_y"))
        low = float(contact_range[0]) if len(contact_range) >= 2 else 0.0
        high = float(contact_range[1]) if len(contact_range) >= 2 else BOARD_H
        for field, support_id in (("bands", "floor"), ("stage_bands", "stage")):
            for raw_band in values(floor.get(field)):
                x, y, w, h = rect(raw_band)
                min_y = max(y + height, low) if field == "bands" else y + height
                max_y = min(y + h, high) if field == "bands" else y + h
                if max_y < min_y:
                    continue
                y_values = [max_y]
                cursor = max_y - height - 8.0
                while cursor >= min_y:
                    y_values.append(cursor)
                    cursor -= height + 8.0
                for contact_y in y_values:
                    cursor_x = x + width / 2.0
                    while cursor_x <= x + w - width / 2.0 + 0.01:
                        add((cursor_x, contact_y), support_id)
                        cursor_x += 8.0
    elif placement_class in {"behind_counter_person", "surface_item"}:
        for counter in values(map_data.get("counters")):
            allowed = values(counter.get("classes")) if isinstance(counter, dict) else []
            if allowed and placement_class not in allowed:
                continue
            x0 = float(counter.get("x0", 0.0))
            x1 = float(counter.get("x1", 0.0))
            cursor_x = x0 + width / 2.0
            while cursor_x <= x1 - width / 2.0 + 0.01:
                add((cursor_x, float(counter.get("top_y", 0.0))), str(counter.get("id", "counter")))
                cursor_x += 8.0
    elif placement_class == "seated_person":
        for seat in values(map_data.get("seats")):
            seat_point = point(seat.get("point")) if isinstance(seat, dict) else None
            if seat_point is not None:
                add(seat_point, str(seat.get("id", "seat")))
    elif placement_class in {"wall_mounted", "hanging"}:
        surface = map_data.get("wall", {}) if placement_class == "wall_mounted" else map_data.get("ceiling", {})
        regions = []
        if placement_class == "wall_mounted":
            regions.extend((str(mount.get("id", "wall_mount")), rect(mount.get("bounds"))) for mount in values(surface.get("mounts")) if isinstance(mount, dict))
        regions.append(("wall" if placement_class == "wall_mounted" else "ceiling", rect(surface.get("bounds"))))
        exclusions = [rect(item.get("bounds")) for item in values(surface.get("exclusions")) if isinstance(item, dict)]
        for support_id, region in regions:
            x, y, w, h = region
            cursor_y = y + height / 2.0
            while cursor_y <= y + h - height / 2.0 + 0.01:
                cursor_x = x + width / 2.0
                while cursor_x <= x + w - width / 2.0 + 0.01:
                    bounds = rect_at_contact((cursor_x, cursor_y), (width, height), placement_class)
                    if not any(intersects(bounds, exclusion) for exclusion in exclusions):
                        add((cursor_x, cursor_y), support_id)
                    cursor_x += 8.0
                cursor_y += 8.0
    elif placement_class == "doorway":
        for doorway in values(map_data.get("doorways")):
            if not isinstance(doorway, dict):
                continue
            x, y, w, h = rect(doorway.get("bounds"))
            cursor_y = max(y + height / 2.0, height / 2.0)
            max_y = min(y + h - height / 2.0, BOARD_H - height / 2.0)
            while cursor_y <= max_y + 0.01:
                center_x = min(max(x + w / 2.0, width / 2.0), BOARD_W - width / 2.0)
                add((center_x, cursor_y), str(doorway.get("id", "doorway")))
                cursor_y += 8.0
    return output


def desired_rect_top_left(raw: Any, placement_class: str) -> tuple[float, float] | None:
    desired = point(raw)
    if desired is None:
        return None
    size = SLOT_SIZE[placement_class]
    return (desired[0] + size[0] / 2.0, desired[1] + (size[1] / 2.0 if placement_class in {"wall_mounted", "hanging", "doorway"} else size[1]))


def zone_for(bounds: tuple[float, float, float, float], zones: dict[str, Any]) -> str:
    x, y, width, height = bounds
    candidates: list[tuple[float, str]] = []
    for zone_id, zone in zones.items():
        zone_bounds = rect(zone.get("bounds")) if isinstance(zone, dict) else (0.0, 0.0, 0.0, 0.0)
        if (x >= zone_bounds[0] and y >= zone_bounds[1]
                and x + width <= zone_bounds[0] + zone_bounds[2]
                and y + height <= zone_bounds[1] + zone_bounds[3]):
            candidates.append((zone_bounds[2] * zone_bounds[3], str(zone_id)))
    return min(candidates)[1] if candidates else "room"


def facing(contact: tuple[float, float], placement_class: str) -> str:
    if placement_class not in PERSON_CLASSES and placement_class != "doorway":
        return "none"
    if contact[0] < BOARD_W * 0.42:
        return "right"
    if contact[0] > BOARD_W * 0.58:
        return "left"
    return "front"


def make_slot(slot_id: str, kind: str, placement_class: str, candidate: dict[str, Any], priority: int, zones: dict[str, Any]) -> dict[str, Any]:
    bounds = candidate["rect"]
    contact = candidate["contact"]
    label_y = max(8.0, bounds[1] - 6.0)
    return {
        "id": slot_id,
        "kind": kind,
        "pos": [round(contact[0], 3), round(contact[1], 3)],
        "footprint_class": placement_class,
        "hit_rect": [round(value, 3) for value in bounds],
        "label_anchor": [round(contact[0], 3), round(label_y, 3)],
        "facing": facing(contact, placement_class),
        "priority": priority,
        "zone_id": zone_for(bounds, zones),
        "support_id": str(candidate["support_id"]),
        "walk_lane_ids": ["lane.public"] if placement_class in PERSON_CLASSES or placement_class == "doorway" else [],
    }


def nearest(candidates: list[dict[str, Any]], wanted: tuple[float, float] | None) -> list[dict[str, Any]]:
    if wanted is None:
        return list(candidates)
    return sorted(candidates, key=lambda item: ((item["contact"][0] - wanted[0]) ** 2 + (item["contact"][1] - wanted[1]) ** 2, item["key"]))


def slot_distance(slot: dict[str, Any], wanted: tuple[float, float] | None) -> float:
    if wanted is None:
        return float(slot["priority"])
    pos = slot["pos"]
    return (float(pos[0]) - wanted[0]) ** 2 + (float(pos[1]) - wanted[1]) ** 2


def archetype_for_map(map_id: str, archetypes: dict[str, dict[str, Any]]) -> dict[str, Any]:
    base_id = map_id.split(":", 1)[0]
    return archetypes.get(base_id, {})


def author_map(
    map_data: dict[str, Any],
    archetype: dict[str, Any],
    semantics: dict[str, dict[str, Any]],
    base_semantics: dict[str, dict[str, Any]],
    phase_snapshots: list[list[dict[str, Any]]],
) -> None:
    zones = copy.deepcopy(archetype.get("semantic_zones", {})) if isinstance(archetype.get("semantic_zones"), dict) else {}
    class_overrides = copy.deepcopy(map_data.get("class_overrides", {})) if isinstance(map_data.get("class_overrides"), dict) else {}
    # Production game semantics outrank legacy placement hints. Several maps
    # still described full cabinets/racks as wall or countertop decorations,
    # which produced compatible-looking slots that the live classifier could
    # never use. Normalize every authored game override from the catalog.
    for object_id in list(map_data.get("object_slot_positions", {})):
        if not str(object_id).startswith("game:"):
            continue
        semantic = base_semantics.get(str(object_id), {})
        if semantic:
            class_overrides[str(object_id)] = classify_with_override(semantic, "game", str(object_id))
    class_overrides.update(SCENARIO_CLASS_OVERRIDES.get(str(map_data.get("id", "")), {}))
    map_data["class_overrides"] = class_overrides
    # Allocation authority includes both fixed hit geometry and the exact label
    # rectangle rendered above it.  Route sweeps intentionally use only the
    # separate physical-hit list below: text is input authority, not a wall.
    occupied_authority: list[tuple[float, float, float, float]] = []
    occupied_hits: list[tuple[float, float, float, float]] = []
    pools = {placement_class: support_candidates(map_data, placement_class) for placement_class in CLASSES}
    previous_slots = {
        "base": [copy.deepcopy(slot) for slot in values(map_data.get("base_slots")) if isinstance(slot, dict)],
        "stage": [copy.deepcopy(slot) for slot in values(map_data.get("stage_slots")) if isinstance(slot, dict)],
        "exit": [copy.deepcopy(slot) for slot in values(map_data.get("exit_slots")) if isinstance(slot, dict)],
    }
    previous_used: set[tuple[str, str]] = set()
    route_sensitive_room = any(
        str(semantic.get("route_id", "")).strip()
        or isinstance(semantic.get("_slot_route_from"), dict)
        for snapshot in phase_snapshots
        for semantic in snapshot
        if isinstance(semantic, dict)
    )

    def take(
        kind: str,
        placement_class: str,
        wanted: tuple[float, float] | None,
        prefix: str,
        ordinal: int,
        label: str | None,
    ) -> dict[str, Any] | None:
        for candidate in nearest(pools[placement_class], wanted):
            reserve = reservation(candidate["rect"])
            if kind == "stage" and placement_class == "floor_fixture" and (
                intersects(candidate["rect"], WALK_LANE_RECT) or intersects(expanded(candidate["rect"]), WALK_LANE_RECT)
            ):
                continue
            authority = candidate_authority(candidate, label)
            if authority_intersects(authority, occupied_authority):
                continue
            occupied_authority.extend(authority)
            occupied_hits.append(reserve)
            return make_slot(f"{prefix}.{placement_class}.{ordinal:02d}", kind, placement_class, candidate, ordinal * 10, zones)
        return None

    def reuse(
        kind: str,
        placement_class: str,
        prefix: str,
        ordinal: int,
        label: str | None,
    ) -> dict[str, Any] | None:
        for prior in previous_slots[kind]:
            prior_key = (kind, str(prior.get("id", "")))
            if prior_key in previous_used:
                continue
            if str(prior.get("footprint_class", "")) != placement_class:
                continue
            bounds = rect(prior.get("hit_rect"))
            if bounds[2] <= 0 or bounds[3] <= 0:
                continue
            if kind == "stage" and placement_class == "floor_fixture" and (
                intersects(bounds, WALK_LANE_RECT) or intersects(expanded(bounds), WALK_LANE_RECT)
            ):
                continue
            reserve = reservation(bounds)
            candidate = {"rect": bounds, "contact": contact_for_rect(bounds, placement_class)}
            authority = candidate_authority(candidate, label)
            if authority_intersects(authority, occupied_authority):
                continue
            contact = point(prior.get("pos")) or contact_for_rect(bounds, placement_class)
            candidate["contact"] = contact
            authority = candidate_authority(candidate, label)
            if authority_intersects(authority, occupied_authority):
                continue
            occupied_authority.extend(authority)
            occupied_hits.append(reserve)
            previous_used.add(prior_key)
            return make_slot(
                f"{prefix}.{placement_class}.{ordinal:02d}", kind, placement_class,
                {"rect": bounds, "contact": contact, "support_id": str(prior.get("support_id", ""))},
                ordinal * 10, zones,
            )
        return None

    exit_states: dict[str, dict[str, Any]] = {}
    exit_conflicts: dict[str, set[str]] = {}
    for snapshot in phase_snapshots:
        current: list[str] = []
        for semantic in snapshot:
            identity = str(semantic.get("identity", ""))
            if not identity.startswith("scenario::") or not bool(semantic.get("safe_exit", False)):
                continue
            stable_id = identity.removeprefix("scenario::")
            key = scenario_position_key(stable_id, semantic)
            fallback = (
                desired_rect_top_left(map_data.get("scenario_object_slot_positions", {}).get(stable_id), "doorway")
                if isinstance(map_data.get("scenario_object_slot_positions"), dict)
                else None
            )
            if key not in exit_states:
                exit_states[key] = {
                    "stable_id": stable_id,
                    "wanted": semantic_contact(archetype, semantic, fallback),
                    "label": placement_label(semantic),
                }
            else:
                next_label = placement_label(semantic)
                if len(next_label) > len(str(exit_states[key].get("label", ""))):
                    exit_states[key]["label"] = next_label
            exit_conflicts.setdefault(key, set())
            current.append(key)
        for index, left in enumerate(current):
            for right in current[index + 1:]:
                if left != right:
                    exit_conflicts[left].add(right)
                    exit_conflicts[right].add(left)
    exit_colors = color_scenario_states(exit_states, exit_conflicts)
    exit_slots: list[dict[str, Any]] = []
    exit_target = max(exit_colors.values(), default=-1) + 1

    base_desires: dict[str, list[tuple[str, tuple[float, float] | None]]] = {key: [] for key in CLASSES}
    object_positions = map_data.get("object_slot_positions", {}) if isinstance(map_data.get("object_slot_positions"), dict) else {}
    for object_id, raw_position in sorted(object_positions.items()):
        object_type = str(object_id).split(":", 1)[0]
        semantic = copy.deepcopy(base_semantics.get(str(object_id), {}))
        placement_class = classify_with_override(
            semantic,
            object_type,
            str(object_id),
            str(class_overrides.get(object_id, "")),
        )
        base_desires[placement_class].append((str(object_id), desired_rect_top_left(raw_position, placement_class)))
    layout = archetype.get("layout", {}) if isinstance(archetype.get("layout"), dict) else {}
    category_desires: list[tuple[str, int, str, tuple[float, float] | None]] = []
    for field_name, placement_class in CATEGORY_CLASS.items():
        for index, raw_spot in enumerate(values(layout.get(field_name))):
            wanted = point(raw_spot)
            category_desires.append((field_name, index, placement_class, wanted))
            base_desires[placement_class].append((f"{field_name}:{index}", wanted))

    # Base records are selected from the archetype's concrete pools at runtime.
    # Reserve the widest exact label that can bind to each class in this room;
    # using an unrelated global maximum needlessly turns one-line door labels
    # into two-line geometry and can make a valid authored inventory impossible.
    potential_base_ids = set(str(identity) for identity in object_positions)
    for pool_field, prefix in (
        ("game_pool", "game"),
        ("item_pool", "item"),
        ("event_pool", "event"),
        ("service_pool", "service"),
    ):
        potential_base_ids.update(f"{prefix}:{value}" for value in values(archetype.get(pool_field)))
    potential_base_ids.update(str(value) for value in values(archetype.get("object_fixtures")))
    potential_base_ids.update(
        f"travel:{value}"
        for field in ("next_archetypes", "rare_next_archetypes")
        for value in values(archetype.get(field))
    )
    potential_base_ids.add("travel:leave")
    base_labels: dict[str, list[str]] = {placement_class: [] for placement_class in CLASSES}
    game_count_hint = max(
        (int(value) for value in values(archetype.get("game_count"))),
        default=int(archetype.get("game_count", 0)) if isinstance(archetype.get("game_count"), (int, float)) else 0,
    )
    for identity in sorted(potential_base_ids):
        object_type = identity.split(":", 1)[0]
        semantic = base_semantics.get(identity, {})
        placement_class = classify_with_override(
            semantic,
            object_type,
            identity,
            str(class_overrides.get(identity, "")),
        )
        label = base_record_label(identity, semantic)
        if object_type == "game" and game_count_hint > 1:
            label = f"{label} {game_count_hint}"
        base_labels[placement_class].append(label)
    base_class_labels: dict[str, str] = {
        placement_class: max(labels, key=len, default=placement_class.replace("_", " ").title())
        for placement_class, labels in base_labels.items()
    }

    base_slots: list[dict[str, Any]] = []
    game_count_raw = archetype.get("game_count", 0)
    game_count_max = max((int(item) for item in values(game_count_raw)), default=int(game_count_raw) if isinstance(game_count_raw, (int, float)) else 0)
    floor_game_ids = [
        object_id for object_id in object_positions
        if str(object_id).startswith("game:")
        and classify_with_override(
            base_semantics.get(str(object_id), {}),
            "game",
            str(object_id),
            str(class_overrides.get(object_id, "")),
        ) == "floor_fixture"
    ]
    floor_game_capacity = min(len(floor_game_ids), game_count_max) if game_count_max > 0 else len(floor_game_ids)
    base_class_order = sorted(
        CLASSES,
        key=lambda placement_class: (len(pools[placement_class]), placement_class),
    )
    deferred_base_specs: list[dict[str, Any]] = []
    for placement_class in base_class_order:
        desired = base_desires[placement_class]
        if map_data.get("id") == "pawn_shop" and placement_class == "surface_item":
            class_cap = 6
        elif map_data.get("id") == "pawn_shop" and placement_class == "behind_counter_person":
            class_cap = 2
        else:
            class_cap = BASE_CAP[placement_class]
        if placement_class == "floor_fixture":
            class_cap = max(floor_game_capacity, 1 if desired else 0)
        cap = min(class_cap, max(1 if desired else 0, min(len(desired), class_cap)))
        for ordinal in range(1, cap + 1):
            wanted = desired[(ordinal - 1) % len(desired)][1] if desired else None
            if route_sensitive_room and placement_class == "standing_person":
                floor_values = values(map_data.get("floor", {}).get("contact_y")) if isinstance(map_data.get("floor"), dict) else []
                route_contact_y = float(floor_values[-1]) if floor_values else BOARD_H - 72.0
                # Keep the far-right doorway/exit support clear while pulling
                # the base actor out of the central movement corridor.
                wanted = (BOARD_W - SLOT_SIZE[placement_class][0] / 2.0 - 144.0, route_contact_y)
            # Base and scenario records form one immutable slot inventory. Pack
            # them in the same CSP so an early greedy base choice cannot strand
            # a later exact label or actor route.
            deferred_base_specs.append({
                "placement_class": placement_class,
                "ordinal": ordinal,
                "wanted": wanted,
                "label": base_class_labels[placement_class],
            })

    base_by_class = {placement_class: [slot for slot in base_slots if slot["footprint_class"] == placement_class] for placement_class in CLASSES}
    object_slot_ids: dict[str, str] = {}
    for placement_class, desired in base_desires.items():
        slots = base_by_class[placement_class]
        used: set[str] = set()
        for identity, wanted in desired:
            if identity.startswith(tuple(CATEGORY_CLASS.keys())):
                continue
            if slots:
                choices = [slot for slot in slots if str(slot["id"]) not in used] or slots
                selected = min(choices, key=lambda slot: (slot_distance(slot, wanted), slot["priority"], slot["id"]))
                object_slot_ids[identity] = selected["id"]
                used.add(str(selected["id"]))
    category_slot_ids: dict[str, str] = {}
    category_used = {placement_class: set() for placement_class in CLASSES}
    for field_name, index, placement_class, wanted in category_desires:
        slots = base_by_class[placement_class]
        if slots:
            choices = [slot for slot in slots if str(slot["id"]) not in category_used[placement_class]] or slots
            selected = min(choices, key=lambda slot: (slot_distance(slot, wanted), slot["priority"], slot["id"]))
            category_slot_ids[f"{field_name}:{index}"] = selected["id"]
            category_used[placement_class].add(str(selected["id"]))

    # Scenario state identities are colored against every reachable composition.
    # A set_position target reserves both its previous and target slots, giving
    # the renderer a reconstructible authored replay route instead of a teleport.
    states, conflicts, movements, authored_route_states = scenario_state_graph(map_data, archetype, phase_snapshots)
    colors: dict[str, int] = {}
    routed_classes = {
        str(state.get("placement_class", ""))
        for state in states.values()
        if bool(state.get("synthetic_route_endpoint", False))
    }
    routed_classes.update(
        str(states.get(target_key, {}).get("placement_class", ""))
        for target_key in movements
    )
    stage_class_order = sorted(
        CLASSES,
        key=lambda placement_class: (
            0 if placement_class in routed_classes else 1,
            len(pools[placement_class]),
            placement_class,
        ),
    )
    for placement_class in stage_class_order:
        class_states = {key: state for key, state in states.items() if state["placement_class"] == placement_class}
        class_conflicts = {
            key: {neighbor for neighbor in conflicts.get(key, set()) if neighbor in class_states}
            for key in class_states
        }
        colors.update(color_scenario_states(class_states, class_conflicts))
    stage_targets = stage_class_targets(map_data, phase_snapshots)
    for placement_class in CLASSES:
        class_colors = [colors[key] for key, state in states.items() if state["placement_class"] == placement_class]
        if class_colors:
            # Reachable graph colors are the exact active-capacity proof.  The
            # earlier demand estimate may count transient route endpoints twice;
            # carrying that excess forward creates unowned spare slots with no
            # truthful simultaneous-occupancy rule.
            stage_targets[placement_class] = max(class_colors) + 1
    floor = map_data.get("floor", {}) if isinstance(map_data.get("floor"), dict) else {}
    contacts = values(floor.get("contact_y"))
    lane_y = float(contacts[-1]) if contacts else 358.0
    lane_y = max(44.0, min(BOARD_H - 16.0, lane_y))
    walk_lanes = [{
        "id": "lane.public",
        "points": [[64.0, lane_y], [450.0, lane_y], [836.0, lane_y]],
        "clearance_px": 8.0,
        "direction": "both",
        "entry": True,
    }]
    permanent_authority = list(occupied_authority)
    permanent_hits = list(occupied_hits)
    synthetic_route_keys = {
        key
        for key, state in states.items()
        if bool(state.get("synthetic_route_endpoint", False))
    }

    def route_sweep_rects(
        start: dict[str, Any],
        end: dict[str, Any],
        placement_class: str,
    ) -> list[tuple[float, float, float, float]]:
        lanes_by_id = {
            str(lane.get("id", "")): lane
            for lane in walk_lanes
            if isinstance(lane, dict)
        }
        start_contact = start["contact"]
        end_contact = end["contact"]
        lane_points: list[tuple[float, float]] = []
        for lane_id in ("lane.public",):
            lane = lanes_by_id.get(lane_id, {})
            points = [point(value) for value in values(lane.get("points"))]
            points = [value for value in points if value is not None]
            if len(points) < 2:
                return []
            direction = str(lane.get("direction", "both"))
            if direction == "reverse":
                points.reverse()
            elif direction == "both":
                approach = start_contact if not lane_points else lane_points[-1]
                if (
                    (approach[0] - points[-1][0]) ** 2 + (approach[1] - points[-1][1]) ** 2
                    < (approach[0] - points[0][0]) ** 2 + (approach[1] - points[0][1]) ** 2
                ):
                    points.reverse()
            if lane_points and lane_points[-1] != points[0]:
                return []
            for lane_point in points:
                if not lane_points or lane_points[-1] != lane_point:
                    lane_points.append(lane_point)
        start_projection = _polyline_projection_with_distance(lane_points, start_contact)
        end_projection = _polyline_projection_with_distance(lane_points, end_contact)
        if start_projection is None or end_projection is None:
            return []
        contact_path = _polyline_slice_points(
            lane_points,
            start_projection[0],
            start_projection[1],
            end_projection[0],
            end_projection[1],
        )
        width, height = SLOT_SIZE[placement_class]
        start_center = (
            start["rect"][0] + start["rect"][2] / 2.0,
            start["rect"][1] + start["rect"][3] / 2.0,
        )
        end_center = (
            end["rect"][0] + end["rect"][2] / 2.0,
            end["rect"][1] + end["rect"][3] / 2.0,
        )
        center_offset = (
            start_center[0] - start_contact[0],
            start_center[1] - start_contact[1],
        )
        route_centers = [start_center]
        route_centers.extend(
            (contact[0] + center_offset[0], contact[1] + center_offset[1])
            for contact in contact_path
        )
        route_centers.append(end_center)
        route_centers = [
            route_center
            for index, route_center in enumerate(route_centers)
            if index == 0 or route_center != route_centers[index - 1]
        ]
        sweeps: list[tuple[float, float, float, float]] = []
        for left, right in zip(route_centers, route_centers[1:]):
            sweeps.append((
                min(left[0], right[0]) - width / 2.0,
                min(left[1], right[1]) - height / 2.0,
                abs(right[0] - left[0]) + width,
                abs(right[1] - left[1]) + height,
            ))
        return sweeps

    # Allocate every (footprint class, graph color) as one constraint problem.
    # A class-by-class greedy pass can strand a scarce later class even though a
    # deterministic whole-room solution exists.
    group_rows: dict[tuple[str, int], dict[str, Any]] = {}
    for placement_class in CLASSES:
        target = int(stage_targets.get(placement_class, 0))
        class_states = sorted(
            (key, state)
            for key, state in states.items()
            if state["placement_class"] == placement_class
        )
        for color in range(target):
            keys = [key for key, _state in class_states if colors.get(key) == color]
            wanted = next((state.get("wanted") for key, state in class_states if key in keys and state.get("wanted") is not None), None)
            labels = [str(state.get("label", "")) for key, state in class_states if key in keys]
            group_rows[(placement_class, color)] = {
                "kind": "stage",
                "placement_class": placement_class,
                "color": color,
                "keys": keys,
                "wanted": wanted,
                # One graph-color slot can render several mutually exclusive
                # states. The longest exact label contains every shorter label
                # rectangle because all share the same authored anchor.
                "label": max(labels, key=len, default=None),
            }
    for spec in deferred_base_specs:
        placement_class = str(spec["placement_class"])
        ordinal = int(spec["ordinal"])
        group_rows[(placement_class, -ordinal)] = {
            "kind": "base",
            "placement_class": placement_class,
            "color": -ordinal,
            "ordinal": ordinal,
            "keys": [],
            "wanted": spec.get("wanted"),
            "label": spec.get("label"),
        }
    for color in range(exit_target):
        keys = [key for key in exit_states if exit_colors.get(key) == color]
        color_wants = [
            exit_states[key].get("wanted")
            for key in keys
            if isinstance(exit_states[key].get("wanted"), tuple)
        ]
        wanted = color_wants[0] if color_wants else None
        labels = [str(exit_states[key].get("label", "")) for key in keys]
        group_rows[("doorway", EXIT_COLOR_OFFSET + color)] = {
            "kind": "exit",
            "placement_class": "doorway",
            "color": EXIT_COLOR_OFFSET + color,
            "exit_color": color,
            "keys": keys,
            "wanted": wanted,
            "label": max(labels, key=len, default=""),
        }

    def groups_conflict(left: tuple[str, int], right: tuple[str, int]) -> bool:
        # Every emitted record is part of one immutable slot inventory. States
        # may reuse a graph-color record, but two distinct records may never
        # overlap merely because their scenarios are mutually exclusive.
        return left != right

    group_domains: dict[tuple[str, int], list[dict[str, Any]]] = {}
    previous_stage_by_id = {
        str(slot.get("id", "")): slot
        for slot in previous_slots["stage"]
        if isinstance(slot, dict)
    }
    previous_base_by_id = {
        str(slot.get("id", "")): slot
        for slot in previous_slots["base"]
        if isinstance(slot, dict)
    }
    for group_id, group in group_rows.items():
        placement_class, color = group_id
        group_kind = str(group.get("kind", "stage"))
        candidates = []
        for candidate in pools[placement_class]:
            bounds = candidate["rect"]
            if group_kind == "stage" and placement_class == "floor_fixture" and (
                intersects(bounds, WALK_LANE_RECT) or intersects(expanded(bounds), WALK_LANE_RECT)
            ):
                continue
            if authority_intersects(
                candidate_authority(candidate, group.get("label")),
                permanent_authority,
            ):
                continue
            candidates.append(candidate)
        if group_kind == "base":
            previous_id = f"base.{placement_class}.{int(group.get('ordinal', 0)):02d}"
            previous = previous_base_by_id.get(previous_id, {})
        elif group_kind == "exit":
            previous_id = f"exit.doorway.{int(group.get('exit_color', 0)) + 1:02d}"
            previous = next(
                (
                    slot
                    for slot in previous_slots["exit"]
                    if str(slot.get("id", "")) == previous_id
                ),
                {},
            )
        else:
            previous_id = f"stage.{placement_class}.{color + 1:02d}"
            previous = previous_stage_by_id.get(previous_id, {})
        previous_bounds = rect(previous.get("hit_rect")) if previous else (0.0, 0.0, 0.0, 0.0)
        wanted = group["wanted"] if isinstance(group["wanted"], tuple) else None

        def domain_rank(candidate: dict[str, Any]) -> tuple[float, float, tuple[float, ...]]:
            candidate_bounds = candidate["rect"]
            retained = 0.0 if previous and candidate_bounds == previous_bounds else 1.0
            distance = 0.0 if wanted is None else (
                (candidate["contact"][0] - wanted[0]) ** 2
                + (candidate["contact"][1] - wanted[1]) ** 2
            )
            return (retained, distance, candidate["key"])

        # Dense support grids contain many geometrically equivalent nearby
        # choices.  Keep the best local choices plus a deterministic spatial
        # sample so a distant corridor remains reachable without multiplying
        # every backtracking branch.
        ranked_candidates = sorted(candidates, key=domain_rank)
        local_count = 32
        spatial_count = 48 if placement_class in GROUNDED_CLASSES or placement_class in PERSON_CLASSES else 32
        complete_threshold = 80
        selected_candidates = list(ranked_candidates) if len(ranked_candidates) <= complete_threshold else ranked_candidates[:local_count]
        if len(ranked_candidates) > complete_threshold:
            spatial_candidates = sorted(ranked_candidates, key=lambda candidate: candidate["key"])
            sample_count = min(spatial_count, len(spatial_candidates))
            for sample_index in range(sample_count):
                index = round(sample_index * (len(spatial_candidates) - 1) / max(1, sample_count - 1))
                candidate = spatial_candidates[index]
                if candidate not in selected_candidates:
                    selected_candidates.append(candidate)
        group_domains[group_id] = selected_candidates

    state_group = {
        key: (str(state.get("placement_class", "")), colors.get(key, -1))
        for key, state in states.items()
    }
    route_relations: list[
        tuple[tuple[str, int], tuple[str, int], str, str, str]
    ] = []
    route_blocker_groups: list[set[tuple[str, int]]] = []
    for start_key, end_key in list(authored_route_states.values()) + list(movements.values()):
        start_group = state_group.get(start_key)
        end_group = state_group.get(end_key)
        placement_class = str(states.get(start_key, {}).get("placement_class", ""))
        if start_group in group_rows and end_group in group_rows and start_group != end_group:
            relation = (start_group, end_group, placement_class, start_key, end_key)
            if relation not in route_relations:
                route_relations.append(relation)
                coactive_keys = conflicts.get(start_key, set()) | conflicts.get(end_key, set())
                blockers = {
                    state_group[key]
                    for key in coactive_keys
                    if key in state_group and state_group[key] in group_rows
                }
                blockers.update(
                    group_id
                    for group_id, row in group_rows.items()
                    if str(row.get("kind", "stage")) in {"base", "exit"}
                )
                blockers.discard(start_group)
                blockers.discard(end_group)
                route_blocker_groups.append(blockers)
    route_families: list[dict[str, Any]] = []
    route_family_by_key: dict[tuple[Any, ...], int] = {}
    for relation_index, relation in enumerate(route_relations):
        start_group, end_group, placement_class = relation[:3]
        left_group, right_group = sorted((start_group, end_group))
        family_key = (left_group, right_group, placement_class, ("lane.public",))
        family_index = route_family_by_key.get(family_key)
        if family_index is None:
            family_index = len(route_families)
            route_family_by_key[family_key] = family_index
            route_families.append({
                "left_group": left_group,
                "right_group": right_group,
                "placement_class": placement_class,
                "relation_indexes": [],
                "blockers": set(),
            })
        route_families[family_index]["relation_indexes"].append(relation_index)
        route_families[family_index]["blockers"].update(route_blocker_groups[relation_index])

    def groups_connected(left: tuple[str, int], right: tuple[str, int]) -> bool:
        if groups_conflict(left, right):
            return True
        return any(
            {left, right} == {start_group, end_group}
            for start_group, end_group, _placement_class, _start_key, _end_key in route_relations
        )

    assignments: dict[tuple[str, int], dict[str, Any]] = {}

    domain_indexes = {
        group_id: {id(candidate): index for index, candidate in enumerate(domain)}
        for group_id, domain in group_domains.items()
    }
    authority_cache = {
        (group_id, index): candidate_authority(candidate, group_rows[group_id].get("label"))
        for group_id, domain in group_domains.items()
        for index, candidate in enumerate(domain)
    }
    permanent_blocked = {
        group_id: {
            index
            for index, _candidate in enumerate(domain)
            if authority_intersects(authority_cache[(group_id, index)], permanent_authority)
        }
        for group_id, domain in group_domains.items()
    }
    overlap_matrices: dict[
        tuple[tuple[str, int], tuple[str, int]],
        set[tuple[int, int]],
    ] = {}
    ordered_groups = sorted(group_domains)
    for left_offset, left_group in enumerate(ordered_groups):
        for right_group in ordered_groups[left_offset + 1:]:
            if not groups_conflict(left_group, right_group):
                continue
            overlap_matrices[(left_group, right_group)] = {
                (left_index, right_index)
                for left_index, _left_candidate in enumerate(group_domains[left_group])
                for right_index, _right_candidate in enumerate(group_domains[right_group])
                if authority_intersects(
                    authority_cache[(left_group, left_index)],
                    authority_cache[(right_group, right_index)],
                )
            }
    directed_conflict_masks: dict[
        tuple[tuple[str, int], tuple[str, int]],
        list[int],
    ] = {}
    for (left_group, right_group), conflicts_for_pair in overlap_matrices.items():
        left_masks = [0] * len(group_domains[left_group])
        right_masks = [0] * len(group_domains[right_group])
        for left_index, right_index in conflicts_for_pair:
            left_masks[left_index] |= 1 << right_index
            right_masks[right_index] |= 1 << left_index
        directed_conflict_masks[(left_group, right_group)] = left_masks
        directed_conflict_masks[(right_group, left_group)] = right_masks

    def candidate_index(group_id: tuple[str, int], candidate: dict[str, Any]) -> int:
        return domain_indexes[group_id][id(candidate)]

    def candidates_conflict(
        left_group: tuple[str, int],
        left_candidate: dict[str, Any],
        right_group: tuple[str, int],
        right_candidate: dict[str, Any],
    ) -> bool:
        if left_group == right_group:
            return left_candidate is not right_candidate
        if not groups_conflict(left_group, right_group):
            return False
        if left_group < right_group:
            pair = (candidate_index(left_group, left_candidate), candidate_index(right_group, right_candidate))
            return pair in overlap_matrices[(left_group, right_group)]
        pair = (candidate_index(right_group, right_candidate), candidate_index(left_group, left_candidate))
        return pair in overlap_matrices[(right_group, left_group)]

    route_family_pairs: list[
        list[tuple[int, int, tuple[tuple[float, float, float, float], ...]]]
    ] = []
    for family in route_families:
        left_group = family["left_group"]
        right_group = family["right_group"]
        placement_class = str(family["placement_class"])
        pairs: list[tuple[int, int, tuple[tuple[float, float, float, float], ...]]] = []
        for left_index, left_candidate in enumerate(group_domains[left_group]):
            for right_index, right_candidate in enumerate(group_domains[right_group]):
                if left_candidate["contact"] == right_candidate["contact"]:
                    continue
                if candidates_conflict(left_group, left_candidate, right_group, right_candidate):
                    continue
                sweeps = tuple(route_sweep_rects(left_candidate, right_candidate, placement_class))
                if not sweeps or any(
                    intersects(sweep, occupied_rect)
                    for sweep in sweeps
                    for occupied_rect in permanent_hits
                ):
                    continue
                pairs.append((left_index, right_index, sweeps))
        route_family_pairs.append(pairs)

    route_pair_blocker_support_masks: dict[
        tuple[int, int, tuple[str, int]],
        int,
    ] = {}

    def route_pair_blocker_support_mask(
        family_index: int,
        pair_index: int,
        blocker_group: tuple[str, int],
    ) -> int:
        """Return blocker candidates compatible with this exact route pair.

        A route pair is a compound value: one candidate for each endpoint plus
        the exact body-width sweep produced by the runtime lane projection.
        Cache its support against every possible blocker so propagation can use
        bit operations instead of rediscovering the same intersections at each
        search node.
        """
        cache_key = (family_index, pair_index, blocker_group)
        cached = route_pair_blocker_support_masks.get(cache_key)
        if cached is not None:
            return cached
        family = route_families[family_index]
        left_group = family["left_group"]
        right_group = family["right_group"]
        left_index, right_index, sweeps = route_family_pairs[family_index][pair_index]
        support = (1 << len(group_domains[blocker_group])) - 1
        if blocker_group != left_group:
            support &= ~directed_conflict_masks[(left_group, blocker_group)][left_index]
        if blocker_group != right_group:
            support &= ~directed_conflict_masks[(right_group, blocker_group)][right_index]
        remaining = support
        while remaining:
            bit = remaining & -remaining
            blocker_index = bit.bit_length() - 1
            blocker_hit = reservation(group_domains[blocker_group][blocker_index]["rect"])
            if any(intersects(sweep, blocker_hit) for sweep in sweeps):
                support &= ~bit
            remaining &= remaining - 1
        route_pair_blocker_support_masks[cache_key] = support
        return support

    def candidate_consistent(group_id: tuple[str, int], candidate: dict[str, Any]) -> bool:
        if candidate_index(group_id, candidate) in permanent_blocked[group_id]:
            return False
        for other_group, other_candidate in assignments.items():
            if candidates_conflict(group_id, candidate, other_group, other_candidate):
                return False
        candidate_hit = reservation(candidate["rect"])
        for family in route_families:
            left_group = family["left_group"]
            right_group = family["right_group"]
            if group_id in {left_group, right_group} \
                    or group_id not in family["blockers"] \
                    or left_group not in assignments \
                    or right_group not in assignments:
                continue
            sweeps = route_sweep_rects(
                assignments[left_group],
                assignments[right_group],
                str(family["placement_class"]),
            )
            if any(intersects(sweep, candidate_hit) for sweep in sweeps):
                return False
        return True

    route_sweep_cache: dict[tuple[int, int, int], list[tuple[float, float, float, float]]] = {}
    last_route_diagnostic = ""

    def cached_route_sweeps(
        relation_index: int,
        start_candidate: dict[str, Any],
        end_candidate: dict[str, Any],
        placement_class: str,
    ) -> list[tuple[float, float, float, float]]:
        cache_key = (relation_index, id(start_candidate), id(end_candidate))
        if cache_key not in route_sweep_cache:
            route_sweep_cache[cache_key] = route_sweep_rects(start_candidate, end_candidate, placement_class)
        return route_sweep_cache[cache_key]

    def routes_have_support() -> bool:
        nonlocal last_route_diagnostic
        for relation_index, (start_group, end_group, placement_class, _start_key, _end_key) in enumerate(route_relations):
            start_domain = [assignments[start_group]] if start_group in assignments else group_domains[start_group]
            end_domain = [assignments[end_group]] if end_group in assignments else group_domains[end_group]
            supported = False
            considered = 0
            geometry_blocked = 0
            permanent_sweep_blocked = 0
            assigned_sweep_blocked = 0
            for start_candidate in start_domain:
                if start_group not in assignments and not candidate_consistent(start_group, start_candidate):
                    continue
                for end_candidate in end_domain:
                    considered += 1
                    if start_candidate["contact"] == end_candidate["contact"]:
                        continue
                    if end_group not in assignments and not candidate_consistent(end_group, end_candidate):
                        continue
                    if candidates_conflict(start_group, start_candidate, end_group, end_candidate):
                        geometry_blocked += 1
                        continue
                    sweeps = cached_route_sweeps(
                        relation_index,
                        start_candidate,
                        end_candidate,
                        placement_class,
                    )
                    if any(
                        intersects(sweep, occupied_rect)
                        for sweep in sweeps
                        for occupied_rect in permanent_hits
                    ):
                        permanent_sweep_blocked += 1
                        continue
                    blocked = False
                    for other_group, other_candidate in assignments.items():
                        if other_group in {start_group, end_group}:
                            continue
                        if other_group not in route_blocker_groups[relation_index]:
                            continue
                        if any(intersects(sweep, reservation(other_candidate["rect"])) for sweep in sweeps):
                            blocked = True
                            break
                    if not blocked:
                        supported = True
                        break
                    assigned_sweep_blocked += 1
                if supported:
                    break
            if not supported:
                last_route_diagnostic = (
                    f"relation={start_group}->{end_group}/{placement_class} "
                    f"pairs={considered} geometry={geometry_blocked} "
                    f"permanent_sweep={permanent_sweep_blocked} "
                    f"assigned_sweep={assigned_sweep_blocked}"
                )
                return False
        return True

    search_nodes = 0

    def solve_stage_component(component: set[tuple[str, int]]) -> bool:
        nonlocal search_nodes
        search_nodes += 1
        if search_nodes > 10000:
            return False
        if all(group_id in assignments for group_id in component):
            return routes_have_support()
        viable_masks: dict[tuple[str, int], int] = {}
        for group_id in component:
            if group_id in assignments:
                continue
            mask = 0
            for index, candidate in enumerate(group_domains[group_id]):
                if candidate_consistent(group_id, candidate):
                    mask |= 1 << index
            if mask == 0:
                return False
            viable_masks[group_id] = mask

        def active_mask(group_id: tuple[str, int]) -> int:
            if group_id in assignments:
                return 1 << candidate_index(group_id, assignments[group_id])
            return viable_masks.get(group_id, 0)

        def revise_geometry_arcs() -> tuple[bool, bool]:
            changed = False
            queue = [
                (left_group, right_group)
                for left_group in viable_masks
                for right_group in viable_masks
                if left_group != right_group and groups_conflict(left_group, right_group)
            ]
            while queue:
                left_group, right_group = queue.pop()
                left_mask = viable_masks[left_group]
                right_mask = viable_masks[right_group]
                revised_mask = left_mask
                candidate_mask = left_mask
                conflict_rows = directed_conflict_masks[(left_group, right_group)]
                while candidate_mask:
                    bit = candidate_mask & -candidate_mask
                    left_index = bit.bit_length() - 1
                    if right_mask & ~conflict_rows[left_index] == 0:
                        revised_mask &= ~bit
                    candidate_mask &= candidate_mask - 1
                if revised_mask == left_mask:
                    continue
                if revised_mask == 0:
                    return False, changed
                viable_masks[left_group] = revised_mask
                changed = True
                for neighbor in viable_masks:
                    if neighbor != left_group and neighbor != right_group and groups_conflict(neighbor, left_group):
                        queue.append((neighbor, left_group))
            return True, changed

        # Alternate ordinary rectangle AC-3 with generalized arc consistency
        # for each compound route family.  A surviving route pair must have one
        # *same* blocker candidate compatible with both endpoints and the full
        # runtime-equivalent body sweep; separate endpoint supports are not a
        # valid proof of a traversable route.
        active_family_pairs: dict[int, list[int]] = {}
        while True:
            geometry_ok, propagation_changed = revise_geometry_arcs()
            if not geometry_ok:
                return False
            for family_index, family in enumerate(route_families):
                left_group = family["left_group"]
                right_group = family["right_group"]
                left_mask = active_mask(left_group)
                right_mask = active_mask(right_group)
                if left_mask == 0 or right_mask == 0:
                    return False
                supported_pairs: list[int] = []
                for pair_index, (left_index, right_index, _sweeps) in enumerate(route_family_pairs[family_index]):
                    if not left_mask & (1 << left_index) or not right_mask & (1 << right_index):
                        continue
                    pair_supported = True
                    for blocker_group in family["blockers"]:
                        blocker_mask = active_mask(blocker_group)
                        if blocker_mask == 0 or route_pair_blocker_support_mask(
                            family_index,
                            pair_index,
                            blocker_group,
                        ) & blocker_mask == 0:
                            pair_supported = False
                            break
                    if pair_supported:
                        supported_pairs.append(pair_index)
                if not supported_pairs:
                    return False
                active_family_pairs[family_index] = supported_pairs

                if left_group in viable_masks:
                    supported_left = 0
                    for pair_index in supported_pairs:
                        supported_left |= 1 << route_family_pairs[family_index][pair_index][0]
                    revised = viable_masks[left_group] & supported_left
                    if revised == 0:
                        return False
                    if revised != viable_masks[left_group]:
                        viable_masks[left_group] = revised
                        propagation_changed = True
                if right_group in viable_masks:
                    supported_right = 0
                    for pair_index in supported_pairs:
                        supported_right |= 1 << route_family_pairs[family_index][pair_index][1]
                    revised = viable_masks[right_group] & supported_right
                    if revised == 0:
                        return False
                    if revised != viable_masks[right_group]:
                        viable_masks[right_group] = revised
                        propagation_changed = True
                for blocker_group in family["blockers"]:
                    if blocker_group not in viable_masks:
                        continue
                    supported_blockers = 0
                    for pair_index in supported_pairs:
                        supported_blockers |= route_pair_blocker_support_mask(
                            family_index,
                            pair_index,
                            blocker_group,
                        )
                    revised = viable_masks[blocker_group] & supported_blockers
                    if revised == 0:
                        return False
                    if revised != viable_masks[blocker_group]:
                        viable_masks[blocker_group] = revised
                        propagation_changed = True
            if not propagation_changed:
                break

        viable_by_group: dict[tuple[str, int], list[dict[str, Any]]] = {
            group_id: [
                candidate
                for index, candidate in enumerate(group_domains[group_id])
                if mask & (1 << index)
            ]
            for group_id, mask in viable_masks.items()
        }

        def group_rank(group_id: tuple[str, int]) -> tuple[int, int, int, str, int]:
            keys = group_rows[group_id]["keys"]
            routed = any(key in synthetic_route_keys for key in keys) or any(
                group_id in relation[:2] for relation in route_relations
            )
            degree = sum(1 for other in group_rows if other != group_id and groups_connected(group_id, other))
            # Establish swept-route endpoint authority before packing unrelated
            # records; otherwise many locally good slots can collectively seal
            # the only body-width corridor and force deep late backtracking.
            return (0 if routed else 1, len(viable_by_group[group_id]), -degree, group_id[0], group_id[1])

        unresolved_families = [
            family_index
            for family_index, family in enumerate(route_families)
            if family["left_group"] not in assignments or family["right_group"] not in assignments
        ]
        if unresolved_families:
            family_index = min(
                unresolved_families,
                key=lambda index: (len(active_family_pairs[index]), index),
            )
            family = route_families[family_index]
            left_group = family["left_group"]
            right_group = family["right_group"]

            def route_pair_rank(pair_index: int) -> tuple[int, int, int, int, tuple[float, ...], tuple[float, ...]]:
                left_index, right_index, _sweeps = route_family_pairs[family_index][pair_index]
                exhausted = 0
                blocked_total = 0
                for other_group, other_mask in viable_masks.items():
                    if other_group in {left_group, right_group}:
                        continue
                    supported = other_mask
                    supported &= ~directed_conflict_masks[(left_group, other_group)][left_index]
                    supported &= ~directed_conflict_masks[(right_group, other_group)][right_index]
                    if other_group in family["blockers"]:
                        supported &= route_pair_blocker_support_mask(
                            family_index,
                            pair_index,
                            other_group,
                        )
                    blocked = other_mask.bit_count() - supported.bit_count()
                    blocked_total += blocked
                    if supported == 0:
                        exhausted += 1
                return (
                    exhausted,
                    blocked_total,
                    left_index,
                    right_index,
                    group_domains[left_group][left_index]["key"],
                    group_domains[right_group][right_index]["key"],
                )

            for pair_index in sorted(active_family_pairs[family_index], key=route_pair_rank):
                left_index, right_index, _sweeps = route_family_pairs[family_index][pair_index]
                newly_assigned: list[tuple[str, int]] = []
                if left_group not in assignments:
                    assignments[left_group] = group_domains[left_group][left_index]
                    newly_assigned.append(left_group)
                if right_group not in assignments:
                    assignments[right_group] = group_domains[right_group][right_index]
                    newly_assigned.append(right_group)
                if solve_stage_component(component):
                    return True
                for group_id in newly_assigned:
                    del assignments[group_id]
            return False

        selected = min(viable_by_group, key=group_rank)

        def value_rank(candidate: dict[str, Any]) -> tuple[int, int, int, tuple[float, ...]]:
            authored_rank = group_domains[selected].index(candidate)
            exhausted = 0
            blocked_total = 0
            for other_group, other_domain in viable_by_group.items():
                if other_group == selected or not groups_conflict(selected, other_group):
                    continue
                blocked = sum(
                    candidates_conflict(selected, candidate, other_group, other_candidate)
                    for other_candidate in other_domain
                )
                blocked_total += blocked
                if blocked == len(other_domain):
                    exhausted += 1
            return (
                exhausted,
                blocked_total,
                authored_rank,
                candidate["key"],
            )

        for candidate in sorted(viable_by_group[selected], key=value_rank):
            assignments[selected] = candidate
            if solve_stage_component(component):
                return True
            del assignments[selected]
        return False

    remaining_groups = set(group_rows)
    components: list[set[tuple[str, int]]] = []
    while remaining_groups:
        seed = min(remaining_groups)
        component = {seed}
        frontier = [seed]
        remaining_groups.remove(seed)
        while frontier:
            current = frontier.pop()
            connected = {
                other
                for other in remaining_groups
                if groups_connected(current, other)
            }
            component.update(connected)
            frontier.extend(sorted(connected))
            remaining_groups.difference_update(connected)
        components.append(component)
    components.sort(key=lambda component: (len(component), sorted(component)))
    failed_component: set[tuple[str, int]] = set()
    solved_stage_groups = True
    for component in components:
        search_nodes = 0
        before = set(assignments)
        if not solve_stage_component(component):
            for group_id in set(assignments) - before:
                del assignments[group_id]
            failed_component = component
            solved_stage_groups = False
            break
    if not solved_stage_groups:
        unresolved = sorted(group_id for group_id in group_rows if group_id not in assignments)
        raise ValueError(
            f"{map_data.get('id')}: no fixed-slot solution after {search_nodes} nodes; "
            f"component={sorted(failed_component)} "
            f"domains={[(group_id, len(group_domains[group_id])) for group_id in sorted(failed_component)]} "
            f"unresolved={unresolved} base={[(slot['id'], slot['hit_rect']) for slot in base_slots]} "
            f"exits={[(slot['id'], slot['hit_rect']) for slot in exit_slots]} "
            f"route={last_route_diagnostic} "
            f"route_relations={[(relation[3], relation[4], sorted(route_blocker_groups[index])) for index, relation in enumerate(route_relations)]}"
        )
    for (placement_class, color), candidate in sorted(assignments.items()):
        group = group_rows[(placement_class, color)]
        if str(group.get("kind", "stage")) != "base":
            continue
        ordinal = int(group.get("ordinal", -color))
        base_slots.append(make_slot(
            f"base.{placement_class}.{ordinal:02d}",
            "base",
            placement_class,
            candidate,
            ordinal * 10,
            zones,
        ))
    for (placement_class, color), candidate in sorted(assignments.items()):
        group = group_rows[(placement_class, color)]
        if str(group.get("kind", "stage")) != "exit":
            continue
        exit_color = int(group.get("exit_color", 0))
        exit_slots.append(make_slot(
            f"exit.doorway.{exit_color + 1:02d}",
            "exit",
            "doorway",
            candidate,
            (exit_color + 1) * 10,
            zones,
        ))
    exit_slots.sort(key=lambda slot: (int(slot.get("priority", 0)), str(slot.get("id", ""))))
    if deferred_base_specs:
        base_by_class = {
            placement_class: sorted(
                (slot for slot in base_slots if slot["footprint_class"] == placement_class),
                key=lambda slot: (int(slot.get("priority", 0)), str(slot.get("id", ""))),
            )
            for placement_class in CLASSES
        }
        deferred_classes = {str(spec["placement_class"]) for spec in deferred_base_specs}
        for placement_class in deferred_classes:
            slots = base_by_class[placement_class]
            used: set[str] = set()
            for identity, wanted in base_desires[placement_class]:
                if identity.startswith(tuple(CATEGORY_CLASS.keys())) or not slots:
                    continue
                choices = [slot for slot in slots if str(slot["id"]) not in used] or slots
                selected = min(choices, key=lambda slot: (slot_distance(slot, wanted), slot["priority"], slot["id"]))
                object_slot_ids[identity] = str(selected["id"])
                used.add(str(selected["id"]))
            category_used = set()
            for field_name, index, category_class, wanted in category_desires:
                if category_class != placement_class or not slots:
                    continue
                choices = [slot for slot in slots if str(slot["id"]) not in category_used] or slots
                selected = min(choices, key=lambda slot: (slot_distance(slot, wanted), slot["priority"], slot["id"]))
                category_slot_ids[f"{field_name}:{index}"] = str(selected["id"])
                category_used.add(str(selected["id"]))
        if map_data.get("id") == "pawn_shop":
            shelf_slots = base_by_class["surface_item"][:6]
            for index, slot in enumerate(shelf_slots):
                # The serialized shelf inventory and its late meta interaction
                # are one physical object and intentionally share one slot.
                object_slot_ids[f"item:sal_shelf_{index}"] = str(slot["id"])
                object_slot_ids[f"meta_sal_shelf:{index}"] = str(slot["id"])
            counter_slots = base_by_class["behind_counter_person"]
            if len(counter_slots) >= 2:
                object_slot_ids["shopkeeper:merchant"] = str(counter_slots[0]["id"])
                object_slot_ids["meta_pawn_counter:sell"] = str(counter_slots[1]["id"])
    stage_slots: list[dict[str, Any]] = []
    if solved_stage_groups:
        for (placement_class, color), candidate in sorted(assignments.items()):
            if str(group_rows[(placement_class, color)].get("kind", "stage")) != "stage":
                continue
            stage_slots.append(make_slot(
                f"stage.{placement_class}.{color + 1:02d}",
                "stage",
                placement_class,
                candidate,
                (color + 1) * 10,
                zones,
            ))

    stage_by_class = {
        placement_class: sorted(
            (slot for slot in stage_slots if slot["footprint_class"] == placement_class),
            key=lambda slot: (int(slot.get("priority", 0)), str(slot.get("id", ""))),
        )
        for placement_class in CLASSES
    }
    scenario_slot_ids: dict[str, str] = {}
    preference_classes: dict[str, set[str]] = {}
    for state in states.values():
        preference_key = str(state.get("preference_key", ""))
        if preference_key:
            preference_classes.setdefault(preference_key, set()).add(str(state.get("placement_class", "")))
    for key, state in sorted(states.items()):
        class_slots = stage_by_class[state["placement_class"]]
        color = colors.get(key, -1)
        if 0 <= color < len(class_slots):
            slot_id = str(class_slots[color]["id"])
            preference_key = str(state.get("preference_key", ""))
            if preference_key and len(preference_classes.get(preference_key, set())) == 1:
                scenario_slot_ids[preference_key] = slot_id

    # Safe exits use their own immutable pool and still receive exact stable and
    # position-state preferences. Two concurrently active exits receive distinct
    # colors; different scenarios may safely share the same authored doorway.
    for key, state in sorted(exit_states.items()):
        color = exit_colors.get(key, -1)
        if 0 <= color < len(exit_slots):
            slot_id = str(exit_slots[color]["id"])
            scenario_slot_ids[key] = slot_id

    actor_routes: list[dict[str, Any]] = []
    for route_id, (start_key, end_key) in sorted(authored_route_states.items()):
        start_state = states.get(start_key, {})
        placement_class = str(start_state.get("placement_class", ""))
        class_slots = stage_by_class.get(placement_class, [])
        start_color = colors.get(start_key, -1)
        end_color = colors.get(end_key, -1)
        if not (0 <= start_color < len(class_slots) and 0 <= end_color < len(class_slots)):
            continue
        start_id = str(class_slots[start_color]["id"])
        end_id = str(class_slots[end_color]["id"])
        if not start_id or not end_id or start_id == end_id:
            continue
        actor_routes.append({
            "id": route_id,
            "footprint_class": placement_class,
            "start_slot_id": start_id,
            "end_slot_id": end_id,
            "lane_ids": ["lane.public"],
            "motion": "to_endpoint",
            "reduced_motion_slot_id": end_id,
        })
    scenario_position_route_ids: dict[str, str] = {}
    for target_key, (from_key, _to_key) in sorted(movements.items()):
        start_id = str(scenario_slot_ids.get(from_key, ""))
        end_id = str(scenario_slot_ids.get(target_key, ""))
        placement_class = str(states.get(target_key, {}).get("placement_class", ""))
        if not start_id or not end_id or start_id == end_id:
            continue
        digest = hashlib.sha256(target_key.encode("utf-8")).hexdigest()[:16]
        route_id = f"position::{digest}"
        actor_routes.append({
            "id": route_id,
            "footprint_class": placement_class,
            "start_slot_id": start_id,
            "end_slot_id": end_id,
            "lane_ids": ["lane.public"],
            "motion": "to_endpoint",
            "reduced_motion_slot_id": end_id,
        })
        preference_key = str(states.get(target_key, {}).get("preference_key", target_key))
        if preference_key:
            scenario_position_route_ids[preference_key] = route_id

    map_data["slot_schema_version"] = 1
    map_data["base_slots"] = base_slots
    map_data["stage_slots"] = stage_slots
    map_data["exit_slots"] = exit_slots
    map_data["walk_lanes"] = walk_lanes
    map_data["actor_routes"] = actor_routes
    map_data["object_slot_ids"] = object_slot_ids
    map_data["category_slot_ids"] = category_slot_ids
    map_data["scenario_slot_ids"] = scenario_slot_ids
    map_data["scenario_position_route_ids"] = scenario_position_route_ids


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--only-map", default="", help="diagnose one map without writing generated data")
    args = parser.parse_args()
    root = args.root.resolve()
    surface_path = root / "data/environments/placement_surfaces.json"
    surface_root = json.loads(surface_path.read_text(encoding="utf-8"))
    archetypes_list = json.loads((root / "data/environments/archetypes.json").read_text(encoding="utf-8"))
    archetypes = {str(item.get("id", "")): item for item in archetypes_list if isinstance(item, dict)}
    semantics = collect_semantics(root)
    base_semantics = collect_base_semantics(root)
    phase_snapshots = collect_active_phase_snapshots(root)
    generated = copy.deepcopy(surface_root)
    generated["schema_version"] = 2
    generated["slot_schema_version"] = 1
    for map_data in generated.get("maps", []):
        if isinstance(map_data, dict):
            if args.only_map and str(map_data.get("id", "")) != args.only_map:
                continue
            print(f"RW06_1 authoring {map_data.get('id', '<missing>')}", flush=True)
            map_id = str(map_data.get("id", ""))
            author_map(map_data, archetype_for_map(map_id, archetypes), semantics, base_semantics, phase_snapshots.get(map_id, []))
    if args.only_map:
        print(f"RW06_1_FIXED_SLOT_AUTHORING MAP PASS {args.only_map}")
        return 0
    encoded = json.dumps(generated, indent=2, ensure_ascii=False) + "\n"
    if args.check:
        current = json.dumps(surface_root, indent=2, ensure_ascii=False) + "\n"
        if encoded != current:
            raise SystemExit("placement_surfaces.json fixed-slot data is stale; run tools/rw06_1_author_fixed_slots.py")
        print("RW06_1_FIXED_SLOT_AUTHORING_CHECK PASS")
        return 0
    surface_path.write_text(encoded, encoding="utf-8", newline="\n")
    print(f"RW06_1_FIXED_SLOT_AUTHORING PASS maps={len(generated.get('maps', []))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
