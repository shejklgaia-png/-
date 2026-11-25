"""V7: authored existing-asset anchors and reflected routing, before V6 compositing."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from shapely.geometry import Point,LineString
from ai_pipeline import geometry,load
from ai_finish import fingerprint,filehash
from ai_mechanism import render,components


def frame_for(d,p,n,i):
    ts=d['source_faces'][i];tri=p[ts];o=tri.mean((0,1));normal=n[ts[0]]
    if np.min(n[ts]@normal)<.999 or np.max(abs((tri-o)@normal))>1e-5:raise ValueError('anchor face is not planar')
    a=np.cross([0.,1.,0.],normal)
    if np.linalg.norm(a)<.1:a=np.cross([0.,0.,1.],normal)
    a/=np.linalg.norm(a);return ts,o,np.stack([a,np.cross(normal,a)],1)


def validate(d,plan,base_path):
    p,u,c,f,part,n,edges,quads,digest=geometry(d)
    if fingerprint(d)!=plan['mesh_sha256'] or filehash(base_path)!=plan['base_sha256']:raise ValueError('input hash mismatch')
    im=np.asarray(Image.open(base_path).convert('RGB'));H=int(plan['resolution'])
    if im.shape!=(H,H,3):raise ValueError('resolution mismatch')
    anchors={};stats=[];routes={};world={}
    for a in plan['anchors']:
        name=a['id'];i=int(a['face']);q=np.asarray(a['point'],float);radius=float(a['radius'])
        if name in anchors or q.shape!=(2,) or not np.isfinite(q).all() or not 0<radius:raise ValueError('invalid anchor')
        ts,o,frame=frame_for(d,p,n,i);local=(p[ts]-o)@frame
        # Use the actual base texture at the authored port, not a generic face-center guess.
        theta=np.linspace(0,2*np.pi,16,endpoint=False);disk=np.vstack([q,q+radius*.5*np.stack([np.cos(theta),np.sin(theta)],1)])
        lum=[]
        for x in disk:
            for j,t in enumerate(ts):
                bc=np.linalg.solve((local[j,1:]-local[j,:1]).T,x-local[j,0])
                if min(bc)>=-1e-8 and bc.sum()<=1+1e-8:
                    uv=np.r_[1-bc.sum(),bc]@u[t];xx,yy=np.clip((uv*H).astype(int),0,H-1);lum.append(float(im[yy,xx].mean()));break
        if len(lum)!=len(disk):raise ValueError('anchor footprint outside original face: '+name)
        mean=float(np.mean(lum));lo,hi=a['luma_range']
        if not lo<=mean<=hi:raise ValueError('anchor color evidence mismatch: '+name)
        anchors[name]=(i,q,radius);stats.append({'anchor':name,'role':a['role'],'mean_luma':mean,'sample_count':len(lum)})
    accepted=[];used=set()
    for r in plan['assemblies']:
        if not r.get('enabled',True):continue
        rid=r['id'];i=int(r['face']);path=np.asarray(r['path'],float);names=r['anchors']
        if rid in routes or len(names)!=2 or names[0]==names[1] or any(k in used for k in names):raise ValueError('duplicate route or port')
        ts,o,frame=frame_for(d,p,n,i)
        for end,name in zip((path[0],path[-1]),names):
            fi,q,radius=anchors[name]
            if fi!=i or np.linalg.norm(end-q)>min(radius*.25,float(r['radius'])*.5):raise ValueError('route misses authored port: '+name)
        components(r);routes[rid]=r;world[rid]=o+path@frame.T;used.update(names);accepted.append(r)
    reflection=np.asarray(plan.get('reflection_plane_x',0.),float)
    for a,b in plan.get('mirror_pairs',[]):
        x=world[a].copy();x[:,0]=2*reflection-x[:,0];y=world[b]
        if x.shape!=y.shape or min(np.max(np.linalg.norm(x-y,axis=1)),np.max(np.linalg.norm(x-y[::-1],axis=1)))>float(plan.get('mirror_tolerance',.0001)):raise ValueError('mirror routes mismatch')
    return accepted,stats


def run(d,plan,base,out):
    out=Path(out);out.mkdir(parents=True,exist_ok=True)
    accepted,stats=validate(d,plan,base)
    result=render(d,dict(plan,assemblies=accepted),base,out)
    result['anchors']=stats;result['mirror_pairs']=plan.get('mirror_pairs',[]);result['placement_approval']='pending visual inspection';result['limitations']+=['anchors are manually identified visual features, not physical sockets; only same-face routes','anchor luminance is a supporting check, not semantic recognition']
    (out/'report.json').write_text(json.dumps(result,indent=2));(out/'plan.json').write_text(json.dumps(plan,indent=2));return result

if __name__=='__main__':
    ap=argparse.ArgumentParser();[ap.add_argument(x) for x in ('mesh','plan','base','out')];a=ap.parse_args();print(json.dumps(run(load(a.mesh),load(a.plan),a.base,a.out),indent=2))
