"""V2: source-face descriptors, surface strokes and reusable actuator recipe."""
import argparse, json
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree
from ai_pipeline import geometry, load, bake


def inspect(d):
    p,u,c,f,part,n,edges,quads,digest=geometry(d)
    area=np.linalg.norm(np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]),axis=1)/2
    fs=d['source_faces']; center=np.array([np.average(p[t].mean(1),axis=0,weights=area[t]) for t in fs]); size=np.array([area[t].sum() for t in fs]); normals=np.array([np.average(n[t],axis=0,weights=area[t]) for t in fs]); normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
    adj=[[] for _ in fs]; links=[]
    for (_,key),e in edges.items():
        if len(e)!=2:continue
        a,b=[int(f[t[0]]) for t in e]; angle=float(np.degrees(np.arccos(np.clip(normals[a]@normals[b],-1,1)))); adj[a].append(b);adj[b].append(a);links.append({'faces':[a,b],'angle_deg':angle,'length':float(np.linalg.norm(np.subtract(*key)))})
    scale=np.linalg.norm(np.ptp(p.reshape(-1,3),axis=0)); mirror=np.array([-1,1,1]); target=center*mirror; tree=cKDTree(center); partner=np.full(len(fs),-1,int)
    for i,point in enumerate(target):
        candidates=tree.query_ball_point(point,.015*scale)
        valid=[j for j in candidates if (normals[i]*mirror)@normals[j]>.96 and .85<size[i]/size[j]<1.18]
        if valid:partner[i]=min(valid,key=lambda j:(np.linalg.norm(point-center[j])/scale+.2*(1-(normals[i]*mirror)@normals[j])+.1*abs(np.log(size[i]/size[j])),j))
    rows=[]
    for i,ts in enumerate(fs):
        j=int(partner[i]); valid=j>=0 and partner[j]==i
        rows.append({'id':i,'part':int(part[ts[0]]),'quad':bool(quads[i]),'area':float(size[i]),'center':center[i].tolist(),'normal':normals[i].tolist(),'neighbors':sorted(set(adj[i])),'mirror_candidate':j if valid else None,'max_dihedral_deg':max([v['angle_deg'] for v in links if i in v['faces']],default=0)})
    return {'geometry_sha256':digest,'faces':rows,'shared_edges':links,'limitations':['X=0 reflection assumes model symmetry axis','descriptors are not semantic recognition','unsigned dihedral is not signed curvature']}


def plane_strokes(d, faces, normal, offset, width, color, name):
    """Intersect actual triangles with a plane; stroke width uses model units."""
    p,u,c,f,part,n,edges,quads,digest=geometry(d); v=np.asarray(normal,float); v/=np.linalg.norm(v); result=[]
    for i in sorted(set(faces)):
        for t in d['source_faces'][i]:
            tri=p[t]; s=tri@v-offset; pts=[]
            if np.max(abs(s))<1e-10:continue
            for a,b in ((0,1),(1,2),(2,0)):
                if abs(s[a])<1e-10:pts.append(tri[a])
                if s[a]*s[b]<-1e-20:pts.append(tri[a]+(tri[b]-tri[a])*s[a]/(s[a]-s[b]))
            if len(pts)<2:continue
            pair=max(((a,b) for a in pts for b in pts),key=lambda ab:np.linalg.norm(ab[0]-ab[1]))
            if np.linalg.norm(pair[0]-pair[1])<1e-9:continue
            result.append(dict(id=f'{name}_{t}',kind='stroke',points=np.asarray(pair).tolist(),width=width,color=color,faces=[i]))
    return result


