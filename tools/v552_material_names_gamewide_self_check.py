#!/usr/bin/env python3
"""SERA v552: all Japanese material names share one source of truth.
No save identifiers, conversion family IDs, starter counts, or icon mapping
may change when localizing the 12 resources.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / "scripts/sera_base_materials.gd").read_text("utf-8")
fac = (root / "scripts/base_facility_system.gd").read_text("utf-8")
warehouse = (root / "scripts/sera_warehouse_grid.gd").read_text("utf-8")
save = (root / "scripts/sera_save.gd").read_text("utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text("utf-8")
expected = {
    "scrap_low": "汎用スクラップ",
    "scrap_mid": "応用スクラップ",
    "scrap_high": "高度スクラップ",
    "alloy_low": "基礎金属複合材",
    "alloy_mid": "精密金属複合材",
    "alloy_high": "高次金属複合材",
    "electronics_low": "汎用電子部品",
    "electronics_mid": "精密電子部品",
    "electronics_high": "高度電子部品",
    "organic_low": "低活性有機素材",
    "organic_mid": "安定有機素材",
    "organic_high": "高活性有機素材"
}
assert 'const FAMILY_IDS = ["scrap", "alloy", "electronics", "organic"]' in source
assert 'const TIERS = ["low", "mid", "high"]' in source
assert '"alloy": "金属複合材"' in source
for id, name in expected.items():
    assert f'"{id}": "{name}"' in source, (id, name)
for old in [
    "雑スクラップ", "選別スクラップ", "高純度スクラップ",
    "粗製合金", "精製合金", "高強度合金",
    "再生電子部品", "高精度電子部品",
]:
    assert old not in source, old
assert '"scrap": {"low": "汎用", "mid": "応用", "high": "高度"}' in source
assert '"alloy": {"low": "基礎", "mid": "精密", "high": "高次"}' in source
assert '"electronics": {"low": "汎用", "mid": "精密", "high": "高度"}' in source
assert 'static func display_name(material_id: String) -> String:' in source
assert 'static func display_lines(material_id: String) -> String:' in source
assert 'BaseMaterials.display_lines(id)' in fac
assert 'BaseMaterials.display_name(id)' in fac
assert 'BaseMaterials.display_name(source_id)' in fac
assert 'BaseMaterials.display_name(target_id)' in fac
assert 'entries.append({"id": id, "name": BaseMaterials.display_name(id)' in fac
assert 'title.text = str(entry.get("name", ""))' in warehouse
assert '"materials": BaseMaterials.starter_inventory()' in save
assert 'stock["scrap_low"] = STARTER_SCRAP_COUNT' in source
assert 'const STARTER_SCRAP_COUNT: int = 5' in source
assert 'data["materials"] = BaseMaterials.sanitize_inventory(' in save
assert 'data.get("materials", {}))' in save
assert 'py tools/v552_material_names_gamewide_self_check.py' in ci
assert 'gd tools/v552_material_names_gamewide_runtime_check.gd' in ci
print("SERA_V552_MATERIAL_NAMES_STATIC_PASS")
