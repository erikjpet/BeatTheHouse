#!/usr/bin/env python3
"""Regression coverage for the reviewed current-v2 slot consolidation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "migrate_environment_slots_v2.py"
SPEC = importlib.util.spec_from_file_location(
    "environment_slot_consolidation", MODULE_PATH
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load migration module: {MODULE_PATH}")
MIGRATION = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MIGRATION)


class EnvironmentSlotConsolidationTests(unittest.TestCase):
    def _ledger(self) -> dict:
        return json.loads(
            MIGRATION.CONSOLIDATION_LEDGER_PATH.read_text(encoding="utf-8")
        )

    def _placement(self) -> dict:
        return json.loads(MIGRATION.PLACEMENT_PATH.read_text(encoding="utf-8"))

    def test_ledger_accounts_for_every_source_and_target_row(self) -> None:
        ledger = self._ledger()
        placement = self._placement()
        rows = ledger["slot_dispositions"]
        self.assertEqual(ledger["source"]["slot_count"], 722)
        self.assertEqual(ledger["target"]["slot_count"], 659)
        self.assertEqual(len(rows), 722)
        source_keys = {
            (row["map_id"], row["source_family"], row["source_slot_id"])
            for row in rows
        }
        self.assertEqual(len(source_keys), 722)

        final_slots = {
            (map_data["id"], slot["id"]): (family, slot)
            for map_data in placement["maps"]
            for family in MIGRATION.FAMILIES
            for slot in map_data[f"{family}_slots"]
        }
        self.assertEqual(len(final_slots), 659)
        for row in rows:
            with self.subTest(
                map_id=row["map_id"], source_slot_id=row["source_slot_id"]
            ):
                self.assertIn(
                    row["disposition"], {"keep", "rename", "merge", "remove"}
                )
                if row["disposition"] == "remove":
                    self.assertIsNone(row["target_family"])
                    self.assertIsNone(row["target_slot_id"])
                else:
                    key = (row["map_id"], row["target_slot_id"])
                    self.assertIn(key, final_slots)
                    self.assertEqual(final_slots[key][0], row["target_family"])
                collision = row["collision"]
                sources = collision["source_slot_ids"]
                self.assertEqual(sources, sorted(set(sources)))
                self.assertEqual(collision["has_collision"], len(sources) > 1)
                if collision["has_collision"]:
                    self.assertIn(row["source_slot_id"], sources)
                    self.assertEqual(
                        collision["policy"],
                        "prefer_exact_target_then_source_order",
                    )

        introduced = ledger["introduced_target_slots"]
        traced_target_keys = {
            (row["map_id"], row["target_slot_id"])
            for row in rows
            if row["target_slot_id"]
        }
        introduced_keys = {
            (row["map_id"], row["slot_id"]) for row in introduced
        }
        self.assertTrue(introduced_keys.isdisjoint(traced_target_keys))
        self.assertEqual(traced_target_keys | introduced_keys, set(final_slots))
        self.assertEqual(
            ledger["counts"]["introduced_target_slots"], len(introduced)
        )

    def test_checked_in_ledger_is_deterministic_and_current(self) -> None:
        expected = MIGRATION.consolidation_ledger_payload("check")
        self.assertEqual(expected, self._ledger())
        self.assertEqual(
            expected["target"]["sha256"],
            MIGRATION._sha256(MIGRATION.PLACEMENT_PATH.read_bytes()),
        )

    def test_report_translation_prefers_exact_target_and_surfaces_losses(self) -> None:
        report = {
            "schema_version": 2,
            "rooms": {
                "bar": {
                    "slot_positions": {
                        "scenario.surface_item_1": [101, 102],
                        "scenario.surface_item_3": [301, 302],
                        "unknown.slot": [901, 902],
                    }
                },
                "back_alley": {
                    "slot_positions": {
                        "scenario.item_shop_1": [201, 202],
                    }
                },
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / "input.json"
            output_path = Path(directory) / "output.json"
            input_path.write_text(json.dumps(report), encoding="utf-8")
            MIGRATION.translate_placement_report(input_path, output_path)
            translated = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(
            translated["rooms"]["bar"]["slot_positions"][
                "scenario.surface_item_1"
            ],
            [101, 102],
        )
        bar_report = translated["migration_report"]["rooms"]["bar"]
        self.assertEqual(bar_report["unmapped_source_slot_ids"], ["unknown.slot"])
        self.assertEqual(
            bar_report["merge_collisions"],
            [{
                "target_slot_id": "scenario.surface_item_1",
                "chosen_source_slot_id": "scenario.surface_item_1",
                "ignored_source_slot_ids": ["scenario.surface_item_3"],
                "policy": "prefer_exact_target_then_source_order",
            }],
        )
        self.assertNotIn("back_alley", translated["rooms"])
        self.assertEqual(
            translated["migration_report"]["rooms"]["back_alley"][
                "removed_source_slot_ids"
            ],
            ["scenario.item_shop_1"],
        )
        self.assertEqual(translated["migration_report"]["removed_positions"], 1)
        self.assertEqual(translated["migration_report"]["unmapped_positions"], 1)
        self.assertEqual(translated["migration_report"]["merge_collisions"], 1)


if __name__ == "__main__":
    unittest.main()
