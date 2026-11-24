extends RefCounted
## Global per-device graphics preferences; deliberately independent of save slots.
## Uses the same ConfigFile as controls without replacing unrelated values.
const SETTINGS_PATH: String = "user://sera_settings.cfg"
const FPS_LEVELS = [60, 40, 30, 20]
const DEFAULTS: Dictionary = {
    "base_nexus": 30,
    "nexus": 60,
    "grid": 60,
    "combat": 60,
}


static func get_limit(scope: String, path: String = SETTINGS_PATH) -> int:
    var fallback: int = int(DEFAULTS.get(scope, 60))
    if not DEFAULTS.has(scope):
        return fallback
    var settings := ConfigFile.new()
    if settings.load(path) != OK:
        return fallback
    var stored: Variant = settings.get_value("fps", scope, fallback)
    # Do not coerce bogus strings, fractional values or unsupported rates.
    if not (stored is int) or not FPS_LEVELS.has(stored):
        return fallback
    return int(stored)


static func set_limit(scope: String, fps: int, path: String = SETTINGS_PATH) -> bool:
    if not DEFAULTS.has(scope) or not FPS_LEVELS.has(fps):
        return false
    var settings := ConfigFile.new()
    var load_error: Error = settings.load(path)
    if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
        push_warning("SERA FPS preferences could not be loaded (%d)" % load_error)
        return false
    settings.set_value("fps", scope, fps)
    var error: Error = settings.save(path)
    if error != OK:
        push_warning("SERA FPS preferences could not be saved (%d)" % error)
        return false
    return true


static func next_limit(current: int) -> int:
    var i: int = FPS_LEVELS.find(current)
    return int(FPS_LEVELS[(i + 1) % FPS_LEVELS.size()])


static func apply(scope: String, path: String = SETTINGS_PATH) -> void:
    Engine.max_fps = get_limit(scope, path)
