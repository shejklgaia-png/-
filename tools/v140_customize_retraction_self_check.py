#!/usr/bin/env python3
"""SERA v140: fast reversible exhibit transfer and Back-button timing.

Source-structure tests only: full Godot runtime and Android visuals remain
unverified until tested on a device.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v151"' in project
assert "const CUSTOMIZE_ENTRANCE_SECONDS: float = 0.14" in s
assert "const CUSTOMIZE_RETRACTION_SECONDS: float = 0.14" in s
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

# Enter and retract use the same interpolator, easing, and 0.14s times.
# Camera and rig now start in the same user-input callback.
assert "start_camera_local.interpolate_with(" in blend
assert "end_camera_local, progress)" in blend
assert "CUSTOMIZE_ENTRANCE_SECONDS)" in show
assert "CUSTOMIZE_RETRACTION_SECONDS)" in retract
assert "customize_entrance_tween.set_trans(Tween.TRANS_LINEAR)" in show
assert "customize_entrance_tween.set_trans(Tween.TRANS_LINEAR)" in retract
assert "pose_progress: float = progress * progress * (3.0 - 2.0 * progress)" in s
assert "sera_display_rig.global_transform" in retract
assert "sera_display_stand.global_transform * sera_original_transform" in retract
assert "customize_entrance_tween.tween_method(_apply_customization_entrance.bind(" in retract
assert "customize_entrance_tween.finished.connect(_customization_retraction_arrived)" in retract
assert "customize_entrance_tween.kill()" in retract
assert "_restore_customization_preview()" in stowed
assert "_move_camera(overview_pose, overview_fov, _overview_arrived)" not in stowed
assert "if focus_tween == null or not focus_tween.is_running():" in stowed
assert "_overview_arrived()" in stowed

# A Back tap immediately disables selection and menus. It first retracts SERA;
# non-CUSTOMIZE devices retain the existing camera-only return route.
assert back.index('outline.set("active_target", "")') < back.index("in_transition = true")
assert 'if focused_target == "CUSTOMIZE" and customize_preview_active:' in back
assert back.index("_begin_customization_retraction()") < back.index("_restore_customization_preview()")
assert back.index("_begin_customization_retraction()") < back.index("_move_camera(")
assert "customize_right_panel.visible = false" in back
assert "back_panel.visible = false" in back
selected = section("_select_target(target_name: String) -> void:", "_focus_arrived(")
assert "_show_customization_preview()" in selected
assert selected.index("_show_customization_preview()") < selected.index("_move_camera(")
assert "_show_customization_preview()" not in focus

assert "customize_entrance_tween.kill()" in restore
assert "customize_glow_quad.visible = false" in restore
assert "sera_display_rig.transform = sera_original_transform" in restore
assert "customize_preview_active = false" in restore
assert 'outline.set("hide_customize_preview_outline", false)' in s
assert 'CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO: float = 0.435' in s
assert 'CUSTOMIZE_BOTTOM_GAP_PIXELS: float = 10.0' in s
assert 'NEXUS_POSE_NAMES' in s

# Both Tweens start simultaneously; the overall CUSTOMIZE return duration is
# bounded by the slower SERA motion, not the sum of two moves.
assert "CAMERA_TRANSITION_SECONDS: float = 0.18" in s
assert max(0.14, 0.18) < 0.14 + 0.18
print("v140 fast 0.14s in/out SERA with parallel camera return: STATIC PASS")
print("Godot engine and Android real-time animation: NOT TESTED")
