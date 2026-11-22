extends RefCounted
## Device-wide graphics switches; no save-slot or gameplay-state mutations.
const SETTINGS_PATH: String = "user://sera_settings.cfg"
const OPTIONS: Dictionary = {
    "base_outline": true,
    "character_outline": true,
    "part_outline": true,
    "motion_blur": true,
}

static func get_enabled(key: String, path: String = SETTINGS_PATH) -> bool:
    var default_value: bool = bool(OPTIONS.get(key, true))
    if not OPTIONS.has(key):
        return default_value
    var settings := ConfigFile.new()
    if settings.load(path) != OK:
        return default_value
    var value: Variant = settings.get_value("graphics", key, default_value)
    return bool(value) if value is bool else default_value


static func set_enabled(key: String, enabled: bool,
        path: String = SETTINGS_PATH) -> bool:
    if not OPTIONS.has(key):
        return false
    var settings := ConfigFile.new()
    var error: Error = settings.load(path)
    if error != OK and error != ERR_FILE_NOT_FOUND:
        push_warning("SERA graphics preferences load failed (%d)" % error)
        return false
    settings.set_value("graphics", key, enabled)
    error = settings.save(path)
    if error != OK:
        push_warning("SERA graphics preferences save failed (%d)" % error)
        return false
    return true
