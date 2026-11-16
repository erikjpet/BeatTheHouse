"""Non-active V3: widen only V2's left tabletop for the painted Numbers contact.

Pure row-wise nearest-neighbor copies of existing V2 table pixels. The immutable
V2 recipe, all right/lower furniture, feet, floor and animation payloads remain.
No generation, recoloring, painting, runtime launch or publication.
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
                                         decode_png, source_inventory, validate_candidate)


V2_SHA256 = "5df5041dabe3d674c31bf201cf8c6ee270f7694cc45cdc59a3326f7bd1d0412d"
V2_RECIPE_SHA256 = "0e243c2c3e41af3f1a750cc1d27136cfcc3d3c54db4024f2b61a389ecdbb0bf6"
LEFT, ANCHOR, TOP, BOTTOM = 1196, 1350, 376, 496
# Conservatively cover the auditor-observed glow/contact x598.84..639.16,
# y188..190 in board units, independently of the label rectangle.
CONTACT_NATIVE = (1197, 376, 82, 4)


def assemble_left_tabletop(image):
    pixels = bytearray(image.rgba)
    mappings, copied = [], {}
    for y in range(TOP, BOTTOM):
        body = [x for x in range(LEFT, ANCHOR) if v2._mask_at(x, y)[2] == "body"]
        if not body:
            raise ValueError("Pinned V2 lacks a physical body sample on row %d" % y)
        old_left = body[0]
        source_width, target_width = ANCHOR - old_left, ANCHOR - LEFT
        mappings.append({"native_y": y, "old_left": old_left, "new_left": LEFT, "fixed_interior_x": ANCHOR})
        for x in range(LEFT, ANCHOR):
            source_x = old_left + min(source_width - 1, int((x - LEFT + .5) * source_width / target_width))
            if v2._mask_at(source_x, y)[2] != "body":
                raise ValueError("Remap attempted to copy a V2 non-table texel")
            target_index, source_index = (y * image.width + x) * 4, (y * image.width + source_x) * 4
            pixels[target_index:target_index + 4] = image.rgba[source_index:source_index + 4]
            if (CONTACT_NATIVE[0] <= x < CONTACT_NATIVE[0] + CONTACT_NATIVE[2] and
                    CONTACT_NATIVE[1] <= y < CONTACT_NATIVE[1] + CONTACT_NATIVE[3]):
                copied[(x, y)] = [source_x, y]
    output = PNGImage(image.width, image.height, bytes(pixels))
    delta = check_changed_region(image, output, board_rect=(598, 188, 77, 60))
    if not delta["ok"]:
        raise ValueError("V3 modified pixels outside the permitted left tabletop")
    failures, provenance = [], []
    for y in range(CONTACT_NATIVE[1], CONTACT_NATIVE[1] + CONTACT_NATIVE[3]):
        for x in range(CONTACT_NATIVE[0], CONTACT_NATIVE[0] + CONTACT_NATIVE[2]):
            donor = copied.get((x, y))
            actual = output.rgba[(y * image.width + x) * 4:(y * image.width + x) * 4 + 4]
            valid = donor is not None and v2._mask_at(*donor)[2] == "body" and actual[3] == 255
            if valid:
                index = (donor[1] * image.width + donor[0]) * 4
                valid = actual == image.rgba[index:index + 4]
            if not valid:
                failures.append({"native_pixel": [x, y], "source": donor})
            else:
                provenance.append({"native_pixel": [x, y], "v2_table_source_pixel": donor})
    return output, {"row_mappings": mappings, "delta_from_v2": delta,
        "right_table_lower_body_feet_floor_wall_outside_extension_identical": True,
        "painted_contact_support": {"ok": not failures, "native_contact_rect": CONTACT_NATIVE,
            "auditor_observed_board_glow": [598.84, 188, 40.32, 2],
            "assertion": "Each actual contact-band texel is copied from an opaque pinned V2 physical tabletop/body texel, not inferred from label bounds.",
            "checked_pixels": len(provenance) + len(failures), "failures": failures, "provenance": provenance,
            "limits": "This is pixel/material provenance for the observed contact band; independent populated review must still confirm believable support. Faint shadow above y188/outside the envelope is not moved."}}


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
        predecessor = directory / "bar-spatial-r2-assembled-v2.png"
        output = directory / "bar-spatial-r2-assembled-v3.png"
        report_path = evidence / "bar-spatial-r2-assembly-v3.json"
        validate_layout(layout, extra_write_paths=(directory, output, report_path))
        if output.exists() or report_path.exists() or not (directory / ".gdignore").is_file():
            raise ValueError("Fresh V3 output/report and existing candidate .gdignore required")
        if hashlib.sha256(Path(v2.__file__).read_bytes()).hexdigest() != V2_RECIPE_SHA256:
            raise ValueError("Immutable V2 recipe changed")
        original = predecessor.read_bytes()
        if hashlib.sha256(original).hexdigest() != V2_SHA256:
            raise ValueError("Immutable V2 candidate changed")
        source = args.source_root.resolve(strict=True)
        before = source_inventory(source)
        if any(before.get(name) != expected for name, expected in ACTIVE_HASHES.items()):
            raise ValueError("Active R4 source identity mismatch")
        image, assembly = assemble_left_tabletop(decode_png(original))
        png = v2.encode_opaque_png(image)
        if decode_png(png) != image or not assembly["painted_contact_support"]["ok"]:
            raise ValueError("V3 encoding/contact-support preflight failed")
        validate_layout(layout, extra_write_paths=(directory, output, report_path))
        with output.open("xb") as handle:
            handle.write(png)
        preflight = validate_candidate(source, output, v2.FELT_POLYGON)
        after = source_inventory(source)
        ready = preflight["status"] == "CANDIDATE_PREFLIGHT_PASS" and before == after
        report = {"schema": "bth.bar_spatial_assembly/v1", "recipe": "bar-spatial-r2-assembly-v3",
            "task_id": "BTH-ENV-SPATIAL-BAR-001", "observed_at": datetime.now(timezone.utc).isoformat(),
            "status": "NON_ACTIVE_V3_READY_FOR_CONTACT_AUDIT" if ready else "NON_ACTIVE_V3_PREFLIGHT_FAILED",
            "predecessor_v2": {"path": str(predecessor), "sha256": V2_SHA256, "recipe_sha256": V2_RECIPE_SHA256},
            "output": {"path": str(output), "sha256": hashlib.sha256(png).hexdigest(), "size": [1800, 860]},
            "declared_felt_polygon_board": v2.FELT_POLYGON, "assembly": assembly, "preflight": preflight,
            "active_source_unchanged": before == after, "active_files_written": False, "art_approval": False,
            "storage_manifest": str(layout.manifest_path),
            "risks": ["Wider rear-left tabletop needs independent actual painted-contact review.",
                "Gold V2 feet are deliberately unchanged and remain rejected pending separately generated dark-timber material.",
                "No motion/scenario/Reduce Motion/liveness/TEST acceptance is implied."]}
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
