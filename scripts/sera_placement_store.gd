extends RefCounted
## Developer preview data lives in the writable Godot project, not player saves.
const Defaults = preload("res://scripts/sera_canonical_placement_defaults.gd")
const DIRECTORY := "res://.sera-placement"
const PATH := DIRECTORY + "/preview.json"
static var _loaded := false
static var _pending: Dictionary = {}
static var _dirty := false

static func _load() -> void:
    if _loaded:
        return
    _loaded = true
    if not OS.has_feature("editor") or not FileAccess.file_exists(PATH):
        return
    var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if decoded is Dictionary and decoded.get("schema") == 1 and decoded.get("records") is Dictionary:
        _pending = decoded["records"]
    else:
        push_warning("Placement preview: invalid JSON; not loading")

static func read(key: String) -> Dictionary:
    _load()
    var official: Dictionary = Defaults.RECORDS.get(key, {})
    var preview: Variant = _pending.get(key, {})
    if preview is Dictionary and not preview.is_empty() and float(preview.get("updated_at", 0.0)) > float(official.get("updated_at", 0.0)):
        return preview.duplicate(true)
    return official.duplicate(true)

static func vec(value: Variant) -> Vector3:
    if value is Array and value.size() == 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return Vector3.ZERO

static func array3(value: Vector3) -> Array:
    return [value.x, value.y, value.z]

static func stage(key: String, record: Dictionary) -> void:
    if not OS.has_feature("editor"):
        return
    _load()
    var next := record.duplicate(true)
    next["updated_at"] = Time.get_unix_time_from_system()
    _pending[key] = next
    _dirty = true

static func flush() -> bool:
    if not _dirty:
        return true
    var dir := ProjectSettings.globalize_path(DIRECTORY)
    if DirAccess.make_dir_recursive_absolute(dir) != OK:
        push_warning("Placement preview: cannot create shared project directory")
        return false
    var temp := ProjectSettings.globalize_path(PATH + ".tmp")
    var final_path := ProjectSettings.globalize_path(PATH)
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        push_warning("Placement preview: project is not writable")
        return false
    file.store_string(JSON.stringify({"schema": 1, "records": _pending}, "\t") + "\n")
    file.flush()
    var error := file.get_error()
    file.close()
    if error != OK or DirAccess.rename_absolute(temp, final_path) != OK:
        push_warning("Placement preview: save failed; copy remains available")
        return false
    _dirty = false
    return true
