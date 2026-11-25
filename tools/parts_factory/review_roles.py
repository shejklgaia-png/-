"""Separate production and review contexts; no automatic aesthetic approval.
Review packets are deliberately separate from author scores and other reviewers.
Identity/context assertions are workflow evidence, not authenticated signatures.
"""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path
import quality_gates as q

FORMAT="SERA_PF_REVIEW_V6"
ART="art_director"
TECH="technical_auditor"
PRODUCERS={"concept":"designer","art":"designer","blueprint":"designer","analysis":"engineer",
"plan":"engineer","model":"modeler","geometry":"modeler","uv":"texture_artist",
"paint":"texture_artist","review":"production_coordinator","viewer":"production_coordinator",
"set":"assembly_artist"}
# Each critical deliverable has two independent vetoes.
CRITERIA={
 "concept":{ART:("identity","appeal","world_cohesion"),TECH:("mechanism","rig_target","reference_quality")},
 "analysis":{ART:("reference_fidelity","silhouette"),TECH:("calibration","correspondence","uncertainty")},
 "model":{ART:("appeal","silhouette","armor_language"),TECH:("mesh_integrity","reference_match","rig_clearance","provenance")},
 "art":{ART:("appeal","identity","silhouette","cohesion","readability"),TECH:("mechanism","feasibility","reference_consistency")},
 "blueprint":{ART:("design_fidelity","proportions","palette"),TECH:("projection_consistency","mechanism","interface")},
 "plan":{ART:("design_fidelity","shape_language","detail_hierarchy"),TECH:("structure","rig_interface","method_choice","reference_traceability")},
 "geometry":{ART:("appeal","silhouette","proportions","armor_language","detail_balance"),TECH:("reference_match","mesh_integrity","mechanism","rig_clearance","budget")},
 "uv":{TECH:("original_faces","overlap","shared_edges","texel_density","padding")},
 "paint":{ART:("panel_language","mechanical_detail","light_direction","readability"),TECH:("texture_binding","seams","resolution_consistency")},
 "review":{ART:("appeal","identity","cohesion","silhouette","texture"),TECH:("mechanism","uv_seams","rig","performance","asset_integrity")},
 "viewer":{TECH:("actual_glb","texture_display","touch_controls","offline_delivery")},
 "set":{ART:("appeal","cohesion","proportions","texture_consistency"),TECH:("part_identity","joint_clearance","weapon_clearance","performance","viewer")}
}
# Only allowlisted assets and numerical diagnostics are copied into reviewer packets.
# Self-review JSONs are omitted; art candidate filenames are relabeled.
RAW={
 "concept":("concept.json","design_brief.json"),
 "analysis":("analysis.json","correspondence.json"),
 "model":("model.glb","mesh_report.json","godot_import.json","interference.json","provenance.json","projections.json",*tuple(v+".png" for v in q.RENDER_VIEWS)),
 "art":(), "blueprint":("blueprint.png",),
 "plan":("design.json","structure_plan.json"),
 "geometry":("comparison.json","geometry_review.json",*tuple(v+".png" for v in q.RENDER_VIEWS)),
 "uv":("uv_model.glb","uv_layout.json","uv_metrics.json","face_geometry.json"),
 "paint":("model.glb","texture_512.png","texture_1024.png","texture_2048.png","surface_plan.json","embedded_review.json","bake_manifest.json",*tuple(v+".png" for v in q.RENDER_VIEWS)),
 "review":("review.json",*tuple(v+".png" for v in q.RENDER_VIEWS)),
 "viewer":("viewer.html",),
 "set":("assembly.glb","viewer.html",*tuple(v+".png" for v in q.RENDER_VIEWS))
}
UPSTREAM={
 "analysis":{"blueprint":("blueprint.png",)},
 "model":{"plan":("design.json","structure_plan.json"),"blueprint":("blueprint.png",),"analysis":("analysis.json",)},
 "art":{"concept":("concept.json","design_brief.json")},
 "blueprint":{"art":("selected.png",)},
 "plan":{"blueprint":("blueprint.png",),"analysis":("analysis.json","correspondence.json")},
 "geometry":{"blueprint":("blueprint.png",),"model":("model.glb","mesh_report.json","godot_import.json","interference.json","projections.json")},
 "uv":{"model":("model.glb",)},
 "paint":{"uv":("uv_metrics.json","uv_model.glb")},
 "review":{"blueprint":("blueprint.png",),"paint":("model.glb","texture_512.png","texture_1024.png","texture_2048.png"),"model":("mesh_report.json","godot_import.json","interference.json")},
 "viewer":{"paint":("model.glb",),"review":tuple(v+".png" for v in q.RENDER_VIEWS)}
}
def need(ok,msg):q.need(ok,msg)
def identity(x,label):
    need(isinstance(x,dict),label+" missing")
    for k in ("actor","context_id"):
        need(isinstance(x.get(k),str) and len(x[k].strip())>=3,label+" missing "+k)
    need(x.get("kind") in ("human","ai"),label+" kind must be human or ai")
    return x

