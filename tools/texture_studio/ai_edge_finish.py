"""Non-destructive edge-oriented armor finishing. Source-face local coordinates."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from shapely.geometry import Polygon,LineString,Point
from shapely.ops import unary_union
from ai_pipeline import geometry,load,samples,stroke
from ai_finish import fingerprint,filehash

def frame(p,n,ts):
    o=p[ts].mean((0,1)); a=np.cross([0.,1.,0.],n[ts[0]])
    if np.linalg.norm(a)<.1:a=np.cross([0.,0.,1.],n[ts[0]])
    a/=np.linalg.norm(a); return o,np.stack([a,np.cross(n[ts[0]],a)],1)

def run(d,plan,base_path,out):
    p,u,c,f,part,n,edges,quads,digest=geometry(d); H=plan['resolution'];out=Path(out);out.mkdir(parents=True,exist_ok=True)
    if fingerprint(d)!=plan['mesh_sha256'] or filehash(base_path)!=plan['base_sha256']:raise ValueError('input hash mismatch')
    base=np.asarray(Image.open(base_path).convert('RGB')); assert base.shape==(H,H,3)
    col=base.astype(float); mask=np.zeros((H,H),bool); stats=[]
    for g in plan['groups']:
        for face,mirror in [(g['face'],False),(g['mirror_face'],True)]:
            ts=d['source_faces'][face];o,F=frame(p,n,ts); q=[];ys=[];xs=[]
            for t in ts:
                y,x,w=samples(u[t],H);ys.extend(y);xs.extend(x);q.extend((w@p[t]-o)@F)
            q=np.asarray(q);y=np.asarray(ys);x=np.asarray(xs); q[:,0]*=-1 if mirror else 1
            verts=(p[ts]-o)@F;verts[:,:,0]*=-1 if mirror else 1
            poly=unary_union([Polygon(t) for t in verts]); boundary=np.array(poly.exterior.coords);dist=stroke(q,boundary)[0]; safe=np.clip((dist-plan['protect'])/plan['fade'],0,1)
            old=base[y,x].astype(float); color=old.copy();changed=np.zeros(len(q),bool)
            # Explicitly selected old marks only; robust local plane fit to intact paint around them.
            for erase in g['erase']:
                center=np.array(erase['center']); radii=np.array(erase['radii']);z=(q-center)/radii; r=np.linalg.norm(z,ord=erase.get('power',2),axis=1); ring=(r>=1.12)&(r<=1.75)&(safe>.99)
                if ring.sum()<20:raise ValueError('not enough intact local paint samples')
                A=np.column_stack([np.ones(len(q)),z]);keep=ring.copy()
                for _ in range(4):
                    coef=np.linalg.lstsq(A[keep],old[keep],rcond=None)[0];err=np.linalg.norm(old-A@coef,axis=1); med=np.median(err[keep]);keep=ring&(err<=max(5,med*2.5))
                    if keep.sum()<12:raise ValueError('paint fit failed')
                alpha=np.clip((1-r)*8,0,1)*safe;color=color*(1-alpha[:,None])+np.clip(A@coef,0,255)*alpha[:,None];changed|=alpha>0
            marks=[]
            for row in g['rows']:
                A,B=np.array(row['edge']);vec=B-A;L=np.linalg.norm(vec);v=vec/L;inward=np.array([-v[1],v[0]])
                if not poly.covers(Point((A+B)/2+inward*row['inset'])):inward=-inward
                for t in row['positions']:
                    center=A+t*vec+inward*row['inset'];r=row['radius'];length=row.get('length',0); a=center-v*length/2;b=center+v*length/2
                    shape=Point(center).buffer(r*1.35) if length==0 else LineString([a,b]).buffer(r*1.35)
                    if not poly.buffer(-plan['protect']).covers(shape):raise ValueError(f'edge feature outside safe band: {face}')
                    if any(shape.intersects(s) for s in marks):raise ValueError('overlapping marks')
                    marks.append(shape);dist0=np.linalg.norm(q-center,axis=1) if length==0 else stroke(q,np.array([a,b]))[0]
                    # Inset shadow + narrow lit lip, oriented by actual world +Y.
                    light=np.array([F[1,0]*(-1 if mirror else 1),F[1,1]]);offset=q-center;top=np.clip(offset@light/max(r,.00001),-1,1)
                    lum=color.mean(1); outer=np.clip((1.22-dist0/r)*6,0,1)*safe; core=np.clip((.86-dist0/r)*7,0,1)*safe
                    lip=np.repeat((lum+np.where(top>0,-20,16))[:,None],3,axis=1); target=np.repeat((lum*(.52 if length else .63)+np.clip(top,-1,1)*8)[:,None],3,axis=1)
                    color=color*(1-outer[:,None])+lip*outer[:,None];color=color*(1-core[:,None])+target*core[:,None];changed|=outer>0
                    if length==0:
                        slot=np.clip((.17*r-abs(offset@v))/(.08*r),0,1)*np.clip((.56*r-abs(offset@inward))/(.12*r),0,1)*safe
                        color=color*(1-slot[:,None])+np.repeat((lum*.38)[:,None],3,axis=1)*slot[:,None];changed|=slot>0
            col[y,x]=color;mask[y,x]|=changed;stats.append({'face':face,'removed_regions':len(g['erase']),'edge_features':len(marks),'changed_mask':int(changed.sum())})
    final=np.clip(col,0,255).round().astype(np.uint8);diff=np.any(final!=base,axis=2);assert not np.any(diff&~mask)
    Image.fromarray(final).save(out/'albedo.png');Image.fromarray(mask.astype(np.uint8)*255).save(out/'edit_mask.png')
    report={'faces':stats,'changed_pixels':int(diff.sum()),'outside_mask_changed':0,'geometry_sha256':digest,'visual_approval':'pending','limitations':['authored face selection and old mark removal zones','local planar projection on mildly nonplanar original quads','baked illustrative shadows, not dynamic geometry']};(out/'report.json').write_text(json.dumps(report,indent=2));return report

if __name__=='__main__':
    ap=argparse.ArgumentParser();[ap.add_argument(x) for x in ('mesh','plan','base','out')];a=ap.parse_args();print(json.dumps(run(load(a.mesh),load(a.plan),a.base,a.out),indent=2))
