#!/usr/bin/env python3
"""Boot-blocking GDScript source regression for LABO prototype text."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
fac = (ROOT / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
startup = (ROOT / "scripts/base_exploration.gd").read_text(encoding="utf-8")
ci = (ROOT / ".github/workflows/sera-model-policy.yml").read_text(encoding="utf-8")
manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

# In v531, escaped newline sequences were accidentally pasted OUTSIDE a
# string after the closing quote, producing an invalid GDScript token.
assert not re.search(r'"\\n\s+(?:if|else)\b', fac), (
    "Literal backslash-n outside a string blocks the whole BASE scene from parsing"
)
assert 'LaboStats.complete_profile_text(selected_prototype)' in fac
assert '3D表示は現行のAモデルを使用します。' not in fac
assert '3D表示はアイリス頭部（HEAD D）を使用します。' not in fac
assert 'func _create_startup_overlay()' in startup
assert 'gd tools/base_startup_parse_runtime_check.gd' in manifest
assert 'py tools/base_gdscript_parse_self_check.py' in manifest
assert '--script tools/base_startup_parse_runtime_check.gd' in ci
print("SERA_BASE_GDSCRIPT_PARSE_STATIC_PASS")
