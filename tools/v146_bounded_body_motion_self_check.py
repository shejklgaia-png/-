#!/usr/bin/env python3
"""SERA v146: bound the projected body width/height during straight transfers.

Static code assertions and perspective proxy simulation. NOT a Godot runtime
or Android device test.
"""
from math import cos, sin, tan, radians
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v152"' in p

def fn(a, b):
    return s.split("func "+a, 1)[1].split("func "+b, 1)[0]

bounds = fn("_customize_body_bounds_ndc(camera_local: Transform3D,",
            "_customize_body_center_ndc(")
motion = fn("_apply_customization_entrance(progress: float,",
            "_customization_entrance_arrived(")
entry = fn("_show_customization_preview() -> void:",
           "_prepare_customization_motion(")
arrived = fn("_customization_entrance_arrived(final_world: Transform3D) -> void:",
             "_begin_customization_retraction()")
returning = fn("_begin_customization_retraction() -> void:",
               "_customization_retraction_arrived()")
back = fn("_return_to_overview() -> void:",
          "_overview_arrived()")
camera = fn("_apply_camera_transition(progress: float,",
            "_start_training()")

assert "func _customize_body_bounds_ndc(" in s
assert "return Rect2(minimum, maximum - minimum)" in bounds
assert "start_bounds.get_center().lerp(" in motion
assert "start_bounds.size.lerp(" in motion
assert "target_size.x / maxf(bounds.size.x, 0.001)" in motion
assert "target_size.y / maxf(bounds.size.y, 0.001)" in motion
assert "minf(fit_width, fit_height)" in motion
assert "camera_relative.basis = camera_relative.basis.scaled(" in motion
assert "Vector3.ONE * uniform_fit" in motion
assert "for fit_pass in range(2):" in motion
assert "for pass_index in range(4):" not in motion
assert "target_ndc - bounds.get_center()" in motion
assert "camera_relative.origin.x += offset_ndc.x" in motion
assert "camera_relative.origin.y += offset_ndc.y" in motion
assert "start_camera_local.interpolate_with(" in motion
assert "pose_progress: float = progress * progress * (3.0 - 2.0 * progress)" in motion
assert "_apply_customization_entrance(customize_motion_progress," in camera
assert "Tween.TRANS_LINEAR" in entry and "Tween.TRANS_LINEAR" in returning

# The shared cyan halo and cyber grid are still invisible during the entry
# and are shown only once SERA reaches the fitted final world transform.
assert "customize_glow_quad.visible = false" in entry
assert "customize_glow_quad.visible = true" not in entry
assert arrived.index("sera_display_rig.global_transform = final_world") < arrived.index(
    "customize_glow_quad.visible = true")
assert back.index("customize_glow_quad.visible = false") < back.index(
    "_begin_customization_retraction()")
assert "CUSTOMIZE_ENTRANCE_SECONDS: float = 0.14" in s
assert "CUSTOMIZE_RETRACTION_SECONDS: float = 0.14" in s
assert "CAMERA_TRANSITION_SECONDS: float = 0.18" in s

# Representative NEXUS body landmarks including different depths; sword and
# shield are deliberately excluded, matching the production proxy.
MARKERS=[(-.28,1.65,-.1),(.25,1.66,.2),(-.35,1.18,.15),
         (.4,1.23,-.15),(-.15,.62,.08),(.16,.62,-.09),
         (-.38,.3,.21),(.35,.23,-.17),(-.35,1.05,.25),
         (.34,1.02,-.24),(-.05,1.30,0)]
ASPECT=720.0/1280.0

def bounds_of(origin, yaw, scale, fov):
    half_tan=tan(radians(fov/2))
    px=[]
    for x,y,z in MARKERS:
        X=origin[0]+scale*(cos(yaw)*x+sin(yaw)*z)
        Y=origin[1]+scale*y
        Z=origin[2]+scale*(-sin(yaw)*x+cos(yaw)*z)
        assert -Z>0.05
        px.append((X/(-Z*half_tan*ASPECT),Y/(-Z*half_tan)))
    return [(min(v[j] for v in px)+max(v[j] for v in px))*.5 for j in (0,1)]+[
        max(v[j] for v in px)-min(v[j] for v in px) for j in (0,1)]

def run(reverse):
    start,end=((-.75,-.2,-3.6),(.2,-.3,-13.5)) if reverse else (
                 (.2,-.3,-13.5),(-.75,-.2,-3.6))
    yaw0,yaw1=(.75,-1.5) if reverse else (-1.5,.75)
    sc0,sc1=(2.1,1.3) if reverse else (1.3,2.1)
    f0,f1=(67.,63.) if reverse else (63.,67.)
    b0=bounds_of(start,yaw0,sc0,f0)
    b1=bounds_of(end,yaw1,sc1,f1)
    largest_dim_excess=0.
    largest_center_error=0.
    for frame in range(101):
        t=frame/100.
        smooth=t*t*(3.-2.*t)
        yaw=yaw0+(yaw1-yaw0)*smooth
        scale=sc0+(sc1-sc0)*smooth
        fov=f0+(f1-f0)*min(1.,t*.14/.18)
        depth=-start[2]+(start[2]-end[2])*t
        half_tan=tan(radians(fov/2))
        target=[b0[j]+(b1[j]-b0[j])*t for j in range(4)]
        origin=[target[0]*depth*half_tan*ASPECT,
                target[1]*depth*half_tan,-depth]
        # Same two size+center fit passes as production source.
        for _ in range(2):
            measured=bounds_of(origin,yaw,scale,fov)
            ratio=min(target[2]/max(measured[2],0.001),
                      target[3]/max(measured[3],0.001))
            scale*=min(3.,max(.1,ratio))
            measured=bounds_of(origin,yaw,scale,fov)
            origin[0]+=(target[0]-measured[0])*depth*half_tan*ASPECT
            origin[1]+=(target[1]-measured[1])*depth*half_tan
        actual=bounds_of(origin,yaw,scale,fov)
        largest_dim_excess=max(largest_dim_excess,
            actual[2]-target[2],actual[3]-target[3])
        largest_center_error=max(largest_center_error,
            abs(actual[0]-target[0]),abs(actual[1]-target[1]))
    assert largest_dim_excess<0.001, largest_dim_excess
    assert largest_center_error<0.001, largest_center_error

run(False)
run(True)
print("v146 linear body-center and bounded visual envelope: STATIC+MATH PASS")
print("Godot parser, actual Android 3D rendering and device motion: NOT TESTED")
