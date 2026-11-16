"""Non-active V2: quilt only V1's exposed floor from adjoining original floor.

Run as one worker under bth_qa_guarded_run. V1 recipe/output remain immutable.
No blending, recoloring, generation, production writes or child launches.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path

import assemble_grand_spatial_candidate as v1
from bar_spatial_candidate_check import PNGImage, decode_png
from bth_qa_storage import validate_layout

V1_RECIPE_SHA = "b65b8239901c198f715df7b70da94e6dc1b3af8082aef5e7dac878530e9a24ba"
V1_SEAL = "f566676578505fcf25809e491ed686fa0a0a21139c77276bf49c64f87205c6ea"
V1_BACKGROUND_SHA = "072bc8842c6d6d6a0a6f5945112901174d1d070922d851d0e664ab024a6d02b6"
V1_REPORT = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GRANDTRIAL-20261116-assemble02/evidence/grand-spatial-r1-assembly.json")
V1_REPORT_SHA = "0d8385a8c0e688eb248a112565b6d1dacbd145de05dfe8f48754d67ed6615695"
STRIPS = {"left": ((0, 164), (708, 1092)), "right": ((708, 1092), (1636, 1800))}
BOTTOM_START = 572
BOTTOM_END = 588


def pixel(image, x, y):
    index = (y * image.width + x) * 4
    return image.rgba[index:index + 4]


def reflected(distance, length):
    v1.require(distance >= 0 and length > 0, "Invalid reflected donor distance")
    position = distance % (length * 2)
    return position if position < length else length * 2 - 1 - position


def floor_pixel(table, x, y):
    tx, ty, width, height = table["target"]
    if not (tx <= x < tx + width and max(ty, v1.HORIZON) <= y < ty + height):
        return False
    sx0, sx1 = table["source_x"]
    sx = min(sx1 - 1, int(sx0 + (x - tx + .5) * (sx1 - sx0) / width))
    return v1.table_component(table, sx, v1.source_y(y)) is None


def valid_floor_donor(x, y):
    v1.require(0 <= x < 1800 and v1.HORIZON <= y < 604, "Floor donor outside original floor/before-inlay bounds")
    v1.require(not any(tx <= x < tx + width and ty <= y < ty + height
                      for tx, ty, width, height in (table["target"] for table in v1.TABLES)),
               "Donor entered an old table footprint")
    v1.require(not (688 <= x < 1112 and y >= 636), "Donor entered host station")


def side_donor(table, x, y, side):
    tx, _, width, _ = table["target"]
    lower, upper = STRIPS[table["id"]][0 if side == "left" else 1]
    distance = x - tx if side == "left" else tx + width - 1 - x
    offset = reflected(distance, upper - lower)
    donor_x = upper - 1 - offset if side == "left" else lower + offset
    valid_floor_donor(donor_x, y)
    return donor_x, y


def bottom_donor(x, y):
    v1.require(BOTTOM_START <= y < BOTTOM_END, "Bottom donor outside last16 rows")
    donor_y = 588 + (587 - y)
    valid_floor_donor(x, donor_y)
    return x, donor_y


def rgb_cost(left, right):
    return sum(abs(left[index] - right[index]) for index in range(3))


def vertical_seam(table, original):
    tx, _, width, _ = table["target"]
    ys = range(v1.HORIZON, BOTTOM_END)
    candidates = range(tx + width // 3, tx + 2 * width // 3)
    middle = tx + width // 2
    previous, parents = {}, []
    for y in ys:
        current, links = {}, {}
        for x in candidates:
            # Protected table/pedestal is traversable zero-write space, allowing
            # one connected seam across the disconnected visible floor regions.
            if floor_pixel(table, x - 1, y) and floor_pixel(table, x, y):
                lx, ly = side_donor(table, x - 1, y, "left")
                rx, ry = side_donor(table, x, y, "right")
                cost = rgb_cost(pixel(original, lx, ly), pixel(original, rx, ry))
            else:
                cost = 0
            local = cost * 1024 + abs(x - middle)
            if previous:
                choices = [prior for prior in (x - 1, x, x + 1) if prior in previous]
                prior = min(choices, key=lambda value: (previous[value], abs(value - middle), value))
                current[x], links[x] = previous[prior] + local, prior
            else:
                current[x] = local
        parents.append(links)
        previous = current
    end = min(previous, key=lambda value: (previous[value], abs(value - middle), value))
    path = [end]
    for links in reversed(parents[1:]):
        path.append(links[path[-1]])
    path.reverse()
    return {y: x for y, x in zip(ys, path)}, previous[end]


def horizontal_seam(table, original, first_image):
    tx, _, width, _ = table["target"]
    previous, parents = {}, []
    for x in range(tx, tx + width):
        # At the two outside corners side continuity wins; every interior bottom
        # pixel must use the original row588 donor. This avoids a full bottom
        # rectangle seam without pretending both different corner colors equal.
        candidates = (587,) if x in (tx, tx + width - 1) else range(BOTTOM_START, 587)
        current, links = {}, {}
        for y in candidates:
            if floor_pixel(table, x, y) and floor_pixel(table, x, y + 1):
                bx, by = bottom_donor(x, y + 1)
                cost = rgb_cost(pixel(first_image, x, y), pixel(original, bx, by))
            else:
                cost = 0
            local = cost * 1024 + abs(y - 579)
            if previous:
                choices = [prior for prior in (y - 1, y, y + 1) if prior in previous]
                if not choices:
                    continue
                prior = min(choices, key=lambda value: (previous[value], abs(value - 579), value))
                current[y], links[y] = previous[prior] + local, prior
            else:
                current[y] = local
        v1.require(current, "No bounded connected bottom quilt seam")
        parents.append(links)
        previous = current
    path = [587]
    for links in reversed(parents[1:]):
        path.append(links[path[-1]])
    path.reverse()
    return {x: y for x, y in zip(range(tx, tx + width), path)}, previous[587]


def quilt_floor(original, predecessor):
    pixels = bytearray(predecessor.rgba)
    donors, seams, all_floor = {}, [], set()
    for table in v1.TABLES:
        tx, _, width, _ = table["target"]
        seam, vertical_cost = vertical_seam(table, original)
        for y in range(v1.HORIZON, BOTTOM_END):
            for x in range(tx, tx + width):
                if not floor_pixel(table, x, y):
                    continue
                all_floor.add((x, y))
                kind = "left_edge_same_row" if x < seam[y] else "right_edge_same_row"
                dx, dy = side_donor(table, x, y, "left" if x < seam[y] else "right")
                donors[x, y] = (dx, dy, kind)
                index = (y * 1800 + x) * 4
                pixels[index:index + 4] = pixel(original, dx, dy)
        first_image = PNGImage(*v1.SIZE, bytes(pixels))
        bottom_path, bottom_cost = horizontal_seam(table, original, first_image)
        for y in range(BOTTOM_START, BOTTOM_END):
            for x in range(tx, tx + width):
                if (x, y) in all_floor and y > bottom_path[x]:
                    dx, dy = bottom_donor(x, y)
                    donors[x, y] = (dx, dy, "bottom_original_same_x")
                    index = (y * 1800 + x) * 4
                    pixels[index:index + 4] = pixel(original, dx, dy)
        seams.append({"table": table["id"], "vertical_path_y_x": sorted(seam.items()), "vertical_cost": vertical_cost,
                      "bottom_path_x_y": sorted(bottom_path.items()), "bottom_cost": bottom_cost})
    output = PNGImage(*v1.SIZE, bytes(pixels))
    changed, boundary = 0, []
    for y in range(860):
        for x in range(1800):
            if pixel(output, x, y) != pixel(predecessor, x, y):
                v1.require((x, y) in all_floor, "V2 changed a protected V1 pixel")
                changed += 1
    for table in v1.TABLES:
        tx, _, width, _ = table["target"]
        for side, x, outside in (("left", tx, tx - 1), ("right", tx + width - 1, tx + width)):
            rows = []
            for y in range(v1.HORIZON, BOTTOM_END):
                if (x, y) not in all_floor:
                    continue
                expected = pixel(original, outside, y)
                after = rgb_cost(pixel(output, x, y), expected)
                v1.require(after == 0, "Side boundary failed exact adjacent-edge RGB continuation")
                rows.append([y, rgb_cost(pixel(predecessor, x, y), expected), after])
            boundary.append({"table": table["id"], "edge": side, "y_before_after_cost": rows})
        bottom = []
        for x in range(tx, tx + width):
            if (x, 587) not in all_floor:
                continue
            expected = pixel(original, x, 588)
            after = rgb_cost(pixel(output, x, 587), expected)
            if x not in (tx, tx + width - 1):
                v1.require(after == 0, "Interior bottom edge failed exact original row588 continuation")
            bottom.append([x, rgb_cost(pixel(predecessor, x, 587), expected), after])
        boundary.append({"table": table["id"], "edge": "bottom", "x_before_after_cost": bottom,
                         "corner_policy": "Two corner pixels retain exact side-edge donors; measured bottom cost is reported."})
    counts = Counter(value[2] for value in donors.values())
    proof = {"changed_pixels": changed, "eligible_floor_pixels": len(all_floor), "donor_counts": dict(counts),
             "protected_table_pedestal_contact_wall_pixels_identical_v1": True, "seams": seams, "boundary_rgb_cost": boundary,
             "all_donor_coordinates_y_x_source_x_source_y_kind": [[y, x, *donors[x, y]] for x, y in sorted(donors, key=lambda p: (p[1], p[0]))],
             "side_strips_half_open": STRIPS, "same_row_side_donors": True,
             "bottom_donor_rule": "Last16rows only: source(x,588+(587-y));588..603 before604inlay, host starts636.",
             "no_blending_recoloring_filtering_or_generated_floor": True}
    return output, all_floor, proof


def assert_only_floor(old, new, origin, allowed):
    v1.require((old.width, old.height) == (new.width, new.height), "Image dimensions changed")
    ox, oy = origin
    for y in range(old.height):
        for x in range(old.width):
            if pixel(old, x, y) != pixel(new, x, y):
                v1.require((x + ox, y + oy) in allowed, "Replay changed a protected V1 pixel")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        layout = v1.load_layout()
        v1.require(v1.digest(v1.read(v1.__file__)) == V1_RECIPE_SHA, "Executed V1 recipe must remain exact b65")
        recipe_sha = v1.digest(v1.read(__file__))
        v1.require(v1.digest(v1.read(V1_REPORT)) == V1_REPORT_SHA, "Immutable V1 report differs")
        report_v1 = json.loads(v1.read(V1_REPORT))
        v1.require(report_v1["recipe_sha256"] == V1_RECIPE_SHA and report_v1["output"]["seal"] == V1_SEAL, "V1 provenance differs")
        job = json.loads(v1.read(V1_REPORT.parent / "job.json"))
        v1.require(job.get("exit_code") == 0 and job.get("active_at_release") == 0 and job.get("assigned_before_execution") and
                   not any(job.get(key) for key in ("error", "cleanup_errors", "timed_out", "log_error", "log_truncated")) and
                   job.get("limits", {}).get("cpu_rate") == 1200 and
                   job.get("limits", {}).get("job_memory_limit_bytes") == 2 * 1024 ** 3 and
                   job.get("storage_gate_before_job") and job.get("storage_gate_before_child"),
                   "Predecessor guarded Job is not closed PASS/zero")
        sources = layout.workspace / "candidate_sources"
        predecessor = sources / "grand-spatial-r1-assembled-v1"
        baseline = layout.workspace / "source_baseline"
        output = sources / "grand-spatial-r1-assembled-v2"
        report_path = layout.evidence / "grand-spatial-r1-assembly-v2.json"
        validate_layout(layout, extra_write_paths=(sources, output, report_path))
        v1.require(not output.exists() and not report_path.exists(), "Fresh V2 output/report required; preserve all predecessors")
        v1.require(v1.read(sources / ".gdignore") == v1.IGNORE_BYTES, "Exact existing non-active ignore required")
        manifest = json.loads(v1.read(predecessor / v1.MANIFEST))
        names = v1.package_names(manifest)
        before = v1.inventory(predecessor, names)
        baseline_before = v1.inventory(baseline, names)
        production_before = v1.inventory(args.source_root, (*names, *v1.CONTROLS))
        v1.require(v1.seal(before) == V1_SEAL and before == report_v1["output"]["files"] and
                   before[v1.BACKGROUND] == V1_BACKGROUND_SHA and v1.seal(baseline_before) == v1.BASELINE_SEAL and
                   {name: production_before[name] for name in names} == baseline_before,
                   "Exact V1/original package seals required")
        original = decode_png(v1.read(baseline / v1.BACKGROUND))
        old = decode_png(v1.read(predecessor / v1.BACKGROUND))
        v1.require(v1.opaque(original, v1.SIZE) and v1.opaque(old, v1.SIZE), "Opaque native masters required")
        quilted, allowed, quilt = quilt_floor(original, old)
        payload = {name: v1.read(predecessor / name) for name in names}
        payload[v1.BACKGROUND] = v1.encode_png(quilted)
        for art_id, rect in v1.COUNTER_RECTS.items():
            name = v1.ART + "counters/" + art_id + ".png"
            counter_old = decode_png(payload[name])
            v1.require(counter_old == v1.crop(old, rect), "V1 counter differs from V1 master")
            counter_new = v1.crop(quilted, rect)
            assert_only_floor(counter_old, counter_new, rect[:2], allowed)
            if art_id != "grand_host_station":
                payload[name] = v1.encode_png(counter_new)
            v1.require(decode_png(payload[name]) == counter_new, "V2 replay is not exact new-master crop")
        hashes = {name: v1.digest(payload[name]) for name in names}
        changed = sorted(name for name in names if hashes[name] != before[name])
        v1.require(set(changed) == {v1.BACKGROUND, v1.ART + "counters/grand_table_left.png",
                                  v1.ART + "counters/grand_table_right.png"}, "Only master and two replay floor pixels may change")
        def unchanged():
            return (v1.inventory(predecessor, names) == before and v1.inventory(baseline, names) == baseline_before and
                    v1.inventory(args.source_root, (*names, *v1.CONTROLS)) == production_before and
                    v1.digest(v1.read(v1.__file__)) == V1_RECIPE_SHA and v1.digest(v1.read(__file__)) == recipe_sha and
                    v1.digest(v1.read(V1_REPORT)) == V1_REPORT_SHA)
        v1.require(unchanged(), "Read-only source/V1 custody changed before output")
        validate_layout(layout, extra_write_paths=(sources, output, report_path))
        output.mkdir()
        for name in names:
            target = output / name
            validate_layout(layout, extra_write_paths=(target.parent,))
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as handle:
                handle.write(payload[name])
        v1.require(v1.inventory(output, names) == hashes and unchanged(), "Output/source/V1 custody differs")
        report = {"schema": "bth.grand_spatial_assembly/v2", "task_id": "BTH-ENV-SPATIAL-GRAND-001",
            "status": "NON_ACTIVE_V2_READY_FOR_INDEPENDENT_PIXEL_AUDIT", "observed_at": datetime.now(timezone.utc).isoformat(),
            "recipe_sha256": recipe_sha, "predecessor": {"path": str(predecessor), "seal": V1_SEAL,
                "recipe_sha256": V1_RECIPE_SHA, "report_sha256": V1_REPORT_SHA, "files": before},
            "output": {"path": str(output), "seal": v1.seal(hashes), "file_count": 22, "files": hashes},
            "changed_payload_paths": changed, "other_19_files_byte_identical_v1": True, "quilt": quilt,
            "all_replay_crops_exact": True, "all_sources_and_v1_unchanged": True,
            "source_hashes_before": production_before, "source_hashes_after": v1.inventory(args.source_root, (*names, *v1.CONTROLS)),
            "active_files_written": False, "art_approval": False, "test_updated": False, "runtime_launched": False,
            "storage_manifest": str(layout.manifest_path),
            "risks": ["Mirrored texture can reverse grain; numerical RGB seam costs do not establish visual acceptance.",
                      "Both corner pixels prioritize the vertical edge; their remaining bottom costs are reported.",
                      "Independent actual-pixel review and populated/native QA remain required."]}
        validate_layout(layout, extra_write_paths=(layout.evidence,))
        with report_path.open("x", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2)
            handle.write("\n")
        print(json.dumps({"status": report["status"], "package": str(output), "report": str(report_path), "art_approval": False}))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(json.dumps({"status": "GRAND_V2_ASSEMBLY_STOPPED", "error": str(error), "active_files_written": False,
                          "art_approval": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
