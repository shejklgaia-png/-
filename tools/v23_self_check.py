#!/usr/bin/env python3
"""v23 target-oriented single-quad static/asset/geometry regression checks."""
from pathlib import Path
from math import sqrt, isclose
from hashlib import sha256
from zipfile import ZipFile
import json

ROOT = Path(__file__).resolve().parent.parent
SRC = (ROOT / "scripts/sword_trail.gd").read_text(encoding="utf-8")
MAIN = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
SHADER = (ROOT / "shaders/slash_foil.gdshader").read_text(encoding="utf-8")

def ok(condition, comment):
    if not condition:
        raise AssertionError(comment)
    print("PASS",comment)

ok("QuadMesh.new()" in SRC and "instance.mesh = quad" in SRC, "single flat textured QuadMesh")
ok("ImmediateMesh" not in SRC and "surface_add_vertex" not in SRC and "PRIMITIVE_TRIANGLES" not in SRC, "no runtime ribbon geometry")
ok("slash_arc_swing_v22.png" in SRC and "slash_arc_swing_reveal_v22.png" in SRC, "retains v22 full arc artwork and reveal")
ok("toward_target: Vector3 = target_node.global_position - player_node.global_position" in SRC, "target bearing instead of sword rotation")
ok("toward_target.y = 0.0" in SRC, "bearing is level on horizontal plane")
ok("var right: Vector3 = toward_target.cross(Vector3.UP).normalized()" in SRC, "side axis perpendicular to attack")
ok("var up: Vector3 = Vector3.UP" in SRC, "arc remains upright")
ok("var toward_player: Vector3 = right.cross(up).normalized()" in SRC, "quad normal toward attacker")
ok("TARGET_HALF_EXTENT / maxf(" in SRC and "FRONT_CLEARANCE: float = 0.12" in SRC,
   "target front-surface positioning with diagonal support")
ok("instance.global_transform = Transform3D(Basis(right, up, toward_player), center)" in SRC, "locks target-facing quad transform")
ok("locked_at_onset = true" in SRC and "if not locked_at_onset and clip_time >= SWEEP_START" in SRC,
   "orientation only once at sweep start")
ok("SWEEP_START: float = 0.08333333" in SRC and "SWEEP_END: float = 0.21500000" in SRC,
   "full v22 stroke reveal timing preserved")
ok("on_hit(_world_hit: Vector3)" in SRC and "pass" in SRC, "hit sparks do not redirect the slash")
ok("reveal_texture" in SHADER and "ink.a" in SHADER and "discard" in SHADER, "shader retains image alpha and progressive reveal")
ok('sword_trail.call("sample_swing"' in MAIN and 'sword_trail.call("on_hit"' in MAIN,
   "existing caller interface preserved")

# Mathematical simulation of the Godot orientation and the box-front plane.
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
for x,z in [(1,0),(-1,0),(0,-1),(0,1),(1,1),(-1,1),(0.3,-2),(2,0.1)]:
    r=sqrt(x*x+z*z)
    f=(x/r,0,z/r)
    side=cross(f,(0,1,0))
    normal=cross(side,(0,1,0))
    face=1.0/max(abs(f[0]),abs(f[2]))
    point=(-f[0]*(face+0.12),-f[2]*(face+0.12))
    ok(abs(dot(f,normal)+1.0)<1e-6 and abs(dot(f,side))<1e-6 and
       abs(dot(side,(0,1,0)))<1e-6 and abs(dot(normal,(0,1,0)))<1e-6 and
       max(abs(point[0]),abs(point[1]))>1.0,
       "frontal, upright, front of target at bearing (%s,%s)"%(x,z))

# Compare unchanged files to the released v22 zip when available. Test works
# without the reference zip, but the release builder can verify all assets.
reference=ROOT.parent/"sera_portrait_godot_melee_v22_texture_arc.zip"
if reference.is_file():
    with ZipFile(reference) as z:
        unchanged=["scripts/main.gd","scripts/sera_rig.gd","scripts/hit_burst.gd",
                   "shaders/slash_foil.gdshader","assets/slash_arc_swing_v22.png",
                   "assets/slash_arc_swing_reveal_v22.png","scenes/main.tscn"]
        for rel in unchanged:
            expected=z.read("sera_portrait_godot_melee_v22/"+rel)
            actual=(ROOT/rel).read_bytes()
            ok(sha256(expected).digest()==sha256(actual).digest(), "v22 unchanged: "+rel)
print("v23 target-facing static regression checks PASSED")
