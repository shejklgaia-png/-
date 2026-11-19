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
    # The top tier is NEXUS itself (outside BaseFacilities), so the
    # machines must span both sides and the lower tier. Combined vertical
    # coverage is verified below using the actual NEXUS 3D projection.
    if min_screen.x > 0.24 or max_screen.x < 0.76 or max_screen.y < 0.73:
        _fail("outer facilities do not span the screen sides and lower edge: " +
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
    # v505 contract (defined before implementation): NEXUS takes the upper
    # center; LABO is the center anchor; all six machines form a surrounding
    # ring, keeping the lower build terminal accessible. Do not check only
    # raw coordinates: require the hierarchy to be visible on the 720x1280
    # projected Android screen.
    var nexus_uv: Vector2 = nexus_spot / view
    # The full visual footprint still reaches the upper and lower parts of
    # the screen: NEXUS now owns the upper band, resources own the lower.
    if minf(min_screen.y, nexus_uv.y) > 0.33 or max_screen.y < 0.73:
        _fail("NEXUS and peripheral equipment do not cover the full screen")
        return
    var labo: Node3D = machines.get_node_or_null("LABO") as Node3D
    if labo == null:
        _fail("central LABO is absent")
        return
    var labo_spot: Vector2 = camera.unproject_position(
        labo.global_position + Vector3(0.0, 1.0, 0.0))
    var labo_uv: Vector2 = labo_spot / view
    if bool(hub.call("_nexus_hit", labo_spot)):
        _fail("NEXUS tap volume covers the central LABO")
        return
    if str(machines.call("key_at", camera, nexus_spot)) != "":
        _fail("device tap volume covers the upper NEXUS")
        return
    if absf(nexus_uv.x - 0.5) > 0.14 or (
            nexus_uv.y > 0.33 or nexus_uv.y < 0.12):
        _fail("NEXUS is not at the upper center: " + str(nexus_uv))
        return
    if absf(labo_uv.x - 0.5) > 0.12 or (
            labo_uv.y < 0.36 or labo_uv.y > 0.63):
        _fail("LABO is not central: " + str(labo_uv))
        return
    if labo_uv.y - nexus_uv.y < 0.16:
        _fail("NEXUS and LABO do not have a clear screen-space separation")
        return
    var left_count: int = 0
    var right_count: int = 0
    var bottom_count: int = 0
    for key in names:
        if key == "LABO":
            continue
        var field_node: Node3D = machines.get_node(key) as Node3D
        var device_uv: Vector2 = camera.unproject_position(
            field_node.global_position + Vector3(0.0, 1.0, 0.0)) / view
        # Every other device must stay outside the center LABO zone,
        # or be clearly underneath it (the lower construction terminal).
        if absf(device_uv.x - 0.5) < 0.19 and device_uv.y < 0.71:
            _fail("outer device occupies the center LABO zone: " + key)
            return
        if device_uv.x <= 0.31:
            left_count += 1
        elif device_uv.x >= 0.69:
            right_count += 1
        if device_uv.y >= 0.72:
            bottom_count += 1
    if left_count < 2 or right_count < 2 or bottom_count < 1:
        _fail("resources do not surround the central LABO on both sides")
        return
    # CRATE must orbit the new center instead of walking through the LABO
    # foundation. Validate every segment, including the loop's closing edge.
    # Read the production route without duplicating its waypoints in the test.
    var route: Array = hub.get_script().get_script_constant_map().get("CRATE_WAYPOINTS", [])
    var start_crate: Node3D = hub.get_node("CRATE") as Node3D
    if start_crate == null or route.size() < 4:
        _fail("CRATE center-avoidance route is missing")
        return
    var route_origin := Vector2(start_crate.position.x, start_crate.position.z)
    var from: Vector2 = route_origin
    for goal in route:
        var to: Vector2 = goal
        for sample_index in range(17):
            var progress: float = float(sample_index) / 16.0
            var point: Vector2 = from.lerp(to, progress)
            if not bool(hub.call("_walkable", Vector3(point.x, 0.08, point.y))):
                _fail("CRATE crosses a building on its patrol")
                return
        from = to
    for sample_index in range(17):
        var point: Vector2 = from.lerp(route[0], float(sample_index) / 16.0)
        if not bool(hub.call("_walkable", Vector3(point.x, 0.08, point.y))):
            _fail("CRATE closing patrol route crosses a building")
            return
    print("SERA_BASE_FACILITIES_RUNTIME_PASS")
    quit(0)
