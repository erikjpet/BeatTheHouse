#!/usr/bin/env python3
"""Export a scoped CRT binary patch through the unchanged artifact exporter.

This is a storage-aware artifact worker, launched inside bth_qa_guarded_run.
It never stages the real index, changes a ref, commits, builds, or publishes.
The caller freezes a raw-hashed scope manifest using ordinary C: Git first.
"""
from __future__ import annotations

import sys
sys.dont_write_bytecode = True

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess

from bth_qa_storage import Layout, StorageGuardError, check_launch, validate_layout

BASE_COMMIT = "89403f389a5807e050a450cd27b1bd93b3a4a41e"
BASE_TREE = "1723e2f077f1c8dadbf0dbd8f740aa0ca3db33f4"
SCOPE_SCHEMA = "bth.crt_transfer_scope/v1"
APPROVED_EXPORT_SHELL = Path(r"C:\Users\theep\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe")
MAX_FILES = 256
MAX_FILE_BYTES = 32 * 1024 * 1024
MAX_TOTAL_BYTES = 128 * 1024 * 1024
LAYOUT_PATHS = ("root", "workspace", "run_root", "profile", "temp", "evidence",
                "appdata", "localappdata", "home", "cache", "save_dir", "pycache")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def relative_path(value: object) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_.\-/]+", value):
        raise ValueError(f"Unsafe scoped path: {value!r}")
    path = PurePosixPath(value)
    if (path.is_absolute() or path.as_posix() != value or
            any(part in ("", ".", "..") for part in value.split("/")) or
            path.parts[0] not in ("scripts", "tools", "docs")):
        raise ValueError(f"Scope must name a regular scripts/tools/docs file: {value}")
    return value


def exported_path(value: object) -> str:
    """Accept the exporter's Windows or slash spelling, never traversal."""
    if not isinstance(value, str):
        raise ValueError("Export manifest path must be a string")
    normalized = value.replace("\\", "/")
    path = PurePosixPath(normalized)
    if (not re.fullmatch(r"[A-Za-z0-9_.\-/]+", normalized) or path.is_absolute() or
            path.as_posix() != normalized or
            any(part in ("", ".", "..") for part in normalized.split("/"))):
        raise ValueError(f"Unsafe export manifest path: {value!r}")
    return normalized


def parse_scope(data: dict) -> list[dict]:
    if (data.get("schema") != SCOPE_SCHEMA or data.get("baseline_commit") != BASE_COMMIT or
            data.get("baseline_tree") != BASE_TREE):
        raise ValueError("Scope schema or exact baseline identity differs")
    files = data.get("files")
    if not isinstance(files, list) or not 1 <= len(files) <= MAX_FILES:
        raise ValueError("Scope requires 1..256 explicitly hashed files")
    seen, total, result = set(), 0, []
    for entry in files:
        if not isinstance(entry, dict):
            raise ValueError("Each scope entry must be an object")
        name = relative_path(entry.get("path"))
        if name.casefold() in seen:
            raise ValueError(f"Duplicate case-insensitive scoped path: {name}")
        seen.add(name.casefold())
        size, digest = entry.get("size"), entry.get("sha256")
        if (type(size) is not int or not 0 <= size <= MAX_FILE_BYTES or
                not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest)):
            raise ValueError(f"Invalid raw size/SHA256 for {name}")
        total += size
        result.append({"path": name, "size": size, "sha256": digest})
    if total > MAX_TOTAL_BYTES:
        raise ValueError("Scoped source exceeds the 128 MiB artifact limit")
    return sorted(result, key=lambda entry: entry["path"])


