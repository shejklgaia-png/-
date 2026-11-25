"""Compare rendered primary silhouette with independently traced approximate reference polygons.
No automatic visual approval; same shared camera scale and ground alignment."""
import sys,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops

def main(root):
    spec=json.loads((root/"design.json").read_text())
    cfg=spec["blockout_reference"]
    out=root/"blockout_review"
    out.mkdir(exist_ok=False)
    n=spec["review_resolution"]
    step=cfg["meters_per_trace_px"]*n/cfg["scale"]
    results={}
    for view,data in cfg["views"].items():
        ox,oy=data["origin"]
        mask=Image.new("L",(n,n))
        draw=ImageDraw.Draw(mask)
        for polygon in data["polygons"]:
            draw.polygon([(round(n/2+(x-ox)*step),round(n/2+(y-oy)*step+cfg["target_z"]*n/cfg["scale"])) for x,y in polygon],fill=255)
        actual=Image.open(root/(view+".png")).convert("RGBA").getchannel("A").point(lambda v:255 if v>=128 else 0)
        if actual.size!=mask.size: raise ValueError("render resolution mismatch")
        both=ImageChops.darker(mask,actual)
        missing=ImageChops.subtract(mask,actual)
        extra=ImageChops.subtract(actual,mask)
        count=lambda im:im.histogram()[255]
        union=count(ImageChops.lighter(mask,actual))
        if not union: raise ValueError("empty silhouette")
        mask.save(out/(view+"_trace.png"))
        Image.merge("RGB",(ImageChops.lighter(both,missing),both,ImageChops.lighter(both,extra))).save(out/(view+"_overlay.png"))
        results[view]={"iou":count(both)/union,"reference_bounds":mask.getbbox(),"render_bounds":actual.getbbox(),
                       "missing_px":count(missing),"extra_px":count(extra)}
    (out/"evaluation.json").write_text(json.dumps({"format":"SERA_BLOCKOUT_REVIEW_V1","source":cfg["source"],"views":results,
        "limits":"Rough hand traced contours; fixed scale and ground, no independent rescaling. Does not measure 45 degree fidelity or aesthetics; manual acceptance required. No detail stage approval."},indent=2))
if __name__=="__main__":
    main(Path(sys.argv[1]).resolve())
