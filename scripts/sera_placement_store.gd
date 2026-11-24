extends RefCounted
## Shared developer-placement previews. Editor keeps the project-local file;
## exported Android/desktop builds use their own persistent user:// storage.
## These records are previews, not the reviewed canonical placement defaults.
const Defaults = preload("res://scripts/sera_canonical_placement_defaults.gd")
const EDITOR_DIRECTORY := "res://.sera-placement"
const RUNTIME_DIRECTORY := "user://.sera-placement"
const FILE_NAME := "/preview.json"
static var _loaded := false
static var _pending: Dictionary = {}
static var _dirty := false


static func _directory() -> String:
    return EDITOR_DIRECTORY if OS.has_feature("editor") else RUNTIME_DIRECTORY


static func _path() -> String:
    return _directory() + FILE_NAME


static func _load() -> void:
    if _loaded:
        return
    _loaded = true
    var path: String = _path()
    if not FileAccess.file_exists(path):
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Placement preview: unable to open saved placements: " + path)
        return
    var decoded: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if decoded is Dictionary and int(decoded.get("schema", -1)) == 1 and (
            decoded.get("records") is Dictionary):
        _pending = decoded["records"]
    else:
        push_warning("Placement preview: invalid saved JSON; keeping defaults")


static func read(key: String) -> Dictionary:
    _load()
    var official: Dictionary = Defaults.RECORDS.get(key, {})
    var preview: Variant = _pending.get(key, {})
    if preview is Dictionary and not preview.is_empty() and (
            float(preview.get("updated_at", 0.0)) >
            float(official.get("updated_at", 0.0))):
        return preview.duplicate(true)
    return official.duplicate(true)


static func vec(value: Variant) -> Vector3:
    if value is Array and value.size() == 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return Vector3.ZERO


static func array3(value: Vector3) -> Array:
    return [value.x, value.y, value.z]


static func stage(key: String, record: Dictionary) -> void:
    # APKs are not editor-feature builds, but must still persist previews.
    # Do not write each drag frame: existing editors flush at touch release,
    # discrete button presses, or when the editing mode closes/OS pauses.
    _load()
    var next := record.duplicate(true)
    next["updated_at"] = Time.get_unix_time_from_system()
    _pending[key] = next
    _dirty = true


static func flush() -> bool:
    if not _dirty:
        return true
    var directory := ProjectSettings.globalize_path(_directory())
    if DirAccess.make_dir_recursive_absolute(directory) != OK:
        push_warning("Placement preview: cannot create save directory: " + directory)
        return false
    var final_path := ProjectSettings.globalize_path(_path())
    var temp_path := final_path + ".tmp"
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        push_warning("Placement preview: cannot open temporary save file")
        return false
    file.store_string(JSON.stringify({"schema": 1, "records": _pending}, "\t") + "\n")
    file.flush()
    var error := file.get_error()
    file.close()
    if error != OK:
        push_warning("Placement preview: write failed; saved placements unchanged")
        return false
    if DirAccess.rename_absolute(temp_path, final_path) != OK:
        push_warning("Placement preview: cannot commit save; earlier file remains")
        return false
    _dirty = false
    return true
