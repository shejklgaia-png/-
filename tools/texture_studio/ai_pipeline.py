"""SERA offline surface painter. Geometry is immutable; authored layers are JSON."""
import argparse, hashlib, json
from pathlib import Path
from collections import defaultdict
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def geometry(d):
    p=np.asarray(d['positions'],float).reshape(-1,3,3); u=np.asarray(d['uvs'],float).reshape(-1,3,2)
    f=d['source_faces']; c=np.asarray(d['chart'],int); n=len(p)
    if not n or len(u)!=n or len(c)!=n or sorted(t for a in f for t in a)!=list(range(n)) or not np.isfinite(p).all() or not np.isfinite(u).all() or u.min()<0 or u.max()>1: raise ValueError('invalid mesh/UV/face mapping')
    normal=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]); area=np.linalg.norm(normal,axis=1)
    if min(area)<1e-12 or min(abs(np.linalg.det(u[:,1:]-u[:,:1])))<1e-12: raise ValueError('degenerate triangle')
    normal/=area[:,None]; face=np.empty(n,int); edges=defaultdict(list); quads=[]
    part=np.asarray(d.get('parts',[-1]*n),int)
    if len(part)!=n: raise ValueError('invalid part IDs')
    for i,ts in enumerate(f):
        local=defaultdict(list)
        for t in ts:
            face[t]=i
            for a,b in [(0,1),(1,2),(2,0)]:
                x,y=tuple(p[t,a]),tuple(p[t,b]); a,b=(a,b) if x<y else (b,a); local[tuple(sorted((x,y)))].append((t,a,b))
        boundary=[(k,v[0]) for k,v in local.items() if len(v)==1]; quads.append(len(ts)==2 and len(boundary)==4)
        for k,v in boundary: edges[(int(part[v[0]]),k)].append(v)
    digest=hashlib.sha256(np.asarray(p,dtype='<f8').tobytes()+np.asarray(face,dtype='<i8').tobytes()+np.asarray(part,dtype='<i8').tobytes()).hexdigest()
    return p,u,c,face,part,normal,edges,quads,digest


def samples(uv,H):
    lo=np.maximum(0,np.floor(uv.min(0)*H).astype(int)); hi=np.minimum(H,np.ceil(uv.max(0)*H).astype(int)); x0,y0=lo;x1,y1=hi
    yy,xx=np.mgrid[y0:y1,x0:x1]; q=(np.stack([xx,yy],-1)+.5)/H
    bc=(q-uv[0])@np.linalg.inv((uv[1:]-uv[0]).T).T; mask=(bc>=-1e-9).all(-1)&(bc.sum(-1)<=1+1e-9)
    return yy[mask],xx[mask],np.column_stack([1-bc[mask].sum(-1),bc[mask]])


def stroke(q,points):
    dist=np.full(len(q),np.inf); delta=np.zeros_like(q)
    for a,b in zip(points[:-1],points[1:]):
        v=b-a; w=np.clip((q-a)@v/max(v@v,1e-20),0,1); dif=q-a-w[:,None]*v; r=np.linalg.norm(dif,axis=1); take=r<dist; dist[take]=r[take];delta[take]=dif[take]
    return dist,delta


