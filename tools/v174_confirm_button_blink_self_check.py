#!/usr/bin/env python3
"""Check v174 CONFIRM-button blink wiring; static, not a Godot runtime test."""
from pathlib import Path
p = Path(__file__).resolve().parents[1]
nexus = (p / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (p / "project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v174"' in project
assert 'SYSTEM_CONFIRM_BLINK_HALF_SECONDS: float = 0.38' in nexus
assert 'func _update_system_confirmation_blink(delta: float) -> void:' in nexus
assert '_update_system_confirmation_blink(delta)' in nexus
refresh = nexus.split('func _refresh_system_controls() -> void:', 1)[1].split(
    'func _reset_system_confirmation_blink()', 1)[0]
blink = nexus.split('func _update_system_confirmation_blink(delta: float) -> void:', 1)[1].split(
    'func _cancel_system_confirmation()', 1)[0]
assert 'style.border_color = Color("#b0edff")' in refresh
assert 'var button: Panel = entry["panel"]' in refresh
assert 'label.text = "CONFIRM " + action' in refresh
assert 'button.add_theme_stylebox_override("panel", button_style)' in refresh
assert 'button_style.set_border_width_all(3)' in refresh
assert 'system_pending_slot != system_selected_slot' in blink
assert 'for entry in system_action_rows:' in blink
assert 'str(entry["action"]) != system_pending_action' in blink
assert 'button.get_theme_stylebox("panel") as StyleBoxFlat' in blink
assert 'button.queue_redraw()' in blink
assert 'style.bg_color = (Color(0.09, 0.30, 0.42, 0.98)' in blink
assert 'system_slot_rows[' not in blink
assert 'style.border_color = (Color("#d2faff")' in blink
assert 'system_pending_action = action\n            system_pending_slot = slot\n            _reset_system_confirmation_blink()' in nexus
assert nexus.count('_reset_system_confirmation_blink()') >= 6
assert '_set_archive_records_visible(target_name == "DATA ARCHIVE")' in nexus
assert 'SeraSave.save_data(slot, _current_system_equipment())' in nexus
assert (p / "README_v174_ja.md").is_file()
print("PASS: v174 CONFIRM button blink and slot-border exclusion static checks")
print("Godot/Android runtime: NOT TESTED")
