"""Rank real modeling diagnostics for an AI reviewer; never auto-approve appearance."""
import hashlib
import heapq
import json
import sys
from pathlib import Path


def load(root, name):
    path = root / name
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else None


def pairs(rows):
    result = {}
    for row in rows:
        key = tuple(sorted(row["parts"]))
        count = row.get("surface_triangle_pairs", 0)
        result[key] = (count, bool(row.get("aabb_containment_candidate")), bool(row.get("declared_intentional")))
    return result


def motion_priority(design, static, motion):
    children = {}
    for part in design["parts"]:
        children.setdefault(part.get("parent"), []).append(part["name"])
    def descendants(node):
        seen = set()
        stack = [node]
        while stack:
            part = stack.pop()
            if part in seen:
                continue
            seen.add(part)
            stack.extend(children.get(part, []))
        return seen
    neutral = pairs(static["candidates"])
    findings = {}
    sample_count = 0
    for sweep in motion["sweeps"]:
        node = sweep["node"]
        moved = descendants(node)
        for sample in sweep["samples"]:
            sample_count += 1
            for key, (count, contained, intentional) in pairs(sample["candidates"]).items():
                if (key[0] in moved) == (key[1] in moved):
                    continue
                old_count, old_contained, _ = neutral.get(key, (0, False, False))
                delta = max(0, count - old_count)
                if not delta and not (contained and not old_contained):
                    continue
                ident = (node, key)
                row = findings.setdefault(ident, {"joint": node, "parts": list(key), "neutral_triangle_pairs": old_count,
                    "affected_poses": [], "peak_triangle_pair_increase": 0, "declared_intentional": intentional})
                row["affected_poses"].append({"degrees": sample["degrees"], "surface_triangle_pairs": count,
                    "increase": delta, "new_containment_candidate": contained and not old_contained})
                row["peak_triangle_pair_increase"] = max(row["peak_triangle_pair_increase"], delta)
    ranked = sorted(findings.values(), key=lambda r: (r["declared_intentional"], -len(r["affected_poses"]),
                    -r["peak_triangle_pair_increase"], r["joint"], r["parts"]))
    return {"sample_count": sample_count, "pair_joint_findings": len(ranked), "ranked": ranked,
            "limits": "Single-joint discrete poses only. Cross-moving-boundary candidates worsened relative to neutral; persistent neutral collisions remain in interference.json. Triangle pairs are not penetration depth or volume. Intentional candidates retained."}


def connection_priority(graph):
    nodes = graph["nodes"]
    links = [[] for _ in nodes]
    for edge in graph["edges"]:
        a, b, gap = edge["a"], edge["b"], edge["sampled_gap_m"]
        links[a].append((b, gap))
        links[b].append((a, gap))
    root_keys = {(n["part"], n["island"]) for n in graph["roots"]}
    dist = [float("inf")] * len(nodes)
    queue = []
    for i, n in enumerate(nodes):
        if (n["part"], n["island"]) in root_keys:
            dist[i] = 0.0
            heapq.heappush(queue, (0.0, i))
    while queue:
        cost, i = heapq.heappop(queue)
        if cost != dist[i]:
            continue
        for j, gap in links[i]:
            new = max(cost, gap)
            if new < dist[j]:
                dist[j] = new
                heapq.heappush(queue, (new, j))
    rows = [{**n, "minimum_path_bottleneck_m": d if d != float("inf") else None}
            for n, d in zip(nodes, dist) if d != 0]
    rows.sort(key=lambda r: (r["minimum_path_bottleneck_m"] is not None,
              -(r["minimum_path_bottleneck_m"] or 0), r["part"], r["island"]))
    return {"islands": len(nodes), "zero_gap_paths": sum(d == 0 for d in dist),
            "near_only_paths": sum(0 < d < float("inf") for d in dist),
            "unreachable": sum(d == float("inf") for d in dist), "ranked": rows,
            "limits": "Minimax sampled gap along graph paths; zero means a BVH-overlap or zero sampled distance chain, not a structural certification. Near-only paths may be intentional clearances; do not auto-fill or weld."}


def main(root):
    root = Path(root)
    design = load(root, "design.json")
    static = load(root, "interference.json")
    motion = load(root, "motion_review.json")
    graph = load(root, "attachment_graph.json")
    renders = []
    for name in ("front.png", "back.png", "left.png", "right.png", "top.png", "bottom.png", "front_3q.png", "back_3q.png"):
        path = root / name
        if path.is_file():
            renders.append({"file": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    result = {"format": "SERA_SUPERVISION_QUEUE_V1", "visual_status": "pending",
              "renders_available_not_reviewed": renders,
              "motion": motion_priority(design, static, motion) if all(x is not None for x in (design, static, motion)) else None,
              "connection": connection_priority(graph) if graph is not None else None,
              "next_action": "Review real renders, inspect ranked parts and poses, write part-specific changes and preserve constraints, regenerate and compare. No automatic visual approval."}
    (root / "supervision_queue.json").write_text(json.dumps(result, indent=2, allow_nan=False), encoding="utf-8")
    print("Supervision queue:", "motion findings", result["motion"]["pair_joint_findings"] if result["motion"] else "not available",
          "near-only islands", result["connection"]["near_only_paths"] if result["connection"] else "not available",
          "visual review pending")


if __name__ == "__main__":
    main(sys.argv[1])
