"""Read-only Bar candidate geometry/custody preflight; never approves artwork.

Run through bth_qa_guarded_run. The sole write is a new JSON report in its
already-prepared evidence directory. There are no image writes or child launches.
"""
import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys
import zlib

from bth_qa_storage import Layout, validate_layout


SCALE = 2
MASTER_SIZE = (1800, 860)
REPAIR_RECT = (598, 188, 224, 108)
COUNTER_RECT = (38, 178, 548, 56)
BASELINE_FELT = ((612, 200), (808, 200), (808, 248), (612, 248))
# Owner's requested native-pixel clearance around second path (1512,464),
# +/-24 horizontal and +/-12 vertical, expressed in fixed board units.
SECOND_BALL_CLEARANCE = (744, 226, 24, 12)
BALLS = {
    "pool_ball_0": {"texture": "anim/pool_ball_0.png", "rect": (630, 217, 25, 11)},
    "pool_ball_1": {"texture": "anim/pool_ball_1.png", "rect": (747, 228, 19, 9)},
}
ANIMATION_IDS = (
    "dive_sign", "cold_beer_sign", "pool_ball_0", "pool_ball_1", "high_smoke_0",
    "high_smoke_1", "warm_glint_0", "warm_glint_1", "warm_glint_2", "warm_glint_3",
    "floor_glint_0", "floor_glint_1", "floor_glint_2", "floor_glint_3",
    "floor_glint_4", "floor_glint_5", "floor_glint_6",
)
# Active R4 bytes observed before this bounded repair. A separate candidate PNG
# never substitutes for these files. The pins include all 15 animation textures.
ACTIVE_HASHES = {
    "data/art/environments/bar.json": "022aeb004597bdc8f1b9a82bbaa5c2ea98fb434f3a38a7c14947fedf0235d696",
    "data/art/environments/index.json": "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24",
    "assets/art/environments/bar/background.png": "22cc647f3766b0391ba6912836b933774d1872d9080425cf5f71e74384e7674f",
    "assets/art/environments/bar/counters/bar_main_counter.png": "200ff6c98adea5639b2554f12557ff87fd52021644ba1f7157e9c77fe73eda3f",
    "assets/art/environments/bar/anim/dive_sign.png": "8c82ead27b75b2a08c779db5ba333963e6953440cf409d3d757f959b6b7274a1",
    "assets/art/environments/bar/anim/cold_beer_sign.png": "82e0744d3494c5981e793ee704773ae2b2662a45e7600bb8452bb517652e8c20",
    "assets/art/environments/bar/anim/pool_ball_0.png": "f48b5633d19525d6cea237c55c866e33355245597ae823ba262079cad401fa80",
    "assets/art/environments/bar/anim/pool_ball_1.png": "8b249c5fb2bd7ad0d347573ab8e6cee8d38f4776af3db425a7e6890e61a0f098",
    "assets/art/environments/bar/anim/high_smoke_0.png": "727cd5cebc02502f04b42dd6fd3642be18f588c65223d176783589fe36313825",
    "assets/art/environments/bar/anim/high_smoke_1.png": "b7125a1b6db0e024e201e18c3ed9c759f5cbe482f3606160d8cc71b9873a8733",
    "assets/art/environments/bar/anim/warm_glint.png": "f53471c3653a5822eec093400c6834f935de9a9e516cda18acfecc111548e565",
    "assets/art/environments/bar/anim/timber_reflection.png": "8a55664beb9f1b3f8a3c30c79f8a1aa9f1d7929fd19c83810aeda8d9522c2ed8",
    "assets/art/environments/bar/anim/floor_glint_0.png": "3f1932fa38df27385553d892be4a4dfc0e174eb7a8fce69755cac608477bb80b",
    "assets/art/environments/bar/anim/floor_glint_1.png": "4ebb3f0fd68fee98491d16407244e8442398dfc931cf3aeb9a692d48b2199925",
    "assets/art/environments/bar/anim/floor_glint_2.png": "8cc559507bef8f371a3113e7da09008fc64a25d15562748a558029c078540163",
    "assets/art/environments/bar/anim/floor_glint_3.png": "8547d1531f117941aa1086a666399f09d3c8f47859fabadbdd20e405ae0e5e18",
    "assets/art/environments/bar/anim/floor_glint_4.png": "93d57144a6fda4f92463208f01bc984de04462c40b52467a120b99306d951736",
    "assets/art/environments/bar/anim/floor_glint_5.png": "5f8eb0ca001a59a0190763483548fa4b95f9e6d7ceb769ea81ad4a9cffd2f0fd",
    "assets/art/environments/bar/anim/floor_glint_6.png": "c0d147f35b9f3f687ae3c81a9b15abc9538420664b573ddb5839e7736adfe950",
    "data/environments/developer_placement_overrides.json": "c5c9808497ee3d4f056bb5a7f24a64524d4e59ee50e3fff106eb41e09383245f",
    "data/environments/placement_surfaces.json": "9caa123fb96816777328ad88f022fe05defb74ef5b4f645b7a15bcac67c25cf1",
    "scripts/ui/pixel_scene_canvas.gd": "c2ce2abee8827372d66fd6c9647a74e06f5db8fed520bbd812b8c7eb29f4af38",
    "scripts/ui/environment_art_renderer.gd": "900b44af05602f6259eed0a2cb33a45d1899cb30bd71aaaed5a744bcc9ccad96",
    "scripts/ui/environment_art_pack.gd": "067cf5f9673bd85705f4971e9c4db70aaafcfe1cec912b926ed9edc685fb5d8f",
    "scripts/ui/game_surface_canvas.gd": "4e5ff7920f2e031e5d0c1d1bdca908fac3da4f5391c4bc19af2298c8fcbbcbac",
}


