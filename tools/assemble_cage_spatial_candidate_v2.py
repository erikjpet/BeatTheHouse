"""Version2 Cage alpha assembly: configured storage budget, unchanged pixel law.

One atlas changes alpha only. No generated geometry, active art, engine, children,
metadata auto-copy, profiles, Git, deletion, cleanup or moves. All source and
historical pixel proofs precede the first exclusive guarded E: output write.
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
import shutil
import stat
import struct
import zlib

from bar_spatial_candidate_check import PNGImage, decode_png
from bth_qa_storage import Layout, validate_layout

ROOM = "grand_casino_cage"
TASK = "BTH-ENV-SPATIAL-CAGE-001"
SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-CAGETRIAL-20261116")
ART = "assets/art/environments/" + ROOM + "/"
BACKGROUND = ART + "background.png"
SIGN = ART + "anim/cage_sign_pulse.png"
COUNTER = ART + "counters/grand_cage_teller_counter.png"
MANIFEST = "data/art/environments/" + ROOM + ".json"
INDEX = "data/art/environments/index.json"
CANONICAL_IMPORT = SIGN + ".import"
CANONICAL_IMPORT_SHA = "c01de65224414a44c9155409991088f1b7cc620ebdc1ef253632ac961ee50812"
CANONICAL_UID = "uid://cnxu3ydc07y0l"
CANONICAL_TARGET = "res://.godot/imported/cage_sign_pulse.png-7969e6e2a49f4106a3cb7efee23e7a17.ctex"
BRIEF = "docs/art/briefs/grand_cage_spatial_repair_20261116.md"
BRIEF_SHA = "60df5cf18828b33944bc9ce417727cd529aa8a954d4f157c61c13bc6f0c249ec"

PREVIOUS_ASSEMBLER_SHA = "0a4120d6284e625808a5b9ab6f4a3076ed80121ad435d0465c926d9f5320779f"
PREVIOUS_TESTS_SHA = "d665f236e80c26196ccaae7cc0099a060cb2a0da6056cdbfe12cd3dc054c82eb"
FAILED_EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-CAGETRIAL-20261116-assemble01/evidence")
FAILED_JOB_SHA = "15832ff904b9a1f07a32b5dceb63e1fce8dc6d1c5b16afbc0046b0a5ebe17227"
FAILED_LOG_SHA = "9fe5b5ccfd9dea038f70463ec3f3857422c5b2340c570ecfb49246eb5120b170"
FAILED_CAPACITY = {
    "total_bytes": 999649439744,
    "available_bytes_at_launch": 72702087168,
    "configured_expected_write_bytes": 4294967296,
    "configured_reserve_bytes": 21474836480,
    "maintained_required_bytes": 25769803776,
    "old_unrequested_volume_headroom_bytes": 119957932770,
    "old_unrequested_required_bytes": 124252900066,
}
METADATA_APPLICATION = "docs/testing/private_and_cage_spatial_metadata_application_20261116.json"
METADATA_APPLICATION_SHA = "6402a9cf1fdd4a490a35f9681fbc3b84992acbb52f123f6de6d11f0763605afa"
DRAFT_CHECKPOINT_SHA = "ee595d1c6f1d66d20648ffd60e223fd7faa13bcae86d3ca8c390c237ddbfa3b3"
CHECKPOINT_TRANSPORT = "review_artifacts/environment_art_sources/cage-alpha-assembly-checkpoints/assemble_cage_spatial_candidate_ee595d1c.py.b64"
CHECKPOINT_TRANSPORT_SHA = "17f9be1629fd81e25f2a300c80c49bde3a9f59d718bbc37145719bb481c7d05c"
CHECKPOINT_PROVENANCE = "review_artifacts/environment_art_sources/cage-alpha-assembly-checkpoints/provenance.json"
CHECKPOINT_PROVENANCE_SHA = "66e5f3f2ba7c608967582421f16324e72eca86f6ccfe97a9bbe9dcd598ff2f62"
PAYLOAD_PINS = {
    "assets/art/environments/grand_casino_cage/anim/atm_scan.png": "1d0e8981dbb9f1fb5c08ba570af1d39be37af691205f5ae4d15067dee2f7df44",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_0.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_1.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_10.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_2.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_3.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_4.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_5.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_6.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_7.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_8.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_glint_9.png": "1739cfd773c7b93801f33e4e104a2ea94c9da3da87443a77cf6a6a71ad5f58d6",
    "assets/art/environments/grand_casino_cage/anim/cage_sign_pulse.png": "02069bd24cb4abc4fc9ed4cfd0a774bda4ac536499ef2a4e28513b1f06f4faee",
    "assets/art/environments/grand_casino_cage/anim/floor_glint_0.png": "bb4f5c707031c24c8f05cca373ab66cb3fb8ea2a729a2dafd6112be0576bc490",
    "assets/art/environments/grand_casino_cage/anim/floor_glint_1.png": "8c3943c4d07602da082a29d49d5d092f1d26dd1726cdf1789cabef2073b1c21a",
    "assets/art/environments/grand_casino_cage/anim/floor_glint_2.png": "411d358e941a5867df0c7edc1f58fe72c1c81633c1bc7f1b2c4ed8453156775b",
    "assets/art/environments/grand_casino_cage/anim/floor_glint_3.png": "18868f32b541dc3a10c44c3dc109054745b7f1e07953883700b4d27ad0ebfa3d",
    "assets/art/environments/grand_casino_cage/anim/floor_glint_4.png": "36cb42a27c9b0588e0130993d78403243e1c11255fce38a0a16097dd4d1d7147",
    "assets/art/environments/grand_casino_cage/anim/floor_glint_5.png": "3658013941c5c6b6a3ca7484d9018e893a681aa97eaef8e2f212451a6362ed27",
    "assets/art/environments/grand_casino_cage/anim/floor_glint_6.png": "d8f87fdc51b4401fef0d151975fb2963bbd43919625a8e6aec9234087627bb57",
    "assets/art/environments/grand_casino_cage/background.png": "9c6f7bb773711b56fbdbddd65d1318342df397ef0130b83c1565784757c7a2f7",
    "assets/art/environments/grand_casino_cage/counters/grand_cage_teller_counter.png": "3af64a745fa97b8261d8ac44146086b5afffee339b6f332fa20841a5a3034e4d",
    "data/art/environments/grand_casino_cage.json": "ab70b2d0fc3e7d02a0b8c645cb1b71a0e056e1e63d7d1c029669cbb3f66c1b9e",
    "data/art/environments/index.json": "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
}
CONTROL_PINS = {
    "tools/assemble_cage_spatial_candidate.py": PREVIOUS_ASSEMBLER_SHA,
    "tools/test_assemble_cage_spatial_candidate.py": PREVIOUS_TESTS_SHA,
    BRIEF: BRIEF_SHA,
    METADATA_APPLICATION: METADATA_APPLICATION_SHA,
    CHECKPOINT_TRANSPORT: CHECKPOINT_TRANSPORT_SHA,
    CHECKPOINT_PROVENANCE: CHECKPOINT_PROVENANCE_SHA,
    CANONICAL_IMPORT: CANONICAL_IMPORT_SHA,
    "data/environments/placement_surfaces.json": "9caa123fb96816777328ad88f022fe05defb74ef5b4f645b7a15bcac67c25cf1",
    "data/environments/developer_placement_overrides.json": "c5c9808497ee3d4f056bb5a7f24a64524d4e59ee50e3fff106eb41e09383245f",
    "scripts/ui/pixel_scene_canvas.gd": "c2ce2abee8827372d66fd6c9647a74e06f5db8fed520bbd812b8c7eb29f4af38",
    "scripts/ui/environment_art_renderer.gd": "900b44af05602f6259eed0a2cb33a45d1899cb30bd71aaaed5a744bcc9ccad96",
    "scripts/ui/environment_art_pack.gd": "067cf5f9673bd85705f4971e9c4db70aaafcfe1cec912b926ed9edc685fb5d8f",
    "tools/bar_spatial_candidate_check.py": "bb0c9fd70fe4c4941d8d1019c682b691db48e5224606340a7e84e6c48dd3837f",
    "tools/bth_qa_storage.py": "cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837",
}
EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-contexts-01/evidence")
METADATA = EVIDENCE / "__none_metadata.json"
METADATA_SHA = "3cdf393984aa8dbcf6e8e92e6178611fefffec8541e67c6e144a5c0ecda78480"
MASK_PINS = {
    "__none_host_0_adorn.png": {
        "kind": "adorn",
        "object_id": "staff:grand_casino_linda",
        "sha256": "f2042f53b0de90853b8ee9a3b02f2f0909477e9355c6cc73c7257d2f48d90558"
    },
    "__none_host_0_body.png": {
        "kind": "body",
        "object_id": "staff:grand_casino_linda",
        "sha256": "598a55a80b694a63efffa352def2be1dad5bd0a67e265c7ef681b369059266af"
    },
    "__none_host_1_adorn.png": {
        "kind": "adorn",
        "object_id": "casino_fixture:cage_atm",
        "sha256": "904fef1387697f7c8f0fd32cbc22711a9f43aeb2ccd66c3991bb0a739b7a1366"
    },
    "__none_host_1_body.png": {
        "kind": "body",
        "object_id": "casino_fixture:cage_atm",
        "sha256": "34b10a71fb3ba0d27cf410443f508ca6e88377ca8685c9bda6eb301a5956c3f8"
    },
    "__none_host_2_adorn.png": {
        "kind": "adorn",
        "object_id": "casino_fixture:cage_counter",
        "sha256": "f4b56240540bdb2291a907b5eda58fa01ffa9177941069f3180927a17beb3600"
    },
    "__none_host_2_body.png": {
        "kind": "body",
        "object_id": "casino_fixture:cage_counter",
        "sha256": "92fa9f16e023df8b08a96a0fb7e207079f56011d2d86c7fa176c529fe641d194"
    },
    "__none_host_3_adorn.png": {
        "kind": "adorn",
        "object_id": "travel:grand_casino",
        "sha256": "29a4fb1500b29cb94a2639431836f092f955fa0aac2a606fcbe5b281bb02c84a"
    },
    "__none_host_3_body.png": {
        "kind": "body",
        "object_id": "travel:grand_casino",
        "sha256": "eeae7524b954523fa18be32f09d6556bd1fe9c46eb14fbcc19f55356281bfe8a"
    },
    "__none_host_4_adorn.png": {
        "kind": "adorn",
        "object_id": "travel:leave",
        "sha256": "a77e00fcefc93493ba355f11b5090f70d17d0a57cd23b8503703cec1703e6cea"
    },
    "__none_host_4_body.png": {
        "kind": "body",
        "object_id": "travel:leave",
        "sha256": "94dd68af353e2cba8876c9db444ee493240a1179b1190931b5de4ef0ac1333a7"
    }
}
CUSTODY_SCHEMA = "sha256(sorted UTF8 project-relative path + TAB + lowercase_sha256 + LF); includes final LF"
ORIGINAL24_SEAL = "dcd9781169080f546281b942773a18f106965d9811b360cc86fe432d0ac62584"
IGNORE = b"# Non-active Cage source/baseline/candidates; exclude from Godot discovery.\n"
GIB = 1024 ** 3
MAX_BYTES = 32 * 1024 ** 2
CLIP = (668, 72, 464, 112)
COMPONENTS = (
    (140, (350, 44, 367, 66)), (233, (369, 44, 387, 66)),
    (186, (392, 44, 405, 67)), (174, (415, 44, 432, 67)),
    (224, (433, 44, 453, 67)), (241, (454, 44, 473, 67)),
    (185, (476, 44, 490, 66)),
)
MOTION_IDS = ("cage_sign_pulse", "atm_scan", *("cage_glint_" + str(i) for i in range(11)),
              *("floor_glint_" + str(i) for i in range(7)))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def same(a, b):
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


def ordinary(path, *, exists=True):
    path = Path(path)
    require(path.is_absolute(), "Explicit absolute ordinary path required: " + str(path))
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
    require(path.is_file() and path.stat().st_size <= MAX_BYTES, "Missing/oversized input: " + str(path))
    data = path.read_bytes()
    require(len(data) <= MAX_BYTES, "Input exceeded byte bound: " + str(path))
    return data


def inventory(root, names):
    return {name: sha(read(root / name)) for name in sorted(names)}


def custody(values):
    # Deliberately not the space/LF seal used by other room helpers.
    return sha("".join(name + "\t" + value + "\n" for name, value in sorted(values.items())).encode("utf-8"))


def payload_contract(values):
    require(values == PAYLOAD_PINS and len(values) == 24 and custody(values) == ORIGINAL24_SEAL,
            "Frozen24-file Cage custody differs")
    return {"file_count": 24, "room_file_count": 23, "seal": ORIGINAL24_SEAL,
            "room23_seal": custody({name: value for name, value in values.items() if name != INDEX}),
            "global_index_separate": True, "canonical_sidecar_is_control_not_payload": True}


def expected_directories(names):
    result = set()
    for name in names:
        p = PurePosixPath(name)
        require(p.as_posix() == name and not p.is_absolute() and
                all(x not in ("", ".", "..") for x in p.parts) and "\\" not in name and ":" not in name,
                "Unsafe physical member: " + name)
        result.update(x.as_posix() for x in p.parents if x != PurePosixPath("."))
    return result


def physical_tree(root):
    root = ordinary(root, exists=False)
    if not root.exists():
        return {"exists": False, "files": [], "directories": []}
    require(root.is_dir(), "Tree root must be an ordinary directory: " + str(root))
    files, directories, pending = set(), set(), [root]
    while pending:
        directory = pending.pop()
        ordinary(directory)
        for path in sorted(directory.iterdir()):
            ordinary(path)
            info = path.lstat()
            name = path.relative_to(root).as_posix()
            expected_directories((name,))
            if stat.S_ISDIR(info.st_mode):
                directories.add(name)
                pending.append(path)
            else:
                require(stat.S_ISREG(info.st_mode), "Nonregular member: " + str(path))
                files.add(name)
    return {"exists": True, "files": sorted(files), "directories": sorted(directories)}


def check_membership(tree, names, *, sentinel=False, absent=False):
    if not tree["exists"]:
        require(absent, "Expected physical tree is absent")
        return
    files, directories = set(tree["files"]), set(tree["directories"])
    expected = set(names)
    # Only this exact root sentinel may be present; no basename exclusions.
    allowed = expected | ({".gdignore"} if sentinel else set())
    require(files <= allowed, "Unknown physical files: " + str(sorted(files - allowed)))
    require(files - ({".gdignore"} if sentinel else set()) == expected, "Incomplete logical physical membership")
    require(directories == expected_directories(files), "Unknown or empty physical directories")


def check_tree(root, values, *, sentinel=False, absent=False, require_sentinel=False):
    tree = physical_tree(root)
    check_membership(tree, values, sentinel=sentinel, absent=absent)
    if tree["exists"]:
        if ".gdignore" in tree["files"]:
            require(sentinel and read(root / ".gdignore") == IGNORE, "Unknown root sentinel bytes")
        require(not require_sentinel or ".gdignore" in tree["files"], "Exact root sentinel absent")
        require(inventory(root, values) == values, "Physical member hashes differ")
    return tree


def pixel(image, x, y):
    require(0 <= x < image.width and 0 <= y < image.height, "Pixel outside input")
    at = (y * image.width + x) * 4
    return image.rgba[at:at + 4]


def nn2(image):
    require(image.width % 2 == image.height % 2 == 0, "Even NN2 dimensions required")
    for y in range(0, image.height, 2):
        for x in range(0, image.width, 2):
            value = pixel(image, x, y)
            require(all(pixel(image, x + dx, y + dy) == value for dx, dy in ((1, 0), (0, 1), (1, 1))),
                    "Nonuniform original NN2 block")


def gold(rgb):
    r, g, b = rgb
    return r >= 100 and g >= 70 and 10 * r >= 9 * g and 4 * g >= 5 * b


def components(points):
    remaining, result = set(points), []
    while remaining:
        first = min(remaining)
        remaining.remove(first)
        pending, found = [first], [first]
        while pending:
            x, y = pending.pop()
            for q in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if q in remaining:
                    remaining.remove(q)
                    pending.append(q)
                    found.append(q)
        result.append((len(found), (min(x for x, y in found), min(y for x, y in found),
                                   max(x for x, y in found) + 1, max(y for x, y in found) + 1)))
    return tuple(sorted(result, key=lambda row: row[1]))


def support_contract(local):
    """Require the source-traced seven fixed glyph components, not just a bbox."""
    ox, oy, width, height = CLIP
    require(len(local) == 5532 and all(type(x) is int and type(y) is int and
            0 <= x < width and 0 <= y < height for x, y in local),
            "Expected5532 bounded native gold glyph texels")
    board = {((ox + x) // 2, (oy + y) // 2) for x, y in local}
    require(len(board) == 1383 and components(board) == COMPONENTS, "Exact seven glyph components differ")
    require(local == {(2 * bx + dx - ox, 2 * by + dy - oy) for bx, by in board
                      for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1))}, "Glyph support must retain full NN2 blocks")
    require((min(x for x, y in local), min(y for x, y in local),
             max(x for x, y in local) + 1, max(y for x, y in local) + 1) == (32, 16, 312, 62),
            "Gold support bounds differ")
    return local


def glyph_support(background):
    require((background.width, background.height) == (1800, 860) and
            background.rgba[3::4] == b"\xff" * (1800 * 860),
            "Exact opaque native Cage background required")
    nn2(background)
    ox, oy, width, height = CLIP
    local = {(x, y) for y in range(height) for x in range(width)
             if gold(pixel(background, ox + x, oy + y)[:3])}
    return support_contract(local)


def original_sign(image):
    require((image.width, image.height) == (464, 112), "Exact sign atlas dimensions required")
    nn2(image)
    require(Counter(tuple(image.rgba[i:i + 4]) for i in range(0, len(image.rgba), 4)) ==
            {(255, 228, 92, 46): 49376, (255, 228, 92, 255): 2592}, "Original sign RGBA census differs")
    for y in range(112):
        for x in range(464):
            require(pixel(image, x, y)[3] == (255 if 16 <= x < 448 and 92 <= y < 98 else 46),
                    "Original sign underline/rectangle positions differ")


def verify_cut(before, after, support):
    require((before.width, before.height) == (after.width, after.height) == (464, 112), "Cut dimensions differ")
    original_sign(before)
    support_contract(support)
    changed = kept = removed = 0
    for y in range(112):
        for x in range(464):
            old, new = pixel(before, x, y), pixel(after, x, y)
            require(old[:3] == new[:3], "RGB changed during alpha-only cut")
            expected = old[3] if (x, y) in support else 0
            require(new[3] == expected, "Cut alpha differs from exact source mask")
            if (x, y) in support:
                require(old[3] == new[3] == 46, "Selected glyph old alpha46 must remain unchanged")
                kept += 1
            else:
                removed += 1
            changed += old != new
    require((kept, removed, changed) == (5532, 46436, 46436), "Cut census differs")
    nn2(after)
    return {"retained_alpha46_native_texels": kept, "outside_alpha_cuts": removed,
            "changed_native_texels": changed, "rgb_all_original_exact": True,
            "selected_original_alpha_exact": True, "NN2_exact": True}


def cut_alpha(image, support):
    original_sign(image)
    support_contract(support)
    data = bytearray(image.rgba)
    for y in range(112):
        for x in range(464):
            if (x, y) not in support:
                data[(y * 464 + x) * 4 + 3] = 0
    result = PNGImage(464, 112, bytes(data))
    return result, verify_cut(image, result, support)


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def encode_png(image):
    stride = image.width * 4
    rows = b"".join(b"\0" + image.rgba[y * stride:(y + 1) * stride] for y in range(image.height))
    return (b"\x89PNG\r\n\x1a\n" +
            chunk(b"IHDR", struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def manifest_contract(data):
    value = json.loads(data)
    require(value["environment_id"] == ROOM and value["board_size"] == [900, 430] and value["pixel_scale"] == 2,
            "Exact Cage manifest identity required")
    rows = value["animations"]
    require(tuple(row["id"] for row in rows) == MOTION_IDS and len(rows) == 20 and
            sum(row["web_low_detail"] is True for row in rows) == 16, "Exact20native/16low Cage inventory required")
    require(value["counters"] == {"grand_cage_teller_counter": {"texture": "counters/grand_cage_teller_counter.png"}},
            "Exact one teller counter required")
    names = {BACKGROUND, MANIFEST, COUNTER, *(ART + row["texture"] for row in rows)}
    expected_directories(names)
    require(names == set(PAYLOAD_PINS) - {INDEX} and len(names) == 23, "Exact23 room payloads required")
    return value


def canonical_contract(data):
    require(sha(data) == CANONICAL_IMPORT_SHA, "Canonical one-sign import absent or differs; root must apply reviewed metadata")
    text = data.decode("utf-8")
    require('uid="' + CANONICAL_UID + '"' in text and 'path="' + CANONICAL_TARGET + '"' in text and
            'source_file="res://' + SIGN + '"' in text, "Existing canonical sign UID/remap/source binding differs")


def metadata_application_contract(data):
    require(sha(data) == METADATA_APPLICATION_SHA, "Exact guarded canonical metadata application receipt required")
    value = json.loads(data)
    pair = value["pairs"]["Cage"]
    require(value["schema"] == "bth.private_cage_spatial_metadata_application/v1" and
            value["status"] == "EXACT_TWO_CANONICAL_IMPORT_ADDITIONS_VERIFIED" and
            pair["target"] == CANONICAL_IMPORT and pair["sidecar_sha256"] == CANONICAL_IMPORT_SHA and
            pair["only_one_target_added_all_prior_room_prefix_and_PNG_JSON_index_bytes_preserved"] is True and
            value["no_PNG_JSON_runtime_profile_or_save_changes"] is True,
            "Applied Cage canonical metadata receipt scope differs")
    return {"path": METADATA_APPLICATION, "sha256": METADATA_APPLICATION_SHA,
            "status": value["status"], "Cage_pair": pair,
            "scope": "Pinned historical root-owned guarded metadata application; no metadata copied by this worker."}


def checkpoint_contract(transport, provenance):
    require(sha(transport) == CHECKPOINT_TRANSPORT_SHA and sha(provenance) == CHECKPOINT_PROVENANCE_SHA,
            "Exact unexecuted assembler checkpoint transport/provenance required")
    raw = base64.b64decode(b"".join(transport.split()), validate=True)
    record = json.loads(provenance)
    require(len(raw) == 34120 and sha(raw) == DRAFT_CHECKPOINT_SHA and
            record["schema"] == "bth.cage_alpha_assembler_checkpoint/v1" and
            record["checkpoint_sha256"] == DRAFT_CHECKPOINT_SHA and record["checkpoint_bytes"] == len(raw) and
            record["status"] == "UNEXECUTED_DRAFT_PRESERVED_BEFORE_REVIEW_HARDENING",
            "Preserved Cage draft source identity differs")
    return {"sha256": DRAFT_CHECKPOINT_SHA, "bytes": len(raw), "transport": CHECKPOINT_TRANSPORT,
            "transport_sha256": CHECKPOINT_TRANSPORT_SHA, "status": record["status"],
            "reason": "Explicit fixed support contract, applied-metadata receipt binding and focused regressions added before any execution."}


def counter_proof(background, counter):
    require((counter.width, counter.height) == (776, 112), "Exact teller replay dimensions required")
    for y in range(112):
        for x in range(776):
            require(pixel(counter, x, y) == pixel(background, 520 + x, 520 + y) and pixel(counter, x, y)[3] == 255,
                    "Teller replay must remain opaque exact final-background crop")
    return {"native_rect_xyxy": [520, 520, 1296, 632], "equal_opaque_native_pixels": 86912,
            "one_same_final_master_replay": True}


def typed_mapping(metadata):
    rows = metadata["source_paint"]["objects"]
    require(metadata["source_paint"]["geometry_equal"] is True and len(rows) == 5 and
            len(metadata["selected_label_evidence"]) == 5, "Exact historical five Base objects/selection captures required")
    result = {}
    for row in rows:
        for kind in ("body", "adorn"):
            name = row[kind + "_png"]
            require(name not in result and PurePosixPath(name).name == name, "Duplicate/unsafe typed mask name")
            result[name] = (row["object"]["id"], kind)
    require(result == {name: (v["object_id"], v["kind"]) for name, v in MASK_PINS.items()},
            "Historical ten typed-mask mapping differs")
    return result


def typed_proof(support):
    metadata_bytes = read(METADATA)
    require(sha(metadata_bytes) == METADATA_SHA, "Retained source-paint metadata differs")
    mapping = typed_mapping(json.loads(metadata_bytes))
    ox, oy, _, _ = CLIP
    report, hashes = [], {str(METADATA): METADATA_SHA}
    for name in sorted(mapping):
        data = read(EVIDENCE / name)
        require(sha(data) == MASK_PINS[name]["sha256"], "Frozen actual typed mask differs: " + name)
        image = decode_png(data)
        require((image.width, image.height) == (1800, 860), "Typed mask native dimensions differ")
        alpha0 = sum(pixel(image, ox + x, oy + y)[3] > 0 for x, y in support)
        alpha64 = sum(pixel(image, ox + x, oy + y)[3] >= 64 for x, y in support)
        require(alpha0 == alpha64 == 0, "Gold support intersects actual painted body/adornment: " + name)
        hashes[str(EVIDENCE / name)] = sha(data)
        report.append({"path": str(EVIDENCE / name), "sha256": sha(data), "object_id": mapping[name][0],
                       "kind": mapping[name][1], "glyph_alpha_gt0": alpha0, "glyph_alpha_ge64": alpha64})
    return {"scope": "Historical R2 Base at retained clocks; not all lifecycle/populations or fresh native acceptance",
            "ten_actual_masks": report, "input_hashes": hashes, "all_glyph_alpha_contacts_zero": True}


def budget(expected, reserve, total, free):
    # Storage amounts come exclusively from the admitted configured layout.
    # CPU1200 and Job-memory2147483648 are process caps, never disk headroom.
    require(expected >= 4 * GIB and reserve >= 20 * GIB, "At least4GiB expected+20GiB reserve required")
    require(total > 0 and 0 <= free <= total, "Invalid volume capacity sample")
    required = expected + reserve
    require(free >= required, "E: capacity below configured expected writes plus reserve; no fallback")
    return {"total_bytes": total, "free_bytes": free, "expected_write_bytes": expected,
            "reserve_bytes": reserve, "required_free_bytes": required,
            "minimum_projected_headroom_bytes": reserve, "projected_free_bytes": free - expected,
            "rule": "configured_expected_write_bytes + configured_reserve_bytes; maintained storage validation unchanged"}


def failed_attempt_history():
    job_bytes, log_bytes = read(FAILED_EVIDENCE / "job.json"), read(FAILED_EVIDENCE / "worker.log")
    require(sha(job_bytes) == FAILED_JOB_SHA and sha(log_bytes) == FAILED_LOG_SHA,
            "Exact preserved pre-art failed Cage v1 Job/log required")
    job, log = json.loads(job_bytes), json.loads(log_bytes)
    require(job["pid"] == 32548 and job["exit_code"] == 1 and job["active_at_release"] == 0 and
            job["assigned_before_execution"] is True and job["limits"]["cpu_rate"] == 1200 and
            job["limits"]["job_memory_limit_bytes"] == 2147483648 and job["limits"]["kill_on_close"] is True and
            job["limits"]["breakaway_allowed"] is False and not job.get("error") and
            not job.get("cleanup_errors") and not job.get("timed_out") and
            log["status"] == "CAGE_ALPHA_ASSEMBLY_STOPPED" and
            "20GiB/12percent/2GiB headroom" in log["error"] and log["active_files_written"] is False and
            all(row["available_bytes"] == FAILED_CAPACITY["available_bytes_at_launch"]
                for row in job["storage_gate_before_child"].values()),
            "Preserved v1 configured-storage pass/extra-rule failure facts differ")
    return {"previous_assembler_sha256": PREVIOUS_ASSEMBLER_SHA, "previous_tests_sha256": PREVIOUS_TESTS_SHA,
            "status": "V1_STOPPED_BEFORE_ART_WRITES_UNREQUESTED_DISK_RULE",
            "failed_job": {"path": str(FAILED_EVIDENCE / "job.json"), "sha256": FAILED_JOB_SHA,
                "log_sha256": FAILED_LOG_SHA, "pid": 32548, "exit_code": 1, "active_at_release": 0,
                "actual_cpu_rate": 1200, "actual_job_memory_limit_bytes": 2147483648},
            "recorded_capacity": FAILED_CAPACITY,
            "correction": "Remove only unrequested percentage-volume/2GiB disk rule. Preserve maintained validate_layout, configured4GiB+20GiB minimum and immediate-before-write gates. Actual CPU/memory Job caps stay unchanged.",
            "old_helpers_preserved": True, "old_launch_retried": False, "drive_or_security_changed": False}

def gate(layout, paths=()):
    observations = validate_layout(layout, extra_write_paths=paths)
    require(layout.prepared and same(layout.root, Path("E:/CodexQA/BTH")) and same(layout.workspace, WORKSPACE),
            "Exact prepared E: Cage campaign required")
    usage = shutil.disk_usage(ordinary(layout.root))
    return {"storage_validation": observations,
            "capacity": budget(layout.expected_write_bytes, layout.reserve_bytes, usage.total, usage.free)}


def admitted_layout():
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    record = json.loads(read(evidence / "storage-manifest.json"))
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
                    **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    require(same(evidence, layout.evidence), "Environment evidence directory differs from admitted manifest")
    gate(layout)
    return layout


def write_fresh(path, data, layout):
    gate(layout, (path.parent, path))
    ordinary(path, exists=False)
    require(not path.exists(), "Fresh exclusive output required: " + str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    ordinary(path.parent)
    with path.open("xb") as handle:
        handle.write(data)


def path_contract(args, layout):
    paths = {name: ordinary(getattr(args, name), exists=name in ("source_root", "workspace"))
             for name in ("source_root", "workspace", "baseline_root", "candidate_root", "report", "pixel_proof")}
    require(same(paths["source_root"], SOURCE_ROOT) and same(paths["workspace"], WORKSPACE) and
            same(paths["workspace"], layout.workspace), "Exact read-only art source/admitted Cage workspace required")
    sources = layout.workspace / "candidate_sources"
    expected = {"baseline_root": layout.workspace / "source_baseline",
                "candidate_root": sources / "cage-spatial-r1-alpha-mask",
                "report": layout.evidence / "cage-spatial-r1-assembly.json",
                "pixel_proof": layout.evidence / "cage-spatial-r1-glyph-proof.json"}
    require(all(same(paths[name], value) for name, value in expected.items()), "Exact explicit Cage output paths required")
    for name in ("candidate_root", "report", "pixel_proof"):
        require(not paths[name].exists(), "Immutable output already exists: " + str(paths[name]))
    require({p.name for p in layout.workspace.iterdir()} <= {"source_baseline", "candidate_sources"},
            "Unknown campaign-root paths; preserve and stop")
    for path in layout.workspace.iterdir():
        require(ordinary(path).is_dir(), "Campaign root members must be ordinary directories")
    gate(layout, (*expected.values(), sources))
    return paths, sources


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source-root", "workspace", "baseline-root", "candidate-root", "report", "pixel-proof"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        layout = admitted_layout()
        paths, sources = path_contract(args, layout)
        source, baseline, output = paths["source_root"], paths["baseline_root"], paths["candidate_root"]
        names = tuple(sorted(PAYLOAD_PINS))
        recipe_sha = sha(read(__file__))
        before = inventory(source, set(names) | set(CONTROL_PINS))
        payload_contract({n: before[n] for n in names})
        require({n: before[n] for n in CONTROL_PINS} == CONTROL_PINS, "Frozen source/control differs")
        canonical_contract(read(source / CANONICAL_IMPORT))
        metadata_application = metadata_application_contract(read(source / METADATA_APPLICATION))
        checkpoint = checkpoint_contract(read(source / CHECKPOINT_TRANSPORT), read(source / CHECKPOINT_PROVENANCE))
        storage_correction = failed_attempt_history()
        # Canonical control is required in source, never copied into logical24.
        art_hashes = {n[len(ART):]: before[n] for n in names if n.startswith(ART)}
        art_hashes["anim/cage_sign_pulse.png.import"] = CANONICAL_IMPORT_SHA
        art_tree_before = check_tree(source / ART, art_hashes)
        payload = {n: read(source / n) for n in names}
        manifest_contract(payload[MANIFEST])
        require(sum(n.endswith(".png") for n in names) == 22, "Exactly22 original PNGs required")
        for name in names:
            if name.endswith(".png"):
                nn2(decode_png(payload[name]))
        bg, sign, counter = (decode_png(payload[n]) for n in (BACKGROUND, SIGN, COUNTER))
        replay = counter_proof(bg, counter)
        support = glyph_support(bg)
        result, proof = cut_alpha(sign, support)
        risks = typed_proof(support)
        payload[SIGN] = encode_png(result)
        require(decode_png(payload[SIGN]) == result, "Encoded cut PNG roundtrip differs")
        hashes = {n: sha(data) for n, data in payload.items()}
        require([n for n in names if hashes[n] != PAYLOAD_PINS[n]] == [SIGN], "Only one sign PNG may change")
        physical_before = {"baseline": check_tree(baseline, PAYLOAD_PINS, sentinel=True, absent=True),
                           "candidate_sources": check_tree(sources, {}, sentinel=True, absent=True)}
        def custody_unchanged():
            require(inventory(source, before) == before and sha(read(__file__)) == recipe_sha and
                    check_tree(source / ART, art_hashes) == art_tree_before and
                    all(sha(read(Path(p))) == h for p, h in risks["input_hashes"].items()) and
                    failed_attempt_history() == storage_correction,
                    "Source/recipe/canonical/retained masks changed during assembly")
        custody_unchanged()
        support_bytes = bytes(1 if (x, y) in support else 0 for y in range(112) for x in range(464))
        pixel_record = {"schema": "bth.cage_sign_alpha_provenance/v1", "background": BACKGROUND,
                        "background_sha256": PAYLOAD_PINS[BACKGROUND], "atlas_origin_native": [668, 72],
                        "atlas_size": [464, 112], "predicate": "R>=100 && G>=70 && 10*R>=9*G && 4*G>=5*B",
                        "mask_encoding": "464x112 row-major bytes0/1; exact native glyph support",
                        "mask_sha256": sha(support_bytes), "selected_native_xy": [list(p) for p in sorted(support, key=lambda p: (p[1], p[0]))],
                        "four_connected_board_components": COMPONENTS, "alpha_proof": proof,
                        "not_a_generated_or_inferred_furniture_mask": True}
        pixel_bytes = (json.dumps(pixel_record, separators=(",", ":")) + "\n").encode()
        capacity_before = gate(layout, (baseline, sources, output, paths["report"], paths["pixel_proof"]))
        require(physical_before == {"baseline": check_tree(baseline, PAYLOAD_PINS, sentinel=True, absent=True),
                                    "candidate_sources": check_tree(sources, {}, sentinel=True, absent=True)},
                "Physical input membership changed during no-write preflight")
        # FIRST WRITES: all exact source, canonical, typed and pixel proofs passed.
        for directory in (baseline, sources):
            gate(layout, (directory,))
            ordinary(directory, exists=False)
            directory.mkdir(exist_ok=True)
            if not (directory / ".gdignore").exists():
                write_fresh(directory / ".gdignore", IGNORE, layout)
        if not physical_before["baseline"]["exists"]:
            for name in names:
                write_fresh(baseline / name, read(source / name), layout)
        gate(layout, (output,))
        ordinary(output, exists=False)
        output.mkdir()
        for name in names:
            write_fresh(output / name, payload[name], layout)
        write_fresh(paths["pixel_proof"], pixel_bytes, layout)
        final_sources = {output.name + "/" + name: value for name, value in hashes.items()}
        physical_after = {"baseline": check_tree(baseline, PAYLOAD_PINS, sentinel=True, require_sentinel=True),
                          "candidate": check_tree(output, hashes),
                          "candidate_sources": check_tree(sources, final_sources, sentinel=True, require_sentinel=True)}
        custody_unchanged()
        require(read(paths["pixel_proof"]) == pixel_bytes, "Pixel provenance output differs")
        report = {"schema": "bth.cage_spatial_assembly/v2", "task_id": TASK, "room": ROOM,
                  "status": "NON_ACTIVE_ALPHA_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT",
                  "observed_at": datetime.now(timezone.utc).isoformat(), "recipe_sha256": recipe_sha,
                  "recipe_history": [checkpoint, storage_correction], "canonical_metadata_application": metadata_application,
                  "storage_manifest": str(layout.manifest_path), "storage_manifest_sha256": sha(read(layout.manifest_path)),
                  "storage_and_capacity_before_writes": capacity_before,
                  "custody_schema": CUSTODY_SCHEMA,
                  "baseline": {"path": str(baseline), "files": PAYLOAD_PINS, "seal": custody(PAYLOAD_PINS),
                               "room23_seal": custody({n: h for n, h in PAYLOAD_PINS.items() if n != INDEX}),
                               "index_control": {INDEX: PAYLOAD_PINS[INDEX]}},
                  "output": {"path": str(output), "files": hashes, "seal": custody(hashes), "file_count": 24,
                             "room_file_count": 23, "room23_seal": custody({n: h for n, h in hashes.items() if n != INDEX}),
                             "index_control": {INDEX: hashes[INDEX]}},
                  "changed_payload_paths": [SIGN], "alpha_cut": proof, "counter_replay": replay,
                  "historical_actual_typed_proof": risks,
                  "pixel_provenance": {"path": str(paths["pixel_proof"]), "sha256": sha(pixel_bytes)},
                  "source_hashes_before": before, "source_hashes_after": inventory(source, before),
                  "physical_membership_before": physical_before, "physical_membership_after": physical_after,
                  "canonical_import_control": {"path": str(source / CANONICAL_IMPORT), "sha256": CANONICAL_IMPORT_SHA,
                                               "uid": CANONICAL_UID, "auto_copied": False},
                  "all_sources_unchanged": True, "full_manifest_index_and_other21_PNGs_byte_exact": True,
                  "native20_default_low16_unchanged": True, "all_existing_positions_and_scheduling_unchanged": True,
                  "active_files_written": False, "runtime_launched": False, "art_approval": False, "test_updated": False,
                  "limitations": ["Historical single-Base10mask proof is not lifecycle/all-population qualification.",
                                  "Glyph brightness and real-clock motion require fresh independent native review.",
                                  "No generated geometry, current native/TEST approval or reached stocked-shop claim."]}
        write_fresh(paths["report"], (json.dumps(report, indent=2) + "\n").encode(), layout)
        custody_unchanged()
        require(check_tree(output, hashes) == physical_after["candidate"] and
                check_tree(baseline, PAYLOAD_PINS, sentinel=True, require_sentinel=True) == physical_after["baseline"] and
                check_tree(sources, final_sources, sentinel=True, require_sentinel=True) == physical_after["candidate_sources"],
                "Final exact output membership/custody differs")
        print(json.dumps({"status": report["status"], "package": str(output), "report": str(paths["report"]),
                          "pixel_provenance": str(paths["pixel_proof"]), "art_approval": False}))
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        print(json.dumps({"status": "CAGE_ALPHA_ASSEMBLY_V2_STOPPED", "error": str(error),
                          "active_files_written": False, "runtime_launched": False, "art_approval": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
