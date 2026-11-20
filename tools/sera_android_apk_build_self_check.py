#!/usr/bin/env python3
"""Validate SERA GAME Android export (not the separate SERA Loader)."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/sera-game-android-apk.yml").read_text(encoding="utf-8")
assert re.search(r'^config/name="SERA v\d+"$', project, re.M)
for marker in (
    'name="Android"', 'platform="Android"', 'runnable=true',
    'gradle_build/use_gradle_build=false',
    'architectures/arm64-v8a=true',
    'architectures/armeabi-v7a=false',
    'package/unique_name="org.shejklgaia.sera"',
    'package/name="SERA"'
):
    assert marker in preset, marker
assert 'keystore/debug_password=' not in preset
assert 'keystore/release_password=' not in preset
for marker in (
    'Build SERA Game APK', 'firebelley/godot-export@v8.0.0',
    '4.7.2-stable', 'presets_to_export: Android',
    'export_debug: true', 'keytool -genkeypair',
    'SERA-Game-Android-APK', 'apksigner', 'aapt',
    'actions/upload-artifact@v4', 'workflow_dispatch:'
):
    assert marker in workflow, marker
assert 'tools/sera-loader/' not in workflow
print("SERA_ANDROID_GAME_APK_EXPORT_CONFIG_PASS")
