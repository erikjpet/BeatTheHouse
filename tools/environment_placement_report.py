#!/usr/bin/env python3
"""Verify an exported schema-3 placement report before producing authority JSON.

The default operation is a dry run.  No file is written unless ``--output`` is
provided explicitly, and even then the destination is an ordinary preview file;
this tool never chooses or overwrites the project's committed authority path.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SURFACES_REL = Path("data/environments/placement_surfaces.json")
SCENARIOS_REL = Path("data/environments/scenario_slot_layouts.json")
REPORT_SCHEMA = "beat_the_house.environment_placement_report/v1"
EXPECTED_BASE = 20
EXPECTED_SCENARIO = 55
EXPECTED_TOTAL = 75
HEX40 = re.compile(r"^[0-9a-f]{40}$")


class ReportError(ValueError):
    pass


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ReportError(message)


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ReportError(f"cannot read JSON {path}: {exc}") from exc
    _require(isinstance(value, dict), f"{path} must contain a JSON object")
    return value


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _git(root: Path, *args: str, text: bool = True) -> str | bytes:
    result = subprocess.run(
        ["git", *args], cwd=root, capture_output=True, text=text, check=False
    )
    if result.returncode != 0:
        error = result.stderr.strip() if text else result.stderr.decode(errors="replace").strip()
        raise ReportError(f"git {' '.join(args)} failed: {error}")
    return result.stdout.strip() if text else result.stdout


def _slot_ids(slots: Any, label: str) -> set[str]:
    _require(isinstance(slots, list), f"{label} must be an array")
    result: set[str] = set()
    for index, slot in enumerate(slots):
        _require(isinstance(slot, dict), f"{label}[{index}] must be an object")
        slot_id = slot.get("id")
        _require(isinstance(slot_id, str) and slot_id.strip() == slot_id and slot_id, f"{label}[{index}] has an invalid id")
        _require(slot_id not in result, f"{label} contains duplicate slot id {slot_id}")
        result.add(slot_id)
    return result


def expected_authority(root: Path = ROOT) -> tuple[dict[str, set[str]], dict[str, dict[str, set[str]]]]:
    surfaces = _read_json(root / SURFACES_REL)
    scenarios = _read_json(root / SCENARIOS_REL)
    base_ids = scenarios.get("base_layout_ids")
    layouts = scenarios.get("layouts")
    _require(isinstance(base_ids, list) and all(isinstance(v, str) for v in base_ids), "base_layout_ids must be a string array")
    _require(isinstance(layouts, list), "scenario layouts must be an array")
    _require(len(base_ids) == EXPECTED_BASE and len(set(base_ids)) == EXPECTED_BASE, "authority must define exactly 20 unique base layouts")
    _require(len(layouts) == EXPECTED_SCENARIO, "authority must define exactly 55 scenario layouts")

    scenarios_by_room: dict[str, dict[str, set[str]]] = {room: {} for room in base_ids}
    for index, layout in enumerate(layouts):
        _require(isinstance(layout, dict), f"layouts[{index}] must be an object")
        room = layout.get("map_id")
        scenario = layout.get("scenario_id")
        _require(room in scenarios_by_room and isinstance(scenario, str) and scenario, f"layouts[{index}] has invalid room/scenario identity")
        _require(scenario not in scenarios_by_room[room], f"duplicate layout {room}::{scenario}")
        scenarios_by_room[room][scenario] = _slot_ids(layout.get("scenario_slots"), f"{room}::{scenario}.scenario_slots")

    maps = surfaces.get("maps")
    _require(isinstance(maps, list), "placement surfaces maps must be an array")
    maps_by_id: dict[str, dict[str, Any]] = {}
    for item in maps:
        _require(isinstance(item, dict) and isinstance(item.get("id"), str), "surface map has invalid identity")
        map_id = item["id"]
        _require(map_id not in maps_by_id, f"duplicate surface map {map_id}")
        maps_by_id[map_id] = item
    _require(set(base_ids) <= set(maps_by_id), "one or more base layouts have no placement surface")

    shared_by_room: dict[str, set[str]] = {}
    for room in base_ids:
        item = maps_by_id[room]
        shared: set[str] = set()
        for family in ("fixed_slots", "event_slots", "exit_slots"):
            family_ids = _slot_ids(item.get(family), f"{room}.{family}")
            _require(not (shared & family_ids), f"{room} repeats a shared slot id across families")
            shared |= family_ids
        scenario_slots = item.get("scenario_slots")
        _slot_ids(scenario_slots, f"{room}.scenario_slots")
        for slot in scenario_slots:
            if bool(slot.get("runtime_reserve", False)) or not scenarios_by_room[room]:
                _require(slot["id"] not in shared, f"{room} repeats shared slot id {slot['id']}")
                shared.add(slot["id"])
        shared_by_room[room] = shared
    return shared_by_room, scenarios_by_room


def _validate_positions(value: Any, expected: set[str], label: str) -> int:
    _require(isinstance(value, dict), f"{label} must be an object")
    actual = set(value)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    _require(not missing and not extra, f"{label} slot set mismatch; missing={missing}, unexpected={extra}")
    for slot_id, position in value.items():
        _require(isinstance(position, list) and len(position) == 2, f"{label}.{slot_id} must be [x, y]")
        for coordinate in position:
            _require(type(coordinate) in (int, float) and math.isfinite(coordinate), f"{label}.{slot_id} coordinates must be finite numbers")
    return len(value)


def validate_report(report_path: Path, root: Path = ROOT) -> tuple[dict[str, Any], dict[str, Any]]:
    report = _read_json(report_path)
    _require(report.get("schema_version") == 3, "report schema_version must be integer 3")
    rooms = report.get("rooms")
    coverage = report.get("coverage")
    metadata = report.get("report_metadata")
    _require(isinstance(rooms, dict), "report rooms must be an object")
    _require(isinstance(coverage, dict), "report coverage must be an object")
    _require(isinstance(metadata, dict), "report_metadata must be an object")
    _require(metadata.get("schema") == REPORT_SCHEMA, f"report_metadata.schema must be {REPORT_SCHEMA}")
    _require(metadata.get("report_scope") == "effective_reviewed_authority", "report must contain effective reviewed authority")

    shared_by_room, scenarios_by_room = expected_authority(root)
    expected_rooms = set(shared_by_room)
    _require(set(rooms) == expected_rooms, f"room set mismatch; missing={sorted(expected_rooms-set(rooms))}, unexpected={sorted(set(rooms)-expected_rooms)}")
    slot_count = 0
    for room_id in sorted(expected_rooms):
        room = rooms[room_id]
        _require(isinstance(room, dict), f"rooms.{room_id} must be an object")
        _require(set(room) <= {"slot_positions", "base_saved", "scenario_layouts"}, f"rooms.{room_id} has unsupported fields")
        _require(room.get("base_saved") is True, f"rooms.{room_id}.base_saved must be true")
        slot_count += _validate_positions(room.get("slot_positions"), shared_by_room[room_id], f"rooms.{room_id}.slot_positions")
        layouts = room.get("scenario_layouts")
        _require(isinstance(layouts, dict), f"rooms.{room_id}.scenario_layouts must be an object")
        _require(set(layouts) == set(scenarios_by_room[room_id]), f"rooms.{room_id}.scenario_layouts set is incomplete or unexpected")
        for scenario_id, expected_slots in scenarios_by_room[room_id].items():
            layout = layouts[scenario_id]
            _require(isinstance(layout, dict) and set(layout) <= {"slot_positions", "saved"}, f"{room_id}::{scenario_id} has invalid fields")
            _require(layout.get("saved") is True, f"{room_id}::{scenario_id}.saved must be true")
            slot_count += _validate_positions(layout.get("slot_positions"), expected_slots, f"{room_id}::{scenario_id}.slot_positions")

    required_coverage = {
        "expected_base_layout_count": EXPECTED_BASE,
        "expected_scenario_layout_count": EXPECTED_SCENARIO,
        "expected_layout_count": EXPECTED_TOTAL,
        "saved_base_layout_count": EXPECTED_BASE,
        "saved_scenario_layout_count": EXPECTED_SCENARIO,
        "saved_layout_count": EXPECTED_TOTAL,
    }
    for key, expected in required_coverage.items():
        _require(coverage.get(key) == expected, f"coverage.{key} must equal {expected}")
    for key in ("missing_base_layout_ids", "missing_scenario_layout_ids", "missing_layout_ids", "unexpected_layout_ids"):
        _require(coverage.get(key) == [], f"coverage.{key} must be empty")
    _require(coverage.get("complete") is True, "coverage.complete must be true")
    _require(coverage.get("next_missing_layout_id", "") == "", "coverage.next_missing_layout_id must be empty")

    surface_bytes = (root / SURFACES_REL).read_bytes()
    scenario_bytes = (root / SCENARIOS_REL).read_bytes()
    surface_hash = _sha256(surface_bytes)
    scenario_hash = _sha256(scenario_bytes)
    _require(metadata.get("placement_surfaces_sha256") == surface_hash, "placement surface authority hash does not match this checkout")
    _require(metadata.get("scenario_slot_layouts_sha256") == scenario_hash, "scenario layout authority hash does not match this checkout")
    _require(metadata.get("effective_room_count") == EXPECTED_BASE, "metadata effective_room_count must be 20")
    _require(metadata.get("effective_slot_count") == slot_count, "metadata effective_slot_count is incorrect")

    commit = metadata.get("source_commit")
    tree = metadata.get("source_tree")
    _require(isinstance(commit, str) and HEX40.fullmatch(commit) is not None, "source_commit must be a full lowercase Git SHA-1")
    _require(isinstance(tree, str) and HEX40.fullmatch(tree) is not None, "source_tree must be a full lowercase Git SHA-1")
    _require(_git(root, "rev-parse", f"{commit}^{{tree}}") == tree, "source_tree does not belong to source_commit")
    _git(root, "merge-base", "--is-ancestor", commit, "HEAD")
    committed_surface = _git(root, "show", f"{commit}:{SURFACES_REL.as_posix()}", text=False)
    committed_scenarios = _git(root, "show", f"{commit}:{SCENARIOS_REL.as_posix()}", text=False)
    # Git may normalize checkout line endings on Windows.  The report hashes the
    # runtime files byte-for-byte, while provenance must therefore compare the
    # committed and checked-out JSON values semantically.
    _require(json.loads(committed_surface) == json.loads(surface_bytes), "source_commit placement surface authority does not match report provenance")
    _require(json.loads(committed_scenarios) == json.loads(scenario_bytes), "source_commit scenario layout authority does not match report provenance")

    authority = {"schema_version": 3, "rooms": rooms}
    canonical = (json.dumps(authority, indent=2, sort_keys=True) + "\n").encode()
    summary = {
        "ok": True,
        "dry_run": True,
        "source_commit": commit,
        "source_tree": tree,
        "rooms": len(rooms),
        "base_layouts": EXPECTED_BASE,
        "scenario_layouts": EXPECTED_SCENARIO,
        "total_layouts": EXPECTED_TOTAL,
        "slots": slot_count,
        "authority_sha256": _sha256(canonical),
    }
    return authority, summary


def _write_explicit(path: Path, authority: dict[str, Any]) -> None:
    path = path.resolve()
    committed_path = (ROOT / "data/environments/developer_placement_overrides.json").resolve()
    _require(path != committed_path, "refusing to overwrite committed project authority; write a preview file for review")
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(authority, indent=2, sort_keys=True) + "\n"
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path, help="explicit preview output; never defaults to project authority")
    args = parser.parse_args()
    try:
        authority, summary = validate_report(args.report.resolve())
        if args.output:
            _write_explicit(args.output, authority)
            summary["dry_run"] = False
            summary["output"] = str(args.output.resolve())
        print(json.dumps(summary, sort_keys=True))
        return 0
    except ReportError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
