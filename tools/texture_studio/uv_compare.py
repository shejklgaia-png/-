import json, sys
from pathlib import Path
root=Path(sys.argv[1])
parts="H01 H02 H03 H04 T01 T02 A01 A02 L01 L02 L03 L04 B01 B02 WR01 WR02 WR03 WL01 WL02".split()
data={}
for p in root.rglob("*.json"):
    variant,part=p.stem.split("-",1)
    data[variant,part]=json.loads(p.read_text())
print("## Face-paint V31 cached-grid evaluation (Linux Godot, not physical Android)")
print("|Part|V20 / V24 shape mean|V20 / V24 atlas|V20 / V24 ms|V20 / V24 bridge|UV max V20 / V24|")
print("|---|---|---|---|---|---|")
issues=[]
for part in parts:
    b,c=data.get(("baseline",part)),data.get(("face",part))
    if not b or not c:
        issues.append(part+":missing")
        continue
    print(f"|{part}|{b['shape_mean']:.6f} / {c['shape_mean']:.6f}|{b['atlas']} / {c['atlas']}|{b['elapsed_ms']} / {c['elapsed_ms']}|{b['bridge_ok']}/{b['bridge_count']} / {c['bridge_ok']}/{c['bridge_count']}|{b['max']:.4f} / {c['max']:.4f}|")
    if b['version']!='shape-affine-v20' or c['version'] not in ('face-paint-v24','face-paint-v29','face-paint-v30','face-paint-v31'):
        issues.append(part+":version")
    if c['invalid'] or c['overlap_pairs'] or c['overlap_unchecked'] or c['physical_edges']!=b['physical_edges'] or c['triangles']!=b['triangles'] or c['winding_signature']!=b['winding_signature']:
        issues.append(part+":geometry/coverage")
    if not c['png_roundtrip'] or not c['mesh_restore']:
        issues.append(part+":roundtrip")
    print(f"  {part} post-bake: {c['atlas']} -> {c['post_bake_side']}, moved triangles {c['post_bake_moved']}, fallback {c['post_bake_fallback']}, sample mismatch {c['post_bake_mismatch']}/{c['post_bake_samples']}, error {c['post_bake_error']}")
    if not c["post_bake_ok"] or c["post_bake_mismatch"] or c["post_bake_samples"]==0 or c["post_bake_side"]>c["atlas"]:
        issues.append(part+":post bake")
    g=c.get('grid_comparison',{})
    if not g or not g.get('artifact_ok'):
        issues.append(part+":grid artifacts")
    else:
        p,n=g['previous'],g['current']
        print(f"  {part} V28 -> current grid: charts {g['previous_charts']} -> {g['current_charts']}; bad {p['bad']} -> {n['bad']}; max {p['worst']:.5f} -> {n['worst']:.5f}; sum_sq {p['sum_sq']:.5f} -> {n['sum_sq']:.5f}; coplanar bad {p['coplanar_bad']} -> {n['coplanar_bad']}; coplanar welded {p['coplanar_welded']} -> {n['coplanar_welded']}; {g['version']}")
        if p['edges']!=n['edges'] or n['bad']>p['bad'] or n['worst']>p['worst']+0.0002 or n['sum_sq']>p['sum_sq']+0.005 or g['current_atlas']>g['previous_atlas']:
            issues.append(part+":grid regression")
    v30=g.get('v30_comparison',{})
    if not v30 or not v30.get('artifact_ok'):
        issues.append(part+":V30 artifacts")
    else:
        p,n=v30['previous'],v30['current']
        print(f"  {part} V29 -> current: bad {p['bad']} -> {n['bad']}; max {p['worst']:.5f} -> {n['worst']:.5f}; sum_sq {p['sum_sq']:.5f} -> {n['sum_sq']:.5f}; coplanar bad {p['coplanar_bad']} -> {n['coplanar_bad']}; {v30['version']}")
        if p['edges']!=n['edges'] or n['bad']>p['bad'] or n['worst']>p['worst']+0.0002 or n['sum_sq']>p['sum_sq']+0.005 or v30['current_atlas']>v30['previous_atlas'] or n['coplanar_bad']>p['coplanar_bad']:
            issues.append(part+":V30 regression")
    v31=g.get('v31_comparison',{})
    if not v31 or not v31.get('artifact_ok'):
        issues.append(part+":V31 artifacts")
    else:
        p,n=v31['previous'],v31['current']
        print(f"  {part} V30 -> V31: bad {p['bad']} -> {n['bad']}; max {p['worst']:.5f} -> {n['worst']:.5f}; sum_sq {p['sum_sq']:.5f} -> {n['sum_sq']:.5f}; coplanar bad {p['coplanar_bad']} -> {n['coplanar_bad']}; time {v31['previous_us']/1000:.3f} -> {v31['current_ms']}ms; identical_uv={v31['identical_uv']}; {v31['version']}")
        if p['edges']!=n['edges'] or n['bad']>p['bad'] or n['worst']>p['worst']+0.0002 or n['sum_sq']>p['sum_sq']+0.005 or v31['current_atlas']>v31['previous_atlas'] or n['coplanar_bad']>p['coplanar_bad']:
            issues.append(part+":V31 regression")
    if c['bridge_count'] and c['bridge_ok']!=c['bridge_count']:
        issues.append(part+":bridge coverage")
    if c['atlas']>b['atlas']*2 or c['shape_max']>b['shape_max']+0.02 or c['shape_mean']>b['shape_mean']*1.05+1e-6 or c['area_max']>b['area_max']+0.02:
        issues.append(part+":capacity/shape")
print("V31 regression gate:", "; ".join(issues) if issues else "passes structural checks; visual stroke and physical Android review still required")
print("Residuals are reported, not treated as equivalent to paint continuity. Midpoint bridge is not a full brush test.")
if issues or len(data)!=len(parts)*2:
    raise SystemExit(1)
