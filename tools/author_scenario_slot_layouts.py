#!/usr/bin/env python3
"""Author scenario-scoped physical slot instances for every catalog layout.

Shared fixed, item, event, and exit slots remain in placement_surfaces.json.
This companion authority restores the object-specific scenario placement that
was lost when all scenario visuals were collapsed into map-wide class pools.
The runtime overlays exactly one layout and keeps only explicitly marked
runtime-reserve scenario capacity beside it.
"""

from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from collections import Counter, defaultdict
from functools import cache
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "tools") not in sys.path:
    sys.path.insert(0, str(ROOT / "tools"))

import environment_fixed_slot_static_check as StaticCheck  # noqa: E402
import rw06_1_author_fixed_slots as SlotAuthoring  # noqa: E402


PLACEMENT_PATH = ROOT / "data" / "environments" / "placement_surfaces.json"
SCENARIO_PATH = ROOT / "data" / "environments" / "scenarios.json"
OUTPUT_PATH = ROOT / "data" / "environments" / "scenario_slot_layouts.json"
SCHEMA_VERSION = 1
TEMPLATE_ONLY_MAP_IDS = {"small_underground_casino"}
ROLE_SLOT_TOKEN = {
    "wall_mounted": "wall_item",
    "hanging": "hanging_item",
}

# Scenario-conditioned runtime records that are not declared by the catalog's
# mutation arrays still belong to the one scenario layout in which they can
# appear. Their broad role is explicit here so unstable prop heuristics cannot
# relabel named recruitment actors as counters or doors.
CONDITIONAL_SCENARIO_OBJECTS: dict[tuple[str, str], list[dict[str, str]]] = {
    ("pawn_shop", "pawn_shop_estate_lot_day"): [
        {
            "object_id": "event:chain06_sal_estate_item",
            "placement_class": "surface_item",
            "label": "Sal Estate Item",
        },
    ],
    ("motel", "motel_weekly_rates"): [
        {
            "object_id": "event:chain06_nico_weekly_door",
            "placement_class": "doorway",
            "label": "Nico Weekly Door",
        },
        {
            "object_id": "event:chain06_nico_what_it_covers",
            "placement_class": "surface_item",
            "label": "Nico Weekly Terms",
        },
    ],
    ("jazz_club", "jazz_club_rent_party"): [
        {
            "object_id": "event:chain06_trio_rent_payoff",
            "placement_class": "floor_fixture",
            "label": "Trio Rent Payoff",
        },
    ],
    ("gas_station_casino", "gas_station_trucker_convoy"): [
        {
            "object_id": "event:recruitment_switch",
            "placement_class": "standing_person",
            "label": "Switch Recruitment",
        },
    ],
    ("back_alley", "back_alley_fence_night"): [
        {
            "object_id": "event:recruitment_mags",
            "placement_class": "standing_person",
            "label": "Mags Recruitment",
        },
    ],
    ("bar", "bar_fight_night"): [
        {
            "object_id": "event:recruitment_knuckles",
            "placement_class": "standing_person",
            "label": "Knuckles Recruitment",
        },
    ],
    ("kitty_cat_lounge", "kitty_cat_lounge_buyout"): [
        {
            "object_id": "event:recruitment_velvet",
            "placement_class": "standing_person",
            "label": "Velvet Recruitment",
        },
    ],
    ("kitty_cat_lounge", "kitty_cat_lounge_slow_night"): [
        {
            "object_id": "event:recruitment_velvet",
            "placement_class": "standing_person",
            "label": "Velvet Recruitment",
        },
    ],
    ("beach", "beach_festival_weekend"): [
        {
            "object_id": "event:recruitment_lucky",
            "placement_class": "standing_person",
            "label": "Lucky Recruitment",
        },
    ],
}


