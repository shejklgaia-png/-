extends Node3D
## Reliable, shader-free monitor animation for Godot's GL Compatibility path.
## The authored 8-cell image atlas stays on a StandardMaterial3D and each
## screen receives genuine 24 Hz frame-by-frame movement of 3D ink marks.
## No per-frame Image decoding, texture uploads, or viewport allocations.
const FPS: float = 24.0
var _id: String = ""
var _mode: int = 0
var _atlas_rate: float = 1.0
var _screen_size: Vector2 = Vector2.ONE
var _screen_mat: StandardMaterial3D
var _clock: float = 0.0
var _last_tick: int = -1
var _trace: MeshInstance3D
var _progress: MeshInstance3D
var _lock_h: MeshInstance3D
var _lock_v: MeshInstance3D
var _lit: StandardMaterial3D
var _amber: StandardMaterial3D

func setup(id: String, mode: int, atlas_rate: float, screen_size: Vector2,
        screen_mat: StandardMaterial3D) -> void:
    _id = id
    _mode = mode
    _atlas_rate = maxf(atlas_rate, 0.1)
    _screen_size = screen_size
    _screen_mat = screen_mat
    _lit = _glowing_material(Color("#4de4f4"))
    _amber = _glowing_material(Color("#efc275"))
    # Markers are physical child quads only millimeters ahead of the visible
    # panel. Unlike a spatial display shader, this renders without GLSL.
    _trace = _quad("LiveScan", Vector2(screen_size.x * 0.012,
        screen_size.y * 0.53), _lit, 0.010)
    _progress = _quad("LiveProgress", Vector2(screen_size.x * 0.69,
        screen_size.y * 0.023), _lit, 0.014)
    _lock_h = _quad("LiveTargetHorizontal", Vector2(screen_size.x * 0.14,
        screen_size.y * 0.011), _amber, 0.018)
    _lock_v = _quad("LiveTargetVertical", Vector2(screen_size.x * 0.011,
        screen_size.y * 0.13), _amber, 0.020)
    _show_tick(0)

func _glowing_material(tint: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    result.albedo_color = tint
    result.emission_enabled = true
    result.emission = tint
    result.emission_energy_multiplier = 1.10
    result.cull_mode = BaseMaterial3D.CULL_DISABLED
    result.no_depth_test = false
    return result

func _quad(name: String, size: Vector2, mat: StandardMaterial3D,
        z: float) -> MeshInstance3D:
    var shape := QuadMesh.new()
    shape.size = size
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = shape
    node.position.z = z
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.set_meta("FX_NO_OUTLINE", true)
    node.set_meta("sera_no_view_edges", true)
    node.set_meta("sera_outline_occluder_only", true)
    node.set_meta("sera_preserve_authored_material", true)
    add_child(node)
    return node

func _process(delta: float) -> void:
    _clock += delta
    var tick: int = int(floor(_clock * FPS))
    if tick != _last_tick:
        _show_tick(tick)

func _show_tick(tick: int) -> void:
    _last_tick = tick
    var time: float = float(tick) / FPS
    var atlas_index: int = posmod(int(floor(time * _atlas_rate)), 8)
    # Godot's native StandardMaterial3D UV transform; compatible with
    # GL Compatibility on Android. No custom shader compile is required.
    _screen_mat.uv1_scale = Vector3(0.25, 0.5, 1.0)
    _screen_mat.uv1_offset = Vector3(
        float(atlas_index % 4) * 0.25,
        float(atlas_index / 4) * 0.5, 0.0)

    var phase: float = float(_mode) * 0.37
    var progress: float = fposmod(time * (0.21 + float(_mode % 3) * 0.045)
        + phase, 1.0)
    var speed: float = 0.75 + float(_mode % 4) * 0.28
    var x: float = -0.34 + 0.68 * progress
    var y: float = 0.05 + 0.20 * sin(time * speed + phase)
    _trace.visible = true
    _trace.rotation.z = 0.0
    _trace.position = Vector3(_screen_size.x * x, _screen_size.y * 0.045, 0.010)
    _trace.scale = Vector3.ONE
    var fill: float = 0.14 + 0.83 * progress
    _progress.visible = true
    _progress.scale = Vector3(fill, 1.0, 1.0)
    _progress.position = Vector3(_screen_size.x * (-0.35 + 0.345 * fill),
        -_screen_size.y * 0.365, 0.014)
    _lock_h.visible = _mode == 2 or _mode == 3 or _mode == 9 or _mode == 10
    _lock_v.visible = _lock_h.visible
    _lock_h.position = Vector3(_screen_size.x * x,
        _screen_size.y * y, 0.018)
    _lock_v.position = Vector3(_screen_size.x * x,
        _screen_size.y * y, 0.020)
    if _mode == 0 or _mode == 5 or _mode == 9:
        # System/analysis/power: oscillating gauge, not a simple loading loop.
        fill = 0.43 + 0.40 * sin(time * 1.17 + phase)
        _progress.scale.x = fill
        _progress.position.x = _screen_size.x * (-0.35 + 0.345 * fill)
    elif _mode == 1 or _mode == 4 or _mode == 6 or _mode == 7:
        # OS logs/archives/inventory: scan follows progressing row selection.
        _trace.position.y = _screen_size.y * (-0.28 + 0.56 * progress)
        _trace.rotation.z = PI * 0.5
        _trace.scale.y = 1.5
    elif _mode == 2:
        # Target tracking: the two reticle axes smoothly track a target.
        _trace.position.x = _screen_size.x * x
    elif _mode == 3:
        # Radar: a continuous 24 Hz rotating ray centered in the panel.
        _trace.position = Vector3.ZERO + Vector3(0, 0, 0.010)
        _trace.rotation.z = time * 1.45
        _trace.scale.y = 1.3
    elif _mode == 8:
        # Printing: progress rail and linear nozzle animation.
        _trace.position.y = _screen_size.y * (0.28 - 0.56 * progress)
    elif _mode == 10:
        # Blueprint: selected wireframe moves with the scan marker.
        _lock_h.scale.x = 0.75 + 0.22 * float(posmod(int(floor(time / 3.0)), 3))
