extends SceneTree
## Test the approved lower screen composition against live Godot projection.
const STATIONS = [
    "LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER",
    "GENERATOR", "STORAGE", "BUILD_TERMINAL",
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_LOWER_LARGER_COMPOSITION_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(28):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null:
            break
    var camera: Camera3D = hub.get("cam") as Camera3D
    var nexus: Node3D = hub.get_node_or_null("NEXUSBuilding") as Node3D
    var stations: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if camera == null or nexus == null or stations == null:
        _fail("BASE camera/facilities missing")
        return
    if camera.projection != Camera3D.PROJECTION_ORTHOGONAL or (
            not is_equal_approx(camera.size, 38.0)):
        _fail("base camera lost orthographic composition")
        return
    if camera.position.distance_to(Vector3(21.0, 25.1, 25.0)) > 0.02:
        _fail("camera was not translated downward on screen")
        return
    var view: Vector2 = camera.get_viewport().get_visible_rect().size
    var nexus_uv: Vector2 = camera.unproject_position(nexus.global_position) / view
    if nexus_uv.x < 0.45 or nexus_uv.x > 0.55 or (
            nexus_uv.y < 0.31 or nexus_uv.y > 0.34):
        _fail("NEXUS not centered near upper third: " + str(nexus_uv))
        return
    var nexus_model: Node3D = nexus.get_node_or_null("NexusArchitecture") as Node3D
    if nexus_model == null or (
            not is_equal_approx(float(nexus_model.get_meta(
            "visual_model_scale", 0.0)), 1.14)):
        _fail("NEXUS was enlarged or replaced")
        return
    for key in STATIONS:
        var node: Node3D = stations.get_node_or_null(key) as Node3D
        if node == null:
            _fail("missing station: " + key)
            return
        var model: Node3D = node.get_node_or_null("IndustrialModel") as Node3D
        if model == null:
            _fail("missing station model: " + key)
            return
        var expected: float = 1.45 if key == "LABO" else 1.55
        if not is_equal_approx(
                float(model.get_meta("visual_model_scale", 0.0)), expected):
            _fail("station not enlarged: " + key)
            return
        var projected: Rect2 = stations.call("_projected_bounds", camera, key)
        var uv: Rect2 = Rect2(projected.position / view, projected.size / view)
        var lower_margin: float = 0.945 if key in [
            "SCRAP_COLLECTOR", "BUILD_TERMINAL"] else 0.89
        if uv.position.x < 0.03 or uv.end.x > 0.96 or (
                uv.position.y < 0.13 or uv.end.y > lower_margin):
            _fail("station clipped / enters HUD: " + key + " " + str(uv))
            return
        var tap: Vector2 = camera.unproject_position(
            node.global_position + Vector3(0.0, 1.0, 0.0))
        if str(stations.call("key_at", camera, tap)) != key:
            _fail("enlarged station cannot be tapped: " + key)
            return
    var terminal: Node3D = stations.get_node("BUILD_TERMINAL") as Node3D
    var bottom_uv: Vector2 = camera.unproject_position(
        terminal.global_position) / view
    if bottom_uv.y < 0.855 or bottom_uv.y > 0.89:
        _fail("lower yard still leaves excess space: " + str(bottom_uv))
        return
    var lab: Node3D = stations.get_node("LABO") as Node3D
    var lab_uv: Vector2 = camera.unproject_position(lab.global_position) / view
    if lab_uv.y < 0.67 or lab_uv.y > 0.71:
        _fail("LABO moved off lower central area: " + str(lab_uv))
        return
    for lower in ["SCRAP_COLLECTOR", "BUILD_TERMINAL"]:
        var lower_node: Node3D = stations.get_node(lower) as Node3D
        var lower_uv: Vector2 = camera.unproject_position(
            lower_node.global_position) / view
        if lower_uv.y - lab_uv.y < 0.16:
            _fail("LABO and lower facility are still crowded: " + lower)
            return
    print("SERA_BASE_LOWER_LARGER_COMPOSITION_RUNTIME_PASS")
    quit(0)
