"""Create review contact sheets of actual renders; no visual pass/fail."""
from pathlib import Path
from PIL import Image,ImageDraw
import sys,json,hashlib,math
root=Path(sys.argv[1])
groups={}
for prefix in ("front","side","three_quarter","godot"):
    files=sorted(root.glob(prefix+"_*.png"))
    if not files: raise RuntimeError("missing "+prefix)
    groups[prefix]=[x.name for x in files]
    sheet=Image.new("RGB",(4*256,math.ceil(len(files)/4)*280),(28,32,39))
    draw=ImageDraw.Draw(sheet)
    for i,file in enumerate(files):
        with Image.open(file) as im:
            im=im.convert("RGB"); im.thumbnail((256,256))
            x=(i%4)*256;y=(i//4)*280
            sheet.paste(im,(x,y));draw.text((x+6,y+258),file.name,fill="white")
    sheet.save(root/(prefix+"_sheet.jpg"),quality=92)
files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.iterdir()) if p.is_file()}
(root/"review_index.json").write_text(json.dumps({"groups":groups,"sha256":files,"visual_approval":False},indent=2))
