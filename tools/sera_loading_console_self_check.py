#!/usr/bin/env python3
"""SERA loading console: real milestones, cyber terminal, 100-tick BASE preview."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
base = (root / "scripts/base_exploration.gd").read_text("utf-8")
console = (root / "scripts/sera_loading_console.gd").read_text("utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text("utf-8")

assert 'const LoadingConsole = preload("res://scripts/sera_loading_console.gd")' in base
assert 'screen.name = "SeraLoadingConsole"' in base
assert 'screen.set_stage(' in base
assert 'console_screen.set_stage(' in base
assert '_startup_step("WORLD / FLOOR MATRIX ONLINE", 18)' in base
assert '_startup_step("SYSTEM / BOOT COMPLETE", 100)' in base
assert base.index('_build_hangar()') < base.index('_startup_step("WORLD / FLOOR MATRIX ONLINE", 18)')
assert base.index('_create_hud()') < base.index('_startup_step("SYSTEM / BOOT COMPLETE", 100)')
assert "startup_layer.queue_free()" in base
assert 'button.name = identifier' in base
assert '"LoadingPreviewButton", _play_loading_preview' in base
assert "screen.start_preview()" in base
assert "extends Control" in console
assert "const PREVIEW_SECONDS: float = 5.0" in console
assert "const PREVIEW_STEPS: int = 100" in console
assert "target = mini(PREVIEW_STEPS" in console
assert "for point in range(percent + 1, target + 1):" in console
assert "set_stage(_preview_message(point), point)" in console
assert "history.push_back(message)" in console
assert "draw_texture_rect(" in console, "procedural repeating electronic-screen texture"
assert "draw_line(" in console, "scanlines, frame, progress divisions"
assert "draw_string(" in console, "terminal log drawn in canvas"
# No animated horizontal line across the screen or progress rail.
# Fixed scanlines and granular electronic noise remain part of the UI design.
assert "sweep_phase" not in console, "remove left-to-right scanner motion"
assert "head_x" not in console, "remove the progress-rail sweep stroke"
assert "scan_y" not in console, "remove the traveling full-width horizontal noise band"
assert "for y in range(0, int(h), 7):" in console, "retain static scanlines"
assert "noise_phase += 1" in console, "retain flickering electronic noise"
assert "for step in range(PREVIEW_STEPS):" in console, "retain real progress rail"
# Core/Shell/OS visual is supplementary; the underlying percent is authoritative.
assert "const SYSTEM_PHASE_THRESHOLDS = {" in console
for label, threshold in [("CORE", 18), ("NEXUS", 33), ("LAB", 49),
                         ("GRID", 67), ("ARCHIVE", 79), ("SHELL", 86),
                         ("CRATE", 92), ("OS", 99)]:
    assert f'"{label}": {threshold}' in console, "node must match actual load milestone"
assert "func _system_node_online(" in console, "online nodes derive from actual milestones"
assert "func _draw_core_visual(" in console, "rotating CORE rings and pulse"
assert "func _draw_system_nodes(" in console, "visible linked system nodes"
assert "func _draw_diagnostics(" in console, "left/right animated diagnostic panels"
assert "func _visible_history_count(" in console, "preserve readable terminal history"
assert "anim_time += dt" in console, "independent decorative animation clock"
assert "_draw_system_visual(w, h)" in console, "render system visual in shared screen"
assert "preview_elapsed = minf(PREVIEW_SECONDS" in console, "retain exact preview rate"
assert '"#55798a"' in console.lower(), "shared UI blueprint color"
assert "py tools/sera_loading_console_self_check.py" in manifest
assert "gd tools/sera_loading_console_runtime_check.gd" in manifest
print("SERA_LOADING_CONSOLE_STATIC_PASS")
