"""Bundle actual Blender renders for human/ChatGPT review; never generate substitute imagery."""
import json
import hashlib
import sys
from pathlib import Path
from PIL import Image, ImageDraw

VIEWS = ("front", "back", "left", "right", "top", "bottom", "front_3q", "back_3q")

def main():
    root = Path(sys.argv[1]).resolve()
    complete = json.loads((root/"complete.json").read_text())
    if set(complete["views"]) != set(VIEWS):
        raise ValueError("incomplete view set")
    mesh = json.loads((root/"mesh_report.json").read_text())
    sheet = Image.new("RGB", (1200, 660), (32, 38, 46))
    draw = ImageDraw.Draw(sheet)
    views = {}
    for index, name in enumerate(VIEWS):
        with Image.open(root/(name+".png")) as source:
            rgba = source.convert("RGBA")
        alpha = rgba.getchannel("A")
        bounds = alpha.getbbox()
        if bounds is None:
            raise ValueError("empty render: "+name)
        w,h = rgba.size
        views[name] = {"size":[w,h], "silhouette_bounds":list(bounds),
                       "foreground_pixels":sum(alpha.histogram()[1:])}
        tile = Image.new("RGBA", rgba.size, (77,85,94,255))
        tile.alpha_composite(rgba)
        tile.thumbnail((290,290), Image.Resampling.LANCZOS)
        x,y = (index%4)*300, (index//4)*330
        sheet.paste(tile.convert("RGB"), (x+(300-tile.width)//2,y+20))
        draw.text((x+10,y+4),name,fill="white")
    sheet.save(root/"contact_sheet.jpg",quality=92)
    paths = ["model.blend","model.glb","design.json","mesh_report.json","complete.json","contact_sheet.jpg"] + [v+".png" for v in VIEWS]
    files = {p:{"bytes":(root/p).stat().st_size,"sha256":hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in paths}
    if any(v["bytes"]==0 for v in files.values()):
        raise ValueError("empty artifact")
    report = {"format":"SERA_MODEL_REVIEW_V1", "source_sha":__import__("os").environ.get("GITHUB_SHA"),
              "parts":len(mesh),"triangles":sum(x["triangles"] for x in mesh),
              "non_manifold_edges":sum(x["non_manifold_edges"] for x in mesh),
              "zero_area_faces":sum(x["zero_area_faces"] for x in mesh),
              "views":views,"files":files,"visual_acceptance":"not_reviewed"}
    (root/"review.json").write_text(json.dumps(report,indent=2),encoding="utf-8")

if __name__ == "__main__":
    main()
