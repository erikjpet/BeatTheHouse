"""Positive Grand Back Room-only TEST executor; fresh selected source, capped phases.

No publication/network. Every child uses the maintained storage/Job launcher.
An authentic final GBR GO and actual delivered-HL certificate are mandatory,
including for planning. Frozen Bar/Grand executors are never patched/dispatched.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re

import bar_spatial_test_build as common
import bth_qa_selected_source_v2 as selected
import grand_back_room_spatial_test_profile_v2 as policy
import grand_back_room_spatial_test_release_profile as release
from bth_qa_guarded_run import execute
from bth_qa_storage import Layout, StorageGuardError, plan_layout, prepare_layout, validate_layout

SCHEMA = "bth.grand_back_room_test_build_phase/v1"
PHASES = ("source-identity", "tree", "baseline-tree", "select", "archive", "extract", "seed", "identity", "identity-scope", "import", "export", "webgl-apply", "webgl-verify", "finalize", "verify")
OUTER = {"source-identity", "tree", "baseline-tree", "select", "archive", "extract"}
FILES = {"select", "extract", "seed", "identity-scope", "finalize", "verify"}
ERROR_LINE = re.compile(r"(?:SCRIPT ERROR|(?<![A-Z])ERROR):")
EDITOR_SHA = "9ed33e21a00a8be3ef2429550451ed6c766debde8d0d21c4f3a4c39e25eb3f82"
DESCRIPTOR = selected.BASE_STAGE.parents[2] / "addons/coin_pusher_native/coin_pusher_native.gdextension"


def sha(path):
    return release.sha(path)


def read(path):
    return release.read(path)


def require(value, message):
    policy.require(value, message)


def evidence(cfg, phase):
    return selected.ROOT / "runs" / (cfg["run_prefix"] + "-" + phase) / "evidence"


def write_paths(cfg, phase):
    """Positive outputs only; an existing tar is never an extract write target."""
    require(phase in PHASES, "Unknown fixed GBR v2 output phase")
    if phase == "archive":
        return (Path(cfg["archive"]),)
    if phase == "extract":
        return (Path(cfg["workspace"]),)
    if phase in OUTER:
        # Git identity/tree and selection write only their guarded run evidence.
        return ()
    return (Path(cfg["workspace"]), Path(cfg["stage"]).parent)


def config(args):
    for name in ("source_commit", "source_tree"):
        policy.full_hash(getattr(args, name), 40)
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,47}", args.run_prefix) and 1 <= args.timeout <= 1200, "Fresh bounded run prefix/timeout required")
    outer, stage = selected.plain(args.workspace), selected.plain(args.stage)
    project = outer / "qa_source"
    require(outer.drive.casefold() == "e:" and outer.is_relative_to(selected.ROOT / "workspaces") and outer != selected.ROOT / "workspaces" and
            stage == project / (".tmp/web-release-" + args.source_commit[:8] + "/stage") and not outer.is_relative_to(release.delivered.WORKSPACE) and
            not release.delivered.WORKSPACE.is_relative_to(outer), "Explicit fresh E outer/project/stage and disjoint delivered baseline required")
    approval = release.load_approval(args.approval_json, args.approval_sha256)
    require(sha(Path(selected.__file__)) == "051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625",
            "Exact independently reviewed/52-test qualified selected-source_v2 helper required; no311 fallback")
    inputs = {name: selected.plain(getattr(args, name), file=True) for name in ("engine", "native_library", "editor_native_library", "template", "git", "node")}
    for name, expected in (("engine", common.ENGINE_SHA), ("native_library", common.NATIVE_SHA), ("editor_native_library", EDITOR_SHA), ("template", common.TEMPLATE_SHA)):
        require(sha(inputs[name]) == expected, "Locked GBR build input differs: " + name)
    require(inputs["native_library"].name == common.NATIVE_NAME and inputs["editor_native_library"].name == common.EDITOR_NATIVE_NAME and
            inputs["template"].name == common.TEMPLATE_NAME, "Exact locked native/template basenames required")
    git_dir = selected.plain(args.git_dir)
    require(git_dir.is_dir(), "Existing explicit read-only repository Git directory required")
    helpers = ("grand_back_room_spatial_test_build.py", "grand_back_room_spatial_test_release_profile.py", "grand_back_room_spatial_test_profile_v2.py", "high_limit_spatial_test_profile.py",
        "high_limit_spatial_delivered_baseline.py", "bth_qa_selected_source_v2.py", "bth_qa_storage.py", "bth_qa_guarded_run.py", "bth_qa_command_paths.py",
        "audit_pck_manifest.py", "prepare_environment_art_build_identity.py", "prepare_environment_art_test_web.py", "publish_environment_art_test.py",
        "web_gl_handles.mjs", "web_gl_handles.lock.json", "web_gl_handles_allocator.txt")
    return {"schema": "bth.grand_back_room_test_build_inputs/v1", "environment": policy.ENVIRONMENT, "outer": str(outer), "workspace": str(project),
        "stage": str(stage), "archive": str(outer / "source_inputs/source.tar"), "run_prefix": args.run_prefix,
        "source_commit": args.source_commit, "source_tree": args.source_tree, "art_package_sha256": policy.PACKAGE_SHA,
        "approval_path": str(selected.plain(args.approval_json, file=True)), "approval_sha256": args.approval_sha256,
        "baseline_certificate_sha256": approval["baseline_certificate"]["certificate_sha256"], "timeout": args.timeout,
        **{name: str(path) for name, path in inputs.items()}, "git_dir": str(git_dir), "python_sha256": sha(sys.executable),
        "input_sha256": {name: sha(path) for name, path in inputs.items()},
        "helpers": {name: sha(Path(__file__).with_name(name)) for name in helpers}}


def approval_for(cfg):
    value = release.load_approval(cfg["approval_path"], cfg["approval_sha256"])
    require(value["baseline_certificate"]["certificate_sha256"] == cfg["baseline_certificate_sha256"], "Authenticated GBR baseline certificate changed")
    return value


def command(cfg, phase):
    git = [cfg["git"], "--git-dir=" + cfg["git_dir"], "-c", "core.quotePath=false", "-c", "tar.umask=0022"]
    if phase == "source-identity":
        return git + ["show", "-s", "--format=%H%n%T", cfg["source_commit"]]
    if phase in ("tree", "baseline-tree"):
        return git + ["ls-tree", "-r", "-l", "-z", selected.BASE_COMMIT if phase == "baseline-tree" else cfg["source_commit"]]
    if phase == "archive":
        return git + ["archive", "--format=tar", "--output=" + cfg["archive"], cfg["source_commit"], *selected.PATHS]
    if phase in FILES:
        tokens = []
        for name in ("workspace", "stage", "source_commit", "source_tree", "run_prefix", "approval_json", "approval_sha256", "engine", "native_library", "editor_native_library", "template", "git", "git_dir", "node", "timeout"):
            value = cfg["outer"] if name == "workspace" else cfg["approval_path"] if name == "approval_json" else cfg[name]
            tokens += ["--" + name.replace("_", "-"), str(value)]
        return [sys.executable, "-B", str(Path(__file__).absolute()), phase, "--worker", *tokens]
    if phase == "identity":
        return [sys.executable, "-B", str(Path(cfg["workspace"]) / "tools/prepare_environment_art_build_identity.py"), "prepare",
            "--snapshot", cfg["workspace"], "--source-commit", cfg["source_commit"], "--source-tree", cfg["source_tree"], "--engine", cfg["engine"],
            "--native-library", str(Path(cfg["workspace"]) / "addons/coin_pusher_native/bin" / common.NATIVE_NAME),
            "--export-presets", str(Path(cfg["workspace"]) / "export_presets.cfg"), "--art-package-sha256", policy.PACKAGE_SHA,
            "--build-version", "0.6.0-art-test+" + cfg["source_commit"][:12]]
    if phase == "import":
        return [cfg["engine"], "--headless", "--path", cfg["workspace"], "--editor", "--import"]
    if phase == "export":
        return [cfg["engine"], "--headless", "--path", cfg["workspace"], "--export-release", "Web", str(Path(cfg["stage"]) / "index.html")]
    if phase.startswith("webgl-"):
        result = [cfg["node"], str(Path(cfg["workspace"]) / "tools/web_gl_handles.mjs"), phase.split("-", 1)[1], "--stage", cfg["stage"]]
        return result + (["--owned-root", str(Path(cfg["stage"]).parent)] if phase == "webgl-apply" else [])
    raise ValueError("Unknown fixed GBR phase")


def previous(cfg, phase):
    e = evidence(cfg, phase)
    result, job, inputs = read(e / "phase-result.json"), read(e / "job.json"), read(e / "build-inputs.json")
    manifest, claim = read(e / "storage-manifest.json"), read(e / "launch-claim.json")
    require(result.get("schema") == SCHEMA and result.get("phase") == phase and result.get("status") == "PASS" and
            result.get("config_sha256") == selected.digest(cfg) and inputs == cfg and selected.qualified_job(job) and
            job["command"] == command(cfg, phase) and result["job_sha256"] == sha(e / "job.json") and result["log_sha256"] == sha(e / "worker.log") and
            selected.same_path(job["storage_manifest"], e / "storage-manifest.json") and
            job["storage_manifest_sha256"] == claim["manifest_sha256"] == sha(e / "storage-manifest.json") and manifest["prepared"] is True and
            selected.same_path(manifest["paths"]["workspace"], cfg["outer"] if phase in OUTER else cfg["workspace"]) and
            selected.same_path(manifest["paths"]["evidence"], e), "Exact prior guarded GBR phase is not closed PASS: " + phase)
    expected = {"worker-result.json"} if phase in FILES else set()
    if phase == "select":
        expected |= {"selection.json", "closure.json"}
    if phase == "identity-scope":
        expected.add("original-identity.json")
    if phase == "finalize":
        expected |= {"grand-back-room-package-seal.json", "art-source-import-pck-linkage.json", "pck-diff.json", "baseline-certificate.json"}
    require(set(result["artifact_sha256"]) == expected, "Incomplete GBR artifact custody")
    for name, expected_sha in result["artifact_sha256"].items():
        require(sha(e / name) == expected_sha, "Prior GBR artifact bytes changed")
    return result


def write(path, value, layout):
    validate_layout(layout, extra_write_paths=(Path(path).parent,))
    with selected.plain(path).open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def snapshot_pins(cfg, approval):
    root = Path(cfg["workspace"])
    require(not (root / ".git").exists() and sha(root / "export_presets.cfg") == common.PRESETS_SHA and
            sha(root / "scripts/core/persistence_paths.gd") == common.PERSISTENCE_SHA, "Unchanged source/export/persistence snapshot required")
    lock = read(root / "native/coin_pusher/toolchain.lock.json")
    require(lock["godot"]["commit"] == "89cea143987d564363e15d207438530651d943ac" and lock["web"]["version"] == "4.0.20" and
            lock["web"]["template_sha256"] == common.TEMPLATE_SHA, "Engine/native toolchain lock differs")
    for name, expected in cfg["helpers"].items():
        require(sha(root / "tools" / name) == expected and sha(Path(__file__).with_name(name)) == expected, "Exact archived/maintained GBR helper differs: " + name)
    return release.source_seal(root, approval)


def stage_links(cfg, approval):
    import audit_pck_manifest
    root, stage = Path(cfg["workspace"]), Path(cfg["stage"])
    base = approval["baseline_certificate"]["manifest"]
    data = (stage / "index.pck").read_bytes()
    require(len(data) <= 512 * 1024 ** 2, "Bounded GBR PCK required")
    directory = audit_pck_manifest.find_directory(data)
    entries = {row["path"]: row for row in directory["entries"]}
    require(len(entries) == len(directory["entries"]) and not audit_pck_manifest.audit(directory["entries"]), "GBR PCK directory invalid")
    raw, compiled, links = {}, {}, []
    for name in base["art_source_files"]:
        source = selected.plain(root / name, file=True)
        raw[name] = sha(source)
        if name.endswith(".png"):
            text = (selected.plain(root / (name + ".import"), file=True)).read_text(encoding="utf-8-sig")
            targets = re.findall(r'^path="res://([^"\n]+\.ctex)"\r?$', text, re.M)
            require(len(targets) == 1, "Actual GBR source has no unique CTEX import target")
            target = targets[0]
            require(target.startswith(".godot/imported/") and ".." not in Path(target).parts and target in base["compiled_art_sha256"], "Unexpected compiled art path")
            cached = selected.plain(root / target, file=True).read_bytes()
            packed = common.pck_entry_bytes(data, directory, entries[target])
            require(cached == packed, "Actual source import/compiled/PCK bytes differ")
            compiled[target] = hashlib.sha256(packed).hexdigest()
            md5 = (root / target).with_suffix(".md5").read_text(encoding="utf-8")
            require(re.findall(r'^source_md5="([0-9a-f]{32})"\r?$', md5, re.M) == [hashlib.md5(source.read_bytes()).hexdigest()] and
                    re.findall(r'^dest_md5="([0-9a-f]{32})"\r?$', md5, re.M) == [hashlib.md5(cached).hexdigest()], "Actual source/import MD5 linkage differs")
            links.append({"source": name, "source_sha256": raw[name], "compiled": target, "compiled_sha256": compiled[target],
                "pck_payload_sha256": hashlib.sha256(packed).hexdigest(), "actual_payload_verified": True})
        else:
            require(common.pck_entry_bytes(data, directory, entries[name]) == source.read_bytes(), "Actual art JSON/PCK differs")
    require(len(raw) == 421 and len(compiled) == len(links) == 400 and compiled.keys() == base["compiled_art_sha256"].keys(), "Complete421/400 import closure required")
    policy.check_source_hashes(base, raw)
    return raw, compiled, links


def finalize(cfg, layout, approval):
    from prepare_environment_art_build_identity import verify_embedded_identity
    from prepare_environment_art_test_web import prepare_test_html, TEST_ARGS, TEST_PERSISTENT_PATHS
    from publish_environment_art_test import validate_payload
    root, stage = Path(cfg["workspace"]), Path(cfg["stage"])
    seal = snapshot_pins(cfg, approval)
    identity = read(root / "build_manifest.json")
    require((identity["source_commit"], identity["source_tree"], identity["art_package_sha256"]) ==
            (cfg["source_commit"], cfg["source_tree"], policy.PACKAGE_SHA), "Pre-export GBR identity differs")
    embedded = verify_embedded_identity(stage / "index.pck", identity)
    raw, compiled, links = stage_links(cfg, approval)
    lock = read(root / "tools/web_gl_handles.lock.json")
    require(sha(stage / "index.js") == lock["output_sha256"] and (stage / lock["receipt_file"]).is_file() and
            sha(stage / common.NATIVE_NAME) == common.NATIVE_SHA, "Actual native/WebGL transform or receipt differs")
    normal, archived = stage / "index.html", stage.parent / "normal-index.html"
    require(not archived.exists() and not (stage / "build_manifest.json").exists() and not any(p.is_dir() for p in stage.iterdir()), "Fresh flat GBR stage required")
    html = prepare_test_html(normal.read_text(encoding="utf-8"), (root / "scripts/core/persistence_paths.gd").read_text(encoding="utf-8-sig"))
    validate_layout(layout, extra_write_paths=(stage, stage.parent))
    normal.rename(archived)
    with normal.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(html)
    base = approval["baseline_certificate"]["manifest"]
    manifest = {**identity, "source_branch": "codex/environment-art-layers", "source_archive_sha256": sha(cfg["archive"]), "source_archive_scope": selected.SCOPE,
        "source_selection_sha256": read(evidence(cfg, "select") / "selection.json")["selection_sha256"],
        "active_art_packages": {**base["active_art_packages"], policy.ENVIRONMENT: policy.PACKAGE_SHA}, "active_doorway_packages": base["active_doorway_packages"],
        "art_source_files": raw, "compiled_art_sha256": compiled, "template_sha256": common.TEMPLATE_SHA, "persistence_core_sha256": common.PERSISTENCE_SHA,
        "test_args": TEST_ARGS, "persistent_paths": TEST_PERSISTENT_PATHS, "generated_at": datetime.now(timezone.utc).isoformat(),
        "embedded_manifest_sha256": embedded["embedded_manifest_sha256"], "embedded_manifest_md5": embedded["embedded_manifest_md5"],
        "previous_test_source_commit": release.delivered.SOURCE,
        "files": {p.name: {"bytes": p.stat().st_size, "sha256": sha(p)} for p in sorted(stage.iterdir()) if p.is_file()}}
    strict = policy.verify_pck_delta((release.delivered.STAGE / "index.pck").read_bytes(), (stage / "index.pck").read_bytes(), base, manifest, release.delivered.PCK_SHA)
    write(stage / "build_manifest.json", manifest, layout)
    validate_payload(stage, cfg["source_commit"], policy.PACKAGE_SHA)
    write(layout.evidence / "grand-back-room-package-seal.json", seal, layout)
    write(layout.evidence / "art-source-import-pck-linkage.json", {"raw_files": 421, "compiled_textures": 400, "links": links}, layout)
    write(layout.evidence / "pck-diff.json", strict, layout)
    write(layout.evidence / "baseline-certificate.json", approval["baseline_certificate"], layout)
    return release.qualify_stage(stage, cfg["source_commit"], cfg["source_tree"], policy.PACKAGE_SHA, approval)


def worker(cfg, phase):
    e = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    stored = read(e / "storage-manifest.json")
    layout = Layout(**{key: Path(value) for key, value in stored["paths"].items()},
        **{key: stored[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and selected.same_path(layout.evidence, evidence(cfg, phase)) and
            selected.same_path(layout.workspace, cfg["outer"] if phase in OUTER else cfg["workspace"]) and read(e / "build-inputs.json") == cfg,
            "Exact own GBR worker admission required")
    approval = approval_for(cfg)
    if phase == "select":
        for required in ("source-identity", "tree", "baseline-tree"):
            previous(cfg, required)
        plan = selected.selection_plan((evidence(cfg, "source-identity") / "worker.log").read_bytes(), (evidence(cfg, "tree") / "worker.log").read_bytes(), cfg["source_commit"], cfg["source_tree"])
        closure = selected.prove_closure(plan, selected.BASE_STAGE, DESCRIPTOR, (evidence(cfg, "baseline-tree") / "worker.log").read_bytes())
        closure["write_budget"] = selected.write_budget(plan, layout.expected_write_bytes)
        write(e / "selection.json", plan, layout)
        write(e / "closure.json", closure, layout)
        result = {"selection_sha256": plan["selection_sha256"], "selected_files": plan["selected_files"], "source_scope": selected.SCOPE}
    elif phase == "extract":
        previous(cfg, "archive")
        previous(cfg, "select")
        require(sha(cfg["archive"]) == previous(cfg, "archive")["archive_sha256"], "Closed selected archive changed")
        plan = read(evidence(cfg, "select") / "selection.json")
        result = selected.extract_verified(cfg["archive"], plan, Path(cfg["workspace"]), layout)
        snapshot_pins(cfg, approval)
    elif phase == "seed":
        snapshot_pins(cfg, approval)
        validate_layout(layout, extra_write_paths=(layout.workspace,))
        root = Path(cfg["workspace"]) / "addons/coin_pusher_native"
        common.copy_new(cfg["native_library"], root / "bin" / common.NATIVE_NAME)
        common.copy_new(cfg["editor_native_library"], root / "bin" / common.EDITOR_NATIVE_NAME)
        common.copy_new(Path(cfg["workspace"]) / "native/coin_pusher/coin_pusher_native.gdextension.template", root / "coin_pusher_native.gdextension")
        require(sha(root / "coin_pusher_native.gdextension") == selected.DESCRIPTOR_SHA, "Canonical native descriptor differs")
        result = {"native_library_sha256": common.NATIVE_SHA, "editor_native_sha256": EDITOR_SHA}
    elif phase == "identity-scope":
        prior = previous(cfg, "identity")
        previous(cfg, "select")
        previous(cfg, "archive")
        path = Path(cfg["workspace"]) / "build_manifest.json"
        original = selected.plain(path, file=True).read_bytes()
        require(hashlib.sha256(original).hexdigest() == prior["identity_sha256"], "Own freshly generated identity changed before scope binding")
        value = json.loads(original.decode("utf-8"))
        require((value["source_commit"], value["source_tree"], value["art_package_sha256"]) ==
                (cfg["source_commit"], cfg["source_tree"], policy.PACKAGE_SHA), "Own source identity differs")
        plan = read(evidence(cfg, "select") / "selection.json")
        selected.write_budget(plan, layout.expected_write_bytes)
        previous(cfg, "extract")
        extracted = read(evidence(cfg, "extract") / "worker-result.json")
        attributes = extracted["extraction"]["attributes_policy"]
        require(attributes == {**plan["attributes_policy"], "actual_extracted_bytes_verified": True}, "Actual extracted source attribute bytes not authenticated")
        archive_sha = sha(cfg["archive"])
        require(archive_sha == previous(cfg, "archive")["archive_sha256"], "Closed selected source tar changed")
        value.update(source_archive_scope=selected.SCOPE, full_repository_archive=False,
            source_selection_sha256=plan["selection_sha256"], source_archive_sha256=archive_sha, source_attributes_policy=attributes)
        validate_layout(layout, extra_write_paths=(layout.evidence, path.parent))
        with (layout.evidence / "original-identity.json").open("xb") as handle:
            handle.write(original)
        require(sha(path) == prior["identity_sha256"], "Own identity changed before checked scope update")
        validate_layout(layout, extra_write_paths=(path.parent,))
        with path.open("w", encoding="utf-8", newline="\n") as handle:
            json.dump(value, handle, indent=2)
            handle.write("\n")
        result = {"original_identity_sha256": prior["identity_sha256"], "scoped_identity_sha256": sha(path),
            "scope": selected.SCOPE, "selection_sha256": plan["selection_sha256"], "archive_sha256": archive_sha}
    elif phase == "finalize":
        result = finalize(cfg, layout, approval)
    elif phase == "verify":
        snapshot_pins(cfg, approval)
        result = release.qualify_stage(cfg["stage"], cfg["source_commit"], cfg["source_tree"], policy.PACKAGE_SHA, approval)
    else:
        raise ValueError("Unsupported GBR file worker")
    write(e / "worker-result.json", result, layout)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", *PHASES))
    for key in ("workspace", "stage", "approval-json", "engine", "native-library", "editor-native-library", "template", "git", "git-dir", "node"):
        parser.add_argument("--" + key, type=Path, required=True)
    for key in ("source-commit", "source-tree", "run-prefix", "approval-sha256"):
        parser.add_argument("--" + key, required=True)
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        cfg = config(args)
        if args.worker:
            require(args.phase in FILES, "Only own GBR file phases may enter worker mode")
            worker(cfg, args.phase)
            return 0
        phases = PHASES if args.phase == "plan" else (args.phase,)
        layouts = {p: plan_layout(selected.ROOT, cfg["outer"] if p in OUTER else cfg["workspace"], cfg["run_prefix"] + "-" + p) for p in phases}
        for phase, layout in layouts.items():
            validate_layout(layout, extra_write_paths=write_paths(cfg, phase))
        if args.phase == "plan":
            print(json.dumps({"status": "AUTHENTICATED_GBR_PLAN_NO_EXECUTION", "phase_count": len(PHASES), "config": cfg, "commands": {p: command(cfg, p) for p in phases}, "executed": False}, indent=2))
            return 0
        phase = args.phase
        outputs = write_paths(cfg, phase)
        if phase == "source-identity":
            require(not Path(cfg["outer"]).exists() or not any(Path(cfg["outer"]).iterdir()), "Fresh absent/empty GBR outer workspace required")
        else:
            previous(cfg, PHASES[PHASES.index(phase) - 1])
        if phase == "archive":
            previous(cfg, "select")
            require(not Path(cfg["archive"]).exists(), "Never overwrite a source archive")
            selected.write_budget(read(evidence(cfg, "select") / "selection.json"), layouts[phase].expected_write_bytes)
        if phase == "extract":
            require(not Path(cfg["workspace"]).exists(), "Fresh source extraction only; no migration/overwrite")
        approval = approval_for(cfg)
        if phase in ("identity", "import", "export", "webgl-apply", "webgl-verify"):
            snapshot_pins(cfg, approval)
        layout = prepare_layout(layouts[phase])
        if phase == "archive":
            validate_layout(layout, extra_write_paths=outputs)
            Path(cfg["archive"]).parent.mkdir(parents=True, exist_ok=False)
        override = Path(cfg["workspace"]) / "override.cfg"
        write(layout.evidence / "build-inputs.json", cfg, layout)
        owned_override = False
        try:
            if phase == "import":
                require(not override.exists(), "Refuse existing import policy")
                validate_layout(layout, extra_write_paths=(Path(cfg["workspace"]),))
                with override.open("xb") as handle:
                    owned_override = True
                    handle.write(common.IMPORT_POLICY)
            if phase == "export":
                require(not override.exists() and not Path(cfg["stage"]).exists(), "Export requires absent import override and fresh stage")
                validate_layout(layout, extra_write_paths=outputs)
                Path(cfg["stage"]).mkdir(parents=True, exist_ok=False)
                template = layout.appdata / "Godot/export_templates/4.6.stable" / common.TEMPLATE_NAME
                validate_layout(layout, extra_write_paths=(template.parent,))
                common.copy_new(cfg["template"], template)
                require(sha(template) == common.TEMPLATE_SHA, "Actual redirected template differs")
            result = execute(layout, command(cfg, phase), timeout=cfg["timeout"], cpu_rate=1200, extra_write_paths=outputs)
        finally:
            if owned_override and override.exists():
                require(override.read_bytes() == common.IMPORT_POLICY, "Owned import policy changed; preserve in place")
                validate_layout(layout, extra_write_paths=(override.parent, layout.evidence))
                override.rename(layout.evidence / "owned-import-override.cfg")
        require(selected.qualified_job(result), "GBR bounded Job failed/not closed at zero; retain evidence")
        log = (layout.evidence / "worker.log").read_bytes()
        require(not ERROR_LINE.search(log.decode("utf-8", errors="replace")), "Worker/native ERROR despite exit0; retain evidence")
        if phase == "source-identity":
            require(log.decode().strip().splitlines() == [cfg["source_commit"], cfg["source_tree"]], "Actual Git identity differs")
        elif phase in ("tree", "baseline-tree"):
            selected.parse_ls_tree(log)
        names = {"worker-result.json"} if phase in FILES else set()
        if phase == "select":
            names |= {"selection.json", "closure.json"}
        if phase == "identity-scope":
            names.add("original-identity.json")
        if phase == "finalize":
            names |= {"grand-back-room-package-seal.json", "art-source-import-pck-linkage.json", "pck-diff.json", "baseline-certificate.json"}
        receipt = {"schema": SCHEMA, "phase": phase, "phase_count": len(PHASES), "status": "PASS", "config_sha256": selected.digest(cfg),
            "job_receipt": str(layout.evidence / "job.json"), "job_sha256": sha(layout.evidence / "job.json"), "log_sha256": sha(layout.evidence / "worker.log"),
            "artifact_sha256": {name: sha(layout.evidence / name) for name in names}, "published": False,
            "source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"], "baseline_certificate_sha256": cfg["baseline_certificate_sha256"]}
        if phase == "archive":
            receipt["archive_sha256"] = sha(cfg["archive"])
        if phase == "identity":
            receipt["identity_sha256"] = sha(Path(cfg["workspace"]) / "build_manifest.json")
        write(layout.evidence / "phase-result.json", receipt, layout)
        print(json.dumps(receipt, indent=2))
        return 0
    except StorageGuardError as error:
        print(json.dumps({"status": "GBR_STORAGE_REJECTED", **error.as_dict(), "fallback_attempted": False}), file=sys.stderr)
        return 2
    except Exception as error:
        print(json.dumps({"status": "GBR_BUILD_STOPPED", "phase": args.phase, "error_type": type(error).__name__, "error": str(error),
            "fallback_attempted": False, "published": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
