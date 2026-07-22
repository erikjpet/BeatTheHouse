"""Audit which repository art files have a live rendering owner.

The art manifest is intentionally reported separately: validation reads it, but
the running game currently resolves art from content data and a few explicit
path conventions instead.
"""

from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ART_ROOT = ROOT / "assets" / "art"
REPORT_JSON = ROOT / ".tmp" / "runtime_art_asset_audit.json"
REPORT_MD = ROOT / ".tmp" / "runtime_art_asset_audit.md"
RES_PATTERN = re.compile(r"res://assets/art/[A-Za-z0-9_./-]+\.png")


def project_path(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def json_files() -> list[Path]:
    return sorted((ROOT / "data").rglob("*.json"))


def runtime_code_files() -> list[Path]:
    return sorted(
        path
        for path in (ROOT / "scripts").rglob("*.gd")
        if "tests" not in path.parts
    )


def text_references(path: Path) -> set[str]:
    return set(RES_PATTERN.findall(path.read_text(encoding="utf-8", errors="replace")))


def walk_icon_keys(value: object) -> set[str]:
    result: set[str] = set()
    if isinstance(value, dict):
        key = value.get("icon_key")
        if isinstance(key, str) and key.strip():
            result.add(key.strip())
        for child in value.values():
            result.update(walk_icon_keys(child))
    elif isinstance(value, list):
        for child in value:
            result.update(walk_icon_keys(child))
    return result


def image_facts(path: Path) -> dict[str, object]:
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        extrema = alpha.getextrema()
        return {
            "width": rgba.width,
            "height": rgba.height,
            "has_transparency": bool(extrema and extrema[0] < 255),
            "bytes": path.stat().st_size,
        }


def collect_owners() -> tuple[dict[str, set[str]], set[str]]:
    owners: dict[str, set[str]] = defaultdict(set)
    manifest_refs: set[str] = set()
    manifest_path = ROOT / "data" / "art" / "art_manifest.json"

    for path in json_files():
        refs = text_references(path)
        if path == manifest_path:
            manifest_refs.update(refs)
            continue
        for ref in refs:
            owners[ref].add(f"data:{path.relative_to(ROOT).as_posix()}")

    for path in runtime_code_files():
        for ref in text_references(path):
            owners[ref].add(f"code:{path.relative_to(ROOT).as_posix()}")

    # Meta collection UI builds item paths directly from collection icon_key.
    collections_path = ROOT / "data" / "collections" / "collections.json"
    collections = json.loads(collections_path.read_text(encoding="utf-8"))
    for icon_key in walk_icon_keys(collections):
        owners[f"res://assets/art/items/{icon_key}.png"].add(
            "convention:meta_item_interaction_view_model(icon_key)"
        )

    # World-map nodes resolve their archetype IDs through this directory. The
    # canvas also prewarms every PNG here, so each existing map icon is a live
    # candidate rather than an art-manifest-only entry.
    for path in sorted((ART_ROOT / "map_icons").glob("*.png")):
        owners[project_path(path)].add("convention:world_map_canvas(archetype_id)")

    return owners, manifest_refs


def build_report() -> dict[str, object]:
    owners, manifest_refs = collect_owners()
    rows: list[dict[str, object]] = []
    for path in sorted(ART_ROOT.rglob("*.png")):
        ref = project_path(path)
        live_owners = sorted(owners.get(ref, set()))
        if live_owners:
            status = "live"
        elif ref in manifest_refs:
            status = "manifest_only"
        else:
            status = "unowned"
        rows.append(
            {
                "path": ref,
                "family": path.relative_to(ART_ROOT).parts[0],
                "status": status,
                "owners": live_owners,
                **image_facts(path),
            }
        )

    counts = Counter(str(row["status"]) for row in rows)
    family_counts: dict[str, Counter[str]] = defaultdict(Counter)
    for row in rows:
        family_counts[str(row["family"])][str(row["status"])] += 1
    return {
        "summary": dict(sorted(counts.items())),
        "families": {
            family: dict(sorted(values.items()))
            for family, values in sorted(family_counts.items())
        },
        "runtime_chains": {
            "inventory_containers": "data/ui/inventory_containers.json -> InventoryContainerCatalog -> InventoryContainerSurface TextureRect",
            "run_items": "data/items/items.json asset_path -> RunActionService -> RunInventoryViewModel -> InventoryContainerSurface TextureRect",
            "meta_collection_items": "data/collections/collections.json icon_key -> MetaItemInteractionViewModel convention -> InventoryContainerSurface TextureRect",
            "environments": "data/environments/archetypes.json asset_path -> EnvironmentInstance/FoundationMain -> PixelSceneCanvas",
            "games": "data/games/games.json asset_path/scene_asset_path -> EnvironmentInteractionViewModel/game surface",
            "events": "data/events/events.json asset_path -> FoundationActionViewModel/EnvironmentInteractionViewModel -> PixelSceneCanvas",
            "map_icons": "world-map archetype_id -> assets/art/map_icons/<id>.png -> WorldMapCanvas",
            "run_outcomes": "data/art/run_outcome_icons.json icon_path -> RunReportViewModel -> RunReportScreen",
        },
        "assets": rows,
    }


def write_markdown(report: dict[str, object]) -> None:
    lines = [
        "# Runtime art asset audit",
        "",
        "Generated by `tools/audit_rendered_art.py`.",
        "",
        "`live` means a runtime data/code owner or an explicit runtime path convention. "
        "`manifest_only` means the file is listed by the validation manifest but no runtime renderer owns that path. "
        "`unowned` means neither was found.",
        "",
        "## Family summary",
        "",
        "| Family | Live | Manifest only | Unowned |",
        "| --- | ---: | ---: | ---: |",
    ]
    for family, values in report["families"].items():
        lines.append(
            f"| {family} | {values.get('live', 0)} | {values.get('manifest_only', 0)} | {values.get('unowned', 0)} |"
        )
    lines.extend(["", "## Render chains", ""])
    for name, chain in report["runtime_chains"].items():
        lines.append(f"- `{name}`: {chain}")
    for status in ("manifest_only", "unowned"):
        selected = [row for row in report["assets"] if row["status"] == status]
        lines.extend(["", f"## {status.replace('_', ' ').title()} ({len(selected)})", ""])
        if not selected:
            lines.append("None.")
        else:
            lines.extend(f"- `{row['path']}`" for row in selected)
    REPORT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    report = build_report()
    REPORT_JSON.parent.mkdir(parents=True, exist_ok=True)
    REPORT_JSON.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    write_markdown(report)
    print(json.dumps(report["summary"], sort_keys=True))
    print(REPORT_MD)


if __name__ == "__main__":
    main()