def author(src,stage):
    a=q.load(src/"author.json")
    need(a.get("format")==FORMAT and a.get("stage")==stage and a.get("role")==PRODUCERS[stage],"wrong author role")
    return identity(a,"author")

def inventory(src):
    out={}
    for p in sorted(src.rglob("*")):
        need(not p.is_symlink(),"symlink in candidate")
        if p.is_file():
            rel=p.relative_to(src).as_posix()
            if not rel.startswith("independent_reviews/"):
                out[rel]=q.sha(p)
    return out

def public_files(src,stage):
    names=list(RAW[stage])
    if stage=="art":
        r=q.load(src/"art_review.json")
        # Sorted by byte hash, not producer ranking or chosen design.
        rows=sorted(r["candidates"],key=lambda x:q.sha(q.evidence(src,x["file"])))
        names.extend((row["file"],"candidate_%02d.png"%(i+1)) for i,row in enumerate(rows))
    if stage=="blueprint":
        r=q.load(src/"blueprint_review.json")
        names.extend((row["file"],"view_"+view+".png") for view,row in sorted(r["views"].items()))
    if stage=="analysis":
        # Include actual image evidence, not just analysis numbers.
        names.extend(p.relative_to(src).as_posix() for p in sorted(src.rglob("*.png")) if "supervision" not in p.relative_to(src).parts and "independent_reviews" not in p.relative_to(src).parts)
        need(any(str(x).endswith(".png") for x in names),"analysis images required")
    if stage=="geometry":
        r=q.load(src/"comparison.json")
        names.extend((row["overlay"],"overlay_"+view+".png") for view,row in sorted(r["views"].items()))
    if stage=="set":
        # Set review filenames are declared by existing assembly review.
        r=q.load(src/"assembly_review.json")
        names=["assembly.glb","viewer.html","set.json","art/selected.png"]+[(row["file"],"view_"+view+".png") for view,row in sorted(r["views"].items())]
    return [(x,x) if isinstance(x,str) else x for x in names]

def set_inputs(src):
    import factory as f
    from set_release import ROLES,stock_ref
    s=q.load(src/"set.json")
    need(set(s["parts"])==set(ROLES),"set roles missing")
    inputs={};authors=[]
    for role,slot in ROLES.items():
        item=s["parts"][role]
        expected=stock_ref(slot,item,s["set_art_sha256"])
        root=f.STOCK/slot/item["id"]/item["revision"]
        model=root/"paint"/"model.glb"
        need(q.sha(model)==expected,"part GLB changed")
        inputs["upstream/parts/"+role+".glb"]=(model,expected)
        job=q.load(root/"job.json")
        for st in job["stages"]:authors.append(identity(q.load(root/st/"author.json"),"part author"))
    return inputs,authors

