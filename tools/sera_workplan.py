#!/usr/bin/env python3
"""One-command SERA developer plan: source lines, model authorities, and safe focused tests.

Examples:
  python3 tools/sera_workplan.py --query "右ステップ" --json
  python3 tools/sera_workplan.py --query katana --changed scripts/sera_rig.gd
  python3 tools/sera_workplan.py --query lock --execute
  python3 tools/sera_workplan.py --query bird --execute --godot /path/to/godot

The focused run is never a substitute for the complete mandatory PR CI.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

from sera_ci_suite import load_tests
from sera_code_map import ROOT, extract_symbols, version_from_text

# Explicit, deliberately conservative hints. Unknown source/feature => warn,
# never declare other systems independent. Test filenames must be CI-registered.
FEATURES: dict[str, dict[str, tuple[str, ...]]] = {
    "step": {
        "aliases": ("step", "dodge", "ステップ", "回避", "フリック"),
        "paths": ("scripts/main.gd", "scripts/sera_rig.gd", "scripts/touch_overlay.gd"),
        "tokens": ("step", "dodge", "flick", "omni"),
        "tests": ("step", "dodge", "flick", "omni", "kick", "animation_runtime_smoke"),
    },
    "boost": {
        "aliases": ("boost", "ブースト", "加速", "走行"),
        "paths": ("scripts/main.gd", "scripts/sera_rig.gd", "scripts/back_thruster_fx.gd"),
        "tokens": ("boost", "run", "exhaust", "slide"),
        "tests": ("boost", "thruster", "nozzle", "run", "slide"),
    },
    "camera": {
        "aliases": ("camera", "カメラ", "視点", "ズーム", "画角"),
        "paths": ("scripts/main.gd", "scripts/command_nexus.gd"),
        "tokens": ("camera", "yaw", "focus", "frame", "zoom"),
        "tests": ("camera", "frame", "zoom"),
    },
    "lock": {
        "aliases": ("lock", "ロック", "ターゲット", "部位", "照準"),
        "paths": ("scripts/main.gd", "scripts/target_parts.gd", "scripts/touch_overlay.gd"),
        "tokens": ("lock", "target", "part", "marker"),
        "tests": ("lock", "target", "part", "reticle"),
    },
    "melee": {
        "aliases": ("melee", "combat", "格闘", "攻撃", "コンボ", "バッシュ", "蹴り"),
        "paths": ("scripts/main.gd", "scripts/sera_rig.gd"),
        "tokens": ("melee", "strike", "kick", "bash", "combo", "hit"),
        "tests": ("melee", "strike", "kick", "bash", "combo", "animation_runtime_smoke"),
    },
    "katana": {
        "aliases": ("katana", "カタナ", "刀", "鞘", "抜き身"),
        "paths": ("scripts/sera_rig.gd", "scripts/sera_equipment.gd", "scripts/main.gd"),
        "tokens": ("katana", "strike"),
        "tests": ("katana", "canonical_models", "animation_runtime_smoke"),
    },
    "bird": {
        "aliases": ("bird", "鳥足", "鳥脚", "逆関節"),
        "paths": ("scripts/sera_rig.gd", "scripts/sera_equipment.gd"),
        "tokens": ("bird", "bone", "ground"),
        "tests": ("bird", "lower_body", "canonical_models", "animation_runtime_smoke"),
    },
    "equipment": {
        "aliases": ("equipment", "装備", "カスタマイズ", "重量足", "頭c", "パーツ"),
        "paths": ("scripts/sera_equipment.gd", "scripts/sera_rig.gd", "scripts/command_nexus.gd"),
        "tokens": ("equipment", "part", "head", "leg", "ground"),
        "tests": ("equipment", "lower_body", "head", "canonical_models", "katana"),
    },
    "animation": {
        "aliases": ("animation", "motion", "モーション", "アニメ", "骨格", "キーフレーム"),
        "paths": ("scripts/sera_rig.gd", "scripts/sera_equipment.gd"),
        "tokens": ("animation", "clip", "motion", "bone"),
        "tests": ("animation", "motion", "canonical_models", "katana", "bird"),
    },
    "nexus": {
        "aliases": ("nexus", "拠点", "展示", "トレーニング"),
        "paths": ("scripts/command_nexus.gd", "scripts/sera_equipment.gd"),
        "tokens": ("nexus", "display", "customiz", "stage"),
        "tests": ("nexus", "customization", "canonical_models"),
    },
    "render": {
        "aliases": ("render", "shader", "描画", "シェーダー", "透明", "エフェクト", "スラスター"),
        "paths": ("scripts/render_order_policy.gd", "scripts/back_thruster_fx.gd", "scripts/sera_equipment.gd"),
        "tokens": ("render", "shader", "effect", "thruster", "transparen"),
        "tests": ("render", "thruster", "nozzle", "draw_order"),
    },
    "controller": {
        "aliases": ("controller", "input", "操作", "コントローラ", "スティック", "タッチ"),
        "paths": ("scripts/main.gd", "scripts/touch_overlay.gd"),
        "tokens": ("touch", "input", "drag", "flick", "controller"),
        "tests": ("controller", "touch", "input", "flick", "boost_gesture"),
    },
    "ci": {
        "aliases": ("ci", "test", "github", "開発", "テスト", "高速化", "開発基盤"),
        "paths": ("tools/sera_ci_suite.py", "tools/sera_workplan.py",
                  "tools/sera_code_map.py", "tools/sera_dev_index.py"),
        "tokens": ("test", "suite", "manifest", "index", "workplan"),
        "tests": ("active_contract", "dev_index", "workplan", "dev_tools"),
    },
}

# These paths affect multiple gameplay systems; filename-only classification
# is necessarily broad and cannot justify skipping unrelated PR regressions.
PATH_HINTS = {
    "scripts/main.gd": ("step", "boost", "camera", "lock", "melee", "controller"),
    "scripts/sera_rig.gd": ("animation", "katana", "bird", "equipment", "step"),
    "scripts/sera_equipment.gd": ("equipment", "katana", "bird", "render"),
    "scripts/command_nexus.gd": ("nexus", "camera", "equipment"),
    "scripts/touch_overlay.gd": ("controller", "lock", "step"),
    "scripts/target_parts.gd": ("lock", "melee"),
    "scripts/back_thruster_fx.gd": ("boost", "render"),
}
MODEL_KEYS = {
    "animation": ("standard", "bird_legs", "katana"),
    "bird": ("bird_legs",),
    "katana": ("katana", "standard"),
    "equipment": ("equipment", "head_C", "lower_body_D"),
    "nexus": ("standard", "equipment"),
    "step": ("standard",),
    "melee": ("standard", "katana"),
}


def recognize(query: str, changed: list[str]) -> list[str]:
    query = query.casefold().strip()
    if query:
        # Explicit feature narrows broad files; all other impacts stay covered
        # by the full PR suite.
        return [feature for feature, spec in FEATURES.items()
                if query == feature or any(alias in query for alias in spec["aliases"])]
    found: set[str] = set()
    for path in changed:
        found.update(PATH_HINTS.get(path, ()))
        if path.startswith(("models/", "blockbench/", "assets/sera_")):
            found.update(("equipment", "animation"))
        if path.startswith(("tools/", ".github/")):
            found.add("ci")
    return sorted(found)


def build_plan(query: str = "", changed: list[str] | None = None, limit: int = 14) -> dict:
    changed = changed or []
    if limit < 1:
        raise ValueError("limit must be positive")
    features = recognize(query, changed)
    paths: set[str] = set(changed)
    for feature in features:
        paths.update(FEATURES[feature]["paths"])
    scripts = []
    for relative in sorted(paths):
        path = ROOT / relative
        if not path.is_file():
            scripts.append({"path": relative, "missing": True})
            continue
        if path.suffix not in (".py", ".gd"):
            continue
        source = path.read_text(encoding="utf-8")
        tokens = {t for feature in features for t in FEATURES[feature]["tokens"]}
        if query:
            tokens.add(query.casefold())
        symbols = extract_symbols(source, include_constants=True)
        relevant = [symbol for symbol in symbols if any(
            token in symbol["name"].casefold() for token in tokens)]
        scripts.append({
            "path": relative, "size_bytes": len(source.encode("utf-8")),
            "matching_symbol_count": len(relevant),
            "symbols": relevant[:limit],
            "truncated": len(relevant) > limit,
        })
    manifest = json.loads((ROOT / "models/manifest.json").read_text(encoding="utf-8"))
    all_models = {**manifest["variants"], **manifest["parts"]}
    model_keys = {key for feature in features for key in MODEL_KEYS.get(feature, ())}
    for path in changed:
        if path in all_models.values():
            model_keys.update(key for key, value in all_models.items() if value == path)
    model_sources = {k: all_models[k] for k in sorted(model_keys) if k in all_models}
    registered = {"py": load_tests("py"), "gd": load_tests("gd")}
    wanted = {t for feature in features for t in FEATURES[feature]["tests"]}
    chosen = {k: [p for p in v if any(t in Path(p).stem.casefold() for t in wanted)]
              for k, v in registered.items()}
    notes = ["This is a conservative HEURISTIC. Dynamic calls, scene signals and shared files may have unlisted dependencies.",
             "Focused checks never replace the full registered Python + Godot CI before merging."]
    if not features:
        notes.append("No known feature matched; inspect manually and run the complete suites.")
    if "scripts/main.gd" in changed and not query:
        notes.append("main.gd spans many features: specify --query to reduce the plan, then still run full PR CI.")
    return {
        "game_version": version_from_text((ROOT / "project.godot").read_text(encoding="utf-8")),
        "query": query, "changed": changed, "features": features, "source_locations": scripts,
        "model_sources": model_sources, "focused_tests": chosen,
        "test_counts": {k: len(v) for k, v in chosen.items()},
        "full_suite_counts": {k: len(v) for k, v in registered.items()},
        "notes": notes,
    }


def run_focused(plan: dict, godot: str = "") -> int:
    selected = plan["focused_tests"]
    if not plan["features"] or not any(selected.values()):
        print("No trusted focused tests; use complete CI.", file=sys.stderr)
        return 2
    for kind, runner in (("py", "static"), ("gd", "godot")):
        if kind == "gd" and not godot:
            print("Godot focused suite skipped (no --godot). Full PR CI is still required.")
            continue
        tests = selected[kind]
        if not tests:
            continue
        command = [sys.executable, "tools/sera_ci_suite.py", runner, "--tests", *tests]
        if kind == "gd":
            command += ["--godot", godot]
        print("FOCUSED:", " ".join(command), flush=True)
        status = subprocess.run(command, cwd=ROOT, check=False).returncode
        if status != 0:
            return status
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--query", default="", help="feature name, English or Japanese")
    parser.add_argument("--changed", nargs="+", default=[], help="modified repository paths")
    parser.add_argument("--limit", type=int, default=14, help="symbol matches per source file")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--execute", action="store_true", help="run only selected registered local tests")
    parser.add_argument("--godot", default="", help="Godot executable for --execute runtime checks")
    opts = parser.parse_args()
    plan = build_plan(opts.query, opts.changed, opts.limit)
    if opts.json:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
    else:
        print(f"SERA v{plan['game_version']} focused work plan: {', '.join(plan['features']) or '(unknown)'}")
        for item in plan["source_locations"]:
            if item.get("missing"):
                print("NOT FOUND", item["path"])
                continue
            print(f"- {item['path']} ({item['size_bytes']} bytes, {item['matching_symbol_count']} matches)")
            for symbol in item["symbols"]:
                print(f"    {symbol['line']}: {symbol['kind']} {symbol['name']}")
        if plan["model_sources"]:
            print("Authoritative models:", ", ".join(plan["model_sources"].values()))
        print("Focused tests:", plan["test_counts"], "Full PR CI:", plan["full_suite_counts"])
        for note in plan["notes"]:
            print("NOTE:", note)
    if opts.execute:
        return run_focused(plan, opts.godot)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
