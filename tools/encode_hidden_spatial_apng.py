"""Guarded lossless first75-frame excerpt of the actual closed Hidden v3 capture.

Requires the actual CLI capture JSON path and SHA; no guessed capture hash.
Authenticates13 closed core phases and the complete original3N+5 PNG ledger.
The separate15 acceptance phases and summary are not qualified by this encoder.
Borrows only pure055 encoding and ef06 independent RGBA recomposition. All
full-app/native1800/diagnostic900 originals remain immutable. The APNG is a
native900 diagnostic excerpt, never the complete capture or actual full UI.
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

import hidden_spatial_native_trial_v3 as native
import encode_bar_spatial_apng as codec
from encode_grand_spatial_apng_excerpt import verify_apng
from bth_qa_storage import Layout, plan_layout, prepare_layout, validate_layout
from bth_qa_guarded_run import execute

ROOT = Path("E:/CodexQA/BTH")
WORKSPACE = ROOT / "workspaces/BTH-ENV-SPATIAL-HIDDEN-APNG-20261116"
SCHEMA = "bth.hidden_spatial_apng_phase/v1"
RUNNER_SHA = "744c7760283029c943f6cd313f5e24a32e3d8c6f2046faf1c683881ef6125674"
SELECTED_SOURCE_SHA = "051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625"
POLICY_SHA = "6f9a986268bd2dc9e453258de64dab6905347b7ef92189455cba3d63467d8d81"
CODEC_SHA = "055cb411dd3cc10b36ce9001658d9f4cb5369f4c7e4ae7e31fe86ac921e72329"
VERIFY_SHA = "ef06a9712aff39cde655679c68f0fcf19a2fd972754150c1ed28f1c06c3119cc"
GRAND_IMPORT_SHA = "9f6c9a51ab5cfdd382e94943feda11b3f1dbe79b878ee68abc71d21df787305a"
PACKAGE_SHA = "508b106419ef299aad27d92f4d54c5c4d1f7e6cf353dff546848ed290a273509"
ROOM, SIZE, FRAME_COUNT, DENOMINATOR, LAST_TICKS = "small_underground_casino", (900, 430), 75, 10000, 200
MAX_BYTES = 10 * 1024 ** 2
SOURCE_COMMIT = "4010535f41e157820d3c06b44cb3d956a1b5946a"
SOURCE_TREE = "1870e5be6208e7a0befbc831deb52319792ebc05"
NATIVE_RUN_PREFIX = "BTH-ENV-SPATIAL-HIDNATIVE-20261116-v3"
CONFIG_SHA = "eccf4ccc6e5e9f426ee1f61d9388f2a5295701c863e422c134eac99c5de45b49"
CAPTURE_RECEIPT_SHA = "ac13dfcf0c35bde9b833374bdce4fee745c14db9cc0e332273bfdb8eee078087"
CAPTURE_JOB_SHA = "f67594f7574d8f1f7b54ec9f984f55748dac1972ce7210928cfcfa4867d0fdbc"
IDENTITY_SHA = "95d605b2a8ae10a8b7ea6dc798a27d3999e11cf3200c1bbdc44ee230d496d1a3"
CAPTURE_INPUTS_SHA = "921b6476590f191e3983c188d61b938944eac200f0fd85bbf00f27517a792791"
PYTHON_SHA = "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
HL_SOURCE_SHA = "48fe17bca5706d1fc47956bfe6161e62cc9e6f573fd2fc5c08f835d416a9c7d4"
GBR_SOURCE_SHA = "bdd217b280f0ea4712614c49666659718f3e72bfffcb050f4021ed2ffd5673a4"
CORE_PHASES = ("source-identity", "tree", "baseline-tree", "select", "archive", "prepare", "install", "import", "identity", "contexts", "motion", "liveness", "capture")
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
    pins = {"hidden_spatial_native_trial_v3.py": RUNNER_SHA, "hidden_spatial_native_profile_v3.py": POLICY_SHA,
        "bth_qa_selected_source_v2.py": SELECTED_SOURCE_SHA,
        "encode_bar_spatial_apng.py": CODEC_SHA, "encode_grand_spatial_apng_excerpt.py": VERIFY_SHA,
        "encode_grand_spatial_apng.py": GRAND_IMPORT_SHA, "encode_high_limit_spatial_apng.py": HL_SOURCE_SHA,
        "encode_grand_back_room_spatial_apng.py": GBR_SOURCE_SHA}
    for name, expected in pins.items():
        require(sha(plain(Path(__file__).with_name(name), file=True)) == expected, "Frozen source changed: " + name)
    require(codec.SIZE == SIZE and codec.DENOMINATOR == DENOMINATOR and codec.LAST_TICKS == LAST_TICKS and
        Path(verify_apng.__code__.co_filename).resolve() == Path(__file__).with_name("encode_grand_spatial_apng_excerpt.py").resolve(),
        "Pure lossless encoder/recomposer contract differs")
    require(tuple(native.CORE_PHASES) == CORE_PHASES and tuple(native.PHASES[:13]) == CORE_PHASES and
        len(native.PHASES) == 29 and len(native.policy.HELPERS) == 19 and len(native.policy.PROVENANCE) == 6,
        "Exact Hidden13-core/29-total/19-GD/6-provenance contract required")
    return pins


def capture_inputs(args, *, decode_payloads=False):
    pins = module_pins()
    native.selected.full_hash(args.source_commit)
    native.selected.full_hash(args.capture_json_sha256, 64)
    require(args.source_commit == SOURCE_COMMIT, "Only the actual completed Hidden v3 core source cohort is admitted")
    path = plain(args.capture_json, file=True)
    require(path.name == "animation_capture.json" and path.parent.name == "capture" and path.parent.parent.name == "evidence" and
        path.is_relative_to(ROOT / "runs") and sha(path) == args.capture_json_sha256, "Actual explicit Hidden capture JSON/SHA required")
    evidence, capture_root = path.parent.parent, path.parent
    inputs = read_json(evidence / "trial-inputs.json")
    cfg = inputs["source_config"]
    native.selected.full_hash(cfg.get("source_tree"))
    require(cfg.get("schema") == "bth.hidden_spatial_inputs/v1" and cfg.get("adapter_sha256") == RUNNER_SHA and
        cfg.get("dependencies", {}).get("hidden_spatial_native_profile_v3.py") == POLICY_SHA and
        cfg.get("dependencies", {}).get("bth_qa_selected_source_v2.py") == SELECTED_SOURCE_SHA and
        cfg.get("source_commit") == args.source_commit == SOURCE_COMMIT and cfg.get("source_tree") == SOURCE_TREE and
        cfg.get("run_prefix") == NATIVE_RUN_PREFIX and native.guard.fingerprint(cfg) == CONFIG_SHA and
        cfg.get("python_sha256") == PYTHON_SHA == sha(plain(sys.executable, file=True)) and
        cfg.get("source_scope") == native.selected.SCOPE and cfg.get("full_repository_archive") is False and
        inputs.get("source_config_sha256") == CONFIG_SHA and inputs.get("engine_campaign_admission") is True and
        same_path(cfg["qa_root"], ROOT) and same_path(evidence, native.guard.evidence_for(cfg, "capture")),
        "Exact Hidden v3 selected-source/config/admission required")
    project, campaign, retained = plain(cfg["project"]), plain(cfg["workspace"]), plain(cfg["input_workspace"])
    output_workspace = plain(args.workspace)
    native.policy.workspace_roles(campaign, retained)
    require(project == campaign / "qa_source" and cfg.get("input_workspace_access") == "READ_ONLY_RETAINED_NO_PROFILE_MIGRATION" and
        all(not output_workspace.is_relative_to(root) and not root.is_relative_to(output_workspace) for root in (campaign, retained)),
        "Disjoint APNG output/fresh QA/retained source workspaces required")
    receipts = {phase: native.previous(cfg, phase) for phase in CORE_PHASES}
    require(sha(evidence / "phase-result.json") == CAPTURE_RECEIPT_SHA and sha(evidence / "job.json") == CAPTURE_JOB_SHA and
        receipts["identity"]["artifacts"]["identity_sha256"] == IDENTITY_SHA and
        receipts["identity"]["artifacts"]["capture_inputs_sha256"] == CAPTURE_INPUTS_SHA,
        "Actual closed Hidden capture/identity receipt differs")
    for phase in CORE_PHASES:
        folder = native.guard.evidence_for(cfg, phase)
        source_inputs, closed_job = read_json(folder / "trial-inputs.json"), read_json(folder / "job.json")
        require(source_inputs.get("source_config") == cfg and
            source_inputs.get("engine_campaign_admission") is (phase in native.ENGINE_PHASES),
            "Native core source/admission differs: " + phase)
        if phase in native.FILE_PHASES:
            require(same_path(closed_job["command"][0], sys.executable) and
                sha(plain(closed_job["command"][0], file=True)) == PYTHON_SHA, "Closed core file-worker Python differs")
    prepared, installed = native.verify_prepared(cfg)
    identity = native.verify_identity(cfg)
    require(installed is not None and installed.get("package_sha256") == PACKAGE_SHA ==
        receipts["identity"]["artifacts"]["candidate_package_sha256"] and
        identity.get("schema") == "bth.hidden_current_source_identity/v1" and
        identity.get("source_commit") == SOURCE_COMMIT and identity.get("source_tree") == SOURCE_TREE and
        identity.get("source_scope") == native.selected.SCOPE and identity.get("canonical_tracked_uid_sidecars_preserved") is True,
        "Current Hidden source/candidate30/canonical UID identity differs")
    files = installed["files"]
    require(len(files) == 30 and set(files) == set(cfg["baseline_files"]) and native.guard.seal(files) == PACKAGE_SHA and
        all(identity["files"].get(name) == digest for name, digest in files.items()), "Actual installed Hidden30 differs")
    native.policy.canonical_imports(project)
    plan, closure = native.selection(cfg)
    require(identity["selection_sha256"] == prepared["selection_sha256"] == plan["selection_sha256"] == closure["selection_sha256"] and
        prepared["source_archive_sha256"] == receipts["archive"]["artifacts"]["sha256"], "Selected Git source/archive differs")
    archive = plain(cfg["archive"], file=True)
    require(sha(archive) == prepared["source_archive_sha256"], "Original selected source tar changed")
    for phase in ("contexts", "motion", "liveness", "capture"):
        actual = native.result_for(cfg, phase, SimpleNamespace(evidence=native.guard.evidence_for(cfg, phase)))
        require(actual == receipts[phase]["artifacts"], "Closed core native report/PNG qualification changed: " + phase)
    artifacts = receipts["capture"]["artifacts"]
    contract = artifacts["contract"]
    require(same_path(artifacts.get("report", ""), path) and artifacts.get("sha256") == args.capture_json_sha256 and
        artifacts.get("current_source_commit") == SOURCE_COMMIT and
        contract.get("fullapp_is_actual_production") is True and contract.get("board900_is_diagnostic_clone") is True and
        contract.get("native1800_excludes_live_objects") is True and contract.get("no_pointer_input_during_capture") is True,
        "Closed Hidden capture/artifact origin differs")
    observer_zip = plain(project / "qa_reference/hidden-original-observers.zip", file=True)
    helpers, provenance = native.policy.HELPERS, native.policy.PROVENANCE
    require(identity.get("original_observers") == prepared.get("helper_bindings"), "Original Hidden19 observer bindings differ")
    bindings = native.policy.literal_bindings(cfg)
    require(bindings == cfg["observer_literal_path_bindings"], "Only original full quoted input-path translations are admitted")
    with zipfile.ZipFile(observer_zip) as saved:
        require(len(saved.namelist()) == len(set(saved.namelist())) == 25 and set(saved.namelist()) == set(helpers) | set(provenance),
            "Exact original19-GD/6-provenance archive required")
        for name, expected in helpers.items():
            old, active = saved.read(name), plain(project / name, file=True).read_bytes()
            transported, operations = native.policy.transport_bytes(name, old, bindings)
            row = identity["original_observers"][name]
            require(hashlib.sha256(old).hexdigest() == expected == row.get("original_sha256") and
                sha(project / name) == row.get("active_sha256") and active == transported and
                row.get("literal_path_transports") == operations and row.get("assertions_unchanged") is True and
                row.get("canonical_uid_overwritten") is False, "Actual preserved observer assertions differ: " + name)
        for name, expected in provenance.items():
            require(hashlib.sha256(saved.read(name)).hexdigest() == expected,
                "Original UID/catalog/input provenance differs: " + name)
    for name, expected in cfg["dependencies"].items():
        require(re.fullmatch(r"[A-Za-z0-9_.-]+", name) and sha(plain(Path(__file__).with_name(name), file=True)) == expected,
            "Captured native dependency changed: " + name)
    engine = plain(cfg["engine"], file=True)
    runtime = plain(engine.with_name("Godot_v4.6-stable_win64.exe"), file=True)
    require(sha(engine) == native.guard.ENGINE_SHA and sha(runtime) == native.guard.RUNTIME_SHA, "Pinned native engine/runtime differs")
    metadata = read_json(path)
    frames = metadata["frames"]
    count = len(frames)
    require(count >= FRAME_COUNT and contract.get("frames") == metadata.get("measured_frame_count") == count and
        metadata.get("archetype") == ROOM and metadata.get("scenario") == "__none" and metadata.get("layer") == "casino" and
        metadata.get("pack_active") is True and metadata.get("board900_is_qa_clone") is True and
        metadata.get("board900_size") == list(SIZE) and metadata.get("board2x_size") == [1800, 860] and
        metadata.get("native_art_layers_only") is True and "no pointer input during capture" in metadata.get("note", ""),
        "Authentic full Hidden capture/diagnostic900 contract differs")
    require([row.get("id") for row in metadata.get("animation_inventory", [])] == list(native.policy.ANIMATION_IDS) and
        all(row.get("web_low_detail") is True for row in metadata["animation_inventory"]) and
        len(metadata["animation_inventory"]) == 31, "Full Hidden31/default31 capture inventory differs")
    equivalence = metadata.get("board900_equivalence", [])
    require(len(equivalence) == count and all(row.get("frame") == index and all(row.get(key) is True for key in
        ("object_layout_equal", "objects_equal", "animation_clock_equal", "actor_route_clock_equal")) for index, row in enumerate(equivalence)),
        "Diagnostic clone clock/layout/object equivalence differs")
    for key in ("actual_arrival_wait", "board900_arrival_wait"):
        row = metadata.get(key, {})
        require(row.get("remaining_person_transits") == 0 and row.get("input_during_wait") is False and
            row.get("positions_modified") is False, "Natural arrival/no-input control differs")
    reduced = metadata.get("reduce_motion", {})
    require(reduced.get("active") is True and reduced.get("production_art_texture_pixels_stable") is True and
        reduced.get("full_app_file") == "reduce_motion_play.png" and reduced.get("native_art_file") == "reduce_motion_board2x.png",
        "Production Reduce Motion proof differs")
    command = inputs["command"]
    excerpt_arg = [value.split("=", 1)[1] for value in command if value.startswith("--excerpt-seconds=")]
    require(len(excerpt_arg) == 1 and numeric(float(excerpt_arg[0])) and
        float(excerpt_arg[0]) == cfg["capture_seconds"] and 0 < float(excerpt_arg[0]) <= 20 and
        numeric(metadata.get("capture_seconds_requested")) and numeric(metadata.get("max_animation_cycle")) and
        abs(metadata["capture_seconds_requested"] - min(20.0, metadata["max_animation_cycle"] + .25, float(excerpt_arg[0]))) < .00001 and
        numeric(metadata.get("sample_fps")) and 0 < metadata["sample_fps"] <= 20 and
        count <= math.ceil(metadata["capture_seconds_requested"] * metadata["sample_fps"]), "Recorded bounded request/sampling differs")
    ledger, clocks = {}, []
    expected_pngs = dict(CONTROLS)
    for index, frame in enumerate(frames):
        clock = frame.get("clock")
        require(numeric(clock) and frame.get("board900_clock") == clock and (frame.get("width"), frame.get("height")) == (1280, 720) and
            [row.get("id") for row in frame.get("animation_states", [])] == list(native.policy.ANIMATION_IDS), "Full frame clocks/states differ")
        clocks.append(clock)
        for family, prefix, dimensions in (("file", "frame", (1280, 720)), ("board900_file", "board900", SIZE), ("board2x_file", "board2x", (1800, 860))):
            name = f"{prefix}_{index:03d}.png"
            require(frame.get(family) == name, "Original frame filename/order differs")
            expected_pngs[name] = dimensions
    native_rows = artifacts.get("generated_png_inventory", [])
    require(len(native_rows) == count * 3 + len(CONTROLS), "Complete closed Hidden3N+5 PNG ledger required")
    for row in native_rows:
        relative = native.selected.relative_name(row["file"])
        require(relative.startswith("capture/") and relative.count("/") == 1, "Only direct original capture PNGs admitted")
        name = relative[len("capture/"):]
        require(name not in ledger, "Duplicate native PNG ledger row")
        ledger[name] = row
    require(set(ledger) == set(expected_pngs), "Complete Hidden native PNG/control ledger has missing/extra paths")
    require(all(b > a for a, b in zip(clocks, clocks[1:])) and numeric(metadata.get("actual_clock_span")) and
        abs(clocks[-1] - clocks[0] - metadata["actual_clock_span"]) < .00001 and
        contract.get("actual_clock_span") == metadata["actual_clock_span"], "Original full source clock span differs")
    actual_pngs = {item.relative_to(capture_root).as_posix(): plain(item, file=True) for item in capture_root.rglob("*.png")}
    require(set(actual_pngs) == set(expected_pngs), "Exact full3N+5 PNG/control inventory required")
    job = read_json(evidence / "job.json")
    claim_start = read_json(evidence / "launch-claim.json")["claimed_epoch"]
    require(numeric(claim_start) and claim_start < job["finished_epoch"], "Capture write window differs")
    pngs, decoded = {}, []
    for name, image_path in sorted(actual_pngs.items()):
        stat = image_path.stat()
        dimensions, digest = png_header(image_path), sha(image_path)
        row = ledger[name]
        require(dimensions == expected_pngs[name] and claim_start - .01 <= stat.st_mtime <= job["finished_epoch"] + .01 and
            row == {"file": "capture/" + name, "sha256": digest, "bytes": stat.st_size, "dimensions": list(dimensions)},
            "Original PNG differs from closed native size/SHA/write-window ledger: " + name)
        pngs[name] = {"sha256": digest, "bytes": stat.st_size, "dimensions": list(dimensions), "modified_ns": stat.st_mtime_ns,
            "hash_origin": "Exact SHA/dimensions/bytes from closed Hidden v3 post-Job generated PNG ledger"}
        if decode_payloads:
            image = codec.decode_png(image_path.read_bytes())
            require((image.width, image.height) == dimensions, "Original full PNG payload/dimensions differ")
            decoded.append({"file": name, "png_sha256": digest, "dimensions": list(dimensions),
                "rgba_sha256": hashlib.sha256(image.rgba).hexdigest()})
    control_paths = [path, archive, observer_zip, project / "hidden_capture_inputs.json", project / "hidden_spatial_source_identity.json",
        project / "qa_reference/prepared-source.json", project / "qa_reference/candidate-install.json",
        project / native.policy.CATALOG_PATH, engine, runtime, plain(sys.executable, file=True)]
    for phase in CORE_PHASES:
        folder = native.guard.evidence_for(cfg, phase)
        control_paths.extend(folder / name for name in ("phase-result.json", "trial-inputs.json", "job.json", "worker.log", "storage-manifest.json", "launch-claim.json"))
        control_paths.extend(folder / name for name in receipts[phase]["artifact_sha256"])
    control_paths.extend(Path(__file__).with_name(name) for name in {*cfg["dependencies"], *pins})
    control_paths.extend(project / name for name in helpers)
    delays, timing = clock_delays(clocks[:FRAME_COUNT])
    binding = {"source_commit": SOURCE_COMMIT, "source_tree": SOURCE_TREE, "source_config_sha256": CONFIG_SHA,
        "source_scope": native.selected.SCOPE, "selection_sha256": plan["selection_sha256"], "candidate_30_file_sha256": PACKAGE_SHA,
        "native_adapter_sha256": RUNNER_SHA, "native_policy_sha256": POLICY_SHA, "python_sha256": PYTHON_SHA,
        "native_capture_phase_receipt_sha256": CAPTURE_RECEIPT_SHA, "native_capture_job_sha256": CAPTURE_JOB_SHA,
        "native_project": str(project), "retained_input_workspace": str(retained), "native_run_prefix": cfg["run_prefix"],
        "capture_json": str(path), "capture_json_sha256": args.capture_json_sha256, "original_full_frame_count": count,
        "original_full_clock_span_seconds": metadata["actual_clock_span"], "full_png_inventory": pngs,
        "native_full_png_ledger_sha256": native.guard.fingerprint(native_rows),
        "control_sha256": {str(item): sha(plain(item, file=True)) for item in control_paths}, "frozen_module_sha256": pins,
        "baseline_auxiliary_files": cfg["baseline_auxiliary_files"], "all_native_core_phases_closed_pass": list(CORE_PHASES),
        "other_native_acceptance_phases_not_qualified_by_encoder": [*native.ACCEPTANCE_PHASES, "acceptance-summary"],
        "excerpt": {"explicit_excerpt": True, "complete_original_capture": False, "source_indices_zero_based": list(range(FRAME_COUNT)),
            "selected_frame_count": FRAME_COUNT, "canvas_size": list(SIZE), "timing": timing,
            "selection": "Contiguous first75 actual recorded frames; no frame omitted within excerpt",
            "scope": "Native900 diagnostic production-canvas clone with actors/counters/labels; actual full UI and native1800 originals retained unchanged"}}
    return binding, [capture_root / frames[index]["board900_file"] for index in range(FRAME_COUNT)], delays, decoded


def output_paths(layout, binding):
    directory = layout.workspace / "preview_artifacts"
    stem = "hidden-first75-excerpt-" + binding["capture_json_sha256"][:12] + "-900"
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
    # adapt only this local proof's provenance to the actual closed Hidden cohort.
    result = dict(verify_apng(data, paths, delays))
    require(result.get("all_frames_exact_rgba") is True and result.get("selected_frame_count") == FRAME_COUNT and
        result.get("source_indices_zero_based") == list(range(FRAME_COUNT)) and result.get("canvas_size") == list(SIZE),
        "Borrowed pure recomposition proof does not match selected75 native frames")
    result["original_frame_count"] = binding["original_full_frame_count"]
    result["original_frame_count_origin"] = "Actual closed Hidden capture measured_frame_count and full native PNG ledger"
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
        not native.guard.ERROR_LINE.search((evidence / "worker.log").read_text(encoding="utf-8", errors="replace")), "Prior Hidden APNG phase is not exact closed PASS")
    validate_decoded(proof, binding)
    return proof


def worker(args):
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    record = read_json(evidence / "storage-manifest.json")
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
        **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and same_path(layout.workspace, WORKSPACE) and same_path(layout.evidence, evidence) and
        layout.run_id == args.run_prefix + "-" + args.phase, "Exact prepared Hidden APNG worker ownership required")
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
                handle.write("# Non-active faithful Hidden first75-frame excerpt.\n")
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
            1 <= args.timeout <= 1200, "Explicit separate Hidden APNG workspace/fresh prefix/timeout required")
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
        require(native.selected.qualified_job(job) and not native.guard.ERROR_LINE.search((layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")), "Hidden APNG Job failed or did not close cleanly at zero")
        proof_path = layout.evidence / "worker-proof.json"
        proof = read_json(proof_path)
        require(proof.get("status") == "WORKER_PASS_PENDING_JOB_CLOSE" and proof.get("source_binding") == binding and
            proof.get("source_png_hashes_unchanged") is True and proof.get("all_full_original_png_payloads_decoded") is True and
            len(proof.get("full_png_payload_decode_ledger", [])) == len(binding["full_png_inventory"]) and capture_inputs(args)[0] == binding,
            "Closed Hidden APNG source/PNG decode proof differs")
        validate_decoded(proof, binding)
        receipt = {"schema": SCHEMA, "phase": args.phase, "status": "PASS", "job_receipt": str(layout.evidence / "job.json"),
            "job_sha256": sha(layout.evidence / "job.json"), "log_sha256": sha(layout.evidence / "worker.log"),
            "proof": str(proof_path), "proof_sha256": sha(proof_path), "explicit_excerpt": True, "complete_original_capture": False, "art_approval": False, "test_updated": False}
        if args.phase == "verify":
            require(proof.get("verification", {}).get("all_frames_exact_rgba") is True, "Exact75-frame RGBA recomposition proof absent")
            write_new(final, {**proof, "status": "EXACT_LOSSLESS_HIDDEN_FIRST75_EXCERPT_VERIFIED", "closed_verify_receipt": receipt}, layout)
            receipt.update(output=proof["output"], final_proof=str(final))
        write_new(layout.evidence / "phase-result.json", receipt, layout)
        print(json.dumps(receipt), flush=True)
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, IndexError, struct.error, zlib.error, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "HIDDEN_APNG_STOPPED", "phase": args.phase, "error": str(error), "fallback_attempted": False,
            "original_frames_modified": False, "test_updated": False}), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
