"""V6: non-destructive connected, planar surface assemblies on a locked UV base."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from shapely.geometry import Polygon, LineString, Point
from shapely.ops import unary_union
from scipy.ndimage import label
from ai_pipeline import geometry,load,samples,stroke
from ai_finish import fingerprint,filehash

MATERIALS={'steel':(np.array([109,119,129]),.85,.38),'dark_alloy':(np.array([72,80,88]),.65,.48),'rubber':(np.array([34,38,43]),0.,.83),'paint':(np.array([152,156,161]),0.,.65)}

def components(recipe):
    """Polyline tube with collars at both ends; optional fin bank on common spine."""
    path=np.asarray(recipe['path'],float); r=float(recipe['radius']); k=recipe['kind']; mat=recipe['material']
    if path.ndim!=2 or path.shape[1]!=2 or len(path)<2 or not np.isfinite(path).all() or not np.isfinite(r) or r<=0 or min(np.linalg.norm(np.diff(path,axis=0),axis=1))<=2*r:raise ValueError('invalid path')
    if k not in ('pipe','cooler') or mat not in MATERIALS:raise ValueError('invalid kind/material')
    def tube(name,points,width,material):
        return (name,np.asarray(points),width,material,LineString(points).buffer(width,quad_segs=12))
    parts=[tube('spine',path,r,mat)]
    for i,j in [(0,1),(-1,-2)]:
        a=path[i];v=path[j]-a;v/=np.linalg.norm(v);parts.append(tube('collar', [a,a+v*r*1.25],r*1.45,'steel'))
    if k=='cooler':
        if len(path)!=2:raise ValueError('cooler must have straight spine')
        a,b=path;v=(b-a)/np.linalg.norm(b-a);w=np.array([-v[1],v[0]]);count=int(recipe.get('count',5));span=float(recipe['fin_span']);fr=float(recipe['fin_radius'])
        if not 2<=count<=12 or not 0<fr<r or span<=r:raise ValueError('invalid fins')
        for t in np.linspace(.20,.80,count):
            q=a+(b-a)*t;parts.append(tube('fin',[q-w*span,q+w*span],fr,'dark_alloy'))
    if any(not parts[0][4].intersects(x[4]) for x in parts[1:]):raise ValueError('disconnected assembly')
    return parts

def render(d,plan,base_path,out):
    p,u,c,f,part,n,edges,quads,digest=geometry(d); H=int(plan['resolution'])
    if fingerprint(d)!=plan['mesh_sha256'] or filehash(base_path)!=plan['base_sha256']:raise ValueError('input hash mismatch')
    base=np.asarray(Image.open(base_path).convert('RGB'));out=Path(out);out.mkdir(parents=True,exist_ok=True)
    if base.shape!=(H,H,3):raise ValueError('resolution mismatch')
    col=base.astype(float);mask=np.zeros((H,H),bool);metal=np.zeros((H,H),float);rough=np.zeros_like(metal);coverage=np.zeros_like(metal);stats=[];ids=set();occupied={}
    for recipe in plan['assemblies']:
        rid=recipe['id'];i=int(recipe['face']);ts=d['source_faces'][i];tri=p[ts];normal=n[ts[0]];o=tri.mean((0,1))
        if rid in ids:raise ValueError('duplicate assembly')
        ids.add(rid)
        if not recipe.get('enabled',True):stats.append({'id':rid,'status':'disabled'});continue
        if np.min(n[ts]@normal)<.999 or np.max(abs((tri-o)@normal))>1e-5:stats.append({'id':rid,'status':'nonplanar'});continue
        a=np.cross([0.,1.,0.],normal)
        if np.linalg.norm(a)<.1:a=np.cross([0.,0.,1.],normal)
        a/=np.linalg.norm(a);b=np.cross(normal,a);frame=np.stack([a,b],1)
        poly=unary_union([Polygon(q) for q in (tri-o)@frame]);pieces=components(recipe);foot=unary_union([x[4] for x in pieces]);margin=float(plan.get('margin',.008))
        if not poly.buffer(-margin).covers(foot):stats.append({'id':rid,'status':'outside_face'});continue
        if i in occupied and occupied[i].intersects(foot):stats.append({'id':rid,'status':'assembly_overlap'});continue
        y,x,q=[],[],[]
        for t in ts:
            yy,xx,w=samples(u[t],H);y.extend(yy);x.extend(xx);q.extend((w@p[t]-o)@frame)
        y,x,q=np.asarray(y),np.asarray(x),np.asarray(q);lum=base[y,x].mean(1);lo,hi=recipe.get('luma_range',[15,85]);safe=np.clip((lum-lo)/8,0,1)*np.clip((hi-lum)/8,0,1)
        layer=col[y,x].copy();mm=np.zeros(len(q));rr=mm.copy();cover=mm.copy();light=np.array([a[1],b[1]]);visibility=[];spine=None
        for name,path,r,material,shape in pieces:
            dist,delta=stroke(q,path);alpha=np.clip((1-dist/r)*5,0,1)*safe;opaque=alpha>.4;visibility.append(float((opaque&(dist<r*.85)).sum()/max(1,(dist<r*.85).sum())))
            if name=='spine':spine=opaque
            elif not np.any(opaque&spine):visibility[-1]=0.
            rgb,m,roughness=MATERIALS[material];profile=np.sqrt(np.maximum(0,1-(dist/r)**2));shade=.52+.40*profile+.20*np.clip(delta@light/r,-1,1);target=rgb*shade[:,None];layer=layer*(1-alpha[:,None])+target*alpha[:,None];mm=mm*(1-alpha)+m*alpha;rr=rr*(1-alpha)+roughness*alpha;cover=1-(1-cover)*(1-alpha)
        # Reject if a luminance mask erases a connection, or fragments the visible assembly.
        binary=np.zeros((H,H),bool);binary[y,x]=cover>.4;_,count=label(binary,structure=np.ones((3,3))); # UV charts may split a face; use per-component contact as primary gate.
        if min(visibility)<.50 or (len(set(c[ts]))==1 and count!=1):stats.append({'id':rid,'status':'masked_connection','visibility':visibility});continue
        col[y,x]=layer;mask[y,x]|=cover>0;coverage[y,x]=cover;metal[y,x]=np.divide(mm,cover,out=np.zeros_like(mm),where=cover>0);rough[y,x]=np.divide(rr,cover,out=np.zeros_like(rr),where=cover>0);occupied[i]=foot if i not in occupied else occupied[i].union(foot);stats.append({'id':rid,'status':'applied','components':len(pieces),'min_visibility':min(visibility),'uv_components':int(count)})
    candidates=[]
    for strength in (.55,.8,1.):
        im=np.clip(base+(col-base)*strength,0,255).round().astype(np.uint8);diff=np.any(im!=base,axis=2);assert not np.any(diff&~mask);name=f'finish_{int(strength*100)}.png';Image.fromarray(im).save(out/name);candidates.append({'file':name,'changed_pixels':int(diff.sum()),'outside_mask_changed':0})
    for name,v in [('overlay_mask',coverage),('overlay_metallic',metal),('overlay_roughness',rough)]:Image.fromarray(np.round(v*255).astype(np.uint8)).save(out/(name+'.png'))
    report={'mesh_sha256':fingerprint(d),'base_sha256':filehash(base_path),'assemblies':stats,'candidates':candidates,'visual_approval':'pending','limitations':['planar single-face assemblies; UV raster base fixed','polygon buffer is finite approximation','material channels are overlay values with separate alpha mask only, not full PBR maps','projected fixed top light, no dynamic reflection']};(out/'report.json').write_text(json.dumps(report,indent=2));(out/'plan.json').write_text(json.dumps(plan,indent=2));return report

if __name__=='__main__':
    ap=argparse.ArgumentParser();[ap.add_argument(x) for x in ('mesh','plan','base','out')];a=ap.parse_args();print(json.dumps(render(load(a.mesh),load(a.plan),a.base,a.out),indent=2))
