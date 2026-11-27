"""Texture Studio bridge: author UV by original face, validate, and bake at 3 sizes."""
import argparse, json, math, shutil, sys, subprocess
from pathlib import Path
import factory as f
import quality_gates as q
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import knowledge_bridge as kb

def prepare(work,out,blender):
    d=f.state(work);valid,_=f.verify(work,d)
    q.need("geometry" in valid,"geometry approval required")
    packet=kb.retrieve("texture",d["slot"]+" UV surface paint")
    model=work/"objects"/d["stages"]["model"]["key"]
    subprocess.run([blender,"-b",str(model/"model.blend"),"--python-exit-code","1","--python",str(Path(__file__).with_name("blender_texture.py")),"--","extract",str(out)],check=True)
    kb.write(out/"knowledge_snapshot.json",packet)
    g=f.read(out/"face_geometry.json")
    q.need(g["source_blend_sha256"]==d["stages"]["model"]["files"]["model.blend"],"source mismatch")
    f.write(out/"handoff.json",{"format":"SERA_PF_TEXTURE_HANDOFF_V4","id":d["id"],"geometry_key":d["stages"]["geometry"]["key"],
        "source_glb_sha256":d["stages"]["model"]["files"]["model.glb"],"source_blend_sha256":g["source_blend_sha256"],
        "face_geometry_sha256":f.digest(out/"face_geometry.json"),"geometry_sha256":g["geometry_sha256"]})

def validate(handoff,layout,out):
    import numpy as np
    from shapely.geometry import Polygon
    from shapely.strtree import STRtree
    g=f.read(handoff/"face_geometry.json");h=f.read(handoff/"handoff.json");l=f.read(layout)
    q.need(h["face_geometry_sha256"]==f.digest(handoff/"face_geometry.json") and l["geometry_sha256"]==g["geometry_sha256"]==h["geometry_sha256"],"layout geometry mismatch")
    q.need(l.get("format")=="SERA_PF_MANUAL_UV_V4" and l.get("method")=="AI_MANUAL_FACE","manual UV layout required")
    q.need(set(l["faces"])=={str(row["id"]) for row in g["faces"]},"UV face coverage")
    positions=[];uvs=[];charts=[];parts=[];groups=[[] for _ in g["faces"]];polys=[];density=[];face_signs={};edge_map={}
    for face in g["faces"]:
        fid=face["id"];r=l["faces"][str(fid)]
        arr=np.asarray(r["uv"],dtype=np.float32)
        q.need(arr.shape==(len(face["loops"]),2) and np.isfinite(arr).all() and arr.min()>=0 and arr.max()<=1,"UV corner error")
        q.need(type(r["chart"]) is int and r["chart"]>=0,"invalid chart")
        q.text(r.get("reason"),"face mapping reason")
        for k,a in enumerate(face["vertices"]):
            j=(k+1)%len(arr);b=face["vertices"][j];key=(face["part"],min(a,b),max(a,b))
            pair=arr[[k,j]] if a<b else arr[[j,k]]
            edge_map.setdefault(key,[]).append((fid,r["chart"],pair))
    for i,tri in enumerate(g["triangles"]):
        fid=tri["face"];face=g["faces"][fid];r=l["faces"][str(fid)]
        p=np.asarray(face["positions"],float)[tri["corners"]]
        # Round-trip through Blender's float32 V-up loop storage.
        uv=np.asarray(r["uv"],np.float32)[tri["corners"]].copy()
        uv[:,1]=1-np.float32(1-uv[:,1])
        da=float(np.linalg.det((uv[1:]-uv[:1]).astype(float)))
        area=float(np.linalg.norm(np.cross(p[1]-p[0],p[2]-p[0])))
        q.need(abs(da)>1e-12 and area>1e-12,"degenerate UV/geometry triangle")
        sign=da>0
        q.need(fid not in face_signs or face_signs[fid]==sign,"folded original face")
        face_signs[fid]=sign
        polys.append(Polygon(uv));density.append(math.sqrt(abs(da)/area))
        positions.extend(p.ravel().tolist());uvs.extend(uv.ravel().tolist());charts.append(r["chart"]);parts.append(tri["part"]);groups[fid].append(i)
    tree=STRtree(polys);overlap=[]
    for i,p in enumerate(polys):
        for j0 in tree.query(p):
            j=int(j0)
            if j>i and p.intersection(polys[j]).area>1e-10:overlap.append([i,j])
    q.need(not overlap,"positive-area UV overlap: "+str(overlap[:12]))
    seams=[];same_chart_error=0.;max_ratio=0.
    for e in edge_map.values():
        if len(e)!=2:continue
        a,b=e;pa,pb=a[2],b[2]
        if a[1]==b[1]:
            err=float(np.linalg.norm(pa-pb,axis=1).max());same_chart_error=max(same_chart_error,err)
            q.need(err<=2e-6,"same-chart edge disconnected")
        else:
            la,lb=float(np.linalg.norm(pa[1]-pa[0])),float(np.linalg.norm(pb[1]-pb[0]))
            q.need(min(la,lb)>0,"collapsed seam")
            ratio=max(la,lb)/min(la,lb);max_ratio=max(max_ratio,ratio)
            seams.append({"faces":[a[0],b[0]],"length_ratio":ratio})
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"texture_studio"))
    from ai_pipeline import geometry
    mesh={"positions":positions,"uvs":uvs,"chart":charts,"parts":parts,"source_faces":groups}
    fingerprint=geometry(mesh)[-1]
    out.mkdir(parents=True,exist_ok=False);shutil.copy2(layout,out/"uv_layout.json");shutil.copy2(handoff/"handoff.json",out/"handoff.json")
    kb.preflight("texture","UV layout seam padding",out)
    f.write(out/"mesh.json",mesh)
    f.write(out/"uv_metrics.json",{"format":"SERA_PF_UV_METRICS_V4","geometry_sha256":g["geometry_sha256"],
        "layout_sha256":f.digest(out/"uv_layout.json"),"mesh_sha256":f.digest(out/"mesh.json"),"painter_geometry_sha256":fingerprint,
        "triangles":len(polys),"original_faces":len(groups),"overlap_pairs":0,"same_chart_max_error":same_chart_error,
        "seam_count":len(seams),"max_seam_length_ratio":max_ratio,"seams":seams,
        "density_min":min(density),"density_max":max(density),"limits":"Positive area overlap threshold 1e-10 normalized area; padding and appearance need separate review."})

