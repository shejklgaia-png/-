#!/usr/bin/env python3
"""Static v173 checks for SYSTEM CONFIRM highlight, not runtime rendering."""
from pathlib import Path
import math
root = Path(__file__).resolve().parents[1]
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
# Historical v173 regression tested the old (wrong) slot-border target.
# v174 moves the blink to CONFIRM; keep this test as a v173 snapshot only.
if 'config/name="SERA v173"' not in project:
    print("SKIP: historical v173 selected-slot blink check")
    raise SystemExit(0)
assert 'SYSTEM_CONFIRM_BLINK_HALF_SECONDS: float = 0.38' in nexus
assert 'func _update_system_confirmation_blink(delta: float) -> void:' in nexus
assert '_update_system_confirmation_blink(delta)' in nexus
assert 'focused_target != "SYSTEM" or in_transition' in nexus
assert 'system_pending_action.is_empty()' in nexus
assert 'system_pending_slot != system_selected_slot' in nexus
assert 'system_slot_rows[system_pending_slot - 1]["panel"]' in nexus
assert 'panel.get_theme_stylebox("panel") as StyleBoxFlat' in nexus
assert 'style.set_border_width_all(3)' in nexus
assert 'Color(0.0, 0.0, 0.0, 0.0)' in nexus
assert 'style.border_color = Color("#b0edff")' in nexus
assert 'system_pending_action = action\n            system_pending_slot = slot\n            _reset_system_confirmation_blink()' in nexus
assert nexus.count('_reset_system_confirmation_blink()') >= 6
assert 'SeraSave.save_data(slot, _current_system_equipment())' in nexus
assert '_set_archive_records_visible(target_name == "DATA ARCHIVE")' in nexus
assert (root / "README_v173_ja.md").is_file()
# The period is 0.76s: selected border on/off alternates, then loops.
period = 0.38
assert [int(t / period) % 2 == 0 for t in (0, .37, .38, .75, .76)] == [
    True, True, False, False, True]
print("PASS: v173 CONFIRM selected-border blink static and phase checks")
print("Godot/Android runtime: NOT TESTED")
