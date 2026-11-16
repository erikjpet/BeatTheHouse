"""Read-only art/capture custody inventory; run inside bth_qa_guarded_run.

This worker starts no children, renders nothing and never opens save/profile data.
It records source identity, not visual, scenario, motion or delivery acceptance.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import struct

from bth_qa_storage import Layout, validate_layout


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_info(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("Not a PNG: " + str(path))
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "width": width, "height": height, "bit_depth": depth, "color_type": color}


def texture_names(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "texture" and isinstance(child, str):
                yield child
            else:
                yield from texture_names(child)
    elif isinstance(value, list):
        for child in value:
            yield from texture_names(child)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args()
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    manifest = json.loads((evidence / "storage-manifest.json").read_text(encoding="utf-8"))
    layout = Layout(**{key: Path(value) for key, value in manifest["paths"].items()},
                    **{key: manifest[key] for key in ("run_id", "token", "expected_write_bytes",
                                                     "reserve_bytes", "prepared")})
    output = evidence / "spatial-source-audit.json"
    admission = validate_layout(layout, extra_write_paths=(output,))
    source = args.source_root.resolve(strict=True)
    inventory_path = source / "docs/testing/environment_spatial_review_evidence_20261116.json"
    captures = json.loads(inventory_path.read_text(encoding="utf-8"))["captures"]
    if len(captures) != 20:
        raise ValueError("Expected the committed all-20 capture inventory")
    rooms = {}
    for room, capture in captures.items():
        spec_path = source / "data/art/environments" / (room + ".json")
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
        art_root = (source / "assets/art/environments" / room).resolve(strict=True)
        textures = []
        for name in sorted(set(texture_names(spec))):
            path = (art_root / name).resolve(strict=True)
            if not path.is_relative_to(art_root):
                raise ValueError("Art texture escaped its room: " + name)
            textures.append(png_info(path))
        observed = png_info(Path(capture["path"]))
        if observed["sha256"] != capture["sha256"] or observed["bytes"] != capture["bytes"]:
            raise ValueError("Historical capture custody mismatch: " + room)
        animations = spec.get("animations", [])
        rooms[room] = {"manifest_sha256": sha(spec_path), "textures": textures,
                       "animation_ids": [item["id"] for item in animations],
                       "animation_count": len(animations),
                       "web_low_detail_count": sum(item.get("web_low_detail", True) is not False
                                                   for item in animations),
                       "historical_capture": observed, "capture_hash_matches": True}
    protected = ("data/environments/developer_placement_overrides.json",
                 "data/environments/placement_surfaces.json",
                 "scripts/ui/pixel_scene_canvas.gd", "scripts/ui/environment_art_renderer.gd",
                 "scripts/ui/environment_art_pack.gd", "scripts/ui/game_surface_canvas.gd")
    result = {"schema": "bth.spatial_source_audit/v1", "task_id": "BTH-ENV-SPATIAL-001",
              "observed_at": datetime.now(timezone.utc).isoformat(), "source_root": str(source),
              "room_count": len(rooms), "rooms": rooms,
              "protected_source_sha256": {name: sha(source / name) for name in protected},
              "storage_manifest": str(layout.manifest_path), "storage_admission": admission,
              "limits": ["Source and historical capture custody only; no rendering or runtime launched.",
                         "No visual, scenario, motion, Reduce Motion, liveness or TEST acceptance.",
                         "No save/profile data opened and no source/art file modified."]}
    with output.open("x", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    print(json.dumps({"room_count": len(rooms), "capture_hashes_match": True,
                      "referenced_textures": sum(len(room["textures"]) for room in rooms.values()),
                      "report": str(output)}))


if __name__ == "__main__":
    main()
