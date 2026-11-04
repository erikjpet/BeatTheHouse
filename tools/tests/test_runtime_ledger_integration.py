"""Runtime evidence must affect the same manual ledger reconciliation result."""
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from test_check_bth_task_ledger import checker, ledger, owners, NOW, STAMP


class RuntimeLedgerIntegrationTests(unittest.TestCase):
    def test_required_inventory_cannot_silently_disappear(self):
        data = ledger()
        data["policies"]["runtime_cleanup_required"] = True
        result = checker.check_ledger(data, owners(), now=NOW)
        self.assertFalse(result["runtime_inventory_supplied"])
        missing = [f for f in result["findings"] if f["code"] == "RUNTIME_INVENTORY_NOT_SUPPLIED"]
        self.assertEqual([f["severity"] for f in missing], ["error"])
        self.assertGreater(result["summary"]["errors"], 0)

    def test_scope_gap_is_part_of_main_report_and_error_count(self):
        snapshot = {"schema": "bth.runtime_inventory/v1", "observed_at": STAMP,
                    "scope": {"description": "Known receipts only", "complete": False,
                              "evidence": ["scoped lifecycle snapshot"]}, "instances": []}
        result = checker.check_ledger(ledger(), owners(), now=NOW, runtimes=snapshot)
        self.assertTrue(result["runtime_inventory_supplied"])
        self.assertEqual(result["runtime_summary"]["instances_checked"], 0)
        self.assertIn("RUNTIME_COVERAGE_INCOMPLETE", [f["code"] for f in result["findings"]])
        self.assertEqual(result["summary"]["errors"], sum(f["severity"] == "error" for f in result["findings"]))

    def test_malformed_runtime_file_returns_input_error_from_shared_cli(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            data = directory / "ledger.json"
            data.write_text(json.dumps(ledger()), encoding="utf-8")
            runtime = directory / "runtime.json"
            runtime.write_text('{"schema":"wrong"}', encoding="utf-8")
            error = io.StringIO()
            with contextlib.redirect_stderr(error):
                result = checker.main(["--ledger", str(data), "--runtimes", str(runtime), "--no-markdown"])
            self.assertEqual(result, 2)
            self.assertIn("inventory.schema", error.getvalue())

    def test_runtime_policy_requires_boolean_and_no_cleanup_is_authorized(self):
        data = ledger()
        data["policies"]["runtime_cleanup_required"] = "true"
        with self.assertRaises(checker.InputError):
            checker.check_ledger(data, owners(), now=NOW)
        from test_check_bth_runtime_inventory import inventory, ended, instance
        snapshot = inventory(ended(instance()))
        result = checker.check_ledger(ledger(), owners(), now=NOW, runtimes=snapshot)
        self.assertTrue(all(item["cleanup_authorized"] is False for item in result["runtime_instances"]))
        self.assertIn("No cleanup is authorized", checker.render_text(result))
        self.assertTrue(result["runtime_limitations"])

    def test_main_output_cannot_overwrite_runtime_input(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            data, runtime = directory / "ledger.json", directory / "runtime.json"
            data.write_text(json.dumps(ledger()), encoding="utf-8")
            runtime.write_text('{"schema":"wrong"}', encoding="utf-8")
            before = runtime.read_bytes()
            with contextlib.redirect_stderr(io.StringIO()) as stderr:
                result = checker.main(["--ledger", str(data), "--runtimes", str(runtime), "--no-markdown", "--output", str(runtime)])
            self.assertEqual(result, 2)
            self.assertIn("--output must not overwrite", stderr.getvalue())
            self.assertEqual(runtime.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
