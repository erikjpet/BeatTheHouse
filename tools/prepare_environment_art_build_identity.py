#!/usr/bin/env python3
"""Bind an immutable art TEST snapshot before export; verify its PCK afterwards.

Run prepare inside an admitted bth_qa_guarded_run workspace before normal Godot
export. It exclusively creates snapshot/build_manifest.json, like the established
export_itch.ps1 Invoke-WithEmbeddedManifest contract, without patching the PCK.
The caller owns the git-archive commit/tree provenance and snapshot cleanup.
verify is read-only and accepts either that manifest or the final external one.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

import audit_pck_manifest

SCHEMA = "beat_the_house.build_manifest/v1"
# Get-SourceIdentity in export_itch.ps1: status + LF + diff blob + LF +
# sorted untracked rows. All three are empty for an immutable clean archive.
EMPTY_DIFF_BLOB = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
CLEAN_DIRTY_DIGEST = hashlib.sha256(("\n" + EMPTY_DIFF_BLOB + "\n").encode("utf-8")).hexdigest()
IDENTITY_FIELDS = (
    "schema", "build_version", "source_commit", "source_tree", "source_dirty",
    "dirty_state_digest", "engine_sha256", "export_presets_sha256", "platform",
    "native_library_path", "native_library_sha256", "channel", "art_package_sha256",
)
POST_EXPORT_FIELDS = ("files", "export_identity_sha256", "embedded_manifest_sha256", "embedded_manifest_md5")


def require_hash(value, length, label):
    if not isinstance(value, str) or not re.fullmatch(r"[a-f0-9]{%d}" % length, value) or value == "0" * length:
        raise ValueError(f"Invalid {label}: expected nonzero lowercase {length}-digit hex")
    return value


def no_links(path):
    for candidate in (path, *path.parents):
        if candidate.is_symlink() or getattr(candidate, "is_junction", lambda: False)():
            raise ValueError("Link/junction not allowed: " + str(candidate))


def input_file(path):
    path = Path(path).absolute()
    no_links(path)
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError("Expected nonempty input file: " + str(path))
    return path.resolve(strict=True)


def file_sha256(path):
    digest = hashlib.sha256()
    with input_file(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_identity(value):
    if not isinstance(value, dict) or value.get("schema") != SCHEMA:
        raise ValueError("Invalid embedded build identity schema")
    for field in ("source_commit", "source_tree"):
        require_hash(value.get(field), 40, field)
    for field in ("dirty_state_digest", "engine_sha256", "export_presets_sha256", "native_library_sha256", "art_package_sha256"):
        require_hash(value.get(field), 64, field)
    version = value.get("build_version")
    if not isinstance(version, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.+_-]{0,127}", version) or "UNBOUND" in version.upper():
        raise ValueError("Invalid bound build_version")
    if value.get("source_dirty") is not False or value["dirty_state_digest"] != CLEAN_DIRTY_DIGEST:
        raise ValueError("Art TEST identity requires immutable clean archive provenance")
    if value.get("platform") != "web" or value.get("channel") != "test":
        raise ValueError("Expected web/test embedded identity")
    native = value.get("native_library_path")
    if not isinstance(native, str) or not native or native in (".", "..") or PurePosixPath(native).name != native or "\\" in native or ":" in native:
        raise ValueError("Expected native library basename")
    return {field: value[field] for field in IDENTITY_FIELDS}


def prepare_identity(snapshot, *, source_commit, source_tree, engine, native_library,
                     export_presets, art_package_sha256, build_version=None):
    """Write only a new root manifest; never infer provenance from the live repo."""
    require_hash(source_commit, 40, "source_commit")
    require_hash(source_tree, 40, "source_tree")
    require_hash(art_package_sha256, 64, "art_package_sha256")
    snapshot = Path(snapshot).absolute()
    no_links(snapshot)
    snapshot = snapshot.resolve(strict=True)
    if not snapshot.is_dir() or (snapshot / ".git").exists():
        raise ValueError("Expected an immutable git-archive snapshot without .git")
    input_file(snapshot / "project.godot")
    presets = input_file(export_presets)
    if presets != snapshot / "export_presets.cfg":
        raise ValueError("Export presets must be the snapshot's export_presets.cfg")
    native = input_file(native_library)
    manifest = {
        "schema": SCHEMA,
        "build_version": build_version if build_version is not None else "0.6.0-dev+" + source_commit[:12],
        "source_commit": source_commit, "source_tree": source_tree,
        "source_dirty": False, "dirty_state_digest": CLEAN_DIRTY_DIGEST,
        "engine_sha256": file_sha256(engine), "export_presets_sha256": file_sha256(presets),
        "platform": "web", "native_library_path": native.name,
        "native_library_sha256": file_sha256(native), "channel": "test",
        "art_package_sha256": art_package_sha256,
    }
    validate_identity(manifest)
    destination = snapshot / "build_manifest.json"
    no_links(destination)
    # Exclusive creation also refuses an existing manifest from a prior export.
    with destination.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(manifest, indent=2) + "\n")
    return manifest


def verify_embedded_identity(package, expected):
    """Use the existing PCK audit/parser, then validate actual manifest bytes."""
    expected_core = validate_identity(expected)
    data = input_file(package).read_bytes()
    directory = audit_pck_manifest.find_directory(data)
    # This helper validates standalone Web packs, not executable overlays.
    if directory["pack_offset"] != 0 or audit_pck_manifest.u32(data, 20) & ~2:
        raise ValueError("Expected standalone unencrypted, nonsparse Web PCK")
    failures = audit_pck_manifest.audit(directory["entries"])
    if failures:
        raise ValueError("PCK content audit failed: " + " | ".join(failures[:12]))
    for entry in directory["entries"]:
        path = entry["path"]
        name = PurePosixPath(path)
        if name.is_absolute() or ".." in name.parts or "\\" in path or name.as_posix() != path:
            raise ValueError("Noncanonical PCK resource path: " + path)
    entries = [entry for entry in directory["entries"] if entry["path"] == "build_manifest.json"]
    if len(entries) != 1:
        raise ValueError("Expected exactly one embedded res://build_manifest.json")
    entry = entries[0]
    if entry["flags"] != 0 or not 0 < entry["bytes"] <= 1024 * 1024:
        raise ValueError("Invalid embedded manifest flags/size")
    # Godot PackedSourcePCK adds file_base to each entry offset. For a standalone
    # pack the V3 relative base (and V2 optional relative base) starts at zero.
    start = directory["file_base"] + entry["offset"]
    end = start + entry["bytes"]
    if start < audit_pck_manifest.HEADER_BYTES or end > len(data):
        raise ValueError("Embedded manifest lies outside the PCK data")
    raw = data[start:end]
    md5 = hashlib.md5(raw).hexdigest()
    if md5 != entry["md5"]:
        raise ValueError("Embedded manifest PCK MD5 mismatch")
    try:
        embedded = json.loads(raw.decode("utf-8"))
    except (UnicodeError, ValueError) as error:
        raise ValueError("Embedded manifest is not UTF-8 JSON") from error
    if validate_identity(embedded) != expected_core:
        raise ValueError("Embedded/external build identity mismatch")
    if any(field in embedded for field in POST_EXPORT_FIELDS):
        raise ValueError("Post-export fields must not be embedded (circular identity)")
    hashes = {"embedded_manifest_sha256": hashlib.sha256(raw).hexdigest(), "embedded_manifest_md5": md5}
    for field, actual in hashes.items():
        if field in expected and expected[field] != actual:
            raise ValueError(field + " mismatch")
    return {"passed": True, "identity": expected_core, "pck_version": directory["pck_version"],
            "pck_files_audited": directory["file_count"], "embedded_manifest_bytes": len(raw), **hashes}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    prepare = commands.add_parser("prepare")
    prepare.add_argument("--snapshot", type=Path, required=True)
    prepare.add_argument("--source-commit", required=True)
    prepare.add_argument("--source-tree", required=True)
    prepare.add_argument("--engine", type=Path, required=True)
    prepare.add_argument("--native-library", type=Path, required=True)
    prepare.add_argument("--export-presets", type=Path, required=True)
    prepare.add_argument("--art-package-sha256", required=True)
    prepare.add_argument("--build-version")
    verify = commands.add_parser("verify")
    verify.add_argument("--package", type=Path, required=True)
    verify.add_argument("--manifest", type=Path, required=True)
    args = vars(parser.parse_args(argv))
    action = args.pop("action")
    if action == "prepare":
        result = prepare_identity(**args)
    else:
        expected = json.loads(input_file(args["manifest"]).read_text(encoding="utf-8-sig"))
        result = verify_embedded_identity(args["package"], expected)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
