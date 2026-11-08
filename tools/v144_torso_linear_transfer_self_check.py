#!/usr/bin/env python3
"""v144: verify torso-anchored straight trajectory and camera-frame correction.

Numerical transform/projection model and source assertions; no Godot runtime.
"""
from math import cos, pi, radians, sin, tan
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root / "project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v149"' in p

def between(a, b):
    return s.split("func " + a, 1)[1].split("func " + b, 1)[0]

anchor = between("_customize_torso_anchor_local() -> Vector3:",
                 "_show_customization_preview()")
show = between("_show_customization_preview() -> void:",
               "_prepare_customization_motion(")
start = between("_prepare_customization_motion(start_local: Transform3D,",
                "_customize_projected_ndc(")
model = between("_apply_customization_entrance(progress: float,",
                "_customization_entrance_arrived(")
camera = between("_apply_camera_transition(progress: float,",
                 "_start_training()")
retract = between("_begin_customization_retraction() -> void:",
                  "_customization_retraction_arrived()")
complete = between("_customization_entrance_arrived(final_world: Transform3D) -> void:",
                   "_begin_customization_retraction()")
restore = between("_restore_customization_preview() -> void:",
                  "_customization_screen_bounds()")
back = between("_return_to_overview() -> void:",
               "_overview_arrived()")

# The actual display rig's named torso joints are measured before fitting.
assert 'bone.name in ["Chest", "Torso", "Waist"]' in anchor
assert "sera_display_rig.to_local(bone.global_position)" in anchor
assert "return summed / float(count)" in anchor
assert 'customize_motion_torso_local = _customize_torso_anchor_local()' in show
assert show.index("customize_motion_torso_local = _customize_torso_anchor_local()") < show.index("_fit_customization_preview()")

# Both world-to-camera endpoints are projected at the TORSO, with the
# interpolated basis's torso offset removed to recover the root transform.
assert "start_camera_local * customize_motion_torso_local" in model
assert "end_camera_local * customize_motion_torso_local" in model
assert "start_bounds.get_center().lerp(" in model
assert "lerpf(-start_torso.z, -end_torso.z, progress)" in model
assert "camera_relative.origin = Vector3(" in model
assert "camera_relative.basis * customize_motion_torso_local" in model
assert "cam.global_transform * camera_relative" in model
assert "start_camera_local.interpolate_with(" in model
assert "_customize_body_bounds_ndc(" in model

# The second Tween corrects the model after camera/FOV changes in the same
# frame, eliminating a one-frame screen-space arc from callback ordering.
assert "customize_motion_start_local = start_local" in start
assert "customize_motion_end_local = end_local" in start
assert "customize_motion_progress = 0.0" in start
assert "customize_motion_active = true" in start
assert "customize_motion_progress = progress" in model
assert "if customize_motion_active and customize_preview_active:" in camera
assert "_apply_customization_entrance(customize_motion_progress," in camera
assert camera.index("cam.fov = lerpf(") < camera.index("_apply_customization_entrance(customize_motion_progress,")
assert "_prepare_customization_motion(start_camera_local, end_camera_local," in show
assert "_prepare_customization_motion(start_camera_local, stowed_camera_local," in retract
assert "customize_motion_active = false" in complete
assert "customize_motion_active = false" in restore

# UI behavior is unchanged by this motion correction.
assert back.index("customize_glow_quad.visible = false") < back.index("_begin_customization_retraction()")
assert "CUSTOMIZE_ENTRANCE_SECONDS: float = 0.14" in s
assert "CUSTOMIZE_RETRACTION_SECONDS: float = 0.14" in s
assert "CAMERA_TRANSITION_SECONDS: float = 0.18" in s
assert "CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO: float = 0.435" in s

# Numerical model: interpolate rotation and scale while the camera FOV moves
# at a different pace. Torso must lie on a straight line, while an old
# root-anchored straight line demonstrably makes the torso curve.
P = (0.25, 1.25, 0.15)  # representative model-local torso
ROOT_A = (0.1, -0.15, -12.0)
ROOT_B = (-0.75, -0.15, -3.25)
ASPECT = 720.0 / 1280.0

def rotate_scale(point, yaw, scale):
    x, y, z = point
    return (scale * (cos(yaw)*x + sin(yaw)*z),
            scale * y,
            scale * (-sin(yaw)*x + cos(yaw)*z))

def add(a, b):
    return tuple(x + y for x, y in zip(a, b))

def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))

def ndc(point, fov):
    x, y, z = point
    d = -z
    assert d > 0.05
    f = tan(radians(fov/2.0))
    return (x / (d*f*ASPECT), y / (d*f))

def from_ndc(point, depth, fov):
    f = tan(radians(fov/2.0))
    return (point[0]*depth*f*ASPECT, point[1]*depth*f, -depth)

def simulate(reverse=False):
    a, b = (ROOT_B, ROOT_A) if reverse else (ROOT_A, ROOT_B)
    ya, yb = (0.0, pi) if reverse else (pi, 0.0)
    sa, sb = (2.55, 1.35) if reverse else (1.35, 2.55)
    fa, fb = (67.0, 63.0) if reverse else (63.0, 67.0)
    torso_a = add(a, rotate_scale(P, ya, sa))
    torso_b = add(b, rotate_scale(P, yb, sb))
    n0, n1 = ndc(torso_a, fa), ndc(torso_b, fb)
    old0, old1 = ndc(a, fa), ndc(b, fb)
    max_curve_old = 0.0
    for i in range(101):
        t = i / 100.0
        yaw = ya + (yb - ya)*t
        scale = sa + (sb - sa)*t
        offset = rotate_scale(P, yaw, scale)
        desired = tuple(x+(y-x)*t for x,y in zip(n0, n1))
        depth = -torso_a[2] + (torso_a[2]-torso_b[2])*t
        camera_t = min(1.0, t*0.14/0.18)
        fov = fa + (fb-fa)*camera_t
        torso = from_ndc(desired, depth, fov)
        root = sub(torso, offset)
        observed = ndc(add(root, offset), fov)
        assert max(abs(x-y) for x, y in zip(observed, desired)) < 1.e-10
        root_ndc = tuple(x+(y-x)*t for x,y in zip(old0,old1))
        root_depth = -a[2] + (a[2]-b[2])*t
        old_root = from_ndc(root_ndc, root_depth, fov)
        old_torso = ndc(add(old_root, offset), fov)
        max_curve_old = max(max_curve_old,
                            max(abs(x-y) for x,y in zip(old_torso,desired)))
    assert max_curve_old > 0.02, max_curve_old

simulate(False)
simulate(True)
print("v144 torso-anchored screen line and camera-frame sync: STATIC + MATH PASS")
print("Godot engine, Xperia visuals, occlusion and physical gestures: NOT TESTED")
