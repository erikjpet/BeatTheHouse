from copy import deepcopy
from datetime import datetime, timezone
import io
import importlib.util
import json
from pathlib import Path
import os
import tempfile
import unittest
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "check_bth_runtime_inventory.py"
spec = importlib.util.spec_from_file_location("runtime_inventory", MODULE_PATH)
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)
NOW = datetime(2026, 11, 4, 12, 0, tzinfo=timezone.utc)
AT = "2026-11-04T11:59:00Z"
OLD = "2026-11-01T12:00:00Z"


def instance():
    return {
        "instance_id": "runtime-001", "task_id": "BTH-QA-001", "owner_task_ref": "owner-001",
        "kind": "test_job", "ownership": "task_owned", "state": "active",
        "launch_identity": {"nonce": "nonce-001", "key": "job-handle:001@start:001", "started_at": "2026-11-04T11:00:00Z", "evidence": ["launch-receipt.json"]},
        "current_identity": {"state": "match", "observed_at": AT, "key": "job-handle:001@start:001", "evidence": ["owned-job-observation.json"]},
        "activity": {"state": "active", "observed_at": AT, "lease_until": "2026-11-04T12:15:00Z", "evidence": ["owner-checkpoint.json"]},
        "protected": {"saves": False, "shared_resources": False},
        "cleanup": {"contract": {event: ["runtime-finally-and-job-close-tests.json"] for event in runtime.CLEANUP_EVENTS}, "receipt": None},
    }


def inventory(item=None):
    return {"schema": runtime.SCHEMA, "observed_at": AT,
            "scope": {"description": "Explicit task-owned launch records", "complete": True, "evidence": ["record-index.json"]},
            "instances": [item or instance()]}


def owners(state="active"):
    return {"schema": runtime.OWNER_SCHEMA, "observed_at": AT,
            "tasks": [{"task_ref": "owner-001", "state": state, "observed_at": AT}]}


def ended(item):
    item["state"] = "ended"
    item["activity"].update(state="idle", lease_until=None)
    return item


def clean_receipt(item):
    item["cleanup"]["receipt"] = {"observed_at": AT, "outcome": "verified_empty", "identity_nonce": item["launch_identity"]["nonce"], "remaining_count": 0, "evidence": ["zero-active-at-release.json"]}
    item["current_identity"].update(state="unknown", key=None, evidence=[])
    return item


