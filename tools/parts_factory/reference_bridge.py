"""Calibrated blueprint bridge; measurements are hypotheses, not automatic geometry.
Optional dependencies for this CLI only: numpy, opencv-python-headless.
"""
import argparse
import json
import math
import shutil
import sys
from pathlib import Path
import quality_gates as q

ORTHO=("front","right","back","left","top","bottom")
DIRECTIONS={"front":(0,-1,0),"right":(1,0,0),"back":(0,1,0),"left":(-1,0,0),"top":(0,0,1),"bottom":(0,0,-1),
"front_right":(1,-1,0),"back_right":(1,1,0),"back_left":(-1,1,0),"front_left":(-1,-1,0)}

def dump(p,x):
    p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False),encoding="utf-8")

def basis(name):
    import numpy as np
    n=np.array(DIRECTIONS[name],float); n/=np.linalg.norm(n)
    if name in ("top","bottom"):
        right=np.array([1.,0.,0.]); up=np.array([0.,1. if name=="top" else -1.,0.])
    else:
        right=np.cross([0.,0.,1.],n);right/=np.linalg.norm(right);up=np.cross(n,right)
    return right,up,n

def analyze(src, manifest, out):
    import cv2
    import numpy as np
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"modeling_studio"))
    from structure_analysis import analyze as regions
    from multiview_parts import regions as region_points, associate
    m=q.load(manifest); b=q.load(src/"blueprint_review.json")
    q.need(m.get("format")=="SERA_PF_CALIBRATION_V3","invalid calibration")
    q.need(set(m["views"])==set(q.BLUEPRINT_VIEWS),"ten calibrated views required")
    n=m["resolution"];scale=float(m["scale_m"]);target=np.asarray(m["target_m"],float)
    q.need(type(n) is int and 256<=n<=1024 and target.shape==(3,) and np.isfinite(target).all() and math.isfinite(scale) and scale>0,"invalid common frame")
    out.mkdir(parents=True,exist_ok=False)
    shutil.copy2(src/"blueprint_review.json",out/"blueprint_review_snapshot.json")
    shutil.copy2(manifest,out/"calibration_snapshot.json")
    result={}; association={}; masks={}
    for name in q.BLUEPRINT_VIEWS:
        cfg=m["views"][name]; row=b["views"][name]
        source=q.evidence(src,row["file"])
        q.need(q.sha(source)==row["sha256"],"blueprint image changed")
        maskpath=q.evidence(manifest.parent,cfg["mask"])
        q.need(q.sha(maskpath)==cfg["mask_sha256"],"mask hash mismatch")
        img=cv2.imread(str(source),cv2.IMREAD_COLOR); mask=cv2.imread(str(maskpath),cv2.IMREAD_GRAYSCALE)
        q.need(img is not None and mask is not None and img.shape[:2]==mask.shape,"mask/image mismatch")
        q.need(set(np.unique(mask).tolist())<={0,255},"independent binary mask required")
        q.text(cfg.get("reason"),"calibration reason")
        origin=np.asarray(cfg["origin_px"],float); ppm=float(cfg["pixels_per_m"])
        q.need(origin.shape==(2,) and np.isfinite(origin).all() and math.isfinite(ppm) and ppm>0,"invalid calibration")
        # Origin is the projection of the common world target; no per-view fit to model.
        f=n/(scale*ppm); a=np.array([[f,0,(n-1)/2-f*origin[0]],[0,f,(n-1)/2-f*origin[1]]],float)
        norm=cv2.warpAffine(mask,a,(n,n),flags=cv2.INTER_NEAREST)
        q.need(0<int(np.count_nonzero(norm))<n*n and not (norm[0].any() or norm[-1].any() or norm[:,0].any() or norm[:,-1].any()),"empty or clipped normalized mask: "+name)
        # Reject clipping even when the clipped component is entirely outside the canvas.
        ys,xs=np.where(mask>0)
        q.need(len(xs)>0 and min(xs)*f+a[0,2]>=0 and max(xs)*f+a[0,2]<n and min(ys)*f+a[1,2]>=0 and max(ys)*f+a[1,2]<n,"source foreground outside common frame")
        image=cv2.warpAffine(img,a,(n,n),flags=cv2.INTER_LINEAR)
        mp=out/(name+"_mask.png"); ip=out/(name+"_image.png")
        q.need(cv2.imwrite(str(mp),norm) and cv2.imwrite(str(ip),image),"write normalized evidence")
        rd=out/name
        report=regions(ip,mp,rd,clusters=int(m.get("clusters",8)),min_area=int(m.get("min_area",40)))
        right,up,normal=basis(name)
        cam={"right":right,"up":up,"normal":normal,"origin":target,"step":scale/n,"n":n,"scale":scale}
        labels=cv2.imread(str(rd/"labels.png"),cv2.IMREAD_UNCHANGED)
        association[name]=(cam,region_points(labels,image,cam))
        masks[name]=norm>0
        yy,xx=np.where(norm>0)
        result[name]={"source_sha256":row["sha256"],"source_mask_sha256":cfg["mask_sha256"],
            "mask":mp.name,"mask_sha256":q.sha(mp),"structure":name+"/structure.json","structure_sha256":q.sha(rd/"structure.json"),
            "bounds_px":[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],
            "regions":len(report["regions"]),"lines":len(report["lines"]),"reason":cfg["reason"]}
    # Correspondence is existing Modeling Studio algorithm, not duplicated semantic recognition.
    q.need(sum(len(v[1]) for v in association.values())<=1000,"too many regions for multiview correspondence; tune min_area")
    matches=associate(association); dump(out/"correspondence.json",matches)
    # Horizontal cross-section envelope from four cardinal silhouettes; conservative extents only.
    sections=[]
    for k in range(1,20):
        y=round((n-1)*k/20); intervals={}
        for name in ("front","back","right","left"):
            xs=np.where(masks[name][y])[0]
            if len(xs): intervals[name]=[(float(xs[0])+.5-n/2)*scale/n,(float(xs[-1])+.5-n/2)*scale/n]
        if len(intervals)==4:
            x0=max(intervals["front"][0],-intervals["back"][1]);x1=min(intervals["front"][1],-intervals["back"][0])
            y0=max(intervals["right"][0],-intervals["left"][1]);y1=min(intervals["right"][1],-intervals["left"][0])
            sections.append({"z_m":float(target[2]+(n/2-y-.5)*scale/n),"x_m":[float(target[0]+x0),float(target[0]+x1)],"y_m":[float(target[1]+y0),float(target[1]+y1)],"conflict":x0>x1 or y0>y1})
    # Explicit surface landmark annotations, not visible region centroids.
    landmarks={}
    for name,entry in m.get("landmarks",{}).items():
        rows=[];rhs=[];obs=[]
        for view,xy in entry["pixels"].items():
            cfg=m["views"][view];right,up,normal=basis(view)
            pixel=np.asarray(xy,float);origin=np.asarray(cfg["origin_px"],float)
            q.need(pixel.shape==(2,) and np.isfinite(pixel).all(),"invalid landmark")
            p=(pixel-origin)/float(cfg["pixels_per_m"])
            rows.extend([right,up]);rhs.extend([p[0]+right@target,-p[1]+up@target])
            obs.append(view)
        q.need(len(obs)>=2,"landmark needs multiple views")
        q.need(len(set(obs))==len(obs),"duplicate landmark view")
        a=np.asarray(rows);bvec=np.asarray(rhs);xyz,_,rank,_=np.linalg.lstsq(a,bvec,rcond=None)
        q.need(rank==3,"landmark needs nonparallel views")
        residual=float(np.sqrt(np.mean((a@xyz-bvec)**2)))
        landmarks[name]={"world_m":xyz.tolist(),"rms_m":residual,"views":obs,"status":"hypothesis"}
    q.need(len(landmarks)>=3 and len({tuple(v['world_m']) for v in landmarks.values()})>=3,"three distinct authored corresponding landmarks required")
    q.need(bool(sections),"no common horizontal sections; review calibration")
    dump(out/"analysis.json",{"format":"SERA_PF_REFERENCE_ANALYSIS_V3","blueprint_review_sha256":q.sha(src/"blueprint_review.json"),"resolution":n,"scale_m":scale,"target_m":target.tolist(),
        "calibration_sha256":q.sha(out/"calibration_snapshot.json"),"views":result,"landmarks":landmarks,"section_envelopes":sections,"correspondence_sha256":q.sha(out/"correspondence.json"),
        "limits":"Approximate orthographic calibration, independent masks, candidate correspondences and section envelopes; concavities and hidden structures not solved."})

