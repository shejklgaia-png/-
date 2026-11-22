extends RefCounted
## Shared portrait presentation settings; 720x1280 is design space.
const SETTINGS_PATH: String = "user://sera_settings.cfg"
const MODE_EXPANDED: String = "expanded"
const MODE_CLASSIC: String = "classic"
const REFERENCE_WIDTH: float = 720.0
const REFERENCE_HEIGHT: float = 1280.0

static func get_mode(path: String = SETTINGS_PATH) -> String:
    var settings := ConfigFile.new()
    if settings.load(path) != OK:
        return MODE_EXPANDED
    var value: Variant = settings.get_value(
        "display", "portrait_mode", MODE_EXPANDED)
    if not (value is String) or not [MODE_EXPANDED, MODE_CLASSIC].has(value):
        return MODE_EXPANDED
    return str(value)


static func set_mode(mode: String, path: String = SETTINGS_PATH) -> bool:
    if not [MODE_EXPANDED, MODE_CLASSIC].has(mode):
        return false
    var settings := ConfigFile.new()
    var result: Error = settings.load(path)
    if result != OK and result != ERR_FILE_NOT_FOUND:
        push_warning("SERA display preferences could not be loaded (%d)" % result)
        return false
    settings.set_value("display", "portrait_mode", mode)
    result = settings.save(path)
    if result != OK:
        push_warning("SERA display preferences could not be saved (%d)" % result)
        return false
    return true


static func apply(window: Window, path: String = SETTINGS_PATH) -> void:
    window.content_scale_aspect = (
        Window.CONTENT_SCALE_ASPECT_EXPAND if get_mode(path) == MODE_EXPANDED
        else Window.CONTENT_SCALE_ASPECT_KEEP)


## 720x1280 -> 1.0, 720x1680 -> 1.3125.
static func height_factor(view_size: Vector2) -> float:
    if view_size.x <= 0.0 or view_size.y <= 0.0:
        return 1.0
    return (view_size.y / view_size.x) * (
        REFERENCE_WIDTH / REFERENCE_HEIGHT)


## Keep horizontal FOV unchanged, extending only vertical FOV on tall devices.
static func vertical_fov(reference_vertical_fov: float,
        view_size: Vector2) -> float:
    return _fov_for_factor(reference_vertical_fov, height_factor(view_size))


static func reframe_vertical_fov(current_vertical_fov: float,
        previous_factor: float, next_factor: float) -> float:
    return _fov_for_factor(current_vertical_fov,
        next_factor / maxf(0.001, previous_factor))


static func _fov_for_factor(vertical_degrees: float, factor: float) -> float:
    var half_tan: float = tan(deg_to_rad(vertical_degrees) * 0.5)
    return clampf(rad_to_deg(2.0 * atan(half_tan * factor)), 1.0, 179.0)
