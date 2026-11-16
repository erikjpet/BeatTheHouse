"""Prepare and qualify one reviewed Grand public candidate in guarded E: storage.

No legacy launcher runs. Original observer GD bytes and their UID provenance are
retained; current committed canonical UID sidecars are never overwritten. The
original context report's dd96 commit label is observer provenance only. Actual
source identity comes from guarded Git archive receipts and the fresh inventory.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import io
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import tarfile
import zipfile

from bth_qa_storage import Layout, plan_layout, prepare_layout, validate_layout
from bth_qa_guarded_run import execute
from bar_spatial_native_suite import qualified_job, sha
from bar_spatial_candidate_check import decode_png

DEFAULT_COMMIT = "7b284648642a896e534c8bfd53c8e7abbc55108d"
ENGINE_SHA = "fc759f9d296fe54f09ab66d41df6ddd2d278493b0e71109f6688ef029ad271ae"
RUNTIME_SHA = "63913d01be2c2d1f929b4a626f5347117126b34e9c64cbf350ea9f35a9657ebf"
EDITOR_DLL_NAME = "coin_pusher_native_v3_10.windows.template_debug.x86_64.nothreads.dll"
EDITOR_DLL_SHA = "9ed33e21a00a8be3ef2429550451ed6c766debde8d0d21c4f3a4c39e25eb3f82"
NATIVE_DESCRIPTOR_SHA = "80b9af791b34cfd93a6017ac11cbcbfb3abae10a71189a2db8eb044a0af8fe96"
QUALIFIED_NATIVE_SOURCE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116/addons/coin_pusher_native")
LEGACY = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-GRAND-TRIAL-20261115")
RAW_SHA = "31e7a40bfedcbc68a00a615e400b3df88bab03d180558fd3c88749a410147c63"
INDEX_SHA = "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
HISTORICAL = {
    "grand_source_identity.json": "f2632acc560ee141b64ac741393011bfad8d4ab8cd1102f6fc7c824aabca8f2f",
    "grand_capture_inputs.json": "86afa111b91f67c401f60e1b99e307d62a1542fb673f107f0d1f9b628895462c",
    "grand_trial_package_identity.json": "ff80155f7ea292d570659704997565ee635e81d02ea59702a6004c39d443f57e",
    "grand_trial_adapter.py": "0fbd311bca25da3bb0082dbd760f51ca1eed3a6e499787794f661e4f012a1331",
}
HELPERS = {
    "tools/envart_grand_context_trace.gd": "171db50e200a1a07c20e01a27bbd13451dd452fc20b411bdac6103821b8faa74",
    "tools/envart_grand_animation_probe.gd": "0c91a3cad63255e3f075fec1649a08f845a2c5c605f7bc61052ec4e305ca0178",
    "tools/envart_grand_animation_capture.gd": "dd4ba3f0c0f646e983c86e8f6b6ea8a30c0ec65613dce3dc90e97d789e1f3976",
    "tools/environment_art_baseline_capture.gd": "89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
    "tools/environment_layout_screenshots.gd": "eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5",
}
LEGACY_UIDS = {
    "tools/envart_grand_context_trace.gd.uid": "9f2468682952600334859b5d1b9ca215956186d2f7d449d743fc3ac45e2d9368",
    "tools/envart_grand_animation_probe.gd.uid": "75cd1ce8900854f0916778be84fe00b3bd3ae24a47ffeeb36030338832b7e0dd",
    "tools/envart_grand_animation_capture.gd.uid": "2304776b5a18ec2e88f0256afd34212e14fbed2376a809d79a90ef6ecc5d73f2",
    "tools/environment_art_baseline_capture.gd.uid": "cd3b58fa80239aada2b1e9752d8d3fecda4a0c4d02aa2a9226e1156fd235b7c2",
    "tools/environment_layout_screenshots.gd.uid": "a4e9a7d6067be76eee07ef86e4fb1a37c5fb88096d2626a05ad83057f243cb35",
}
SCENARIOS = ("__none", "grand_casino_gala_night", "grand_casino_convention_crowd", "grand_casino_audit_night")
PHASES = ("source-identity", "archive", "prepare", "install", "import", "identity", "contexts", "motion", "liveness", "capture")
OUTER_PHASES = {"source-identity", "archive", "prepare"}
FILE_PHASES = {"prepare", "install", "identity"}
ENGINE_PHASES = {"import", "contexts", "motion", "liveness", "capture"}
IMPORT_POLICY = b"[editor]\nimport/use_multiple_threads=false\n\n[threading]\nworker_pool/max_threads=1\n"
NONACTIVE_IGNORE = b"# Non-active Grand candidate sources; excluded from Godot import.\n"
ERROR_LINE = re.compile(r"(?:SCRIPT ERROR|(?<![A-Z])ERROR):")
COUNTERS = {"grand_table_left": (82, 258, 272, 36), "grand_table_right": (546, 258, 272, 36),
            "grand_host_station": (344, 318, 212, 48)}


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write_new(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def plain(path):
    path = Path(path).absolute()
    for item in (path, *path.parents):
        if item.exists() and (item.is_symlink() or getattr(item.lstat(), "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT):
            raise ValueError("Linked path is not admitted: " + str(item))
    return path


def seal(files):
    return hashlib.sha256("\n".join(name + " " + digest for name, digest in sorted(files.items())).encode()).hexdigest()


def scan(root, *, identity=False):
    files = {}
    omitted = {"grand_capture_inputs.json", "grand_spatial_source_identity.json"} if identity else set()
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if relative.parts[0] == ".godot" or relative.as_posix() in omitted:
            continue
        plain(path)
        if path.is_file():
            files[relative.as_posix()] = sha(path)
    return files


def baseline_files():
    for name, expected in {**HISTORICAL, **HELPERS, **LEGACY_UIDS}.items():
        if sha(LEGACY / name) != expected:
            raise ValueError("Preserved Grand source identity differs: " + name)
    package = read_json(LEGACY / "grand_trial_package_identity.json")
    if len(package["files"]) != 22 or seal(package["files"]) != package["package_sha256"]:
        raise ValueError("Historical22-file seal is not self-consistent")
    current = dict(package["files"])
    current["data/art/environments/index.json"] = INDEX_SHA
    return current


def nonactive_package_names(workspace, baseline):
    """Keep concurrent art outputs quarantined outside the imported QA project.

    No package bytes are read/copied before install binds its complete approved
    proof. Only known Grand payload relative paths may occur in a version folder.
    """
    names = []
    allowed_directories = {str(parent) for name in baseline for parent in PurePosixPath(name).parents if str(parent) != "."}
    for child in (workspace / "candidate_sources").iterdir():
        plain(child)
        if child.name == "grand-spatial-r1.png" and child.is_file():
            continue
        if child.name == ".gdignore" and child.is_file() and child.read_bytes() == NONACTIVE_IGNORE:
            continue
        if not child.is_dir() or not re.fullmatch(r"grand-spatial-r1-assembled-v[1-9][0-9]*", child.name):
            raise ValueError("Unexpected non-active candidate source path: " + str(child))
        for path in child.rglob("*"):
            plain(path)
            relative = path.relative_to(child).as_posix()
            if (path.is_file() and relative not in baseline) or (path.is_dir() and relative not in allowed_directories):
                raise ValueError("Unexpected path inside quarantined Grand package: " + str(path))
        names.append(child.name)
    return sorted(names)


def config(args):
    if (not all(path.is_absolute() for path in (args.workspace, args.qa_root, args.engine, args.git, args.git_dir,
                args.native_extension_descriptor, args.editor_native_library)) or
            args.qa_root.drive.casefold() != "e:" or not re.fullmatch(r"[0-9a-f]{40}", args.source_commit)):
        raise ValueError("Explicit absolute paths, admitted E: root and full source commit required")
    workspace = plain(args.workspace)
    if not workspace.is_relative_to(plain(args.qa_root)):
        raise ValueError("Campaign workspace escapes the admitted root")
    baseline = baseline_files()
    if set(path.name for path in workspace.iterdir()) - {"source_baseline", "candidate_sources", "qa_source"}:
        raise ValueError("Unexpected preexisting campaign-root content")
    if scan(workspace / "source_baseline") != baseline:
        raise ValueError("Existing source_baseline must contain exactly the22 pinned current-baseline files")
    raw = workspace / "candidate_sources/grand-spatial-r1.png"
    if sha(raw) != RAW_SHA:
        raise ValueError("Preserved raw Grand first-trial source changed")
    nonactive_package_names(workspace, baseline)
    if sha(args.engine) != ENGINE_SHA or sha(args.engine.with_name("Godot_v4.6-stable_win64.exe")) != RUNTIME_SHA:
        raise ValueError("Pinned Godot console/adjacent runtime mismatch")
    descriptor, editor_dll = plain(args.native_extension_descriptor), plain(args.editor_native_library)
    descriptor_sha = args.native_descriptor_sha256.lower()
    if (not descriptor.is_relative_to(plain(args.qa_root)) or not editor_dll.is_relative_to(plain(args.qa_root)) or
            descriptor_sha != NATIVE_DESCRIPTOR_SHA or sha(descriptor) != descriptor_sha or
            editor_dll.name != EDITOR_DLL_NAME or sha(editor_dll) != EDITOR_DLL_SHA):
        raise ValueError("Explicit pinned retained E: extension descriptor and exact Windows debug DLL are required")
    expected_library = "res://addons/coin_pusher_native/bin/" + EDITOR_DLL_NAME
    library_lines = [line.strip() for line in descriptor.read_text(encoding="utf-8-sig").splitlines()
                     if line.strip().startswith("windows.debug")]
    if not any('"' + expected_library + '"' in line for line in library_lines):
        raise ValueError("Qualified descriptor does not reference the exact explicitly seeded Windows debug DLL")
    dependencies = {name: sha(Path(__file__).parent / name) for name in
        ("bth_qa_storage.py", "bth_qa_guarded_run.py", "bar_spatial_native_suite.py", "bar_spatial_candidate_check.py")}
    return {"schema": "bth.grand_spatial_trial_inputs/v1", "workspace": str(workspace),
        "project": str(workspace / "qa_source"), "qa_root": str(args.qa_root), "run_prefix": args.run_prefix,
        "source_commit": args.source_commit, "engine": str(args.engine), "engine_sha256": ENGINE_SHA,
        "runtime_sha256": RUNTIME_SHA, "git": str(args.git), "git_sha256": sha(args.git), "git_dir": str(args.git_dir),
        "adapter_sha256": sha(__file__), "python_sha256": sha(sys.executable), "dependencies": dependencies,
        "baseline_files": baseline, "baseline_seal": seal(baseline), "raw_r1_sha256": RAW_SHA,
        "original_observer_hashes": HELPERS, "historical_source_commit": "dd96c9dd2da5abc550f0076877cb0c57e370ae52",
        "native_overlay": {"descriptor_input": str(descriptor), "descriptor_sha256": descriptor_sha,
            "editor_dll_input": str(editor_dll), "editor_dll_sha256": EDITOR_DLL_SHA,
            "scope": "Explicit qualified-build configuration overlay beyond committed source and candidate; native QA only, no guessed libraries"}}


def fingerprint(cfg):
    return hashlib.sha256(json.dumps(cfg, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def evidence_for(cfg, phase):
    return Path(cfg["qa_root"]) / "runs" / (cfg["run_prefix"] + "-" + phase) / "evidence"


def prior(cfg, phase):
    evidence = evidence_for(cfg, phase)
    result, job = read_json(evidence / "phase-result.json"), read_json(evidence / "job.json")
    if (result.get("phase") != phase or result.get("status") != "PASS" or
            result.get("source_config_sha256") != fingerprint(cfg) or not qualified_job(job)):
        raise ValueError("Prior exact guarded phase is not qualified: " + phase)
    return result


def load_layout(cfg):
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    receipt = read_json(evidence / "storage-manifest.json")
    layout = Layout(**{key: Path(value) for key, value in receipt["paths"].items()},
        **{key: receipt[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout, extra_write_paths=(Path(cfg["project"]),))
    return layout


def verify_prepared(cfg):
    project = Path(cfg["project"])
    prepared_path = project / "qa_reference/prepared-source.json"
    if sha(prepared_path) != prior(cfg, "prepare")["artifacts"]["prepared_identity_sha256"]:
        raise ValueError("Prepared committed-source record differs from its qualified phase receipt")
    prepared = read_json(prepared_path)
    installed_path = project / "qa_reference/candidate-install.json"
    installed = read_json(installed_path) if installed_path.exists() else None
    if installed is not None:
        admitted = prior(cfg, "install")["artifacts"]
        if sha(installed_path) != admitted["candidate_install_sha256"] or installed != admitted["record"]:
            raise ValueError("Candidate-install source record differs from its qualified phase receipt")
    for name, expected in prepared["files"].items():
        if installed and name in installed["files"]:
            expected = installed["files"][name]
        if sha(project / name) != expected:
            raise ValueError("QA source/canonical UID custody changed: " + name)
    return prepared, installed


def prepare_worker(cfg, layout):
    workspace, project = Path(cfg["workspace"]), Path(cfg["project"])
    if project.exists():
        raise ValueError("Preparation requires absentqa_source; never overwrite a partially prepared project")
    quarantined = nonactive_package_names(workspace, cfg["baseline_files"])
    archive_receipt = prior(cfg, "archive")["artifacts"]
    archive = Path(archive_receipt["path"])
    if sha(archive) != archive_receipt["sha256"]:
        raise ValueError("Guarded source archive changed")
    validate_layout(layout, extra_write_paths=(project,))
    with tarfile.open(archive, "r:") as package:
        if package.pax_headers.get("comment") != cfg["source_commit"]:
            raise ValueError("Git archive PAX commit mismatch")
        members = package.getmembers()
        if sum(item.size for item in members if item.isfile()) > layout.expected_write_bytes:
            raise ValueError("Source archive exceeds the admitted write budget")
        for item in members:
            relative = PurePosixPath(item.name)
            if (relative.is_absolute() or ".." in relative.parts or "\\" in item.name or ":" in item.name or
                    relative.as_posix() != item.name.rstrip("/") or not (item.isfile() or item.isdir())):
                raise ValueError("Unsafe archive member: " + item.name)
            if not (project / item.name).resolve().is_relative_to(project.resolve()):
                raise ValueError("Archive target escapes the admitted E: project: " + item.name)
        project.mkdir()
        for item in members:
            target = project / item.name
            if item.isdir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open("xb") as handle:
                    shutil.copyfileobj(package.extractfile(item), handle)
    for name, expected in cfg["baseline_files"].items():
        if sha(project / name) != expected:
            raise ValueError("Committed source differs from the pinned staged Grand baseline: " + name)
    overlay = cfg["native_overlay"]
    for input_key, expected, relative in (
            ("descriptor_input", overlay["descriptor_sha256"], "addons/coin_pusher_native/coin_pusher_native.gdextension"),
            ("editor_dll_input", EDITOR_DLL_SHA, "addons/coin_pusher_native/bin/" + EDITOR_DLL_NAME)):
        target = project / relative
        if target.exists() or sha(overlay[input_key]) != expected:
            raise ValueError("Native overlay destination occupied or retained input changed: " + relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as handle:
            handle.write(Path(overlay[input_key]).read_bytes())
        if sha(target) != expected:
            raise ValueError("Native QA overlay copy mismatch: " + relative)
    helper_bindings = {}
    for name, expected in HELPERS.items():
        target, original = project / name, (LEGACY / name).read_bytes()
        if target.exists():
            active = target.read_bytes()
            if active.replace(b"\r\n", b"\n") != original.replace(b"\r\n", b"\n"):
                raise ValueError("Current canonical helper differs beyond newline encoding: " + name)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as handle:
                handle.write(original)
        helper_bindings[name] = {"original_sha256": expected, "active_sha256": sha(target),
            "original_assertions_unchanged": True, "canonical_uid_overwritten": False}
    reference = project / "qa_reference"
    reference.mkdir()
    with (reference / ".gdignore").open("x") as handle:
        handle.write("# Preserved observer/reference source is not imported as active code.\n")
    with zipfile.ZipFile(reference / "grand-public-r4-originals.zip", "x", compression=zipfile.ZIP_DEFLATED) as saved:
        for name in sorted({**HISTORICAL, **HELPERS, **LEGACY_UIDS}):
            saved.writestr(name, (LEGACY / name).read_bytes())
    with (project / "override.cfg").open("xb") as handle:
        handle.write(IMPORT_POLICY)
    files = scan(project)
    old = read_json(LEGACY / "grand_source_identity.json")["files"]
    delta = {"changed": [name for name in sorted(old.keys() & files.keys()) if old[name] != files[name]],
        "removed": sorted(old.keys() - files.keys()), "added": sorted(files.keys() - old.keys())}
    write_new(layout.evidence / "historical-to-current-source-delta.json", delta)
    result = {"source_commit": cfg["source_commit"], "source_tree": prior(cfg, "source-identity")["artifacts"]["tree"],
        "source_archive_sha256": archive_receipt["sha256"], "source_config_sha256": fingerprint(cfg),
        "files": files, "helper_bindings": helper_bindings, "historical_7318_inventory_retained_in_ignored_archive": True,
        "nonactive_package_folders_not_read_or_copied": quarantined,
        "source_only": True, "candidate_installed": False, "legacy_adapter_executed": False,
        "explicit_qualified_native_overlay": cfg["native_overlay"]}
    write_new(reference / "prepared-source.json", result)
    return {"project": str(project), "files": len(files), "source_commit": cfg["source_commit"],
        "source_tree": result["source_tree"], "prepared_identity_sha256": sha(reference / "prepared-source.json"),
        "helper_bindings": helper_bindings, "historical_delta": str(layout.evidence / "historical-to-current-source-delta.json")}


def check_crops(root):
    master = decode_png((root / "assets/art/environments/grand_casino/background.png").read_bytes())
    if (master.width, master.height) != (1800, 860) or master.rgba[3::4].count(255) != 1800 * 860:
        raise ValueError("Opaque1800x860 Grand master required")
    results = {}
    for name, (x, y, width, height) in COUNTERS.items():
        image = decode_png((root / ("assets/art/environments/grand_casino/counters/" + name + ".png")).read_bytes())
        if (image.width, image.height) != (width * 2, height * 2) or image.rgba[3::4].count(255) != image.width * image.height:
            raise ValueError("Exact opaque counter dimensions required: " + name)
        expected = b"".join(master.rgba[((y * 2 + row) * master.width + x * 2) * 4:
            ((y * 2 + row) * master.width + (x + width) * 2) * 4] for row in range(height * 2))
        if expected != image.rgba:
            raise ValueError("Counter is not its exact same-coordinate master crop: " + name)
        results[name] = {"board_rect": [x, y, width, height], "native_rect": [x * 2, y * 2, width * 2, height * 2],
                         "exact_master_crop": True, "opaque": True}
    return results


def install_worker(args, cfg, layout):
    prior(cfg, "prepare")
    prepared, installed = verify_prepared(cfg)
    if installed is not None or args.candidate_root is None or args.candidate_manifest is None or args.review is None:
        raise ValueError("Fresh install requires explicit reviewed candidate root, manifest and review")
    if not all(path.is_absolute() for path in (args.candidate_root, args.candidate_manifest, args.review)):
        raise ValueError("Explicit absolute candidate-root/manifest/review input paths required")
    root = plain(args.candidate_root).resolve(strict=True)
    if not root.is_relative_to(Path(cfg["workspace"]) / "candidate_sources"):
        raise ValueError("Reviewed candidate payload must remain under admitted candidate_sources")
    candidate, review = read_json(args.candidate_manifest), read_json(args.review)
    files = candidate["output"]["files"]
    proof_sha = sha(args.candidate_manifest)
    if (set(files) != set(cfg["baseline_files"]) or scan(root) != files or seal(files) != candidate["output"]["seal"] or
            plain(candidate["output"]["path"]).resolve(strict=True) != root or
            review.get("native_trial_approved") is not True or
            review.get("decision") not in ("STATIC_GO_FOR_NATIVE_TRIAL", "GO_FOR_NATIVE_TRIAL_ONLY", "STATIC_GO") or
            review.get("package_22_file_sha256") != seal(files) or review.get("assembly_proof_sha256") != proof_sha or
            review.get("executed_recipe_sha256") != candidate.get("recipe_sha256") or
            not isinstance(review.get("independent_reviewer"), str) or not review["independent_reviewer"].strip()):
        raise ValueError("Exact22-file assembly proof and matching independent native-trial approval are required")
    assembly_job_path = args.candidate_manifest.parent / "job.json"
    assembly_job = read_json(assembly_job_path)
    if not qualified_job(assembly_job):
        raise ValueError("Approved assembly proof lacks a closed exact guarded PASS/zero Job")
    tokens = assembly_job.get("command", [])
    if len(tokens) < 3 or tokens[1] != "-B":
        raise ValueError("Approved assembly Job does not identify its executed recipe")
    recipe = plain(tokens[2]).resolve(strict=True)
    if (recipe.parent != Path(__file__).resolve().parent or not recipe.name.startswith("assemble_grand_spatial_candidate") or
            recipe.suffix != ".py" or sha(recipe) != candidate["recipe_sha256"]):
        raise ValueError("Exact reviewed/executed Grand repair-mask recipe source is unavailable or changed")
    allowed_png = {"assets/art/environments/grand_casino/" + relative for relative in
        ("background.png", "counters/grand_table_left.png", "counters/grand_table_right.png", "anim/casino_sign_pulse.png",
         *("anim/casino_light_" + str(index) + ".png" for index in range(5)))}
    changed = {name for name in files if files[name] != cfg["baseline_files"][name]}
    if changed != allowed_png | {"data/art/environments/grand_casino.json"}:
        raise ValueError("Only the exact nine Grand PNG payloads and one Grand JSON delta may change")
    if files["data/art/environments/index.json"] != INDEX_SHA:
        raise ValueError("The current20-room global index cannot change")
    baseline_spec = read_json(Path(cfg["workspace"]) / "source_baseline/data/art/environments/grand_casino.json")
    spec = read_json(root / "data/art/environments/grand_casino.json")
    if (spec.get("environment_id") != "grand_casino" or spec.get("board_size") != [900, 430] or spec.get("pixel_scale") != 2 or
            len(spec.get("animations", [])) != 16 or spec.get("counters") != baseline_spec.get("counters")):
        raise ValueError("Grand board/16-entry/counter contract changed")
    expected_spec = json.loads(json.dumps(baseline_spec))
    if expected_spec["animations"][0]["id"] != "casino_light_0" or expected_spec["animations"][0]["rect"][0] != 250:
        raise ValueError("Pinned original lamp0 rect contract differs")
    expected_spec["animations"][0]["rect"][0] = 245
    if (type(spec["animations"][0]["rect"][0]) is not int or
            json.dumps(spec, sort_keys=True, separators=(",", ":")) !=
            json.dumps(expected_spec, sort_keys=True, separators=(",", ":"))):
        raise ValueError("Only semantic Grand JSON delta allowed: lamp0.rect.x integer250->245; every other field is frozen")
    mask_metrics = {}
    columns = ({0, 1}, {20, 21, 22, 23, 102, 103}, {96, 97}, {14, 15}, {8, 9, 54, 55, 56, 57})
    for index, allowed in enumerate(columns):
        name = "casino_light_" + str(index)
        image = decode_png((root / ("assets/art/environments/grand_casino/anim/" + name + ".png")).read_bytes())
        if (image.width, image.height) != (104, 16):
            raise ValueError("Audited lamp mask dimensions differ: " + name)
        actual = {(x, y) for y in range(16) for x in range(104) if image.rgba[(y * 104 + x) * 4 + 3] != 0}
        wanted = {(x, y) for x in allowed for y in range(16)}
        if actual != wanted:
            raise ValueError("Lamp mask no longer matches its audited warm-trim support columns: " + name)
        mask_metrics[name] = {"nonzero_alpha_pixels": len(actual), "local_support_columns": sorted(allowed),
            "actual_visible_practical": "Independently audited warm vertical brass bay edge/mullion; not the lower plinth fixture"}
    sign = decode_png((root / "assets/art/environments/grand_casino/anim/casino_sign_pulse.png").read_bytes())
    if (sign.width, sign.height) != (468, 124) or sign.rgba[3::4].count(46) != 2656 or set(sign.rgba[3::4]) != {0, 46}:
        raise ValueError("Sign underline must retain exactly2656 nonzero46-alpha pixels")
    mask_metrics["casino_sign_pulse"] = {"nonzero_alpha_pixels": 2656, "nonzero_alpha": 46}
    crops = check_crops(root)
    project, reference = Path(cfg["project"]), Path(cfg["project"]) / "qa_reference"
    validate_layout(layout, extra_write_paths=(project,))
    for name in files:
        if sha(project / name) != cfg["baseline_files"][name]:
            raise ValueError("QA baseline changed before candidate installation: " + name)
    for name, expected in files.items():
        if expected != cfg["baseline_files"][name]:
            shutil.copyfile(root / name, project / name)
    for name, expected in files.items():
        if sha(project / name) != expected:
            raise ValueError("Candidate installation copy mismatch: " + name)
    result = {"package_sha256": seal(files), "files": files, "candidate_root": str(root),
        "candidate_manifest_sha256": proof_sha, "review_sha256": sha(args.review),
        "approved_repair_source_proof": {"path": str(args.candidate_manifest), "sha256": proof_sha,
            "executed_recipe": str(recipe), "executed_recipe_sha256": candidate["recipe_sha256"],
            "guarded_assembly_job_sha256": sha(assembly_job_path),
            "scope": "Exact independently approved bounded repair-mask recipe and proof; no adapter rectangle expansion or blanket outside-pixel exception"},
        "review": review, "exact_counter_crops": crops, "audited_practical_masks": mask_metrics,
        "source_commit": cfg["source_commit"],
        "source_baseline_unchanged": scan(Path(cfg["workspace"]) / "source_baseline") == cfg["baseline_files"],
        "production_art_written": False, "test_updated": False}
    write_new(reference / "candidate-install.json", result)
    return result


def identity_worker(cfg, layout):
    prior(cfg, "import")
    prepared, installed = verify_prepared(cfg)
    if installed is None:
        raise ValueError("An approved QA candidate must be installed before identity binding")
    project = Path(cfg["project"])
    for name in ("grand_capture_inputs.json", "grand_spatial_source_identity.json"):
        if (project / name).exists():
            raise ValueError("Fresh identity output required; no rebinding an existing trial: " + name)
    files = scan(project, identity=True)
    extras = set(files) - set(prepared["files"]) - {"qa_reference/prepared-source.json", "qa_reference/candidate-install.json"}
    for name in extras:
        if not ((name.endswith(".uid") and (project / name[:-4]).is_file()) or
                (name.endswith(".import") and (project / name[:-7]).is_file())):
            raise ValueError("Unexpected source addition after import: " + name)
    catalog = read_json(project / "data/environments/scenarios.json")
    selections = ["__none", *(row["id"] for row in catalog["grand_casino"])]
    if selections != list(SCENARIOS):
        raise ValueError("All four original direct Grand contexts must remain present")
    inputs = {"source_hashes": files, "catalog": selections}
    write_new(project / "grand_capture_inputs.json", inputs)
    result = {"schema": "bth.grand_current_source_identity/v1", "source_commit": cfg["source_commit"],
        "source_tree": prepared["source_tree"], "source_archive_sha256": prepared["source_archive_sha256"],
        "source_config_sha256": fingerprint(cfg), "candidate_package_sha256": installed["package_sha256"],
        "files": files, "capture_inputs_sha256": sha(project / "grand_capture_inputs.json"),
        "original_observers": prepared["helper_bindings"], "canonical_tracked_uid_sidecars_preserved": True,
        "historical_observer_report_commit_label": cfg["historical_source_commit"],
        "historical_label_is_not_current_source_identity": True}
    write_new(project / "grand_spatial_source_identity.json", result)
    return {"identity_sha256": sha(project / "grand_spatial_source_identity.json"),
        "capture_inputs_sha256": result["capture_inputs_sha256"], "source_files": len(files),
        "expected_context_checks_if_original_object_coverage_retained": 2 * len(files) + 753,
        "candidate_package_sha256": installed["package_sha256"]}


def verify_identity(cfg):
    qualified = prior(cfg, "identity")["artifacts"]
    project = Path(cfg["project"])
    if (sha(project / "grand_spatial_source_identity.json") != qualified["identity_sha256"] or
            sha(project / "grand_capture_inputs.json") != qualified["capture_inputs_sha256"]):
        raise ValueError("The fresh current-source identity or original-observer input was modified")
    identity = read_json(project / "grand_spatial_source_identity.json")
    if scan(project, identity=True) != identity["files"]:
        raise ValueError("Current committed source/candidate/UID inventory changed")
    return identity


@contextmanager
def engine_admission(enabled):
    if not enabled:
        raise ValueError("Explicit --engine-go campaign admission required for a Godot phase")
    key = "BTH_GRAND_PREART_ENGINE_GO"
    old = os.environ.get(key)
    os.environ[key] = "EXPLICIT_PARENT_SAFE_GAP_GO"
    try:
        yield
    finally:
        if old is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = old


def command(args, cfg, phase, layout, arguments):
    project = cfg["project"]
    if phase == "source-identity":
        return [cfg["git"], "--git-dir", cfg["git_dir"], "show", "-s", "--format=%H%n%T", cfg["source_commit"]]
    if phase == "archive":
        return [cfg["git"], "--git-dir", cfg["git_dir"], "archive", "--format=tar", "--output", str(layout.evidence / "source.tar"), cfg["source_commit"]]
    if phase in FILE_PHASES:
        return [sys.executable, "-B", str(Path(__file__).resolve()), phase, *arguments, "--worker"]
    result = [cfg["engine"]]
    if phase in ("import", "liveness"):
        result += ["--headless"]
    result += ["--path", project]
    if phase == "import":
        return result + ["--editor", "--import"]
    if phase == "liveness":
        return result + ["--script", "res://scripts/tests/animation_liveness_without_pointer_check.gd"]
    scripts = {"contexts": "envart_grand_context_trace.gd", "motion": "envart_grand_animation_probe.gd", "capture": "envart_grand_animation_capture.gd"}
    result += ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--resolution", "1280x720",
        "--position", args.position, "--script", "res://tools/" + scripts[phase]]
    if phase == "motion":
        result += ["--", "--out=" + str(layout.evidence)]
    elif phase == "capture":
        result += ["--", "--out=" + str(layout.evidence / "capture"), "--excerpt-seconds=" + str(args.capture_seconds),
            "--archetype=grand_casino", "--scenario=" + args.capture_scenario]
    return result


def result_for(args, cfg, phase, layout):
    log = (layout.evidence / "worker.log").read_text(encoding="utf-8")
    if phase in FILE_PHASES:
        value = read_json(layout.evidence / "worker-result.json")
        if phase == "install":
            return {"candidate_install_sha256": sha(Path(cfg["project"]) / "qa_reference/candidate-install.json"), "record": value}
        return value
    if phase == "source-identity":
        rows = log.strip().splitlines()
        if len(rows) != 2 or rows[0] != cfg["source_commit"] or not re.fullmatch(r"[0-9a-f]{40}", rows[1]):
            raise ValueError("Actual Git commit/tree identity differs")
        return {"commit": rows[0], "tree": rows[1]}
    if phase == "archive":
        archive = layout.evidence / "source.tar"
        return {"path": str(archive), "sha256": sha(archive), "bytes": archive.stat().st_size}
    if phase == "import":
        return {"source_only_import": True, "canonical_source_files_verified": True}
    if phase == "liveness":
        if "Animation liveness without pointer input: PASS" not in log:
            raise ValueError("Mandatory no-pointer liveness marker absent")
        return {"no_pointer_liveness": True}
    names = {"contexts": "grand_casino_preart_metadata.json", "motion": "grand_casino_animation_probe.json", "capture": "capture/animation_capture.json"}
    path = layout.evidence / names[phase]
    report = read_json(path)
    if report.get("findings") or report.get("failures"):
        raise ValueError("Native report contains findings: " + phase)
    if phase == "contexts":
        views = report.get("views", {})
        counts = {name: len(views.get(name, {}).get("source_paint", {}).get("objects", [])) for name in SCENARIOS}
        ids = {row["id"] for view in views.values() for row in view.get("actual_view", {}).get("objects", [])}
        expected_checks = prior(cfg, "identity")["artifacts"]["expected_context_checks_if_original_object_coverage_retained"]
        if (set(views) != set(SCENARIOS) or list(report.get("direct_catalog", [])) != list(SCENARIOS) or
                counts != dict(zip(SCENARIOS, (19, 26, 27, 26))) or len(ids) != 40 or report.get("checks") != expected_checks):
            raise ValueError("Original four-context/98-pair/40-ID assertion coverage changed")
        return {"report": str(path), "sha256": sha(path), "checks": report["checks"], "source_paint_pairs": sum(counts.values()),
            "union_ids": len(ids), "source_commit": cfg["source_commit"], "observer_embedded_historical_commit": report.get("commit"),
            "historical_commit_is_not_current_identity": True}
    if phase == "motion":
        ids = [row["id"] for row in read_json(Path(cfg["project"]) / "data/art/environments/grand_casino.json")["animations"]]
        if ([row.get("id") for row in report.get("entries", [])] != ids or len(ids) != 16 or
                report.get("simulated_low_detail_count") != 7 or report.get("checks") != 66):
            raise ValueError("Original16-entry/7-simulated-low-detail/66-check motion coverage changed")
    else:
        frames = report.get("frames", [])
        clocks = [row["clock"] for row in frames]
        ids = [row["id"] for row in read_json(Path(cfg["project"]) / "data/art/environments/grand_casino.json")["animations"]]
        if (report.get("archetype") != "grand_casino" or report.get("scenario") != args.capture_scenario or
                not report.get("pack_active") or [row.get("id") for row in report.get("animation_inventory", [])] != ids or
                len(ids) != 16 or len(frames) < 2 or
                not all(isinstance(clock, (int, float)) and math.isfinite(clock) for clock in clocks) or
                any(b <= a for a, b in zip(clocks, clocks[1:])) or
                abs(report["actual_clock_span"] - (clocks[-1] - clocks[0])) > 0.00001 or
                not report.get("reduce_motion", {}).get("active") or
                not report.get("reduce_motion", {}).get("production_art_texture_pixels_stable") or
                "no pointer input during capture" not in report.get("note", "")):
            raise ValueError("Authentic Grand16-entry/current-clock/Reduce Motion recording contract failed")
        for row in frames:
            if [state.get("id") for state in row.get("animation_states", [])] != ids:
                raise ValueError("Recorded frame lacks the exact16-entry current animation state")
            for key in ("file", "board900_file", "board2x_file"):
                relative = PurePosixPath(row[key])
                if relative.is_absolute() or ".." in relative.parts or "\\" in row[key] or not (layout.evidence / "capture" / relative).is_file():
                    raise ValueError("Capture frame output path is unsafe or missing")
    return {"report": str(path), "sha256": sha(path), "checks": report.get("checks"), "frames": len(report.get("frames", [])),
        "actual_clock_span": report.get("actual_clock_span"), "encoding": "None; APNG must use these actual timestamps without a fake FPS"}


def main(argv=None):
    tokens = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", *PHASES))
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--qa-root", type=Path, default=Path("E:/CodexQA/BTH"))
    parser.add_argument("--run-prefix", required=True)
    parser.add_argument("--source-commit", default=DEFAULT_COMMIT)
    for name in ("engine", "git", "git-dir"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--native-extension-descriptor", type=Path, default=QUALIFIED_NATIVE_SOURCE / "coin_pusher_native.gdextension")
    parser.add_argument("--native-descriptor-sha256", default=NATIVE_DESCRIPTOR_SHA)
    parser.add_argument("--editor-native-library", type=Path, default=QUALIFIED_NATIVE_SOURCE / "bin" / EDITOR_DLL_NAME)
    for name in ("candidate-root", "candidate-manifest", "review"):
        parser.add_argument("--" + name, type=Path)
    parser.add_argument("--engine-go", action="store_true")
    parser.add_argument("--capture-scenario", choices=SCENARIOS, default="grand_casino_gala_night")
    parser.add_argument("--capture-seconds", type=float, default=20)
    parser.add_argument("--position", default="-32000,-32000")
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(tokens)
    try:
        if not 1 <= args.timeout <= 1200 or not 0 < args.capture_seconds <= 20:
            raise ValueError("Bounded timeout1..1200 and actual capture0..20seconds required")
        cfg = config(args)
        if args.worker:
            layout = load_layout(cfg)
            if args.phase == "prepare":
                result = prepare_worker(cfg, layout)
            elif args.phase == "install":
                result = install_worker(args, cfg, layout)
            elif args.phase == "identity":
                result = identity_worker(cfg, layout)
            else:
                raise ValueError("Unsupported internal file worker")
            write_new(layout.evidence / "worker-result.json", result)
            return 0
        phases = PHASES if args.phase == "plan" else (args.phase,)
        layouts = {}
        for phase in phases:
            workspace = cfg["workspace"] if phase in OUTER_PHASES else cfg["project"]
            suffix = phase + "-" + args.capture_scenario if phase == "capture" else phase
            layouts[phase] = plan_layout(root=args.qa_root, workspace=workspace, run_id=args.run_prefix + "-" + suffix)
            validate_layout(layouts[phase], extra_write_paths=(Path(cfg["project"]),) if phase in OUTER_PHASES else ())
        if args.phase == "plan":
            print(json.dumps({"status": "READ_ONLY_GRAND_PLAN", "source_config": cfg,
                "phases": [{"phase": phase, "command": command(args, cfg, phase, layout, tokens[1:]),
                    "engine_admission_required": phase in ENGINE_PHASES, "workspace": str(layout.workspace)} for phase, layout in layouts.items()],
                "candidate_approval_required_before_install_or_engine": True, "executed": False}, indent=2))
            return 0
        phase, layout = args.phase, layouts[args.phase]
        if phase == "archive":
            prior(cfg, "source-identity")
        if phase == "prepare":
            prior(cfg, "archive")
        if phase in ENGINE_PHASES:
            if not args.engine_go:
                raise ValueError("Explicit --engine-go campaign admission is required; no automatic token bypass")
            if phase == "import":
                prior(cfg, "install")
                verify_prepared(cfg)
            else:
                verify_identity(cfg)
        layout = prepare_layout(layout)
        cmd = command(args, cfg, phase, layout, tokens[1:])
        extra = (Path(cfg["project"]),) if phase in OUTER_PHASES else ()
        if phase == "capture":
            extra += (layout.evidence / "capture",)
        write_new(layout.evidence / "trial-inputs.json", {"source_config": cfg, "source_config_sha256": fingerprint(cfg),
            "command": cmd, "engine_campaign_admission": args.engine_go if phase in ENGINE_PHASES else False,
            "admission_scope": "Explicit campaign admission; no global-process inspection or host-zero claim"})
        if phase in ENGINE_PHASES:
            with engine_admission(args.engine_go):
                job = execute(layout, cmd, timeout=args.timeout, cpu_rate=1200, extra_write_paths=extra)
        else:
            job = execute(layout, cmd, timeout=args.timeout, cpu_rate=1200, extra_write_paths=extra)
        log = (layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")
        if not qualified_job(job) or ERROR_LINE.search(log):
            raise ValueError("Guarded Job/native log failed; retained evidence: " + str(layout.evidence))
        if phase == "import":
            verify_prepared(cfg)
        elif phase in ENGINE_PHASES:
            verify_identity(cfg)
        result = result_for(args, cfg, phase, layout)
        validate_layout(layout)
        receipt = {"schema": "bth.grand_spatial_trial_phase/v1", "phase": phase, "status": "PASS",
            "source_config_sha256": fingerprint(cfg), "job_receipt": str(layout.evidence / "job.json"), "artifacts": result,
            "source_commit": cfg["source_commit"], "art_approval": False, "production_art_written": False, "test_updated": False}
        write_new(layout.evidence / "phase-result.json", receipt)
        print(json.dumps(receipt, indent=2))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, TypeError, tarfile.TarError) as error:
        print(json.dumps({"status": "GRAND_TRIAL_STOPPED", "phase": args.phase, "error": str(error),
            "fallback_attempted": False, "production_art_written": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
