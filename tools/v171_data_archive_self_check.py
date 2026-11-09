#!/usr/bin/env python3
"""v171 per-slot archive wiring checks. Static only; not an Android runtime test."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
project = (root / "project.godot").read_text(encoding="utf-8")
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
save = (root / "scripts/sera_save.gd").read_text(encoding="utf-8")
equipment = (root / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
training = (root / "scripts/main.gd").read_text(encoding="utf-8")
# Historical v171 checks describe the former DATA ARCHIVE placement.
# They apply only to v171; v172 deliberately moves controls into SYSTEM.
if 'config/name="SERA v171"' not in project:
    print("SKIP: historical v171 archive layout (project is a newer version)")
    raise SystemExit(0)
assert 'SeraSave="*res://scripts/sera_save.gd"' in project
for name in ("create_data", "save_data", "load_data", "delete_data",
             "get_slot", "record_training_time"):
    assert f"func {name}(" in save, name
for field in ("schema_version", "slot", "equipment", "training_seconds",
              "tutorial_completed", "last_location", "created_at", "updated_at"):
    assert f'"{field}"' in save
assert 'DirAccess.rename_absolute(' in save, "temporary-file replacement"
assert 'if not _valid_slot(slot)' in save, "slot bounds"
assert 'if stored.is_empty() or not _write_index(slot):' in save, "load validation"
assert 'SeraSave.record_training_time(delta)' in training
assert 'get_working_equipment' in equipment
assert 'update_working_equipment' in equipment
for name in ("_tap_archive_control", "_refresh_archive_controls",
             "_layout_archive_controls", "_apply_archive_equipment"):
    assert f"func {name}(" in nexus
assert 'archive_pending_action != action or archive_pending_slot != slot' in nexus
assert 'for candidate in ["TRAINING", "SYSTEM", "CUSTOMIZE", "DATA ARCHIVE", "DEPLOYMENT"]:' in nexus
assert 'func _start_training() -> void:' in nexus
assert (root / "README_v171_ja.md").is_file()
print("PASS: v171 archive static integration and 3-slot storage checks")
print("Godot parser and Android runtime: NOT TESTED")
