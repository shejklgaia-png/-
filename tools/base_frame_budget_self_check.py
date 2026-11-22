#!/usr/bin/env python3
"""BASE renders at 30 Hz while dispatching touch at up to 60 Hz; GRID zoom renders at 60."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
budget = (root / "scripts/sera_base_frame_budget.gd").read_text(encoding="utf-8")
hub = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

# Independently accepted product spec; avoid deriving expectations from implementation.
assert "const BASE_RENDER_FPS: int = 30" in budget
assert "const INPUT_LOOP_FPS: int = 60" in budget
assert "Engine.max_fps = INPUT_LOOP_FPS" in budget
assert "Engine.physics_ticks_per_second = INPUT_LOOP_FPS" in budget
assert "Input.use_accumulated_input = false" in budget
assert "RenderingServer.VIEWPORT_UPDATE_ONCE" in budget
assert "RenderingServer.VIEWPORT_UPDATE_DISABLED" in budget
assert "RenderingServer.VIEWPORT_UPDATE_ALWAYS" in budget
assert "func set_grid_zoomed(" in budget and "func stop(" in budget
assert "Engine.max_fps = _previous_max_fps" in budget
assert "Engine.physics_ticks_per_second = _previous_physics_fps" in budget
assert "Input.use_accumulated_input = _previous_input_accumulation" in budget
assert "func _input(event: InputEvent)" in hub, "Keep touch event routing immediate"
assert "_frame_budget.advance(delta)" in hub
assert "_frame_budget.set_grid_zoomed(true)" in hub, "Start 60 FPS at edit zoom entry"
assert "_frame_budget.set_grid_zoomed(grid_placement_active)" in hub, "Restore 30 after zoom-out finishes"
assert "_frame_budget.stop()" in hub, "Never leak BASE settings into NEXUS/combat"
assert "py tools/base_frame_budget_self_check.py" in manifest
assert "gd tools/base_frame_budget_runtime_check.gd" in manifest
print("BASE_FRAME_BUDGET_STATIC_PASS")
