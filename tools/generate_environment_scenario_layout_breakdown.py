#!/usr/bin/env python3
"""Generate the exhaustive environment/scenario manual-placement guide.

The guide is deliberately derived from the same four authorities used by the
runtime and the Environment Library.  It is not an independently maintained
inventory.  Run with ``--check`` in validation to reject a stale document.
"""

from __future__ import annotations

import argparse
import html
import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
PLACEMENT_PATH = ROOT / "data" / "environments" / "placement_surfaces.json"
LAYOUT_PATH = ROOT / "data" / "environments" / "scenario_slot_layouts.json"
ARCHETYPE_PATH = ROOT / "data" / "environments" / "archetypes.json"
SCENARIO_PATH = ROOT / "data" / "environments" / "scenarios.json"
OUTPUT_PATH = ROOT / "docs" / "plans" / "environment_scenario_layout_breakdown.md"

EXPECTED_BASE_CONTEXTS = 20
EXPECTED_SCENARIO_CONTEXTS = 55
EXPECTED_CONTEXTS = EXPECTED_BASE_CONTEXTS + EXPECTED_SCENARIO_CONTEXTS
TEMPLATE_ONLY_MAP_ID = "small_underground_casino"
FAMILIES = ("fixed", "event", "scenario", "exit")
FAMILY_FIELDS = {family: f"{family}_slots" for family in FAMILIES}


