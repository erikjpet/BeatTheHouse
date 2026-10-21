#!/usr/bin/env python3
"""Enumerate a Godot PCK v3 directory and reject development-only content."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

MAGIC = b"GDPC"
HEADER_BYTES = 112
FORBIDDEN_PREFIXES = (
    ".tmp/",
    "builds/",
    "docs/",
    "native/",
    "reports/",
    "review_artifacts/",
    "scripts/tests/",
    "tools/",
)
FORBIDDEN_SUFFIXES = (
    ".bat", ".cmd", ".env", ".key", ".lock", ".log", ".orig", ".pdb",
    ".pem", ".pfx", ".ps1", ".py", ".pyc", ".sh", ".tmp",
)
ALLOWED_SUFFIXES = (
    ".bin", ".binary", ".bthadpcm", ".bthpcm", ".bthsfx", ".bthstems", ".cfg", ".css", ".csv", ".ctex", ".data", ".dll",
    ".fontdata", ".gd", ".gdc", ".gdextension", ".glsl", ".gz", ".html",
    ".ico", ".import", ".ini", ".jpeg", ".jpg", ".js", ".json", ".mo",
    ".mp3", ".ogg", ".otf", ".po", ".png", ".res", ".sample", ".scn",
    ".remap", ".shader", ".svg", ".tres", ".tscn", ".ttf", ".txt", ".uid", ".wasm",
    ".wav", ".webp", ".xml",
)
SENSITIVE_FRAGMENTS = ("credential", "private_key", "secret", "token_dump")


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def u64(data: bytes, offset: int) -> int:
    return struct.unpack_from("<Q", data, offset)[0]


def parse_directory(data: bytes, start: int) -> dict | None:
    if start < 0 or start + HEADER_BYTES > len(data) or data[start : start + 4] != MAGIC:
        return None
    version = u32(data, start + 4)
    file_base = u64(data, start + 24)
    directory_offset = u64(data, start + 32) if version >= 3 else 0
    directory_start = start + directory_offset if version >= 3 else start + 100
    if directory_start + 4 > len(data):
        return None
    count = u32(data, directory_start)
    if version not in (2, 3) or count <= 0 or count > 1_000_000:
        return None
    cursor = directory_start + 4
    entries: list[dict] = []
    try:
        for _ in range(count):
            length = u32(data, cursor)
            cursor += 4
            if length <= 0 or length > 1_048_576 or cursor + length > len(data):
                return None
            raw_path = data[cursor : cursor + length]
            cursor += length
            cursor += (-length) % 4
            path = raw_path.rstrip(b"\0").decode("utf-8")
            if not path or "\0" in path:
                return None
            offset = u64(data, cursor)
            size = u64(data, cursor + 8)
            digest = data[cursor + 16 : cursor + 32].hex()
            flags = u32(data, cursor + 32)
            cursor += 36
            entries.append({"path": path.removeprefix("res://"), "offset": offset, "bytes": size, "md5": digest, "flags": flags})
    except (UnicodeDecodeError, struct.error):
        return None
    return {
        "pck_version": version,
        "engine_version": [u32(data, start + 8), u32(data, start + 12), u32(data, start + 16)],
        "pack_offset": start,
        "file_base": file_base,
        "file_count": count,
        "entries": entries,
    }


def find_directory(data: bytes) -> dict:
    positions: list[int] = []
    cursor = 0
    while True:
        found = data.find(MAGIC, cursor)
        if found < 0:
            break
        positions.append(found)
        cursor = found + 1
    for position in reversed(positions):
        parsed = parse_directory(data, position)
        if parsed is not None:
            return parsed
    raise ValueError("no valid unencrypted Godot PCK v2/v3 directory found")


def audit(entries: list[dict]) -> list[str]:
    failures: list[str] = []
    for entry in entries:
        path = str(entry["path"]).replace("\\", "/").lstrip("/")
        lowered = path.lower()
        if lowered.startswith(FORBIDDEN_PREFIXES):
            failures.append(f"development-only prefix: {path}")
            continue
        if lowered.endswith(FORBIDDEN_SUFFIXES):
            failures.append(f"forbidden file type: {path}")
            continue
        if any(fragment in lowered for fragment in SENSITIVE_FRAGMENTS):
            failures.append(f"sensitive-looking resource: {path}")
            continue
        if not lowered.endswith(ALLOWED_SUFFIXES):
            failures.append(f"unexpected file type: {path}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("package", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    data = args.package.read_bytes()
    try:
        result = find_directory(data)
    except ValueError as exc:
        print(f"PCK AUDIT FAIL: {exc}", file=sys.stderr)
        return 1
    failures = audit(result["entries"])
    report = {
        "schema": "beat_the_house.pck_manifest_audit/v1",
        "package": args.package.name,
        "package_bytes": len(data),
        "package_sha256": hashlib.sha256(data).hexdigest(),
        "pck_version": result["pck_version"],
        "engine_version": result["engine_version"],
        "pack_offset": result["pack_offset"],
        "file_count": result["file_count"],
        "passed": not failures,
        "failures": failures,
        "files": sorted(result["entries"], key=lambda row: str(row["path"])),
    }
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if failures:
        print(f"PCK AUDIT FAIL ({len(failures)}): " + " | ".join(failures[:12]), file=sys.stderr)
        return 1
    print(f"PCK AUDIT PASS files={result['file_count']} package={args.package}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
