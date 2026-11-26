"""Audit explicitly authored foot contacts, not inferred minimum-height contact.
Y-up metres. foot_vertices[N,F,V,3], root_translation[N,3] (zero for world
vertices), anchors[N,F,V] boolean, contact[N,F] boolean. A material vertex
must stay within tolerance throughout each consecutive active interval.
An active interval across cycle boundary is evaluated by caller using repeated
cycle samples with accumulated root travel. Does not prove dynamics/collision.
"""
import argparse,json
from pathlib import Path
import numpy as np

def audit(foot_vertices, root_translation, anchors, contact, floor_y=0., tolerance_m=.005, flight_min_m=.002):
    v=np.asarray(foot_vertices,float); root=np.asarray(root_translation,float)
    a=np.asarray(anchors,bool); c=np.asarray(contact,bool)
    if v.ndim!=4 or v.shape[-1]!=3 or min(v.shape[:3])<1 or root.shape!=(len(v),3) or a.shape!=v.shape[:-1] or c.shape!=v.shape[:2] or not np.isfinite(v).all() or not np.isfinite(root).all() or not np.isfinite([floor_y,tolerance_m,flight_min_m]).all() or tolerance_m<=0 or flight_min_m<0:raise ValueError('invalid contact packet')
    w=v+root[:,None,None,:];y=w[...,1]-floor_y;missing=int(np.count_nonzero(c!=a.any(2)));height=float(np.max(np.abs(y[a]),initial=0));drift=0.;segments=0;durations=[];worst=None
    for f in range(v.shape[1]):
        for k in range(v.shape[2]):
            ids=np.flatnonzero(a[:,f,k]);runs=np.split(ids,np.flatnonzero(np.diff(ids)>1)+1)
            for run in runs:
                if len(run)<2:continue
                segments+=1;durations.append(len(run));d=np.linalg.norm(w[run,f,k][:,[0,2]]-w[run[0],f,k][[0,2]],axis=1);m=float(d.max())
                if m>drift:drift=m;worst=[f,k,int(run[0]),int(run[d.argmax()])]
    air=~c.any(1);clear=y.min((1,2));penetration=float(max(0.,-y.min()));flight_peak=float(np.max(clear[air],initial=0.));flight_low=float(np.min(clear[air])) if air.any() else None
    flight_ok=bool(air.any() and flight_peak>=flight_min_m and flight_low>=-tolerance_m)
    return dict(samples=len(v),missing_anchor_samples=missing,material_segments=segments,longest_segment_samples=max(durations,default=0),anchor_height_m=height,anchor_drift_m=drift,worst_anchor=worst,penetration_m=penetration,flight_samples=int(air.sum()),flight_peak_m=flight_peak,flight_min_m=flight_low,pass_kinematic=bool(not missing and segments and height<=tolerance_m and drift<=tolerance_m and penetration<=tolerance_m and flight_ok),scope='sampled authored material-point contact; not visual approval, force/contact inference, continuous collision or engine verification')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('--out',type=Path,required=True);p.add_argument('--floor',type=float,default=0.);p.add_argument('--tol',type=float,default=.005);args=p.parse_args()
    with np.load(args.input,allow_pickle=False) as data: r=audit(data['foot_vertices'],data['root_translation'],data['anchors'],data['contact'],args.floor,args.tol)
    args.out.write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2));raise SystemExit(0 if r['pass_kinematic'] else 2)
if __name__=='__main__':main()
