#!/usr/bin/env python3
"""Duration scheduling keeps the same tests, with expensive ones first."""
import json
import tempfile
from pathlib import Path
from sera_ci_suite import prioritize_slowest, load_tests, TIMING_HINTS, isolation_prefix
registered = load_tests("py")
assert "tools/sera_model_build_self_check.py" in registered
assert len(registered) >= 129
assert load_tests("gd")
assert len(set(prioritize_slowest(registered, "py"))) == len(registered)
assert set(prioritize_slowest(registered, "py")) == set(registered)
with tempfile.TemporaryDirectory() as tmp:
    p = Path(tmp) / "timings.json"
    names = registered[:3]
    p.write_text(json.dumps({"schema": 1, "tests": {"py": {
        names[0]: 0.1, names[1]: 20.0, names[2]: 0.5}}}), encoding="utf-8")
    selected = prioritize_slowest(names, "py", p)
    assert selected == [names[1], names[2], names[0]]
    p.write_text("invalid json", encoding="utf-8")
    assert prioritize_slowest(names, "py", p) == names
# Nested Godot tools must not leak slashes into mkdtemp(prefix=...).
# A previous full Godot CI run raised FileNotFoundError creating a literal
# "sera-ci-icon_studio/front_right_orientation_runtime_check-*" folder.
nested = "tools/icon_studio/front_right_orientation_runtime_check.gd"
near_collision = "tools/icon_studio-front_right_orientation_runtime_check.gd"
prefix = isolation_prefix(nested)
assert prefix.startswith("sera-ci-") and prefix.endswith("-")
assert "/" not in prefix and "\\\\" not in prefix
assert prefix != isolation_prefix(near_collision)
assert prefix == isolation_prefix(nested), "cache-independent deterministic prefix"
with tempfile.TemporaryDirectory() as tmp:
    with tempfile.TemporaryDirectory(prefix=prefix, dir=tmp) as actual:
        assert Path(actual).is_dir() and Path(actual).parent == Path(tmp)
assert TIMING_HINTS.is_file()
print("SERA_CI_TIMINGS_PASS: full coverage and descending-cost scheduling")
