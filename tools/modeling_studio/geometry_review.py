"""Offline orthographic camera estimation and static mesh intersection candidates."""
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from itertools import combinations

def fit_camera(world, image, resolution):
    # Fit two scaled orthogonal projection axes to labeled, noncoplanar points.
    x=np.asarray(world,dtype=float)
    y=np.asarray(image,dtype=float)
    if x.ndim!=2 or x.shape[1]!=3 or y.shape!=(len(x),2) or len(x)<4 or not np.isfinite(x).all() or not np.isfinite(y).all():
        raise ValueError("camera fit requires >=4 finite 3D/2D correspondences")
    if resolution<=0:
        raise ValueError("invalid image size")
    center=x.mean(axis=0)
    yc=y.mean(axis=0)
    xx=x-center
    singular=np.linalg.svd(xx,compute_uv=False)
    if singular[-1]<=singular[0]*1e-5:
        raise ValueError("camera landmarks must span 3D, not a plane or line")
    a=np.linalg.lstsq(xx,y-yc,rcond=None)[0].T
    u,d,vt=np.linalg.svd(a,full_matrices=False)
    axes=u@vt
    scale=float(np.sum((xx@axes.T)*(y-yc))/np.sum((xx@axes.T)**2))
    if not np.isfinite(scale) or scale<=1e-8:
        raise ValueError("degenerate projection")
    right=axes[0]
    up=-axes[1]
    back=np.cross(right,up)
    target=center+right*(resolution/2-yc[0])/scale+up*(yc[1]-resolution/2)/scale
    predicted=(x-target)@axes.T*scale+resolution/2
    errors=np.linalg.norm(predicted-y,axis=1)
    q=Matrix(np.column_stack((right,up,back)).tolist()).to_quaternion()
    return {"target":target.tolist(),"direction":back.tolist(),"ortho_scale":resolution/scale,
            "quaternion":list(q),"rms_px":float(np.sqrt(np.mean(errors**2))),
            "max_px":float(errors.max()),"point_count":len(x),
            "condition":float(singular[0]/singular[-1]),
            "status":"candidate_needs_review"}

def mesh_interference(objects, allowed_pairs):
    """Surface intersection candidates, not proof of volumetric penetration."""
    allowed=set()
    meshes={o.name:o for o in objects if o.type=="MESH"}
    for entry in allowed_pairs:
        pair=entry["parts"]
        if len(pair)!=2 or len(set(pair))!=2 or not set(pair)<=set(meshes) or not entry.get("reason","").strip():
            raise ValueError("invalid intentional overlap declaration")
        allowed.add(frozenset(pair))
    entries=[]
    for name,obj in meshes.items():
        obj.data.calc_loop_triangles()
        verts=[obj.matrix_world@v.co for v in obj.data.vertices]
        tris=[tuple(t.vertices) for t in obj.data.loop_triangles]
        if not verts or not tris:
            continue
        low=[min(v[i] for v in verts) for i in range(3)]
        high=[max(v[i] for v in verts) for i in range(3)]
        entries.append((name,low,high,BVHTree.FromPolygons(verts,tris,all_triangles=True)))
    rows=[]
    for a,b in combinations(entries,2):
        if any(a[2][i]<b[1][i] or b[2][i]<a[1][i] for i in range(3)):
            continue
        pairs=a[3].overlap(b[3])
        if pairs:
            rows.append({"parts":[a[0],b[0]],"surface_triangle_pairs":len(pairs),
                         "declared_intentional":frozenset((a[0],b[0])) in allowed})
        elif all(a[1][i]<=b[1][i] and a[2][i]>=b[2][i] for i in range(3)) or all(b[1][i]<=a[1][i] and b[2][i]>=a[2][i] for i in range(3)):
            rows.append({"parts":[a[0],b[0]],"surface_triangle_pairs":0,
                         "aabb_containment_candidate":True,
                         "declared_intentional":frozenset((a[0],b[0])) in allowed})
    return {"format":"SERA_INTERFERENCE_V1","mesh_count":len(entries),"candidates":rows,
            "unreviewed_count":sum(not r["declared_intentional"] for r in rows),
            "limits":"Static pose only. Surface contact and crossing are not distinguished; AABB containment is a candidate, not proof. Self-intersection, animated sweep and exact volume are not evaluated."}
