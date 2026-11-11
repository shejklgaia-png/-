#!/usr/bin/env python3
"""Read-only consistency audit of SERA RUN/BOOST input and HUD dimensions.

No values are hardcoded as the "latest version": the live scripts are the
source of truth. Mismatched input/display constants stop CI before a merge.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


class TuningAuditError(ValueError):
    pass


def number(source: str, name: str, declaration: str = "const") -> float:
    pattern = rf"^{re.escape(declaration)}\s+{re.escape(name)}:\s*float\s*=\s*(-?(?:\d+(?:\.\d*)?|\.\d+))(?=\s|$)"
    matches = re.findall(pattern, source, flags=re.MULTILINE)
    if len(matches) != 1:
        raise TuningAuditError(f"{declaration} {name}: expected one numeric literal, found {len(matches)}")
    value = float(matches[0])
    if not math.isfinite(value):
        raise TuningAuditError(f"{name}: not finite")
    return value


def equal(label: str, a: float, b: float) -> None:
    if not math.isclose(a, b, rel_tol=1e-9, abs_tol=1e-7):
        raise TuningAuditError(f"{label}: gameplay {a:g} != display {b:g}")


def audit(main: str, ui: str) -> dict:
    run = number(main, "RUN_CONTROL_RADIUS")
    dead = number(main, "RUN_INPUT_DEADZONE_PIXELS")
    boost = number(main, "DRAG_RADIUS")
    entry = number(main, "BOOST_START_RADIUS_RATIO")
    leave = number(main, "BOOST_EXIT_RADIUS_RATIO")
    visible_run = number(ui, "CONTROLLER_RUN_RADIUS")
    initial_run = number(ui, "radius", "var")
    initial_boost = number(ui, "boost_base_radius", "var")
    visible_entry = number(ui, "CONTROLLER_BOOST_START_RADIUS_RATIO")

    equal("RUN control radius", run, visible_run)
    equal("Initial RUN HUD radius", run, initial_run)
    equal("Initial BOOST HUD base radius", boost, initial_boost)
    equal("BOOST start ratio", entry, visible_entry)
    if not (0.0 < dead < run < boost and 0.0 < leave < entry):
        raise TuningAuditError("RUN/BOOST radii, deadzone or hysteresis are outside their required ordering")
    # Verify that drawing uses the input radius passed from the gameplay code.
    # These are source-level contracts; they cannot validate Android visuals.
    contracts = {
        "scripts/main.gd": (
            'touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)',
            "if finger_distance < DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:",
            "elif finger_distance >= DRAG_RADIUS * BOOST_START_RADIUS_RATIO:",
        ),
        "scripts/touch_overlay.gd": (
            "radius = CONTROLLER_RUN_RADIUS",
            "boost_base_radius = max_radius",
            "draw_arc(anchor_point, boost_base_radius * CONTROLLER_BOOST_START_RADIUS_RATIO,",
        ),
    }
    for filename, tokens in contracts.items():
        source = main if filename.endswith("main.gd") else ui
        for token in tokens:
            if token not in source:
                raise TuningAuditError(f"{filename}: required active usage missing: {token}")

    return {
        "run_radius_px": run,
        "run_deadzone_px": dead,
        "boost_base_radius_px": boost,
        "boost_enter_ratio": entry,
        "boost_leave_ratio": leave,
        "boost_enter_distance_px": boost * entry,
        "boost_leave_distance_px": boost * leave,
        "status": "consistent",
        "verification": "static source check only (not Android runtime)",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="machine-readable values and status")
    args = parser.parse_args()
    result = audit(
        (ROOT / "scripts/main.gd").read_text(encoding="utf-8"),
        (ROOT / "scripts/touch_overlay.gd").read_text(encoding="utf-8"),
    )
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print("PASS: HUD and input use matching RUN/BOOST dimensions")
        print(f'RUN={result["run_radius_px"]:g}px, deadzone={result["run_deadzone_px"]:g}px, '
              f'BOOST={result["boost_base_radius_px"]:g}px')
        print(f'BOOST enter={result["boost_enter_distance_px"]:g}px, '
              f'leave={result["boost_leave_distance_px"]:g}px')
        print("Godot parser, on-screen accuracy, and Android touch remain unverified.")


if __name__ == "__main__":
    main()
