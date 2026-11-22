#!/usr/bin/env python3
"""SERA loading console: real milestones, cyber terminal, 100-tick BASE preview."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
base = (root / "scripts/base_exploration.gd").read_text("utf-8")
console = (root / "scripts/sera_loading_console.gd").read_text("utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text("utf-8")
pixel_font = (root / "scripts/sera_terminal_pixel_font.gd").read_text("utf-8")

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
assert '"LoadingPreviewMediumButton"' in base
assert '"LoadingPreviewLowButton"' in base
assert "_play_loading_preview.bind(LoadingConsole.PREVIEW_RENDER_SCALE_1)" in base
assert "_play_loading_preview.bind(LoadingConsole.PREVIEW_RENDER_SCALE_2)" in base
assert "screen.set_render_scale(render_scale)" in base
assert "screen.start_preview()" in base
assert "extends Control" in console
# Explicit contract: the user wants EXACTLY three actually presented frames.
assert "signal completion_cut_finished" in console
assert "const COMPLETE_CUT_FRAMES: int = 3" in console
assert "const LOADING_FPS: int = 10" in console
assert "Engine.max_fps = LOADING_FPS" in console
assert "Engine.max_fps = _previous_max_fps" in console
assert "RenderingServer.frame_post_draw.connect(_on_completion_frame_presented)" in console
assert "if not RenderingServer.render_loop_enabled:" in console
assert "func _finish_headless_cut(generation: int) -> void:" in console
assert "RenderingServer.frame_post_draw.disconnect(_on_completion_frame_presented)" in console
assert "completion_frames_remaining -= 1" in console
assert 'pixel_source.set("completion_cut_active", completion_cut_active)' in console
assert 'var latest: String = ("COMPLETE" if completion_cut_active' in console
assert '"ALL SYSTEMS ONLINE" if completion_cut_active' in console
assert 'if completion_cut_active:' in console
assert 'value = 1.0 if completion_cut_active' in console
assert "1.0 / float(LOADING_FPS)" in console
assert "await Signal(console_screen, &"completion_cut_finished")" in base
assert '_startup_step("SYSTEM / BOOT COMPLETE", 100)' in base
assert base.index('_startup_step("SYSTEM / BOOT COMPLETE", 100)') < base.index("await Signal(console_screen, &"completion_cut_finished")") < base.index("startup_layer.queue_free()")
# Render only this prompt at half raster resolution. Do not touch the game viewport.
assert "const CONSOLE_RENDER_SCALE: float = 0.5" in console
assert "const PREVIEW_RENDER_SCALE_1: float = 0.375" in console
assert "const PREVIEW_RENDER_SCALE_2: float = 0.25" in console
assert "func set_render_scale(scale_value: float) -> void:" in console
assert "var console_render_scale: float = CONSOLE_RENDER_SCALE" in console
assert "SubViewport.new()" in console, "dedicated reduced-size render target"
assert "pixel_viewport.size = Vector2i(" in console, "offscreen viewport follows console dimensions"
assert "pixel_source.scale = Vector2(console_render_scale, console_render_scale)" in console
assert "int(ceilf(size.x * console_render_scale))" in console
assert "int(ceilf(size.y * console_render_scale))" in console
assert "get_script() as GDScript" in console, "typed GDScript constructor is available for the offscreen replica"
assert "TextureRect.new()" in console
assert "CanvasItem.TEXTURE_FILTER_NEAREST" in console, "no bilinear blur"
assert "pixel_output.texture = pixel_viewport.get_texture()" in console
assert "if not pixel_source_mode:" in console, "controller must not render native-resolution duplicate"
assert 'config/name="SERA v' in (root / "project.godot").read_text("utf-8")
assert "viewport_width=720" in (root / "project.godot").read_text("utf-8")
assert "viewport_height=1280" in (root / "project.godot").read_text("utf-8")
assert "const PREVIEW_SECONDS: float = 5.0" in console
assert "const PREVIEW_STEPS: int = 100" in console
assert "target = mini(PREVIEW_STEPS" in console
assert "for point in range(percent + 1, target + 1):" in console
assert "set_stage(_preview_message(point), point)" in console
assert "history.push_back(message)" in console
assert "draw_texture_rect(" in console, "procedural repeating electronic-screen texture"
assert "draw_line(" in console, "scanlines, frame, progress divisions"
# Pixel glyphs are generated as a compact atlas, never scaled TTFs.
assert 'preload("res://scripts/sera_terminal_pixel_font.gd")' in console
assert 'pixel_font_atlas = TerminalPixelFont.make_atlas()' in console
assert 'draw_texture_rect_region(pixel_font_atlas' in console
assert 'roundi(at.x * console_render_scale)' in console
assert 'roundi(at.y * console_render_scale)' in console
assert 'func _pixel_cell_pixels(font_size: int) -> int:' in console
assert 'console_render_scale >= 0.35' in console, "37.5 percent title must have a distinct 2px mode"
assert 'SERA // OMNI SYNC' in console, "medium title fits the screen at 2x pixels"
assert 'func _pixel_text_width(message: String, font_size: int) -> float:' in console
assert '_fit_pixel_text(' in console, "truncate long logs by actual glyph width"
assert 'pixel_source.set("console_render_scale", console_render_scale)' in console
assert 'var percent_x: float =' in console
assert 'Image.create(' in pixel_font
assert 'ImageTexture.create_from_image(' in pixel_font
assert 'GLYPH_ROWS' in pixel_font
assert 'GLYPH_ORDER' in pixel_font
# Verify all symbols are authored as complete non-antialiased 5x7 cells.
import re
glyph_rows = re.findall(r'^    "[^"]": (\\[[^\\n]+\\]),
assert "draw_string(" not in console, "no scaled vector glyphs in the terminal"
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
, pixel_font, re.M)
assert len(glyph_rows) >= 50, f"bitmap atlas has only {len(glyph_rows)} symbols"
for line in glyph_rows:
    cells = re.findall(r'"([01]{5})"', line)
    assert len(cells) == 7, "each glyph must have seven full 5-bit rows"
for label in ("CORE", "SHELL", "NEXUS", "GRID", "OS", "100%", ">", "/"):
    assert all(f'"{character}"' in pixel_font for character in label)
assert "draw_string(" not in console, "no scaled vector glyphs in the terminal"
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
