"""Equipment set release gate. Stock each independently approved part first."""
import argparse
import json
import re
import shutil
import tempfile
from pathlib import Path
import factory as f
import quality_gates as q
import review_roles as rr

ROLES={"head":"head","body":"body","arms":"arms","legs":"legs","weapon_r":"weapons","weapon_l":"weapons"}

def stock_ref(slot, item, art_hash):
    pid,rev=item["id"],item["revision"]
    f.require(re.fullmatch(r"[A-Z][A-Z0-9_-]{1,39}",pid) and re.fullmatch(r"[0-9a-f]{64}",rev),"invalid stock reference")
    folder=f.STOCK/slot/pid/rev
    d=f.read(folder/"job.json"); release=f.read(folder/"release.json")
    f.require(d["format"]=="SERA_PARTS_FACTORY_V6" and d["id"]==pid and d["slot"]==slot,"wrong part identity or old schema")
    f.require(release["format"]=="SERA_PARTS_STOCK_V6" and release["revision"]==rev,"wrong stock revision")
    previous="ROOT"
    for name in f.ORDER:
        row=d["stages"][name]
        f.require(row["upstream"]==previous and f.signature({k:v for k,v in row.items() if k!="key"})==row["key"],"invalid stage chain")
        f.require(f.files(folder/name)==row["files"],"changed stock files: "+pid+"/"+name)
        previous=row["key"]
    f.require(previous==rev and set(d["stages"])==set(f.ORDER),"incomplete stock")
    concept=f.read(folder/"concept"/"concept.json")
    f.require(concept.get("set_art_sha256")==art_hash,"different set art direction")
    return d["stages"]["paint"]["files"]["model.glb"]

def release(src, deliver_to):
    s=f.read(src/"set.json")
    f.require(s.get("format")=="SERA_PF_SET_V2" and re.fullmatch(r"[A-Z][A-Z0-9_-]{1,39}",s["id"]),"invalid set")
    f.require(q.art(src/"art")==s["set_art_sha256"],"set art mismatch")
    f.require(set(s["parts"])==set(ROLES),"all six independent roles required")
    f.require(len({i["id"] for i in s["parts"].values()})==len(ROLES),"part IDs must be distinct")
    hashes={role:stock_ref(slot,s["parts"][role],s["set_art_sha256"]) for role,slot in ROLES.items()}
    f.glb(src/"assembly.glb")
    r=f.read(src/"assembly_review.json")
    f.require(r.get("part_glb_sha256")==hashes and r.get("assembly_sha256")==f.digest(src/"assembly.glb"),"assembly input mismatch")
    q.bound_images(src,r.get("views"),q.RENDER_VIEWS)
    q.rubric(r.get("rubric"),("appeal","cohesion","proportions","joint_clearance","weapon_clearance","texture_consistency","performance"),"assembly")
    q.text(r.get("notes"),"assembly evaluation")
    f.require(r.get("blocking_issues")==[] and bool(r.get("reviewer")),"assembly review incomplete")
    v=f.read(src/"viewer_review.json")
    f.require(v.get("assembly_sha256")==r["assembly_sha256"] and v.get("viewer_sha256")==f.digest(src/"viewer.html"),"assembly viewer mismatch")
    f.require(v.get("texture_display")==v.get("touch_controls")=="accepted" and bool(v.get("reviewer")),"assembly viewer pending")
    rr.check(src,"set",s["id"],{})
    manifest=f.files(src); rev=f.signature(manifest)
    root=f.STOCK/"sets"/s["id"]; root.mkdir(parents=True,exist_ok=True)
    dest=root/rev
    f.require(not deliver_to.exists(),"refuse overwrite")
    if not dest.exists():
        with tempfile.TemporaryDirectory(dir=root) as tmp:
            p=Path(tmp)/"release";shutil.copytree(src,p)
            f.require(f.files(p)==manifest,"assembly changed during copy")
            p.rename(dest)
    f.require(f.files(dest)==manifest,"stock set changed")
    deliver_to.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(dest/"viewer.html",deliver_to)
    print(json.dumps({"set":s["id"],"revision":rev,"stock":str(dest),"viewer":str(deliver_to)},ensure_ascii=False))

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("source",type=Path);p.add_argument("output",type=Path)
    a=p.parse_args();release(a.source.resolve(),a.output.resolve())
