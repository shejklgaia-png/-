"""Explicit common-coordinate surface authoring for Modeling Studio.
No image recognition or aesthetic approval is implied by successful compilation.
"""
from collections import defaultdict
from copy import deepcopy
import math

def require(condition, message):
    if not condition:
        raise ValueError("surface_authoring: " + message)

def coordinate(value):
    require(isinstance(value, list) and len(value) == 3 and all(
        isinstance(x, (int, float)) and not isinstance(x, bool) and math.isfinite(x)
        for x in value), "invalid XYZ")
    return tuple(float(x) for x in value)

def edges(faces):
    out = defaultdict(list)
    for i, face in enumerate(faces):
        for a, b in zip(face, face[1:] + face[:1]):
            out[tuple(sorted((a, b)))].append((a, b, i))
    return out

def validate_faces(faces, coords, label):
    require(bool(faces), label + ": empty faces")
    seen = set()
    for f in faces:
        require(isinstance(f, list) and 3 <= len(f) <= 4 and len(set(f)) == len(f),
                label + ": use explicit triangles or quads")
        require(all(v in coords for v in f), label + ": unknown vertex")
        key = tuple(sorted(f))
        require(key not in seen, label + ": duplicate face")
        seen.add(key)
        origin = coords[f[0]]
        for a, b in zip(f[1:-1], f[2:]):
            u = [x-y for x,y in zip(coords[a], origin)]
            v = [x-y for x,y in zip(coords[b], origin)]
            cross = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
            require(sum(x*x for x in cross) > 1e-24, label + ": degenerate triangle")
    e = edges(faces)
    neighbors = defaultdict(set)
    for uses in e.values():
        require(len(uses) <= 2, label + ": nonmanifold edge")
        if len(uses) == 2:
            a,b,i = uses[0]
            c,d,j = uses[1]
            require((a,b) == (d,c), label + ": inconsistent winding")
            neighbors[i].add(j)
            neighbors[j].add(i)
    reached = {0}
    pending = [0]
    while pending:
        for j in neighbors[pending.pop()] - reached:
            reached.add(j)
            pending.append(j)
    require(len(reached) == len(faces), label + ": disconnected face islands")
    return e


def finish_spec(patch):
    """Opt-in shading and edge finishing; old surface designs are unchanged."""
    cfg = patch.get("finish")
    if cfg is None:
        return {}
    label = patch["name"]
    require(isinstance(cfg, dict) and set(cfg) <= {
        "mode", "angle_deg", "bevel_m", "bevel_segments", "bevel_angle_deg"
    }, label + ": invalid finish fields")
    mode = cfg.get("mode", "flat")
    require(mode in ("flat", "angle", "weighted"), label + ": invalid finish mode")
    def number(key, default, lo, hi):
        value = cfg.get(key, default)
        require(isinstance(value, (float, int)) and not isinstance(value, bool)
                and math.isfinite(value) and lo <= value <= hi,
                label + ": invalid finish " + key)
        return float(value)
    angle = number("angle_deg", 45, 1, 179)
    width = number("bevel_m", 0, 0, .02)
    limit = number("bevel_angle_deg", 30, 1, 179)
    segments = cfg.get("bevel_segments", 1)
    require(isinstance(segments, int) and not isinstance(segments, bool) and
            1 <= segments <= 3, label + ": invalid bevel segments")
    return {"normal_finish": {"mode": mode, "angle_deg": angle},
            "bevel": width, "bevel_segments": segments, "bevel_angle_deg": limit}


def vector_sub(a, b):
    return tuple(x-y for x, y in zip(a, b))


