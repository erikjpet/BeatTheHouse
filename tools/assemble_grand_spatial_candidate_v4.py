"""Non-active V4: quiet generated timber on the right lower collar only.

Parent runs this worker under a fresh guarded E Job. No neck repair, recolor,
new pixels, floor changes, full-leg replacement, runtime or activation.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path

import assemble_grand_spatial_candidate as v1
from bar_spatial_candidate_check import PNGImage, decode_png
from bth_qa_storage import validate_layout

V3_SEAL = "3502800e87bbdb65510cf20193a6237d6894cf6fceaed8708bdbeb2e424bc892"
V3_MASTER_SHA = "5b017df8ec2373c9779d2b76d0f705217f7ec2c1d7402afd0cc7b19e5082d3e1"
V3_REPORT = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GRANDTRIAL-20261116-assemble07/evidence/grand-spatial-r1-assembly-v3.json")
V3_REPORT_SHA = "e4fb71fa74def2d2c5f0a24c290b48a6c966f5ec9108b467e47c9718c20491b8"
RAW_SHA = "31e7a40bfedcbc68a00a615e400b3df88bab03d180558fd3c88749a410147c63"
V1_SEAL = "f566676578505fcf25809e491ed686fa0a0a21139c77276bf49c64f87205c6ea"
V2_SEAL = "006c07da034046c64544020f4a0662a4d43f42eefad843bd74e26c02fbc68524"
FROZEN_RECIPES = {
    "assemble_grand_spatial_candidate.py": "b65b8239901c198f715df7b70da94e6dc1b3af8082aef5e7dac878530e9a24ba",
    "assemble_grand_spatial_candidate_v2.py": "25d12a1e2e9c43a44d5f170c91c23ab2955a00044c65c8e3d5ee2c995d88dd6f",
    "assemble_grand_spatial_candidate_v3.py": "2cdd549cd9fd878c57fcc5b1c6d9fff44df5aab8dbec754f6b37df6c0d922d64",
    "assemble_high_limit_spatial_candidate.py": "5fe162da9488e47aef545d7e60ae00908f1bd3f9899451a8ad791218ee516855",
}
DONOR = (1364, 552, 30, 29)  # Inspected quiet inner timber, no gold pixels.
# Half-open actual physical collar runs: last narrow upper edge followed by
# complete lower collar face/outline, never a label-shaped rectangle.
COLLAR_RUNS = ((575, 1347, 1389), (576, 1339, 1394), (577, 1339, 1394),
               (578, 1339, 1394), (579, 1339, 1394))
MASK_PIXELS = 262


def at(image, x, y):
    index = (y * image.width + x) * 4
    return image.rgba[index:index + 4]


def warm_gold(pixel):
    red, green, blue, _ = pixel
    return red >= 90 and green >= 55 and red >= blue + 25


def bright_gold(pixel):
    red, green, blue, _ = pixel
    return red >= 160 and green >= 80 and red >= blue + 25


def recipe_inventory():
    directory = Path(__file__).parent
    return {name: v1.digest(v1.read(directory / name)) for name in FROZEN_RECIPES}


def collar_mask():
    table = next(table for table in v1.TABLES if table["id"] == "right")
    tx, _, width, _ = table["target"]
    sx0, sx1 = table["source_x"]
    rows = []
    for y in range(575, 580):
        xs = []
        sy = v1.source_y(y)
        for x in range(1338, 1394):
            sx = min(sx1 - 1, int(sx0 + (x - tx + .5) * (sx1 - sx0) / width))
            if v1.table_component(table, sx, sy) == "pedestal_stem_and_collar":
                xs.append(x)
        v1.require(xs and xs == list(range(xs[0], xs[-1] + 1)), "Collar component is not contiguous")
        rows.append((y, xs[0], xs[-1] + 1))
    v1.require(tuple(rows) == COLLAR_RUNS and sum(end - begin for _, begin, end in rows) == MASK_PIXELS,
               "Pinned V1 physical lower-collar mask changed")
    return {(x, y) for y, begin, end in rows for x in range(begin, end)}


def graft(predecessor, raw):
    v1.require(v1.opaque(predecessor, v1.SIZE) and v1.opaque(raw, v1.RAW_SIZE), "Opaque pinned master/raw dimensions required")
    dx, dy, dw, dh = DONOR
    donor_pixels = [at(raw, x, y) for y in range(dy, dy + dh) for x in range(dx, dx + dw)]
    v1.require(max(max(pixel[:3]) for pixel in donor_pixels) <= 69 and not any(warm_gold(pixel) for pixel in donor_pixels),
               "Inspected original generated timber donor is no longer quiet/dark")
    mask = collar_mask()
    pixels = bytearray(predecessor.rgba)
    provenance = []
    for y, begin, end in COLLAR_RUNS:
        source_y = min(dy + dh - 1, int(dy + (y - 575 + .5) * dh / 5))
        for x in range(begin, end):
            source_x = min(dx + dw - 1, int(dx + (x - begin + .5) * dw / (end - begin)))
            source = at(raw, source_x, source_y)
            old = at(predecessor, x, y)
            v1.require(source[3] == old[3] == 255, "Physical collar/source alpha changed")
            index = (y * predecessor.width + x) * 4
            pixels[index:index + 4] = source
            provenance.append([y, x, source_x, source_y, list(old), list(source)])
    output = PNGImage(*v1.SIZE, bytes(pixels))
    changed = []
    for y in range(output.height):
        for x in range(output.width):
            if at(predecessor, x, y) != at(output, x, y):
                v1.require((x, y) in mask, "Graft escaped the exact physical lower collar")
                changed.append((x, y))
            v1.require(at(predecessor, x, y)[3] == at(output, x, y)[3], "Graft changed shape/alpha")
    before_warm = sum(warm_gold(at(predecessor, x, y)) for x, y in mask)
    before_bright = sum(bright_gold(at(predecessor, x, y)) for x, y in mask)
    after_warm = sum(warm_gold(at(output, x, y)) for x, y in mask)
    v1.require(changed and before_bright > 0 and after_warm == 0, "Bright lower collar was not replaced by quiet source timber")
    return output, mask, {"exact_native_runs_y_x0_x1": COLLAR_RUNS, "physical_mask_pixels": MASK_PIXELS,
        "changed_pixels": len(changed), "donor_raw_bounds_xywh": DONOR, "donor_max_rgb_channel": 69,
        "per_pixel_y_x_source_x_source_y_old_rgba_copied_rgba": provenance,
        "warm_before_after_predicate_R90_G55_RminusB25": [before_warm, after_warm],
        "bright_before_predicate_R160_G80_RminusB25": before_bright,
        "all_alpha_identical": True, "outside_mask_rgba_identical_v3": True,
        "sampling": "Per-row nearest-center fit of inspected original generated inner-stem pixels to the actual lower collar face/edge.",
        "physical_parts_unchanged": "Topcap, full leg, foot base, neck, table, all floor and all V3 contact shadows.",
        "no_painted_colors_recolor_filter_blend_or_label_plaque": True,
        "label_risk_basis": "Blackjack native label[1293.8002,558,128.4,30] crosses this collar; actor/label coordinates remain fixed."}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        layout = v1.load_layout()
        recipe_sha = v1.digest(v1.read(__file__))
        v1.require(recipe_inventory() == FROZEN_RECIPES, "A frozen Grand/HL predecessor recipe changed")
        v1.require(v1.digest(v1.read(V3_REPORT)) == V3_REPORT_SHA, "Immutable V3 report differs")
        prior = json.loads(v1.read(V3_REPORT))
        job = json.loads(v1.read(V3_REPORT.parent / "job.json"))
        v1.require(job.get("exit_code") == 0 and job.get("active_at_release") == 0 and job.get("assigned_before_execution") and
                   not any(job.get(key) for key in ("error", "cleanup_errors", "timed_out", "log_error", "log_truncated")) and
                   job.get("limits", {}).get("cpu_rate") == 1200 and job.get("limits", {}).get("job_memory_limit_bytes") == 2 * 1024 ** 3 and
                   job.get("storage_gate_before_job") and job.get("storage_gate_before_child"), "V3 guarded Job is not closed PASS/zero")
        sources = layout.workspace / "candidate_sources"
        predecessor = sources / "grand-spatial-r1-assembled-v3"
        output = sources / "grand-spatial-r1-assembled-v4"
        report_path = layout.evidence / "grand-spatial-r1-assembly-v4.json"
        raw_path = sources / "grand-spatial-r1.png"
        validate_layout(layout, extra_write_paths=(sources, output, report_path))
        v1.require(not output.exists() and not report_path.exists(), "Fresh V4 output/report required; preserve V1/V2/V3")
        v1.require(v1.read(sources / ".gdignore") == v1.IGNORE_BYTES, "Exact existing non-active ignore required")
        names = v1.package_names(json.loads(v1.read(predecessor / v1.MANIFEST)))
        before = v1.inventory(predecessor, names)
        v1.require(v1.seal(before) == V3_SEAL and before == prior["output"]["files"] and before[v1.BACKGROUND] == V3_MASTER_SHA,
                   "Exact V3 payload/seal/master required")
        source_before = v1.inventory(args.source_root, (*names, *v1.CONTROLS))
        v1_before = v1.inventory(sources / "grand-spatial-r1-assembled-v1", names)
        v2_before = v1.inventory(sources / "grand-spatial-r1-assembled-v2", names)
        v1.require(v1.seal(v1_before) == V1_SEAL and v1.seal(v2_before) == V2_SEAL, "Immutable V1/V2 payload seal differs")
        raw_bytes = v1.read(raw_path)
        v1.require(v1.digest(raw_bytes) == RAW_SHA, "Retained generated R1 source differs")
        predecessor_image = decode_png(v1.read(predecessor / v1.BACKGROUND))
        assembled, mask, assembly = graft(predecessor_image, decode_png(raw_bytes))
        payload = {name: v1.read(predecessor / name) for name in names}
        payload[v1.BACKGROUND] = v1.encode_png(assembled)
        replay = []
        for art_id, rect in v1.COUNTER_RECTS.items():
            name = v1.ART + "counters/" + art_id + ".png"
            old, new = decode_png(payload[name]), v1.crop(assembled, rect)
            v1.require(old == v1.crop(predecessor_image, rect), "V3 replay is not exact master crop")
            for y in range(old.height):
                for x in range(old.width):
                    if at(old, x, y) != at(new, x, y):
                        v1.require((x + rect[0], y + rect[1]) in mask, "Counter changed outside exact collar")
            if art_id == "grand_table_right":
                payload[name] = v1.encode_png(new)
            v1.require(decode_png(payload[name]) == new, "V4 replay is not exact integrated master crop")
            replay.append({"id": art_id, "native_crop": rect, "opaque": v1.opaque(new, rect[2:]), "exact_master_crop": True,
                           "byte_identical_v3": art_id != "grand_table_right"})
        hashes = {name: v1.digest(payload[name]) for name in names}
        changed = sorted(name for name in names if hashes[name] != before[name])
        v1.require(set(changed) == {v1.BACKGROUND, v1.ART + "counters/grand_table_right.png"}, "Only master and right counter may change")
        def unchanged():
            return (v1.inventory(predecessor, names) == before and v1.inventory(args.source_root, (*names, *v1.CONTROLS)) == source_before and
                    v1.inventory(sources / "grand-spatial-r1-assembled-v1", names) == v1_before and
                    v1.inventory(sources / "grand-spatial-r1-assembled-v2", names) == v2_before and
                    recipe_inventory() == FROZEN_RECIPES and v1.digest(v1.read(__file__)) == recipe_sha and
                    v1.digest(v1.read(raw_path)) == RAW_SHA and v1.digest(v1.read(V3_REPORT)) == V3_REPORT_SHA)
        v1.require(unchanged(), "Source/V1/V2/V3 custody changed before output")
        validate_layout(layout, extra_write_paths=(sources, output, report_path))
        output.mkdir()
        for name in names:
            target = output / name
            validate_layout(layout, extra_write_paths=(target.parent,))
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as handle:
                handle.write(payload[name])
        v1.require(v1.inventory(output, names) == hashes and unchanged(), "Written payload or read-only predecessor custody differs")
        report = {"schema": "bth.grand_spatial_assembly/v4", "task_id": "BTH-ENV-SPATIAL-GRAND-001",
            "status": "NON_ACTIVE_V4_READY_FOR_INDEPENDENT_ACTUAL_PIXEL_AUDIT", "observed_at": datetime.now(timezone.utc).isoformat(),
            "recipe_sha256": recipe_sha, "frozen_recipe_sha256": FROZEN_RECIPES,
            "predecessor": {"path": str(predecessor), "seal": V3_SEAL, "report_sha256": V3_REPORT_SHA, "files": before},
            "generated_material_source": {"path": str(raw_path), "sha256": RAW_SHA, "size": v1.RAW_SIZE},
            "output": {"path": str(output), "seal": v1.seal(hashes), "file_count": 22, "files": hashes},
            "changed_payload_paths": changed, "other20_payloads_byte_identical_v3": True, "assembly": assembly,
            "counter_replays": replay, "all_sources_v1_v2_v3_and_hl_recipe_unchanged": True,
            "v1_v2_payload_seals_before_after": [V1_SEAL, V2_SEAL],
            "source_hashes_before": source_before, "source_hashes_after": v1.inventory(args.source_root, (*names, *v1.CONTROLS)),
            "active_files_written": False, "runtime_launched": False, "art_approval": False, "test_updated": False,
            "storage_manifest": str(layout.manifest_path),
            "risks": ["Fresh actual populated Blackjack label readability and native/motion acceptance remain pending.",
                      "This changes only quiet material on the existing narrow collar; no alpha or geometry changes are implied."]}
        validate_layout(layout, extra_write_paths=(layout.evidence,))
        with report_path.open("x", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2)
            handle.write("\n")
        print(json.dumps({"status": report["status"], "package": str(output), "report": str(report_path), "art_approval": False}))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(json.dumps({"status": "GRAND_V4_ASSEMBLY_STOPPED", "error": str(error), "active_files_written": False,
                          "art_approval": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
