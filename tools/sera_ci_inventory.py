#!/usr/bin/env python3
"""Read-only CI inventory: exact duplicates, unregistered potential regressions, durations.

Never disables a test. Use the report to make evidence-backed decisions about
consolidation, rather than inferring duplicate coverage from filename alone.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from sera_ci_suite import ROOT, load_tests, TIMING_HINTS


def audit() -> dict:
    registered = {"py": load_tests("py"), "gd": load_tests("gd")}
    all_registered = set(registered["py"] + registered["gd"])
    candidate_files = sorted(
        p for p in (ROOT / "tools").glob("*.py") if (
            p.name.startswith("v") or p.name.startswith("sera_")))
    candidate_files += sorted(p for p in (ROOT / "tools").glob("*.gd") if (
        p.name.startswith("v") or p.name.startswith("sera_")))
    candidates = {p.relative_to(ROOT).as_posix() for p in candidate_files}
    duplicates: dict[str, list[str]] = {}
    for path in sorted(all_registered):
        data = (ROOT / path).read_bytes()
        hash_id = hashlib.sha256(data).hexdigest()
        duplicates.setdefault(hash_id, []).append(path)
    exact_duplicates = [group for group in duplicates.values() if len(group) > 1]
    try:
        timings = json.loads(TIMING_HINTS.read_text(encoding="utf-8"))["tests"]
    except (OSError, ValueError, KeyError):
        timings = {"py": {}, "gd": {}}
    measured = {
        kind: sum(float(timings.get(kind, {}).get(path, 0.0)) for path in paths)
        for kind, paths in registered.items()
    }
    return {
        "counts": {kind: len(paths) for kind, paths in registered.items()},
        "exact_duplicate_content": exact_duplicates,
        "candidate_unregistered": sorted(candidates - all_registered),
        "measured_aggregate_seconds": measured,
        "policy": "No tests skipped. Exact byte duplicates are reported, not automatically removed.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    report = audit()
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("SERA CI inventory:", report["counts"])
        print("Exact duplicate groups:", len(report["exact_duplicate_content"]))
        print("Unregistered candidates:", len(report["candidate_unregistered"]))
        print("Measured aggregate test seconds:", report["measured_aggregate_seconds"])
        print(report["policy"])


if __name__ == "__main__":
    main()