def cross3(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def planar_diagnostics(patch, coords, outer):
    """Measure authored major planes, not arbitrary triangle count.
    A stable plane is formed from the longest baseline and farthest point.
    Report-only: intended curvature must not be labeled as a plane.
    """
    reports = []
    regions = patch.get("planar_regions", [])
    require(isinstance(regions, list), patch["name"] + ": invalid planar regions")
    names = set()
    for region in regions:
        require(isinstance(region, dict), patch["name"] + ": invalid planar region")
        label = region.get("name")
        ids = region.get("vertices")
        require(isinstance(label, str) and label.strip() and label not in names,
                patch["name"] + ": duplicate/empty planar region")
        names.add(label)
        require(isinstance(ids, list) and len(ids) >= 4 and len(set(ids)) == len(ids)
                and set(ids) <= set(outer), label + ": invalid planar region vertices")
        points = [coords[v] for v in ids]
        a, b = max(((a,b) for i,a in enumerate(points) for b in points[i+1:]),
                   key=lambda pair: math.dist(*pair))
        axis = vector_sub(b,a)
        normal = max((cross3(axis,vector_sub(c,a)) for c in points),
                                        key=lambda n: math.hypot(*n))
        length = math.hypot(*normal)
        require(length > 1e-12, label + ": collinear planar region")
        distances = [sum(x*y for x,y in zip(vector_sub(p,a),normal))/length for p in points]
        tolerance = region.get("tolerance_m", .0001)
        require(isinstance(tolerance,(int,float)) and not isinstance(tolerance,bool)
                and math.isfinite(tolerance) and tolerance > 0, label + ": invalid tolerance")
        residual = max(abs(x) for x in distances)
        reports.append({"name":label,"vertex_count":len(ids),
                        "max_abs_residual_m":residual,
                        "peak_to_peak_m":max(distances)-min(distances),
                        "tolerance_m":tolerance,"within_tolerance":residual <= tolerance})
    return reports


def compile_surfaces(spec):
    """Compile optional authored surface networks into ordinary explicit mesh parts."""
    if "surface_authoring" not in spec:
        return spec, None
    cfg = spec["surface_authoring"]
    require(cfg.get("format") == "SERA_SURFACE_AUTHORING_V1", "unsupported format")
    require(cfg.get("stage") in ("primary", "secondary", "refinement"), "unknown stage")
    require(isinstance(cfg.get("reference"), str) and cfg["reference"].strip(), "reference required")
    require(isinstance(cfg.get("views"), list) and len(set(cfg["views"])) >= 2,
            "two or more distinct reference views required")
    if cfg["stage"] != "primary":
        prior = cfg.get("prior_review", {})
        require(prior.get("decision") == "accepted_for_next_stage" and
                all(isinstance(prior.get(k), str) and prior[k].strip()
                    for k in ("artifact", "reviewer", "observation")),
                "previous stage review record required (not automatic approval)")
    result = deepcopy(spec)
    coords = {name: coordinate(v) for name, v in cfg["vertices"].items()}
    parts = result.setdefault("parts", [])
    existing = {p["name"] for p in parts}
    report = []
    for patch in cfg["patches"]:
        name = patch["name"]
        require(name not in existing, "duplicate part " + name)
        require(patch.get("material") in result["materials"], name + ": unknown material")
        require(isinstance(patch.get("reason"), str) and patch["reason"].strip(), name + ": design reason required")
        require(isinstance(patch.get("evidence"), list) and len(set(patch["evidence"])) >= 2
                and set(patch["evidence"]) <= set(cfg["views"]), name + ": two reference views required")
        faces = deepcopy(patch["faces"])
        e = validate_faces(faces, coords, name)
        boundary = [uses[0][:2] for uses in e.values() if len(uses) == 1]
        outer = list(dict.fromkeys(v for f in faces for v in f))
        vertices = [coords[v] for v in outer]
        index = {v:i for i,v in enumerate(outer)}
        polygons = [[index[v] for v in f] for f in faces]
        mode = patch.get("mode")
        if mode == "shell":
            require(bool(boundary), name + ": shell needs an open outer surface")
            inner = patch["inner"]
            require(set(inner) == set(outer), name + ": inner coordinates must cover every outer vertex")
            for v in outer:
                require(inner[v] in coords and math.dist(coords[v], coords[inner[v]]) > 1e-7,
                        name + ": invalid inner coordinate")
            require(len(set(inner.values())) == len(outer), name + ": duplicate inner vertices")
            n = len(outer)
            vertices += [coords[inner[v]] for v in outer]
            polygons += [[index[v]+n for v in reversed(f)] for f in faces]
            polygons += [[index[b], index[a], index[a]+n, index[b]+n] for a,b in boundary]
        elif mode == "closed":
            require(not boundary, name + ": closed part has open edges")
        else:
            raise ValueError(name + ": mode must be shell or closed")
        validate_faces(polygons, dict(enumerate(vertices)), name + " compiled")
        require(all(len(v)==2 for v in edges(polygons).values()), name + ": compiled mesh not closed")
        part = {"name":name, "shape":"mesh", "material":patch["material"],
                "vertices":vertices, "faces":polygons}
        finish = finish_spec(patch)
        part.update(finish)
        planes = planar_diagnostics(patch, coords, outer)
        if "parent" in patch:
            require(patch["parent"] in existing, name + ": parent must precede patch")
            part["parent"] = patch["parent"]
        parts.append(part)
        existing.add(name)
        report.append({"part":name,"mode":mode,"vertices":len(vertices),"faces":len(polygons),
                       "source_vertex_ids":outer,"reason":patch["reason"],"evidence":patch["evidence"],
                       "finish":finish or {"mode":"legacy_flat"}, "planar_regions":planes})
    require(bool(report), "no surface patches")
    return result, {"format":"SERA_SURFACE_REPORT_V1","stage":cfg["stage"],
                    "reference":cfg["reference"],"views":cfg["views"],"patches":report,
                    "aesthetic_review":"pending","limitations":"Topology only; no self-intersection, thickness uniformity, visual match or independent review guaranteed."}
