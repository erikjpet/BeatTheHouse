"""Private Crew V2: a bounded row-affine tabletop perspective correction.

Root executes this non-active worker under bth_qa_guarded_run. The rejected V1,
its source recipe and all evidence remain immutable. No children, painting,
color transforms, anchor edits, counters, source writes or activation.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import math
from pathlib import Path

import assemble_private_crew_spatial_candidate as v1
from bar_spatial_native_suite import qualified_job

require, read, sha = v1.require, v1.read, v1.sha
WORKSPACE = v1.WORKSPACE
PREDECESSOR = WORKSPACE / "candidate_sources/private-crew-spatial-r1-assembled-v1"
OUTPUT = WORKSPACE / "candidate_sources/private-crew-spatial-r1-assembled-v2"
EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-PRIVATETRIAL-20261116-assemble01/evidence")
PROOF = EVIDENCE / "private-crew-spatial-r1-assembly.json"
PIXELS = EVIDENCE / "private-crew-spatial-r1-pixel-provenance.json"
PROOF_SHA = "5586bb600f5e0947bdf9931be4f767286844c27f1e90d392234a80bf8b3f7b64"
PIXELS_SHA = "753068fdc7573943bcc9e5a4640cd0fcc1e300c74a00f1f5ede749b515206463"
JOB_SHA = "5373eb0e8172f8dddc90b62b1eedb4120ed08b30f2b74fbad6230324c72d0b56"
RECIPE_SHA = "fe1bbec18e2a35ad107890f89969e9e32da00a344a69fc609dd3b974920bfb29"
PACKAGE_SHA = "fbec404fc5c5577e4f5c421e4c287054dfc9e86ef222b2f2b62e768c8652711c"
BACKGROUND_SHA = "d35b56c23d411ee46c3648d761abe047b67c11549d8edef50309b875d40531ea"
BASELINE_SHA = "ce147a7e45f5252460d3a19dbe180b71ef0863fc9201097b8e3f9e20bd5ebb13"
# Native coordinates. Complete near-contact rim ends450; apron ends474.
# One affine X map per raw row retains actual source rail/felt proportions.
Y_TARGET = (302, 320, 440, 444, 450, 474)
TITLE_RECTS_BOARD = {
    "Velvet retained title": (536, 203, 584, 218),
    "Lucky recruitment retained title": (619, 196, 667, 211),
    "Knuckles retained title": (298.8, 329, 356.2, 344),
    "Silas retained title": (216, 329, 286, 344),
}
PROTECTED_FIXTURES_BOARD = {
    "jobboard": (42, 54, 212, 158), "NumbersDesk": (42, 168, 212, 236),
    "MAGS shelf": (680, 62, 834, 108), "RIG": (674, 142, 846, 224),
    "door": (790, 70, 870, 244),
}


def outer_geometry(ny):
    require(302 <= ny <= 450, "Outside V2 outer plane")
    fraction = (ny - 302) / 148
    return 504 - 64 * fraction, 1264 + 72 * fraction


def geometry(ny):
    sy = math.floor(v1.lerp_knots(tuple(zip(Y_TARGET, v1.Y_SOURCE)), ny))
    sol, sor = v1.lerp_knots(v1.TOP_LEFT, sy), v1.lerp_knots(v1.TOP_RIGHT, sy)
    ol, right = outer_geometry(ny)
    if 330 <= sy < 395:
        sfl, sfr = v1.lerp_knots(v1.FELT_LEFT, sy), v1.lerp_knots(v1.FELT_RIGHT, sy)
        fl = ol + (sfl - sol) * (right - ol) / (sor - sol)
        fr = ol + (sfr - sol) * (right - ol) / (sor - sol)
    else:
        fl = fr = None
    return sy, sol, sor, ol, fl, fr, right


def furniture(bx, by):
    nx, ny = bx * 2 + 1, by * 2 + 1
    if 302 <= ny < 450:
        sy, sol, sor, ol, fl, fr, right = geometry(ny)
        if ol <= nx < right:
            sx = v1.remap(nx, ol, right, sol, sor)
            if fl is None:
                kind = "rear_rail" if sy < 330 else "near_contact_rail"
            else:
                kind = "left_side_rail" if nx < fl else "felt" if nx < fr else "right_side_rail"
            return sx, sy, kind
    elif 450 <= ny < 474:
        sy = math.floor(v1.lerp_knots(tuple(zip(Y_TARGET, v1.Y_SOURCE)), ny))
        inset = max(0.0, (sy - 440) * .8)
        tl, tr = 448 + max(0, ny - 462) / 3, 1328 - max(0, ny - 462) / 3
        if tl <= nx < tr:
            return v1.remap(nx, tl, tr, 488 + inset, 1308 - inset), sy, "shallow_apron"
    return None


def geometry_regressions():
    """Numerical acceptance cases independent of any PNG/QA write."""
    far, near = outer_geometry(302), outer_geometry(450)
    require(far == (504, 1264) and near == (440, 1336), "Explicit perspective anchors changed")
    convergence = ((far[0] - near[0]) / 2, (near[1] - far[1]) / 2)
    require(min(convergence) >= 30 and (far[1] - far[0]) / (near[1] - near[0]) < .86,
            "Regressed toward the rejected upright plane")
    # Historical counterexample: V1's4/4 sides must fail the same criterion.
    require(not (min(4, 4) >= 30 and 364 / 372 < .86), "Upright counterexample was accepted")
    count = 0
    for by in range(151, 237):
        for bx in range(220, 668):
            old = v1.furniture(bx, by)
            if old is not None:
                require(furniture(bx, by) is not None, "New tabletop would leave an old V1 frame sliver")
                count += 1
    # No broad bounding box is painted; masks must exclude adjacent fixtures.
    for by in range(151, 237):
        for bx in range(220, 668):
            if furniture(bx, by) is not None:
                require(not any(x0 <= bx < x1 and y0 <= by < y1
                                for x0, y0, x1, y1 in PROTECTED_FIXTURES_BOARD.values()),
                        "New physical table reaches an original protected fixture")
    return {"far_board": [252, 151, 632, 151], "near_board": [220, 225, 668, 225],
            "left_right_convergence_board": convergence, "far_near_width_ratio": 760 / 896,
            "rejected_upright_counterexample_detected": True, "V1_top_apron_subset_board_pixels": count,
            "protected_fixture_intersections": 0, "NumbersDesk_gap_board": 8, "RIG_gap_board": 6}


def authenticate_inherited(original, predecessor, raw, old, document):
    require(document["schema"] == "bth.private_crew_pixel_provenance/v1" and
            document["all_native_donor_equalities_checked"] is True and
            document["outside_selected_union_original_exact"] is True, "Exact V1 pixel proof required")
    rows = document["rows"]
    require(len(rows) == 33229 and len(rows) * 4 == 132916, "Exact inherited V1 donor count required")
    trace = {}
    for x, y, source_id, sx, sy, kind in rows:
        require(isinstance(x, int) and isinstance(y, int) and x % 2 == y % 2 == 0 and
                0 <= x < 1800 and 0 <= y < 860 and source_id in (0, 1) and
                (x // 2, y // 2) not in trace, "Invalid/duplicate inherited NN2 donor")
        color = v1.pixel(raw if source_id == 0 else old, sx, sy)
        for dy in (0, 1):
            for dx in (0, 1):
                require(v1.pixel(predecessor, x + dx, y + dy) == color, "Inherited V1 donor mismatch")
        trace[(x // 2, y // 2)] = (source_id, sx, sy, kind)
    for by in range(430):
        for bx in range(900):
            if (bx, by) not in trace:
                for dy in (0, 1):
                    at = ((by * 2 + dy) * 1800 + bx * 2) * 4
                    require(predecessor.rgba[at:at + 8] == original.rgba[at:at + 8],
                            "Inherited V1 changed pixels outside its authenticated union")
    return trace


def assemble(original, predecessor, raw, old, inherited):
    pixels = bytearray(predecessor.rgba)
    trace = dict(inherited)
    mask, added, replaced = set(), set(), []
    for by in range(151, 237):
        for bx in range(220, 668):
            item = furniture(bx, by)
            if item is None:
                continue
            sx, sy, kind = item
            color = v1.pixel(raw, sx, sy)
            require(color[3] == 255, "Transparent generated table material")
            mask.add((bx, by))
            if (bx, by) not in inherited:
                added.add((bx, by))
            trace[(bx, by)] = (0, sx, sy, kind)
            replaced.append([bx * 2, by * 2, 0, sx, sy, kind])
            for dy in (0, 1):
                at = ((by * 2 + dy) * 1800 + bx * 2) * 4
                pixels[at:at + 8] = color * 2
    for key, value in inherited.items():
        if value[0] == 0 and key[1] < 237:
            require(key in mask, "Old V1 table pixels were not replaced by the V2 physical plane")
    image = v1.PNGImage(1800, 860, bytes(pixels))
    require(v1.opaque(image, v1.SIZE) and image.rgba[474 * 1800 * 4:] ==
            predecessor.rgba[474 * 1800 * 4:], "V1 supports/studs/floor from237board changed")
    changed_v1 = changed_original = 0
    for by in range(430):
        for bx in range(900):
            key = (bx, by)
            color = v1.pixel(image, bx * 2, by * 2)
            for dy in (0, 1):
                at = ((by * 2 + dy) * 1800 + bx * 2) * 4
                block = image.rgba[at:at + 8]
                require(block == color * 2, "Output lost NN2 block identity")
                if block != predecessor.rgba[at:at + 8]:
                    require(key in mask, "Changed V1 pixels escaped the new physical table")
                    changed_v1 += sum(block[i:i + 4] != predecessor.rgba[at + i:at + i + 4] for i in (0, 4))
                if block != original.rgba[at:at + 8]:
                    require(key in trace, "Changed original pixels escaped the declared inherited/new union")
                    changed_original += sum(block[i:i + 4] != original.rgba[at + i:at + i + 4] for i in (0, 4))
            if key in trace:
                source_id, sx, sy, _ = trace[key]
                require(color == v1.pixel(raw if source_id == 0 else old, sx, sy),
                        "Final combined pixel donor equality failed")
    union = bytearray(900 * 430)
    physical = bytearray(900 * 430)
    for bx, by in trace:
        union[by * 900 + bx] = 1
    for bx, by in mask:
        physical[by * 900 + bx] = 1
    components = {key: value[3] for key, value in trace.items()}
    return image, components, trace, replaced, {
        "changed_native_pixels_from_V1": changed_v1, "changed_native_pixels_from_original": changed_original,
        "new_physical_board_pixels": len(mask), "new_physical_board_runs": v1.runs(mask),
        "new_physical_board_mask_sha256": sha(physical),
        "explicit_original_union_addition_board_pixels": len(added),
        "explicit_original_union_addition_board_runs": v1.runs(added),
        "original_plus_V2_union_board_mask_sha256": sha(union),
        "union_encoding": "900x430 row-major bytes0/1",
        "new_component_board_counts": dict(Counter(components[key] for key in mask)),
        "V1_outside_new_physical_mask_exact": True, "original_outside_combined_union_exact": True,
        "V1_all_pixels_native_y474_onward_exact": True,
        "source_mapping": "Nearest-center NN2, same affine X map for complete raw silhouette on each remapped row",
        "Y_source": list(v1.Y_SOURCE), "Y_target": list(Y_TARGET),
        "source_TOP_LEFT": v1.TOP_LEFT, "source_TOP_RIGHT": v1.TOP_RIGHT,
        "source_FELT_LEFT": v1.FELT_LEFT, "source_FELT_RIGHT": v1.FELT_RIGHT,
        "no_invented_pixels_recolor_blending_floor_or_wall_donors": True,
    }


def poker_risk(components, raw, trace):
    image = v1.decode_png(read(v1.ACTUAL_BOARD))
    require(sha(read(v1.ACTUAL_BOARD)) == v1.ACTUAL_BOARD_SHA and
            (image.width, image.height) == v1.SIZE, "Exact actual populated Poker source required")
    palette, row_counts, material, contacts = Counter(), {}, Counter(), []
    minimum, minimum_point = float("inf"), None
    for y in range(338, 422):
        row_xs = []
        for x in range(542, 835):
            color = tuple(v1.pixel(image, x, y)[:3])
            if color not in ((18, 80, 58), (28, 138, 98)):
                continue
            row_xs.append(x)
            palette[color] += 1
            bx, by = x // 2, y // 2
            require(components.get((bx, by)) == "felt", "Actual Poker paint leaves the physical felt")
            _, _, _, _, left, right, _ = geometry(by * 2 + 1)
            margin = min(x + .5 - left, right - x - .5, y + .5 - 320, 440 - y - .5) / 2
            require(margin > 0, "Poker paint touches the outer rail")
            if margin < minimum:
                minimum, minimum_point = margin, [x, y]
            source_id, sx, sy, kind = trace[(bx, by)]
            require(source_id == 0 and kind == "felt", "Poker was supported by healed wall")
            red, green, blue, _ = v1.pixel(raw, sx, sy)
            if green >= 8 and green > red * 1.15 and green > blue * 1.05:
                material["green_or_dark_green_inset"] += 1
            else:
                material["inner_inlay_or_non_green_pixel"] += 1
                contacts.append([x, y, sx, sy])
        if row_xs:
            row_counts[y] = [len(row_xs), min(row_xs), max(row_xs) + 1]
    expected = {}
    for y0, y1, count in ((339, 350, 168), (350, 388, 208), (388, 414, 288),
                           (414, 418, 162), (418, 420, 288)):
        expected.update({y: [count, 544, 832] for y in range(y0, y1)})
    require(row_counts == expected and palette == {(18, 80, 58): 11512, (28, 138, 98): 6952},
            "Actual Poker row-specific painted support changed")
    # Independent row339 calculation: source340, projected left527.2035270460663,
    # actual first painted center544.5. Keep float precision, never PS-int rounding.
    require(abs(minimum - 8.648236476966872) < 1e-9 and minimum_point == [544, 339],
            "Measured V2 source-specific felt margin or limiting painted pixel changed")
    # A shortened felt edge at board209 clips576 genuine row418/419 paint pixels.
    shortened_clipped = sum(row[0] for y, row in row_counts.items() if y + .5 >= 418)
    require(shortened_clipped == 576, "Shortened-felt regression counterexample disappeared")
    return {"actual_board": str(v1.ACTUAL_BOARD), "sha256": v1.ACTUAL_BOARD_SHA,
            "actual_painted_texels": sum(palette.values()), "native_row_count_x0_x1_exclusive": row_counts,
            "painted_rgb_counts": {str(key): value for key, value in palette.items()},
            "all_actual_painted_surface_pixels_on_felt": True, "minimum_geometric_felt_margin_board": minimum,
            "minimum_margin_actual_native_pixel": minimum_point,
            "shortened_felt_209board_counterexample_clips_actual_paint": True,
            "shortened_felt_209board_clipped_actual_pixels": shortened_clipped,
            "mapped_source_material_counts": dict(material), "inner_inlay_contact_native_source_points": contacts,
            "candid_limit": "Source inset/brass contacts under live opaque paint remain explicit for actual review; no actor, card or game coordinate changes."}


def label_material_risk(image, predecessor, components, provenance):
    """Measure retained title envelopes AND real alpha, never claim visual GO."""
    results = {}
    for name, (x0, y0, x1, y1) in TITLE_RECTS_BOARD.items():
        counts, bright, changed = Counter(), Counter(), Counter()
        for y in range(math.floor(y0 * 2), math.ceil(y1 * 2)):
            for x in range(math.floor(x0 * 2), math.ceil(x1 * 2)):
                kind = components.get((x // 2, y // 2))
                if kind is None:
                    continue
                counts[kind] += 1
                color = v1.pixel(image, x, y)
                if max(color[:3]) >= 160:
                    bright[kind] += 1
                if color != v1.pixel(predecessor, x, y):
                    changed[kind] += 1
        results[name] = {"board_title_envelope_xyxy": [x0, y0, x1, y1],
            "envelope_underlay_native_counts": dict(counts), "envelope_underlay_maxRGB_ge160": dict(bright),
            "envelope_changed_underlay_from_V1": dict(changed),
            "scope": "Title envelope diagnostic, not an alpha mask or legibility approval"}
    actual = []
    for name, record in sorted(provenance["mask_evidence"].items()):
        mask = v1.decode_png(read(name))
        nonzero, changed, kind_counts, bright = 0, 0, Counter(), Counter()
        for y in range(302, 474):
            for x in range(440, 1336):
                alpha = mask.rgba[(y * 1800 + x) * 4 + 3]
                if not alpha:
                    continue
                kind = components.get((x // 2, y // 2))
                if kind is None:
                    continue
                nonzero += 1
                kind_counts[kind] += 1
                color = v1.pixel(image, x, y)
                if color != v1.pixel(predecessor, x, y):
                    changed += 1
                if max(color[:3]) >= 160:
                    bright[kind] += 1
        actual.append({"path": name, "id": record["object_id"], "kind": record["kind"],
            "actual_alpha_gt0_table_underlay_pixels": nonzero, "changed_underlay_from_V1_pixels": changed,
            "actual_alpha_gt0_underlay_by_component": dict(kind_counts),
            "actual_alpha_gt0_underlay_maxRGB_ge160": dict(bright)})
    return {"retained_title_envelopes": results, "all50_actual_masks_expanded_table_depth_underlay": actual,
            "object_body_adornment_label_anchors_unchanged": True,
            "depth_policy": "Background table stays behind actual actors/paint; zero counters. Feet alpha must not intersect supports. Historical overlap is measured, not erased.",
            "requires_fresh_populated_label_readability_review": True}


def sentinels():
    result = {}
    for directory in (WORKSPACE / "source_baseline", WORKSPACE / "candidate_sources"):
        path = directory / ".gdignore"
        data = read(path)
        require(data == v1.IGNORE, "Original quarantine sentinel changed")
        info = path.stat()
        result[str(path)] = {"sha256": sha(data), "bytes": len(data), "modified_ns": info.st_mtime_ns,
                             "file_id": info.st_ino, "ordinary_file": True, "written": False}
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        layout = v1.layout_from_environment()
        report_path = layout.evidence / "private-crew-spatial-r1-assembly-v2.json"
        pixel_path = layout.evidence / "private-crew-spatial-r1-pixel-provenance-v2.json"
        v1.validate_layout(layout, extra_write_paths=(OUTPUT, report_path, pixel_path))
        for path in (OUTPUT, report_path, pixel_path):
            v1.ordinary(path, exists=False)
            require(not path.exists(), "Fresh immutable V2 output required: " + str(path))
        source = v1.ordinary(args.source_root.absolute())
        require(v1.same(source, v1.SOURCE_ROOT), "Exact art worktree required")
        recipe_sha = sha(read(__file__))
        require(sha(read(v1.__file__)) == RECIPE_SHA and sha(read(PROOF)) == PROOF_SHA and
                sha(read(PIXELS)) == PIXELS_SHA and sha(read(EVIDENCE / "job.json")) == JOB_SHA,
                "Frozen V1 source/proof/pixel provenance/Job changed")
        proof, job = json.loads(read(PROOF)), json.loads(read(EVIDENCE / "job.json"))
        require(qualified_job(job) and proof["schema"] == "bth.private_crew_spatial_assembly/v1" and
                proof["recipe_sha256"] == RECIPE_SHA and Path(proof["output"]["path"]) == PREDECESSOR and
                proof["output"]["seal"] == PACKAGE_SHA and proof["baseline"]["payload10_with_index_seal"] == BASELINE_SHA,
                "Exact closed V1 predecessor required; its art remains rejected")
        expected, baseline_hashes = proof["output"]["files"], proof["baseline"]["files"]
        require(v1.seal(expected) == PACKAGE_SHA and v1.seal(baseline_hashes) == BASELINE_SHA and
                expected[v1.BACKGROUND] == BACKGROUND_SHA and len(expected) == 10 and
                set(expected) == set(baseline_hashes), "V1/baseline10 membership changed")
        manifest = json.loads(read(source / v1.MANIFEST))
        room_names = v1.package_names(manifest)
        names = tuple(sorted((*room_names, v1.INDEX)))
        require(set(names) == set(expected), "Exact nine room files plus index required")
        extras = set(v1.SOURCE_PINS) | set(v1.CONTROL_PINS)
        source_before = v1.inventory(source, set(names) | extras)
        require({name: source_before[name] for name in names} == baseline_hashes and
                v1.seal({name: source_before[name] for name in room_names}) == v1.ROOM_SEAL,
                "Read-only original source differs from V1 baseline")
        for name, value in {**v1.SOURCE_PINS, **v1.CONTROL_PINS}.items():
            require(source_before[name] == value, "Pinned source/control changed: " + name)
        before_aux = sentinels()
        baseline, sources = WORKSPACE / "source_baseline", WORKSPACE / "candidate_sources"
        preserved = {name: source_before[v1.SOURCE_DIR + "/" + name]
                     for name in ("private-crew-spatial-r1.png", "private-crew-spatial-r1.png.b64", "prompt.txt", "provenance.json")}
        source_tree_hashes = {**preserved, **{PREDECESSOR.name + "/" + name: value for name, value in expected.items()}}
        def exact_existing():
            v1.check_tree(PREDECESSOR, expected)
            v1.check_tree(baseline, baseline_hashes, sentinel=True)
            v1.check_tree(sources, source_tree_hashes, sentinel=True)
            require(sentinels() == before_aux, "Read-only sentinel custody changed")
        exact_existing()
        inputs = {str(v1.OLD_RAW): v1.OLD_RAW_SHA, str(v1.OLD_RECIPE): v1.OLD_RECIPE_SHA,
                  str(PROOF): PROOF_SHA, str(PIXELS): PIXELS_SHA, str(EVIDENCE / "job.json"): JOB_SHA,
                  str(v1.__file__): RECIPE_SHA, str(__file__): recipe_sha,
                  str(v1.decode_png.__code__.co_filename): source_before["tools/bar_spatial_candidate_check.py"],
                  str(v1.ACTUAL_BOARD): v1.ACTUAL_BOARD_SHA}
        provenance = json.loads(read(source / (v1.SOURCE_DIR + "/provenance.json")))
        inputs.update({name: row["sha256"] for name, row in provenance["retained_evidence"].items()})
        inputs.update({name: row["sha256"] for name, row in provenance["mask_evidence"].items()})
        def custody():
            require(v1.inventory(source, source_before) == source_before and
                    all(sha(read(name)) == value for name, value in inputs.items()), "Read-only source/evidence custody changed")
        custody()
        raw, original, predecessor = (v1.decode_png(read(source / v1.RAW_REL)),
            v1.decode_png(read(baseline / v1.BACKGROUND)), v1.decode_png(read(PREDECESSOR / v1.BACKGROUND)))
        old = v1.decode_png(read(v1.OLD_RAW))
        require(v1.opaque(raw, v1.RAW_SIZE) and v1.opaque(original, v1.SIZE) and
                v1.opaque(predecessor, v1.SIZE), "Exact opaque raw and native masters required")
        geometry_proof = geometry_regressions()
        inherited = authenticate_inherited(original, predecessor, raw, old, json.loads(read(PIXELS)))
        # Old material is used only to verify inherited, immutable donor rows.
        image, components, trace, new_rows, assembly = assemble(original, predecessor, raw, old, inherited)
        risks = v1.typed_risk(provenance, components)
        poker = poker_risk(components, raw, trace)
        label_risk = label_material_risk(image, predecessor, components, provenance)
        payload = {name: read(PREDECESSOR / name) for name in names}
        payload[v1.BACKGROUND] = v1.encode(image)
        hashes = {name: sha(data) for name, data in payload.items()}
        require([name for name in names if hashes[name] != expected[name]] == [v1.BACKGROUND] and
                [name for name in names if hashes[name] != baseline_hashes[name]] == [v1.BACKGROUND],
                "Only background PNG may change; all seven motions/full JSON/index exact")
        full_rows = [[bx * 2, by * 2, *value] for (bx, by), value in
                     sorted(trace.items(), key=lambda item: (item[0][1], item[0][0]))]
        pixel_report = {"schema": "bth.private_crew_pixel_provenance/v2",
            "row_fields": ["destination_x", "destination_y", "source_id", "source_x", "source_y", "component"],
            "destination_coordinates": "native top-left; each row expands to one2x2NN block",
            "source_ids": {"0": {"path": str(sources / "private-crew-spatial-r1.png"), "sha256": v1.SOURCE_PINS[v1.RAW_REL]},
                           "1": {"path": str(v1.OLD_RAW), "sha256": v1.OLD_RAW_SHA}},
            "inherited_pixel_proof_sha256": PIXELS_SHA, "rows": full_rows,
            "all_native_donor_equalities_checked": True, "outside_selected_union_original_exact": True}
        pixel_bytes = (json.dumps(pixel_report, separators=(",", ":")) + "\n").encode()
        custody()
        exact_existing()
        # FIRST QA WRITE, after full source, physical-tree, donor, actual paint,
        # alpha, explicit expansion and storage gates. No children are launched.
        v1.validate_layout(layout, extra_write_paths=(OUTPUT, report_path, pixel_path))
        OUTPUT.mkdir()
        for name in names:
            v1.write_fresh(OUTPUT / name, payload[name], layout)
        v1.write_fresh(pixel_path, pixel_bytes, layout)
        source_tree_hashes.update({OUTPUT.name + "/" + name: value for name, value in hashes.items()})
        exact_existing()
        v1.check_tree(OUTPUT, hashes)
        custody()
        report = {"schema": "bth.private_crew_spatial_assembly/v2", "task_id": "BTH-ENV-SPATIAL-PRIVATE-001",
            "status": "NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT",
            "observed_at": datetime.now(timezone.utc).isoformat(), "recipe_sha256": recipe_sha,
            "storage_manifest": str(layout.manifest_path), "room": v1.ROOM,
            "context": "small_underground_casino:back_room",
            "predecessor": {"path": str(PREDECESSOR), "seal": PACKAGE_SHA, "background_sha256": BACKGROUND_SHA,
                "recipe_sha256": RECIPE_SHA, "proof_sha256": PROOF_SHA, "pixel_proof_sha256": PIXELS_SHA,
                "closed_job_sha256": JOB_SHA, "immutable": True,
                "art_status": "NO_GO_UPRIGHT_TABLE_PERSPECTIVE"},
            "baseline": proof["baseline"],
            "output": {"path": str(OUTPUT), "seal": v1.seal(hashes), "files": hashes,
                       "file_count": 10, "room_file_count": 9, "index_byte_exact": True},
            "changed_payload_paths": [v1.BACKGROUND], "changed_payload_paths_from_V1": [v1.BACKGROUND],
            "geometry_regressions": geometry_proof, "assembly": assembly,
            "populated_painted_pixel_risk": risks, "actual_poker_surface": poker, "label_material_risk": label_risk,
            "pixel_provenance": {"path": str(pixel_path), "sha256": sha(pixel_bytes),
                                "rows": len(full_rows), "new_source_rows": len(new_rows), "native_donor_equalities": len(full_rows) * 4},
            "auxiliary_ignore_files_before": before_aux, "auxiliary_ignore_files_after": sentinels(),
            "source_hashes_before": source_before, "source_hashes_after": v1.inventory(source, source_before),
            "retained_input_hashes": inputs, "all_sources_unchanged": True,
            "source_original_outside_selected_union_exact": True,
            "zero_counters_and_replays": True, "native7_and_web_low_detail7_byte_exact": True,
            "full_manifest_and_index_byte_exact": True, "active_files_written": False,
            "runtime_launched": False, "art_approval": False, "test_updated": False,
            "risks": ["Strong trapezoid/raw-row rail proportions require actual integrated art review.",
                      "Historical50 typed-mask alpha/depth and18464Poker tests do not replace fresh Base/all5 lifecycle native review.",
                      "Lucky recruitment and Velvet title underlays are measured explicitly; fresh actual readability is still gated.",
                      "No Mags/C3, UI-earned lifecycle, save/revisit, Web, animated preview or TEST acceptance implied."]}
        v1.write_fresh(report_path, (json.dumps(report, indent=2) + "\n").encode(), layout)
        print(json.dumps({"status": report["status"], "package": str(OUTPUT), "report": str(report_path),
                          "pixel_provenance": str(pixel_path), "art_approval": False}))
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        print(json.dumps({"status": "PRIVATE_CREW_V2_ASSEMBLY_STOPPED", "error": str(error),
                          "active_files_written": False, "runtime_launched": False, "art_approval": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

