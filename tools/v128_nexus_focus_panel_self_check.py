#!/usr/bin/env python3
"""v128: asymmetric Nexus camera focus and placeholder menu panel regression.

Checks authored scene/mesh data and a conservative portrait projection.
No Godot editor, Android or GPU execution occurs in this test.
"""
from pathlib import Path
import json
import math
import re

ROOT = Path(__file__).resolve().parents[1]
S = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
P = (ROOT / "project.godot").read_text(encoding="utf-8")
SRC = json.loads((ROOT / "assets/sera_source.json").read_text(encoding="utf-8"))
MODULES = json.loads(
    (ROOT / "assets/base_command_modules.gd").read_text(encoding="utf-8").split("const MODULES = ", 1)[1].strip()
)

assert 'config/name="SERA v146 - Bounded visual transfer"' in P
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in P
assert 'pointing/emulate_mouse_from_touch=false' in P
assert 'renderer/rendering_method="gl_compatibility"' in P

# All five destinations remain. TRAINING/SYSTEM were swapped in v127.
shots = {
    "TRAINING": ((1.95,3.15,7.70), (0.45,1.35,1.25), 68.0),
    "SYSTEM": ((-1.95,3.15,7.70), (-0.45,1.35,1.25), 68.0),
    "CUSTOMIZE": ((-4.50,3.80,5.00), (-1.70,2.00,-4.75), 67.0),
    "DATA ARCHIVE": ((-3.90,4.50,2.50), (-1.70,3.55,-8.80), 64.0),
    "DEPLOYMENT": ((6.20,5.30,5.00), (1.80,3.40,-10.48), 76.0),
}
panels = {
    "TRAINING": (.045, .585),
    "SYSTEM": (.365, .590),
    "CUSTOMIZE": (.035, .435),
    "DATA ARCHIVE": (.365, .590),
    "DEPLOYMENT": (.045, .465),
}
for name, (eye, look, fov) in shots.items():
    to_v3 = lambda a: "Vector3(" + ", ".join(f"{v:.2f}" for v in a) + ")"
    assert f'"{name}": {{"eye": {to_v3(eye)}' in S, name
    assert f'"look": {to_v3(look)}, "fov": {fov:.1f}' in S, name
    assert f'"{name}": Vector2({panels[name][0]:.3f}, {panels[name][1]:.3f})' in S, name

# Focus menus are plain translucent-blue rectangles with solid opaque headers.
assert 'focus_panel.add_theme_stylebox_override("panel", _menu_body_style())' in S
assert 'focus_header.add_theme_stylebox_override("panel", _menu_header_style())' in S
assert 'focus_header.add_child(focus_title)' in S
assert 'style.bg_color = Color(0.025, 0.155, 0.260, 0.52)' in S
assert 'style.bg_color = Color(0.035, 0.190, 0.315, 1.00)' in S
body_fn = S.split("func _menu_body_style() -> StyleBoxFlat:", 1)[1].split("func _menu_header_style()", 1)[0]
header_fn = S.split("func _menu_header_style() -> StyleBoxFlat:", 1)[1].split("func _action_style()", 1)[0]
assert "border_color" not in body_fn + header_fn
assert "set_border_width_all" not in body_fn + header_fn
assert 'focus_panel.size = Vector2(view.x * panel_placement.y, view.y * 0.535)' in S
assert 'focus_panel.position = Vector2(view.x * panel_placement.x, view.y * 0.225)' in S
assert 'focus_title.text = target_name' in S
assert 'action_panel.visible = target_name == "TRAINING"' in S
assert 'action_label.text = "ENTER TRAINING" if target_name == "TRAINING" else ""' in S
assert 'get_tree().change_scene_to_file(TRAINING_SCENE)' in S
assert 'back_panel.position = Vector2(view.x - margin - 62.0, view.y - margin - 62.0)' in S

# CUSTOMIZE no longer shrinks a left overlay around the projected model:
# its square panel is below the upper-left preview, with a tall right panel.
assert 'if focused_target == "CUSTOMIZE":\n        var square: Rect2 = _customize_square_menu_rect(view)' in S
assert 'focus_panel.position = square.position' in S
assert 'focus_panel.size = square.size' in S
assert 'customize_right_panel.position = tall.position' in S
assert 'customize_right_panel.size = tall.size' in S
assert 'func _customize_model_area(view: Vector2) -> Rect2:' in S
assert '_keep_customization_clear()' not in S
assert 'target_parts["CUSTOMIZE"] = grouped.values()' in S
assert 'piece.is_visible_in_tree()' in S

