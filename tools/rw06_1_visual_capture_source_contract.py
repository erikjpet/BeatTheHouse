#!/usr/bin/env python3
"""Engine-free semantic contract for rw06_1 visual-evidence capture."""

from __future__ import annotations

import argparse
import copy
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


FUNC_START = re.compile(r"(?m)^func\s+([A-Za-z0-9_]+)\([^\n]*\)(?:\s*->\s*[^:]+)?:\s*$")


def _strip_comments(text: str) -> str:
    """Strip GDScript comments without treating # inside a string as a comment."""
    output: list[str] = []
    for line in text.splitlines():
        quoted = False
        escaped = False
        kept: list[str] = []
        for character in line:
            if character == "#" and not quoted:
                break
            kept.append(character)
            if escaped:
                escaped = False
            elif character == "\\" and quoted:
                escaped = True
            elif character == '"':
                quoted = not quoted
        output.append("".join(kept))
    return "\n".join(output)


def _functions(source: str) -> dict[str, str]:
    matches = list(FUNC_START.finditer(source))
    return {
        match.group(1): source[match.start() : (matches[index + 1].start() if index + 1 < len(matches) else len(source))]
        for index, match in enumerate(matches)
    }


@dataclass
class Contract:
    source: str

    def __post_init__(self) -> None:
        self.failures: list[str] = []
        self.functions = _functions(self.source)
        self.code = _strip_comments(self.source)

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.failures.append(message)

    def body(self, name: str) -> str:
        raw = self.functions.get(name, "")
        self.require(bool(raw), f"missing function {name}")
        return _strip_comments(raw)

    def matches(self, body: str, pattern: str, message: str) -> None:
        self.require(re.search(pattern, body, re.MULTILINE | re.DOTALL) is not None, message)

    def ordered(self, body: str, tokens: tuple[str, ...], message: str) -> None:
        positions = [body.find(token) for token in tokens]
        self.require(all(position >= 0 for position in positions) and positions == sorted(positions), message)


def _strict_static_report(report: object) -> bool:
    if type(report) is not dict:
        return False
    if report.get("tool") != "environment_fixed_slot_static_check" or type(report.get("tool")) is not str:
        return False
    if type(report.get("passed")) is not bool or report["passed"] is not True:
        return False
    if type(report.get("error_count")) is not int or report["error_count"] != 0:
        return False
    if type(report.get("errors")) is not list or report["errors"]:
        return False
    if type(report.get("contact_sheet")) is not list or not report["contact_sheet"]:
        return False
    if type(report.get("active_scenarios")) is not list or not report["active_scenarios"]:
        return False
    counts = report.get("counts")
    if type(counts) is not dict:
        return False
    exact = {
        "archetypes": 18,
        "scenarios": 55,
        "legal_hosts": 55,
        "historical_exact_seeds": 22,
        "base_scenario_conflicts": 0,
        "base_base_conflicts": 0,
    }
    if any(type(counts.get(key)) is not int or counts[key] != value for key, value in exact.items()):
        return False
    for key in ("maps", "active_snapshots", "active_bindings", "complete_snapshots"):
        if type(counts.get(key)) is not int:
            return False
    return (
        counts["maps"] >= 18
        and counts["active_snapshots"] > 0
        and counts["active_bindings"] > 0
        and counts["complete_snapshots"] >= counts["active_snapshots"]
    )


