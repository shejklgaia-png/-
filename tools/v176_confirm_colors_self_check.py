#!/usr/bin/env python3
"""v176 CONFIRM two-bright-colors regression; source/static only."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
n=(root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
proj=(root/"project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v176"' in proj
def color_constant(name):
    match=re.search(r"const "+name+r": Color = Color\(([^)]*)\)",n)
    assert match, name
    vals=[float(a.strip()) for a in match.group(1).split(",")]
    assert len(vals)==4, name
    return vals
bright=color_constant("SYSTEM_CONFIRM_BG_BRIGHT")
dim=color_constant("SYSTEM_CONFIRM_BG_DIM")
default=[0.018,0.035,0.060,0.92]
assert all(a>b for a,b in zip(dim,default)), (dim,default)
assert all(a>b for a,b in zip(bright,dim)), (bright,dim)
assert 'const SYSTEM_CONFIRM_BORDER_BRIGHT: Color = Color("#e5fbff")' in n
assert 'const SYSTEM_CONFIRM_BORDER_DIM: Color = Color("#7cd6f0")' in n
assert 'SYSTEM_CONFIRM_BLINK_HALF_SECONDS: float = 0.38' in n
refresh=n.split("func _refresh_system_controls() -> void:",1)[1].split(
    "func _reset_system_confirmation_blink()",1)[0]
blink=n.split("func _update_system_confirmation_blink(delta: float) -> void:",1)[1].split(
    "func _cancel_system_confirmation()",1)[0]
for section in (refresh,blink):
    assert "SYSTEM_CONFIRM_BG_BRIGHT" in section
    assert "SYSTEM_CONFIRM_BG_DIM" in section
    assert "SYSTEM_CONFIRM_BORDER_BRIGHT" in section
    assert "SYSTEM_CONFIRM_BORDER_DIM" in section
assert "button.add_theme_stylebox_override(\"panel\", button_style)" in refresh
assert "system_slot_rows[" not in blink
assert "button.queue_redraw()" in blink
assert 'system_pending_action = ""\n    system_pending_slot = 0\n    _reset_system_confirmation_blink()\n    system_message = "OPERATION CANCELLED"\n    _refresh_system_controls()' in n
assert "if not touched_confirm:\n            _cancel_system_confirmation()\n            return" in n
assert 'var needs_confirmation: bool = (action == "LOAD" or action == "DELETE"' in n
assert 'success = SeraSave.load_data(slot)' in n
assert (root/"README_v176_ja.md").is_file()
print("PASS: v176 both blinking button colors brighter than default and immediate reset")
print("Godot/Android runtime: NOT TESTED")
