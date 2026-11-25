"""Extract reviewable geometric line candidates; never infer material/part semantics.
Usage: python reference_lines.py image.png mask.png output_directory
Requires opencv-python-headless; mask is independent binary foreground segmentation.
"""
import json
import sys
from pathlib import Path
import cv2
import numpy as np

def extract(image_path, mask_path, out):
    image=cv2.imread(str(image_path),cv2.IMREAD_COLOR)
    mask=cv2.imread(str(mask_path),cv2.IMREAD_GRAYSCALE)
    if image is None or mask is None or image.shape[:2]!=mask.shape:
        raise ValueError("image and mask must have same dimensions")
    h,w=mask.shape
    if max(h,w)>4096 or min(h,w)<8:
        raise ValueError("reference image size must be 8..4096 pixels per axis")
    mask=np.where(mask>=128,255,0).astype(np.uint8)
    if not np.any(mask) or np.all(mask):
        raise ValueError("mask must contain foreground and background")
    contours,hierarchy=cv2.findContours(mask,cv2.RETR_CCOMP,cv2.CHAIN_APPROX_SIMPLE)
    lines=[]
    for i,c in enumerate(contours):
        if abs(cv2.contourArea(c))<8:
            continue
        p=cv2.approxPolyDP(c,1.25,True).reshape(-1,2).tolist()
        if len(p)>=3:
            lines.append({"id":"outline_"+str(i),"kind":"silhouette_candidate" if hierarchy[0,i,3]<0 else "hole_candidate",
                          "closed":True,"pixels":p})
    gray=cv2.cvtColor(image,cv2.COLOR_BGR2GRAY)
    edge=cv2.Canny(cv2.GaussianBlur(gray,(3,3),0),45,120)
    inner=cv2.erode(mask,np.ones((5,5),np.uint8))
    edge=cv2.bitwise_and(edge,inner)
    # Hough segments are candidates, not panel boundaries or confirmed geometry.
    seg=cv2.HoughLinesP(edge,1,np.pi/180,threshold=18,minLineLength=10,maxLineGap=3)
    if seg is not None:
        for i,(x1,y1,x2,y2) in enumerate(seg.reshape(-1,4)):
            lines.append({"id":"internal_"+str(i),"kind":"unknown","closed":False,
                          "pixels":[[int(x1),int(y1)],[int(x2),int(y2)]]})
    overlay=image.copy()
    for line in lines:
        color=(20,220,240) if line["kind"]=="unknown" else (240,200,40)
        cv2.polylines(overlay,[np.array(line["pixels"],dtype=np.int32)],line["closed"],color,1,cv2.LINE_AA)
    out.mkdir(parents=True,exist_ok=False)
    cv2.imwrite(str(out/"line_candidates.png"),overlay)
    cv2.imwrite(str(out/"internal_edges.png"),edge)
    (out/"line_candidates.json").write_text(json.dumps({"format":"SERA_REFERENCE_LINES_V1","size":[w,h],
        "lines":lines,"limits":"Independent mask required. Canny/Hough detects shading, scratches and texture as well as structure; all internal lines need semantic confirmation."},indent=2),encoding="utf-8")

if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit(__doc__)
    extract(Path(sys.argv[1]),Path(sys.argv[2]),Path(sys.argv[3]))
