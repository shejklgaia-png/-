"""Numerical regression of the v26 one-quad / two-world-anchor placement.

Godot CLI is not present, so this checks the actual mapping mathematics for
8 cardinal/diagonal approaches and proves uniform scaling and real endpoint
alignment; it does NOT assert that Godot rendered frames were checked.
"""
from math import sin,cos,pi,sqrt
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
text=(ROOT/'scripts/sword_trail.gd').read_text()
main=(ROOT/'scripts/main.gd').read_text()
for needed in ['QuadMesh.new()', 'slash_arc_aim_v26.png',
               'ARC_START_U: float = 84.0 / 1024.0',
               'ARC_END_U: float = 940.0 / 1024.0',
               'ARC_END_V: float = 423.0 / 512.0',
               '_lock_from_sword_tip(base, tip)', 'var span: Vector3 = finish - start',
               'instance.global_transform = Transform3D(Basis(right, up, normal), origin)']:
 assert needed in text, needed
assert 'sword_trail.set("rig_node", rig)' in main
assert 'ImmediateMesh' not in text and 'surface_add_vertex' not in text
img=Image.open(ROOT/'assets/slash_arc_aim_v26.png').convert('RGBA')
reveal=Image.open(ROOT/'assets/slash_arc_aim_v26_reveal.png')
assert img.size == (1024,512) == reveal.size
start_local=np.array([-.686248,2.15602311,-.86768963]);mid_local=np.array([.9469,2.442,-.937])
rig_y=np.array([0,.195,0])
for i in range(8):
 theta=i*pi/4
 # player is around target at radius 2.7 m, in the forward +Z axis at theta=0
 player=np.array([2.7*sin(theta),0,2.7*cos(theta)])
 target=np.array([0,1.53,0]);
 R=np.array([[cos(theta),0,sin(theta)],[0,1,0],[-sin(theta),0,cos(theta)]])
 start=player+R@start_local+rig_y
 mid=player+R@mid_local+rig_y
 aim=target-player;aim[1]=0.;aim/=np.linalg.norm(aim)
 face=1./max(abs(aim[0]),abs(aim[2]))
 finish=target-aim*(face+.035)
 chord=finish-start
 length=np.linalg.norm(chord);right=chord/length
 middle=(start+finish)*.5
 arch=mid-middle;arch-=right*np.dot(arch,right)
 if np.dot(arch,arch)<1e-9:
  arch=np.array([0.,1.,0.]);arch-=right*np.dot(arch,right)
 up=arch/np.linalg.norm(arch)
 normal=np.cross(right,up);normal/=np.linalg.norm(normal)
 cam=player+np.array([2.5,3.7,3.2])
 to_cam=cam-middle;to_cam-=right*np.dot(to_cam,right)
 if np.dot(to_cam,to_cam)>1e-6:
  v=to_cam/np.linalg.norm(to_cam)
  if np.dot(v,normal)<0: v=-v
  normal=.40*normal+.60*v; normal/=np.linalg.norm(normal)
  up=np.cross(normal,right);up/=np.linalg.norm(up)
 width=length/(856./1024)
 height=width*.5
 yoff=(.5-423./512)*height
 origin=middle-up*yoff
 def mapped(u,v):
  return origin+right*((u-.5)*width)+up*((.5-v)*height)
 actual_a=mapped(84./1024,423./512)
 actual_b=mapped(940./1024,423./512)
 error_a=np.linalg.norm(actual_a-start)
 error_b=np.linalg.norm(actual_b-finish)
 dot=np.dot(right,up)
 print(f'approach {i*45:>3}°: start_error={error_a:.9f}m target_error={error_b:.9f}m chord={length:.3f}m plane={width:.3f}x{height:.3f}m orthogonality={dot:.9f}')
 assert error_a<1e-6 and error_b<1e-6
 assert abs(dot)<1e-6
 assert abs(width/height-2.)<1e-8
 assert .2<length<5.
print('PASS: 8 approach directions, rigid single quad, UV endpoint geometry, asset sizes')
