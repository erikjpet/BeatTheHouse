"""Acceptance tests for manual task reconciliation; no network or worker calls."""

import copy
from datetime import datetime, timezone
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "check_bth_task_ledger.py"
SPEC = importlib.util.spec_from_file_location("check_bth_task_ledger", SCRIPT)
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)

NOW = datetime(2026, 11, 4, 12, tzinfo=timezone.utc)
STAMP = "2026-11-04T11:00:00Z"
OLD = "2026-11-01T11:00:00Z"
COMMIT = "a" * 40


def deployment(required=False, verified=False):
    return {"required": required, "state": "verified" if verified else "not_applicable",
            "commit": COMMIT if verified else None,
            "evidence": ["NEXT build identity and changed-behavior record"] if verified else []}


def task(task_id="BTH-TEST-001", complete=False):
    return {
        "id": task_id, "name": "Full audit objective", "kind": "objective", "parent_ids": [],
        "group": "current", "objective": {
            "text": "Review the entire requested obsolete-code scope and remove confirmed obsolete code.",
            "source": "User request, source thread 123", "scope_confirmed": True,
            "acceptance": [{"id": "full-review", "description": "Entire requested scope reviewed",
                            "required": True, "state": "pass" if complete else "open",
                            "evidence": ["Coverage and compatibility report"] if complete else []}],
            "coverage": {"required": True, "complete": complete, "areas": [
                {"id": "core", "state": "reviewed" if complete else "remaining",
                 "evidence": ["Reviewed file disposition inventory"] if complete else []}]}},
        "state": "complete" if complete else "open", "status": "Verified" if complete else "Active review",
        "owner": {"name": "Auditor", "task_ref": "worker-123"},
        "commits": [{"sha": COMMIT, "evidence": ["scoped commit"]}] if complete else [],
        "deployment": deployment(required=complete, verified=complete), "evidence": [],
        "implementation_batches": [], "next_action": None if complete else "Review remaining files in the coverage inventory.",
        "blocker": {"state": "none", "kind": None, "description": None,
                    "observed_at": None, "evidence": [], "requires_user_input": False},
        "planned_app_changes": [], "updated_at": STAMP,
    }


def ledger(*tasks):
    return {"schema": checker.SCHEMA, "updated_at": STAMP,
            "policies": {"completion_requires_commit": True, "no_intentional_holds": True,
                         "no_portrait_app_updates": True, "original_user_incident_saves": "unavailable"},
            "objectives": list(tasks) or [task()], "batches": []}


def owners(state="active", observed_at=STAMP):
    return {"schema": checker.OWNER_SCHEMA, "observed_at": observed_at, "tasks": [
        {"task_ref": "worker-123", "title": "Audit full requested objective", "state": state,
         "observed_at": observed_at, "source": "manual task-state snapshot"}]}