def actuator(d, face, name, length, radius, direction=(0,0,1)):
    """Return a local actuator recipe; reject sampled footprints outside the face."""
    p,u,c,f,part,n,edges,quads,digest=geometry(d); ts=d['source_faces'][face]; tri=p[ts]; o=tri.mean((0,1)); normal=n[ts[0]]
    if np.min(n[ts]@normal)<.999 or np.max(abs((tri-o)@normal))>1e-5:raise ValueError('non-planar face')
    a=np.asarray(direction,float);a-=normal*(a@normal)
    if np.linalg.norm(a)<1e-8:raise ValueError('axis normal to face')
    a/=np.linalg.norm(a); b=np.cross(normal,a)
    def at(x,y=0):return o+x*a+y*b
    def inside(q):
        for t in tri:
            uv=np.linalg.lstsq((t[1:]-t[0]).T,q-t[0],rcond=None)[0]
            if min(uv)>=-1e-8 and uv.sum()<=1+1e-8:return True
        return False
    if not all(inside(at(x,y)) for x in np.linspace(-length/2-radius,length/2+radius,17) for y in np.linspace(-radius*1.4,radius*1.4,7)):raise ValueError('actuator footprint exceeds face')
    def line(s,x0,x1,w,col,kind='cylinder'):
        return dict(id=name+'_'+s,kind=kind,points=[at(x0).tolist(),at(x1).tolist()],width=w,color=col,faces=[face])
    return [line('recess',-length*.49,length*.49,radius*1.3,[29,34,40],'stroke'),line('housing',-length*.43,-length*.04,radius,[89,99,110]),line('rod',-length*.04,length*.43,radius*.43,[154,165,175]),line('collar_a',-length*.43,-length*.39,radius*1.12,[112,122,132]),line('collar_b',-length*.07,-length*.025,radius*1.1,[110,120,131]),line('mount',length*.37,length*.44,radius*.85,[99,108,118])]


def refine(d, plan):
    info=inspect(d)
    if info['geometry_sha256']!='6c4c7e2995a18aeb4ac3b5195f2666f24bb39ec57d7f18f39994b18283983989':raise ValueError('H02 example only')
    plan=json.loads(json.dumps(plan)); added=[]; skipped=[]
    old=next(x for x in plan['layers'] if x['id']=='brow'); plan['layers']=[x for x in plan['layers'] if x['id']!='brow']; faces=[i for i in old['faces'] if plan['face_material'][i]=='armor']; added+=plane_strokes(d,faces,old['normal'],old['offset'],old['width'],old['color'],'brow_surface')
    # Open the underside of the brow visually, as an exposed mechanism.
    for i in [20,62]:plan['face_material'][i]='mechanism'
    for i in [20,62,102,114,103,115]:
        for axis in [(0,0,1),(0,1,0),(1,0,0)]:
            try:
                recipe=actuator(d,i,'actuator_'+str(i),.065,.009,axis);added+=recipe;break
            except ValueError:continue
        else:skipped.append(i)
    # Paired fasteners on large original armor faces; inset along the longest span.
    p,_,_,_,_,_,_,_,_=geometry(d)
    for i in [27,70,25,68,97,109,99,111]:
        tri=p[d['source_faces'][i]]; verts=np.unique(tri.reshape(-1,3),axis=0); o=verts.mean(0)
        if len(verts)<4:continue
        a,b=max(((a,b) for a in verts for b in verts),key=lambda ab:np.linalg.norm(ab[0]-ab[1]))
        for j,v in enumerate((a,b)):
            q=.58*v+.42*o
            added.append(dict(id=f'fastener_{i}_{j}',kind='dot',center=q.tolist(),width=.0036,color=[91,98,106],faces=[i],relief=True))
    plan['layers']+=added
    return plan,{'added_layers':len(added),'actuator_faces_skipped':skipped,'surface_stroke_segments':sum(x['id'].startswith('brow_surface') for x in added)}


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('mesh');ap.add_argument('plan');ap.add_argument('output');a=ap.parse_args();d=load(a.mesh);plan=load(a.plan);out=Path(a.output);out.mkdir(parents=True,exist_ok=True)
    (out/'structure.json').write_text(json.dumps(inspect(d),indent=2));plan,report=refine(d,plan);(out/'refinement.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));print(json.dumps(bake(d,plan,out),indent=2))
