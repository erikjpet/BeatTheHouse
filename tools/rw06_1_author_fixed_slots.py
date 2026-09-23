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
import json
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
    "standing_person": 2,
    "behind_counter_person": 2,
    "seated_person": 1,
    "group": 1,
    "floor_fixture": 3,
    "ground_marker": 1,
    "surface_item": 4,
    "wall_mounted": 2,
    "hanging": 1,
    "doorway": 3,
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
STAGE_BUDGET_MAX = 18

COUNTER_PERSON_TOKENS = ("bartender", "cashier", "clerk", "dealer", "shopkeeper", "staff", "teller", "vendor")
PERSON_TOKENS = ("actor", "bouncer", "captain", "crew", "driver", "guard", "host", "landlord", "mate", "observer", "patron", "person", "regular", "runner", "staff")
SEATED_TOKENS = ("audience", "booth", "chair", "seated", "stool")
GROUP_TOKENS = ("crowd", "drivers", "group", "sheltering", "the crew")
WALL_TOKENS = ("board", "bracket", "calendar", "camera", "clock", "easel", "gauge", "lamp", "menu", "notice", "panel", "poster", "scoreboard", "screen", "seal", "sign", "signal")
HANGING_TOKENS = ("banner", "hanging", "speaker rig", "string light")
DOOR_TOKENS = ("door", "exit", "gangway", "leave")
GROUND_TOKENS = ("chalk", "lane", "mark", "spill", "tape")
SURFACE_TOKENS = ("basket", "card", "case", "desk", "drink", "glass", "item", "ledger", "manifest", "note", "provenance", "table", "ticket", "tray", "watch")

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
    hit = expanded(bounds)
    label_w = max(88.0, min(132.0, bounds[2] + 24.0))
    label = (max(0.0, min(BOARD_W - label_w, bounds[0] + bounds[2] / 2.0 - label_w / 2.0)), max(0.0, bounds[1] - 24.0), label_w, 20.0)
    x0 = min(hit[0], label[0])
    y0 = min(hit[1], label[1])
    x1 = max(hit[0] + hit[2], label[0] + label[2])
    y1 = max(hit[1] + hit[3], label[1] + label[3])
    return (x0, y0, x1 - x0, y1 - y0)


def tokens(text: str, wanted: Iterable[str]) -> bool:
    clean = " " + text.lower() + " "
    for separator in "_:-/.,;()[]":
        clean = clean.replace(separator, " ")
    clean = " ".join(clean.split())
    return any(f" {token.replace('_', ' ').lower().strip()} " in f" {clean} " for token in wanted)


def classify(data: dict[str, Any], object_type: str, object_id: str, override: str = "") -> str:
    explicit = str(data.get("placement_class", override)).strip()
    if explicit in CLASSES:
        return explicit
    clean_type = object_type.strip().lower()
    clean_prop = str(data.get("visual_prop", data.get("environment_prop", data.get("prop", "")))).strip().lower()
    role = str(data.get("role", "")).strip().lower()
    person_text = " ".join(str(data.get(key, "")) for key in ("actor_id", "character_id", "npc_id", "speaker_id", "role", "pose", "appearance")) + " " + object_id + " " + clean_prop
    person_object = clean_type in {"actor", "character", "lender", "merchant", "npc", "scenario_actor", "shopkeeper", "numbers_silas"} or role in {"bartender", "casino_host", "clerk", "dealer", "guard", "host", "lender", "merchant", "musician", "patron", "person", "pit_boss", "shopkeeper", "staff", "teller", "vendor"} or any(str(data.get(key, "")).strip() for key in ("actor_id", "character_id", "npc_id", "speaker_id"))
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
    if role in {"task_station", "display", "notice", "sign", "wall"}:
        return "wall_mounted"
    if role in {"route_marker", "ground_marker"}:
        return "ground_marker"
    if role in {"vehicle", "obstacle", "barrier", "blockade", "utility", "furniture", "game_station"}:
        return "floor_fixture"
    if clean_type in {"travel", "layer", "casino_door"} or tokens(text, DOOR_TOKENS):
        return "doorway"
    if tokens(text, HANGING_TOKENS):
        return "hanging"
    if tokens(text, GROUND_TOKENS):
        return "ground_marker"
    if tokens(text, WALL_TOKENS):
        return "wall_mounted"
    if tokens(text, SURFACE_TOKENS) or role in {"arrangement", "evidence", "refreshment"}:
        return "surface_item"
    if clean_type in {"lender", "numbers_silas"}:
        return "standing_person"
    if clean_type == "shopkeeper":
        return "behind_counter_person"
    if clean_type in {"game", "game_hook"}:
        return "floor_fixture" if tokens(text, ("coin pusher", "pull tab", "scratch ticket", "slot", "video poker")) else "surface_item"
    if clean_type in {"item", "drink", "numbers", "service"}:
        return "surface_item"
    return "floor_fixture"


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
                payload = value.get("data")
                if isinstance(payload, dict):
                    target.update({key: item for key, item in payload.items() if not isinstance(item, (list, dict))})
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    for source in sorted((root / "data/environments/scenario_sequences").glob("*.json")):
        visit(json.loads(source.read_text(encoding="utf-8")))
    return result


