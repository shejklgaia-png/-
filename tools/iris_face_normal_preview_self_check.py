#!/usr/bin/env python3
"""Ensure NEXUS IRIS shades authored quad faces, not their triangulation.
Static + independent model-geometry reference; Godot/Android require runtime review.
"""
import json
from pathlib import Path
from math import acos, degrees

root = Path(__file__).resolve().parents[1]
read = lambda p: (root / p).read_text(encoding="utf-8")
model = json.loads(read("models/storage/カメラアイ頭部.bbmodel"))
helper = read("scripts/sera_iris_face_normal_preview.gd")
widget = read("scripts/sera_part_preview_widget.gd")
shader = read("shaders/sera_iris_polygon_light.gdshader")
closed = read("shaders/sera_iris_polygon_light_closed.gdshader")
manifest = read("tools/sera_ci_manifest.txt")
assert "py tools/iris_face_normal_preview_self_check.py" in manifest
assert len(model["elements"]) == 6
assert "const FACE_CULLING = preload(" in helper
assert "static func authored_elements()" in helper
assert "static func make_face_uniform_mesh(" in helper
assert "source_mesh.surface_get_arrays(0)" in helper
assert "Mesh.ARRAY_NORMAL" in helper and "Mesh.ARRAY_VERTEX" in helper
assert "surface_get_primitive_type(0)" in helper
assert "if offset + count * 3 != vertices.size()" in helper
assert "surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)" in helper
assert 'source.mesh = preview_mesh' in widget
assert '"original_mesh": source.mesh' in widget
assert 'source.mesh = item.get("original_mesh")' in widget
assert "IrisFaceNormals.authored_elements()" in widget
assert "IrisFaceNormals.make_face_uniform_mesh(" in widget
assert "normalize(NORMAL)" in shader and "normalize(NORMAL)" in closed
assert "dFdx(VERTEX)" not in shader and "dFdy(VERTEX)" not in shader
assert shader.replace("cull_disabled", "cull_front") == closed
assert "SHADING_MODES = [0, 2, 3, 4, 5, 6, 7, 8]" in widget

def cross(a, b, c):
    u = [b[i] - a[i] for i in range(3)]
    v = [c[i] - a[i] for i in range(3)]
    return (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2],
            u[0]*v[1]-u[1]*v[0])

def mag(v):
    return sum(t*t for t in v) ** 0.5

triangle_count = 0
twisted_quads = 0
max_diagonal_angle = 0.0
for element in model["elements"]:
    for face in element["faces"].values():
        points = [element["vertices"][k] for k in face["vertices"]]
        assert len(points) in (3, 4)
        triangle_count += len(points) - 2
        if len(points) == 4:
            n0 = cross(points[0], points[1], points[2])
            n1 = cross(points[0], points[2], points[3])
            assert mag(n0) > 1e-8 and mag(n1) > 1e-8
            cos = sum(n0[i]*n1[i] for i in range(3)) / (mag(n0)*mag(n1))
            angle = degrees(acos(max(-1.0, min(1.0, cos))))
            if angle > 0.15:
                twisted_quads += 1
                max_diagonal_angle = max(max_diagonal_angle, angle)
            # One area-weighted normal is assigned to every vertex in BOTH
            # generated triangles, so their internal diagonal cannot shade.
            combined = [n0[i] + n1[i] for i in range(3)]
            assert mag(combined) > 1e-8
            shared = [v / mag(combined) for v in combined]
            assert all(abs(sum(v*v for v in shared)-1) < 1e-8 for _ in range(2))
assert triangle_count == 396, triangle_count
assert twisted_quads == 28, twisted_quads
assert 13.0 < max_diagonal_angle < 13.5
print("IRIS authored-face normal geometry contracts PASS "
      f"({twisted_quads} twisted quads, {triangle_count} triangles)")
