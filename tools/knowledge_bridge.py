"""Production knowledge snapshot. Read public Git objects as data, never execute them."""
import functools
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unicodedata

REMOTE = "https://github.com/shejklgaia-png/SERA_knowledge.git"
PREFIXES = ("knowledge/", "experience/", "methodology/", "evaluation/", "synthesis/")
TERMS = {
    "modeling": "modeling mesh topology intersection bevel normal 造形 メッシュ 干渉 法線",
    "motion": "motion locomotion foot-lock IK 接地 歩行 旋回 補間",
    "texture": "texture UV padding compression surface テクスチャ 塗装 パネルライン",
    "factory": "modeling texture methodology evaluation 設計 造形 評価 失敗",
}

def norm(value):
    return unicodedata.normalize("NFKC", str(value)).casefold()

def sha(data):
    return hashlib.sha256(data).hexdigest()

def git(args, cwd=None, timeout=20):
    env=dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_CONFIG_NOSYSTEM="1",
             GIT_CONFIG_GLOBAL=os.devnull)
    return subprocess.check_output(["git", "-c", "credential.helper=", *args],
                                   cwd=cwd, env=env, stderr=subprocess.PIPE, timeout=timeout)

@functools.lru_cache(maxsize=1)
def snapshot():
    if os.environ.get("SERA_KNOWLEDGE_OFFLINE") == "1":
        raise RuntimeError("offline explicitly selected")
    # No user query or design file leaves the production environment.
    with tempfile.TemporaryDirectory(prefix="sera-knowledge-") as tmp:
        git(["clone", "--quiet", "--depth=1", "--no-tags", "--single-branch",
             "--branch", "main", "--no-checkout", REMOTE, tmp], timeout=30)
        commit=git(["rev-parse", "HEAD"], tmp).decode().strip()
        rules={}
        for path in ("README.md","AGENTS.md"):
            raw=git(["show",commit+":"+path],tmp)
            rules[path]={"sha256":sha(raw),"body":raw.decode("utf-8-sig")}
        paths=git(["ls-tree","-r","--name-only","-z",commit],tmp).decode().split("\0")
        rows=[]; warnings=[]
        for path in paths:
            if not path.startswith(PREFIXES) or not path.endswith(".md") or Path(path).name.lower()=="readme.md":
                continue
            try:
                raw=git(["show",commit+":"+path],tmp)
                if len(raw)>512_000:
                    warnings.append("oversize skipped: "+path);continue
                text=raw.decode("utf-8-sig")
                meta={}
                if text.startswith("---\n") and "\n---\n" in text[4:]:
                    header,body=text[4:].split("\n---\n",1)
                    for line in header.splitlines():
                        k,sep,v=line.partition(":")
                        if sep:meta[k.strip()]=v.strip().strip("\"'")
                else:body=text
                title=next((x[2:].strip() for x in body.splitlines() if x.startswith("# ")),Path(path).stem)
                rows.append({"id":meta.get("id",Path(path).stem),"path":path,
                             "title":title,"status":meta.get("status","unknown"),
                             "category":meta.get("category",""),"tags":meta.get("tags",""),
                             "sha256":sha(raw),"body":body,
                             "url":"https://github.com/shejklgaia-png/SERA_knowledge/blob/"+commit+"/"+path})
            except (OSError,UnicodeError,subprocess.SubprocessError) as exc:
                warnings.append(path+": "+type(exc).__name__)
        ids=[row["id"] for row in rows]
        if len(ids)!=len(set(ids)):warnings.append("duplicate IDs; distinguish by path and SHA")
        return commit,rules,rows,warnings

def ranking_profile(kind):
    path=os.environ.get("SERA_KNOWLEDGE_PROFILE")
    if not path:return {}, "not_configured"
    try:
        p=Path(path)
        if p.stat().st_size>2_000_000:raise ValueError("profile too large")
        d=json.loads(p.read_text(encoding="utf-8"))
        scope=os.environ.get("SERA_KNOWLEDGE_SCOPE")
        protocol=os.environ.get("SERA_KNOWLEDGE_PROTOCOL")
        if not scope or not protocol or d.get("format")!="SERA_RANKING_PROFILE_V5" or (d.get("kind"),d.get("scope"),d.get("protocol"))!=(kind,scope,protocol):
            raise ValueError("scope mismatch")
        entries=d["entries"]
        if not isinstance(entries,dict):raise ValueError("invalid entries")
        for item in entries.values():
            if not isinstance(item,dict) or type(item.get("factor")) not in (int,float) or not .85<=item["factor"]<=1.15:
                raise ValueError("invalid factor")
        return entries,"local_advisory"
    except (OSError,ValueError,KeyError,TypeError,AttributeError):
        return {},"invalid_or_mismatched"

