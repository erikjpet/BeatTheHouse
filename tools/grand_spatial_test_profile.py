"""Fixed Grand public policy for the shared, guarded art TEST build flow.

No launches or writes. Future independent approval supplies exact candidate
hashes, never an arbitrary path allowlist. Bar remains the executor's default.
"""
import sys
sys.dont_write_bytecode = True

import hashlib
import json
from pathlib import Path
import re


ENVIRONMENT = "grand_casino"
TASK_ID = "BTH-ENV-SPATIAL-GRAND-001"
SCHEMA = "bth.grand_spatial_test_approval/v1"
SERVED_SCHEMA = "bth.grand_spatial_test_served/v1"
BASE_SOURCE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116")
BASE_STAGE = BASE_SOURCE / ".tmp/web-release-7b284648/stage"
BASE_COMMIT = "7b284648642a896e534c8bfd53c8e7abbc55108d"
BASE_TREE = "f7d316a268984bfdd7fafef71d0971c9fff0956e"
BASE_MANIFEST_SHA = "5855381ff2137ece43c2b097b169c70c50b658f1caa6d86e1461b42b22bbe447"
BASE_PCK_SHA = "a84ed267a7d664ada937d441be1d053419fe78df5e6725e217c99d60b0bc4ba1"
BASE_GRAND_JSON_SHA = "5cc2d0c568552a88557f0f0eee89655bc86a5e73c535e822e09b267901044bcd"
BAR_SEAL = "e001ad4d76344f0bb2e0542a21fa3f4936656c8c2a63ace475a6294cb9ca723e"
GRAND_JSON = "data/art/environments/grand_casino.json"
INDEX_JSON = "data/art/environments/index.json"
ROOT = "assets/art/environments/grand_casino/"
IMPORT_SHAS = {
    ROOT + "background.png": "1384297708d0753553bf0c74e751a9cf233b9c3e16a7e9ec01697afd91787dcf",
    ROOT + "counters/grand_table_left.png": "16f7065e0029362e735da3b7ad9b7e23a5a2bd913f5d98ea08305517b99e2642",
    ROOT + "counters/grand_table_right.png": "17f72268fffefead2f7b887f2ec0e51022572eca626dad54bc0ca4fbb83cf862",
    ROOT + "anim/casino_sign_pulse.png": "29d7e8253debc93923c829beadc832f181a9953934c8c6aa21ed11de89af717d",
    ROOT + "anim/casino_light_0.png": "b15c84e29e1303ef89135cde55a58885313016c38af7ed12585ba936d8116bfe",
    ROOT + "anim/casino_light_1.png": "ecc363e9dfd36ba5cb212255dc7b9678cb135981a92bd5fa6406293d1c52c9eb",
    ROOT + "anim/casino_light_2.png": "8d9c78b142032a74f6bfe8a1245ac3b26f3f26c5d1543ed7c27735c6662a4c27",
    ROOT + "anim/casino_light_3.png": "f2e29bd897e0d3c0be108b958c1a9aa8c81daadc03f6764abebbe63cfac5f4c2",
    ROOT + "anim/casino_light_4.png": "9b7914e48b145de3d6360525c658c79c3df299facd3fda7bfbf5acac2b09a944",
}
LOW_DETAIL_IDS = {"casino_light_1", "casino_light_2", "casino_light_3", "casino_sign_pulse",
                  "floor_glint_0", "floor_glint_1", "floor_glint_2"}


