"""Non-active V4: pinned V3 book support plus generated dark-timber feet.

Only the exact existing V2 leg masks receive copied generated-material pixels.
No color transform, painting, floor/shadow copy, image generation or runtime.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path

from bth_qa_storage import Layout, validate_layout
import assemble_bar_spatial_candidate as v2
from bar_spatial_candidate_check import (ACTIVE_HASHES, PNGImage, check_changed_region,
                                         check_master, decode_png, source_inventory, validate_candidate)


V3_SHA256 = "165680e258e4d5d5727f6ef7879166f974a88a28c4837285c9b456cafe20abc0"
V3_RECIPE_SHA256 = "dc0012d61c6746055fba2edc65f146ce93988413fcce68e441052b3f8693d887"
V2_RECIPE_SHA256 = "0e243c2c3e41af3f1a750cc1d27136cfcc3d3c54db4024f2b61a389ecdbb0bf6"
DARK_SOURCE_SHA256 = "fd57182cfee0e5c94f393a0faf64c2a7825713638f5c63e2edf59425c36273f9"
DARK_SIZE = (1815, 867)
MASK_COUNTS = {"left_leg": 1681, "right_leg": 1652}
# Half-open source x ranges from inspected dark-timber stems and plinths.
# Clamp edge samples inside timber rather than borrowing adjacent floor colors.
MATERIAL_BOUNDS = {
    "left_leg": {"stem": (1256, 1292), "base": (1249, 1300)},
    "right_leg": {"stem": (1576, 1608), "base": (1568, 1622)},
}
SOURCE_BASE_START_Y = 579


def fit_dark_material(predecessor, generated):
    if not check_master(predecessor)["ok"] or not check_master(generated, DARK_SIZE)["ok"]:
        raise ValueError("Pinned opaque V3/dark-source dimensions required")
    pixels = bytearray(predecessor.rgba)
    counts = {name: 0 for name in MASK_COUNTS}
    clamped, provenance = 0, []
    for y in range(376, 592):
        for x in range(1196, 1644):
            mask = v2._mask_at(x, y)[2]
            if mask not in MASK_COUNTS:
                continue
            source_y = min(generated.height - 1, int((y + .5) * generated.height / predecessor.height))
            normalized_x = min(generated.width - 1, int((x + .5) * generated.width / predecessor.width))
            band = "stem" if source_y < SOURCE_BASE_START_Y else "base"
            lower, upper = MATERIAL_BOUNDS[mask][band]
            source_x = min(upper - 1, max(lower, normalized_x))
            clamped += int(source_x != normalized_x)
            source_index = (source_y * generated.width + source_x) * 4
            target_index = (y * predecessor.width + x) * 4
            pixels[target_index:target_index + 4] = generated.rgba[source_index:source_index + 4]
            counts[mask] += 1
            provenance.append({"target": [x, y], "generated_source": [source_x, source_y],
                               "existing_mask": mask, "material_band": band})
    if counts != MASK_COUNTS:
        raise ValueError("Exact immutable leg silhouette pixel counts changed: " + repr(counts))
    output = PNGImage(predecessor.width, predecessor.height, bytes(pixels))
    delta = check_changed_region(predecessor, output)
    if not delta["ok"]:
        raise ValueError("Foot-material assembly escaped the original repair envelope")
    changed = 0
    for y in range(376, 592):
        for x in range(1196, 1644):
            index = (y * predecessor.width + x) * 4
            if predecessor.rgba[index:index + 4] == output.rgba[index:index + 4]:
                continue
            changed += 1
            if v2._mask_at(x, y)[2] not in MASK_COUNTS:
                raise ValueError("Changed a non-leg V3 pixel at %d,%d" % (x, y))
    if changed == 0:
        raise ValueError("No generated dark material was installed")
    return output, {"copied_mask_pixel_counts": counts, "changed_pixels": changed,
        "clamped_source_edge_samples": clamped, "source_material_x_bounds": MATERIAL_BOUNDS,
        "source_base_start_y": SOURCE_BASE_START_Y,
        "sampling": "Nearest center-normalized 1815x867 -> 1800x860 coordinates; x clamped to inspected timber interiors per stem/base.",
        "material_provenance": provenance,
        "only_existing_leg_masks_changed": True, "silhouette_mask_unchanged": True,
        "negative_floor_and_contact_shadows_identical": True,
        "v3_book_contact_tabletop_and_ball_planes_identical": True,
        "no_color_transform_or_painted_pixels": True}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
        receipt = json.loads((evidence / "storage-manifest.json").read_text())
        layout = Layout(**{key: Path(value) for key, value in receipt["paths"].items()},
                        **{key: receipt[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
        directory = layout.workspace / "candidate_sources"
        source_path = directory / "bar-spatial-dark-feet-raw.png"
        predecessor_path = directory / "bar-spatial-r2-assembled-v3.png"
        output = directory / "bar-spatial-r2-assembled-v4.png"
        report_path = evidence / "bar-spatial-r2-assembly-v4.json"
        validate_layout(layout, extra_write_paths=(directory, output, report_path))
        if output.exists() or report_path.exists() or not (directory / ".gdignore").is_file():
            raise ValueError("Fresh V4 output/report and existing candidate .gdignore required")
        if hashlib.sha256(Path(v2.__file__).read_bytes()).hexdigest() != V2_RECIPE_SHA256:
            raise ValueError("V2 silhouette recipe changed")
        v3_recipe = Path(__file__).with_name("assemble_bar_spatial_candidate_v3.py")
        if hashlib.sha256(v3_recipe.read_bytes()).hexdigest() != V3_RECIPE_SHA256:
            raise ValueError("Immutable V3 book-support recipe changed")
        generated_bytes, predecessor_bytes = source_path.read_bytes(), predecessor_path.read_bytes()
        if hashlib.sha256(generated_bytes).hexdigest() != DARK_SOURCE_SHA256:
            raise ValueError("Generated dark-feet input SHA256 differs")
        if hashlib.sha256(predecessor_bytes).hexdigest() != V3_SHA256:
            raise ValueError("Immutable V3 input SHA256 differs")
        source_root = args.source_root.resolve(strict=True)
        before = source_inventory(source_root)
        if any(before.get(name) != expected for name, expected in ACTIVE_HASHES.items()):
            raise ValueError("Active R4 source identity mismatch")
        image, assembly = fit_dark_material(decode_png(predecessor_bytes), decode_png(generated_bytes))
        encoded = v2.encode_opaque_png(image)
        if decode_png(encoded) != image:
            raise ValueError("V4 PNG encoder changed material pixels")
        validate_layout(layout, extra_write_paths=(directory, output, report_path))
        with output.open("xb") as handle:
            handle.write(encoded)
        preflight = validate_candidate(source_root, output, v2.FELT_POLYGON)
        after = source_inventory(source_root)
        ready = preflight["status"] == "CANDIDATE_PREFLIGHT_PASS" and before == after
        report = {"schema": "bth.bar_spatial_assembly/v1", "task_id": "BTH-ENV-SPATIAL-BAR-001",
            "recipe": "bar-spatial-r2-assembly-v4", "observed_at": datetime.now(timezone.utc).isoformat(),
            "status": "NON_ACTIVE_V4_READY_FOR_INDEPENDENT_AUDIT" if ready else "NON_ACTIVE_V4_PREFLIGHT_FAILED",
            "recipe_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "predecessor_v3": {"path": str(predecessor_path), "sha256": V3_SHA256, "recipe_sha256": V3_RECIPE_SHA256},
            "generated_dark_material": {"path": str(source_path), "sha256": DARK_SOURCE_SHA256, "size": DARK_SIZE},
            "output": {"path": str(output), "sha256": hashlib.sha256(encoded).hexdigest(), "size": [1800, 860]},
            "declared_felt_polygon_board": v2.FELT_POLYGON, "assembly": assembly, "preflight": preflight,
            "active_source_unchanged": before == after, "active_files_written": False, "art_approval": False,
            "storage_manifest": str(layout.manifest_path),
            "risks": ["Copied stem/base material edges require independent actual-pixel review.",
                "Actual Fight labels and Numbers painted contact still need populated composition audit.",
                "No native scenario, animation/liveness, Reduce Motion or TEST release acceptance is implied."]}
        validate_layout(layout, extra_write_paths=(directory, report_path))
        with report_path.open("x", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2)
            handle.write("\n")
        print(json.dumps({"status": report["status"], "output": str(output), "report": str(report_path), "art_approval": False}))
        return 0 if ready else 1
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(json.dumps({"status": "ASSEMBLY_STOPPED", "error": str(error), "art_approval": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
