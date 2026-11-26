"""Resume a verified Parts Factory job without replaying accepted stages.

This is a production coordinator, not an AI author or aesthetic judge.
Only factory.accept may advance a quality stage. No arbitrary commands from inboxes.
"""
import argparse
import json
import os
import re
import shutil
import stat
import tempfile
import zipfile
from pathlib import Path

import factory as f
import review_roles as rr

FORMAT = "SERA_PF_CONTINUATION_V1"
OPS = ("prepare", "draft_packet", "rebuild_template", "final_packet", "accept")
HEX = re.compile(r"[a-f0-9]{64}")
MAX_ARCHIVE = 24 * 1024 * 1024
MAX_EXPANDED = 256 * 1024 * 1024
ROUTES = {
    "concept": "designer: concept and design knowledge brief",
    "art": "designer: actual independent candidate images, image_intake, supervision",
    "blueprint": "designer: actual 10-view blueprint, orthographic consistency and rig interface",
    "analysis": "engineer: reference_bridge analyze, calibration and real masks",
    "plan": "engineer: structure plan and reference-bound Modeling Studio design",
    "model": "modeler: factory authorize-model, dedicated Modeling Studio build and real renders",
    "geometry": "modeler: reference_bridge compare, actual render and clearance review",
    "uv": "texture_artist: texture_bridge prepare, authored face UV, validate and export",
    "paint": "texture_artist: texture_bridge bake/export with real PNGs and GLB review",
    "review": "production_coordinator: actual painted model, eight views and evidence review",
    "viewer": "production_coordinator: V6.5 integrated HTML, game shading/outline toggles and real review",
    "stock": "production_coordinator: V6.5 delivery validation, permanent stock and HTML delivery",
}

def require(ok, message):
    if not ok:
        raise ValueError(message)

def load_request(path):
    c = f.read(path)
    require(c.get("format") == FORMAT, "unsupported continuation request")
    require(c.get("operation") in OPS, "unsupported operation")
    require(c.get("stage") in (*f.ORDER, "stock"), "unknown stage")
    require(re.fullmatch(r"[A-Z][A-Z0-9_-]{1,39}", c.get("job_id", "")), "invalid job")
    require(c.get("upstream_revision") == "ROOT" or HEX.fullmatch(c.get("upstream_revision", "")), "invalid revision")
    require(type(c.get("source_run")) is int and c["source_run"] > 0, "source run required")
    require(type(c.get("source_artifact")) is int and c["source_artifact"] > 0, "source artifact required")
    require(re.fullmatch(r"[A-Za-z0-9_-]{1,100}", c.get("source_name", "")), "invalid artifact name")
    if c["operation"] != "prepare":
        require(c["stage"] != "stock" and HEX.fullmatch(c.get("payload_sha256", "")), "reviewed stage payload required")
        require(isinstance(c.get("producer"), str) and len(c["producer"].strip()) >= 12, "real producer provenance required")
    return c

def extract_payload(archive, dest, c):
    require(archive.is_file() and 0 < archive.stat().st_size <= MAX_ARCHIVE, "payload archive limit")
    require(f.digest(archive) == c["payload_sha256"], "payload SHA mismatch")
    with zipfile.ZipFile(archive) as z:
        entries = z.infolist()
        names = [i.filename for i in entries]
        require(len(names) == len(set(names)) and len(names) <= 4096 and "manifest.json" in names, "invalid payload inventory")
        require(sum(i.file_size for i in entries) <= MAX_EXPANDED, "expanded payload too large")
        for i in entries:
            parts = i.filename.split("/")
            require(not i.is_dir() and not any(p in ("", ".", "..") for p in parts)
                    and not any("\\" in p or ":" in p for p in parts)
                    and not stat.S_ISLNK(i.external_attr >> 16)
                    and not (i.flag_bits & 1)
                    and (i.filename == "manifest.json" or (parts[0] == "candidate" and len(parts) > 1)),
                    "forbidden payload member: " + i.filename)
        require(z.getinfo("manifest.json").file_size < 2*1024*1024, "oversized payload manifest")
        m = json.loads(z.read("manifest.json"))
        for k in ("format", "job_id", "stage", "operation", "upstream_revision"):
            require(m.get(k) == c.get(k), "payload binding mismatch: " + k)
        files = m.get("files")
        require(isinstance(files, dict) and set(names) == {"manifest.json", *("candidate/"+n for n in files)}, "payload file list mismatch")
        dest.mkdir()
        for n, digest in files.items():
            require(isinstance(digest, str) and HEX.fullmatch(digest), "invalid payload file hash")
            p = dest/n
            p.parent.mkdir(parents=True, exist_ok=True)
            with z.open("candidate/"+n) as src, p.open("xb") as dst:
                shutil.copyfileobj(src, dst)
            require(f.digest(p) == digest, "payload content hash mismatch: "+n)
        require(f.files(dest) == files, "payload verification failed")

