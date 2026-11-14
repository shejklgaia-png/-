#!/usr/bin/env python3
"""Approved active SERA gameplay contract for regression tests.

Expected values intentionally live outside scripts/main.gd: an accidental
gameplay value change must fail CI. Historical vNNN tests must not pin values
from their original release when those values have been superseded.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "tools/sera_active_specs.json"


def load_active_specs() -> dict:
    data = json.loads(SPEC.read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        raise ValueError("Unsupported active spec schema")
    return data


def main_float_constant(source: str, name: str) -> float:
    pattern = (r"^\s*const\s+" + re.escape(name) +
               r"\s*:\s*float\s*=\s*(-?(?:\d+(?:\.\d*)?|\.\d+))\s*(?:#.*)?$")
    matches = re.findall(pattern, source, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError(f"Expected one numeric constant {name}, found {len(matches)}")
    return float(matches[0])


def require_close(actual: float, expected: float, label: str) -> None:
    if not math.isfinite(actual) or not math.isclose(actual, expected, abs_tol=1e-6):
        raise AssertionError(f"{label}: runtime={actual:g}, approved={expected:g}; "
                             "change code and active spec together only when intended")


def require_min_version(project: str, minimum: int) -> bool:
    """Require a valid project title and a release containing this contract."""
    matches = re.findall(r'^config/name="SERA v([1-9][0-9]*)"$', project, re.MULTILINE)
    if len(matches) != 1 or int(matches[0]) < minimum:
        raise AssertionError(f"Expected one SERA project version >= {minimum}")
    return True