def _coverage_model(pixels: list[list[tuple[int, int, int, int]]]) -> bool:
    if not pixels or not pixels[0]:
        return False
    height, width = len(pixels), len(pixels[0])
    if any(len(row) != width for row in pixels):
        return False
    cells: list[list[tuple[int, int]]] = [[] for _ in range(12)]
    global_buckets: set[int] = set()
    opaque = 0
    luminances: list[int] = []
    for y, row in enumerate(pixels):
        for x, (red, green, blue, alpha) in enumerate(row):
            if alpha < 192:
                continue
            opaque += 1
            luma = round(0.2126 * red + 0.7152 * green + 0.0722 * blue)
            bucket = ((red >> 4) << 8) | ((green >> 4) << 4) | (blue >> 4)
            global_buckets.add(bucket)
            luminances.append(luma)
            cell = min(2, y * 3 // height) * 4 + min(3, x * 4 // width)
            cells[cell].append((bucket, luma))
    occupied = sum(bool(cell) for cell in cells)
    variant = sum(len({item[0] for item in cell}) >= 2 and max(item[1] for item in cell) - min(item[1] for item in cell) >= 8 for cell in cells if cell)
    ratio = opaque / (width * height)
    span = max(luminances) - min(luminances) if luminances else 0
    return ratio >= 0.08 and occupied >= 8 and variant >= 8 and len(global_buckets) >= 12 and span >= 32


def _hostile_fixture_checks() -> list[str]:
    failures: list[str] = []
    base_counts = {
        "maps": 21,
        "archetypes": 18,
        "scenarios": 55,
        "legal_hosts": 55,
        "active_snapshots": 10,
        "active_bindings": 20,
        "complete_snapshots": 12,
        "historical_exact_seeds": 22,
        "base_scenario_conflicts": 0,
        "base_base_conflicts": 0,
    }
    valid = {
        "tool": "environment_fixed_slot_static_check",
        "passed": True,
        "error_count": 0,
        "errors": [],
        "counts": base_counts,
        "contact_sheet": [{}],
        "active_scenarios": [{}],
    }
    if not _strict_static_report(valid):
        failures.append("independent strict static-report model rejected its valid fixture")
    hostile_reports: list[dict[str, object]] = []
    for mutate in (
        lambda row: row.update(passed="true"),
        lambda row: row.update(error_count=False),
        lambda row: row.update(errors=["hidden"]),
        lambda row: row.update(tool="decoy"),
        lambda row: row["counts"].update(active_snapshots="10"),
        lambda row: row["counts"].update(complete_snapshots=9),
    ):
        candidate = copy.deepcopy(valid)
        mutate(candidate)
        hostile_reports.append(candidate)
    if any(_strict_static_report(row) for row in hostile_reports):
        failures.append("independent strict static-report model accepted a hostile fixture")

    width, height = 48, 36
    varied = [
        [((x * 17 + y * 5) % 256, (x * 7 + y * 19) % 256, (x * 23 + y * 3) % 256, 255) for x in range(width)]
        for y in range(height)
    ]
    transparent = [[(0, 0, 0, 0) for _ in range(width)] for _ in range(height)]
    two_pixels = copy.deepcopy(transparent)
    two_pixels[0][0], two_pixels[-1][-1] = (255, 255, 0, 255), (0, 0, 255, 255)
    localized = [[(24, 24, 24, 255) for _ in range(width)] for _ in range(height)]
    for y in range(4):
        for x in range(12):
            localized[y][x] = ((x * 21) % 256, (y * 73) % 256, 255, 255)
    flat = [[(80, 80, 80, 255) for _ in range(width)] for _ in range(height)]
    if not _coverage_model(varied):
        failures.append("independent coverage model rejected distributed varied pixels")
    for label, fixture in (("transparent", transparent), ("two-pixel", two_pixels), ("localized", localized), ("flat", flat)):
        if _coverage_model(fixture):
            failures.append(f"independent coverage model accepted hostile {label} pixels")
    return failures


def _run_source_checks(source: str) -> list[str]:
    check = Contract(source)
    for declaration in (
        r"^const RW06_1_SOURCE_CAPTURE_SIZE := Vector2i\(1280, 720\)$",
        r"^const RW06_1_Q008_SHEET_SIZE := Vector2i\(960, 360\)$",
        r"^const RW06_1_CAPTURE_BASE_PATH := \"res://\.tmp/rw06_1/visual_evidence\"$",
        r"^const RW06_1_MIN_VARIANT_GRID_CELLS := 8$",
    ):
        check.require(re.search(declaration, check.code, re.MULTILINE) is not None, f"missing exact authority declaration: {declaration}")

    run = check.body("_run")
    check.ordered(run, ("_rw06_1_claim_capture_root()", "MainScene.instantiate()"), "capture root must be claimed before app creation")

    claim = check.body("_rw06_1_claim_capture_root")
    for pattern, message in (
        (r"_rw06_1_path_is_inside\(candidate, allowed_base\)", "claim lacks base containment"),
        (r"DirAccess\.dir_exists_absolute\(candidate\)", "claim does not require a precreated root"),
        (r"_rw06_1_path_has_link_boundary\(candidate\)", "claim does not reject reparse/link roots"),
        (r"directory\.list_dir_begin\(\)", "claim does not enumerate freshness"),
        (r"not first_entry\.is_empty\(\)", "claim does not reject nonempty roots"),
        (r"owner_file\.get_error\(\)", "claim does not check marker write status"),
        (r"owner_text != rw06_1_capture_owner_token", "claim does not verify marker bytes"),
    ):
        check.matches(claim, pattern, message)

    remove_file = check.body("_rw06_1_remove_file")
    for pattern, message in (
        (r"^\s*elif not rw06_1_manifest_files\.has\(manifest_key\):", "cleanup is not manifest confined"),
        (r"^\s*elif not _rw06_1_capture_ownership_is_valid\(\):", "cleanup is not owner-marker bound"),
        (r"^\s*elif _rw06_1_path_has_link_boundary\(absolute_path\):", "cleanup does not reject link/reparse paths"),
        (r"^\s*var remove_error := DirAccess\.remove_absolute\(absolute_path\)$", "cleanup does not capture removal Error"),
        (r"^\s*if remove_error != OK:$", "cleanup does not reject a removal Error"),
        (r"^\s*if FileAccess\.file_exists\(absolute_path\) or DirAccess\.dir_exists_absolute\(absolute_path\):", "cleanup does not verify absence"),
        (r'^\s*return \{"ok": failures\.is_empty\(\), "path": absolute_path, "absent": failures\.is_empty\(\), "errors": failures\}$', "cleanup success is not derived from verified failures"),
    ):
        check.matches(remove_file, pattern, message)
    check.require("func _rw06_1_remove_png_files" not in check.code, "unsafe directory-wide PNG cleanup still exists")
    cleanup = check.body("_rw06_1_cleanup_paths")
    check.matches(cleanup, r'not bool\(removal\.get\("ok", false\)\) or not bool\(removal\.get\("absent", false\)\)', "set cleanup does not inspect every removal result")

    static_schema = check.body("_rw06_1_validate_static_report")
    for pattern, message in (
        (r'typeof\(report\.get\("tool", null\)\) != TYPE_STRING.*environment_fixed_slot_static_check', "static tool identity/type is not strict"),
        (r'typeof\(report\.get\("passed", null\)\) != TYPE_BOOL or not report\.get\("passed", false\)', "static passed flag/type is not strict"),
        (r'_rw06_1_json_integer\(report\.get\("error_count", null\)\).*!= 0', "static error_count is not strict zero"),
        (r'typeof\(report\.get\("errors", null\)\) != TYPE_ARRAY.*\.is_empty\(\)', "static errors are not a native empty array"),
        (r'"archetypes": RW06_1_CONTACT_ROOM_COUNT.*"scenarios": 55.*"legal_hosts": 55.*"historical_exact_seeds": 22', "static exact coverage counts are missing"),
        (r'complete_snapshots.*< int\(counts\.get\("active_snapshots"', "static complete/active coverage relationship is missing"),
    ):
        check.matches(static_schema, pattern, message)
    for runner, selector in (("_run_rw06_1_contact_sheet", "_rw06_1_contact_selections"), ("_run_rw06_1_q008", "_rw06_1_q008_selections")):
        body = check.body(runner)
        check.ordered(body, ("_rw06_1_read_json_evidence", "_rw06_1_validate_static_report", selector), f"{runner} scans rows before strict report validation")
        check.matches(body, r'if bool\([^\n]*cleanup[^\n]*get\("ok", false\)\).*get\("all_absent", false\).*:\s*\n\s+[^\n]*\.clear\(\)', f"{runner} clears rows without verified cleanup")
        check.matches(body, r"report_write := _write_fix06_31_json.*if not bool\(report_write\.get\(\"ok\", false\)\).*_rw06_1_cleanup_paths", f"{runner} does not fail-clean a JSON write failure")

    geometry = check.body("_rw06_1_validate_interaction_geometry")
    for token in (
        'view_snapshot.get("object_layout", null)',
        'view_snapshot.get("objects", null)',
        '["interaction_rect", "label_rect"]',
        'object_data.get(rect_key, null)',
        '_rw06_1_rect_pair_overlaps(objects, "interaction_rect")',
        '_rw06_1_rect_pair_overlaps(objects, "label_rect")',
        'layout.get("overlap_count", null)',
        'layout.get("overlaps", null)',
        'layout.get("label_layout", null)',
        '"resolved_label_overlap_count"',
        '"resolved_object_overlap_count"',
        '"ok": failures.is_empty()',
    ):
        check.require(token in geometry, f"strict geometry validation is missing executable token: {token}")

    identity = check.body("_rw06_1_rendered_identity")
    check.matches(
        identity,
        r'"uses_foundation_snapshot": typeof\(view_snapshot\.get\("uses_foundation_snapshot", null\)\) == TYPE_BOOL\s+and bool\(view_snapshot\.get\("uses_foundation_snapshot", false\)\)',
        "active renderer identity does not require native true uses_foundation_snapshot",
    )
    for token in (
        'view_snapshot.get("environment_id", null)',
        'view_snapshot.get("scenario_layout_authority_digest", "")',
        'rendered_environment.get("scenario_layout_authority_digest", "")',
        'active_object_ids == layout_object_ids',
        'view_snapshot.get("small_screen_mode", null)',
    ):
        check.require(token in identity, f"active renderer identity is not bound by: {token}")

    for name in ("_rw06_1_capture_pair", "_rw06_1_capture_normal_source"):
        body = check.body(name)
        check.ordered(body, ("current_view_snapshot", "_rw06_1_rendered_identity", "_rw06_1_validate_interaction_geometry", "image.save_png"), f"{name} does not reject active identity/geometry before save")

    coverage = check.body("_rw06_1_image_coverage")
    for condition in (
        "opaque_ratio < RW06_1_MIN_OPAQUE_SAMPLE_RATIO",
        "occupied_grid_cells < RW06_1_MIN_OCCUPIED_GRID_CELLS",
        "variant_grid_cells < RW06_1_MIN_VARIANT_GRID_CELLS",
        "global_color_buckets.size() < RW06_1_MIN_COLOR_BUCKETS",
        "luma_span < RW06_1_MIN_LUMA_SPAN",
    ):
        check.require(condition in coverage, f"distributed image coverage omits threshold: {condition}")
    png = check.body("_rw06_1_validate_png")
    check.matches(png, r"coverage = _rw06_1_image_coverage\(image\).*nonblank = bool\(coverage\.get\(\"ok\", false\)\).*\"ok\": failures\.is_empty\(\)", "PNG success is not derived from decode/dimensions/distributed coverage failures")

    expected_seed = check.body("_rw06_1_expected_capture_seed")
    check.require("RW06-1-CONTACT-BASE:%s" in expected_seed and "RW06-1-CONTACT-%s" in expected_seed, "expected seed authority is incomplete")
    provenance = check.body("_rw06_1_generation_identity")
    for token in ('"seed_text_exact"', 'actual_seed_text == expected_seed_text', '"environment_map_exact"', '"identity_key"', '"ok": failures.is_empty()'):
        check.require(token in provenance, f"capture provenance does not assert: {token}")
    for name in ("_rw06_1_contact_generation_identity", "_rw06_1_q008_generation_identity"):
        body = check.body(name)
        check.require("seen_identity_keys.has(identity_key)" in body and "identity_key.is_empty()" in body, f"{name} does not reject empty/duplicate identities")

    writer = check.body("_write_fix06_31_json")
    for token in ("file.flush()", "file.get_error()", "FileAccess.file_exists(path)", "FileAccess.open(path, FileAccess.READ)", "stored_text != encoded", "FileAccess.get_sha256(path)", '"ok": failures.is_empty()'):
        check.require(token in writer, f"checked JSON writer is missing: {token}")
    check.failures.extend(_hostile_fixture_checks())
    return check.failures


def _replace_function(source: str, name: str, transform: Callable[[str], str]) -> str:
    functions = _functions(source)
    original = functions[name]
    changed = transform(original)
    if changed == original:
        raise AssertionError(f"hostile mutation for {name} made no change")
    return source.replace(original, changed, 1)


def _hostile_mutations(source: str) -> list[tuple[str, str]]:
    def replace_once(old: str, new: str) -> Callable[[str], str]:
        def apply(body: str) -> str:
            if old not in body:
                raise AssertionError(f"mutation needle missing: {old}")
            return body.replace(old, new, 1)
        return apply

    def noop_with_decoys(body: str) -> str:
        header = body.split("\n", 1)[0]
        decoy = " | ".join(line.strip() for line in _strip_comments(body).splitlines()[1:] if line.strip()).replace('"', "'")
        return header + f'\n\tvar decoy := "{decoy}"\n\treturn {{"ok": true, "absent": true, "errors": []}}\n\n'

    return [
        ("unconditional_png_success", _replace_function(source, "_rw06_1_validate_png", replace_once('"ok": failures.is_empty(),', '"ok": true,'))),
        ("noop_cleanup_with_decoy_string", _replace_function(source, "_rw06_1_remove_file", noop_with_decoys)),
        ("unbound_foundation_snapshot", _replace_function(source, "_rw06_1_rendered_identity", replace_once('"uses_foundation_snapshot": typeof(view_snapshot.get("uses_foundation_snapshot", null)) == TYPE_BOOL', '"uses_foundation_snapshot": true or typeof(view_snapshot.get("uses_foundation_snapshot", null)) == TYPE_BOOL'))),
        ("static_passed_bypass", _replace_function(source, "_rw06_1_validate_static_report", replace_once('if typeof(report.get("passed", null)) != TYPE_BOOL or not report.get("passed", false):', 'if false:'))),
        ("coverage_threshold_bypass", _replace_function(source, "_rw06_1_image_coverage", replace_once('if variant_grid_cells < RW06_1_MIN_VARIANT_GRID_CELLS:', 'if false:'))),
        ("geometry_label_bypass", _replace_function(source, "_rw06_1_validate_interaction_geometry", replace_once('_rw06_1_rect_pair_overlaps(objects, "label_rect")', '_rw06_1_rect_pair_overlaps(objects, "interaction_rect")'))),
        ("seed_assertion_bypass", _replace_function(source, "_rw06_1_generation_identity", replace_once('actual_seed_text == expected_seed_text', 'true'))),
        ("unchecked_json_success", _replace_function(source, "_write_fix06_31_json", replace_once('"ok": failures.is_empty(),', '"ok": true,'))),
    ]


def run_contract(source: str, run_mutations: bool = True) -> list[str]:
    failures = _run_source_checks(source)
    if failures or not run_mutations:
        return failures
    for name, mutant in _hostile_mutations(source):
        mutant_failures = _run_source_checks(mutant)
        if not mutant_failures:
            failures.append(f"hostile in-memory mutation escaped the contract: {name}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parent / "environment_layout_screenshots.gd")
    args = parser.parse_args()
    if not args.source.is_file():
        print(f"RW06_1_VISUAL_CAPTURE_SOURCE_CONTRACT FAIL missing source: {args.source}", file=sys.stderr)
        return 2
    failures = run_contract(args.source.read_text(encoding="utf-8"), run_mutations=True)
    if failures:
        print(f"RW06_1_VISUAL_CAPTURE_SOURCE_CONTRACT FAIL failures={len(failures)}", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        return 1
    print("RW06_1_VISUAL_CAPTURE_SOURCE_CONTRACT PASS hostile_mutations=8 hostile_fixtures=10")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
