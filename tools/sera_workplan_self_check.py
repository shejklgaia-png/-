#!/usr/bin/env python3
"""Developer plan/selection invariants: focused tests cannot hide full CI."""
from pathlib import Path

from sera_ci_suite import focused_selection, load_tests
from sera_workplan import ROOT, build_plan, recognize, FEATURES

assert "step" in recognize("右ステップ", [])
assert "katana" in recognize("カタナ２段目", [])
assert "bird" in recognize("鳥脚", [])
assert "ci" in recognize("開発基盤", [])
assert recognize("unknown-unrelated-feature-xyz", []) == []
full_py = load_tests("py")
full_gd = load_tests("gd")
assert len(full_py) >= 127 and len(full_gd) >= 43
assert focused_selection("py", None) == full_py
assert focused_selection("gd", None) == full_gd
sample = next(path for path in full_py if path.endswith("v315_step_warp_launch_self_check.py"))
assert focused_selection("py", [sample]) == [sample]
for invalid in ([sample, sample], ["tools/not_a_registered_test.py"]):
    try:
        focused_selection("py", invalid)
    except ValueError:
        pass
    else:
        raise AssertionError("Unregistered/duplicate focused tests must be rejected")
step = build_plan("ステップ", ["scripts/main.gd"], limit=3)
assert step["game_version"] >= 316
assert "step" in step["features"]
assert step["model_sources"]["standard"] == "models/core/Standard.bbmodel"
assert any(x["path"] == "scripts/main.gd" for x in step["source_locations"])
assert any("v315_step_warp" in x for x in step["focused_tests"]["gd"])
assert all(len(x["symbols"]) <= 3 for x in step["source_locations"] if not x.get("missing"))
assert all(symbol["end_line"] >= symbol["line"] for entry in step["source_locations"] if not entry.get("missing") for symbol in entry["symbols"])
katana = build_plan("刀")
assert "katana" in katana["features"]
assert "models/core/Katana.bbmodel" in katana["model_sources"].values()
assert any("v316_canonical_models" in x for x in katana["focused_tests"]["gd"])
bird = build_plan("鳥脚")
assert "bird" in bird["features"]
assert "models/core/BirdLeg.bbmodel" in bird["model_sources"].values()
unknown = build_plan("unmapped-xyz")
assert not unknown["features"] and not any(unknown["focused_tests"].values())
for plan in (step, katana, bird):
    for kind in ("py", "gd"):
        assert set(plan["focused_tests"][kind]).issubset(
            set(full_py if kind == "py" else full_gd))
assert (ROOT / "docs/history/AGENTS_THROUGH_V316.md").is_file()
assert (ROOT / "AGENTS.md").stat().st_size < 8000
assert "SERA_MODEL_PARTS_V1" in (ROOT / "AGENTS.md").read_text(encoding="utf-8")
print("SERA_WORKPLAN_PASS: bounded source hints, registered focused tests, full CI unchanged")
