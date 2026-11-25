"""Verify authored fixed/moving joint membership in actual Blender world matrices."""
import math
import bpy
from mathutils import Quaternion,Vector

def review_joints(objects,checks):
    nodes={o.name:o for o in objects}
    def descendant(obj,ancestor):
        p=obj.parent
        while p:
            if p==ancestor:return True
            p=p.parent
        return False
    def error(a,b):
        return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
    rows=[]
    for cfg in checks:
        joint=nodes[cfg["node"]]
        axis=Vector(cfg["axis"])
        angle=float(cfg["probe_deg"])
        lo,hi=map(float,cfg["range_deg"])
        fixed=[nodes[k] for k in cfg["fixed"]]
        moving=[nodes[k] for k in cfg["moving"]]
        if joint.type!="EMPTY" or axis.length<1e-8 or not lo<=angle<=hi or abs(angle)<1e-6 or not fixed or not moving:
            raise ValueError("invalid joint probe: "+joint.name)
        if any(descendant(o,joint) or o==joint for o in fixed) or any(not descendant(o,joint) for o in moving):
            raise ValueError("fixed/moving hierarchy mismatch: "+joint.name)
        snapshot={o.name:o.matrix_world.copy() for o in fixed+moving}
        base=joint.rotation_euler.copy()
        initial=joint.matrix_world.copy()
        try:
            joint.rotation_euler=(base.to_quaternion()@Quaternion(axis.normalized(),math.radians(angle))).to_euler()
            bpy.context.view_layer.update()
            delta=joint.matrix_world@initial.inverted()
            fixed_error=max(error(o.matrix_world,snapshot[o.name]) for o in fixed)
            moving_error=max(error(o.matrix_world,delta@snapshot[o.name]) for o in moving)
            moved=min(error(o.matrix_world,snapshot[o.name]) for o in moving)
            center_error=(joint.matrix_world.translation-initial.translation).length
            ok=fixed_error<1e-5 and moving_error<1e-5 and moved>1e-5 and center_error<1e-5
            rows.append({"joint":joint.name,"fixed":cfg["fixed"],"moving":cfg["moving"],
                         "axis_local":list(axis.normalized()),"pivot_world_m":list(initial.translation),
                         "range_deg":[lo,hi],"probe_deg":angle,"fixed_matrix_error":fixed_error,
                         "moving_matrix_error":moving_error,"min_moving_change":moved,
                         "pivot_drift_m":center_error,"passed":ok,"provenance":cfg.get("provenance")})
        finally:
            joint.rotation_euler=base
            bpy.context.view_layer.update()
    return {"format":"SERA_JOINT_HIERARCHY_REVIEW_V1","joints":rows,"all_passed":all(r["passed"] for r in rows),
            "limits":"Single-pivot world matrix checks of declared representative meshes. Does not establish physical clearance, joint limits in runtime, axis accuracy relative to artwork or aesthetic acceptance."}
