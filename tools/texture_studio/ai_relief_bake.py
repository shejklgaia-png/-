"""Temporary tessellated displacement mesh; project its normals onto the original UV."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
from ai_pipeline import geometry,load,samples,stroke

def unit(v):
    return v/np.maximum(np.linalg.norm(v,axis=-1,keepdims=True),1e-15)

def layers_for(plan,fid,part,mat):
    for l in plan['layers']:
        if not l.get('enabled',True) or ('faces' in l and fid not in l['faces']) or ('parts' in l and part not in l['parts']) or ('materials' in l and mat not in l['materials']):continue
        k=l['kind'];w=float(l['width'])
        if k=='cylinder':h=w*.38
        elif k=='dot' and l.get('relief'):h=w*.30
        elif k=='stroke' and l['id'].startswith(('hatch','vent','brow_surface')):h=-w*.40
        else:continue
        yield l,h

def patch(p,n,layers,boundary,N):
    i,j=np.mgrid[0:N+1,0:N+1];valid=i+j<=N
    q=np.stack([1-(i+j)/N,i/N,j/N],-1)[valid]@p;pos=np.zeros(len(q));neg=pos.copy()
    for l,h in layers:
        d=np.linalg.norm(q-np.asarray(l['center']),axis=1) if l['kind']=='dot' else stroke(q,np.asarray(l['points'],float))[0]
        v=h*(1-np.clip(d/float(l['width']),0,1)**2)**2
        if h>0:pos=np.maximum(pos,v)
        else:neg=np.minimum(neg,v)
    h=pos+neg
    if boundary:
        dist=np.minimum.reduce([stroke(q,np.asarray(e))[0] for e in boundary]);h*=np.clip(dist/.003,0,1)
    verts=q+h[:,None]*n;ix=np.full((N+1,N+1),-1,int);ix[valid]=np.arange(len(q))
    a,b=np.where(i+j<N);t1=np.column_stack([ix[a,b],ix[a+1,b],ix[a,b+1]])
    a,b=np.where(i+j<N-1);t2=np.column_stack([ix[a+1,b],ix[a+1,b+1],ix[a,b+1]])
    tri=np.concatenate([t1,t2]);cross=np.cross(verts[tri[:,1]]-verts[tri[:,0]],verts[tri[:,2]]-verts[tri[:,0]]);vn=np.zeros_like(verts)
    for k in range(3):np.add.at(vn,tri[:,k],cross)
    return verts,tri,ix,h,unit(vn)

def transfer(w,N,ix,h,vn):
    w=np.maximum(w,1e-10);w/=w.sum(1,keepdims=True);ij=np.clip(w[:,1:]*N,0,N-1e-8);i,j=np.floor(ij).astype(int).T;a,b=(ij-np.floor(ij)).T
    upper=(a+b>1)&(i+j<N-1);a=np.where(upper,1-a,a);b=np.where(upper,1-b,b)
    ii=np.where(upper,i+1,i);jj=np.where(upper,j+1,j);sg=np.where(upper,-1,1)
    ids=np.column_stack([ix[ii,jj],ix[ii+sg,jj],ix[ii,jj+sg]]);weights=np.column_stack([1-a-b,a,b])
    if np.any(ids<0):raise ValueError('projection outside patch')
    return (h[ids]*weights).sum(1),unit((vn[ids]*weights[:,:,None]).sum(1))

def depthmap(tris,L,M=768,frame=None):
    right=unit(np.cross(L,[0.,0.,1.]));B=np.stack([right,np.cross(right,L),L],1);p=tris@B;lo=p[:,:,:2].min((0,1));span=np.maximum(p[:,:,:2].max((0,1))-lo,1e-9);lo,span=(lo,span) if frame is None else frame;uv=(p[:,:,:2]-lo)/span;depth=np.full((M,M),-np.inf)
    low=np.maximum(0,np.floor(uv.min(1)*M).astype(int));high=np.minimum(M,np.ceil(uv.max(1)*M).astype(int));size=high-low;good=(abs(np.linalg.det(uv[:,1:]-uv[:,:1]))>1e-14)&(size>0).all(1)
    for sx,sy in np.unique(size[good],axis=0):
        ids=np.flatnonzero(good&(size[:,0]==sx)&(size[:,1]==sy));yy,xx=np.mgrid[:sy,:sx];offset=np.stack([xx.ravel(),yy.ravel()],1);chunk=max(1,250000//(sx*sy))
        for start in range(0,len(ids),chunk):
            t=ids[start:start+chunk];xy=low[t,None,:]+offset;q=(xy+.5)/M-uv[t,None,0];bc=np.einsum('tij,tkj->tki',np.linalg.inv((uv[t,1:]-uv[t,:1]).transpose(0,2,1)),q);mask=(bc>=-1e-8).all(2)&(bc.sum(2)<=1+1e-8);z=p[t,None,0,2]+(bc*(p[t,1:,2]-p[t,:1,2])[:,None,:]).sum(2);x,y=xy[mask].T;np.maximum.at(depth,(y,x),z[mask])
    return depth,B,lo,span

def visible(q,m):
    depth,B,lo,span=m;pr=q@B;M=len(depth);xy=np.clip(((pr[:,:2]-lo)/span*M).astype(int),0,M-1);gap=depth[xy[:,1],xy[:,0]]-pr[:,2];return 1-np.clip((gap-.0015)/.003,0,1)

def run(d,plan,base_path,out):
    p,u,c,face,part,n,edges,quads,digest=geometry(d);H=int(plan['resolution']);base=np.asarray(Image.open(base_path).convert('RGB'))
    if base.shape!=(H,H,3) or plan['geometry_sha256']!=digest:raise ValueError('base or geometry mismatch')
    out=Path(out);out.mkdir(parents=True,exist_ok=True);patches={};high=[];boundary={}
    for (_,key),e in edges.items():
        for t,_,_ in e:boundary.setdefault(int(face[t]),[]).append(key)
    for t in range(len(p)):
        fid=int(face[t]);mat=plan['face_material'][fid];layers=list(layers_for(plan,fid,int(part[t]),mat))
        if not layers or mat in plan.get('emissive_materials',[]):high.append(p[t:t+1]);continue
        length=max(np.linalg.norm(p[k,a]-p[k,b]) for k in d['source_faces'][fid] for a,b in [(0,1),(1,2),(2,0)]);N=int(np.clip(np.ceil(length/min(l['width'] for l,h in layers)*2),8,96));v,tr,ix,h,vn=patch(p[t],n[t],layers,boundary.get(fid,[]),N);patches[t]=(N,ix,h,vn);high.append(v[tr])
    high=np.concatenate(high);lights=unit(np.array([[0,1,0],[.35,1,.2],[-.35,1,-.2]]));maps=[]
    for L in lights:
        B=np.stack([unit(np.cross(L,[0.,0.,1.])),np.cross(unit(np.cross(L,[0.,0.,1.])),L),L],1);xy=np.concatenate([high,p])@B;lo=xy[:,:,:2].min((0,1));span=np.maximum(xy[:,:,:2].max((0,1))-lo,1e-9);hi=depthmap(high,L,frame=(lo,span));maps.append((depthmap(p,L,frame=hi[2:]),hi))
    owner=np.full((H,H),-1,int);factor=np.ones((H,H));normals=np.zeros((H,H,3));heightmap=np.zeros((H,H));shadow=np.ones((H,H));affected=0
    for t in range(len(p)):
        y,x,w=samples(u[t],H);q=w@p[t];h=np.zeros(len(q));nn=np.tile(n[t],(len(q),1))
        if t in patches:h,nn=transfer(w,*patches[t]);affected+=int((abs(h)>1e-7).sum())
        new=np.zeros(len(q));old=new.copy();delta=new.copy()
        for L,(a,b) in zip(lights,maps):
            va=visible(q,a);vb=visible(q+h[:,None]*n[t],b);old+=.60+.40*max(0,n[t]@L)*va;new+=.60+.40*np.maximum(0,nn@L)*vb;delta+=vb-va
        gain=np.clip(new/np.maximum(old,1e-8),.78,1.22)
        if plan['face_material'][face[t]] in plan.get('emissive_materials',[]):gain[:]=1
        owner[y,x]=t;factor[y,x]=gain;normals[y,x]=nn;heightmap[y,x]=h;shadow[y,x]=np.clip(1+delta/len(lights),0,1)
    valid=owner>=0;dist,idx=distance_transform_edt(~valid,return_indices=True);pad=(~valid)&(dist<=plan.get('padding',8));factor[pad]=factor[idx[0][pad],idx[1][pad]]
    final=np.clip(base.astype(float)*factor[:,:,None],0,255).round().astype(np.uint8);Image.fromarray(final).save(out/'albedo.png');Image.fromarray(np.round((normals+1)*127.5).astype(np.uint8)).save(out/'relief_normal_world.png');Image.fromarray(np.round(np.clip(.5+heightmap/.02,0,1)*65535).astype(np.uint16)).save(out/'relief_height.png');Image.fromarray(np.round(shadow*255).astype(np.uint8)).save(out/'relief_shadow.png');np.savez_compressed(out/'virtual_mesh.npz',triangles=high.astype(np.float32))
    report={'geometry_sha256':digest,'low_triangles':len(p),'virtual_triangles':len(high),'patched_low_triangles':len(patches),'displaced_texels':affected,'max_height':float(heightmap.max()),'min_height':float(heightmap.min()),'gain_min':float(factor[valid].min()),'gain_max':float(factor[valid].max()),'modified_covered_texels':int(np.count_nonzero(np.any(final!=base,axis=2)&valid)),'resolution':H,'light_directions':len(lights),'visual_approval':'pending','limitations':['normal displacement only, not arbitrary high-poly cage transfer','original face boundary taper','directional shadow map, not hemispherical AO','world normals not tangent-space runtime maps','differential lighting on already shaded base','nearest padding for lighting gain']}
    (out/'report.json').write_text(json.dumps(report,indent=2));return report

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('mesh');ap.add_argument('plan');ap.add_argument('base');ap.add_argument('out');a=ap.parse_args();print(json.dumps(run(load(a.mesh),load(a.plan),a.base,a.out),indent=2))
