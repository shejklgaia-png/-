#!/usr/bin/env python3
"""Regression: Android BASE must render a minimal frame before heavy setup."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
base = (root / "scripts/base_exploration.gd").read_text("utf-8")
project = (root / "project.godot").read_text("utf-8")

assert 'run/main_scene="res://scenes/base_exploration.tscn"' in project
ready = base.split("func _ready() -> void:", 1)[1].split("\nfunc _create_startup_overlay()", 1)[0]
assert ready.index("_setup_world()") < ready.index("_create_camera()")
assert ready.index("_create_camera()") < ready.index("_create_startup_overlay()")
assert ready.index("_create_startup_overlay()") < ready.index(
    "await get_tree().process_frame")
assert ready.count("await get_tree().process_frame") >= 2, (
    "One signal resumes before rendering; two are required for a visible frame")
assert ready.index("await get_tree().process_frame") < ready.index("_build_hangar()")
assert ready.index("_build_hangar()") < ready.index("_build_field_facilities()")
assert ready.index("_build_field_facilities()") < ready.index("_create_hud()")
assert ready.index("_create_hud()") < ready.index("startup_layer.queue_free()")
assert 'cover.color = Color("#0b111b")' in base
assert "startup_label.text = \"SERA / INITIALIZING\"" in base
assert "SERA_BASE_BOOT: COMPLETE" in base
# Disabled hub character should not force the entire combat script graph
# and its models to preload on a mobile BASE-first boot.
assert 'const SeraRig = preload(' not in base
assert 'const SERA_RIG_PATH: String = "res://scripts/sera_rig.gd"' in base
assert base.index('if not HUB_SERA_CONTROLS_ENABLED:') < base.index(
    'load(SERA_RIG_PATH) as Script')
print("SERA_BASE_STARTUP_FIRST_FRAME_STATIC_PASS")