def comparison_binding(kind):
    path=os.environ.get("SERA_KNOWLEDGE_COMPARISON_PLAN")
    arm=os.environ.get("SERA_KNOWLEDGE_COMPARISON_ARM")
    run=os.environ.get("SERA_KNOWLEDGE_RUN_KEY")
    if not any((path,arm,run)):return {"status":"not_configured"}
    try:
        if not path or arm not in ("baseline","candidate") or not run or not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,127}",run):
            raise ValueError("missing plan, arm or run key")
        p=Path(path)
        if p.stat().st_size>256000:raise ValueError("plan too large")
        raw=p.read_bytes();d=json.loads(raw)
        if d.get("format")!="SERA_COMPARISON_PLAN_V6" or d.get("kind")!=kind:
            raise ValueError("plan kind mismatch")
        return dict(status="bound",plan_sha256=sha(raw),arm=arm,run_key=run,
                    bound_at=datetime.now(timezone.utc).isoformat(),
                    production_commit=os.environ.get("GITHUB_SHA"),
                    workflow_run=os.environ.get("GITHUB_RUN_ID"))
    except (OSError,ValueError,TypeError,AttributeError):
        return {"status":"invalid_binding"}

def retrieve(kind, query="", limit=8):
    result={"format":"SERA_KNOWLEDGE_SNAPSHOT_V3","kind":kind,"query":str(query)[:1000],
            "status":"unavailable","matches":[],"approval_added":False,
            "requires_author_review":True,"comparison":comparison_binding(kind)}
    try:
        commit,rules,rows,warnings=snapshot()
        terms=set(norm(TERMS[kind]).split()); specific=set(norm(query).split())
        def rank(row):
            fields=((row["title"],6),(row["tags"],4),(row["category"],3),(row["body"],1))
            return sum(w*(sum(t in norm(v) for t in terms)+3*sum(t in norm(v) for t in specific)) for v,w in fields)
        entries,profile_status=ranking_profile(kind)
        def adjust(row):
            base=rank(row)
            item=entries.get(row["id"],{})
            factor=item.get("factor",1) if item.get("body_sha256")==sha("\n".join(row["body"].splitlines()).encode()) else 1
            return base*factor,base,factor,row
        ranked=sorted((adjust(r) for r in rows),key=lambda x:(x[0],x[3]["path"]),reverse=True)
        hits=[dict(row,score=n,base_score=base,ranking_factor=factor) for n,base,factor,row in ranked if n>0][:limit]
        failure_warnings=[dict(row,score=base) for _,base,_,row in ranked if base>0 and row["path"].startswith("experience/failure/")][:limit]
        result.update(ranking_profile_status=profile_status,failure_warnings=failure_warnings,
                      failure_warning_status="advisory_author_review_required")
        result.update(commit=commit,rules=rules,matches=hits,scanned=len(rows),warnings=warnings,
                      status="partial" if warnings else ("retrieved" if hits else "no_match"))
    except (OSError,UnicodeError,RuntimeError,subprocess.SubprocessError) as exc:
        result["reason"]=type(exc).__name__+": public knowledge snapshot not obtained"
    return result

def write(path, value):
    with Path(path).open("x",encoding="utf-8") as f:
        json.dump(value,f,ensure_ascii=False,indent=2);f.write("\n")

def preflight(kind, query, out):
    packet=retrieve(kind,query)
    write(Path(out)/"knowledge_snapshot.json",packet)
    print("SERA knowledge:",packet["status"],packet.get("commit",""),flush=True)
    for row in packet.get("failure_warnings",[]):
        print("SERA failure advisory:",row["id"],row["title"],flush=True)
    return packet

def receipt(out, filenames, snapshot_file="knowledge_snapshot.json"):
    out=Path(out)
    evidence={}
    for name in filenames:
        p=out/name
        if p.is_file():
            evidence[name]=sha(p.read_bytes())
    write(out/"knowledge_evidence.json",{
        "format":"SERA_KNOWLEDGE_EVIDENCE_V3",
        "snapshot_sha256":sha((out/snapshot_file).read_bytes()),
        "evidence":evidence,"status":"candidate",
        "approval_added":False,"requires_visual_and_evidence_review":True})
