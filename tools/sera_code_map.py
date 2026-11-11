#!/usr/bin/env python3
"""Fast, read-only function/constant locator for the current SERA source.

Examples:
  python3 tools/sera_code_map.py camera
  python3 tools/sera_code_map.py boost --include-constants
  python3 tools/sera_code_map.py --summary
  python3 tools/sera_code_map.py lock --json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FUNCTION = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z_0-9]*)\s*\(")
CONSTANT = re.compile(r"^const\s+([A-Za-z_][A-Za-z_0-9]*)\s*(?::|=)")
PROJECT_VERSION = re.compile(r'^config/name="SERA v([1-9][0-9]*)"$', re.MULTILINE)


def version_from_text(source: str) -> int:
    versions = PROJECT_VERSION.findall(source)
    if len(versions) != 1:
        raise ValueError("Expected exactly one SERA v<number> application/config/name")
    return int(versions[0])


def extract_symbols(source: str, include_constants: bool = False) -> list[dict]:
    symbols = []
    for line_number, line in enumerate(source.splitlines(), 1):
        match = FUNCTION.match(line)
        kind = "function"
        if match is None and include_constants:
            match = CONSTANT.match(line)
            kind = "constant"
        if match is not None:
            symbols.append({"line": line_number, "kind": kind, "name": match.group(1)})
    return symbols


def find_symbols(query: str = "", include_constants: bool = False) -> list[dict]:
    query = query.casefold()
    result = []
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        relative = path.relative_to(ROOT).as_posix()
        source = path.read_text(encoding="utf-8")
        for item in extract_symbols(source, include_constants):
            if query and query not in item["name"].casefold() and query not in relative.casefold():
                continue
            result.append({"path": relative, **item})
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("query", nargs="?", default="", help="case-insensitive name or file filter")
    parser.add_argument("--include-constants", action="store_true")
    parser.add_argument("--summary", action="store_true", help="show largest scripts and function counts")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()
    version = version_from_text((ROOT / "project.godot").read_text(encoding="utf-8"))
    rows = find_symbols(args.query, args.include_constants)
    if args.summary:
        files = sorted((ROOT / "scripts").rglob("*.gd"))
        summary = [
            {"path": p.relative_to(ROOT).as_posix(),
             "bytes": p.stat().st_size,
             "functions": len(extract_symbols(p.read_text(encoding="utf-8")))}
            for p in files
        ]
        summary.sort(key=lambda row: row["bytes"], reverse=True)
        payload = {"game_version": version, "script_count": len(files),
                   "largest_scripts": summary[:12]}
        if args.json:
            print(json.dumps(payload, ensure_ascii=False, indent=2))
        else:
            print(f"SERA v{version}: {len(files)} scripts (largest first)")
            for row in payload["largest_scripts"]:
                print(f'{row["path"]}: {row["bytes"]} bytes, {row["functions"]} functions')
        return
    if args.json:
        print(json.dumps({"game_version": version, "match_count": len(rows),
                          "results": rows}, ensure_ascii=False, indent=2))
    else:
        print(f"SERA v{version}: {len(rows)} matching symbols")
        for item in rows:
            print(f'{item["path"]}:{item["line"]}: {item["kind"]} {item["name"]}')


if __name__ == "__main__":
    main()
