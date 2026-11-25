"""Factory V4 texture evidence gates (stdlib only)."""
import quality_gates as q

def uv(src,d):
    h=q.load(src/"handoff.json");m=q.load(src/"uv_metrics.json");g=q.load(src/"face_geometry.json")
    e=q.load(src/"export_manifest.json");l=q.load(src/"uv_layout.json")
    model=d["stages"]["model"]["files"]
    q.need(h.get("format")=="SERA_PF_TEXTURE_HANDOFF_V4" and h["id"]==d["id"] and h["geometry_key"]==d["stages"]["geometry"]["key"],"stale texture handoff")
    q.need(h["source_glb_sha256"]==model["model.glb"] and h["source_blend_sha256"]==model["model.blend"]==g["source_blend_sha256"]==e["source_blend_sha256"],"texture source mismatch")
    q.need(q.sha(src/"face_geometry.json")==h["face_geometry_sha256"],"face geometry changed")
    q.need(q.canonical({k:v for k,v in g.items() if k!="geometry_sha256"})==g["geometry_sha256"]==h["geometry_sha256"]==m["geometry_sha256"]==l["geometry_sha256"]==e["geometry_sha256"],"geometry fingerprint mismatch")
    q.need(l["method"]=="AI_MANUAL_FACE" and l["format"]=="SERA_PF_MANUAL_UV_V4","manual UV required")
    q.need(m["format"]=="SERA_PF_UV_METRICS_V4" and m["overlap_pairs"]==0 and m["same_chart_max_error"]<=2e-6,"UV validation failed")
    q.need(q.sha(src/"uv_layout.json")==m["layout_sha256"]==e["layout_sha256"] and q.sha(src/"mesh.json")==m["mesh_sha256"],"UV file changed")
    q.need(e["uv_metrics_sha256"]==q.sha(src/"uv_metrics.json") and e["glb_sha256"]==q.sha(src/"uv_model.glb") and e["atlas_sha256"] is None,"UV export mismatch")
    q.need(e["format"]=="SERA_PF_TEXTURE_EXPORT_V4","invalid UV export")

def paint(src,d,g):
    u=d["stages"]["uv"]["files"];b=q.load(src/"bake_manifest.json");e=q.load(src/"export_manifest.json")
    q.need(b["format"]=="SERA_PF_TEXTURE_BAKE_V4" and b["tool"]=="Texture Studio ai_pipeline","Texture Studio bake required")
    q.need(b["mesh_sha256"]==u["mesh.json"] and b["layout_sha256"]==u["uv_layout.json"]==e["layout_sha256"],"paint input mismatch")
    q.need(e["source_blend_sha256"]==d["stages"]["model"]["files"]["model.blend"] and e["uv_metrics_sha256"]==u["uv_metrics.json"] and e["geometry_sha256"]==b["geometry_sha256"],"paint export mismatch")
    q.need(q.sha(src/"surface_plan.json")==b["surface_plan_sha256"],"surface plan changed")
    for n in (512,1024,2048):
        name=f"texture_{n}.png"
        q.need(q.sha(src/name)==b["textures"][name],"texture changed: "+name)
        p=src/str(n)/"report.json"
        q.need(q.sha(p)==b["reports"][str(n)],"bake report changed")
        r=q.load(p)
        q.need(r["resolution"]==n and r["covered_samples_changed"]==0,"invalid bake diagnostics")
    q.need(e["format"]=="SERA_PF_TEXTURE_EXPORT_V4" and e["glb_sha256"]==q.sha(src/"model.glb") and e["bake_manifest_sha256"]==q.sha(src/"bake_manifest.json"),"painted export changed")
    q.need(e["atlas_sha256"] in b["textures"].values(),"embedded atlas not from accepted bake")
    v=q.load(src/"embedded_review.json")
    q.need(v["format"]=="SERA_PF_EMBEDDED_REVIEW_V4" and v["glb_sha256"]==e["glb_sha256"] and v["atlas_sha256"]==e["atlas_sha256"] and v["all_primitives_match"] is True,"embedded texture comparison required")
    for mesh in g["meshes"]:
        for prim in mesh["primitives"]:
            q.need("TEXCOORD_0" in prim["attributes"] and "material" in prim and "baseColorTexture" in g["materials"][prim["material"]]["pbrMetallicRoughness"],"untextured primitive")
