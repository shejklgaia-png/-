"""Revision-bound adapters to existing production CLIs, not automatic approvals."""
import argparse
import json
import os
import shutil
import subprocess
from pathlib import Path
import factory as f
import quality_gates as q
import continuation as c

ROOT=f.ROOT
TOOLS={
    "blueprint_brief": ("blueprint", False, False),
    "analyze": ("analysis", True, False),
    "model_build": ("model", False, True),
    "geometry_compare": ("geometry", False, False),
    "uv_prepare": ("uv", False, True),
    "uv_build": ("uv", True, True),
    "paint_build": ("paint", True, True),
}
def check_request(config):
    req=f.read(config)
    c.require(req.get("operation")=="tool" and req.get("tool") in TOOLS,"invalid tool operation")
    stage,payload,blender=TOOLS[req["tool"]]
    c.require(req.get("stage")==stage,"wrong tool for current stage")
    # Validate ordinary request identity and source checkpoint as well.
    with __import__("tempfile").TemporaryDirectory() as t:
        p=Path(t)/"request.json"
        f.write(p,dict(req,operation="accept" if payload else "prepare"))
        c.load_request(p)
    return req,payload,blender

def run(*args):
    subprocess.run([str(x) for x in args],check=True,cwd=ROOT)

def execute(source,config,out,archive=None,blender="blender",godot=None):
    req,needs_payload,needs_blender=check_request(config)
    d=f.state(source);valid,key=f.verify(source,d)
    c.require(d["id"]==req["job_id"] and key==req["upstream_revision"] and len(valid)<len(f.ORDER)
              and f.ORDER[len(valid)]==req["stage"],"stale or incorrect stage")
    c.require((archive is not None)==needs_payload,"incorrect input payload")
    c.require(not out.exists(),"new output required")
    out.mkdir(parents=True)
    work=out/"work";shutil.copytree(source,work)
    def accepted(s):
        return work/"objects"/d["stages"][s]["key"]
    result=out/"tool_output"
    tool=req["tool"]
    try:
        inp=out/"input"
        if needs_payload:
            c.extract_payload(archive,inp,req)
        if tool=="blueprint_brief":
            result.mkdir()
            concept=f.read(accepted("concept")/"concept.json")
            shutil.copy2(accepted("art")/"selected.png",result/"selected_art.png")
            from reference_bridge import DIRECTIONS
            f.write(result/"blueprint_brief.json",{
                "job_id":d["id"],"upstream_revision":key,
                "selected_art_sha256":f.digest(result/"selected_art.png"),
                "view_directions":DIRECTIONS,
                "views":list(q.BLUEPRINT_VIEWS),
                "projection_axes":"reference_bridge coordinates X right, Y back, Z up; source rig units must be converted explicitly",
                "rig_target":concept["rig_target"],"mechanism":concept["mechanism"],
                "authoring_requirements":["shared scale and origin across all ten views","show unseen surfaces as authored design, not observed evidence","separate neck clearance from external shell","draft, critique, actual reconstruction, final review"],
                "status":"unapproved_authoring_input","not_a_blueprint":True})
        elif tool=="analyze":
            from reference_bridge import analyze
            analyze(accepted("blueprint"),inp/"calibration.json",result)
        elif tool=="model_build":
            # Same authoring renderer and isolated Godot importer as Modeling Studio.
            c.require(godot is not None,"isolated Godot executable required")
            design=out/("pf_"+d["id"].lower()+".json")
            f.authorize(work,design)
            run(blender,"--background","--factory-startup","--python-exit-code","1",
                ROOT/"tools/modeling_studio/build.py","--",design,result)
            shutil.copy2(design,result/"design.json")
            project=out/"godot_review_project";project.mkdir()
            (project/"project.godot").write_text('config_version=5\n[application]\nconfig/name="Parts Factory model review"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            shutil.copy2(ROOT/"tools/modeling_studio/check_godot_import.gd",project)
            run(godot,"--headless","--path",project,"--script","res://check_godot_import.gd","--",result)
            c.require((result/"godot_import.json").is_file(),"missing Godot import evidence")
            # Artifact ID is assigned only after upload; do not fabricate final provenance.
            f.write(result/"build_receipt.json",{"tool":"Modeling Studio - authoring render",
                "commit":os.environ.get("GITHUB_SHA"),"run_id":os.environ.get("GITHUB_RUN_ID"),
                "glb_sha256":f.digest(result/"model.glb"),"artifact_id":None,"status":"awaiting_uploaded_artifact_and_review"})
        elif tool=="geometry_compare":
            from reference_bridge import compare
            compare(accepted("analysis"),accepted("model"),result)
            for view in q.RENDER_VIEWS:shutil.copy2(accepted("model")/(view+".png"),result)
        elif tool=="uv_prepare":
            import texture_bridge as t
            t.prepare(work,result,blender)
        elif tool=="uv_build":
            import texture_bridge as t
            hand=out/"texture_handoff";uv=out/"validated_uv"
            # Re-extract canonical faces; validate against actual original geometry.
            t.prepare(work,hand,blender)
            t.validate(hand,inp/"uv_layout.json",uv)
            t.export(work,hand,uv,result,blender)
        elif tool=="paint_build":
            import texture_bridge as t
            uv=accepted("uv");baked=out/"baked"
            t.bake(uv,inp/"surface_plan.json",baked)
            t.export(work,uv,uv,result,blender,baked,size=1024)
        c.require(f.verify(work,f.state(work))==(valid,key),"tool mutated approved state")
        f.write(out/"tool_receipt.json",{"job_id":d["id"],"stage":req["stage"],"tool":tool,
            "revision":key,"run_id":os.environ.get("GITHUB_RUN_ID"),"commit":os.environ.get("GITHUB_SHA"),
            "files":f.files(result),"quality_approval_added":False,"requires_visual_review":True})
        c.handoff(work,out,req,"awaiting_tool_output_review")
    except Exception as exc:
        c.handoff(work,out,req,"blocked",str(exc))
        raise

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("source",type=Path);p.add_argument("config",type=Path);p.add_argument("out",type=Path)
    p.add_argument("--payload",type=Path);p.add_argument("--blender",default="blender");p.add_argument("--godot")
    a=p.parse_args()
    execute(a.source.resolve(),a.config.resolve(),a.out.resolve(),a.payload.resolve() if a.payload else None,a.blender,a.godot)
