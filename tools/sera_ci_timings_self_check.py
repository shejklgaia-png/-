#!/usr/bin/env python3
"""Duration scheduling keeps the same tests, with expensive ones first."""
import json
import tempfile
from pathlib import Path
from sera_ci_suite import prioritize_slowest, load_tests, TIMING_HINTS
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
assert TIMING_HINTS.is_file()
print("SERA_CI_TIMINGS_PASS: full coverage and descending-cost scheduling")
