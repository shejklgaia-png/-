import json, sys
from pathlib import Path
root=Path(sys.argv[1])
parts="H01 H02 H03 H04 T01 T02 A01 A02 L01 L02 L03 L04 B01 B02 WR01 WR02 WR03 WL01 WL02".split()
data={}
for p in root.rglob("*.json"):
    variant,part=p.stem.split("-",1)
    data[variant,part]=json.loads(p.read_text())
print("## Face-paint V24 experiment (Linux Godot, not physical Android)")
print("|Part|V20 / V24 shape mean|V20 / V24 atlas|V20 / V24 ms|V20 / V24 bridge|UV max V20 / V24|")
print("|---|---|---|---|---|---|")
issues=[]
for part in parts:
    b,c=data.get(("baseline",part)),data.get(("face",part))
    if not b or not c:
        issues.append(part+":missing")
        continue
    print(f"|{part}|{b['shape_mean']:.6f} / {c['shape_mean']:.6f}|{b['atlas']} / {c['atlas']}|{b['elapsed_ms']} / {c['elapsed_ms']}|{b['bridge_ok']}/{b['bridge_count']} / {c['bridge_ok']}/{c['bridge_count']}|{b['max']:.4f} / {c['max']:.4f}|")
    if b['version']!='shape-affine-v20' or c['version']!='face-paint-v24':
        issues.append(part+":version")
    if c['invalid'] or c['overlap_pairs'] or c['overlap_unchecked'] or c['physical_edges']!=b['physical_edges'] or c['triangles']!=b['triangles'] or c['winding_signature']!=b['winding_signature']:
        issues.append(part+":geometry/coverage")
    if not c['png_roundtrip'] or not c['mesh_restore']:
        issues.append(part+":roundtrip")
    if c['bridge_count'] and c['bridge_ok']!=c['bridge_count']:
        issues.append(part+":bridge coverage")
    if c['atlas']>b['atlas']*2 or c['shape_max']>b['shape_max']+0.02 or c['shape_mean']>b['shape_mean']*1.05+1e-6 or c['area_max']>b['area_max']+0.02:
        issues.append(part+":capacity/shape")
print("V24 prototype gate:", "; ".join(issues) if issues else "passes structural checks; visual stroke and physical Android review still required")
print("Residuals are reported, not treated as equivalent to paint continuity. Midpoint bridge is not a full brush test.")
if issues or len(data)!=len(parts)*2:
    raise SystemExit(1)
