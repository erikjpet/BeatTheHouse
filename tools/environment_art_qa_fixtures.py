"""Admitted E:-only synthetic art inputs; never edits supplied/production art."""
import sys
sys.dont_write_bytecode = True
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import zlib
from bth_qa_storage import Layout, validate_layout


def png(width, height, rgb):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    rows = (b"\0" + bytes((*rgb, 255)) * width) * height
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 3)) + chunk(b"IEND", b""))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("prepare", "cleanup"))
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    out = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    receipt = json.loads((out / "storage-manifest.json").read_text(encoding="utf-8"))
    layout = Layout(**{k: Path(v) for k, v in receipt["paths"].items()}, run_id=receipt["run_id"],
                    token=receipt["token"], prepared=True, expected_write_bytes=receipt["expected_write_bytes"],
                    reserve_bytes=receipt["reserve_bytes"])
    validate_layout(layout)
    root = layout.workspace.resolve()
    index = root / "data/art/environments/index.json"

    def admitted(path):
        assert path.resolve().is_relative_to(root)
        validate_layout(layout, extra_write_paths=(path.parent,))

    if args.action == "prepare":
        original_index = index.read_bytes()
        enabled = json.loads(original_index)["enabled"]
        records = []
        rooms = {"corner_store": (48, 24, 72), "bar": (24, 48, 88),
                 "animation_liveness_environment": (16, 48, 32)}
        for room, color in rooms.items():
            manifest = {"schema": "bth.environment_art/v1", "environment_id": room,
                        "board_size": [900, 430], "pixel_scale": 2,
                        "background": {"texture": "background.png"}, "animations": [], "counters": {}}
            if room == "animation_liveness_environment":
                manifest["animations"] = [{"id": "liveness", "type": "pulse", "texture": "anim/pulse.png",
                                            "rect": [4, 4, 4, 2], "min_opacity": 0.2, "max_opacity": 1.0, "period": 1.0}]
            values = {f"data/art/environments/{room}.json": (json.dumps(manifest, indent=2) + "\n").encode(),
                      f"assets/art/environments/{room}/background.png": png(1800, 860, color)}
            if room == "animation_liveness_environment":
                values[f"assets/art/environments/{room}/anim/pulse.png"] = png(8, 4, (255, 255, 255))
            for relative, data in values.items():
                target = root / relative
                admitted(target)
                assert not target.exists(), "Refusing to replace non-fixture input: " + relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                backup = out / "fixture-inputs" / relative
                validate_layout(layout, extra_write_paths=(backup.parent,))
                backup.parent.mkdir(parents=True, exist_ok=True)
                backup.write_bytes(data)
                records.append({"path": relative, "sha256": hashlib.sha256(data).hexdigest(),
                                "sidecar_existed": target.with_name(target.name + ".import").exists()})
            enabled.append(room)
        admitted(index)
        replacement = (json.dumps({"enabled": enabled}, indent=2) + "\n").encode()
        index.write_bytes(replacement)
        result = {"workspace": str(root), "original_index_b64": base64.b64encode(original_index).decode(),
                  "temporary_index_sha256": hashlib.sha256(replacement).hexdigest(), "files": records,
                  "scope": "QA-only generated inputs; no Phase8 rollout or supplied PNG changes"}
        (out / "fixtures.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    else:
        assert args.receipt is not None
        source = json.loads(args.receipt.read_text(encoding="utf-8"))
        assert Path(source["workspace"]).resolve() == root
        assert hashlib.sha256(index.read_bytes()).hexdigest() == source["temporary_index_sha256"]
        removed = []
        for record in source["files"]:
            target = root / record["path"]
            admitted(target)
            assert hashlib.sha256(target.read_bytes()).hexdigest() == record["sha256"], str(target)
            target.unlink()
            removed.append(str(target))
            sidecar = target.with_name(target.name + ".import")
            if not record["sidecar_existed"] and sidecar.exists():
                text = sidecar.read_text(encoding="utf-8")
                assert ('source_file="res://' + record["path"] + '"') in text
                sidecar.unlink()
        admitted(index)
        index.write_bytes(base64.b64decode(source["original_index_b64"]))
        result = {"only_owned_generated_inputs_removed": removed, "original_index_restored": True}
        (out / "cleanup.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    shutil.copyfile(__file__, out / "fixture-adapter.py")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
