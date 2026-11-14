#!/usr/bin/env python3
"""Repeated Godot tests must not inherit saves/settings from their prior run."""
import os
from pathlib import Path
import sys
import tempfile
from sera_ci_suite import run_test

with tempfile.TemporaryDirectory(prefix="sera-isolation-regression-") as folder:
    base = Path(folder)
    fixture = base / "godot-fixture"
    fixture.write_text("#!" + sys.executable + "\n" + '''import os
from pathlib import Path
for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
    directory = Path(os.environ[variable])
    marker = directory / "settings-from-previous-execution"
    if marker.exists():
        raise SystemExit("inherited persistent test state: " + variable)
    marker.write_text("poison the next run if isolation is reused")
print("FRESH_ISOLATED_EXECUTION")
''')
    fixture.chmod(0o755)
    previous = os.environ.get("RUNNER_TEMP")
    os.environ["RUNNER_TEMP"] = folder
    try:
        for attempt in range(2):
            _, passed, _, output = run_test("gd", "tools/isolation_probe.gd", str(fixture), 10)
            assert passed and "FRESH_ISOLATED_EXECUTION" in output, (attempt, output)
        assert list(base.iterdir()) == [fixture], "temporary test state was not cleaned"
    finally:
        if previous is None:
            del os.environ["RUNNER_TEMP"]
        else:
            os.environ["RUNNER_TEMP"] = previous
print("SERA_CI_ISOLATION_PASS: repeated executions have fresh user data/config/cache")
