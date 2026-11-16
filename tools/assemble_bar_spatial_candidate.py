"""Mechanically assemble one non-active Bar R2 candidate; never activate art.

Only copies/nearest-neighbor resamples the pinned imagegen source and original
master/floor pixels. No new colors, painting, blending, imagegen or child launch.
Run through the admitted capped QA runner; all new files remain candidate/evidence.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import zlib

from bth_qa_storage import Layout, validate_layout
from bar_spatial_candidate_check import (ACTIVE_HASHES, PNGImage, check_changed_region,
                                         check_master, decode_png, point_in_polygon,
                                         source_inventory, validate_candidate)


RECIPE_VERSION = "bar-spatial-r2-assembly-v1"
RAW_SHA256 = "a850b1bc8f36ea62db85cba4f80233cc10591353b8fb0d8a0a82c9998aec16c7"
RAW_SIZE = (1815, 867)
SOURCE_RECT = (1184, 376, 488, 216)
TARGET_RECT = (1196, 376, 448, 216)
SOURCE_Y = (376, 390, 460, 531, 582, 592)
TARGET_Y = (376, 392, 496, 544, 588, 592)
FELT_POLYGON = ((633, 204), (788, 204), (805, 246), (616, 246))
FLOOR_HORIZON = 488
OLD_BODY_BOTTOM = 528  # Same-coordinate R4 floor is exposed below the old frame.
FLOOR_DONOR_X = (1664, 1800)  # Unobstructed original floor; keep each exact y.

# Source-pixel silhouettes traced from inspected R2. Body/legs/contact shadows
# stay separate so the negative floor space is never vertically resampled.
TABLE_MASKS = {
    "body": ((1241, 376), (1607, 376), (1618, 383), (1666, 451),
             (1671, 459), (1671, 476), (1664, 485), (1657, 489),
             (1652, 520), (1648, 528), (1207, 528), (1202, 520),
             (1196, 488), (1189, 484), (1185, 476), (1185, 460),
             (1190, 451), (1234, 385)),
    "left_leg": ((1239, 525), (1277, 525), (1274, 562), (1286, 565),
                 (1286, 578), (1231, 578), (1231, 565), (1238, 561)),
    "right_leg": ((1580, 525), (1616, 525), (1619, 562), (1628, 565),
                  (1628, 578), (1574, 578), (1574, 565), (1583, 561)),
    "left_contact_shadow": ((1228, 575), (1290, 575), (1295, 584), (1223, 584)),
    "right_contact_shadow": ((1568, 575), (1634, 575), (1638, 584), (1562, 584)),
}


def native_source_row(target_y):
    for index in range(len(TARGET_Y) - 1):
        if TARGET_Y[index] <= target_y < TARGET_Y[index + 1]:
            source_height = SOURCE_Y[index + 1] - SOURCE_Y[index]
            target_height = TARGET_Y[index + 1] - TARGET_Y[index]
            offset = int((target_y - TARGET_Y[index] + .5) * source_height / target_height)
            return SOURCE_Y[index] + min(offset, source_height - 1)
    raise ValueError("Row is outside the bounded target")


def assemble_pixels(original, generated):
    """Pure in-memory recipe. Every returned RGBA sample is copied from an input."""
    if not check_master(original)["ok"] or not check_master(generated, RAW_SIZE)["ok"]:
        raise ValueError("Exact opaque original/raw dimensions are required")
    candidate = bytearray(original.rgba)
    counts = {"generated_table": 0, "generated_upper_background": 0,
              "original_floor_same_coordinate": 0, "original_floor_same_row_donor": 0}
    counts.update({name: 0 for name in TABLE_MASKS})
    target_left, target_top, target_width, target_height = TARGET_RECT
    source_left, _source_top, source_width, _source_height = SOURCE_RECT
    for y in range(target_top, target_top + target_height):
        source_y = native_source_row(y)
        for x in range(target_left, target_left + target_width):
            source_x = source_left + min(source_width - 1,
                                        int((x - target_left + .5) * source_width / target_width))
            point = (source_x + .5, source_y + .5)
            mask = next((name for name, polygon in TABLE_MASKS.items()
                         if point_in_polygon(point, polygon)), None)
            target_index = (y * original.width + x) * 4
            if mask is not None:
                source_index = (source_y * generated.width + source_x) * 4
                candidate[target_index:target_index + 4] = generated.rgba[source_index:source_index + 4]
                counts["generated_table"] += 1
                counts[mask] += 1
            elif y < FLOOR_HORIZON:
                # Clear the old upright frame with the generated wall material,
                # within the explicitly permitted repair rectangle only.
                source_index = (source_y * generated.width + source_x) * 4
                candidate[target_index:target_index + 4] = generated.rgba[source_index:source_index + 4]
                counts["generated_upper_background"] += 1
            elif y >= OLD_BODY_BOTTOM:
                # The original master's real floor was never hidden here.
                counts["original_floor_same_coordinate"] += 1
            else:
                # Original R4 has a frame, not floor, at these few side slivers.
                # Copy unobstructed original floor from exactly the same y, so
                # no vertical plank/horizon position can drift.
                donor_x = FLOOR_DONOR_X[0] + (x - target_left) % (FLOOR_DONOR_X[1] - FLOOR_DONOR_X[0])
                donor_index = (y * original.width + donor_x) * 4
                candidate[target_index:target_index + 4] = original.rgba[donor_index:donor_index + 4]
                counts["original_floor_same_row_donor"] += 1
    image = PNGImage(original.width, original.height, bytes(candidate))
    bounded = check_changed_region(original, image)
    if not bounded["ok"]:
        raise ValueError("Internal recipe error: changed pixels outside repair envelope")
    return image, counts, bounded


def encode_opaque_png(image):
    """Encode deterministic filter-0 RGBA PNG bytes, requiring fully opaque input."""
    if image.rgba[3::4].count(255) != image.width * image.height:
        raise ValueError("Opaque PNG encoder rejects nonopaque pixels")

    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload +
                struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))

    stride = image.width * 4
    rows = b"".join(b"\0" + image.rgba[y * stride:(y + 1) * stride] for y in range(image.height))
    return (b"\x89PNG\r\n\x1a\n" +
            chunk(b"IHDR", struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(rows, level=6)) + chunk(b"IEND", b""))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--raw-source", type=Path, help="Pinned R2 raw PNG; defaults to workspace candidate_sources")
    args = parser.parse_args(argv)
    try:
        evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
        receipt = json.loads((evidence / "storage-manifest.json").read_text(encoding="utf-8"))
        layout = Layout(**{key: Path(value) for key, value in receipt["paths"].items()},
                        **{key: receipt[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
        candidate_dir = layout.workspace / "candidate_sources"
        output = candidate_dir / "bar-spatial-r2-assembled-v1.png"
        ignore = candidate_dir / ".gdignore"
        report_path = evidence / "bar-spatial-r2-assembly.json"
        admission = validate_layout(layout, extra_write_paths=(candidate_dir, output, report_path))
        # No mkdir, exclusion marker or output has been written before admission.
        if output.exists() or report_path.exists():
            raise ValueError("Immutable candidate/report already exists; no overwrite is permitted")
        source = args.source_root.resolve(strict=True)
        raw_path = (args.raw_source or candidate_dir / "bar-spatial-r2-raw.png").resolve(strict=True)
        raw_bytes = raw_path.read_bytes()
        if hashlib.sha256(raw_bytes).hexdigest() != RAW_SHA256:
            raise ValueError("R2 raw source SHA256 differs from the pinned imagegen input")
        before = source_inventory(source)
        mismatched = [name for name, digest in ACTIVE_HASHES.items() if before.get(name) != digest]
        if mismatched:
            raise ValueError("Active R4 source identity mismatch: " + ", ".join(mismatched))
        original_path = source / "assets/art/environments/bar/background.png"
        original_bytes = original_path.read_bytes()
        image, counts, bounded = assemble_pixels(decode_png(original_bytes), decode_png(raw_bytes))
        png_bytes = encode_opaque_png(image)
        roundtrip = decode_png(png_bytes)
        if roundtrip != image:
            raise ValueError("Encoder round-trip changed candidate pixels")
        validate_layout(layout, extra_write_paths=(candidate_dir, output, report_path))
        candidate_dir.mkdir(exist_ok=True)
        marker_created = False
        if ignore.exists():
            if ignore.is_symlink() or not ignore.is_file():
                raise ValueError("Existing .gdignore is not a regular file")
        else:
            # Exclusive creation preserves any concurrent owner's marker.
            try:
                with ignore.open("xb") as marker:
                    marker.write(b"")
                marker_created = True
            except FileExistsError:
                if ignore.is_symlink() or not ignore.is_file():
                    raise ValueError("Concurrent .gdignore is not a regular file")
        validate_layout(layout, extra_write_paths=(candidate_dir, output, report_path))
        with output.open("xb") as handle:
            handle.write(png_bytes)
        # This reads the new candidate and active source; it never activates it.
        preflight = validate_candidate(source, output, FELT_POLYGON)
        after = source_inventory(source)
        changed = [name for name in sorted(set(before) | set(after)) if before.get(name) != after.get(name)]
        ready = preflight["status"] == "CANDIDATE_PREFLIGHT_PASS" and not changed
        report = {"schema": "bth.bar_spatial_assembly/v1", "task_id": "BTH-ENV-SPATIAL-BAR-001",
                  "observed_at": datetime.now(timezone.utc).isoformat(), "recipe": RECIPE_VERSION,
                  "recipe_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  "status": "NON_ACTIVE_CANDIDATE_READY_FOR_AUDIT" if ready else "NON_ACTIVE_CANDIDATE_PREFLIGHT_FAILED",
                  "art_approval": False, "active_files_written": False,
                  "raw_source": {"path": str(raw_path), "sha256": RAW_SHA256, "size": list(RAW_SIZE)},
                  "active_master": {"path": str(original_path), "sha256": hashlib.sha256(original_bytes).hexdigest()},
                  "output": {"path": str(output), "sha256": hashlib.sha256(png_bytes).hexdigest(), "size": [image.width, image.height]},
                  "source_crop_native": SOURCE_RECT, "target_rect_native": TARGET_RECT,
                  "source_y_bands": SOURCE_Y, "target_y_bands": TARGET_Y,
                  "resampling": "Nearest neighbor, center-sampled; horizontal strip fit plus explicit vertical bands.",
                  "table_masks_source_native": TABLE_MASKS, "declared_felt_polygon_board": FELT_POLYGON,
                  "floor_restoration": {"horizon_native_y": FLOOR_HORIZON,
                      "same_coordinate_original_floor_begins_y": OLD_BODY_BOTTOM,
                      "occluded_sliver_same_row_original_donor_x": FLOOR_DONOR_X,
                      "no_vertical_floor_resampling": True},
                  "copied_pixel_counts": counts, "bounded_difference": bounded,
                  "gdignore": {"path": str(ignore), "created": marker_created},
                  "active_source_unchanged": not changed, "changed_active_source_paths": changed,
                  "preflight": preflight, "storage_manifest": str(layout.manifest_path),
                  "storage_admission": admission, "zlib_version": zlib.ZLIB_VERSION,
                  "declared_outputs": [str(output), str(ignore), str(report_path)],
                  "risks": ["Declared felt and tight silhouettes require independent inspection against actual painted pixels.",
                      "Nearest-neighbor band fitting changes proportions and may expose local sampling/outline artifacts.",
                      "Same-row original-floor donors fill previously hidden side slivers; those are copied pixels, not recovered original hidden floor.",
                      "Generated upper background is local to the allowed envelope; inspect its wall joins for seams.",
                      "No live actor/label, floor-mover occlusion, animation/liveness, Reduce Motion or TEST/Web approval."]}
        # Output PNG is now an existing file: validate the admitted containing
        # directory and still-new report path, not an existing-file ancestor.
        validate_layout(layout, extra_write_paths=(candidate_dir, report_path))
        with report_path.open("x", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2)
            handle.write("\n")
        print(json.dumps({"status": report["status"], "output": str(output),
                          "felt_polygon": FELT_POLYGON, "report": str(report_path), "art_approval": False}))
        return 0 if ready else 1
    except (OSError, ValueError, KeyError, RuntimeError) as exc:
        # Preserve any partial/non-active candidate; never delete or fall back.
        print(json.dumps({"status": "ASSEMBLY_STOPPED", "error": str(exc),
                          "art_approval": False, "active_files_written": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
