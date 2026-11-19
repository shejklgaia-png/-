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
    # Approved layout: distribute the visible facilities across the
    # portrait viewport, not as a cluster of machinery around NEXUS.
    # These requirements are independent of individual world coordinates.
    var view: Vector2 = camera.get_viewport().get_visible_rect().size
    var min_screen := Vector2(INF, INF)
    var max_screen := Vector2(-INF, -INF)
    var foundations: Array[MeshInstance3D] = []
    for name in names:
        var machine: Node3D = machines.get_node_or_null(name) as Node3D
        if machine == null or machine.get_child_count() < 2:
            _fail("missing solid 3D device: " + name)
            return
        var foundation: MeshInstance3D = machine.get_node_or_null(
            "Foundation") as MeshInstance3D
        if foundation == null or not (foundation.mesh is BoxMesh):
            _fail("physical foundation missing: " + name)
            return
        var footprint: Vector3 = (foundation.mesh as BoxMesh).size
        for earlier in foundations:
            var other: Vector3 = (earlier.mesh as BoxMesh).size
            var other_node: Node3D = earlier.get_parent() as Node3D
            var dx: float = absf(machine.global_position.x -
                other_node.global_position.x)
            var dz: float = absf(machine.global_position.z -
                other_node.global_position.z)
            if dx < (footprint.x + other.x) * 0.5 + 0.30 and (
                    dz < (footprint.z + other.z) * 0.5 + 0.30):
                _fail("two physical facilities are crowded together: " + name)
                return
        foundations.append(foundation)
        var spot: Vector2 = camera.unproject_position(
            machine.global_position + Vector3(0.0, 1.0, 0.0))
        var uv: Vector2 = spot / view
        if uv.x < 0.065 or uv.x > 0.935 or (
                uv.y < 0.16 or uv.y > 0.87):
            _fail("facility moved off practical portrait tap area: " + name)
            return
        min_screen = Vector2(minf(min_screen.x, uv.x), minf(min_screen.y, uv.y))
        max_screen = Vector2(maxf(max_screen.x, uv.x), maxf(max_screen.y, uv.y))
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
    if min_screen.x > 0.24 or max_screen.x < 0.76 or (
            min_screen.y > 0.33 or max_screen.y < 0.73):
        _fail("hub facilities do not occupy the full portrait screen: " +
            str(min_screen) + " - " + str(max_screen))
        return
    machines.call("update_tags", camera)
    var tags: Dictionary = machines.get("facility_tags")
    for name in names:
        var label: Label = tags.get(name) as Label
        if label == null or not label.visible or (
                label.position.x < 0 or label.position.y < 95.0) or (
                label.position.x + label.size.x > view.x + 0.01) or (
                label.position.y + label.size.y > view.y + 0.01):
            _fail("facility label clipped or hidden: " + name)
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
