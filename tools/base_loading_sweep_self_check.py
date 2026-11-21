#!/usr/bin/env python3
"""BASE loading sweep: blue edge, white core, sharp taper, fast seamless loop."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
base = (root / "scripts/base_exploration.gd").read_text("utf-8")
sweep = (root / "scripts/sera_loading_sweep.gd").read_text("utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text("utf-8")

# The first frame still uses only engine-native primitives, with no texture import.
assert 'const LoadingSweep = preload("res://scripts/sera_loading_sweep.gd")' in base
assert 'sweep.name = "LoadingSweep"' in base
assert "sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE" in base
assert "startup_layer.add_child(sweep)" in base
assert base.index("startup_layer.add_child(sweep)") < base.index("startup_layer.add_child(startup_label)")
assert "startup_layer.queue_free()" in base
assert "await get_tree().process_frame" in base

assert "extends Control" in sweep
assert "const LOOP_SECONDS: float = 0.78" in sweep
assert "phase = fposmod(phase + maxf(delta, 0.0), LOOP_SECONDS)" in sweep
assert "queue_redraw()" in sweep
assert "draw_polygon(" in sweep
assert 'Color("#ffffff")' in sweep, "white light core"
assert 'Color("#209dff")' in sweep, "blue edge"
assert "pow(" in sweep and "taper" in sweep, "tapered blue ends"
assert sweep.count("_draw_streak(") >= 5, "at least four concentric light layers"
assert "py tools/base_loading_sweep_self_check.py" in manifest
assert "gd tools/base_loading_sweep_runtime_check.gd" in manifest
print("SERA_BASE_LOADING_SWEEP_STATIC_PASS")
