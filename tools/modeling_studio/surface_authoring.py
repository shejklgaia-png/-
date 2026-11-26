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
        if "parent" in patch:
            require(patch["parent"] in existing, name + ": parent must precede patch")
            part["parent"] = patch["parent"]
        parts.append(part)
        existing.add(name)
        report.append({"part":name,"mode":mode,"vertices":len(vertices),"faces":len(polygons),
                       "source_vertex_ids":outer,"reason":patch["reason"],"evidence":patch["evidence"]})
    require(bool(report), "no surface patches")
    return result, {"format":"SERA_SURFACE_REPORT_V1","stage":cfg["stage"],
                    "reference":cfg["reference"],"views":cfg["views"],"patches":report,
                    "aesthetic_review":"pending","limitations":"Topology only; no self-intersection, thickness uniformity, visual match or independent review guaranteed."}
