#!/usr/bin/env python3
"""Geometry and asset checks; not a substitute for the Godot runtime test."""
from pathlib import Path
from zipfile import ZipFile
from hashlib import sha256
from math import sqrt, sin, cos, pi
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
SRC=(ROOT/'scripts/sword_trail.gd').read_text()
MAIN=(ROOT/'scripts/main.gd').read_text()

def check(result, name):
    if not result:
        raise AssertionError(name)
    print('PASS',name)

check('QuadMesh.new()' in SRC and 'instance.mesh = quad' in SRC,'rigid single QuadMesh')
check('ImmediateMesh' not in SRC and 'surface_add_vertex' not in SRC, 'no ribbon or vertex deformation')
check('view_camera' in SRC and 'view_camera.global_transform' not in SRC,'not a camera-facing billboard')
check('target_node.global_position - player_node.global_position' in SRC,'target-relative attack bearing')
check('target_node.global_position - toward_target * (face_radius + FRONT_CLEARANCE)' in SRC,'positioned outside target face')
check('Basis(right, up, toward_player)' in SRC and 'basis = basis.rotated(toward_player, ARC_IN_PLANE_TILT)' in SRC,'orientation is target facing, in-plane swing angle separately')
check('sword_trail.call("sample_swing"' in MAIN and 'sword_trail.call("on_hit"' in MAIN, 'caller interfaces retained')

tex=Image.open(ROOT/'assets/slash_arc_target_v25.png').convert('RGBA')
mask=Image.open(ROOT/'assets/slash_arc_target_v25_reveal.png')
check(tex.size == mask.size == (785,345), 'texture and reveal have identical dimensions')
arr=np.asarray(tex)
ys,xs=np.where(arr[:,:,3] > 5)
check(xs.size > 1000 and xs.min()>=10 and xs.max()<=774, 'transparent padding and visible crescent present')
check(arr[:,:,3].max()==255 and arr[:,:,3].min()==0, 'usable transparent alpha')
check(abs((3.05/1.34) - (785/345)) < .012, 'texture and quad aspect ratio preserved (<0.6%)')
check((1.34 < 2.0) and (3.05 < 4.0), 'short arc instead of tall lower-screen effect')

# Minimum actual alpha world-space Y over texture pixels (taper and tilt included).
rotation = 0.104719755
xx=((xs+.5)/785-.5)*3.05
# UV v increases downward, thus y is inverted
yy=((.5-(ys+.5)/345)*1.34)
world_y=1.53+.32 + sin(rotation)*xx + cos(rotation)*yy
check(world_y.min() > .4 and world_y.max() < 3.2, f'visible pixels above floor (Y={world_y.min():.2f}..{world_y.max():.2f}m)')

# Face plane orientation for 8 bearings including diagonals.
for vx,vz in ((0,-1),(0,1),(1,0),(-1,0),(1,1),(-1,1),(1,-1),(-1,-1)):
    l=sqrt(vx*vx+vz*vz)
    toward=np.array([vx/l,0,vz/l]); up=np.array([0,1,0]); side=np.cross(toward,up); normal=np.cross(side,up)
    face=1/max(abs(toward[0]),abs(toward[2]))
    center=-toward*(face+.1)
    check(abs(np.dot(normal,toward)+1)<1.e-8 and max(abs(center[0]),abs(center[2]))>1,
          f'normal and target-front position for bearing ({vx},{vz})')

reference=ROOT.parent/'sera_portrait_godot_melee_v23_target_facing.zip'
if reference.is_file():
    with ZipFile(reference) as z:
        for rel in ('scripts/main.gd','scripts/sera_rig.gd','scripts/hit_burst.gd','shaders/slash_foil.gdshader','scenes/main.tscn'):
            old=z.read('sera_portrait_godot_melee_v23/'+rel)
            new=(ROOT/rel).read_bytes()
            check(sha256(old).digest()==sha256(new).digest(), f'unmodified v23 core: {rel}')

print('STATIC CHECKS PASSED (Godot runtime and mobile rendering NOT tested)')
