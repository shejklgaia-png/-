#!/usr/bin/env python3
"""v143: immediate backdrop shutdown and straight projected SERA trajectory.

Pure source and mathematical checks; Godot / Android visual behavior untested.
"""
from math import radians, tan
from pathlib import Path
root = Path(__file__).resolve().parents[1]
script = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (root/"project.godot").read_text(encoding="utf-8")
shader = (root/"shaders/nexus_customize_radial_glow.gdshader").read_text(encoding="utf-8")
assert 'config/name="SERA v143 - Straight transfer and instant glow off"' in project

def fn(a,b):
    return script.split("func "+a, 1)[1].split("func "+b, 1)[0]

back = fn("_return_to_overview() -> void:", "_overview_arrived()")
show = fn("_show_customization_preview() -> void:", "_customize_projected_ndc(")
interp = fn("_apply_customization_entrance(progress: float,",
            "_customization_entrance_arrived(")
retract = fn("_begin_customization_retraction() -> void:",
             "_customization_retraction_arrived() -> void:")
select = fn("_select_target(target_name: String) -> void:",
            "_focus_arrived(")
restore = fn("_restore_customization_preview() -> void:",
             "_customization_screen_bounds()")

# Back immediately turns off BOTH effects (one shared glow/grid mesh),
# prior to any SERA or camera tween, with no need to await their completion.
assert 'if focused_target == "CUSTOMIZE" and customize_glow_quad != null:' in back
assert "customize_glow_quad.visible = false" in back
assert back.index("customize_glow_quad.visible = false") < back.index("in_transition = true")
assert back.index("customize_glow_quad.visible = false") < back.index("_begin_customization_retraction()")
assert back.index("customize_glow_quad.visible = false") < back.index("_move_camera(")
assert 'outline.set("active_target", "")' in back
assert 'customize_glow_quad.visible = false' in restore

# Both endpoints have stable camera and FOV frames.
assert "customize_transition_start_camera_fov = previous_camera_fov" in select
assert "customize_transition_start_camera_pose = cam.global_transform" in select
assert "start_camera_local, end_camera_local," in show
assert "customize_transition_start_camera_fov, cam.fov" in show
assert "start_camera_local, stowed_camera_local," in retract
assert "cam.fov, overview_fov" in retract

# Distinguish between the straight projected center and the 3D pose:
# transform interpolation is retained for orientation and scale only.
assert 'func _customize_projected_ndc(point: Vector3, view_fov: float) -> Vector2:' in script
assert "start_ndc.lerp(end_ndc, progress)" in interp
assert "start_camera_local.interpolate_with(" in interp
assert "camera_relative.origin = Vector3(" in interp
assert "on_screen.x * depth * half_tan * aspect" in interp
assert "on_screen.y * depth * half_tan" in interp
assert "cam.global_transform * camera_relative" in interp
assert "tan(deg_to_rad(cam.fov) * 0.5)" in interp
assert 'CUSTOMIZE_ENTRANCE_SECONDS: float = 0.28' in script
assert 'CUSTOMIZE_RETRACTION_SECONDS: float = 0.28' in script
assert 'CAMERA_TRANSITION_SECONDS: float = 0.18' in script
assert 'uniform vec3 cyber_blue : source_color' in shader
assert 'uniform vec2 grid_cells' in shader

# Test perspective re-projection using two endpoints of dramatically different
# depths and camera FOV values. NDC must remain exactly on their straight line
# even though camera zoom and model depth both vary.
aspect = 720.0 / 1280.0
start = (-0.8, -0.3, -3.25)
end = (0.3, 0.4, -15.0)

def ndc(point, fov):
    depth = -point[2]
    factor = tan(radians(fov*0.5))
    return (point[0]/(depth*factor*aspect),
            point[1]/(depth*factor))

def evaluate(a, b, f0, f1):
    p0, p1 = ndc(a, f0), ndc(b, f1)
    prev = None
    for i in range(101):
        t = i/100.0
        ndc_target = (p0[0] + (p1[0]-p0[0])*t,
                      p0[1] + (p1[1]-p0[1])*t)
        depth = (-a[2]) + ((-b[2])-(-a[2]))*t
        # Camera finishes earlier than model (0.18s vs 0.28s).
        cam_t = min(1.0, t*0.28/0.18)
        current_fov = f0 + (f1-f0)*cam_t
        factor = tan(radians(current_fov*0.5))
        camera_point = (ndc_target[0]*depth*factor*aspect,
                        ndc_target[1]*depth*factor, -depth)
        actual = ndc(camera_point, current_fov)
        assert abs(actual[0]-ndc_target[0]) < 1.e-12
        assert abs(actual[1]-ndc_target[1]) < 1.e-12
        if prev is not None:
            assert abs(actual[0]-prev[0] - (p1[0]-p0[0])*.01) < 1.e-12
            assert abs(actual[1]-prev[1] - (p1[1]-p0[1])*.01) < 1.e-12
        prev = actual
    assert ndc(a,f0) == p0 and ndc(b,f1) == p1

evaluate(start, end, 67.0, 63.0)
evaluate(end, start, 63.0, 67.0)
print("v143 instant glow off and reversible straight projection: STATIC PASS")
print("Godot parser / Android motion or occlusion: NOT TESTED")
