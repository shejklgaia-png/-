#!/usr/bin/env python3
"""SERA Android game APK export contract; not the separate loader APK."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/sera-game-android-apk.yml").read_text(encoding="utf-8")
assert re.search(r'^config/name="SERA v\d+"$', project, re.M)
for text in ['name="Android"', 'platform="Android"', 'runnable=true',
             'gradle_build/use_gradle_build=false',
             'architectures/arm64-v8a=true',
             'architectures/armeabi-v7a=false',
             'package/unique_name="org.shejklgaia.sera"',
             'package/name="SERA"']:
    assert text in preset, text
assert 'keystore/debug_password=' not in preset
assert 'keystore/release_password=' not in preset
assert 'Build SERA Game APK' in workflow, "must not build only SERA Loader"
assert 'firebelley/godot-export@v8.0.0' in workflow
assert '4.7.2-stable' in workflow
assert 'presets_to_export: Android' in workflow
assert 'export_debug: true' in workflow
assert 'keytool -genkeypair' in workflow
assert 'SERA-Game-Android-APK' in workflow
assert 'apksigner' in workflow and 'aapt' in workflow
assert 'actions/upload-artifact@v4' in workflow
assert 'gh workflow run' not in workflow
assert 'workflow_dispatch:' in workflow
assert 'tools/sera-loader/' not in workflow
print("SERA_ANDROID_GAME_APK_EXPORT_CONFIG_PASS")
, project, re.M)
for text in ['name="Android"', 'platform="Android"', 'runnable=true',
             'gradle_build/use_gradle_build=false',
             'architectures/arm64-v8a=true',
             'architectures/armeabi-v7a=false',
             'package/unique_name="org.shejklgaia.sera"',
             'package/name="SERA"']:
    assert text in preset, text
assert 'keystore/debug_password=' not in preset
assert 'keystore/release_password=' not in preset
assert 'Build SERA Game APK' in workflow, "must not build only SERA Loader"
assert 'firebelley/godot-export@v8.0.0' in workflow
assert '4.7.2-stable' in workflow
assert 'presets_to_export: Android' in workflow
assert 'export_debug: true' in workflow
assert 'keytool -genkeypair' in workflow
assert 'SERA-Game-Android-APK' in workflow
assert 'apksigner' in workflow and 'aapt' in workflow
assert 'actions/upload-artifact@v4' in workflow
assert 'gh workflow run' not in workflow
assert 'workflow_dispatch:' in workflow
assert 'tools/sera-loader/' not in workflow
print("SERA_ANDROID_GAME_APK_EXPORT_CONFIG_PASS")
