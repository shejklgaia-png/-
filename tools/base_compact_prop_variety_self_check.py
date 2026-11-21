#!/usr/bin/env python3
"""Keep broader BASE floor clutter visible, site-local and Android-batched."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
code = (root/"scripts/sera_base_clutter.gd").read_text(encoding="utf-8")
arch = (root/"scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
ci = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'static func _accent(' in code
assert 'static func _make_micro(' in code
assert 'item["accent"] = true' in code, "accent flag must be set in the authored item"
assert '"sealed_canister":' in code
assert '"locator_beacon":' in code
assert code.count('_accent("') == 24, "keep 24 distinct authored compact models"
assert 'static func _append_satellite_props(' in code
assert 'item["satellite"] = true' in code
assert '_append_satellite_props(key, items)' in code
assert 'g.host.set_meta("clutter_props", props)' in code
assert 'BaseClutter.decorate(g, "NEXUS")' in arch
assert 'BaseClutter.decorate(g, key)' in arch
assert 'MultiMeshInstance3D.new()' not in code, "no extra per-prop draw nodes"
assert 'RandomNumberGenerator' not in code
assert 'py tools/base_compact_prop_variety_self_check.py' in ci
assert 'gd tools/base_compact_prop_variety_runtime_check.gd' in ci
print("SERA_BASE_COMPACT_PROP_VARIETY_STATIC_PASS")
