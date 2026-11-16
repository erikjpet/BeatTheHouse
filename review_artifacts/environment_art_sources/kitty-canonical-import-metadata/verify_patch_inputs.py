"""Read-only verification of one background-sidecar metadata application.

Prints JSON only. No file writes, imports of project code, network or children.
The guarded caller retains before stdout in E evidence and supplies it to after.
Observed creation-time PNG/JSON hashes are provenance, not future art pins.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import struct


SCHEMA = "bth.kitty_canonical_import_metadata_check/v1"
KITTY_JSON = "data/art/environments/kitty_cat_lounge.json"
SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
W2 = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116")
STAGE = W2 / ".tmp/web-release-7b284648/stage"
KITTY_ART = "assets/art/environments/kitty_cat_lounge"
GLOBAL_INDEX = "data/art/environments/index.json"
COMMIT = "7b284648642a896e534c8bfd53c8e7abbc55108d"
TREE = "f7d316a268984bfdd7fafef71d0971c9fff0956e"
PCK_SHA = "a84ed267a7d664ada937d441be1d053419fe78df5e6725e217c99d60b0bc4ba1"
MANIFEST_SHA = "5855381ff2137ece43c2b097b169c70c50b658f1caa6d86e1461b42b22bbe447"
UID_SHA = "587514374b37d67f6c0e795cc82d840f1d4a5f9f0b0c2f3c80586ce4eb38b4db"
UID_MAP_SHA = "293bcadacffd15543a5686b5e40cc6cd409495e80628d77bc0e5e62c2eb61b55"
PNG_PATHS = (
    "assets/art/environments/kitty_cat_lounge/background.png",
)
UID_ENTRY = ".godot/uid_cache.bin"
CLASS_ENTRY = ".godot/global_script_class_cache.cfg"
CLASS_SHA = "43ed255c77d8ef9809383d0fef148e952dabddbbf434c69b0276790b6da5816d"
CLASS_MAP_SHA = "1813424138ef329623c64c769891af4bbb2ba8b329330fb2fb19026cb503addc"
MAX_META = 8 * 1024 ** 2
MAX_ENTRY = 64 * 1024 ** 2
MAX_SELECTED_TOTAL = 128 * 1024 ** 2


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 ** 2), b""):
            value.update(block)
    return value.hexdigest()


def plain(path, *, exists=True):
    path = Path(path)
    if not path.is_absolute():
        raise ValueError("Explicit absolute path required: " + str(path))
    for part in (path, *path.parents):
        if not part.exists() and not part.is_symlink():
            continue
        if (part.is_symlink() or getattr(part, "is_junction", lambda: False)() or
                getattr(part.lstat(), "st_file_attributes", 0) & 0x400):
            raise ValueError("Reparse/alias input is not admitted: " + str(part))
    resolved = path.resolve(strict=exists)
    if os.path.normcase(str(path)) != os.path.normcase(str(resolved)):
        raise ValueError("Noncanonical path is not admitted: " + str(path))
    return resolved


def small(path):
    path = plain(path)
    if not path.is_file() or path.stat().st_size > MAX_META:
        raise ValueError("Expected bounded regular input: " + str(path))
    data = path.read_bytes()
    if len(data) > MAX_META:
        raise ValueError("Input grew beyond the metadata bound")
    return data


def json_object(raw, label):
    value = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError("Expected JSON object: " + label)
    return value


def exact_read(handle, count):
    data = handle.read(count)
    if len(data) != count:
        raise ValueError("Truncated PCK/UID metadata")
    return data


def pck_payloads(path, selected):
    """Read only selected bounded payloads from the authenticated standalone PCK."""
    entries = {}
    with Path(path).open("rb") as handle:
        length = handle.seek(0, 2)
        handle.seek(0)
        if length < 112 or exact_read(handle, 4) != b"GDPC" or struct.unpack("<I", exact_read(handle, 4))[0] != 3:
            raise ValueError("Expected standalone Godot PCK v3")
        handle.seek(20)
        flags, file_base, directory_offset = struct.unpack("<IQQ", exact_read(handle, 20))
        if flags != 2 or file_base != 112 or directory_offset != 131566576 or directory_offset + 4 > length:
            raise ValueError("Encrypted or invalid PCK directory")
        handle.seek(directory_offset)
        count = struct.unpack("<I", exact_read(handle, 4))[0]
        if count != 2107:
            raise ValueError("Exact qualified PCK directory must contain 2107 entries")
        for _ in range(count):
            path_size = struct.unpack("<I", exact_read(handle, 4))[0]
            if not 1 <= path_size <= 4096:
                raise ValueError("PCK path is outside its bound")
            name = exact_read(handle, path_size).rstrip(b"\0").decode("utf-8").removeprefix("res://")
            exact_read(handle, (-path_size) % 4)
            offset, size = struct.unpack("<QQ", exact_read(handle, 16))
            md5 = exact_read(handle, 16).hex()
            entry_flags = struct.unpack("<I", exact_read(handle, 4))[0]
            if name in selected:
                start = file_base + offset
                if name in entries or entry_flags != 0 or not 0 < size <= MAX_ENTRY or start < 112 or start + size > directory_offset:
                    raise ValueError("Invalid selected PCK payload: " + name)
                entries[name] = (start, size, md5)
        if set(entries) != selected or sum(item[1] for item in entries.values()) > MAX_SELECTED_TOTAL:
            raise ValueError("Selected PCK inventory is missing or exceeds its total bound")
        payloads = {}
        for name, (start, size, md5) in entries.items():
            handle.seek(start)
            data = exact_read(handle, size)
            if hashlib.md5(data).hexdigest() != md5:
                raise ValueError("Actual PCK payload MD5 mismatch: " + name)
            payloads[name] = data
    return payloads


def uid_map(raw):
    if len(raw) < 4:
        raise ValueError("Truncated UID cache header")
    count = struct.unpack_from("<I", raw)[0]
    if count != 1605:
        raise ValueError("Expected the complete retained 1605-entry UID map")
    cursor, result, seen = 4, {}, set()
    for _ in range(count):
        if cursor + 12 > len(raw):
            raise ValueError("Truncated UID cache record")
        numeric, size = struct.unpack_from("<QI", raw, cursor)
        cursor += 12
        if not 0 < size <= 65536 or cursor + size > len(raw):
            raise ValueError("Invalid UID path size")
        path = raw[cursor:cursor + size].decode("utf-8")
        cursor += size
        name = PurePosixPath(path.removeprefix("res://"))
        if (not path.startswith("res://") or name.is_absolute() or ".." in name.parts or "\\" in path or
                "res://" + name.as_posix() != path or path in result or numeric in seen):
            raise ValueError("Noncanonical or duplicate UID binding")
        result[path] = str(numeric)
        seen.add(numeric)
    if cursor != len(raw):
        raise ValueError("UID cache trailing bytes")
    return result


def import_fields(raw):
    text = raw.decode("utf-8")
    values = {}
    for field in ("uid", "path", "source_file"):
        found = re.findall(r"^" + field + r'="([^"\n]+)"$', text, re.M)
        if len(found) > 1 or (field in ("uid", "path") and len(found) != 1):
            raise ValueError("Import metadata has an ambiguous " + field)
        values[field] = found[0] if found else None
    return values


def patch_payloads(raw):
    lines = raw.decode("utf-8").splitlines()
    if not lines or lines[0] != "*** Begin Patch" or lines[-1] != "*** End Patch":
        raise ValueError("Unexpected canonical patch envelope")
    result, current, content = {}, None, []
    for line in lines[1:]:
        if line.startswith("*** Add File: ") or line == "*** End Patch":
            if current is not None:
                if current in result:
                    raise ValueError("Duplicate patch target")
                result[current] = ("\n".join(content) + "\n").encode("utf-8")
            current = line.removeprefix("*** Add File: ") if line != "*** End Patch" else None
            if current is not None:
                prefix = SOURCE_ROOT.as_posix() + "/"
                if not current.startswith(prefix):
                    raise ValueError("Patch target must be absolute within the exact art worktree")
                current = current.removeprefix(prefix)
            content = []
        elif current is not None and line.startswith("+"):
            content.append(line[1:])
        else:
            raise ValueError("Only complete Add File sidecars are allowed in this patch")
    return result


def bindings(artifact, proof):
    patch = small(artifact / "canonical-source.patch")
    if sha_bytes(patch) != proof["patch_sha256"] or sha(__file__) != proof["verifier_sha256"]:
        raise ValueError("Reviewed patch/verifier source hash differs")
    proposed = patch_payloads(patch)
    wanted = {path + ".import" for path in PNG_PATHS}
    rows = proof["sidecars"]
    if len(rows) != 1 or {row["path"] for row in rows} != wanted or set(proposed) != wanted:
        raise ValueError("Canonical metadata must contain exactly the fixed one background-sidecar addition")
    baseline = proof["baseline"]
    manifest_path, pck_path = plain(baseline["manifest_path"]), plain(baseline["pck_path"])
    if (manifest_path != plain(STAGE / "build_manifest.json") or pck_path != plain(STAGE / "index.pck") or
            plain(baseline["workspace"]) != plain(W2) or
            baseline["manifest_sha256"] != MANIFEST_SHA or baseline["pck_sha256"] != PCK_SHA or
            baseline["source_commit"] != COMMIT or baseline["source_tree"] != TREE or
            baseline["uid_cache"]["payload_sha256"] != UID_SHA or baseline["uid_cache"]["mapping_sha256"] != UID_MAP_SHA or
            baseline["class_cache"]["payload_sha256"] != CLASS_SHA or baseline["class_cache"]["mapping_sha256"] != CLASS_MAP_SHA):
        raise ValueError("Provenance does not name the exact reviewed W2/qualified7b baseline")
    if sha(manifest_path) != baseline["manifest_sha256"] or sha(pck_path) != baseline["pck_sha256"]:
        raise ValueError("Qualified immutable 7b baseline bytes changed")
    manifest = json_object(small(manifest_path), "qualified 7b manifest")
    if (manifest.get("source_commit"), manifest.get("source_tree")) != (baseline["source_commit"], baseline["source_tree"]):
        raise ValueError("Qualified baseline source identity differs")
    selected = wanted | {row["compiled_target"] for row in rows} | {UID_ENTRY, CLASS_ENTRY}
    payloads = pck_payloads(pck_path, selected)
    mapping = uid_map(payloads[UID_ENTRY])
    mapping_sha = sha_bytes(json.dumps(mapping, sort_keys=True, separators=(",", ":")).encode())
    if sha_bytes(payloads[UID_ENTRY]) != baseline["uid_cache"]["payload_sha256"] or mapping_sha != baseline["uid_cache"]["mapping_sha256"]:
        raise ValueError("Complete baseline UID payload/map binding differs")
    if small(W2 / UID_ENTRY) != payloads[UID_ENTRY]:
        raise ValueError("Retained complete UID cache differs from actual packed cache")
    classes = payloads[CLASS_ENTRY]
    if sha_bytes(classes) != CLASS_SHA or small(W2 / CLASS_ENTRY) != classes:
        raise ValueError("Actual complete224-class packed/cache payload differs")
    pairs = re.findall(r'"class":\s*&"([^"]+)"(?:(?!"class":)[\s\S])*?"path":\s*"(res://[^"]+)"', classes.decode("utf-8"))
    class_map = dict(pairs)
    if (len(pairs) != 224 or len(class_map) != 224 or len(set(class_map.values())) != 224 or
            any(path not in mapping for path in class_map.values()) or
            sha_bytes(json.dumps(class_map, sort_keys=True, separators=(",", ":")).encode()) != CLASS_MAP_SHA):
        raise ValueError("Complete224 class-name/path and UID closure differs")
    for row in rows:
        if row["source_path"] not in PNG_PATHS or plain(row["baseline_donor"]) != plain(W2 / row["path"]):
            raise ValueError("Sidecar donor/source escaped the exact Kitty background-only scope")
        if manifest["art_source_files"].get(row["source_path"]) != row["baseline_source_sha256"]:
            raise ValueError("Retained source PNG differs from its qualified baseline manifest")
        donor = small(row["baseline_donor"])
        if sha_bytes(donor) != row["new_sha256"] or len(donor) != row["new_bytes"] or proposed[row["path"]] != donor:
            raise ValueError("Full retained donor/proposed sidecar bytes differ: " + row["path"])
        donor_fields = import_fields(donor)
        packed = payloads[row["path"]]
        packed_fields = import_fields(packed)
        expected_remap = "res://" + row["compiled_target"]
        if (sha_bytes(packed) != row["pck_import_sha256"] or len(packed) != row["pck_import_bytes"] or
                hashlib.md5(packed).hexdigest() != row["pck_import_md5"] or
                donor_fields["uid"] != row["uid"] or packed_fields["uid"] != row["uid"] or
                donor_fields["path"] != expected_remap or packed_fields["path"] != expected_remap or
                donor_fields["source_file"] != "res://" + row["source_path"] or
                row["source_path"] + ".import" != row["path"] or
                mapping.get("res://" + row["source_path"]) != row["numeric_uid"]):
            raise ValueError("UID, source, or actual PCK remap binding differs: " + row["path"])
        compiled_sha = sha_bytes(payloads[row["compiled_target"]])
        if (compiled_sha != row["baseline_compiled_sha256"] or len(payloads[row["compiled_target"]]) != row["baseline_compiled_bytes"] or
                manifest["compiled_art_sha256"].get(row["compiled_target"]) != compiled_sha):
            raise ValueError("Actual baseline CTEX differs from its qualified manifest")
        compiled = payloads[row["compiled_target"]]
        if (hashlib.md5(compiled).hexdigest() != row["baseline_compiled_md5"] or
                sha(W2 / row["compiled_target"]) != compiled_sha or
                sha(W2 / row["source_path"]) != row["baseline_source_sha256"]):
            raise ValueError("Actual W2 source/cache or CTEX payload MD5 differs")
        md5_path = plain(row["md5_record_path"])
        if md5_path != plain((W2 / row["compiled_target"]).with_suffix(".md5")):
            raise ValueError("Compiled MD5 record escaped its exact imported-cache path")
        md5_raw = small(md5_path)
        md5_text = md5_raw.decode("utf-8")
        source_md5 = re.findall(r'^source_md5="([0-9a-f]{32})"$', md5_text, re.M)
        dest_md5 = re.findall(r'^dest_md5="([0-9a-f]{32})"$', md5_text, re.M)
        if (sha_bytes(md5_raw) != row["md5_record_sha256"] or len(source_md5) != 1 or len(dest_md5) != 1 or
                source_md5[0] != row["baseline_source_md5"] or
                source_md5[0] != hashlib.md5(small(W2 / row["source_path"])).hexdigest() or
                dest_md5[0] != row["baseline_compiled_md5"]):
            raise ValueError("Actual source/destination MD5 record differs from its PNG/CTEX payloads")
    return proposed, mapping_sha, CLASS_MAP_SHA


def snapshot_source(source, proof):
    # Dynamic snapshot: separately approved later image/manifest changes are not
    # permanently constrained to this proposal's historical creation-time hashes.
    hashes = {path: sha(plain(source / path)) for path in (*PNG_PATHS, KITTY_JSON)}
    spec = json_object(small(source / KITTY_JSON), "current Kitty JSON")
    if spec.get("environment_id") != "kitty_cat_lounge" or spec.get("board_size") != [900, 430] or spec.get("pixel_scale") != 2:
        raise ValueError("Current JSON is not the exact Kitty board namespace")
    entries = spec.get("animations", [])
    inventory = {"native_entries": len(entries),
                 "web_low_detail_entries": sum(row.get("web_low_detail", True) is True for row in entries),
                 "animation_ids": [row.get("id") for row in entries],
                 "unique_animation_pngs": len({row.get("texture") for row in entries}),
                 "counter_ids": sorted(spec.get("counters", {}))}
    if (spec.get("background", {}).get("texture") != "background.png" or
            spec.get("counters", {}).get("kitty_champagne_bar", {}).get("texture") != "counters/kitty_champagne_bar.png" or
            inventory["counter_ids"] != ["kitty_champagne_bar"]):
        raise ValueError("Exact Kitty background and sole champagne-bar replay paths required")
    if inventory != proof["manifest_inventory"]:
        raise ValueError("Kitty27 native/27 default-low-detail motion entries or animation IDs changed")
    return hashes, inventory


def room_snapshot(source):
    """Observe all files under the strict room prefix, plus its JSON/index."""
    room = plain(source / KITTY_ART)
    tree = {}
    for entry in sorted(room.rglob("*")):
        entry = plain(entry)
        if entry.is_file():
            relative = entry.relative_to(source).as_posix()
            if not relative.startswith(KITTY_ART + "/") or len(tree) >= 1000:
                raise ValueError("Kitty source tree escaped scope or exceeded its bound")
            tree[relative] = sha(entry)
    png = {name: value for name, value in tree.items() if name.endswith(".png")}
    if len(png) != 29:
        raise ValueError("Expected exactly29 raw Kitty room PNGs")
    source_files = {**png, KITTY_JSON: sha(plain(source / KITTY_JSON)), GLOBAL_INDEX: sha(plain(source / GLOBAL_INDEX))}
    return tree, source_files


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--mode", choices=("before", "after"), required=True)
    parser.add_argument("--before-proof", type=Path)
    args = parser.parse_args(argv)
    report = {"schema": SCHEMA, "mode": args.mode, "status": "FAIL", "files_written": False,
              "observed_utc": datetime.now(timezone.utc).isoformat(), "art_approval": False}
    try:
        artifact = Path(__file__).resolve().parent
        proof_raw = small(artifact / "provenance.json")
        proof = json_object(proof_raw, "metadata proposal provenance")
        if proof.get("schema") != "bth.kitty_canonical_import_metadata/v1":
            raise ValueError("Unexpected canonical metadata provenance schema")
        source = plain(args.source_root)
        if source != plain(SOURCE_ROOT) or source != plain(proof["source_root"]):
            raise ValueError("Source root differs from the reviewed original worktree")
        if bool(args.before_proof) != (args.mode == "after"):
            raise ValueError("Only after mode requires --before-proof from the immediately preceding metadata check")
        proposed, mapping_sha, class_mapping_sha = bindings(artifact, proof)
        hashes, inventory = snapshot_source(source, proof)
        tree, source_files = room_snapshot(source)
        report.update(source_root=str(source), provenance_sha256=sha_bytes(proof_raw), patch_sha256=proof["patch_sha256"],
                      verifier_sha256=proof["verifier_sha256"], baseline_pck_sha256=proof["baseline"]["pck_sha256"],
                      baseline_uid_map_sha256=mapping_sha, baseline_class_map_sha256=class_mapping_sha, sidecars=1,
                      source_hash_snapshot=hashes, manifest_inventory=inventory,
                      room_file_snapshot=tree, complete_room_png_json_hash_snapshot=source_files)
        for relative, expected in proposed.items():
            target = plain(source / relative, exists=(args.mode == "after"))
            if args.mode == "before":
                if target.exists():
                    raise ValueError("Originally absent target now exists; inspect without overwrite: " + relative)
            elif small(target) != expected:
                raise ValueError("Applied sidecar is not byte-identical to its reviewed donor: " + relative)
        if args.mode == "after":
            before_path = plain(args.before_proof)
            if not before_path.is_relative_to(Path("E:/CodexQA/BTH/runs").resolve(strict=True)):
                raise ValueError("Prior stdout proof must be retained under admitted E run evidence")
            before_raw = small(before_path)
            before = json_object(before_raw, "prior before proof")
            for key in ("schema", "source_root", "provenance_sha256", "patch_sha256", "verifier_sha256", "baseline_pck_sha256", "baseline_uid_map_sha256", "baseline_class_map_sha256"):
                if before.get(key) != report.get(key):
                    raise ValueError("Prior before proof identity differs: " + key)
            if before.get("status") != "PASS" or before.get("mode") != "before":
                raise ValueError("A successful prior before proof is required")
            if before.get("source_hash_snapshot") != hashes or before.get("manifest_inventory") != inventory:
                raise ValueError("Underlying PNG/Kitty JSON changed during this metadata-only application")
            expected_tree = {**before.get("room_file_snapshot", {}), **{path: sha_bytes(data) for path, data in proposed.items()}}
            if (not before.get("room_file_snapshot") or tree != expected_tree or
                    before.get("complete_room_png_json_hash_snapshot") != source_files):
                raise ValueError("Only the background sidecar may be added; all room PNGs/JSON/index and prior files must remain exact")
            report.update(before_proof=str(before_path), before_proof_sha256=sha_bytes(before_raw), underlying_source_unchanged=True)
        report.update(status="PASS", scope="Exactly one canonical background import metadata file; current PNG/JSON snapshot applies only to this before/after pair.")
    except Exception as error:
        report.update(error_type=type(error).__name__, error=str(error))
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
