"""Independent modeling-only checks executed using Blender."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy
import numpy as np
from mathutils import Vector, Quaternion
from bpy_extras.object_utils import world_to_camera_view
from geometry_review import fit_camera, mesh_interference

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.render.resolution_x=scene.render.resolution_y=768
    scene.render.resolution_percentage=100
    data=bpy.data.cameras.new("Fit check")
    data.type="ORTHO"
    data.ortho_scale=4.2
    cam=bpy.data.objects.new("Fit check",data)
    scene.collection.objects.link(cam)
    target=Vector((.2,-.1,.3))
    cam.location=target+Vector((3,-5,2))
    cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    bpy.context.view_layer.update()
    world=[(-1,-1,-1),(1,-1,-1),(-1,1,-1),(-1,-1,1),(1,1,1),(0,.2,-.4)]
    def project():
        points=[world_to_camera_view(scene,cam,Vector(p)) for p in world]
        return [[p.x*768,(1-p.y)*768] for p in points]
    image=project()
    fit=fit_camera(world,image,768)
    cam.location=Vector(fit["target"])+Vector(fit["direction"])*6
    cam.rotation_euler=Quaternion(fit["quaternion"]).to_euler()
    data.ortho_scale=fit["ortho_scale"]
    bpy.context.view_layer.update()
    assert fit["rms_px"]<.01
    assert np.max(np.abs(np.array(project())-np.array(image)))<.02
    try:
        fit_camera([(0,0,0),(1,0,0),(0,1,0),(1,1,0)],image[:4],768)
    except ValueError:
        pass
    else:
        raise AssertionError("planar input accepted")
    def cube(name,location,size):
        bpy.ops.mesh.primitive_cube_add(size=size,location=location)
        obj=bpy.context.object
        obj.name=name
        return obj
    a=cube("A",(0,0,0),2)
    b=cube("B",(.8,.3,.2),2)
    c=cube("C",(5,0,0),2)
    d=cube("D",(0,0,0),.3)
    bpy.context.view_layer.update()
    report=mesh_interference([a,b,c,d],[{"parts":["A","B"],"reason":"fixture joint"}])
    rows={frozenset(r["parts"]):r for r in report["candidates"]}
    assert rows[frozenset(("A","B"))]["surface_triangle_pairs"]>0
    assert rows[frozenset(("A","B"))]["declared_intentional"]
    assert rows[frozenset(("A","D"))]["aabb_containment_candidate"]
    assert all("C" not in r["parts"] for r in rows.values())
    print("geometry review: projection, degeneracy, crossing, containment candidate, separated pair PASS")
if __name__=="__main__":
    main()
