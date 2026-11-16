"""In-memory selected-source contracts; run only through an admitted QA worker.

These fixtures create no directories or files and launch no child processes.
They exercise Git inventory and tar parsing, not a mocked verification result.
"""
import sys
sys.dont_write_bytecode = True

import copy
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import tarfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bth_qa_selected_source_v2 as selected


COMMIT = "a" * 40
TREE = "b" * 40
SCOPE = "PARTIAL_SELECTED_PATH_ARCHIVE"
ROOTS = {"assets", "data", "native", "scenes", "scripts", "tools"}
FLAT = {
    ".gdlintrc", ".gitattributes", ".gitignore", "AGENTS.md", "CHANGELOG.md",
    "README.md", "default_bus_layout.tres", "export_presets.cfg", "icon.svg",
    "project.godot",
}
DOCS = {
    "docs/.gdignore",
    "docs/plans/world06_1_crew_sequence_adapter_contract.md",
    "docs/archive/0.5/plans/0.5_voice_bible.md",
    "docs/todo/environment_slot_family_manifest_legacy_mapping.json",
    "docs/todo/environment_slot_consolidation_disposition.json",
}


def git_blob_oid(data):
    # Independent Git object framing, including a NUL after the decimal length.
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


def fixture_files():
    files = {name: (name + "\n").encode("ascii") for name in FLAT | DOCS}
    files[".gitattributes"] = selected.BASELINE_ATTRIBUTES
    files.update({
        "assets/example.png": b"a synthetic source asset\n",
        "data/example.json": b'{"fixture":true}\n',
        "native/coin_pusher/toolchain.lock.json": b'{"fixture":"pin"}\n',
        "scenes/main.tscn": b'[gd_scene format=3]\n[node name="Main" type="Control"]\n',
        "scripts/example.gd": b"extends RefCounted\n",
        "tools/example.py": b'print("fixture only; never executed")\n',
    })
    return files


def ls_tree(files, modes=None):
    modes = modes or {}
    return "".join(
        f"{modes.get(name, '100644')} blob {git_blob_oid(data)} {len(data):7d}\t{name}\0"
        for name, data in sorted(files.items())
    )


def make_plan(files=None, modes=None):
    return selected.selection_plan(
        COMMIT + "\n" + TREE + "\n", ls_tree(fixture_files() if files is None else files, modes),
        COMMIT, TREE,
    )


def ancestor_directories(files):
    return sorted({
        parent.as_posix()
        for name in files
        for parent in PurePosixPath(name).parents
        if parent.as_posix() != "."
    })


def member(name, data=b"", kind=tarfile.REGTYPE, mode=0o644, linkname=""):
    info = tarfile.TarInfo(name)
    info.type, info.mode, info.linkname = kind, mode, linkname
    info.size = len(data) if kind == tarfile.REGTYPE else 0
    return info, data


def archive_bytes(files=None, modes=None, directories=None, extra=(),
                  replacements=None, comment=COMMIT):
    files = fixture_files() if files is None else files
    modes, replacements = modes or {}, replacements or {}
    directories = ancestor_directories(files) if directories is None else directories
    buffer = io.BytesIO()
    headers = {} if comment is None else {"comment": comment}
    with tarfile.open(fileobj=buffer, mode="w", format=tarfile.PAX_FORMAT,
                      pax_headers=headers) as package:
        for name in directories:
            info, data = member(name + "/", kind=tarfile.DIRTYPE, mode=0o755)
            package.addfile(info)
        for name, data in sorted(files.items()):
            info, data = replacements.get(
                name, member(name, data, mode=0o755 if modes.get(name) == "100755" else 0o644))
            package.addfile(info, io.BytesIO(data) if info.isreg() else None)
        for info, data in extra:
            package.addfile(info, io.BytesIO(data) if info.isreg() else None)
    return buffer.getvalue()


def verify(raw, plan=None):
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as package:
        return selected.verify_tar_stream(package, make_plan() if plan is None else plan)


