extends RefCounted
# NEXUS-selected training defaults, shared with the training room.
# These device-wide preferences are intentionally separate from save slots.
const SETTINGS_PATH: String = "user://sera_training_defaults.cfg"

static func load_defaults() -> Dictionary:
    var config := ConfigFile.new()
    config.load(SETTINGS_PATH)
    return {
        "move_enabled": bool(config.get_value("target", "move_enabled", true)),
        "auto_fire_enabled": bool(config.get_value("target", "auto_fire_enabled", true)),
        "attack_type": clampi(int(config.get_value("target", "attack_type", 0)), 0, 3)
    }

static func save_defaults(values: Dictionary) -> Error:
    var config := ConfigFile.new()
    config.set_value("target", "move_enabled", bool(values.get("move_enabled", true)))
    config.set_value("target", "auto_fire_enabled", bool(values.get("auto_fire_enabled", true)))
    config.set_value("target", "attack_type", clampi(int(values.get("attack_type", 0)), 0, 3))
    return config.save(SETTINGS_PATH)