def values(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def mapping(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


@cache
def base_semantics() -> dict[str, dict[str, Any]]:
    return SlotAuthoring.collect_base_semantics(ROOT)


def clean_slug(value: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")
    return cleaned or "object"


def friendly(value: str) -> str:
    return clean_slug(value).replace("_", " ").title()


def effective_map(base: dict[str, Any], scenario_id: str) -> dict[str, Any]:
    result = copy.deepcopy(base)
    override = mapping(mapping(base.get("scenario_overrides")).get(scenario_id))
    base_classes = copy.deepcopy(mapping(base.get("class_overrides")))
    result.update(copy.deepcopy(override))
    base_classes.update(copy.deepcopy(mapping(override.get("class_overrides"))))
    result["class_overrides"] = base_classes
    return result


def scenario_rows() -> list[tuple[str, str, dict[str, Any]]]:
    catalog = json.loads(SCENARIO_PATH.read_text(encoding="utf-8"))
    rows: list[tuple[str, str, dict[str, Any]]] = []
    for host_id, host_rows in catalog.items():
        for row in values(host_rows):
            if not isinstance(row, dict):
                continue
            layer_id = str(row.get("layer_id", "")).strip()
            map_id = f"{host_id}:{layer_id}" if layer_id else str(host_id)
            rows.append((map_id, str(row.get("id", "")), row))
    return sorted(rows, key=lambda item: (item[0], item[1]))


def snapshots_by_scenario() -> dict[tuple[str, str], list[list[dict[str, Any]]]]:
    result: dict[tuple[str, str], list[list[dict[str, Any]]]] = defaultdict(list)
    for map_id, snapshots in SlotAuthoring.collect_active_phase_snapshots(
        ROOT, include_aftermath=True
    ).items():
        for snapshot in snapshots:
            scenario_id = next(
                (
                    str(entry.get("_slot_scenario_id", "")).strip()
                    for entry in snapshot
                    if isinstance(entry, dict)
                    and str(entry.get("_slot_scenario_id", "")).strip()
                ),
                "",
            )
            if scenario_id:
                result[(map_id, scenario_id)].append(snapshot)
    return result


def scenario_base_objects(
    map_id: str,
    scenario_id: str,
    surface: dict[str, Any],
    scenario_row: dict[str, Any],
) -> list[dict[str, Any]]:
    serialized = json.dumps(scenario_row, sort_keys=True, separators=(",", ":"))
    slots = {
        str(slot.get("id", "")): slot
        for slot in values(surface.get("scenario_slots"))
        if isinstance(slot, dict)
    }
    class_overrides = mapping(surface.get("class_overrides"))
    family_ids = mapping(surface.get("object_family_ids"))
    candidates: dict[str, dict[str, str]] = {}
    for object_id, old_slot_id_value in sorted(
        mapping(surface.get("scenario_object_slot_ids")).items()
    ):
        old_slot_id = str(old_slot_id_value)
        old_slot = mapping(slots.get(old_slot_id))
        source_id = str(object_id).partition(":")[2]
        if not source_id or source_id not in serialized or not old_slot:
            continue
        candidates[str(object_id)] = {
            "source_id": source_id,
            "preferred_slot_id": old_slot_id,
            "object_type": str(object_id).partition(":")[0],
        }

    source_fields = {
        "event_pool_add": "event",
        "service_add": "service",
        "item_offer_add": "item",
        "game_pool_add": "game",
    }
    for node in StaticCheck._v2_iter_dict_nodes(scenario_row):
        for field, prefix in source_fields.items():
            for raw in values(node.get(field)):
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
                declared_family = str(family_ids.get(object_id, ""))
                if declared_family == "fixed":
                    continue
                old_slot_id = str(
                    mapping(surface.get("scenario_object_slot_ids")).get(object_id, "")
                )
                candidates[object_id] = {
                    "source_id": source_id,
                    "preferred_slot_id": old_slot_id,
                    "object_type": prefix,
                }
        opportunity = mapping(node.get("exclusive_opportunity"))
        for field, prefix in (("event_id", "event"), ("game_id", "game")):
            source_id = str(opportunity.get(field, "")).strip()
            if not source_id:
                continue
            object_id = f"{prefix}:{source_id}"
            if str(family_ids.get(object_id, "")) == "fixed":
                continue
            candidates[object_id] = {
                "source_id": source_id,
                "preferred_slot_id": str(
                    mapping(surface.get("scenario_object_slot_ids")).get(object_id, "")
                ),
                "object_type": prefix,
            }

    for conditional in CONDITIONAL_SCENARIO_OBJECTS.get((map_id, scenario_id), []):
        object_id = str(conditional["object_id"])
        candidates[object_id] = {
            "source_id": object_id.partition(":")[2],
            "preferred_slot_id": str(
                mapping(surface.get("scenario_object_slot_ids")).get(object_id, "")
            ),
            "object_type": object_id.partition(":")[0],
            "placement_class": str(conditional["placement_class"]),
            "label": str(conditional["label"]),
            "conditional": "true",
        }

    for object_id in list(candidates):
        candidate = candidates[object_id]
        object_type = candidate["object_type"]
        semantic = copy.deepcopy(base_semantics().get(object_id, {}))
        override = str(class_overrides.get(object_id, "")).strip()
        placement_class = str(candidate.get("placement_class", ""))
        if placement_class not in StaticCheck.CLASSES:
            visual_prop = str(
                semantic.get("environment_prop", semantic.get("visual_prop", ""))
            ).strip()
            # EnvironmentInstance adds context-sensitive event placement hints
            # before the live binder classifies base records. Mirror those two
            # physical rules here so generated exact slots cannot disagree with
            # production about a bar patron's seat or a clerk's counter.
            if override in StaticCheck.CLASSES:
                placement_class = override
            elif object_type == "item":
                placement_class = "shop_item"
            elif (
                object_type == "event"
                and map_id.partition(":")[0] == "bar"
                and values(surface.get("seats"))
                and visual_prop
                in {"bar_patron", "patron", "patron_talk", "rowdy_patron"}
            ):
                placement_class = "seated_person"
            elif object_type == "event" and visual_prop in {
                "clerk_counter",
                "host_station",
            }:
                placement_class = "behind_counter_person"
            else:
                placement_class = SlotAuthoring.classify_with_override(
                    semantic, object_type, object_id, override
                )
        if placement_class not in StaticCheck.CLASSES:
            candidates.pop(object_id)
            continue
        candidate["placement_class"] = placement_class
        if not str(candidate.get("label", "")).strip():
            candidate["label"] = str(
                semantic.get("display_name", semantic.get("label", friendly(candidate["source_id"])))
            )
        preferred_slot = mapping(slots.get(candidate["preferred_slot_id"]))
        if str(preferred_slot.get("footprint_class", "")) != placement_class:
            candidate["preferred_slot_id"] = ""

    # Any source-added object without a legacy exact hint receives deterministic
    # geometry from the first unused compatible source bank.
    available = source_slots_by_class(surface)
    used_preferred: dict[str, set[str]] = defaultdict(set)
    for candidate in candidates.values():
        placement_class = candidate["placement_class"]
        preferred = candidate["preferred_slot_id"]
        if preferred:
            used_preferred[placement_class].add(preferred)
    for object_id in sorted(candidates):
        candidate = candidates[object_id]
        placement_class = candidate["placement_class"]
        if not candidate["preferred_slot_id"]:
            source = next(
                (
                    slot
                    for slot in available.get(placement_class, [])
                    if str(slot.get("id", "")) not in used_preferred[placement_class]
                ),
                {},
            )
            candidate["preferred_slot_id"] = str(source.get("id", ""))
            if candidate["preferred_slot_id"]:
                used_preferred[placement_class].add(candidate["preferred_slot_id"])

    result: list[dict[str, Any]] = []
    for object_id, candidate in sorted(candidates.items()):
        source_id = candidate["source_id"]
        result.append(
            {
                "node_key": f"base::{object_id}",
                "object_id": str(object_id),
                "identity": str(object_id),
                "stable_id": source_id,
                "placement_class": candidate["placement_class"],
                "label": candidate["label"],
                "preferred_slot_id": candidate["preferred_slot_id"],
                "base_record": True,
                "conditional": candidate.get("conditional") == "true",
            }
        )
    return result


def visual_entry(
    surface: dict[str, Any], semantic: dict[str, Any]
) -> dict[str, Any] | None:
    if bool(semantic.get("_slot_interaction_only", False)) or bool(
        semantic.get("_slot_nonvisual", False)
    ):
        return None
    identity = str(semantic.get("identity", "")).strip()
    if not identity.startswith("scenario::") or not bool(
        semantic.get("present", True)
    ):
        return None
    stable_id = identity.removeprefix("scenario::")
    interaction = mapping(semantic.get("_slot_interaction"))
    actor = bool(semantic.get("_slot_actor", False))
    safe_exit = bool(interaction.get("safe_exit", semantic.get("safe_exit", False)))
    navigation_exit = StaticCheck._v2_interaction_navigates_environment(interaction)
    if navigation_exit:
        # Real travel continues to use the shared exit family.
        return None
    art_key = StaticCheck._v2_scenario_art_key(
        surface, semantic, actor, safe_exit, navigation_exit
    )
    if not (actor or safe_exit or art_key):
        return None
    classified = copy.deepcopy(semantic)
    if art_key:
        classified["icon_key"] = art_key
    class_overrides = mapping(surface.get("class_overrides"))
    placement_class = SlotAuthoring.classify_with_override(
        classified,
        "actor" if actor else "scene_object",
        identity,
        str(class_overrides.get(identity, class_overrides.get(stable_id, ""))),
    )
    if safe_exit:
        placement_class = "doorway"
    position_key = SlotAuthoring.scenario_position_key(stable_id, semantic)
    route_id = str(semantic.get("route_id", "")).strip() or str(
        mapping(surface.get("scenario_position_route_ids")).get(position_key, "")
    ).strip()
    preferences = mapping(surface.get("scenario_slot_ids"))
    preferred = next(
        (
            str(preferences[key])
            for key in (position_key, stable_id, identity)
            if key and key in preferences
        ),
        "",
    )
    label = str(semantic.get("label", "")).strip() or friendly(stable_id)
    return {
        "node_key": position_key,
        "position_key": position_key,
        "identity": identity,
        "stable_id": stable_id,
        "placement_class": placement_class,
        "label": label,
        "preferred_slot_id": preferred,
        "route_id": route_id,
        "semantic": copy.deepcopy(semantic),
        "base_record": False,
    }


def source_slots_by_class(surface: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for slot in values(surface.get("scenario_slots")):
        if not isinstance(slot, dict) or bool(slot.get("runtime_reserve", False)):
            continue
        result[str(slot.get("footprint_class", ""))].append(slot)
    for slots in result.values():
        slots.sort(key=lambda slot: (int(slot.get("priority", 0)), str(slot.get("id", ""))))
    return result


def geometry_templates_by_class(
    surface: dict[str, Any],
) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for family in ("scenario", "event", "fixed", "exit"):
        for slot in values(surface.get(f"{family}_slots")):
            if not isinstance(slot, dict):
                continue
            placement_class = str(slot.get("footprint_class", ""))
            if placement_class not in StaticCheck.CLASSES:
                continue
            template = copy.deepcopy(slot)
            template["_source_slot_id"] = str(slot.get("id", ""))
            template["_source_family"] = family
            result[placement_class].append(template)
    for slots in result.values():
        slots.sort(
            key=lambda slot: (
                ("scenario", "event", "fixed", "exit").index(
                    str(slot.get("_source_family", "exit"))
                ),
                int(slot.get("priority", 0)),
                str(slot.get("id", "")),
            )
        )
    aliases = {
        "behind_counter_person": ("standing_person", "seated_person"),
        "standing_person": ("behind_counter_person", "seated_person"),
        "seated_person": ("standing_person", "behind_counter_person"),
        "group": ("standing_person", "floor_fixture"),
        "shop_item": ("surface_item", "wall_mounted"),
        "surface_item": ("shop_item", "wall_mounted", "floor_fixture"),
        "wall_mounted": ("surface_item", "hanging"),
        "hanging": ("wall_mounted", "surface_item"),
        "ground_marker": ("floor_fixture", "surface_item"),
        "floor_fixture": ("ground_marker", "surface_item"),
        "doorway": ("standing_person", "floor_fixture"),
    }
    for placement_class in StaticCheck.CLASSES:
        if result.get(placement_class):
            continue
        for alias in aliases.get(placement_class, ()):
            if result.get(alias):
                template = copy.deepcopy(result[alias][0])
                template["footprint_class"] = placement_class
                template["_synthetic_geometry"] = True
                result[placement_class].append(template)
                break
    return result


def _color_graph(
    node_keys: list[str],
    conflicts: dict[str, set[str]],
    color_count: int,
) -> dict[str, int] | None:
    """Return a deterministic coloring using at most ``color_count`` banks."""

    colors: dict[str, int] = {}

    def solve() -> bool:
        if len(colors) == len(node_keys):
            return True
        remaining = [node for node in node_keys if node not in colors]
        node_key = min(
            remaining,
            key=lambda key: (
                -len(
                    {
                        colors[neighbor]
                        for neighbor in conflicts.get(key, set())
                        if neighbor in colors
                    }
                ),
                -len(conflicts.get(key, set())),
                key,
            ),
        )
        unavailable = {
            colors[neighbor]
            for neighbor in conflicts.get(node_key, set())
            if neighbor in colors
        }
        used_colors = sorted(set(colors.values()))
        candidates = [color for color in used_colors if color not in unavailable]
        next_color = len(used_colors)
        if next_color < color_count and next_color not in unavailable:
            candidates.append(next_color)
        for color in candidates:
            colors[node_key] = color
            if solve():
                return True
            colors.pop(node_key, None)
        return False

    return colors if solve() else None


def _best_geometry_by_color(
    color_nodes: dict[int, list[str]],
    nodes: dict[str, dict[str, Any]],
    available: list[dict[str, Any]],
) -> dict[int, dict[str, Any]]:
    """Match compact banks to old geometry while maximizing retained hints."""

    colors = sorted(color_nodes)
    source_ids = [str(slot.get("id", "")) for slot in available]
    weights: list[list[int]] = []
    for color in colors:
        preferred = Counter(str(nodes[key].get("preferred_slot_id", "")) for key in color_nodes[color])
        weights.append([preferred.get(source_id, 0) for source_id in source_ids])

    @cache
    def solve(color_index: int, used_mask: int) -> tuple[int, tuple[int, ...]]:
        if color_index == len(colors):
            return 0, ()
        best_score = -1
        best_choice: tuple[int, ...] = ()
        for source_index in range(len(available)):
            if used_mask & (1 << source_index):
                continue
            tail_score, tail_choice = solve(
                color_index + 1, used_mask | (1 << source_index)
            )
            score = weights[color_index][source_index] * 1000 + tail_score
            choice = (source_index, *tail_choice)
            if score > best_score or (score == best_score and choice < best_choice):
                best_score = score
                best_choice = choice
        return best_score, best_choice

    _, chosen = solve(0, 0)
    if len(chosen) != len(colors):
        raise ValueError("could not assign distinct source geometry to compact banks")
    return {color: available[chosen[index]] for index, color in enumerate(colors)}


def assign_geometry(
    nodes: dict[str, dict[str, Any]],
    conflicts: dict[str, set[str]],
    source_slots: dict[str, list[dict[str, Any]]],
    fallback_templates: dict[str, list[dict[str, Any]]],
    scope: str,
) -> tuple[dict[str, int], dict[tuple[str, int], dict[str, Any]]]:
    """Color semantic objects into compact, scenario-local role banks.

    Mutually exclusive phase/outcome objects deliberately reuse one physical
    marker. Only objects proven able to coexist consume separate ordinals.
    """

    assigned_colors: dict[str, int] = {}
    bank_geometry: dict[tuple[str, int], dict[str, Any]] = {}
    by_class: dict[str, list[str]] = defaultdict(list)
    for node_key, node in nodes.items():
        by_class[str(node.get("placement_class", ""))].append(node_key)

    for placement_class, class_nodes in sorted(by_class.items()):
        available = copy.deepcopy(source_slots.get(placement_class, []))
        templates = fallback_templates.get(placement_class, [])
        if not available and not templates:
            raise ValueError(
                f"{scope}: no geometry template exists for scenario class {placement_class}"
            )
        class_nodes.sort()
        colors: dict[str, int] | None = None
        for color_count in range(1, len(class_nodes) + 1):
            colors = _color_graph(class_nodes, conflicts, color_count)
            if colors is not None:
                break
        if colors is None:
            raise ValueError(
                f"{scope}: scenario {placement_class} conflict graph cannot be colored"
            )
        required_geometry = max(colors.values(), default=-1) + 1
        while len(available) < required_geometry:
            template = copy.deepcopy(
                templates[len(available) % len(templates)]
                if templates
                else available[0]
            )
            template["_synthetic_geometry"] = True
            template["id"] = (
                f"__provisional__.{clean_slug(placement_class)}_{len(available) + 1}"
            )
            available.append(template)
        grouped: dict[int, list[str]] = defaultdict(list)
        for node_key, color in colors.items():
            grouped[color].append(node_key)
            assigned_colors[node_key] = color
        chosen_geometry = _best_geometry_by_color(grouped, nodes, available)
        for color, source in chosen_geometry.items():
            bank_geometry[(placement_class, color)] = source
    return assigned_colors, bank_geometry


def clone_slot(
    source: dict[str, Any],
    slot_id: str,
    placement_class: str,
    ordinal: int,
    bank_nodes: list[dict[str, Any]],
    scenario_id: str,
    priority: int,
) -> dict[str, Any]:
    slot = copy.deepcopy(source)
    position_keys = sorted(
        {
            str(node.get("position_key", "")).strip()
            for node in bank_nodes
            if str(node.get("position_key", "")).strip()
        }
    )
    object_ids = sorted(
        {
            str(node.get("identity", node.get("object_id", ""))).strip()
            for node in bank_nodes
            if str(node.get("identity", node.get("object_id", ""))).strip()
        }
    )
    occupant_labels = sorted(
        {
            str(node.get("label", "")).strip()
            for node in bank_nodes
            if str(node.get("label", "")).strip()
        }
    )
    if not occupant_labels:
        occupant_labels = [f"{friendly(placement_class)} {ordinal}"]
    physical_role = occupant_labels[0]
    if len(occupant_labels) > 1:
        physical_role = "Scenario alternatives: " + " / ".join(occupant_labels)
    slot.update(
        {
            "id": slot_id,
            "kind": "scenario",
            "priority": priority,
            "occupancy_required": False,
            "physical_role": physical_role,
            "occupant_ids": object_ids,
            "scenario_occupant_labels": occupant_labels,
            "runtime_reserve": False,
            "reserve_reason": "",
            "scenario_id": scenario_id,
            "scenario_instance": True,
            "scenario_role": placement_class,
            "scenario_ordinal": ordinal,
            "scenario_position_keys": position_keys,
            "scenario_object_ids": object_ids,
            "source_slot_id": str(
                source.get("_source_slot_id", source.get("id", ""))
            ),
            "source_slot_family": str(source.get("_source_family", "scenario")),
            "provisional_geometry": bool(source.get("_synthetic_geometry", False)),
        }
    )
    return slot


def _rect_intersects(left: list[float], right: list[float]) -> bool:
    return not (
        left[0] + left[2] <= right[0]
        or right[0] + right[2] <= left[0]
        or left[1] + left[3] <= right[1]
        or right[1] + right[3] <= left[1]
    )


def place_provisional_geometry(
    authored_slots: list[dict[str, Any]],
    surface: dict[str, Any],
) -> None:
    """Move synthesized capacity to a free provisional board position."""

    occupied: list[list[float]] = []
    for family in ("fixed", "event", "exit"):
        for slot in values(surface.get(f"{family}_slots")):
            hit = values(mapping(slot).get("hit_rect"))
            if len(hit) >= 4:
                occupied.append([float(hit[i]) for i in range(4)])
    for slot in values(surface.get("scenario_slots")):
        if not isinstance(slot, dict) or not bool(slot.get("runtime_reserve", False)):
            continue
        hit = values(slot.get("hit_rect"))
        if len(hit) >= 4:
            occupied.append([float(hit[i]) for i in range(4)])
    for slot in authored_slots:
        if bool(slot.get("provisional_geometry", False)):
            continue
        hit = values(slot.get("hit_rect"))
        if len(hit) >= 4:
            occupied.append([float(hit[i]) for i in range(4)])

    for slot in authored_slots:
        if not bool(slot.get("provisional_geometry", False)):
            continue
        old_hit = values(slot.get("hit_rect"))
        width = float(old_hit[2]) if len(old_hit) >= 4 else 72.0
        height = float(old_hit[3]) if len(old_hit) >= 4 else 48.0
        placement_class = str(slot.get("footprint_class", ""))
        if placement_class in {
            "standing_person", "behind_counter_person", "seated_person", "group",
            "floor_fixture", "ground_marker", "doorway",
        }:
            y_values = list(range(max(8, int(430 - height) - 8), 31, -8))
        else:
            y_values = list(range(16, max(17, int(430 - height) - 7), 8))
        candidate: list[float] | None = None
        for y in y_values:
            for x in range(8, max(9, int(900 - width) - 7), 8):
                proposed = [float(x), float(y), width, height]
                if all(not _rect_intersects(proposed, other) for other in occupied):
                    candidate = proposed
                    break
            if candidate is not None:
                break
        if candidate is None:
            raise ValueError(
                f"{surface.get('id', '<map>')}: no provisional free position for {slot.get('id', '<slot>')}"
            )
        occupied.append(candidate)
        slot["hit_rect"] = candidate
        slot["pos"] = [
            candidate[0] + candidate[2] / 2.0,
            candidate[1] + candidate[3],
        ]
        slot["label_anchor"] = [
            candidate[0] + candidate[2] / 2.0,
            max(0.0, candidate[1] - 6.0),
        ]
        slot["zone_id"] = "provisional"
        slot["support_id"] = "manual_placement_required"


def build_layout(
    map_id: str,
    scenario_id: str,
    scenario_row: dict[str, Any],
    base_map: dict[str, Any],
    snapshots: list[list[dict[str, Any]]],
) -> dict[str, Any]:
    surface = effective_map(base_map, scenario_id)
    nodes: dict[str, dict[str, Any]] = {}
    conflicts: dict[str, set[str]] = defaultdict(set)
    action_only_ids: set[str] = set()
    route_nodes: dict[str, tuple[str, str]] = {}
    max_simultaneous = 0

    base_nodes = scenario_base_objects(map_id, scenario_id, surface, scenario_row)
    for node in base_nodes:
        nodes[str(node["node_key"])] = node
    # Catalog-added game/event/service/item records are active base-room objects
    # while the sequence projection is composed above them. Treat them as live
    # in every reachable snapshot so exact banks never double-book a base event
    # and a scenario visual.
    for index, left in enumerate(base_nodes):
        for right in base_nodes[index + 1 :]:
            left_key = str(left["node_key"])
            right_key = str(right["node_key"])
            conflicts[left_key].add(right_key)
            conflicts[right_key].add(left_key)

    for snapshot in snapshots:
        active: list[str] = []
        for semantic in snapshot:
            if not isinstance(semantic, dict):
                continue
            entry = visual_entry(surface, semantic)
            identity = str(semantic.get("identity", ""))
            if entry is None:
                if identity.startswith("scenario::") and not bool(
                    semantic.get("_slot_nonvisual", False)
                ):
                    action_only_ids.add(identity.removeprefix("scenario::"))
                continue
            route_id = str(entry.get("route_id", ""))
            if route_id:
                route_pair = route_nodes.get(route_id)
                if route_pair is None:
                    start_key = f"route::{route_id}::start"
                    end_key = f"route::{route_id}::end"
                    route_pair = (start_key, end_key)
                    route_nodes[route_id] = route_pair
                    routes = {
                        str(route.get("id", "")): route
                        for route in values(surface.get("actor_routes"))
                        if isinstance(route, dict)
                    }
                    source_route = mapping(routes.get(route_id))
                    for node_key, endpoint in zip(route_pair, ("start", "end")):
                        route_node = copy.deepcopy(entry)
                        route_node.update(
                            {
                                "node_key": node_key,
                                "position_key": node_key,
                                "label": f"{entry['label']} route {endpoint}",
                                "route_endpoint": endpoint,
                                "preferred_slot_id": str(
                                    source_route.get(f"{endpoint}_slot_id", "")
                                ),
                            }
                        )
                        nodes[node_key] = route_node
                active.extend(route_pair)
                continue
            node_key = str(entry["node_key"])
            prior = nodes.get(node_key)
            if prior is not None and str(prior.get("placement_class", "")) != str(
                entry.get("placement_class", "")
            ):
                node_key = f"{node_key}|@class={entry['placement_class']}"
                entry["node_key"] = node_key
            if node_key not in nodes:
                nodes[node_key] = entry
            active.append(node_key)
        active = sorted(set(active))
        active_with_base = sorted(
            set(active + [str(node["node_key"]) for node in base_nodes])
        )
        max_simultaneous = max(max_simultaneous, len(active_with_base))
        for index, left in enumerate(active_with_base):
            for right in active_with_base[index + 1 :]:
                conflicts[left].add(right)
                conflicts[right].add(left)

    if not snapshots:
        raise ValueError(f"{map_id}/{scenario_id} has no reachable scenario snapshots")
    assigned_colors, bank_geometry = assign_geometry(
        nodes,
        conflicts,
        source_slots_by_class(surface),
        geometry_templates_by_class(surface),
        f"{map_id}/{scenario_id}",
    )
    authored_slots: list[dict[str, Any]] = []
    exact_preferences: dict[str, str] = {}
    exact_object_preferences: dict[str, str] = {}
    route_slot_ids: dict[str, dict[str, str]] = defaultdict(dict)
    stable_nodes: dict[str, list[str]] = defaultdict(list)

    bank_nodes: dict[tuple[str, int], list[dict[str, Any]]] = defaultdict(list)
    for node_key, color in assigned_colors.items():
        placement_class = str(nodes[node_key].get("placement_class", ""))
        bank_nodes[(placement_class, color)].append(nodes[node_key])
    bank_slot_ids: dict[tuple[str, int], str] = {}
    class_ordinals: dict[str, int] = defaultdict(int)
    reserved_ids = {
        str(slot.get("id", ""))
        for slot in values(surface.get("scenario_slots"))
        if isinstance(slot, dict) and bool(slot.get("runtime_reserve", False))
    }
    for priority, bank_key in enumerate(sorted(bank_nodes), start=1):
        placement_class, color = bank_key
        slot_token = ROLE_SLOT_TOKEN.get(placement_class, placement_class)
        while True:
            class_ordinals[placement_class] += 1
            ordinal = class_ordinals[placement_class]
            slot_id = f"scenario.{clean_slug(slot_token)}_{ordinal}"
            if slot_id not in reserved_ids:
                break
        bank_slot_ids[bank_key] = slot_id
        authored_slots.append(
            clone_slot(
                bank_geometry[bank_key],
                slot_id,
                placement_class,
                ordinal,
                bank_nodes[bank_key],
                scenario_id,
                priority,
            )
        )
    place_provisional_geometry(authored_slots, surface)

    for node_key in sorted(nodes):
        node = nodes[node_key]
        placement_class = str(node.get("placement_class", ""))
        slot_id = bank_slot_ids[(placement_class, assigned_colors[node_key])]
        route_endpoint = str(node.get("route_endpoint", ""))
        if bool(node.get("base_record", False)):
            exact_object_preferences[str(node.get("object_id", ""))] = slot_id
        elif route_endpoint:
            route_slot_ids[str(node.get("route_id", ""))][route_endpoint] = slot_id
        else:
            position_key = str(node.get("position_key", ""))
            if position_key:
                exact_preferences[position_key] = slot_id
            stable_nodes[str(node.get("stable_id", ""))].append(slot_id)

    for stable_id, slot_ids in stable_nodes.items():
        unique_slot_ids = sorted(set(slot_ids))
        if stable_id and len(unique_slot_ids) == 1:
            exact_preferences[stable_id] = unique_slot_ids[0]
            exact_preferences[f"scenario::{stable_id}"] = unique_slot_ids[0]

    source_routes = {
        str(route.get("id", "")): route
        for route in values(surface.get("actor_routes"))
        if isinstance(route, dict)
    }
    authored_routes: list[dict[str, Any]] = []
    for route_id, endpoints in sorted(route_slot_ids.items()):
        source_route = copy.deepcopy(mapping(source_routes.get(route_id)))
        if not source_route:
            raise ValueError(f"{map_id}/{scenario_id} references missing route {route_id}")
        source_route["start_slot_id"] = endpoints.get("start", "")
        source_route["end_slot_id"] = endpoints.get("end", "")
        if not source_route["start_slot_id"] or not source_route["end_slot_id"]:
            raise ValueError(f"{map_id}/{scenario_id} route {route_id} lacks endpoints")
        authored_routes.append(source_route)

    by_class = Counter(str(slot.get("footprint_class", "")) for slot in authored_slots)
    return {
        "layout_id": f"{map_id}::{scenario_id}",
        "map_id": map_id,
        "scenario_id": scenario_id,
        "display_name": str(scenario_row.get("display_name", scenario_id)),
        "scenario_slots": authored_slots,
        "scenario_instance_slot_ids": dict(sorted(exact_preferences.items())),
        "scenario_instance_object_slot_ids": dict(
            sorted(exact_object_preferences.items())
        ),
        "scenario_instance_object_family_ids": {
            object_id: "scenario" for object_id in sorted(exact_object_preferences)
        },
        "actor_routes": authored_routes,
        "audit": {
            "snapshot_count": len(snapshots),
            "slot_count": len(authored_slots),
            "semantic_position_count": len(nodes),
            "reused_semantic_position_count": len(nodes) - len(authored_slots),
            "slots_by_class": dict(sorted(by_class.items())),
            "max_simultaneous_slot_count": max_simultaneous,
            "action_only_ids": sorted(action_only_ids),
            "source_generic_slot_ids": sorted(
                {str(slot.get("source_slot_id", "")) for slot in authored_slots}
            ),
        },
    }


def build_payload() -> dict[str, Any]:
    placement = json.loads(PLACEMENT_PATH.read_text(encoding="utf-8"))
    maps = {str(item.get("id", "")): item for item in values(placement.get("maps"))}
    snapshots = snapshots_by_scenario()
    layouts: list[dict[str, Any]] = []
    for map_id, scenario_id, row in scenario_rows():
        if map_id not in maps:
            raise ValueError(f"catalog scenario {scenario_id} references missing map {map_id}")
        layouts.append(
            build_layout(
                map_id,
                scenario_id,
                row,
                maps[map_id],
                snapshots.get((map_id, scenario_id), []),
            )
        )
    if len(layouts) != 55:
        raise ValueError(f"expected 55 scenario layouts, authored {len(layouts)}")
    unknown_templates = TEMPLATE_ONLY_MAP_IDS - set(maps)
    if unknown_templates:
        raise ValueError(
            f"template-only placement maps are missing: {sorted(unknown_templates)}"
        )
    # The layered Punchline parent is source geometry used by its three real
    # floors. Runtime always resolves it to club/casino/back_room, so counting
    # the raw parent as a manual base context would make coverage impossible.
    base_layout_ids = sorted(set(maps) - TEMPLATE_ONLY_MAP_IDS)
    template_map_ids = sorted(TEMPLATE_ONLY_MAP_IDS)
    maps_with_scenarios = sorted({str(layout["map_id"]) for layout in layouts})
    return {
        "schema_version": SCHEMA_VERSION,
        "slot_schema_version": int(placement.get("slot_schema_version", 0)),
        "base_layout_ids": base_layout_ids,
        "template_map_ids": template_map_ids,
        "maps_with_catalog_scenarios": maps_with_scenarios,
        "layout_count": len(layouts),
        "scenario_slot_count": sum(
            len(values(layout.get("scenario_slots"))) for layout in layouts
        ),
        "layouts": layouts,
    }


def encoded(payload: dict[str, Any]) -> bytes:
    return (json.dumps(payload, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    payload = build_payload()
    output = encoded(payload)
    if args.check:
        if not OUTPUT_PATH.exists() or OUTPUT_PATH.read_bytes() != output:
            raise SystemExit(
                "scenario slot layout authority is missing or stale; run "
                "tools/author_scenario_slot_layouts.py"
            )
        print(
            "SCENARIO_SLOT_LAYOUT_CHECK PASS "
            f"layouts={payload['layout_count']} slots={payload['scenario_slot_count']}"
        )
        return 0
    OUTPUT_PATH.write_bytes(output)
    print(
        "Authored scenario slot layouts: "
        f"layouts={payload['layout_count']} slots={payload['scenario_slot_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