def sha(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for part in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(part)
    return result.hexdigest()


def plain(path):
    path = Path(path).absolute()
    for item in (path, *path.parents):
        if item.is_symlink() or getattr(item, "is_junction", lambda: False)():
            raise ValueError("Grand profile rejects aliased input: " + str(item))
    return path.resolve(strict=True)


def full_hash(value, label):
    if not isinstance(value, str) or not re.fullmatch(r"[a-f0-9]{64}", value) or value == "0" * 64:
        raise ValueError("Grand approval requires full nonzero " + label)
    return value


def baseline():
    manifest_path = plain(BASE_STAGE / "build_manifest.json")
    if sha(manifest_path) != BASE_MANIFEST_SHA or sha(plain(BASE_STAGE / "index.pck")) != BASE_PCK_SHA:
        raise ValueError("Qualified 7b Grand baseline bytes differ")
    value = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    if ((value["source_commit"], value["source_tree"]) != (BASE_COMMIT, BASE_TREE) or
            len(value["art_source_files"]) != 421 or len(value["compiled_art_sha256"]) != 400 or
            value["active_art_packages"]["bar"] != BAR_SEAL):
        raise ValueError("Qualified baseline identity/inventory/Bar seal differs")
    return value


def load_approval(path, expected_sha):
    full_hash(expected_sha, "approval document SHA256")
    path = plain(path)
    if not path.is_file() or path.stat().st_size > 1024 * 1024 or sha(path) != expected_sha:
        raise ValueError("Grand approval document bytes differ or exceed the bound")
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if (value.get("schema"), value.get("environment_id"), value.get("verdict")) != (SCHEMA, ENVIRONMENT, "GO_FOR_TEST_BUILD"):
        raise ValueError("An actual independent Grand GO_FOR_TEST_BUILD approval is required")
    if (value.get("baseline_source_commit"), value.get("baseline_manifest_sha256")) != (BASE_COMMIT, BASE_MANIFEST_SHA):
        raise ValueError("Grand approval is not bound to the qualified 7b baseline")
    if (not isinstance(value.get("reviewer"), str) or not value["reviewer"].strip() or
            not isinstance(value.get("evidence"), list) or not value["evidence"] or
            any(not isinstance(item, str) or not item.strip() for item in value["evidence"])):
        raise ValueError("Independent reviewer and concrete native/numeric/visual evidence references are required")
    textures = value.get("approved_png_sha256")
    if not isinstance(textures, dict) or not 1 <= len(textures) <= 9 or not set(textures).issubset(IMPORT_SHAS):
        raise ValueError("Grand approval must enumerate the actual changed subset of the fixed nine PNG paths")
    old = baseline()
    for relative, expected in textures.items():
        full_hash(expected, "approved PNG SHA256")
        if old["art_source_files"][relative] == expected:
            raise ValueError("Approved changed PNG is actually unchanged: " + relative)
    full_hash(value.get("grand_json_sha256"), "approved Grand JSON SHA256")
    full_hash(value.get("grand_package_sha256"), "approved 22-file Grand seal")
    if value["grand_json_sha256"] == BASE_GRAND_JSON_SHA:
        raise ValueError("Approved Grand JSON must contain the single lamp0 reanchor")
    return {**value, "approval_path": str(path), "approval_sha256": expected_sha,
            "profile_sha256": sha(__file__)}


def augment_config(cfg, args):
    approval = load_approval(args.approval_json, args.approval_sha256)
    if plain(cfg["baseline_stage"]) != plain(BASE_STAGE) or cfg["art_package_sha256"] != approval["grand_package_sha256"]:
        raise ValueError("Grand build baseline or requested package differs from independent approval")
    return {**cfg, "schema": "bth.grand_test_build_inputs/v1", "environment": ENVIRONMENT, "grand_approval": approval}


def changed_sources(cfg):
    approval = cfg["grand_approval"]
    return {**approval["approved_png_sha256"], GRAND_JSON: approval["grand_json_sha256"]}


def _same_typed(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(_same_typed(left[key], right[key]) for key in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(_same_typed(a, b) for a, b in zip(left, right))
    return left == right


def check_json(raw, approval):
    original = (plain(BASE_SOURCE / GRAND_JSON)).read_bytes()
    if hashlib.sha256(original).hexdigest() != BASE_GRAND_JSON_SHA:
        raise ValueError("Retained original Grand JSON differs")
    expected = json.loads(original.decode("utf-8-sig"))
    rows = [item for item in expected["animations"] if item["id"] == "casino_light_0"]
    if len(rows) != 1 or type(rows[0]["rect"][0]) is not int or rows[0]["rect"] != [250, 124, 52, 8]:
        raise ValueError("Original Grand lamp0 contract differs")
    rows[0]["rect"][0] = 245
    candidate = json.loads(raw.decode("utf-8-sig"))
    if not _same_typed(expected, candidate) or hashlib.sha256(raw).hexdigest() != approval["grand_json_sha256"]:
        raise ValueError("Grand JSON is not exactly the approved typed lamp0 x250->245 semantic change")
    entries = candidate["animations"]
    if len(entries) != 16 or {item["id"] for item in entries if item.get("web_low_detail", True)} != LOW_DETAIL_IDS:
        raise ValueError("Grand 16-entry/7-low-detail contract differs")
    return candidate


def payload_paths(base):
    paths = {name for name in base["art_source_files"] if name.startswith(ROOT)} | {GRAND_JSON, INDEX_JSON}
    if len(paths) != 22 or len([name for name in paths if name.endswith(".png")]) != 20:
        raise ValueError("Expected the exact 22-file Grand package")
    return sorted(paths)


def seal_from_hashes(paths, hashes):
    return hashlib.sha256("\n".join(name + " " + hashes[name] for name in paths).encode()).hexdigest()


def canonical_imports(workspace):
    for relative, expected in IMPORT_SHAS.items():
        if sha(plain(Path(workspace) / (relative + ".import"))) != expected:
            raise ValueError("Canonical Grand import sidecar is absent or differs: " + relative)


def source_seal(workspace, cfg):
    base = baseline()
    approval = cfg["grand_approval"]
    canonical_imports(workspace)
    check_json((Path(workspace) / GRAND_JSON).read_bytes(), approval)
    paths = payload_paths(base)
    hashes = {name: sha(plain(Path(workspace) / name)) for name in paths}
    approved = changed_sources(cfg)
    for name, observed in hashes.items():
        if observed != approved.get(name, base["art_source_files"][name]):
            raise ValueError("Grand source differs from exact approved or retained hash: " + name)
    bar_paths = sorted(name for name in base["art_source_files"] if name.startswith("assets/art/environments/bar/") or name in ("data/art/environments/bar.json", INDEX_JSON))
    if len(bar_paths) != 19 or seal_from_hashes(bar_paths, {name: sha(plain(Path(workspace) / name)) for name in bar_paths}) != BAR_SEAL:
        raise ValueError("Previously qualified Bar package changed")
    result = seal_from_hashes(paths, hashes)
    if result != approval["grand_package_sha256"]:
        raise ValueError("Actual 22-file Grand seal differs from independent approval")
    return {"package_sha256": result, "files": {name: {"sha256": hashes[name], "bytes": (Path(workspace) / name).stat().st_size} for name in paths},
            "algorithm": "SHA256 of sorted path + space + SHA256 rows joined by LF, no trailing LF",
            "environment_id": ENVIRONMENT, "approval_sha256": approval["approval_sha256"], "preserved_bar_seal": BAR_SEAL}


def compiled_targets(approval):
    result = set()
    for relative in approval["approved_png_sha256"]:
        donor = plain(BASE_SOURCE / (relative + ".import"))
        if sha(donor) != IMPORT_SHAS[relative]:
            raise ValueError("Retained full Grand import settings differ: " + relative)
        matches = re.findall(r'^path="res://([^"\n]+)"', donor.read_text(encoding="utf-8-sig"), re.M)
        if len(matches) != 1:
            raise ValueError("Grand source has no unique compiled target: " + relative)
        result.add(matches[0])
    if len(result) != len(approval["approved_png_sha256"]):
        raise ValueError("Grand approved texture paths collapse to shared compiled targets")
    return result


def validate_manifest(manifest, approval):
    base = baseline()
    expected_raw = dict(base["art_source_files"])
    expected_raw.update(approval["approved_png_sha256"])
    expected_raw[GRAND_JSON] = approval["grand_json_sha256"]
    if manifest["art_source_files"] != expected_raw or len(expected_raw) != 421:
        raise ValueError("Grand raw inventory is not the exact approved delta plus preserved baseline")
    paths = payload_paths(base)
    if seal_from_hashes(paths, expected_raw) != approval["grand_package_sha256"] or manifest["art_package_sha256"] != approval["grand_package_sha256"]:
        raise ValueError("Grand manifest is not bound to the actual approved 22-file seal")
    expected_active = dict(base["active_art_packages"])
    expected_active[ENVIRONMENT] = approval["grand_package_sha256"]
    if (manifest["active_art_packages"] != expected_active or manifest["active_doorway_packages"] != base["active_doorway_packages"] or
            manifest["active_art_packages"]["bar"] != BAR_SEAL):
        raise ValueError("Grand activation changed a protected room/doorway package")
    compiled = manifest["compiled_art_sha256"]
    targets = compiled_targets(approval)
    if compiled.keys() != base["compiled_art_sha256"].keys() or len(compiled) != 400:
        raise ValueError("Grand compiled texture inventory changed")
    for name, prior in base["compiled_art_sha256"].items():
        full_hash(compiled[name], "compiled texture SHA256")
        if (name in targets) == (compiled[name] == prior):
            raise ValueError("Grand compiled delta does not exactly match approved changed PNGs: " + name)
    if manifest["files"].keys() != base["files"].keys():
        raise ValueError("Grand Web payload file inventory changed")
    for name, prior in base["files"].items():
        if name not in ("index.html", "index.pck") and manifest["files"][name] != prior:
            raise ValueError("Grand build changed a protected engine/native/WebGL payload: " + name)


def verify_qualified_pck(package, approval):
    """Read-only strict local PCK proof reused by served verification."""
    from bar_spatial_test_build import decode_uid_cache, pck_entry_bytes
    import audit_pck_manifest
    old = (plain(BASE_STAGE / "index.pck")).read_bytes()
    new = plain(package).read_bytes()
    if hashlib.sha256(old).hexdigest() != BASE_PCK_SHA:
        raise ValueError("Qualified Grand baseline PCK changed")
    od, nd = audit_pck_manifest.find_directory(old), audit_pck_manifest.find_directory(new)
    oe = {item["path"]: item for item in od["entries"]}
    ne = {item["path"]: item for item in nd["entries"]}
    if oe.keys() != ne.keys() or od["pack_offset"] != 0 or nd["pack_offset"] != 0:
        raise ValueError("Grand PCK resource inventory/standalone format differs")
    changed = {name for name in oe if pck_entry_bytes(old, od, oe[name]) != pck_entry_bytes(new, nd, ne[name])}
    expected = compiled_targets(approval) | {"build_manifest.json", GRAND_JSON}
    if changed != expected:
        raise ValueError("Grand PCK delta is not exact: " + repr(sorted(changed)))
    uid_path = ".godot/uid_cache.bin"
    om = decode_uid_cache(pck_entry_bytes(old, od, oe[uid_path]))
    nm = decode_uid_cache(pck_entry_bytes(new, nd, ne[uid_path]))
    if len(om) != 1605 or om != nm:
        raise ValueError("Grand full 1605-entry UID mapping differs")
    check_json(pck_entry_bytes(new, nd, ne[GRAND_JSON]), approval)
    return {"baseline_pck_sha256": BASE_PCK_SHA, "pck_sha256": hashlib.sha256(new).hexdigest(),
            "changed": sorted(changed), "resources": len(ne), "uid_bindings": 1605,
            "uid_cache_bytes_equal": True, "class_cache_bytes_equal": True, "all_scn_gdc_bytes_equal": True,
            "approved_png_count": len(approval["approved_png_sha256"])}
