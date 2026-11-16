"""Guarded, non-active Grand Back Room R1 preparation and exact source assembly.

Run this worker under bth_qa_guarded_run in the explicit fresh GBR E workspace.
All image/source preflight precedes its first write. No children, generation,
color transforms, active assets, runtime, saves or TEST paths are used.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import base64
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

ROOM = "grand_casino_back_room"
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GBRTRIAL-20261116")
SOURCE_DIR = "review_artifacts/environment_art_sources/grand-back-room-spatial-r1"
RAW_REL = SOURCE_DIR + "/grand-back-room-spatial-r1.png"
RAW_SHA = "91fbde8eb4ebc2c007646eb506dc01bc5b1c8c40cc4baa4d71d088afd7b9ec8d"
BASELINE_SEAL = "065a5f98dfabb2b435bc31af76a0273921a370d1ebb9d9887ce6283c3231fbbb"
MASTER_SHA = "f9d2ca14641e3ac7dd67c92af9453ce4993f0a7dec22156b4f96d6f046f8fcdf"
MANIFEST_SHA = "bb6d6c293824bf9e6347dfba6db5df0e874469fc11e0d094b8f1bd108f45a067"
ART = "assets/art/environments/" + ROOM + "/"
MANIFEST = "data/art/environments/" + ROOM + ".json"
BACKGROUND, INDEX = ART + "background.png", "data/art/environments/index.json"
SIZE, RAW_SIZE = (1800, 860), (1815, 866)
# Source rows are the actual generated rail/apron/leg/complete sole. Only
# these table silhouettes are copied; the generated wall/floor is never used.
SOURCE_Y = (414, 502, 508, 517, 538, 585, 602, 604)
TARGET_Y = (412, 512, 516, 520, 538, 574, 586, 588)
TABLES = (
    {"id": "left", "target": (164, 412, 544, 176), "source_x": (156, 717),
     "far": (233, 650), "apron": (164, 709),
     "legs": ((271, 320), (551, 600)), "feet": ((265, 325), (546, 606)),
     "wall_sides": ((162, 164),), "floor_sides": ((158, 164), (708, 716)),
     "bottom": (162, 712), "envelope": (158, 716)},
    {"id": "right", "target": (1092, 412, 544, 176), "source_x": (1087, 1651),
     "far": (1162, 1583), "apron": (1095, 1641),
     "legs": ((1202, 1252), (1483, 1532)), "feet": ((1197, 1257), (1478, 1537)),
     "wall_sides": ((1090, 1092), (1636, 1638)), "floor_sides": ((1086, 1092), (1636, 1646)),
     "bottom": (1088, 1636), "bottom594_595": (1088, 1642), "envelope": (1086, 1646)},
)
COUNTERS = {"grand_table_left": (164, 516, 544, 72), "grand_table_right": (1092, 516, 544, 72)}
ANIMATION_IDS = tuple([f"casino_light_{i}" for i in range(5)] + ["casino_sign_pulse"] +
                      [f"casino_sparkle_{i}" for i in range(3)] + [f"floor_glint_{i}" for i in range(7)])
LOW_IDS = ("casino_light_1", "casino_light_2", "casino_light_3", "casino_sign_pulse", "floor_glint_0", "floor_glint_1", "floor_glint_2")
MASK_COUNTS = (32, 32, 32, 48, 64, 1632)
IGNORE = b"# Non-active Grand Back Room source/candidates; exclude from Godot discovery.\n"
CONTROLS = ("data/environments/placement_surfaces.json", "data/environments/developer_placement_overrides.json",
            "scripts/ui/pixel_scene_canvas.gd", "scripts/ui/environment_art_renderer.gd", "scripts/ui/environment_art_pack.gd")
CONTEXT_DIR = Path("E:/CodexQA/BTH/runs/BTH-ENVART-GRANDBACKTRIAL-20261115-r1-contexts-01/evidence")
CONTEXT_PINS = {
    "__none_actual_play.png": "f33106111a565f899abe1dc7ae06fbc5b43b0bb2dbfc7142523488250363dbce",
    "__none_metadata.json": "34cf4a43fd7d4389e1a42d91e34248018d93fb9a1b06266da04a8bea5394e792",
    "__none_host_0_body.png": "00796388634d8a17b03db46d2f1eb1c3bf3fd1916b9058b056e28ff3abc999e2",
    "__none_host_0_adorn.png": "2f419c9307584613136af197d29eb1133b9616e678365e91edd0df87ac7127c2",
    "__none_host_1_body.png": "fd66efd1ffdf31144baf2b1d062b43d718d0dbd59dadfe27d84ba13d807d3eb1",
    "__none_host_1_adorn.png": "a315d213f3a3d578642710770c1d33efb742e166cdd1313578225ce600d1c007",
    "__none_host_2_body.png": "87a6c609b5dc46cec24833de49d59a325ab81c2e6d297a2800d7b59428c38e24",
    "__none_host_2_adorn.png": "3a5ce77f44ecbe34595adf868c5c294f69d78261978349ed835d752c4411970c"}
OLD_RECIPE = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261115/assemble_grandback_v1r1.py")
OLD_RECIPE_SHA = "ff4058a7d0a7a6ac33061cc6735ae605362458631c7db8780bc3c240c0d9d0bf"
INHERITED_RECIPE = OLD_RECIPE.with_name("assemble_highlimit_v1r1.py")
INHERITED_RECIPE_SHA = "5139d13bf08399d8574ff2fc04b4b89b9fbdf43a84cd0112b6bedc3c04ac41b8"


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
            "Exact Grand Back Room board/manifest required")
    require([row.get("id") for row in manifest["animations"]] == list(ANIMATION_IDS) and
            tuple(row["id"] for row in manifest["animations"] if row.get("web_low_detail")) == LOW_IDS,
            "Exact native16/low-detail7 ordered motion contract required")
    require(set(manifest["counters"]) == set(COUNTERS), "Only two actual table foregrounds; no OFFICE/host replay")
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
    if sy < 502:
        fraction = (sy + .5 - 414) / (502 - 414)
        lower = table["far"][0] + fraction * (sx0 - table["far"][0])
        upper = table["far"][1] + fraction * (sx1 - table["far"][1])
        if lower <= sx + .5 < upper:
            return sx, sy, "tabletop"
    elif sy < 517:
        return sx, sy, "near_contact_rail"
    elif sy < 538:
        # Both apron sides narrow towards the last dark underside row.
        inset = max(0, sy - 534)
        if table["apron"][0] + inset <= sx < table["apron"][1] - inset:
            return sx, sy, "shallow_apron"
    else:
        for index, (lower, upper) in enumerate(table["legs"]):
            if sy >= 585:
                fl, fr = table["feet"][index]
                fraction = min(1.0, (sy - 585 + .5) / 4)
                lower = lower + fraction * (fl - lower)
                upper = upper + fraction * (fr - upper)
            if lower <= sx + .5 < upper:
                return sx, sy, f"leg_{index}_" + ("complete_sole_and_tight_contact" if sy >= 585 else "dark_timber")
    return None

def repair_reason(table, x, y):
    tx, ty, width, height = table["target"]
    if tx <= x < tx + width and 410 <= y < ty + height:
        return "original_table_body" if y >= 412 else "traced_green_frame_top_fringe"
    if 410 <= y < 492 and any(a <= x < b for a, b in table["wall_sides"]):
        return "traced_old_wall_post"
    if 524 <= y < 594 and any(a <= x < b for a, b in table["floor_sides"]):
        return "traced_old_floor_side_shadow"
    bottom = table.get("bottom594_595", table["bottom"]) if y < 596 else table["bottom"]
    if 594 <= y < 602 and bottom[0] <= x < bottom[1]:
        return "traced_old_bottom_return_above_global_inlay"
    return None

def floor_phase_check(original):
    proof = []
    for x0, width in ((162, 550), (1090, 552)):
        equal = sum(pixel(original, x, y) == pixel(original, x % 128, y) for y in range(588, 594) for x in range(x0, x0 + width))
        require(equal == width * 6, "Grand Back Room original same-row x%128 provenance check failed")
        proof.append({"native_rect": [x0, 588, width, 6], "equal_pixels": equal})
    return proof


def assemble(original, raw):
    require(opaque(original, SIZE) and opaque(raw, RAW_SIZE), "Exact opaque original/raw dimensions required")
    out = bytearray(original.rgba)
    provenance, counts, components, mask = [], Counter(), {}, set()
    for table in TABLES:
        for y in range(410, 602):
            for x in range(table["envelope"][0], table["envelope"][1]):
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
                    require(724 <= dx < 948, "Wall donor left the actual Grand Back Room central gap")
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
                require((x, y) in mask and y < 602, "Assembly escaped the traced Grand Back Room union/inlay protection")
                changed += 1
            if different and start is None:
                start = x
            elif not different and start is not None:
                runs.append([y, start, x]); start = None
        if start is not None:
            runs.append([y, start, 1800])
    require(all(not kind.startswith("generated_") or 412 <= y < 588 for (x, y), kind in components.items()),
            "Furniture escaped the fixed opaque replay occlusion regions")
    supports = []
    for table in TABLES:
        rx, ry, rw, rh = COUNTERS["grand_table_" + table["id"]]
        for index in range(2):
            prefix = "generated_" + table["id"] + f"_leg_{index}_"
            points = [(x, y) for (x, y), kind in components.items() if kind.startswith(prefix)]
            require(points and all(rx <= x < rx + rw and ry <= y < ry + rh for x, y in points) and
                    max(y for x, y in points) == 587 and map_y(586) == 602 and map_y(587) == 603,
                    "Complete generated leg/sole must stay inside its actual opaque replay")
            supports.append({"id": prefix.rstrip("_"), "pixels": len(points),
                             "native_bounds": [min(x for x, y in points), min(y for x, y in points),
                                               max(x for x, y in points) + 1, max(y for x, y in points) + 1],
                             "final_two_target_rows": [586, 587], "actual_source_sole_rows": [602, 603]})
    return image, components, {"tables": TABLES, "source_y": SOURCE_Y, "target_y": TARGET_Y,
        "fixed_contact_native_y": 516, "complete_furniture_contact_bottom_exclusive": 588,
        "actual_source_sample_at_contact_y516": map_y(516), "complete_support_masks": supports,
        "all_generated_supports_inside_actual_replay_rects": True, "original_inlay_rows602_onward_exact": True,
        "changed_pixels": changed, "changed_native_runs_y_x0_x1": runs, "pixel_source_counts": dict(counts),
        "per_pixel_donor_y_x_source_x_source_y_kind_reason": provenance,
        "original_outside_traced_union_exact": True, "no_color_transform_blending_or_generated_wall_floor": True,
        "old_frame_trace": {"top_fringe_y": [410, 412], "own_wall_post_y": [410, 492],
                            "own_global_clean_floor_lip_preserved_outside_tables": [492, 524],
                            "floor_side_shadow_y": [524, 594], "old_bottom_y": [594, 602],
                            "global_inlay_edge602_603_and_all_later_rows_immutable": True,
                            "independent_GBR_floor_core_means_y536_593_RGBsum_vs_phase": [
                                [158, 160, 42.3, 49.8], [160, 162, 40.8, 49.7],
                                [712, 714, 41.6, 49.2], [714, 716, 43.3, 48.3],
                                [1086, 1088, 43.4, 48.0], [1088, 1090, 42.7, 48.2],
                                [1642, 1644, 46.6, 51.0], [1644, 1646, 47.5, 51.1]],
                            "weaker_unproven_outer_halos_preserved": [[156, 158], [716, 718], [1084, 1086], [1646, 1648]]},
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
    updated["animations"][2]["rect"][0] = 448
    differences = logical_diff(manifest, updated)
    require(len(differences) == 1 and differences[0] == (("animations", 2, "rect", 0), 450, 448) and
            type(differences[0][1]) is int and type(differences[0][2]) is int,
            "Manifest delta must be exactly lamp2 integer X450->448")
    require(updated["animations"][5]["rect"] == [332, 54, 234, 62], "Sign rect changed")
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
                selected = ((red >= 150 and blue >= 80 and red >= green + 40 and blue >= green + 20) if index == 5 else
                            (red >= 70 and green >= 20 and red >= blue + 20))
                at = (y * source.width + x) * 4
                if selected:
                    require(alpha == 255 and pixels[at + 3] > 0, "Mask selected absent source opacity/material")
                    active += 1; points.append([x, y]); alphas[source.rgba[at + 3]] += 1
                else:
                    pixels[at + 3] = 0
        require(active == MASK_COUNTS[index], "Actual original-material mask count differs: " + entry["id"])
        bounds = [min(p[0] for p in points), min(p[1] for p in points),
                  max(p[0] for p in points) + 1, max(p[1] for p in points) + 1]
        if index == 5:
            require(bounds == [86, 28, 292, 46], "Actual subtitle glyph mask bounds differ")
        image = PNGImage(source.width, source.height, bytes(pixels))
        require(all(image.rgba[i:i + 3] == source.rgba[i:i + 3] and image.rgba[i + 3] in (0, source.rgba[i + 3])
                    for i in range(0, len(pixels), 4)), "Mask changed RGB or increased alpha")
        payload[path] = encode(image)
        reports.append({"id": entry["id"], "rect": entry["rect"],
                        "actual_material": "ROURKE'S TABLES pink subtitle" if index == 5 else "original vertical lacquer/brass moulding",
                        "nonzero_alpha_pixels": active, "local_active_bounds": bounds,
                        "retained_original_alphas": dict(alphas), "local_active_pixels": points,
                        "all_original_rgb_preserved": True, "alpha_cut_only": True})
    payload[MANIFEST] = (json.dumps(updated, indent=2) + "\n").encode()
    return {"typed_json_diff": [{"path": list(path), "before": a, "after": b} for path, a, b in differences],
            "native_entries": 16, "simulated_low_detail_entries": 7, "masks": reports,
            "all_other_fields_timing_phase_flags_and_positions_unchanged": True,
            "approval_scope": "Explicit parent NONACTIVE-only lamp2-X proposal approval; independent visible motion review pending"}

def populated_risk(components):
    inputs = {name: read(CONTEXT_DIR / name) for name in CONTEXT_PINS}
    require({name: sha(data) for name, data in inputs.items()} == CONTEXT_PINS, "Historical typed source evidence identity changed")
    metadata = json.loads(inputs["__none_metadata.json"])
    rows = metadata["source_paint"]["objects"]
    require([row["object"]["id"] for row in rows] == ["game:craps", "game:blackjack", "travel:leave"] and
            all(row["object"]["z_order"] == 0 for row in rows), "Exact historical 3-object/layer0 Base required")
    report = []
    for index, row in enumerate(rows):
        require(row["body_png"] == f"__none_host_{index}_body.png" and row["adorn_png"] == f"__none_host_{index}_adorn.png",
                "Actual typed painter mapping differs")
        layers = {}
        for layer in ("body", "adorn"):
            image = decode_png(inputs[row[layer + "_png"]])
            require((image.width, image.height) == SIZE, "Typed evidence must be actual 1800 board")
            strong = [(x, y) for y in range(image.height) for x in range(image.width) if pixel(image, x, y)[3] >= 64]
            require(strong, "Typed source has no strong actual paint")
            bounds = [min(x for x, y in strong), min(y for x, y in strong),
                      max(x for x, y in strong) + 1, max(y for x, y in strong) + 1]
            support = Counter(components.get(point, "outside_generated_furniture") for point in strong)
            feet = [point for point, value in components.items() if "_leg_" in value]
            layers[layer] = {"strong_native_bounds_x0_y0_x1_y1": bounds,
                             "strong_board_bounds": [value / 2 for value in bounds],
                             "strong_paint_furniture_intersections": dict(support),
                             "leg_foot_alpha_gt0_intersections": sum(pixel(image, x, y)[3] > 0 for x, y in feet),
                             "leg_foot_alpha_ge64_intersections": sum(pixel(image, x, y)[3] >= 64 for x, y in feet)}
        report.append({"id": row["object"]["id"], "actual_draw_layer": 0, "paint": layers})
    return {"historical_metadata": str(CONTEXT_DIR / "__none_metadata.json"), "input_hashes": CONTEXT_PINS,
        "scope": "Historical Base typed-paint intersections only; not fresh actual composition or acceptance.",
        "objects": report, "all_fixed_labels_and_gameplay_geometry_unchanged": True,
        "no_Rourke_actor_present_in_historical_fixture": True,
        "risk": "Fresh Blackjack/Craps table support, leg contacts and label readability still need populated native review. Three-object Base establishes no later Rourke/boss/showdown/heist/lifecycle/save/revisit clearance."}

def layout_from_environment():
    path = Path(os.environ["BTH_QA_EVIDENCE_DIR"]) / "storage-manifest.json"
    record = json.loads(read(path))
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
                    **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and os.path.normcase(str(layout.workspace)) == os.path.normcase(str(WORKSPACE)), "Exact prepared GBR E workspace required")
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
        output = sources / "grand-back-room-spatial-r1-assembled-v1"
        report_path = layout.evidence / "grand-back-room-spatial-r1-assembly.json"
        validate_layout(layout, extra_write_paths=(baseline, sources, output, report_path))
        require(not output.exists() and not report_path.exists(), "Fresh immutable candidate/report required")
        source = args.source_root.absolute()
        require(source == Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers"),
                "Exact read-only art worktree source root required")
        manifest_data = read(source / MANIFEST); require(sha(manifest_data) == MANIFEST_SHA, "Original manifest pin differs")
        manifest = json.loads(manifest_data); names = package_names(manifest)
        extra = (*CONTROLS, RAW_REL, RAW_REL + ".b64", SOURCE_DIR + "/provenance.json",
                 SOURCE_DIR + "/prompt.txt", "docs/art/briefs/grand_back_room_spatial_repair_20261116.md")
        before = inventory(source, (*names, *extra))
        original_hashes = {name: before[name] for name in names}
        require(seal(original_hashes) == BASELINE_SEAL and before[BACKGROUND] == MASTER_SHA and before[RAW_REL] == RAW_SHA,
                "Exact original21/raw source seals required")
        require(sha(read(OLD_RECIPE)) == OLD_RECIPE_SHA and sha(read(INHERITED_RECIPE)) == INHERITED_RECIPE_SHA,
                "Original Back Room wrapper/inherited floor provenance recipes differ")
        payload = {name: read(source / name) for name in names}
        raw_bytes = read(source / RAW_REL)
        require(sha(read(source / (RAW_REL + ".b64"))) == "0150bbaa5989a1601145d624682636df11dc94a9880a2c0f83e7b7afa8d6886a" and
                base64.b64decode(b"".join(read(source / (RAW_REL + ".b64")).split()), validate=True) == raw_bytes and
                before[SOURCE_DIR + "/prompt.txt"] == "02c90e29dd6d6ca83bcfb94b6cb6eeb26fe9b9d0c54cdbd79abc652160fce3b2",
                "Frozen raw/base64/prompt source preservation differs")
        original, raw = decode_png(payload[BACKGROUND]), decode_png(raw_bytes)
        assembled, components, assembly = assemble(original, raw)
        payload[BACKGROUND] = encode(assembled)
        for art_id, rect in COUNTERS.items():
            path = ART + "counters/" + art_id + ".png"
            require(decode_png(payload[path]) == crop(original, rect), "Original opaque front is not exact master crop")
            cut = crop(assembled, rect); require(opaque(cut, rect[2:]), "New replay became transparent")
            payload[path] = encode(cut)
        masks, risk = cut_light_masks(original, payload, manifest), populated_risk(components)
        candidate_names = package_names(json.loads(payload[MANIFEST])); require(candidate_names == names, "Payload membership changed")
        expected = {BACKGROUND, MANIFEST, *(ART + "counters/" + key + ".png" for key in COUNTERS),
                    *(ART + entry["texture"] for entry in manifest["animations"][:6])}
        hashes = {name: sha(payload[name]) for name in names}
        changed = sorted(name for name in names if hashes[name] != original_hashes[name])
        require(set(changed) == expected, "Only tables/fronts/six alpha masks/sole lamp2-X manifest may change")
        if baseline.exists():
            require(inventory(baseline, names) == original_hashes, "Existing baseline differs; preserve and stop")
        if sources.exists() and (sources / "grand-back-room-spatial-r1.png").exists():
            require(sha(read(sources / "grand-back-room-spatial-r1.png")) == RAW_SHA, "Existing preserved raw differs")
        for preserved_name in ("provenance.json", "prompt.txt", "grand-back-room-spatial-r1.png.b64"):
            if (sources / preserved_name).exists():
                require(read(sources / preserved_name) == read(source / SOURCE_DIR / preserved_name),
                        "Existing preserved source differs; stop before writes")
        for directory in (baseline, sources):
            if (directory / ".gdignore").exists():
                require(read(directory / ".gdignore") == IGNORE, "Existing ignore differs; preserve and stop")
        require(inventory(source, (*names, *extra)) == before and sha(read(OLD_RECIPE)) == OLD_RECIPE_SHA and sha(read(INHERITED_RECIPE)) == INHERITED_RECIPE_SHA and
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
        for name, data in (("grand-back-room-spatial-r1.png", raw_bytes),
                           *((key, read(source / SOURCE_DIR / key)) for key in
                             ("provenance.json", "prompt.txt", "grand-back-room-spatial-r1.png.b64"))):
            target = sources / name
            if target.exists():
                require(read(target) == data, "Existing source preservation differs")
            else:
                write_fresh(target, data, layout)
        output.mkdir()
        for name in names:
            write_fresh(output / name, payload[name], layout)
        require(inventory(output, names) == hashes and inventory(baseline, names) == original_hashes and
                sha(read(sources / "grand-back-room-spatial-r1.png")) == RAW_SHA and inventory(source, (*names, *extra)) == before and
                sha(read(__file__)) == recipe_sha and sha(read(decode_png.__code__.co_filename)) == decoder_sha and
                sha(read(OLD_RECIPE)) == OLD_RECIPE_SHA and sha(read(INHERITED_RECIPE)) == INHERITED_RECIPE_SHA and inventory(CONTEXT_DIR, CONTEXT_PINS) == CONTEXT_PINS,
                "Prepared/output/read-only input custody changed")
        report = {"schema": "bth.grand_back_room_spatial_assembly/v1", "task_id": "BTH-ENV-SPATIAL-GBR-001",
            "status": "NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT", "observed_at": datetime.now(timezone.utc).isoformat(),
            "recipe_sha256": recipe_sha, "decoder_sha256": decoder_sha, "raw_source": {"path": str(sources / "grand-back-room-spatial-r1.png"), "sha256": RAW_SHA, "size": RAW_SIZE},
            "baseline": {"path": str(baseline), "seal": BASELINE_SEAL, "file_count": 21, "files": original_hashes},
            "auxiliary_ignore_sentinels": [str(baseline / ".gdignore"), str(sources / ".gdignore")],
            "ignore_sentinels_excluded_from_logical_21_file_payload": True,
            "output": {"path": str(output), "seal": seal(hashes), "file_count": 21, "files": hashes},
            "changed_payload_paths": changed, "assembly": assembly, "motion_masks": masks, "populated_source_risk": risk,
            "source_hashes_before": before, "source_hashes_after": inventory(source, (*names, *extra)), "all_sources_unchanged": True,
            "old_floor_recipe_sha256": OLD_RECIPE_SHA, "inherited_floor_recipe_sha256": INHERITED_RECIPE_SHA, "counter_crops_exact_opaque": COUNTERS,
            "no_third_foreground_added": True, "source_original_outside_traced_union_exact": True,
            "active_files_written": False, "runtime_launched": False, "art_approval": False, "test_updated": False,
            "storage_manifest": str(layout.manifest_path),
            "risks": ["Generated furniture edges, wall/floor continuation and complete foot contacts need independent actual-pixel review.",
                "Typed-paint intersection is historical; fresh populated Blackjack/Craps contacts and label readability remain pending.",
                "Original pulse RGB retained on pink ROURKE\'S TABLES glyph mask; actual color/motion acceptance remains pending.",
                "Native16/low-detail7 visibility, Reduce Motion, liveness and exact TEST delivery are not implied."]}
        write_fresh(report_path, (json.dumps(report, indent=2) + "\n").encode(), layout)
        print(json.dumps({"status": report["status"], "package": str(output), "report": str(report_path), "art_approval": False}))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(json.dumps({"status": "GRAND_BACK_ROOM_ASSEMBLY_STOPPED", "error": str(error), "active_files_written": False,
                          "art_approval": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
