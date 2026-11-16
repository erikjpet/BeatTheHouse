"""Version2 guarded qualification of the reviewed High Limit R1 package.

Admits only the exact assembler-created external baseline ignore sentinel as a
separate authenticated auxiliary. It never enters the art seal or qa_source.

Explicit phases only; no automatic retries or full-archive fallback. Selection
uses bth_qa_selected_source's pure APIs and exact Git commands. Historical source
labels remain provenance; fresh selected Git blobs and all QA overlays are bound.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from contextlib import contextmanager
import json
import math
import os
from pathlib import Path
import re
import struct
import tarfile
from types import SimpleNamespace
import zipfile

import grand_spatial_native_trial as guard
import bth_qa_selected_source as selected
import high_limit_spatial_native_profile_v2 as policy

FROZEN_GUARD_SHA = "650e14dfd71197bd55021553e3ec9adfe1f67533ea3e7c930a456e05bcd3ac6a"
ORIGINAL_POLICY_SHA = "1c6cc6a722870785b9a39ecbb88f99cddbda34fc17151b52dc0392f81d8e1273"
ORIGINAL_RUNNER_SHA = "5ecdbb5b626be06059db0bbe305b76765adf8cfae1c8832abde00dc4361adef3"
SELECTED_SOURCE_SHA = "311ab097dd7d57ab0eacdd342b2b4e0b8f6d49af914e827c8f5adbd934c7e353"
PHASES = ("source-identity", "tree", "baseline-tree", "select", "archive", "prepare", "install", "import", "identity", "contexts", "motion", "liveness", "capture")
GIT_PHASES = {"source-identity", "tree", "baseline-tree", "archive"}
FILE_PHASES = {"select", "prepare", "install", "identity"}
OUTER_PHASES = GIT_PHASES | {"select", "prepare"}
ENGINE_PHASES = {"import", "contexts", "motion", "liveness", "capture"}
IDENTITY_NAMES = {"highlimit_capture_inputs.json", "highlimit_spatial_source_identity.json"}
PHASE_SCHEMA = "bth.high_limit_spatial_trial_phase/v1"
REPORT_NAMES = {"contexts": policy.ROOM + "_preart_metadata.json", "motion": policy.ROOM + "_animation_probe.json", "capture": "capture/animation_capture.json"}


def config(args):
    selected.full_hash(args.source_commit)
    selected.full_hash(args.source_tree)
    policy.require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,65}", args.run_prefix) and
        1 <= args.timeout <= 1200 and 0 < args.capture_seconds <= 20, "Fresh prefix/timeout1..1200/capture0..20 required")
    paths = {name: selected.plain(getattr(args, name)) for name in ("workspace", "qa_root", "engine", "git", "git_dir", "baseline_stage",
        "native_extension_descriptor", "editor_native_library", "candidate_root", "candidate_manifest", "review")}
    policy.require(all(Path(getattr(args, name)).is_absolute() for name in paths) and
        selected.same_path(paths["qa_root"], selected.ROOT) and paths["workspace"].parent == paths["qa_root"] / "workspaces" and
        paths["workspace"].name == "BTH-ENV-SPATIAL-HLTRIAL-20261116", "Exact existing admitted HL campaign and explicit absolute paths required")
    workspace = paths["workspace"]
    policy.require({p.name for p in workspace.iterdir()} <= {"source_baseline", "candidate_sources", "qa_source"}, "Unexpected campaign-root content")
    baseline_state = policy.baseline_state(workspace)
    baseline = baseline_state["payload_files"]
    policy.require(guard.sha(Path(__file__).with_name("high_limit_spatial_native_profile.py")) == ORIGINAL_POLICY_SHA and
        guard.sha(Path(__file__).with_name("high_limit_spatial_native_trial.py")) == ORIGINAL_RUNNER_SHA,
        "Frozen original HL policy/runner must remain unchanged")
    sources = workspace / "candidate_sources"
    policy.require({p.name for p in sources.iterdir()} == {".gdignore", "provenance.json", "high-limit-spatial-r1.png", "high-limit-spatial-r1-assembled-v1"} and
        selected.plain(sources / ".gdignore").read_bytes() == policy.IGNORE and guard.sha(sources / "high-limit-spatial-r1.png") == policy.RAW_SHA,
        "Exact quarantined non-active source/candidate closure required")
    for path in sources.rglob("*"):
        selected.plain(path)
    policy.require(guard.sha(paths["engine"]) == guard.ENGINE_SHA and
        guard.sha(paths["engine"].with_name("Godot_v4.6-stable_win64.exe")) == guard.RUNTIME_SHA and
        guard.sha(Path(guard.__file__)) == FROZEN_GUARD_SHA and guard.sha(Path(selected.__file__)) == SELECTED_SOURCE_SHA,
        "Pinned engine/runtime/frozen generic guard/selected-source helper changed")
    descriptor, library = paths["native_extension_descriptor"], paths["editor_native_library"]
    policy.require(descriptor.is_relative_to(paths["qa_root"]) and library.is_relative_to(paths["qa_root"]) and
        guard.sha(descriptor) == guard.NATIVE_DESCRIPTOR_SHA and guard.sha(library) == guard.EDITOR_DLL_SHA and
        library.name == guard.EDITOR_DLL_NAME and selected.same_path(paths["baseline_stage"], selected.BASE_STAGE), "Explicit qualified native overlay/baseline stage required")
    lines = [row.strip() for row in descriptor.read_text(encoding="utf-8-sig").splitlines() if row.strip().startswith("windows.debug")]
    policy.require(any('"res://addons/coin_pusher_native/bin/' + guard.EDITOR_DLL_NAME + '"' in row for row in lines), "Descriptor Windows debug library mismatch")
    dependencies = {name: guard.sha(Path(__file__).with_name(name)) for name in
        ("grand_spatial_native_trial.py", "high_limit_spatial_native_profile_v2.py", "high_limit_spatial_native_profile.py", "high_limit_spatial_native_trial.py", "bth_qa_selected_source.py", "bth_qa_storage.py",
         "bth_qa_guarded_run.py", "bth_qa_command_paths.py", "bar_spatial_native_suite.py", "bar_spatial_candidate_check.py", "audit_pck_manifest.py")}
    cfg = {"schema": "bth.high_limit_spatial_inputs/v1", **{name: str(path) for name, path in paths.items()},
        "project": str(workspace / "qa_source"), "run_prefix": args.run_prefix, "source_commit": args.source_commit, "source_tree": args.source_tree,
        "timeout": args.timeout, "position": args.position, "capture_seconds": args.capture_seconds,
        "adapter_sha256": guard.sha(__file__), "python_sha256": guard.sha(sys.executable), "git_sha256": guard.sha(paths["git"]),
        "dependencies": dependencies, "baseline_files": baseline, "baseline_seal": policy.BASELINE_SEAL,
        "baseline_auxiliary_files": baseline_state["auxiliary_files"], "baseline_auxiliary_policy": "exact_single_sentinel_v2",
        "candidate_proof_sha256": policy.PROOF_SHA, "review_sha256": policy.REVIEW_SHA,
        "source_scope": selected.SCOPE, "full_repository_archive": False,
        "historical_observer_commit": policy.HISTORICAL_COMMIT, "canonical_imports_must_be_committed": policy.CANONICAL_IMPORTS,
        "native_overlay": {"descriptor_input": str(descriptor), "descriptor_sha256": guard.NATIVE_DESCRIPTOR_SHA,
            "editor_dll_input": str(library), "editor_dll_sha256": guard.EDITOR_DLL_SHA,
            "scope": "Explicit retained qualified TEST native configuration overlay beyond Git source/candidate; native QA only"}}
    cfg["archive"] = str(guard.evidence_for(cfg, "archive") / "source.tar")
    return cfg



def verify_baseline(cfg):
    state = policy.baseline_state(Path(cfg["workspace"]))
    policy.require(state["payload_files"] == cfg["baseline_files"] and
        state["auxiliary_files"] == cfg["baseline_auxiliary_files"],
        "External logical21/auxiliary custody changed after configuration")
    return state["auxiliary_files"]


def command(cfg, phase, layout):
    if phase in GIT_PHASES:
        return selected.phase_command(cfg, phase)
    if phase in FILE_PHASES:
        arguments = []
        for key in ("workspace", "qa_root", "engine", "git", "git_dir", "baseline_stage", "native_extension_descriptor", "editor_native_library",
                    "candidate_root", "candidate_manifest", "review", "source_commit", "source_tree", "run_prefix", "timeout", "capture_seconds", "position"):
            arguments += ["--" + key.replace("_", "-") + "=" + str(cfg[key])]
        return [sys.executable, "-B", str(Path(__file__).resolve()), phase, *arguments, "--worker"]
    result = [cfg["engine"]] + (["--headless"] if phase in ("import", "liveness") else []) + ["--path", cfg["project"]]
    if phase == "import":
        return result + ["--editor", "--import"]
    if phase == "liveness":
        return result + ["--script", "res://scripts/tests/animation_liveness_without_pointer_check.gd"]
    scripts = {"contexts": "envart_highlimit_preart_metadata.gd", "motion": "envart_highlimit_animation_probe.gd", "capture": "envart_highlimit_animation_capture.gd"}
    result += ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--resolution", "1280x720", "--position", cfg["position"], "--script", "res://tools/" + scripts[phase]]
    if phase == "motion":
        result += ["--", "--out=" + str(layout.evidence)]
    elif phase == "capture":
        result += ["--", "--out=" + str(layout.evidence / "capture"), "--excerpt-seconds=" + str(cfg["capture_seconds"]), "--archetype=" + policy.ROOM, "--scenario=__none"]
    return result


def previous(cfg, phase):
    result = guard.prior(cfg, phase)
    evidence = guard.evidence_for(cfg, phase)
    job, inputs = guard.read_json(evidence / "job.json"), guard.read_json(evidence / "trial-inputs.json")
    manifest, claim = (guard.read_json(evidence / name) for name in ("storage-manifest.json", "launch-claim.json"))
    required = {"worker-result.json"} if phase in FILE_PHASES else set()
    if phase == "select":
        required |= {"selection.json", "closure.json"}
    if phase in REPORT_NAMES:
        required.add(REPORT_NAMES[phase])
    workspace = cfg["workspace"] if phase in OUTER_PHASES else cfg["project"]
    policy.require(result.get("schema") == PHASE_SCHEMA and selected.qualified_job(job) and
        result.get("baseline_auxiliary_files_before") == cfg["baseline_auxiliary_files"] == result.get("baseline_auxiliary_files_after") and
        result.get("baseline_auxiliary_files_unchanged") is True and
        result.get("job_sha256") == guard.sha(evidence / "job.json") and result.get("log_sha256") == guard.sha(evidence / "worker.log") and
        inputs.get("source_config") == cfg and inputs.get("source_config_sha256") == guard.fingerprint(cfg) and
        job.get("command") == inputs.get("command") == command(cfg, phase, SimpleNamespace(evidence=evidence)) and
        selected.same_path(result.get("job_receipt", ""), evidence / "job.json") and manifest.get("prepared") is True and
        selected.same_path(manifest["paths"]["workspace"], workspace) and selected.same_path(manifest["paths"]["evidence"], evidence) and
        selected.same_path(job.get("storage_manifest", ""), evidence / "storage-manifest.json") and
        job.get("storage_manifest_sha256") == claim.get("manifest_sha256") == guard.sha(evidence / "storage-manifest.json") and
        set(result.get("artifact_sha256", {})) == required and
        not guard.ERROR_LINE.search((evidence / "worker.log").read_text(encoding="utf-8", errors="replace")), "Prior exact closed phase custody differs: " + phase)
    for name, digest in result["artifact_sha256"].items():
        policy.require(guard.sha(evidence / selected.relative_name(name)) == digest, "Prior phase artifact changed: " + name)
    return result


def selection(cfg):
    result = previous(cfg, "select")
    evidence = guard.evidence_for(cfg, "select")
    plan, closure = guard.read_json(evidence / "selection.json"), guard.read_json(evidence / "closure.json")
    selected.validate_plan(plan)
    policy.require(plan["source_commit"] == cfg["source_commit"] and plan["source_tree"] == cfg["source_tree"] and
        closure["selection_sha256"] == plan["selection_sha256"] == result["artifacts"]["selection_sha256"], "Selected current source binding changed")
    return plan, closure


def select_worker(cfg, layout):
    for phase in ("source-identity", "tree", "baseline-tree"):
        previous(cfg, phase)
    plan = selected.selection_plan((guard.evidence_for(cfg, "source-identity") / "worker.log").read_bytes(),
        (guard.evidence_for(cfg, "tree") / "worker.log").read_bytes(), cfg["source_commit"], cfg["source_tree"])
    selected.write_budget(plan, layout.expected_write_bytes)
    closure = selected.prove_closure(plan, cfg["baseline_stage"], cfg["native_extension_descriptor"],
        (guard.evidence_for(cfg, "baseline-tree") / "worker.log").read_bytes())
    policy.require(set(policy.CANONICAL_IMPORTS).issubset(plan["files"]), "Root must first commit the nine independently audited canonical HL imports")
    for name, value in (("selection.json", plan), ("closure.json", closure)):
        guard.write_new(layout.evidence / name, value)
    return {"selection_sha256": plan["selection_sha256"], "selected_files": plan["selected_files"], "selected_bytes": plan["selected_bytes"], "scope": selected.SCOPE}


def prepare_worker(cfg, layout):
    plan, closure = selection(cfg)
    archive = previous(cfg, "archive")["artifacts"]
    policy.require(guard.sha(cfg["archive"]) == archive["sha256"], "Closed Git selected archive changed")
    selected.write_budget(plan, layout.expected_write_bytes)
    proof = selected.verify_tar(cfg["archive"], plan)
    for name, expected in {**cfg["baseline_files"], **policy.CANONICAL_IMPORTS}.items():
        policy.require(proof["files"].get(name, {}).get("sha256") == expected, "Committed baseline/canonical import differs: " + name)
    project = Path(cfg["project"])
    extracted = selected.extract_verified(cfg["archive"], plan, project, layout)
    policy.canonical_imports(project)
    for relative, source, expected in (
        (selected.DESCRIPTOR, cfg["native_extension_descriptor"], guard.NATIVE_DESCRIPTOR_SHA),
        ("addons/coin_pusher_native/bin/" + guard.EDITOR_DLL_NAME, cfg["editor_native_library"], guard.EDITOR_DLL_SHA)):
        target = project / relative
        policy.require(not target.exists() and guard.sha(source) == expected, "Overlay occupied/input changed: " + relative)
        guard.validate_layout(layout, extra_write_paths=(target.parent,))
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as handle:
            handle.write(Path(source).read_bytes())
        policy.require(guard.sha(target) == expected, "Qualified native overlay copy differs: " + relative)
    bindings = {}
    for name, expected in policy.HELPERS.items():
        target, original = project / name, (policy.LEGACY / name).read_bytes()
        if target.exists():
            policy.require(target.read_bytes().replace(b"\r\n", b"\n") == original.replace(b"\r\n", b"\n"), "Current observer differs beyond line endings: " + name)
        else:
            guard.validate_layout(layout, extra_write_paths=(target.parent,))
            with target.open("xb") as handle:
                handle.write(original)
        bindings[name] = {"original_sha256": expected, "active_sha256": guard.sha(target), "assertions_unchanged": True, "canonical_uid_overwritten": False}
    reference = project / "qa_reference"
    guard.validate_layout(layout, extra_write_paths=(reference,))
    reference.mkdir()
    with (reference / ".gdignore").open("x") as handle:
        handle.write("# Historical observer/reference source is excluded from Godot discovery.\n")
    with zipfile.ZipFile(reference / "high-limit-original-observers.zip", "x", compression=zipfile.ZIP_DEFLATED) as saved:
        for name in sorted({**policy.HELPERS, **policy.PROVENANCE}):
            saved.writestr(name, (policy.LEGACY / name).read_bytes())
    with (project / "override.cfg").open("xb") as handle:
        handle.write(guard.IMPORT_POLICY)
    result = {"source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"], "source_scope": selected.SCOPE,
        "source_archive_sha256": archive["sha256"], "selection_sha256": plan["selection_sha256"], "selected_archive_proof": extracted,
        "qualified_baseline_closure": closure, "files": guard.scan(project), "helper_bindings": bindings,
        "explicit_qualified_native_overlay": cfg["native_overlay"], "historical_7344_inventory_is_provenance_only": True,
        "candidate_sources_not_imported": True, "canonical_tracked_uid_sidecars_preserved": True, "legacy_adapter_executed": False,
        "baseline_auxiliary_files": verify_baseline(cfg), "baseline_auxiliary_not_extracted_into_project": True}
    guard.write_new(reference / "prepared-source.json", result)
    return {"project": str(project), "source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"],
        "source_scope": selected.SCOPE, "prepared_identity_sha256": guard.sha(reference / "prepared-source.json"), "files": len(result["files"])}


def install_worker(cfg, layout):
    previous(cfg, "prepare")
    prepared, installed = guard.verify_prepared(cfg)
    policy.require(installed is None, "Fresh install only; no candidate overwrite")
    policy.require(prepared.get("baseline_auxiliary_files") == verify_baseline(cfg), "Prepared external auxiliary binding changed")
    result = policy.candidate(Path(cfg["candidate_root"]), Path(cfg["workspace"]), Path(cfg["candidate_manifest"]), Path(cfg["review"]), cfg["baseline_files"])
    project = Path(cfg["project"])
    for name, baseline in cfg["baseline_files"].items():
        policy.require(guard.sha(project / name) == baseline, "Prepared baseline changed before installation")
    for name, expected in result["files"].items():
        if expected != cfg["baseline_files"][name]:
            guard.validate_layout(layout, extra_write_paths=((project / name).parent,))
            with (project / name).open("wb") as handle:
                handle.write((Path(cfg["candidate_root"]) / name).read_bytes())
        policy.require(guard.sha(project / name) == expected, "Candidate copy mismatch: " + name)
    policy.canonical_imports(project)
    result["baseline_auxiliary_files"] = verify_baseline(cfg)
    guard.write_new(project / "qa_reference/candidate-install.json", result)
    return result


def identity_files(project):
    return {name: value for name, value in guard.scan(project).items() if name not in IDENTITY_NAMES}


def verify_prepared(cfg):
    previous(cfg, "prepare")
    previous(cfg, "install")
    prepared, installed = guard.verify_prepared(cfg)
    auxiliary = verify_baseline(cfg)
    policy.require(prepared.get("baseline_auxiliary_files") == auxiliary and
        (installed is None or installed.get("baseline_auxiliary_files") == auxiliary),
        "Prepared/installed external auxiliary proof differs")
    return prepared, installed


def identity_worker(cfg, layout):
    previous(cfg, "import")
    prepared, installed = verify_prepared(cfg)
    policy.require(installed is not None, "Approved installed candidate required")
    project = Path(cfg["project"])
    policy.require(not any((project / name).exists() for name in IDENTITY_NAMES), "No rebinding an existing identity")
    files = identity_files(project)
    extras = set(files) - set(prepared["files"]) - {"qa_reference/prepared-source.json", "qa_reference/candidate-install.json"}
    policy.require(all((name.endswith(".uid") and (project / name[:-4]).is_file()) or
        (name.endswith(".import") and (project / name[:-7]).is_file()) for name in extras), "Unexpected source addition after import")
    catalog = guard.read_json(project / "data/environments/scenarios.json")
    policy.require(catalog.get(policy.ROOM, []) == [], "High Limit supports Base only; no public-Grand scenarios")
    guard.write_new(project / "highlimit_capture_inputs.json", {"source_hashes": files, "catalog": ["__none"],
        "baseline_auxiliary_files": verify_baseline(cfg), "external_auxiliary_excluded_from_res_source_hashes": True})
    result = {"schema": "bth.high_limit_current_source_identity/v1", "source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"],
        "source_scope": selected.SCOPE, "selection_sha256": prepared["selection_sha256"], "source_archive_sha256": prepared["source_archive_sha256"],
        "source_config_sha256": guard.fingerprint(cfg), "files": files, "capture_inputs_sha256": guard.sha(project / "highlimit_capture_inputs.json"),
        "original_observers": prepared["helper_bindings"], "historical_observer_report_commit_label": policy.HISTORICAL_COMMIT,
        "historical_label_is_not_current_source_identity": True, "canonical_tracked_uid_sidecars_preserved": True,
        "baseline_auxiliary_files": verify_baseline(cfg), "baseline_auxiliary_not_in_project_inventory": True}
    guard.write_new(project / "highlimit_spatial_source_identity.json", result)
    return {"identity_sha256": guard.sha(project / "highlimit_spatial_source_identity.json"), "capture_inputs_sha256": result["capture_inputs_sha256"],
        "source_files": len(files), "expected_context_checks": 2 * len(files) + 83, "candidate_package_sha256": installed["package_sha256"]}


def verify_identity(cfg):
    qualified = previous(cfg, "identity")["artifacts"]
    project = Path(cfg["project"])
    policy.require(guard.sha(project / "highlimit_spatial_source_identity.json") == qualified["identity_sha256"] and
        guard.sha(project / "highlimit_capture_inputs.json") == qualified["capture_inputs_sha256"], "Current frozen identity/observer input changed")
    identity = guard.read_json(project / "highlimit_spatial_source_identity.json")
    policy.require(identity_files(project) == identity["files"], "Selected source/candidate/native overlay/UID inventory changed")
    auxiliary = verify_baseline(cfg)
    capture_inputs = guard.read_json(project / "highlimit_capture_inputs.json")
    policy.require(identity.get("baseline_auxiliary_files") == capture_inputs.get("baseline_auxiliary_files") == auxiliary and
        capture_inputs.get("external_auxiliary_excluded_from_res_source_hashes") is True,
        "Identity/capture external auxiliary proof differs")
    return identity


@contextmanager
def engine_admission(enabled):
    policy.require(enabled, "Explicit --engine-go campaign admission required")
    key, token = "BTH_HIGHLIMIT_PREART_ENGINE_GO", "EXPLICIT_PARENT_SAFE_GAP_GO"
    old = os.environ.get(key)
    os.environ[key] = token
    try:
        yield
    finally:
        if old is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = old


def result_for(cfg, phase, layout):
    if phase in FILE_PHASES:
        value = guard.read_json(layout.evidence / "worker-result.json")
        return {"candidate_install_sha256": guard.sha(Path(cfg["project"]) / "qa_reference/candidate-install.json"), "record": value} if phase == "install" else value
    log = (layout.evidence / "worker.log").read_text(encoding="utf-8", errors="strict")
    if phase == "source-identity":
        policy.require(log.strip().splitlines() == [cfg["source_commit"], cfg["source_tree"]], "Actual Git full commit/tree mismatch")
        return {"commit": cfg["source_commit"], "tree": cfg["source_tree"]}
    if phase in ("tree", "baseline-tree"):
        rows = selected.parse_ls_tree((layout.evidence / "worker.log").read_bytes())
        return {"records_sha256": selected.digest(rows), "files": len(rows)}
    if phase == "archive":
        return {"path": cfg["archive"], "sha256": guard.sha(cfg["archive"]), "bytes": Path(cfg["archive"]).stat().st_size}
    if phase == "import":
        return {"canonical_source_files_verified": True, "candidate_installed": True}
    if phase == "liveness":
        policy.require("Animation liveness without pointer input: PASS" in log, "Mandatory no-pointer liveness marker absent")
        return {"no_pointer_liveness": True}
    path = layout.evidence / REPORT_NAMES[phase]
    report = guard.read_json(path)
    additional = {}
    policy.require(not report.get("findings") and not report.get("failures"), "Native report contains findings/failures")
    if phase == "contexts":
        views = report.get("views", {})
        view = views.get("__none", {})
        pairs = view.get("source_paint", {}).get("objects", [])
        ids = {row.get("id") for row in view.get("actual_view", {}).get("objects", [])}
        selected_ids = {row.get("id") for row in view.get("selected_label_evidence", [])}
        pair_ids = {row.get("object", {}).get("id") for row in pairs}
        policy.require(set(views) == {"__none"} and report.get("direct_catalog") == ["__none"] and
            ids == selected_ids == pair_ids == policy.OBJECT_IDS and len(pairs) == 9 and len(view.get("selected_label_evidence", [])) == 9 and
            report.get("checks") == previous(cfg, "identity")["artifacts"]["expected_context_checks"], "Original Base9objects/9pairs/9selections/2N+83 checks changed")
    elif phase == "motion":
        entries, low = report.get("entries", []), report.get("simulated_low_detail_entries", [])
        policy.require([row.get("id") for row in entries] == list(policy.ANIMATION_IDS) and
            [row.get("id") for row in low if row.get("included")] == list(policy.LOW_IDS) and len(low) == 16 and
            report.get("simulated_low_detail_count") == 7 and report.get("checks") == 66 and
            all(row.get("live_visible_change") is True and row.get("reduce_motion_stable") is True for row in entries) and
            all(row.get("reduce_motion_stable") is True and row.get("live_change") == row.get("included") for row in low), "Original16/7/66 visible-motion/Reduce Motion coverage changed")
    else:
        frames = report.get("frames", [])
        clocks = [row.get("clock") for row in frames]
        policy.require(report.get("archetype") == policy.ROOM and report.get("scenario") == "__none" and report.get("pack_active") is True and
            [row.get("id") for row in report.get("animation_inventory", [])] == list(policy.ANIMATION_IDS) and len(frames) >= 2 and
            all(type(clock) in (int, float) and math.isfinite(clock) for clock in clocks) and all(b > a for a, b in zip(clocks, clocks[1:])) and
            abs(report["actual_clock_span"] - (clocks[-1] - clocks[0])) <= 0.00001 and
            report.get("reduce_motion", {}).get("active") is True and report.get("reduce_motion", {}).get("production_art_texture_pixels_stable") is True and
            "no pointer input during capture" in report.get("note", ""), "Authentic16-entry actual-clock capture/Reduce Motion contract failed")
        pngs = []
        for row in frames:
            policy.require([item.get("id") for item in row.get("animation_states", [])] == list(policy.ANIMATION_IDS), "Capture frame missing original16-entry states")
            policy.require(row.get("width") == 1280 and row.get("height") == 720, "Full-app recording dimensions changed")
            for key, dimensions in (("file", (1280, 720)), ("board900_file", (900, 430)), ("board2x_file", (1800, 860))):
                name = selected.relative_name(row[key])
                png = selected.plain(layout.evidence / "capture" / name, file=True)
                with png.open("rb") as handle:
                    header = handle.read(24)
                policy.require(len(header) == 24 and header[:8] == b"\x89PNG\r\n\x1a\n" and header[8:16] == b"\0\0\0\rIHDR" and
                    struct.unpack(">II", header[16:24]) == dimensions, "Capture PNG header/dimensions differ")
                pngs.append({"file": name, "family": key, "clock": row["clock"], "dimensions": list(dimensions), "bytes": png.stat().st_size, "sha256": guard.sha(png)})
        policy.require(len({row["file"] for row in pngs}) == len(pngs), "Capture PNG path reused across frames/families")
        additional = {"frame_png_inventory": pngs, "source_capture_json_sha256": guard.sha(path),
            "baseline_auxiliary_files": verify_baseline(cfg), "baseline_auxiliary_not_in_res_source_hashes": True,
            "fullapp_is_actual_production": True, "board900_is_diagnostic_clone": True, "native1800_excludes_live_objects": True,
            "no_pointer_input_during_capture": True, "no_interpolation_resizing_or_frame_clock_rewrite": True}
    return {"report": str(path), "sha256": guard.sha(path), "checks": report.get("checks"), "frames": len(report.get("frames", [])),
        "actual_clock_span": report.get("actual_clock_span"), "current_source_commit": cfg["source_commit"],
        "observer_embedded_historical_commit": report.get("commit"), "historical_label_is_not_current_source_identity": True,
        "encoding": "None; animated user artifact must preserve these actual clocks without invented FPS", **additional}


def main(argv=None):
    tokens = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", *PHASES))
    for name in ("workspace", "engine", "git", "git-dir", "candidate-root", "candidate-manifest", "review"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--qa-root", type=Path, default=selected.ROOT)
    parser.add_argument("--baseline-stage", type=Path, default=selected.BASE_STAGE)
    parser.add_argument("--native-extension-descriptor", type=Path, default=guard.QUALIFIED_NATIVE_SOURCE / "coin_pusher_native.gdextension")
    parser.add_argument("--editor-native-library", type=Path, default=guard.QUALIFIED_NATIVE_SOURCE / "bin" / guard.EDITOR_DLL_NAME)
    for name in ("source-commit", "source-tree", "run-prefix"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--engine-go", action="store_true")
    parser.add_argument("--capture-seconds", type=float, default=20)
    parser.add_argument("--position", default="-32000,-32000")
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(tokens)
    try:
        cfg = config(args)
        baseline_auxiliary_before = verify_baseline(cfg)
        if args.worker:
            policy.require(args.phase in FILE_PHASES, "Only internal file phases allowed")
            layout = guard.load_layout(cfg)
            inputs = guard.read_json(layout.evidence / "trial-inputs.json")
            policy.require(layout.prepared and inputs.get("source_config") == cfg and
                selected.same_path(layout.evidence, guard.evidence_for(cfg, args.phase)), "Exact worker admission required")
            workers = {"select": select_worker, "prepare": prepare_worker, "install": install_worker, "identity": identity_worker}
            result = workers[args.phase](cfg, layout)
            policy.require(verify_baseline(cfg) == baseline_auxiliary_before, "External baseline changed during file worker")
            guard.write_new(layout.evidence / "worker-result.json", result)
            return 0
        phases = PHASES if args.phase == "plan" else (args.phase,)
        layouts = {phase: guard.plan_layout(args.qa_root, cfg["workspace"] if phase in OUTER_PHASES else cfg["project"], args.run_prefix + "-" + phase) for phase in phases}
        for layout in layouts.values():
            guard.validate_layout(layout, extra_write_paths=(Path(cfg["project"]),))
        if args.phase == "plan":
            print(json.dumps({"status": "READ_ONLY_HIGH_LIMIT_V2_PLAN", "source_config": cfg, "source_config_sha256": guard.fingerprint(cfg),
                "phases": [{"phase": phase, "workspace": str(layout.workspace), "command": command(cfg, phase, layout),
                    "engine_admission_required": phase in ENGINE_PHASES} for phase, layout in layouts.items()], "executed": False}, indent=2))
            return 0
        phase, layout = args.phase, layouts[args.phase]
        if phase == "source-identity":
            policy.require(not Path(cfg["project"]).exists(), "Fresh absent qa_source required before new campaign")
        elif phase in ("tree", "baseline-tree", "select", "archive", "prepare", "install", "import", "identity"):
            previous(cfg, PHASES[PHASES.index(phase) - 1])
        if phase == "archive":
            plan, _ = selection(cfg)
            selected.write_budget(plan, layout.expected_write_bytes)
            policy.require(not Path(cfg["archive"]).exists(), "No overwriting a selected source archive")
        if phase in ENGINE_PHASES:
            policy.require(args.engine_go, "Explicit --engine-go campaign admission required")
            verify_prepared(cfg) if phase == "import" else verify_identity(cfg)
        if phase == "capture":
            for required in ("contexts", "motion", "liveness"):
                previous(cfg, required)
        layout = guard.prepare_layout(layout)
        cmd = command(cfg, phase, layout)
        extra = (Path(cfg["project"]),) if phase in OUTER_PHASES else ()
        if phase == "capture":
            extra += (layout.evidence / "capture",)
        guard.write_new(layout.evidence / "trial-inputs.json", {"source_config": cfg, "source_config_sha256": guard.fingerprint(cfg), "command": cmd,
            "engine_campaign_admission": args.engine_go if phase in ENGINE_PHASES else False, "admission_scope": "Explicit campaign admission; no host-zero or mutex claim"})
        if phase in ENGINE_PHASES:
            with engine_admission(args.engine_go):
                job = guard.execute(layout, cmd, timeout=args.timeout, cpu_rate=1200, extra_write_paths=extra)
        else:
            job = guard.execute(layout, cmd, timeout=args.timeout, cpu_rate=1200, extra_write_paths=extra)
        log = (layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")
        policy.require(verify_baseline(cfg) == baseline_auxiliary_before, "External baseline changed during guarded phase")
        policy.require(selected.qualified_job(job) and not guard.ERROR_LINE.search(log), "Guarded Job/native log failed; retained evidence: " + str(layout.evidence))
        if phase == "import":
            verify_prepared(cfg)
        elif phase in ENGINE_PHASES:
            verify_identity(cfg)
        artifacts = result_for(cfg, phase, layout)
        names = {"worker-result.json"} if phase in FILE_PHASES else set()
        if phase == "select":
            names |= {"selection.json", "closure.json"}
        if phase in REPORT_NAMES:
            names.add(REPORT_NAMES[phase])
        receipt = {"schema": PHASE_SCHEMA, "phase": phase, "status": "PASS", "source_config_sha256": guard.fingerprint(cfg),
            "source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"], "source_scope": selected.SCOPE,
            "job_receipt": str(layout.evidence / "job.json"), "job_sha256": guard.sha(layout.evidence / "job.json"), "log_sha256": guard.sha(layout.evidence / "worker.log"),
            "artifact_sha256": {name: guard.sha(layout.evidence / name) for name in sorted(names)}, "artifacts": artifacts,
            "baseline_auxiliary_files_before": baseline_auxiliary_before, "baseline_auxiliary_files_after": verify_baseline(cfg),
            "baseline_auxiliary_files_unchanged": True,
            "art_approval": False, "production_art_written": False, "test_updated": False}
        guard.validate_layout(layout)
        guard.write_new(layout.evidence / "phase-result.json", receipt)
        print(json.dumps(receipt, indent=2))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, TypeError, tarfile.TarError, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "HIGH_LIMIT_V2_TRIAL_STOPPED", "phase": args.phase, "error": str(error), "fallback_attempted": False,
            "production_art_written": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
