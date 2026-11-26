"""Lossless, bounded transport for a production ZIP over text-only connectors.
Pack generates small Base64 text files; bridge uploads each as a binary Git
blob. Join verifies every fragment and the complete ZIP before exposing it.
This is file transport, never visual approval or game registration.
"""
import argparse
import base64
import hashlib
import json
import os
import re
import tempfile
from pathlib import Path

FORMAT="SERA_PF_BINARY_TRANSPORT_V1"
CHUNK=540000
MAX=24*1024*1024
HEX=re.compile(r"[a-f0-9]{64}")
def need(ok,msg):
    if not ok: raise ValueError(msg)
def sha(data): return hashlib.sha256(data).hexdigest()
def pack(archive,out):
    need(archive.is_file() and not archive.is_symlink() and 0<archive.stat().st_size<=MAX,"invalid archive")
    need(not out.exists(),"new transport directory required")
    data=archive.read_bytes()
    need(0<len(data)<=MAX,"archive size changed")
    out.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(dir=out.parent) as tmp:
        staged=Path(tmp)/"transfer";staged.mkdir()
        rows=[]
        for i,offset in enumerate(range(0,len(data),CHUNK)):
            raw=data[offset:offset+CHUNK]
            name=f"part{i:03d}.bin"
            encoded=base64.b64encode(raw)
            (staged/(name+".b64.txt")).write_bytes(encoded)
            rows.append({"path":name,"bytes":len(raw),"sha256":sha(raw),"text_sha256":sha(encoded)})
        m={"format":FORMAT,"archive_bytes":len(data),"archive_sha256":sha(data),"parts":rows}
        (staged/"manifest.json").write_text(json.dumps(m,indent=2)+"\n",encoding="utf-8")
        staged.rename(out)
    print(json.dumps(m,indent=2))
def join(folder,output):
    need(folder.is_dir() and not folder.is_symlink(),"invalid transport folder")
    manifest=folder/"manifest.json"
    need(manifest.is_file() and not manifest.is_symlink() and manifest.stat().st_size<=65536,"invalid manifest")
    m=json.loads(manifest.read_text(encoding="utf-8"))
    need(m.get("format")==FORMAT and type(m.get("archive_bytes")) is int and 0<m["archive_bytes"]<=MAX
         and isinstance(m.get("archive_sha256"),str) and HEX.fullmatch(m["archive_sha256"]),"invalid archive metadata")
    rows=m.get("parts")
    expected=(m["archive_bytes"]+CHUNK-1)//CHUNK
    need(isinstance(rows,list) and len(rows)==expected,"fragment count mismatch")
    names={f"part{i:03d}.bin" for i in range(expected)}
    need({p.name for p in folder.iterdir()}==names|{"manifest.json"},"unexpected transport files")
    need(not output.exists(),"refuse to overwrite archive")
    output.parent.mkdir(parents=True,exist_ok=True)
    h=hashlib.sha256();total=0
    with tempfile.TemporaryDirectory(dir=output.parent) as tmp:
        staged=Path(tmp)/"archive.zip"
        with staged.open("wb") as out:
            for i,row in enumerate(rows):
                name=f"part{i:03d}.bin"
                size=min(CHUNK,m["archive_bytes"]-total)
                need(row.get("path")==name and type(row.get("bytes")) is int and row["bytes"]==size
                     and isinstance(row.get("sha256"),str) and HEX.fullmatch(row["sha256"]),"invalid fragment metadata")
                p=folder/name
                need(p.is_file() and not p.is_symlink() and p.stat().st_size==size,"fragment missing or wrong length")
                data=p.read_bytes()
                need(len(data)==size and sha(data)==row["sha256"],"fragment checksum mismatch: "+name)
                h.update(data);total+=len(data);out.write(data)
        need(total==m["archive_bytes"] and h.hexdigest()==m["archive_sha256"],"whole archive checksum mismatch")
        os.link(staged,output)
    print(json.dumps({"status":"verified_transfer","bytes":total,"sha256":h.hexdigest(),"parts":len(rows),"quality_approved":False},indent=2))
if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest="cmd",required=True)
    a=s.add_parser("pack");a.add_argument("archive",type=Path);a.add_argument("out",type=Path)
    a=s.add_parser("join");a.add_argument("folder",type=Path);a.add_argument("out",type=Path)
    a=p.parse_args()
    if a.cmd=="pack":pack(a.archive,a.out)
    else:join(a.folder,a.out)
