"""Run preserved Bar observers sequentially in fresh guarded E: evidence.

No helper is rewritten. A phase PASS is machine/native evidence, never art or
TEST approval. Capture preserves real frame clocks and does not encode video.
Use ``plan`` to inspect commands, then ``run`` with explicit remaining phases.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile

from bth_qa_storage import plan_layout, prepare_layout, validate_layout
from bth_qa_guarded_run import execute


ENGINE_SHA = "fc759f9d296fe54f09ab66d41df6ddd2d278493b0e71109f6688ef029ad271ae"
ENGINE_RUNTIME_SHA = "63913d01be2c2d1f929b4a626f5347117126b34e9c64cbf350ea9f35a9657ebf"
ARCHIVE_SHA = "f63ad0a587d329290b0edfe66fcc2d7f8f9915318df8fa9473ac06685adfca5d"
SCENARIOS = ("bar_wake", "bar_fight_night", "bar_payday_rush", "bar_lock_in",
             "bar_darts_league_night", "bar_live_band", "bar_dead_tuesday")
SEQUENCE_PHASES = tuple("sequence-" + name for name in SCENARIOS)
SCRIPTS = {
    "settled": ("tools/envart_bar_settled_r4.gd", "bar_r4_settled_metadata.json", 600),
    "motion": ("tools/envart_bar_animation_probe_r4.gd", "bar_animation_probe.json", 180),
    "composite": ("tools/envart_bar_full_composite_r4.gd", "bar_full_composite.json", 1200),
    "composite-rm": ("tools/envart_bar_full_composite_rm_r4.gd", "bar_full_composite_rm.json", 600),
    "floor-wrap": ("tools/envart_bar_floor_wrap_r4.gd", "floor_wrap_probe.json", 180),
    "smoke-wrap": ("tools/envart_bar_smoke_wrap_r4.gd", "bar_smoke_wrap.json", 180),
    "glint-masks": ("tools/envart_bar_glint_masks_r4.gd", "bar_glint_source_paint.json", 300),
    "counter-replay": ("tools/envart_bar_counter_replay_r4.gd", "bar_counter_replay.json", 180),
    "placement-closing": ("tools/envart_bar_placement_closing_r4.gd", "bar_placement_closing.json", 300),
    "liveness": ("scripts/tests/animation_liveness_without_pointer_check.gd", None, 180),
    "capture": ("tools/envart_bar_animation_capture_r4.gd", "capture/animation_capture.json", 600),
}
PHASES = ("import", "settled", *SEQUENCE_PHASES, *tuple(SCRIPTS)[1:])
HISTORICAL = {
    "settled": ("E:/CodexQA/BTH/runs/BTH-ENVART-BAR-20261114-preart-capture-01/evidence/bar_preart_metadata.json",
                "0893a4c95147ab0898093d01ef389abeaf95d9d41656a045dd2072ae0da87822"),
    "glint-masks": ("E:/CodexQA/BTH/runs/BTH-ENVART-BARTRIAL-20261114-r4-full-composite-01/evidence/bar_full_composite.json",
                    "8831b1a3fb2a8aea9013cb576b370d3147c5b0f66a1ea3214bd53c61083b328d"),
}
ERROR_LINE = re.compile(r"(?:SCRIPT ERROR|(?<![A-Z])ERROR):")


def sha(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write_new(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def case_id(row):
    return row["scenario_id"] + "__" + row["kind"] + "_" + row.get("outcome", row.get("phase", ""))


def identity(args):
    workspace, source = args.workspace.resolve(strict=True), args.source_root.resolve(strict=True)
    if workspace == source or sha(workspace / "assets/art/environments/bar/background.png") != args.candidate_sha256:
        raise ValueError("An isolated QA source with the exact candidate background is required")
    if not (workspace / "qa_baseline/.gdignore").is_file() or not (workspace / "candidate_sources/.gdignore").is_file():
        raise ValueError("Both archived reference and non-active candidate folders must be excluded from discovery")
    if sha(args.engine) != ENGINE_SHA:
        raise ValueError("Pinned Godot console identity mismatch")
    companion = args.engine.with_name("Godot_v4.6-stable_win64.exe")
    if sha(companion) != ENGINE_RUNTIME_SHA:
        raise ValueError("Pinned adjacent Godot runtime identity mismatch")
    archive = source / "review_artifacts/environment_art_sources/bar-v1-r4/bar-v1-r4-qa-source.zip"
    if sha(archive) != ARCHIVE_SHA:
        raise ValueError("Preserved Bar QA archive identity mismatch")
    helpers = {}
    with zipfile.ZipFile(archive) as frozen:
        pending = {spec[0] for spec in SCRIPTS.values() if spec[0].startswith("tools/")}
        pending.add("tools/envart_bar_sequence_proof_r4.gd")
        pending.add("tools/envart_bar_sequence_cases.json")
        while pending:
            name = pending.pop()
            if name in helpers:
                continue
            data = frozen.read(name)
            if (workspace / name).read_bytes() != data:
                raise ValueError("Archived observer differs: " + name)
            helpers[name] = hashlib.sha256(data).hexdigest()
            if name.endswith(".gd"):
                pending.update(re.findall(r'res://(tools/[^"\s]+\.(?:gd|json))', data.decode("utf-8-sig")))
        baseline = frozen.read("baseline/pixel_scene_canvas.182ae255.gd")
        if (workspace / "qa_baseline/pixel_scene_canvas.182ae255.gd").read_bytes() != baseline:
            raise ValueError("Exact preserved reference canvas differs")
    catalog = read_json(workspace / "tools/envart_bar_sequence_cases.json")
    if (catalog["scenario_ids"] != list(SCENARIOS) or len(catalog["cases"]) != 58 or
            len({case_id(row) for row in catalog["cases"]}) != 58 or
            sha(workspace / catalog["source"]) != catalog["source_sha256"]):
        raise ValueError("Exact unique58-case/source-derived Bar catalog differs")
    # Production code/data and active Bar textures stay immutable during a suite.
    files = {}
    for directory in ("scripts", "scenes", "data", "assets/art/environments/bar"):
        for path in sorted((workspace / directory).rglob("*")):
            if path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                raise ValueError("Linked QA source input is forbidden: " + str(path))
            if path.is_file():
                files[path.relative_to(workspace).as_posix()] = sha(path)
    files["project.godot"] = sha(workspace / "project.godot")
    result = {"workspace": str(workspace), "candidate_sha256": args.candidate_sha256,
              "engine": str(args.engine), "engine_sha256": ENGINE_SHA,
              "engine_runtime_sha256": ENGINE_RUNTIME_SHA, "archive_sha256": ARCHIVE_SHA,
              "baseline_sha256": hashlib.sha256(baseline).hexdigest(), "helpers": helpers,
              "production_source_sha256": files}
    result["identity_sha256"] = hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return result, catalog


def phase_command(args, phase, layout):
    command = [str(args.engine)]
    if phase in ("import", "liveness"):
        command += ["--headless"]
    command += ["--path", str(args.workspace)]
    if phase == "import":
        return command + ["--editor", "--import"], 300
    if phase in SEQUENCE_PHASES:
        script, timeout = "tools/envart_bar_sequence_proof_r4.gd", 1200
    else:
        script, _, timeout = SCRIPTS[phase]
    if phase != "liveness":
        command += ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                    "--resolution", "1280x720", "--position", args.position]
    command += ["--script", "res://" + script]
    if phase in SEQUENCE_PHASES:
        command += ["--", "--out=" + str(layout.evidence),
                    "--baseline-source=" + str(args.workspace / "qa_baseline/pixel_scene_canvas.182ae255.gd"),
                    "--bar-scenario=" + phase.removeprefix("sequence-")]
    elif phase in ("motion", "floor-wrap"):
        command += ["--", "--out=" + str(layout.evidence)]
    elif phase == "capture":
        command += ["--", "--out=" + str(layout.evidence / "capture"),
                    "--scenario=" + args.capture_scenario, "--excerpt-seconds=" + str(args.capture_seconds)]
    return command, timeout


def validate_result(phase, evidence, catalog, animation_ids, args):
    if phase == "import":
        return {"scope": "Error-free editor import only"}
    if phase == "liveness":
        if "Animation liveness without pointer input: PASS" not in (evidence / "worker.log").read_text(encoding="utf-8"):
            raise ValueError("Mandatory no-pointer liveness PASS marker absent")
        return {"no_pointer_liveness": True}
    name = "bar_sequence_live_proof.json" if phase in SEQUENCE_PHASES else SCRIPTS[phase][1]
    result = read_json(evidence / name)
    if result.get("findings") or result.get("failures") or result.get("ok") is False:
        raise ValueError("Native report records a failure: " + phase)
    summary = {"report": str(evidence / name), "sha256": sha(evidence / name),
               "checks": result.get("checks"), "findings": [], "failures": []}
    if phase in SEQUENCE_PHASES:
        scenario = phase.removeprefix("sequence-")
        expected = {case_id(row) for row in catalog["cases"] if row["scenario_id"] == scenario}
        completed = result.get("completed", [])
        scope = result.get("batch_scope", {})
        if (len(completed) != len(expected) or set(completed) != expected or
                set(scope.get("selected_case_ids", [])) != expected or scope.get("full_catalog_count") != 58 or
                scope.get("explicitly_skipped_case_ids") or
                any(not result.get("views", {}).get(name, {}).get("case_passed") for name in expected)):
            raise ValueError("Exact scenario case coverage/receipts failed: " + scenario)
        summary["completed_case_ids"] = sorted(expected)
    elif phase == "settled":
        if set(result.get("views", {})) != {"__none", *SCENARIOS}:
            raise ValueError("All8 initial populated contexts were not captured")
    elif phase == "motion":
        if [row.get("id") for row in result.get("entries", [])] != animation_ids:
            raise ValueError("All17 exact motion entries were not checked")
    elif phase in ("composite", "composite-rm"):
        rows = result.get("scenarios", [])
        expected = {"__none", *SCENARIOS} if phase == "composite" else {"__none"}
        if ({row.get("scenario") for row in rows} != expected or
                any([entry.get("id") for entry in row.get("entries", [])] != animation_ids for row in rows)):
            raise ValueError("Exact full-composite context/17-entry coverage failed")
    elif phase == "floor-wrap" and len(result.get("glints", [])) != 7:
        raise ValueError("All7 floor movers were not checked")
    elif phase == "capture":
        frames = result.get("frames", [])
        clocks = [row.get("clock") for row in frames]
        if (not result.get("pack_active") or result.get("scenario") != args.capture_scenario or
                [row.get("id") for row in result.get("animation_inventory", [])] != animation_ids or
                any([state.get("id") for state in row.get("animation_states", [])] != animation_ids for row in frames) or
                len(frames) < 2 or not all(isinstance(clock, (int, float)) and math.isfinite(clock) for clock in clocks) or
                any(b <= a for a, b in zip(clocks, clocks[1:])) or
                not math.isclose(result.get("actual_clock_span", -1), clocks[-1] - clocks[0], abs_tol=1e-5) or
                not 0 < result.get("capture_seconds_requested", 0) <= 20 or
                not result.get("reduce_motion", {}).get("active") or
                not result.get("reduce_motion", {}).get("production_art_texture_pixels_stable")):
            raise ValueError("Authentic capture clocks/active pack/Reduce Motion failed")
        for row in frames:
            for key in ("file", "board900_file", "board2x_file"):
                rel = PurePosixPath(row[key])
                if rel.is_absolute() or ".." in rel.parts or "\\" in row[key] or not (evidence / "capture" / rel).is_file():
                    raise ValueError("Capture frame path is unsafe or missing")
        summary.update({"frames": len(frames), "actual_clock_span": result["actual_clock_span"],
                        "cycle_capped": result.get("cycle_capped"), "encoding": "None; use actual clocks for VFR playback"})
    return summary


def qualified_job(job):
    return (job.get("exit_code") == 0 and job.get("active_at_release") == 0 and
            job.get("assigned_before_execution") and not any(job.get(key) for key in
                ("error", "cleanup_errors", "timed_out", "log_error", "log_truncated")) and
            "storage_gate_before_job" in job and "storage_gate_before_child" in job and
            job.get("limits", {}).get("cpu_rate") == 1200 and
            job.get("limits", {}).get("job_memory_limit_bytes") == 2 * 1024 ** 3)


def sequence_coverage(args, current_identity, catalog):
    completed, reports = [], []
    for phase in SEQUENCE_PHASES:
        evidence = args.qa_root / "runs" / (args.run_prefix + "-" + phase) / "evidence"
        if not (evidence / "phase-result.json").is_file():
            return {"complete": False, "reason": "Remaining sequence phases have not passed"}
        receipt, job = read_json(evidence / "phase-result.json"), read_json(evidence / "job.json")
        if (receipt.get("status") != "PASS" or receipt.get("identity_sha256") != current_identity or
                not qualified_job(job) or ERROR_LINE.search((evidence / "worker.log").read_text(encoding="utf-8"))):
            raise ValueError("Prior sequence phase is not exact/qualified: " + phase)
        checked = validate_result(phase, evidence, catalog, [], args)
        completed.extend(checked["completed_case_ids"])
        reports.append(checked)
    expected = {case_id(row) for row in catalog["cases"]}
    if len(completed) != 58 or set(completed) != expected:
        raise ValueError("Combined sequence proof does not cover exactly58 unique cases")
    return {"complete": True, "unique_cases": 58, "completed_case_ids": sorted(completed), "reports": reports}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("plan", "run"))
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--run-prefix", required=True)
    parser.add_argument("--candidate-sha256", required=True)
    parser.add_argument("--phases", nargs="+", choices=("all", *PHASES), required=True)
    parser.add_argument("--qa-root", type=Path, default=Path("E:/CodexQA/BTH"))
    parser.add_argument("--position", default="-32000,-32000")
    parser.add_argument("--capture-scenario", choices=("__none", *SCENARIOS), default="bar_fight_night")
    parser.add_argument("--capture-seconds", type=float, default=12.0)
    parser.add_argument("--timeout", type=int, help="Explicit per-phase override,1..1200 seconds")
    args = parser.parse_args(argv)
    try:
        if not re.fullmatch(r"[0-9a-f]{64}", args.candidate_sha256) or not 0 < args.capture_seconds <= 20:
            raise ValueError("Exact lowercase candidateSHA256 and0<capture<=20 required")
        if args.timeout is not None and not 1 <= args.timeout <= 1200:
            raise ValueError("Timeout must be1..1200")
        phases = PHASES if args.phases == ["all"] else tuple(args.phases)
        if "all" in phases or len(set(phases)) != len(phases):
            raise ValueError("Choose all alone, or explicit unique remaining phases")
        # Every output layout is admitted before the first write/child. These
        # calls reject occupied runs and insufficient E capacity, with no fallback.
        layouts = {phase: plan_layout(root=args.qa_root, workspace=args.workspace,
                    run_id=args.run_prefix + "-" + phase) for phase in phases}
        inputs, catalog = identity(args)
        animation_ids = [row["id"] for row in read_json(args.workspace / "data/art/environments/bar.json")["animations"]]
        if len(animation_ids) != 17:
            raise ValueError("Exact17-entry Bar pack required")
        plans = []
        for phase, layout in layouts.items():
            command, timeout = phase_command(args, phase, layout)
            historical = HISTORICAL.get(phase)
            if historical and sha(historical[0]) != historical[1]:
                raise ValueError("Historical observer input identity differs: " + historical[0])
            plans.append({"phase": phase, "command": command, "timeout": args.timeout or timeout,
                          "historical_input": historical, "storage": layout.as_dict()})
        if args.action == "plan":
            planned_identity = {key: value for key, value in inputs.items() if key != "production_source_sha256"}
            planned_identity["production_source_file_count"] = len(inputs["production_source_sha256"])
            print(json.dumps({"status": "READ_ONLY_NATIVE_PLAN", "identity": planned_identity, "phases": plans,
                "resource_caps": {"cpu_rate": 1200, "memory_bytes": 2 * 1024 ** 3},
                "art_approval": False, "published": False}, indent=2))
            return 0
        for plan in plans:
            phase, layout = plan["phase"], layouts[plan["phase"]]
            if identity(args)[0] != inputs:
                raise ValueError("QA source identity changed before phase: " + phase)
            layout = prepare_layout(layout)
            outputs = (layout.evidence / "capture",) if phase == "capture" else ()
            validate_layout(layout, extra_write_paths=outputs)
            write_new(layout.evidence / "suite-inputs.json", {"identity": inputs,
                "adapter_sha256": sha(__file__), "phase": phase, "command": plan["command"],
                "historical_input": plan["historical_input"], "position": args.position,
                "capture_scenario": args.capture_scenario, "capture_seconds": args.capture_seconds})
            print(json.dumps({"status": "STARTING", "phase": phase, "run_id": layout.run_id}), flush=True)
            job = execute(layout, plan["command"], timeout=plan["timeout"], cpu_rate=1200,
                          extra_write_paths=outputs)
            errors = [line for line in (layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace").splitlines()
                      if ERROR_LINE.search(line)]
            if not qualified_job(job) or errors:
                write_new(layout.evidence / "phase-failure.json", {"phase": phase,
                    "status": "FAILED", "job_receipt": str(layout.evidence / "job.json"), "logged_errors": errors})
                raise ValueError("Guarded job or native log failed; retained evidence: " + str(layout.evidence))
            if identity(args)[0] != inputs:
                raise ValueError("QA source identity changed during phase: " + phase)
            result = validate_result(phase, layout.evidence, catalog, animation_ids, args)
            receipt = {"schema": "bth.bar_spatial_native_phase/v1", "phase": phase, "status": "PASS",
                "observed_at": datetime.now(timezone.utc).isoformat(), "identity_sha256": inputs["identity_sha256"],
                "candidate_sha256": args.candidate_sha256, "job_receipt": str(layout.evidence / "job.json"),
                "result": result, "art_approval": False, "published": False}
            validate_layout(layout)
            write_new(layout.evidence / "phase-result.json", receipt)
            if phase in SEQUENCE_PHASES:
                coverage = sequence_coverage(args, inputs["identity_sha256"], catalog)
                write_new(layout.evidence / "sequence-coverage.json", coverage)
                receipt["sequence_coverage_complete"] = coverage["complete"]
            print(json.dumps(receipt), flush=True)
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "NATIVE_SUITE_STOPPED", "error": str(error),
            "art_approval": False, "published": False, "fallback_attempted": False}), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
