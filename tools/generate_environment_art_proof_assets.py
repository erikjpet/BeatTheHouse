#!/usr/bin/env python3
"""Generate exact-size geometric scanline data for the ENVART renderer proof."""
import argparse
import json
from pathlib import Path
import struct
import zlib


def png(width, height):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    rows = []
    for y in range(height):
        alpha = 255 if y < 2 else (64 if y < 6 else 0)
        rows.append(b"\0" + bytes((170, 235, 255, alpha)) * width)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--activate", action="store_true", help="Install the generated proof manifest from the preserved starter reference")
    args = parser.parse_args()
    target = args.root / "assets/art/environments/gas_station_casino/anim/proof_scanline.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(png(1800, 68))
    if args.activate:
        reference = args.root / "docs/art/starter_pack/gas_station_casino.json"
        manifest = json.loads(reference.read_text(encoding="utf-8-sig"))
        manifest.pop("note", None)
        for animation in manifest["animations"]:
            if animation["type"] == "scroll":
                animation["texture"] = "anim/proof_scanline.png"
        (args.root / "data/art/environments/gas_station_casino.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"generated": str(target), "size": [1800, 68], "activated": args.activate}))


if __name__ == "__main__":
    main()
