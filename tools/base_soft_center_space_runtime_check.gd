extends SceneTree
## BASE composition: lightly open middle, not a formal empty plaza.
## Validate actual 3D positions, single facility slabs and scattered micro props.
const Deck = preload("res://scripts/sera_base_deck_layout.gd")
const KEYS = ["NEXUS", "LABO", "SMELTER", "RECYCLER",
    "STORAGE", "GENERATOR", "SCRAP_COLLECTOR", "BUILD_TERMINAL"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_SOFT_CENTER_SPACE_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    if scene == null:
        _fail("cannot load actual base")
        return
    var hub: Node3D = scene.instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var camera: Camera3D = hub.get("cam") as Camera3D
    var facilities: Node3D = hub.get_node("BaseFacilities") as Node3D
    var nexus: Node3D = hub.get_node("NEXUSBuilding") as Node3D
    if camera == null or facilities == null or nexus == null:
        _fail("missing base objects")
        return
    var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
    var labo: Node3D = facilities.get_node("LABO") as Node3D
    var labo_uv: Vector2 = camera.unproject_position(
        labo.global_position) / viewport
    var nexus_uv: Vector2 = camera.unproject_position(
        nexus.global_position) / viewport
    if absf(labo_uv.x - 0.52) > 0.06 or (
            labo_uv.y < 0.60 or labo_uv.y > 0.69):
        _fail("LABO must sit slightly below the open middle")
        return
    if absf(nexus_uv.x - 0.50) > 0.10 or (
            labo_uv.y - nexus_uv.y < 0.29 or
            labo_uv.y - nexus_uv.y > 0.44):
        _fail("center gap is too cramped or a huge formal plaza")
        return
    var specs: Array = facilities.get_script().get_script_constant_map().get(
        "FACILITY_SPECS", [])
    var sites: Array[Dictionary] = Deck.facility_sites(nexus.position, specs)
    var panels: Array[Dictionary] = Deck.generate(42, 3.0, sites)
    var site_count: int = 0
    var center := Rect2(Vector2(-1.20, -3.60), Vector2(2.40, 2.60))
    for panel in panels:
        if str(panel["site"]).is_empty():
            continue
        site_count += 1
        var center_at: Vector2 = panel["center"]
        var size: Vector2 = panel["size"]
        var r := Rect2(center_at - size * 0.5, size)
        if r.intersects(center):
            _fail("building/facility site occupies the subtle center clearance")
            return
    if site_count != 8:
        _fail("lost a facility's dedicated one-piece slab")
        return
    var scraps: int = 0
    var nearby: int = 0
    var inside: int = 0
    var center_at := Vector2(0.0, -2.20)
    for node in hub.get_children():
        if not node is Node3D or not str(node.name).begins_with("ScrapPile_"):
            continue
        var scrap: Node3D = node as Node3D
        scraps += 1
        var spot: Vector2 = Vector2(scrap.position.x, scrap.position.z)
        var distance: float = spot.distance_to(center_at)
        if distance < 1.50:
            inside += 1
        if distance >= 1.50 and distance <= 5.50:
            nearby += 1
        if not bool(hub.call("_walkable", scrap.position + Vector3(0.0, 0.08, 0.0))):
            # Props placed outside station foundations may be on maintenance
            # lanes, but must not occupy the station cores themselves.
            if distance <= 5.50:
                _fail("central salvage piece blocks a facility")
                return
    if scraps != 16 or nearby < 2 or nearby > 6 or inside > 0:
        _fail("center needs loose props at its edges, not a barren void or pileup: " +
            str(scraps) + "/" + str(nearby) + "/" + str(inside))
        return
    # Distinctly staggered side stations; do not restore a rigid 3x3 grid.
    var left_heights: Array[float] = []
    var right_heights: Array[float] = []
    for key in KEYS:
        if key in ["NEXUS", "LABO"]:
            continue
        var station: Node3D = facilities.get_node(key) as Node3D
        var uv: Vector2 = camera.unproject_position(station.position) / viewport
        if uv.x < 0.38:
            left_heights.append(uv.y)
        elif uv.x > 0.62:
            right_heights.append(uv.y)
        else:
            _fail("outer facility intrudes into loose central route: " + key)
            return
    if left_heights.size() != 3 or right_heights.size() != 3:
        _fail("peripheral stations no longer surround the middle")
        return
    left_heights.sort()
    right_heights.sort()
    for i in range(3):
        if absf(left_heights[i] - right_heights[i]) < 0.007:
            _fail("left and right sites have become an exact mirrored grid")
            return
    print("SERA_BASE_SOFT_CENTER_SPACE_PASS: 8 staggered sites, 16 props, moderate gap")
    quit(0)
