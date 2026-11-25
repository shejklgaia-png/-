"""Produce a review-only CRATE source variant from the exact current generator.
Fail on changed anchors; do not write to scripts/ or silently reuse old geometry.
"""
import sys
from pathlib import Path

def main():
    source,dest=map(Path,sys.argv[1:])
    s=source.read_text(encoding="utf-8")
    changes=[
        # Wider optical aperture, thicker continuous cyan slit.
        ('[0.83, 0.31, 0.054, 0.30, -0.458]', '[0.87, 0.335, 0.044, 0.30, -0.458]',2),
        ('[0.77, 0.255, 0.035, 0.30, -0.412]', '[0.81, 0.285, 0.030, 0.30, -0.412]',2),
        ('[0.77, 0.255, 0.035, 0.30, -0.409]', '[0.81, 0.285, 0.030, 0.30, -0.409]',1),
        ('Vector3(0.565, 0.061, 0.013)', 'Vector3(0.615, 0.075, 0.013)',1),
        ('Vector3(0.525, 0.034, 0.012)', 'Vector3(0.575, 0.050, 0.012)',1),
        # Light armor antenna with dark root and short amber band.
        ('_prism_yz(b, "joint", ear, ear_x - 0.047, ear_x + 0.047)', '_prism_yz(b, "porcelain", ear, ear_x - 0.047, ear_x + 0.047)',1),
        ('Vector2(0.095, 0.70), Vector2(0.135, 0.70),\n            Vector2(0.385, 1.015), Vector2(0.346, 1.027)', 'Vector2(0.095, 0.69), Vector2(0.135, 0.69),\n            Vector2(0.180, 0.76), Vector2(0.135, 0.77)',1),
        ('_disk_x(b, "steel", Vector3(ear_x, 0.62, 0.18), 0.085, 0.11, 12)', '_bevel(b, "joint", Vector3(ear_x, 0.625, 0.155), Vector3(0.12, 0.15, 0.15), 0.023)\n        _disk_x(b, "steel", Vector3(ear_x, 0.62, 0.18), 0.085, 0.11, 12)',1),
        # Chest broader at lower half, close to rectangular maintenance cover.
        ('Vector2(-0.25, 0.43), Vector2(0.25, 0.43), Vector2(0.39, 0.73)', 'Vector2(-0.32, 0.43), Vector2(0.32, 0.43), Vector2(0.38, 0.73)',1),
        ('Vector2(-0.20, 0.52), Vector2(0.20, 0.52), Vector2(0.31, 0.75)', 'Vector2(-0.28, 0.52), Vector2(0.28, 0.52), Vector2(0.31, 0.75)',1),
        ('Vector3(0.155, 0.285, 0.063)', 'Vector3(0.185, 0.31, 0.063)',1),
        ('Vector3(0.059, 0.192, 0.016)', 'Vector3(0.072, 0.145, 0.016)',1),
        ('Vector3(0.028, 0.157, 0.008)', 'Vector3(0.038, 0.112, 0.008)',1),
        ('_box(b, "cyan_dim", Vector3(s * 0.20, 0.87, 0.684),', '_box(b, "cyan_dim", Vector3(s * 0.116, 0.895, 0.726), Vector3(0.048, 0.042, 0.009))\n        _box(b, "cyan_dim", Vector3(s * 0.116, 0.655, 0.726), Vector3(0.032, 0.026, 0.009))\n        _box(b, "cyan_dim", Vector3(s * 0.20, 0.87, 0.684),',1),
        # Side tread rising toward rear. Transform only upper perimeter, retain flat ground.
        ('    shape.reverse()\n    return shape', '    for j in range(shape.size()):\n        var p: Vector2 = shape[j]\n        p.y += clampf((p.y - 0.31) / 0.21, 0.0, 1.0) * (0.025 + 0.12 * p.x)\n        shape[j] = p\n    shape.reverse()\n    return shape',1),
        ('for z in [-0.36, 0.0, 0.36]:', 'for z in [-0.36, 0.0, 0.36]:',1),
        ('# Distinct high-contrast side maintenance panel from the drawing.', '_disk_x(b, "joint", Vector3(outside, 0.47, 0.27), 0.088, 0.064, 16)\n        _disk_x(b, "hub", Vector3(outside + s * 0.043, 0.47, 0.27), 0.062, 0.036, 16)\n        # Distinct high-contrast side maintenance panel from the drawing.',1),
        # Longer curved fingers with clear white/amber separation.
        ('Vector2(0.105, -0.012), Vector2(0.162, -0.077),\n        Vector2(0.177, -0.145), Vector2(0.134, -0.218),\n        Vector2(0.081, -0.243), Vector2(0.060, -0.228)', 'Vector2(0.105, -0.012), Vector2(0.180, -0.070),\n        Vector2(0.202, -0.155), Vector2(0.165, -0.241),\n        Vector2(0.109, -0.280), Vector2(0.070, -0.267)',1),
        ('var w: float = 0.058 if i < 4 else 0.048', 'var w: float = 0.051 if i < 4 else 0.043',1),
        ('var h: float = 0.048 if i < 4 else 0.037', 'var h: float = 0.042 if i < 4 else 0.034',1),
        ('"porcelain" if j < 2 else ("trim" if j == 2 else "amber")', '"porcelain" if j < 4 else "amber"',1),
        ('Vector3(0.23, 0.28, 0.30), 0.068', 'Vector3(0.25, 0.30, 0.32), 0.085',1),
        ('Vector3(0.24, 0.22, 0.31), 0.053', 'Vector3(0.26, 0.235, 0.32), 0.065',1),
    ]
    for old,new,n in changes:
        actual=s.count(old)
        if actual!=n:
            raise ValueError(f"CRATE source changed: {old[:80]!r}: {actual} != {n}")
        s=s.replace(old,new)
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(s,encoding="utf-8")
    print("CRATE local detail variant generated; source unchanged",len(changes))
if __name__=="__main__":
    main()
