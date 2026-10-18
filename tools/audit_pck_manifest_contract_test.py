#!/usr/bin/env python3
"""Pure allowlist regression for the packaged-resource manifest audit."""

from __future__ import annotations

import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("audit_pck_manifest.py")
SPEC = importlib.util.spec_from_file_location("audit_pck_manifest", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Could not load {MODULE_PATH}")
AUDIT_MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT_MODULE)


def entry(path: str) -> dict[str, str]:
    return {"path": path}


def main() -> int:
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
