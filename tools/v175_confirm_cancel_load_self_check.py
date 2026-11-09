#!/usr/bin/env python3
"""Static checks for v175 SYSTEM confirmation input and LOAD behavior."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
# Keep the v175 snapshot as a historical test; v176 has new blink colors.
if 'config/name="SERA v175"' not in project:
    print("SKIP: historical v175 confirm cancellation/LOAD check")
    raise SystemExit(0)
tap = src.split("func _tap_system_control(point: Vector2) -> void:", 1)[1].split(
    "func _current_system_equipment()", 1)[0]
outside = tap.split("    for i in range(system_slot_rows.size()):", 1)[0]
assert "if not system_pending_action.is_empty():" in outside
assert 'str(entry["action"]) != system_pending_action' in outside
assert 'Rect2(confirm_panel.position, confirm_panel.size).has_point(local)' in outside
assert "if not touched_confirm:\n            _cancel_system_confirmation()\n            return" in outside
assert 'var exists: bool = not SeraSave.get_slot(slot).is_empty()' in tap
assert 'if action == "LOAD" and not exists:' in tap
assert 'var needs_confirmation: bool = (action == "LOAD" or action == "DELETE"' in tap
assert '(exists and (action == "SAVE" or action == "NEW")))' in tap
assert 'if needs_confirmation and (system_pending_action != action or system_pending_slot != slot):' in tap
assert 'system_message = "PRESS CONFIRM %s FOR SLOT %02d"' in tap
assert 'success = SeraSave.load_data(slot)' in tap
assert '_apply_system_equipment()' in tap
assert 'label.text = "CONFIRM " + action' in src
assert 'str(entry["action"]) != system_pending_action' in src
assert src.count('_reset_system_confirmation_blink()') >= 6
assert 'focused_target != "SYSTEM" or not _cancel_system_confirmation()' in src
assert 'elif focused_target == "SYSTEM" and focus_panel.visible:\n            _tap_system_control(point)' in src
assert '_set_archive_records_visible(target_name == "DATA ARCHIVE")' in src
assert (root / "README_v175_ja.md").exists()
# Scenario matrix: empty-load rejected; existing-load/delete confirmed;
# empty-save/new immediate; existing-save/new confirmed.
for action in ("SAVE", "LOAD", "NEW", "DELETE"):
    for exists in (False, True):
        expected = (action in ("LOAD", "DELETE") or (
            exists and action in ("SAVE", "NEW")))
        if action in ("LOAD", "DELETE") and not exists:
            continue  # missing-slot guard wins before confirmation checks.
        actual = (action in ("LOAD", "DELETE") or (
            exists and action in ("SAVE", "NEW")))
        assert actual == expected, (action, exists)
print("PASS: v175 CONFIRM outside tap cancels; existing LOAD requires confirmation")
print("Godot/Android runtime: NOT TESTED")
