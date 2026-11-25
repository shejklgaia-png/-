"""Bundle actual Blender renders for human/ChatGPT review; never generate substitute imagery."""
import json
import hashlib
import sys
from pathlib import Path
from PIL import Image, ImageDraw

VIEWS = ("front", "back", "left", "right", "top", "bottom", "front_3q", "back_3q")

def contact_sheet(root):
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
    return views

def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def compare_candidates(root):
    """Compare actual rendered silhouettes, never treat the baseline as concept art."""
    from reference_review import mask, compare
    baseline = root / "crate_baseline"
    candidates = [name for name in ("crate_candidate", "crate_detail_v2")
                  if (root / name).is_dir()]
    if not candidates:
        return []
    if not baseline.is_dir():
        raise ValueError("candidate exists without production baseline")
    out = root / "candidate_comparison"
    out.mkdir(exist_ok=False)
    paths = []
    variants = {}
    for name in candidates:
        scores = {}
        for view in VIEWS:
            a = mask(baseline / (view + ".png"), "alpha")
            b = mask(root / name / (view + ".png"), "alpha")
            score, overlay = compare(a, b, {}, {}, "bbox")
            filename = name + "_" + view + "_overlay.png"
            overlay.save(out / filename)
            paths.append("candidate_comparison/" + filename)
            score["baseline_image_size"] = list(a.size)
            score["candidate_image_size"] = list(b.size)
            scores[view] = score
        variants[name] = {
            "views": scores,
            "mean_iou": sum(v["iou"] for v in scores.values()) / len(scores),
            "lowest_iou_view": min(scores, key=lambda v: scores[v]["iou"]),
        }
    report = {
        "format": "SERA_CANDIDATE_COMPARISON_V1",
        "baseline": "crate_baseline",
        "alignment": "independent_bbox_uniform_scale",
        "alpha_threshold": 128,
        "variants": variants,
        "visual_acceptance": "not_reviewed",
        "limits": "Actual model-to-model silhouettes, not concept-art accuracy. "
                  "Independent framing removes translation and uniform scale; "
                  "named view orientations must match. IoU measures change, not improvement. "
                  "No guarantee of depth, material, topology or motion compatibility.",
        "overlay_legend": {"red": "baseline_only", "blue": "candidate_only", "white": "both"},
    }
    (out / "comparison.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return paths + ["candidate_comparison/comparison.json"]


def main():
    root = Path(sys.argv[1]).resolve()
    complete = json.loads((root/"complete.json").read_text())
    if set(complete["views"]) != set(VIEWS):
        raise ValueError("incomplete view set")
    mesh = json.loads((root/"mesh_report.json").read_text())
    views = contact_sheet(root)
    paths = ["model.blend","model.glb","design.json","mesh_report.json","complete.json","projections.json","camera_fit.json","interference.json","motion_review.json","godot_import.json","contact_sheet.jpg"] + [v+".png" for v in VIEWS]
    if (root/"reference").is_dir():
        paths += [p.relative_to(root).as_posix() for p in sorted((root/"reference").glob("*")) if p.is_file()]
    for optional in ("model_lod.glb","lod_report.json","model_grouped.glb","grouped_export.json"):
        if (root/optional).is_file():
            paths.append(optional)
    if (root/"crate_baseline").is_dir():
        baseline = root/"crate_baseline"
        contact_sheet(baseline)
        required = ["crate_current.glb","crate_current.blend","godot_source.json","blender_source.json",
                    "projections.json","camera_fit.json","source_commit.txt","source_blob.txt","contact_sheet.jpg"] + [v+".png" for v in VIEWS]
        paths += ["crate_baseline/"+p for p in required]
    if (root/"crate_candidate").is_dir():
        candidate = root/"crate_candidate"
        contact_sheet(candidate)
        required = ["crate_candidate.glb","crate_candidate.blend","candidate_report.json",
                    "projections.json","camera_fit.json","contact_sheet.jpg"]+[v+".png" for v in VIEWS]
        paths += ["crate_candidate/"+p for p in required]
    if (root/"crate_detail_v2").is_dir():
        detail=root/"crate_detail_v2"
        contact_sheet(detail)
        required=["crate_candidate.glb","crate_candidate.blend","candidate_report.json",
                  "projections.json","camera_fit.json","contact_sheet.jpg",
                  "articulation_review.json","crate_godot_review.json"]+[v+".png" for v in VIEWS]
        paths += ["crate_detail_v2/"+p for p in required]
        source=root/"crate_detail_source"
        paths += [p.relative_to(root).as_posix() for p in sorted(source.glob("*")) if p.is_file()]
        got=json.loads((detail/"crate_godot_review.json").read_text())
        expected=json.loads((detail/"candidate_report.json").read_text())
        if got["counts"]["triangles"]!=expected["triangles"]:
            raise ValueError("CRATE V2 Godot triangle count differs from Blender")
    if (root/"grouped_export.json").is_file():
        grouped=json.loads((root/"grouped_export.json").read_text())
        got=json.loads((root/"godot_import.json").read_text())["files"]
        if got["model.glb"]["triangles"]!=grouped["source_triangles"] or got["model_grouped.glb"]["triangles"]!=grouped["source_triangles"]:
            raise ValueError("grouped export triangle mismatch")
        if got["model_grouped.glb"]["meshes"]!=grouped["mesh_groups"]:
            raise ValueError("grouped export mesh count mismatch")
    if (root/"wireframe_guides.json").is_file():
        paths += ["wireframe_guides.json","wireframe_guides.obj"]
        from wireframe_projection import review as review_wireframe
        paths += review_wireframe(root)
    from hard_surface_review import review as review_hard_surface
    paths += review_hard_surface(root)
    if (root/'mechanism_graph.json').is_file():
        paths.append('mechanism_graph.json')
    if (root/"structure_analysis").is_dir():
        paths += [p.relative_to(root).as_posix() for p in sorted((root/"structure_analysis").rglob("*")) if p.is_file()]
    if (root/"blockout_review").is_dir():
        paths += [p.relative_to(root).as_posix() for p in sorted((root/"blockout_review").glob("*")) if p.is_file()]
    if (root/'joint_hierarchy_review.json').is_file():
        paths.append('joint_hierarchy_review.json')
    paths += compare_candidates(root)
    files = {p:{"bytes":(root/p).stat().st_size,"sha256":sha256_file(root/p)} for p in paths}
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
