"""SERA design knowledge: immutable revisions, scoped retrieval, evidence and learning.
Knowledge is guidance, not auto-generated geometry or game approval.
"""
import argparse
import json
import re
from pathlib import Path
import quality_gates as q

ROOT=Path(__file__).resolve().parent/"design_library"
SLOTS=("head","body","arms","legs","weapons")
CATEGORIES=("armor","joint","mechanism","sensor","propulsion","paint","interface","failure","process")
STATES=("guideline","reference","technical_evidence","failure","candidate")
ID=r"[A-Z][A-Z0-9_-]{2,63}"

def validate(e):
    q.need(re.fullmatch(ID,e["id"]) and type(e["revision"]) is int and e["revision"]>=1,"invalid knowledge identity")
    q.need(e["category"] in CATEGORIES and e["state"] in STATES,"invalid knowledge class")
    q.need(isinstance(e["slots"],list) and bool(e["slots"]) and set(e["slots"])<=set(SLOTS),"invalid slot scope")
    q.need(type(e["mandatory"]) is bool and (not e["mandatory"] or e["state"] in ("guideline","failure")),"only rules/failures can be mandatory")
    for k in ("title","intent","application","limitations","review"):
        q.need(isinstance(e[k],str) and e[k].strip(),"missing field "+k)
    for k in ("tags","checks","avoid","sources"):
        q.need(isinstance(e[k],list) and e[k] and all(isinstance(x,str) and x.strip() for x in e[k]),"missing list "+k)
    q.need(e["state"]!="candidate" or not e["mandatory"],"candidate not enforceable")
    return e

def key(e):
    return e["id"]+"@"+str(e["revision"])

def catalog(root=ROOT):
    rows=[]
    for path in sorted(root.glob("*.json")):
        data=q.load(path)
        q.need(data.get("format")=="SERA_DESIGN_LIBRARY_V5","invalid catalog "+str(path))
        rows.extend(validate(e) for e in data["entries"])
    by={}
    for e in rows:
        k=key(e);q.need(k not in by,"duplicate knowledge revision "+k);by[k]=e
    q.need(bool(by),"empty design library")
    latest={}
    for e in rows:
        if e["id"] not in latest or latest[e["id"]]["revision"]<e["revision"]:latest[e["id"]]=e
    return by,latest

def applicable(e,slot):
    return slot in e["slots"] and e["state"]!="candidate"

def rank(e,terms):
    text=" ".join([e["title"],e["category"],e["intent"],*e["tags"]]).casefold()
    return sum(1 for term in terms if term in text)

def brief(slot,query,limit=8,root=ROOT):
    _,latest=catalog(root)
    terms=[x.casefold() for x in re.split(r"[\s,、/]+",query) if x]
    rows=[e for e in latest.values() if applicable(e,slot)]
    mandatory=sorted((e for e in rows if e["mandatory"]),key=key)
    optional=sorted((e for e in rows if not e["mandatory"]),key=lambda e:(-rank(e,terms),key(e)))
    optional=[e for e in optional if not terms or rank(e,terms)>0][:limit]
    # With no keyword match, return general applicable reference examples.
    if not optional:
        optional=sorted((e for e in rows if not e["mandatory"]),key=key)[:min(limit,3)]
    return {"format":"SERA_PF_DESIGN_BRIEF_V5","slot":slot,"query":query,
            "entries":[{"key":key(e),"sha256":q.canonical(e),"entry":e} for e in mandatory+optional]}

def check_brief(src,slot):
    b=q.load(src/"design_brief.json");q.need(b["format"]=="SERA_PF_DESIGN_BRIEF_V5" and b["slot"]==slot,"brief slot mismatch")
    by,latest=catalog();seen=set()
    for row in b["entries"]:
        e=validate(row["entry"]);k=key(e)
        q.need(k==row["key"] and k not in seen and k in by and q.canonical(e)==row["sha256"]==q.canonical(by[k]),"changed or unknown library revision")
        q.need(applicable(e,slot) and key(latest[e["id"]])==k,"not current/applicable knowledge")
        seen.add(k)
    required={key(e) for e in latest.values() if applicable(e,slot) and e["mandatory"]}
    q.need(required<=seen,"mandatory knowledge omitted: "+str(sorted(required-seen)))
    q.need(bool(seen-required),"at least one applicable design reference required")
    return b

