#!/usr/bin/env python3
"""Enforce the short Godot project title convention across future SERA versions."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / "project.godot").read_text(encoding="utf-8")
matches = re.findall(r'^config/name="([^"\\r\\n]+)"$', source, flags=re.MULTILINE)
assert len(matches) == 1, f"Expected one Godot project title, found {len(matches)}"
title = matches[0]
assert re.fullmatch(r"SERA v[1-9][0-9]*", title), (
    f"Project title must contain only SERA and a positive integer version: {title!r}")
assert (root / f"README_v{title.split('v',1)[1]}_ja.md").is_file(), (
    "The current version should have its own README.")
print(f"PASS: Godot project title {title!r} follows version-only naming.")