def _phase_operations(container: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for field in ("scene_ops", "actor_ops", "interaction_ops"):
        result.extend(item for item in values(container.get(field)) if isinstance(item, dict))
    result.extend(item for item in values(container.get("operations")) if isinstance(item, dict))
    return result


def _apply_phase_operations(
    state: tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]],
    container: dict[str, Any],
) -> None:
    visuals, interactions = state
    for operation in _phase_operations(container):
        family = str(operation.get("family", ""))
        verb = str(operation.get("op", ""))
        owner = str(operation.get("owner_namespace", "scenario"))
        stable_id = str(operation.get("stable_object_id", ""))
        identity = f"{owner}::{stable_id}"
        if not stable_id:
            continue
        if family in {"scene_ops", "actor_ops"}:
            if verb in {"remove", "despawn"}:
                visuals.pop(identity, None)
                continue
            if verb == "spawn":
                payload_field = "actor" if family == "actor_ops" else "object"
                payload = copy.deepcopy(operation.get(payload_field, {})) if isinstance(operation.get(payload_field), dict) else {}
                for field in ("owner_namespace", "stable_object_id", "zone_id", "anchor_id"):
                    if field in operation:
                        payload[field] = operation[field]
                payload["_slot_actor"] = family == "actor_ops"
                payload["_slot_hidden"] = False
                visuals[identity] = payload
                continue
            if identity not in visuals:
                continue
            if verb == "hide":
                visuals[identity]["_slot_hidden"] = True
            elif verb == "reveal":
                visuals[identity]["_slot_hidden"] = False
            else:
                for field, value in operation.items():
                    if field not in {"family", "op", "receipt_id"}:
                        visuals[identity][field] = copy.deepcopy(value)
        elif family == "interaction_ops":
            if verb == "remove":
                interactions.pop(identity, None)
            elif verb == "add":
                payload = copy.deepcopy(operation.get("interaction", {})) if isinstance(operation.get("interaction"), dict) else {}
                payload["owner_namespace"] = owner
                payload["stable_object_id"] = stable_id
                interactions[identity] = payload


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
                state: tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]],
            ) -> None:
                snapshot: list[dict[str, Any]] = []
                for identity, semantic in sorted(state[0].items()):
                    entry = copy.deepcopy(semantic)
                    entry["identity"] = identity
                    entry["_slot_scenario_id"] = scenario_id
                    entry["_slot_phase_id"] = phase_id
                    entry["_slot_interaction"] = copy.deepcopy(state[1].get(identity, {}))
                    entry["safe_exit"] = bool(entry["_slot_interaction"].get("safe_exit", False))
                    snapshot.append(entry)
                for identity, interaction in sorted(state[1].items()):
                    if identity in state[0]:
                        continue
                    snapshot.append({
                        "identity": identity,
                        "_slot_scenario_id": scenario_id,
                        "_slot_phase_id": phase_id,
                        "_slot_interaction": copy.deepcopy(interaction),
                        "_slot_interaction_only": True,
                        "safe_exit": bool(interaction.get("safe_exit", False)),
                    })
                result.setdefault(map_id, []).append(snapshot)

            def walk(
                phase_id: str,
                state: tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]],
                path: tuple[str, ...],
            ) -> None:
                if phase_id in path or phase_id not in phases:
                    return
                next_state = (copy.deepcopy(state[0]), copy.deepcopy(state[1]))
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
                        aftermath_state = (copy.deepcopy(next_state[0]), copy.deepcopy(next_state[1]))
                        cleanup = sequence.get("cleanup", {}) if isinstance(sequence.get("cleanup"), dict) else {}
                        aftermaths = sequence.get("aftermath", {}) if isinstance(sequence.get("aftermath"), dict) else {}
                        _apply_phase_operations(aftermath_state, cleanup)
                        aftermath = aftermaths.get(outcome, {}) if isinstance(aftermaths.get(outcome), dict) else {}
                        _apply_phase_operations(aftermath_state, aftermath)
                        append_snapshot(f"aftermath:{outcome}", aftermath_state)

            walk(str(phase_graph.get("initial_phase", "")), ({}, {}), ())
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
            if bool(semantic.get("_slot_interaction_only", False)):
                continue
            if bool(semantic.get("_slot_hidden", False)):
                continue
            if bool(semantic.get("safe_exit", False)):
                continue
            identity = str(semantic.get("identity", ""))
            stable_id = identity.removeprefix("scenario::")
            object_type = "actor" if bool(semantic.get("_slot_actor", False)) else "scene_object"
            placement_class = classify(
                semantic,
                object_type,
                identity,
                str(class_overrides.get(identity, class_overrides.get(stable_id, ""))),
            )
            demand[placement_class] += 1
            if str(semantic.get("route_id", "")):
                # A routed actor reserves a distinct authored endpoint too.
                demand[placement_class] += 1
                route_actor_present = True
        demands.append(demand)
        maximum_active = max(maximum_active, sum(demand.values()))
    # Author the full small-room budget.  Different common scenarios in the
    # same room stress different footprint classes; stopping at one phase's
    # peak count made a room look capacious in aggregate while overflowing a
    # common composition whose classes differed from the plurality.
    budget = STAGE_BUDGET_MAX
    allocated = {placement_class: 0 for placement_class in CLASSES}
    if route_actor_present:
        allocated["standing_person"] = 2
    while sum(allocated.values()) < budget:
        gains = {
            placement_class: sum(1 for demand in demands if demand[placement_class] > allocated[placement_class])
            for placement_class in CLASSES
        }
        best = max(CLASSES, key=lambda placement_class: (gains[placement_class], -CLASSES.index(placement_class)))
        if gains[best] <= 0:
            break
        allocated[best] += 1
    return {placement_class: count for placement_class, count in allocated.items() if count > 0}


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
                cursor = max_y - height - 26.0
                while cursor >= min_y:
                    y_values.append(cursor)
                    cursor -= height + 26.0
                for contact_y in y_values:
                    cursor_x = x + width / 2.0
                    while cursor_x <= x + w - width / 2.0 + 0.01:
                        add((cursor_x, contact_y), support_id)
                        cursor_x += width + 28.0
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
                cursor_x += width + 24.0
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
                    cursor_x += width + 28.0
                cursor_y += height + 24.0
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
                cursor_y += height + 24.0
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
    phase_snapshots: list[list[dict[str, Any]]],
) -> None:
    zones = copy.deepcopy(archetype.get("semantic_zones", {})) if isinstance(archetype.get("semantic_zones"), dict) else {}
    class_overrides = map_data.get("class_overrides", {}) if isinstance(map_data.get("class_overrides"), dict) else {}
    occupied: list[tuple[float, float, float, float]] = []
    pools = {placement_class: support_candidates(map_data, placement_class) for placement_class in CLASSES}

    def take(kind: str, placement_class: str, wanted: tuple[float, float] | None, prefix: str, ordinal: int) -> dict[str, Any] | None:
        for candidate in nearest(pools[placement_class], wanted):
            reserve = reservation(candidate["rect"])
            if any(intersects(reserve, other) for other in occupied):
                continue
            occupied.append(reserve)
            return make_slot(f"{prefix}.{placement_class}.{ordinal:02d}", kind, placement_class, candidate, ordinal * 10, zones)
        return None

    exit_slots: list[dict[str, Any]] = []
    for ordinal in range(1, 3):
        doorway_candidates = sorted(pools["doorway"], key=lambda item: (min(item["contact"][0], BOARD_W - item["contact"][0]), item["contact"][1], item["contact"][0]))
        selected = None
        for candidate in doorway_candidates:
            reserve = reservation(candidate["rect"])
            if not any(intersects(reserve, other) for other in occupied):
                occupied.append(reserve)
                selected = make_slot(f"exit.doorway.{ordinal:02d}", "exit", "doorway", candidate, ordinal * 10, zones)
                break
        if selected is not None:
            exit_slots.append(selected)

    scenario_positions = map_data.get("scenario_object_slot_positions", {}) if isinstance(map_data.get("scenario_object_slot_positions"), dict) else {}
    scenario_desires: dict[str, list[tuple[str, tuple[float, float] | None]]] = {key: [] for key in CLASSES}
    for stable_id, raw_position in sorted(scenario_positions.items()):
        semantic = semantics.get(str(stable_id), {})
        object_type = "actor" if any(key in semantic for key in ("actor_id", "character_id")) or str(semantic.get("family", "")) == "actor_ops" else "scene_object"
        placement_class = classify(semantic, object_type, str(stable_id), str(class_overrides.get(stable_id, class_overrides.get(f"scenario::{stable_id}", ""))))
        if placement_class == "doorway" and str(stable_id).endswith("_safe_exit"):
            continue
        scenario_desires[placement_class].append((str(stable_id), desired_rect_top_left(raw_position, placement_class)))

    stage_slots: list[dict[str, Any]] = []
    # Tune the immutable stage inventory from actual reachable phase snapshots,
    # not from the union of every visual mentioned anywhere in the scenario.
    # Stage slots are reserved before base inventory so common active phases fit;
    # both families still use the same disjoint reservation authority.
    stage_targets = stage_class_targets(map_data, phase_snapshots)
    for placement_class in CLASSES:
        desired = scenario_desires[placement_class]
        target = int(stage_targets.get(placement_class, 0))
        for ordinal in range(1, target + 1):
            wanted = desired[(ordinal - 1) % len(desired)][1] if desired else None
            slot = take("stage", placement_class, wanted, "stage", ordinal)
            if slot is not None:
                stage_slots.append(slot)

    base_desires: dict[str, list[tuple[str, tuple[float, float] | None]]] = {key: [] for key in CLASSES}
    object_positions = map_data.get("object_slot_positions", {}) if isinstance(map_data.get("object_slot_positions"), dict) else {}
    for object_id, raw_position in sorted(object_positions.items()):
        object_type = str(object_id).split(":", 1)[0]
        placement_class = classify({}, object_type, str(object_id), str(class_overrides.get(object_id, "")))
        base_desires[placement_class].append((str(object_id), desired_rect_top_left(raw_position, placement_class)))
    layout = archetype.get("layout", {}) if isinstance(archetype.get("layout"), dict) else {}
    category_desires: list[tuple[str, int, str, tuple[float, float] | None]] = []
    for field_name, placement_class in CATEGORY_CLASS.items():
        for index, raw_spot in enumerate(values(layout.get(field_name))):
            wanted = point(raw_spot)
            category_desires.append((field_name, index, placement_class, wanted))
            base_desires[placement_class].append((f"{field_name}:{index}", wanted))

    base_slots: list[dict[str, Any]] = []
    for placement_class in CLASSES:
        desired = base_desires[placement_class]
        class_cap = 6 if map_data.get("id") == "pawn_shop" and placement_class == "surface_item" else BASE_CAP[placement_class]
        cap = min(class_cap, max(1 if desired else 0, min(len(desired), class_cap)))
        for ordinal in range(1, cap + 1):
            wanted = desired[(ordinal - 1) % len(desired)][1] if desired else None
            slot = take("base", placement_class, wanted, "base", ordinal)
            if slot is not None:
                base_slots.append(slot)

    base_by_class = {placement_class: [slot for slot in base_slots if slot["footprint_class"] == placement_class] for placement_class in CLASSES}
    object_slot_ids: dict[str, str] = {}
    for placement_class, desired in base_desires.items():
        slots = base_by_class[placement_class]
        for identity, wanted in desired:
            if identity.startswith(tuple(CATEGORY_CLASS.keys())):
                continue
            if slots:
                object_slot_ids[identity] = min(slots, key=lambda slot: (slot_distance(slot, wanted), slot["priority"], slot["id"]))["id"]
    category_slot_ids: dict[str, str] = {}
    for field_name, index, placement_class, wanted in category_desires:
        slots = base_by_class[placement_class]
        if slots:
            category_slot_ids[f"{field_name}:{index}"] = min(slots, key=lambda slot: (slot_distance(slot, wanted), slot["priority"], slot["id"]))["id"]

    stage_by_class = {placement_class: [slot for slot in stage_slots if slot["footprint_class"] == placement_class] for placement_class in CLASSES}
    scenario_slot_ids: dict[str, str] = {}
    for stable_id, raw_position in sorted(scenario_positions.items()):
        semantic = semantics.get(str(stable_id), {})
        object_type = "actor" if any(key in semantic for key in ("actor_id", "character_id")) else "scene_object"
        placement_class = classify(semantic, object_type, str(stable_id), str(class_overrides.get(stable_id, class_overrides.get(f"scenario::{stable_id}", ""))))
        wanted = desired_rect_top_left(raw_position, placement_class)
        slots = exit_slots if placement_class == "doorway" and str(stable_id).endswith("_safe_exit") else stage_by_class[placement_class]
        if slots:
            scenario_slot_ids[str(stable_id)] = min(slots, key=lambda slot: (slot_distance(slot, wanted), slot["priority"], slot["id"]))["id"]

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
    actor_routes: list[dict[str, Any]] = []
    if map_data.get("id") == "back_alley" and len(stage_by_class["standing_person"]) >= 2:
        actor_routes.append({
            "id": "base::world:bar",
            "footprint_class": "standing_person",
            "start_slot_id": stage_by_class["standing_person"][0]["id"],
            "end_slot_id": stage_by_class["standing_person"][1]["id"],
            "lane_ids": ["lane.public"],
            "motion": "to_endpoint",
            "reduced_motion_slot_id": stage_by_class["standing_person"][1]["id"],
        })

    map_data["slot_schema_version"] = 1
    map_data["base_slots"] = base_slots
    map_data["stage_slots"] = stage_slots
    map_data["exit_slots"] = exit_slots
    map_data["walk_lanes"] = walk_lanes
    map_data["actor_routes"] = actor_routes
    map_data["object_slot_ids"] = object_slot_ids
    map_data["category_slot_ids"] = category_slot_ids
    map_data["scenario_slot_ids"] = scenario_slot_ids


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    surface_path = root / "data/environments/placement_surfaces.json"
    surface_root = json.loads(surface_path.read_text(encoding="utf-8"))
    archetypes_list = json.loads((root / "data/environments/archetypes.json").read_text(encoding="utf-8"))
    archetypes = {str(item.get("id", "")): item for item in archetypes_list if isinstance(item, dict)}
    semantics = collect_semantics(root)
    phase_snapshots = collect_active_phase_snapshots(root)
    generated = copy.deepcopy(surface_root)
    generated["schema_version"] = 2
    generated["slot_schema_version"] = 1
    for map_data in generated.get("maps", []):
        if isinstance(map_data, dict):
            map_id = str(map_data.get("id", ""))
            author_map(map_data, archetype_for_map(map_id, archetypes), semantics, phase_snapshots.get(map_id, []))
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