class SelectedInventoryContractTests(unittest.TestCase):
    def test_fixed_scope_keeps_runtime_qa_pins_and_assertion_documents(self):
        self.assertEqual(len(selected.PATHS), 21)
        self.assertEqual(set(selected.PATHS), ROOTS | FLAT | DOCS)

    def test_plan_labels_partial_scope_and_binds_all_selected_objects(self):
        files = fixture_files()
        plan = make_plan(files)
        self.assertEqual(plan["scope"], SCOPE)
        self.assertEqual((plan["source_commit"], plan["source_tree"]), (COMMIT, TREE))
        self.assertEqual(set(plan["files"]), set(files))
        for name, data in files.items():
            self.assertEqual(plan["files"][name], {
                "mode": "100644", "oid": git_blob_oid(data), "bytes": len(data)})

    def test_inventory_accepts_nul_delimited_bytes_and_text_equally(self):
        text = ls_tree(fixture_files())
        self.assertEqual(selected.parse_ls_tree(text.encode("ascii")), selected.parse_ls_tree(text))

    def test_unselected_historical_media_are_not_silently_added(self):
        files = fixture_files()
        files["review_artifacts/historical.mp4"] = b"historical media"
        files["docs/unrelated.md"] = b"an unrelated document"
        plan = make_plan(files)
        self.assertNotIn("review_artifacts/historical.mp4", plan["files"])
        self.assertNotIn("docs/unrelated.md", plan["files"])

    def test_each_required_selector_must_exist_in_actual_tree(self):
        files = fixture_files()
        for name in files:
            with self.subTest(missing=name):
                missing = dict(files)
                del missing[name]
                with self.assertRaises(ValueError):
                    make_plan(missing)

    def test_mandatory_leaf_cannot_be_substituted_by_a_directory(self):
        for name in FLAT | DOCS:
            with self.subTest(leaf=name):
                files = fixture_files()
                data = files.pop(name)
                files[name + "/descendant.txt"] = data
                with self.assertRaises(ValueError):
                    make_plan(files)

    def test_identity_requires_actual_commit_and_tree(self):
        for identity in (
            "c" * 40 + "\n" + TREE + "\n",
            COMMIT + "\n" + "d" * 40 + "\n",
            COMMIT + "\n" + TREE + "\nextra\n",
        ):
            with self.subTest(identity=identity), self.assertRaises(ValueError):
                selected.selection_plan(identity, ls_tree(fixture_files()), COMMIT, TREE)

    def test_nonhex_source_identity_is_rejected(self):
        with self.assertRaises(ValueError):
            selected.selection_plan("z" * 40 + "\n" + TREE + "\n",
                                    ls_tree(fixture_files()), "z" * 40, TREE)

    def test_newline_inventory_is_not_the_nul_delimited_protocol(self):
        with self.assertRaises(ValueError):
            selected.parse_ls_tree(ls_tree(fixture_files()).replace("\0", "\n"))

    def test_duplicate_and_case_aliased_git_records_are_rejected(self):
        row = ls_tree({"assets/fixture.png": b"fixture"})
        for text in (row + row, row + row.replace("assets/fixture.png", "assets/FIXTURE.png")):
            with self.subTest(text=text), self.assertRaises(ValueError):
                selected.parse_ls_tree(text)

    def test_case_aliased_ancestor_directories_are_rejected(self):
        with self.assertRaises(ValueError):
            selected.parse_ls_tree(ls_tree({"assets/A/one.png": b"one", "assets/a/two.png": b"two"}))

    def test_nonregular_git_modes_and_nonblob_objects_are_rejected(self):
        row = ls_tree({"assets/fixture.png": b"fixture"})
        for text in (
            row.replace("100644", "120000", 1),
            row.replace("100644", "160000", 1).replace(" blob ", " commit ", 1),
            row.replace(" blob ", " tree ", 1),
        ):
            with self.subTest(text=text), self.assertRaises(ValueError):
                selected.parse_ls_tree(text)

    def test_unsafe_noncanonical_or_quoted_git_paths_are_rejected(self):
        bad_paths = (
            "../escape", "/absolute", "C:/drive", "assets/../escape", "assets//alias",
            "assets\\backslash", '"assets/quoted.png"', "assets/tab\tname",
            "assets/line\nname", "assets/nonascii-\u00e9.png", "assets/a<b.png",
            "assets/a>b.png", "assets/a|b.png", "assets/a?b.png", "assets/a*b.png",
            "assets/" + "x" * 256,
        )
        for name in bad_paths:
            with self.subTest(path=name), self.assertRaises(ValueError):
                selected.parse_ls_tree(ls_tree({name: b"fixture"}))

    def test_malformed_sizes_and_oids_are_rejected(self):
        row = ls_tree({"assets/fixture.png": b"fixture"})
        oid = git_blob_oid(b"fixture")
        for text in (
            row.replace("      7\t", "     -7\t"),
            row.replace("      7\t", "   True\t"),
            row.replace(oid, "g" * 40),
            row.replace(oid, oid[:-1]),
        ):
            with self.subTest(text=text), self.assertRaises(ValueError):
                selected.parse_ls_tree(text)

    def test_input_order_does_not_change_selected_inventory_digest(self):
        text = ls_tree(fixture_files())
        reversed_text = "\0".join(reversed(text[:-1].split("\0"))) + "\0"
        original = make_plan()
        reordered = selected.selection_plan(COMMIT + "\n" + TREE + "\n", reversed_text, COMMIT, TREE)
        self.assertEqual(original["files"], reordered["files"])
        self.assertEqual(original["selection_sha256"], reordered["selection_sha256"])

    def test_pure_planning_and_tar_verification_do_not_launch_guarded_children(self):
        with patch.object(selected, "execute", side_effect=AssertionError("Pure API launched a child")) as launch:
            plan = make_plan()
            selected.parse_ls_tree(ls_tree(fixture_files()))
            verify(archive_bytes(), plan)
            launch.assert_not_called()

    def test_small_source_fits_the_default_write_budget_without_reducing_reserve(self):
        result = selected.write_budget(make_plan(), 4 * 1024 ** 3)
        self.assertTrue(result["capacity_reserve_unchanged"])
        self.assertLessEqual(result["archive_extraction_evidence_upper_bound_bytes"], 4 * 1024 ** 3)

    def test_write_budget_must_include_tar_extraction_and_evidence_not_just_payload(self):
        plan = make_plan()
        with self.assertRaises(ValueError):
            selected.write_budget(plan, plan["selected_bytes"])

    def test_write_budget_must_be_a_positive_integer(self):
        for budget in (True, False, 0, -1, 4.0, "4294967296"):
            with self.subTest(budget=budget), self.assertRaises(ValueError):
                selected.write_budget(make_plan(), budget)


