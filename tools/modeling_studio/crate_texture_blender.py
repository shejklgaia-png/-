"""CRATE review-candidate texture bridge. Existing Texture Studio painter, no geometry replacement."""
import json,sys,hashlib
from pathlib import Path
import bpy

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
sys.path.insert(0,str(ROOT.parent/"parts_factory"))
from blender_texture import collect
from build import render_views

def dump(path,data):
    path.write_text(json.dumps(data,indent=2,allow_nan=False),encoding="utf-8")

def extract(root):
    out=root/"textured"
    out.mkdir(exist_ok=False)
    objects,g=collect()
    # Existing per-object UVs are already unwrapped by Modeling Studio.
    # Pack all islands globally, preserving polygon loop order and topology.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        obj.data.uv_layers.active.data[0].uv # fail if no UV
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.context.scene.tool_settings.use_uv_select_sync=True
        bpy.ops.uv.average_islands_scale()
        bpy.ops.uv.pack_islands(rotate=True,margin_method="FRACTION",margin=.0015)
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")
    by={o.name:o for o in objects}
    face_uv=[]
    for face in g["faces"]:
        layer=by[face["object"]].data.uv_layers.active
        face_uv.append([[float(layer.data[i].uv.x),1-float(layer.data[i].uv.y)] for i in face["loops"]])
    dump(out/"surface_geometry.json",g)
    dump(out/"face_uv.json",face_uv)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"uv.blend"))

def apply(root):
    out=root/"textured"
    atlas=out/"paint"/"albedo.png"
    report=json.loads((out/"paint"/"report.json").read_text())
    if report["triangles"]<=0 or report["raster_collision_samples"]>max(64,report["triangles"]//10):
        raise ValueError("unexpected raster overlap; inspect paint report")
    image=bpy.data.images.load(str(atlas),check_existing=False)
    image.colorspace_settings.name="sRGB"
    image.pack()
    objects=[o for o in bpy.context.scene.objects if o.type in ("MESH","EMPTY")]
    used={}
    for obj in objects:
        if obj.type!="MESH":continue
        for slot in obj.material_slots:
            original=slot.material
            if original.name not in used:
                m=original.copy();m.use_nodes=True
                nodes=m.node_tree.nodes
                bs=next(n for n in nodes if n.type=="BSDF_PRINCIPLED")
                tex=nodes.new("ShaderNodeTexImage");tex.image=image
                uv=nodes.new("ShaderNodeTexCoord")
                m.node_tree.links.new(uv.outputs["UV"],tex.inputs["Vector"])
                m.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])
                used[original.name]=m
            slot.material=used[original.name]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/"model.glb"),export_format="GLB",
        use_selection=True,export_yup=True,export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"painted.blend"))
    spec=json.loads((root/"design.json").read_text())
    render_views(objects,out,int(spec.get("review_resolution",768)),spec.get("landmarks",{}),
        spec.get("review_cameras",{}),spec.get("camera_fits",{}))
    dump(out/"texture_manifest.json",{"format":"SERA_CRATE_TEXTURE_CANDIDATE_V1",
        "source_model_sha256":hashlib.sha256((root/"model.glb").read_bytes()).hexdigest(),
        "painted_glb_sha256":hashlib.sha256((out/"model.glb").read_bytes()).hexdigest(),
        "atlas_sha256":hashlib.sha256(atlas.read_bytes()).hexdigest(),
        "uv_method":"existing Blender original-loop UVs, globally repacked; not manual approved UV",
        "visual_approval":"pending","tool":"Texture Studio ai_pipeline","notes":"Candidate, not game replacement."})

if __name__=="__main__":
    phase,root=sys.argv[sys.argv.index("--")+1:]
    {"extract":extract,"apply":apply}[phase](Path(root).resolve())
