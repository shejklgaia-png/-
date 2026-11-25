"""Non-destructive UV-locked finishing layers for an approved texture."""
import argparse, hashlib, json
from pathlib import Path
import numpy as np
from PIL import Image
from ai_pipeline import geometry, load, samples, stroke


def fingerprint(d):
    return hashlib.sha256(json.dumps(d,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def filehash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def finish(d, plan, base_path, out):
    p,u,c,f,part,n,edges,quads,digest=geometry(d)
    if plan['mesh_sha256']!=fingerprint(d) or plan['base_sha256']!=filehash(base_path):
        raise ValueError('mesh/UV or approved texture mismatch')
    base=np.asarray(Image.open(base_path).convert('RGB')); H=int(plan['resolution'])
    if base.shape!=(H,H,3): raise ValueError('resolution mismatch')
    layers=plan['layers']; ids=[l['id'] for l in layers]
    if len(set(ids))!=len(ids): raise ValueError('duplicate layer ID')
    out=Path(out);out.mkdir(parents=True,exist_ok=True)
    owner=np.full((H,H),-1,int); pos=np.zeros((H,H,3)); boundaries={}
    for (_,key),entries in edges.items():
        for t,_,_ in entries: boundaries.setdefault(int(f[t]),[]).append(np.asarray(key))
    for t in range(len(p)):
        y,x,w=samples(u[t],H);owner[y,x]=f[t];pos[y,x]=w@p[t]
    col=base.astype(float); changed=np.zeros((H,H),bool); stats=[]
    for l in layers:
        if not l.get('enabled',True):continue
        i=int(l['face']);ts=d['source_faces'][i]; tri=p[ts]; normal=n[ts[0]]; o=tri.mean((0,1)); axis=np.array(l['axis'],float);axis-=normal*(axis@normal)
        if np.linalg.norm(axis)<1e-8 or np.min(n[ts]@normal)<.999 or np.max(abs((tri-o)@normal))>1e-5:
            stats.append({'id':l['id'],'status':'rejected_nonplanar'});continue
        axis/=np.linalg.norm(axis); side=np.cross(normal,axis); o=o+axis*l.get('offset',[0,0])[0]+side*l.get('offset',[0,0])[1]
        length=float(l['length']); width=float(l['width']); opacity=float(l.get('opacity',1)); kind=l['kind']
        if min(length,width)<=0 or not 0<=opacity<=1 or kind not in ('vent','rail'):raise ValueError('invalid recipe')
        def contains(q):
            for t in tri:
                bc=np.linalg.lstsq((t[1:]-t[0]).T,q-t[0],rcond=None)[0]
                if min(bc)>=-1e-8 and bc.sum()<=1+1e-8:return True
            return False
        if not all(contains(o+a*axis+b*side) for a in np.linspace(-length/2-width,length/2+width,17) for b in np.linspace(-width,width,7)):
            stats.append({'id':l['id'],'status':'rejected_footprint'});continue
        y,x=np.where(owner==i);q=pos[y,x]-o; a=q@axis;b=q@side; light=np.array([0.,1.,0.]); top=b*(side@light)+a*(axis@light)
        edge=np.minimum.reduce([stroke(pos[y,x],seg)[0] for seg in boundaries[i]]); safe=np.clip((edge-.006)/.004,0,1)
        # Preserve existing bright/dark markings using explicitly authored luminance range.
        lo,hi=l.get('luma_range',[0,255]); lum=base[y,x].mean(1); safe*=np.clip((lum-lo)/8,0,1)*np.clip((hi-lum)/8,0,1)
        if kind=='vent':
            count=int(l.get('count',5)); pitch=length/count; inner=np.abs((a+length/2)%pitch-pitch/2); shape=np.maximum(inner/(pitch*.27),abs(b)/(width*.72)); mask=np.clip((1-shape)*4,0,1)*(abs(a)<length/2); tone=lum*(.48+.12*np.clip(-top/width,-1,1)); rim=np.clip(1-abs(shape-1.08)*5,0,1)*(abs(a)<length/2); target=np.repeat((tone+rim*9)[:,None],3,axis=1)
        else:
            dist=np.hypot(np.maximum(abs(a)-length/2,0),b); mask=np.clip((1-dist/width)*5,0,1); profile=np.sqrt(np.maximum(0,1-(dist/width)**2)); tone=lum*.74+profile*28+np.clip(top/width,-1,1)*12; target=tone[:,None]+np.array([-2,0,3])
        alpha=mask*safe*opacity; col[y,x]=col[y,x]*(1-alpha[:,None])+target*alpha[:,None];changed[y,x]|=alpha>0;stats.append({'id':l['id'],'status':'applied','samples':int((alpha>0).sum())})
    candidates=[]
    for strength in (.55,.8,1.):
        im=np.clip(base+(col-base)*strength,0,255).round().astype(np.uint8); name=f'finish_{int(strength*100)}.png';Image.fromarray(im).save(out/name); diff=np.any(im!=base,axis=2);assert not np.any(diff&~changed);candidates.append({'file':name,'changed_pixels':int(diff.sum()),'outside_mask_changed':int((diff&~changed).sum())})
    report={'geometry_sha256':digest,'mesh_sha256':fingerprint(d),'base_sha256':filehash(base_path),'layers':stats,'candidates':candidates,'visual_approval':'pending','limitations':['UV-locked raster base, not recovered historical vectors','sampled footprint check','illustrative baked metal shading, not PBR','original padding preserved']}
    (out/'report.json').write_text(json.dumps(report,indent=2));(out/'plan.json').write_text(json.dumps(plan,indent=2));return report


if __name__=='__main__':
    ap=argparse.ArgumentParser();[ap.add_argument(x) for x in ('mesh','plan','base','out')];a=ap.parse_args();print(json.dumps(finish(load(a.mesh),load(a.plan),a.base,a.out),indent=2))
