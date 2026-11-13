#!/usr/bin/env python3
"""Compact function, asset and test lookup for ChatGPT SERA development.

Examples: python3 tools/sera_dev_index.py step --json
          python3 tools/sera_dev_index.py katana --json
          python3 tools/sera_dev_index.py --summary
This index is read-only and does not resolve dynamic references.
"""
from __future__ import annotations
import argparse
import json
import re
from sera_code_map import ROOT, extract_symbols, version_from_text

RESOURCE = re.compile(r'res://[^"\'\s)]+')
MANIFEST = ROOT / "tools/sera_ci_manifest.txt"


def build_index(query: str = "", summary: bool = False) -> dict:
    needle = query.casefold()
    entries = []
    paths = list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "assets").glob("*.gd"))
    for path in sorted(paths):
        body = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT).as_posix()
        symbols = extract_symbols(body, include_constants=True)
        resources = sorted(set(RESOURCE.findall(body)))
        matched_symbols = [s for s in symbols if needle in s["name"].casefold()]
        matched_resources = [x for x in resources if needle in x.casefold()]
        if not needle or needle in rel.casefold() or matched_symbols or matched_resources:
            entries.append({
                "path": rel, "bytes": len(body.encode("utf-8")),
                "symbols": matched_symbols if needle else symbols,
                "resources": matched_resources if needle else resources,
            })
    tests = []
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[0] in ("py", "gd"):
            kind, path = fields
            if not needle or needle in path.casefold():
                tests.append({"kind": kind, "path": path})
    source = json.loads((ROOT / "assets/sera_source.json").read_text(encoding="utf-8"))
    motions = sorted(str(x.get("name", "")) for x in source.get("animations", []))
    if needle:
        motions = [n for n in motions if needle in n.casefold()]
    if summary:
        entries = sorted(entries, key=lambda e: -e["bytes"])[:12]
        tests = tests[:12]
    return {
        "game_version": version_from_text((ROOT / "project.godot").read_text(encoding="utf-8")),
        "query": query, "scripts": entries, "source_motions": motions,
        "registered_tests": tests,
        "notice": "Literal resources only; dynamic calls and bone name remaps require manual review.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("query", nargs="?", default="")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--summary", action="store_true")
    opt = parser.parse_args()
    result = build_index(opt.query, opt.summary)
    if opt.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"SERA v{result['game_version']}: {len(result['scripts'])} scripts, "
              f"{len(result['source_motions'])} motions, "
              f"{len(result['registered_tests'])} registered tests for {opt.query!r}")
        for entry in result["scripts"]:
            print(f"- {entry['path']}: " + ", ".join(x["name"] for x in entry["symbols"][:14]))
        if result["source_motions"]:
            print("Motions: " + ", ".join(result["source_motions"]))


if __name__ == "__main__":
    main()
