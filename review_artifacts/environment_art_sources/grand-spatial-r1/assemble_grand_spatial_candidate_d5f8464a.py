"""Bounded mechanical Grand R1 assembly; non-active candidate only.

Launch this worker through bth_qa_guarded_run, with the exact prepared Grand E
workspace and --source-root pointing at the unchanged art worktree. No children,
image generation, color transforms, production writes or activation occur here.
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

WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GRANDTRIAL-20261116")
RAW_SHA = "31e7a40bfedcbc68a00a615e400b3df88bab03d180558fd3c88749a410147c63"
BASELINE_SEAL = "5b4e87763e85358b85fc0ce73232afc8878f132a4294904970c7fdfbd8f30060"
BACKGROUND_SHA = "f5b26c4f16b4ff419154c555d48f553013d8c75363284c0090b7eff07d19eb9f"
MANIFEST_SHA = "5cc2d0c568552a88557f0f0eee89655bc86a5e73c535e822e09b267901044bcd"
ART = "assets/art/environments/grand_casino/"
MANIFEST = "data/art/environments/grand_casino.json"
INDEX = "data/art/environments/index.json"
BACKGROUND = ART + "background.png"
SIZE = (1800, 860)
RAW_SIZE = (1815, 867)
HORIZON = 492
ANIMATION_IDS = tuple([f"casino_light_{i}" for i in range(5)] + ["casino_sign_pulse"] +
                      [f"casino_sparkle_{i}" for i in range(3)] + [f"floor_glint_{i}" for i in range(7)])
LOW_DETAIL_IDS = ("casino_light_1", "casino_light_2", "casino_light_3", "casino_sign_pulse",
                  "floor_glint_0", "floor_glint_1", "floor_glint_2")
# Source row landmarks were inspected in the actual generated raster. Piecewise
# nearest-center resampling fixes the near contact at native y516 and puts every
# base pixel above y588. The 1815x867 room is never globally resized or copied.
SOURCE_Y = (413, 508, 516, 539, 550, 582, 590, 602, 605)
TARGET_Y = (412, 508, 516, 536, 544, 576, 580, 586, 588)
TABLES = (
    {"id": "left", "target": (164, 412, 544, 176), "source_x": (159, 721),
     "top_points": ((201, 413), (679, 413), (721, 508), (721, 524), (718, 539), (159, 539), (159, 508)),
     "cap": (413, 468), "stem": (417, 464), "base": (405, 476)},
    {"id": "right", "target": (1092, 412, 544, 176), "source_x": (1094, 1658),
     "top_points": ((1138, 413), (1615, 413), (1658, 508), (1658, 524), (1655, 539), (1094, 539), (1094, 508)),
     "cap": (1350, 1407), "stem": (1358, 1402), "base": (1342, 1417)},
)
COUNTER_RECTS = {"grand_table_left": (164, 516, 544, 72), "grand_table_right": (1092, 516, 544, 72),
                 "grand_host_station": (688, 636, 424, 96)}
LAMP_COLUMNS = {0: ((0, 2),), 1: ((20, 24), (102, 104)), 2: ((96, 98),),
                3: ((14, 16),), 4: ((8, 10), (54, 58))}
MASK_COUNTS = {"casino_light_0": 32, "casino_light_1": 96, "casino_light_2": 32,
               "casino_light_3": 32, "casino_light_4": 96, "casino_sign_pulse": 2656}
CONTROLS = ("data/environments/placement_surfaces.json", "data/environments/developer_placement_overrides.json",
            "scripts/ui/pixel_scene_canvas.gd", "scripts/ui/environment_art_renderer.gd",
            "scripts/ui/environment_art_pack.gd")
IGNORE_BYTES = b"# Non-active Grand candidate sources; excluded from Godot import.\n"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def ordinary_file(path):
    path = Path(path)
    for item in (path, *path.parents):
        info = item.lstat()
        require(not (getattr(info, "st_file_attributes", 0) & 0x400) and not stat.S_ISLNK(info.st_mode),
                "Reparse input forbidden: " + str(item))
    require(path.is_file(), "Missing ordinary input: " + str(path))
    return path


def read(path):
    return ordinary_file(path).read_bytes()


def inventory(root, names):
    return {name: digest(read(root / name)) for name in sorted(names)}


def seal(hashes):
    return digest("\n".join(name + " " + value for name, value in sorted(hashes.items())).encode())


def package_names(manifest):
    require(manifest.get("environment_id") == "grand_casino" and manifest.get("board_size") == [900, 430] and
            manifest.get("pixel_scale") == 2, "Exact Grand public manifest required")
    require([row.get("id") for row in manifest["animations"]] == list(ANIMATION_IDS), "Exact 16-entry inventory required")
    require(tuple(row["id"] for row in manifest["animations"] if row.get("web_low_detail")) == LOW_DETAIL_IDS,
            "Exact seven-entry low-detail contract required")
    names = {MANIFEST, INDEX, BACKGROUND}
    names.update(ART + row["texture"] for row in manifest["animations"])
    names.update(ART + row["texture"] for row in manifest["counters"].values())
    require(len(names) == 22 and len({row["texture"] for row in manifest["animations"]}) == 16,
            "Exact 22-file payload/16 unique animation paths required")
    require(all(not name.startswith(("/", "\\")) and ".." not in name.split("/") and "\\" not in name for name in names),
            "Unsafe package path")
    return tuple(sorted(names))


def opaque(image, size):
    return (image.width, image.height) == size and image.rgba[3::4] == bytes((255,)) * (image.width * image.height)


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def encode_png(image):
    stride = image.width * 4
    compressor = zlib.compressobj(9)
    parts = [compressor.compress(b"\0" + image.rgba[y * stride:(y + 1) * stride]) for y in range(image.height)]
    parts.append(compressor.flush())
    header = struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)
    encoded = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", header) + png_chunk(b"IDAT", b"".join(parts)) + png_chunk(b"IEND", b"")
    require(decode_png(encoded) == image, "PNG roundtrip changed pixels")
    return encoded


def crop(image, rect):
    x, y, width, height = rect
    require(0 <= x < x + width <= image.width and 0 <= y < y + height <= image.height, "Invalid crop")
    data = b"".join(image.rgba[((y + row) * image.width + x) * 4:((y + row) * image.width + x + width) * 4]
                    for row in range(height))
    return PNGImage(width, height, data)


def inside_polygon(x, y, points):
    inside = False
    for (ax, ay), (bx, by) in zip(points, (*points[1:], points[0])):
        if (ay > y) != (by > y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
            inside = not inside
    return inside


def source_y(target_y):
    for sy0, sy1, ty0, ty1 in zip(SOURCE_Y, SOURCE_Y[1:], TARGET_Y, TARGET_Y[1:]):
        if ty0 <= target_y < ty1:
            return min(sy1 - 1, int(sy0 + (target_y - ty0 + .5) * (sy1 - sy0) / (ty1 - ty0)))
    raise ValueError("Y outside table remap")


def table_component(table, sx, sy):
    if sy < 539:
        return "top_and_shallow_apron" if inside_polygon(sx + .5, sy + .5, table["top_points"]) else None
    if sy < 550:
        lower, upper = table["cap"]
        return "pedestal_cap" if lower <= sx < upper else None
    if sy < 590:
        lower, upper = table["stem"]
        # The generated lower gold collar widens at y582; use its physical cap.
        if sy >= 582:
            lower, upper = table["cap"]
        return "pedestal_stem_and_collar" if lower <= sx < upper else None
    lower, upper = table["base"]
    if sy < 602:
        return "pedestal_base" if lower <= sx < upper else None
    # Only the narrow contact directly under the complete physical foot. The
    # surrounding broad cast shadow/generated floor is deliberately excluded.
    return "tight_foot_contact" if lower - 2 <= sx < upper + 2 and sy < 605 else None


def original_donor(table, x, y):
    if y >= HORIZON:
        donor = 744 + (x - table["target"][0]) % 312
        require(708 <= donor < 1092, "Floor donor touched an old table footprint")
        return donor, y, "original_same_row_floor"
    middle = table["target"][0] + table["target"][2] / 2
    offset = (720 if x < middle else 180) if table["id"] == "left" else (-360 if x < middle else -720)
    donor = x + offset
    require(708 <= donor < 1092 and offset % 180 == 0, "Wall donor is not an unobstructed same-phase plank")
    return donor, y, "original_same_row_wall"


def assemble_tables(original, generated):
    require(opaque(original, SIZE) and opaque(generated, RAW_SIZE), "Pinned opaque native/raw dimensions required")
    pixels = bytearray(original.rgba)
    counts, row_evidence = Counter(), []
    for table in TABLES:
        tx, ty, width, height = table["target"]
        sx0, sx1 = table["source_x"]
        for y in range(ty, ty + height):
            sy = source_y(y)
            row_counts = Counter()
            for x in range(tx, tx + width):
                sx = min(sx1 - 1, int(sx0 + (x - tx + .5) * (sx1 - sx0) / width))
                component = table_component(table, sx, sy)
                if component:
                    source_image, donor_x, donor_y, kind = generated, sx, sy, "generated_" + component
                else:
                    donor_x, donor_y, kind = original_donor(table, x, y)
                    source_image = original
                    require(not (688 <= donor_x < 1112 and donor_y >= 636) and donor_y < 604,
                            "Donor touched host/raised circulation trim")
                start = (donor_y * source_image.width + donor_x) * 4
                target = (y * original.width + x) * 4
                pixels[target:target + 4] = source_image.rgba[start:start + 4]
                counts[table["id"] + ":" + kind] += 1
                row_counts[kind] += 1
            row_evidence.append({"table": table["id"], "target_y": y, "generated_source_y": sy, "counts": dict(row_counts)})
    assembled = PNGImage(*SIZE, bytes(pixels))
    changed_runs, changed_pixels = [], 0
    for y in range(SIZE[1]):
        run = None
        for x in range(SIZE[0]):
            at = (y * SIZE[0] + x) * 4
            changed = original.rgba[at:at + 4] != assembled.rgba[at:at + 4]
            if changed:
                require(any(tx <= x < tx + width and ty <= y < ty + height for tx, ty, width, height in
                            (table["target"] for table in TABLES)), "Table assembly escaped the two exact repair regions")
                changed_pixels += 1
            if changed and run is None:
                run = x
            elif not changed and run is not None:
                changed_runs.append([y, run, x])
                run = None
        if run is not None:
            changed_runs.append([y, run, SIZE[0]])
    require(changed_pixels > 0 and opaque(assembled, SIZE), "No opaque table repair produced")
    return assembled, {"source_tables": TABLES, "source_y_landmarks": SOURCE_Y, "target_y_landmarks": TARGET_Y,
        "native_near_contact_anchor_y": 516, "physical_base_bottom_exclusive": 586,
        "tight_foot_contact_bottom_exclusive": 588,
        "source_pixel_counts": dict(counts), "rows": row_evidence,
        "changed_pixels": changed_pixels, "changed_native_runs_y_x0_x1": changed_runs,
        "outside_two_repair_regions_pixel_identical": True, "all_samples_copied_without_color_transform": True,
        "floor_donor": "same target row, x=744+((target_x-table_left)%312), unobstructed original gap744..1056",
        "wall_donors": "same target row; left table halves +720/+180; right halves -360/-720; period180 native",
        "wall_floor_horizon_native": HORIZON,
        "sampling": "Piecewise nearest-center Y and per-table nearest-center X; no global room resize or generated-wall/open-floor samples. Narrow generated foot contact at source602..604 is explicitly included."}


def warm_gold(pixel):
    red, green, blue, alpha = pixel
    return alpha == 255 and red >= 90 and green >= 60 and red >= blue + 20 and green >= blue


def alpha_masks(original, payload, manifest):
    updated = deepcopy(manifest)
    updated["animations"][0]["rect"][0] = 245
    expected_manifest = deepcopy(manifest)
    expected_manifest["animations"][0]["rect"][0] = 245
    require(updated == expected_manifest and manifest["animations"][0]["rect"] == [250, 124, 52, 8], "Unexpected manifest delta")
    reports = []
    for entry in updated["animations"][:6]:
        name = ART + entry["texture"]
        source = decode_png(payload[name])
        is_sign = entry["id"] == "casino_sign_pulse"
        require((source.width, source.height) == ((468, 124) if is_sign else (104, 16)), "Unexpected original pulse dimensions")
        pixels, nonzero, retained = bytearray(source.rgba), 0, []
        bx, by, bw, bh = entry["rect"]
        require((source.width, source.height) == (bw * 2, bh * 2), "Pulse scale must remain exact2x")
        for y in range(source.height):
            start = None
            for x in range(source.width):
                index = (y * source.width + x) * 4
                world_x, world_y = bx * 2 + x, by * 2 + y
                master = original.rgba[(world_y * original.width + world_x) * 4:(world_y * original.width + world_x) * 4 + 4]
                if is_sign:
                    selected = 138 <= world_y < 144 and warm_gold(master)
                else:
                    lamp = int(entry["id"].rsplit("_", 1)[1])
                    selected = any(lower <= x < upper for lower, upper in LAMP_COLUMNS[lamp]) and warm_gold(master)
                if selected:
                    require(source.rgba[index + 3] > 0, "Mask attempted to invent opacity")
                    nonzero += 1
                    if start is None:
                        start = x
                else:
                    pixels[index + 3] = 0  # Preserve all original RGB, alpha cut only.
                    if start is not None:
                        retained.append([y, start, x])
                        start = None
            if start is not None:
                retained.append([y, start, source.width])
        require(nonzero == MASK_COUNTS[entry["id"]], "Inspected physical-mask pixel count changed: " + entry["id"])
        image = PNGImage(source.width, source.height, bytes(pixels))
        require(all(image.rgba[i:i + 3] == source.rgba[i:i + 3] and image.rgba[i + 3] in (0, source.rgba[i + 3])
                    for i in range(0, len(pixels), 4)), "Pulse mask changed RGB/increased alpha")
        payload[name] = encode_png(image)
        reports.append({"id": entry["id"], "rect_board": entry["rect"], "size": [source.width, source.height],
            "nonzero_alpha_pixels": nonzero, "transparent_pixels": source.width * source.height - nonzero,
            "all_nonzero_on_actual_original_warm_trim": True, "original_rgb_all_preserved": True,
            "alpha_only_removed_never_increased": True, "retained_local_runs_y_x0_x1": retained})
    payload[MANIFEST] = (json.dumps(updated, indent=2) + "\n").encode()
    return updated, {"masks": reports, "only_manifest_delta": {"id": "casino_light_0", "field": "rect.x", "before": 250, "after": 245},
        "approval_scope": "Explicit parent approval for non-active candidate only", "native_entries": 16,
        "web_low_detail_entries": 7, "all_other_geometry_timing_phase_opacity_blend_still_and_flags_unchanged": True,
        "sign_underline_native_rows": [138, 144], "sign_preserved_alpha": 46}


def load_layout():
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    record = json.loads((evidence / "storage-manifest.json").read_text())
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
                    **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and os.path.normcase(str(layout.workspace)) == os.path.normcase(str(WORKSPACE)),
            "Exact prepared Grand E workspace required")
    return layout


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        layout = load_layout()
        sources = layout.workspace / "candidate_sources"
        baseline = layout.workspace / "source_baseline"
        raw_path = sources / "grand-spatial-r1.png"
        output = sources / "grand-spatial-r1-assembled-v1"
        report_path = layout.evidence / "grand-spatial-r1-assembly.json"
        validate_layout(layout, extra_write_paths=(sources, output, report_path))
        require(not output.exists() and not report_path.exists(), "Immutable candidate/report already exists")
        ignore_path = sources / ".gdignore"
        ignore_exists = ignore_path.exists()
        if ignore_exists:
            require(read(ignore_path) == IGNORE_BYTES, "Existing candidate .gdignore differs; preserve it and stop")
        source = args.source_root.absolute()
        manifest_bytes = read(baseline / MANIFEST)
        require(digest(manifest_bytes) == MANIFEST_SHA, "Original manifest pin differs")
        manifest = json.loads(manifest_bytes)
        names = package_names(manifest)
        before = inventory(baseline, names)
        production_before = inventory(source, (*names, *CONTROLS))
        require(seal(before) == BASELINE_SEAL and {name: production_before[name] for name in names} == before,
                "Original 22-file baseline/current art source differs")
        raw = read(raw_path)
        require(digest(raw) == RAW_SHA, "Generated source exact PNG hash differs")
        original = decode_png(read(baseline / BACKGROUND))
        require(before[BACKGROUND] == BACKGROUND_SHA, "Original master pin differs")
        generated = decode_png(raw)
        assembled, assembly = assemble_tables(original, generated)
        payload = {name: read(baseline / name) for name in names}
        payload[BACKGROUND] = encode_png(assembled)
        counter_proof = []
        for art_id, rectangle in COUNTER_RECTS.items():
            name = ART + "counters/" + art_id + ".png"
            require(decode_png(payload[name]) == crop(original, rectangle), "Original replay is not exact master crop")
            cut = crop(assembled, rectangle)
            require(opaque(cut, (rectangle[2], rectangle[3])), "Replay front became transparent")
            if art_id != "grand_host_station":
                payload[name] = encode_png(cut)
            require(decode_png(payload[name]) == cut, "Candidate replay is not exact integrated crop")
            counter_proof.append({"id": art_id, "native_crop": rectangle, "exact_integrated_master_crop": True,
                                  "opaque": True, "host_bytes_unchanged": art_id == "grand_host_station"})
        candidate_manifest, masks = alpha_masks(original, payload, manifest)
        require(package_names(candidate_manifest) == names, "Candidate package membership changed")
        changed = sorted(name for name in names if digest(payload[name]) != before[name])
        expected_changes = {BACKGROUND, MANIFEST, ART + "counters/grand_table_left.png", ART + "counters/grand_table_right.png"}
        expected_changes.update(ART + row["texture"] for row in manifest["animations"][:6])
        require(set(changed) == expected_changes, "Unexpected changed/unchanged payload set")
        require(inventory(baseline, names) == before and inventory(source, (*names, *CONTROLS)) == production_before and
                digest(read(raw_path)) == RAW_SHA, "Read-only input custody changed before output")
        hashes = {name: digest(payload[name]) for name in names}
        outputs = (sources, output, report_path) + (() if ignore_exists else (ignore_path,))
        validate_layout(layout, extra_write_paths=outputs)
        if not ignore_exists:
            with ignore_path.open("xb") as handle:
                handle.write(IGNORE_BYTES)
        require(read(ignore_path) == IGNORE_BYTES, "Candidate ignore bytes differ after exclusive preparation")
        output.mkdir()  # Exclusive fresh package; never overwrite a predecessor.
        for name in names:
            target = output / name
            validate_layout(layout, extra_write_paths=(target.parent,))
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as handle:
                handle.write(payload[name])
        require(inventory(output, names) == hashes, "Written candidate payload differs from preflight bytes")
        require(inventory(baseline, names) == before and inventory(source, (*names, *CONTROLS)) == production_before and
                digest(read(raw_path)) == RAW_SHA, "Read-only input custody changed during output")
        report = {"schema": "bth.grand_spatial_assembly/v1", "task_id": "BTH-ENV-SPATIAL-GRAND-001",
            "observed_at": datetime.now(timezone.utc).isoformat(), "status": "NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT",
            "recipe_sha256": digest(read(__file__)), "png_decoder_sha256": digest(read(decode_png.__code__.co_filename)),
            "raw_source": {"path": str(raw_path), "sha256": RAW_SHA, "size": RAW_SIZE},
            "baseline": {"path": str(baseline), "file_count": 22, "seal": BASELINE_SEAL, "files": before},
            "output": {"path": str(output), "file_count": 22, "seal": seal(hashes), "files": hashes},
            "changed_payload_paths": changed, "tables": assembly, "counter_replays": counter_proof, "motion_masks": masks,
            "candidate_source_ignore": {"path": str(ignore_path), "sha256": digest(IGNORE_BYTES),
                "status": "EXISTING_EXACT" if ignore_exists else "EXCLUSIVELY_CREATED_AFTER_ALL_PREFLIGHT"},
            "source_hashes_before": production_before, "source_hashes_after": inventory(source, (*names, *CONTROLS)),
            "all_inputs_unchanged": True, "active_files_written": False, "runtime_launched": False,
            "art_approval": False, "test_updated": False, "storage_manifest": str(layout.manifest_path),
            "risks": ["Table silhouette/cap sampling and original-wall continuation require actual-pixel seam review.",
                "Generated gold pedestal collars are copied, never recolored; label/readability needs populated review.",
                "Rourke/Coordinator contacts, all four populated contexts and full motion/Reduce Motion/liveness are pending.",
                "Lamp0 reanchor is art-only and explicit; this candidate is not approved or activated."]}
        validate_layout(layout, extra_write_paths=(layout.evidence,))
        with report_path.open("x", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2)
            handle.write("\n")
        print(json.dumps({"status": report["status"], "package": str(output), "report": str(report_path),
                          "package_seal": seal(hashes), "art_approval": False, "test_updated": False}))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(json.dumps({"status": "GRAND_ASSEMBLY_STOPPED", "error": str(error),
                          "active_files_written": False, "art_approval": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
