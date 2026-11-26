"""Import original PNG concept evidence, never accept or score it.
Only a dedicated production workspace may receive a bundle. No network,
archive code execution, automatic visual approval, or game registration.
"""
import argparse
import hashlib
import io
import json
import re
import stat
import tempfile
import zipfile
from pathlib import Path
from PIL import Image, ImageChops
import factory as f

FORMAT = "SERA_PF_ART_TRANSFER_V1"
MAX_ARCHIVE = 24 * 1024 * 1024
MAX_TOTAL = 72 * 1024 * 1024
MAX_PNG = 16 * 1024 * 1024
MAX_PIXELS = 16_777_216
ID = re.compile(r"[A-Z][A-Z0-9_-]{0,39}")
HEX = re.compile(r"[a-f0-9]{64}")
NAME = re.compile(r"(?:sources|candidates)/[A-Za-z0-9_-]{1,60}\.png")
def need(ok, message):
    if not ok:
        raise ValueError(message)
def sha(data):
    return hashlib.sha256(data).hexdigest()
def read_png(z, name, digest):
    need(NAME.fullmatch(name) and HEX.fullmatch(digest), "invalid PNG path/hash")
    info=z.getinfo(name)
    need(0 < info.file_size <= MAX_PNG, "PNG size limit")
    data=z.read(info)
    need(sha(data)==digest, "PNG hash mismatch: "+name)
    with Image.open(io.BytesIO(data)) as im:
        need(im.format=="PNG" and getattr(im,"n_frames",1)==1, "single-frame PNG required")
        need(min(im.size)>=128 and im.width*im.height<=MAX_PIXELS, "image dimensions outside limits")
        im.verify()
    with Image.open(io.BytesIO(data)) as im:
        pixels=im.convert("RGBA")
        pixels.load()
    return data,pixels
def read_bundle(work, archive, out):
    d=f.state(work); accepted,revision=f.verify(work,d)
    need(accepted==["concept"],"concept must be accepted; use a new attempt before art acceptance")
    need(archive.is_file() and not archive.is_symlink() and 0<archive.stat().st_size<=MAX_ARCHIVE,"archive size/path invalid")
    need(not out.exists(), "new evidence directory required")
    with zipfile.ZipFile(archive) as z:
        infos=z.infolist(); names=[i.filename for i in infos]
        need(7<=len(names)<=25 and len(names)==len(set(names)), "unexpected or duplicate archive entries")
        need(sum(i.file_size for i in infos)<=MAX_TOTAL, "archive expansion limit")
        for i in infos:
            mode=(i.external_attr>>16)&0xFFFF
            need((i.filename=="manifest.json" or NAME.fullmatch(i.filename)) and not i.is_dir()
                and not (i.flag_bits&1) and not stat.S_ISLNK(mode)
                and i.compress_type in (zipfile.ZIP_STORED,zipfile.ZIP_DEFLATED), "forbidden archive entry")
        need("manifest.json" in names and z.getinfo("manifest.json").file_size<=65536, "missing or oversized manifest")
        m=json.loads(z.read("manifest.json"))
        need(m.get("format")==FORMAT and m.get("job_id")==d["id"] and m.get("concept_revision")==revision,
            "job or concept revision mismatch")
        need(m.get("phase") in ("draft","rebuilt") and m.get("status")=="unreviewed", "only unreviewed image evidence")
        need(isinstance(m.get("image_task_id"),str) and 3<=len(m["image_task_id"])<=128, "image task ID missing")
        sources=m.get("sources"); candidates=m.get("candidates")
        need(isinstance(sources,list) and 1<=len(sources)<=8 and isinstance(candidates,list) and 3<=len(candidates)<=8,"expected 3–8 candidate images")
        declared={"manifest.json"}; source_pixels={}; payload={}; ids=set(); hashes=set()
        for row in sources:
            path=row["path"]; need(path.startswith("sources/") and path not in declared,"duplicate/invalid source path")
            data,pixels=read_png(z,path,row["sha256"]); declared.add(path)
            need(row.get("width")==pixels.width and row.get("height")==pixels.height,"source size mismatch")
            source_pixels[path]=pixels;payload[path]=data
        for row in candidates:
            cid=row["id"]; path=row["path"]; source=row["source"]
            need(ID.fullmatch(cid) and cid not in ids,"duplicate or invalid candidate ID");ids.add(cid)
            need(path.startswith("candidates/") and path not in declared and source in source_pixels,"invalid candidate/source")
            data,pixels=read_png(z,path,row["sha256"]);declared.add(path)
            need(row["sha256"] not in hashes,"duplicate candidate image");hashes.add(row["sha256"])
            box=row["crop"]; parent=source_pixels[source]
            need(isinstance(box,list) and len(box)==4 and all(type(x) is int for x in box),"invalid crop")
            x0,y0,x1,y1=box
            need(0<=x0<x1<=parent.width and 0<=y0<y1<=parent.height,"crop outside source")
            crop=parent.crop(tuple(box))
            need(crop.size==pixels.size and all(channel.getbbox() is None for channel in ImageChops.difference(crop,pixels).split()),"candidate differs from original crop")
            payload[path]=data
        need(set(names)==declared,"unexpected archive files")
        # Store only validated data, never blindly extract paths.
        out.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=out.parent) as tmp:
            staged=Path(tmp)/"intake";staged.mkdir()
            for path,data in payload.items():
                dest=staged/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
            f.write(staged/"manifest.json",m)
            f.write(staged/"intake_report.json",{"format":FORMAT,"job_id":d["id"],"concept_revision":revision,
                "phase":m["phase"],"archive_sha256":f.digest(archive),"candidates":len(candidates),
                "status":"quarantined_unreviewed","next":"Inspect original and candidates. Reject invented completion, certification, measured mesh/rig/UV claims or fake UI. Author visual and role reviews; rebuild and re-review before factory accept art.",
                "quality_approved":False,"factory_stage_accepted":False})
            staged.rename(out)
    print(json.dumps(f.read(out/"intake_report.json"),ensure_ascii=False,indent=2))
if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("work",type=Path);p.add_argument("archive",type=Path);p.add_argument("out",type=Path)
    a=p.parse_args();read_bundle(a.work.resolve(),a.archive.resolve(),a.out.resolve())
