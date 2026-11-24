"""Deterministic tests for reference metrics; no real reference quality claims."""
from PIL import Image, ImageDraw
from reference_review import compare

def rectangle(box):
    im=Image.new("L",(100,100))
    ImageDraw.Draw(im).rectangle(box, fill=255)
    return im

def main():
    a=rectangle((10,20,29,39))
    b=rectangle((20,20,39,39))
    r,_=compare(a,a,{"center":[20,30]},{"center":[20,30]},"fixed")
    assert r["iou"] == 1 and r["mean_landmark_error"] == 0
    r,_=compare(a,b,{"center":[20,30]},{"center":[30,30]},"fixed")
    assert abs(r["iou"]-1/3)<1e-9 and r["missing_pixels"]==200 and r["extra_pixels"]==200
    r,_=compare(a,b,{"center":[20,30]},{"center":[30,30]},"bbox")
    assert r["iou"]==1 and r["mean_landmark_error"]==0
    r,_=compare(a,rectangle((10,20,49,39)),{},{},"bbox")
    assert .49 < r["iou"] < .51 and r["mean_landmark_error"] is None
    print("reference metrics: identity, shift, normalization, aspect mismatch PASS")

if __name__=="__main__":
    main()
