"""Guarded non-active GBR V2: remove only two traced old rail/post remnants.

V1 remains immutable and visually rejected. This worker copies 200 original
same-row floor pixels into the independently traced detached nubs; it never
generates art, extends furniture, changes colors, launches children or activates
anything. Run only through the parent's admitted capped E: worker.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path, PurePosixPath
import stat

import assemble_grand_back_room_spatial_candidate as v1
from bar_spatial_native_suite import qualified_job

WORKSPACE = v1.WORKSPACE
PREDECESSOR = WORKSPACE / "candidate_sources/grand-back-room-spatial-r1-assembled-v1"
OUTPUT = WORKSPACE / "candidate_sources/grand-back-room-spatial-r1-assembled-v2"
PREDECESSOR_EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GBRTRIAL-20261116-assemble01/evidence")
PROOF_PATH = PREDECESSOR_EVIDENCE / "grand-back-room-spatial-r1-assembly.json"
PROOF_SHA = "a1d3e98397eba9a9c33119aa5f9103f58dc948abb6f4f57aa5ce1e45599eb206"
JOB_SHA = "49417b4f3dbf2515eaf778411131219d4190eee44b6ad7a3edeaa82107e40c7c"
RECIPE_SHA = "2dc30990563c5881b9b7546e306cbf1479867e20275ffee8d4cc342a94156ac3"
PACKAGE_SHA = "15d88d5b7438aaebad295dcf6d0748a0a04cf64b3f3f08193be35e1f002b9f04"
BACKGROUND_SHA = "6e2d5531f378339da91ee269ae2c0c70f4f013e608b28c190fd5df48a5dd2fb9"
PATCHES = ((708, 504, 4, 20), (1636, 504, 6, 20))
require, sha, read = v1.require, v1.sha, v1.read


def exact_package(root, expected, allow_ignore=False):
    """Read every physical path; admit only the declared payload and sentinel."""
    allowed_dirs = {parent.as_posix() for name in expected for parent in PurePosixPath(name).parents
                    if parent.as_posix() != "."}
    wanted = {**expected, **({".gdignore": sha(v1.IGNORE)} if allow_ignore else {})}
    files, directories = {}, set()
    for item in sorted(root.rglob("*")):
        # v1.read authenticates every ancestor of each regular file. Explicitly
        # inspect directories too, including empty/unexpected dot directories.
        info = item.lstat()
        require(not (getattr(info, "st_file_attributes", 0) & 0x400) and not stat.S_ISLNK(info.st_mode),
                "Reparse package path: " + str(item))
        name = item.relative_to(root).as_posix()
        if stat.S_ISDIR(info.st_mode):
            require(name in allowed_dirs, "Unexpected package directory: " + name)
            directories.add(name)
        else:
            require(stat.S_ISREG(info.st_mode) and name in wanted, "Unexpected package file: " + name)
            files[name] = sha(read(item))
    require(files == wanted and directories == allowed_dirs, "Exact physical package membership/hash differs: " + str(root))
    if allow_ignore:
        require(read(root / ".gdignore") == v1.IGNORE, "Original baseline sentinel changed")


def ignore_inputs():
    result = {}
    for directory in (WORKSPACE / "source_baseline", WORKSPACE / "candidate_sources"):
        path = directory / ".gdignore"
        data = read(path)
        require(data == v1.IGNORE, "Original quarantine sentinel changed: " + str(path))
        info = path.stat()
        result[str(path)] = {"sha256": sha(data), "bytes": len(data), "modified_ns": info.st_mtime_ns,
                             "ordinary_file": True, "access": "read-only", "written": False}
    return result


def remove_old_nubs(original, predecessor):
    require(v1.opaque(original, v1.SIZE) and v1.opaque(predecessor, v1.SIZE), "Exact opaque native masters required")
    pixels = bytearray(predecessor.rgba)
    allowed, donors, joins = set(), [], []
    for x0, y0, width, height in PATCHES:
        for y in range(y0, y0 + height):
            # The immediately adjoining outer column is already genuine floor.
            x = x0 + width
            donor = v1.pixel(original, x % 128, y)
            require(v1.pixel(original, x, y) == donor and v1.pixel(predecessor, x, y) == donor,
                    "Traced nub outer boundary is not existing same-row floor")
            joins.append([x, y, x % 128, y, "outer_existing_floor"])
            for x in range(x0, x0 + width):
                donor = v1.pixel(original, x % 128, y)
                require(v1.pixel(predecessor, x, y) == v1.pixel(original, x, y) and
                        v1.pixel(original, x, y) != donor,
                        "Traced remnant is not exact retained original table/post paint")
                require(all(not (rx <= x < rx + rw and ry <= y < ry + rh)
                            for rx, ry, rw, rh in v1.COUNTERS.values()), "Repair entered a replay foreground")
                require(0 <= x % 128 < 128 and 492 <= y < 602, "Donor escaped original clean floor before inlay")
                at = (y * 1800 + x) * 4
                pixels[at:at + 4] = donor
                allowed.add((x, y))
                donors.append([x, y, x % 128, y, list(v1.pixel(original, x, y)), list(donor)])
        # Own-source row500..503 and V1's repaired row524 bound each nub;
        # no additional pixel is changed to join the old and new floor.
        for x in range(x0, x0 + width):
            for y in (*range(500, 504), 524):
                donor = v1.pixel(original, x % 128, y)
                require(v1.pixel(predecessor, x, y) == donor and
                        (y == 524 or v1.pixel(original, x, y) == donor),
                        "Traced nub top/bottom boundary is not existing same-row floor")
                joins.append([x, y, x % 128, y, "top_original_or_bottom_V1_floor"])
    image = v1.PNGImage(1800, 860, bytes(pixels))
    changed = {(index % 1800, index // 1800) for index in range(1800 * 860)
               if image.rgba[index * 4:index * 4 + 4] != predecessor.rgba[index * 4:index * 4 + 4]}
    require(changed == allowed and len(changed) == 200, "V2 must change exactly the 200 traced remnant texels")
    require(image.rgba[602 * 1800 * 4:] == original.rgba[602 * 1800 * 4:], "Global inlay602+ changed")
    return image, {"relative_to": "immutable V1 master", "native_patch_rects": PATCHES,
        "changed_pixels": 200, "allowed_native_pixels": [list(point) for point in sorted(allowed, key=lambda p: (p[1], p[0]))],
        "pixel_donors_target_x_y_source_x_y_originalRGBA_donorRGBA": donors,
        "unchanged_floor_join_checks": joins, "source_floor_donor_rule": "original native same-y x%128",
        "floor_provenance": "Own preserved GBR ff4058 wrapper/5139 base recipe and V1 exact588..593 floor checks",
        "scope_reason": "Independently traced old rail endcaps and attached dark posts; warm60 subset lies inside full200 remnant",
        "independent_trace_reviewer": "/root/audit_spatial_handoff", "original_inlay_rows602_onward_exact": True,
        "all_generated_table_apron_leg_contact_pixels_unchanged_from_V1": True,
        "outside_two_traced_rectangles_exact_V1": True, "no_color_transform_blending_or_generated_floor": True}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        layout = v1.layout_from_environment()
        report_path = layout.evidence / "grand-back-room-spatial-r1-assembly-v2.json"
        v1.validate_layout(layout, extra_write_paths=(OUTPUT, report_path))
        require(not OUTPUT.exists() and not report_path.exists(), "Fresh immutable V2 output/report required")
        source = args.source_root.absolute()
        require(source == Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers"), "Exact read-only art worktree required")
        recipe_sha, predecessor_recipe_sha = sha(read(__file__)), sha(read(v1.__file__))
        decoder_sha = sha(read(v1.decode_png.__code__.co_filename))
        require(predecessor_recipe_sha == RECIPE_SHA and sha(read(PROOF_PATH)) == PROOF_SHA and
                sha(read(PREDECESSOR_EVIDENCE / "job.json")) == JOB_SHA, "Frozen V1 recipe/proof/Job changed")
        proof, job = json.loads(read(PROOF_PATH)), json.loads(read(PREDECESSOR_EVIDENCE / "job.json"))
        require(qualified_job(job) and proof["recipe_sha256"] == RECIPE_SHA and
                Path(proof["output"]["path"]) == PREDECESSOR and proof["output"]["file_count"] == 21 and
                proof["output"]["seal"] == PACKAGE_SHA, "Exact closed V1 predecessor required")
        expected, baseline_hashes = proof["output"]["files"], proof["baseline"]["files"]
        require(v1.seal(expected) == PACKAGE_SHA and v1.seal(baseline_hashes) == v1.BASELINE_SEAL and
                set(expected) == set(baseline_hashes) and expected[v1.BACKGROUND] == BACKGROUND_SHA,
                "Predecessor logical21/source-baseline identity changed")
        baseline = WORKSPACE / "source_baseline"
        exact_package(PREDECESSOR, expected)
        exact_package(baseline, baseline_hashes, allow_ignore=True)
        auxiliary_before = ignore_inputs()
        names = tuple(sorted(expected))
        extras = (*v1.CONTROLS, v1.RAW_REL, v1.RAW_REL + ".b64", v1.SOURCE_DIR + "/provenance.json",
                  v1.SOURCE_DIR + "/prompt.txt", "docs/art/briefs/grand_back_room_spatial_repair_20261116.md")
        source_before = v1.inventory(source, (*names, *extras))
        require({name: source_before[name] for name in names} == baseline_hashes and
                source_before[v1.RAW_REL] == v1.RAW_SHA and sha(read(v1.OLD_RECIPE)) == v1.OLD_RECIPE_SHA and
                sha(read(v1.INHERITED_RECIPE)) == v1.INHERITED_RECIPE_SHA, "Read-only original source/floor provenance changed")
        preserved_names = ("grand-back-room-spatial-r1.png", "grand-back-room-spatial-r1.png.b64", "prompt.txt", "provenance.json")
        preserved_root = WORKSPACE / "candidate_sources"
        preserved_before = v1.inventory(preserved_root, preserved_names)
        require(preserved_before == {name: source_before[v1.SOURCE_DIR + "/" + name] for name in preserved_names},
                "Preserved raw PNG/base64/prompt/provenance differs from exact read-only source")
        payload = {name: read(PREDECESSOR / name) for name in names}
        manifest = json.loads(payload[v1.MANIFEST])
        require(v1.package_names(manifest) == names, "V1 logical21/motion membership differs")
        original = v1.decode_png(read(baseline / v1.BACKGROUND))
        predecessor = v1.decode_png(payload[v1.BACKGROUND])
        image, assembly = remove_old_nubs(original, predecessor)
        payload[v1.BACKGROUND] = v1.encode(image)
        for art_id, rect in v1.COUNTERS.items():
            path = v1.ART + "counters/" + art_id + ".png"
            cut = v1.crop(image, rect)
            require(v1.opaque(cut, rect[2:]) and v1.decode_png(payload[path]) == cut and
                    cut == v1.crop(predecessor, rect), "Unchanged replay is not exact V2 master crop")
        hashes = {name: sha(payload[name]) for name in names}
        require([name for name in names if hashes[name] != expected[name]] == [v1.BACKGROUND], "Only master PNG may change from V1")
        require(v1.inventory(source, (*names, *extras)) == source_before and ignore_inputs() == auxiliary_before,
                "Read-only source/quarantine custody changed during preflight")
        require(v1.inventory(preserved_root, preserved_names) == preserved_before and
                sha(read(__file__)) == recipe_sha and sha(read(v1.__file__)) == RECIPE_SHA and
                sha(read(v1.decode_png.__code__.co_filename)) == decoder_sha and sha(read(PROOF_PATH)) == PROOF_SHA and
                sha(read(PREDECESSOR_EVIDENCE / "job.json")) == JOB_SHA,
                "Frozen source/recipe/decoder/proof/Job changed before first write")
        exact_package(PREDECESSOR, expected)
        exact_package(baseline, baseline_hashes, allow_ignore=True)
        # FIRST QA WRITE: only after exact predecessor, mask, floor joins,
        # source, counter, auxiliary and storage preflight have all passed.
        v1.validate_layout(layout, extra_write_paths=(OUTPUT, report_path))
        OUTPUT.mkdir()
        for name in names:
            v1.write_fresh(OUTPUT / name, payload[name], layout)
        exact_package(OUTPUT, hashes)
        exact_package(PREDECESSOR, expected)
        exact_package(baseline, baseline_hashes, allow_ignore=True)
        require(v1.inventory(source, (*names, *extras)) == source_before and ignore_inputs() == auxiliary_before and
                sha(read(__file__)) == recipe_sha and sha(read(v1.__file__)) == RECIPE_SHA and
                sha(read(v1.decode_png.__code__.co_filename)) == decoder_sha and sha(read(PROOF_PATH)) == PROOF_SHA and
                sha(read(PREDECESSOR_EVIDENCE / "job.json")) == JOB_SHA and
                sha(read(v1.OLD_RECIPE)) == v1.OLD_RECIPE_SHA and sha(read(v1.INHERITED_RECIPE)) == v1.INHERITED_RECIPE_SHA and
                v1.inventory(preserved_root, preserved_names) == preserved_before,
                "Immutable predecessor/output/source/recipe custody changed")
        report = {"schema": "bth.grand_back_room_spatial_assembly/v2", "task_id": "BTH-ENV-SPATIAL-GBR-001",
            "status": "NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT", "observed_at": datetime.now(timezone.utc).isoformat(),
            "recipe_sha256": recipe_sha, "decoder_sha256": decoder_sha, "raw_source": proof["raw_source"],
            "predecessor": {"path": str(PREDECESSOR), "seal": PACKAGE_SHA, "master_sha256": BACKGROUND_SHA,
                "recipe_sha256": RECIPE_SHA, "proof_path": str(PROOF_PATH), "proof_sha256": PROOF_SHA,
                "closed_assembly_job_sha256": JOB_SHA, "art_status": "STATIC_NO_GO_OLD_RAIL_NUBS_RETAINED", "immutable": True},
            "baseline": {"path": str(baseline), "seal": v1.BASELINE_SEAL, "file_count": 21, "files": baseline_hashes},
            "output": {"path": str(OUTPUT), "seal": v1.seal(hashes), "file_count": 21, "files": hashes},
            "changed_payload_paths_from_V1": [v1.BACKGROUND],
            "changed_payload_paths": [name for name in names if hashes[name] != baseline_hashes[name]],
            "assembly": assembly, "inherited_motion_mask_proof": {"proof_sha256": PROOF_SHA, "motion_masks": proof["motion_masks"]},
            "motion_manifest_and_all16_animation_PNGs_byte_identical_V1": True,
            "counter_crops_exact_opaque": v1.COUNTERS, "counter_PNGs_byte_identical_V1": True,
            "auxiliary_ignore_sentinels": list(auxiliary_before), "ignore_sentinels_excluded_from_logical_21_file_payload": True,
            "auxiliary_ignore_files_before": auxiliary_before, "auxiliary_ignore_files_after": ignore_inputs(),
            "preserved_raw_artifacts_before": preserved_before,
            "preserved_raw_artifacts_after": v1.inventory(preserved_root, preserved_names),
            "source_hashes_before": source_before, "source_hashes_after": v1.inventory(source, (*names, *extras)),
            "all_sources_unchanged": True, "source_original_outside_V1_union_plus200_exact": True,
            "old_floor_recipe_sha256": v1.OLD_RECIPE_SHA, "inherited_floor_recipe_sha256": v1.INHERITED_RECIPE_SHA,
            "storage_manifest": str(layout.manifest_path), "active_files_written": False, "runtime_launched": False,
            "art_approval": False, "test_updated": False,
            "risks": ["Resulting integrated pixels and populated Base contacts still need independent review.",
                      "Inherited mask color/motion, native16/7, Reduce Motion, liveness, animation and TEST delivery remain gated."]}
        v1.write_fresh(report_path, (json.dumps(report, indent=2) + "\n").encode(), layout)
        print(json.dumps({"status": report["status"], "package": str(OUTPUT), "report": str(report_path), "art_approval": False}))
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        print(json.dumps({"status": "GRAND_BACK_ROOM_V2_ASSEMBLY_STOPPED", "error": str(error),
                          "active_files_written": False, "art_approval": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
