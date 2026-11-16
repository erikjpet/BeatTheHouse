"""Read-only before/after verification for the reviewed Bar metadata patch."""
import sys
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
from pathlib import Path
import re


def sha(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for part in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(part)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--mode", choices=("before", "after"), required=True)
    args = parser.parse_args()
    artifact = Path(__file__).resolve().parent
    proof = json.loads((artifact / "provenance.json").read_text(encoding="utf-8"))
    source = args.source_root.resolve(strict=True)
    if source != Path(proof["source_root"]).resolve(strict=True):
        raise ValueError("Source root differs from the reviewed original worktree")
    if sha(artifact / "canonical-source.patch") != proof["patch_sha256"]:
        raise ValueError("Canonical patch artifact bytes changed")
    mapping = proof["baseline_uid_cache"]["path_to_uid"]
    if len(mapping) != 1605 or any(not re.fullmatch(r"[0-9]+", uid) for uid in mapping.values()):
        raise ValueError("Full lossless 1605-entry baseline UID map is absent")
    mapping_sha = hashlib.sha256(json.dumps(mapping, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    if mapping_sha != proof["baseline_uid_cache"]["mapping_sha256"]:
        raise ValueError("Baseline UID mapping artifact differs")
    if sha(proof["baseline_pck"]) != proof["baseline_pck_sha256"]:
        raise ValueError("Immutable baseline PCK bytes changed")
    failures = []
    for item in proof["sidecars"]:
        target = source / item["path"]
        if target.is_symlink() or not target.resolve().is_relative_to(source):
            failures.append("Aliased sidecar target: " + item["path"])
            continue
        if args.mode == "before":
            if target.exists():
                failures.append("Originally absent sidecar now exists: " + item["path"])
        elif not target.is_file() or sha(target) != item["new_sha256"]:
            failures.append("Applied sidecar bytes differ: " + item["path"])
        if sha(item["baseline_source"]) != item["new_sha256"]:
            failures.append("Retained sidecar donor differs: " + item["path"])
        original = item["path"].removesuffix(".import").removesuffix(".uid")
        if mapping.get("res://" + original) != item["baseline_pck_numeric_uid"]:
            failures.append("Sidecar baseline UID binding differs: " + item["path"])
    for item in proof["scene_header_changes"]:
        target = source / item["path"]
        data = target.read_bytes()
        expected = item["old_sha256"] if args.mode == "before" else item["new_sha256"]
        if hashlib.sha256(data).hexdigest() != expected:
            failures.append("Scene original/result hash differs: " + item["path"])
        original, proposed = item["old_header"].encode(), item["new_header"].encode()
        if args.mode == "after":
            if data.count(proposed) != 1 or hashlib.sha256(data.replace(proposed, original, 1)).hexdigest() != item["old_sha256"]:
                failures.append("Scene changed beyond its single original root attribute: " + item["path"])
        elif data.count(original) != 1:
            failures.append("Original root header is not unique: " + item["path"])
    for relative, expected in proof["unchanged_source_file_sha256"].items():
        if sha(source / relative) != expected:
            failures.append("Underlying PNG or GDScript source changed: " + relative)
    rows = [path + " " + sha(source / path) for path in proof["bar_19_payload_paths"]]
    seal = hashlib.sha256("\n".join(rows).encode()).hexdigest()
    if len(rows) != 19 or seal != proof["bar_19_payload_sha256"]:
        failures.append("Approved 19-payload Bar seal changed")
    if sha(source / "assets/art/environments/bar/background.png") != proof["bar_background_sha256"]:
        failures.append("Approved Bar background bytes changed")
    discovery = proof["native_syntax_discovery"]
    if discovery["status"] != "FAIL" or sha(discovery["path"]) != discovery["sha256"]:
        failures.append("Failed native syntax-discovery evidence changed")
    print(json.dumps({"status": "PASS" if not failures else "FAIL", "mode": args.mode,
        "sidecars": len(proof["sidecars"]), "scene_header_changes": len(proof["scene_header_changes"]),
        "baseline_uid_bindings": len(mapping), "bar_19_payload_sha256": seal,
        "failures": failures, "files_written": False}, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
