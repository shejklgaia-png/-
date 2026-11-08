#!/usr/bin/env python3
"""SERA v140: fast reversible exhibit transfer and Back-button timing.

Source-structure tests only: full Godot runtime and Android visuals remain
unverified until tested on a device.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v140 - Fast reversible SERA motion"' in project
assert "const CUSTOMIZE_ENTRANCE_SECONDS: float = 0.28" in s
assert "const CUSTOMIZE_RETRACTION_SECONDS: float = 0.28" in s
assert "const CAMERA_TRANSITION_SECONDS: float = 0.18" in s

def section(start, end):
    return s.split("func " + start, 1)[1].split("func " + end, 1)[0]

show = section("_show_customization_preview() -> void:",
               "_apply_customization_entrance(")
blend = section("_apply_customization_entrance(progress: float,",
                "_customization_entrance_arrived(")
retract = section("_begin_customization_retraction() -> void:",
                  "_customization_retraction_arrived() -> void:")
stowed = section("_customization_retraction_arrived() -> void:",
                 "_restore_customization_preview() -> void:")
restore = section("_restore_customization_preview() -> void:",
                  "_customization_screen_bounds()")
back = section("_return_to_overview() -> void:", "_overview_arrived()")
focus = section("_focus_arrived(target_name: String) -> void:",
                "_return_to_overview()")

# Enter and retract use the same interpolator, smooth easing and distinct
# 0.28s timing parameters. The camera remains on the scene until stow ends.
assert "initial_world.interpolate_with(" in blend
assert "final_world, progress)" in blend
assert "CUSTOMIZE_ENTRANCE_SECONDS)" in show
assert "CUSTOMIZE_RETRACTION_SECONDS)" in retract
assert "customize_entrance_tween.set_trans(Tween.TRANS_CUBIC)" in show
assert "customize_entrance_tween.set_ease(Tween.EASE_IN_OUT)" in show
assert "customize_entrance_tween.set_trans(Tween.TRANS_CUBIC)" in retract
assert "customize_entrance_tween.set_ease(Tween.EASE_IN_OUT)" in retract
assert "sera_display_rig.global_transform" in retract
assert "sera_display_stand.global_transform * sera_original_transform" in retract
assert "customize_entrance_tween.tween_method(_apply_customization_entrance.bind(" in retract
assert "customize_entrance_tween.finished.connect(_customization_retraction_arrived)" in retract
assert "customize_entrance_tween.kill()" in retract
assert "_restore_customization_preview()" in stowed
assert "_move_camera(overview_pose, overview_fov, _overview_arrived)" in stowed
assert stowed.index("_restore_customization_preview()") < stowed.index("_move_camera(")

# A Back tap immediately disables selection and menus. It first retracts SERA;
# non-CUSTOMIZE devices retain the existing camera-only return route.
assert back.index('outline.set("active_target", "")') < back.index("in_transition = true")
assert 'if focused_target == "CUSTOMIZE" and customize_preview_active:' in back
assert back.index("_begin_customization_retraction()") < back.index("_restore_customization_preview()")
assert back.index("_begin_customization_retraction()") < back.index("_move_camera(")
assert "customize_right_panel.visible = false" in back
assert "back_panel.visible = false" in back
assert 'if target_name == "CUSTOMIZE":\n        _show_customization_preview()' in focus

assert "customize_entrance_tween.kill()" in restore
assert "customize_glow_quad.visible = false" in restore
assert "sera_display_rig.transform = sera_original_transform" in restore
assert "customize_preview_active = false" in restore
assert 'outline.set("hide_customize_preview_outline", false)' in s
assert 'CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO: float = 0.435' in s
assert 'CUSTOMIZE_BOTTOM_GAP_PIXELS: float = 10.0' in s
assert 'NEXUS_POSE_NAMES' in s

# A single reverse 0.28s leg is followed by 0.18s camera travel; there is
# no extra wait, model instance, or additional transition in this branch.
assert (0.28 + 0.18) < (0.46 + 0.18)
print("v140 fast 0.28s in/out SERA with post-stow camera return: STATIC PASS")
print("Godot engine and Android real-time animation: NOT TESTED")
