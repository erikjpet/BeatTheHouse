"""Read-only source proof of the legacy Grand layout inverse; no engine/imports."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

BASELINE = "89403f389a5807e050a450cd27b1bd93b3a4a41e"
PLACEMENT = "data/environments/placement_surfaces.json"
PLACEMENT_BLOB = "9b78e3642c63534cae99e3cd6c8cd9e6e59385cd"
HELPER = "scripts/core/grand_coin_pusher_layout_compatibility.gd"


def inverse(current: dict, room: str) -> dict:
    # Static mirror of the small pure production helper. Runtime use of that
    # helper, cache isolation and saved seals are covered by the GDScript check.
    result = json.loads(json.dumps(current))
    fields = ("class_overrides", "fixed_object_slot_ids", "object_family_ids")
    if room == "grand_casino":
        for field in fields:
            result[field] = {
                "game:pull_tabs" if key == "game:coin_pusher" else key: value
                for key, value in result[field].items()
            }
        slot = next(row for row in result["fixed_slots"] if row["id"] == "fixed.game_machine_5")
        slot["physical_role"] = "Pull Tabs machine"
        slot["occupant_ids"] = ["game:pull_tabs"]
    else:
        for field in fields:
            result[field].pop("game:coin_pusher")
        result["fixed_category_slot_ids"].pop("game_spots:4")
        result["fixed_slots"] = [row for row in result["fixed_slots"] if row["id"] != "fixed.game_coin_pusher"]
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--git", default="git")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    git = [args.git, "-C", str(root)]
    blob = subprocess.check_output(git + ["rev-parse", f"{BASELINE}:{PLACEMENT}"], text=True).strip()
    assert blob == PLACEMENT_BLOB, blob
    old = json.loads(subprocess.check_output(git + ["show", f"{BASELINE}:{PLACEMENT}"], encoding="utf-8"))
    current = json.loads((root / PLACEMENT).read_text(encoding="utf-8"))
    old_maps = {row["id"]: row for row in old["maps"]}
    current_maps = {row["id"]: row for row in current["maps"]}
    old_archetypes = json.loads(subprocess.check_output(
        git + ["show", f"{BASELINE}:data/environments/archetypes.json"], encoding="utf-8"))
    old_archetypes = {row["id"]: row for row in old_archetypes}
    fixture = json.loads((root / "scripts/tests/fixtures/pull_tab_grand_historical_89403f389.json").read_text(encoding="utf-8"))
    assert fixture["source"]["commit"] == BASELINE
    assert fixture["archetype"] == old_archetypes["grand_casino"]
    assert fixture["high_limit_archetype"] == old_archetypes["grand_casino_high_limit"]
    changed = [key for key in old_maps if old_maps[key] != current_maps[key]]
    assert changed == ["grand_casino", "grand_casino_high_limit"], changed
    receipts = []
    for room in changed:
        restored = inverse(current_maps[room], room)
        assert restored == old_maps[room], f"{room}: full semantic inverse mismatch"
        # This additional comparison also catches a changed authored key order.
        expected = json.dumps(old_maps[room], ensure_ascii=False, separators=(",", ":"))
        actual = json.dumps(restored, ensure_ascii=False, separators=(",", ":"))
        assert actual == expected, f"{room}: authored serialization order mismatch"
        receipts.append({"room": room, "full_map_semantic_equal": True, "authored_order_equal": True,
                         "canonical_static_sha256": hashlib.sha256(actual.encode()).hexdigest()})
    print(json.dumps({"baseline": BASELINE, "placement_blob": blob,
                      "helper_sha256": hashlib.sha256((root / HELPER).read_bytes()).hexdigest(),
                      "maps": receipts, "historical_archetypes_match_baseline": True,
                      "scope": "read-only Python mirror of production inverse; no GDScript/runtime claim"}))


if __name__ == "__main__":
    main()