def packet_data(src,stage,job_id,upstream,work=None):
    a=author(src,stage)
    private=inventory(src)
    items={}
    for original,dst in public_files(src,stage):
        p=q.evidence(src,original)
        need(not {"independent_reviews","supervision"}.intersection(p.relative_to(src.resolve()).parts),"review or draft files cannot substitute final evidence")
        label="candidate/"+dst
        need(label not in items,"duplicate packet path")
        items[label]=(p,q.sha(p))
    if work is not None:
        for st,names in UPSTREAM.get(stage,{}).items():
            rec=upstream[st]
            root=work/"objects"/rec["key"]
            for name in names:
                p=q.evidence(root,name)
                digest=q.sha(p);need(digest==rec["files"][name],"upstream evidence changed")
                items["upstream/"+st+"/"+name]=(p,digest)
    if stage=="set":items.update(set_inputs(src)[0])
    draft=src/"supervision"/"draft"
    if draft.is_dir():
        need(not (draft/"supervision").exists(),"nested draft forbidden")
        for original,dst in public_files(draft,stage):
            p=q.evidence(draft,original)
            need("independent_reviews" not in Path(original).parts and "supervision" not in Path(original).parts,"draft review files cannot be evidence")
            label="draft/"+dst
            need(label not in items,"duplicate draft packet path")
            items[label]=(p,q.sha(p))
    manifest={k:hashlib.sha256(view_payload(v[0],stage)).hexdigest() for k,v in sorted(items.items())}
    binding={"format":FORMAT,"job_id":job_id,"stage":stage,
        "candidate_sha256":q.canonical(private),
        "upstream":{k:v["key"] for k,v in upstream.items()},
        "evidence":manifest}
    return a,items,binding

def view_payload(p,stage):
    # Structure plan contains authored design rationale, not self-score; omit reviewer and scoring metadata.
    if p.name in ("structure_plan.json","geometry_review.json","review.json"):
        r=q.load(p)
        for k in ("reviewer","rubric","score","approval","blocking_issues","checks"):r.pop(k,None)
        return json.dumps(r,ensure_ascii=False,sort_keys=True,indent=2).encode()
    return p.read_bytes()

def make_packet(work,stage,src,out,role):
    import factory as f
    d=f.state(work);f.verify(work,d)
    idx=f.ORDER.index(stage)
    need(role in CRITERIA[stage] and all(k in d["stages"] for k in f.ORDER[:idx]),"wrong stage/role or missing upstream")
    up={k:d["stages"][k] for k in f.ORDER[:idx]}
    a,items,binding=packet_data(src,stage,d["id"],up,work)
    emit(out,stage,role,items,binding)

def emit(out,stage,role,items,binding):
    need(not out.exists(),"new review directory required")
    out.mkdir(parents=True)
    exported={}
    for label,(p,digest) in items.items():
        dest=out/label
        dest.parent.mkdir(parents=True,exist_ok=True)
        data=view_payload(p,stage);dest.write_bytes(data)
        exported[label]=q.sha(dest)
    request={"format":FORMAT,"role":role,"binding":binding,"packet_files":exported,
        "criteria":list(CRITERIA[stage][role]),
        "instructions":"Open evidence files, evaluate independently before seeing author or other scores. Give a concrete defect or justification for every criterion and cite evidence paths. Do not approve missing or uninspected evidence. If draft evidence is present, compare it to the final candidate: reject cosmetic-only changes or unresolved defects, and require a concrete improvement or documented deterministic rebuild. Record your real context ID; never fabricate independence."}
    (out/"request.json").write_text(json.dumps(request,ensure_ascii=False,indent=2),encoding="utf-8")
    template={"format":FORMAT,"role":role,"binding_sha256":q.canonical(binding),
        "reviewer":{"actor":"","context_id":"","kind":"ai"},"independent_context_attested":False,"packet_files":exported,
        "verdict":"pending","criteria":{k:{"score":None,"reason":"","evidence":[]} for k in CRITERIA[stage][role]},
        "blocking_issues":[],"revision_advice":"","selected_candidate_sha256":None}
    (out/"response_template.json").write_text(json.dumps(template,ensure_ascii=False,indent=2),encoding="utf-8")

