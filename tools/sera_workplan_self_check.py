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
# The always-loaded entrypoint should stay small; detailed original rules remain routed.
assert (ROOT / "AGENTS.md").stat().st_size < 5000
assert "SERA_MODEL_PARTS_V1" in (ROOT / "AGENTS.md").read_text(encoding="utf-8")
# Feature-specific documentation must be discoverable without eagerly loading every rule.
for name in ("CI_WORKFLOW.md", "SOURCE_POLICY.md", "EQUIPMENT.md", "RUNTIME_BOUNDARIES.md"):
    assert (ROOT / "docs/agent" / name).is_file(), name
entry = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
assert "sera_workplan.py" in entry and "CI_WORKFLOW.md" in entry
assert "SERA_MODEL_PARTS_V1" in entry
assert "headless" in entry or "実機" in entry
assert "base" in recognize("拠点施設の床と配置", [])
assert "labo" in recognize("ラボの製作確認", [])
assert "warehouse" in recognize("倉庫でスクロール", [])
assert "ui" in recognize("UIの文字サイズ", [])
assert "boss" in recognize("ビットタランの攻撃", [])
for q, expected in (
    ("拠点施設", "base"),
    ("ラボの製作", "labo"),
    ("倉庫の装備", "warehouse"),
    ("UIレイアウト", "ui"),
    ("ビットタラン", "boss"),
):
    plan = build_plan(q)
    assert expected in plan["features"], (q, plan["features"])
    assert all((ROOT / p).is_file() for p in plan["documentation"]["required"])
    assert all((ROOT / p).is_file() for p in plan["documentation"]["selected"])
    assert len(plan["documentation"]["selected"]) == len(set(plan["documentation"]["selected"]))
    assert (ROOT / "docs/agent/CI_WORKFLOW.md").as_posix().endswith(plan["documentation"]["required"][0])
assert "docs/agent/EQUIPMENT.md" in build_plan("装備作成")["documentation"]["selected"]
assert "docs/SERA_WAREHOUSE_UI_AND_CRAFT_AFFIXES_ja.md" in build_plan("倉庫")["documentation"]["selected"]
assert "docs/RENDER_PIPELINE_POLICY_ja.md" in build_plan("シェーダー")["documentation"]["selected"]
unknown_docs = build_plan("unknown-unrelated-feature-xyz")["documentation"]
assert unknown_docs["fallback"] is True
assert "docs/SERA_REPOSITORY_LAYOUT_ja.md" in unknown_docs["selected"]
# Guard against accidentally losing mandatory old rules while splitting by domain.
joined = "\\n".join((ROOT / "docs/agent" / name).read_text(encoding="utf-8")
                  for name in ("CI_WORKFLOW.md", "SOURCE_POLICY.md", "EQUIPMENT.md", "RUNTIME_BOUNDARIES.md"))
for phrase in ("SERA_MODEL_PARTS_V1", "999個", "HEAD D", "main.gd", "Icon Studio",
               "CI失敗時", "DEVELOPMENT.md", "GitSync", "DIAG: OFF"):
    assert phrase in joined, phrase
print("SERA_WORKPLAN_PASS: bounded source hints, registered focused tests, full CI unchanged")
