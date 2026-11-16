"""Materialize exact approved Grand V4 bytes in one fresh guarded campaign.

This is transport, not art generation or assembly. Run only through the maintained
E: capped runner after source_baseline and the original raw trial are prepared.
No children, image decoding/encoding, active assets, profiles or saves are used.
"""
import sys
sys.dont_write_bytecode = True

from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat

from bth_qa_storage import Layout, validate_layout

WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GRANDTRIAL4B-20261116")
OLD_WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GRANDTRIAL-20261116")
PARENT_EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GRANDTRIAL-20261116-assemble08/evidence")
PARENT_PROOF = PARENT_EVIDENCE / "grand-spatial-r1-assembly-v4.json"
PARENT_PROOF_SHA = "a2244588795f89d207c0cf74ea6c2411113d47254969bd058b80c26271931b9b"
PARENT_JOB_SHA = "d4a1cbc3da8b4b8c03580f23ede25851f34dcc3042a90b9d8c6fbb55853182d4"
PARENT_RECIPE = Path(__file__).absolute().with_name("assemble_grand_spatial_candidate_v4.py")
PARENT_RECIPE_SHA = "a41ac9e5fa14cf5409c68989587013aeca9d14044d547b051120f70d2f2016d7"
PACKAGE_SHA = "563ef08fec04e980c9cb2e215b2801f3612a22dd8f8250ba6247293c12f069d4"
BACKGROUND_SHA = "5408ef84bc3d8aec92b0814a8bf446210091f4d6b513be9ba8fff5a64565e9ae"
BASELINE_SHA = "5b4e87763e85358b85fc0ce73232afc8878f132a4294904970c7fdfbd8f30060"
RAW_SHA = "31e7a40bfedcbc68a00a615e400b3df88bab03d180558fd3c88749a410147c63"
ART = "assets/art/environments/grand_casino/"
MANIFEST = "data/art/environments/grand_casino.json"
INDEX = "data/art/environments/index.json"
OUTPUT_NAME = "grand-spatial-r1-assembled-v4"
MAX_FILE_BYTES = 32 * 1024 ** 2
MAX_PACKAGE_BYTES = 128 * 1024 ** 2


def require(condition, message):
    if not condition:
        raise ValueError(message)


def same(left, right):
    return os.path.normcase(os.path.abspath(left)) == os.path.normcase(os.path.abspath(right))


def ordinary(path, *, exists=True):
    path = Path(path)
    require(path.is_absolute(), "Explicit absolute path required: " + str(path))
    for part in (path, *path.parents):
        if part.exists() or part.is_symlink():
            info = part.lstat()
            require(not stat.S_ISLNK(info.st_mode) and not (getattr(info, "st_file_attributes", 0) & 0x400),
                    "Reparse or linked path forbidden: " + str(part))
    resolved = path.resolve(strict=exists)
    require(same(path, resolved), "Noncanonical source/output path: " + str(path))
    return resolved


def read(path, limit=MAX_FILE_BYTES):
    path = ordinary(path)
    require(path.is_file() and path.stat().st_size <= limit, "Expected bounded ordinary file: " + str(path))
    data = path.read_bytes()
    require(len(data) <= limit, "Input grew beyond its bound: " + str(path))
    return data


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sha(path):
    return digest(read(path))


def seal(files):
    return digest("\n".join(name + " " + value for name, value in sorted(files.items())).encode())


def inventory(root):
    root = ordinary(root)
    require(root.is_dir(), "Expected source package directory: " + str(root))
    result = {}
    for path in sorted(root.rglob("*")):
        ordinary(path)
        if path.is_file():
            name = path.relative_to(root).as_posix()
            relative_name(name)
            result[name] = sha(path)
    return result


def relative_name(name):
    require(isinstance(name, str) and name and "\\" not in name, "Invalid package relative path")
    value = PurePosixPath(name)
    require(not value.is_absolute() and not any(part in ("", ".", "..") for part in value.parts)
            and value.as_posix() == name and ":" not in name, "Unsafe package relative path: " + name)
    return name


def qualified_job(job):
    limits = job.get("limits", {})
    return (job.get("pid") == 39944 and job.get("exit_code") == 0 and job.get("active_at_release") == 0
            and job.get("assigned_before_execution") is True
            and all(not job.get(k) for k in ("error", "cleanup_errors", "timed_out", "log_error", "log_truncated"))
            and bool(job.get("storage_gate_before_job")) and bool(job.get("storage_gate_before_child"))
            and limits.get("cpu_rate") == 1200 and limits.get("job_memory_limit_bytes") == 2 * 1024 ** 3
            and limits.get("kill_on_close") is True and limits.get("breakaway_allowed") is False
            and type(job.get("finished_epoch")) in (int, float) and math.isfinite(job["finished_epoch"]))


