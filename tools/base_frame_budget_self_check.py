#!/usr/bin/env python3
"""BASE/NEXUS and GRID editing honor independent user FPS caps without skips."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
budget = (root / "scripts/sera_base_frame_budget.gd").read_text(encoding="utf-8")
hub = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
settings = (root / "scripts/sera_frame_rate_settings.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

assert 'FrameRateSettings.get_limit("base_nexus", _settings_path)' in budget
assert 'FrameRateSettings.get_limit("grid", _settings_path)' in budget
assert 'settings_path: String = FrameRateSettings.SETTINGS_PATH' in budget
assert "const INPUT_LOOP_FPS: int = 60" in budget
assert "Engine.physics_ticks_per_second = INPUT_LOOP_FPS" in budget
assert "Input.use_accumulated_input = false" in budget
assert "viewport_set_update_mode" not in budget
assert "Engine.time_scale" not in budget
assert "func set_grid_zoomed(" in budget and "func stop(" in budget
assert "Engine.max_fps = _previous_max_fps" in budget
assert "Engine.physics_ticks_per_second = _previous_physics_fps" in budget
assert "Input.use_accumulated_input = _previous_input_accumulation" in budget
assert "func _input(event: InputEvent)" in hub
assert "_frame_budget.advance(delta)" not in hub
assert "_frame_budget.set_grid_zoomed(true)" in hub
assert "_frame_budget.set_grid_zoomed(grid_placement_active)" in hub
assert "_frame_budget.stop()" in hub
assert '"base_nexus": 30' in settings
assert '"grid": 60' in settings
assert "_update_crate(delta)" in hub
assert "py tools/base_frame_budget_self_check.py" in manifest
assert "gd tools/base_frame_budget_runtime_check.gd" in manifest
print("BASE_FRAME_BUDGET_STATIC_PASS")
