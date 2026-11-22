extends Node3D
## Standalone calibration cube for Android GL Compatibility stencil support.
## It uses stencil ref 29 (SERA is ref 17) in the SAME active 3D viewport.
## Mode 10: green if EQUAL; Mode 11: magenta if NOT EQUAL.
## No GPU readback or scene-dependent pass order is inferred from counters.
const SHADER_WRITE = preload("res://shaders/sera_nexus_stencil_probe_write.gdshader")
const SHADER_EQUAL = preload("res://shaders/sera_nexus_stencil_probe_equal.gdshader")
const SHADER_UNEQUAL = preload("res://shaders/sera_nexus_stencil_probe_unequal.gdshader")

var _rig: Node3D
var _writer: MeshInstance3D
var _reader: MeshInstance3D
var _read_equal: ShaderMaterial
var _read_unequal: ShaderMaterial
var _mode: int = 0
var _camera_seen: bool = false

func configure(rig: Node3D) -> void:
    _rig = rig

func _ready() -> void:
    name = "SeraStencilCalibrationCube"
    set_meta("sera_generated_live_edge", true)
    set_meta("FX_NO_OUTLINE", true)
    top_level = true
    var write_material := ShaderMaterial.new()
    write_material.shader = SHADER_WRITE
    write_material.render_priority = -19
    _read_equal = ShaderMaterial.new()
    _read_equal.shader = SHADER_EQUAL
    _read_equal.render_priority = -18
    _read_unequal = ShaderMaterial.new()
    _read_unequal.shader = SHADER_UNEQUAL
    _read_unequal.render_priority = -18
    _writer = _make_box("CalibrationStencilWriter", Vector3.ONE,
        write_material)
    _reader = _make_box("CalibrationStencilReader", Vector3.ONE * 1.18,
        _read_equal)
    visible = false
    set_process(false)

func _make_box(name_text: String, box_size: Vector3,
        mat: ShaderMaterial) -> MeshInstance3D:
    var draw := MeshInstance3D.new()
    draw.name = name_text
    draw.set_meta("sera_generated_live_edge", true)
    draw.set_meta("FX_NO_OUTLINE", true)
    var cube := BoxMesh.new()
    cube.size = box_size
    draw.mesh = cube
    draw.material_override = mat
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    draw.extra_cull_margin = 1.0
    add_child(draw)
    return draw

func set_probe_mode(mode: int) -> void:
    _mode = mode if (mode == 10 or mode == 11) else 0
    visible = _mode != 0
    _reader.material_override = (
        _read_equal if _mode == 10 else _read_unequal)
    if visible:
        _position_cube()
    set_process(visible)

func _process(_delta: float) -> void:
    if visible:
        _position_cube()

func _position_cube() -> void:
    var camera: Camera3D = get_viewport().get_camera_3d()
    _camera_seen = is_instance_valid(camera)
    if not _camera_seen:
        return
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    var pixel: Vector2 = Vector2(viewport.x * 0.16, viewport.y * 0.47)
    var distance: float = 4.0
    if is_instance_valid(_rig):
        distance = camera.global_position.distance_to(_rig.global_position)
    distance = maxf(distance * 0.70, camera.near * 5.0)
    var anchor: Vector3 = camera.project_position(pixel, distance)
    var near_right: Vector3 = camera.project_position(
        pixel + Vector2(32.0, 0.0), distance)
    var scale_factor: float = maxf(0.02,
        anchor.distance_to(near_right) * 1.15)
    global_transform = Transform3D(
        camera.global_transform.basis.orthonormalized(), anchor)
    scale = Vector3.ONE * scale_factor

func get_probe_snapshot() -> Dictionary:
    return {"mode": _mode, "camera": _camera_seen,
        "write_ref": 29, "reader": "equal" if _mode == 10 else (
            "not_equal" if _mode == 11 else "disabled")}
