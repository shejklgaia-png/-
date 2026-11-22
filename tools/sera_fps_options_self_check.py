#!/usr/bin/env python3
"""Three independent persistent frame-rate options in SYSTEM (60/40/30/20 FPS)."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
settings = (root / "scripts/sera_frame_rate_settings.gd").read_text(encoding="utf-8")
budget = (root / "scripts/sera_base_frame_budget.gd").read_text(encoding="utf-8")
base = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
combat = (root / "scripts/main.gd").read_text(encoding="utf-8")
battle = (root / "scripts/bittaran_battle.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

assert 'const SETTINGS_PATH: String = "user://sera_settings.cfg"' in settings
assert 'const FPS_LEVELS = [60, 40, 30, 20]' in settings
assert '"base_nexus": 30' in settings
assert '"grid": 60' in settings
assert '"combat": 60' in settings
assert 'func get_limit(' in settings and 'func set_limit(' in settings
assert 'func next_limit(' in settings and 'func apply(' in settings
assert 'ConfigFile.new()' in settings and 'settings.save(path)' in settings
assert 'FPS_LEVELS.has(' in settings, "Reject invalid FPS values"
assert 'FrameRateSettings.get_limit("base_nexus", _settings_path)' in budget
assert 'FrameRateSettings.get_limit("grid", _settings_path)' in budget
assert 'RenderingServer.viewport_set_update_mode' not in budget, "Never return to frame skipping"
assert 'Engine.physics_ticks_per_second = INPUT_LOOP_FPS' in budget
assert '_frame_budget.set_grid_zoomed(grid_placement_active)' in base
assert 'FrameRateSettings.apply("base_nexus")' in nexus
assert 'FrameRateSettings.apply("combat")' in combat
assert 'super._ready()' in battle, "Boss must inherit combat FPS setup"
assert 'func _create_fps_option_controls(' in nexus
assert 'func _layout_fps_option_controls(' in nexus
assert 'func _tap_fps_option_control(' in nexus
assert 'func _close_fps_option_controls(' in nexus
assert 'FPS SETTINGS' in nexus
assert '"base_nexus"' in nexus and '"grid"' in nexus and '"combat"' in nexus
assert 'FrameRateSettings.set_limit(' in nexus
assert 'FrameRateSettings.next_limit(' in nexus
assert 'if system_fps_options_open:' in nexus, "Back must close submenu"
# Keep all tap targets inside the short portrait SYSTEM panel.
assert "var compact: bool = focus_panel.size.y < 575.0" in nexus
assert 'value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT' in nexus
assert 'focus_panel.size.y = minf(view.y * 0.76,' in nexus
for screen_height in (640.0, 800.0, 1280.0):
    panel_height = min(screen_height * .76, max(610.0, screen_height * .535))
    header_height = min(60.0, screen_height * .068)
    compact = panel_height < 575.0
    gap = 5.0 if compact else 8.0
    row_height = max(39.0 if compact else 50.0,
                     min(73.0, (panel_height - header_height -
                                (312.0 if compact else 365.0)) / 3.0))
    actions_top = (header_height + 12.0 + 3.0 * (row_height + gap)
                   + (6.0 if compact else 9.0))
    status_top = actions_top + (224.0 if compact else 276.0)
    assert status_top + 24.0 <= panel_height, "SYSTEM status must fit"
assert 'py tools/sera_fps_options_self_check.py' in manifest
assert 'gd tools/sera_fps_options_runtime_check.gd' in manifest
print("SERA_FPS_OPTIONS_STATIC_PASS")
