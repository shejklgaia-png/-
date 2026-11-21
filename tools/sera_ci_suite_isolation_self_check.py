#!/usr/bin/env python3
"""A nested tools/ test must create its own safe isolated Godot user://."""
from pathlib import Path
import tempfile

from sera_ci_suite import godot_isolation_prefix, load_tests

nested = "tools/icon_studio/front_right_orientation_runtime_check.gd"
prefix = godot_isolation_prefix(nested)
assert prefix.startswith("sera-ci-")
assert "/" not in prefix and "\\" not in prefix
assert "front_right_orientation_runtime_check" in prefix
# The actual system temporary directory creation must work for nested names.
with tempfile.TemporaryDirectory(prefix=prefix) as isolated:
    assert Path(isolated).is_dir()

all_gd = load_tests("gd")
names = [godot_isolation_prefix(name) for name in all_gd]
assert len(names) == len(set(names)), "Collision in isolated test identities"
assert all("/" not in name and "\\" not in name for name in names)
print("SERA_GODOT_ISOLATION_PATHS_PASS", len(names))
