"""Encode a future closed Grand capture losslessly, with its actual frame clocks.

Plan/encode/verify each use a fresh admitted E: capped Job. Workers launch no
children. This tool never starts Godot/FFmpeg, publishes, contacts the network,
or writes to the original capture or native source. The frozen Bar codec supplies
only its pure sparse APNG encoder and independent RGBA recomposition verifier.
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
import stat
import struct
import zipfile
import zlib

import encode_bar_spatial_apng as codec
from bth_qa_guarded_run import execute
from bth_qa_storage import Layout, plan_layout, prepare_layout, validate_layout


ROOT = Path("E:/CodexQA/BTH")
WORKSPACE = ROOT / "workspaces/BTH-ENV-SPATIAL-GRAND-APNG-20261116"
CODEC_SHA256 = "055cb411dd3cc10b36ce9001658d9f4cb5369f4c7e4ae7e31fe86ac921e72329"
SCHEMA = "bth.grand_spatial_apng_phase/v1"
SIZE = (900, 430)
MAX_FRAMES = 160
DENOMINATOR = 10000
LAST_TICKS = 200
MAX_BYTES = 10 * 1024 ** 2
ERROR_LINE = re.compile(r"(?:SCRIPT ERROR|(?<![A-Z])ERROR):")
ANIMATION_IDS = tuple(["casino_light_" + str(i) for i in range(5)] + ["casino_sign_pulse"] +
                      ["casino_sparkle_" + str(i) for i in range(3)] + ["floor_glint_" + str(i) for i in range(7)])
SCENARIOS = ("__none", "grand_casino_gala_night", "grand_casino_convention_crowd", "grand_casino_audit_night")
ORIGINAL_HELPERS = {
    "tools/envart_grand_context_trace.gd": "171db50e200a1a07c20e01a27bbd13451dd452fc20b411bdac6103821b8faa74",
    "tools/envart_grand_animation_probe.gd": "0c91a3cad63255e3f075fec1649a08f845a2c5c605f7bc61052ec4e305ca0178",
    "tools/envart_grand_animation_capture.gd": "dd4ba3f0c0f646e983c86e8f6b6ea8a30c0ec65613dce3dc90e97d789e1f3976",
    "tools/environment_art_baseline_capture.gd": "89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
    "tools/environment_layout_screenshots.gd": "eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5",
}
require, sha, ordinary_file, qualified_job = codec.require, codec.sha, codec.ordinary_file, codec.qualified_job


def read_json(path):
    return json.loads(ordinary_file(path).read_text(encoding="utf-8-sig"))


def canonical_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def same_path(left, right):
    return codec.same_path(left, right)


def full_hash(value, length, label):
    require(isinstance(value, str) and re.fullmatch(r"[a-f0-9]{%d}" % length, value) is not None and value != "0" * length,
            "Grand requires full nonzero lowercase " + label)


def safe_relative(value):
    require(isinstance(value, str) and value and "\\" not in value and ":" not in value,
            "Invalid source-relative filename")
    path = Path(value)
    require(not path.is_absolute() and ".." not in path.parts and path.as_posix() == value, "Unsafe relative input: " + value)
    return path


def storage_binding(evidence, job):
    manifest_path = ordinary_file(evidence / "storage-manifest.json")
    claim_path = ordinary_file(evidence / "launch-claim.json")
    manifest, claim = read_json(manifest_path), read_json(claim_path)
    require(job.get("schema") == "bth.qa_guarded_run/v1" and
            manifest.get("schema") == "bth-qa-storage/v1" and manifest.get("prepared") is True and
            same_path(manifest.get("paths", {}).get("evidence", ""), evidence) and
            same_path(job.get("storage_manifest", ""), manifest_path) and
            sha(manifest_path) == job.get("storage_manifest_sha256") == claim.get("manifest_sha256"),
            "Closed Grand Job, launch claim and prepared storage manifest differ")
    return manifest


def source_inventory(project):
    """Same source exclusions as the native adapter; never inspect user saves."""
    result = {}
    for directory, dirs, files in os.walk(project):
        current = Path(directory)
        if current == project:
            dirs[:] = [name for name in dirs if name != ".godot"]
        for name in dirs:
            item = current / name
            info = item.lstat()
            require(not (getattr(info, "st_file_attributes", 0) & 0x400) and not stat.S_ISLNK(info.st_mode),
                    "Reparse source directory forbidden: " + str(item))
        for name in files:
            item = current / name
            relative = item.relative_to(project).as_posix()
            if relative in ("grand_capture_inputs.json", "grand_spatial_source_identity.json"):
                continue
            result[relative] = sha(ordinary_file(item))
    return result


def clock_delays(clocks):
    require(2 <= len(clocks) <= MAX_FRAMES and all(type(value) in (int, float) and math.isfinite(value) for value in clocks),
            "Grand capture needs 2..160 genuine finite clocks")
    values = [Decimal(str(value)) for value in clocks]
    intervals = [b - a for a, b in zip(values, values[1:])]
    require(all(value > 0 for value in intervals), "Grand capture clocks must strictly increase")
    ticks = [int((value * DENOMINATOR).quantize(Decimal(1), rounding=ROUND_HALF_UP)) for value in intervals] + [LAST_TICKS]
    require(all(0 < tick < 65536 for tick in ticks), "Actual clock interval cannot be represented by positive n/10000 APNG delay")
    elapsed, errors = Decimal(0), []
    for index, clock in enumerate(values):
        errors.append(abs(elapsed - (clock - values[0])))
        elapsed += Decimal(ticks[index]) / DENOMINATOR
    span = values[-1] - values[0]
    require(max(errors) <= Decimal("0.05") and abs(elapsed - span - Decimal("0.02")) <= Decimal("0.05"),
            "Grand rounded frame clocks drift more than 50ms")
    return ticks, {"frames": len(values), "first_scene_clock": str(values[0]), "last_scene_clock": str(values[-1]),
        "scene_clock_span_seconds": str(span), "duration_seconds": str(elapsed), "maximum_frame_clock_error_seconds": str(max(errors)),
        "denominator": DENOMINATOR, "delay_numerators": ticks, "last_frame_ticks": LAST_TICKS,
        "last_frame_policy": "Explicit final 20ms presentation hold; not an additional captured frame",
        "loop_boundary": "Infinite playback returns to the authentic first frame after the final hold; no interpolation or synthetic FPS"}


def png_size(path):
    with ordinary_file(path).open("rb") as handle:
        header = handle.read(24)
    require(len(header) == 24 and header[:8] == codec.SIGNATURE and header[12:16] == b"IHDR", "Invalid original PNG header")
    return struct.unpack_from(">II", header, 16)


def capture_inputs(args):
    path = ordinary_file(args.capture_json)
    require(path.name == "animation_capture.json" and path.parent.name == "capture" and path.parent.parent.name == "evidence" and
            path.resolve().is_relative_to((ROOT / "runs").resolve(strict=True)), "Grand capture must be original admitted E run evidence")
    require(sha(path) == args.capture_json_sha256, "Grand capture JSON differs from its explicit SHA256")
    evidence = path.parent.parent
    receipt_path, job_path, inputs_path = evidence / "phase-result.json", evidence / "job.json", evidence / "trial-inputs.json"
    receipt, job, inputs = read_json(receipt_path), read_json(job_path), read_json(inputs_path)
    cfg = inputs.get("source_config", {})
    cfg_sha = canonical_sha(cfg)
    require(cfg.get("schema") == "bth.grand_spatial_trial_inputs/v1" and
            cfg_sha == inputs.get("source_config_sha256") == receipt.get("source_config_sha256") and
            cfg.get("source_commit") == args.source_commit == receipt.get("source_commit") and
            inputs.get("engine_campaign_admission") is True and job.get("command") == inputs.get("command"),
            "Grand native source_config/command/commit/admission differs from the closed phase")
    require(receipt.get("schema") == "bth.grand_spatial_trial_phase/v1" and receipt.get("phase") == "capture" and
            receipt.get("status") == "PASS" and same_path(receipt.get("job_receipt", ""), job_path) and qualified_job(job),
            "Grand source capture is not closed PASS at zero under exact guarded caps")
    storage = storage_binding(evidence, job)
    project, campaign = Path(cfg["project"]), Path(cfg["workspace"])
    require(same_path(storage["paths"]["workspace"], project) and project.is_relative_to(campaign) and
            campaign.resolve().is_relative_to(ROOT.resolve(strict=True)) and
            not (args.workspace.resolve().is_relative_to(campaign.resolve()) or campaign.resolve().is_relative_to(args.workspace.resolve())),
            "Grand encoder output must be disjoint from its native project/campaign")
    require(not ERROR_LINE.search(ordinary_file(evidence / "worker.log").read_text(encoding="utf-8", errors="replace")),
            "Grand native capture log contains ERROR/SCRIPT ERROR")
    artifacts = receipt.get("artifacts", {})
    require(same_path(artifacts.get("report", ""), path) and artifacts.get("sha256") == args.capture_json_sha256,
            "Closed Grand phase does not identify the explicit capture report")
    identity_path = project / "grand_spatial_source_identity.json"
    capture_inputs_path = project / "grand_capture_inputs.json"
    installed_path, prepared_path = project / "qa_reference/candidate-install.json", project / "qa_reference/prepared-source.json"
    identity, captured_inputs = read_json(identity_path), read_json(capture_inputs_path)
    installed, prepared = read_json(installed_path), read_json(prepared_path)
    identity_evidence = Path(cfg["qa_root"]) / "runs" / (cfg["run_prefix"] + "-identity") / "evidence"
    identity_receipt, identity_job = read_json(identity_evidence / "phase-result.json"), read_json(identity_evidence / "job.json")
    identity_inputs = read_json(identity_evidence / "trial-inputs.json")
    require(identity_receipt.get("schema") == "bth.grand_spatial_trial_phase/v1" and identity_receipt.get("phase") == "identity" and
            identity_receipt.get("status") == "PASS" and identity_receipt.get("source_config_sha256") == cfg_sha and
            identity_inputs.get("source_config") == cfg and identity_inputs.get("source_config_sha256") == cfg_sha and
            identity_job.get("command") == identity_inputs.get("command") and
            same_path(identity_receipt.get("job_receipt", ""), identity_evidence / "job.json") and qualified_job(identity_job),
            "Grand current-source identity phase is not the exact closed guarded PASS")
    storage_binding(identity_evidence, identity_job)
    qualified = identity_receipt["artifacts"]
    require(sha(identity_path) == qualified.get("identity_sha256") and
            sha(capture_inputs_path) == qualified.get("capture_inputs_sha256") == identity.get("capture_inputs_sha256") and
            identity.get("schema") == "bth.grand_current_source_identity/v1" and
            identity.get("source_commit") == prepared.get("source_commit") == args.source_commit and
            identity.get("source_tree") == prepared.get("source_tree") and
            identity.get("source_config_sha256") == prepared.get("source_config_sha256") == cfg_sha and
            identity.get("candidate_package_sha256") == installed.get("package_sha256") ==
            qualified.get("candidate_package_sha256") == args.candidate_package_sha256,
            "Grand current source/candidate22 identity differs")
    full_hash(identity.get("source_tree"), 40, "source tree")
    source_hashes = source_inventory(project)
    require(source_hashes == identity.get("files") == captured_inputs.get("source_hashes"),
            "Original Grand committed source, candidate, canonical UIDs or QA controls changed")
    files = installed.get("files", {})
    expected = {"assets/art/environments/grand_casino/anim/" + name + ".png" for name in ANIMATION_IDS} | {
        "assets/art/environments/grand_casino/background.png", "data/art/environments/grand_casino.json", "data/art/environments/index.json",
        *("assets/art/environments/grand_casino/counters/" + name + ".png" for name in ("grand_table_left", "grand_table_right", "grand_host_station"))}
    require(set(files) == expected and len(files) == 22 and
            hashlib.sha256("\n".join(name + " " + files[name] for name in sorted(files)).encode()).hexdigest() == args.candidate_package_sha256 and
            all(source_hashes.get(name) == value for name, value in files.items()), "Actual Grand candidate22 payload/hash differs")
    spec_path = project / "data/art/environments/grand_casino.json"
    spec = read_json(spec_path)
    require(tuple(row.get("id") for row in spec.get("animations", [])) == ANIMATION_IDS and
            sum(row.get("web_low_detail") is True for row in spec["animations"]) == 7, "Grand16/7 manifest inventory differs")
    require(cfg.get("original_observer_hashes") == ORIGINAL_HELPERS, "Original Grand capture observer closure differs")
    observer_archive = ordinary_file(project / "qa_reference/grand-public-r4-originals.zip")
    with zipfile.ZipFile(observer_archive) as archived:
        for name, expected_sha in ORIGINAL_HELPERS.items():
            original = archived.read(name)
            active = ordinary_file(project / name).read_bytes()
            row = identity.get("original_observers", {}).get(name, {})
            require(hashlib.sha256(original).hexdigest() == row.get("original_sha256") == expected_sha and
                    sha(project / name) == row.get("active_sha256") and row.get("original_assertions_unchanged") is True and
                    original.replace(b"\r\n", b"\n") == active.replace(b"\r\n", b"\n"), "Grand active observer/helper bytes differ: " + name)
    native_adapter = ordinary_file(Path(__file__).with_name("grand_spatial_native_trial.py"))
    require(sha(native_adapter) == cfg.get("adapter_sha256"), "Grand native adapter changed since authentic capture")
    require({"bth_qa_storage.py", "bth_qa_guarded_run.py", "bar_spatial_native_suite.py", "bar_spatial_candidate_check.py"}.issubset(cfg.get("dependencies", {})),
            "Grand native dependency closure is incomplete")
    for name, expected_sha in cfg.get("dependencies", {}).items():
        require(sha(ordinary_file(Path(__file__).with_name(name))) == expected_sha, "Grand captured adapter dependency changed: " + name)
    decoder_path = ordinary_file(Path(codec.decode_png.__code__.co_filename))
    require(sha(ordinary_file(Path(codec.__file__))) == CODEC_SHA256 and codec.SIZE == SIZE and
            codec.DENOMINATOR == DENOMINATOR and codec.LAST_TICKS == LAST_TICKS and
            cfg.get("dependencies", {}).get("bar_spatial_candidate_check.py") == sha(decoder_path),
            "Frozen Bar lossless codec or independent PNG decoder differs")
    metadata = read_json(path)
    frames = metadata.get("frames", [])
    count = len(frames)
    require(2 <= count <= MAX_FRAMES and artifacts.get("frames") == metadata.get("measured_frame_count") == count and
            metadata.get("archetype") == "grand_casino" and metadata.get("scenario") in SCENARIOS and
            metadata.get("layer") == "" and
            metadata.get("pack_active") is True and metadata.get("board900_is_qa_clone") is True and
            metadata.get("board900_size") == list(SIZE) and metadata.get("board2x_size") == [1800, 860] and
            metadata.get("native_art_layers_only") is True and "no pointer input during capture" in metadata.get("note", ""),
            "Authentic full-app/native-art/900-clone Grand capture contract differs")
    for key in ("actual_arrival_wait", "board900_arrival_wait"):
        arrival = metadata.get(key, {})
        require(arrival.get("remaining_person_transits") == 0 and arrival.get("input_during_wait") is False and
                arrival.get("positions_modified") is False, "Grand natural actor-arrival control differs")
    reduced = metadata.get("reduce_motion", {})
    require(reduced.get("active") is True and reduced.get("production_art_texture_pixels_stable") is True,
            "Actual production Grand Reduce Motion art stability proof is missing")
    require(reduced.get("full_app_file") == "reduce_motion_play.png" and reduced.get("native_art_file") == "reduce_motion_board2x.png",
            "Grand Reduce Motion original filenames differ")
    for name, dimensions in (("settled_play.png", (1280, 720)), ("settled_board900.png", SIZE),
            ("reduce_motion_play.png", (1280, 720)), ("reduce_motion_board2x.png", (1800, 860)),
            ("reduce_motion_play_after.png", (1280, 720))):
        require(png_size(path.parent / name) == dimensions, "Required settled/Reduce Motion Grand PNG is missing or has wrong dimensions: " + name)
    require(tuple(row.get("id") for row in metadata.get("animation_inventory", [])) == ANIMATION_IDS,
            "Original sixteen-entry Grand capture inventory differs")
    equivalence = metadata.get("board900_equivalence", [])
    require(len(equivalence) == count and all(row.get("frame") == index and all(row.get(key) is True for key in
            ("actor_route_clock_equal", "animation_clock_equal", "object_layout_equal", "objects_equal")) for index, row in enumerate(equivalence)),
            "Every Grand clone clock/layout/object equivalence row must be true")
    command = inputs["command"]
    out_arguments = [token.removeprefix("--out=") for token in command if isinstance(token, str) and token.startswith("--out=")]
    excerpt_arguments = [token.removeprefix("--excerpt-seconds=") for token in command if isinstance(token, str) and token.startswith("--excerpt-seconds=")]
    require(len(excerpt_arguments) == 1 and math.isfinite(float(excerpt_arguments[0])) and
            0 < float(excerpt_arguments[0]) <= 20 and type(metadata.get("max_animation_cycle")) in (int, float) and
            math.isfinite(metadata["max_animation_cycle"]) and metadata["max_animation_cycle"] > 0 and
            type(metadata.get("capture_seconds_requested")) in (int, float) and
            abs(metadata["capture_seconds_requested"] - min(metadata["max_animation_cycle"] + 0.25, 20.0, float(excerpt_arguments[0]))) < 1e-5,
            "Grand actual capture excerpt bound differs from its command")
    require(isinstance(command, list) and command[0] == cfg.get("engine") and
            command.count("--path") == 1 and same_path(command[command.index("--path") + 1], project) and
            command.count("--script") == 1 and command[command.index("--script") + 1] == "res://tools/envart_grand_animation_capture.gd" and
            len(out_arguments) == 1 and same_path(out_arguments[0], path.parent) and "--archetype=grand_casino" in command and
            "--scenario=" + metadata["scenario"] in command,
            "Closed Grand capture command does not match actual project/helper/output/scenario")
    paths, clocks = [], []
    for index, frame in enumerate(frames):
        clock = frame.get("clock")
        require(type(clock) in (int, float) and math.isfinite(clock) and frame.get("board900_clock") == clock and
                tuple(row.get("id") for row in frame.get("animation_states", [])) == ANIMATION_IDS and
                (frame.get("width"), frame.get("height")) == (1280, 720), "Grand actual frame clocks/inventory/full-app size differs")
        for key, prefix, dimensions in (("file", "frame", (1280, 720)), ("board900_file", "board900", SIZE), ("board2x_file", "board2x", (1800, 860))):
            require(frame.get(key) == f"{prefix}_{index:03d}.png", "Unexpected original Grand frame filename")
            require(png_size(path.parent / safe_relative(frame[key])) == dimensions, "Original Grand frame dimensions differ")
        paths.append(path.parent / frame["board900_file"])
        clocks.append(clock)
    delays, timing = clock_delays(clocks)
    span = float(timing["scene_clock_span_seconds"])
    require(type(metadata.get("actual_clock_span")) in (int, float) and math.isfinite(metadata["actual_clock_span"]) and
            abs(span - metadata["actual_clock_span"]) < 1e-5 and abs(span - artifacts.get("actual_clock_span", -1)) < 1e-5,
            "Grand actual measured clock span differs from its closed native report")
    pngs = sorted(path.parent.rglob("*.png"), key=lambda item: item.relative_to(path.parent).as_posix())
    require(count * 3 + 5 <= len(pngs) <= count * 3 + 32, "Grand original capture PNG/control inventory differs")
    claim_start = read_json(evidence / "launch-claim.json").get("claimed_epoch")
    require(type(claim_start) in (int, float) and math.isfinite(claim_start) and claim_start < job["finished_epoch"],
            "Native capture launch/finish interval is invalid")
    png_stats = {}
    for item in pngs:
        info = ordinary_file(item).stat()
        require(claim_start - 0.01 <= info.st_mtime <= job["finished_epoch"] + 0.01,
                "Original capture PNG was modified outside the closed native Job write window: " + str(item))
        png_stats[item.relative_to(path.parent).as_posix()] = {"bytes": info.st_size, "modified_ns": info.st_mtime_ns}
    sources = {item.relative_to(path.parent).as_posix(): sha(ordinary_file(item)) for item in pngs}
    controls = [path, receipt_path, job_path, inputs_path, evidence / "worker.log", evidence / "storage-manifest.json", evidence / "launch-claim.json",
        identity_path, capture_inputs_path, installed_path, prepared_path, observer_archive, spec_path, native_adapter,
        identity_evidence / "phase-result.json", identity_evidence / "job.json", identity_evidence / "storage-manifest.json",
        identity_evidence / "launch-claim.json", identity_evidence / "worker.log", identity_evidence / "trial-inputs.json", decoder_path, Path(codec.__file__)]
    controls += [project / name for name in ORIGINAL_HELPERS]
    controls += [Path(__file__).with_name(name) for name in cfg.get("dependencies", {})]
    engine = ordinary_file(Path(cfg["engine"]))
    runtime = ordinary_file(engine.with_name("Godot_v4.6-stable_win64.exe"))
    require(sha(engine) == cfg.get("engine_sha256") and sha(runtime) == cfg.get("runtime_sha256"),
            "Captured Grand engine/runtime input bytes changed")
    controls += [engine, runtime]
    binding = {"capture_json": str(path), "capture_json_sha256": args.capture_json_sha256,
        "source_commit": args.source_commit, "source_tree": identity["source_tree"], "source_config_sha256": cfg_sha,
        "candidate_22_file_sha256": args.candidate_package_sha256, "candidate_files": files,
        "native_project": str(project), "native_campaign": str(campaign), "source_identity_sha256": sha(identity_path),
        "source_inventory_sha256": canonical_sha(source_hashes), "source_inventory_count": len(source_hashes),
        "controls_sha256": {str(item): sha(ordinary_file(item)) for item in controls}, "source_png_sha256": sources,
        "source_png_stat": png_stats, "source_png_native_write_window_checked": True,
        "png_hash_custody_origin": "Encoding-admission inventory; native closure did not record individual PNG SHA256 values",
        "codec_sha256": CODEC_SHA256, "independent_png_decoder_sha256": sha(decoder_path),
        "scenario": metadata["scenario"], "canvas_size": list(SIZE), "frames": count, "animation_ids": list(ANIMATION_IDS),
        "timing": timing, "board900_source": metadata.get("board900_source"), "source_phase_closed_pass": True,
        "source_job_active_at_release": 0, "all_board_clones_clock_layout_object_equal": True,
        "scope": "Current committed code plus exact non-active candidate22 overlay; full-app and native1800-art originals retained."}
    # This process-local codec setting occurs only after the authentic native
    # receipt, all source/control hashes and all original frame evidence bind.
    codec.FRAME_COUNT = count
    return binding, paths, delays


def output_paths(layout, binding):
    scenario = binding["scenario"].replace("__none", "base")
    stem = "grand-spatial-" + scenario + "-" + binding["capture_json_sha256"][:12] + "-900"
    directory = layout.workspace / "preview_artifacts"
    return directory, directory / (stem + ".png"), directory / (stem + ".proof.json")


def declared_outputs(layout, phase, binding):
    directory, output, proof = output_paths(layout, binding)
    paths = [directory]
    if phase == "encode":
        paths.append(output)
        if not (directory / ".gdignore").exists():
            paths.append(directory / ".gdignore")
        else:
            ordinary_file(directory / ".gdignore")
    if phase == "verify":
        paths.append(proof)
    return tuple(paths)


def write_new(path, data, layout):
    validate_layout(layout, extra_write_paths=(Path(path).parent,))
    with Path(path).open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


def prior_phase(prefix, phase, binding):
    evidence = ROOT / "runs" / (prefix + "-" + phase) / "evidence"
    receipt_path, proof_path = evidence / "phase-result.json", evidence / "worker-proof.json"
    receipt, proof, job = read_json(receipt_path), read_json(proof_path), read_json(evidence / "job.json")
    storage_binding(evidence, job)
    require(receipt.get("schema") == SCHEMA and receipt.get("phase") == phase and receipt.get("status") == "PASS" and
            qualified_job(job) and same_path(receipt.get("job_receipt", ""), evidence / "job.json") and
            same_path(receipt.get("proof", ""), proof_path) and receipt.get("active_at_release") == 0 and
            receipt.get("proof_sha256") == sha(proof_path) and proof.get("source_binding") == binding and
            proof.get("adapter_sha256") == sha(__file__) and proof.get("source_png_hashes_unchanged") is True and
            not ERROR_LINE.search(ordinary_file(evidence / "worker.log").read_text(encoding="utf-8", errors="replace")),
            "Prior Grand APNG phase is not the exact closed guarded PASS: " + phase)
    return proof


def load_layout(args):
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    manifest = read_json(evidence / "storage-manifest.json")
    layout = Layout(**{key: Path(value) for key, value in manifest["paths"].items()},
        **{key: manifest[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and same_path(layout.workspace, WORKSPACE) and same_path(layout.evidence, evidence) and
            layout.run_id == args.run_prefix + "-" + args.phase, "Exact prepared Grand APNG worker ownership required")
    return layout


def worker(args):
    layout = load_layout(args)
    binding, paths, delays = capture_inputs(args)
    directory, output, final = output_paths(layout, binding)
    validate_layout(layout, extra_write_paths=declared_outputs(layout, args.phase, binding))
    admitted = read_json(layout.evidence / "phase-inputs.json")
    require(admitted.get("source_binding") == binding and admitted.get("adapter_sha256") == sha(__file__) and
            admitted.get("phase") == args.phase, "Grand APNG source changed after supervisor admission")
    proof = {"schema": SCHEMA, "phase": args.phase, "source_binding": binding, "adapter_sha256": sha(__file__),
        "observed_at": datetime.now(timezone.utc).isoformat(), "art_approval": False, "test_updated": False,
        "child_processes_launched_by_worker": 0}
    if args.phase != "plan":
        prior_phase(args.run_prefix, "plan", binding)
    if args.phase == "encode":
        require(not output.exists() and not final.exists(), "Grand immutable preview/proof already exists")
        data, rectangles = codec.encode_apng(paths, delays)
        verification = codec.verify_apng(data, paths, delays)
        require(capture_inputs(args)[0] == binding, "Grand originals changed during lossless encoding")
        validate_layout(layout, extra_write_paths=(directory,))
        directory.mkdir(exist_ok=True)
        if not (directory / ".gdignore").exists():
            with (directory / ".gdignore").open("x", encoding="utf-8") as handle:
                handle.write("# Non-active faithful Grand native preview.\n")
        ordinary_file(directory / ".gdignore")
        validate_layout(layout, extra_write_paths=(directory,))
        with output.open("xb") as handle:
            handle.write(data)
        proof.update(output={"path": str(output), "sha256": sha(output), "bytes": output.stat().st_size},
                     encoding=rectangles, verification=verification)
    elif args.phase == "verify":
        prior = prior_phase(args.run_prefix, "encode", binding)
        ordinary_file(output)
        require(output.stat().st_size < MAX_BYTES and sha(output) == prior["output"]["sha256"], "Grand immutable APNG bytes differ")
        proof.update(output=prior["output"], verification=codec.verify_apng(output.read_bytes(), paths, delays))
        require(sha(output) == prior["output"]["sha256"], "Grand APNG changed during independent verification")
    after = capture_inputs(args)[0]
    require(after == binding, "Grand source PNGs or controls changed during APNG phase")
    proof.update(source_png_hashes_unchanged=True, source_png_sha256_before=binding["source_png_sha256"],
                 source_png_sha256_after=after["source_png_sha256"], status="WORKER_PASS_PENDING_JOB_CLOSE")
    write_new(layout.evidence / "worker-proof.json", proof, layout)
    print(json.dumps({"status": proof["status"], "phase": args.phase}), flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", "encode", "verify"))
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--capture-json", type=Path, required=True)
    parser.add_argument("--capture-json-sha256", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--candidate-package-sha256", required=True)
    parser.add_argument("--run-prefix", required=True)
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        require(same_path(args.workspace, WORKSPACE), "Use the separate explicit admitted Grand APNG output workspace")
        full_hash(args.capture_json_sha256, 64, "capture JSON SHA256")
        full_hash(args.source_commit, 40, "source commit")
        full_hash(args.candidate_package_sha256, 64, "candidate22 package SHA256")
        require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,70}", args.run_prefix) is not None and 1 <= args.timeout <= 1200,
                "Fresh Grand phase run prefix and bounded timeout1..1200 required")
        if args.worker:
            worker(args)
            return 0
        layout = plan_layout(root=ROOT, workspace=args.workspace, run_id=args.run_prefix + "-" + args.phase)
        binding, _, _ = capture_inputs(args)
        directory, output, final = output_paths(layout, binding)
        outputs = declared_outputs(layout, args.phase, binding)
        validate_layout(layout, extra_write_paths=outputs)
        if args.phase != "plan":
            prior_phase(args.run_prefix, "plan", binding)
        if args.phase == "encode":
            require(not output.exists() and not final.exists(), "Existing Grand APNG/proof cannot be overwritten")
        if args.phase == "verify":
            prior_phase(args.run_prefix, "encode", binding)
            require(not final.exists(), "Existing final Grand proof cannot be overwritten")
        layout = prepare_layout(layout)
        write_new(layout.evidence / "phase-inputs.json", {"phase": args.phase, "source_binding": binding,
            "adapter_sha256": sha(__file__), "declared_outputs": [str(item) for item in outputs]}, layout)
        command = [sys.executable, "-B", str(Path(__file__).absolute()), args.phase, "--worker", "--workspace", str(args.workspace),
            "--capture-json", str(args.capture_json), "--capture-json-sha256", args.capture_json_sha256,
            "--source-commit", args.source_commit, "--candidate-package-sha256", args.candidate_package_sha256,
            "--run-prefix", args.run_prefix, "--timeout", str(args.timeout)]
        print(json.dumps({"status": "STARTING_GUARDED_GRAND_APNG_PHASE", "phase": args.phase, "run_id": layout.run_id}), flush=True)
        job = execute(layout, command, timeout=args.timeout, cpu_rate=1200, extra_write_paths=outputs)
        require(qualified_job(job), "Grand APNG Job failed or did not close at zero; retain its evidence")
        require(not ERROR_LINE.search((layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")), "Grand APNG worker logged ERROR")
        proof_path = layout.evidence / "worker-proof.json"
        proof = read_json(proof_path)
        require(proof.get("status") == "WORKER_PASS_PENDING_JOB_CLOSE" and proof.get("source_binding") == binding and
                proof.get("source_png_hashes_unchanged") is True and capture_inputs(args)[0] == binding,
                "Closed Grand APNG proof or original PNG/control custody differs")
        receipt = {"schema": SCHEMA, "phase": args.phase, "status": "PASS", "job_receipt": str(layout.evidence / "job.json"),
            "active_at_release": 0, "proof": str(proof_path), "proof_sha256": sha(proof_path),
            "art_approval": False, "test_updated": False}
        if args.phase == "verify":
            require(proof.get("verification", {}).get("all_frames_exact_rgba") is True, "Grand full RGBA recomposition proof absent")
            write_new(final, {**proof, "status": "EXACT_LOSSLESS_GRAND_APNG_VERIFIED", "closed_verify_receipt": receipt,
                "scope": "Actual diagnostic900x430 Grand production-canvas clone; full-app/native1800-art originals retained unchanged."}, layout)
            receipt.update(output=proof["output"], final_proof=str(final))
        write_new(layout.evidence / "phase-result.json", receipt, layout)
        print(json.dumps(receipt), flush=True)
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, IndexError, struct.error, zlib.error, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "GRAND_APNG_PHASE_STOPPED", "phase": args.phase, "error": str(error),
            "fallback_attempted": False, "original_frames_modified": False, "test_updated": False}), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
