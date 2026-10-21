#!/usr/bin/env python3
"""Pure allowlist regression for the packaged-resource manifest audit."""

from __future__ import annotations

import importlib.util
import struct
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("audit_pck_manifest.py")
SPEC = importlib.util.spec_from_file_location("audit_pck_manifest", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Could not load {MODULE_PATH}")
AUDIT_MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT_MODULE)


def entry(path: str) -> dict[str, str]:
    return {"path": path}


def pack(version: int, path: str) -> bytes:
    header = bytearray(AUDIT_MODULE.HEADER_BYTES)
    header[:4] = AUDIT_MODULE.MAGIC
    struct.pack_into("<I", header, 4, version)
    struct.pack_into("<III", header, 8, 4, 6, 0)
    if version == 3:
        struct.pack_into("<Q", header, 32, len(header))
    else:
        header = header[:100]
    encoded = path.encode("utf-8") + b"\0"
    directory = struct.pack("<II", 1, len(encoded)) + encoded
    directory += b"\0" * ((-len(encoded)) % 4)
    directory += struct.pack("<QQ16sI", 0, 0, bytes(16), 0)
    return bytes(header) + directory


def check_directory_selection() -> None:
    for version in (2, 3):
        first = pack(version, "res://first.gdc")
        last = pack(version, "res://last.gdc")
        # Invalid signatures on either side must not hide the last valid pack.
        prefix = b"executable\0GDPC" + bytes(120)
        data = prefix + first + b"GDPC" + bytes(120) + last + b"GDPC"
        result = AUDIT_MODULE.find_directory(data)
        expected_offset = len(prefix) + len(first) + 124
        if result["pack_offset"] != expected_offset or result["entries"][0]["path"] != "last.gdc":
            raise AssertionError(f"PCK v{version}: last valid embedded directory was not selected")
        at_zero = AUDIT_MODULE.find_directory(first)
        if at_zero["pack_offset"] != 0 or at_zero["pck_version"] != version:
            raise AssertionError(f"PCK v{version}: standalone directory at zero was not selected")
    for data in (b"", b"no pack", b"GDPC", b"GDPC" + bytes(120)):
        try:
            AUDIT_MODULE.find_directory(data)
        except ValueError:
            continue
        raise AssertionError("Invalid package was accepted")


def main() -> int:
    check_directory_selection()
    allowed = [
        "audio/music/casino_loop.bthpcm",
        "audio/voice/announcer.bthadpcm",
        "audio/sfx/coins.bthsfx",
        "audio/stems/table.bthstems",
    ]
    failures = AUDIT_MODULE.audit([entry(path) for path in allowed])
    if failures:
        raise AssertionError(f"RP-011: runtime audio formats were rejected: {failures}")

    rejected = [
        "audio/music/casino_loop.bthpcm.tmp",
        "audio/music/casino_loop.bthpcmx",
        "audio/voice/announcer.bthadpcmx",
        "audio/sfx/coins.bthsfxx",
        "audio/stems/table.bthstemsx",
        "reports/private/audio.bthpcm",
    ]
    for path in rejected:
        if not AUDIT_MODULE.audit([entry(path)]):
            raise AssertionError(f"RP-011: unsafe near-match was accepted: {path}")

    print("AUDIT_PCK_MANIFEST_CONTRACT PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
