"""PARTS FACTORY V1: resumable, non-destructive production coordinator."""
import argparse
import hashlib
import json
import re
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STOCK = ROOT / "parts_stock"
STAGES = {
    "concept": ("concept.json",),
    "blueprint": ("blueprint.png", "design.json"),
    "model": ("model.blend", "model.glb", "mesh_report.json", "complete.json", "review.json", "design.json"),
    "uv": ("uv.json", "uv_model.glb"),
    "paint": ("texture_512.png", "texture_1024.png", "texture_2048.png", "model.glb", "paint.json"),
    "review": ("review.json", "front.png", "front_3q.png", "right.png", "back_3q.png", "back.png", "left.png", "top.png", "bottom.png"),
    "viewer": ("viewer.html", "viewer_review.json"),
}
SLOTS = ("head", "body", "arms", "legs", "weapons")
ORDER = list(STAGES)

def require(ok, msg):
    if not ok:
        raise ValueError(msg)

def digest(p):
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def read(p):
    return json.loads(p.read_text(encoding="utf-8"))

def write(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=p.parent, delete=False) as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    Path(f.name).replace(p)

def signature(data):
    return hashlib.sha256(json.dumps(data, sort_keys=True, separators=(",", ":")).encode()).hexdigest()

def files(folder):
    result = {}
    for p in sorted(folder.rglob("*")):
        require(not p.is_symlink(), "symlink forbidden: " + str(p))
        if p.is_file():
            require(p.stat().st_size > 0, "empty file: " + str(p))
            result[p.relative_to(folder).as_posix()] = digest(p)
    return result

def state(work):
    d = read(work / "job.json")
    require(d["format"] == "SERA_PARTS_FACTORY_V1", "invalid format")
    require(d["slot"] in SLOTS and re.fullmatch(r"[A-Z][A-Z0-9_-]{1,39}", d["id"]), "invalid job identity")
    return d

def verify(work, d):
    previous = "ROOT"
    valid = []
    for name in ORDER:
        item = d["stages"].get(name)
        if not item:
            break
        folder = work / "objects" / item["key"]
        require(re.fullmatch(r"[0-9a-f]{64}", item["key"]), "invalid cache key")
        require(item["upstream"] == previous, "stale upstream: " + name)
        require(files(folder) == item["files"], "changed or missing files: " + name)
        require(signature({k:v for k,v in item.items() if k != "key"}) == item["key"], "record mismatch")
        previous = item["key"]
        valid.append(name)
    require(len(valid) == len(d["stages"]), "stage gap")
    return valid, previous

def png_size(p):
    with p.open("rb") as f:
        data = f.read(24)
    require(len(data) == 24 and data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR", "not PNG: " + str(p))
    return tuple(int.from_bytes(data[i:i+4], "big") for i in (16,20))

def glb(p):
    with p.open("rb") as f:
        head = f.read(12)
        require(head[:8] == b"glTF\x02\x00\x00\x00" and int.from_bytes(head[8:12],"little") == p.stat().st_size, "bad GLB: " + str(p))
        chunk = f.read(8)
        n = int.from_bytes(chunk[:4],"little")
        require(chunk[4:] == b"JSON" and 0 < n <= min(64*1024*1024, p.stat().st_size-20), "bad GLB JSON")
        g = json.loads(f.read(n))
    require(bool(g.get("meshes")), "empty GLB")
    return g

def check_stage(name, src, d):
    for filename in STAGES[name]:
        require((src / filename).is_file(), "missing " + filename)
    if name == "concept":
        obj = read(src / "concept.json")
        require(obj.get("id") == d["id"] and obj.get("slot") == d["slot"], "concept identity mismatch")
        for k in ("name","lore","mechanism","references","rig_target","proposed_stats"):
            require(bool(obj.get(k)), "missing concept field " + k)
    if name == "blueprint":
        png_size(src / "blueprint.png")
        require(read(src / "design.json").get("format") == "SERA_MODELING_STUDIO_V1", "bad modeling design")
    if name == "model":
        require(digest(src / "design.json") == d["stages"]["blueprint"]["files"]["design.json"], "model design mismatch")
        glb(src / "model.glb")
        require(isinstance(read(src / "mesh_report.json"),list) and bool(read(src / "mesh_report.json")), "empty mesh report")
        require(bool(read(src / "complete.json").get("views")), "no completion views")
        read(src / "review.json")
    if name == "uv":
        u = read(src / "uv.json")
        require(u.get("source_glb_sha256") == d["stages"]["model"]["files"]["model.glb"], "UV source mismatch")
        require(u.get("method") == "AI_MANUAL_FACE", "manual face route required")
        glb(src / "uv_model.glb")
    if name == "paint":
        g = glb(src / "model.glb")
        require(any(m.get("pbrMetallicRoughness",{}).get("baseColorTexture") for m in g.get("materials",[])), "painted GLB has no base-color texture")
        require(bool(g.get("images")) and all("bufferView" in i for i in g["images"]), "GLB images must be embedded")
        for size in (512,1024,2048):
            require(png_size(src / f"texture_{size}.png") == (size,size), "wrong texture resolution")
        p = read(src / "paint.json")
        require(p.get("source_uv_glb_sha256") == d["stages"]["uv"]["files"]["uv_model.glb"], "paint source mismatch")
        require(p.get("painted_glb_sha256") == digest(src / "model.glb"), "paint GLB mismatch")
    if name == "review":
        r = read(src / "review.json")
        require(r.get("painted_glb_sha256") == d["stages"]["paint"]["files"]["model.glb"], "review is not for painted GLB")
        for k in ("silhouette","mechanism","uv_seams","texture","rig","performance"):
            require(r.get("checks",{}).get(k) == "accepted", "review pending: " + k)
        require(bool(r.get("reviewer")) and bool(r.get("notes")), "review evidence required")
        for f in STAGES[name][1:]:
            png_size(src / f)
    if name == "viewer":
        v = read(src / "viewer_review.json")
        require(v.get("painted_glb_sha256") == d["stages"]["paint"]["files"]["model.glb"], "viewer model mismatch")
        require(v.get("viewer_sha256") == digest(src / "viewer.html"), "viewer hash mismatch")
        require(v.get("texture_display") == "accepted" and v.get("touch_controls") == "accepted" and bool(v.get("reviewer")), "viewer review pending")

def accept(work, name, src, producer):
    d = state(work)
    verify(work,d)
    idx = ORDER.index(name)
    require(all(x in d["stages"] for x in ORDER[:idx]), "upstream stages missing")
    require(src.is_dir() and not src.is_symlink(), "source directory required")
    upstream = d["stages"][ORDER[idx-1]]["key"] if idx else "ROOT"
    check_stage(name,src,d)
    record = {"stage":name,"upstream":upstream,"producer":producer,"files":files(src)}
    key = signature(record)
    record["key"] = key
    dest = work / "objects" / key
    if dest.exists():
        require(files(dest) == record["files"], "cache corrupted")
    else:
        dest.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=dest.parent) as tmp:
            copied = Path(tmp) / "data"
            shutil.copytree(src,copied)
            require(files(copied) == record["files"], "source changed during copy")
            copied.rename(dest)
    if d["stages"].get(name,{}).get("key") == key:
        print("CACHE HIT", name, key)
        return
    d["stages"] = {k:v for k,v in d["stages"].items() if ORDER.index(k)<idx}
    d["stages"][name] = record
    write(work / "job.json", d)
    print("ACCEPTED", name, key, "downstream reset")

