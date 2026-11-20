#!/usr/bin/env python3
"""Android Godot editor must use the same texture import configuration as APK."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/sera-game-android-apk.yml").read_text(encoding="utf-8")
docs = (ROOT / "docs/SERA_ANDROID_EDITOR_IMPORT_ja.md").read_text(encoding="utf-8")
manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
render = project.partition("[rendering]")[2]
assert render, "Godot rendering section missing"
assert "renderer/rendering_method=\"gl_compatibility\"" in render
assert "textures/vram_compression/import_etc2_astc=true" in render, \
    "Android editor needs ETC2/ASTC imports in tracked project.godot"
assert "s=s.replace('[rendering]'" not in workflow and "p.write_text(s,encoding" not in workflow, \
    "APK workflow must not quietly patch a different project setting"
assert "textures/vram_compression/import_etc2_astc=true" in workflow, \
    "APK workflow must check that Android import configuration is committed"
assert ".godot/imported" in docs, "document reimport process"
assert "user://" in docs, "warn to preserve save files"
assert "py tools/sera_android_editor_import_parity_self_check.py" in manifest
print("SERA_ANDROID_EDITOR_IMPORT_PARITY_PASS")