def check_plan(src,concept_record):
    b=q.load(src/"design_brief_snapshot.json");p=q.load(src/"structure_plan.json")
    q.need(q.sha(src/"design_brief_snapshot.json")==concept_record["files"]["design_brief.json"],"design library snapshot mismatch")
    refs={r["key"]:r["entry"] for r in b["entries"]}
    dispositions=p.get("knowledge_disposition",{})
    q.need(set(dispositions)==set(refs),"every selected knowledge item needs a disposition")
    for k,r in dispositions.items():
        q.need(r["decision"] in ("applied","not_applicable","avoid"),"invalid knowledge disposition")
        q.text(r.get("reason"),"knowledge disposition "+k)
        if refs[k]["state"]=="failure":q.need(r["decision"] in ("avoid","not_applicable"),"failure not reusable")
        if refs[k]["mandatory"] and refs[k]["state"]=="guideline":q.need(r["decision"]=="applied","mandatory guideline omitted")
    used=set()
    for c in p["components"]:
        ks=c.get("knowledge_refs",[])
        q.need(isinstance(ks,list) and len(set(ks))==len(ks),"invalid component refs")
        for k in ks:
            q.need(k in refs and dispositions[k]["decision"]=="applied" and refs[k]["state"]!="failure","invalid applied reference "+k)
            used.add(k)
        q.text(c.get("original_design_reason"),"component original design/adaptation")
    q.need(any(not refs[k]["mandatory"] for k in used),"at least one applied reference mapped to actual component")

def candidate(work,stage,entry_id,category,source,out,reason):
    import factory as f
    d=f.state(work);f.verify(work,d)
    q.need(re.fullmatch(ID,entry_id) and category in CATEGORIES,"invalid candidate identity")
    q.text(reason,"specific reusable lesson")
    if stage=="success":
        valid,rev=f.verify(work,d);q.need(valid==f.ORDER,"complete approved job required")
        root=f.STOCK/d["slot"]/d["id"]/rev
        q.need(f.read(root/"job.json")==d and f.read(root/"release.json")["revision"]==rev,"stock not complete")
        for name,row in d["stages"].items():q.need(f.files(root/name)==row["files"],"stock corruption")
        record={"type":"approved_part_stock","part":d["id"],"revision":rev,"review_sha256":d["stages"]["review"]["files"]["review.json"]}
    else:
        q.need(stage=="failure" and source is not None,"reject record required")
        src=source.resolve();q.need(src.parent==(work/"rejections").resolve() and src.suffix==".json","job rejection evidence required")
        r=q.load(src);record={"type":"rejected_attempt","part":d["id"],"rejection_sha256":q.sha(src),"record":r}
    q.need(not out.exists(),"refuse overwrite")
    f.write(out,{"format":"SERA_PF_KNOWLEDGE_CANDIDATE_V5","id":entry_id,"category":category,
        "slot":d["slot"],"state":"candidate","lesson":reason,"evidence":record,
        "next":"Curate a new versioned library entry with review, scope, limits and sources. No automatic promotion."})

def main():
    import factory as f
    p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest="cmd",required=True)
    a=sub.add_parser("brief");a.add_argument("slot",choices=SLOTS);a.add_argument("query");a.add_argument("out",type=Path);a.add_argument("--limit",type=int,default=8)
    a=sub.add_parser("learn");a.add_argument("work",type=Path);a.add_argument("kind",choices=("success","failure"));a.add_argument("id");a.add_argument("category",choices=CATEGORIES);a.add_argument("out",type=Path);a.add_argument("--source",type=Path);a.add_argument("--reason",required=True)
    a=sub.add_parser("list");a.add_argument("--slot",choices=SLOTS)
    args=p.parse_args()
    if args.cmd=="brief":
        q.need(1<=args.limit<=50 and not args.out.exists(),"invalid limit or existing output")
        f.write(args.out,brief(args.slot,args.query,args.limit))
    elif args.cmd=="learn":
        candidate(args.work.resolve(),args.kind,args.id,args.category,args.source,args.out,args.reason)
    else:
        _,latest=catalog();print(json.dumps([{"key":key(e),"title":e["title"],"state":e["state"],"category":e["category"]} for e in latest.values() if not args.slot or applicable(e,args.slot)],ensure_ascii=False,indent=2))

if __name__=="__main__":main()
