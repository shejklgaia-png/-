extends Node
## v171: local, per-device SERA profiles. Stored separately from the GitSync source.
const SLOT_COUNT: int = 3
const ARCHIVE_DIR: String = "user://sera_archive"
const INDEX_PATH: String = ARCHIVE_DIR + "/index.json"
const EQUIPMENT_SLOTS = ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]
const SCHEMA_VERSION: int = 1

var active_slot: int = 0
var active_data: Dictionary = {}
var working_equipment: Dictionary = {}

func _ready() -> void:
    var err: Error = DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(ARCHIVE_DIR))
    if err != OK:
        push_error("SERA: cannot create save directory (%d)" % err)
        return
    var index: Dictionary = _read_json(INDEX_PATH)
    var requested_slot: int = int(index.get("active_slot", 0))
    if _valid_slot(requested_slot):
        var restored: Dictionary = _read_slot(requested_slot)
        if not restored.is_empty():
            active_slot = requested_slot
            active_data = restored
            working_equipment = _sanitize_equipment(restored.get("equipment", {}))

func _valid_slot(slot: int) -> bool:
    return slot >= 1 and slot <= SLOT_COUNT

func _slot_path(slot: int) -> String:
    return "%s/slot_%02d.json" % [ARCHIVE_DIR, slot]

func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

func _read_slot(slot: int) -> Dictionary:
    if not _valid_slot(slot):
        return {}
    var data: Dictionary = _read_json(_slot_path(slot))
    if data.is_empty() or int(data.get("schema_version", -1)) != SCHEMA_VERSION:
        return {}
    if int(data.get("slot", -1)) != slot or not (data.get("equipment") is Dictionary):
        return {}
    if not (data.get("training_seconds") is float or data.get("training_seconds") is int):
        return {}
    data["training_seconds"] = maxf(0.0, float(data["training_seconds"]))
    data["equipment"] = _sanitize_equipment(data["equipment"])
    # v171 profile compatibility: absent statistics are introduced as zeroes.
    data["play_seconds"] = maxf(float(data["training_seconds"]),
        float(data.get("play_seconds", 0.0)))
    data["training_visited"] = bool(data.get("training_visited",
        float(data["training_seconds"]) > 0.0))
    data["stats"] = _sanitize_stats(data.get("stats", {}))
    return data

func _sanitize_equipment(candidate: Variant) -> Dictionary:
    var clean: Dictionary = {}
    for part in EQUIPMENT_SLOTS:
        var set_id: String = "A"
        if candidate is Dictionary:
            set_id = str(candidate.get(part, "A")).strip_edges().to_upper()
        if set_id.is_empty() or set_id.length() > 4:
            set_id = "A"
        clean[part] = set_id
    return clean

func _default_stats() -> Dictionary:
    return {
        "target_destroys": 0, "melee_hits": 0, "bash_hits": 0,
        "damage_dealt": 0, "guarded_hits": 0, "received_hits": 0
    }

func _sanitize_stats(raw: Variant) -> Dictionary:
    var stats: Dictionary = _default_stats()
    if raw is Dictionary:
        for key in stats.keys():
            stats[key] = maxi(0, int(raw.get(key, 0)))
    return stats

func _write_json(path: String, data: Dictionary) -> bool:
    var temp: String = path + ".tmp"
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        push_warning("SERA: save write failed: " + path)
        return false
    file.store_string(JSON.stringify(data, "\t") + "\n")
    file.flush()
    file.close()
    var result: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
    if result != OK:
        push_warning("SERA: save replace failed (%d): %s" % [result, path])
        return false
    return true

func _write_index(slot: int) -> bool:
    return _write_json(INDEX_PATH, {"active_slot": slot})

func _timestamp() -> String:
    return Time.get_datetime_string_from_system(false, true)

