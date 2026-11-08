#!/usr/bin/env python3
"""SERA v142: camera-relative model transfer, Back return and projected coverage.

Source and independent geometry regression only, not a Godot engine test.
"""
from math import radians, tan
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v148"' in p

def fn(start, stop):
    return s.split("func "+start, 1)[1].split("func "+stop, 1)[0]

show = fn("_show_customization_preview() -> void:",
          "_apply_customization_entrance(")
blend = fn("_apply_customization_entrance(progress: float,",
           "_customization_entrance_arrived(")
ret = fn("_begin_customization_retraction() -> void:",
         "_customization_retraction_arrived() -> void:")
select = fn("_select_target(target_name: String) -> void:", "_focus_arrived(")
back = fn("_return_to_overview() -> void:", "_overview_arrived()")
stowed = fn("_customization_retraction_arrived() -> void:",
            "_restore_customization_preview() -> void:")
overview = fn("_overview_arrived() -> void:", "_move_camera(")

# World coordinates are converted to camera-relative poses at both ends,
# then mapped through the camera's real pose on every Tween frame.
assert "customize_transition_start_camera_pose.affine_inverse() * initial_world" in show
assert "cam.global_transform.affine_inverse() * final_world" in show
assert "cam.global_transform.affine_inverse() * initial_world" in ret
assert "overview_camera_world.affine_inverse() * stowed_world" in ret
assert "var overview_camera_world: Transform3D = global_transform * overview_pose" in ret
assert "start_camera_local.interpolate_with(" in blend
assert "end_camera_local, progress)" in blend
assert "cam.global_transform * camera_relative" in blend
assert "initial_world.interpolate_with(" not in blend
assert "stowed_world, progress)" not in blend
assert "customize_transition_start_camera_pose = cam.global_transform" in select
assert select.index("customize_transition_start_camera_pose = cam.global_transform") < select.index("cam.transform = aim_pose")
assert select.index("_show_customization_preview()") < select.index("_move_camera(")
assert "start_camera_local, end_camera_local" in show
assert "start_camera_local, stowed_camera_local" in ret

# Model and camera start on the same tap and Back events.
assert back.index("_begin_customization_retraction()") < back.index("_move_camera(")
assert 'if focused_target == "CUSTOMIZE" and customize_preview_active:' in overview
assert "_restore_customization_preview()" in stowed
assert "CUSTOMIZE_ENTRANCE_SECONDS: float = 0.14" in s
assert "CUSTOMIZE_RETRACTION_SECONDS: float = 0.14" in s
assert "CAMERA_TRANSITION_SECONDS: float = 0.18" in s

# Representative 720x1280 viewport points, using the two stable camera frames.
# Their camera-space depth remains positive, so normalized screen positions
# move continuously without leaving the frame in either direction.
preview = (-0.75, -0.10, -3.25)
exhibit = (0.0, -0.40, -15.0)
aspect = 720.0 / 1280.0

def project(v, fov):
    x, y, z = v
    depth = -z
    assert depth > 0.05
    half_height = tan(radians(fov * 0.5)) * depth
    return (0.5 + x / (2.0*half_height*aspect),
            0.5 - y / (2.0*half_height))

for start, end, from_fov, to_fov in (
    (preview, exhibit, 67.0, 63.0),
    (exhibit, preview, 63.0, 67.0),
):
    positions = []
    for i in range(101):
        progress = i/100.0
        point = tuple(a+(b-a)*progress for a,b in zip(start, end))
        camera_progress = min(1.0, progress*0.14/0.18)
        fov = from_fov + (to_fov-from_fov)*camera_progress
        px, py = project(point, fov)
        assert 0.05 < px < 0.95 and 0.05 < py < 0.95, (progress,px,py)
        if positions:
            assert abs(px-positions[-1][0]) < 0.02
            assert abs(py-positions[-1][1]) < 0.02
        positions.append((px,py))
    assert abs(positions[0][0]-project(start, from_fov)[0]) < 1.e-9
    assert abs(positions[-1][0]-project(end, to_fov)[0]) < 1.e-9

print("v142 camera-relative SERA transfer and on-screen continuity: STATIC PASS")
print("Godot/Xperia runtime rendering and occlusion: NOT TESTED")