def check(src,stage,job_id,upstream,work=None,allow_reject=False):
    if stage not in CRITERIA:return []
    a,items,binding=packet_data(src,stage,job_id,upstream,work)
    contexts={a["context_id"]}
    # Every producer context in upstream is excluded from review roles.
    if work:
        for st,rec in upstream.items():
            p=work/"objects"/rec["key"]/"author.json"
            contexts.add(identity(q.load(p),"upstream author")["context_id"])
    identities={(a["kind"],a["actor"].strip().casefold())}
    if work:
        for st,rec in upstream.items():
            i=identity(q.load(work/"objects"/rec["key"]/"author.json"),"upstream author")
            identities.add((i["kind"],i["actor"].strip().casefold()))
    if stage=="set":
        for i in set_inputs(src)[1]:
            contexts.add(i["context_id"]);identities.add((i["kind"],i["actor"].strip().casefold()))
    records=[]
    for role,keys in CRITERIA[stage].items():
        p=src/"independent_reviews"/(role+".json")
        r=q.load(p)
        need(r.get("format")==FORMAT and r.get("role")==role and r.get("binding_sha256")==q.canonical(binding),"stale review or wrong role")
        i=identity(r.get("reviewer"),role)
        need(i["kind"]=="ai","AI supervision required")
        need(i["context_id"] not in contexts,"review context overlaps a producer or another reviewer")
        actor=(i["kind"],i["actor"].strip().casefold())
        need(actor not in identities,"review actor must differ from author and other reviewer")
        contexts.add(i["context_id"]);identities.add(actor)
        need(r.get("independent_context_attested") is True,"independence attestation missing")
        need(r.get("packet_files")==binding["evidence"],"reviewed packet hash manifest mismatch")
        verdict=r.get("verdict");need(verdict in ("approve","reject","unverified"),"invalid verdict")
        q.rubric(r.get("criteria"),keys,role,minimum=4 if verdict=="approve" else 1)
        for k,row in r["criteria"].items():
            refs=row.get("evidence")
            need(isinstance(refs,list) and bool(refs) and set(refs)<=set(items),"missing or invalid evidence reference "+k)
        issues=r.get("blocking_issues")
        need(isinstance(issues,list) and all(isinstance(x,str) and len(x.strip())>=12 for x in issues),"invalid blocking issues")
        q.text(r.get("revision_advice"),role+" correction advice")
        if verdict=="approve":
            need(not issues,"blocking issues present")
        else:need(bool(issues),"reject/unverified must explain blockers")
        if stage=="art" and verdict=="approve":
            # Reviewer chooses an actual candidate by hash, independent of author's selection.
            candidate_hashes={digest for name,(_,digest) in items.items() if name.startswith("candidate/candidate_")}
            need(r.get("selected_candidate_sha256") in candidate_hashes,"reviewer must select an actual candidate")
            if not allow_reject:need(r["selected_candidate_sha256"]==q.sha(src/"selected.png"),"reviewer selects different concept; revise and re-review")
        records.append(r)
    if not allow_reject:
        need(all(r["verdict"]=="approve" for r in records),"independent review veto")
        if work:
            for path in (work/"review_vetoes").glob("*.json"):
                old=q.load(path)
                current=q.canonical({k:v for k,v in binding["evidence"].items() if not k.startswith("draft/")})
                if old.get("stage")==stage and old.get("upstream")==binding["upstream"] and old.get("candidate_evidence_sha256",old.get("evidence_sha256"))==current:
                    need(not any(x["verdict"]=="reject" for x in old["reviews"]),"rejected evidence unchanged; revise actual deliverable")
    return records

# V6.1: bind an independently reviewed draft to a rebuilt candidate.
# The draft is archived with its real reviews; final reviewers see before/after
# public evidence, not prior scores. Evidence is not authentication.
CYCLE="SERA_PF_SUPERVISION_V61"
PRIMARY={
 "concept":("concept.json","design_brief.json"),
 "art":("selected.png",),
 "blueprint":("blueprint.png",),
 "analysis":("analysis.json","correspondence.json"),
 "plan":("design.json","structure_plan.json"),
 "model":("model.glb",),
 "geometry":("comparison.json","geometry_review.json"),
 "uv":("uv_model.glb","uv_layout.json"),
 "paint":("model.glb","texture_1024.png","surface_plan.json"),
 "review":("review.json",),
 "viewer":("viewer.html",),
 "set":("assembly.glb","viewer.html")
}
def material_digest(src,name):
    p=q.evidence(src,name)
    if p.suffix==".json":
        obj=q.load(p)
        # Reviewer names, scores and timestamps alone are not reconstruction.
        def clean(v):
            if isinstance(v,dict):
                return {k:clean(x) for k,x in v.items() if k not in ("reviewer","rubric","score","timestamp","created_at","updated_at","iteration_notes","approval","checks")}
            if isinstance(v,list):return [clean(x) for x in v]
            return v
        return q.canonical(clean(obj))
    return q.sha(p)

