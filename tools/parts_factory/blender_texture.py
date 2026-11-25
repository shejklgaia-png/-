"""Blender 4.5 offline bridge: preserve evaluated original polygon corners.
Run blender -b approved.blend --python-exit-code 1 --python blender_texture.py -- extract OUT
or -- apply HANDOFF UV_DIR OUT [ATLAS.png].
No remesh, transform, triangulation modifier or runtime model replacement.
"""
import bpy
import sys,json,hashlib,math
from pathlib import Path

def sha(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda:f.read(1048576),b""):h.update(b)
    return h.hexdigest()

def write(p,data):
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False),encoding="utf-8")

def canonical(x):
    return hashlib.sha256(json.dumps(x,sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest()

def collect():
    objects=sorted((o for o in bpy.context.scene.objects if o.type=="MESH"),key=lambda o:o.name)
    if not objects or len(objects)>254:raise ValueError("mesh count exceeds painter ID budget")
    faces=[];tris=[];parts=[];meta=[]
    for pi,o in enumerate(objects):
        if o.modifiers or o.data.shape_keys or o.data.users!=1:raise ValueError("unsupported live modifiers, shape keys or shared mesh: "+o.name)
        if o.matrix_world.to_3x3().determinant()<=0:raise ValueError("negative/singular transform: "+o.name)
        me=o.data;me.calc_loop_triangles()
        parts.append({"id":pi,"name":o.name,"parent":o.parent.name if o.parent else None,
            "matrix_world":[list(row) for row in o.matrix_world]})
        by_poly={}
        for t in me.loop_triangles:by_poly.setdefault(t.polygon_index,[]).append(list(t.loops))
        for p in me.polygons:
            fid=len(faces)
            if fid>=65534:raise ValueError("face ID budget")
            ls=list(p.loop_indices)
            pos=[]
            for li in ls:
                v=o.matrix_world@me.vertices[me.loops[li].vertex_index].co
                pos.append([float(v.x),float(v.z),float(-v.y)])
            material=o.material_slots[p.material_index].material if p.material_index<len(o.material_slots) else None
            if material is None:raise ValueError("unassigned material: "+o.name)
            face={"id":fid,"part":pi,"object":o.name,"polygon":p.index,"loops":ls,
                "vertices":[me.loops[i].vertex_index for i in ls],"positions":pos,
                "material":material.name,"triangles":[]}
            for tri in by_poly.get(p.index,[]):
                face["triangles"].append(len(tris));tris.append({"face":fid,"part":pi,"corners":[ls.index(i) for i in tri]})
            if not face["triangles"]:raise ValueError("untessellated polygon")
            faces.append(face)
    return objects,{"format":"SERA_PF_FACE_GEOMETRY_V4","coordinates":"world Y up; X,Z,-Y from Blender","parts":parts,"faces":faces,"triangles":tris}

def extract(out):
    out.mkdir(parents=True,exist_ok=False)
    _,g=collect()
    g["source_blend_sha256"]=sha(Path(bpy.data.filepath))
    g["geometry_sha256"]=canonical(g)
    write(out/"face_geometry.json",g)

def apply(handoff,uvdir,out,atlas=None):
    source=json.loads((handoff/"face_geometry.json").read_text())
    uv=json.loads((uvdir/"uv_layout.json").read_text())
    report=json.loads((uvdir/"uv_metrics.json").read_text())
    objects,g=collect()
    g["source_blend_sha256"]=sha(Path(bpy.data.filepath))
    if canonical(g)!=source["geometry_sha256"] or canonical({k:v for k,v in source.items() if k!="geometry_sha256"})!=source["geometry_sha256"]:raise ValueError("geometry changed")
    if uv["geometry_sha256"]!=source["geometry_sha256"] or report["layout_sha256"]!=sha(uvdir/"uv_layout.json") or report["geometry_sha256"]!=source["geometry_sha256"] or report["overlap_pairs"]!=0:raise ValueError("UV binding invalid")
    by_name={o.name:o for o in objects};layers={}
    for o in objects:
        me=o.data
        # Export exactly one UV set, while original blend remains untouched.
        for layer in list(me.uv_layers):me.uv_layers.remove(layer)
        layers[o.name]=me.uv_layers.new(name="PF_Atlas")
        me.uv_layers.active=layers[o.name];layers[o.name].active_render=True
    for f in g["faces"]:
        row=uv["faces"][str(f["id"])]
        if len(row["uv"])!=len(f["loops"]):raise ValueError("corner count changed")
        for li,(u,v) in zip(f["loops"],row["uv"]):
            if not (math.isfinite(u) and math.isfinite(v) and 0<=u<=1 and 0<=v<=1):raise ValueError("invalid UV")
            layers[f["object"]].data[li].uv=(u,1-v)
    out.mkdir(parents=True,exist_ok=False)
    if atlas:
        bake=json.loads((atlas.parent/"bake_manifest.json").read_text())
        if bake["geometry_sha256"]!=source["geometry_sha256"] or bake["layout_sha256"]!=sha(uvdir/"uv_layout.json") or bake["textures"].get(atlas.name)!=sha(atlas):raise ValueError("atlas provenance mismatch")
        image=bpy.data.images.load(str(atlas),check_existing=False)
        image.colorspace_settings.name="sRGB";image.pack()
        copied={}
        for o in objects:
            for slot in o.material_slots:
                original=slot.material
                if original.name not in copied:
                    mat=original.copy();mat.use_nodes=True
                    nodes=mat.node_tree.nodes
                    shader=next((n for n in nodes if n.type=="BSDF_PRINCIPLED"),None)
                    if shader is None:raise ValueError("unsupported material shader")
                    tex=nodes.new("ShaderNodeTexImage");tex.image=image;tex.interpolation="Linear"
                    coord=nodes.new("ShaderNodeUVMap");coord.uv_map="PF_Atlas"
                    mat.node_tree.links.new(coord.outputs["UV"],tex.inputs["Vector"])
                    mat.node_tree.links.new(tex.outputs["Color"],shader.inputs["Base Color"])
                    copied[original.name]=mat
                slot.material=copied[original.name]
    # Include empty parents, preserve hierarchy and bind transforms.
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        current=o
        while current is not None:
            current.select_set(True);current=current.parent
    name="model.glb" if atlas else "uv_model.glb"
    bpy.ops.export_scene.gltf(filepath=str(out/name),export_format="GLB",use_selection=True,export_yup=True,export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/("painted.blend" if atlas else "uv.blend")))
    write(out/"export_manifest.json",{"format":"SERA_PF_TEXTURE_EXPORT_V4","source_blend_sha256":g["source_blend_sha256"],
        "geometry_sha256":source["geometry_sha256"],"layout_sha256":sha(uvdir/"uv_layout.json"),
        "uv_metrics_sha256":sha(uvdir/"uv_metrics.json"),"glb_sha256":sha(out/name),"atlas_sha256":sha(atlas) if atlas else None,
        "bake_manifest_sha256":sha(atlas.parent/"bake_manifest.json") if atlas else None})

if __name__=="__main__":
    a=sys.argv[sys.argv.index("--")+1:]
    if len(a)==2 and a[0]=="extract":extract(Path(a[1]).resolve())
    elif len(a) in (4,5) and a[0]=="apply":apply(*(Path(x).resolve() for x in a[1:]))
    else:raise SystemExit("extract OUT | apply HANDOFF UV_DIR OUT [ATLAS.png]")
