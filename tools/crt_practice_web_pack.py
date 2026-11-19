#!/usr/bin/env python3
"""Build one fresh private CRT QA composite; never publish or replace a build.

Run directly with --workspace <approved E: checkout> --run-id <fresh ID>.
The caller separately proves that native/addons/project/export inputs remain
unchanged from the baseline below. --caller-proof may name that retained receipt.
"""
from __future__ import annotations

import sys
sys.dont_write_bytecode = True

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import shutil

import audit_pck_manifest
from bth_qa_guarded_run import execute
from bth_qa_storage import StorageGuardError, plan_layout, prepare_layout, validate_layout

BASE_COMMIT = "89403f389a5807e050a450cd27b1bd93b3a4a41e"
BASE_TREE = "1723e2f077f1c8dadbf0dbd8f740aa0ca3db33f4"
BASE_ROOT = Path(r"D:\Projects\site\projects\beat-the-house\public\play\dev") / BASE_COMMIT
GODOT = Path(r"D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe")
GODOT_SHA = "fc759f9d296fe54f09ab66d41df6ddd2d278493b0e71109f6688ef029ad271ae"
TEMPLATE_NAME = "web_dlink_nothreads_release.zip"
TEMPLATE = Path(r"D:\Projects\site\state\bth-next\appdata\Godot\export_templates\4.6.stable") / TEMPLATE_NAME
TEMPLATE_SHA = "cf371f607aa9cb18e690bd595976c1baaf00c8cec24078e4a307fd515ad07913"
NATIVE_NAME = "coin_pusher_native_v3_10.web.template_release.wasm32.nothreads.wasm"
NATIVE_SHA = "080d40035a0b3656c0f06162f1434c03f71f7f49370752bda8af624fee94d922"
RUNTIME_FILES = (
    "index.html", "index.js", "index.wasm", "index.side.wasm", NATIVE_NAME,
    "index.audio.position.worklet.js", "index.audio.worklet.js",
    "index.apple-touch-icon.png", "index.icon.png", "index.png",
)
REQUIRED_RESOURCES = ("scripts/ui/crt_practice_menu.gd",
                      "scripts/ui/crt_practice_screen.gdshader",
                      "scripts/core/home_practice_console.gd")
CALLER_PROOF_SCOPE = ("native/", "addons/", "project.godot", "export_presets.cfg")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def pin(path: Path, expected: str) -> None:
    if not path.is_file() or sha256(path) != expected:
        raise ValueError(f"Pinned QA input is missing or changed: {path}")


def write_json(path: Path, value: dict) -> None:
    with path.open("x", encoding="utf-8") as target:
        json.dump(value, target, indent=2)
        target.write("\n")


