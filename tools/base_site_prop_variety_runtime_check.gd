extends SceneTree
## Verify authored props, category variation, non-overlap and exact site containment.
const Deck = preload("res://scripts/sera_base_deck_layout.gd")
const Props = preload("res://scripts/sera_base_clutter.gd")
const KEYS := [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER",
    "GENERATOR", "STORAGE", "BUILD_TERMINAL",
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_SITE_PROP_VARIETY_FAIL: " + message)
    quit(1)

func _overlap(a: Rect2, b: Rect2) -> bool:
    return a.position.x < b.end.x and a.end.x > b.position.x and (
        a.position.y < b.end.y and a.end.y > b.position.y)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    if scene == null:
        _fail("scene unavailable")
        return
    var hub: Node3D = scene.instantiate()
    root.add_child(hub)
    await process_frame
    var nexus: Node3D = hub.get_node_or_null("NEXUSBuilding") as Node3D
    var facilities: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if nexus == null or facilities == null:
        _fail("missing physical buildings")
        return
    var specs: Array = facilities.get_script().get_script_constant_map().get(
        "FACILITY_SPECS", [])
    var sites: Array[Dictionary] = Deck.facility_sites(nexus.position, specs)
    var panels: Array[Dictionary] = Deck.generate(42, 3.0, sites)
    var reserved: Dictionary = {}
    for panel in panels:
        if not str(panel["site"]).is_empty():
            reserved[str(panel["site"])] = panel
    if reserved.size() != 8:
        _fail("all eight dedicated site slabs must remain intact")
        return
    var seen_shapes: Dictionary = {}
    var total: int = 0
    for key in KEYS:
        var props: Array[Dictionary] = Props.props_for(key)
        if props.size() < 6 or props.size() > 12:
            _fail(key + " needs 6-12 authored prop clusters")
            return
        var own_shapes: Dictionary = {}
        var occupied: Array[Rect2] = []
        var panel: Dictionary = reserved[key]
        var slab_center: Vector2 = panel["center"]
        var slab_size: Vector2 = panel["size"]
        var site: Dictionary = {}
        for candidate in sites:
            if candidate["id"] == key:
                site = candidate
        var local_slab_center: Vector2 = slab_center - (site["at"] as Vector2)
        var slab: Rect2 = Rect2(local_slab_center - slab_size * 0.5,
            slab_size)
        # Keep the center of the site and its active/front-facing walkway open.
        var protected: Rect2 = (
            Rect2(Vector2(-3.38, -2.85), Vector2(6.76, 6.60))
            if key == "NEXUS" else
            Rect2(Vector2(-2.18, -1.98), Vector2(4.36, 4.98))
            if key == "LABO" else
            Rect2(Vector2(-1.37, -1.37), Vector2(2.74, 2.86)))
        for p in props:
            var kind: String = str(p["kind"])
            var at: Vector2 = p["at"]
            var footprint: Vector2 = Props.bounds_for(kind) * float(p["scale"])
            var rect := Rect2(at - footprint * 0.5, footprint)
            if not slab.grow(-0.15).encloses(rect):
                _fail(key + " prop " + kind + " crosses site-panel edge")
                return
            if _overlap(rect, protected):
                _fail(key + " prop " + kind + " blocks machinery or entrance")
                return
            for previous in occupied:
                if _overlap(rect, previous):
                    _fail(key + " prop clusters overlap")
                    return
            occupied.append(rect)
            own_shapes[kind] = true
            seen_shapes[kind] = true
        if own_shapes.size() < 5:
            _fail(key + " does not have enough distinctive prop types")
            return
        var parent: Node3D = (
            nexus.get_node_or_null("NexusArchitecture") as Node3D
            if key == "NEXUS" else
            facilities.get_node_or_null(key + "/IndustrialModel") as Node3D)
        if parent == null:
            _fail("missing decorated model for " + key)
            return
        var rendered: Array = parent.get_meta("clutter_props", []) as Array
        if rendered.size() != props.size():
            _fail(key + " prop data not submitted to actual batch")
            return
        total += props.size()
    if total != 76 or seen_shapes.size() < 63:
        _fail("insufficient global assortment across base facilities")
        return
    print("SERA_BASE_SITE_PROP_VARIETY_RUNTIME_PASS props=", total,
        " unique_shapes=", seen_shapes.size())
    quit(0)
