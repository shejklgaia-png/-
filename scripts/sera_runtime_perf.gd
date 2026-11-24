extends Node
## Low-cost scene-local wall-clock frame interval telemetry, not GPU timing.
## Optional resolution adjustment uses only the main completed-frame viewport.
const Settings = preload("res://scripts/sera_graphics_settings.gd")
const SAMPLE_COUNT := 300
var samples := PackedFloat32Array()
var count: int = 0
var index: int = 0
var last_usec: int = 0
var last_scene: int = 0
var last_limit: int = 0
var elapsed: float = 0.0
var adaptive_enabled: bool = false
var slow_windows: int = 0
var fast_windows: int = 0
var active_viewport: SubViewport
var scale_index: int = 0
const SCALES: Array[float] = [1.0, 0.9, 0.8]

func _ready() -> void:
    samples.resize(SAMPLE_COUNT)
    adaptive_enabled = Settings.get_enabled("adaptive_3d_resolution")
    process_mode = Node.PROCESS_MODE_ALWAYS

func set_adaptive_enabled(enabled: bool) -> void:
    adaptive_enabled = enabled
    slow_windows = 0
    fast_windows = 0
    if not enabled and is_instance_valid(active_viewport):
        active_viewport.scaling_3d_scale = 1.0
        scale_index = 0

func _reset_window() -> void:
    count = 0
    index = 0
    elapsed = 0.0

func _process(_delta: float) -> void:
    var now: int = Time.get_ticks_usec()
    var scene := get_tree().current_scene
    var scene_id: int = scene.get_instance_id() if is_instance_valid(scene) else 0
    var limit: int = Engine.max_fps
    if scene_id != last_scene:
        if is_instance_valid(active_viewport) and scale_index != 0:
            active_viewport.scaling_3d_scale = 1.0
        active_viewport = scene.get_node_or_null("CompletedFrameContainer/CompletedFrame") as SubViewport if is_instance_valid(scene) else null
        scale_index = 0
        slow_windows = 0
        fast_windows = 0
    if last_usec == 0 or scene_id != last_scene or limit != last_limit or limit == 10 or scene_id == 0:
        _reset_window()
        last_scene = scene_id
        last_limit = limit
        last_usec = now
        return
    var ms: float = float(now-last_usec)/1000.0
    last_usec = now
    if ms > 500.0:
        # Exclude app suspension, retain ordinary slow frames.
        _reset_window()
        return
    samples[index] = ms
    index = (index+1)%SAMPLE_COUNT
    count = mini(count+1,SAMPLE_COUNT)
    elapsed += ms/1000.0
    if elapsed < 5.0 or count < 30:
        return
    var ordered := samples.slice(0,count)
    ordered.sort()
    var p95: float = ordered[clampi(ceili(count*0.95)-1,0,count-1)]
    var p99: float = ordered[clampi(ceili(count*0.99)-1,0,count-1)]
    var worst: float = ordered[count-1]
    print("SERA_FRAME ", scene.name, " cap=", limit, " p95_ms=", snappedf(p95,0.1), " p99_ms=", snappedf(p99,0.1), " max_ms=", snappedf(worst,0.1))
    # Hysteresis, conservative steps, no input/physics/outline viewport changes.
    if adaptive_enabled and is_instance_valid(active_viewport) and limit >= 30:
        var target: float = 1000.0/float(limit)
        slow_windows = slow_windows+1 if p95 > target*1.35 else 0
        fast_windows = fast_windows+1 if p95 < target*1.12 else 0
        var next: int = scale_index
        if slow_windows >= 2:
            next = mini(scale_index+1,SCALES.size()-1)
        elif fast_windows >= 4:
            next = maxi(scale_index-1,0)
        if next != scale_index:
            scale_index = next
            active_viewport.scaling_3d_scale = SCALES[scale_index]
            slow_windows = 0
            fast_windows = 0
    _reset_window()