def build(args) -> dict:
    # The maintained guard performs all path/capacity checks before any mkdir,
    # copy, receipt write or child creation. There is no C: fallback.
    layout = plan_layout(root=r"E:\CodexQA\BTH", workspace=args.workspace, run_id=args.run_id)
    output = layout.workspace / "builds" / args.output_name
    addon = layout.workspace / "addons" / "coin_pusher_native"
    native_destination = addon / "bin" / NATIVE_NAME
    extension = addon / "coin_pusher_native.gdextension"
    extension_source = layout.workspace / "native" / "coin_pusher" / "coin_pusher_native.gdextension.template"
    template_destination = layout.appdata / "Godot" / "export_templates" / "4.6.stable" / TEMPLATE_NAME
    outputs = (output, addon, template_destination.parent)
    capacity = validate_layout(layout, extra_write_paths=outputs)
    if output.exists():
        raise ValueError(f"Private output already exists; retain it and choose a fresh --output-name: {output}")
    pin(GODOT, GODOT_SHA)
    pin(TEMPLATE, TEMPLATE_SHA)
    pin(BASE_ROOT / NATIVE_NAME, NATIVE_SHA)
    baseline = json.loads((BASE_ROOT / "BUILD.json").read_text(encoding="utf-8-sig"))
    if baseline.get("source_commit") != BASE_COMMIT or baseline.get("source_tree") != BASE_TREE:
        raise ValueError("Baseline served BUILD.json differs from the exact approved SHA/tree.")
    for leaf in RUNTIME_FILES:
        if not (BASE_ROOT / leaf).is_file():
            raise ValueError(f"Baseline runtime input is absent: {leaf}")
    if not extension_source.is_file():
        raise ValueError("Candidate native extension descriptor template is absent.")
    if native_destination.exists():
        pin(native_destination, NATIVE_SHA)
    if extension.exists() and extension.read_text(encoding="utf-8").replace("\r\n", "\n") != extension_source.read_text(encoding="utf-8").replace("\r\n", "\n"):
        raise ValueError("Existing candidate extension differs; refusing to overwrite it.")
    for resource in REQUIRED_RESOURCES:
        if not (layout.workspace / resource).is_file():
            raise ValueError(f"CRT candidate source is absent: {resource}")
    layout = prepare_layout(layout)
    validate_layout(layout, extra_write_paths=outputs)
    output.mkdir(parents=True, exist_ok=False)
    for leaf in RUNTIME_FILES:
        shutil.copyfile(BASE_ROOT / leaf, output / leaf)
    native_destination.parent.mkdir(parents=True, exist_ok=True)
    if not native_destination.exists():
        shutil.copyfile(BASE_ROOT / NATIVE_NAME, native_destination)
    if not extension.exists():
        shutil.copyfile(extension_source, extension)
    template_destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(TEMPLATE, template_destination)
    pin(native_destination, NATIVE_SHA)
    pin(template_destination, TEMPLATE_SHA)
    candidate_sources = REQUIRED_RESOURCES + ("scripts/ui/foundation_main.gd",)
    inputs = {
        "schema": "bth.crt_private_web_inputs/v1", "baseline": baseline,
        "baseline_native_sha256": NATIVE_SHA, "godot_console_sha256": GODOT_SHA,
        "locked_template_sha256": TEMPLATE_SHA,
        "caller_proof_scope": {"baseline_commit": BASE_COMMIT, "paths": CALLER_PROOF_SCOPE,
                               "receipt": args.caller_proof,
                               "independently_checked_by_adapter": False,
                               "requirement": "Caller retains unchanged-input Git comparison; this adapter does not execute Git or alter trust."},
        "candidate_source_sha256": {resource: sha256(layout.workspace / resource) for resource in candidate_sources},
        "copied_runtime_sha256": {leaf: sha256(output / leaf) for leaf in RUNTIME_FILES},
        "storage_manifest": str(layout.manifest_path), "capacity_before_preparation": capacity,
        "scope": "Disposable private composite QA only: fresh candidate PCK with exact recorded baseline runtime inputs. No production source/deployment identity claim.",
    }
    write_json(layout.evidence / "private-web-inputs.json", inputs)
    package = output / "index.pck"
    command = [str(GODOT), "--headless", "--path", str(layout.workspace),
               "--export-pack", "Web", str(package)]
    # execute rechecks check_launch immediately before its suspended child is
    # created, and preserves assignment-before-resume, 12% CPU and 2 GiB caps.
    worker = execute(layout, command, timeout=240, extra_write_paths=outputs)
    okay = (worker.get("exit_code") == 0 and worker.get("active_at_release") == 0
            and not worker.get("error") and not worker.get("cleanup_errors")
            and not worker.get("timed_out") and not worker.get("log_error"))
    log = (layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")
    error_lines = [line[:600] for line in log.splitlines()
                   if re.search(r"^(?:SCRIPT ERROR:|ERROR:)|Export failed|Failed to load script|Parse Error:", line, re.IGNORECASE)]
    if not okay or error_lines or not package.is_file():
        raise RuntimeError(f"Private pack export is unqualified; owned worker receipt retained at {layout.evidence / 'job.json'}; errors={error_lines[:8]}")
    for leaf, expected in inputs["copied_runtime_sha256"].items():
        pin(output / leaf, expected)
    data = package.read_bytes()
    directory = audit_pck_manifest.find_directory(data)
    failures = audit_pck_manifest.audit(directory["entries"])
    names = {entry["path"] for entry in directory["entries"]}
    required = {resource: sorted(names.intersection((resource, resource + ".remap"))) for resource in REQUIRED_RESOURCES}
    for resource, entries in required.items():
        if not entries:
            failures.append(f"CRT resource/remap missing from candidate PCK: {resource}")
    audit = {"schema": "bth.crt_private_pck_audit/v1", "package_bytes": len(data),
             "package_sha256": hashlib.sha256(data).hexdigest(), "file_count": directory["file_count"],
             "required_resources": required, "failures": failures, "passed": not failures,
             "files": directory["entries"]}
    write_json(layout.evidence / "private-pck-audit.json", audit)
    if failures:
        raise RuntimeError("Private PCK audit rejected: " + " | ".join(failures[:8]))
    html_path = output / "index.html"
    html = html_path.read_text(encoding="utf-8")
    config_pattern = re.compile(r"(?m)^(const GODOT_CONFIG = )(\{[^\r\n]+\})(;)$")
    matches = list(config_pattern.finditer(html))
    if len(matches) != 1:
        raise ValueError("Expected exactly one unchanged baseline GODOT_CONFIG JSON statement.")
    config = json.loads(matches[0].group(2))
    if config.get("fileSizes", {}).get("index.pck") != (BASE_ROOT / "index.pck").stat().st_size:
        raise ValueError("Baseline HTML's original PCK length differs from its recorded payload.")
    size_pattern = re.compile(r'("index\.pck"\s*:\s*)[0-9]+')
    if len(size_pattern.findall(matches[0].group(2))) != 1:
        raise ValueError("Expected one index.pck file-size entry in GODOT_CONFIG.")
    new_config = size_pattern.sub(lambda match: match.group(1) + str(len(data)), matches[0].group(2), count=1)
    replacement = matches[0].group(1) + new_config + matches[0].group(3)
    html_path.write_text(html[:matches[0].start()] + replacement + html[matches[0].end():], encoding="utf-8", newline="\n")
    receipt = {"schema": "bth.crt_private_web_composite/v1", "passed": True,
               "created_at": dt.datetime.now(dt.timezone.utc).isoformat(), "output": str(output),
               "baseline_runtime_commit": BASE_COMMIT, "baseline_runtime_tree": BASE_TREE,
               "candidate_pck_sha256": audit["package_sha256"], "candidate_pck_bytes": len(data),
               "html_sha256": sha256(html_path), "native_sha256": NATIVE_SHA,
               "required_resources": required, "inputs_receipt": str(layout.evidence / "private-web-inputs.json"),
               "pck_audit": str(layout.evidence / "private-pck-audit.json"),
               "worker_receipt": str(layout.evidence / "job.json"), "active_at_release": 0,
               "scope": inputs["scope"]}
    write_json(layout.evidence / "private-web-composite.json", receipt)
    write_json(output / "PRIVATE_QA_COMPOSITE.json", receipt)
    return receipt


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--output-name", default="crt-private", help="Fresh builds/ leaf; old output is always retained")
    parser.add_argument("--caller-proof", help="Retained caller receipt for the separately verified unchanged native/project/export inputs")
    args = parser.parse_args(argv)
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", args.output_name):
        parser.error("--output-name must be a plain fresh directory leaf")
    try:
        print(json.dumps(build(args)))
        return 0
    except StorageGuardError as error:
        print(json.dumps({"status": "PRIVATE_QA_STORAGE_REJECTED", **error.as_dict()}), file=sys.stderr)
        return 2
    except (OSError, ValueError, RuntimeError) as error:
        print(json.dumps({"status": "PRIVATE_QA_UNQUALIFIED", "error": str(error)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
