#!/usr/bin/env python3
"""v333 lock-part aim controls front, combo ring persists and icons follow gates."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
p=(r/"scripts/flick_direction_policy.gd").read_text()
ui=(r/"scripts/touch_overlay.gd").read_text()
assert 'func projected_lock_forward(' in p
assert 'Vector3(lock_direction.x, 0.0, lock_direction.z)' in p
assert '_locked_target_facing_direction(),' in m.split('func _projected_sera_facing()',1)[1].split('func _combo_normal_attack_ready()',1)[0]
assert 'func _combo_normal_attack_ready() -> bool:' in m
assert 'strike_index < _strike_stage_count() - 1' in m
assert 'func _combo_flick_attack_ready() -> bool:' in m
assert 'bash_followup_window_remaining > 0.0' in m
assert 'combo_visible: bool' in ui and 'combo_normal_ready: bool' in ui and 'combo_flick_ready: bool' in ui
assert 'func set_combo_presentation(' in ui
assert 'if dragging or combo_visible:' in ui
assert 'if combo_visible and combo_normal_ready:' in ui
assert 'if combo_visible and combo_flick_ready:' in ui
assert 'func _draw_combo_sword_icon()' in ui
assert 'func _draw_combo_direction_icon(sector: int)' in ui
assert 'COMBO_TAP_FLASH_SECONDS: float = 0.18' in ui
assert 'touch_ui.call("acknowledge_combo_tap")' in m
assert 'gesture_screen_forward if gesture_active else _projected_sera_facing()' in m
assert 'return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)' in m
assert 'return INPUT_GESTURES.step_flick(' in m
v=re.search(r'config/name="SERA v(\d+)"',(r/"project.godot").read_text())
assert v and int(v.group(1))>=333
print("PASS v333 lock-part front and persistent combo guidance")
