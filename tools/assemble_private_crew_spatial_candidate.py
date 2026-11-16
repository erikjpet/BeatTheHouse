"""Guarded non-active Private Crew planning-table assembly.

CODE-ONLY preparation: root runs this later through bth_qa_guarded_run in the
exact admitted E: campaign. No children, active art, profiles, saves or Git.
All source, geometry, historical mask and pixel-custody checks precede writes.
Flattened-image halo cleanup is explicitly a bounded contrast inference, not
a recovered semantic alpha mask or an art approval.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import base64
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import stat
import struct
import zlib

from bar_spatial_candidate_check import PNGImage, decode_png
from bth_qa_storage import Layout, validate_layout

ROOM = "punchline_back_room"
SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-PRIVATETRIAL-20261116")
ART = "assets/art/environments/" + ROOM + "/"
BACKGROUND = ART + "background.png"
MANIFEST = "data/art/environments/" + ROOM + ".json"
INDEX = "data/art/environments/index.json"
SOURCE_DIR = "review_artifacts/environment_art_sources/private-crew-spatial-r1"
RAW_REL = SOURCE_DIR + "/private-crew-spatial-r1.png"
BRIEF = "docs/art/briefs/private_crew_spatial_repair_20261116.md"
SOURCE_PINS = {
    RAW_REL: "ac34392a170633b5fd8bebb987c2b81de9adc007c7a951fe41c008d5053b34aa",
    RAW_REL + ".b64": "0223177475b84ea6c165010eddf4453da4239cf3e4b88427899fd58b2bd82af6",
    SOURCE_DIR + "/prompt.txt": "da997f23a22ec21a5b403fff31fe76dea920fcdf89308f0476dd5e63c1ae7751",
    SOURCE_DIR + "/provenance.json": "b567eb8c0efb997e0a9691fb1bd04b98adac7588623b93eab2a5c52ffd2e2ca1",
    BRIEF: "f48c9779a4b47e15f2d60e050bd213c3ec97fcceee169db0c83942dd2b211c41",
}
MASTER_SHA = "0913167ca23cb0422a11e8fa7a7be429e04ff19c0ead3ddfb6a751598029f4ee"
MANIFEST_SHA = "c8734f4d3a00a0e3620167216e18faabdfb87551ee1d8f05fd89a5ed47cbc059"
ROOM_SEAL = "c8882f6f7fee3d1514b94f3a3834e04f47bbf4e10413ce0ef53b27fc824dd733"
CONTROL_PINS = {
    INDEX: "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24",
    "data/environments/placement_surfaces.json": "9caa123fb96816777328ad88f022fe05defb74ef5b4f645b7a15bcac67c25cf1",
    "data/environments/developer_placement_overrides.json": "c5c9808497ee3d4f056bb5a7f24a64524d4e59ee50e3fff106eb41e09383245f",
    "scripts/ui/pixel_scene_canvas.gd": "c2ce2abee8827372d66fd6c9647a74e06f5db8fed520bbd812b8c7eb29f4af38",
    "scripts/ui/environment_art_renderer.gd": "900b44af05602f6259eed0a2cb33a45d1899cb30bd71aaaed5a744bcc9ccad96",
    "scripts/ui/environment_art_pack.gd": "067cf5f9673bd85705f4971e9c4db70aaafcfe1cec912b926ed9edc685fb5d8f",
    "tools/bar_spatial_candidate_check.py": "bb0c9fd70fe4c4941d8d1019c682b691db48e5224606340a7e84e6c48dd3837f",
}
OLD_RAW = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-ARTIST-20261115/sources/private-room-source-r1.png")
OLD_RAW_SHA = "c877cf57857cc33f75f61c1accc1959c5e71ef566b3d1d209133371400082686"
OLD_RECIPE = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261115/assemble_private_r4.py")
OLD_RECIPE_SHA = "5da164be8dbd27cab12537464b69428dc96924ad56f4c87208dbd0218a5df561"
BASE_DIR = Path("E:/CodexQA/BTH/runs/BTH-ENVART-PRIVATETRIAL-20261115-r4-base-01/evidence")
LIFE_DIR = Path("E:/CodexQA/BTH/runs/BTH-ENVART-PRIVATETRIAL-20261115-r4-lifecycle-01/evidence")
ACTUAL_BOARD = BASE_DIR / "__none_production_board_1800x860.png"
ACTUAL_BOARD_SHA = "2e60dd0dda0f9498ef142024b0b6b86040ef28bcadeb5c1da12b523420fd4bde"
CASE_NAMES = ("C1_marker", "C2_associate_0", "C2_associate_2", "C2_associate_5", "C4_silas")
MOTION_IDS = tuple("floor_glint_" + str(i) for i in range(7))
IGNORE = b"# Non-active Private Crew source/candidates; exclude from Godot discovery.\n"
SIZE = (1800, 860)
RAW_SIZE = (1815, 867)
MAX_BYTES = 32 * 1024 ** 2
# Superseded, never-executed author version retained for review history.
# Its independent audit blocked unknown/nested paths in QA source trees.
PREVIOUS_RECIPE_SHA = "b84b1b29651e05faad1a5905046faecf92d4eda0ad0e39068680d3aba7a63451"
# Source and target coordinates below are native pixels; all output remains NN2.
Y_SOURCE = (305, 330, 395, 408, 424, 450)
Y_TARGET = (302, 320, 432, 442, 450, 474)
# Conservative actual-source silhouette trace. The far/near outline and
# separately mapped inner felt prevent a whole-crop taper from losing Poker.
TOP_LEFT = ((305, 552), (408, 480), (424, 480))
TOP_RIGHT = ((305, 1245), (408, 1317), (424, 1315))
FELT_LEFT = ((330, 570), (390, 535), (395, 531))
FELT_RIGHT = ((330, 1227), (390, 1264), (395, 1268))
SUPPORTS = (
    {"id": "left", "leg_source": (528, 450, 560, 516), "leg_target": (560, 474, 584, 504),
     "foot_source": (522, 516, 565, 532), "foot_target": (556, 504, 588, 520)},
    {"id": "right", "leg_source": (1236, 450, 1268, 516), "leg_target": (1216, 474, 1240, 504),
     "foot_source": (1231, 516, 1274, 532), "foot_target": (1212, 504, 1244, 520)},
)
# Per-row outer clips for conditional halo inference, NOT solid fill rectangles.
HALO_BOTTOM = {226: (263, 639), 227: (264, 638), 228: (264, 638),
               229: (265, 637), 230: (267, 636),
               231: (269, 634), 232: (269, 634), 233: (269, 634), 234: (269, 634)}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def same(a, b):
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


def ordinary(path, *, exists=True):
    path = Path(path)
    require(path.is_absolute(), "Absolute ordinary path required: " + str(path))
    for part in (path, *path.parents):
        if part.exists() or part.is_symlink():
            info = part.lstat()
            require(not stat.S_ISLNK(info.st_mode) and not (getattr(info, "st_file_attributes", 0) & 0x400),
                    "Linked/reparse path forbidden: " + str(part))
    resolved = path.resolve(strict=exists)
    require(same(path, resolved), "Noncanonical path: " + str(path))
    return resolved


def read(path):
    path = ordinary(path)
    require(path.is_file() and path.stat().st_size <= MAX_BYTES, "Missing or oversized input: " + str(path))
    data = path.read_bytes()
    require(len(data) <= MAX_BYTES, "Input grew beyond its bound: " + str(path))
    return data


def inventory(root, names):
    return {name: sha(read(root / name)) for name in sorted(names)}


def expected_directories(names):
    result = set()
    for name in names:
        value = PurePosixPath(name)
        require(value.as_posix() == name and not value.is_absolute() and
                all(part not in ("", ".", "..") for part in value.parts) and
                "\\" not in name and ":" not in name, "Unsafe physical member name: " + name)
        result.update(parent.as_posix() for parent in value.parents if parent != PurePosixPath("."))
    return result


def physical_tree(root):
    """Inspect every member before descent; no basename exclusions or links."""
    root = ordinary(root, exists=False)
    if not root.exists():
        return {"exists": False, "files": [], "directories": []}
    require(root.is_dir(), "Physical tree root must be an ordinary directory: " + str(root))
    files, directories, pending = set(), set(), [root]
    while pending:
        directory = pending.pop()
        ordinary(directory)
        for path in sorted(directory.iterdir()):
            ordinary(path)
            info = path.lstat()
            relative = path.relative_to(root).as_posix()
            expected_directories((relative,))
            if stat.S_ISDIR(info.st_mode):
                directories.add(relative)
                pending.append(path)
            else:
                require(stat.S_ISREG(info.st_mode), "Non-regular physical tree member: " + str(path))
                files.add(relative)
    return {"exists": True, "files": sorted(files), "directories": sorted(directories)}


def check_tree(root, required_hashes, *, partial=False, sentinel=False, absent=False):
    """Require exact ordinary physical membership, allowing only chosen partial files."""
    tree = physical_tree(root)
    if not tree["exists"]:
        require(absent, "Expected prepared physical tree is absent: " + str(root))
        return tree
    files, directories = set(tree["files"]), set(tree["directories"])
    logical = files - {".gdignore"} if sentinel else files
    allowed = set(required_hashes) | ({".gdignore"} if sentinel else set())
    require(files <= allowed, "Unknown physical files in " + str(root) + ": " + str(sorted(files - allowed)))
    require(directories == expected_directories(files),
            "Unknown or empty physical directories in " + str(root) + ": " + str(sorted(directories)))
    require(logical <= set(required_hashes) and (partial or logical == set(required_hashes)),
            "Incomplete or unexpected logical file membership in " + str(root) +
            "; partial baseline requires explicit --allow-partial-baseline")
    if ".gdignore" in files:
        require(sentinel and read(root / ".gdignore") == IGNORE, "Unknown root ignore sentinel")
    for name in logical:
        require(sha(read(root / name)) == required_hashes[name], "Existing physical member differs: " + str(root / name))
    return tree


def seal(values):
    return sha("\n".join(name + " " + value for name, value in sorted(values.items())).encode())


def pixel(image, x, y):
    require(0 <= x < image.width and 0 <= y < image.height, "Pixel outside source")
    at = (y * image.width + x) * 4
    return image.rgba[at:at + 4]


def old_s(old, x, y):
    sx = math.floor((x + .5) * old.width / 900)
    sy = math.floor((y + .5) * old.height / 430)
    return sx, sy, pixel(old, sx, sy)


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def encode(image):
    compressor = zlib.compressobj(9)
    stride = image.width * 4
    data = b"".join(compressor.compress(b"\0" + image.rgba[y * stride:(y + 1) * stride])
                    for y in range(image.height)) + compressor.flush()
    result = (b"\x89PNG\r\n\x1a\n" +
              chunk(b"IHDR", struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)) +
              chunk(b"IDAT", data) + chunk(b"IEND", b""))
    require(decode_png(result) == image, "Lossless PNG roundtrip failed")
    return result


def opaque(image, size):
    return (image.width, image.height) == size and image.rgba[3::4] == b"\xff" * (image.width * image.height)


def lerp_knots(knots, value):
    for (x0, y0), (x1, y1) in zip(knots, knots[1:]):
        if x0 <= value <= x1:
            return y0 + (value - x0) * (y1 - y0) / (x1 - x0)
    raise ValueError("Outside explicit remap knots: " + str(value))


def remap(value, target0, target1, source0, source1):
    require(target0 <= value < target1 and target1 > target0 and source1 > source0, "Invalid remap")
    return min(math.ceil(source1) - 1, math.floor(source0 + (value - target0) * (source1 - source0) / (target1 - target0)))


def top_geometry(ny):
    # Target far edge268..632; near edge264..636. Interior felt has a
    # separate mapping, leaving actual Poker body a small visible felt margin.
    fraction = min(1.0, max(0.0, (ny - 302) / (442 - 302)))
    outer_l, outer_r = 536 - 8 * fraction, 1264 + 8 * fraction
    felt_fraction = min(1.0, max(0.0, (ny - 320) / (432 - 320)))
    return outer_l, 542 - 6 * felt_fraction, 1258 + 6 * felt_fraction, outer_r


def furniture(bx, by):
    nx, ny = bx * 2 + 1, by * 2 + 1
    if 302 <= ny < 450:
        sy = math.floor(lerp_knots(tuple(zip(Y_TARGET, Y_SOURCE)), ny))
        ol, fl, fr, oright = top_geometry(ny)
        if not (ol <= nx < oright):
            return None
        sol, sor = lerp_knots(TOP_LEFT, sy), lerp_knots(TOP_RIGHT, sy)
        if 330 <= sy < 395:
            sfl, sfr = lerp_knots(FELT_LEFT, sy), lerp_knots(FELT_RIGHT, sy)
            if nx < fl:
                sx = remap(nx, ol, fl, sol, sfl)
                kind = "left_side_rail"
            elif nx < fr:
                sx = remap(nx, fl, fr, sfl, sfr)
                kind = "felt"
            else:
                sx = remap(nx, fr, oright, sfr, sor)
                kind = "right_side_rail"
        else:
            sx = remap(nx, ol, oright, sol, sor)
            kind = "rear_rail" if sy < 330 else "near_contact_rail"
        return sx, sy, kind
    if 450 <= ny < 474:
        sy = math.floor(lerp_knots(tuple(zip(Y_TARGET, Y_SOURCE)), ny))
        # Source apron is a shaped top slab, not the rectangle of wall below it.
        inset = max(0.0, (sy - 440) * .8)
        sl, sr = 488 + inset, 1308 - inset
        tl, tr = 532 + max(0, ny - 462) / 3, 1268 - max(0, ny - 462) / 3
        if tl <= nx < tr:
            return remap(nx, tl, tr, sl, sr), sy, "shallow_apron"
    for item in SUPPORTS:
        for part in ("leg", "foot"):
            tx0, ty0, tx1, ty1 = item[part + "_target"]
            if tx0 <= nx < tx1 and ty0 <= ny < ty1:
                sx0, sy0, sx1, sy1 = item[part + "_source"]
                return (remap(nx, tx0, tx1, sx0, sx1),
                        remap(ny, ty0, ty1, sy0, sy1), item["id"] + "_" + part)
    return None


def wall_donor(old, bx, by):
    candidates = [bx + 41 * k for k in range(-23, 24)
                  if 216 <= bx + 41 * k < 262 or 638 <= bx + 41 * k < 670]
    # The source's own table/shadow contamination cannot be a donor. This is
    # a donor exclusion only, never an output fill rectangle or claimed period.
    candidates = [x for x in candidates if not (260 <= x < 643 and 147 <= by < 238)]
    require(candidates, "No clean own-source same-row wall donor")
    dx = min(candidates, key=lambda x: (abs(x - bx), x))
    sx, sy, color = old_s(old, dx, by)
    return sx, sy, color, dx


def halo_kind(original, old, bx, by):
    if 148 <= by <= 150 and 263 <= bx < 635:
        clean_rows = (144, 145, 146)
        name = "old_top_halo"
        reference = sorted(pixel(original, bx * 2, yy * 2)[0] for yy in clean_rows)[1]
    elif 151 <= by <= 225 and 636 <= bx < 638:
        name = "old_right_fringe"
        reference = sorted(old_s(old, xx, by)[2][0] for xx in (643, 644, 645))[1]
    elif by in HALO_BOTTOM and HALO_BOTTOM[by][0] <= bx < HALO_BOTTOM[by][1]:
        clean_rows = (235, 236, 237)
        name = "old_bottom_halo"
        reference = sorted(pixel(original, bx * 2, yy * 2)[0] for yy in clean_rows)[1]
    else:
        return None
    red = pixel(original, bx * 2, by * 2)[0]
    donor = wall_donor(old, bx, by)
    if reference > 20 and reference - red > max(4, .12 * reference) and donor[2][0] > red + 4:
        return name, donor
    return None


def runs(points):
    result = []
    for y in sorted({p[1] for p in points}):
        xs = sorted(x for x, yy in points if yy == y)
        start = previous = xs[0]
        for x in xs[1:]:
            if x != previous + 1:
                result.append([y, start, previous + 1])
                start = x
            previous = x
        result.append([y, start, previous + 1])
    return result


def validate_original(original, old):
    require(opaque(original, SIZE) and opaque(old, RAW_SIZE), "Exact opaque original/source dimensions required")
    for by in range(430):
        for bx in range(900):
            color = pixel(original, bx * 2, by * 2)
            require(all(pixel(original, bx * 2 + dx, by * 2 + dy) == color
                        for dx, dy in ((1, 0), (0, 1), (1, 1))), "Original lost NN2 block identity")
    for j in range(74):
        for i in range(372):
            sx = 263 + math.floor((i + .5) * 371 / 372)
            sy = 152 + math.floor((j + .5) * 72 / 74)
            require(pixel(original, (264 + i) * 2, (151 + j) * 2) == old_s(old, sx, sy)[2],
                    "Exact old module recipe/source equation differs")
    # Reconstruct the actual original floor plate, including its inherited
    # five-row transition repair. No floor donor is needed for broad healing.
    for by in range(245, 430):
        floor_y = by - 245
        if 5 <= floor_y < 10:
            floor_y += 5
        for bx in range(900):
            sx, sy = 8 + 2 * bx, 498 + 2 * floor_y
            require(pixel(original, bx * 2, by * 2) == pixel(old, sx, sy), "Own floor plate differs")
    return {"original_NN2_blocks_verified": 900 * 430,
            "old_module_pixels_verified": 372 * 74, "own_floor_plate_pixels_verified": 900 * 185,
            "global_texture_period_claimed": False}


def assemble(original, raw, old):
    require(opaque(raw, RAW_SIZE), "Exact opaque frozen trial required")
    pixels = bytearray(original.rgba)
    trace, components, halos = {}, {}, {}
    # The conservative iteration envelope is NOT an edit mask. Only exact
    # furniture silhouettes, old rectangular module or selected halos write.
    for by in range(148, 260):
        for bx in range(262, 640):
            source = furniture(bx, by)
            if source is not None:
                sx, sy, kind = source
                color, source_id = pixel(raw, sx, sy), 0
            elif 264 <= bx < 636 and 151 <= by < 225:
                sx, sy, color, donor_board_x = wall_donor(old, bx, by)
                source_id, kind = 1, "old_module_wall_heal"
            else:
                selected = halo_kind(original, old, bx, by)
                if selected is None:
                    continue
                kind, donor = selected
                sx, sy, color, donor_board_x = donor
                source_id = 1
                halos[(bx, by)] = kind
            require(color[3] == 255, "Source pixel became transparent")
            components[(bx, by)] = kind
            trace[(bx, by)] = (source_id, sx, sy, kind)
            for dy in (0, 1):
                at = ((by * 2 + dy) * original.width + bx * 2) * 4
                pixels[at:at + 8] = color * 2
    result = PNGImage(original.width, original.height, bytes(pixels))
    changed = 0
    for y in range(860):
        for x in range(1800):
            before, after = pixel(original, x, y), pixel(result, x, y)
            key = (x // 2, y // 2)
            if before != after:
                changed += 1
                require(key in trace, "Changed pixel outside traced union")
            if key in trace:
                source_id, sx, sy, kind = trace[key]
                require(after == pixel(raw if source_id == 0 else old, sx, sy), "Per-pixel donor equality failed")
            if 470 <= y < 474:
                require(before == after or components.get(key, "") == "shallow_apron" or
                        components.get(key, "").endswith(("_leg", "_foot")),
                        "Old halo healing escaped below235 outside new physical table")
            if 474 <= y < 490:
                require(before == after or components.get(key, "").endswith(("_leg", "_foot")),
                        "Protected studs/wall base changed outside tight support mask")
            if 490 <= y < 502:
                require(before == after or components.get(key, "").endswith(("_leg", "_foot")),
                        "Protected floor transition changed outside tight support mask")
            if y >= 520:
                require(before == after, "Foot contact exceeded260 or changed first floor motion274+")
    # Existing actual gold studs must not be obscured, even inside a proposed
    # support envelope. Their RGB test is evidence-only; it does not paint.
    studs = []
    for by in range(238, 244):
        for bx in range(262, 640):
            red, green, blue, alpha = pixel(original, bx * 2, by * 2)
            if red >= 120 and green >= 75 and red >= blue * 1.3:
                studs.append((bx, by))
                require(pixel(result, bx * 2, by * 2) == pixel(original, bx * 2, by * 2), "Gold wall stud obscured")
    proof_rows = [[bx * 2, by * 2, value[0], value[1], value[2], value[3]]
                  for (bx, by), value in sorted(trace.items(), key=lambda item: (item[0][1], item[0][0]))]
    union_mask = bytearray(900 * 430)
    halo_mask = bytearray(900 * 430)
    for bx, by in trace:
        union_mask[by * 900 + bx] = 1
    for bx, by in halos:
        halo_mask[by * 900 + bx] = 1
    report = {"component_board_pixel_counts": dict(Counter(components.values())),
              "changed_native_pixels": changed, "applied_board_donors": len(trace),
              "source_original_outside_selected_union_exact": True,
              "output_NN2_blocks_preserved": True, "maximum_new_furniture_board_y_exclusive": 260,
              "protected_gold_stud_board_pixels": len(studs), "halo_selected_board_runs": runs(set(halos)) if halos else [],
              "halo_method": "Explicit clipped contrast inference; not recovered semantic alpha. Original same-row41-step wall donors, excluding table-contaminated source points. No solid halo rectangle.",
              "halo_component_counts": dict(Counter(halos.values())),
              "selected_union_board_mask_sha256": sha(union_mask),
              "selected_halo_board_mask_sha256": sha(halo_mask),
              "mask_encoding": "900x430 row-major bytes0/1; no semantic alpha claim",
              "halo_threshold": {"baseline_min_exclusive": 20, "deficit_min_exclusive": 4,
                                 "deficit_baseline_ratio_exclusive": .12, "donor_red_gain_exclusive": 4,
                                 "top_clean_rows": [144, 145, 146], "bottom_clean_rows": [235, 236, 237],
                                 "right_reference_columns": [643, 644, 645],
                                 "source_donor_exclusion_board_xyxy": [260, 147, 643, 238],
                                 "bottom_outer_clips_exclusive": HALO_BOTTOM},
              "no_floor_rectangle_or_global_recolor": True}
    return result, components, proof_rows, report


def typed_risk(provenance, components):
    records = provenance["mask_evidence"]
    require(len(records) == 50, "Exact50 typed body/adornment inputs required")
    decoded, hashes, report = {}, {}, []
    for name, record in sorted(records.items()):
        path = Path(name)
        require(path.parent in (BASE_DIR, LIFE_DIR), "Unexpected typed-evidence root")
        data = read(path); hashes[name] = sha(data)
        require(hashes[name] == record["sha256"], "Frozen typed mask differs: " + name)
        # Decode each identical byte variant once; still pin every path.
        key = hashes[name]
        if key not in decoded:
            decoded[key] = decode_png(data)
        image = decoded[key]
        require((image.width, image.height) == SIZE, "Actual typed mask dimensions differ")
        counts0, counts64 = Counter(), Counter()
        for (bx, by), kind in components.items():
            for dy in (0, 1):
                for dx in (0, 1):
                    alpha = pixel(image, bx * 2 + dx, by * 2 + dy)[3]
                    if alpha:
                        counts0[kind] += 1
                    if alpha >= 64:
                        counts64[kind] += 1
        support0 = sum(counts0[k] for k in counts0 if k.endswith(("_leg", "_foot")))
        support64 = sum(counts64[k] for k in counts64 if k.endswith(("_leg", "_foot")))
        require(support0 == support64 == 0, "An actual Base/lifecycle painted pixel intersects a proposed support: " + name)
        report.append({"path": name, "id": record["object_id"], "kind": record["kind"],
                       "alpha_gt0_by_component": dict(counts0), "alpha_ge64_by_component": dict(counts64),
                       "support_alpha_gt0": support0, "support_alpha_ge64": support64})
    life = json.loads(read(LIFE_DIR / "private_lifecycle_result.json"))
    base = json.loads(read(BASE_DIR / "private_preart_metadata.json"))
    require(tuple(c["name"] for c in life["cases"]) == CASE_NAMES, "Exact five lifecycle cases required")
    expected = {}
    for data, root in [(base["views"]["__none"]["source_paint"], BASE_DIR)] + [(c["source_character_paint"], LIFE_DIR) for c in life["cases"]]:
        for row in data["objects"]:
            for field in ("body_png", "adorn_png"):
                expected[str(root / row[field])] = row["object"]["id"]
    require({os.path.normcase(k): v for k, v in expected.items()} ==
            {os.path.normcase(k): v["object_id"] for k, v in records.items()}, "Typed mask source mapping differs")
    return {"scope": "Historical Base+all5 lifecycle actual painted pixels; no fresh native acceptance.",
            "mask_hashes": hashes, "masks": report, "all38_lifecycle_masks_support_alpha_gt0_and_ge64_zero": True,
            "all50_Base_plus_lifecycle_masks_support_alpha_gt0_and_ge64_zero": True,
            "fixed_geometry_and_labels_unchanged": True, "strict_cases": ["C2_associate_5 Knuckles", "C4_silas Silas"]}


def poker_risk(components, raw, trace):
    data = read(ACTUAL_BOARD)
    require(sha(data) == ACTUAL_BOARD_SHA, "Actual populated Poker board identity differs")
    image = decode_png(data)
    require((image.width, image.height) == SIZE, "Actual populated Poker board dimensions differ")
    palette_counts, source_material = Counter(), Counter()
    minimum_margin, contacts = float("inf"), []
    for y in range(338, 422):
        for x in range(542, 835):
            color = tuple(pixel(image, x, y)[:3])
            if color not in ((18, 80, 58), (28, 138, 98)):
                continue
            palette_counts[color] += 1
            bx, by = x // 2, y // 2
            require(components.get((bx, by)) == "felt", "Actual Poker painted surface leaves proposed felt plane")
            _, left, right, _ = top_geometry(y + .5)
            margin = min(x + .5 - left, right - x - .5, y + .5 - 320, 432 - y - .5) / 2
            minimum_margin = min(minimum_margin, margin)
            source_id, sx, sy, kind = trace[(bx, by)]
            require(source_id == 0, "Poker support was healed wall, not trial tabletop")
            red, green, blue, alpha = pixel(raw, sx, sy)
            if green >= 8 and green > red * 1.15 and green > blue * 1.05:
                source_material["green_or_dark_green_inset"] += 1
            else:
                source_material["inner_inlay_or_non_green_pixel"] += 1
                contacts.append([x, y, sx, sy])
    require(palette_counts == {(18, 80, 58): 11512, (28, 138, 98): 6952}, "Actual Poker source-painted pixel counts differ")
    require(minimum_margin > 0, "Poker face contacts outer felt boundary")
    return {"actual_board": str(ACTUAL_BOARD), "sha256": ACTUAL_BOARD_SHA,
            "actual_painted_texels": sum(palette_counts.values()),
            "painted_rgb_counts": {str(k): v for k, v in palette_counts.items()},
            "all_actual_painted_surface_pixels_on_felt_plane": True,
            "minimum_geometric_felt_margin_board": minimum_margin,
            "mapped_source_material_counts": dict(source_material),
            "inner_inlay_contact_native_source_points": contacts,
            "candid_limit": "Inner source inset/brass pixels can lie underneath opaque live Poker paint; these are reported for actual visual review, not hidden by moving game anchors. Geometric outer rail contact is prohibited."}


def package_names(manifest):
    require(manifest["environment_id"] == ROOM and manifest["board_size"] == [900, 430] and manifest["pixel_scale"] == 2,
            "Exact Private Crew manifest identity required")
    require(manifest["counters"] == {} and [row["id"] for row in manifest["animations"]] == list(MOTION_IDS),
            "Private Crew requires ZERO counters and seven unchanged movers")
    require(all(row["type"] == "mover" and row.get("web_low_detail", True) for row in manifest["animations"]),
            "Seven normal+low-detail floor movers required")
    names = {BACKGROUND, MANIFEST}
    names.update(ART + row["texture"] for row in manifest["animations"])
    require(len(names) == 9, "Exact nine room payload files required")
    require(all(".." not in name.split("/") and "\\" not in name and not name.startswith("/") for name in names), "Unsafe payload path")
    return tuple(sorted(names))


def layout_from_environment():
    path = Path(os.environ["BTH_QA_EVIDENCE_DIR"]) / "storage-manifest.json"
    record = json.loads(read(path))
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
                    **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and same(layout.root, Path("E:/CodexQA/BTH")) and same(layout.workspace, WORKSPACE),
            "Exact admitted E root and prepared Private Crew workspace required")
    return layout


def write_fresh(path, data, layout):
    validate_layout(layout, extra_write_paths=(path.parent, path))
    ordinary(path, exists=False)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as handle:
        handle.write(data)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--allow-partial-baseline", action="store_true",
                        help="Explicitly preserve/fill only pinned known baseline files; reject unknown/empty directories.")
    args = parser.parse_args(argv)
    try:
        layout = layout_from_environment()
        source = ordinary(args.source_root.absolute())
        require(same(source, SOURCE_ROOT), "Exact read-only art worktree required")
        recipe_sha, decoder_sha = sha(read(__file__)), sha(read(decode_png.__code__.co_filename))
        baseline, sources = layout.workspace / "source_baseline", layout.workspace / "candidate_sources"
        output = sources / "private-crew-spatial-r1-assembled-v1"
        report_path = layout.evidence / "private-crew-spatial-r1-assembly.json"
        pixel_path = layout.evidence / "private-crew-spatial-r1-pixel-provenance.json"
        validate_layout(layout, extra_write_paths=(baseline, sources, output, report_path, pixel_path))
        for path in (output, report_path, pixel_path):
            ordinary(path, exists=False)
            require(not path.exists(), "Fresh immutable output required: " + str(path))
        manifest_bytes = read(source / MANIFEST)
        require(sha(manifest_bytes) == MANIFEST_SHA, "Frozen full manifest differs")
        manifest = json.loads(manifest_bytes)
        room_names = package_names(manifest)
        names = tuple(sorted((*room_names, INDEX)))
        extras = tuple(sorted(set(CONTROL_PINS) | set(SOURCE_PINS)))
        before = inventory(source, set(names) | set(extras))
        require(seal({name: before[name] for name in room_names}) == ROOM_SEAL and before[BACKGROUND] == MASTER_SHA,
                "Frozen nine-file room identity differs")
        for name, value in {**CONTROL_PINS, **SOURCE_PINS}.items():
            require(before[name] == value, "Frozen source/control differs: " + name)
        old_inputs = {str(OLD_RAW): sha(read(OLD_RAW)), str(OLD_RECIPE): sha(read(OLD_RECIPE))}
        require(old_inputs == {str(OLD_RAW): OLD_RAW_SHA, str(OLD_RECIPE): OLD_RECIPE_SHA}, "Original source/recipe differs")
        raw_bytes = read(source / RAW_REL)
        require(base64.b64decode(b"".join(read(source / (RAW_REL + ".b64")).split()), validate=True) == raw_bytes,
                "Frozen raw/base64 transport differs")
        provenance = json.loads(read(source / (SOURCE_DIR + "/provenance.json")))
        evidence_before = {}
        for name, record in provenance["retained_evidence"].items():
            evidence_before[name] = sha(read(name))
            require(evidence_before[name] == record["sha256"], "Retained actual/metadata evidence differs: " + name)
        original, raw, old = decode_png(read(source / BACKGROUND)), decode_png(raw_bytes), decode_png(read(OLD_RAW))
        original_proof = validate_original(original, old)
        assembled, components, pixel_rows, assembly = assemble(original, raw, old)
        risks, poker = typed_risk(provenance, components), poker_risk(components, raw, {(row[0] // 2, row[1] // 2): tuple(row[2:]) for row in pixel_rows})
        payload = {name: read(source / name) for name in names}
        payload[BACKGROUND] = encode(assembled)
        original_hashes = {name: before[name] for name in names}
        hashes = {name: sha(payload[name]) for name in names}
        require([name for name in names if hashes[name] != original_hashes[name]] == [BACKGROUND],
                "Only Private background may change; seven animations/full JSON/index stay byte-exact")
        require(package_names(json.loads(payload[MANIFEST])) == room_names and len(names) == 10, "Logical9+index payload membership differs")
        preserved = {"private-crew-spatial-r1.png": raw_bytes,
                     "private-crew-spatial-r1.png.b64": read(source / (RAW_REL + ".b64")),
                     "provenance.json": read(source / (SOURCE_DIR + "/provenance.json")),
                     "prompt.txt": read(source / (SOURCE_DIR + "/prompt.txt"))}
        preserved_hashes = {name: sha(data) for name, data in preserved.items()}
        physical_before = {
            "baseline": check_tree(baseline, original_hashes, partial=args.allow_partial_baseline, sentinel=True, absent=True),
            "candidate_sources": check_tree(sources, preserved_hashes, partial=True, sentinel=True, absent=True),
        }
        require(inventory(source, before) == before and sha(read(__file__)) == recipe_sha and
                sha(read(decode_png.__code__.co_filename)) == decoder_sha and
                {name: sha(read(name)) for name in old_inputs} == old_inputs and
                {name: sha(read(name)) for name in evidence_before} == evidence_before and
                all(sha(read(name)) == value for name, value in risks["mask_hashes"].items()) and
                sha(read(ACTUAL_BOARD)) == ACTUAL_BOARD_SHA, "Inputs changed during no-write preflight")
        pixel_report = {"schema": "bth.private_crew_pixel_provenance/v1",
                        "destination_coordinates": "native top-left, each row expands to a2x2 NN block",
                        "row_fields": ["destination_x", "destination_y", "source_id", "source_x", "source_y", "component"],
                        "source_ids": {"0": {"path": str(sources / "private-crew-spatial-r1.png"), "sha256": SOURCE_PINS[RAW_REL]},
                                       "1": {"path": str(OLD_RAW), "sha256": OLD_RAW_SHA}},
                        "rows": pixel_rows, "all_native_donor_equalities_checked": True,
                        "outside_selected_union_original_exact": True}
        pixel_bytes = (json.dumps(pixel_report, separators=(",", ":")) + "\n").encode()
        # FIRST E WRITES: all source, exact geometry, actual paint, contact,
        # NN2 exterior and controls have passed. Root owns guard/capped Job.
        validate_layout(layout, extra_write_paths=(baseline, sources, output, report_path, pixel_path))
        require({"baseline": check_tree(baseline, original_hashes, partial=args.allow_partial_baseline, sentinel=True, absent=True),
                 "candidate_sources": check_tree(sources, preserved_hashes, partial=True, sentinel=True, absent=True)} == physical_before,
                "Physical source/baseline membership changed during no-write preflight")
        ordinary(baseline, exists=False); ordinary(sources, exists=False)
        baseline.mkdir(exist_ok=True); sources.mkdir(exist_ok=True)
        for directory in (baseline, sources):
            if not (directory / ".gdignore").exists():
                write_fresh(directory / ".gdignore", IGNORE, layout)
        for name in names:
            if not (baseline / name).exists():
                write_fresh(baseline / name, payload[name] if name != BACKGROUND else read(source / name), layout)
        for name, data in preserved.items():
            if not (sources / name).exists():
                write_fresh(sources / name, data, layout)
        validate_layout(layout, extra_write_paths=(output,))
        ordinary(output, exists=False)
        output.mkdir()
        for name in names:
            write_fresh(output / name, payload[name], layout)
        write_fresh(pixel_path, pixel_bytes, layout)
        source_final_hashes = {**preserved_hashes,
                               **{output.name + "/" + name: value for name, value in hashes.items()}}
        physical_after = {
            "baseline": check_tree(baseline, original_hashes, sentinel=True),
            "candidate": check_tree(output, hashes),
            "candidate_sources": check_tree(sources, source_final_hashes, sentinel=True),
        }
        require(".gdignore" in physical_after["baseline"]["files"] and
                ".gdignore" in physical_after["candidate_sources"]["files"], "Final root sentinels absent")
        require(inventory(output, names) == hashes and inventory(baseline, names) == original_hashes and
                inventory(source, before) == before and sha(read(__file__)) == recipe_sha and
                sha(read(decode_png.__code__.co_filename)) == decoder_sha and
                {name: sha(read(name)) for name in old_inputs} == old_inputs and
                {name: sha(read(name)) for name in evidence_before} == evidence_before and
                all(sha(read(name)) == value for name, value in risks["mask_hashes"].items()) and
                all(read(sources / name) == data for name, data in preserved.items()) and
                sha(read(ACTUAL_BOARD)) == ACTUAL_BOARD_SHA, "Source/output custody changed after assembly")
        report = {"schema": "bth.private_crew_spatial_assembly/v1", "task_id": "BTH-ENV-SPATIAL-PRIVATE-001",
                  "room": ROOM, "context": "small_underground_casino:back_room",
                  "status": "NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT",
                  "observed_at": datetime.now(timezone.utc).isoformat(), "recipe_sha256": recipe_sha,
                  "recipe_history": [{"sha256": PREVIOUS_RECIPE_SHA, "status": "SUPERSEDED_CODE_REVIEW_BLOCKED_NOT_EXECUTED",
                                      "reason": "Strict ordinary physical file/directory membership added; art/body assembly unchanged."}],
                  "decoder_sha256": decoder_sha, "storage_manifest": str(layout.manifest_path),
                  "baseline": {"path": str(baseline), "room9_seal": ROOM_SEAL, "files": original_hashes,
                               "payload10_with_index_seal": seal(original_hashes)},
                  "output": {"path": str(output), "files": hashes, "seal": seal(hashes), "file_count": 10,
                             "room_file_count": 9, "index_byte_exact": True},
                  "changed_payload_paths": [BACKGROUND], "source_hashes_before": before,
                  "physical_membership_before": physical_before, "physical_membership_after": physical_after,
                  "partial_baseline_fill_explicitly_requested": args.allow_partial_baseline,
                  "final_exact_file_and_directory_membership_verified": True,
                  "source_hashes_after": inventory(source, before), "old_inputs": old_inputs,
                  "retained_evidence_hashes": evidence_before, "original_geometry_proof": original_proof,
                  "assembly": assembly, "populated_painted_pixel_risk": risks, "actual_poker_surface": poker,
                  "pixel_provenance": {"path": str(pixel_path), "sha256": sha(pixel_bytes), "rows": len(pixel_rows),
                                       "native_donor_equalities": 4 * len(pixel_rows)},
                  "all_sources_unchanged": True, "zero_counters_and_replays": True,
                  "native7_and_web_low_detail7_byte_exact": True, "full_manifest_and_index_byte_exact": True,
                  "source_original_outside_selected_union_exact": True,
                  "active_files_written": False, "runtime_launched": False, "art_approval": False, "test_updated": False,
                  "risks": ["Explicit contrast-inference halo mask and generated rails/apron/complete feet need independent actual-pixel review.",
                            "Historical all5 lifecycle and actual Poker pigment checks are not fresh populated/native/motion acceptance.",
                            "Inner-inlay material contacts under opaque live Poker face are reported explicitly; no game anchors move.",
                            "Velvet title at206..218 crosses the proposed felt/near-rail region and needs actual populated readability review.",
                            "No Mags/C3, UI-earned lifecycle, save/revisit, Web or TEST acceptance implied."]}
        write_fresh(report_path, (json.dumps(report, indent=2) + "\n").encode(), layout)
        print(json.dumps({"status": report["status"], "package": str(output), "report": str(report_path),
                          "pixel_provenance": str(pixel_path), "art_approval": False}))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(json.dumps({"status": "PRIVATE_CREW_ASSEMBLY_STOPPED", "error": str(error),
                          "active_files_written": False, "runtime_launched": False, "art_approval": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