class SelectedTarContractTests(unittest.TestCase):
    def test_exact_archive_yields_git_and_sha256_evidence_for_every_file(self):
        files = fixture_files()
        proof = verify(archive_bytes())
        self.assertEqual(proof["scope"], SCOPE)
        self.assertEqual((proof["source_commit"], proof["source_tree"]), (COMMIT, TREE))
        self.assertEqual(proof["selection_sha256"], make_plan()["selection_sha256"])
        self.assertEqual(proof["file_count"], len(files))
        self.assertEqual(proof["directory_count"], len(ancestor_directories(files)))
        self.assertEqual(set(proof["files"]), set(files))
        for name, data in files.items():
            self.assertEqual(proof["files"][name], {
                "mode": "100644", "oid": git_blob_oid(data), "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest()})

    def test_planned_executable_git_mode_is_preserved(self):
        modes = {"tools/example.py": "100755"}
        proof = verify(archive_bytes(modes=modes), make_plan(modes=modes))
        self.assertEqual(proof["files"]["tools/example.py"]["mode"], "100755")

    def test_missing_file_is_rejected(self):
        files = fixture_files()
        del files["scripts/example.gd"]
        with self.assertRaises(ValueError):
            verify(archive_bytes(files))

    def test_unplanned_file_even_under_selected_root_is_rejected(self):
        with self.assertRaises(ValueError):
            verify(archive_bytes(extra=[member("assets/unplanned.png", b"extra")]))

    def test_all_expected_ancestor_directories_are_required(self):
        directories = ancestor_directories(fixture_files())
        directories.remove("docs/archive/0.5")
        with self.assertRaises(ValueError):
            verify(archive_bytes(directories=directories))

    def test_unplanned_empty_directory_is_rejected(self):
        with self.assertRaises(ValueError):
            verify(archive_bytes(extra=[member("assets/extra/", kind=tarfile.DIRTYPE, mode=0o755)]))

    def test_duplicate_file_and_duplicate_directory_are_rejected(self):
        duplicates = [member("scripts/example.gd", fixture_files()["scripts/example.gd"]),
                      member("assets/", kind=tarfile.DIRTYPE, mode=0o755)]
        for duplicate in duplicates:
            with self.subTest(name=duplicate[0].name), self.assertRaises(ValueError):
                verify(archive_bytes(extra=[duplicate]))

    def test_case_alias_is_rejected(self):
        with self.assertRaises(ValueError):
            verify(archive_bytes(extra=[member("assets/EXAMPLE.png", b"alias")]))

    def test_links_and_special_members_cannot_stand_in_for_planned_file(self):
        name = "scripts/example.gd"
        for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE, tarfile.CHRTYPE):
            replacement = member(name, kind=kind, linkname="../outside")
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                verify(archive_bytes(replacements={name: replacement}))

    def test_escaping_and_noncanonical_archive_names_are_rejected(self):
        for name in ("../outside", "/outside", "C:/outside", "assets/../outside",
                     "assets//extra", "assets\\extra", "assets/line\nname"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                verify(archive_bytes(extra=[member(name, b"extra")]))

    def test_pax_effective_path_cannot_escape_a_safe_literal_header(self):
        name = "scripts/example.gd"
        replacement = member(name, fixture_files()[name])
        replacement[0].pax_headers = {"path": "../outside"}
        with self.assertRaises(ValueError):
            verify(archive_bytes(replacements={name: replacement}))

    def test_file_cannot_replace_an_existing_ancestor_directory(self):
        with self.assertRaises(ValueError):
            verify(archive_bytes(extra=[member("assets", b"not a directory")]))

    def test_git_pax_commit_is_required_and_must_match(self):
        for comment in (None, "c" * 40, COMMIT + "\n"):
            with self.subTest(comment=comment), self.assertRaises(ValueError):
                verify(archive_bytes(comment=comment))

    def test_same_length_payload_tampering_is_rejected_by_git_oid(self):
        files = fixture_files()
        original = files["scripts/example.gd"]
        files["scripts/example.gd"] = b"X" + original[1:]
        self.assertEqual(len(files["scripts/example.gd"]), len(original))
        with self.assertRaises(ValueError):
            verify(archive_bytes(files))

    def test_newline_transformation_is_not_a_matching_source_blob(self):
        files = fixture_files()
        files["scripts/example.gd"] = files["scripts/example.gd"].replace(b"\n", b"\r\n")
        with self.assertRaises(ValueError):
            verify(archive_bytes(files))

    def test_regular_file_mode_cannot_change_to_executable(self):
        with self.assertRaises(ValueError):
            verify(archive_bytes(modes={"scripts/example.gd": "100755"}))

    def test_plan_cannot_claim_boolean_as_file_length(self):
        plan = copy.deepcopy(make_plan())
        plan["files"]["assets/example.png"]["bytes"] = True
        plan["selection_sha256"] = hashlib.sha256(json.dumps(
            plan["files"], sort_keys=True, separators=(",", ":")).encode("ascii")).hexdigest()
        with self.assertRaises(ValueError):
            verify(archive_bytes(), plan)

    def test_relabelled_full_snapshot_is_not_accepted(self):
        plan = copy.deepcopy(make_plan())
        plan["scope"] = "FULL_SOURCE_CHECKOUT"
        with self.assertRaises(ValueError):
            verify(archive_bytes(), plan)


class SelectedTarTrailerContractTests(unittest.TestCase):
    def test_unparsed_trailing_payload_is_rejected(self):
        with self.assertRaises(ValueError):
            verify(archive_bytes() + b"X" * 512)

    def test_concatenated_second_archive_is_rejected(self):
        with self.assertRaises(ValueError):
            verify(archive_bytes() + archive_bytes())

    def test_missing_both_tar_eof_records_is_rejected(self):
        raw = archive_bytes()
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as package:
            package.getmembers()
            payload_end = package.offset
        with self.assertRaises((ValueError, tarfile.ReadError)):
            verify(raw[:payload_end])


class SelectedPriorReceiptContractTests(unittest.TestCase):
    def setUp(self):
        self.cfg = {
            "workspace": "E:/CodexQA/BTH/workspaces/SELECTED-CONTRACT",
            "archive": "E:/CodexQA/BTH/workspaces/SELECTED-CONTRACT/source.tar",
            "destination": "E:/CodexQA/BTH/workspaces/SELECTED-CONTRACT/source",
            "git": "D:/fixture/git.exe", "git_dir": "D:/fixture/repo.git",
            "source_commit": COMMIT, "source_tree": TREE,
            "baseline_stage": str(selected.BASE_STAGE),
            "overlay_descriptor": "E:/CodexQA/BTH/workspaces/fixture/native.gdextension",
            "run_prefix": "SELECTED-CONTRACT", "timeout": 1200,
        }
        self.phase = "select"
        evidence = selected.evidence_for(self.cfg, self.phase)
        fingerprint, value = selected.digest(self.cfg), "e" * 64
        command = selected.phase_command(self.cfg, self.phase)
        self.documents = {
            "phase-result.json": {
                "schema": selected.PHASE_SCHEMA, "phase": self.phase, "status": "PASS", "scope": SCOPE,
                "config_sha256": fingerprint, "job_receipt": str(evidence / "job.json"),
                "job_sha256": value, "log_sha256": value,
                "artifact_sha256": {name: value for name in ("worker-result.json", "selection.json", "closure.json")},
            },
            "job.json": {
                "schema": "bth.qa_guarded_run/v1", "exit_code": 0, "active_at_release": 0,
                "assigned_before_execution": True, "error": None, "cleanup_errors": [],
                "timed_out": False, "log_error": None, "log_truncated": False,
                "storage_gate_before_job": {"fixture": True}, "storage_gate_before_child": {"fixture": True},
                "limits": {"cpu_rate": 1200, "job_memory_limit_bytes": 2 * 1024 ** 3,
                           "kill_on_close": True, "breakaway_allowed": False},
                "finished_epoch": 1.0, "command": command,
                "storage_manifest": str(evidence / "storage-manifest.json"), "storage_manifest_sha256": value,
            },
            "phase-inputs.json": {"config": self.cfg, "config_sha256": fingerprint, "command": command},
            "storage-manifest.json": {"prepared": True, "paths": {
                "workspace": self.cfg["workspace"], "evidence": str(evidence)}},
            "launch-claim.json": {"manifest_sha256": value},
        }

    def read_previous(self):
        with patch.object(selected, "read_json", side_effect=lambda path: self.documents[Path(path).name]), \
                patch.object(selected, "file_sha", return_value="e" * 64):
            return selected.previous(self.cfg, self.phase)

    def test_complete_consistent_prior_receipt_is_accepted_without_file_reads(self):
        self.assertEqual(self.read_previous()["status"], "PASS")

    def test_select_artifact_custody_cannot_be_missing_empty_or_partial(self):
        complete = copy.deepcopy(self.documents["phase-result.json"]["artifact_sha256"])
        for value in (None, {}, {"selection.json": "e" * 64}):
            with self.subTest(artifacts=value):
                self.documents["phase-result.json"]["artifact_sha256"] = value
                with self.assertRaises(ValueError):
                    self.read_previous()
        self.documents["phase-result.json"]["artifact_sha256"] = complete

    def test_prior_command_must_match_the_actual_guarded_phase(self):
        self.documents["job.json"]["command"] = ["a different command"]
        with self.assertRaises(ValueError):
            self.read_previous()

    def test_prior_job_must_be_closed_at_zero(self):
        self.documents["job.json"]["active_at_release"] = 1
        with self.assertRaises(ValueError):
            self.read_previous()

    def test_archive_command_pins_umask_before_git_archive(self):
        command = selected.phase_command(self.cfg, "archive")
        archive_index = command.index("archive")
        mask_index = command.index("tar.umask=0022")
        self.assertLess(mask_index, archive_index)
        self.assertEqual(command[mask_index - 1], "-c")
        self.assertIn("--output=" + self.cfg["archive"], command)
        self.assertEqual(command[archive_index + 3:], [COMMIT, *selected.PATHS])


class ExactAttributesTests(unittest.TestCase):
    @staticmethod
    def record(raw, mode="100644"):
        return {"mode": mode, "oid": git_blob_oid(raw), "bytes": len(raw)}

    def test_exact_baseline_bytes_and_git_record_are_accepted(self):
        raw = selected.BASELINE_ATTRIBUTES
        self.assertEqual(len(raw), 1892)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "8aee1678b0fbba7a01fb435680f33e011cb17161d77666875e7913d029528699")
        self.assertEqual(git_blob_oid(raw), "585f20732573101758e50ccffbc18c256bc02235")
        proof = selected.attributes_record_policy(self.record(raw), self.record(raw))
        self.assertFalse(proof["review_only_suffix_applied"])
        self.assertEqual(proof["baseline_sha256"], proof["source_sha256"])

    def test_only_exact_review_suffix_bytes_and_record_are_accepted(self):
        raw = selected.BASELINE_ATTRIBUTES + selected.REVIEW_ATTRIBUTES_SUFFIX
        self.assertEqual(len(raw), 2097)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "8d7388ac3cd2be265a2de7730c8f695230649e05856f608d225ff2e99586f79a")
        self.assertEqual(git_blob_oid(raw), "05d30f81604b233ca99757fc7e6f3830a8b5bc0c")
        proof = selected.attributes_record_policy(self.record(selected.BASELINE_ATTRIBUTES), self.record(raw))
        self.assertTrue(proof["review_only_suffix_applied"])
        self.assertFalse(proof["runtime_paths_or_export_directives_changed"])
        self.assertFalse(proof["source_bytes_substituted"])

    def test_runtime_review_export_directive_and_prefix_edits_are_rejected(self):
        base, suffix = selected.BASELINE_ATTRIBUTES, selected.REVIEW_ATTRIBUTES_SUFFIX
        variants = [base.replace(b"/data/art/environments/bar.json -text", b"/data/art/environments/bar.json text"),
            base + suffix.replace(b"provenance.json", b"unknown.json"),
            base + suffix.replace(b"-text whitespace", b"text whitespace"),
            base + suffix + b"/assets/** export-ignore\n",
            base + suffix + b"/review_artifacts/** export-ignore\n",
            base + suffix.replace(b"independently", b"previously"),
            base.replace(b"# These historical", b"# Those historical") + suffix,
            base + suffix + b"\n", (base + suffix).replace(b"\n", b"\r\n"), b"\xef\xbb\xbf" + base]
        for raw in variants:
            with self.subTest(raw=raw[-180:]):
                with self.assertRaises(ValueError):
                    selected.attributes_bytes_policy(raw)
                with self.assertRaises(ValueError):
                    selected.attributes_record_policy(self.record(base), self.record(raw))

    def test_altered_baseline_mode_size_or_oid_cannot_authorize_a_suffix(self):
        base = self.record(selected.BASELINE_ATTRIBUTES)
        source = self.record(selected.BASELINE_ATTRIBUTES + selected.REVIEW_ATTRIBUTES_SUFFIX)
        for field, value in (("mode", "100755"), ("bytes", 1893), ("oid", "0" * 40)):
            with self.subTest(field=field):
                bad = {**base, field: value}
                with self.assertRaises(ValueError):
                    selected.attributes_record_policy(bad, source)
        for source_record in ({**source, "mode": "100755"}, {**source, "bytes": float(source["bytes"])}, {**source, "extra": "unreviewed"}):
            with self.assertRaises(ValueError):
                selected.attributes_record_policy(base, source_record)

    def test_plan_binds_literal_source_attrs_and_rejects_unknown_changes_before_archive(self):
        files = fixture_files()
        files[".gitattributes"] += selected.REVIEW_ATTRIBUTES_SUFFIX
        plan = make_plan(files)
        self.assertEqual(plan["attributes_policy"]["source_sha256"], selected.REVIEW_ATTRIBUTES_SHA)
        files[".gitattributes"] += b"/scripts/** export-ignore\n"
        with self.assertRaises(ValueError):
            make_plan(files)

    def test_actual_archive_retains_review_form_bytes_without_baseline_substitution(self):
        files = fixture_files()
        files[".gitattributes"] += selected.REVIEW_ATTRIBUTES_SUFFIX
        raw = archive_bytes(files)
        proof = verify(raw, make_plan(files))
        self.assertEqual(proof["files"][".gitattributes"]["sha256"], selected.REVIEW_ATTRIBUTES_SHA)
        self.assertTrue(proof["attributes_policy"]["actual_archive_bytes_verified"])
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as package:
            self.assertEqual(package.extractfile(".gitattributes").read(), files[".gitattributes"])
        substituted = {**files, ".gitattributes": selected.BASELINE_ATTRIBUTES}
        with self.assertRaises(ValueError):
            verify(archive_bytes(substituted), make_plan(files))

    def test_missing_or_forged_plan_and_archive_attribute_provenance_is_rejected(self):
        plan = make_plan()
        missing = copy.deepcopy(plan)
        del missing["attributes_policy"]
        with self.assertRaises(ValueError):
            selected.validate_plan(missing)
        proof = verify(archive_bytes(), plan)
        proof["attributes_policy"]["source_sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            selected.validate_tar_proof(plan, proof)


if __name__ == "__main__":
    unittest.main()
