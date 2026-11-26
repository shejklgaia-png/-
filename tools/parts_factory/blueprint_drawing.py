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
        im=Image.new("RGB",(size,size),"#F5F7F9");draw=ImageDraw.Draw(im)
        # Back-to-front drawing patches; independent from Modeling Studio mesh production.
        ordered=sorted(patches,key=lambda p:sum(dot(v,n) for v in p["points"])/len(p["points"]))
        for patch in ordered:
            # Explicit drafting face direction, not a material or mesh normal claim.
            face=patch.get("visible_from")
            if face is not None:
                q.need(len(face)==3 and all(type(x) in (int,float) and math.isfinite(x) for x in face),"invalid drafting direction")
                if dot(norm(face),n)<=.035:continue
            pts=[proj(v) for v in patch["points"]]
            area=abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(pts,pts[1:]+pts[:1])))/2
            if area<1:continue
            draw.polygon(pts,fill=COLORS[patch["material"]])
            draw.line(pts+[pts[0]],fill="#243442",width=2,joint="curve")
        # Pure draft, no fake certification or measured mesh values.
        dest=out/(name+".png");im.save(dest)
        views[name]={"file":dest.name,"sha256":f.digest(dest),"notes":"Shared-scale design projection; hidden surfaces are authored proposals, not observed geometry."}
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
    draw.text((40,1006),"W 5.90  /  H 5.60  /  D 6.10   |   NECK APERTURE 2.50 x 2.50   |   PROPOSED SOURCE UNITS - NOT MEASURED",fill="#334E62",font=font(18))
    board.save(out/"blueprint.png")
    f.write(out/"drawing_receipt.json",{"status":"unapproved_draft","source_art_sha256":f.digest(art),
        "source_sha256":f.digest(out/"drawing_source.json"),"views":views,"blueprint_sha256":f.digest(out/"blueprint.png"),
        "units":"Blockbench source units; no metre conversion or collision verification",
        "proposed_bounds":[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)],
        "limits":"2D drafting via common projected patch outlines. Occlusion is approximate. No mesh, UV, game geometry or aesthetic approval."})
