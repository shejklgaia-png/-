#!/usr/bin/env python3
"""v147: 2x SERA preview transfer speed with safe model/camera completion.

Static source-order and duration invariants, not Godot/Android rendering.
"""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$', p, flags=re.MULTILINE) == ["SERA v152"]
assert "const CUSTOMIZE_ENTRANCE_SECONDS: float = 0.14" in s
assert "const CUSTOMIZE_RETRACTION_SECONDS: float = 0.14" in s
assert "const CAMERA_TRANSITION_SECONDS: float = 0.18" in s
assert abs(0.28 / 0.14 - 2.0) < 1e-12
assert max(0.14, 0.18) == 0.18

def between(a,b):
    return s.split("func "+a,1)[1].split("func "+b,1)[0]

enter = between("_show_customization_preview() -> void:",
                "_prepare_customization_motion(")
arrival = between("_customization_entrance_arrived(final_world: Transform3D) -> void:",
                  "_begin_customization_retraction() -> void:")
retract = between("_begin_customization_retraction() -> void:",
                  "_customization_retraction_arrived() -> void:")
stowed = between("_customization_retraction_arrived() -> void:",
                 "_restore_customization_preview() -> void:")
focus = between("_focus_arrived(target_name: String) -> void:",
                "_return_to_overview() -> void:")
overview = between("_overview_arrived() -> void:",
                   "_move_camera(")
camera = between("_apply_camera_transition(progress: float,",
                 "_start_training()")
back = between("_return_to_overview() -> void:",
               "_overview_arrived() -> void:")
select = between("_select_target(target_name: String) -> void:",
                 "_focus_arrived(")

assert "customize_preview_final_world = final_world" in enter
assert "CUSTOMIZE_ENTRANCE_SECONDS)" in enter
assert "CUSTOMIZE_RETRACTION_SECONDS)" in retract
assert "customize_entrance_tween.set_trans(Tween.TRANS_LINEAR)" in enter
assert "customize_entrance_tween.set_trans(Tween.TRANS_LINEAR)" in retract

# At 0.14s the rig is finished, but camera can continue until 0.18s.
# Do not snap to world/stand transforms or show backdrop before camera lands.
assert "customize_motion_progress = 1.0" in arrival
assert arrival.index("if focus_tween != null and focus_tween.is_running():") < arrival.index(
    "sera_display_rig.global_transform = final_world")
assert arrival.index("sera_display_rig.global_transform = final_world") < arrival.index(
    "customize_glow_quad.visible = true")
assert "customize_motion_active = false" in arrival
assert "_customization_entrance_arrived(customize_preview_final_world)" in focus
assert "customize_entrance_tween.is_running()" in focus
assert "customize_motion_progress = 1.0" in stowed
assert stowed.index("if focus_tween == null or not focus_tween.is_running():") < stowed.index(
    "_restore_customization_preview()")
assert overview.index("if customize_entrance_tween != null and customize_entrance_tween.is_running():") < overview.index(
    "_restore_customization_preview()")
assert "_apply_customization_entrance(customize_motion_progress," in camera
assert "if customize_motion_active and customize_preview_active:" in camera

# The original v146 path and size-envelope behavior are untouched.
assert "start_bounds.get_center().lerp(" in s
assert "start_bounds.size.lerp(" in s
assert "for fit_pass in range(2):" in s
assert select.index("_show_customization_preview()") < select.index("_move_camera(")
assert back.index("_begin_customization_retraction()") < back.index("_move_camera(")
assert back.index("customize_glow_quad.visible = false") < back.index(
    "_begin_customization_retraction()")
assert (root/"README_v147_ja.md").is_file()
print("v147 SERA 0.14s in/out, camera 0.18s, safe finalization: STATIC PASS")
print("Godot runtime and Android animation playback: NOT TESTED")
