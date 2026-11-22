extends RefCounted
## IRIS/H02 material preferences shared across all save slots.
## Reuse ConfigFile with FPS/controls; never modify SeraSave profiles.
const SETTINGS_PATH: String = "user://sera_settings.cfg"
const FORMAT: String = "SERA_IRIS_MATERIAL_SHADING_V1"
const MODEL: String = "H02/アイリス"
const SLOT_COUNT: int = 5
const MATERIAL_KEYS: Array[String] = ["armor", "dark_mechanism", "lens", "emission"]
const SHADE_LEVELS: Array[int] = [0, 2, 3, 4, 5, 6, 7, 8]
const SECTION_LAST: String = "iris_material"

static func default_payload() -> Dictionary:
    return {
        "format": FORMAT,
        "model": MODEL,
        "scope": "NEXUS_SINGLE_PREVIEW",
        "lens_lit": false,
        "materials": {
            "armor": {"steps": 4, "threshold": 0.55},
            "dark_mechanism": {"steps": 4, "threshold": 0.60},
            "lens": {"steps": 0, "threshold": 0.25},
            "emission": {"steps": 0, "threshold": 0.0}
        }
    }

## Strict validation applies to clipboard imports AND disk data.
## Do not let malformed values reach ShaderMaterial uniforms.
static func normalize(value: Variant) -> Dictionary:
    if not (value is Dictionary):
        return {}
    var data: Dictionary = value
    if data.get("format") != FORMAT or data.get("model") != MODEL:
        return {}
    if not (data.get("lens_lit") is bool):
        return {}
    if not (data.get("materials") is Dictionary):
        return {}
    var source: Dictionary = data["materials"]
    if source.size() != MATERIAL_KEYS.size():
        return {}
    var materials: Dictionary = {}
    for key in MATERIAL_KEYS:
        if not (source.get(key) is Dictionary):
            return {}
        var item: Dictionary = source[key]
        var steps: Variant = item.get("steps")
        var threshold: Variant = item.get("threshold")
        if not (steps is int) or not SHADE_LEVELS.has(steps):
            return {}
        if not (threshold is int or threshold is float):
            return {}
        var threshold_value: float = float(threshold)
        if is_nan(threshold_value) or is_inf(threshold_value) or (
                threshold_value < 0.0 or threshold_value > 1.0):
            return {}
        if key == "emission" and int(steps) != 0:
            return {}
        materials[key] = {
            "steps": int(steps), "threshold": threshold_value
        }
    return {
        "format": FORMAT,
        "model": MODEL,
        "scope": "NEXUS_SINGLE_PREVIEW",
        "lens_lit": bool(data["lens_lit"]),
        "materials": materials
    }

static func make_payload(values: Array, lens_lit: bool) -> Dictionary:
    if values.size() != MATERIAL_KEYS.size():
        return {}
    var materials: Dictionary = {}
    for i in range(MATERIAL_KEYS.size()):
        materials[MATERIAL_KEYS[i]] = values[i]
    return normalize({
        "format": FORMAT, "model": MODEL,
        "lens_lit": lens_lit, "materials": materials
    })

static func parse_text(raw: String) -> Dictionary:
    if raw.length() > 8192:
        return {}
    return normalize(JSON.parse_string(raw))

static func _get_config() -> ConfigFile:
    var settings := ConfigFile.new()
    settings.load(SETTINGS_PATH)
    return settings

static func _get_writable_config() -> ConfigFile:
    var settings := ConfigFile.new()
    var error: Error = settings.load(SETTINGS_PATH)
    if error != OK and error != ERR_FILE_NOT_FOUND:
        push_warning("IRIS: settings could not be loaded (%d)" % error)
        return null
    return settings

static func load_last() -> Dictionary:
    var settings := _get_config()
    var raw: Variant = settings.get_value(SECTION_LAST, "last", "")
    if not (raw is String):
        return {}
    return parse_text(raw)

static func save_last(value: Dictionary) -> bool:
    var data: Dictionary = normalize(value)
    if data.is_empty():
        return false
    var settings: ConfigFile = _get_writable_config()
    if settings == null:
        return false
    settings.set_value(SECTION_LAST, "last", JSON.stringify(data))
    return settings.save(SETTINGS_PATH) == OK

static func _section(slot: int) -> String:
    return "iris_material_slot_%d" % slot

static func _valid_slot(slot: int) -> bool:
    return slot >= 1 and slot <= SLOT_COUNT

static func read_preset(slot: int) -> Dictionary:
    if not _valid_slot(slot):
        return {}
    var settings := _get_config()
    var section: String = _section(slot)
    var raw: Variant = settings.get_value(section, "data", "")
    if not (raw is String):
        return {}
    var payload: Dictionary = parse_text(raw)
    if payload.is_empty():
        return {}
    var name_value: Variant = settings.get_value(section, "name", "")
    var preset_name: String = str(name_value).strip_edges().substr(0, 24)
    if preset_name.is_empty():
        preset_name = "プリセット %d" % slot
    return {"name": preset_name, "payload": payload}

static func list_presets() -> Array[Dictionary]:
    var items: Array[Dictionary] = []
    for slot in range(1, SLOT_COUNT + 1):
        var loaded: Dictionary = read_preset(slot)
        items.append({
            "slot": slot,
            "name": str(loaded.get("name", "プリセット %d" % slot)),
            "exists": not loaded.is_empty()
        })
    return items

static func save_preset(slot: int, name: String, value: Dictionary) -> bool:
    if not _valid_slot(slot):
        return false
    var data: Dictionary = normalize(value)
    if data.is_empty():
        return false
    var settings: ConfigFile = _get_writable_config()
    if settings == null:
        return false
    var clean_name: String = name.replace("\n", " ").replace("\r", " "
        ).strip_edges().substr(0, 24)
    if clean_name.is_empty():
        clean_name = "プリセット %d" % slot
    settings.set_value(_section(slot), "name", clean_name)
    settings.set_value(_section(slot), "data", JSON.stringify(data))
    return settings.save(SETTINGS_PATH) == OK