def check_cycle(src,stage,job_id,upstream,work=None):
    need(stage in CRITERIA and stage in PRIMARY,"missing supervision policy")
    draft=src/"supervision"/"draft"
    need(draft.is_dir() and not draft.is_symlink() and not (draft/"supervision").exists(),"independently reviewed draft required")
    # Reject symlinks throughout both candidates before reading evidence.
    inventory(src)
    a,_,binding=packet_data(draft,stage,job_id,upstream,work)
    first=check(draft,stage,job_id,upstream,work,allow_reject=True)
    rec=q.load(src/"supervision"/"reconstruction.json")
    need(rec.get("format")==CYCLE and rec.get("stage")==stage and rec.get("draft_binding_sha256")==q.canonical(binding),"wrong draft binding")
    first_hashes={role:q.sha(draft/"independent_reviews"/(role+".json")) for role in CRITERIA[stage]}
    need(rec.get("draft_review_sha256")==first_hashes,"draft review binding mismatch")
    old={n:material_digest(draft,n) for n in PRIMARY[stage]}
    new={n:material_digest(src,n) for n in PRIMARY[stage]}
    changed=sorted(n for n in old if old[n]!=new[n])
    need(rec.get("changed_primary_files")==changed,"reconstruction change manifest mismatch")
    if stage=="model":
        p0=q.load(draft/"provenance.json");p1=q.load(src/"provenance.json")
        for candidate,p in ((draft,p0),(src,p1)):
            need(p.get("tool")=="Modeling Studio - authoring render" and re.fullmatch(r"[0-9a-f]{40}",p.get("commit","")) and type(p.get("run_id")) is int and p["run_id"]>0 and type(p.get("artifact_id")) is int and p["artifact_id"]>0 and p.get("glb_sha256")==q.sha(candidate/"model.glb"),"actual model build provenance required")
        need(p0["run_id"]!=p1["run_id"] and p0["artifact_id"]!=p1["artifact_id"],"separate model rebuild run required")
    if not changed:
        # A deterministic model build can legitimately reproduce the same GLB:
        # require a second real recorded build and no first-pass veto.
        need(stage=="model" and all(r["verdict"]=="approve" for r in first),"actual reconstruction required; scores or renamed files are insufficient")
        need(p0["glb_sha256"]==p1["glb_sha256"],"reproducible model hash mismatch")
    actions=rec.get("actions")
    need(isinstance(actions,dict) and set(actions)==set(CRITERIA[stage]),"address every supervisor")
    for role,review in zip(CRITERIA[stage],first):
        row=actions[role]
        need(isinstance(row,dict),"invalid reconstruction action")
        q.text(row.get("response"),"response to "+role)
        q.text(row.get("method"),"reconstruction method for "+role)
        issues=row.get("resolved_issues")
        need(isinstance(issues,dict) and set(issues)==set(review["blocking_issues"]),"resolve every recorded blocker")
        for value in issues.values():q.text(value,"blocker resolution")
        refs=row.get("evidence")
        need(isinstance(refs,list) and bool(refs) and len(refs)==len(set(refs)),"reconstruction evidence required")
        for n in refs:
            need(isinstance(n,str) and not n.startswith(("supervision/","independent_reviews/")),"reconstruction evidence must be final material")
            p=q.evidence(src,n)
            need(not {"supervision","independent_reviews"}.intersection(p.relative_to(src.resolve()).parts),"reconstruction evidence must refer to final files")
    # Fresh final review is bound to the rebuilt files and the archived draft.
    final=check(src,stage,job_id,upstream,work)
    final_author=author(src,stage)
    for producer,reviews in ((a,final),(final_author,first)):
        for review in reviews:
            i=review["reviewer"]
            need(i["context_id"]!=producer["context_id"] and i["actor"].strip().casefold()!=producer["actor"].strip().casefold(),"reviewer overlaps draft or rebuilt producer")
    return {"format":CYCLE,"draft_binding_sha256":q.canonical(binding),"reconstruction_sha256":q.sha(src/"supervision"/"reconstruction.json"),"final_review_sha256":{role:q.sha(src/"independent_reviews"/(role+".json")) for role in CRITERIA[stage]}}

