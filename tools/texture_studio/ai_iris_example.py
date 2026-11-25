"""H02 V6 example only: explicit original face assignments; not generic design AI."""
import sys, json
import numpy as np
from ai_pipeline import geometry, load


def design(d):
    p,u,c,f,part,n,e,quads,digest=geometry(d)
    if d.get('source_blob_sha')!='9466c485d0674181ad832fa49f7ec5eb57b6482f' or len(p)!=396 or len(quads)!=230 or digest!='6c4c7e2995a18aeb4ac3b5195f2666f24bb39ec57d7f18f39994b18283983989':raise ValueError('H02 V6 source only')
    mats=[]
    for ts in d['source_faces']:
        t=ts[0];x,y,z=p[ts].mean((0,1));nx,ny,nz=n[t];i=part[t]
        if i<2:
            m='armor' if nz<-.35 or ny>.5 or abs(nx)>.65 else 'mechanism'
            if nz>.8 or ny<-.78 or (abs(nx)>.65 and nx*x<0):m='mechanism'
        elif i==2:m='armor' if abs(nx)>.55 or nz>.35 or ny>.5 else 'mechanism'
        elif i<5:m='mechanism'
        else:m='eye' if nz<-.12 else 'mechanism'
        mats.append(m)
    plan={'geometry_sha256':digest,'resolution':1024,'supersample':2,'padding':8,'light':[0,1,0],'ambient':.78,'direct':.22,'face_material':mats,'palette':{'armor':[195,200,204],'mechanism':[61,67,75],'eye':[54,168,194]},'emissive_materials':['eye'],'layers':[]}
    L=plan['layers']
    def line(id,points,width,color,faces,kind='stroke',relief=False):
        L.append(dict(id=id,kind=kind,points=np.asarray(points).tolist(),width=width,color=color,faces=faces,relief=relief))
    for id,v,offset,fs in [('brow',[0,.2,1],-.16,[i for i,ts in enumerate(d['source_faces']) if part[ts[0]]<2 and p[ts].mean((0,1))[1]>.26]),('rear',[0,1,.12],.30,[89,90,96,108])]:
        L.append(dict(id=id,kind='plane',normal=v,offset=offset,width=.002,color=[70,78,86],faces=fs,materials=['armor']))
    # Explicit planar original faces. Draw in an orthogonal local frame, exactly on the source plane.
    def frame(i):
        ts=d['source_faces'][i];t=ts[0];o=p[ts].mean((0,1));v=n[t];a=np.cross([0,1,0],v)
        if np.linalg.norm(a)<.1:a=np.cross([0,0,1],v)
        a/=np.linalg.norm(a);b=np.cross(v,a);return lambda x,y:o+x*a+y*b
    for i,w,h in [(89,.075,.045),(96,.063,.055),(108,.063,.055),(87,.062,.052)]:
        at=frame(i);q=[(-w,-h*.65),(-w*.78,-h),(w*.78,-h),(w,-h*.65),(w,h*.65),(w*.78,h),(-w*.78,h),(-w,h*.65),(-w,-h*.65)]
        line('hatch'+str(i),[at(*a) for a in q],.0017,[79,86,95],[i]);
        for x in [-w*.66,w*.66]:
            for y in [-h*.65,h*.65]:L.append(dict(id=f'bolt{i}_{x}_{y}',kind='dot',center=at(x,y).tolist(),width=.004,color=[102,111,121],faces=[i],relief=True))
        for k in [-2,-1,0,1,2]:line(f'vent{i}_{k}',[at(k*.014,-.016),at(k*.014,.016)],.0024,[72,79,87],[i])
    at=frame(88);theta=np.linspace(0,2*np.pi,33)
    for r,col in [(.046,[125,134,145]),(.030,[38,43,50])]:line('mount'+str(r),[at(r*np.cos(a),r*np.sin(a)) for a in theta],.005,col,[88],relief=True)
    for sign in [-1,1]:
        line('bottom_housing'+str(sign),[at(sign*.093,-.073),at(sign*.093,.015)],.017,[111,120,130],[88],'cylinder')
        line('bottom_rod'+str(sign),[at(sign*.093,.014),at(sign*.093,.073)],.006,[159,168,177],[88],'cylinder')
    # Actual cylindrical sensor faces get rings following their original geometry.
    for i in [3,4]:
        fs=[j for j,ts in enumerate(d['source_faces']) if part[ts[0]]==i]
        for z in ([-.113,-.084,-.052] if i==3 else [.05,.075]):
            L.append(dict(id=f'collar{i}_{z}',kind='plane',normal=[0,0,1],offset=z,width=.004,color=[123,132,142],faces=fs,relief=True))
    return plan

if __name__=='__main__':
    d=load(sys.argv[1]);open(sys.argv[2],'w').write(json.dumps(design(d),indent=2))
