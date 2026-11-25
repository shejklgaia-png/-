"""Rigid-node pose assets and explicit phase compiler. No production model writes."""
import json, hashlib, math, re
from pathlib import Path

FORMAT="SERA_MOTION_POSES_V1"
PROPS={"location","rotation_deg"}
MODES={"BEZIER","LINEAR","CONSTANT"}
def identity(d,design_path):
    if d.get("source_bbmodel"):
        repo=Path(__file__).resolve().parents[2]
        source=(repo/d["source_bbmodel"]).resolve()
        manifest=json.loads((repo/"models/manifest.json").read_text())
        allowed={manifest["body_rig"],*manifest["variants"].values(),*manifest["parts"].values(),*manifest["bosses"].values()}
        if source not in {(repo/p).resolve() for p in allowed}: raise ValueError("not a canonical model")
        return {"kind":"bbmodel","path":d["source_bbmodel"],"sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"unit_m":float(d["bb_unit_m"])}
    if d.get("source_glb"):
        source=(design_path.parent/d["source_glb"]).resolve()
        return {"kind":"glb","sha256":hashlib.sha256(source.read_bytes()).hexdigest()}
    return {"kind":"procedural","parts":d["parts"]}

def canonical(x):
    return json.dumps(x,sort_keys=True,separators=(",",":"),ensure_ascii=False,allow_nan=False)

def compile_poses(d,design_path,nodes,end,out):
    template=d.get("pose_sequence")
    if not template: return
    root=Path(__file__).resolve().parent/"poses"
    path=(root/template["library"]).resolve()
    if not path.is_relative_to(root.resolve()) or path.suffix!=".json": raise ValueError("invalid pose library path")
    raw=path.read_bytes(); lib=json.loads(raw)
    rig=identity(d,design_path)
    if lib.get("format")!=FORMAT or canonical(lib.get("rig"))!=canonical(rig):
        raise ValueError("pose library rig identity mismatch")
    phases=template["phases"]
    if not 2<=len(phases)<=30: raise ValueError("2..30 phases required")
    previous=0; channels=None; compiled={}; timeline=[]; events=dict(d.get("events",{}))
    for phase in phases:
        frame=phase["frame"]; event=phase["event"]; pose_id=phase["pose"]
        if type(frame)!=int or not previous<frame<=end: raise ValueError("invalid phase frame")
        if not re.fullmatch(r"[A-Za-z0-9_]+",event) or event in events: raise ValueError("duplicate/invalid phase event")
        previous=frame
        pose=lib["poses"][pose_id]["channels"]
        current={(node,prop) for node,props in pose.items() for prop in props}
        if not current or (channels is not None and current!=channels): raise ValueError("pose channel mismatch")
        channels=current
        if any(node not in nodes or prop not in PROPS for node,prop in current): raise ValueError("unknown pose channel")
        interpolation=phase.get("interpolation","BEZIER")
        if interpolation not in MODES: raise ValueError("invalid phase interpolation")
        for node,props in pose.items():
            for prop,value in props.items():
                if len(value)!=3 or not all(isinstance(v,(int,float)) and math.isfinite(v) for v in value): raise ValueError("invalid pose vector")
                if prop in d.get("tracks",{}).get(node,{}): raise ValueError("explicit/pose track collision")
                compiled.setdefault(node,{}).setdefault(prop,[]).append({"frame":frame,"value":value,"interpolation":interpolation})
        events[event]=frame
        timeline.append({"event":event,"pose":pose_id,"frame":frame,"interpolation_to_next":interpolation})
    if phases[0]["frame"]!=1 or phases[-1]["frame"]!=end: raise ValueError("explicit sequence endpoints required")
    for node,props in compiled.items(): d.setdefault("tracks",{}).setdefault(node,{}).update(props)
    d["events"]=events
    (out/"pose_compile_report.json").write_text(json.dumps({"library":path.name,"sha256":hashlib.sha256(raw).hexdigest(),"rig":rig,"phases":timeline,"compiled_tracks":compiled,"scope":"absolute local rigid-node poses, no retargeting"},indent=2,ensure_ascii=False))

def export_poses(scene,d,design_path,nodes,end,out):
    requests=d.get("export_poses",[])
    if not requests: return
    if len(requests)>30: raise ValueError("max 30 pose exports")
    channels=d.get("pose_export_channels",{})
    if not channels: raise ValueError("pose_export_channels required")
    for name,props in channels.items():
        if name not in nodes or not props or set(props)-PROPS: raise ValueError("invalid export channels")
    poses={}
    for req in requests:
        name=req["id"]; f=req["frame"]
        if not re.fullmatch(r"[A-Za-z0-9_]+",name) or name in poses or type(f)!=int or not 1<=f<=end: raise ValueError("invalid pose export")
        scene.frame_set(f);scene.view_layers[0].update()
        values={}
        for node,props in channels.items():
            o=nodes[node]
            if o.constraints or o.rotation_mode!="XYZ": raise ValueError("pose export requires unconstrained XYZ nodes")
            values[node]={p:list(o.location) if p=="location" else [math.degrees(v) for v in o.rotation_euler] for p in props}
        poses[name]={"channels":values,"source_frame":f,"status":"candidate_not_approved"}
    (out/"pose_candidates.json").write_text(json.dumps({"format":FORMAT,"rig":identity(d,design_path),"poses":poses,"status":"review_required"},indent=2,ensure_ascii=False))
