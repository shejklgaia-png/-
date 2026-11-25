"""Read-only Blender inspection of the production CRATE export."""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build import render_views, mesh_report
from geometry_review import mesh_interference

def main():
    args=sys.argv[sys.argv.index("--")+1:]
    if len(args)!=1:
        raise ValueError("expected baseline output folder")
    out=Path(args[0]).resolve()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(out/"crate_current.glb"))
    objects=list(bpy.context.scene.objects)
    if not any(o.type=="MESH" for o in objects):
        raise ValueError("no CRATE geometry imported")
    # Godot forward -Z imports as Blender +Y; rotate the review copy to -Y.
    turn=Matrix.Rotation(math.pi,4,"Z")
    for obj in objects:
        if obj.parent is None:
            obj.matrix_world=turn @ obj.matrix_world
    bpy.context.view_layer.update()
    rows=mesh_report(objects)
    source=json.loads((out/"godot_source.json").read_text())
    total=sum(row["triangles"] for row in rows)
    if total!=source["model"]["triangles"]:
        raise ValueError("triangle count changed during CRATE export/import")
    # The production meshes batch surfaces by material and may split vertices
    # at hard edges: topological counts are diagnostic, not watertight verdicts.
    report={"format":"SERA_CRATE_BLENDER_BASELINE_V1","triangles":total,
            "mesh_count":len(rows),"meshes":rows,
            "nodes":[{"name":o.name,"parent":o.parent.name if o.parent else None,
                      "type":o.type,"location":list(o.location)} for o in objects],
            "limits":"Imported material batches are not separate mechanical solids. Hard-edge vertex splits affect manifold counts. Review excludes game shaders, outlines, animation and actual Android rendering."}
    (out/"blender_source.json").write_text(json.dumps(report,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"crate_current.blend"))
    render_views(objects,out,768,{},{},{})
    print("CRATE production baseline render PASS",total)
if __name__=="__main__":
    main()
