#!/usr/bin/env python3
"""Engine-free checks for authenticated historical custody byte portability."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = Path("scripts/tests/fixtures/integ06_1/mid_0_6")
# Frozen original identities, also recorded by the unchanged provenance files.
ORIGINAL_SHA256 = {
    "mid06_pre_environment_depth_bar_dice": "ed3ae47e67a4c4064fb8fa80376ba3475bb86713602b03724e3905807cea6494",
    "mid06_pre_game_depth_slot": "94f5ff10e3bf254057a16087294906a636167303dfe14baf88a78064e39c351e",
    "mid06_pre_world_depth_crew_debt": "f2a5301d9cd162a9fe3ef9b8b0cacd2a46f48fa1e5449584489d0a9ea7e71b16",
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class HistoricalCustodyByteTests(unittest.TestCase):
    def test_original_provenance_and_raw_bytes(self) -> None:
        for fixture, expected in ORIGINAL_SHA256.items():
            with self.subTest(fixture=fixture):
                provenance = json.loads(
                    (ROOT / FIXTURES / f"{fixture}.provenance.json").read_text(
                        encoding="utf-8-sig"
                    )
                )
                self.assertEqual(provenance["custody_inventory_sha256"].lower(), expected)
                raw = (ROOT / FIXTURES / f"{fixture}.custody.json").read_bytes()
                self.assertEqual(sha256(raw), expected)
                self.assertTrue(raw.startswith(b"\xef\xbb\xbf"))
                self.assertNotIn(b"\n", raw.replace(b"\r\n", b""))
                # The LF conversion that caused the regression must still fail
                # the original raw-byte hash; never normalize the integrity input.
                self.assertNotEqual(sha256(raw.replace(b"\r\n", b"\n")), expected)
                custody = json.loads(raw.decode("utf-8-sig"))
                self.assertEqual(
                    custody["schema"],
                    "beat_the_house.integ06_1_historical_custody_inventory",
                )
                self.assertEqual(custody["historical_commit"], provenance["historical_commit"])
                # Paths inventoried by the custody document are never traversed.

    @unittest.skipUnless(shutil.which("git"), "Git is required for checkout portability")
    def test_git_storage_and_checkout_keep_original_bytes(self) -> None:
        env = os.environ.copy()
        for name in (
            "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY",
            "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_CONFIG_COUNT",
        ):
            env.pop(name, None)
        env.update({
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_ATTR_NOSYSTEM": "1",
        })
        temp_root = Path(tempfile.gettempdir()).resolve()
        with tempfile.TemporaryDirectory(prefix="bth-custody-bytes-", dir=temp_root) as temporary:
            work = Path(temporary).resolve()
            # Verify the exact recursive-cleanup target before TemporaryDirectory
            # owns any files. Only this newly created temporary directory is removed.
            self.assertTrue(work.is_relative_to(temp_root))
            self.assertNotEqual(work, temp_root)

            def git(*arguments: str) -> bytes:
                result = subprocess.run(
                    ["git", "-C", str(work), *arguments],
                    env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                )
                if result.returncode:
                    raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
                return result.stdout

            git("init", "--quiet")
            shutil.copyfile(ROOT / ".gitattributes", work / ".gitattributes")
            paths = []
            for fixture in ORIGINAL_SHA256:
                relative = FIXTURES / f"{fixture}.custody.json"
                destination = work / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, destination)
                paths.append(relative.as_posix())
            # Stage under the conversion setting that originally lost the CR bytes.
            git("-c", "core.autocrlf=true", "add", "--", ".gitattributes", *paths)
            for fixture, relative in zip(ORIGINAL_SHA256, paths):
                with self.subTest(fixture=fixture, stage="git-blob"):
                    self.assertEqual(sha256(git("show", f":{relative}")), ORIGINAL_SHA256[fixture])
            for name, autocrlf, eol in (
                ("lf", "false", "lf"),
                ("crlf", "true", "crlf"),
                ("input", "input", "lf"),
            ):
                checkout = work / name
                self.assertTrue(checkout.resolve().is_relative_to(work))
                checkout.mkdir()
                git(
                    "-c", f"core.autocrlf={autocrlf}", "-c", f"core.eol={eol}",
                    "checkout-index", "--all", "--force", f"--prefix={checkout.as_posix()}/",
                )
                for fixture, relative in zip(ORIGINAL_SHA256, paths):
                    with self.subTest(fixture=fixture, checkout=name):
                        self.assertEqual(
                            sha256((checkout / relative).read_bytes()), ORIGINAL_SHA256[fixture]
                        )


if __name__ == "__main__":
    unittest.main()
