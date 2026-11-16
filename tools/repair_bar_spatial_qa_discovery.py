"""Exclude archived Bar baseline from editor discovery in the admitted QA copy."""
import hashlib
import json
import os
from pathlib import Path

from bth_qa_storage import Layout, validate_layout


def main():
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    manifest = json.loads((evidence / "storage-manifest.json").read_text())
    layout = Layout(**{key: Path(value) for key, value in manifest["paths"].items()},
                    **{key: manifest[key] for key in ("run_id", "token", "prepared", "expected_write_bytes", "reserve_bytes")})
    target = layout.workspace / "qa_baseline/.gdignore"
    validate_layout(layout, extra_write_paths=(target.parent,))
    baseline = target.parent / "pixel_scene_canvas.182ae255.gd"
    before = hashlib.sha256(baseline.read_bytes()).hexdigest()
    if not baseline.read_text(encoding="utf-8-sig").startswith("class_name PixelSceneCanvas"):
        raise ValueError("Expected preserved reference canvas is absent")
    if target.exists():
        raise ValueError("Discovery marker exists; inspect prior repair instead of retrying")
    with target.open("x") as handle:
        handle.write("# Explicit reference source; exclude global-class discovery.\n")
    if hashlib.sha256(baseline.read_bytes()).hexdigest() != before:
        raise ValueError("Reference source custody changed")
    result = {"scope": "QA discovery only; baseline bytes preserved", "marker": str(target),
              "baseline_sha256": before, "editor_refresh_required": True,
              "production_art_written": False, "test_updated": False}
    with (evidence / "bar-qa-discovery-repair.json").open("x") as handle:
        json.dump(result, handle, indent=2)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
