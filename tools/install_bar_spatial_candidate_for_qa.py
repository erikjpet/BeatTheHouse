"""Install the exact static-reviewed Bar candidate into the admitted QA copy only."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil

from bth_qa_storage import Layout, validate_layout
from bar_spatial_candidate_check import ACTIVE_HASHES, source_inventory

CANDIDATE_SHA256 = "5df5041dabe3d674c31bf201cf8c6ee270f7694cc45cdc59a3326f7bd1d0412d"
MASTER_REL = "assets/art/environments/bar/background.png"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--version", choices=("v2", "v4"), default="v2")
    args = parser.parse_args()
    candidate_sha = CANDIDATE_SHA256 if args.version == "v2" else "a870d3652a72d3ebb5067fe9e46b412f3c2a5b938a40e4c3b2cf72e0be7a2408"
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    m = json.loads((evidence / "storage-manifest.json").read_text())
    layout = Layout(**{k: Path(v) for k, v in m["paths"].items()},
                    **{k: m[k] for k in ("run_id", "token", "prepared", "expected_write_bytes", "reserve_bytes")})
    source = args.source_root.resolve(strict=True)
    if source == layout.workspace.resolve():
        raise ValueError("QA copy must be separate from the active source")
    before = source_inventory(source)
    if any(before.get(name) != expected for name, expected in ACTIVE_HASHES.items()):
        raise ValueError("Active baseline custody mismatch")
    review_path = source / ("docs/testing/bar_spatial_r2_static_review_" + args.version + "_20261116.json")
    review = json.loads(review_path.read_text())
    if (review["verdict"], review["candidate_sha256"]) != ("GO_FOR_NATIVE_TRIAL_ONLY", candidate_sha):
        raise ValueError("Exact independent static trial gate is missing")
    candidate = layout.workspace / ("candidate_sources/bar-spatial-r2-assembled-" + args.version + ".png")
    target = layout.workspace / MASTER_REL
    baseline = layout.workspace / "candidate_sources/bar-r4-native-baseline.png"
    validate_layout(layout, extra_write_paths=(target.parent, baseline.parent))
    previous_qa_sha = ACTIVE_HASHES[MASTER_REL] if args.version == "v2" else CANDIDATE_SHA256
    if sha(candidate) != candidate_sha or sha(target) != previous_qa_sha:
        raise ValueError("Candidate or QA baseline identity mismatch; no overwrite")
    if args.version == "v2":
        if baseline.exists():
            raise ValueError("QA baseline backup already exists; inspect existing trial instead of reinstalling")
        with baseline.open("xb") as handle:
            handle.write(target.read_bytes())
    elif not baseline.is_file() or sha(baseline) != ACTIVE_HASHES[MASTER_REL]:
        raise ValueError("Original R4 QA baseline was not preserved")
    shutil.copyfile(candidate, target)
    if sha(target) != candidate_sha:
        raise ValueError("QA candidate copy mismatch")
    if source_inventory(source) != before:
        raise ValueError("Active source changed during isolated QA installation")
    result = {"schema": "bth.bar_candidate_qa_install/v1", "task_id": "BTH-ENV-SPATIAL-BAR-001",
              "observed_at": datetime.now(timezone.utc).isoformat(), "candidate_sha256": candidate_sha,
              "candidate_version": args.version, "previous_qa_sha256": previous_qa_sha,
              "qa_target": str(target), "preserved_qa_baseline": str(baseline),
              "baseline_sha256": sha(baseline), "static_review": str(review_path),
              "static_review_sha256": sha(review_path), "active_source_unchanged": True,
              "production_art_written": False, "test_updated": False,
              "scope": "Exact reviewed candidate installed only in admitted QA source; native qualification pending."}
    with (evidence / "bar-candidate-qa-install.json").open("x", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