def regular_file(root: Path, name: str) -> Path:
    """Reject aliases and links without following a scoped source leaf."""
    target = root / name
    current = root
    for part in ("", *PurePosixPath(name).parts):
        if part:
            current = current / part
        info = current.lstat()
        if (stat.S_ISLNK(info.st_mode) or
                getattr(info, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT):
            raise ValueError(f"Scoped source is a link/reparse path: {current}")
    if not target.is_file() or target.resolve() != target:
        raise ValueError(f"Scoped source is not a regular exact path: {target}")
    return target


def inherited_layout() -> Layout:
    value = os.environ.get("BTH_QA_EVIDENCE_DIR")
    if not value:
        raise ValueError("Run through bth_qa_guarded_run; inherited evidence directory is required")
    manifest = Path(value) / "storage-manifest.json"
    data = json.loads(manifest.read_text(encoding="utf-8-sig"))
    if data.get("schema") != "bth-qa-storage/v1" or not data.get("prepared"):
        raise ValueError("Only an ordinary fresh prepared QA layout is accepted")
    layout = Layout(**{key: Path(data["paths"][key]) for key in LAYOUT_PATHS},
                    run_id=data["run_id"], token=data["token"],
                    expected_write_bytes=data["expected_write_bytes"],
                    reserve_bytes=data["reserve_bytes"], prepared=True)
    if layout.manifest_path != manifest or str(layout.root).casefold() != r"E:\CodexQA\BTH".casefold():
        raise ValueError("Inherited manifest must identify the exact admitted E: layout")
    validate_layout(layout, prepared=True)
    return layout


def write_json(path: Path, data: dict) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def transfer(args) -> dict:
    layout = inherited_layout()
    stage = layout.workspace / ".tmp" / ("crt-transfer-" + layout.run_id)
    artifact = stage / "artifact"
    export = layout.evidence / "artifact-export"
    outputs = (stage, export)
    validate_layout(layout, prepared=True, extra_write_paths=outputs)
    if stage.exists() or export.exists():
        raise ValueError("Artifact staging/export must be fresh; existing output is retained")
    export_shell = Path(args.export_shell)
    if (export_shell != APPROVED_EXPORT_SHELL or export_shell.resolve() != export_shell or
            not re.fullmatch(r"[0-9a-f]{64}", args.export_shell_sha256)):
        raise ValueError("Explicit exact approved PowerShell path and lowercase SHA256 are required")
    regular_file(export_shell.parent, export_shell.name)
    if sha256(export_shell.read_bytes()) != args.export_shell_sha256:
        raise ValueError("Approved export PowerShell executable hash differs from caller's pin")
    scope_path = Path(args.scope_manifest)
    scope_raw = scope_path.read_bytes()
    scope = json.loads(scope_raw.decode("utf-8-sig"))
    entries = parse_scope(scope)
    source = Path(scope["source_root"])
    if not source.is_absolute() or source.drive.casefold() != "c:":
        raise ValueError("Scope must identify the authoritative read-only C: source checkout")
    if source.resolve() != source:
        raise ValueError("Source root must be an exact resolved directory")
    # Check all bytes before the first write or child. No Git runs in C:.
    for entry in entries:
        raw = regular_file(source, entry["path"]).read_bytes()
        if len(raw) != entry["size"] or sha256(raw) != entry["sha256"]:
            raise ValueError(f"Frozen C: source changed: {entry['path']}")

    # Remove inherited Git plumbing overrides; ordinary repository config and
    # attributes still govern clean normalization. Never set safe.directory.
    env = {key: value for key, value in os.environ.items() if not key.upper().startswith("GIT_")}
    env["GIT_OPTIONAL_LOCKS"] = "0"

    def child(command, *, child_env=None, output=None):
        active_env = env if child_env is None else child_env
        check_launch(layout, cwd=layout.workspace, env=active_env, extra_write_paths=outputs)
        result = subprocess.run(command, cwd=layout.workspace, env=active_env,
                                stdin=subprocess.DEVNULL, stdout=output or subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=90, check=False)
        if result.returncode:
            diagnostics = {"command": list(command), "exit_code": result.returncode,
                           "stdout": ("<redirected to artifact file>" if output is not None else
                                      (result.stdout or b"").decode("utf-8", errors="replace")[:3000]),
                           "stderr": (result.stderr or b"").decode("utf-8", errors="replace")[:3000]}
            raise RuntimeError("Artifact child failed: " + json.dumps(diagnostics))
        return result.stdout

    def git(*tokens, child_env=None, output=None):
        return child(["git", *tokens], child_env=child_env, output=output)

    git_dir = Path(git("rev-parse", "--absolute-git-dir").decode().strip())
    if git_dir != layout.workspace / ".git" or not git_dir.is_dir():
        raise ValueError("Transfer requires the admitted E: clone's own .git directory")
    head = git("rev-parse", "HEAD").decode().strip()
    tree = git("rev-parse", BASE_COMMIT + "^{tree}").decode().strip()
    if head != BASE_COMMIT or tree != BASE_TREE:
        raise ValueError("E: HEAD/tree differs from the exact approved baseline")
    exporter = layout.workspace / "tools" / "manage_local_artifacts.ps1"
    exporter_bytes = exporter.read_bytes()
    pinned_exporter = git("show", BASE_COMMIT + ":tools/manage_local_artifacts.ps1")
    # Working-tree EOLs may differ; exporter semantics must remain baseline.
    if exporter_bytes.replace(b"\r\n", b"\n") != pinned_exporter.replace(b"\r\n", b"\n"):
        raise ValueError("The maintained artifact exporter differs from the approved baseline")
    index_path = git_dir / "index"
    original_index = index_path.read_bytes() if index_path.exists() else None
    refs_before = git("show-ref")
    validate_layout(layout, prepared=True, extra_write_paths=outputs)
    stage.mkdir(parents=True, exist_ok=False)
    artifact.mkdir()
    objects, worktree = stage / "objects", stage / "source"
    objects.mkdir()
    worktree.mkdir()
    for entry in entries:
        raw = regular_file(source, entry["path"]).read_bytes()
        if len(raw) != entry["size"] or sha256(raw) != entry["sha256"]:
            raise ValueError(f"C: source changed while copying: {entry['path']}")
        target = worktree / entry["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write(raw)
        if sha256(target.read_bytes()) != entry["sha256"]:
            raise ValueError(f"Scoped E: copy hash differs: {entry['path']}")
    scratch_env = dict(env, GIT_DIR=str(git_dir), GIT_WORK_TREE=str(worktree),
                       GIT_OBJECT_DIRECTORY=str(objects),
                       GIT_ALTERNATE_OBJECT_DIRECTORIES=str(git_dir / "objects"),
                       GIT_INDEX_FILE=str(stage / "candidate.index"))
    git("read-tree", BASE_COMMIT, child_env=scratch_env)
    paths = [entry["path"] for entry in entries]
    git("add", "--", *paths, child_env=scratch_env)
    changed = git("diff", "--cached", "--name-only", "-z", BASE_COMMIT,
                  child_env=scratch_env).decode().rstrip("\0").split("\0")
    if sorted(changed) != paths:
        raise ValueError("Patch changed-path set differs from the complete frozen scope")
    git("diff", "--cached", "--check", BASE_COMMIT, child_env=scratch_env)
    patch = artifact / "crt-practice-console.patch"
    with patch.open("xb") as stream:
        git("diff", "--cached", "--binary", "--full-index", "--no-ext-diff", "--no-textconv",
            BASE_COMMIT, "--", *paths, child_env=scratch_env, output=stream)
    candidate_tree = git("write-tree", child_env=scratch_env).decode().strip()
    verified_env = dict(scratch_env, GIT_INDEX_FILE=str(stage / "verification.index"))
    git("read-tree", BASE_COMMIT, child_env=verified_env)
    git("apply", "--cached", "--check", str(patch), child_env=verified_env)
    git("apply", "--cached", str(patch), child_env=verified_env)
    verified_tree = git("write-tree", child_env=verified_env).decode().strip()
    if verified_tree != candidate_tree:
        raise ValueError("Independent exact-base patch application produced a different tree")
    records = []
    for entry in entries:
        specification = ":" + entry["path"]
        blob = git("rev-parse", specification, child_env=scratch_env).decode().strip()
        verified_blob = git("rev-parse", specification, child_env=verified_env).decode().strip()
        if blob != verified_blob:
            raise ValueError(f"Verified patch blob differs: {entry['path']}")
        normalized = git("cat-file", "blob", blob, child_env=scratch_env)
        records.append({**entry, "raw_source_sha256": entry["sha256"],
                        "raw_copy_sha256": sha256((worktree / entry["path"]).read_bytes()),
                        "git_blob": blob, "verified_git_blob": verified_blob,
                        "normalized_size": len(normalized), "normalized_sha256": sha256(normalized)})
    for entry in entries:
        if sha256(regular_file(source, entry["path"]).read_bytes()) != entry["sha256"]:
            raise ValueError(f"Frozen C: source changed before export: {entry['path']}")
    if (git("rev-parse", "HEAD").decode().strip() != head or git("show-ref") != refs_before or
            (index_path.read_bytes() if index_path.exists() else None) != original_index):
        raise ValueError("Real E: HEAD, refs or index changed during transfer")
    with (artifact / "scope-manifest.json").open("xb") as stream:
        stream.write(scope_raw)
    receipt = {"schema": "bth.crt_transfer/v1", "passed": True,
               "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
               "baseline_commit": BASE_COMMIT, "baseline_tree": BASE_TREE,
               "candidate_tree": candidate_tree, "verified_tree": verified_tree,
               "source_root": str(source), "source_scope_sha256": sha256(scope_raw),
               "patch": patch.name, "patch_size": patch.stat().st_size,
               "patch_sha256": sha256(patch.read_bytes()), "files": records,
               "normalization": "Existing Git clean normalization/attributes; raw hashes recorded separately.",
               "real_index_refs_unchanged": True, "source_files_unchanged": True,
               "exporter_sha256": sha256(exporter_bytes),
               "export_runtime": {"path": str(export_shell), "sha256": args.export_shell_sha256},
               "scope": "Transfer artifact only. No commit, runtime, build, deployment or acceptance claim."}
    write_json(artifact / "transfer-manifest.json", receipt)
    with (artifact / "README.txt").open("x", encoding="utf-8", newline="\n") as stream:
        stream.write("CRT practice console transfer artifact\n\n"
                     f"Required baseline: {BASE_COMMIT}\nRequired baseline tree: {BASE_TREE}\n"
                     f"Expected resulting tree: {candidate_tree}\n\n"
                     "Use a clean isolated checkout at the exact baseline. Verify all SHA256 hashes first.\n"
                     "Run git apply --check crt-practice-console.patch, then git apply --index <patch>.\n"
                     "Verify git write-tree equals the expected resulting tree. Review before committing.\n"
                     "The patch contains all explicit tracked and previously untracked feature files.\n"
                     "No source file, real index/ref, profile or save was changed by this transfer.\n")
    regular_file(export_shell.parent, export_shell.name)
    if sha256(export_shell.read_bytes()) != args.export_shell_sha256:
        raise ValueError("Approved export PowerShell executable changed before launch")
    export_log = child([str(export_shell), "-NoProfile", "-File", str(exporter),
                        "-Export", str(export), "-IncludePath", str(artifact)])
    (layout.evidence / "artifact-export.log").write_bytes(export_log)
    exported = json.loads((export / "artifact_manifest.json").read_text(encoding="utf-8-sig"))
    expected = {path.relative_to(layout.workspace).as_posix(): path
                for path in artifact.iterdir() if path.is_file()}
    exported_names = [exported_path(entry["path"]) for entry in exported.get("files", [])]
    if (set(exported_names) != set(expected) or len(exported_names) != len(expected) or
            exported.get("file_count") != len(expected)):
        raise ValueError("Artifact exporter manifest file set differs")
    for entry, name in zip(exported["files"], exported_names):
        raw = (export / name).read_bytes()
        if (len(raw) != entry["size"] or sha256(raw) != entry["sha256"] or
                raw != expected[name].read_bytes()):
            raise ValueError(f"Exported artifact hash/size differs: {name}")
    if (git("rev-parse", "HEAD").decode().strip() != head or git("show-ref") != refs_before or
            (index_path.read_bytes() if index_path.exists() else None) != original_index):
        raise ValueError("Real E: HEAD, refs or index changed during artifact export")
    result = {"schema": "bth.crt_transfer_export/v1", "passed": True,
              "storage_manifest": str(layout.manifest_path), "export": str(export),
              "artifact_manifest": str(export / "artifact_manifest.json"),
              "artifact_manifest_sha256": sha256((export / "artifact_manifest.json").read_bytes()),
              "exported_artifact": str(export / artifact.relative_to(layout.workspace)),
              "patch_sha256": receipt["patch_sha256"], "verified_tree": verified_tree,
              "baseline_commit": BASE_COMMIT, "file_count": len(entries),
              "real_index_refs_unchanged": True}
    write_json(layout.evidence / "transfer-export.json", result)
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scope-manifest", required=True,
                        help="Frozen caller-created C: source scope with raw file hashes")
    parser.add_argument("--export-shell", required=True,
                        help="Exact caller-approved existing PowerShell executable; no fallback")
    parser.add_argument("--export-shell-sha256", required=True,
                        help="Caller-pinned SHA256 of the approved existing PowerShell executable")
    args = parser.parse_args(argv)
    try:
        print(json.dumps(transfer(args)))
        return 0
    except StorageGuardError as error:
        print(json.dumps({"status": "CRT_TRANSFER_STORAGE_REJECTED", **error.as_dict()}), file=sys.stderr)
        return 2
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, KeyError) as error:
        print(json.dumps({"status": "CRT_TRANSFER_UNQUALIFIED", "error": str(error)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
