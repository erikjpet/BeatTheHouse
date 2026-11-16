"""Read-only verification of one nine-sidecar metadata application.

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


SCHEMA = "bth.grand_canonical_import_metadata_check/v1"
GRAND_JSON = "data/art/environments/grand_casino.json"
PNG_PATHS = (
    "assets/art/environments/grand_casino/background.png",
    "assets/art/environments/grand_casino/counters/grand_table_left.png",
    "assets/art/environments/grand_casino/counters/grand_table_right.png",
    "assets/art/environments/grand_casino/anim/casino_sign_pulse.png",
    *tuple("assets/art/environments/grand_casino/anim/casino_light_%d.png" % i for i in range(5)),
)
UID_ENTRY = ".godot/uid_cache.bin"
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
        if flags & ~2 or directory_offset < 112 or directory_offset + 4 > length:
            raise ValueError("Encrypted or invalid PCK directory")
        handle.seek(directory_offset)
        count = struct.unpack("<I", exact_read(handle, 4))[0]
        if not 1 <= count <= 10000:
            raise ValueError("PCK entry count exceeds the bounded parser")
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
                if name in entries or entry_flags != 0 or not 0 < size <= MAX_ENTRY or start < 112 or start + size > length:
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
    if len(rows) != 9 or {row["path"] for row in rows} != wanted or set(proposed) != wanted:
        raise ValueError("Canonical metadata must contain exactly the fixed nine sidecar additions")
    baseline = proof["baseline"]
    manifest_path, pck_path = plain(baseline["manifest_path"]), plain(baseline["pck_path"])
    if sha(manifest_path) != baseline["manifest_sha256"] or sha(pck_path) != baseline["pck_sha256"]:
        raise ValueError("Qualified immutable 7b baseline bytes changed")
    manifest = json_object(small(manifest_path), "qualified 7b manifest")
    if (manifest.get("source_commit"), manifest.get("source_tree")) != (baseline["source_commit"], baseline["source_tree"]):
        raise ValueError("Qualified baseline source identity differs")
    selected = wanted | {row["compiled_target"] for row in rows} | {UID_ENTRY}
    payloads = pck_payloads(pck_path, selected)
    mapping = uid_map(payloads[UID_ENTRY])
    mapping_sha = sha_bytes(json.dumps(mapping, sort_keys=True, separators=(",", ":")).encode())
    if sha_bytes(payloads[UID_ENTRY]) != baseline["uid_cache"]["payload_sha256"] or mapping_sha != baseline["uid_cache"]["mapping_sha256"]:
        raise ValueError("Complete baseline UID payload/map binding differs")
    for row in rows:
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
        if compiled_sha != row["baseline_compiled_sha256"] or manifest["compiled_art_sha256"].get(row["compiled_target"]) != compiled_sha:
            raise ValueError("Actual baseline CTEX differs from its qualified manifest")
    return proposed, mapping_sha


def snapshot_source(source, proof):
    # Dynamic snapshot: approved later image/one-field manifest changes are not
    # permanently constrained to this proposal's historical creation-time hashes.
    hashes = {path: sha(plain(source / path)) for path in (*PNG_PATHS, GRAND_JSON)}
    spec = json_object(small(source / GRAND_JSON), "current Grand JSON")
    entries = spec.get("animations", [])
    inventory = {"native_entries": len(entries), "web_low_detail_entries": sum(row.get("web_low_detail") is True for row in entries),
                 "animation_ids": [row.get("id") for row in entries]}
    if inventory != proof["manifest_inventory"]:
        raise ValueError("Grand sixteen motions, seven low-detail entries, or animation IDs changed")
    return hashes, inventory


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
        if proof.get("schema") != "bth.grand_canonical_import_metadata/v1":
            raise ValueError("Unexpected canonical metadata provenance schema")
        source = plain(args.source_root)
        if source != plain(proof["source_root"]):
            raise ValueError("Source root differs from the reviewed original worktree")
        if bool(args.before_proof) != (args.mode == "after"):
            raise ValueError("Only after mode requires --before-proof from the immediately preceding metadata check")
        proposed, mapping_sha = bindings(artifact, proof)
        hashes, inventory = snapshot_source(source, proof)
        report.update(source_root=str(source), provenance_sha256=sha_bytes(proof_raw), patch_sha256=proof["patch_sha256"],
                      verifier_sha256=proof["verifier_sha256"], baseline_pck_sha256=proof["baseline"]["pck_sha256"],
                      baseline_uid_map_sha256=mapping_sha, sidecars=9,
                      source_hash_snapshot=hashes, manifest_inventory=inventory)
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
            for key in ("schema", "source_root", "provenance_sha256", "patch_sha256", "verifier_sha256", "baseline_pck_sha256", "baseline_uid_map_sha256"):
                if before.get(key) != report.get(key):
                    raise ValueError("Prior before proof identity differs: " + key)
            if before.get("status") != "PASS" or before.get("mode") != "before":
                raise ValueError("A successful prior before proof is required")
            if before.get("source_hash_snapshot") != hashes or before.get("manifest_inventory") != inventory:
                raise ValueError("Underlying PNG/Grand JSON changed during this metadata-only application")
            report.update(before_proof=str(before_path), before_proof_sha256=sha_bytes(before_raw), underlying_source_unchanged=True)
        report.update(status="PASS", scope="Exactly nine canonical import metadata files; current PNG/JSON snapshot applies only to this before/after pair.")
    except Exception as error:
        report.update(error_type=type(error).__name__, error=str(error))
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
