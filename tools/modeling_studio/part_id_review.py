"""Independent visible mesh IDs from saved Blender geometry and exact review cameras.
Run Blender --background model.blend --python-exit-code 1 --python part_id_review.py -- output_root
"""
import sys
import json
import math
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector,Euler
from mathutils.bvhtree import BVHTree

def main():
    root=Path(sys.argv[sys.argv.index("--")+1]).resolve()
    out=root/"structure_analysis"/"truth"
    out.mkdir(parents=True,exist_ok=False)
    cameras=json.loads((root/"projections.json").read_text())
    scene=bpy.context.scene
    bpy.context.view_layer.update()
    depsgraph=bpy.context.evaluated_depsgraph_get()
    objects=sorted((o for o in scene.objects if o.type=="MESH" and not o.hide_render),key=lambda o:o.name)
    if not 0<len(objects)<65535:
        raise ValueError("invalid mesh count")
    # Single BVH with polygon-to-object lookup; IDs are independent of image clustering.
    verts=[]; faces=[]; ids=[]
    for index,obj in enumerate(objects,1):
        ev=obj.evaluated_get(depsgraph)
        mesh=ev.to_mesh()
        try:
            offset=len(verts)
            verts.extend(ev.matrix_world@v.co for v in mesh.vertices)
            for f in mesh.polygons:
                faces.append(tuple(offset+i for i in f.vertices))
                ids.append(index)
        finally:
            ev.to_mesh_clear()
    tree=BVHTree.FromPolygons(verts,faces,all_triangles=False)
    report={"format":"SERA_VISIBLE_PART_ID_V1","ids":{i:o.name for i,o in enumerate(objects,1)},"views":{},
            "limits":"One orthographic center ray per pixel, nearest opaque mesh surface. No antialiasing or transparent-material simulation. Object IDs are mesh nodes, not semantic classes."}
    for name in ("front","right","back","front_3q"):
        cfg=cameras[name]
        n=int(cfg["resolution"])
        scale=float(cfg["ortho_scale"])
        if not 1<=n<=2048 or not math.isfinite(scale) or scale<=0:
            raise ValueError("invalid camera")
        rotation=Euler(cfg["camera_rotation"],'XYZ').to_matrix()
        origin=Vector(cfg["camera_location"])
        right=rotation@Vector((1,0,0))
        up=rotation@Vector((0,1,0))
        direction=rotation@Vector((0,0,-1))
        mask=np.zeros((n,n),np.uint16)
        for y in range(n):
            row=origin+up*((.5-(y+.5)/n)*scale)
            for x in range(n):
                p=row+right*(((x+.5)/n-.5)*scale)
                _,_,face,_=tree.ray_cast(p,direction)
                if face is not None:
                    mask[y,x]=ids[face]
        unique,counts=np.unique(mask,return_counts=True)
        stats={int(k):int(v) for k,v in zip(unique,counts) if k}
        if not stats:
            raise ValueError("empty part ID view "+name)
        np.save(out/(name+".npy"),mask,allow_pickle=False)
        report["views"][name]={"resolution":n,"visible_pixels_by_id":stats}
    (out/"manifest.json").write_text(json.dumps(report,indent=2),encoding="utf-8")

if __name__=="__main__":
    main()
