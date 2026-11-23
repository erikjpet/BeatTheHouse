"""Resolve synthetic test storage from the normal guarded-run custody record."""
import hashlib
import json
import os
from pathlib import Path

import bth_qa_storage as guard


def _read_claimed_json(path):
    guard._inspect(path.parent)
    if guard._probe(path) != (True, False, False):
        raise AssertionError("A plain guarded-run receipt is required: " + str(path))
    with path.open("rb") as stream:
        data = stream.read(65537)
    if len(data) > 65536:
        raise AssertionError("Oversize guarded-run receipt: " + str(path))
    return json.loads(data), hashlib.sha256(data).hexdigest()


def prepared_test_temp():
    env = os.environ
    run_root = guard._path(env.get("BTH_QA_RUN_DIR", ""))
    evidence = guard._path(env.get("BTH_QA_EVIDENCE_DIR", ""))
    if (run_root.parent.name.lower() != "runs"
            or run_root.name.lower() == "crew-fresh-cj2-261116"
            or guard._key(evidence) != guard._key(run_root / "evidence")):
        raise AssertionError("A fresh guarded run and its own evidence directory are required")

    receipt, digest = _read_claimed_json(evidence / "storage-manifest.json")
    claim, _ = _read_claimed_json(evidence / "launch-claim.json")
    if (receipt.get("schema") != guard.SCHEMA or receipt.get("prepared") is not True
            or claim.get("schema") != "bth.qa_launch_claim/v1"
            or claim.get("manifest_sha256") != digest):
        raise AssertionError("An exact, claimed, fresh prepared storage manifest is required")

    layout = guard.Layout(
        **{name: guard._path(value) for name, value in receipt["paths"].items()},
        run_id=receipt["run_id"], token=receipt["token"],
        expected_write_bytes=receipt["expected_write_bytes"],
        reserve_bytes=receipt["reserve_bytes"], prepared=True,
    )
    if (guard._key(layout.run_root) != guard._key(run_root)
            or guard._key(layout.evidence) != guard._key(evidence)):
        raise AssertionError("Guarded run/evidence paths must match the claimed manifest")
    # The production gate verifies exact prepared manifest identity, writable path
    # ownership, current capacity, cwd and every controlled environment variable.
    guard.check_launch(layout, cwd=Path.cwd(), env=env)
    return layout.temp