def load_layout():
    value = os.environ.get("BTH_QA_EVIDENCE_DIR", "")
    require(value and Path(value).is_absolute(), "Guarded explicit evidence environment is required")
    evidence = ordinary(value)
    record = json.loads(read(evidence / "storage-manifest.json").decode("utf-8-sig"))
    layout = Layout(**{k: Path(v) for k, v in record["paths"].items()},
                    **{k: record[k] for k in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and same(layout.workspace, WORKSPACE) and same(layout.root, WORKSPACE.parents[1])
            and same(layout.evidence, evidence), "Only the exact fresh TRIAL4B guarded layout is admitted")
    ordinary(layout.workspace)
    return layout


def baseline_names(baseline):
    spec = json.loads(read(baseline / MANIFEST).decode("utf-8-sig"))
    require(spec.get("environment_id") == "grand_casino" and spec.get("board_size") == [900, 430]
            and spec.get("pixel_scale") == 2 and len(spec.get("animations", [])) == 16
            and len(spec.get("counters", {})) == 3, "Exact original Grand22 package is required")
    names = {ART + "background.png", MANIFEST, INDEX}
    names.update(ART + relative_name(row["texture"]) for row in spec["animations"])
    names.update(ART + relative_name(row["texture"]) for row in spec["counters"].values())
    require(len(names) == 22, "Original package membership must contain exactly22 files")
    return names


def main():
    try:
        require(len(sys.argv) == 1, "No path overrides or alternate workspaces are supported")
        layout = load_layout()  # Actual storage/capacity admission precedes every write.
        source = OLD_WORKSPACE / "candidate_sources" / OUTPUT_NAME
        destination = layout.workspace / "candidate_sources" / OUTPUT_NAME
        report_path = layout.evidence / "grand-spatial-r1-v4-scoped-copy.json"
        validate_layout(layout, extra_write_paths=(destination, report_path))
        ordinary(destination, exists=False)
        require(not destination.exists() and not report_path.exists(), "Exclusive fresh output/report required; never overwrite")
        candidates = ordinary(layout.workspace / "candidate_sources")
        require(not ({p.name for p in candidates.iterdir()} - {"grand-spatial-r1.png", ".gdignore"}),
                "Fresh candidate_sources may contain only the pinned raw PNG and optional ignore marker")
        if (candidates / ".gdignore").exists():
            read(candidates / ".gdignore")
        old_baseline = OLD_WORKSPACE / "source_baseline"
        new_baseline = layout.workspace / "source_baseline"
        names = baseline_names(new_baseline)
        old_base_before, new_base_before = inventory(old_baseline), inventory(new_baseline)
        require(set(old_base_before) == names and old_base_before == new_base_before
                and seal(new_base_before) == BASELINE_SHA, "Both original22-file baseline inventories must remain exact")
        old_raw = OLD_WORKSPACE / "candidate_sources/grand-spatial-r1.png"
        new_raw = candidates / "grand-spatial-r1.png"
        self_path = ordinary(Path(__file__).absolute())
        self_before = sha(self_path)
        proof_bytes, job_bytes = read(PARENT_PROOF), read(PARENT_EVIDENCE / "job.json")
        require(digest(proof_bytes) == PARENT_PROOF_SHA and digest(job_bytes) == PARENT_JOB_SHA
                and sha(PARENT_RECIPE) == PARENT_RECIPE_SHA, "Original V4 producer proof/Job/recipe identity mismatch")
        parent, job = json.loads(proof_bytes), json.loads(job_bytes)
        require(qualified_job(job), "Original V4 producer is not closed guarded PASS/zero with exact resource caps")
        tokens = job.get("command", [])
        require(len(tokens) >= 3 and tokens[1] == "-B" and same(tokens[2], PARENT_RECIPE)
                and parent.get("recipe_sha256") == PARENT_RECIPE_SHA,
                "Original producer command/recipe binding differs")
        files = parent["output"]["files"]
        require(isinstance(files, dict) and set(files) == names and all(
            isinstance(v, str) and re.fullmatch(r"[0-9a-f]{64}", v) for v in files.values())
            and seal(files) == PACKAGE_SHA and parent["output"]["seal"] == PACKAGE_SHA
            and same(parent["output"]["path"], source) and files[ART + "background.png"] == BACKGROUND_SHA,
            "Exact approved V4 output22-file identity mismatch")
        source_before = inventory(source)
        require(source_before == files and sha(old_raw) == sha(new_raw) == RAW_SHA,
                "Original V4 payload or preserved original raw PNG changed")
        payload = {name: read(source / name) for name in sorted(files)}
        require(all(digest(data) == files[name] for name, data in payload.items())
                and sum(map(len, payload.values())) <= min(MAX_PACKAGE_BYTES, layout.expected_write_bytes),
                "Copied bytes differ from approved hashes or exceed admitted write budget")
        inputs = {"original_v4_payload": source_before, "original_baseline": old_base_before,
                  "fresh_campaign_baseline": new_base_before, "original_raw_sha256": RAW_SHA,
                  "parent_proof_sha256": PARENT_PROOF_SHA, "parent_job_sha256": PARENT_JOB_SHA,
                  "parent_recipe_sha256": PARENT_RECIPE_SHA, "copier_sha256": self_before}
        validate_layout(layout, extra_write_paths=(destination, report_path))
        destination.mkdir()  # Parent exists; exclusive, never repurpose an old phase.
        for name, data in payload.items():
            target = destination / relative_name(name)
            validate_layout(layout, extra_write_paths=(target.parent, target))
            ordinary(target.parent, exists=False)
            target.parent.mkdir(parents=True, exist_ok=True)
            ordinary(target.parent)
            with target.open("xb") as handle:
                handle.write(data)  # The original compressed PNG/JSON bytes, no decoding.
        require(inventory(destination) == files and seal(inventory(destination)) == PACKAGE_SHA,
                "Fresh destination is not exactly the same22 approved payload bytes")
        require(inventory(source) == source_before and inventory(old_baseline) == old_base_before
                and inventory(new_baseline) == new_base_before and sha(old_raw) == sha(new_raw) == RAW_SHA
                and sha(PARENT_PROOF) == PARENT_PROOF_SHA and sha(PARENT_EVIDENCE / "job.json") == PARENT_JOB_SHA
                and sha(PARENT_RECIPE) == PARENT_RECIPE_SHA and sha(self_path) == self_before,
                "A preserved source/proof/recipe changed during materialization")
        report = {"schema": "EXACT_APPROVED_CANDIDATE_MATERIALIZATION", "schema_version": 1,
            "task_id": "BTH-ENV-SPATIAL-GRAND-001", "observed_at": datetime.now(timezone.utc).isoformat(),
            "status": "EXACT_APPROVED_CANDIDATE_MATERIALIZATION", "recipe_sha256": self_before,
            "output": {"path": str(destination), "files": files, "seal": PACKAGE_SHA, "file_count": 22},
            "parent_assembly_proof": {"path": str(PARENT_PROOF), "sha256": PARENT_PROOF_SHA,
                "recipe_path": str(PARENT_RECIPE), "actual_recipe_sha256": PARENT_RECIPE_SHA,
                "closed_producer_job": str(PARENT_EVIDENCE / "job.json"),
                "closed_producer_job_sha256": PARENT_JOB_SHA, "producer_pid": 39944,
                "producer_exit_code": 0, "producer_active_at_release": 0},
            "source_inputs_before": inputs, "source_inputs_after": inputs,
            "all_sources_unchanged": True, "all_sources_scope": "Exactly the authenticated read-only inputs listed above",
            "destination_exact_path_set_and_hashes": True, "pixel_generation": False,
            "png_decoding_or_encoding": False, "active_files_written": False, "qa_source_written": False,
            "profiles_or_saves_accessed": False, "child_processes_launched": 0,
            "art_approval": False, "test_updated": False,
            "approval_scope": "Byte-identical transport of existing V4; matching fresh independent transport review remains required",
            "copy_job_closure": "Pending supervisor finalization; this worker does not certify its own exit/zero receipt",
            "storage_manifest": str(layout.manifest_path), "storage_manifest_sha256": sha(layout.manifest_path)}
        validate_layout(layout, extra_write_paths=(report_path,))
        with report_path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(report, handle, indent=2)
            handle.write("\n")
        print(json.dumps({"status": report["status"], "output": str(destination),
                          "seal": PACKAGE_SHA, "report": str(report_path), "pixel_generation": False}))
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        print(json.dumps({"status": "EXACT_CANDIDATE_MATERIALIZATION_STOPPED", "error": str(error),
                          "pixel_generation": False, "active_files_written": False, "fallback_attempted": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