class RuntimeInventoryTests(unittest.TestCase):
    def report(self, item=None, owner=None, **kwargs):
        return runtime.check_inventory(inventory(item), owners() if owner is None else owner, now=NOW, **kwargs)

    def codes(self, report):
        return {entry["code"] for entry in report["findings"]}

    def disposition(self, report):
        return report["instances"][0]["disposition"]

    def test_active_owner_and_fresh_gameplay_are_preserved(self):
        report = self.report()
        self.assertEqual(report["summary"]["errors"], 0)
        self.assertEqual(self.disposition(report), "preserve_active_use")
        self.assertFalse(report["instances"][0]["cleanup_authorized"])

    def test_active_owner_is_preserved_even_when_session_declared_ended(self):
        report = self.report(ended(instance()))
        self.assertIn("RUNTIME_ENDED_WITHOUT_CLEANUP", self.codes(report))
        self.assertEqual(self.disposition(report), "preserve_active_use")

    def test_user_shared_profile_and_protected_save_never_become_candidates(self):
        variants = []
        for ownership in ("user", "shared_service"):
            item = ended(instance())
            item["ownership"] = ownership
            variants.append(item)
        for field in ("saves", "shared_resources"):
            item = ended(instance())
            item["protected"][field] = True
            variants.append(item)
        item = ended(instance())
        item["kind"] = "profile"
        variants.append(item)
        for item in variants:
            with self.subTest(item=item):
                report = self.report(item, owners("ended"))
                self.assertEqual(self.disposition(report), "preserve_protected_resource")
                self.assertNotIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))

    def test_ended_and_superseded_uncleared_instances_flagged(self):
        for state in ("ended", "superseded"):
            item = ended(instance())
            item["state"] = state
            report = self.report(item, owners("ended"))
            self.assertIn("RUNTIME_ENDED_WITHOUT_CLEANUP", self.codes(report))
            self.assertIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))
            self.assertFalse(report["instances"][0]["cleanup_authorized"])

    def test_protection_does_not_hide_unknown_ownership(self):
        for field in ("saves", "shared_resources"):
            item = instance()
            item["ownership"] = "unknown"
            item["protected"][field] = True
            report = self.report(item)
            self.assertIn("RUNTIME_OWNERSHIP_UNKNOWN", self.codes(report))
            self.assertEqual(self.disposition(report), "preserve_protected_resource")
            self.assertGreater(report["summary"]["errors"], 0)

    def test_preserving_saves_does_not_hide_ended_runtime_cleanup_gap(self):
        item = ended(instance())
        item["protected"]["saves"] = True
        report = self.report(item, owners("ended"))
        self.assertIn("RUNTIME_ENDED_WITHOUT_CLEANUP", self.codes(report))
        self.assertEqual(self.disposition(report), "preserve_protected_resource")
        self.assertNotIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))

    def test_idle_owner_does_not_prove_abandonment(self):
        report = self.report(ended(instance()), owners("idle"))
        self.assertIn("RUNTIME_USE_UNCERTAIN", self.codes(report))
        self.assertNotIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))

    def test_unknown_current_use_does_not_become_orphan_candidate(self):
        item = ended(instance())
        item["activity"]["state"] = "unknown"
        report = self.report(item, owners("ended"))
        self.assertIn("RUNTIME_USE_UNCERTAIN", self.codes(report))
        self.assertNotIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))
        self.assertEqual(self.disposition(report), "review_required")
        self.assertFalse(report["instances"][0]["cleanup_authorized"])

    def test_stale_owner_or_snapshot_cannot_make_candidate(self):
        for target in ("snapshot", "task"):
            owner = owners("ended")
            if target == "snapshot":
                owner["observed_at"] = OLD
            else:
                owner["tasks"][0]["observed_at"] = OLD
            report = self.report(ended(instance()), owner)
            self.assertIn("RUNTIME_STALE_OBSERVATION", self.codes(report))
            self.assertNotIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))

    def test_future_owner_activity_identity_snapshot_are_not_current_evidence(self):
        future = "2026-11-05T12:00:00Z"
        for field in ("inventory", "owner", "activity", "identity"):
            item, owner, manifest = ended(instance()), owners("ended"), None
            if field == "owner":
                owner["tasks"][0]["observed_at"] = future
            elif field == "activity":
                item["activity"]["observed_at"] = future
            elif field == "identity":
                item["current_identity"]["observed_at"] = future
            manifest = inventory(item)
            if field == "inventory":
                manifest["observed_at"] = future
            report = runtime.check_inventory(manifest, owner, now=NOW)
            self.assertIn("RUNTIME_FUTURE_OBSERVATION", self.codes(report))
            self.assertNotIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))

    def test_stale_activity_or_identity_cannot_make_candidate(self):
        for field in ("activity", "current_identity"):
            item = ended(instance())
            item[field]["observed_at"] = OLD
            report = self.report(item, owners("ended"))
            self.assertIn("RUNTIME_STALE_OBSERVATION", self.codes(report))
            self.assertNotIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))

    def test_pid_reuse_or_explicit_mismatch_never_make_candidate(self):
        for state, key in (("match", "same-pid@different-start"), ("mismatch", "job-handle:001@start:001")):
            item = ended(instance())
            item["current_identity"].update(state=state, key=key)
            report = self.report(item, owners("ended"))
            self.assertIn("RUNTIME_IDENTITY_MISMATCH", self.codes(report))
            self.assertNotIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))

    def test_unknown_ownership_and_missing_launch_nonce_preserved(self):
        item = ended(instance())
        item["ownership"] = "unknown"
        item["launch_identity"]["nonce"] = None
        report = self.report(item, owners("ended"))
        self.assertIn("RUNTIME_OWNERSHIP_UNKNOWN", self.codes(report))
        self.assertIn("RUNTIME_LAUNCH_IDENTITY_UNKNOWN", self.codes(report))
        self.assertNotIn("RUNTIME_ORPHAN_CANDIDATE", self.codes(report))

    def test_all_cleanup_paths_require_evidence(self):
        item = instance()
        item["cleanup"]["contract"] = {"success": ["happy-path.json"]}
        report = self.report(item)
        finding = next(entry for entry in report["findings"] if entry["code"] == "RUNTIME_CLEANUP_CONTRACT_INCOMPLETE")
        self.assertEqual(finding["evidence"], ["failure", "timeout", "interruption"])

    def test_failed_nonzero_pending_and_uncertain_cleanup_stay_open(self):
        for outcome in ("failed", "pending", "uncertain"):
            item = clean_receipt(ended(instance()))
            item["cleanup"]["receipt"].update(outcome=outcome, remaining_count=2)
            report = self.report(item, owners("ended"))
            self.assertIn("RUNTIME_CLEANUP_" + outcome.upper(), self.codes(report))
            self.assertIn("RUNTIME_RESOURCES_REMAIN", self.codes(report))
            self.assertNotEqual(self.disposition(report), "historical_cleanup_verified")

    def test_nonce_bound_zero_receipt_is_historical_only(self):
        item = clean_receipt(ended(instance()))
        report = self.report(item, owners("ended"))
        self.assertEqual(self.disposition(report), "historical_cleanup_verified")
        self.assertIn("RUNTIME_CURRENT_IDENTITY_UNKNOWN", self.codes(report))
        self.assertIn("historical", " ".join(report["limitations"]).lower())

    def test_wrong_nonce_and_nonzero_clean_receipt_not_accepted(self):
        for bad in ("nonce", "nonzero", "timestamp", "evidence"):
            item = clean_receipt(ended(instance()))
            receipt = item["cleanup"]["receipt"]
            if bad == "nonce":
                receipt["identity_nonce"] = "other-launch"
            elif bad == "nonzero":
                receipt["remaining_count"] = 1
            elif bad == "timestamp":
                receipt["observed_at"] = OLD
            else:
                receipt["evidence"] = []
            report = self.report(item, owners("ended"))
            self.assertIn("RUNTIME_CLEANUP_RECEIPT_UNVERIFIED", self.codes(report))
            self.assertNotEqual(self.disposition(report), "historical_cleanup_verified")

    def test_later_matching_identity_contradicts_clean_receipt(self):
        item = clean_receipt(ended(instance()))
        item["current_identity"].update(state="match", key=item["launch_identity"]["key"], evidence=["later-owned-job.json"])
        report = self.report(item, owners("ended"))
        self.assertIn("RUNTIME_CLEANUP_CONTRADICTED", self.codes(report))
        self.assertNotEqual(self.disposition(report), "historical_cleanup_verified")

    def test_exact_absence_can_resolve_launch_without_term_action(self):
        item = ended(instance())
        item["current_identity"].update(state="absent", key=None)
        report = self.report(item, owners("ended"))
        self.assertEqual(self.disposition(report), "recorded_launch_absent")
        self.assertNotIn("RUNTIME_ENDED_WITHOUT_CLEANUP", self.codes(report))

    def test_missing_owners_and_incomplete_scope_remain_open(self):
        manifest = inventory()
        manifest["scope"]["complete"] = False
        report = runtime.check_inventory(manifest, now=NOW)
        self.assertIn("RUNTIME_OWNER_SNAPSHOT_MISSING", self.codes(report))
        self.assertIn("RUNTIME_COVERAGE_INCOMPLETE", self.codes(report))

    def test_schema_rejects_duplicate_ids_bad_timestamps_types_and_missing_fields(self):
        variants = []
        manifest = inventory()
        manifest["instances"].append(deepcopy(manifest["instances"][0]))
        variants.append(manifest)
        manifest = inventory()
        manifest["observed_at"] = "2026-11-04T11:59:00"
        variants.append(manifest)
        manifest = inventory()
        manifest["instances"][0]["activity"]["evidence"] = [12]
        variants.append(manifest)
        manifest = inventory()
        del manifest["instances"][0]["cleanup"]["receipt"]
        variants.append(manifest)
        manifest = inventory()
        manifest["instances"][0]["protected"]["saves"] = 1
        variants.append(manifest)
        for manifest in variants:
            with self.subTest(manifest=manifest), self.assertRaises(runtime.InputError):
                runtime.check_inventory(manifest, owners(), now=NOW)

    def test_age_limit_validation(self):
        for value in (0, -1, float("nan"), float("inf"), True):
            with self.subTest(value=value), self.assertRaises(runtime.InputError):
                self.report(max_age_hours=value)

    def test_checker_does_not_mutate_input(self):
        manifest, owner = inventory(), owners()
        before = deepcopy((manifest, owner))
        runtime.check_inventory(manifest, owner, now=NOW)
        self.assertEqual((manifest, owner), before)

    def test_cli_exit_and_json_report(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            inv, own, output = root / "inventory.json", root / "owners.json", root / "report.json"
            inv.write_text(json.dumps(inventory()), encoding="utf-8")
            own.write_text(json.dumps(owners()), encoding="utf-8")
            self.assertEqual(runtime.main(["--inventory", str(inv), "--owners", str(own), "--now", NOW.isoformat(), "--format", "json", "--output", str(output)]), 0)
            self.assertEqual(json.loads(output.read_text())["schema"], runtime.REPORT_SCHEMA)
            inv.write_text(json.dumps(inventory(ended(instance()))), encoding="utf-8")
            own.write_text(json.dumps(owners("ended")), encoding="utf-8")
            self.assertEqual(runtime.main(["--inventory", str(inv), "--owners", str(own), "--now", NOW.isoformat(), "--output", str(output)]), 1)

    def test_standalone_output_cannot_overwrite_inventory_owner_or_link_alias(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            inv, own = root / "inventory.json", root / "owners.json"
            inv.write_text(json.dumps(inventory()), encoding="utf-8")
            own.write_text(json.dumps(owners()), encoding="utf-8")
            before = {path: path.read_bytes() for path in (inv, own)}
            outputs = [inv, own]
            hardlink = root / "inventory-hardlink.json"
            try:
                os.link(inv, hardlink)
                outputs.append(hardlink)
            except (OSError, NotImplementedError):
                pass
            for output in outputs:
                with self.subTest(output=output), patch("sys.stderr", new_callable=io.StringIO) as stderr:
                    result = runtime.main(["--inventory", str(inv), "--owners", str(own), "--output", str(output)])
                    self.assertEqual(result, 2)
                    self.assertIn("--output must not overwrite", stderr.getvalue())
                self.assertEqual({path: path.read_bytes() for path in before}, before)


if __name__ == "__main__":
    unittest.main()
