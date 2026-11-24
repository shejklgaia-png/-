"""Compare independently supplied reference masks with actual renders.
Masks: transparent PNG alpha or explicitly segmented grayscale white foreground.
Reference manifests never inferred from model output.
"""
import json
import math
import sys
from pathlib import Path
from PIL import Image, ImageChops

VIEWS = {"front","back","left","right","top","bottom","front_3q","back_3q"}
SIZE = 768

def uniform_background_mask(im, tolerance=20):
    """Remove only border-connected pixels near a uniform background color.
    Preserve interior same-color details. Reject nonuniform borders.
    """
    if not 0 <= tolerance <= 80:
        raise ValueError("background tolerance must be 0..80")
    rgb = im.convert("RGB")
    w,h = rgb.size
    if min(w,h)<3 or w*h>16_000_000:
        raise ValueError("reference size outside supported range")
    p=rgb.load()
    border=[p[x,0] for x in range(w)]+[p[x,h-1] for x in range(w)]+[p[0,y] for y in range(1,h-1)]+[p[w-1,y] for y in range(1,h-1)]
    bg=tuple(sorted(v[i] for v in border)[len(border)//2] for i in range(3))
    def close(v):
        return max(abs(v[i]-bg[i]) for i in range(3)) <= tolerance
    if sum(close(v) for v in border)/len(border)<.98:
        raise ValueError("nonuniform or obstructed image border; use a manual mask")
    # Flood fill a binary candidate image from an external padded border.
    from PIL import ImageDraw
    candidates=Image.new("L",(w+2,h+2),255)
    inner=Image.new("L",(w,h))
    inner.putdata([255 if close(v) else 0 for v in rgb.getdata()])
    candidates.paste(inner,(1,1))
    ImageDraw.floodfill(candidates,(0,0),128)
    return candidates.crop((1,1,w+1,h+1)).point(lambda v:0 if v==128 else 255)

def mask(path, mode, tolerance=20):
    with Image.open(path) as im:
        if mode == "alpha":
            if "A" not in im.getbands() and "transparency" not in im.info:
                raise ValueError("alpha mask required: "+str(path))
            channel = im.convert("RGBA").getchannel("A")
        elif mode == "white":
            channel = im.convert("L")
        elif mode == "uniform_background":
            channel = uniform_background_mask(im,tolerance)
        else:
            raise ValueError("mask mode must be alpha, white or uniform_background")
        result = channel.point(lambda x: 255 if x >= 128 else 0)
    if not result.getbbox() or result.getbbox() == (0,0,*result.size) and result.histogram()[255] == result.width*result.height:
        raise ValueError("empty or entirely foreground mask")
    return result

def normalized(im):
    x0,y0,x1,y1 = im.getbbox()
    w,h = x1-x0,y1-y0
    scale = (SIZE-32)/max(w,h)
    nw,nh = max(1,round(w*scale)),max(1,round(h*scale))
    dx,dy = (SIZE-nw)//2,(SIZE-nh)//2
    canvas = Image.new("L",(SIZE,SIZE))
    canvas.paste(im.crop((x0,y0,x1,y1)).resize((nw,nh),Image.Resampling.NEAREST),(dx,dy))
    def transform(p):
        return ((p[0]-x0)*nw/w+dx,(p[1]-y0)*nh/h+dy)
    return canvas,transform

def count(im):
    return im.histogram()[255]

def compare(ref,model,ref_points,model_points,alignment):
    if alignment == "bbox":
        a,ta = normalized(ref)
        b,tb = normalized(model)
    elif alignment == "fixed":
        if ref.size != model.size:
            raise ValueError("fixed comparison requires equal image sizes")
        a,b = ref,model
        ta=tb=lambda p:p
    else:
        raise ValueError("alignment must be bbox or fixed")
    both = ImageChops.darker(a,b)
    missing = ImageChops.subtract(a,b)
    extra = ImageChops.subtract(b,a)
    intersection,union=count(both),count(ImageChops.lighter(a,b))
    overlay = Image.merge("RGB",(ImageChops.lighter(both,missing),both,ImageChops.lighter(both,extra)))
    box=a.getbbox()
    diag=math.hypot(box[2]-box[0],box[3]-box[1])
    errors={}
    for label,p in ref_points.items():
        if label not in model_points:
            raise ValueError("missing model landmark "+label)
        if len(p)!=2 or not all(math.isfinite(v) for v in p) or not (0<=p[0]<=ref.width and 0<=p[1]<=ref.height):
            raise ValueError("invalid reference landmark "+label)
        errors[label]=math.dist(ta(p),tb(model_points[label]))/diag
    def aspect(im):
        x0,y0,x1,y1=im.getbbox()
        return (x1-x0)/(y1-y0)
    return {"iou":intersection/union,"missing_pixels":count(missing),"extra_pixels":count(extra),
            "reference_aspect":aspect(ref),"model_aspect":aspect(model),
            "landmark_error_fraction_bbox_diagonal":errors,
            "mean_landmark_error":sum(errors.values())/len(errors) if errors else None},overlay

def main():
    root,manifest,out=map(lambda p:Path(p).resolve(),sys.argv[1:])
    spec=json.loads(manifest.read_text())
    if spec.get("format")!="SERA_REFERENCE_REVIEW_V1":
        raise ValueError("wrong manifest format")
    projections=json.loads((root/"projections.json").read_text())
    views=spec["views"]
    if not views or not set(views)<=VIEWS:
        raise ValueError("unknown or empty view set")
    out.mkdir(parents=True,exist_ok=False)
    scores={}
    for name,s in views.items():
        if s.get("projection")!="orthographic":
            raise ValueError("only matching orthographic reference views supported")
        path=(manifest.parent/s["mask"]).resolve()
        if not path.is_relative_to(manifest.parent):
            raise ValueError("reference must be inside manifest directory")
        a=mask(path,s["mode"],s.get("background_tolerance",20))
        a.save(out/(name+"_reference_mask.png"))
        b=mask(root/(name+".png"),"alpha")
        report,overlay=compare(a,b,s.get("landmarks",{}),projections[name]["landmarks"],s.get("alignment","fixed"))
        report["alignment"]=s.get("alignment","fixed")
        report["mask_mode"]=s["mode"]
        report["mask_requires_visual_review"]=s["mode"]=="uniform_background"
        scores[name]=report
        overlay.save(out/(name+"_overlay.png"))
    report={"format":"SERA_REFERENCE_RESULT_V1","views":scores,
            "mean_iou":sum(v["iou"] for v in scores.values())/len(scores),
            "visual_acceptance":"not_reviewed",
            "limits":"Only the supplied matching views are measured; bbox alignment removes translation and uniform scale. Hidden surfaces, depth, color and function are not established."}
    (out/"reference_review.json").write_text(json.dumps(report,indent=2),encoding="utf-8")

if __name__=="__main__":
    main()
