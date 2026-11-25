"""Offline V4 contact occlusion from virtual geometry; bounded ray distance."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
from numba import njit,prange,set_num_threads
from ai_pipeline import geometry,load,samples,stroke

def bvh(tri):
    lo=tri.min(1);hi=tri.max(1);cent=(lo+hi)*.5;bounds=[];nodes=[];order=[]
    def visit(ids):
        i=len(nodes);nodes.append(None);bounds.append(np.stack((lo[ids].min(0),hi[ids].max(0))))
        if len(ids)<=12:
            nodes[i]=(-1,-1,len(order),len(ids));order.extend(ids);return i
        axis=np.argmax(np.ptp(cent[ids],axis=0));ids=ids[np.argsort(cent[ids,axis],kind='stable')];mid=len(ids)//2
        a=visit(ids[:mid]);b=visit(ids[mid:]);nodes[i]=(a,b,0,0);return i
    visit(np.arange(len(tri)));return np.asarray(bounds),np.asarray(nodes),tri[np.asarray(order)]

@njit
def hit(o,d,bounds,nodes,tris,radius,stack):
    top=1;stack[0]=0;best=radius
    while top:
        top-=1;i=stack[top];a=0.;b=best
        for k in range(3):
            if abs(d[k])<1e-12:
                if o[k]<bounds[i,0,k] or o[k]>bounds[i,1,k]:a=1.;b=0.;break
            else:
                x=(bounds[i,0,k]-o[k])/d[k];y=(bounds[i,1,k]-o[k])/d[k];a=max(a,min(x,y));b=min(b,max(x,y))
        if b<a:continue
        if nodes[i,0]>=0:
            stack[top]=nodes[i,0];stack[top+1]=nodes[i,1];top+=2;continue
        for j in range(nodes[i,2],nodes[i,2]+nodes[i,3]):
            v=tris[j];ex,ey,ez=v[1]-v[0];fx,fy,fz=v[2]-v[0];dx,dy,dz=d
            hx=dy*fz-dz*fy;hy=dz*fx-dx*fz;hz=dx*fy-dy*fx;det=ex*hx+ey*hy+ez*hz
            if abs(det)<1e-12:continue
            sx,sy,sz=o-v[0];u=(sx*hx+sy*hy+sz*hz)/det
            if u<0 or u>1:continue
            qx=sy*ez-sz*ey;qy=sz*ex-sx*ez;qz=sx*ey-sy*ex;w=(dx*qx+dy*qy+dz*qz)/det
            if w<0 or u+w>1:continue
            t=(fx*qx+fy*qy+fz*qz)/det
            if 1e-6<t<best:best=t
    return best

@njit(parallel=True)
def cast(orig,dirs,bounds,nodes,tris,radius):
    result=np.zeros(len(orig))
    for i in prange(len(orig)):
        stack=np.empty(64,np.int64);s=0.
        for j in range(len(dirs)):
            t=hit(orig[i],dirs[j],bounds,nodes,tris,radius,stack);s+=max(0.,1.-t/radius)
        result[i]=s/len(dirs)
    return result

def run(d,plan,base_path,virtual_path,height_path,out):
    p,u,c,f,part,n,edges,quads,digest=geometry(d);H=int(plan['resolution']);base=np.asarray(Image.open(base_path).convert('RGB'));height=(np.asarray(Image.open(height_path),float)/65535-.5)*.02
    if plan['geometry_sha256']!=digest or base.shape!=(H,H,3) or height.shape!=(H,H):raise ValueError('input mismatch')
    high=np.load(virtual_path,allow_pickle=False)['triangles'].astype(float)
    if high.ndim!=3 or high.shape[1:]!=(3,3) or not np.isfinite(high).all() or len(high)>2000000:raise ValueError('invalid virtual mesh')
    bounds,nodes,tris=bvh(high);set_num_threads(min(4,__import__('numba').get_num_threads()))
    scale=np.linalg.norm(np.ptp(p.reshape(-1,3),axis=0));radius=scale*.095;bias=scale*.00065;K=16;owner=np.full((H,H),-1,np.int32);ao=np.zeros((H,H));curv=np.zeros_like(ao);em=np.zeros((H,H),bool);edge_info={}
    for e in edges.values():
        if len(e)!=2:continue
        (t,a,b),(r,k,l)=e
        if f[t]==f[r]:continue
        angle=np.arccos(np.clip(n[t]@n[r],-1,1));signed=np.dot(n[t],p[r,3-k-l]-p[t,a])+np.dot(n[r],p[t,3-a-b]-p[r,k]);kind=1 if signed< -1e-8 else -1 if signed>1e-8 else 0
        if angle<np.deg2rad(12) or not kind:continue
        for i,j,m in ((t,a,b),(r,k,l)):edge_info.setdefault(int(f[i]),[]).append((p[i,[j,m]],kind,min(angle/(np.pi/2),1)))
    for t in range(len(p)):
        y,x,w=samples(u[t],H);q=w@p[t];owner[y,x]=t;mat=plan['face_material'][f[t]]
        if mat in plan.get('emissive_materials',[]):em[y,x]=True;continue
        normal=n[t];ref=np.array([0.,1.,0.]) if abs(normal[1])<.9 else np.array([1.,0.,0.]);a=np.cross(normal,ref);a/=np.linalg.norm(a);b=np.cross(normal,a)
        j=np.arange(K);z=np.sqrt(1-(j+.5)/K);r=np.sqrt(1-z*z);phi=j*2.399963229728653
        dirs=(r*np.cos(phi))[:,None]*a+(r*np.sin(phi))[:,None]*b+z[:,None]*normal
        o=q+(height[y,x]+bias)[:,None]*normal;ao[y,x]=cast(o,dirs,bounds,nodes,tris,radius)
        v=np.zeros(len(q));neg=v.copy()
        for seg,kind,weight in edge_info.get(int(f[t]),[]):
            dist=stroke(q,seg)[0];signal=np.exp(-dist/(scale*.0025))*weight
            if kind>0:v=np.maximum(v,signal)
            else:neg=np.maximum(neg,signal)
        curv[y,x]=v-neg
    valid=owner>=0;out=Path(out);out.mkdir(parents=True,exist_ok=True)
    # Protect the original bake at chart borders, including its neighbor padding.
    chart_map=np.where(valid,c[np.maximum(owner,0)],-1);fade=np.zeros_like(ao)
    for chart in np.unique(c):
        yy,xx=np.where(chart_map==chart)
        if not len(yy):continue
        y0=max(0,yy.min()-6);y1=min(H,yy.max()+7);x0=max(0,xx.min()-6);x1=min(H,xx.max()+7)
        mask=chart_map[y0:y1,x0:x1]==chart;distance=distance_transform_edt(np.pad(mask,1))[1:-1,1:-1];fade[y0:y1,x0:x1][mask]=np.clip((distance[mask]-2)/3,0,1)
    report={'geometry_sha256':digest,'triangles':len(p),'virtual_triangles':len(high),'rays_per_texel':K,'radius':radius,'bias':bias,'covered':int(valid.sum()),'emissive':int(em.sum()),'ao_mean':float(ao[valid&~em].mean()),'ao_p95':float(np.percentile(ao[valid&~em],95)),'curvature_faces':len(edge_info),'candidates':[],'visual_approval':'pending','boundary_protection':'2px protected, 3px ramp; preserve original padding'}
    for name,strength,edge in [('subtle',.16,.035),('balanced',.28,.06),('strong',.42,.09)]:
        gain=np.clip(1+fade*(-strength*ao+edge*curv),.68,1.12);gain[em]=1;final=np.clip(base.astype(float)*gain[:,:,None],0,255).round().astype(np.uint8);Image.fromarray(final).save(out/(name+'.png'));report['candidates'].append({'name':name,'ao_strength':strength,'edge_strength':edge,'modified_covered':int((np.any(final!=base,axis=2)&valid).sum()),'emissive_changed':int((np.any(final!=base,axis=2)&em).sum()),'mean_gain':float(gain[valid].mean())})
    Image.fromarray(np.round((1-ao)*255).astype(np.uint8)).save(out/'ao.png');Image.fromarray(np.round((curv*.5+.5)*255).astype(np.uint8)).save(out/'curvature.png');(out/'report.json').write_text(json.dumps(report,indent=2));return report
if __name__=='__main__':
    ap=argparse.ArgumentParser();[ap.add_argument(x) for x in ('mesh','plan','base','virtual','height','out')];a=ap.parse_args();print(json.dumps(run(load(a.mesh),load(a.plan),a.base,a.virtual,a.height,a.out),indent=2))
