"""Prepare experimental solver variants in an isolated Actions checkout only."""
import sys
from pathlib import Path

variant = sys.argv[1]
p = Path("scripts/sera_texture_uv.gd")
s = p.read_text(encoding="utf-8")
if variant == "baseline":
    sys.exit(0)
if variant == "threshold":
    # Shift effort toward crossing the 0.25px usability boundary.
    pairs = [
        ("4.0*maxf(0.0,r-0.20)/r+8.0*maxf(0.0,r-0.45)/r",
         "12.0*maxf(0.0,r-0.16)/r+2.0*maxf(0.0,r-0.45)/r"),
        ("4.0*pow(maxf(0.0,rms-0.20),2.0)+8.0*pow(maxf(0.0,rms-0.45),2.0)",
         "12.0*pow(maxf(0.0,rms-0.16),2.0)+2.0*pow(maxf(0.0,rms-0.45),2.0)"),
    ]
elif variant == "peak":
    # Put more weight on the visually worst seams. Keep cost/gradient matched.
    pairs = [
        ("4.0*maxf(0.0,r-0.20)/r+8.0*maxf(0.0,r-0.45)/r",
         "2.0*maxf(0.0,r-0.20)/r+24.0*maxf(0.0,r-0.35)/r"),
        ("4.0*pow(maxf(0.0,rms-0.20),2.0)+8.0*pow(maxf(0.0,rms-0.45),2.0)",
         "2.0*pow(maxf(0.0,rms-0.20),2.0)+24.0*pow(maxf(0.0,rms-0.35),2.0)"),
    ]
else:
    raise SystemExit("Unknown variant: " + variant)
for old, new in pairs:
    if s.count(old) != 1:
        raise SystemExit("Solver changed; rebase experiment instead of silently replacing")
    s = s.replace(old, new)
p.write_text(s, encoding="utf-8")
