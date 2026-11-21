extends SceneTree
## Physical invariants: each of the eight facilities has one dedicated slab,
## the building footprint is inset by at least 1m, and no other tile intersects.
const Layout = preload("res://scripts/sera_base_deck_layout.gd")
const BaseFacilities = preload("res://scripts/base_facility_system.gd")
const HUB = preload("res://scripts/base_exploration.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_FACILITY_SINGLE_PANEL_FAIL: " + message)
    quit(1)

func _run() -> void:
    var sites: Array[Dictionary] = Layout.facility_sites(
        HUB.NEXUS_BUILDING_ORIGIN, BaseFacilities.FACILITY_SPECS)
    if sites.size() != 8:
        _fail("exactly eight separate facility slabs required")
        return
    var layout: Array[Dictionary] = Layout.generate(42, 3.0, sites)
    var found: Dictionary = {}
    for panel in layout:
        var id: String = str(panel["site"])
        if id.is_empty():
            continue
        if found.has(id):
            _fail("facility spans multiple deck panels: " + id)
            return
        found[id] = panel
    if found.size() != 8:
        _fail("one or more reserved facility slabs missing")
        return
    var occupied := PackedByteArray()
    occupied.resize(170 * 170)
    for panel in layout:
        var rect: Rect2 = panel["cells"]
        var ix: int = roundi(rect.position.x * 2.0)
        var iz: int = roundi(rect.position.y * 2.0)
        var nx: int = roundi(rect.size.x * 2.0)
        var nz: int = roundi(rect.size.y * 2.0)
        if ix < 0 or iz < 0 or ix + nx > 170 or iz + nz > 170:
            _fail("panel leaves the full base floor")
            return
        for z in range(iz, iz + nz):
            for x in range(ix, ix + nx):
                var addr: int = z * 170 + x
                if occupied[addr] != 0:
                    _fail("different floor panels overlap")
                    return
                occupied[addr] = 1
    for flag in occupied:
        if flag != 1:
            _fail("gap in logical floor outside 6cm metal seams")
            return
    for site in sites:
        var key: String = str(site["id"])
        if not found.has(key):
            _fail("no single slab for " + key)
            return
        var panel: Dictionary = found[key]
        var center: Vector2 = panel["center"]
        var size: Vector2 = panel["size"]
        var at: Vector2 = site["at"]
        var footprint: Vector2 = site["physical"]
        var left_gap: float = at.x - footprint.x * 0.5 - (center.x - size.x * 0.5)
        var right_gap: float = center.x + size.x * 0.5 - (at.x + footprint.x * 0.5)
        var rear_gap: float = at.y - footprint.y * 0.5 - (center.y - size.y * 0.5)
        var front_gap: float = center.y + size.y * 0.5 - (at.y + footprint.y * 0.5)
        if minf(minf(left_gap, right_gap), minf(rear_gap, front_gap)) < 0.99:
            _fail("not enough empty surface around " + key)
            return
        if size.x < footprint.x + 2.0 or size.y < footprint.y + 2.0:
            _fail("undersized dedicated equipment slab: " + key)
            return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    var floor: Node3D = hub.get_node_or_null("PatchworkSteelFloor") as Node3D
    var machines: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if floor == null or machines == null:
        _fail("base floor / machines lost")
        return
    var batches: int = 0
    var instances: int = 0
    for child in floor.get_children():
        if child.name.begins_with("GridPlateBatch_"):
            batches += 1
            instances += (child as MultiMeshInstance3D).multimesh.instance_count
    if batches != 6 or instances != layout.size():
        _fail("batched rendered geometry diverges from single-panel layout")
        return
    for site in sites:
        var key: String = str(site["id"])
        if key == "NEXUS":
            if hub.get_node_or_null("NEXUSBuilding") == null:
                _fail("NEXUS missing from its platform")
                return
        elif machines.get_node_or_null(key) == null:
            _fail("missing facility on its reserved panel: " + key)
            return
    print("SERA_BASE_FACILITY_SINGLE_PANEL_RUNTIME_PASS 8 sites ", layout.size(), " slabs")
    quit(0)
