extends SceneTree
## In a real Godot scene the generated ImmediateMesh must cover the center
## during ordinary shield contact, but leave a clear hole after a break.
const FX = preload("res://scripts/enemy_shield_hit_fx.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V514_SHIELD_MEMBRANE_FAILED: " + why)
    quit(1)

func _sample_center(mesh: ImmediateMesh, camera: Camera3D,
        center: Vector2) -> Dictionary:
    if mesh.get_surface_count() == 0:
        return {"valid": false, "center_alpha": 0.0, "nearest_visible": 0.0}
    var arrays: Array = mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
    if vertices.is_empty() or colors.size() != vertices.size():
        return {"valid": false, "center_alpha": 0.0, "nearest_visible": 0.0}
    var center_alpha: float = 0.0
    var nearest_visible: float = INF
    for i in range(vertices.size()):
        var d: float = camera.unproject_position(vertices[i]).distance_to(center)
        if d < 0.75:
            center_alpha = maxf(center_alpha, colors[i].a)
        if colors[i].a > 0.04:
            nearest_visible = minf(nearest_visible, d)
    return {
        "valid": true,
        "center_alpha": center_alpha,
        "nearest_visible": nearest_visible,
    }

func _run() -> void:
    var camera := Camera3D.new()
    root.add_child(camera)
    camera.make_current()
    var fx: Node3D = FX.new()
    root.add_child(fx)
    fx.set("view_camera", camera)
    var hit := Vector3(0.0, 0.0, -6.0)
    var center: Vector2 = camera.unproject_position(hit)
    var mat: StandardMaterial3D = fx.get("material")
    if mat == null or mat.no_depth_test or (
            mat.render_priority != 115) or (
            mat.blend_mode != BaseMaterial3D.BLEND_MODE_MIX):
        _fail("contact membrane lost depth-tested color-preserving layering")
        return
    # Even after the white *flash* dies, a colored solid membrane remains.
    fx.call("start_impact", hit, 0.95, false)
    fx.call("advance", 0.15)
    var mesh: ImmediateMesh = fx.get("mesh")
    var normal: Dictionary = _sample_center(mesh, camera, center)
    if not bool(normal["valid"]) or float(normal["center_alpha"]) < 0.50 or (
            float(normal["nearest_visible"]) > 0.75):
        _fail("ordinary hit has a missing, hollow, or dim membrane center")
        return
    # The break is the ONLY state with an open center. Sample after the
    # horizontal crack has faded so that only the broken annulus remains.
    fx.call("reset")
    fx.call("start_impact", hit, 0.0, true)
    fx.call("advance", 0.40)
    var broken: Dictionary = _sample_center(mesh, camera, center)
    if not bool(broken["valid"]) or (
            float(broken["center_alpha"]) > 0.01) or (
            float(broken["nearest_visible"]) < 16.0):
        _fail("broken membrane failed to open a visibly empty center")
        return
    var audio: AudioStreamPlayer = fx.get("break_audio")
    if audio == null or audio.stream == null:
        _fail("shield shatter lost its sound")
        return
    # Once the break effect expires, no persistent transparent shell remains.
    fx.call("advance", 0.30)
    if mesh.get_surface_count() != 0:
        _fail("the torn membrane did not disappear at the end of the burst")
        return
    fx.queue_free()
    camera.queue_free()
    print("GODOT_V514_SOLID_MEMBRANE_AND_SHATTER_HOLE_PASS")
    quit(0)
