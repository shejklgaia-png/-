extends SceneTree
## Actual Godot scene contract: five clearly separated portrait tiers, 152
## rendered prop entries on eight distinct pads, 76 additional tiny meshes.
const Props = preload("res://scripts/sera_base_clutter.gd")
const KEYS = [
    "NEXUS", "SMELTER", "RECYCLER", "STORAGE", "GENERATOR",
    "LABO", "SCRAP_COLLECTOR", "BUILD_TERMINAL",
]
const APPROVED_Y = {
    "NEXUS": 0.285, "SMELTER": 0.406, "RECYCLER": 0.418,
    "STORAGE": 0.582, "GENERATOR": 0.590, "LABO": 0.670,
    "SCRAP_COLLECTOR": 0.851, "BUILD_TERMINAL": 0.861,
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_TALL_DENSE_COMPOSITION_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(22):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null:
            break
    var camera: Camera3D = hub.get("cam") as Camera3D
    var facilities: Node3D = hub.get_node("BaseFacilities") as Node3D
    var nexus: Node3D = hub.get_node("NEXUSBuilding") as Node3D
    if camera == null or facilities == null or nexus == null:
        _fail("live BASE scene is incomplete")
        return
    if camera.projection != Camera3D.PROJECTION_ORTHOGONAL or (
            absf(camera.size - 38.0) > 0.001):
        _fail("mobile portrait camera was altered")
        return
    var frame_size: Vector2 = camera.get_viewport().get_visible_rect().size
    var total: int = 0
    var extra: int = 0
    for key in KEYS:
        var site: Node3D = nexus if key == "NEXUS" else (
            facilities.get_node(key) as Node3D)
        var uv: Vector2 = camera.unproject_position(site.global_position) / frame_size
        if absf(uv.y - float(APPROVED_Y[key])) > 0.022:
            _fail(key + " outside approved vertical tier " + str(uv))
            return
        var model: Node3D = site.get_node(
            "NexusArchitecture" if key == "NEXUS" else "IndustrialModel") as Node3D
        var actual: Array = model.get_meta("clutter_props", [])
        var original: Array[Dictionary] = Props._authored_props_for(key)
        if actual.size() != original.size() * 2:
            _fail(key + " was not doubled: " + str(actual.size()))
            return
        var site_extra: int = 0
        for prop in actual:
            if bool(prop.get("satellite", false)):
                site_extra += 1
        if site_extra != original.size():
            _fail(key + " has too few non-overlapping satellite models")
            return
        total += actual.size()
        extra += site_extra
    if total != 152 or extra != 76:
        _fail("BASE requires 152 physical prop placements, received " +
            str(total) + "/" + str(extra))
        return
    var first: Vector2 = camera.unproject_position(nexus.global_position) / frame_size
    var last: Node3D = facilities.get_node("BUILD_TERMINAL") as Node3D
    var bottom: Vector2 = camera.unproject_position(last.global_position) / frame_size
    if bottom.y - first.y < 0.54:
        _fail("BASE was collapsed into a compact vertical knot")
        return
    print("SERA_BASE_TALL_DENSE_COMPOSITION_RUNTIME_PASS: 152 props / 76 satellites / five tiers")
    quit(0)
