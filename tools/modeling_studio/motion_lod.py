"""Sample articulated poses and create an explicitly requested, separate LOD."""
import math
import bpy
import bmesh
from mathutils import Quaternion, Vector
from geometry_review import mesh_interference

def motion_review(objects, sweeps, allowed):
    nodes={o.name:o for o in objects}
    results=[]
    for cfg in sweeps:
        obj=nodes[cfg["node"]]
        axis=Vector(cfg["axis"])
        start,end=map(float,cfg["degrees"])
        steps=int(cfg.get("samples",13))
        if obj.type!="EMPTY" or axis.length<1e-8 or not 2<=steps<=121 or not all(math.isfinite(v) for v in (start,end,*axis)):
            raise ValueError("motion sweep requires pivot, finite axis/range, 2..121 samples")
        base=obj.rotation_euler.copy()
        rows=[]
        try:
            for i in range(steps):
                angle=start+(end-start)*i/(steps-1)
                obj.rotation_euler=(base.to_quaternion() @ Quaternion(axis.normalized(),math.radians(angle))).to_euler()
                bpy.context.view_layer.update()
                r=mesh_interference(objects,allowed)
                rows.append({"degrees":angle,"candidates":r["candidates"],"unreviewed_count":r["unreviewed_count"]})
        finally:
            obj.rotation_euler=base
            bpy.context.view_layer.update()
        results.append({"node":obj.name,"samples":rows,"samples_with_candidates":sum(r["unreviewed_count"]>0 for r in rows)})
    return {"format":"SERA_MOTION_REVIEW_V1","sweeps":results,"limits":"Single joint at a time; discrete poses only. Surface and AABB candidates, not continuous collision or exact penetration."}

def triangles(data):
    data.calc_loop_triangles()
    return len(data.loop_triangles)

def topology(data):
    bm=bmesh.new()
    try:
        bm.from_mesh(data)
        return sum(not e.is_manifold for e in bm.edges),sum(f.calc_area()<1e-12 for f in bm.faces)
    finally:
        bm.free()

def bounds(data):
    return [min(v.co[i] for v in data.vertices) for i in range(3)]+[max(v.co[i] for v in data.vertices) for i in range(3)]

def export_lod(objects, config, output):
    nodes={o.name:o for o in objects if o.type=="MESH"}
    originals={}
    rows=[]
    if not set(config)<=set(nodes):
        raise ValueError("unknown LOD part")
    try:
        for name,opts in config.items():
            obj=nodes[name]
            ratio=float(opts["ratio"])
            limit=float(opts.get("max_bounds_error",.01))
            if not 0<ratio<1 or not 0<=limit<=.1:
                raise ValueError("invalid LOD ratio or bounds limit")
            original=obj.data
            original_bounds=bounds(original)
            original_topology=topology(original)
            n=triangles(original)
            obj.data=original.copy()
            originals[name]=original
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new("LOD collapse","DECIMATE")
            mod.decimate_type="COLLAPSE"
            mod.ratio=ratio
            bpy.ops.object.modifier_apply(modifier=mod.name)
            new=obj.data
            m=triangles(new)
            extent=max(max(original_bounds[i+3]-original_bounds[i] for i in range(3)),1e-8)
            error=max(abs(a-b) for a,b in zip(original_bounds,bounds(new)))/extent if len(new.vertices) else 1.0
            accepted=0<m<n and error<=limit and all(a<=b for a,b in zip(topology(new),original_topology)) and len(new.uv_layers)==len(original.uv_layers)
            rows.append({"part":name,"before":n,"candidate":m,"bounds_error_fraction":error,"accepted":accepted})
            if not accepted:
                obj.data=original
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(output),export_format="GLB",use_selection=True,export_yup=True,export_animations=False)
        return {"format":"SERA_LOD_V1","parts":rows,"triangles":sum(triangles(o.data) for o in nodes.values()),"limits":"Bounds/topology guard only; UV quality, silhouette and shading need visual review. Original GLB and BLEND unchanged."}
    finally:
        for name,data in originals.items():
            nodes[name].data=data
        bpy.context.view_layer.update()
