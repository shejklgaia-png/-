extends PanelContainer
## On-demand Xperia diagnostics. No recording, filesystem writes or network
## access when disabled. Main samples every 0.12 seconds only while enabled.
const MAX_SAMPLES: int = 500
var collecting: bool = false
var samples: Array[String] = []
var display: Label

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.07, 0.10, 0.93)
    style.border_color = Color("5de4d1")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    add_theme_stylebox_override("panel", style)
    display = Label.new()
    display.mouse_filter = Control.MOUSE_FILTER_IGNORE
    display.add_theme_font_size_override("font_size", 14)
    display.add_theme_color_override("font_color", Color("d9f1f4"))
    add_child(display)

func set_collecting(enabled: bool) -> void:
    collecting = enabled
    visible = enabled
    if enabled:
        samples.clear()
        if display != null:
            display.text = "SERA DIAGNOSTICS ON\nMove, dodge, attack or lock on. Tap COPY LOG to export."
    elif display != null:
        display.text = ""

func record_sample(data: Dictionary) -> void:
    if not collecting:
        return
    var frame: float = float(data.get("fps", 0.0))
    var clip: String = str(data.get("clip", "none"))
    var state: String = str(data.get("combat", "-"))
    var lock_id: String = str(data.get("lock", "BODY"))
    var yaw: float = float(data.get("camera_yaw", 0.0))
    var radius: float = float(data.get("camera_radius", 0.0))
    var lag: float = float(data.get("camera_lag", 0.0))
    var step: float = float(data.get("step", 0.0))
    var dx: float = float(data.get("drag_x", 0.0))
    var dy: float = float(data.get("drag_y", 0.0))
    var boost: bool = bool(data.get("boost", false))
    var en: float = float(data.get("energy", 0.0))
    var seconds: float = float(Time.get_ticks_msec()) / 1000.0
    var line: String = "%.2f\t%.1f\t%s\t%s\t%s\t%.4f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%s\t%.1f" % [
        seconds, frame, clip, state, lock_id, yaw, radius, lag, step, dx, dy,
        "1" if boost else "0", en]
    samples.append(line)
    if samples.size() > MAX_SAMPLES:
        samples.remove_at(0)
    if display != null:
        display.text = "FPS %.0f | EN %.0f | BOOST %s\nCAM YAW %.1f deg | RAD %.2fm | LAG %.2fm\nCLIP %s | STATE %s\nLOCK %s | STEP %.2fm\nDRAG (%.2f, %.2f) | %d samples" % [
            frame, en, "ON" if boost else "OFF",
            rad_to_deg(yaw), radius, lag, clip, state, lock_id, step,
            dx, dy, samples.size()]

func export_text() -> String:
    return ("SERA_DIAG_V1\ttime_s\tfps\tclip\tcombat\tlock\tcamera_yaw_rad\t"
        + "camera_radius_m\tcamera_lag_m\tstep_m\tdrag_x\tdrag_y\tboost\ten\n"
        + "\n".join(PackedStringArray(samples)))

func copy_trace() -> int:
    if samples.is_empty():
        return 0
    DisplayServer.clipboard_set(export_text())
    if display != null:
        display.text += "\nCOPIED %d samples to clipboard" % samples.size()
    return samples.size()
