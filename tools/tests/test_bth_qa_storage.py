"""Behavior tests use an in-memory metadata adapter: no E: writes or child launches."""
from dataclasses import replace
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bth_qa_storage as guard


class FakeFilesystem:
    def __init__(self):
        self.entries = {}
        self.receipts = {}
        self.writes = []
        self.probes = []
        self.free = 100 * guard.GIB
        self.after_mkdir = None
        for path in ("E:\\", r"E:\CodexQA", r"E:\CodexQA\BTH", "D:\\", r"D:\QA"):
            self.entries[guard._key(path)] = "dir"

    def probe(self, path):
        kind = self.entries.get(guard._key(path))
        return kind is not None, kind == "dir", kind == "reparse"

    def disk_free(self, path):
        self.probes.append(str(path))
        return self.free

    def mkdir(self, path):
        key = guard._key(path)
        if key in self.entries:
            raise FileExistsError(str(path))
        if self.entries.get(guard._key(path.parent)) != "dir":
            raise FileNotFoundError(str(path.parent))
        self.entries[key] = "dir"
        self.writes.append(str(path))
        if self.after_mkdir:
            self.after_mkdir(path)

    def write_manifest(self, layout):
        key = guard._key(layout.manifest_path)
        if key in self.entries:
            raise FileExistsError(str(layout.manifest_path))
        self.entries[key] = "file"
        self.receipts[key] = json.loads(json.dumps(layout.as_dict()))
        self.writes.append(str(layout.manifest_path))

    def read_manifest(self, path):
        return self.receipts[guard._key(path)]


