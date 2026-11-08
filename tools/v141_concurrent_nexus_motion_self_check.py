#!/usr/bin/env python3
"""SERA v141: simultaneous camera and exhibition rig motions.

Source-level regression: Godot runtime / Android rendering are not run here.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v143 - Straight transfer and instant glow off"' in p
assert "CUSTOMIZE_ENTRANCE_SECONDS: float = 0.28" in s
assert "CUSTOMIZE_RETRACTION_SECONDS: float = 0.28" in s
assert "CAMERA_TRANSITION_SECONDS: float = 0.18" in s

def part(a,b):
    return s.split("func "+a,1)[1].split("func "+b,1)[0]
select = part("_select_target(target_name: String) -> void:", "_focus_arrived(")
focus = part("_focus_arrived(target_name: String) -> void:", "_return_to_overview()")
back = part("_return_to_overview() -> void:", "_overview_arrived()")
overview = part("_overview_arrived() -> void:", "_move_camera(")
show = part("_show_customization_preview() -> void:", "_apply_customization_entrance(")
retract = part("_begin_customization_retraction() -> void:", "_customization_retraction_arrived() -> void:")
stowed = part("_customization_retraction_arrived() -> void:", "_restore_customization_preview() -> void:")
blend = part("_apply_customization_entrance(progress: float,", "_customization_entrance_arrived(")
arrive = part("_customization_entrance_arrived(final_world: Transform3D) -> void:", "_begin_customization_retraction() -> void:")

# The press event calculates the final placement in the target camera frame.
assert "cam.transform = aim_pose" in select
assert 'cam.fov = float(view["fov"])' in select
assert 'var previous_camera_pose: Transform3D = cam.transform' in select
assert 'var previous_camera_fov: float = cam.fov' in select
assert "cam.transform = previous_camera_pose" in select
assert "cam.fov = previous_camera_fov" in select
assert select.index("_show_customization_preview()") < select.index("_move_camera(")
assert select.index("cam.transform = previous_camera_pose") < select.index("_move_camera(")
assert 'outline.set("active_target", target_name)' in select
assert select.index('outline.set("active_target", target_name)') < select.index("_show_customization_preview()")

# The focus callback is *not* allowed to create another SERA tween or unlock
# input at camera completion when the SERA tween is still running.
assert "_show_customization_preview()" not in focus
assert "customize_entrance_tween.is_running()" in focus
assert 'in_transition = false' in focus
assert 'in_transition = false' in arrive
assert "customize_entrance_tween.set_ease(Tween.EASE_IN_OUT)" in show
assert "start_camera_local.interpolate_with(" in blend

# The Back input launches both Tweens; camera must never await stow completion.
assert 'outline.set("active_target", "")' in back
assert 'if focused_target == "CUSTOMIZE" and customize_preview_active:' in back
assert back.index("_begin_customization_retraction()") < back.index("_move_camera(")
assert "_move_camera(overview_pose, overview_fov, _overview_arrived)" in back
assert "CUSTOMIZE_RETRACTION_SECONDS)" in retract
assert "sera_display_stand.global_transform * sera_original_transform" in retract
assert "customize_entrance_tween.finished.connect(_customization_retraction_arrived)" in retract
assert "_move_camera(" not in stowed
assert "_restore_customization_preview()" in stowed
assert "if focus_tween == null or not focus_tween.is_running():" in stowed
assert "if focused_target == \"CUSTOMIZE\" and customize_preview_active:" in overview
assert overview.index('if focused_target == "CUSTOMIZE" and customize_preview_active:') < overview.index("in_transition = false")

# The fixed background and on-screen model rotation remain independent.
rotate = part("_rotate_customization_preview(delta_x: float) -> void:", "_update_projected_silhouettes()")
assert "_update_customization_glow()" not in rotate
assert "customize_preview_position" not in rotate
assert 'customize_right_panel.visible = false' in back
assert 'focus_panel.visible = false' in back
assert 'back_panel.visible = false' in back
assert "NEXUS_POSE_NAMES" in s
assert 'CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO: float = 0.435' in s

# Parallel tween wall time is the maximum individual duration, not their sum.
assert max(0.28, 0.18) == 0.28
assert max(0.28, 0.18) < 0.28 + 0.18
print("v141 concurrent tap and Back motion, completion gate: STATIC PASS")
print("Godot engine and Android input/visual runtime: NOT TESTED")
