"""V9: fasteners tied to authored visible panel seams, not arbitrary mesh edges."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from ai_pipeline import geometry,load
from ai_finish import fingerprint,filehash
from ai_edge_finish import frame,run

def validate(d,plan,base_path):
    p,u,c,f,part,n,edges,quads,digest=geometry(d);H=plan['resolution'];im=np.asarray(Image.open(base_path).convert('RGB'),float)
    if fingerprint(d)!=plan['mesh_sha256'] or filehash(base_path)!=plan['base_sha256']:raise ValueError('input hash mismatch')
    evidence=[]
    for g in plan['groups']:
        for row in g['rows']:
            if row.get('length',0)!=0 or not row.get('panel_id'):raise ValueError('fastener needs named panel seam')
            A,B=np.asarray(row['edge'],float);v=B-A;L=np.linalg.norm(v);normal=np.array([-v[1],v[0]])/L;r=row['radius'];D=2*r
            # Visual head diameter is a game-design proxy, not an engineering shank diameter.
            if not 1.4*D<=row['inset']<=3.5*D or np.any(np.diff(row['positions'])*L<3*D):raise ValueError('fastener inset or pitch')
            for face,mirror in [(g['face'],False),(g['mirror_face'],True)]:
                ts=d['source_faces'][face];o,F=frame(p,n,ts);local=(p[ts]-o)@F;local[:,:,0]*=-1 if mirror else 1
                def lum(q):
                    for j,t in enumerate(ts):
                        bc=np.linalg.solve((local[j,1:]-local[j,:1]).T,q-local[j,0])
                        if min(bc)>=-1e-7 and bc.sum()<=1+1e-7:
                            uv=np.r_[1-bc.sum(),bc]@u[t];x,y=np.clip((uv*H).astype(int),0,H-1);return im[y,x].mean()
                    return np.nan
                # Check the dark groove is present near the authored line, against both shoulders.
                samples=[]
                for t in np.linspace(.12,.88,9):
                    q=A+t*v;vals=np.array([lum(q+normal*k) for k in np.linspace(-.004,.004,9)]);shoulders=np.array([lum(q+normal*k) for k in (-.009,.009)])
                    if np.isfinite(vals).any() and np.isfinite(shoulders).all():samples.append(float(shoulders.mean()-np.nanmin(vals)))
                if len(samples)<6 or np.median(samples)<12:raise ValueError(f'panel seam not evidenced: {row["panel_id"]} face {face}: {samples}')
                evidence.append({'panel':row['panel_id'],'face':face,'median_contrast':round(float(np.median(samples)),2),'count':len(samples),'fasteners':len(row['positions'])})
    return evidence

def finish(d,plan,base,out):
    evidence=validate(d,plan,base);report=run(d,plan,base,out);report['panel_evidence']=evidence;report['visual_approval']='pending';(Path(out)/'report.json').write_text(json.dumps(report,indent=2));return report

if __name__=='__main__':
    ap=argparse.ArgumentParser();[ap.add_argument(x) for x in ('mesh','plan','base','out')];a=ap.parse_args();print(json.dumps(finish(load(a.mesh),load(a.plan),a.base,a.out),indent=2))