def compare(analysis_dir, model_dir, out):
    import cv2
    import numpy as np
    a=q.load(analysis_dir/"analysis.json");d=q.load(model_dir/"design.json")
    p=q.load(model_dir/"projections.json");n=a["resolution"];scale=a["scale_m"]
    q.need(d.get("parts_factory",{}).get("reference_sha256")==q.sha(analysis_dir/"analysis.json"),"reference not bound to model run")
    out.mkdir(parents=True,exist_ok=False); rows={}
    for name in ORTHO:
        cam=p[name];right,up,normal=basis(name)
        # Compare actual camera orientation, not merely claimed direction.
        sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"modeling_studio"))
        from multiview_parts import camera
        c=camera(cam)
        q.need(cam["resolution"]==n and abs(cam["ortho_scale"]-scale)<1e-6 and np.allclose(cam["target"],a["target_m"],atol=1e-6) and np.allclose(c["right"],right,atol=1e-5) and np.allclose(c["up"],up,atol=1e-5) and np.allclose(c["normal"],normal,atol=1e-5) and np.linalg.norm(np.cross(c["origin"]-np.array(a["target_m"]),normal))<1e-5,"camera mismatch: "+name)
        v=a["views"][name];mp=q.evidence(analysis_dir,v["mask"]);q.need(q.sha(mp)==v["mask_sha256"],"reference mask changed")
        mask=cv2.imread(str(mp),0)>127
        rp=model_dir/(name+".png");im=cv2.imread(str(rp),cv2.IMREAD_UNCHANGED)
        q.need(im is not None and im.shape==(n,n,4),"RGBA render required")
        actual=im[:,:,3]>=128
        both=mask&actual;missing=mask&~actual;extra=actual&~mask
        q.need(actual.any() and mask.any(),"empty silhouette")
        overlay=np.zeros((n,n,3),np.uint8);overlay[both]=(185,185,185);overlay[missing]=(35,55,235);overlay[extra]=(235,120,35)
        op=out/(name+"_overlay.png");q.need(cv2.imwrite(str(op),overlay),"write overlay")
        dist=cv2.distanceTransform((~actual).astype(np.uint8),cv2.DIST_L2,5)
        dist2=cv2.distanceTransform((~mask).astype(np.uint8),cv2.DIST_L2,5)
        rows[name]={"iou":float(both.sum()/(mask|actual).sum()),"missing_px":int(missing.sum()),"extra_px":int(extra.sum()),
          "max_missing_m":float(dist[mask].max()*scale/n),"max_extra_m":float(dist2[actual].max()*scale/n),
          "render_sha256":q.sha(rp),"overlay":op.name,"overlay_sha256":q.sha(op)}
    landmarks={}
    for name,ref in a["landmarks"].items():
        q.need(name in d.get("landmarks",{}),"design missing landmark: "+name)
        errors={}
        xyz=np.array(ref["world_m"])-np.array(a["target_m"])
        for view in ORTHO:
            right,up,_=basis(view)
            expected=np.array([n/2+(right@xyz)*n/scale,n/2-(up@xyz)*n/scale])
            actual=np.asarray(p[view]["landmarks"][name])
            errors[view]=float(np.linalg.norm(actual-expected)*scale/n)
        landmarks[name]={"reference_rms_m":ref["rms_m"],"projection_error_m":errors}
    dump(out/"comparison.json",{"format":"SERA_PF_REFERENCE_COMPARISON_V3","reference_sha256":q.sha(analysis_dir/"analysis.json"),"model_glb_sha256":q.sha(model_dir/"model.glb"),
        "views":rows,"landmarks":landmarks,"priority":sorted(rows,key=lambda v:rows[v]["iou"]),"limits":"Fixed calibrated camera, no best fit. Silhouette and landmark diagnostics do not approve aesthetics or hidden mechanisms."})

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest="cmd",required=True)
    a=s.add_parser("analyze");a.add_argument("blueprint",type=Path);a.add_argument("calibration",type=Path);a.add_argument("out",type=Path)
    a=s.add_parser("compare");a.add_argument("analysis",type=Path);a.add_argument("model",type=Path);a.add_argument("out",type=Path)
    a=p.parse_args()
    if a.cmd=="analyze":analyze(a.blueprint.resolve(),a.calibration.resolve(),a.out.resolve())
    else:compare(a.analysis.resolve(),a.model.resolve(),a.out.resolve())
