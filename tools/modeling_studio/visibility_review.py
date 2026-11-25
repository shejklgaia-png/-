"""Check authored visible features against actual assembled mesh geometry."""
import bpy
from mathutils import Vector

def review_visibility(checks):
    scene=bpy.context.scene
    deps=bpy.context.evaluated_depsgraph_get()
    rows=[]
    for cfg in checks:
        direction=Vector(cfg["direction"]).normalized()
        results=[]
        for point in cfg["points"]:
            origin=Vector(point)+direction*2
            hit,loc,normal,index,obj,matrix=scene.ray_cast(deps,origin,-direction,distance=2.1)
            name=obj.name if hit else None
            results.append({"point_m":point,"first_surface":name,"passed":name==cfg["target"]})
        rows.append({"name":cfg["name"],"target":cfg["target"],"samples":results,"passed":all(r["passed"] for r in results)})
    return {"format":"SERA_VISIBILITY_REVIEW_V1","checks":rows,"all_passed":all(r["passed"] for r in rows),
            "limits":"Finite ray samples at neutral pose; does not certify material appearance or all angles."}