def handoff(work, out, c, state, error=None):
    d = f.state(work)
    valid, key = f.verify(work, d)
    stage = f.ORDER[len(valid)] if len(valid) < len(f.ORDER) else "stock"
    result = {
        "format": FORMAT, "job_id": d["id"], "review_mode": d.get("review_mode", rr.STRICT),
        "accepted": valid, "revision": key, "next_stage": stage,
        "status": state, "error": error, "route": ROUTES[stage],
        "required_files": list(f.STAGES.get(stage, ())),
        "review_roles": list(rr.CRITERIA.get(stage, {})),
        "upstream": {s: {"revision": d["stages"][s]["key"], "files": d["stages"][s]["files"]} for s in valid},
        "source_run": c["source_run"], "source_artifact": c["source_artifact"],
        "run_id": os.environ.get("GITHUB_RUN_ID"), "commit": os.environ.get("GITHUB_SHA"),
        "operation": c["operation"], "request_sha256": f.signature(c),
        "authoring_required": stage != "stock",
        "stocked": False, "quality_approval_added": state == "accepted",
    }
    f.write(out/"handoff.json", result)
    # Real selected art is part of the next worker's evidence, not an invented drawing.
    if "art" in valid:
        src = work/"objects"/d["stages"]["art"]["key"]/"selected.png"
        shutil.copy2(src, out/"selected_art.png")
    if "concept" in valid:
        src = work/"objects"/d["stages"]["concept"]["key"]/"concept.json"
        shutil.copy2(src, out/"concept.json")
    print(json.dumps(result, ensure_ascii=False, indent=2))

def execute(source, config, out, archive=None):
    c = load_request(config)
    d = f.state(source)
    valid, key = f.verify(source, d)
    next_stage = f.ORDER[len(valid)] if len(valid) < len(f.ORDER) else "stock"
    require(d["id"] == c["job_id"] and key == c["upstream_revision"] and next_stage == c["stage"], "stale checkpoint or wrong stage")
    require(not out.exists(), "new output directory required")
    out.mkdir(parents=True)
    work = out/"work"
    # Copy entire verified accepted state, including rejection history, without rerunning it.
    shutil.copytree(source, work)
    try:
        if c["operation"] == "prepare":
            require(archive is None, "prepare must not carry a payload")
            handoff(work, out, c, "awaiting_authoring")
            return
        require(archive is not None, "missing stage payload")
        candidate = out/"candidate"
        extract_payload(archive, candidate, c)
        stage = c["stage"]
        upstream = {s: d["stages"][s] for s in valid}
        if c["operation"] in ("draft_packet", "final_packet"):
            if c["operation"] == "final_packet":
                require((candidate/"supervision"/"reconstruction.json").is_file(), "reconstruction record required")
            for role in rr.CRITERIA[stage]:
                rr.make_packet(work, stage, candidate, out/"packets"/role, role)
            handoff(work, out, c, "awaiting_review")
        elif c["operation"] == "rebuild_template":
            rr.cycle_template(candidate, stage, d["id"], upstream, work)
            handoff(work, out, c, "awaiting_reconstruction_record")
        else:
            f.accept(work, stage, candidate, c["producer"])
            handoff(work, out, c, "accepted")
    except Exception as exc:
        handoff(work, out, c, "blocked", str(exc))
        raise

if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source", type=Path)
    p.add_argument("config", type=Path)
    p.add_argument("out", type=Path)
    p.add_argument("--payload", type=Path)
    a = p.parse_args()
    execute(a.source.resolve(), a.config.resolve(), a.out.resolve(), a.payload.resolve() if a.payload else None)
