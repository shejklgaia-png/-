#!/usr/bin/env python3
"""Independent mesh-topology audit and SERA render-contract regression.

All expectations are grounded in the approved switch to front-face-only
rendering for valid closed shells; uncertain/open shells stay double-sided.
This test does not alter canonical Blockbench sources or derived assets.
"""
from __future__ import annotations
from collections import defaultdict
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "models/manifest.json").read_text(encoding="utf-8"))
paths = sorted({manifest["body_rig"], *manifest["variants"].values(),
                *manifest["parts"].values(), *manifest.get("bosses", {}).values()})
assert len(paths) == 8, paths

closed = open_or_nonmanifold = centric_wrong = triangles = 0
exceptions = []
for name in paths:
    model = json.loads((ROOT / name).read_text(encoding="utf-8"))
    for element in model.get("elements", []):
        vertices, faces = element.get("vertices", {}), element.get("faces", {})
        if not vertices or not faces:
            continue
        coords = {key: tuple(float(x) for x in point) for key, point in vertices.items()}
        center = tuple(sum(p[k] for p in coords.values()) / len(coords) for k in range(3))
        edges = defaultdict(list)
        volume = 0.0
        for face in faces.values():
            ids = face.get("vertices", [])
            if len(ids) < 3:
                continue
            poly = [coords[x] for x in ids]
            fc = tuple(sum(p[k] for p in poly) / len(poly) for k in range(3))
            u = tuple(poly[1][k]-poly[0][k] for k in range(3))
            v = tuple(poly[2][k]-poly[0][k] for k in range(3))
            n = (u[1]*v[2]-u[2]*v[1],
                 u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
            if sum(n[k]*(fc[k]-center[k]) for k in range(3)) < 0:
                centric_wrong += max(0, len(poly)-2)
            triangles += max(0, len(poly)-2)
            for a, b in zip(ids, ids[1:]+ids[:1]):
                pa = tuple(round(x, 4) for x in coords[a])
                pb = tuple(round(x, 4) for x in coords[b])
                edges[tuple(sorted((pa,pb)))].append((pa,pb))
            for j in range(1,len(poly)-1):
                a,b,c = poly[0],poly[j],poly[j+1]
                cr = (b[1]*c[2]-b[2]*c[1],
                      b[2]*c[0]-b[0]*c[2], b[0]*c[1]-b[1]*c[0])
                volume += sum(a[k]*cr[k] for k in range(3))/6.0
        bounded = all(len(refs)==2 and refs[0]==tuple(reversed(refs[1]))
                      for refs in edges.values())
        if bounded and volume > 1e-5:
            closed += 1
        else:
            open_or_nonmanifold += 1
            exceptions.append(f'{name}:{element.get("name", "?")}')
assert (closed, open_or_nonmanifold, centric_wrong) == (155, 10, 224), (
    closed, open_or_nonmanifold, centric_wrong, exceptions)
assert triangles > 2000, triangles

cull = (ROOT / "scripts/sera_face_culling.gd").read_text(encoding="utf-8")
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
boss = (ROOT / "scripts/bittaran_rig.gd").read_text(encoding="utf-8")
edges = (ROOT / "scripts/sera_view_edges.gd").read_text(encoding="utf-8")
fast_shader = (ROOT / "shaders/sera_view_edges_fast.gdshader").read_text(encoding="utf-8")
slow_shader = (ROOT / "shaders/sera_view_edges.gdshader").read_text(encoding="utf-8")
ci_manifest = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

assert "static func inspect_element(element: Dictionary) -> Dictionary:" in cull
assert "surface_edges" in cull and "boundary_count" in cull
assert "nonmanifold_count" in cull and "winding_conflict" in cull
assert "signed_volume" in cull and "reverse_faces" in cull
assert '"cull_back": safe_closed' in cull
assert "FACE_CULLING.inspect_element(element)" in rig
assert "FACE_CULLING.inspect_element(element)" in boss
assert "BaseMaterial3D.CULL_BACK" in rig and "BaseMaterial3D.CULL_DISABLED" in rig
assert "BaseMaterial3D.CULL_BACK" in boss and "BaseMaterial3D.CULL_DISABLED" in boss
assert 'set_meta("sera_single_sided", safe_closed)' in rig
assert 'set_meta("sera_single_sided", safe_closed)' in boss
assert "face_center - centroid" not in rig[rig.index("func _make_mesh(element: Dictionary)"):rig.index("func _merge_authored_side_kick_clips")]
assert "face_center - centroid" not in boss[boss.index("func _make_mesh(element: Dictionary)"):boss.index("func _key_rotation(")]

# Dense opaque shells use 0 depth samples in the fast contour pass.
assert "SeraEdgeInk" in edges
assert 'const FAST_INK_SHADER = preload("res://shaders/sera_view_edges_fast.gdshader")' in edges
assert 'get_meta("sera_single_sided", false)' in edges
assert "_fast_ink_material" in edges and "_ink_material" in edges
assert "render_mode unshaded, cull_front, depth_draw_never;" in fast_shader
assert "VIEWPORT_SIZE" in fast_shader and "stroke_px" in fast_shader
assert "ALPHA = 1.0;" in fast_shader
assert not any(key in fast_shader for key in ("hint_depth_texture", "textureLod", "opaque_depth_at"))
assert "hint_depth_texture" in slow_shader   # fallback for uncertain meshes
assert "depth_test_disabled" not in fast_shader
assert "py tools/sera_face_culling_self_check.py" in ci_manifest
assert "gd tools/sera_face_culling_runtime_check.gd" in ci_manifest
assert "gd tools/sera_render_performance_benchmark.gd" in ci_manifest
print(f"SERA_FACE_CULLING_STATIC_PASS: closed={closed}, exceptions={open_or_nonmanifold}, "
      f"previous_wrong_flips={centric_wrong}, triangles={triangles}")
