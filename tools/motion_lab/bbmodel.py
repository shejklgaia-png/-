"""Read-only Blockbench 5 rigid free-model preview. No source editing."""
import json, hashlib, math
from mathutils import Vector, Matrix, Euler
import bpy

# BB/Godot Y up -> Blender Z up, proper rotation (not reflection).
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def vec(x,unit):
    return C @ Vector(x) * unit
def rot(x):
    return C @ Euler(tuple(math.radians(v) for v in x),"XYZ").to_matrix() @ C.transposed()
def label(uuid):
    return "BB_"+uuid.replace("-","_")

def load_bbmodel(src,unit,scene,out):
    raw=src.read_bytes(); d=json.loads(raw)
    if d.get("meta",{}).get("model_format")!="free":
        raise ValueError("rigid free model only")
    groups={g["uuid"]:g for g in d["groups"]}
    elems={e["uuid"]:e for e in d["elements"]}
    if len(groups)!=len(d["groups"]) or len(elems)!=len(d["elements"]) or groups.keys() & elems.keys():
        raise ValueError("duplicate UUID")
    nodes={}; entries=[]; visited=set()
    mat=bpy.data.materials.new("Geometry review only"); mat.diffuse_color=(.38,.48,.58,1)
    def visit(item,parent,origin,parent_uuid):
        uuid=item["uuid"] if isinstance(item,dict) else item
        if uuid in visited: raise ValueError("duplicate hierarchy reference "+uuid)
        visited.add(uuid)
        g=groups.get(uuid)
        e=elems.get(uuid)
        if g is None and e is None: raise ValueError("unknown UUID "+uuid)
        data=g if g is not None else e
        pivot=Vector(data.get("origin",[0,0,0]))
        rotation=rot(data.get("rotation",[0,0,0]))
        if g is not None:
            if not isinstance(item,dict): raise ValueError("group must have outliner children")
            obj=bpy.data.objects.new(label(uuid),None)
        else:
            if e.get("type")!="mesh": raise ValueError("unsupported element "+str(e.get("type")))
            if e.get("export",True) is False or e.get("visibility",True) is False:
                entries.append({"uuid":uuid,"name":e.get("name"),"omitted":"hidden or nonexport"})
                return
            keys=list(e["vertices"]); index={k:i for i,k in enumerate(keys)}
            vertices=[vec(e["vertices"][k],unit) for k in keys]
            faces=[]
            for f in e["faces"].values():
                ids=f["vertices"]
                if len(ids)<3: raise ValueError("nonpolygon face")
                faces.append([index[k] for k in ids])
            mesh=bpy.data.meshes.new(label(uuid)); mesh.from_pydata(vertices,[],faces); mesh.update()
            obj=bpy.data.objects.new(label(uuid),mesh); mesh.materials.append(mat)
        scene.collection.objects.link(obj)
        obj.parent=parent
        obj.location=vec(pivot-origin,unit)
        obj.rotation_mode="XYZ"; obj.rotation_euler=rotation.to_euler("XYZ")
        obj["bb_uuid"]=uuid; obj["bb_name"]=str(data.get("name",""))
        nodes[uuid]=obj
        entries.append({"uuid":uuid,"name":data.get("name"),"node":obj.name,"parent_uuid":parent_uuid,"kind":"group" if g is not None else "mesh","origin_bb":list(pivot),"rotation_bb":data.get("rotation",[0,0,0]),"local_position_m":list(obj.location)})
        if g is not None:
            for child in item.get("children",[]): visit(child,obj,pivot,uuid)
    for item in d["outliner"]: visit(item,None,Vector((0,0,0)),None)
    if set(groups)-visited or set(elems)-visited: raise ValueError("unreferenced UUIDs")
    (out/"rig_report.json").write_text(json.dumps({"source":str(src.name),"sha256":hashlib.sha256(raw).hexdigest(),"unit_m":unit,"groups":len(groups),"elements":len(elems),"entries":entries,"scope":"raw rigid mesh geometry; no texture, gameplay equipment, runtime offsets or existing clips"},indent=2,ensure_ascii=False))
    return nodes