def bake(uvdir,planpath,out):
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"texture_studio"))
    from ai_pipeline import bake as paint, geometry
    uv=f.read(uvdir/"uv_metrics.json");mesh=f.read(uvdir/"mesh.json");plan=f.read(planpath)
    q.need(f.digest(uvdir/"mesh.json")==uv["mesh_sha256"] and f.digest(uvdir/"uv_layout.json")==uv["layout_sha256"],"UV assets changed")
    q.need(plan["geometry_sha256"]==geometry(mesh)[-1]==uv["painter_geometry_sha256"],"paint geometry mismatch")
    q.need(plan.get("layers") and all(layer.get("faces") or layer.get("parts") or layer.get("materials") for layer in plan["layers"]),"authored scoped surface layers required")
    out.mkdir(parents=True,exist_ok=False);shutil.copy2(planpath,out/"surface_plan.json")
    kb.preflight("texture","surface paint panel lines compression",out)
    textures={};reports={}
    for n in (512,1024,2048):
        # Same normalized surface strokes, independently rasterized rather than resized.
        p=dict(plan,resolution=n,supersample=min(int(plan.get("supersample",2)),4096//n),padding=max(4,round(int(plan.get("padding",8))*n/1024)))
        sub=out/str(n);r=paint(mesh,p,sub)
        name=f"texture_{n}.png";shutil.copy2(sub/"albedo.png",out/name)
        textures[name]=f.digest(out/name);reports[str(n)]=f.digest(sub/"report.json")
    f.write(out/"bake_manifest.json",{"format":"SERA_PF_TEXTURE_BAKE_V4","geometry_sha256":uv["geometry_sha256"],
        "layout_sha256":uv["layout_sha256"],"mesh_sha256":uv["mesh_sha256"],"surface_plan_sha256":f.digest(out/"surface_plan.json"),
        "textures":textures,"reports":reports,"visual_approval":"pending","tool":"Texture Studio ai_pipeline"})


def export(work,handoff,uvdir,out,blender,baked=None,size=1024):
    import struct,io
    from PIL import Image,ImageChops
    d=f.state(work);valid,_=f.verify(work,d)
    q.need("geometry" in valid,"geometry approval required")
    h=f.read(handoff/"handoff.json")
    q.need(h["id"]==d["id"] and h["geometry_key"]==d["stages"]["geometry"]["key"],"stale handoff")
    model=work/"objects"/d["stages"]["model"]["key"]
    q.need(h["source_blend_sha256"]==d["stages"]["model"]["files"]["model.blend"],"source mismatch")
    args=[blender,"-b",str(model/"model.blend"),"--python-exit-code","1","--python",str(Path(__file__).with_name("blender_texture.py")),"--","apply",str(handoff),str(uvdir),str(out)]
    if baked:
        q.need("uv" in valid,"accepted UV required for paint export")
        q.need(f.digest(uvdir/"uv_layout.json")==d["stages"]["uv"]["files"]["uv_layout.json"] and f.digest(uvdir/"uv_metrics.json")==d["stages"]["uv"]["files"]["uv_metrics.json"],"unaccepted UV revision")
        atlas=baked/f"texture_{size}.png"
        args.append(str(atlas))
    subprocess.run(args,check=True)
    if not baked:
        for name in ("face_geometry.json","handoff.json"):shutil.copy2(handoff/name,out/name)
        for name in ("uv_layout.json","uv_metrics.json","mesh.json"):shutil.copy2(uvdir/name,out/name)
        f.write(out/"uv.json",{"method":"AI_MANUAL_FACE","source_glb_sha256":h["source_glb_sha256"],"reviewer":"","rubric":{}})
        return
    for name in ("bake_manifest.json","surface_plan.json","texture_512.png","texture_1024.png","texture_2048.png"):shutil.copy2(baked/name,out/name)
    for n in (512,1024,2048):
        (out/str(n)).mkdir();shutil.copy2(baked/str(n)/"report.json",out/str(n)/"report.json")
    glb=out/"model.glb";g=f.glb(glb)
    with glb.open("rb") as z:
        z.seek(12);ln,kind=struct.unpack("<I4s",z.read(8));z.seek(ln,1)
        sizebin,kind=struct.unpack("<I4s",z.read(8));q.need(kind==b"BIN\x00","missing binary chunk")
        binary=z.read(sizebin)
    ref=Image.open(atlas).convert("RGB");used=set()
    for mesh in g["meshes"]:
        for prim in mesh["primitives"]:
            q.need("TEXCOORD_0" in prim["attributes"],"missing UV")
            info=g["materials"][prim["material"]]["pbrMetallicRoughness"]["baseColorTexture"]
            q.need(info.get("texCoord",0)==0 and not info.get("extensions"),"unsupported UV transform")
            used.add(g["textures"][info["index"]]["source"])
    q.need(bool(used),"no textured primitives")
    for idx in used:
        image=g["images"][idx];v=g["bufferViews"][image["bufferView"]]
        q.need(v["buffer"]==0,"external image")
        start=v.get("byteOffset",0);raw=binary[start:start+v["byteLength"]]
        actual=Image.open(io.BytesIO(raw)).convert("RGB")
        q.need(actual.size==ref.size and ImageChops.difference(actual,ref).getbbox() is None,"embedded pixels differ")
    f.write(out/"embedded_review.json",{"format":"SERA_PF_EMBEDDED_REVIEW_V4","glb_sha256":f.digest(glb),"atlas_sha256":f.digest(atlas),"all_primitives_match":True,"images":len(used)})
    f.write(out/"paint.json",{"source_uv_glb_sha256":d["stages"]["uv"]["files"]["uv_model.glb"],"painted_glb_sha256":f.digest(glb),"reviewer":"","rubric":{}})

def main():
    p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest="cmd",required=True)
    a=s.add_parser("prepare");a.add_argument("work",type=Path);a.add_argument("out",type=Path);a.add_argument("--blender",default="blender")
    a=s.add_parser("validate");a.add_argument("handoff",type=Path);a.add_argument("layout",type=Path);a.add_argument("out",type=Path)
    a=s.add_parser("bake");a.add_argument("uv",type=Path);a.add_argument("plan",type=Path);a.add_argument("out",type=Path)
    a=s.add_parser("export");a.add_argument("work",type=Path);a.add_argument("handoff",type=Path);a.add_argument("uv",type=Path);a.add_argument("out",type=Path);a.add_argument("--blender",default="blender");a.add_argument("--baked",type=Path);a.add_argument("--size",type=int,choices=(512,1024,2048),default=1024)
    a=p.parse_args()
    if a.cmd=="export":export(a.work.resolve(),a.handoff.resolve(),a.uv.resolve(),a.out.resolve(),a.blender,a.baked.resolve() if a.baked else None,a.size)
    elif a.cmd=="prepare":prepare(a.work.resolve(),a.out.resolve(),a.blender)
    elif a.cmd=="validate":validate(a.handoff.resolve(),a.layout.resolve(),a.out.resolve())
    else:bake(a.uv.resolve(),a.plan.resolve(),a.out.resolve())
if __name__=="__main__":main()