def bake(d,plan,out):
    p,u,c,face,part,n,edges,quads,digest=geometry(d); H=int(plan.get('resolution',1024)); S=int(plan.get('supersample',2)); R=H*S
    if H not in (256,512,1024,2048) or S not in (1,2,4) or R>4096: raise ValueError('resolution budget')
    if plan.get('geometry_sha256')!=digest: raise ValueError('geometry fingerprint mismatch')
    if 'parts' not in d: raise ValueError('explicit triangle part IDs required for painting')
    out=Path(out); out.mkdir(parents=True,exist_ok=True); owner=np.full((R,R),-1,np.int32); rgb=np.zeros((R,R,3),np.uint8)
    pos=np.zeros((H,H,3),np.uint8); normal=np.zeros_like(pos); ids=np.zeros_like(pos); lo=p.min((0,1)); span=np.maximum(p.max((0,1))-lo,1e-12)
    light=np.asarray(plan.get('light',[0,1,0]),float); light/=np.linalg.norm(light); ambient=float(plan.get('ambient',.72)); strength=float(plan.get('direct',.25))
    # Orthographic upper-light depth buffer. Geometry, not UV, determines occlusion.
    ref=np.array([0.,0.,1.]) if abs(light[2])<.9 else np.array([1.,0.,0.]); right=np.cross(light,ref);right/=np.linalg.norm(right); B=np.stack([right,np.cross(right,light),light],1); proj=p@B
    low=proj[:,:,:2].min((0,1)); extent=np.maximum(proj[:,:,:2].max((0,1))-low,1e-9); M=768; depth=np.full((M,M),-np.inf); pp=(proj[:,:,:2]-low)/extent
    for t in range(len(p)):
        if abs(np.linalg.det(pp[t,1:]-pp[t,:1]))<1e-12:continue
        y,x,w=samples(pp[t],M); z=w@proj[t,:,2];depth[y,x]=np.maximum(depth[y,x],z)
    mats=plan['face_material']; palette=plan['palette']; layers=plan.get('layers',[])
    if len(mats)!=len(quads):raise ValueError('face material mapping incomplete')
    overlap=0
    for t in range(len(p)):
        y,x,w=samples(u[t],R); q=w@p[t]; m=mats[face[t]]; col=np.tile(np.asarray(palette[m],float),(len(q),1))
        for layer in layers:
            if not layer.get('enabled',True) or ('faces' in layer and int(face[t]) not in layer['faces']) or ('parts' in layer and int(part[t]) not in layer['parts']) or ('materials' in layer and m not in layer['materials']):continue
            kind=layer['kind']; radius=float(layer['width']);
            if radius<=0:raise ValueError('width must be positive')
            if kind=='stroke' or kind=='cylinder':dist,delta=stroke(q,np.asarray(layer['points'],float))
            elif kind=='dot':delta=q-np.asarray(layer['center']);dist=np.linalg.norm(delta,axis=1)
            elif kind=='plane':v=np.asarray(layer['normal'],float);v/=np.linalg.norm(v); signed=q@v-float(layer['offset']);dist=abs(signed);delta=signed[:,None]*v
            else:raise ValueError('unsupported primitive '+kind)
            a=np.clip((1-dist/radius)*4,0,1)*float(layer.get('opacity',1)); target=np.tile(np.asarray(layer['color'],float),(len(q),1))
            if kind=='cylinder' or layer.get('relief',False):target+=((delta@light/radius)*32+20*np.sqrt(np.maximum(0,1-(dist/radius)**2)))[:,None]
            col=col*(1-a[:,None])+target*a[:,None]
        if m not in plan.get('emissive_materials',[]):
            pr=q@B; xy=np.clip(((pr[:,:2]-low)/extent*M).astype(int),0,M-1); gap=depth[xy[:,1],xy[:,0]]-pr[:,2]; vis=1-np.clip((gap-.002)/.008,0,1); col*= (ambient+strength*max(0,n[t]@light)*vis)[:,None]
        overlap+=int((owner[y,x]>=0).sum());owner[y,x]=t;rgb[y,x]=np.clip(col,0,255).round().astype(np.uint8)
        yy,xx,ww=samples(u[t],H);pos[yy,xx]=np.clip((ww@p[t]-lo)/span*255,0,255).astype(np.uint8);normal[yy,xx]=((n[t]+1)*127.5).astype(np.uint8);ids[yy,xx]=[(int(face[t])+1)&255,((int(face[t])+1)>>8)&255,(int(part[t])+1)&255]
    valid=owner>=0; dist,idx=distance_transform_edt(~valid,return_indices=True); pad=(~valid)&(dist<=int(plan.get('padding',8))*S); rgb[pad]=rgb[idx[0][pad],idx[1][pad]]; fixed=rgb.copy(); best=np.full((R,R),np.inf,np.float32)
    # Transfer same-material neighbor color only into unused atlas samples; align by 3D edge endpoints.
    for e in edges.values():
        if len(e)!=2:continue
        for (t,a,b),(r,k,l) in (e,e[::-1]):
            if c[t]==c[r] or mats[face[t]]!=mats[face[r]]:continue
            A,B=u[t,a]*R,u[t,b]*R; C,D=u[r,k]*R,u[r,l]*R; v=B-A; w=D-C; L=np.linalg.norm(v); W=np.linalg.norm(w); nv=np.array([-v[1],v[0]])/L; nw=np.array([-w[1],w[0]])/W
            h=3-a-b;j=3-k-l
            if nv@(u[t,h]*R-A)<0:nv=-nv
            if nw@(u[r,j]*R-C)<0:nw=-nw
            width=int(plan.get('padding',8))*S; low2=np.maximum(0,np.floor(np.minimum(A,B)-width).astype(int)); high2=np.minimum(R,np.ceil(np.maximum(A,B)+width).astype(int));x0,y0=low2;x1,y1=high2; yy,xx=np.mgrid[y0:y1,x0:x1]; q=np.stack([xx+.5,yy+.5],-1)-A; along=q@v/L**2; dep=-(q@nv)
            ratio=lambda i,a,b,h: np.linalg.norm(np.cross(p[i,b]-p[i,a],p[i,h]-p[i,a]))/np.linalg.norm(p[i,b]-p[i,a])
            scale=(ratio(t,a,b,h)/abs(nv@(u[t,h]*R-A)))/(ratio(r,k,l,j)/abs(nw@(u[r,j]*R-C)))
            target=C+along[...,None]*w+dep[...,None]*scale*nw; tx,ty=np.clip(np.floor(target).astype(int),0,R-1).transpose(2,0,1); near=owner[idx[0][yy,xx],idx[1][yy,xx]]
            mask=(along>=0)&(along<=1)&(dep>0)&(dep<=width)&pad[yy,xx]&(near>=0)&(c[np.maximum(near,0)]==c[t])&(owner[ty,tx]==r)&(dep<best[yy,xx]);rgb[yy[mask],xx[mask]]=fixed[ty[mask],tx[mask]];best[yy[mask],xx[mask]]=dep[mask]
    assert np.array_equal(rgb[valid],fixed[valid])
    down=lambda a:a.reshape(H,S,H,S,3).mean((1,3)).round().astype(np.uint8); base=down(fixed); final=down(rgb)
    def seam(im):
        err=[]
        for e in edges.values():
            if len(e)!=2:continue
            (t,a,b),(r,k,l)=e
            if c[t]==c[r] or mats[face[t]]!=mats[face[r]]:continue
            def sample(i,a,b):
                q=np.linspace(.05,.95,19)[:,None]*(u[i,b]-u[i,a])+u[i,a]; xy=np.clip(q*H-.5,0,H-1); ix=np.floor(xy).astype(int); j=np.minimum(ix+1,H-1); f=xy-ix;x,y=ix.T;X,Y=j.T;s,t=f.T;return im[y,x]*(1-s)[:,None]*(1-t)[:,None]+im[y,X]*s[:,None]*(1-t)[:,None]+im[Y,x]*(1-s)[:,None]*t[:,None]+im[Y,X]*s[:,None]*t[:,None]
            err.append(sample(t,a,b)-sample(r,k,l))
        return {'edges':len(err),'rms':float(np.sqrt(np.mean(np.square(err)))) if err else None}
    a,b=seam(base),seam(final); use=b['rms'] is not None and b['rms']<=a['rms']; chosen=final if use else base
    for name,im in [('albedo',chosen),('position',pos),('normal_world',normal),('face_part_id',ids)]:Image.fromarray(im).save(out/(name+'.png'))
    report={'geometry_sha256':digest,'triangles':len(p),'quad_faces':sum(quads),'charts':len(set(c)),'raster_collision_samples':overlap,'padding_2d':a,'padding_neighbor':b,'neighbor_selected':bool(use),'covered_samples_changed':0,'resolution':H,'visual_approval':'pending','limitations':['raster collisions include shared-edge samples; not exact polygon overlap','fixed directional light; not physical AO','projected surface strokes are not geodesics','material assignments are authored']}
    (out/'report.json').write_text(json.dumps(report,indent=2));(out/'plan.json').write_text(json.dumps(plan,indent=2));return report


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('mesh');ap.add_argument('plan');ap.add_argument('output');args=ap.parse_args(); print(json.dumps(bake(load(args.mesh),load(args.plan),args.output),indent=2))