@dataclass(frozen=True)
class PNGImage:
    width: int
    height: int
    rgba: bytes

    def __post_init__(self):
        if self.width <= 0 or self.height <= 0 or len(self.rgba) != self.width * self.height * 4:
            raise ValueError("Invalid decoded RGBA dimensions")


def _paeth(left, up, upper_left):
    prediction = left + up - upper_left
    distances = (abs(prediction - left), abs(prediction - up), abs(prediction - upper_left))
    return (left, up, upper_left)[distances.index(min(distances))]


def decode_png(data):
    """Decode 8-bit, non-interlaced RGB/RGBA PNG bytes; check chunk CRCs."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Invalid PNG signature")
    offset, header, compressed, ended, transparent_rgb = 8, None, bytearray(), False, None
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("Truncated PNG chunk")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError("Truncated PNG payload")
        payload = data[offset + 8:offset + 8 + length]
        crc = struct.unpack_from(">I", data, offset + 8 + length)[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError("PNG CRC mismatch: " + kind.decode("ascii", errors="replace"))
        if header is None and kind != b"IHDR":
            raise ValueError("PNG IHDR must be first")
        if kind == b"IHDR":
            if header is not None or length != 13:
                raise ValueError("Invalid PNG IHDR")
            header = struct.unpack(">IIBBBBB", payload)
            width, height, depth, color, compression, filtering, interlace = header
            if not (0 < width <= 16384 and 0 < height <= 16384 and width * height <= 16_777_216):
                raise ValueError("PNG dimensions exceed analysis limit")
            if depth != 8 or color not in (2, 6) or compression or filtering or interlace:
                raise ValueError("Only 8-bit non-interlaced RGB/RGBA PNGs are supported")
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"tRNS":
            if header[3] != 2 or length != 6 or transparent_rgb is not None:
                raise ValueError("Invalid RGB PNG transparency")
            transparent_rgb = struct.unpack(">HHH", payload)
        elif kind == b"IEND":
            if length or end != len(data):
                raise ValueError("Invalid PNG IEND/trailing data")
            ended = True
            break
        elif kind not in (b"PLTE",) and not (kind[0] & 32):
            raise ValueError("Unsupported critical PNG chunk")
        offset = end
    if not ended or not compressed:
        raise ValueError("PNG missing image data/IEND")
    width, height, _, color, _, _, _ = header
    bpp = 3 if color == 2 else 4
    stride = width * bpp
    expected = (stride + 1) * height
    try:
        inflater = zlib.decompressobj()
        raw = inflater.decompress(bytes(compressed), expected + 1)
    except zlib.error as exc:
        raise ValueError("Invalid PNG deflate stream") from exc
    if len(raw) != expected or not inflater.eof or inflater.unused_data or inflater.unconsumed_tail:
        raise ValueError("PNG inflated byte count/stream mismatch")
    output = bytearray(width * height * 4)
    prior = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        if filter_type > 4:
            raise ValueError("Unsupported PNG scanline filter")
        row = bytearray(raw[start + 1:start + stride + 1])
        if filter_type:
            for x in range(stride):
                left = row[x - bpp] if x >= bpp else 0
                up = prior[x]
                upper_left = prior[x - bpp] if x >= bpp else 0
                if filter_type == 1:
                    predictor = left
                elif filter_type == 2:
                    predictor = up
                elif filter_type == 3:
                    predictor = (left + up) // 2
                else:
                    predictor = _paeth(left, up, upper_left)
                row[x] = (row[x] + predictor) & 255
        if bpp == 4:
            output[y * width * 4:(y + 1) * width * 4] = row
        else:
            for x in range(width):
                src, dst = x * bpp, (y * width + x) * 4
                rgb = row[src:src + 3]
                output[dst:dst + 4] = rgb + bytes((0 if tuple(rgb) == transparent_rgb else 255,))
        prior = row
    return PNGImage(width, height, bytes(output))


def _runs(image, predicate):
    """All matching pixels, represented losslessly as [y,x0,x1_exclusive] runs."""
    result = []
    for y in range(image.height):
        start = None
        for x in range(image.width):
            matched = predicate(x, y, (y * image.width + x) * 4)
            if matched and start is None:
                start = x
            if start is not None and (not matched or x == image.width - 1):
                result.append([y, start, x if not matched else x + 1])
                start = None
    return result


def check_master(image, expected_size=MASTER_SIZE):
    alpha = image.rgba[3::4]
    runs = ([] if alpha.count(255) == len(alpha) else
            _runs(image, lambda _x, _y, i: image.rgba[i + 3] != 255))
    count = sum(end - start for _y, start, end in runs)
    return {"ok": (image.width, image.height) == tuple(expected_size) and count == 0,
            "size": [image.width, image.height], "expected_size": list(expected_size),
            "nonopaque_pixel_count": count, "nonopaque_runs": runs}


def check_changed_region(reference, candidate, board_rect=REPAIR_RECT, scale=SCALE):
    if (reference.width, reference.height) != (candidate.width, candidate.height):
        return {"ok": False, "error": "Candidate/reference dimensions differ"}
    x0, y0, width, height = board_rect
    left, top, right, bottom = x0 * scale, y0 * scale, (x0 + width) * scale, (y0 + height) * scale
    changed, runs = 0, []
    for y in range(reference.height):
        row_start = y * reference.width * 4
        row_end = row_start + reference.width * 4
        if reference.rgba[row_start:row_end] == candidate.rgba[row_start:row_end]:
            continue
        run_start = None
        for x in range(reference.width):
            index = row_start + x * 4
            differs = reference.rgba[index:index + 4] != candidate.rgba[index:index + 4]
            changed += int(differs)
            outside = differs and not (left <= x < right and top <= y < bottom)
            if outside and run_start is None:
                run_start = x
            if run_start is not None and (not outside or x == reference.width - 1):
                runs.append([y, run_start, x if not outside else x + 1])
                run_start = None
    count = sum(end - start for _y, start, end in runs)
    return {"ok": count == 0, "changed_pixel_count": changed,
            "outside_region_changed_pixel_count": count,
            "outside_region_changed_runs": runs, "allowed_board_rect": list(board_rect),
            "allowed_native_rect": [left, top, right - left, bottom - top]}


def _cross(a, b, point):
    return (b[0] - a[0]) * (point[1] - a[1]) - (b[1] - a[1]) * (point[0] - a[0])


def _on_segment(point, a, b):
    return (abs(_cross(a, b, point)) <= 1e-9 and
            min(a[0], b[0]) - 1e-9 <= point[0] <= max(a[0], b[0]) + 1e-9 and
            min(a[1], b[1]) - 1e-9 <= point[1] <= max(a[1], b[1]) + 1e-9)


def normalize_polygon(value):
    if not isinstance(value, (list, tuple)):
        raise ValueError("Felt polygon must be an array of board vertices")
    points = []
    for point in value:
        if (not isinstance(point, (list, tuple)) or len(point) != 2 or
                any(isinstance(n, bool) or not isinstance(n, (int, float)) or not math.isfinite(n) for n in point)):
            raise ValueError("Felt polygon vertices must contain two finite numbers")
        points.append(tuple(float(n) for n in point))
    if len(points) > 1 and points[0] == points[-1]:
        points.pop()
    if not 3 <= len(points) <= 64 or len(set(points)) != len(points):
        raise ValueError("Felt polygon needs 3..64 distinct vertices")
    if any(not (0 <= x <= 900 and 0 <= y <= 430) for x, y in points):
        raise ValueError("Felt polygon vertices must lie on the 900x430 board")
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(points, points[1:] + points[:1]))
    if abs(area) < 1e-9:
        raise ValueError("Felt polygon has zero area")
    edges = list(zip(points, points[1:] + points[:1]))
    for i, (a, b) in enumerate(edges):
        for j, (c, d) in enumerate(edges):
            if j <= i or j == i + 1 or (i == 0 and j == len(edges) - 1):
                continue
            crosses = (_cross(a, b, c) * _cross(a, b, d) < 0 and
                       _cross(c, d, a) * _cross(c, d, b) < 0)
            if crosses or any((_on_segment(c, a, b), _on_segment(d, a, b),
                               _on_segment(a, c, d), _on_segment(b, c, d))):
                raise ValueError("Felt polygon self-intersects")
    return tuple(points)


def point_in_polygon(point, polygon):
    inside = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if _on_segment(point, a, b):
            return True
        if (a[1] > point[1]) != (b[1] > point[1]):
            crossing_x = (b[0] - a[0]) * (point[1] - a[1]) / (b[1] - a[1]) + a[0]
            if point[0] < crossing_x:
                inside = not inside
    return inside


def _segment_enters_open_box(a, b, box):
    lo, hi = 0.0, 1.0
    for axis, lower, upper in ((0, box[0], box[2]), (1, box[1], box[3])):
        lower, upper = lower + 1e-9, upper - 1e-9
        delta = b[axis] - a[axis]
        if abs(delta) < 1e-12:
            if not lower < a[axis] < upper:
                return False
        else:
            first, last = sorted(((lower - a[axis]) / delta, (upper - a[axis]) / delta))
            lo, hi = max(lo, first), min(hi, last)
            if lo >= hi:
                return False
    return lo < hi


def pixel_in_polygon(left, top, size, polygon):
    """Require the complete mapped texel square, including antialiased edges."""
    right, bottom = left + size, top + size
    if not all(point_in_polygon(p, polygon) for p in
               ((left, top), (right, top), (right, bottom), (left, bottom))):
        return False
    # A concave notch can cross a texel while leaving all four corners inside.
    return not any(_segment_enters_open_box(a, b, (left, top, right, bottom))
                   for a, b in zip(polygon, polygon[1:] + polygon[:1]))


def check_ball_atlas(atlas, rect, felt_polygon, frames=48, scale=SCALE):
    polygon = normalize_polygon(felt_polygon)
    frame_width, frame_height = rect[2] * scale, rect[3] * scale
    if (atlas.width, atlas.height) != (frame_width * frames, frame_height):
        raise ValueError("Ball atlas does not match its fixed horizontal frame strip")
    failures, counts = [], []
    for frame in range(frames):
        count = 0
        for y in range(frame_height):
            for x in range(frame_width):
                atlas_x = frame * frame_width + x
                alpha = atlas.rgba[(y * atlas.width + atlas_x) * 4 + 3]
                if alpha == 0:
                    continue
                count += 1
                left, top = rect[0] + x / scale, rect[1] + y / scale
                if not pixel_in_polygon(left, top, 1 / scale, polygon):
                    failures.append({"frame": frame, "atlas_pixel": [atlas_x, y],
                                     "frame_pixel": [x, y], "alpha": alpha,
                                     "board_pixel_rect": [left, top, 1 / scale, 1 / scale],
                                     "board_center": [left + .5 / scale, top + .5 / scale]})
        counts.append(count)
    empty = [frame for frame, count in enumerate(counts) if not count]
    return {"ok": not failures and not empty, "frames": frames,
            "frame_native_size": [frame_width, frame_height], "fixed_board_rect": list(rect),
            "nonzero_alpha_pixel_counts": counts, "checked_pixel_count": sum(counts),
            "empty_frames": empty, "failing_pixel_count": len(failures), "failures": failures,
            "containment_rule": "Every nonzero-alpha texel's complete mapped square lies in declared felt."}


def check_required_clearance(felt_polygon):
    polygon = normalize_polygon(felt_polygon)
    left, top, width, height = SECOND_BALL_CLEARANCE
    failures = []
    for y in range(height * SCALE):
        for x in range(width * SCALE):
            px, py = left + x / SCALE, top + y / SCALE
            if not pixel_in_polygon(px, py, 1 / SCALE, polygon):
                failures.append([px, py, 1 / SCALE, 1 / SCALE])
    return {"ok": not failures, "board_rect": list(SECOND_BALL_CLEARANCE),
            "native_center": [1512, 464], "native_half_clearance": [24, 12],
            "failing_native_pixel_count": len(failures), "failures": failures}


def check_counter_crop(master, counter, board_rect=COUNTER_RECT, scale=SCALE):
    x, y, width, height = (n * scale for n in board_rect)
    if ((counter.width, counter.height) != (width, height) or
            x + width > master.width or y + height > master.height):
        return {"ok": False, "error": "Counter/master crop dimensions differ"}
    mismatches = []
    for row in range(height):
        source_start = ((y + row) * master.width + x) * 4
        expected = master.rgba[source_start:source_start + width * 4]
        actual = counter.rgba[row * width * 4:(row + 1) * width * 4]
        for column in range(width):
            i = column * 4
            if actual[i:i + 4] != expected[i:i + 4]:
                mismatches.append([column, row])
    return {"ok": not mismatches and all(a == 255 for a in counter.rgba[3::4]),
            "size": [counter.width, counter.height], "board_rect": list(board_rect),
            "mismatch_count": len(mismatches), "mismatch_pixels": mismatches,
            "opaque": all(a == 255 for a in counter.rgba[3::4])}


def source_inventory(root):
    paths = set(ACTIVE_HASHES)
    for directory, suffixes in (("scripts", {".gd", ".gdshader"}), ("scenes", {".tscn"}),
                                ("data", {".json"})):
        paths.update(p.relative_to(root).as_posix() for p in (root / directory).rglob("*")
                     if p.is_file() and p.suffix in suffixes)
    paths.update(("project.godot", "export_presets.cfg"))
    result = {}
    for name in sorted(paths):
        path = (root / name).resolve(strict=True)
        if not path.is_relative_to(root):
            raise ValueError("Source inventory path escaped source root: " + name)
        result[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def validate_candidate(source_root, candidate=None, felt_polygon=None):
    """Read source/candidate files and return evidence without creating files."""
    root = Path(source_root).resolve(strict=True)
    if candidate is not None and felt_polygon is None:
        raise ValueError("A candidate requires its own declared --felt-polygon")
    polygon = normalize_polygon(BASELINE_FELT if felt_polygon is None else felt_polygon)
    before = source_inventory(root)
    mismatches = [{"path": path, "expected": expected, "observed": before.get(path)}
                  for path, expected in ACTIVE_HASHES.items() if before.get(path) != expected]
    art_root = root / "assets/art/environments/bar"
    master = decode_png((art_root / "background.png").read_bytes())
    candidate_path = None if candidate is None else Path(candidate).resolve(strict=True)
    candidate_bytes = None if candidate_path is None else candidate_path.read_bytes()
    inspected = master if candidate_bytes is None else decode_png(candidate_bytes)
    spec = json.loads((root / "data/art/environments/bar.json").read_text(encoding="utf-8-sig"))
    animations = spec.get("animations", [])
    manifest_ok = (spec.get("schema") == "bth.environment_art/v1" and
                   spec.get("environment_id") == "bar" and spec.get("board_size") == [900, 430] and
                   spec.get("pixel_scale") == SCALE and
                   tuple(entry.get("id") for entry in animations) == ANIMATION_IDS)
    entries = {entry.get("id"): entry for entry in animations}
    ball_checks = {}
    for name, fixed in BALLS.items():
        entry = entries.get(name, {})
        manifest_ok = manifest_ok and (entry.get("type") == "frames" and entry.get("frames") == 48 and
                                       entry.get("rect") == list(fixed["rect"]) and
                                       entry.get("texture") == fixed["texture"])
        atlas = decode_png((art_root / fixed["texture"]).read_bytes())
        ball_checks[name] = check_ball_atlas(atlas, fixed["rect"], polygon)
    counter = decode_png((art_root / "counters/bar_main_counter.png").read_bytes())
    checks = {"active_master": check_master(master), "candidate_master": check_master(inspected),
              "bounded_difference": check_changed_region(master, inspected),
              "counter_matches_active_master": check_counter_crop(master, counter),
              "counter_matches_candidate_master": check_counter_crop(inspected, counter),
              "requested_second_ball_clearance": check_required_clearance(polygon),
              "balls": ball_checks, "manifest_17_entries": {"ok": manifest_ok,
                  "count": len(animations), "ids": [entry.get("id") for entry in animations]},
              "active_custody": {"ok": not mismatches, "pinned_file_count": len(ACTIVE_HASHES),
                                  "mismatches": mismatches}}
    after = source_inventory(root)
    changed = [name for name in sorted(set(before) | set(after)) if before.get(name) != after.get(name)]
    findings = [{"check": key, "code": "CHECK_FAILED"} for key, value in checks.items()
                if key != "balls" and not value["ok"]]
    findings += [{"check": "balls." + name, "code": "BALL_PIXELS_OUTSIDE_DECLARED_FELT_OR_EMPTY"}
                 for name, value in ball_checks.items() if not value["ok"]]
    if changed:
        findings.append({"check": "source_inventory", "code": "SOURCE_CHANGED_DURING_CHECK", "paths": changed})
    mode = "baseline_preparation" if candidate is None else "candidate_preflight"
    return {"schema": "bth.bar_spatial_candidate/v1", "task_id": "BTH-ENV-SPATIAL-BAR-001",
            "observed_at": datetime.now(timezone.utc).isoformat(), "mode": mode,
            "status": mode.upper() + ("_PASS" if not findings else "_FAIL"),
            "source_root": str(root), "candidate": None if candidate_path is None else str(candidate_path),
            "candidate_sha256": None if candidate_bytes is None else hashlib.sha256(candidate_bytes).hexdigest(),
            "declared_felt_polygon": polygon, "checks": checks, "findings": findings,
            "source_inventory": {"scope": "Scripts, shaders, scenes, data JSON, project/export pins and active Bar payloads; no saves/profiles.",
                                 "sha256_before": before, "unchanged_after": not changed, "changed_paths": changed},
            "art_approval": False, "active_files_written": False,
            "limits": ["Machine geometry/custody preflight only; no approval to activate artwork.",
                       "An independent auditor must verify the declared polygon matches actual painted felt.",
                       "No furniture support, label contrast, scenario, animation/liveness, Reduce Motion or TEST/Web acceptance.",
                       "Before/after source inventory is not full historical source parity; only named files are baseline-pinned."]}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--felt-polygon", help="JSON array of visible felt vertices in board coordinates")
    args = parser.parse_args(argv)
    try:
        evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
        manifest = json.loads((evidence / "storage-manifest.json").read_text(encoding="utf-8"))
        layout = Layout(**{key: Path(value) for key, value in manifest["paths"].items()},
                        **{key: manifest[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
        output = evidence / "bar-candidate-check.json"
        admission = validate_layout(layout, extra_write_paths=(output,))
    except (OSError, ValueError, KeyError, RuntimeError) as exc:
        print(json.dumps({"status": "STORAGE_REJECTED_NO_REPORT", "error": str(exc)}), file=sys.stderr)
        return 2
    try:
        polygon = None if args.felt_polygon is None else json.loads(args.felt_polygon)
        report = validate_candidate(args.source_root, args.candidate, polygon)
    except (OSError, ValueError, KeyError) as exc:
        report = {"schema": "bth.bar_spatial_candidate/v1", "status": "INPUT_OR_ANALYSIS_FAILED",
                  "mode": "baseline_preparation" if args.candidate is None else "candidate_preflight",
                  "error": str(exc), "art_approval": False, "active_files_written": False}
    report["storage_manifest"] = str(layout.manifest_path)
    report["storage_admission"] = admission
    validate_layout(layout, extra_write_paths=(output,))
    with output.open("x", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(json.dumps({"status": report["status"], "report": str(output), "art_approval": False}))
    return 0 if report["status"].endswith("_PASS") else 1


if __name__ == "__main__":
    raise SystemExit(main())
