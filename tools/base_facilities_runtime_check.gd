extends SceneTree
## Physical, camera-pickable LABO/resource machines with an independent modal UI.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_BASE_FACILITIES_RUNTIME_FAIL: " + why)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/base_exploration.tscn")
    if packed == null:
        _fail("base scene missing")
        return
    var hub: Node3D = packed.instantiate()
    root.add_child(hub)
    await process_frame
    var camera: Camera3D = hub.get("cam") as Camera3D
    var machines: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if machines == null or camera == null:
        _fail("facilities or hub camera missing")
        return
    var names := ["LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER",
        "GENERATOR", "STORAGE", "BUILD_TERMINAL"]
    for name in names:
        var machine: Node3D = machines.get_node_or_null(name) as Node3D
        if machine == null or machine.get_child_count() < 2:
            _fail("missing solid 3D device: " + name)
            return
        var spot: Vector2 = camera.unproject_position(
            machine.global_position + Vector3(0.0, 1.0, 0.0))
        if str(machines.call("key_at", camera, spot)) != name:
            _fail("3D screen picking failed: " + name)
            return
        machines.call("open_facility", name)
        var modal: Control = machines.get("modal") as Control
        if modal == null or not modal.visible:
            _fail("device menu does not open: " + name)
            return
        machines.call("close_menu")
        if modal.visible:
            _fail("device menu cannot close: " + name)
            return
    if str(machines.call("key_at", camera, Vector2(-1000, -1000))) != "":
        _fail("picking outside facilities is not empty")
        return
    var nexus: Node3D = hub.get_node_or_null("NEXUSBuilding") as Node3D
    if nexus == null:
        _fail("original NEXUS building is gone")
        return
    var nexus_spot: Vector2 = camera.unproject_position(
        nexus.global_position + Vector3(0.0, 2.5, 0.0))
    if not bool(hub.call("_nexus_hit", nexus_spot)):
        _fail("NEXUS entrance is no longer pickable")
        return
    print("SERA_BASE_FACILITIES_RUNTIME_PASS")
    quit(0)