def values(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def mapping(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"could not read {path.relative_to(ROOT)}: {error}") from error


def friendly(identifier: str) -> str:
    words = re.sub(r"[^A-Za-z0-9]+", " ", identifier).strip().split()
    acronyms = {"atm", "npc", "ui", "vip"}
    return " ".join(word.upper() if word.lower() in acronyms else word.capitalize() for word in words)


def markdown_text(value: Any) -> str:
    return html.escape(str(value), quote=False).replace("|", "&#124;").replace("\n", "<br>")


def code(value: Any) -> str:
    return f"<code>{markdown_text(value)}</code>"


def formatted_number(value: Any) -> str:
    require(isinstance(value, (int, float)) and not isinstance(value, bool), f"invalid coordinate {value!r}")
    number = float(value)
    require(math.isfinite(number), f"non-finite coordinate {value!r}")
    if number.is_integer():
        return str(int(number))
    return f"{number:.6f}".rstrip("0").rstrip(".")


def position(slot: dict[str, Any], scope: str) -> str:
    raw = values(slot.get("pos"))
    require(len(raw) == 2, f"{scope}/{slot.get('id', '<missing>')} must have a two-number pos")
    return f"{formatted_number(raw[0])}, {formatted_number(raw[1])}"


def unique_strings(items: Iterable[Any]) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for item in items:
        text = str(item).strip()
        if text and text not in seen:
            seen.add(text)
            result.append(text)
    return result


def map_title(surface: dict[str, Any], archetypes: dict[str, dict[str, Any]]) -> str:
    map_id = str(surface.get("id", ""))
    archetype_id = str(surface.get("archetype_id", map_id.split(":", 1)[0]))
    archetype = mapping(archetypes.get(archetype_id))
    base_title = str(archetype.get("display_name", "")).strip() or friendly(archetype_id)
    layer_id = str(surface.get("layer_id", "")).strip()
    if not layer_id and ":" in map_id:
        layer_id = map_id.split(":", 1)[1]
    if not layer_id:
        return base_title
    layer = mapping(mapping(archetype.get("layers")).get(layer_id))
    layer_title = str(layer.get("layer_display_name", "")).strip() or friendly(layer_id)
    return f"{base_title} — {layer_title}"


def scenario_catalog_rows(
    payload: dict[str, Any], archetypes: dict[str, dict[str, Any]]
) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for host_id, rows in payload.items():
        require(host_id in archetypes, f"scenario host {host_id} has no archetype")
        require(isinstance(rows, list), f"scenario host {host_id} must contain an array")
        for raw_row in rows:
            require(isinstance(raw_row, dict), f"scenario host {host_id} contains a non-object row")
            scenario_id = str(raw_row.get("id", "")).strip()
            layer_id = str(raw_row.get("layer_id", "")).strip()
            map_id = f"{host_id}:{layer_id}" if layer_id else host_id
            layout_id = f"{map_id}::{scenario_id}"
            require(scenario_id, f"scenario host {host_id} contains an empty scenario id")
            require(layout_id not in result, f"duplicate scenario catalog layout {layout_id}")
            result[layout_id] = raw_row
    return result


def slots_for_family(surface: dict[str, Any], family: str) -> list[dict[str, Any]]:
    field = FAMILY_FIELDS[family]
    raw_slots = surface.get(field)
    require(isinstance(raw_slots, list), f"{surface.get('id', '<map>')}.{field} must be an array")
    result: list[dict[str, Any]] = []
    for raw_slot in raw_slots:
        require(isinstance(raw_slot, dict), f"{surface.get('id', '<map>')}.{field} contains a non-object slot")
        result.append(raw_slot)
    return result


def effective_shared_slots(
    surface: dict[str, Any], has_catalog_scenarios: bool
) -> list[tuple[str, dict[str, Any]]]:
    result: list[tuple[str, dict[str, Any]]] = []
    for family in ("fixed", "event"):
        result.extend((family, slot) for slot in slots_for_family(surface, family))
    scenario_slots = slots_for_family(surface, "scenario")
    if has_catalog_scenarios:
        scenario_slots = [slot for slot in scenario_slots if bool(slot.get("runtime_reserve", False))]
    result.extend(("scenario", slot) for slot in scenario_slots)
    result.extend(("exit", slot) for slot in slots_for_family(surface, "exit"))
    return result


def validate_slot(slot: dict[str, Any], family: str, scope: str, seen: set[str]) -> None:
    slot_id = str(slot.get("id", "")).strip()
    require(slot_id, f"{scope} contains an empty {family} slot id")
    require(slot_id.startswith(f"{family}."), f"{scope}/{slot_id} is not a {family} slot")
    require(str(slot.get("kind", "")) == family, f"{scope}/{slot_id} has the wrong kind")
    require(slot_id not in seen, f"{scope} contains duplicate slot id {slot_id}")
    seen.add(slot_id)
    position(slot, scope)
    require(str(slot.get("physical_role", "")).strip(), f"{scope}/{slot_id} has no physical_role")


def build_model() -> dict[str, Any]:
    placement = read_json(PLACEMENT_PATH)
    authority = read_json(LAYOUT_PATH)
    archetype_rows = read_json(ARCHETYPE_PATH)
    scenarios = read_json(SCENARIO_PATH)
    require(isinstance(placement, dict), "placement_surfaces.json must have an object root")
    require(isinstance(authority, dict), "scenario_slot_layouts.json must have an object root")
    require(isinstance(archetype_rows, list), "archetypes.json must have an array root")
    require(isinstance(scenarios, dict), "scenarios.json must have an object root")

    archetypes: dict[str, dict[str, Any]] = {}
    for raw_archetype in archetype_rows:
        require(isinstance(raw_archetype, dict), "archetypes.json contains a non-object row")
        archetype_id = str(raw_archetype.get("id", "")).strip()
        require(archetype_id and archetype_id not in archetypes, f"invalid or duplicate archetype {archetype_id!r}")
        archetypes[archetype_id] = raw_archetype

    surface_rows = values(placement.get("maps"))
    surfaces: dict[str, dict[str, Any]] = {}
    map_order: list[str] = []
    for raw_surface in surface_rows:
        require(isinstance(raw_surface, dict), "placement_surfaces.json contains a non-object map")
        map_id = str(raw_surface.get("id", "")).strip()
        require(map_id and map_id not in surfaces, f"invalid or duplicate placement map {map_id!r}")
        archetype_id = str(raw_surface.get("archetype_id", map_id.split(":", 1)[0])).strip()
        require(archetype_id in archetypes, f"placement map {map_id} has unknown archetype {archetype_id}")
        layer_id = str(raw_surface.get("layer_id", "")).strip()
        if layer_id:
            require(layer_id in mapping(archetypes[archetype_id].get("layers")), f"placement map {map_id} has unknown layer {layer_id}")
        seen: set[str] = set()
        for family in FAMILIES:
            for slot in slots_for_family(raw_surface, family):
                validate_slot(slot, family, map_id, seen)
        surfaces[map_id] = raw_surface
        map_order.append(map_id)

    base_ids = unique_strings(values(authority.get("base_layout_ids")))
    template_ids = unique_strings(values(authority.get("template_map_ids")))
    require(len(base_ids) == EXPECTED_BASE_CONTEXTS, f"expected {EXPECTED_BASE_CONTEXTS} base contexts, found {len(base_ids)}")
    require(template_ids == [TEMPLATE_ONLY_MAP_ID], f"template-only maps must be exactly [{TEMPLATE_ONLY_MAP_ID!r}]")
    require(set(base_ids).isdisjoint(template_ids), "base and template-only map ids overlap")
    require(set(base_ids) | set(template_ids) == set(surfaces), "base/template ids do not exactly cover placement maps")

    catalog = scenario_catalog_rows(scenarios, archetypes)
    raw_layouts = values(authority.get("layouts"))
    require(len(raw_layouts) == EXPECTED_SCENARIO_CONTEXTS, f"expected {EXPECTED_SCENARIO_CONTEXTS} exact layouts, found {len(raw_layouts)}")
    require(int(authority.get("layout_count", -1)) == len(raw_layouts), "scenario layout_count is stale")
    layouts: dict[str, dict[str, Any]] = {}
    layouts_by_map: dict[str, list[dict[str, Any]]] = defaultdict(list)
    exact_slot_total = 0
    for raw_layout in raw_layouts:
        require(isinstance(raw_layout, dict), "scenario layout authority contains a non-object layout")
        map_id = str(raw_layout.get("map_id", "")).strip()
        scenario_id = str(raw_layout.get("scenario_id", "")).strip()
        layout_id = f"{map_id}::{scenario_id}"
        require(map_id in base_ids, f"scenario layout {layout_id} targets a non-reachable map")
        require(str(raw_layout.get("layout_id", "")) == layout_id, f"scenario layout {layout_id} has a noncanonical layout_id")
        require(layout_id not in layouts, f"duplicate scenario layout {layout_id}")
        require(layout_id in catalog, f"scenario layout {layout_id} is absent from scenarios.json")
        catalog_name = str(catalog[layout_id].get("display_name", scenario_id)).strip()
        require(str(raw_layout.get("display_name", scenario_id)).strip() == catalog_name, f"scenario layout {layout_id} has a stale display name")
        seen: set[str] = set()
        exact_slots = values(raw_layout.get("scenario_slots"))
        for raw_slot in exact_slots:
            require(isinstance(raw_slot, dict), f"scenario layout {layout_id} contains a non-object slot")
            validate_slot(raw_slot, "scenario", layout_id, seen)
            claimant_labels = unique_strings(values(raw_slot.get("scenario_occupant_labels")))
            require(claimant_labels, f"{layout_id}/{raw_slot.get('id', '<slot>')} has no scenario_occupant_labels")
        exact_slot_total += len(exact_slots)
        layouts[layout_id] = raw_layout
        layouts_by_map[map_id].append(raw_layout)
    require(set(layouts) == set(catalog), "scenario_slot_layouts.json does not exactly cover scenarios.json")
    require(int(authority.get("scenario_slot_count", -1)) == exact_slot_total, "scenario_slot_count is stale")
    declared_catalog_maps = set(unique_strings(values(authority.get("maps_with_catalog_scenarios"))))
    actual_catalog_maps = set(layouts_by_map)
    require(declared_catalog_maps == actual_catalog_maps, "maps_with_catalog_scenarios is stale")
    require(EXPECTED_BASE_CONTEXTS + len(layouts) == EXPECTED_CONTEXTS, "manual context census is not 75")

    for map_layouts in layouts_by_map.values():
        map_layouts.sort(key=lambda row: str(row.get("scenario_id", "")))
    reachable_order = [map_id for map_id in map_order if map_id in base_ids]
    titles = {map_id: map_title(surface, archetypes) for map_id, surface in surfaces.items()}
    base_slots = {
        map_id: effective_shared_slots(surfaces[map_id], map_id in actual_catalog_maps)
        for map_id in reachable_order
    }
    return {
        "placement": placement,
        "authority": authority,
        "surfaces": surfaces,
        "map_order": map_order,
        "reachable_order": reachable_order,
        "base_ids": set(base_ids),
        "template_ids": set(template_ids),
        "archetypes": archetypes,
        "catalog": catalog,
        "layouts": layouts,
        "layouts_by_map": layouts_by_map,
        "titles": titles,
        "base_slots": base_slots,
        "exact_slot_total": exact_slot_total,
    }


def fixed_label_indexes(surface: dict[str, Any]) -> tuple[dict[str, list[str]], dict[str, str]]:
    labels_by_slot: dict[str, list[str]] = defaultdict(list)
    label_by_object: dict[str, str] = {}
    for raw_object in values(surface.get("fixed_objects")):
        if not isinstance(raw_object, dict):
            continue
        label = str(raw_object.get("label", raw_object.get("display_name", raw_object.get("name", "")))).strip()
        if not label:
            continue
        slot_id = str(raw_object.get("exact_slot_id", raw_object.get("slot_id", ""))).strip()
        if slot_id and label not in labels_by_slot[slot_id]:
            labels_by_slot[slot_id].append(label)
        for field in ("object_id", "presentation_id"):
            object_id = str(raw_object.get(field, "")).strip()
            if object_id:
                label_by_object[object_id] = label
    return dict(labels_by_slot), label_by_object


def occupant_label(identifier: str, titles: dict[str, str]) -> str:
    clean = identifier.strip()
    if clean.startswith("travel:"):
        destination = clean.removeprefix("travel:")
        return titles.get(destination, friendly(destination))
    if clean in titles:
        return titles[clean]
    tokens = [token for token in re.split(r":+", clean) if token]
    return friendly(tokens[-1] if tokens else clean)


def shared_claimant_labels(
    surface: dict[str, Any], slot: dict[str, Any], titles: dict[str, str]
) -> list[str]:
    labels_by_slot, label_by_object = fixed_label_indexes(surface)
    slot_id = str(slot.get("id", ""))
    candidates: list[str] = list(labels_by_slot.get(slot_id, []))
    for raw_occupant in values(slot.get("occupant_ids")):
        occupant_id = str(raw_occupant).strip()
        if not occupant_id:
            continue
        candidates.append(label_by_object.get(occupant_id, occupant_label(occupant_id, titles)))
    labels = unique_strings(candidates)
    if labels:
        return labels
    if bool(slot.get("runtime_reserve", False)):
        return ["Runtime reserve (unclaimed)"]
    return ["Empty capacity"]


def placement_state(slot: dict[str, Any], claimant_labels: list[str], exact: bool = False) -> str:
    if exact:
        return "Provisional geometry" if bool(slot.get("provisional_geometry", False)) else "Exact scenario"
    if bool(slot.get("runtime_reserve", False)):
        reason = str(slot.get("reserve_reason", "")).strip()
        return f"Runtime reserve — {reason}" if reason else "Runtime reserve"
    if bool(slot.get("occupancy_required", False)):
        return "Required"
    if claimant_labels == ["Empty capacity"]:
        return "Optional empty capacity"
    return "Mapped capacity"


def labels_cell(labels: Iterable[str]) -> str:
    rendered = [markdown_text(label) for label in unique_strings(labels)]
    return "<br>".join(rendered) if rendered else "—"


def append_shared_table(
    lines: list[str], map_id: str, surface: dict[str, Any], slots: list[tuple[str, dict[str, Any]]], titles: dict[str, str]
) -> None:
    lines.append("| Family | Slot ID | Physical role | Footprint | Position | Support | Occupant/claimant labels | Placement state |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for family, slot in slots:
        labels = shared_claimant_labels(surface, slot, titles)
        support = str(slot.get("support_id", "")).strip()
        lines.append(
            "| %s | %s | %s | %s | %s | %s | %s | %s |"
            % (
                code(family),
                code(slot.get("id", "")),
                markdown_text(slot.get("physical_role", "")),
                code(slot.get("footprint_class", "")),
                code(position(slot, map_id)),
                code(support) if support else "—",
                labels_cell(labels),
                markdown_text(placement_state(slot, labels)),
            )
        )
    lines.append("")


def append_exact_table(lines: list[str], layout: dict[str, Any]) -> None:
    layout_id = str(layout.get("layout_id", ""))
    lines.append("| Slot ID | Physical role | Footprint | Position | Support | Actual claimant labels | Placement state |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- |")
    for slot in values(layout.get("scenario_slots")):
        labels = unique_strings(values(slot.get("scenario_occupant_labels")))
        support = str(slot.get("support_id", "")).strip()
        lines.append(
            "| %s | %s | %s | %s | %s | %s | %s |"
            % (
                code(slot.get("id", "")),
                markdown_text(slot.get("physical_role", "")),
                code(slot.get("footprint_class", "")),
                code(position(slot, layout_id)),
                code(support) if support else "—",
                labels_cell(labels),
                markdown_text(placement_state(slot, labels, exact=True)),
            )
        )
    lines.append("")


def render(model: dict[str, Any]) -> str:
    surfaces: dict[str, dict[str, Any]] = model["surfaces"]
    reachable_order: list[str] = model["reachable_order"]
    layouts_by_map: dict[str, list[dict[str, Any]]] = model["layouts_by_map"]
    titles: dict[str, str] = model["titles"]
    base_slots: dict[str, list[tuple[str, dict[str, Any]]]] = model["base_slots"]

    raw_counts: Counter[str] = Counter()
    for surface in surfaces.values():
        for family in FAMILIES:
            raw_counts[family] += len(slots_for_family(surface, family))
    base_counts: Counter[str] = Counter()
    for slots in base_slots.values():
        base_counts.update(family for family, _slot in slots)
    base_total = sum(base_counts.values())
    exact_total = int(model["exact_slot_total"])
    unique_manual_entries = base_total + exact_total
    full_snapshot_appearances = base_total + sum(
        len(base_slots[map_id]) + len(values(layout.get("scenario_slots")))
        for map_id, layouts in layouts_by_map.items()
        for layout in layouts
    )
    template = surfaces[TEMPLATE_ONLY_MAP_ID]
    template_counts = {family: len(slots_for_family(template, family)) for family in FAMILIES}
    provisional_total = sum(
        1
        for layout in model["layouts"].values()
        for slot in values(layout.get("scenario_slots"))
        if bool(slot.get("provisional_geometry", False))
    )

    lines: list[str] = [
        "# Environment scenario layout breakdown",
        "",
        "<!-- GENERATED by tools/generate_environment_scenario_layout_breakdown.py. Do not edit by hand. -->",
        "",
        "Status: **GENERATED MANUAL-PLACEMENT AUTHORITY GUIDE**.",
        "",
        "This guide is generated from these four runtime authorities:",
        "",
        f"- {code(PLACEMENT_PATH.relative_to(ROOT).as_posix())}",
        f"- {code(LAYOUT_PATH.relative_to(ROOT).as_posix())}",
        f"- {code(ARCHETYPE_PATH.relative_to(ROOT).as_posix())}",
        f"- {code(SCENARIO_PATH.relative_to(ROOT).as_posix())}",
        "",
        f"The manual pass has exactly **{EXPECTED_BASE_CONTEXTS} reachable base + {EXPECTED_SCENARIO_CONTEXTS} exact scenario = {EXPECTED_CONTEXTS} save contexts**. "
        f"The raw {code(TEMPLATE_ONLY_MAP_ID)} map is a **template-only source** for the layered Punchline rooms; it is not reachable as a save context and must not be counted or manually saved.",
        "",
        "## Slot ownership and movement rules",
        "",
        "| Family | Ownership rule |",
        "| --- | --- |",
        "| `fixed.*` | Guaranteed room content and stable capacity that belongs to every generated variation of that map. |",
        "| `event.*` | Capacity for independent random events that may or may not appear. |",
        "| `scenario.*` | Scenario-owned physical content, plus explicitly marked shared runtime reserves. Exact catalog scenarios have their own local slot bank. |",
        "| `exit.*` | Travel to another environment or to another layer/sub-environment. |",
        "",
        "Shared `fixed.*`, `event.*`, and `exit.*` positions are keyed by the stable **slot ID**, not by an occupant ID. An occupant/claimant label describes what currently uses the slot; changing the occupant does not create a new position. Moving one of these shared slots moves that slot for the base room and every exact scenario on the same map. Shared runtime-reserve `scenario.*` slots follow the same room-scoped rule.",
        "",
        "Exact scenario slots are saved under `map_id::scenario_id`. The same compact slot ID may appear in two scenarios, but those positions are independent because each exact layout has its own scope. Exact tables below show the generated **actual claimant labels**, including alternatives that share a slot at different moments in the scenario.",
        "",
        "For maps with catalog scenarios, Base / No Scenario includes only shared `scenario.*` slots marked as runtime reserves. Maps without catalog scenarios retain their shared scenario capacity in their one base context.",
        "",
        "## Manual placement workflow",
        "",
        "1. Open **Settings > Environment Library**.",
        "2. Choose an environment (and the specific layer for a layered venue), then load **Base / No Scenario**.",
        "3. Turn on **Empty capacity** and **Runtime reserves** so every authored slot in the table is visible.",
        "4. Move the fixed, event, shared scenario-reserve, and exit slots into their intended positions. Claimant labels are guidance; the slot ID is the saved identity.",
        "5. Press **Save Current Layout**. Do this even if the starting coordinates already look correct so the base context is explicitly marked complete.",
        "6. Read the overlay's **Progress** line and **Next missing** layout ID. They are the authoritative completion tracker.",
        "7. Return to the Environment Library and load every exact scenario listed for that map. Keep **Empty capacity** and **Runtime reserves** visible, place its local scenario slots around the shared room content, and press **Save Current Layout** for each one.",
        "8. Continue until progress is **75/75 saved**, then press **Export Placement Report** to produce the complete handoff report.",
        "",
        "Only one family tab is shown at a time, so even with **Empty capacity** and **Runtime reserves** enabled, you work through the full snapshot one family at a time instead of manipulating every slot simultaneously.",
        "",
        "`Save Current Layout` snapshots the full active context, including hidden families, empty capacity, and runtime reserves. A scenario save contains the shared room geometry plus its exact local slots, but it does not mark the separate Base / No Scenario context complete.",
        "",
        "## Generated census",
        "",
        "| Metric | Generated count |",
        "| --- | ---: |",
        f"| Reachable base contexts | {EXPECTED_BASE_CONTEXTS} |",
        f"| Exact scenario contexts | {EXPECTED_SCENARIO_CONTEXTS} |",
        f"| Total manual save contexts | **{EXPECTED_CONTEXTS}** |",
        f"| Reachable base-scoped slot positions | {base_total} |",
        f"| Exact scenario-local slot positions | {exact_total} |",
        f"| Unique manual position entries | **{unique_manual_entries}** |",
        f"| Slot appearances across all full save snapshots | {full_snapshot_appearances} |",
        f"| Exact slots with provisional geometry | {provisional_total} |",
        "",
        "The unique manual-position count adds each room-scoped shared slot once and each scenario-local slot once. The larger full-snapshot count repeats shared geometry in every scenario snapshot, matching what **Save Current Layout** validates.",
        "",
        "### Raw source inventory",
        "",
        "| Scope | Fixed | Event | Scenario | Exit | Total |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
        f"| All {len(surfaces)} raw placement maps | {raw_counts['fixed']} | {raw_counts['event']} | {raw_counts['scenario']} | {raw_counts['exit']} | {sum(raw_counts.values())} |",
        f"| Template-only {code(TEMPLATE_ONLY_MAP_ID)} | {template_counts['fixed']} | {template_counts['event']} | {template_counts['scenario']} | {template_counts['exit']} | {sum(template_counts.values())} |",
        f"| Reachable effective base contexts | {base_counts['fixed']} | {base_counts['event']} | {base_counts['scenario']} | {base_counts['exit']} | {base_total} |",
        "",
        "The raw inventory includes generic source scenario capacity and the template-only parent. It is not the manual completion total.",
        "",
        "### Per-map summary",
        "",
        "| Environment | Base layout ID | Fixed | Event | Shared scenario | Exit | Base total | Exact layouts | Exact local slots | Unique entries |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]

    for map_id in reachable_order:
        counts = Counter(family for family, _slot in base_slots[map_id])
        map_layouts = layouts_by_map.get(map_id, [])
        local_count = sum(len(values(layout.get("scenario_slots"))) for layout in map_layouts)
        lines.append(
            "| %s<br>%s | %s | %d | %d | %d | %d | %d | %d | %d | %d |"
            % (
                markdown_text(titles[map_id]),
                code(map_id),
                code(f"{map_id}::__base"),
                counts["fixed"],
                counts["event"],
                counts["scenario"],
                counts["exit"],
                len(base_slots[map_id]),
                len(map_layouts),
                local_count,
                len(base_slots[map_id]) + local_count,
            )
        )
    lines.extend(
        [
            "| **Reachable total** | **20 bases** | **%d** | **%d** | **%d** | **%d** | **%d** | **55** | **%d** | **%d** |"
            % (base_counts["fixed"], base_counts["event"], base_counts["scenario"], base_counts["exit"], base_total, exact_total, unique_manual_entries),
            "",
            "### Exact scenario summary",
            "",
            "| Exact layout ID | Scenario | Shared slots | Local slots | Full save slots | Claimant labels | Provisional | Action-only IDs |",
            "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for map_id in reachable_order:
        shared_count = len(base_slots[map_id])
        for layout in layouts_by_map.get(map_id, []):
            exact_slots = values(layout.get("scenario_slots"))
            claimant_count = sum(len(unique_strings(values(slot.get("scenario_occupant_labels")))) for slot in exact_slots)
            provisional = sum(1 for slot in exact_slots if bool(slot.get("provisional_geometry", False)))
            action_only = len(values(mapping(layout.get("audit")).get("action_only_ids")))
            lines.append(
                "| %s | %s | %d | %d | %d | %d | %d | %d |"
                % (
                    code(layout.get("layout_id", "")),
                    markdown_text(layout.get("display_name", "")),
                    shared_count,
                    len(exact_slots),
                    shared_count + len(exact_slots),
                    claimant_count,
                    provisional,
                    action_only,
                )
            )

    lines.extend(
        [
            "",
            "## Template-only source",
            "",
            f"{markdown_text(titles[TEMPLATE_ONLY_MAP_ID])} ({code(TEMPLATE_ONLY_MAP_ID)}) is retained only as raw layered-source geometry. It has no {code(f'{TEMPLATE_ONLY_MAP_ID}::__base')} completion context. Use the reachable `:club`, `:casino`, and `:back_room` maps instead.",
            "",
            "## Detailed placement guide",
            "",
            "Positions are canonical 900×430 board coordinates. Base tables list the exact effective slots loaded by Base / No Scenario. Exact tables list only the scenario-local additions; every scenario's full save also includes the shared base rows immediately above it.",
            "",
        ]
    )

    for map_id in reachable_order:
        surface = surfaces[map_id]
        map_layouts = layouts_by_map.get(map_id, [])
        counts = Counter(family for family, _slot in base_slots[map_id])
        lines.extend(
            [
                f"### {markdown_text(titles[map_id])} — {code(map_id)}",
                "",
                f"#### Base / No Scenario — {code(f'{map_id}::__base')}",
                "",
                "**Save snapshot:** %d slots = %d fixed + %d event + %d shared scenario + %d exit. Exact scenarios on this map: %d."
                % (len(base_slots[map_id]), counts["fixed"], counts["event"], counts["scenario"], counts["exit"], len(map_layouts)),
                "",
            ]
        )
        append_shared_table(lines, map_id, surface, base_slots[map_id], titles)
        if not map_layouts:
            lines.extend(["This map has no exact catalog scenario. Its manual coverage ends with the base context.", ""])
            continue
        for layout in map_layouts:
            exact_slots = values(layout.get("scenario_slots"))
            lines.extend(
                [
                    f"#### Scenario — {markdown_text(layout.get('display_name', ''))} — {code(layout.get('layout_id', ''))}",
                    "",
                    "**Full save:** %d slots = %d shared + %d exact scenario-local. The shared slot positions remain keyed by the base table's slot IDs."
                    % (len(base_slots[map_id]) + len(exact_slots), len(base_slots[map_id]), len(exact_slots)),
                    "",
                ]
            )
            append_exact_table(lines, layout)
            action_only_ids = unique_strings(values(mapping(layout.get("audit")).get("action_only_ids")))
            if action_only_ids:
                lines.extend(
                    [
                        "**Action-only IDs (%d; no placement marker):** %s"
                        % (len(action_only_ids), "<br>".join(code(item) for item in action_only_ids)),
                        "",
                    ]
                )

    lines.extend(
        [
            "## Regeneration",
            "",
            "Regenerate after changing any of the four source authorities:",
            "",
            "```text",
            "python tools/generate_environment_scenario_layout_breakdown.py",
            "```",
            "",
            "Validation uses the non-writing stale-file check:",
            "",
            "```text",
            "python tools/generate_environment_scenario_layout_breakdown.py --check",
            "```",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail when the generated guide is missing or stale")
    args = parser.parse_args()
    try:
        model = build_model()
        output = render(model).encode("utf-8")
    except ValueError as error:
        print(f"ENVIRONMENT_SCENARIO_LAYOUT_BREAKDOWN ERROR: {error}", file=sys.stderr)
        return 2
    if args.check:
        if not OUTPUT_PATH.exists() or OUTPUT_PATH.read_bytes() != output:
            print(
                "environment scenario layout breakdown is missing or stale; run "
                "python tools/generate_environment_scenario_layout_breakdown.py",
                file=sys.stderr,
            )
            return 1
        print(
            "ENVIRONMENT_SCENARIO_LAYOUT_BREAKDOWN_CHECK PASS "
            f"base={EXPECTED_BASE_CONTEXTS} scenarios={EXPECTED_SCENARIO_CONTEXTS} contexts={EXPECTED_CONTEXTS} "
            f"exact_slots={model['exact_slot_total']}"
        )
        return 0
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_bytes(output)
    print(
        "Generated environment scenario layout breakdown: "
        f"base={EXPECTED_BASE_CONTEXTS} scenarios={EXPECTED_SCENARIO_CONTEXTS} contexts={EXPECTED_CONTEXTS} "
        f"exact_slots={model['exact_slot_total']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
