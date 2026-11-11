#!/usr/bin/env python3
"""Read-only, short SERA preflight. No Godot execution or gameplay mutation."""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CORE = (
    "tools/codex_project_check.py",
    "tools/self_check.py",
    "tools/project_name_self_check.py",
    "tools/sera_dev_tools_self_check.py",
)
RENDER = ("tools/render_policy_self_check.py",)


def run_checks(include_render: bool = False) -> int:
    selected = CORE + (RENDER if include_render else ())
    failures: list[str] = []
    for path in selected:
        print(f"\n=== {path} ===", flush=True)
        result = subprocess.run([sys.executable, str(ROOT / path)], cwd=ROOT, check=False)
        if result.returncode:
            failures.append(f"{path} (exit {result.returncode})")
    print(f"\nSERA quick checks: {len(selected) - len(failures)}/{len(selected)} passed.")
    print("Godot parser, Android rendering, input and audio have NOT been verified.")
    if failures:
        print("Failed:", ", ".join(failures), file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--render", action="store_true",
        help="also verify the shared 3D draw-order and shader contract",
    )
    args = parser.parse_args()
    return run_checks(include_render=args.render)


if __name__ == "__main__":
    raise SystemExit(main())
