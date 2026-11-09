#!/usr/bin/env python3
"""Static source checks for v172 SYSTEM and DATA ARCHIVE separation."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
save = (root / "scripts/sera_save.gd").read_text(encoding="utf-8")
combat = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v172"' in project
assert '_set_system_visible(target_name == "SYSTEM")' in nexus
assert '_set_archive_records_visible(target_name == "DATA ARCHIVE")' in nexus
assert 'focused_target == "SYSTEM" and focus_panel.visible' in nexus
assert 'focused_target == "DATA ARCHIVE" and focus_panel.visible' in nexus
assert "func _tap_archive_record(point: Vector2)" in nexus
assert "func _refresh_archive_records() -> void:" in nexus
assert '["SUMMARY", "COMBAT", "PROGRESS", "PROFILE"]' in nexus
assert 'NOT IMPLEMENTED' in nexus
assert 'SeraSave.save_data(slot, _current_system_equipment())' in nexus
for token in ('"play_seconds"', '"training_visited"', '"stats"',
              '"target_destroys"', '"melee_hits"', '"bash_hits"',
              '"damage_dealt"', '"guarded_hits"', '"received_hits"'):
    assert token in save, token
for method in ("record_game_time", "record_training_time",
               "record_target_hit", "record_defensive_impact", "get_active_stats"):
    assert f"func {method}(" in save, method
assert 'SeraSave.record_target_hit("melee", hp_before_hit - target_hp,' in combat
assert 'SeraSave.record_target_hit("bash", hp_before_hit - target_hp,' in combat
assert 'hp_before_hit > 0 and target_hp == 0)' in combat
assert 'SeraSave.record_defensive_impact(true)' in combat
assert 'SeraSave.record_defensive_impact(false)' in combat
assert 'SeraSave.record_game_time(delta)' in nexus
assert 'SeraSave.record_game_time(delta)' in combat
assert (root / "README_v172_ja.md").is_file()
print("PASS: v172 static SYSTEM/ARCHIVE role and telemetry wiring")
print("Godot/Android runtime: NOT TESTED")