def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b):
    return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(v):
    n=math.sqrt(dot(v,v))
    return tuple(x/n for x in v)
def r_y(v,rad):
    return (math.cos(rad)*v[0]+math.sin(rad)*v[2],v[1],
            -math.sin(rad)*v[0]+math.cos(rad)*v[2])
def r_x(v,rad):
    return (v[0],math.cos(rad)*v[1]-math.sin(rad)*v[2],
            math.sin(rad)*v[1]+math.cos(rad)*v[2])
def r_z(v,rad):
    return (math.cos(rad)*v[0]-math.sin(rad)*v[1],
            math.sin(rad)*v[0]+math.cos(rad)*v[1],v[2])
def module_vertices(name,at,yaw=0,scale=1,height=1):
    result=[]
    for p in MODULES[name]:
        lo=[u*.1*scale for u in p[1]]
        hi=[u*.1*scale for u in p[2]]
        center=[(a+b)*.5 for a,b in zip(lo,hi)]
        size=[b-a for a,b in zip(lo,hi)]
        rotation=[math.radians(t) for t in p[4]]
        for ix in (-.5,.5):
            for iy in (-.5,.5):
                for iz in (-.5,.5):
                    v=(ix*size[0],iy*size[1],iz*size[2])
                    v=r_z(r_y(r_x(v,rotation[0]),rotation[1]),rotation[2])
                    local=((center[0]+v[0]),(center[1]+v[1])*height,center[2]+v[2])
                    rotated=r_y(local,yaw)
                    result.append(tuple(a+b for a,b in zip(at,rotated)))
    return result

kiosk_l = module_vertices("kiosk", (-1.95,0,1.30), math.radians(36))
kiosk_r = module_vertices("kiosk", (1.95,0,1.30), math.radians(-36))
archive = module_vertices("data_bank", (-4,2.19,-8.95))
gate = module_vertices("deployment_gate", (4,.02,-10.48),
                       math.atan2(-4.0,5.73),1.2,1.25)
# Conservative proxy for displayed SERA: authored mesh origins plus vertices,
# scaled by the display rig and standing on its existing pad.
sera=[]
for element in SRC["elements"]:
    if element["name"] == "Swordeffect":
        continue
    for p in element["vertices"].values():
        local = tuple((a+b)*.065*1.35 for a,b in zip(element["origin"],p))
        rotated = r_y(local,math.pi)
        sera.append((rotated[0],rotated[1]+.40,rotated[2]-4.75))
sera += module_vertices("maintenance_pad", (0,0,-4.75))

def projected(vertices, eye, look, fov):
    forward=norm(sub(look,eye))
    right=norm(cross(forward,(0,1,0)))
    up=norm(cross(right,forward))
    tangent=math.tan(math.radians(fov/2))
    xs=[]; ys=[]
    for p in vertices:
        v=sub(p,eye); depth=dot(v,forward)
        assert depth > 0.05
        xs.append(.5+dot(v,right)/(2*depth*tangent*(720/1280)))
        ys.append(.5-dot(v,up)/(2*depth*tangent))
    return min(xs),min(ys),max(xs),max(ys)

parts={
    "TRAINING":kiosk_r,"SYSTEM":kiosk_l,"CUSTOMIZE":sera,
    "DATA ARCHIVE":archive,"DEPLOYMENT":gate
}
for name,(eye,look,fov) in shots.items():
    l,t,r,b=projected(parts[name],eye,look,fov)
    panel_left,panel_width=panels[name]
    panel_right=panel_left+panel_width
    if name in ("TRAINING","DEPLOYMENT"):
        assert l >= panel_right-.09 and r <= 1.02, (name,l,r,panel_right)
        assert panel_right-l >= .012, (name,l,r,panel_right)
    elif name in ("SYSTEM","DATA ARCHIVE"):
        assert l >= -.015 and r <= panel_left+.09, (name,l,r,panel_left)
        assert r-panel_left >= .012, (name,l,r,panel_left)
    else:
        # CAMERA overview view is preserved; CUSTOMIZE's menu is now below
        # the floating preview rather than to its left.
        assert l >= 0.0 and r <= 1.01 and t>=0 and b<=1.0, ("SERA full body/weapon/pad clipped",l,t,r,b)
    assert t>=.10 and b<=.90, (name,l,t,r,b)
print("v128 five side-biased cameras and opposite menu panels: PASS")
print("SERA full visible body/weapon/pedestal conservative proxy: PASS")
print("Static source/projection check only; not Godot/Android rendering.")
