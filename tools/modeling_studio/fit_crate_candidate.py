"""Reference-fitted CRATE candidate; never overwrites production or baseline."""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Matrix, Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build import render_views, mesh_report

# Fitted on projected production mesh groups against independent three-view
# masks, with bounded scale/translation. Blender axes X width, Y depth, Z up.
# Each row is sx, sy(depth), sz(height), dy, dz, around group bounds center.
FITS = {
    "Head": (.73931116,.89943585,.93061935,.01974705,.00651272),
    "Body": (.73368810,.69811813,1.29036593,.03330081,-.02424733),
    "Track": (.83184491,1.10151272,1.13818927,-.00281016,-.00661788),
    "Arm": (.74197783,.68925424,1.00483677,.09947075,-.00403252),
}

def group(obj):
    n=obj
    while n is not None:
        if n.name=="HeadPivot": return "Head"
        if n.name in ("LeftTrack","RightTrack"): return "Track"
        if n.name in ("LeftArmPivot","RightArmPivot"): return "Arm"
        n=n.parent
    if obj.name.startswith("Body_"): return "Body"
    return None

def main():
    source,out=map(lambda p:Path(p).resolve(),sys.argv[sys.argv.index("--")+1:])
    out.mkdir(parents=True,exist_ok=False)
    bpy.ops.wm.open_mainfile(filepath=str(source/"crate_current.blend"))
    objects=list(bpy.context.scene.objects)
    before=mesh_report(objects)
    original={o.name:o.matrix_world.copy() for o in objects}
    groups={g:[o for o in objects if group(o)==g] for g in FITS}
    mesh_names={o.name for o in objects if o.type=="MESH"}
    grouped={o.name for group_objects in groups.values() for o in group_objects if o.type=="MESH"}
    if mesh_names!=grouped: raise ValueError("unclassified CRATE meshes")
    transforms={}
    for g,members in groups.items():
        vs=[o.matrix_world@v.co for o in members if o.type=="MESH" for v in o.data.vertices]
        if not vs: raise ValueError("empty CRATE group "+g)
        anchor=Vector([(min(v[i] for v in vs)+max(v[i] for v in vs))/2 for i in range(3)])
        sx,sy,sz,dy,dz=FITS[g]
        scale=Matrix.Diagonal((sx,sy,sz,1))
        affine=Matrix.Translation(anchor+Vector((0,dy,dz)))@scale@Matrix.Translation(-anchor)
        for obj in members:
            if obj.parent not in members:
                obj.matrix_world=affine@original[obj.name]
        transforms[g]={"anchor":list(anchor),"scale":[sx,sy,sz],"translation":[0,dy,dz]}
    bpy.context.view_layer.update()
    after=mesh_report(objects)
    if sum(x["triangles"] for x in before)!=sum(x["triangles"] for x in after):
        raise ValueError("candidate changed triangle count unexpectedly")
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"crate_candidate.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects: obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/"crate_candidate.glb"),export_format="GLB",use_selection=True,export_yup=True,export_animations=False)
    render_views(objects,out,768,{},{},{})
    report={"format":"SERA_CRATE_PROPORTION_CANDIDATE_V1",
            "source_commit":(source/"source_commit.txt").read_text().strip(),
            "source_blob":(source/"source_blob.txt").read_text().strip(),
            "transforms":transforms,"triangles":sum(x["triangles"] for x in after),
            "reference":"クレート・コンパニオンロボット三面図.png",
            "projected_estimate_iou":{"front":.80772,"right":.88374,"back":.83212},
            "limits":"Estimated IoU from low-resolution group projection, not actual candidate render. Group scaling changes pivots and may alter articulation. No game replacement. Need actual image comparison and motion compatibility review."}
    (out/"candidate_report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False))
if __name__=="__main__":
    main()
