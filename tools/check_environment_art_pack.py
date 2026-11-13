#!/usr/bin/env python3
"""Check the v1 environment art contract without Godot; never edits the pack."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path, PurePosixPath
import struct
import zlib

BOARD = (900, 430)
SCHEMA = "bth.environment_art/v1"
TYPES = ("frames", "pulse", "mover", "scroll", "sweep")


class PackError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise PackError(message)


def number(value):
    try:
        return type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        return False


def vector(value, length):
    return isinstance(value, list) and len(value) == length and all(number(x) for x in value)


def rectangle(value, label):
    require(vector(value, 4), f"{label}: expected four finite board coordinates")
    x, y, w, h = value
    require(w > 0 and h > 0 and x < BOARD[0] and y < BOARD[1] and x + w > 0 and y + h > 0,
            f"{label}: positive rectangle must intersect the 900x430 board")


def png_size(path):
    """Read PNG dimensions and verify chunk structure/CRCs, including IEND."""
    try:
        with path.open("rb") as handle:
            require(handle.read(8) == b"\x89PNG\r\n\x1a\n", f"{path}: not a PNG")
            size = None
            image_data = False
            while True:
                header = handle.read(8)
                require(len(header) == 8, f"{path}: truncated PNG")
                length, kind = struct.unpack(">I4s", header)
                require(length <= 0x7fffffff, f"{path}: invalid PNG chunk length")
                if size is None:
                    require(kind == b"IHDR" and length == 13, f"{path}: missing PNG IHDR")
                remaining, checksum = length, zlib.crc32(kind)
                data = b""
                while remaining:
                    block = handle.read(min(65536, remaining))
                    require(bool(block), f"{path}: truncated PNG chunk")
                    checksum = zlib.crc32(block, checksum)
                    if kind == b"IHDR":
                        data += block
                    remaining -= len(block)
                crc = handle.read(4)
                require(len(crc) == 4, f"{path}: truncated PNG chunk")
                require(struct.unpack(">I", crc)[0] == checksum, f"{path}: PNG chunk CRC mismatch")
                if size is None:
                    require(kind == b"IHDR" and length == 13, f"{path}: missing PNG IHDR")
                    size = struct.unpack(">II", data[:8])
                    require(min(size) > 0, f"{path}: empty PNG")
                if kind == b"IDAT":
                    image_data = True
                if kind == b"IEND":
                    require(length == 0 and image_data and not handle.read(1), f"{path}: invalid PNG ending")
                    return size
    except OSError as error:
        raise PackError(f"{path}: {error.strerror}") from error


def room_map_id(root, room):
    maps = json.loads((root / "data/environments/placement_surfaces.json").read_text(encoding="utf-8-sig"))["maps"]
    archetypes = json.loads((root / "data/environments/archetypes.json").read_text(encoding="utf-8-sig"))
    for archetype in archetypes:
        for layer_id, layer in archetype.get("layers", {}).items():
            art_key = layer.get("art_key", layer.get("visual_context", {}).get("art_key", ""))
            if art_key == room:
                return archetype["id"] + ":" + layer_id
    if any(m["id"] == room for m in maps):
        return room
    raise PackError(f"{room}: no room surface map")


def counter_rectangles(root, room):
    map_id = room_map_id(root, room)
    maps = json.loads((root / "data/environments/placement_surfaces.json").read_text(encoding="utf-8-sig"))["maps"]
    room_map = next(m for m in maps if m["id"] == map_id)
    result = {}
    for counter in room_map.get("counters", []):
        if counter.get("foreground_art_id"):
            result[counter["foreground_art_id"]] = [counter["x0"], counter["top_y"],
                                                    counter["x1"] - counter["x0"], counter["front_y"] - counter["top_y"]]
    return result


def validate_manifest(manifest, room, asset_root, counters):
    require(isinstance(manifest, dict), "manifest: expected an object")
    require(manifest.get("schema") == SCHEMA, "schema: expected bth.environment_art/v1")
    require(manifest.get("environment_id") == room, "environment_id: does not match requested room")
    require(vector(manifest.get("board_size"), 2) and tuple(manifest["board_size"]) == BOARD,
            "board_size: expected [900, 430]")
    require(type(manifest.get("pixel_scale")) in (int, float) and manifest["pixel_scale"] == 2,
            "pixel_scale: expected 2")
    textures = {}

    def texture(entry, expected, label, frames=1):
        require(isinstance(entry, dict), f"{label}: expected an object")
        name = entry.get("texture")
        require(isinstance(name, str) and bool(name) and "\\" not in name and ":" not in name,
                f"{label}.texture: expected a relative PNG path")
        path = PurePosixPath(name)
        require(not path.is_absolute() and ".." not in path.parts and path.suffix.lower() == ".png",
                f"{label}.texture: must stay within the room asset folder")
        full = asset_root / name
        require(full.resolve().is_relative_to(asset_root.resolve()), f"{label}.texture: escaped room folder")
        size = textures.setdefault(name, png_size(full)) if name not in textures else textures[name]
        require(size[0] % frames == 0, f"{label}: uneven horizontal frame strip")
        if expected is not None:
            wanted = (expected[0] * 2 * frames, expected[1] * 2)
            require(size == wanted, f"{label}: texture is {size[0]}x{size[1]}; expected {wanted[0]:g}x{wanted[1]:g}")
        else:
            # Sweep has endpoints, not a fixed rect/size; its length is stretched.
            require(size[0] % 2 == 0 and size[1] % 2 == 0, f"{label}: sweep texture must be authored at 2x")

    texture(manifest.get("background"), BOARD, "background")
    animations = manifest.get("animations", [])
    require(isinstance(animations, list), "animations: expected an array")
    for i, animation in enumerate(animations):
        label = f"animations[{i}]"
        require(isinstance(animation, dict), f"{label}: expected an object")
        kind = animation.get("type")
        require(kind in TYPES, f"{label}.type: unknown animation type")
        require(animation.get("blend", "mix") in ("mix", "add"), f"{label}.blend: expected mix or add")
        for key, default in (("opacity", 1), ("phase", 0)):
            require(number(animation.get(key, default)), f"{label}.{key}: must be finite")
        require(0 <= animation.get("opacity", 1) <= 1, f"{label}.opacity: expected 0..1")
        require(type(animation.get("web_low_detail", True)) is bool, f"{label}.web_low_detail: expected boolean")
        frames = animation.get("frames", 1)
        require(number(frames) and frames >= 1 and int(frames) == frames, f"{label}.frames: expected integer >= 1")
        frames = int(frames)
        if kind == "frames" or (kind == "mover" and ("frames" in animation or "fps" in animation)):
            require("frames" in animation and number(animation.get("fps")) and animation["fps"] > 0,
                    f"{label}: frames and positive fps are required together")
        require(animation.get("loop", "loop") in ("loop", "pingpong", "once_hold"), f"{label}.loop: unknown loop mode")
        still = animation.get("still", "first")
        require(still in ("first", "hide") if isinstance(still, str) else
                number(still) and int(still) == still and 0 <= still < frames,
                f"{label}.still: expected first, hide or an existing frame number")
        expected = None
        if kind in ("frames", "pulse", "scroll"):
            rectangle(animation.get("rect"), f"{label}.rect")
            expected = animation["rect"][2:]
        if kind == "pulse":
            lo, hi, period = (animation.get(k) for k in ("min_opacity", "max_opacity", "period"))
            require(all(number(x) for x in (lo, hi, period)) and 0 <= lo <= hi <= 1 and period > 0,
                    f"{label}: pulse needs 0 <= min_opacity <= max_opacity <= 1 and positive period")
        if kind == "mover":
            require(vector(animation.get("size"), 2) and min(animation["size"]) > 0, f"{label}.size: expected positive finite size")
            expected = animation["size"]
            require(vector(animation.get("from"), 2) and vector(animation.get("to"), 2), f"{label}: expected finite from/to points")
            require(number(animation.get("duration")) and animation["duration"] > 0, f"{label}.duration: must be positive")
            require(number(animation.get("gap", 0)) and animation.get("gap", 0) >= 0, f"{label}.gap: must be nonnegative")
            if "clip" in animation:
                rectangle(animation["clip"], f"{label}.clip")
        if kind == "scroll":
            require(vector(animation.get("speed"), 2), f"{label}.speed: expected two finite values")
        if kind == "sweep":
            require(all(vector(animation.get(k), 2) for k in ("origin", "from", "to")), f"{label}: expected finite origin/from/to")
            require(number(animation.get("period")) and animation["period"] > 0, f"{label}.period: must be positive")
        texture(animation, expected, label, frames if kind in ("frames", "mover") else 1)
    entries = manifest.get("counters", {})
    require(isinstance(entries, dict), "counters: expected an object")
    for name, entry in entries.items():
        require(name in counters, f"counters.{name}: not a foreground_art_id in this room")
        require(isinstance(entry, dict), f"counters.{name}: expected an object")
        bleed = entry.get("bleed", [0, 0, 0, 0])
        require(vector(bleed, 4) and min(bleed) >= 0, f"counters.{name}.bleed: expected four nonnegative finite values")
        x, y, w, h = counters[name]
        rectangle([x - bleed[0], y - bleed[1], w + bleed[0] + bleed[2], h + bleed[1] + bleed[3]], f"counters.{name}")
        texture(entry, (w + bleed[0] + bleed[2], h + bleed[1] + bleed[3]), f"counters.{name}")
    return {"environment_id": room, "animations": len(animations), "counters": len(entries), "textures": len(textures)}


def check_pack(root, room):
    require(isinstance(room, str) and room and all(c.isascii() and (c.isalnum() or c == "_") for c in room), "invalid environment id")
    try:
        manifest = json.loads((root / f"data/art/environments/{room}.json").read_text(encoding="utf-8-sig"))
        return validate_manifest(manifest, room, root / f"assets/art/environments/{room}", counter_rectangles(root, room))
    except (OSError, json.JSONDecodeError, KeyError, StopIteration) as error:
        raise PackError(f"{room}: {error}") from error


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rooms", nargs="*")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--all", action="store_true", help="Check every manifest, including disabled packs")
    args = parser.parse_args(argv)
    try:
        index = json.loads((args.root / "data/art/environments/index.json").read_text(encoding="utf-8-sig"))
        require(isinstance(index, dict) and isinstance(index.get("enabled"), list) and all(isinstance(x, str) for x in index["enabled"]), "index.enabled: expected an array of room ids")
        rooms = args.rooms or (sorted(p.stem for p in (args.root / "data/art/environments").glob("*.json") if p.stem != "index") if args.all else index["enabled"])
        require(bool(rooms), "no rooms selected")
        failed = False
        for room in rooms:
            try:
                result = check_pack(args.root, room)
                print(json.dumps({"valid": True, "enabled": room in index["enabled"], **result}))
            except PackError as error:
                failed = True
                print(json.dumps({"valid": False, "environment_id": room, "reason": str(error)}))
        return 1 if failed else 0
    except (OSError, ValueError) as error:
        print(json.dumps({"valid": False, "reason": str(error)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