def stock(work):
    d = state(work)
    valid,key = verify(work,d)
    require(valid == ORDER, "not all stages accepted")
    root = STOCK / d["slot"] / d["id"]
    dest = root / key
    root.mkdir(parents=True,exist_ok=True)
    if dest.exists():
        require(read(dest/"job.json")==d, "stock record differs")
        for name,item in d["stages"].items():
            require(files(dest/name)==item["files"], "stock corrupted: "+name)
        print("ALREADY STOCKED",dest)
        return
    with tempfile.TemporaryDirectory(dir=root) as tmp:
        out = Path(tmp)/"release"
        out.mkdir()
        for name,item in d["stages"].items():
            shutil.copytree(work/"objects"/item["key"],out/name)
            require(files(out/name)==item["files"],"stock copy mismatch")
        write(out/"job.json",d)
        write(out/"release.json",{"id":d["id"],"slot":d["slot"],"revision":key,"state":"stocked_not_in_game","format":"SERA_PARTS_STOCK_V1"})
        out.rename(dest)
    print("STOCKED",dest)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd",required=True)
    a = sub.add_parser("init"); a.add_argument("work",type=Path); a.add_argument("id"); a.add_argument("slot",choices=SLOTS)
    a = sub.add_parser("accept"); a.add_argument("work",type=Path); a.add_argument("stage",choices=ORDER); a.add_argument("source",type=Path); a.add_argument("--producer",required=True,help="tool version + source commit/run or AI review provenance")
    for cmd in ("status","stock","handoff"):
        a = sub.add_parser(cmd); a.add_argument("work",type=Path)
    args=p.parse_args()
    work=args.work.resolve()
    if args.cmd=="init":
        require(re.fullmatch(r"[A-Z][A-Z0-9_-]{1,39}",args.id),"invalid ID")
        work.mkdir(parents=True,exist_ok=True)
        require(not (work/"job.json").exists(),"job already exists")
        write(work/"job.json",{"format":"SERA_PARTS_FACTORY_V1","id":args.id,"slot":args.slot,"stages":{}})
    elif args.cmd=="accept":
        accept(work,args.stage,args.source.resolve(),args.producer)
    elif args.cmd=="stock":
        stock(work)
    else:
        d=state(work); valid,key=verify(work,d)
        next_stage=ORDER[len(valid)] if len(valid)<len(ORDER) else "stock"
        result={"id":d["id"],"accepted":valid,"next":next_stage,"revision":key}
        if args.cmd=="handoff" and valid:
            last=d["stages"][valid[-1]]
            result.update({"input_dir":str(work/"objects"/last["key"]),"input_hashes":last["files"],"producer":last["producer"]})
            if next_stage=="model":
                result["route"]=".github/workflows/modeling_studio_render.yml (design input under tools/modeling_studio; no CRATE iteration)"
            elif next_stage=="uv":
                result["route"]="Texture Studio AI manual face route; preserve original quad orientation"
        print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=="__main__":
    main()