def cycle_template(src,stage,job_id,upstream,work=None):
    draft=src/"supervision"/"draft"
    _,_,binding=packet_data(draft,stage,job_id,upstream,work)
    first=check(draft,stage,job_id,upstream,work,allow_reject=True)
    changed=sorted(n for n in PRIMARY[stage] if material_digest(draft,n)!=material_digest(src,n))
    obj={"format":CYCLE,"stage":stage,"draft_binding_sha256":q.canonical(binding),
        "draft_review_sha256":{role:q.sha(draft/"independent_reviews"/(role+".json")) for role in CRITERIA[stage]},
        "changed_primary_files":changed,
        "actions":{role:{"response":"","method":"","resolved_issues":{x:"" for x in r["blocking_issues"]},"evidence":[]} for role,r in zip(CRITERIA[stage],first)}}
    p=src/"supervision"/"reconstruction.json"
    need(not p.exists(),"refuse to overwrite reconstruction record")
    p.write_text(json.dumps(obj,ensure_ascii=False,indent=2),encoding="utf-8")
    print(p)

def record_veto(work,stage,src):
    import factory as f
    d=f.state(work);f.verify(work,d);idx=f.ORDER.index(stage)
    up={k:d["stages"][k] for k in f.ORDER[:idx]}
    records=check(src,stage,d["id"],up,work,allow_reject=True)
    need(any(r["verdict"]!="approve" or (stage=="art" and r.get("selected_candidate_sha256")!=q.sha(src/"selected.png")) for r in records),"no veto to record")
    # Record even unaccepted attempts; never overwrite accepted snapshots.
    _,_,binding=packet_data(src,stage,d["id"],up,work)
    obj={"stage":stage,"candidate_sha256":binding["candidate_sha256"],"evidence_sha256":q.canonical(binding["evidence"]),"candidate_evidence_sha256":q.canonical({k:v for k,v in binding["evidence"].items() if not k.startswith("draft/")}),"upstream":binding["upstream"],"reviews":records}
    path=work/"review_vetoes"/(q.canonical(obj)+".json")
    if not path.exists():f.write(path,obj)
    print(path)

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest="cmd",required=True)
    a=s.add_parser("packet");a.add_argument("work",type=Path);a.add_argument("stage",choices=tuple(k for k in CRITERIA if k!="set"));a.add_argument("source",type=Path);a.add_argument("out",type=Path);a.add_argument("--role",choices=(ART,TECH),required=True)
    a=s.add_parser("veto");a.add_argument("work",type=Path);a.add_argument("stage",choices=tuple(k for k in CRITERIA if k!="set"));a.add_argument("source",type=Path)
    a=s.add_parser("set-packet");a.add_argument("source",type=Path);a.add_argument("out",type=Path);a.add_argument("--role",choices=(ART,TECH),required=True)
    a=s.add_parser("cycle-template");a.add_argument("work",type=Path);a.add_argument("stage",choices=tuple(k for k in CRITERIA if k!="set"));a.add_argument("source",type=Path)
    a=s.add_parser("set-cycle-template");a.add_argument("source",type=Path)
    a=p.parse_args()
    if a.cmd=="cycle-template":
        import factory as f
        work=a.work.resolve();d=f.state(work);f.verify(work,d)
        idx=f.ORDER.index(a.stage);up={k:d["stages"][k] for k in f.ORDER[:idx]}
        cycle_template(a.source.resolve(),a.stage,d["id"],up,work)
    elif a.cmd=="set-cycle-template":
        src=a.source.resolve();cycle_template(src,"set",q.load(src/"set.json")["id"],{})
    elif a.cmd=="packet":make_packet(a.work.resolve(),a.stage,a.source.resolve(),a.out.resolve(),a.role)
    elif a.cmd=="veto":record_veto(a.work.resolve(),a.stage,a.source.resolve())
    else:
        src=a.source.resolve();_,items,binding=packet_data(src,"set",q.load(src/"set.json")["id"],{})
        emit(a.out.resolve(),"set",a.role,items,binding)
