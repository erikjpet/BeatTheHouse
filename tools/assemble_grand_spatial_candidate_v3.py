"""V3 non-active floor quilt: remove the demonstrated old-table shadow frame.

CODE-ONLY recipe, executed by the parent under a fresh guarded E Job. V1/V2 and
all generated tables, pedestal contacts, masks, timings and geometry are pinned.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path

import assemble_grand_spatial_candidate as v1
import assemble_grand_spatial_candidate_v2 as v2
from bar_spatial_candidate_check import PNGImage, decode_png
from bth_qa_storage import validate_layout

V2_RECIPE_SHA = "25d12a1e2e9c43a44d5f170c91c23ab2955a00044c65c8e3d5ee2c995d88dd6f"
V2_SEAL = "006c07da034046c64544020f4a0662a4d43f42eefad843bd74e26c02fbc68524"
V2_BACKGROUND_SHA = "b7b5cdeac8acaec6bbe93a0e19fa6a7ba1eaa24cb1a1c3b0b6e681806a25e25c"
V2_REPORT = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GRANDTRIAL-20261116-assemble03/evidence/grand-spatial-r1-assembly-v2.json")
V2_REPORT_SHA = "c0fd02e38b460abc65987153fe29f023a97f12368cffa0f7e54dcdbe9d556d6f"
# Explicit traced frame, not a whole enlarged room rectangle. The inner strips
# include visibly defective old table-clear-fill boundaries, not only raw shadow.
DOMAINS = (
    {"id": "left", "x0": 158, "x1": 716, "side_bands": ((158, 164), (708, 716)),
     "bulk_strips": ((0, 152), (724, 1074))},
    {"id": "right", "x0": 1086, "x1": 1646, "side_bands": ((1086, 1092), (1636, 1646)),
     "bulk_strips": ((724, 1074), (1652, 1800))},
)
TOP, BOTTOM = 536, 602
BOTTOM_CUT_START = 598
SOURCE_SHADOW_AND_CLEAR_FILL = ((158, 536, 558, 66), (1086, 536, 560, 66))


def original_table(domain):
    return next(table for table in v1.TABLES if table["id"] == domain["id"])


def eligible(domain, x, y):
    if not (domain["x0"] <= x < domain["x1"] and TOP <= y < BOTTOM):
        return False
    if y >= 588:
        return True  # Explicitly approved shaded old bottom/return, through601.
    if any(lower <= x < upper for lower, upper in domain["side_bands"]):
        return True
    return v2.floor_pixel(original_table(domain), x, y)


def valid_original_floor(x, y):
    v1.require(0 <= x < 1800 and v1.HORIZON <= y < 604, "Donor outside original floor/before-inlay bounds")
    exclusions = [table["target"] for table in v1.TABLES] + list(SOURCE_SHADOW_AND_CLEAR_FILL)
    v1.require(not any(rx <= x < rx + width and ry <= y < ry + height for rx, ry, width, height in exclusions),
               "Donor entered an old table, shadow or table-clear-fill region")
    v1.require(not (688 <= x < 1112 and y >= 636), "Donor entered host")


def edge_donor(domain, x, y, left):
    distance = x - domain["x0"] if left else domain["x1"] - 1 - x
    if distance == 0:
        # Single boundary anchors are immediately outside the proven old frame;
        # bulk reflection excludes wider halos instead of repeating these pixels.
        dx = domain["x0"] - 1 if left else domain["x1"]
        kind = "left_adjacent_boundary" if left else "right_adjacent_boundary"
    else:
        lower, upper = domain["bulk_strips"][0 if left else 1]
        offset = v2.reflected(distance - 1, upper - lower)
        dx = upper - 1 - offset if left else lower + offset
        v1.require(lower <= dx < upper, "Reflected donor escaped clean strip")
        kind = "left_clean_same_row" if left else "right_clean_same_row"
    valid_original_floor(dx, y)
    return dx, y, kind


def lower_donor(x, y):
    v1.require(BOTTOM_CUT_START <= y < BOTTOM, "Bottom donor requested above bounded join")
    # Only the two unshadowed rows before the y604 inlay. The dynamic cut uses
    # these for at most three rows, never as a broad replacement floor stripe.
    dy = 602 + v2.reflected(601 - y, 2)
    valid_original_floor(x, dy)
    return x, dy, "bottom_original_602_603"


def vertical_cut(domain, original):
    middle = (domain["x0"] + domain["x1"]) // 2
    third = (domain["x1"] - domain["x0"]) // 3
    previous, parents = {}, []
    for y in range(TOP, BOTTOM):
        current, links = {}, {}
        for x in range(domain["x0"] + third, domain["x1"] - third):
            if eligible(domain, x - 1, y) and eligible(domain, x, y):
                lx, ly, _ = edge_donor(domain, x - 1, y, True)
                rx, ry, _ = edge_donor(domain, x, y, False)
                cost = v2.rgb_cost(v2.pixel(original, lx, ly), v2.pixel(original, rx, ry))
            else:
                cost = 0  # Protected pedestal traversable, never writable.
            local = cost * 1024 + abs(x - middle)
            if previous:
                prior = min((p for p in (x - 1, x, x + 1) if p in previous),
                            key=lambda p: (previous[p], abs(p - middle), p))
                current[x], links[x] = previous[prior] + local, prior
            else:
                current[x] = local
        previous = current
        parents.append(links)
    end = min(previous, key=lambda p: (previous[p], abs(p - middle), p))
    path = [end]
    for links in reversed(parents[1:]):
        path.append(links[path[-1]])
    path.reverse()
    return dict(zip(range(TOP, BOTTOM), path)), previous[end]


def bottom_cut(domain, original, first_image):
    previous, parents = {}, []
    for x in range(domain["x0"], domain["x1"]):
        candidates = (601,) if x in (domain["x0"], domain["x1"] - 1) else range(BOTTOM_CUT_START, 601)
        current, links = {}, {}
        for y in candidates:
            if eligible(domain, x, y) and eligible(domain, x, y + 1):
                bx, by, _ = lower_donor(x, y + 1)
                cost = v2.rgb_cost(v2.pixel(first_image, x, y), v2.pixel(original, bx, by))
            else:
                cost = 0
            local = cost * 1024 + (601 - y) * 16
            if previous:
                options = [p for p in (y - 1, y, y + 1) if p in previous]
                if not options:
                    continue
                prior = min(options, key=lambda p: (previous[p], -p))
                current[y], links[y] = previous[prior] + local, prior
            else:
                current[y] = local
        v1.require(current, "No connected bounded bottom seam")
        previous = current
        parents.append(links)
    path = [601]
    for links in reversed(parents[1:]):
        path.append(links[path[-1]])
    path.reverse()
    return dict(zip(range(domain["x0"], domain["x1"]), path)), previous[601]


def quilt(original, predecessor):
    pixels = bytearray(predecessor.rgba)
    allowed, donors, paths = set(), {}, []
    for domain in DOMAINS:
        seam, cost = vertical_cut(domain, original)
        for y in range(TOP, BOTTOM):
            for x in range(domain["x0"], domain["x1"]):
                if not eligible(domain, x, y):
                    continue
                allowed.add((x, y))
                dx, dy, kind = edge_donor(domain, x, y, x < seam[y])
                donors[x, y] = (dx, dy, kind)
                index = (y * 1800 + x) * 4
                pixels[index:index + 4] = v2.pixel(original, dx, dy)
        first = PNGImage(*v1.SIZE, bytes(pixels))
        bottom, bottom_cost = bottom_cut(domain, original, first)
        for y in range(BOTTOM_CUT_START, BOTTOM):
            for x in range(domain["x0"], domain["x1"]):
                if (x, y) in allowed and y > bottom[x]:
                    dx, dy, kind = lower_donor(x, y)
                    donors[x, y] = (dx, dy, kind)
                    index = (y * 1800 + x) * 4
                    pixels[index:index + 4] = v2.pixel(original, dx, dy)
        paths.append({"table": domain["id"], "vertical_y_x": sorted(seam.items()), "vertical_cost": cost,
                      "bottom_x_y": sorted(bottom.items()), "bottom_cost": bottom_cost})
    output = PNGImage(*v1.SIZE, bytes(pixels))
    changed, mask_runs = 0, []
    for y in range(860):
        run = None
        for x in range(1800):
            if v2.pixel(output, x, y) != v2.pixel(predecessor, x, y):
                v1.require((x, y) in allowed, "V3 escaped the approved floor/old-shadow mask")
                changed += 1
            # Original pixels outside the original table boxes plus revised
            # shadow/clear-fill union are an independent, full-canvas invariant.
            union = (x, y) in allowed or any(tx <= x < tx + width and ty <= y < ty + height
                                           for tx, ty, width, height in (t["target"] for t in v1.TABLES))
            if not union:
                v1.require(v2.pixel(output, x, y) == v2.pixel(original, x, y), "Original outside-union pixel changed")
            active = (x, y) in allowed
            if active and run is None:
                run = x
            elif not active and run is not None:
                mask_runs.append([y, run, x])
                run = None
        if run is not None:
            mask_runs.append([y, run, 1800])
    boundary = []
    for domain in DOMAINS:
        for side, x, outside in (("left", domain["x0"], domain["x0"] - 1),
                                  ("right", domain["x1"] - 1, domain["x1"])):
            rows = []
            for y in range(TOP, BOTTOM):
                if (x, y) in allowed:
                    expected = v2.pixel(original, outside, y)
                    after = v2.rgb_cost(v2.pixel(output, x, y), expected)
                    v1.require(after == 0, "Side edge is not exact adjacent original floor")
                    rows.append([y, v2.rgb_cost(v2.pixel(predecessor, x, y), expected), after])
            boundary.append({"table": domain["id"], "edge": side, "before_after_cost": rows})
        bottom = []
        for x in range(domain["x0"], domain["x1"]):
            expected = v2.pixel(original, x, 602)
            after = v2.rgb_cost(v2.pixel(output, x, 601), expected)
            if x not in (domain["x0"], domain["x1"] - 1):
                v1.require(after == 0, "Bottom interior is not exact original row602 continuation")
            bottom.append([x, v2.rgb_cost(v2.pixel(predecessor, x, 601), expected), after])
        boundary.append({"table": domain["id"], "edge": "bottom", "before_after_cost": bottom})
    return output, allowed, {"changed_pixels": changed, "eligible_pixels": len(allowed), "exact_mask_y_x0_x1": mask_runs,
        "domains": DOMAINS, "traced_scope": {"sides_y": [536, 600], "old_bottom_y": [588, 602],
            "right_end1646_reason": "Actual original right post occupies1642..1645; explicit parent approval extends initial example by2nativepx.",
            "old_clear_fill_provenance": "Prior recipe cleared162..711/1090..1641,y508..599; visible remnant boundaries are included by explicit parent approval, not mislabeled raw shadow.",
            "protected_original_rows": [602, 603, 604], "protected_generated_components": "Every non-floor V1/V2 table, apron, pedestal and tight foot-contact pixel."},
        "excluded_original_donor_regions": SOURCE_SHADOW_AND_CLEAR_FILL,
        "all_donor_coordinates_y_x_source_x_source_y_kind": [[y, x, *donors[x, y]] for x, y in sorted(donors, key=lambda p: (p[1], p[0]))],
        "donor_counts": dict(Counter(value[2] for value in donors.values())), "dynamic_seams": paths,
        "boundary_rgb_cost": boundary, "all_source_samples_copied_without_blending_recoloring": True,
        "two_corner_policy": "Retain exact side continuity; bottom corner residual costs are reported.",
        "outside_original_table_plus_revised_shadow_union_exact_original": True}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        layout = v1.load_layout()
        v1.require(v1.digest(v1.read(v1.__file__)) == v2.V1_RECIPE_SHA and v1.digest(v1.read(v2.__file__)) == V2_RECIPE_SHA,
                   "Immutable predecessor recipes changed")
        recipe_sha = v1.digest(v1.read(__file__))
        v1.require(v1.digest(v1.read(V2_REPORT)) == V2_REPORT_SHA, "Immutable V2 report changed")
        prior = json.loads(v1.read(V2_REPORT))
        job = json.loads(v1.read(V2_REPORT.parent / "job.json"))
        v1.require(job.get("exit_code") == 0 and job.get("active_at_release") == 0 and job.get("assigned_before_execution") and
                   not any(job.get(k) for k in ("error", "cleanup_errors", "timed_out", "log_error", "log_truncated")) and
                   job.get("limits", {}).get("cpu_rate") == 1200 and
                   job.get("limits", {}).get("job_memory_limit_bytes") == 2 * 1024 ** 3 and
                   job.get("storage_gate_before_job") and job.get("storage_gate_before_child"), "V2 Job is not closed guarded PASS/zero")
        sources, baseline = layout.workspace / "candidate_sources", layout.workspace / "source_baseline"
        predecessor = sources / "grand-spatial-r1-assembled-v2"
        output = sources / "grand-spatial-r1-assembled-v3"
        report_path = layout.evidence / "grand-spatial-r1-assembly-v3.json"
        validate_layout(layout, extra_write_paths=(sources, output, report_path))
        v1.require(not output.exists() and not report_path.exists(), "Fresh V3 output/report required; preserve all predecessors")
        v1.require(v1.read(sources / ".gdignore") == v1.IGNORE_BYTES, "Exact existing candidate ignore required")
        names = v1.package_names(json.loads(v1.read(predecessor / v1.MANIFEST)))
        before, originals = v1.inventory(predecessor, names), v1.inventory(baseline, names)
        v1_path = sources / "grand-spatial-r1-assembled-v1"
        v1_before = v1.inventory(v1_path, names)
        production = v1.inventory(args.source_root, (*names, *v1.CONTROLS))
        v1.require(v1.seal(before) == V2_SEAL and before == prior["output"]["files"] and
                   before[v1.BACKGROUND] == V2_BACKGROUND_SHA and v1.seal(originals) == v1.BASELINE_SEAL and
                   {name: production[name] for name in names} == originals and v1.seal(v1_before) == v2.V1_SEAL,
                   "Exact V1/V2/original/source seals required")
        original = decode_png(v1.read(baseline / v1.BACKGROUND))
        old = decode_png(v1.read(predecessor / v1.BACKGROUND))
        v1.require(v1.opaque(original, v1.SIZE) and v1.opaque(old, v1.SIZE), "Opaque native masters required")
        assembled, allowed, assembly = quilt(original, old)
        payload = {name: v1.read(predecessor / name) for name in names}
        payload[v1.BACKGROUND] = v1.encode_png(assembled)
        for art_id, rect in v1.COUNTER_RECTS.items():
            name = v1.ART + "counters/" + art_id + ".png"
            old_counter, new_counter = decode_png(payload[name]), v1.crop(assembled, rect)
            v1.require(old_counter == v1.crop(old, rect), "V2 replay not exact master crop")
            v2.assert_only_floor(old_counter, new_counter, rect[:2], allowed)
            if art_id != "grand_host_station":
                payload[name] = v1.encode_png(new_counter)
            v1.require(decode_png(payload[name]) == new_counter, "V3 replay not exact integrated crop")
        hashes = {name: v1.digest(payload[name]) for name in names}
        changed = sorted(name for name in names if hashes[name] != before[name])
        v1.require(set(changed) == {v1.BACKGROUND, v1.ART + "counters/grand_table_left.png",
                                  v1.ART + "counters/grand_table_right.png"}, "Only background and two floor recrops may change")
        def unchanged():
            return (v1.inventory(predecessor, names) == before and v1.inventory(baseline, names) == originals and
                    v1.inventory(v1_path, names) == v1_before and
                    v1.inventory(args.source_root, (*names, *v1.CONTROLS)) == production and
                    v1.digest(v1.read(v1.__file__)) == v2.V1_RECIPE_SHA and v1.digest(v1.read(v2.__file__)) == V2_RECIPE_SHA and
                    v1.digest(v1.read(__file__)) == recipe_sha and v1.digest(v1.read(V2_REPORT)) == V2_REPORT_SHA)
        v1.require(unchanged(), "Read-only predecessor/source custody changed before output")
        validate_layout(layout, extra_write_paths=(sources, output, report_path))
        output.mkdir()
        for name in names:
            target = output / name
            validate_layout(layout, extra_write_paths=(target.parent,))
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as handle:
                handle.write(payload[name])
        v1.require(v1.inventory(output, names) == hashes and unchanged(), "Output/source/predecessor custody differs")
        report = {"schema": "bth.grand_spatial_assembly/v3", "task_id": "BTH-ENV-SPATIAL-GRAND-001",
            "status": "NON_ACTIVE_V3_READY_FOR_INDEPENDENT_PIXEL_AUDIT", "observed_at": datetime.now(timezone.utc).isoformat(),
            "recipe_sha256": recipe_sha, "predecessor": {"path": str(predecessor), "seal": V2_SEAL,
                "recipe_sha256": V2_RECIPE_SHA, "report_sha256": V2_REPORT_SHA, "files": before},
            "output": {"path": str(output), "seal": v1.seal(hashes), "file_count": 22, "files": hashes},
            "changed_payload_paths": changed, "other19_payload_files_byte_identical": True, "assembly": assembly,
            "v1_payload_seal_before_after": v2.V1_SEAL,
            "all_sources_v1_v2_unchanged": True, "source_hashes_before": production,
            "source_hashes_after": v1.inventory(args.source_root, (*names, *v1.CONTROLS)),
            "all_replay_crops_exact": True, "active_files_written": False, "art_approval": False,
            "test_updated": False, "runtime_launched": False, "storage_manifest": str(layout.manifest_path),
            "risks": ["Mirrored grain and hard copied-pixel seams require independent actual-pixel review.",
                      "The two bottom corner residuals prioritize exact side continuity and are explicitly measured.",
                      "No populated/native/TEST acceptance is implied by assembly invariants."]}
        validate_layout(layout, extra_write_paths=(layout.evidence,))
        with report_path.open("x", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2)
            handle.write("\n")
        print(json.dumps({"status": report["status"], "package": str(output), "report": str(report_path), "art_approval": False}))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(json.dumps({"status": "GRAND_V3_ASSEMBLY_STOPPED", "error": str(error), "active_files_written": False,
                          "art_approval": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
