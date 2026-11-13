#!/usr/bin/env python3
"""Check that fast AI code navigation remains usable."""
from sera_dev_index import build_index
step = build_index("step")
assert step["game_version"] >= 315
assert any(e["path"] == "scripts/main.gd" for e in step["scripts"])
assert any(e["path"] == "scripts/sera_rig.gd" for e in step["scripts"])
assert any(x["path"].endswith("step_distance_runtime_check.gd")
           for x in step["registered_tests"])
katana = build_index("katana")
assert "Melee_katana" in katana["source_motions"]
assert any(e["path"] == "scripts/sera_rig.gd" for e in katana["scripts"])
print("SERA_DEV_INDEX_PASS")
