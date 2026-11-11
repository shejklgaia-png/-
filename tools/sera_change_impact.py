#!/usr/bin/env python3
"""Read-only source dependency and change-impact hints for AI-only SERA work.

Only literal res:// GDScript preloads/loads are indexed. Dynamic calls and
runtime signal/scene references are NOT proven independent by this report.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

from sera_code_map import ROOT, extract_symbols, version_from_text

REF = re.compile(r"""(?:preload|load)\s*\(\s*["']res://([^"']+\.gd)["']\s*\)""")
# Test hints are intentionally narrow: always run the existing full CI before
# merge. A test must be present on disk and explicitly named by an audit hint.
TEST_HINTS = {
    "scripts/main.gd": ("v229_", "v230_", "v231_", "v232_", "v233_", "v234_",
                        "v237_", "v242_", "v243_", "v244_", "v245_", "v246_"),
    "scripts/touch_overlay.gd": ("v242_", "v243_", "v244_", "v245_", "v246_"),
    "scripts/sera_rig.gd": ("v199_", "v200_", "v204_", "v215_", "v227_", "v228_"),
    "scripts/back_thruster_fx.gd": ("v223_", "v224_", "v225_"),
    "scripts/command_nexus.gd": ("v198_", "v203_"),
    "scripts/target_parts.gd": ("v237_", "v242_", "v243_"),
}


def dependencies_of(source: str) -> set[str]:
    return {"scripts/" + p.removeprefix("scripts/") if p.startswith("scripts/") else p
            for p in REF.findall(source)}


def inventory(root: Path = ROOT) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for path in sorted((root / "scripts").rglob("*.gd")):
        content = path.read_text(encoding="utf-8")
        relative = path.relative_to(root).as_posix()
        result[relative] = {
            "bytes": len(content.encode("utf-8")),
            "functions": len(extract_symbols(content)),
            "depends_on": sorted(dependencies_of(content)),
            "used_by": [],
        }
    for filename, item in result.items():
        for dependency in item["depends_on"]:
            if dependency in result:
                result[dependency]["used_by"].append(filename)
    for item in result.values():
        item["used_by"].sort()
    return result


def suggested_tests(changed: list[str], root: Path = ROOT) -> list[str]:
    if not changed:
        return []
    prefixes = {prefix for path in changed for prefix in TEST_HINTS.get(path, ())}
    available = sorted((root / "tools").glob("v*_self_check.py"))
    return [p.relative_to(root).as_posix() for p in available
            if any(p.name.startswith(prefix) for prefix in prefixes)]


def impact_report(paths: list[str], root: Path = ROOT) -> dict:
    index = inventory(root)
    version = version_from_text((root / "project.godot").read_text(encoding="utf-8"))
    result = {}
    for name in paths:
        if name not in index:
            result[name] = {"present_in_scripts": False}
            continue
        item = index[name]
        result[name] = {
            "present_in_scripts": True,
            **item,
            "related_scripts": sorted(set(item["depends_on"]) | set(item["used_by"])),
        }
    return {
        "game_version": version,
        "changed_or_queried": result,
        "suggested_regression_tests": suggested_tests(paths, root),
        "caution": "Dependency graph is incomplete for dynamic calls. Full existing CI and device acceptance remain required.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--query", default="", help="script name/path substring to inspect")
    parser.add_argument("--changed", nargs="+", default=None,
                        help="explicit paths changed by an agent, e.g. scripts/main.gd")
    parser.add_argument("--summary", action="store_true", help="show the largest and most referenced scripts")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    inv = inventory()
    if args.changed is not None:
        paths = args.changed
    elif args.query:
        paths = [p for p in inv if args.query.lower() in p.lower()]
    elif args.summary:
        paths = sorted(inv, key=lambda p: (-inv[p]["bytes"], p))[:8]
    else:
        parser.error("Specify --query, --changed or --summary")
    result = impact_report(paths)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f'SERA v{result["game_version"]} dependency / impact overview:')
        for path, item in result["changed_or_queried"].items():
            if not item["present_in_scripts"]:
                print(f"- {path}: no static script entry; inspect manually")
                continue
            print(f'- {path}: {item["functions"]} funcs, {item["bytes"]} bytes')
            if item["depends_on"]:
                print('  loads: ' + ', '.join(item["depends_on"]))
            if item["used_by"]:
                print('  used by: ' + ', '.join(item["used_by"]))
        if result["suggested_regression_tests"]:
            print("Suggested scoped regression tests (in addition to FULL CI):")
            for path in result["suggested_regression_tests"]:
                print("  python3 " + path)
        print(result["caution"])


if __name__ == "__main__":
    main()
