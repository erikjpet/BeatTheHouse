"""Guarded lossless first75-frame excerpt of a future closed HL v4 capture.

Authenticates the entire selected-source/native cohort and full PNG ledger.
Only the pure055 encoder and ef06 independent75-frame recomposer are borrowed;
no Grand capture validator or imported global mutation is used. All full-app,
native1800 and diagnostic900 originals remain immutable. Output is explicitly
an excerpt of the native900 diagnostic clone, not the complete20-second capture.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import json
import math
import os
from pathlib import Path
import re
import struct
from types import SimpleNamespace
import zipfile
import zlib

import high_limit_spatial_native_trial_v4 as native
import encode_bar_spatial_apng as codec
from encode_grand_spatial_apng_excerpt import verify_apng
from bth_qa_storage import Layout, plan_layout, prepare_layout, validate_layout
from bth_qa_guarded_run import execute

ROOT = Path("E:/CodexQA/BTH")
WORKSPACE = ROOT / "workspaces/BTH-ENV-SPATIAL-HL-APNG-20261116"
SCHEMA = "bth.high_limit_spatial_apng_phase/v1"
RUNNER_SHA = "e1fe5dc3168a23f07aad03c0c6270e1915c1714182769d70ce2496ad1576c72d"
SELECTED_SOURCE_SHA = "051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625"
POLICY_SHA = "db7e8944a7d4e7ede36b24f9cfd4f5ee2b844e17cd92551b12b89ee2da9a3d6b"
CODEC_SHA = "055cb411dd3cc10b36ce9001658d9f4cb5369f4c7e4ae7e31fe86ac921e72329"
VERIFY_SHA = "ef06a9712aff39cde655679c68f0fcf19a2fd972754150c1ed28f1c06c3119cc"
GRAND_IMPORT_SHA = "9f6c9a51ab5cfdd382e94943feda11b3f1dbe79b878ee68abc71d21df787305a"
PACKAGE_SHA = "481e858ee3c484b06ba6df935983c29979a188e7e59ff5f44eaf22ecdbe020e4"
ROOM, SIZE, FRAME_COUNT, DENOMINATOR, LAST_TICKS = "grand_casino_high_limit", (900, 430), 75, 10000, 200
MAX_BYTES = 10 * 1024 ** 2
HELPERS = {
    "tools/envart_highlimit_preart_metadata.gd": "b6a43a9b9a62e447c06c544c1c2eef49039226350bd0da7af0455036070f769f",
    "tools/envart_highlimit_animation_probe.gd": "b5d1ee7d9a9598545e8b0c50fa98901cf1c24b7f955f0ac5a47ecd048254e30b",
    "tools/envart_highlimit_animation_capture.gd": "7770ec597d1909281d6707804d6cc7b4b4434d15cb8dab0107ec1e4a5f98b9df",
    "tools/environment_art_baseline_capture.gd": "89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
    "tools/environment_layout_screenshots.gd": "eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5",
}
CONTROLS = {"settled_play.png": (1280, 720), "settled_board900.png": SIZE,
    "reduce_motion_play.png": (1280, 720), "reduce_motion_board2x.png": (1800, 860), "reduce_motion_play_after.png": (1280, 720)}
require, sha, read_json = native.policy.require, native.guard.sha, native.guard.read_json
same_path, plain = native.selected.same_path, native.selected.plain


def numeric(value):
    return type(value) in (int, float) and math.isfinite(value)


def clock_delays(clocks):
    require(len(clocks) == FRAME_COUNT and all(numeric(value) for value in clocks), "Exactly75 finite original clocks required")
    values = [Decimal(str(value)) for value in clocks]
    intervals = [b - a for a, b in zip(values, values[1:])]
    require(all(value > 0 for value in intervals), "Recorded clocks must strictly increase")
    ticks = [int((value * DENOMINATOR).quantize(Decimal(1), rounding=ROUND_HALF_UP)) for value in intervals] + [LAST_TICKS]
    require(all(0 < value < 65536 for value in ticks), "Clock interval does not fit a positive n/10000 APNG delay")
    elapsed, errors = Decimal(0), []
    for index, value in enumerate(values):
        errors.append(abs(elapsed - (value - values[0])))
        elapsed += Decimal(ticks[index]) / DENOMINATOR
    span = values[-1] - values[0]
    require(max(errors) <= Decimal("0.05") and abs(elapsed - span - Decimal("0.02")) <= Decimal("0.05"), "APNG rounding drift exceeds50ms")
    return ticks, {"first_source_clock": str(values[0]), "last_source_clock": str(values[-1]), "actual_source_clock_span_seconds": str(span),
        "encoded_presentation_duration_seconds": str(elapsed), "maximum_frame_clock_error_seconds": str(max(errors)),
        "delay_numerators": ticks, "delay_denominator": DENOMINATOR, "terminal_presentation_ticks": LAST_TICKS,
        "terminal_presentation_seconds": "0.02", "terminal_policy": "One20ms container display tick for the final recorded frame; no additional source frame",
        "frame_rate_invented": False, "loop_boundary": "Infinite playback returns to the authentic first excerpt frame"}


def png_header(path):
    with plain(path, file=True).open("rb") as handle:
        data = handle.read(24)
    require(len(data) == 24 and data[:8] == codec.SIGNATURE and data[8:16] == b"\0\0\0\rIHDR", "Invalid original PNG header")
    return struct.unpack(">II", data[16:24])


def module_pins():
    pins = {"high_limit_spatial_native_trial_v4.py": RUNNER_SHA, "high_limit_spatial_native_profile_v2.py": POLICY_SHA,
        "bth_qa_selected_source_v2.py": SELECTED_SOURCE_SHA,
        "encode_bar_spatial_apng.py": CODEC_SHA, "encode_grand_spatial_apng_excerpt.py": VERIFY_SHA,
        "encode_grand_spatial_apng.py": GRAND_IMPORT_SHA}
    for name, expected in pins.items():
        require(sha(plain(Path(__file__).with_name(name), file=True)) == expected, "Frozen source changed: " + name)
    require(codec.SIZE == SIZE and codec.DENOMINATOR == DENOMINATOR and codec.LAST_TICKS == LAST_TICKS and
        Path(verify_apng.__code__.co_filename).resolve() == Path(__file__).with_name("encode_grand_spatial_apng_excerpt.py").resolve(),
        "Pure lossless encoder/recomposer contract differs")
    return pins


def capture_inputs(args, *, decode_payloads=False):
    pins = module_pins()
    native.selected.full_hash(args.source_commit)
    native.selected.full_hash(args.capture_json_sha256, 64)
    path = plain(args.capture_json, file=True)
    require(path.name == "animation_capture.json" and path.parent.name == "capture" and path.parent.parent.name == "evidence" and
        path.is_relative_to(ROOT / "runs") and sha(path) == args.capture_json_sha256, "Exact future admitted HL capture JSON/SHA required")
    evidence, capture_root = path.parent.parent, path.parent
    inputs = read_json(evidence / "trial-inputs.json")
    cfg = inputs["source_config"]
    native.selected.full_hash(cfg.get("source_tree"))
    require(cfg.get("schema") == "bth.high_limit_spatial_inputs/v1" and cfg.get("adapter_sha256") == RUNNER_SHA and
        cfg.get("dependencies", {}).get("high_limit_spatial_native_profile_v2.py") == POLICY_SHA and
        cfg.get("dependencies", {}).get("bth_qa_selected_source_v2.py") == SELECTED_SOURCE_SHA and
        cfg.get("source_commit") == args.source_commit and cfg.get("source_scope") == native.selected.SCOPE and
        cfg.get("full_repository_archive") is False and inputs.get("source_config_sha256") == native.guard.fingerprint(cfg) and
        inputs.get("engine_campaign_admission") is True and same_path(cfg["qa_root"], ROOT) and
        same_path(evidence, native.guard.evidence_for(cfg, "capture")), "Exact HL v4 selected-source cohort/config required")
    project, campaign = plain(cfg["project"]), plain(cfg["workspace"])
    output_workspace = plain(args.workspace)
    require(campaign.is_relative_to(ROOT / "workspaces") and project == campaign / "qa_source" and
        not output_workspace.is_relative_to(campaign) and not campaign.is_relative_to(output_workspace), "Disjoint native campaign/output workspace required")
    receipts = {phase: native.previous(cfg, phase) for phase in native.PHASES}
    prepared, installed = native.verify_prepared(cfg)
    identity = native.verify_identity(cfg)
    require(installed is not None and installed.get("package_sha256") == PACKAGE_SHA == receipts["identity"]["artifacts"]["candidate_package_sha256"] and
        identity.get("schema") == "bth.high_limit_current_source_identity/v1" and identity.get("source_commit") == args.source_commit and
        identity.get("source_tree") == cfg["source_tree"] and identity.get("source_scope") == native.selected.SCOPE and
        identity.get("canonical_tracked_uid_sidecars_preserved") is True, "Current source/UID/HL21 candidate identity differs")
    files = installed["files"]
    require(len(files) == 21 and set(files) == set(cfg["baseline_files"]) and native.guard.seal(files) == PACKAGE_SHA and
        all(identity["files"].get(name) == digest for name, digest in files.items()), "Actual installed21-file package differs")
    native.policy.canonical_imports(project)
    plan, closure = native.selection(cfg)
    require(identity["selection_sha256"] == prepared["selection_sha256"] == plan["selection_sha256"] == closure["selection_sha256"] and
        prepared["source_archive_sha256"] == receipts["archive"]["artifacts"]["sha256"], "Selected Git source/archive custody differs")
    archive = plain(cfg["archive"], file=True)
    require(sha(archive) == prepared["source_archive_sha256"], "Original selected source tar changed")
    for phase in ("contexts", "motion", "liveness", "capture"):
        actual = native.result_for(cfg, phase, SimpleNamespace(evidence=native.guard.evidence_for(cfg, phase)))
        require(actual == receipts[phase]["artifacts"], "Original native report/PNG qualification changed: " + phase)
    artifacts = receipts["capture"]["artifacts"]
    require(same_path(artifacts.get("report", ""), path) and artifacts.get("sha256") == artifacts.get("source_capture_json_sha256") == args.capture_json_sha256 and
        artifacts.get("fullapp_is_actual_production") is True and artifacts.get("board900_is_diagnostic_clone") is True and
        artifacts.get("native1800_excludes_live_objects") is True and artifacts.get("no_pointer_input_during_capture") is True,
        "Closed HL capture/artifact origin differs")
    observer_zip = plain(project / "qa_reference/high-limit-original-observers.zip", file=True)
    require(native.policy.HELPERS == HELPERS and identity.get("original_observers") == prepared.get("helper_bindings"), "Original HL observer closure differs")
    with zipfile.ZipFile(observer_zip) as saved:
        for name, expected in HELPERS.items():
            old, active = saved.read(name), plain(project / name, file=True).read_bytes()
            row = identity["original_observers"][name]
            require(hashlib.sha256(old).hexdigest() == expected == row.get("original_sha256") and sha(project / name) == row.get("active_sha256") and
                row.get("assertions_unchanged") is True and row.get("canonical_uid_overwritten") is False and
                old.replace(b"\r\n", b"\n") == active.replace(b"\r\n", b"\n"), "Active HL observer bytes/assertions differ: " + name)
    for name, expected in cfg["dependencies"].items():
        require(sha(plain(Path(__file__).with_name(name), file=True)) == expected, "Captured native dependency changed: " + name)
    engine = plain(cfg["engine"], file=True)
    require(sha(engine) == native.guard.ENGINE_SHA, "Pinned native engine differs")
    runtime = plain(engine.with_name("Godot_v4.6-stable_win64.exe"), file=True)
    require(sha(runtime) == native.guard.RUNTIME_SHA, "Pinned native runtime differs")
    metadata = read_json(path)
    frames = metadata["frames"]
    count = len(frames)
    require(FRAME_COUNT <= count <= 400 and artifacts.get("frames") == metadata.get("measured_frame_count") == count and
        metadata.get("archetype") == ROOM and metadata.get("scenario") == "__none" and metadata.get("layer") == "" and
        metadata.get("pack_active") is True and metadata.get("board900_is_qa_clone") is True and metadata.get("board900_size") == list(SIZE) and
        metadata.get("board2x_size") == [1800, 860] and metadata.get("native_art_layers_only") is True and
        "no pointer input during capture" in metadata.get("note", ""), "Authentic full-capture/diagnostic900 contract differs")
    require([row.get("id") for row in metadata.get("animation_inventory", [])] == list(native.policy.ANIMATION_IDS) and
        [row.get("id") for row in metadata["animation_inventory"] if row.get("web_low_detail")] == list(native.policy.LOW_IDS), "Full native16/low-detail7 capture inventory differs")
    equivalence = metadata.get("board900_equivalence", [])
    require(len(equivalence) == count and all(row.get("frame") == index and all(row.get(key) is True for key in
        ("object_layout_equal", "objects_equal", "animation_clock_equal", "actor_route_clock_equal")) for index, row in enumerate(equivalence)), "Diagnostic clone clock/layout/object equivalence differs")
    for key in ("actual_arrival_wait", "board900_arrival_wait"):
        row = metadata.get(key, {})
        require(row.get("remaining_person_transits") == 0 and row.get("input_during_wait") is False and row.get("positions_modified") is False, "Natural arrival/no-input control differs")
    reduced = metadata.get("reduce_motion", {})
    require(reduced.get("active") is True and reduced.get("production_art_texture_pixels_stable") is True and
        reduced.get("full_app_file") == "reduce_motion_play.png" and reduced.get("native_art_file") == "reduce_motion_board2x.png", "Production Reduce Motion proof differs")
    command = inputs["command"]
    excerpt_arg = [value.split("=", 1)[1] for value in command if value.startswith("--excerpt-seconds=")]
    require(len(excerpt_arg) == 1 and numeric(float(excerpt_arg[0])) and 0 < float(excerpt_arg[0]) <= 20 and
        numeric(metadata.get("capture_seconds_requested")) and numeric(metadata.get("max_animation_cycle")) and
        abs(metadata["capture_seconds_requested"] - min(20.0, metadata["max_animation_cycle"] + .25, float(excerpt_arg[0]))) < .00001 and
        numeric(metadata.get("sample_fps")) and 0 < metadata["sample_fps"] <= 20 and count <= math.ceil(metadata["capture_seconds_requested"] * metadata["sample_fps"]), "Recorded capture request/bounded sampling contract differs")
    ledger, clocks = {}, []
    expected_pngs = dict(CONTROLS)
    for index, frame in enumerate(frames):
        clock = frame.get("clock")
        require(numeric(clock) and frame.get("board900_clock") == clock and (frame.get("width"), frame.get("height")) == (1280, 720) and
            [row.get("id") for row in frame.get("animation_states", [])] == list(native.policy.ANIMATION_IDS), "Full frame clocks/states differ")
        clocks.append(clock)
        for family, prefix, dimensions in (("file", "frame", (1280, 720)), ("board900_file", "board900", SIZE), ("board2x_file", "board2x", (1800, 860))):
            name = f"{prefix}_{index:03d}.png"
            require(frame.get(family) == name, "Original source frame filename/order differs")
            expected_pngs[name] = dimensions
    native_rows = artifacts.get("frame_png_inventory", [])
    require(len(native_rows) == count * 3, "Complete native post-Job3N PNG ledger required")
    for row in native_rows:
        name = native.selected.relative_name(row["file"])
        require(name not in ledger, "Duplicate native PNG ledger row")
        ledger[name] = row
    require(set(ledger) == set(expected_pngs) - set(CONTROLS), "Native frame ledger has a missing/extra source path")
    require(all(b > a for a, b in zip(clocks, clocks[1:])) and numeric(metadata.get("actual_clock_span")) and
        abs(clocks[-1] - clocks[0] - metadata["actual_clock_span"]) < .00001 and artifacts.get("actual_clock_span") == metadata["actual_clock_span"], "Original full source clock span differs")
    actual_pngs = {item.relative_to(capture_root).as_posix(): plain(item, file=True) for item in capture_root.rglob("*.png")}
    require(set(actual_pngs) == set(expected_pngs), "Expected exact full3N+5 PNG/control inventory; no omitted originals")
    job = read_json(evidence / "job.json")
    claim_start = read_json(evidence / "launch-claim.json")["claimed_epoch"]
    require(numeric(claim_start) and claim_start < job["finished_epoch"], "Capture write window differs")
    pngs, decoded = {}, []
    for name, image_path in sorted(actual_pngs.items()):
        stat = image_path.stat()
        dimensions = png_header(image_path)
        digest = sha(image_path)
        require(dimensions == expected_pngs[name] and claim_start - .01 <= stat.st_mtime <= job["finished_epoch"] + .01, "Original PNG size/write-window differs: " + name)
        origin = "Encoding-admission control PNG hash; original native closure has no individual control-PNG SHA"
        if name in ledger:
            row = ledger[name]
            index = int(name.rsplit("_", 1)[1][:-4])
            family = "file" if name.startswith("frame_") else "board900_file" if name.startswith("board900_") else "board2x_file"
            require(row == {"file": name, "family": family, "clock": clocks[index], "dimensions": list(dimensions), "bytes": stat.st_size, "sha256": digest}, "Original frame differs from native post-Job PNG ledger: " + name)
            origin = "Exact SHA/dimensions/bytes/clock from closed native v4 post-Job capture qualification ledger"
        pngs[name] = {"sha256": digest, "bytes": stat.st_size, "dimensions": list(dimensions), "modified_ns": stat.st_mtime_ns, "hash_origin": origin}
        if decode_payloads:
            image = codec.decode_png(image_path.read_bytes())
            require((image.width, image.height) == dimensions, "Original complete PNG payload/dimensions differ")
            decoded.append({"file": name, "png_sha256": digest, "dimensions": list(dimensions), "rgba_sha256": hashlib.sha256(image.rgba).hexdigest()})
    control_paths = [path, archive, observer_zip, project / "highlimit_capture_inputs.json", project / "highlimit_spatial_source_identity.json",
        project / "qa_reference/prepared-source.json", project / "qa_reference/candidate-install.json", engine, runtime]
    for phase in native.PHASES:
        folder = native.guard.evidence_for(cfg, phase)
        control_paths.extend(folder / name for name in ("phase-result.json", "trial-inputs.json", "job.json", "worker.log", "storage-manifest.json", "launch-claim.json"))
        control_paths.extend(folder / name for name in receipts[phase]["artifact_sha256"])
    control_paths.extend(Path(__file__).with_name(name) for name in {*cfg["dependencies"], *pins})
    control_paths.extend(project / name for name in HELPERS)
    delays, timing = clock_delays(clocks[:FRAME_COUNT])
    binding = {"source_commit": args.source_commit, "source_tree": cfg["source_tree"], "source_config_sha256": native.guard.fingerprint(cfg),
        "source_scope": native.selected.SCOPE, "selection_sha256": plan["selection_sha256"], "candidate_21_file_sha256": PACKAGE_SHA,
        "native_project": str(project), "native_run_prefix": cfg["run_prefix"], "capture_json": str(path), "capture_json_sha256": args.capture_json_sha256,
        "original_full_frame_count": count, "original_full_clock_span_seconds": metadata["actual_clock_span"], "full_png_inventory": pngs,
        "native_frame_png_ledger_sha256": hashlib.sha256(json.dumps(native_rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
        "control_sha256": {str(item): sha(plain(item, file=True)) for item in control_paths}, "frozen_module_sha256": pins,
        "baseline_auxiliary_files": cfg["baseline_auxiliary_files"], "all_native_cohort_phases_closed_pass": list(native.PHASES),
        "excerpt": {"explicit_excerpt": True, "complete_original_capture": False, "source_indices_zero_based": list(range(FRAME_COUNT)),
            "selected_frame_count": FRAME_COUNT, "canvas_size": list(SIZE), "timing": timing,
            "selection": "Contiguous first75 actual recorded frames; no frame omitted within excerpt",
            "scope": "Native900 diagnostic production-canvas clone with actors/counters/labels; full actual UI and native1800 originals retained unchanged"}}
    return binding, [capture_root / frames[index]["board900_file"] for index in range(FRAME_COUNT)], delays, decoded


def output_paths(layout, binding):
    directory = layout.workspace / "preview_artifacts"
    stem = "high-limit-first75-excerpt-" + binding["capture_json_sha256"][:12] + "-900"
    return directory, directory / (stem + ".png"), directory / (stem + ".proof.json")


def declared_outputs(layout, phase, binding):
    directory, output, final = output_paths(layout, binding)
    result = [directory]
    if phase == "encode":
        result.append(output)
        if not (directory / ".gdignore").exists():
            result.append(directory / ".gdignore")
        else:
            plain(directory / ".gdignore", file=True)
    if phase == "verify":
        result.append(final)
    return tuple(result)


def write_new(path, value, layout):
    validate_layout(layout, extra_write_paths=(path.parent,))
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def worker_command(args, phase):
    return [sys.executable, "-B", str(Path(__file__).absolute()), phase, "--worker", "--workspace", str(args.workspace),
        "--capture-json", str(args.capture_json), "--capture-json-sha256", args.capture_json_sha256,
        "--source-commit", args.source_commit, "--run-prefix", args.run_prefix, "--timeout", str(args.timeout)]


def validate_decoded(proof, binding):
    rows = proof.get("full_png_payload_decode_ledger", [])
    require(proof.get("all_full_original_png_payloads_decoded") is True and len(rows) == len(binding["full_png_inventory"]) and
        {row.get("file") for row in rows} == set(binding["full_png_inventory"]), "Full original PNG decode inventory differs")
    for row in rows:
        original = binding["full_png_inventory"][row["file"]]
        require(row.get("png_sha256") == original["sha256"] and row.get("dimensions") == original["dimensions"] and
            isinstance(row.get("rgba_sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", row["rgba_sha256"]), "Full PNG payload proof differs from immutable source")


def verify_excerpt(data, paths, delays, binding):
    # The borrowed pure verifier proves75 actual RGBA frames, but its historical
    # Grand return label hardcodes151 full frames. Keep the frozen verifier and
    # adapt only this local proof's provenance to the actual closed HL cohort.
    result = dict(verify_apng(data, paths, delays))
    require(result.get("all_frames_exact_rgba") is True and result.get("selected_frame_count") == FRAME_COUNT and
        result.get("source_indices_zero_based") == list(range(FRAME_COUNT)) and result.get("canvas_size") == list(SIZE),
        "Borrowed pure recomposition proof does not match selected75 native frames")
    result["original_frame_count"] = binding["original_full_frame_count"]
    result["original_frame_count_origin"] = "Actual closed HL capture measured_frame_count and full native PNG ledger"
    return result


def prior(args, phase, binding):
    evidence = ROOT / "runs" / (args.run_prefix + "-" + phase) / "evidence"
    receipt, proof, job, manifest, claim = (read_json(evidence / name) for name in ("phase-result.json", "worker-proof.json", "job.json", "storage-manifest.json", "launch-claim.json"))
    inputs = read_json(evidence / "phase-inputs.json")
    require(receipt.get("schema") == SCHEMA and receipt.get("phase") == phase and receipt.get("status") == "PASS" and
        native.selected.qualified_job(job) and same_path(receipt.get("job_receipt", ""), evidence / "job.json") and
        job.get("command") == worker_command(args, phase) and inputs.get("phase") == phase and inputs.get("source_binding") == binding and
        inputs.get("adapter_sha256") == sha(__file__) and same_path(receipt.get("proof", ""), evidence / "worker-proof.json") and
        receipt.get("job_sha256") == sha(evidence / "job.json") and receipt.get("log_sha256") == sha(evidence / "worker.log") and
        receipt.get("proof_sha256") == sha(evidence / "worker-proof.json") and proof.get("source_binding") == binding and
        proof.get("adapter_sha256") == sha(__file__) and proof.get("source_png_hashes_unchanged") is True and
        manifest.get("schema") == "bth-qa-storage/v1" and manifest.get("prepared") is True and same_path(manifest["paths"]["workspace"], WORKSPACE) and same_path(manifest["paths"]["evidence"], evidence) and
        same_path(job.get("storage_manifest", ""), evidence / "storage-manifest.json") and
        job.get("storage_manifest_sha256") == claim.get("manifest_sha256") == sha(evidence / "storage-manifest.json") and
        not native.guard.ERROR_LINE.search((evidence / "worker.log").read_text(encoding="utf-8", errors="replace")), "Prior HL APNG phase is not exact closed PASS")
    validate_decoded(proof, binding)
    return proof


def worker(args):
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    record = read_json(evidence / "storage-manifest.json")
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
        **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and same_path(layout.workspace, WORKSPACE) and same_path(layout.evidence, evidence) and
        layout.run_id == args.run_prefix + "-" + args.phase, "Exact prepared HL APNG worker ownership required")
    binding, paths, delays, decoded = capture_inputs(args, decode_payloads=True)
    directory, output, final = output_paths(layout, binding)
    validate_layout(layout, extra_write_paths=declared_outputs(layout, args.phase, binding))
    admitted = read_json(evidence / "phase-inputs.json")
    require(admitted.get("phase") == args.phase and admitted.get("source_binding") == binding and admitted.get("adapter_sha256") == sha(__file__), "Capture changed after encoding admission")
    proof = {"schema": SCHEMA, "phase": args.phase, "source_binding": binding, "adapter_sha256": sha(__file__),
        "observed_at": datetime.now(timezone.utc).isoformat(), "full_png_payload_decode_ledger": decoded,
        "all_full_original_png_payloads_decoded": True, "child_processes_launched_by_worker": 0, "art_approval": False, "test_updated": False}
    if args.phase != "plan":
        prior(args, "plan", binding)
    if args.phase == "encode":
        require(not output.exists() and not final.exists(), "No overwriting an excerpt/proof")
        data, rectangles = codec.encode_apng(paths, delays)
        verification = verify_excerpt(data, paths, delays, binding)
        require(capture_inputs(args)[0] == binding, "Full originals changed while encoding")
        validate_layout(layout, extra_write_paths=(directory,))
        directory.mkdir(exist_ok=True)
        if not (directory / ".gdignore").exists():
            with (directory / ".gdignore").open("x", encoding="utf-8") as handle:
                handle.write("# Non-active faithful High Limit first75-frame excerpt.\n")
        validate_layout(layout, extra_write_paths=(directory,))
        with output.open("xb") as handle:
            handle.write(data)
        proof.update(output={"path": str(output), "bytes": len(data), "sha256": sha(output)}, encoding=rectangles, verification=verification)
    elif args.phase == "verify":
        encoded = prior(args, "encode", binding)
        require(sha(plain(output, file=True)) == encoded["output"]["sha256"] and output.stat().st_size < MAX_BYTES, "Encoded excerpt bytes differ/oversize")
        proof.update(output=encoded["output"], verification=verify_excerpt(output.read_bytes(), paths, delays, binding))
        require(sha(output) == encoded["output"]["sha256"], "Excerpt changed during independent recomposition")
    require(capture_inputs(args)[0] == binding, "Full source/canonical UID/PNG/control custody changed during encoding phase")
    proof.update(status="WORKER_PASS_PENDING_JOB_CLOSE", source_png_hashes_unchanged=True)
    write_new(evidence / "worker-proof.json", proof, layout)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", "encode", "verify"))
    for name in ("workspace", "capture-json"):
        parser.add_argument("--" + name, type=Path, required=True)
    for name in ("capture-json-sha256", "source-commit", "run-prefix"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        require(same_path(args.workspace, WORKSPACE) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,70}", args.run_prefix) and
            1 <= args.timeout <= 1200, "Explicit separate HL APNG workspace/fresh prefix/timeout required")
        if args.worker:
            worker(args)
            return 0
        layout = plan_layout(ROOT, args.workspace, args.run_prefix + "-" + args.phase)
        binding, _, _, _ = capture_inputs(args)
        directory, output, final = output_paths(layout, binding)
        outputs = declared_outputs(layout, args.phase, binding)
        validate_layout(layout, extra_write_paths=outputs)
        if args.phase != "plan":
            prior(args, "plan", binding)
        if args.phase == "encode":
            require(not output.exists() and not final.exists(), "No overwriting an existing excerpt/proof")
        if args.phase == "verify":
            prior(args, "encode", binding)
            require(not final.exists(), "No overwriting a final proof")
        layout = prepare_layout(layout)
        write_new(layout.evidence / "phase-inputs.json", {"phase": args.phase, "source_binding": binding, "adapter_sha256": sha(__file__)}, layout)
        command = worker_command(args, args.phase)
        job = execute(layout, command, timeout=args.timeout, cpu_rate=1200, extra_write_paths=outputs)
        require(native.selected.qualified_job(job) and not native.guard.ERROR_LINE.search((layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")), "HL APNG Job failed or did not close cleanly at zero")
        proof_path = layout.evidence / "worker-proof.json"
        proof = read_json(proof_path)
        require(proof.get("status") == "WORKER_PASS_PENDING_JOB_CLOSE" and proof.get("source_binding") == binding and
            proof.get("source_png_hashes_unchanged") is True and proof.get("all_full_original_png_payloads_decoded") is True and
            len(proof.get("full_png_payload_decode_ledger", [])) == len(binding["full_png_inventory"]) and capture_inputs(args)[0] == binding,
            "Closed HL APNG source/PNG decode proof differs")
        validate_decoded(proof, binding)
        receipt = {"schema": SCHEMA, "phase": args.phase, "status": "PASS", "job_receipt": str(layout.evidence / "job.json"),
            "job_sha256": sha(layout.evidence / "job.json"), "log_sha256": sha(layout.evidence / "worker.log"),
            "proof": str(proof_path), "proof_sha256": sha(proof_path), "explicit_excerpt": True, "complete_original_capture": False, "art_approval": False, "test_updated": False}
        if args.phase == "verify":
            require(proof.get("verification", {}).get("all_frames_exact_rgba") is True, "Exact75-frame RGBA recomposition proof absent")
            write_new(final, {**proof, "status": "EXACT_LOSSLESS_HIGH_LIMIT_FIRST75_EXCERPT_VERIFIED", "closed_verify_receipt": receipt}, layout)
            receipt.update(output=proof["output"], final_proof=str(final))
        write_new(layout.evidence / "phase-result.json", receipt, layout)
        print(json.dumps(receipt), flush=True)
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, IndexError, struct.error, zlib.error, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "HIGH_LIMIT_APNG_STOPPED", "phase": args.phase, "error": str(error), "fallback_attempted": False,
            "original_frames_modified": False, "test_updated": False}), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