def markdown(data):
    lines = ["# Release plan", "", "## Named playtest task ledger", "",
             "| ID / aliases | Task | Parent | Owner | Completion | Status / retained scoped result | Commit(s) | NEXT / remaining work |",
             "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    for item in data["objectives"] + data["batches"]:
        parent = ", ".join(item.get("parent_ids", [])) or item.get("parent_id", "-")
        lines.append("| " + " | ".join([item["id"], item["name"], parent, item.get("owner", {}).get("name", ""),
                     item["state"].title(), item.get("status", ""), ", ".join(commit["sha"] for commit in item["commits"]) or "NONE - OPEN",
                     item.get("next_action") or "Verified"]) + " |")
    lines.extend(["", "## Another section", "| BTH-IGNORED | unrelated table |"])
    return "\n".join(lines)


class ReconciliationTests(unittest.TestCase):
    def run_check(self, data, snapshot=None, **kwargs):
        return checker.check_ledger(data, owners() if snapshot is None else snapshot, now=NOW, **kwargs)

    def codes(self, report):
        return {entry["code"] for entry in report["findings"]}

    def test_valid_open_and_fully_verified_complete_objective(self):
        data = ledger(task(), task("BTH-TEST-002", complete=True))
        before = copy.deepcopy(data)
        report = self.run_check(data)
        self.assertEqual(report["summary"]["errors"], 0)
        self.assertEqual(report["summary"]["warnings"], 0)
        self.assertEqual(data, before, "The checker must not change task states or data")

    def test_parent_cannot_close_when_only_first_batch_complete(self):
        parent = task(complete=True)
        parent["objective"]["acceptance"][0].update(state="open", evidence=[])
        parent["objective"]["coverage"]["complete"] = False
        parent["objective"]["coverage"]["areas"][0].update(state="remaining", evidence=[])
        parent["implementation_batches"] = ["BTH-TEST-BATCH-01"]
        data = ledger(parent)
        data["batches"] = [{"id": "BTH-TEST-BATCH-01", "parent_id": parent["id"],
                            "name": "First removal batch", "scope": ["four confirmed obsolete helpers"],
                            "state": "complete", "commits": [{"sha": COMMIT, "evidence": ["commit"]}],
                            "deployment": deployment(True, True), "evidence": []}]
        report = self.run_check(data)
        self.assertTrue({"PARENT_BATCH_ONLY_COMPLETION", "COVERAGE_INCOMPLETE", "COMPLETE_WITH_OPEN_ACCEPTANCE"} <= self.codes(report))
        self.assertNotIn("BATCH_COMPLETE_WITHOUT_COMMIT", self.codes(report))

    def test_open_parent_remains_open_with_completed_batch(self):
        parent = task()
        parent["implementation_batches"] = ["BTH-TEST-BATCH-01"]
        data = ledger(parent)
        data["batches"] = [{"id": "BTH-TEST-BATCH-01", "parent_id": parent["id"], "name": "first batch",
                            "scope": ["limited scope"], "state": "complete",
                            "commits": [{"sha": COMMIT, "evidence": []}], "deployment": deployment(), "evidence": []}]
        report = self.run_check(data)
        self.assertEqual(report["summary"]["errors"], 0)
        self.assertEqual(parent["state"], "open")
        self.assertEqual(report["summary"]["open_work_items"], 1)
        entry = report["open_work"][0]
        self.assertEqual(entry["id"], parent["id"])
        self.assertEqual(entry["full_objective"]["text"], parent["objective"]["text"])
        self.assertEqual(entry["next_action"], parent["next_action"])
        self.assertEqual(entry["completed_batch_ids"], ["BTH-TEST-BATCH-01"])
        self.assertEqual(entry["acceptance_progress"]["remaining_ids"], ["full-review"])
        self.assertEqual(entry["coverage_progress"]["remaining_ids"], ["core"])
        self.assertEqual(entry["owner"]["observed_state"], "active")
        readable_report = checker.render_text(report)
        self.assertIn("[OPEN] " + parent["id"], readable_report)
        self.assertIn("Next: " + parent["next_action"], readable_report)
        self.assertIn("completed batches: BTH-TEST-BATCH-01", readable_report)

    def test_open_work_reports_batch_scope_parent_progress_and_owner_observation(self):
        parent = task()
        parent["implementation_batches"] = ["BTH-TEST-BATCH-01"]
        data = ledger(parent)
        data["batches"] = [{"id": "BTH-TEST-BATCH-01", "parent_id": parent["id"], "name": "next batch",
                            "scope": ["limited confirmed removals"], "state": "open", "commits": [],
                            "deployment": deployment(), "evidence": [],
                            "owner": {"name": "Auditor", "task_ref": "worker-123"}, "status": "Active batch",
                            "next_action": "Review callers for the next bounded removal.",
                            "blocker": {"state": "none"}}]
        report = self.run_check(data, owners("idle"))
        self.assertEqual(report["summary"]["open_work_items"], 2)
        self.assertEqual(report["summary"]["open_batches"], 1)
        entry = report["open_work"][1]
        self.assertEqual(entry["item_type"], "implementation_batch")
        self.assertEqual(entry["progress_scope_id"], parent["id"])
        self.assertEqual(entry["full_objective"]["text"], parent["objective"]["text"])
        self.assertEqual(entry["batch_scope"], ["limited confirmed removals"])
        self.assertEqual(entry["owner"]["observed_state"], "idle")
        self.assertEqual(entry["owner"]["observed_at"], STAMP)
        self.assertEqual(entry["next_action"], data["batches"][0]["next_action"])
        entry["coverage"]["areas"].clear()
        self.assertEqual(len(parent["objective"]["coverage"]["areas"]), 1, "Report data must not alias the input ledger")

    def test_no_completed_item_without_full_associated_commit(self):
        item = task(complete=True)
        item["commits"] = [{"sha": "6a78462", "evidence": ["short historical hash"]}]
        report = self.run_check(ledger(item))
        self.assertTrue({"INVALID_COMMIT_ID", "COMPLETE_WITHOUT_COMMIT"} <= self.codes(report))

    def test_batch_also_needs_commit(self):
        data = ledger()
        data["objectives"][0]["implementation_batches"] = ["BTH-BATCH-001"]
        data["batches"] = [{"id": "BTH-BATCH-001", "parent_id": data["objectives"][0]["id"],
                            "name": "batch", "scope": [], "state": "complete", "commits": [],
                            "deployment": deployment(), "evidence": []}]
        self.assertIn("BATCH_COMPLETE_WITHOUT_COMMIT", self.codes(self.run_check(data)))

    def test_open_batch_needs_its_own_current_owner_and_next_action(self):
        data = ledger()
        data["objectives"][0]["implementation_batches"] = ["BTH-BATCH-001"]
        data["batches"] = [{"id": "BTH-BATCH-001", "parent_id": data["objectives"][0]["id"],
                            "name": "batch", "scope": [], "state": "open", "commits": [],
                            "deployment": deployment(), "evidence": []}]
        report = self.run_check(data)
        batch_codes = {finding["code"] for finding in report["findings"] if finding["task_id"] == "BTH-BATCH-001"}
        self.assertTrue({"OWNER_MISSING", "OWNER_TASK_REFERENCE_MISSING", "NEXT_ACTION_MISSING"} <= batch_codes)

    def test_owner_missing_reference_idle_ended_and_not_found(self):
        for state, expected in (("idle", "OWNER_IDLE_WITH_OPEN_WORK"), ("ended", "OWNER_ENDED_WITH_OPEN_WORK"), ("not_found", "OWNER_NOT_FOUND")):
            with self.subTest(state=state):
                self.assertIn(expected, self.codes(self.run_check(ledger(), owners(state))))
        data = ledger()
        data["objectives"][0]["owner"] = {"name": None, "task_ref": None}
        self.assertTrue({"OWNER_MISSING", "OWNER_TASK_REFERENCE_MISSING"} <= self.codes(self.run_check(data)))
        snapshot = owners()
        snapshot["tasks"] = []
        self.assertIn("OWNER_NOT_IN_SNAPSHOT", self.codes(self.run_check(ledger(), snapshot)))

    def test_completed_owner_does_not_need_to_remain_running(self):
        report = self.run_check(ledger(task(complete=True)), owners("ended", OLD))
        self.assertEqual(report["summary"]["errors"], 0)

    def test_missing_snapshot_is_warning_and_stale_snapshot_is_error(self):
        report = checker.check_ledger(ledger(), now=NOW)
        self.assertEqual(report["summary"]["errors"], 0)
        self.assertEqual(report["summary"]["warnings"], 1)
        self.assertIn("OWNER_SNAPSHOT_NOT_SUPPLIED", self.codes(report))
        self.assertTrue({"OWNER_SNAPSHOT_STALE", "OWNER_OBSERVATION_STALE"} <= self.codes(self.run_check(ledger(), owners(observed_at=OLD))))

    def test_next_action_must_be_concrete(self):
        for action in (None, "", "continue", "TBD", "wait"):
            data = ledger()
            data["objectives"][0]["next_action"] = action
            with self.subTest(action=action):
                self.assertIn("NEXT_ACTION_MISSING", self.codes(self.run_check(data)))

    def test_stale_blocker_and_user_original_save_demand(self):
        data = ledger()
        data["objectives"][0]["blocker"] = {"state": "active", "kind": "exact_user_save",
            "description": "Waiting for Erik to provide the exact incident save checks.",
            "observed_at": OLD, "evidence": ["old task note"], "requires_user_input": True}
        self.assertTrue({"BLOCKER_STALE", "STALE_USER_SAVE_BLOCKER"} <= self.codes(self.run_check(data)))
        data["objectives"][0]["blocker"]["kind"] = "verification"
        self.assertIn("STALE_USER_SAVE_BLOCKER", self.codes(self.run_check(data)))

    def test_retained_fixtures_and_eligible_hand_prerequisite_are_allowed(self):
        data = ledger()
        data["objectives"][0]["blocker"] = {"state": "active", "kind": "eligible_hand",
            "description": "Need a natural eligible hand; retained agent original save fixture is available.",
            "observed_at": STAMP, "evidence": ["warm/cold natural replay record"], "requires_user_input": False}
        codes = self.codes(self.run_check(data))
        self.assertNotIn("STALE_USER_SAVE_BLOCKER", codes)
        self.assertNotIn("INTENTIONAL_HOLD_FORBIDDEN", codes)
        self.assertEqual(self.run_check(data)["summary"]["errors"], 0)
        data["objectives"][0]["blocker"]["description"] = "Need a natural eligible hand using retained agent original save fixtures. User original saves are unavailable."
        self.assertNotIn("STALE_USER_SAVE_BLOCKER", self.codes(self.run_check(data)))

    def test_intentional_hold_flag_does_not_scan_historical_evidence(self):
        data = ledger()
        data["objectives"][0]["evidence"] = [{"kind": "history", "reference": "old note", "summary": "Removed HELD_USER_HANDS_ON label"}]
        self.assertNotIn("INTENTIONAL_HOLD_FORBIDDEN", self.codes(self.run_check(data)))
        data["objectives"][0]["status"] = "HELD_USER_HANDS_ON"
        self.assertIn("INTENTIONAL_HOLD_FORBIDDEN", self.codes(self.run_check(data)))
        data["objectives"][0]["group"] = "historical"
        self.assertIn("INTENTIONAL_HOLD_FORBIDDEN", self.codes(self.run_check(data)))
        data["objectives"][0]["state"] = "superseded"
        self.assertNotIn("INTENTIONAL_HOLD_FORBIDDEN", self.codes(self.run_check(data)))

    def test_real_tls_approval_blocker_and_negated_hold_reminders_are_allowed(self):
        for description in (
            "The local TLS operation needs approval. This is not an intentional hold.",
            "No intentional holds; revalidate the actual TLS approval result.",
            "Owner source is unknown; do not invent a design decision or intentional hold.",
            "There are zero intentional holds.",
        ):
            data = ledger()
            data["objectives"][0]["blocker"] = {"state": "active", "kind": "approval",
                "description": description, "observed_at": STAMP,
                "evidence": ["Actual automatic approval-review response"], "requires_user_input": False}
            with self.subTest(description=description):
                self.assertNotIn("INTENTIONAL_HOLD_FORBIDDEN", self.codes(self.run_check(data)))
        data["objectives"][0]["blocker"].update(kind="intentional_hold", description="No intentional holds are allowed, but this task was held.")
        self.assertIn("INTENTIONAL_HOLD_FORBIDDEN", self.codes(self.run_check(data)))
        data["objectives"][0]["blocker"].update(kind="verification", description="Intentional hold pending user hands-on checks.")
        self.assertIn("INTENTIONAL_HOLD_FORBIDDEN", self.codes(self.run_check(data)))

    def test_portrait_tests_are_evidence_not_planned_app_changes(self):
        data = ledger()
        data["objectives"][0]["evidence"] = [{"kind": "regression", "reference": "portrait screenshot", "summary": "Portrait viewport test passed"}]
        data["objectives"][0]["objective"]["acceptance"][0]["description"] = "Portrait regression evidence retained"
        self.assertNotIn("PORTRAIT_APP_CHANGE_FORBIDDEN", self.codes(self.run_check(data)))
        data["objectives"][0]["planned_app_changes"] = [
            {"kind": "regression_test", "description": "Portrait layout regression test"},
            "Run portrait viewport regression tests", "Portrait regression evidence"]
        self.assertNotIn("PORTRAIT_APP_CHANGE_FORBIDDEN", self.codes(self.run_check(data)))
        data["objectives"][0]["planned_app_changes"] = ["Implement portrait-mode layout"]
        self.assertIn("PORTRAIT_APP_CHANGE_FORBIDDEN", self.codes(self.run_check(data)))

    def test_verified_deployment_needs_identity_and_evidence(self):
        data = ledger(task(complete=True))
        data["objectives"][0]["deployment"].update(commit=None, evidence=[])
        self.assertTrue({"DEPLOYMENT_IDENTITY_MISSING", "DEPLOYMENT_EVIDENCE_MISSING"} <= self.codes(self.run_check(data)))
        data["objectives"][0]["deployment"]["state"] = "pending"
        self.assertIn("COMPLETE_WITHOUT_DEPLOYMENT", self.codes(self.run_check(data)))

    def test_coverage_boolean_alone_does_not_prove_reviewed_areas(self):
        data = ledger(task(complete=True))
        data["objectives"][0]["objective"]["coverage"]["areas"][0]["state"] = "unknown"
        self.assertIn("COVERAGE_INCOMPLETE", self.codes(self.run_check(data)))

    def test_required_pass_needs_evidence_and_unavailable_is_not_pass(self):
        data = ledger(task(complete=True))
        criterion = data["objectives"][0]["objective"]["acceptance"][0]
        criterion["evidence"] = []
        self.assertIn("COMPLETE_WITHOUT_ACCEPTANCE_EVIDENCE", self.codes(self.run_check(data)))
        criterion.update(required=False, state="unavailable", evidence=["User original incident saves gone"])
        data["objectives"][0]["objective"]["acceptance"].append(
            {"id": "alternative", "description": "Reconstructed independent acceptance", "required": True,
             "state": "pass", "evidence": ["reconstruction report"]})
        self.assertEqual(self.run_check(data)["summary"]["errors"], 0)

    def test_broken_references_duplicates_and_open_children(self):
        parent, child = task(complete=True), task("BTH-CHILD-001")
        child["parent_ids"] = [parent["id"], "MISSING-PARENT"]
        parent["implementation_batches"] = ["MISSING-BATCH"]
        data = ledger(parent, child)
        codes = self.codes(self.run_check(data))
        self.assertTrue({"PARENT_NOT_FOUND", "BATCH_NOT_FOUND", "COMPLETE_WITH_OPEN_CHILDREN"} <= codes)
        data["objectives"].append(copy.deepcopy(child))
        self.assertIn("DUPLICATE_ID", self.codes(self.run_check(data)))

    def test_group_selection_resolves_parent_in_other_group(self):
        parent, child = task("BTH-HISTORY-001", complete=True), task()
        parent["group"] = "historical"
        parent["commits"] = []
        child["parent_ids"] = [parent["id"]]
        report = self.run_check(ledger(parent, child), group="current")
        self.assertEqual(report["summary"]["objectives_checked"], 1)
        self.assertNotIn("PARENT_NOT_FOUND", self.codes(report))
        self.assertNotIn("COMPLETE_WITHOUT_COMMIT", self.codes(report))

    def test_verify_git_is_local_cat_file_only(self):
        with patch.object(checker.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            report = self.run_check(ledger(task(complete=True)), verify_git=True, repo_root=Path("local-repo"))
        self.assertEqual(report["summary"]["errors"], 0)
        self.assertEqual(run.call_count, 1, "Same SHA should be verified once")
        self.assertEqual(run.call_args.args[0], ["git", "-C", "local-repo", "cat-file", "-e", COMMIT + "^{commit}"])
        with patch.object(checker.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)):
            self.assertIn("COMMIT_NOT_FOUND", self.codes(self.run_check(ledger(task(complete=True)), verify_git=True)))

    def test_schema_and_timezone_errors_are_input_errors(self):
        for mutation in (lambda data: data.update(schema="unknown"),
                         lambda data: data.update(updated_at="2026-11-04T12:00:00"),
                         lambda data: data["objectives"][0].update(deployment="bad"),
                         lambda data: data["objectives"][0]["objective"]["coverage"].pop("required")):
            data = ledger()
            mutation(data)
            with self.subTest(data=data), self.assertRaises(checker.InputError):
                self.run_check(data)

    def test_freshness_limit_must_be_finite_and_positive(self):
        for value in (float("nan"), float("inf"), 0, -1, 1e100):
            with self.subTest(value=value), self.assertRaises(checker.InputError):
                self.run_check(ledger(), max_owner_age_hours=value)

    def test_markdown_matches_objectives_and_batches_and_short_commit_prefix(self):
        data = ledger(task(complete=True))
        parent = data["objectives"][0]
        parent["implementation_batches"] = ["BTH-BATCH-001"]
        data["batches"] = [{"id": "BTH-BATCH-001", "parent_id": parent["id"], "name": "First batch",
                            "scope": ["bounded changes"], "state": "complete", "commits": [{"sha": COMMIT, "evidence": []}],
                            "deployment": deployment(), "owner": {"name": "Auditor"}, "status": "Batch verified", "evidence": []}]
        readable = markdown(data).replace(COMMIT, COMMIT[:8])
        report = self.run_check(data, markdown=readable)
        self.assertEqual(report["summary"]["errors"], 0)
        self.assertEqual(report["markdown_rows_checked"], 2)

    def test_markdown_drift_detects_missing_ids_status_owner_commit_and_completion(self):
        data = ledger(task(complete=True))
        readable = markdown(data).replace("| Complete |", "| Open |")
        readable = readable.replace("| Auditor |", "| Missing worker |")
        readable = readable.replace("| Verified |", "| Different status |", 1)
        readable = readable.replace(COMMIT, "b" * 40)
        report = self.run_check(data, markdown=readable)
        self.assertTrue({"MARKDOWN_COMPLETION_DRIFT", "MARKDOWN_OWNER_DRIFT", "MARKDOWN_STATUS_DRIFT", "MARKDOWN_COMMIT_MISSING_FROM_JSON"} <= self.codes(report))
        readable = readable.replace(data["objectives"][0]["id"], "BTH-MD-ONLY-001")
        codes = self.codes(self.run_check(data, markdown=readable))
        self.assertTrue({"MARKDOWN_ID_MISSING_FROM_JSON", "JSON_ID_MISSING_FROM_MARKDOWN"} <= codes)

    def test_markdown_commit_cell_cannot_drop_structured_commits(self):
        data = ledger(task(complete=True))
        readable = markdown(data).replace(COMMIT, "NONE - OPEN")
        codes = self.codes(self.run_check(data, markdown=readable))
        self.assertTrue({"JSON_COMMIT_MISSING_FROM_MARKDOWN", "MARKDOWN_COMPLETE_WITHOUT_COMMIT"} <= codes)
        second_commit = "b" * 40
        data["objectives"][0]["commits"].append({"sha": second_commit, "evidence": ["follow-up scoped commit"]})
        readable = markdown(data).replace(", " + second_commit, "")
        report = self.run_check(data, markdown=readable)
        missing = [entry for entry in report["findings"] if entry["code"] == "JSON_COMMIT_MISSING_FROM_MARKDOWN"]
        self.assertEqual(len(missing), 1)
        self.assertIn(second_commit, missing[0]["evidence"])
        self.assertNotIn("MARKDOWN_COMPLETE_WITHOUT_COMMIT", self.codes(report))

    def test_markdown_parent_drift_and_schema_failure(self):
        data = ledger()
        readable = markdown(data).replace("| - | Auditor", "| BTH-WRONG-PARENT | Auditor")
        self.assertIn("MARKDOWN_PARENT_DRIFT", self.codes(self.run_check(data, markdown=readable)))
        with self.assertRaises(checker.InputError):
            self.run_check(data, markdown="# Missing named ledger section")

    def test_cli_exit_codes_json_output_and_input_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source, snapshot, output = root / "ledger.json", root / "owners.json", root / "report.json"
            data = ledger()
            source.write_text(json.dumps(data), encoding="utf-8")
            snapshot.write_text(json.dumps(owners()), encoding="utf-8")
            arguments = ["--ledger", str(source), "--owners", str(snapshot), "--no-markdown", "--format", "json", "--output", str(output), "--now", checker.iso(NOW)]
            self.assertEqual(checker.main(arguments), 0)
            report = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(report["schema"], checker.REPORT_SCHEMA)
            data["objectives"][0]["owner"]["name"] = None
            source.write_text(json.dumps(data), encoding="utf-8")
            self.assertEqual(checker.main(arguments), 1)
            source.write_text("{broken", encoding="utf-8")
            with patch("sys.stderr", new_callable=io.StringIO) as stderr:
                self.assertEqual(checker.main(arguments), 2)
                self.assertIn("Input error:", stderr.getvalue())

    def test_cli_markdown_drift_and_nonfinite_input_exit_codes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source, readable, output = root / "ledger.json", root / "plan.md", root / "report.json"
            data = ledger(task(complete=True))
            source.write_text(json.dumps(data), encoding="utf-8")
            readable.write_text(markdown(data), encoding="utf-8")
            arguments = ["--ledger", str(source), "--markdown", str(readable), "--format", "json", "--output", str(output), "--now", checker.iso(NOW)]
            self.assertEqual(checker.main(arguments), 0)
            readable.write_text(markdown(data).replace("| Auditor |", "| Another owner |"), encoding="utf-8")
            self.assertEqual(checker.main(arguments), 1)
            self.assertIn("MARKDOWN_OWNER_DRIFT", self.codes(json.loads(output.read_text(encoding="utf-8"))))
            with patch("sys.stderr", new_callable=io.StringIO):
                self.assertEqual(checker.main(arguments + ["--max-owner-age-hours", "nan"]), 2)

    def test_output_cannot_overwrite_any_input_and_preserves_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source, snapshot, readable = root / "ledger.json", root / "owners.json", root / "plan.md"
            data = ledger()
            source.write_text(json.dumps(data), encoding="utf-8")
            snapshot.write_text(json.dumps(owners()), encoding="utf-8")
            readable.write_text(markdown(data), encoding="utf-8")
            before = {path: path.read_bytes() for path in (source, snapshot, readable)}
            arguments = ["--ledger", str(source), "--owners", str(snapshot), "--markdown", str(readable), "--now", checker.iso(NOW)]
            for path in before:
                with self.subTest(path=path), patch("sys.stderr", new_callable=io.StringIO) as stderr:
                    self.assertEqual(checker.main(arguments + ["--output", str(path)]), 2)
                    self.assertIn("--output must not overwrite", stderr.getvalue())
                self.assertEqual({item: item.read_bytes() for item in before}, before)
            # A lexical alias must be resolved before comparing destinations.
            alias = root / "subdir" / ".." / source.name
            (root / "subdir").mkdir()
            with patch("sys.stderr", new_callable=io.StringIO):
                self.assertEqual(checker.main(arguments + ["--output", str(alias)]), 2)
            self.assertEqual(source.read_bytes(), before[source])

    def test_output_symlink_or_hardlink_alias_cannot_overwrite_input(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "ledger.json"
            source.write_text(json.dumps(ledger()), encoding="utf-8")
            before = source.read_bytes()
            aliases = []
            symlink = root / "ledger-symlink.json"
            try:
                symlink.symlink_to(source)
                aliases.append(symlink)
            except (OSError, NotImplementedError):
                pass  # Windows may not grant symlink privilege; exercise hardlink too.
            hardlink = root / "ledger-hardlink.json"
            try:
                os.link(source, hardlink)
                aliases.append(hardlink)
            except (OSError, NotImplementedError):
                pass
            if not aliases:
                self.skipTest("This filesystem does not support creating symlink or hardlink aliases")
            for alias in aliases:
                with self.subTest(alias=alias), patch("sys.stderr", new_callable=io.StringIO) as stderr:
                    self.assertEqual(checker.main(["--ledger", str(source), "--no-markdown", "--output", str(alias)]), 2)
                    self.assertIn("--output must not overwrite", stderr.getvalue())
                self.assertEqual(source.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
