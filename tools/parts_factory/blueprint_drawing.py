"""Technical drafting from authored 3D landmarks and panel outlines.
Produces 2D design evidence, never a production mesh or an approved blueprint.
Coordinates are draft Blockbench units, X right, Y rear, Z up.
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import factory as f
from reference_bridge import DIRECTIONS
import quality_gates as q

COLORS={"armor":"#E1E5E7","facet":"#BBC5CD","frame":"#303A42",
        "rim":"#52616E","recess":"#182128","optic":"#78DAF7","latch":"#B55E2D"}
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(v):
    n=math.sqrt(dot(v,v));q.need(n>0,"invalid projection vector");return tuple(x/n for x in v)

def render(out,spec,art,concept):
    q.need(spec.get("format")=="SERA_PF_DRAFT_DRAWING_V1","invalid drawing format")
    q.need(spec.get("selected_art_sha256")==f.digest(art),"drawing does not refer to selected art")
    q.need(spec.get("revision") in ("draft","rebuilt"),"draft or rebuilt drawing required")
    patches=spec["patches"]
    q.need(12<=len(patches)<=200,"drawing patch count")
    names=set()
    points=[]
    for p in patches:
        q.need(p["name"] not in names and p["material"] in COLORS,"drawing patch identity")
        names.add(p["name"])
        pts=p["points"]
        q.need(3<=len(pts)<=12 and all(len(v)==3 and all(type(x) in (int,float) and math.isfinite(x) and abs(x)<=10 for x in v) for v in pts),"invalid drafting points")
        points.extend(pts)
    out.mkdir(parents=True,exist_ok=False)
    f.write(out/"drawing_source.json",spec)
    size=640;scale=74;center=(size/2,size/2);target=(0,0,2.8)
    views={}
    for name in q.BLUEPRINT_VIEWS:
        n=norm(DIRECTIONS[name])
        right=(1,0,0) if name in ("top","bottom") else norm(cross((0,0,1),n))
        up=(0,1 if name=="top" else -1,0) if name in ("top","bottom") else cross(n,right)
        def proj(p):
            v=sub(p,target)
            return (center[0]+scale*dot(v,right),center[1]-scale*dot(v,up))
        import numpy as np
        from PIL import ImageColor
        depth=np.full((size,size),-np.inf)
        ids=np.full((size,size),-1,dtype=np.int32)
        rgb=np.empty((size,size,3),dtype=np.uint8);rgb[:]=ImageColor.getrgb("#F5F7F9")
        for idx,patch in enumerate(patches):
            face=patch.get("visible_from")
            if face is not None and dot(norm(face),n)<=.035:continue
            vertices=[(*proj(v),dot(v,n)) for v in patch["points"]]
            # Ear clipping in the projected plane preserves concave panel outlines.
            poly=list(range(len(vertices)))
            def orient(a,b,c):
                return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
            signed=sum(vertices[i][0]*vertices[(i+1)%len(vertices)][1]-vertices[(i+1)%len(vertices)][0]*vertices[i][1] for i in poly)
            if abs(signed)<1e-6:continue
            if signed<0:poly.reverse()
            tris=[]
            while len(poly)>3:
                found=False
                for j,b in enumerate(poly):
                    a,c=poly[j-1],poly[(j+1)%len(poly)]
                    A,B,C=[vertices[k] for k in (a,b,c)]
                    if orient(A,B,C)<=1e-8:continue
                    if any(min(orient(A,B,vertices[k]),orient(B,C,vertices[k]),orient(C,A,vertices[k]))>1e-8 for k in poly if k not in (a,b,c)):continue
                    tris.append((a,b,c));poly.pop(j);found=True;break
                if not found:break
            if len(poly)==3:tris.append(tuple(poly))
            for tri in tris:
                a,b,c=np.array([vertices[k] for k in tri])
                area=orient(a,b,c)
                if abs(area)<1e-8:continue
                x0=max(0,int(math.floor(min(a[0],b[0],c[0]))));x1=min(size,int(math.ceil(max(a[0],b[0],c[0])))+1)
                y0=max(0,int(math.floor(min(a[1],b[1],c[1]))));y1=min(size,int(math.ceil(max(a[1],b[1],c[1])))+1)
                if x0>=x1 or y0>=y1:continue
                yy,xx=np.mgrid[y0:y1,x0:x1];xx=xx+.5;yy=yy+.5
                u=((b[0]-xx)*(c[1]-yy)-(b[1]-yy)*(c[0]-xx))/area
                v=((c[0]-xx)*(a[1]-yy)-(c[1]-yy)*(a[0]-xx))/area
                w=1-u-v;z=u*a[2]+v*b[2]+w*c[2]
                d=depth[y0:y1,x0:x1]
                mask=(u>=-1e-8)&(v>=-1e-8)&(w>=-1e-8)&(z>=d)
                d[mask]=z[mask];ids[y0:y1,x0:x1][mask]=idx
                rgb[y0:y1,x0:x1][mask]=ImageColor.getrgb(COLORS[patch["material"]])
        # Visible panel boundaries only; no hidden or edge-on floating strokes.
        edge=np.zeros_like(ids,dtype=bool)
        edge[1:,:]|=ids[1:,:]!=ids[:-1,:]
        edge[:,1:]|=ids[:,1:]!=ids[:,:-1]
        rgb[edge&(ids>=0)]=ImageColor.getrgb("#243442")
        im=Image.fromarray(rgb)
        # Pure draft, no fake certification or measured mesh values.
        dest=out/(name+".png");im.save(dest)
        views[name]={"file":dest.name,"sha256":f.digest(dest),"notes":"Shared-scale design projection; hidden surfaces are authored proposals, not observed geometry."}
    bounds=[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]
    width,depth,height=(b[1]-b[0] for b in bounds)
    aperture=spec.get("neck_aperture",{})
    w,h=2000,1050
    board=Image.new("RGB",(w,h),"#E7EDF2");draw=ImageDraw.Draw(board)
    def font(n):
        try:return ImageFont.truetype("DejaVuSans.ttf",n)
        except OSError:return ImageFont.load_default()
    draw.text((38,20),"KITE  /  HEAD SHELL    |    TECHNICAL DESIGN "+spec["revision"].upper(),fill="#172838",font=font(35))
    draw.text((40,69),"A2 reference  /  common orthographic axes  /  proposed Blockbench units  /  NOT APPROVED",fill="#334E62",font=font(20))
    labels=list(q.BLUEPRINT_VIEWS)
    for i,name in enumerate(labels):
        x=24+(i%5)*396;y=112+(i//5)*440
        tile=Image.open(out/(name+".png")).resize((380,380),Image.Resampling.LANCZOS)
        board.paste(tile,(x,y+34))
        draw.text((x+8,y+5),name.replace("_"," ").upper(),fill="#172838",font=font(20))
    draw.text((40,1006),f"W {width:.2f}  /  H {height:.2f}  /  D {depth:.2f}   |   NECK APERTURE {aperture.get('width',0):.2f} x {aperture.get('depth',0):.2f}   |   PROPOSED SOURCE UNITS - NOT MEASURED",fill="#334E62",font=font(18))
    board.save(out/"blueprint.png")
    f.write(out/"drawing_receipt.json",{"status":"unapproved_draft","source_art_sha256":f.digest(art),
        "source_sha256":f.digest(out/"drawing_source.json"),"views":views,"blueprint_sha256":f.digest(out/"blueprint.png"),
        "units":"Blockbench source units; no metre conversion or collision verification",
        "proposed_bounds":bounds,
        "limits":"2D drafting via common projected patch outlines. Per-pixel orthographic depth; authored nonplanar outlines remain approximations. No mesh, UV, game geometry or aesthetic approval."})
