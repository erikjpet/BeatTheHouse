"""Focused ENVART source/art custody proof; run with the maintained QA guard."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import zipfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-source", type=Path, required=True)
    parser.add_argument("--starter-zip", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--phase", type=int, default=5)
    args = parser.parse_args()
    root = Path(os.environ["BTH_QA_WORKSPACE"]).resolve()
    out = Path(os.environ["BTH_QA_EVIDENCE_DIR"]).resolve()
    assert root.drive.upper() == "E:" and out.drive.upper() == "E:"
    before = args.baseline_source.read_text(encoding="utf-8")
    after = (root / "scripts/ui/pixel_scene_canvas.gd").read_text(encoding="utf-8")

    def functions(source):
        matches = list(re.finditer(r"^func (\w+)\(", source, re.MULTILINE))
        return {m.group(1): source[m.start(): matches[i + 1].start() if i + 1 < len(matches) else len(source)].strip()
                for i, m in enumerate(matches)}

    old, new = functions(before), functions(after)
    allowed = {"_ready", "_render_owned_environment_snapshot", "_draw", "_draw_counter_foreground_art"}
    if args.phase >= 6:
        allowed.update({"_process", "_notification"})
    changed = [name for name in old if old[name] != new.get(name)]
    assert set(changed).issubset(allowed), changed
    assert set(old).issubset(new), "An original function was removed"
    supplied = []
    with zipfile.ZipFile(args.starter_zip) as archive:
        for name in archive.namelist():
            if name.endswith(".png"):
                value = archive.read(name)
                assert (root / name).read_bytes() == value, name
                supplied.append({"path": name, "sha256": hashlib.sha256(value).hexdigest()})
        original_manifest = archive.read("data/art/environments/gas_station_casino.json")
        assert (root / "docs/art/starter_pack/gas_station_casino.json").read_bytes() == original_manifest
    spec = root / "docs/todo/BTH_environment_art_layers_plan.md"
    assert hashlib.sha256(spec.read_bytes()).hexdigest() == "41758c4e59cc75f980e1d34d09db4d21aa10f49f5da77c94b9025f3498aab58c"
    inputs = ["scripts/ui/pixel_scene_canvas.gd", "scripts/ui/environment_art_pack.gd",
              "scripts/ui/environment_art_renderer.gd", "scripts/ui/foundation_main.gd",
              "project.godot", "export_presets.cfg", "native/coin_pusher/toolchain.lock.json",
              "data/art/environments/index.json", "data/art/environments/gas_station_casino.json"]
    inputs.extend(p.relative_to(root).as_posix() for p in sorted((root / "assets/art/environments/gas_station_casino").rglob("*.png")))
    hashes = {}
    for name in inputs:
        data = (root / name).read_bytes()
        assert (args.source_root / name).read_bytes() == data, "Test/source mismatch: " + name
        hashes[name] = hashlib.sha256(data).hexdigest()
    result = {"original_functions": len(old), "unchanged_functions": len(old) - len(changed),
              "changed_only_in_authorized_layer_seams": changed, "all_original_functions_retained": True,
              "supplied_pngs_unchanged": supplied, "supplied_manifest_archived_verbatim": True,
              "spec_unchanged": True, "tested_inputs_match_branch_bytes": hashes}
    (out / "source_invariants.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
