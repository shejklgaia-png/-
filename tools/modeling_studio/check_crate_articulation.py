"""Compare neutral and sampled mechanical pose candidates, not exact collision."""
import bpy
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fit_crate_candidate import group
from geometry_review import mesh_interference
from mathutils import Quaternion, Vector
import math

def region(obj):
    p=obj
    while p:
        if p.name.startswith("WristPivot"):
            return "Hand_"+p.parent.name
        if p.name in ("LeftArmPivot","RightArmPivot","LeftTrack","RightTrack","HeadPivot"):
            return p.name
        p=p.parent
    return group(obj)

def main():
    out=Path(sys.argv[sys.argv.index("--")+1]).resolve()
    bpy.ops.wm.open_mainfile(filepath=str(out/"crate_candidate.blend"))
    objects=list(bpy.context.scene.objects)
    byname={o.name:o for o in objects}
    def cross_pairs():
        rows=mesh_interference(objects,[])["candidates"]
        return {tuple(sorted(r["parts"])) for r in rows if region(byname[r["parts"][0]])!=region(byname[r["parts"][1]])}
    neutral=cross_pairs()
    report=[]
    for obj in objects:
        if obj.type!="EMPTY" or not (obj.name in ("HeadPivot","LeftArmPivot","RightArmPivot") or obj.name.startswith("WristPivot")):
            continue
        base=obj.rotation_euler.copy()
        # World-up head yaw / local X arm and wrist pitch. These are
        # diagnostic ranges, not approved animation clips.
        axis=Vector((0,0,1)) if obj.name=="HeadPivot" else Vector((1,0,0))
        samples=[]
        try:
            for angle in (-30,-15,15,30):
                obj.rotation_euler=(base.to_quaternion() @ Quaternion(axis,math.radians(angle))).to_euler()
                bpy.context.view_layer.update()
                pairs=cross_pairs()
                samples.append({"degrees":angle,"candidate_count":len(pairs),"new_pairs":[list(p) for p in sorted(pairs-neutral)]})
        finally:
            obj.rotation_euler=base
            bpy.context.view_layer.update()
        report.append({"pivot":obj.name,"scale":list(obj.scale),"samples":samples})
    if len(report)!=5:
        raise ValueError("expected head, two arms and two wrists")
    (out/"articulation_review.json").write_text(json.dumps({"format":"SERA_CRATE_ARTICULATION_V1",
         "neutral_cross_region_candidates":len(neutral),"joints":report,
         "limits":"Discrete one-joint poses in Blender review coordinates; material batches can include intentional overlaps. New candidates require visual review. Not exact penetration, not animation compatibility."},indent=2))
if __name__=="__main__":
    main()