class StorageGuardTests(unittest.TestCase):
    def setUp(self):
        self.fs = FakeFilesystem()
        for name, replacement in (
            ("_require_windows", lambda: None), ("_probe", self.fs.probe),
            ("_free_bytes", self.fs.disk_free), ("_mkdir_new", self.fs.mkdir),
            ("_resolve_path", lambda path: path),
            ("_write_manifest", self.fs.write_manifest), ("_read_manifest", self.fs.read_manifest),
        ):
            patcher = patch.object(guard, name, replacement)
            patcher.start()
            self.addCleanup(patcher.stop)

    def plan(self, **kwargs):
        return guard.plan_layout(kwargs.pop("root", guard.DEFAULT_ROOT),
                                 kwargs.pop("workspace", r"E:\CodexQA\BTH\workspaces\unit"),
                                 kwargs.pop("run_id", "unit-01"), **kwargs)

    def prepared(self):
        return guard.prepare_layout(self.plan())

    def fails(self, code, call):
        with self.assertRaises(guard.StorageGuardError) as caught:
            call()
        self.assertEqual(caught.exception.code, code)
        return caught.exception

    def test_e_plan_is_read_only_and_probes_each_path(self):
        layout = self.plan()
        self.assertFalse(layout.prepared)
        self.assertEqual(layout.reserve_bytes + layout.expected_write_bytes, 24 * guard.GIB)
        self.assertEqual(self.fs.writes, [])
        self.assertEqual(len(self.fs.probes), 12)
        self.assertTrue(all(path.startswith("E:") for path in self.fs.probes))
        self.assertEqual(json.loads(json.dumps(layout.as_dict()))["paths"]["profile"], str(layout.profile))

    def test_c_rejected_in_every_writable_field_before_writes(self):
        for parameter in ("root", "workspace"):
            with self.subTest(parameter=parameter):
                self.fails("system_volume", lambda: self.plan(**{parameter: r"C:\qa"}))
        layout = self.plan()
        for name in ("root", "workspace", "run_root") + guard._LEAVES:
            with self.subTest(field=name):
                self.fails("system_volume", lambda: guard.prepare_layout(replace(layout, **{name: Path(r"C:\qa")})))
        self.assertEqual(self.fs.writes, [])

    def test_d_low_space_fails_with_exact_budget_and_no_writes(self):
        self.fs.free = 12 * guard.GIB
        error = self.fails("insufficient_space", lambda: self.plan(root=r"D:\QA", workspace=r"D:\QA\workspace"))
        self.assertEqual(error.as_dict()["required_bytes"], 24 * guard.GIB)
        self.assertEqual(error.available_bytes, 12 * guard.GIB)
        self.assertEqual(self.fs.writes, [])

    def test_space_rechecked_before_prepare_before_any_mkdir(self):
        layout = self.plan()
        self.fs.free = 23 * guard.GIB
        self.fails("insufficient_space", lambda: guard.prepare_layout(layout))
        self.assertEqual(self.fs.writes, [])

    def test_prepare_creates_empty_workspace_and_exclusive_manifest(self):
        layout = self.prepared()
        self.assertTrue(layout.prepared)
        self.assertTrue(self.fs.probe(layout.workspace)[0])
        self.assertEqual(self.fs.receipts[guard._key(layout.manifest_path)], layout.as_dict())
        self.assertTrue(guard.validate_layout(layout, prepared=True))
        self.fails("already_prepared", lambda: guard.prepare_layout(layout))

    def test_preexisting_workspace_is_preserved(self):
        workspace = r"E:\CodexQA\BTH\workspace"
        self.fs.entries[guard._key(workspace)] = "dir"
        layout = guard.prepare_layout(self.plan(workspace=workspace))
        self.assertNotIn(str(layout.workspace), self.fs.writes)

    def test_occupied_run_is_not_reused_or_overwritten(self):
        layout = self.plan()
        self.fs.entries[guard._key(layout.run_root)] = "dir"
        self.fails("occupied_run", lambda: guard.prepare_layout(layout))
        self.assertEqual(self.fs.writes, [])

    def test_free_space_rechecked_after_mkdir_before_manifest(self):
        layout = self.plan()
        self.fs.after_mkdir = lambda path: setattr(self.fs, "free", 2 * guard.GIB)
        self.fails("insufficient_space", lambda: guard.prepare_layout(layout))
        self.assertNotIn(guard._key(layout.manifest_path), self.fs.receipts)

    def test_launch_rechecks_free_and_refuses_unprepared_or_missing_workspace(self):
        self.fails("not_prepared", lambda: guard.check_launch(self.plan(), r"E:\CodexQA\BTH\workspaces\unit", {}))
        layout = self.prepared()
        env = guard.child_environment(layout, {})
        self.fs.free = 1 * guard.GIB
        self.fails("insufficient_space", lambda: guard.check_launch(layout, layout.workspace, env))
        self.fs.free = 100 * guard.GIB
        del self.fs.entries[guard._key(layout.workspace)]
        self.fails("missing_prepared_directory", lambda: guard.check_launch(layout, layout.workspace, env))

    def test_child_environment_is_isolated_and_preserves_read_only_c_binaries(self):
        layout = self.prepared()
        parent = {"Temp": r"C:\old", "PATH": r"C:\Python310", "USERPROFILE": r"C:\Users\person",
                  "HOMEDRIVE": "C:", "HOMEPATH": r"\Users\person", "custom": "unchanged"}
        original = parent.copy()
        child = guard.child_environment(layout, parent)
        self.assertEqual(parent, original)
        self.assertEqual(child["PATH"], original["PATH"])
        self.assertNotIn("Temp", child)
        self.assertEqual(child["PYTHONDONTWRITEBYTECODE"], "1")
        self.assertEqual(child["HOMEDRIVE"] + child["HOMEPATH"], str(layout.home))
        self.assertNotIn("BTH_WEB_STORAGE_PROFILE", child)
        self.assertTrue(guard.check_launch(layout, layout.workspace, child))

    def test_launch_environment_spills_and_missing_overrides_fail(self):
        layout = self.prepared()
        good = guard.child_environment(layout, {})
        for key in ("TEMP", "BTH_QA_PROFILE_DIR", "BTH_WEB_EVIDENCE_DIR", "BTH_SAVE_DIR"):
            with self.subTest(key=key):
                bad = {**good, key: r"C:\spill"}
                self.fails("system_volume", lambda: guard.check_launch(layout, layout.workspace, bad))
                bad = {**good, key: r"E:\CodexQA\BTH\wrong"}
                self.fails("environment_spill", lambda: guard.check_launch(layout, layout.workspace, bad))
        self.fails("environment_spill", lambda: guard.check_launch(layout, layout.workspace, {}))
        self.fails("environment_spill", lambda: guard.check_launch(layout, layout.workspace, {**good, "HOMEDRIVE": "C:"}))
        self.fails("duplicate_environment", lambda: guard.check_launch(layout, layout.workspace, {**good, "temp": str(layout.temp)}))

    def test_tmpdir_priority_c_spill_is_overridden_and_launch_tampering_rejected(self):
        layout = self.prepared()
        parent = {"tmpdir": r"C:\higher-priority-temp", "TEMP": r"C:\old-temp", "TMP": r"C:\old-tmp"}
        original = parent.copy()
        child = guard.child_environment(layout, parent)
        self.assertEqual(parent, original)
        self.assertNotIn("tmpdir", child)
        for key in ("TMPDIR", "TEMP", "TMP"):
            self.assertEqual(child[key], str(layout.temp))
        self.assertTrue(guard.check_launch(layout, layout.workspace, child))
        self.fails("system_volume", lambda: guard.check_launch(
            layout, layout.workspace, {**child, "TMPDIR": r"C:\higher-priority-temp"}))

    def test_native_output_overrides_replace_inherited_c_without_gameplay_mode_change(self):
        layout = self.prepared()
        parent = {key: r"C:\old-output" for key in guard._ENV_RELATIVE}
        parent["BTH_DISTRIBUTION_BUILD"] = "original-mode"
        original = parent.copy()
        child = guard.child_environment(layout, parent)
        self.assertEqual(parent, original)
        self.assertEqual(child["BTH_DISTRIBUTION_BUILD"], "original-mode")
        self.assertTrue(guard.check_launch(layout, layout.workspace, child))
        for key, (attr, name) in guard._ENV_RELATIVE.items():
            with self.subTest(key=key):
                self.assertEqual(child[key], str(getattr(layout, attr) / name))
                self.fails("system_volume", lambda: guard.check_launch(layout, layout.workspace, {**child, key: r"C:\spill"}))
        target = Path(child["BTH_USER_SETTINGS_PATH"])
        self.fs.entries[guard._key(target)] = "reparse"
        self.fails("reparse_path", lambda: guard.check_launch(layout, layout.workspace, child))

    def test_extra_outputs_and_cwd_checked(self):
        layout = self.prepared()
        env = guard.child_environment(layout, {})
        self.fails("system_volume", lambda: guard.check_launch(layout, layout.workspace, env, [r"C:\output"]))
        self.fails("root_escape", lambda: guard.check_launch(layout, layout.workspace, env, [r"E:\elsewhere"]))
        self.fails("cwd_mismatch", lambda: guard.check_launch(layout, layout.evidence, env))
        self.assertTrue(guard.check_launch(layout, layout.workspace, env, [layout.evidence / "new.json"]))

    def test_extra_output_c_rejected_before_preparation_writes(self):
        layout = self.plan()
        self.fails("system_volume", lambda: guard.validate_layout(layout, extra_write_paths=[r"C:\output"]))
        for path in (r"E:\CodexQA\BTH", r"E:\CodexQA\BTH\Broad\old-campaign", r"E:\CodexQA\BTH\runs\old-run\profile"):
            self.fails("root_escape", lambda: guard.validate_layout(layout, extra_write_paths=[path]))
        self.assertTrue(guard.validate_layout(layout, extra_write_paths=[layout.workspace / "builds" / "out.zip"]))
        self.assertEqual(self.fs.writes, [])

    def test_path_escape_and_ambiguous_windows_paths_rejected(self):
        paths = (r"E:\CodexQA\BTH-other\workspace", r"D:\QA\workspace")
        for path in paths:
            self.fails("root_escape", lambda: self.plan(workspace=path))
        for path in (r"E:\CodexQA\BTH\..\escape", r"E:relative", "relative", r"\\server\share\work", r"E:\CodexQA\BTH\name.", r"E:\CodexQA\BTH\stream:ads"):
            self.fails("invalid_path", lambda: self.plan(workspace=path))
        self.assertEqual(self.fs.writes, [])

    def test_reparse_root_or_ancestor_rejected_without_following_alias(self):
        for alias in (r"E:\CodexQA", r"E:\CodexQA\BTH", r"E:\CodexQA\BTH\alias"):
            with self.subTest(alias=alias):
                old = self.fs.entries.get(guard._key(alias))
                self.fs.entries[guard._key(alias)] = "reparse"
                self.fails("reparse_path", lambda: self.plan(workspace=r"E:\CodexQA\BTH\alias\workspace"))
                if old is None:
                    del self.fs.entries[guard._key(alias)]
                else:
                    self.fs.entries[guard._key(alias)] = old
        self.assertEqual(self.fs.writes, [])

    def test_non_reparse_drive_alias_resolution_to_c_or_other_root_rejected(self):
        with patch.object(guard, "_resolve_path", lambda path: Path(r"C:\aliased")):
            self.fails("system_volume", self.plan)
        with patch.object(guard, "_resolve_path", lambda path: Path(r"E:\outside")):
            self.fails("resolved_alias", self.plan)
        self.assertEqual(self.fs.writes, [])

    def test_prepared_receipt_tamper_or_reparse_is_rejected(self):
        layout = self.prepared()
        key = guard._key(layout.manifest_path)
        self.fs.receipts[key]["token"] = "wrong"
        self.fails("manifest_mismatch", lambda: guard.validate_layout(layout))
        self.fs.entries[key] = "reparse"
        self.fails("invalid_manifest", lambda: guard.validate_layout(layout))

    def test_workspace_output_overlap_rejected(self):
        for workspace in (r"E:\CodexQA\BTH\runs", r"E:\CodexQA\BTH\runs\unit-01\profile", r"E:\CodexQA\BTH\runs\unit-01"):
            self.fails("overlap", lambda: self.plan(workspace=workspace))
        self.assertEqual(self.fs.writes, [])

    def test_invalid_budgets_and_ids_fail_before_writes(self):
        for name in ("reserve_bytes", "expected_write_bytes"):
            for value in (-1, True, 1.5, "4"):
                with self.subTest(name=name, value=value):
                    self.fails("invalid_budget", lambda: self.plan(**{name: value}))
        for run_id in ("", "../x", "bad space", "x" * 81, None):
            self.fails("invalid_run_id", lambda: self.plan(run_id=run_id))
        self.assertEqual(self.fs.writes, [])


if __name__ == "__main__":
    unittest.main()
