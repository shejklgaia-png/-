#!/usr/bin/env python3
"""Read-only SERA exact function line ranges with possible/direct dynamic references.

python3 tools/sera_function_index.py --query camera --json
python3 tools/sera_function_index.py --symbol _stable_shoulder_camera_yaw --json
"""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path
from sera_code_map import ROOT, version_from_text

FUNCTION = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(")
RESOURCE = re.compile(r"""res://[^"'\s)]+""")
DYNAMIC = re.compile(r"""\bcall\s*\(\s*["']([A-Za-z_]\w*)["']""")
DIRECT = re.compile(r"\b([A-Za-z_]\w*)\s*\(")


def ranges_for_source(source: str) -> list[dict]:
    lines = source.splitlines()
    starts = [(i+1, match.group(1)) for i, line in enumerate(lines)
              if (match := FUNCTION.match(line))]
    return [{"name": name, "start_line": line,
             "end_line": starts[i+1][0]-1 if i+1 < len(starts) else len(lines)}
            for i, (line, name) in enumerate(starts)]


def build_index(query: str = "", path_filter: str = "", limit: int = 100) -> dict:
    files: dict[str, str] = {}
    for p in sorted((ROOT / "scripts").rglob("*.gd")):
        rel = p.relative_to(ROOT).as_posix()
        if not path_filter or path_filter in rel:
            files[rel] = p.read_text(encoding="utf-8")
    known = {x["name"] for s in files.values() for x in ranges_for_source(s)}
    out = []
    matched = 0
    query = query.casefold()
    for rel, source in files.items():
        lines = source.splitlines()
        for item in ranges_for_source(source):
            if query and query not in rel.casefold() and query not in item["name"].casefold():
                continue
            matched += 1
            if len(out) >= limit:
                continue
            body = "\n".join(lines[item["start_line"]-1:item["end_line"]])
            out.append({"path": rel, **item,
                "possible_calls": sorted((set(DIRECT.findall(body)) & known) - {item["name"]}),
                "dynamic_calls": sorted(set(DYNAMIC.findall(body))),
                "literal_resources": sorted(set(RESOURCE.findall(body)))})
    return {"game_version": version_from_text((ROOT/"project.godot").read_text(encoding="utf-8")),
            "query": query, "path": path_filter, "total_matches": matched,
            "truncated": matched > limit, "results": out,
            "notice": "Ranges match current sources. Dynamic call targets remain ambiguous."}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--query", default="")
    ap.add_argument("--symbol", default="")
    ap.add_argument("--path", default="")
    ap.add_argument("--limit", type=int, default=100)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    if args.limit < 1:
        ap.error("--limit must be positive")
    result = build_index(args.symbol or args.query, args.path, args.limit)
    if args.symbol:
        result["results"] = [x for x in result["results"] if x["name"] == args.symbol]
        result["total_matches"] = len(result["results"])
        result["truncated"] = False
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        for x in result["results"]:
            print(f'{x["path"]}:{x["start_line"]}-{x["end_line"]} {x["name"]}')
        if result["truncated"]:
            print("More matches exist; specify a narrower query")


if __name__ == "__main__":
    main()
