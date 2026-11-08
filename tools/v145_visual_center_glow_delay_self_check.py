#!/usr/bin/env python3
"""SERA v145: straight, constant-speed visual-body center; glow after arrival.

Static source and independent perspective/projection math; Godot and Android
real-time frame behavior require separate runtime verification.
"""
from math import cos, radians, sin, tan
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")
shader = (root/"shaders/nexus_customize_radial_glow.gdshader").read_text(encoding="utf-8")
assert 'config/name="SERA v146 - Bounded visual transfer"' in p

def fn(a,b):
    return s.split("func "+a,1)[1].split("func "+b,1)[0]

collect = fn("_capture_customize_body_markers() -> void:",
             "_show_customization_preview() -> void:")
show = fn("_show_customization_preview() -> void:",
          "_prepare_customization_motion(")
center = fn("_customize_body_center_ndc(camera_local: Transform3D,",
            "_apply_customization_entrance(")
move = fn("_apply_customization_entrance(progress: float,",
          "_customization_entrance_arrived(")
arrived = fn("_customization_entrance_arrived(final_world: Transform3D) -> void:",
             "_begin_customization_retraction() -> void:")
retract = fn("_begin_customization_retraction() -> void:",
             "_customization_retraction_arrived() -> void:")
back = fn("_return_to_overview() -> void:","_overview_arrived() -> void:")
restore = fn("_restore_customization_preview() -> void:","_customization_screen_bounds()")
camera = fn("_apply_camera_transition(progress: float,","_start_training()")

assert 'customize_motion_body_markers: PackedVector3Array' in s
for name in ("Head", "Neck", "Chest", "Torso", "Waist",
             "Shoulder_L", "Shoulder_R", "Thigh_L", "Thigh_R"):
    assert '"'+name+'"' in collect
assert "sera_display_rig.to_local(bone.global_position)" in collect
assert "customize_motion_body_markers.append(" in collect
assert "customize_motion_body_markers.is_empty()" in collect
assert "_capture_customize_body_markers()" in show

# The visible body bounds are evaluated using a small set of bone pivots,
# keeping the sword and shield from shifting the trajectory.
assert "var minimum := Vector2(INF, INF)" in center
assert "var maximum := Vector2(-INF, -INF)" in center
assert "camera_local * marker" in center
assert "return Rect2(minimum, maximum - minimum)" in center
assert "return _customize_body_bounds_ndc(camera_local, view_fov).get_center()" in center
assert '"Sword"' not in collect and '"Shield"' not in collect
assert "start_bounds.get_center().lerp(" in move
assert "target_ndc - bounds.get_center()" in move
assert "for fit_pass in range(2):" in move
assert "_customize_body_bounds_ndc(camera_relative, cam.fov)" in move
assert "camera_relative.origin.x += offset_ndc.x" in move
assert "camera_relative.origin.y += offset_ndc.y" in move
assert "cam.global_transform * camera_relative" in move
assert "customize_entrance_tween.set_trans(Tween.TRANS_LINEAR)" in show
assert "customize_entrance_tween.set_trans(Tween.TRANS_LINEAR)" in retract
assert "pose_progress: float = progress * progress * (3.0 - 2.0 * progress)" in move
assert "_apply_customization_entrance(customize_motion_progress," in camera

# The same shared background mesh contains both grid and cyan gradient.
# It stays hidden from entry until model Tween completion, never on camera
# focus completion, and goes off immediately on Back.
assert show.index("_update_customization_glow()") < show.index(
    "customize_glow_quad.visible = false")
assert "customize_glow_quad.visible = true" not in show
assert arrived.index("sera_display_rig.global_transform = final_world") < arrived.index(
    "customize_glow_quad.visible = true")
assert "_update_customization_glow()" in arrived
assert "customize_glow_quad.visible = false" in restore
assert back.index("customize_glow_quad.visible = false") < back.index(
    "_begin_customization_retraction()")
assert "uniform vec3 cyber_blue : source_color" in shader
assert "uniform vec2 grid_cells" in shader
assert "CUSTOMIZE_ENTRANCE_SECONDS: float = 0.28" in s
assert "CUSTOMIZE_RETRACTION_SECONDS: float = 0.28" in s
assert "CAMERA_TRANSITION_SECONDS: float = 0.18" in s

# The visual-center algorithm should remain on a straight screen segment
# even while scale and yaw evolve. The numerical model includes 3D landmarks
# with different depths and a varying camera FOV. The historical v145
# numerical center correction is retained only as a baseline; v146 size
# constraints are tested separately in its dedicated script.
MARKERS = [(-.28,1.65,-.1),(.25,1.66,.2),(-.35,1.18,.15),
           (.4,1.23,-.15),(-.15,.62,.08),(.16,.62,-.09),
           (-.38,.3,.21),(.35,.23,-.17),(-.35,1.05,.25),
           (.34,1.02,-.24),(-.05,1.30,0.0)]
ASPECT=720.0/1280.0

def offset(marker,yaw,scale):
    x,y,z=marker
    return (scale*(cos(yaw)*x + sin(yaw)*z),
            scale*y,scale*(-sin(yaw)*x + cos(yaw)*z))

def ndc(v,fov):
    x,y,z=v
    assert -z>.05
    half=tan(radians(fov)*.5)
    return (x/(-z*half*ASPECT),y/(-z*half))

def box_center(root,angle,scale,fov):
    projected=[]
    for m in MARKERS:
        d=offset(m,angle,scale)
        projected.append(ndc(tuple(root[k]+d[k] for k in range(3)),fov))
    return tuple((min(pt[j] for pt in projected)+max(pt[j] for pt in projected))*.5
                 for j in range(2))

def simulate(reverse=False):
    a,b=((-.75,-.2,-3.6),(.20,-.3,-13.5)) if reverse else (
          (.20,-.3,-13.5),(-.75,-.2,-3.6))
    start_yaw,end_y=(.75,-1.5) if reverse else (-1.5,.75)
    start_scale,end_scale=(2.1,1.3) if reverse else (1.3,2.1)
    f0,f1=(67.0,63.0) if reverse else (63.0,67.0)
    p0=box_center(a,start_yaw,start_scale,f0)
    p1=box_center(b,end_yaw,end_scale,f1)
    biggest_error=0.
    for i in range(101):
        t=i/100.0
        target=tuple(p0[j]+(p1[j]-p0[j])*t for j in range(2))
        pose=t*t*(3.-2.*t)
        yaw=start_yaw+(end_yaw-start_yaw)*pose
        scale=start_scale+(end_scale-start_scale)*pose
        camprogress=min(1.,t*.28/.18)
        fov=f0+(f1-f0)*camprogress
        depth=-a[2]+(a[2]-b[2])*t
        half=tan(radians(fov)*.5)
        root=[target[0]*depth*half*ASPECT,target[1]*depth*half,-depth]
        for _ in range(4):
            current=box_center(root,yaw,scale,fov)
            delta=[target[j]-current[j] for j in range(2)]
            root[0]+=delta[0]*depth*half*ASPECT
            root[1]+=delta[1]*depth*half
        out=box_center(root,yaw,scale,fov)
        error=max(abs(out[j]-target[j]) for j in range(2))
        biggest_error=max(biggest_error,error)
        assert error < 1e-4,(t,error)
    return biggest_error

assert simulate(False)<1.e-4
assert simulate(True)<1.e-4
print("v145 body silhouette center constant-speed line and delayed glow: STATIC+MATH PASS")
print("Godot/Android playback and visual occlusion: NOT TESTED")