func _new_document(slot: int) -> Dictionary:
    var now: String = _timestamp()
    var gear: Dictionary = {}
    for part in EQUIPMENT_SLOTS:
        gear[part] = "A"
    return {
        "schema_version": SCHEMA_VERSION, "slot": slot,
        "created_at": now, "updated_at": now, "training_seconds": 0.0,
        "last_location": "NEXUS", "tutorial_completed": false,
        "training_visited": false, "play_seconds": 0.0,
        "stats": _default_stats(), "equipment": gear
    }

func get_slot(slot: int) -> Dictionary:
    return _read_slot(slot).duplicate(true)

func get_active_data() -> Dictionary:
    return active_data.duplicate(true)

func get_working_equipment() -> Dictionary:
    return working_equipment.duplicate(true)

func get_active_stats() -> Dictionary:
    return _sanitize_stats(active_data.get("stats", {}))

func record_game_time(delta: float) -> void:
    if active_slot == 0 or delta <= 0.0:
        return
    active_data["play_seconds"] = float(active_data.get("play_seconds", 0.0)) + delta

func mark_location(location: String) -> void:
    if active_slot > 0 and (location == "NEXUS" or location == "TRAINING"):
        active_data["last_location"] = location

func record_target_hit(kind: String, damage: int, destroyed: bool) -> void:
    if active_slot == 0 or not (kind == "melee" or kind == "bash"):
        return
    var stats: Dictionary = get_active_stats()
    if kind == "melee":
        stats["melee_hits"] += 1
    else:
        stats["bash_hits"] += 1
    stats["damage_dealt"] += maxi(0, damage)
    if destroyed:
        stats["target_destroys"] += 1
    active_data["stats"] = stats

func record_defensive_impact(guarded: bool) -> void:
    if active_slot == 0:
        return
    var stats: Dictionary = get_active_stats()
    if guarded:
        stats["guarded_hits"] += 1
    else:
        stats["received_hits"] += 1
    active_data["stats"] = stats

func update_working_equipment(part: String, set_id: String) -> void:
    if EQUIPMENT_SLOTS.has(part):
        working_equipment[part] = set_id

func record_training_time(delta: float) -> void:
    if active_slot == 0 or delta <= 0.0:
        return
    active_data["training_seconds"] = float(active_data.get("training_seconds", 0.0)) + delta
    active_data["last_location"] = "TRAINING"
    active_data["training_visited"] = true

func create_data(slot: int) -> bool:
    if not _valid_slot(slot):
        return false
    var fresh: Dictionary = _new_document(slot)
    if not _write_json(_slot_path(slot), fresh):
        return false
    if not _write_index(slot):
        return false
    active_slot = slot
    active_data = fresh
    working_equipment = fresh["equipment"].duplicate(true)
    return true

func save_data(slot: int, equipment: Dictionary) -> bool:
    if not _valid_slot(slot):
        return false
    var current: Dictionary = active_data.duplicate(true)
    if current.is_empty():
        current = _new_document(slot)
    var destination: Dictionary = _read_slot(slot)
    if not destination.is_empty():
        current["created_at"] = destination["created_at"]
    current["schema_version"] = SCHEMA_VERSION
    current["slot"] = slot
    current["updated_at"] = _timestamp()
    current["equipment"] = _sanitize_equipment(equipment)
    if not _write_json(_slot_path(slot), current):
        return false
    if not _write_index(slot):
        return false
    active_slot = slot
    active_data = current
    working_equipment = current["equipment"].duplicate(true)
    return true

func load_data(slot: int) -> bool:
    var stored: Dictionary = _read_slot(slot)
    if stored.is_empty() or not _write_index(slot):
        return false
    active_slot = slot
    active_data = stored
    working_equipment = stored["equipment"].duplicate(true)
    return true

func delete_data(slot: int) -> bool:
    if not _valid_slot(slot) or _read_slot(slot).is_empty():
        return false
    var err: Error = DirAccess.remove_absolute(
        ProjectSettings.globalize_path(_slot_path(slot)))
    if err != OK:
        return false
    if slot == active_slot:
        active_slot = 0
        active_data = {}
        working_equipment = {}
        _write_index(0)
    return true
