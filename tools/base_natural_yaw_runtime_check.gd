extends SceneTree
## Preserve eight tappable, single-slab stations while varying actual draw geometry.
const Props = preload("res://scripts/sera_base_clutter.gd")
const Arch = preload("res://scripts/sera_base_architecture.gd")
const Deck = preload("res://scripts/sera_base_deck_layout.gd")
const KEYS = ["NEXUS", "LABO", "SMELTER", "RECYCLER",
    "STORAGE", "GENERATOR", "SCRAP_COLLECTOR", "BUILD_TERMINAL"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_NATURAL_YAW_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var nexus: Node3D = hub.get_node("NEXUSBuilding") as Node3D
    var facilities: Node3D = hub.get_node("BaseFacilities") as Node3D
    var camera: Camera3D = hub.get("cam") as Camera3D
    var yaw_values: Dictionary = {}
    var specs: Array = facilities.get_script().get_script_constant_map().get("FACILITY_SPECS", [])
    var sites: Array[Dictionary] = Deck.facility_sites(nexus.position, specs)
    var panels: Array[Dictionary] = Deck.generate(42, 3.0, sites)
    var site_panels: Dictionary = {}
    for panel in panels:
        if not str(panel["site"]).is_empty():
            site_panels[str(panel["site"])] = panel
    if site_panels.size() != 8:
        _fail("all eight single-slab sites must remain")
        return
    for key in KEYS:
        var root_node: Node3D = nexus if key == "NEXUS" else (
            facilities.get_node(key) as Node3D)
        var visual: Node3D = root_node.get_node(
            "NexusArchitecture" if key == "NEXUS" else "IndustrialModel") as Node3D
        var foundation: MeshInstance3D = root_node.get_node("Foundation") as MeshInstance3D
        var yaw: float = Arch.facility_yaw_radians(key)
        if absf(rad_to_deg(yaw)) < 9.0 or absf(rad_to_deg(yaw)) > 23.0:
            _fail(key + " station has no legible but restrained yaw")
            return
        if absf(foundation.rotation.y - yaw) > 0.0001:
            _fail(key + " pad chassis is not aligned with station")
            return
        if absf(float(visual.get_meta("body_yaw", 0.0)) - yaw) > 0.0001:
            _fail(key + " architecture not oriented")
            return
        yaw_values[roundi(rad_to_deg(yaw))] = true
        var props: Array[Dictionary] = Props.props_for(key)
        var positive: int = 0
        var negative: int = 0
        var panel: Dictionary = site_panels[key]
        var slab_center: Vector2 = panel["center"]
        var slab_size: Vector2 = panel["size"]
        var site_origin: Vector2 = Vector2(root_node.position.x, root_node.position.z)
        var slab := Rect2(slab_center - site_origin - slab_size * 0.5, slab_size)
        var used: Array[Rect2] = []
        for p in props:
            var angle: float = float(p.get("yaw_deg", 0.0))
            var original: Vector2 = Props.bounds_for(str(p["kind"])) * float(p["scale"])
            var c: float = absf(cos(deg_to_rad(angle)))
            var sn: float = absf(sin(deg_to_rad(angle)))
            var extent := Vector2(original.x * c + original.y * sn,
                original.x * sn + original.y * c)
            var bounds := Rect2((p["at"] as Vector2) - extent * 0.5, extent)
            if not slab.grow(-0.15).encloses(bounds):
                _fail(key + " rotated prop crosses its dedicated slab")
                return
            for other in used:
                if bounds.intersects(other):
                    _fail(key + " angled prop clusters intersect")
                    return
            used.append(bounds)
            if angle > 5.0:
                positive += 1
            elif angle < -5.0:
                negative += 1
        if positive < 2 or negative < 2:
            _fail(key + " props are too parallel: " +
                str(positive) + "/" + str(negative))
            return
        var visible: Array = visual.get_meta("clutter_props", [])
        if visible.size() != props.size():
            _fail(key + " prop metadata differs from generated geometry")
            return
        var actual_rotated: int = 0
        for child in visual.get_children():
            if not child is MultiMeshInstance3D:
                continue
            var draw: MultiMeshInstance3D = child as MultiMeshInstance3D
            if not draw.name.begins_with("Architectural_cube_rubber"):
                continue
            var mm: MultiMesh = draw.multimesh
            for index in range(mm.instance_count):
                var pose: Transform3D = mm.get_instance_transform(index)
                var heading: float = rad_to_deg(atan2(-pose.basis.x.z, pose.basis.x.x))
                if absf(heading) > 4.0:
                    actual_rotated += 1
        if actual_rotated < 3:
            _fail(key + " has no actually rotated floor props")
            return
    if yaw_values.size() < 7:
        _fail("facility headings insufficiently scattered")
        return
    if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("BASE camera changed")
        return
    for key in KEYS:
        var node: Node3D = nexus if key == "NEXUS" else (
            facilities.get_node(key) as Node3D)
        var pixel: Vector2 = camera.unproject_position(
            node.global_position + Vector3(0, 1.0, 0))
        if key == "NEXUS":
            if not bool(hub.call("_nexus_hit", pixel)):
                _fail("NEXUS touch was lost")
                return
        elif str(facilities.call("key_at", camera, pixel)) != key:
            _fail("facility touch was lost: " + key)
            return
    print("SERA_BASE_NATURAL_YAW_RUNTIME_PASS 8 independently oriented stations and props")
    quit(0)
