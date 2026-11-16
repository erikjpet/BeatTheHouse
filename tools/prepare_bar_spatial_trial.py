"""Provision a fresh, non-active Bar trial source under admitted E: storage.

Copies source/art only, preserves archive bytes, starts no children and never
opens profiles or player saves. Does not replace the active Bar package.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import zipfile

from bth_qa_storage import Layout, validate_layout

QA_ARCHIVE_SHA256 = "f63ad0a587d329290b0edfe66fcc2d7f8f9915318df8fa9473ac06685adfca5d"
SOURCE_DIRS = ("addons", "assets", "data", "scenes", "scripts")
SOURCE_FILES = ("project.godot", "default_bus_layout.tres", "icon.svg", "icon.svg.import")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--harness-only", action="store_true",
                        help="Add missing preserved helpers only; identical files are retained and mismatches fail")
    args = parser.parse_args()
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    manifest = json.loads((evidence / "storage-manifest.json").read_text())
    layout = Layout(**{key: Path(value) for key, value in manifest["paths"].items()},
                    **{key: manifest[key] for key in ("run_id", "token", "expected_write_bytes",
                                                     "reserve_bytes", "prepared")})
    validate_layout(layout, extra_write_paths=(layout.workspace,))
    if not args.harness_only and any(layout.workspace.iterdir()):
        raise ValueError("Trial workspace must be empty; no reuse or overwrite: " + str(layout.workspace))
    source = args.source_root.resolve(strict=True)
    if args.harness_only and (layout.workspace / "project.godot").read_bytes() != (source / "project.godot").read_bytes():
        raise ValueError("Harness completion requires the exact prepared project identity")
    archive = source / "review_artifacts/environment_art_sources/bar-v1-r4/bar-v1-r4-qa-source.zip"
    if digest(archive.read_bytes()) != QA_ARCHIVE_SHA256:
        raise ValueError("Preserved R4 QA archive identity mismatch")
    files = []
    for directory in (() if args.harness_only else SOURCE_DIRS):
        for path in sorted((source / directory).rglob("*")):
            info = path.lstat()
            if path.is_symlink() or getattr(info, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                raise ValueError("Source link/reparse path is not admitted: " + str(path))
            if path.is_file():
                files.append(path)
    if not args.harness_only:
        files.extend(source / name for name in SOURCE_FILES if (source / name).is_file())
    total = sum(path.stat().st_size for path in files)
    if total + archive.stat().st_size > layout.expected_write_bytes:
        raise ValueError("Source copy exceeds admitted expected-write budget: " + str(total))
    copied = {}
    for path in files:
        relative = path.relative_to(source)
        target = layout.workspace / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        before = digest(path.read_bytes())
        shutil.copyfile(path, target)
        if digest(target.read_bytes()) != before or digest(path.read_bytes()) != before:
            raise ValueError("Source changed or copy mismatch: " + str(relative))
        copied[relative.as_posix()] = before
    harness = {}
    with zipfile.ZipFile(archive) as frozen:
        members = set(frozen.namelist())
        selected = {name for name in members
                    if (name.startswith("tools/envart_bar_") and PurePosixPath(name).suffix in (".gd", ".json", ".uid"))
                    or name in ("tools/environment_art_baseline_capture.gd",
                                "baseline/bar_source_identity.json", "baseline/pixel_scene_canvas.182ae255.gd")}
        pending = list(selected)
        while pending:
            name = pending.pop()
            if not name.endswith(".gd"):
                continue
            text = frozen.read(name).decode("utf-8-sig")
            for dependency in re.findall(r'res://(tools/[^"\s]+\.(?:gd|json))', text):
                if dependency not in members:
                    raise ValueError("Preserved helper dependency is absent from archive: " + dependency)
                if dependency not in selected:
                    selected.add(dependency)
                    pending.append(dependency)
        for name in sorted(selected):
            rel = PurePosixPath(name)
            if rel.is_absolute() or ".." in rel.parts or "\\" in name:
                raise ValueError("Unsafe archive member: " + name)
            # Preserve the full GDScript helper family because the Bar sequence
            # proof inherits the earlier Back-Alley observer. Never copy old
            # Python launcher adapters or old production code over current code.
            target = layout.workspace / ("qa_baseline" if name.startswith("baseline/") else "") / (
                rel.name if name.startswith("baseline/") else rel)
            data = frozen.read(name)
            if target.exists():
                if not args.harness_only or target.read_bytes() != data:
                    raise ValueError("Archived helper would overwrite current source: " + str(target))
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open("xb") as output:
                    output.write(data)
            harness[target.relative_to(layout.workspace).as_posix()] = digest(data)
    # Bounded cold-import settings apply to this fresh QA source only. No
    # project pipeline pin or original workspace setting is changed.
    if not args.harness_only:
        with (layout.workspace / "override.cfg").open("x") as output:
            output.write("[editor]\nimport/use_multiple_threads=false\n\n[threading]\nworker_pool/max_threads=1\n")
    result = {"schema": "bth.bar_spatial_trial_preparation/v1", "task_id": "BTH-ENV-SPATIAL-BAR-001",
              "observed_at": datetime.now(timezone.utc).isoformat(), "source_root": str(source),
              "trial_workspace": str(layout.workspace), "source_files": copied,
              "source_bytes": total, "qa_archive_sha256": QA_ARCHIVE_SHA256,
              "harness_only": args.harness_only,
              "archived_helper_files": harness, "candidate_installed": False,
              "limits": ["Source and harness preparation only; no game/browser or child launched.",
                         "Active R4 art copied unchanged; no trial art installed or approved.",
                         "Archived assertions retained; current-source/native qualification remains pending.",
                         "No profile or player-save data was read, copied or moved."]}
    with (evidence / "bar-trial-preparation.json").open("x", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    print(json.dumps({"source_files": len(copied), "source_bytes": total,
                      "archived_helpers": len(harness), "candidate_installed": False,
                      "workspace": str(layout.workspace)}))


if __name__ == "__main__":
    main()
