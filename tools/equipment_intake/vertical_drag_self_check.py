#!/usr/bin/env python3
"""Common SERA equipment 3D vertical-drag direction, independent of camera presets."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")

native = read("tools/equipment_intake/godot_preview.gd")
# Screen and mouse drag MUST use the same positive pitch delta for downward
# movement. Only pitch is inverted: horizontal yaw, two-finger pan/pinch and
# saved camera/preset values keep their established conventions.
assert "camera_pitch = clampf(camera_pitch + delta.y * 0.4, -89.0, 89.0)" in native
assert "camera_pitch = clampf(camera_pitch + event.relative.y * 0.4, -89.0, 89.0)" in native
assert "camera_pitch = clampf(camera_pitch - delta.y * 0.4" not in native
assert "camera_pitch = clampf(camera_pitch - event.relative.y * 0.4" not in native
assert "camera_yaw = wrapf(camera_yaw + delta.x * 0.4" in native
assert "camera_yaw = wrapf(camera_yaw + event.relative.x * 0.4" in native
assert "camera_pan += Vector2(movement.x, -movement.y)" in native
assert "camera_zoom = clampf(camera_zoom * relative" in native

# Gameplay's LAB craft confirmation, warehouse detail and NEXUS single-part
# inspector share this actual Godot preview through the reusable widget.
widget = read("scripts/sera_part_preview_widget.gd")
assert 'preload("res://tools/equipment_intake/godot_preview.gd")' in widget
assert 'preview_scene.call("_on_preview_drag", index, point)' in widget
assert 'preload("res://tools/equipment_intake/godot_preview.gd")' in read("scripts/base_facility_system.gd")
assert 'preload("res://scripts/sera_part_preview_widget.gd")' in read("scripts/command_nexus.gd")
assert 'preload("res://scripts/sera_part_preview_widget.gd")' in read("scripts/sera_warehouse_detail_popup.gd")

# Legacy offline/standalone WebGL variants are still distributed. Change their
# one-finger model rotation without altering pan-mode or two-finger controls.
for path in (
    "tools/icon_studio/SERA_Icon_Studio.template.html",
    "tools/icon_studio/dist/SERA_Icon_Studio_IRIS.html",
    "tools/equipment_intake/dist/SERA_Equipment_Intake_IRIS.html",
):
    source = read(path)
    assert "state.pitch=clamp(state.pitch+dy*.42,-89,89)" in source, path
    assert "state.pitch=clamp(state.pitch-dy*.42,-89,89)" not in source, path
    assert "state.yaw=((state.yaw+dx*.42+540)%360)-180" in source, path
    assert "state.panY=clamp(state.panY-dy*scale,-.7,.7)" in source, path

print("SERA_EQUIPMENT_VERTICAL_DRAG_STATIC_OK")
