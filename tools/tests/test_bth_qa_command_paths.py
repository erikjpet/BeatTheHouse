"""Known CLI write paths are admitted without any filesystem writes or launches."""
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bth_qa_storage as storage
from bth_qa_command_paths import command_write_paths


@unittest.skipUnless(os.name == "nt", "Windows QA path admission")
class CommandWritePathsTests(unittest.TestCase):
    def setUp(self):
        # Synthetic metadata only: no E: directory reads, writes or execution.
        self.addCleanup(patch.stopall)
        patch.object(storage, "_probe", side_effect=lambda path: (
            str(path).lower() in {"e:\\", r"e:\codexqa", r"e:\codexqa\bth"}, True, False)).start()
        patch.object(storage, "_resolve_path", side_effect=lambda path: path).start()
        patch.object(storage, "_free_bytes", return_value=100 * storage.GIB).start()
        self.layout = storage.plan_layout(r"E:\CodexQA\BTH", r"E:\CodexQA\BTH\workspaces\new", "new-run")

    def reject(self, command, code):
        with self.assertRaises(storage.StorageGuardError) as failure:
            command_write_paths(self.layout, command)
        self.assertEqual(failure.exception.code, code)

    def test_c_output_rejected(self):
        self.reject(["worker", "--output=C:\\leak.json"], "system_volume")

    def test_old_e_profile_rejected(self):
        self.reject(["browser", "--user-data-dir", r"E:\CodexQA\BTH\runs\old\profile"], "root_escape")

    def test_relative_output_uses_admitted_workspace(self):
        result = command_write_paths(self.layout, ["worker", "--output-dir", "results"])
        self.assertEqual(result, (self.layout.workspace / "results",))

    def test_c_workspace_rejected(self):
        self.reject(["godot", "--path", r"C:\old-source"], "system_volume")

    def test_readonly_c_binary_and_d_script_allowed(self):
        self.assertEqual(command_write_paths(self.layout,
            [r"C:\Python\python.exe", "-B", r"D:\scripts\worker.py"]), ())

    def test_admitted_profile_workspace_and_run_outputs(self):
        expected = (self.layout.profile, self.layout.workspace,
                    self.layout.cache, self.layout.evidence / "worker.log")
        result = command_write_paths(self.layout, ["worker",
            "--user-data-dir=" + str(expected[0]), "--path", str(expected[1]),
            "--disk-cache-dir", str(expected[2]), "--log-file=" + str(expected[3])])
        self.assertEqual(result, expected)

    def test_other_current_run_profile_rejected(self):
        self.reject(["browser", "--user-data-dir", str(self.layout.cache)], "command_path_mismatch")

    def test_other_workspace_rejected(self):
        self.reject(["godot", "--path", str(self.layout.workspace / "nested")], "command_path_mismatch")

    def test_conflicting_identity_duplicates_rejected(self):
        for flag, expected in (("--path", self.layout.workspace), ("--user-data-dir", self.layout.profile)):
            with self.subTest(flag=flag):
                self.reject(["worker", flag, str(expected), flag + "=" + str(expected / "other")],
                            "conflicting_command_path")

    def test_matching_duplicates_allowed(self):
        value = str(self.layout.profile)
        self.assertEqual(command_write_paths(self.layout,
            ["browser", "--user-data-dir=" + value, "--user-data-dir", value.lower()]),
            (self.layout.profile, Path(value.lower())))

    def test_missing_values_rejected(self):
        for command in (["worker", "--output"], ["worker", "--output="],
                        ["worker", "--output", "--path", str(self.layout.workspace)]):
            with self.subTest(command=command):
                self.reject(command, "missing_command_path")

    def test_unknown_flags_are_outside_scope(self):
        self.assertEqual(command_write_paths(self.layout, ["worker", "--arbitrary=C:\\unknown"]), ())

    def test_shell_text_rejected(self):
        self.reject("worker --output=anything", "invalid_command")


if __name__ == "__main__":
    unittest.main()
