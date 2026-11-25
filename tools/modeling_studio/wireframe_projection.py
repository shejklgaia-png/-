"""Review pre-finish guide projections against independently authored silhouette polygons."""
import json
import math
from PIL import Image, ImageDraw, ImageChops

def xy(p):
    if len(p)!=2 or not all(math.isfinite(float(v)) for v in p):
        raise ValueError("invalid silhouette coordinate")
    return tuple(float(v) for v in p)

def review(root):
    source=root/"wireframe_guides.json"
    if not source.is_file():
        return []
    guides=json.loads(source.read_text())
    out=root/"wireframe_projection"
    out.mkdir(exist_ok=False)
    results={}
    paths=[]
    for i,(name,guide) in enumerate(guides.items()):
        points=guide["points"]
        views=guide.get("view_calibration",{})
        silhouettes=guide.get("silhouettes",{})
        if not set(silhouettes)<=set(views):
            raise ValueError("silhouette view has no calibration")
        results[name]={}
        for view in views:
            coords={k:xy(p["views"][view]["projected_px"]) for k,p in points.items()}
            obs={k:xy(p["views"][view]["observed_px"]) for k,p in points.items() if "observed_px" in p["views"][view]}
            ref=silhouettes.get(view)
            polygon=[xy(p) for p in ref["outline"]] if ref else []
            if ref and len(polygon)<3:
                raise ValueError("silhouette requires >=3 vertices")
            allpts=list(coords.values())+list(obs.values())+polygon
            xmin=min(p[0] for p in allpts)
            xmax=max(p[0] for p in allpts)
            ymin=min(p[1] for p in allpts)
            ymax=max(p[1] for p in allpts)
            # Identical transform for observed and reconstructed guides, never independently normalize.
            scale=min(1.,900/max(xmax-xmin,ymax-ymin,1.))
            def pix(p):
                return (round((p[0]-xmin)*scale+12),round((p[1]-ymin)*scale+12))
            size=(math.ceil((xmax-xmin)*scale)+25,math.ceil((ymax-ymin)*scale)+25)
            projected=Image.new("L",size)
            pd=ImageDraw.Draw(projected)
            for face in guide["faces"]:
                pd.polygon([pix(coords[k]) for k in face],fill=255)
            img=Image.new("RGB",size,(32,38,46))
            entry={"observed_points":len(obs),"guide_points":len(coords),
                   "max_reprojection_error_px":max((points[k]["views"][view]["error_px"] for k in obs),default=None),
                   "raster_scale":scale,"silhouette_iou":None}
            if ref:
                target=Image.new("L",size)
                ImageDraw.Draw(target).polygon([pix(p) for p in polygon],fill=255)
                common=ImageChops.darker(target,projected)
                missing=ImageChops.subtract(target,projected)
                extra=ImageChops.subtract(projected,target)
                count=lambda a:a.histogram()[255]
                union=count(ImageChops.lighter(target,projected))
                if not union or not count(target):
                    raise ValueError("empty reference silhouette")
                iou=count(common)/union
                entry.update(silhouette_iou=iou,missing_pixels=count(missing),extra_pixels=count(extra))
                img=Image.merge("RGB",(ImageChops.lighter(common,missing),common,ImageChops.lighter(common,extra)))
                if "min_iou" in ref:
                    minimum=float(ref["min_iou"])
                    if not math.isfinite(minimum) or not 0<=minimum<=1:
                        raise ValueError("invalid min_iou")
                    entry["min_iou"]=minimum
                    entry["meets_iou_target"]=iou>=minimum
            draw=ImageDraw.Draw(img)
            for a,b in guide["edges"]:
                draw.line([pix(coords[a]),pix(coords[b])],fill=(40,210,240),width=1)
            for a,b in guide["edges"]:
                if a in obs and b in obs:
                    draw.line([pix(obs[a]),pix(obs[b])],fill=(255,175,50),width=1)
            for k,p in obs.items():
                q=pix(p)
                draw.line([q,pix(coords[k])],fill=(255,60,170),width=1)
                draw.ellipse((q[0]-2,q[1]-2,q[0]+2,q[1]+2),fill=(255,175,50))
            filename=f"part_{i:04d}_{view}.png"
            img.save(out/filename)
            paths.append("wireframe_projection/"+filename)
            entry["image"]=filename
            results[name][view]=entry
    report={"format":"SERA_WIREFRAME_PROJECTION_V2","parts":results,
            "legend":{"cyan":"projected_edges","orange":"observed_endpoint_connections","magenta":"point_residual","red":"reference_only","blue":"projected_only","white":"overlap"},
            "limits":"Pre-bevel orthographic projected face union, not actual finished render, occlusion or hidden surface reconstruction. Silhouette is authored independently; IoU is raster approximation. Target misses are diagnostic, not silently repaired."}
    (out/"report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    return paths+["wireframe_projection/report.json"]
