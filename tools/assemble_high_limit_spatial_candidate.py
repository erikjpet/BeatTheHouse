"""Guarded, non-active High Limit R1 preparation and exact source assembly.

Run this worker under bth_qa_guarded_run in the explicit fresh HL E workspace.
All image/source preflight precedes its first write. No children, generation,
color transforms, active assets, runtime, saves or TEST paths are used.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from collections import Counter
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import stat
import struct
import zlib

from bar_spatial_candidate_check import PNGImage, decode_png
from bth_qa_storage import Layout, validate_layout

ROOM = "grand_casino_high_limit"
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLTRIAL-20261116")
SOURCE_DIR = "review_artifacts/environment_art_sources/high-limit-spatial-r1"
RAW_REL = SOURCE_DIR + "/high-limit-spatial-r1.png"
RAW_SHA = "ad4bfe68a0444cecd1914ba75ae2986cb1b797509eb6347f5df42f3231492911"
BASELINE_SEAL = "69c7023d0dae2468f73dc4c836d055d29592443c42cb72060901ef1390c97c93"
MASTER_SHA = "dc9509ca6ab5b4e23ea7ed9fb6adbb28e6674984cc7571161b94304dc8b3bd28"
MANIFEST_SHA = "3c2accd38cf268b33853bd3894e53b4def84e2bbf10f240a20de38ccb868fdd2"
ART = "assets/art/environments/" + ROOM + "/"
MANIFEST = "data/art/environments/" + ROOM + ".json"
BACKGROUND, INDEX = ART + "background.png", "data/art/environments/index.json"
SIZE, RAW_SIZE = (1800, 860), (1815, 867)
SOURCE_Y = (408, 499, 503, 507, 527, 598, 602)
TARGET_Y = (412, 512, 516, 520, 536, 586, 588)
TABLES = (
    {"id": "left", "target": (164, 412, 544, 176), "source_x": (157, 716),
     "far": (213, 662), "apron": (159, 713), "legs": ((270, 303), (559, 594)),
     "wall_sides": ((156, 164), (708, 718)), "floor_sides": ((156, 162), (712, 718)),
     "bottom": (156, 718)},
    {"id": "right", "target": (1092, 412, 544, 176), "source_x": (1093, 1653),
     "far": (1147, 1595), "apron": (1096, 1650), "legs": ((1214, 1248), (1501, 1535)),
     "wall_sides": ((1084, 1092), (1636, 1648)), "floor_sides": ((1084, 1090), (1642, 1648)),
     "bottom": (1084, 1648)},
)
COUNTERS = {"grand_table_left": (164, 516, 544, 72), "grand_table_right": (1092, 516, 544, 72)}
ANIMATION_IDS = tuple([f"casino_light_{i}" for i in range(5)] + ["casino_sign_pulse"] +
                      [f"casino_sparkle_{i}" for i in range(3)] + [f"floor_glint_{i}" for i in range(7)])
LOW_IDS = ("casino_light_1", "casino_light_2", "casino_light_3", "casino_sign_pulse", "floor_glint_0", "floor_glint_1", "floor_glint_2")
MASK_COUNTS = (176, 176, 208, 200, 164, 1804)
IGNORE = b"# Non-active High Limit source/candidates; exclude from Godot discovery.\n"
CONTROLS = ("data/environments/placement_surfaces.json", "data/environments/developer_placement_overrides.json",
            "scripts/ui/pixel_scene_canvas.gd", "scripts/ui/environment_art_renderer.gd", "scripts/ui/environment_art_pack.gd")
CONTEXT_DIR = Path("E:/CodexQA/BTH/runs/BTH-ENVART-HIGHLIMITTRIAL-20261115-r1-contexts-03/evidence")
CONTEXT_PINS = {"__none_metadata.json": "67999a314912d1da344e80c6e957b2b86523b1918866bd85e9040e4a4ef9af3f",
    "__none_host_3_body.png": "1d27bf9ca3bb31850175f9b89abfd6d1e9c3c4d0ddbbedcd52779fd8993f8edf",
    "__none_host_3_adorn.png": "38f46226c67a26501673d839e91a1c8fca28d9f2386a4e019988e3d2b4a3c17b"}
OLD_RECIPE = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261115/assemble_highlimit_v1r1.py")
OLD_RECIPE_SHA = "5139d13bf08399d8574ff2fc04b4b89b9fbdf43a84cd0112b6bedc3c04ac41b8"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    path = Path(path)
    for item in (path, *path.parents):
        info = item.lstat()
        require(not (getattr(info, "st_file_attributes", 0) & 0x400) and not stat.S_ISLNK(info.st_mode), "Reparse input: " + str(item))
    require(path.is_file(), "Missing source file: " + str(path))
    return path.read_bytes()


def inventory(root, names):
    return {name: sha(read(root / name)) for name in sorted(names)}


def seal(hashes):
    return sha("\n".join(path + " " + value for path, value in sorted(hashes.items())).encode())


def package_names(manifest):
    require(manifest.get("environment_id") == ROOM and manifest.get("board_size") == [900, 430] and manifest.get("pixel_scale") == 2,
            "Exact High Limit board/manifest required")
    require([row.get("id") for row in manifest["animations"]] == list(ANIMATION_IDS) and
            tuple(row["id"] for row in manifest["animations"] if row.get("web_low_detail")) == LOW_IDS,
            "Exact native16/low-detail7 ordered motion contract required")
    require(set(manifest["counters"]) == set(COUNTERS), "Only two actual table foregrounds; no VIP/host replay")
    names = {BACKGROUND, MANIFEST, INDEX}
    names.update(ART + row["texture"] for row in manifest["animations"])
    names.update(ART + row["texture"] for row in manifest["counters"].values())
    require(len(names) == 21 and len({row["texture"] for row in manifest["animations"]}) == 16, "Exact 21-file/16-PNG-motion payload required")
    require(all(not p.startswith(("/", "\\")) and ".." not in p.split("/") and "\\" not in p for p in names), "Unsafe payload path")
    return tuple(sorted(names))


def opaque(image, size):
    return (image.width, image.height) == size and image.rgba[3::4] == b"\xff" * (image.width * image.height)


def pixel(image, x, y):
    at = (y * image.width + x) * 4
    return image.rgba[at:at + 4]


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def encode(image):
    compressor = zlib.compressobj(9)
    stride = image.width * 4
    data = b"".join(compressor.compress(b"\0" + image.rgba[y * stride:(y + 1) * stride]) for y in range(image.height)) + compressor.flush()
    result = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", data) + chunk(b"IEND", b"")
    require(decode_png(result) == image, "Lossless PNG roundtrip failed")
    return result


def crop(image, rect):
    x, y, width, height = rect
    return PNGImage(width, height, b"".join(image.rgba[((y + row) * image.width + x) * 4:((y + row) * image.width + x + width) * 4]
                                           for row in range(height)))


def map_y(y):
    for s0, s1, t0, t1 in zip(SOURCE_Y, SOURCE_Y[1:], TARGET_Y, TARGET_Y[1:]):
        if t0 <= y < t1:
            return min(s1 - 1, int(s0 + (y - t0 + .5) * (s1 - s0) / (t1 - t0)))
    raise ValueError("Outside furniture Y remap")


def furniture(table, x, y):
    tx, ty, width, height = table["target"]
    if not (tx <= x < tx + width and ty <= y < ty + height):
        return None
    sx0, sx1 = table["source_x"]
    sx = min(sx1 - 1, int(sx0 + (x - tx + .5) * (sx1 - sx0) / width))
    sy = map_y(y)
    if sy < 499:
        fraction = (sy + .5 - 408) / (499 - 408)
        lower = table["far"][0] + fraction * (sx0 - table["far"][0])
        upper = table["far"][1] + fraction * (sx1 - table["far"][1])
        if lower <= sx + .5 < upper:
            return sx, sy, "tabletop"
    elif sy < 507:
        return sx, sy, "near_contact_rail"
    elif sy < 527:
        if table["apron"][0] <= sx < table["apron"][1]:
            return sx, sy, "shallow_apron"
    else:
        for index, (lower, upper) in enumerate(table["legs"]):
            padding = 2 if sy >= 598 else 0
            if lower - padding <= sx < upper + padding:
                return sx, sy, f"leg_{index}" + ("_tight_contact" if padding else "_timber_and_sole")
    return None


def repair_reason(table, x, y):
    tx, ty, width, height = table["target"]
    if tx <= x < tx + width and 410 <= y < ty + height:
        return "original_table_body" if y >= 412 else "traced_green_top_fringe"
    if 410 <= y < 492 and any(a <= x < b for a, b in table["wall_sides"]):
        return "traced_old_wall_shadow"
    if 504 <= y < 594 and any(a <= x < b for a, b in table["floor_sides"]):
        return "traced_old_floor_side_shadow"
    if 594 <= y < 602 and table["bottom"][0] <= x < table["bottom"][1]:
        return "traced_old_bottom_return"
    return None


def floor_phase_check(original):
    proof = []
    for x0, width in ((162, 550), (1090, 552)):
        equal = sum(pixel(original, x, y) == pixel(original, x % 128, y) for y in range(588, 594) for x in range(x0, x0 + width))
        require(equal == width * 6, "High Limit original same-row x%128 provenance check failed")
        proof.append({"native_rect": [x0, 588, width, 6], "equal_pixels": equal})
    return proof


def assemble(original, raw):
    require(opaque(original, SIZE) and opaque(raw, RAW_SIZE), "Exact opaque original/raw dimensions required")
    out = bytearray(original.rgba)
    provenance, counts, components, mask = [], Counter(), {}, set()
    for table in TABLES:
        for y in range(410, 602):
            for x in range(table["bottom"][0], table["bottom"][1]):
                reason = repair_reason(table, x, y)
                if reason is None:
                    continue
                mask.add((x, y))
                part = furniture(table, x, y)
                if part:
                    dx, dy, kind = part
                    source = raw
                    kind = "generated_" + table["id"] + "_" + kind
                    components[x, y] = kind
                elif y < 492:
                    dx, dy, kind, source = 724 + ((x - 724) % 224), y, "original_same_row_wall_phase224", original
                    require(724 <= dx < 948, "Wall donor left the actual High Limit central gap")
                else:
                    dx, dy, kind, source = x % 128, y, "original_same_row_floor_phase128", original
                    require(0 <= dx < 128 and 492 <= dy < 602, "Floor donor touched a table/shadow/inlay")
                index = (y * SIZE[0] + x) * 4
                out[index:index + 4] = pixel(source, dx, dy)
                provenance.append([y, x, dx, dy, kind, reason])
                counts[kind] += 1
    image = PNGImage(*SIZE, bytes(out))
    changed, runs = 0, []
    for y in range(860):
        start = None
        for x in range(1800):
            different = pixel(image, x, y) != pixel(original, x, y)
            if different:
                require((x, y) in mask and y < 602, "Assembly escaped the traced High Limit union/inlay protection")
                changed += 1
            if different and start is None:
                start = x
            elif not different and start is not None:
                runs.append([y, start, x]); start = None
        if start is not None:
            runs.append([y, start, 1800])
    require(all(not kind.startswith("generated_") or 412 <= y < 588 for (x, y), kind in components.items()),
            "Furniture escaped the fixed opaque replay occlusion regions")
    return image, components, {"tables": TABLES, "source_y": SOURCE_Y, "target_y": TARGET_Y,
        "fixed_contact_native_y": 516, "complete_furniture_contact_bottom_exclusive": 588,
        "all_generated_supports_inside_actual_replay_rects": True, "original_inlay_rows602_onward_exact": True,
        "changed_pixels": changed, "changed_native_runs_y_x0_x1": runs, "pixel_source_counts": dict(counts),
        "per_pixel_donor_y_x_source_x_source_y_kind_reason": provenance,
        "original_outside_traced_union_exact": True, "no_color_transform_blending_or_generated_wall_floor": True,
        "old_frame_trace": {"top_fringe_y": [410, 412], "wall_shadow_y": [410, 492], "clean_floor_lip_not_extended": [492, 504],
                            "floor_side_shadow_y": [504, 594], "old_bottom_y": [594, 602]},
        "phase_checks": floor_phase_check(original)}


def logical_diff(old, new, path=()):
    if type(old) is not type(new):
        return [(path, old, new)]
    if isinstance(old, dict):
        require(old.keys() == new.keys(), "Manifest dictionary membership changed")
        return [item for key in old for item in logical_diff(old[key], new[key], (*path, key))]
    if isinstance(old, list):
        require(len(old) == len(new), "Manifest list length changed")
        return [item for index, (a, b) in enumerate(zip(old, new)) for item in logical_diff(a, b, (*path, index))]
    return [] if old == new else [(path, old, new)]


def cut_light_masks(original, payload, manifest):
    updated = deepcopy(manifest)
    for index in range(5):
        require(manifest["animations"][index]["rect"] == [250 + index * 100, 124, 52, 8], "Original lamp geometry differs")
        updated["animations"][index]["rect"][1] = 8
    differences = logical_diff(manifest, updated)
    require({path for path, a, b in differences} == {("animations", i, "rect", 1) for i in range(5)} and
            all(type(a) is int and type(b) is int and a == 124 and b == 8 for path, a, b in differences),
            "Manifest delta must be exactly five integer lamp Ys124->8")
    reports = []
    for index, entry in enumerate(updated["animations"][:6]):
        path = ART + entry["texture"]
        source = decode_png(payload[path]); pixels = bytearray(source.rgba)
        bx, by, width, height = entry["rect"]
        require((source.width, source.height) == (width * 2, height * 2), "Exact 2x pulse dimensions required")
        active, points, alphas = 0, [], Counter()
        for y in range(source.height):
            for x in range(source.width):
                red, green, blue, alpha = pixel(original, bx * 2 + x, by * 2 + y)
                selected = ((green >= 100 and blue >= 100 and green >= red + 40 and blue >= red + 40) if index == 5 else
                            (red >= 90 and green >= 60 and red >= blue + 20 and green >= blue))
                at = (y * source.width + x) * 4
                if selected:
                    require(alpha == 255 and pixels[at + 3] > 0, "Mask selected absent source opacity/material")
                    active += 1; points.append([x, y]); alphas[source.rgba[at + 3]] += 1
                else:
                    pixels[at + 3] = 0
        require(active == MASK_COUNTS[index], "Actual original-material mask count differs: " + entry["id"])
        image = PNGImage(source.width, source.height, bytes(pixels))
        require(all(image.rgba[i:i + 3] == source.rgba[i:i + 3] and image.rgba[i + 3] in (0, source.rgba[i + 3])
                    for i in range(0, len(pixels), 4)), "Mask changed RGB or increased alpha")
        payload[path] = encode(image)
        reports.append({"id": entry["id"], "rect": entry["rect"], "actual_material": "PRIVATE TABLES cyan subtitle" if index == 5 else "original gold soffit",
                        "nonzero_alpha_pixels": active, "retained_original_alphas": dict(alphas), "local_active_pixels": points,
                        "all_original_rgb_preserved": True, "alpha_cut_only": True})
    payload[MANIFEST] = (json.dumps(updated, indent=2) + "\n").encode()
    return {"typed_json_diff": [{"path": list(path), "before": a, "after": b} for path, a, b in differences],
            "native_entries": 16, "simulated_low_detail_entries": 7, "masks": reports,
            "all_other_fields_timing_phase_flags_and_positions_unchanged": True, "approval_scope": "Explicit parent NONACTIVE-only lamp-Y proposal approval; independent motion review pending"}


def baccarat_risk(components):
    inputs = {name: read(CONTEXT_DIR / name) for name in CONTEXT_PINS}
    require({name: sha(data) for name, data in inputs.items()} == CONTEXT_PINS, "Historical typed source evidence identity changed")
    metadata = json.loads(inputs["__none_metadata.json"])
    row = next(item for item in metadata["source_paint"]["objects"] if item["object"]["id"] == "game:baccarat")
    require(row["body_png"] == "__none_host_3_body.png" and row["adorn_png"] == "__none_host_3_adorn.png", "Actual Baccarat typed painter mapping differs")
    bodies = {"body": decode_png(inputs[row["body_png"]]), "adornment": decode_png(inputs[row["adorn_png"]])}
    report = []
    for kind in sorted(set(components.values())):
        if "left_leg_" not in kind:
            continue
        coordinates = [(x, y) for (x, y), value in components.items() if value == kind]
        overlap = {}
        for layer, image in bodies.items():
            require((image.width, image.height) == SIZE, "Typed evidence must be actual 1800 board")
            overlap[layer] = {"alpha_gt0": sum(pixel(image, x, y)[3] > 0 for x, y in coordinates),
                              "alpha_ge64": sum(pixel(image, x, y)[3] >= 64 for x, y in coordinates)}
        report.append({"background_component": kind, "native_bounds": [min(x for x, y in coordinates), min(y for x, y in coordinates),
            max(x for x, y in coordinates) + 1, max(y for x, y in coordinates) + 1], "typed_paint_intersections": overlap})
    return {"historical_metadata": str(CONTEXT_DIR / "__none_metadata.json"), "input_hashes": CONTEXT_PINS,
        "scope": "Historical Base typed-paint intersection only; not fresh actual composition or an approval.",
        "components": report, "all_fixed_labels_and_gameplay_geometry_unchanged": True,
        "risk": "Left table second leg sits near boardx280 and Baccarat's lower body/adornment; dark material and layer0 foreground do not waive populated foot/readability review."}


def layout_from_environment():
    path = Path(os.environ["BTH_QA_EVIDENCE_DIR"]) / "storage-manifest.json"
    record = json.loads(read(path))
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
                    **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and os.path.normcase(str(layout.workspace)) == os.path.normcase(str(WORKSPACE)), "Exact prepared HL E workspace required")
    return layout


def write_fresh(path, data, layout):
    validate_layout(layout, extra_write_paths=(path.parent,))
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as handle:
        handle.write(data)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        layout = layout_from_environment()
        recipe_sha = sha(read(__file__))
        decoder_sha = sha(read(decode_png.__code__.co_filename))
        baseline, sources = layout.workspace / "source_baseline", layout.workspace / "candidate_sources"
        output = sources / "high-limit-spatial-r1-assembled-v1"
        report_path = layout.evidence / "high-limit-spatial-r1-assembly.json"
        validate_layout(layout, extra_write_paths=(baseline, sources, output, report_path))
        require(not output.exists() and not report_path.exists(), "Fresh immutable candidate/report required")
        source = args.source_root.absolute()
        manifest_data = read(source / MANIFEST); require(sha(manifest_data) == MANIFEST_SHA, "Original manifest pin differs")
        manifest = json.loads(manifest_data); names = package_names(manifest)
        extra = (*CONTROLS, RAW_REL, SOURCE_DIR + "/provenance.json", "docs/art/briefs/high_limit_spatial_repair_20261116.md")
        before = inventory(source, (*names, *extra))
        original_hashes = {name: before[name] for name in names}
        require(seal(original_hashes) == BASELINE_SEAL and before[BACKGROUND] == MASTER_SHA and before[RAW_REL] == RAW_SHA,
                "Exact original21/raw source seals required")
        require(sha(read(OLD_RECIPE)) == OLD_RECIPE_SHA, "Original HL floor provenance recipe differs")
        payload = {name: read(source / name) for name in names}
        raw_bytes = read(source / RAW_REL)
        original, raw = decode_png(payload[BACKGROUND]), decode_png(raw_bytes)
        assembled, components, assembly = assemble(original, raw)
        payload[BACKGROUND] = encode(assembled)
        for art_id, rect in COUNTERS.items():
            path = ART + "counters/" + art_id + ".png"
            require(decode_png(payload[path]) == crop(original, rect), "Original opaque front is not exact master crop")
            cut = crop(assembled, rect); require(opaque(cut, rect[2:]), "New replay became transparent")
            payload[path] = encode(cut)
        masks, risk = cut_light_masks(original, payload, manifest), baccarat_risk(components)
        candidate_names = package_names(json.loads(payload[MANIFEST])); require(candidate_names == names, "Payload membership changed")
        expected = {BACKGROUND, MANIFEST, *(ART + "counters/" + key + ".png" for key in COUNTERS),
                    *(ART + entry["texture"] for entry in manifest["animations"][:6])}
        hashes = {name: sha(payload[name]) for name in names}
        changed = sorted(name for name in names if hashes[name] != original_hashes[name])
        require(set(changed) == expected, "Only tables/fronts/six alpha masks/five-Y manifest may change")
        if baseline.exists():
            require(inventory(baseline, names) == original_hashes, "Existing baseline differs; preserve and stop")
        if sources.exists() and (sources / "high-limit-spatial-r1.png").exists():
            require(sha(read(sources / "high-limit-spatial-r1.png")) == RAW_SHA, "Existing preserved raw differs")
        if (sources / "provenance.json").exists():
            require(read(sources / "provenance.json") == read(source / (SOURCE_DIR + "/provenance.json")),
                    "Existing preserved provenance differs; stop before writes")
        for directory in (baseline, sources):
            if (directory / ".gdignore").exists():
                require(read(directory / ".gdignore") == IGNORE, "Existing ignore differs; preserve and stop")
        require(inventory(source, (*names, *extra)) == before and sha(read(OLD_RECIPE)) == OLD_RECIPE_SHA and
                inventory(CONTEXT_DIR, CONTEXT_PINS) == CONTEXT_PINS and sha(read(__file__)) == recipe_sha and
                sha(read(decode_png.__code__.co_filename)) == decoder_sha, "Read-only sources/recipe changed during preflight")
        # FIRST QA WRITES: all exact source, geometry, mask and typed-evidence
        # checks above are complete. Parent guard owns CPU/Job and launch gates.
        validate_layout(layout, extra_write_paths=(baseline, sources, output, report_path))
        baseline.mkdir(exist_ok=True); sources.mkdir(exist_ok=True)
        for directory in (baseline, sources):
            if not (directory / ".gdignore").exists():
                write_fresh(directory / ".gdignore", IGNORE, layout)
        for name in names:
            if not (baseline / name).exists():
                write_fresh(baseline / name, read(source / name), layout)
        for name, data in (("high-limit-spatial-r1.png", raw_bytes), ("provenance.json", read(source / (SOURCE_DIR + "/provenance.json")))):
            target = sources / name
            if target.exists():
                require(read(target) == data, "Existing source preservation differs")
            else:
                write_fresh(target, data, layout)
        output.mkdir()
        for name in names:
            write_fresh(output / name, payload[name], layout)
        require(inventory(output, names) == hashes and inventory(baseline, names) == original_hashes and
                sha(read(sources / "high-limit-spatial-r1.png")) == RAW_SHA and inventory(source, (*names, *extra)) == before and
                sha(read(__file__)) == recipe_sha and sha(read(decode_png.__code__.co_filename)) == decoder_sha and
                sha(read(OLD_RECIPE)) == OLD_RECIPE_SHA and inventory(CONTEXT_DIR, CONTEXT_PINS) == CONTEXT_PINS,
                "Prepared/output/read-only input custody changed")
        report = {"schema": "bth.high_limit_spatial_assembly/v1", "task_id": "BTH-ENV-SPATIAL-HL-001",
            "status": "NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT", "observed_at": datetime.now(timezone.utc).isoformat(),
            "recipe_sha256": recipe_sha, "decoder_sha256": decoder_sha, "raw_source": {"path": str(sources / "high-limit-spatial-r1.png"), "sha256": RAW_SHA, "size": RAW_SIZE},
            "baseline": {"path": str(baseline), "seal": BASELINE_SEAL, "file_count": 21, "files": original_hashes},
            "output": {"path": str(output), "seal": seal(hashes), "file_count": 21, "files": hashes},
            "changed_payload_paths": changed, "assembly": assembly, "motion_masks": masks, "baccarat_risk": risk,
            "source_hashes_before": before, "source_hashes_after": inventory(source, (*names, *extra)), "all_sources_unchanged": True,
            "old_floor_recipe_sha256": OLD_RECIPE_SHA, "counter_crops_exact_opaque": COUNTERS,
            "no_third_foreground_added": True, "source_original_outside_traced_union_exact": True,
            "active_files_written": False, "runtime_launched": False, "art_approval": False, "test_updated": False,
            "storage_manifest": str(layout.manifest_path),
            "risks": ["Generated furniture edges, wall/floor continuation and complete foot contacts need independent actual-pixel review.",
                "Typed-paint intersection is historical; fresh populated Baccarat/Blackjack/Kite contacts and label readability remain pending.",
                "Warm original pulse RGB retained on cyan PRIVATE TABLES glyph mask; actual color/motion acceptance remains pending.",
                "Native16/low-detail7 visibility, Reduce Motion, liveness and exact TEST delivery are not implied."]}
        write_fresh(report_path, (json.dumps(report, indent=2) + "\n").encode(), layout)
        print(json.dumps({"status": report["status"], "package": str(output), "report": str(report_path), "art_approval": False}))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(json.dumps({"status": "HIGH_LIMIT_ASSEMBLY_STOPPED", "error": str(error), "active_files_written": False,
                          "art_approval": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
