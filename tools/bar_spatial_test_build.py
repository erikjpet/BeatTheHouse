"""Build one committed Bar art TEST stage in fresh admitted E: storage.

Explicit single-Job phases; no publication, network, browser or server commands.
The supervisor owns every child through bth_qa_guarded_run.execute. Internal
workers only perform admitted local file work and never create children.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import tarfile

from bth_qa_storage import Layout, plan_layout, prepare_layout, validate_layout
from bth_qa_guarded_run import execute


PHASES = ("source-identity", "archive", "extract", "seed", "identity", "import",
          "export", "webgl-apply", "webgl-verify", "finalize", "verify")
FILE_PHASES = {"extract", "seed", "finalize", "verify"}
ENGINE_SHA = "fc759f9d296fe54f09ab66d41df6ddd2d278493b0e71109f6688ef029ad271ae"
NATIVE_SHA = "9c34c4ea306efe66a13a9707a64f53573a31779e3b300bd359ed61c2f2ec33fc"
NATIVE_NAME = "coin_pusher_native_v3_10.web.template_release.wasm32.nothreads.wasm"
EDITOR_NATIVE_NAME = "coin_pusher_native_v3_10.windows.template_debug.x86_64.nothreads.dll"
TEMPLATE_SHA = "cf371f607aa9cb18e690bd595976c1baaf00c8cec24078e4a307fd515ad07913"
TEMPLATE_NAME = "web_dlink_nothreads_release.zip"
PRESETS_SHA = "2270c54e6bec3b36bacafc87aa28c1e656fec45dd52f7df8cc28d2e04426aa5f"
PERSISTENCE_SHA = "c4baa91d7a72d803040ee3b043f205d73271c115202b66efed23262066393b61"
BAR_BACKGROUND = "assets/art/environments/bar/background.png"
IMPORT_POLICY = b"[editor]\nimport/use_multiple_threads=false\n\n[threading]\nworker_pool/max_threads=1\n"
HELPERS = ("prepare_environment_art_build_identity.py", "prepare_environment_art_test_web.py",
           "publish_environment_art_test.py", "audit_pck_manifest.py", "web_gl_handles.mjs",
           "web_gl_handles.lock.json", "web_gl_handles_allocator.txt")


def sha(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def no_links(path):
    path = Path(path).absolute()
    for item in (path, *path.parents):
        if item.is_symlink() or getattr(item, "is_junction", lambda: False)():
            raise ValueError("Link/junction input or output is forbidden: " + str(item))
    return path


def write_new(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def copy_new(source, destination):
    destination = no_links(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if not destination.is_file() or sha(destination) != sha(source):
            raise ValueError("Existing seeded input differs; refusing overwrite: " + str(destination))
        return
    with Path(source).open("rb") as src, destination.open("xb") as dst:
        shutil.copyfileobj(src, dst)


def config(args):
    for value, length, name in ((args.source_commit, 40, "commit"), (args.source_tree, 40, "tree"),
                                (args.art_package_sha256, 64, "art package")):
        if not re.fullmatch("[a-f0-9]{%d}" % length, value) or value == "0" * length:
            raise ValueError("Exact nonzero lowercase full " + name + " is required")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,47}", args.run_prefix):
        raise ValueError("Run prefix must be 1..48 letters/digits/underscores/hyphens")
    if not args.workspace.is_absolute() or not args.stage.is_absolute():
        raise ValueError("Workspace/stage must be explicit absolute E: paths")
    workspace, stage = no_links(args.workspace), no_links(args.stage)
    if stage.name != "stage" or not stage.is_relative_to(workspace) or stage == workspace:
        raise ValueError("Explicit stage must be a strict workspace descendant named stage")
    if stage.parent == workspace:
        raise ValueError("Stage needs its own fresh attempt parent inside the workspace")
    if not 1 <= args.timeout <= 1200:
        raise ValueError("Timeout must be 1..1200 seconds")
    inputs = {name: no_links(getattr(args, name)).resolve(strict=True)
              for name in ("engine", "native_library", "template", "git", "node", "baseline_stage", "git_dir")}
    for name in ("engine", "native_library", "template", "git", "node"):
        if not inputs[name].is_file():
            raise ValueError("Explicit input executable/library/template missing: " + name)
    for name, expected in (("engine", ENGINE_SHA), ("native_library", NATIVE_SHA), ("template", TEMPLATE_SHA)):
        if sha(inputs[name]) != expected:
            raise ValueError("Locked input SHA256 mismatch: " + name)
    if inputs["native_library"].name != NATIVE_NAME or inputs["template"].name != TEMPLATE_NAME:
        raise ValueError("Locked native/template basename mismatch")
    baseline = inputs["baseline_stage"] / "build_manifest.json"
    if not baseline.is_file() or not inputs["git_dir"].is_dir():
        raise ValueError("Existing read-only baseline stage and repository Git directory required")
    if inputs["baseline_stage"].is_relative_to(workspace) or workspace.is_relative_to(inputs["baseline_stage"]):
        raise ValueError("Fresh workspace and retained baseline stage must be disjoint")
    editor = None
    if bool(args.editor_native_library) != bool(args.editor_native_sha256):
        raise ValueError("Editor native DLL and its full expected SHA256 must be supplied together")
    if args.editor_native_library:
        editor = no_links(args.editor_native_library).resolve(strict=True)
        if (editor.name != EDITOR_NATIVE_NAME or not re.fullmatch(r"[a-f0-9]{64}", args.editor_native_sha256) or
                sha(editor) != args.editor_native_sha256):
            raise ValueError("Explicit Windows editor native DLL basename/hash mismatch")
    result = {"schema": "bth.bar_test_build_inputs/v1", "workspace": str(workspace), "stage": str(stage),
            "qa_root": str(no_links(args.qa_root)), "run_prefix": args.run_prefix,
            "source_commit": args.source_commit, "source_tree": args.source_tree,
            "art_package_sha256": args.art_package_sha256,
            **{name: str(path) for name, path in inputs.items()},
            "engine_sha256": ENGINE_SHA, "native_library_sha256": NATIVE_SHA,
            "template_sha256": TEMPLATE_SHA, "git_sha256": sha(inputs["git"]),
            "node_sha256": sha(inputs["node"]), "python_sha256": sha(sys.executable),
            "baseline_manifest_sha256": sha(baseline), "adapter_sha256": sha(__file__),
            "editor_native_library": None if editor is None else str(editor),
            "editor_native_sha256": args.editor_native_sha256,
            "missing_setup": (["Supply explicit Windows editor debug native DLL/hash for an error-free headless import"]
                              if os.name == "nt" and editor is None else [])}
    if getattr(args, "environment", "bar") == "grand_casino":
        if not args.approval_json or not args.approval_sha256:
            raise ValueError("Grand builds require the exact independent approval document and its SHA256")
        from grand_spatial_test_profile import augment_config
        return augment_config(result, args)
    if getattr(args, "approval_json", None) or getattr(args, "approval_sha256", None):
        raise ValueError("Grand approval flags are not accepted by the unchanged Bar profile")
    return result


def grand_profile(cfg):
    return cfg is not None and cfg.get("environment") == "grand_casino"


def config_sha(cfg):
    return hashlib.sha256(json.dumps(cfg, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def previous(cfg, phase):
    evidence = Path(cfg["qa_root"]) / "runs" / (cfg["run_prefix"] + "-" + phase) / "evidence"
    result = json.loads((evidence / "phase-result.json").read_text(encoding="utf-8"))
    job = json.loads((evidence / "job.json").read_text(encoding="utf-8"))
    if (result.get("config_sha256") != config_sha(cfg) or result.get("phase") != phase or
            result.get("status") != "PASS" or job.get("exit_code") != 0 or
            job.get("active_at_release") != 0 or not job.get("assigned_before_execution") or
            job.get("error") or job.get("cleanup_errors") or job.get("timed_out") or
            job.get("log_error") or job.get("log_truncated") or
            "storage_gate_before_job" not in job or "storage_gate_before_child" not in job or
            job.get("limits", {}).get("cpu_rate") != 1200 or
            job.get("limits", {}).get("job_memory_limit_bytes") != 2 * 1024 ** 3):
        raise ValueError("Prior exact guarded phase is not qualified: " + phase)
    return result


def load_worker_layout(cfg):
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    receipt = json.loads((evidence / "storage-manifest.json").read_text(encoding="utf-8"))
    layout = Layout(**{key: Path(value) for key, value in receipt["paths"].items()},
                    **{key: receipt[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    if layout.workspace != Path(cfg["workspace"]):
        raise ValueError("Worker workspace differs from the actual prepared layout")
    validate_layout(layout, extra_write_paths=(layout.workspace, layout.evidence))
    return layout


def bar_payload_seal(workspace):
    """Derive the exact current 19-file Bar seal, including global index bytes."""
    spec = json.loads((workspace / "data/art/environments/bar.json").read_text(encoding="utf-8-sig"))
    animations = spec.get("animations", [])
    if len(animations) != 17 or len({entry.get("id") for entry in animations}) != 17:
        raise ValueError("Expected all 17 unchanged Bar animation entries")
    textures = set()
    for entry in animations:
        relative = entry.get("texture", "")
        if not isinstance(relative, str):
            raise ValueError("Invalid Bar motion texture path")
        name = PurePosixPath(relative)
        if (not relative.startswith("anim/") or name.suffix != ".png" or
                name.is_absolute() or ".." in name.parts or "\\" in relative or name.as_posix() != relative):
            raise ValueError("Invalid Bar motion texture path")
        textures.add("assets/art/environments/bar/" + relative)
    if len(textures) != 15:
        raise ValueError("Expected the 15 distinct Bar animation PNGs")
    names = textures | {BAR_BACKGROUND, "assets/art/environments/bar/counters/bar_main_counter.png",
                        "data/art/environments/bar.json", "data/art/environments/index.json"}
    files = {}
    for relative in sorted(names):
        path = no_links(workspace / relative)
        if not path.resolve(strict=True).is_relative_to(workspace):
            raise ValueError("Bar seal path escaped snapshot")
        files[relative] = {"sha256": sha(path), "bytes": path.stat().st_size}
    if len(files) != 19:
        raise ValueError("Bar seal must bind exactly 19 payload files")
    text = "\n".join(path + " " + files[path]["sha256"] for path in sorted(files))
    return {"package_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(), "files": files,
            "algorithm": "SHA256 of sorted path + space + file SHA256 rows joined by LF, no trailing LF"}


def snapshot_pins(workspace, cfg):
    if (workspace / ".git").exists() or sha(workspace / "export_presets.cfg") != PRESETS_SHA:
        raise ValueError("Expected an archive snapshot with unchanged export presets")
    if sha(workspace / "scripts/core/persistence_paths.gd") != PERSISTENCE_SHA:
        raise ValueError("TEST persistence code differs from its reviewed source")
    lock = json.loads((workspace / "native/coin_pusher/toolchain.lock.json").read_text(encoding="utf-8"))
    if (lock["godot"]["commit"] != "89cea143987d564363e15d207438530651d943ac" or
            lock["web"]["version"] != "4.0.20" or lock["web"]["template_sha256"] != TEMPLATE_SHA):
        raise ValueError("Snapshot engine/native toolchain lock differs")
    for name in HELPERS:
        archived = (workspace / "tools" / name).read_bytes().replace(b"\r\n", b"\n")
        maintained = (Path(__file__).parent / name).read_bytes().replace(b"\r\n", b"\n")
        if archived != maintained:
            raise ValueError("Archive/adapter maintained helper differs: " + name)
    if grand_profile(cfg):
        from grand_spatial_test_profile import source_seal
        for name in ("grand_spatial_test_profile.py", "grand_spatial_test_build.py"):
            archived = (workspace / "tools" / name).read_bytes().replace(b"\r\n", b"\n")
            maintained = (Path(__file__).parent / name).read_bytes().replace(b"\r\n", b"\n")
            if archived != maintained:
                raise ValueError("Grand profile/entrypoint differs from exact archived source: " + name)
        seal = source_seal(workspace, cfg)
    else:
        seal = bar_payload_seal(workspace)
    if seal["package_sha256"] != cfg["art_package_sha256"]:
        label = "22-file Grand" if grand_profile(cfg) else "19-file Bar"
        raise ValueError("Actual extracted " + label + " seal differs: " + seal["package_sha256"])
    return seal


def pck_entry_bytes(data, directory, entry):
    """Read and authenticate actual standalone PCK payload bytes, not directory claims."""
    import audit_pck_manifest
    if entry.get("flags") != 0 or not isinstance(entry.get("bytes"), int) or entry["bytes"] <= 0:
        raise ValueError("PCK entry flags/size are not plain nonempty content: " + entry.get("path", ""))
    start = directory["file_base"] + entry["offset"]
    end = start + entry["bytes"]
    if start < audit_pck_manifest.HEADER_BYTES or end < start or end > len(data):
        raise ValueError("PCK entry payload bounds invalid: " + entry.get("path", ""))
    payload = data[start:end]
    if hashlib.md5(payload).hexdigest() != entry["md5"]:
        raise ValueError("Actual PCK entry payload MD5 differs from its record: " + entry.get("path", ""))
    return payload


def decode_uid_cache(raw):
    """Decode the complete UID path map, rejecting truncated or aliased records."""
    if len(raw) < 4:
        raise ValueError("UID cache header is truncated")
    count = struct.unpack_from("<I", raw)[0]
    if not 1 <= count <= 10000:
        raise ValueError("UID cache count is outside the bounded parser")
    cursor, result, seen_ids = 4, {}, set()
    for _ in range(count):
        if cursor + 12 > len(raw):
            raise ValueError("UID cache record is truncated")
        uid, size = struct.unpack_from("<QI", raw, cursor)
        cursor += 12
        if not 0 < size <= 65536 or cursor + size > len(raw):
            raise ValueError("UID cache path is truncated or oversized")
        path = raw[cursor:cursor + size].decode("utf-8")
        cursor += size
        name = PurePosixPath(path.removeprefix("res://"))
        if (not path.startswith("res://") or name.is_absolute() or ".." in name.parts or
                "\\" in path or "res://" + name.as_posix() != path or path in result or uid in seen_ids):
            raise ValueError("UID cache contains a noncanonical or duplicate binding: " + path)
        result[path] = str(uid)
        seen_ids.add(uid)
    if cursor != len(raw) or len(result) != count:
        raise ValueError("UID cache trailing bytes/count mismatch")
    return result


def stage_links(workspace, stage, baseline, cfg=None):
    """Bind all retained art sources, import hashes and actual PCK resources."""
    sys.path.insert(0, str(workspace / "tools"))
    import audit_pck_manifest
    data = (stage / "index.pck").read_bytes()
    directory = audit_pck_manifest.find_directory(data)
    failures = audit_pck_manifest.audit(directory["entries"])
    if failures:
        raise ValueError("PCK audit failed: " + " | ".join(failures[:12]))
    entries = {entry["path"]: entry for entry in directory["entries"]}
    if any(name.startswith(("docs/", "tools/", "review_artifacts/", "scripts/tests/", "candidate_sources/")) for name in entries):
        raise ValueError("Non-runtime source/evidence leaked into PCK")
    raw, compiled, links = {}, {}, []
    old_raw, old_compiled = baseline["art_source_files"], baseline["compiled_art_sha256"]
    if len(old_raw) != 421 or len(old_compiled) != 400 or BAR_BACKGROUND not in old_raw:
        raise ValueError("Expected the retained complete 20-interior/12-doorway baseline inventory")
    bar_compiled = None
    grand = grand_profile(cfg)
    approved, changed_compiled = {}, set()
    if grand:
        from grand_spatial_test_profile import changed_sources
        approved = changed_sources(cfg)
    for relative, old_hash in old_raw.items():
        source = no_links(workspace / relative)
        if not source.resolve(strict=True).is_relative_to(workspace):
            raise ValueError("Baseline art path escaped snapshot")
        raw[relative] = sha(source)
        if grand and relative in approved:
            if raw[relative] != approved[relative] or raw[relative] == old_hash:
                raise ValueError("Grand raw source is not the exact approved changed hash: " + relative)
        elif (grand or relative != BAR_BACKGROUND) and raw[relative] != old_hash:
            raise ValueError("Unrelated art source changed: " + relative)
        if relative.endswith(".png"):
            imported = Path(str(source) + ".import").read_text(encoding="utf-8-sig")
            match = re.search(r'^path="res://([^"\n]+)"', imported, re.M)
            if not match:
                raise ValueError("Missing PNG import linkage: " + relative)
            target = match.group(1)
            compiled_file = no_links(workspace / target)
            if not compiled_file.resolve(strict=True).is_relative_to(workspace):
                raise ValueError("Imported texture escaped snapshot")
            source_md5 = hashlib.md5(source.read_bytes()).hexdigest()
            md5_text = compiled_file.with_suffix(".md5").read_text(encoding="utf-8-sig")
            if 'source_md5="' + source_md5 + '"' not in md5_text:
                raise ValueError("Stale source import MD5: " + relative)
            compiled_bytes = compiled_file.read_bytes()
            compiled[target] = hashlib.sha256(compiled_bytes).hexdigest()
            actual = pck_entry_bytes(data, directory, entries[target]) if target in entries else None
            if actual != compiled_bytes or hashlib.sha256(actual or b"").hexdigest() != compiled[target]:
                raise ValueError("Compiled texture/PCK mismatch: " + target)
            if grand and relative in approved:
                if compiled[target] == old_compiled.get(target):
                    raise ValueError("Approved Grand PNG produced no compiled texture change: " + relative)
                changed_compiled.add(target)
            elif not grand and relative == BAR_BACKGROUND:
                bar_compiled = target
            elif compiled[target] != old_compiled.get(target):
                raise ValueError("Unrelated compiled art changed: " + relative)
            links.append({"source": relative, "source_sha256": raw[relative], "compiled": target,
                          "compiled_sha256": compiled[target], "pck_payload_sha256": hashlib.sha256(actual).hexdigest(),
                          "pck_md5": entries[target]["md5"], "actual_payload_verified": True})
        else:
            source_bytes = source.read_bytes()
            actual = pck_entry_bytes(data, directory, entries[relative]) if relative in entries else None
            if actual != source_bytes or hashlib.sha256(actual or b"").hexdigest() != raw[relative]:
                raise ValueError("Actual art manifest/PCK payload mismatch: " + relative)
    if grand:
        from grand_spatial_test_profile import compiled_targets
        actual = {name for name in raw if raw[name] != old_raw[name]}
        if actual != set(approved) or changed_compiled != compiled_targets(cfg["grand_approval"]):
            raise ValueError("Grand raw/compiled delta does not exactly match independent approval")
    elif raw[BAR_BACKGROUND] == old_raw[BAR_BACKGROUND] or compiled.get(bar_compiled) == old_compiled.get(bar_compiled):
        raise ValueError("Bar background was not changed/reimported")
    if set(compiled) != set(old_compiled):
        raise ValueError("Art texture inventory changed")
    return data, directory, entries, raw, compiled, links, changed_compiled if grand else bar_compiled


def finalize(cfg, layout):
    workspace, stage = Path(cfg["workspace"]), Path(cfg["stage"])
    sys.path.insert(0, str(workspace / "tools"))
    import audit_pck_manifest
    from prepare_environment_art_build_identity import verify_embedded_identity
    from prepare_environment_art_test_web import prepare_test_html, TEST_ARGS, TEST_PERSISTENT_PATHS
    from publish_environment_art_test import validate_payload
    seal = snapshot_pins(workspace, cfg)
    baseline_stage = Path(cfg["baseline_stage"])
    baseline = json.loads((baseline_stage / "build_manifest.json").read_text(encoding="utf-8-sig"))
    validate_payload(baseline_stage, baseline["source_commit"], baseline["art_package_sha256"])
    identity = json.loads((workspace / "build_manifest.json").read_text(encoding="utf-8"))
    if (identity["source_commit"] != cfg["source_commit"] or identity["source_tree"] != cfg["source_tree"] or
            identity["art_package_sha256"] != cfg["art_package_sha256"]):
        raise ValueError("Embedded pre-export identity differs from requested source")
    embedded = verify_embedded_identity(stage / "index.pck", identity)
    data, directory, entries, raw, compiled, links, bar_compiled = stage_links(workspace, stage, baseline, cfg)
    old_data = (baseline_stage / "index.pck").read_bytes()
    old_directory = audit_pck_manifest.find_directory(old_data)
    old_entries = {entry["path"]: entry for entry in old_directory["entries"]}
    if entries.keys() != old_entries.keys():
        raise ValueError("Unexpected PCK resource additions/removals")
    changed = []
    for name, entry in entries.items():
        old = old_entries[name]
        if pck_entry_bytes(data, directory, entry) != pck_entry_bytes(old_data, old_directory, old):
            changed.append(name)
    uid_path = ".godot/uid_cache.bin"
    old_uid_map = decode_uid_cache(pck_entry_bytes(old_data, old_directory, old_entries[uid_path]))
    new_uid_map = decode_uid_cache(pck_entry_bytes(data, directory, entries[uid_path]))
    if len(old_uid_map) != 1605 or old_uid_map != new_uid_map:
        differences = [path for path in sorted(old_uid_map.keys() | new_uid_map.keys())
                       if old_uid_map.get(path) != new_uid_map.get(path)]
        raise ValueError("Complete retained 1605-entry UID mapping differs: " + repr(differences[:20]))
    uid_map_digest = hashlib.sha256(json.dumps(old_uid_map, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    uid_equivalence = {"entry": uid_path, "entries": len(old_uid_map), "complete_mapping_equal": True,
                       "bytes_equal": uid_path not in changed, "old_mapping_sha256": uid_map_digest,
                       "new_mapping_sha256": uid_map_digest, "path_to_uid": old_uid_map,
                       "scope": "All bindings compared; no additional QA paths or UID aliases are allowed."}
    if grand_profile(cfg):
        from grand_spatial_test_profile import GRAND_JSON
        required = {"build_manifest.json", GRAND_JSON} | bar_compiled
        allowed = required
    else:
        required = {"build_manifest.json", bar_compiled}
        allowed = required | {".godot/uid_cache.bin", ".godot/global_script_class_cache.cfg"}
    if not required.issubset(changed) or not set(changed).issubset(allowed):
        raise ValueError("Unexpected PCK delta: " + repr(changed))
    classes = ".godot/global_script_class_cache.cfg"
    if classes in changed:
        def class_records(blob, index, item):
            start = index["file_base"] + item["offset"]
            return set(re.findall(r"\{([^{}]*)\}", blob[start:start + item["bytes"]].decode("utf-8")))
        if class_records(data, directory, entries[classes]) != class_records(old_data, old_directory, old_entries[classes]):
            raise ValueError("Script class record set changed")
    lock = json.loads((workspace / "tools/web_gl_handles.lock.json").read_text())
    if sha(stage / "index.js") != lock["output_sha256"] or not (stage / lock["receipt_file"]).is_file():
        raise ValueError("Maintained WebGL transform/receipt missing")
    if sha(stage / NATIVE_NAME) != NATIVE_SHA:
        raise ValueError("Exported native library differs from locked input")
    normal_html = stage / "index.html"
    isolated_html = prepare_test_html(normal_html.read_text(encoding="utf-8"),
                                      (workspace / "scripts/core/persistence_paths.gd").read_text(encoding="utf-8-sig"))
    archived_html = stage.parent / "normal-index.html"
    if archived_html.exists() or (stage / "build_manifest.json").exists():
        raise ValueError("Finalization output already exists; no overwrite")
    normal_html.rename(archived_html)
    with normal_html.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(isolated_html)
    active = dict(baseline["active_art_packages"])
    doorways = dict(baseline["active_doorway_packages"])
    if len(active) != 20 or len(doorways) != 12 or "bar" not in active:
        raise ValueError("Incomplete retained room/doorway package inventory")
    active["grand_casino" if grand_profile(cfg) else "bar"] = cfg["art_package_sha256"]
    if any(p.is_dir() for p in stage.iterdir()):
        raise ValueError("Unexpected directory inside flat Web stage")
    manifest = dict(identity)
    manifest.update(source_branch="codex/environment-art-layers", source_archive_sha256=sha(stage.parent / "source.tar"),
        active_art_packages=active, active_doorway_packages=doorways, art_source_files=raw,
        compiled_art_sha256=compiled, template_sha256=TEMPLATE_SHA, persistence_core_sha256=PERSISTENCE_SHA,
        test_args=TEST_ARGS, persistent_paths=TEST_PERSISTENT_PATHS,
        generated_at=datetime.now(timezone.utc).isoformat(),
        embedded_manifest_sha256=embedded["embedded_manifest_sha256"], embedded_manifest_md5=embedded["embedded_manifest_md5"],
        previous_test_source_commit=baseline["source_commit"],
        files={p.name: {"bytes": p.stat().st_size, "sha256": sha(p)} for p in sorted(stage.iterdir()) if p.is_file()})
    if grand_profile(cfg):
        from grand_spatial_test_profile import validate_manifest
        validate_manifest(manifest, cfg["grand_approval"])
    write_new(stage / "build_manifest.json", manifest)
    validate_payload(stage, cfg["source_commit"], cfg["art_package_sha256"])
    write_new(layout.evidence / "art-source-import-pck-linkage.json", {"raw_files": len(raw), "compiled_textures": len(compiled), "links": links})
    write_new(layout.evidence / ("grand-package-seal.json" if grand_profile(cfg) else "bar-package-seal.json"), seal)
    write_new(layout.evidence / "uid-cache-equivalence.json", uid_equivalence)
    write_new(layout.evidence / "pck-diff.json", {"added": [], "removed": [], "changed": sorted(changed),
        "scope": ("Exact approved Grand CTEXs, one typed Grand JSON reanchor and bound identity; all cache/SCN/GDC bytes unchanged."
                  if grand_profile(cfg) else "Bar background CTEX and bound identity; equivalent cache metadata only."),
        ("web_js_preserved" if grand_profile(cfg) else "web_js_packaging_correction"): {"prior_sha256": sha(baseline_stage / "index.js"),
            "new_sha256": sha(stage / "index.js"), "receipt": lock["receipt_file"]}})
    return {"stage": str(stage), "manifest_sha256": sha(stage / "build_manifest.json"), "pck_sha256": sha(stage / "index.pck")}


def worker(phase, cfg):
    layout = load_worker_layout(cfg)
    workspace, stage = layout.workspace, Path(cfg["stage"])
    details = {}
    if phase == "extract":
        archive = stage.parent / "source.tar"
        if sha(archive) != previous(cfg, "archive")["artifacts"]["archive_sha256"]:
            raise ValueError("Archive changed after its guarded Git export")
        count = 0
        with tarfile.open(archive, "r:") as package:
            if package.pax_headers.get("comment") != cfg["source_commit"]:
                raise ValueError("Git archive PAX commit does not match requested source")
            members = package.getmembers()
            for member in members:
                name = PurePosixPath(member.name)
                if (name.is_absolute() or ".." in name.parts or "\\" in member.name or
                        not (member.isfile() or member.isdir()) or name.as_posix() != member.name.rstrip("/")):
                    raise ValueError("Unsafe/noncanonical archive member: " + member.name)
                destination = no_links(workspace / name.as_posix())
                if not destination.resolve().is_relative_to(workspace):
                    raise ValueError("Archive member escapes workspace")
                if member.isfile() and destination.exists():
                    raise ValueError("Archive extraction would overwrite an existing file: " + member.name)
            for member in members:
                destination = workspace / member.name
                if member.isdir():
                    destination.mkdir(parents=True, exist_ok=True)
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with package.extractfile(member) as source, destination.open("xb") as target:
                        shutil.copyfileobj(source, target)
                    count += 1
        seal = snapshot_pins(workspace, cfg)
        details = {"files_extracted": count, "source_commit": cfg["source_commit"], "archive_sha256": sha(archive),
                   ("derived_grand_seal" if grand_profile(cfg) else "derived_bar_seal"): seal}
    elif phase == "seed":
        snapshot_pins(workspace, cfg)
        destination = workspace / "addons/coin_pusher_native/bin" / NATIVE_NAME
        copy_new(cfg["native_library"], destination)
        copy_new(workspace / "native/coin_pusher/coin_pusher_native.gdextension.template",
                 workspace / "addons/coin_pusher_native/coin_pusher_native.gdextension")
        if cfg["editor_native_library"]:
            copy_new(cfg["editor_native_library"], workspace / "addons/coin_pusher_native/bin" / EDITOR_NATIVE_NAME)
        details = {"native_library": str(destination), "native_library_sha256": sha(destination)}
    elif phase == "finalize":
        details = finalize(cfg, layout)
    elif phase == "verify":
        sys.path.insert(0, str(workspace / "tools"))
        from publish_environment_art_test import validate_payload
        manifest = validate_payload(stage, cfg["source_commit"], cfg["art_package_sha256"])
        if manifest["source_tree"] != cfg["source_tree"] or manifest["engine_sha256"] != ENGINE_SHA:
            raise ValueError("Final stage identity differs")
        details = {"status": "VERIFIED_FRESH_E_TEST_STAGE_NOT_PUBLISHED", "stage": str(stage),
                   "manifest_sha256": sha(stage / "build_manifest.json"), "files_verified": len(manifest["files"]) + 1,
                   "source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"], "published": False}
    write_new(layout.evidence / "worker-result.json", details)
    print(json.dumps(details))


def child_command(phase, cfg, args):
    workspace, stage = Path(cfg["workspace"]), Path(cfg["stage"])
    if phase in FILE_PHASES:
        return [sys.executable, "-B", str(Path(__file__).resolve()), phase, "--worker", *args]
    if phase == "source-identity":
        return [cfg["git"], "--git-dir=" + cfg["git_dir"], "show", "-s", "--format=%H%n%T", cfg["source_commit"]]
    if phase == "archive":
        return [cfg["git"], "--git-dir=" + cfg["git_dir"], "archive", "--format=tar", "--output=" + str(stage.parent / "source.tar"), cfg["source_commit"]]
    if phase == "identity":
        return [sys.executable, "-B", str(workspace / "tools/prepare_environment_art_build_identity.py"), "prepare",
                "--snapshot", str(workspace), "--source-commit", cfg["source_commit"], "--source-tree", cfg["source_tree"],
                "--engine", cfg["engine"], "--native-library", str(workspace / "addons/coin_pusher_native/bin" / NATIVE_NAME),
                "--export-presets", str(workspace / "export_presets.cfg"), "--art-package-sha256", cfg["art_package_sha256"],
                "--build-version", "0.6.0-art-test+" + cfg["source_commit"][:12]]
    if phase == "import":
        return [cfg["engine"], "--headless", "--path", str(workspace), "--editor", "--import"]
    if phase == "export":
        return [cfg["engine"], "--headless", "--path", str(workspace), "--export-release", "Web", str(stage / "index.html")]
    if phase.startswith("webgl-"):
        command = [cfg["node"], str(workspace / "tools/web_gl_handles.mjs"), phase.split("-", 1)[1], "--stage", str(stage)]
        return command + (["--owned-root", str(stage.parent)] if phase == "webgl-apply" else [])
    raise ValueError("Unknown build phase")


def run_phase(phase, cfg, args, timeout):
    workspace, stage = Path(cfg["workspace"]), Path(cfg["stage"])
    if phase == "source-identity":
        if workspace.exists() and any(workspace.iterdir()):
            raise ValueError("First phase requires a fresh empty/absent workspace; never migrate an existing one")
    else:
        previous(cfg, PHASES[PHASES.index(phase) - 1])
    layout = plan_layout(root=cfg["qa_root"], workspace=str(workspace), run_id=cfg["run_prefix"] + "-" + phase)
    layout = prepare_layout(layout)
    validate_layout(layout, extra_write_paths=(workspace, stage.parent, layout.evidence))
    write_new(layout.evidence / "build-inputs.json", cfg)
    if phase == "archive":
        stage.parent.mkdir(parents=True, exist_ok=False)
    if phase == "export":
        snapshot_pins(workspace, cfg)
        if (workspace / "override.cfg").exists() or stage.exists():
            raise ValueError("Export requires absent override.cfg and a fresh stage")
        stage.mkdir()
        template = layout.appdata / "Godot/export_templates/4.6.stable" / TEMPLATE_NAME
        validate_layout(layout, extra_write_paths=(template.parent,))
        copy_new(cfg["template"], template)
        if sha(template) != TEMPLATE_SHA:
            raise ValueError("Actual redirected export template differs")
        write_new(layout.evidence / "export-policy.json", {"override_absent": True, "template": str(template),
            "template_sha256": TEMPLATE_SHA, "export_presets_sha256": sha(workspace / "export_presets.cfg")})
    override = workspace / "override.cfg"
    if phase == "import":
        if override.exists():
            raise ValueError("Refusing an existing import override")
        with override.open("xb") as handle:
            handle.write(IMPORT_POLICY)
    command = child_command(phase, cfg, args)
    try:
        job = execute(layout, command, timeout=timeout, cpu_rate=1200,
                      extra_write_paths=(workspace, stage.parent, layout.evidence))
    finally:
        if phase == "import" and override.exists():
            if override.read_bytes() != IMPORT_POLICY:
                raise ValueError("Owned import policy was changed; preserving it in place")
            validate_layout(layout, extra_write_paths=(workspace, layout.evidence))
            override.rename(layout.evidence / "owned-import-override.cfg")
    if (job.get("exit_code") != 0 or job.get("active_at_release") != 0 or job.get("error") or
            job.get("cleanup_errors") or job.get("timed_out") or job.get("log_error") or job.get("log_truncated") or
            not job.get("assigned_before_execution")):
        raise ValueError("Guarded build phase failed; preserve its exact evidence: " + phase)
    if phase in ("import", "export"):
        log_lines = (layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace").splitlines()
        errors = [line for line in log_lines if re.search(r"(?:SCRIPT ERROR|(?<![A-Z])ERROR):", line)]
        if errors:
            write_new(layout.evidence / "log-error-diagnostic.json", {
                "phase": phase, "process_exit_code": job["exit_code"], "rejected_error_lines": errors,
                "status": "FAILED_DESPITE_PROCESS_EXIT_ZERO"})
            raise ValueError("Godot logged ERROR/SCRIPT ERROR; exit0 is not a passing phase: " + phase)
    artifacts = {}
    if phase == "source-identity":
        observed = (layout.evidence / "worker.log").read_text(encoding="utf-8").strip().splitlines()
        if observed != [cfg["source_commit"], cfg["source_tree"]]:
            raise ValueError("Actual Git commit/tree differs from requested identity: " + repr(observed))
        artifacts = {"source_commit": observed[0], "source_tree": observed[1]}
    elif phase == "archive":
        artifacts = {"archive": str(stage.parent / "source.tar"), "archive_sha256": sha(stage.parent / "source.tar")}
    elif phase in FILE_PHASES:
        artifacts = json.loads((layout.evidence / "worker-result.json").read_text())
    validate_layout(layout, extra_write_paths=(layout.evidence,))
    result = {"schema": "bth.grand_test_build_phase/v1" if grand_profile(cfg) else "bth.bar_test_build_phase/v1", "status": "PASS", "phase": phase,
              "config_sha256": config_sha(cfg), "job_receipt": str(layout.evidence / "job.json"),
              "artifacts": artifacts, "published": False}
    write_new(layout.evidence / "phase-result.json", result)
    print(json.dumps(result, indent=2))


def main(argv=None):
    tokens = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", *PHASES))
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--stage", type=Path, required=True)
    parser.add_argument("--run-prefix", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--source-tree", required=True)
    parser.add_argument("--art-package-sha256", required=True)
    parser.add_argument("--environment", choices=("bar", "grand_casino"), default="bar")
    parser.add_argument("--approval-json", type=Path)
    parser.add_argument("--approval-sha256")
    for name in ("engine", "native-library", "template", "git", "node", "git-dir", "baseline-stage"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--qa-root", type=Path, default=Path("E:/CodexQA/BTH"))
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--editor-native-library", type=Path)
    parser.add_argument("--editor-native-sha256")
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    parsed = parser.parse_args(tokens)
    try:
        cfg = config(parsed)
        # All filesystem admission precedes every QA directory/write/child.
        if parsed.worker:
            if parsed.phase not in FILE_PHASES:
                raise ValueError("This phase is not an internal file worker")
            worker(parsed.phase, cfg)
        elif parsed.phase == "plan":
            for phase in PHASES:
                plan_layout(root=cfg["qa_root"], workspace=cfg["workspace"], run_id=cfg["run_prefix"] + "-" + phase)
            print(json.dumps({"status": "READ_ONLY_BUILD_PLAN", "inputs": cfg,
                "phase_order": PHASES, "commands": [[sys.executable, "-B", str(Path(__file__).resolve()), phase, *tokens[1:]] for phase in PHASES],
                "declared_stage": cfg["stage"], "expected_write_gib": 4, "reserve_gib": 20,
                "cpu_percent": 12, "memory_bytes": 2 * 1024 ** 3,
                "missing_setup": cfg["missing_setup"], "published": False}, indent=2))
        else:
            if cfg["missing_setup"]:
                raise ValueError("; ".join(cfg["missing_setup"]))
            run_phase(parsed.phase, cfg, tokens[1:], parsed.timeout)
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, tarfile.TarError) as error:
        print(json.dumps({"status": "BUILD_STOPPED", "phase": parsed.phase, "error": str(error),
                          "published": False, "fallback_attempted": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
