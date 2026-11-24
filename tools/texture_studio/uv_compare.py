import json, sys
from pathlib import Path
from math import isfinite

root = Path(sys.argv[1])
parts = ["H01","H02","H03","H04","T01","T02","A01","A02","L01","L02","L03","L04","B01","B02","WR01","WR02","WR03","WL01","WL02"]
variants = ["baseline", "v22"]
data = {}
for f in root.rglob("*.json"):
    variant, part = f.stem.split("-", 1)
    data[variant, part] = json.loads(f.read_text())
print("## UV real-model runtime results (Linux Godot, not Android hardware)")
print("| Variant | Part | Physical edges | >0.25px | >1px | Max px | Sum sq | Atlas | ms | Invalid |")
print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
for v in variants:
    for p in parts:
        x = data.get((v,p))
        if x is None:
            print(f"| {v} | {p} | missing | | | | | | | |")
            continue
        print(f"| {v} | {p} | {x['physical_edges']} | {x['bad']} | {x['severe']} | {x['max']:.4f} | {x['sum_sq']:.4f} | {x['atlas']} | {x['elapsed_ms']} | {x['invalid']} |")
print("\n### Inter-island residuals (no dilution by internal edges)")
for v in variants:
    for p in parts:
        x = data.get((v,p))
        if x:
            print(f"- {v} {p}: {x['island_bad']}/{x['island_edges']} above 0.25px; max {x['island_max']:.5f}px; sum {x['island_sum_sq']:.5f}")
print("\n### Candidate gate (no automated merge)")
for v in variants[1:]:
    reasons, improved = [], False
    for p in parts:
        b, c = data.get(("baseline",p)), data.get((v,p))
        if not b or not c:
            reasons.append(p+": missing")
            continue
        fields = ["max","sum_sq","shape_max","shape_mean","area_max"]
        if not all(isfinite(x[k]) for x in [b,c] for k in fields):
            reasons.append(p+": nonfinite")
            continue
        if b["invalid"] or c["invalid"] or c["physical_edges"] != b["physical_edges"] or c["triangles"] != b["triangles"]:
            reasons.append(p+": invalid or coverage changed")
        if c["bad"] > b["bad"] or c["severe"] > b["severe"] or c["max"] > b["max"]+1e-5 or c["sum_sq"] > b["sum_sq"]+1e-5:
            reasons.append(p+": residual regression")
        # Island counts can change after a cut; the absolute bad count and
        # physical-edge gate must both be non-regressing.
        if c["island_bad"] > b["island_bad"] or c["island_severe"] > b["island_severe"] or c["island_max"] > b["island_max"]+1e-5 or c["island_sum_sq"] > b["island_sum_sq"]+1e-5:
            reasons.append(p+": island residual regression")
        if b["overlap_pairs"] or c["overlap_pairs"] or b["overlap_unchecked"] or c["overlap_unchecked"]:
            reasons.append(p+": overlap present or validation incomplete")
        if b["winding_signature"] != c["winding_signature"]:
            reasons.append(p+": packed winding changed")
        if c["atlas"] > b["atlas"] or c["shape_max"] > b["shape_max"]+0.02 or c["shape_mean"] > b["shape_mean"]*1.05+1e-6 or c["area_max"] > b["area_max"]+0.02:
            reasons.append(p+": atlas or shape regression")
        if c["elapsed_ms"] > max(b["elapsed_ms"]*1.5, b["elapsed_ms"]+500):
            reasons.append(p+": runtime regression (provisional)")
        improved |= c["bad"] < b["bad"] or c["max"] < b["max"]-0.001 or c["sum_sq"] < b["sum_sq"]-0.001
    print(f"- {v}: " + ("eligible for further Android/visual review" if not reasons and improved else "not promoted; "+("; ".join(reasons) or "no material improvement")))
    if reasons or not improved:
        raise SystemExit("V22 promotion gate failed")
if len(data) != len(parts)*len(variants):
    raise SystemExit("Incomplete measurements")
