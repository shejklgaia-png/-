extends SceneTree
## Independent scene-based check: 24 independently modeled small ornaments, density,
## per-site 1-piece pad containment, clear entrance and material batch output.
const Props = preload("res://scripts/sera_base_clutter.gd")
const Deck = preload("res://scripts/sera_base_deck_layout.gd")
const KEYS := [
    "NEXUS", "LABO", "SMELTER", "RECYCLER",
    "SCRAP_COLLECTOR", "STORAGE", "GENERATOR", "BUILD_TERMINAL",
]

class Capture:
    extends RefCounted
    var host := Node3D.new()
    var features: Array[String] = []
    func box(feature: String, at: Vector3, size: Vector3,
            tint: String = "armor", yaw: float = 0.0) -> void:
        features.append(feature)
    func rod(feature: String, a: Vector3, b: Vector3, diameter: float,
            tint: String = "trim") -> void:
        features.append(feature)
    func ring(feature: String, center: Vector3, radius: float, tint: String,
            axis: String = "y") -> void:
        features.append(feature)
    func crate(at: Vector3, size: Vector3, index: int = 0) -> void:
        features.append("CargoBody")

func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("SERA_BASE_COMPACT_PROP_VARIETY_FAIL: " + message)
    quit(1)
func _overlap(a: Rect2, b: Rect2) -> bool:
    return a.position.x < b.end.x and a.end.x > b.position.x and (
        a.position.y < b.end.y and a.end.y > b.position.y)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/base_exploration.tscn")
    if scene == null:
        _fail("base scene missing")
        return
    var hub: Node3D = scene.instantiate()
    root.add_child(hub)
    await process_frame
    var nexus: Node3D = hub.get_node_or_null("NEXUSBuilding") as Node3D
    var machines: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if nexus == null or machines == null:
        _fail("missing live facilities")
        return
    var specs: Array = machines.get_script().get_script_constant_map().get(
        "FACILITY_SPECS", [])
    var sites: Array[Dictionary] = Deck.facility_sites(nexus.position, specs)
    var panels: Array[Dictionary] = Deck.generate(42, 3.0, sites)
    var reserved: Dictionary = {}
    for panel in panels:
        if not str(panel["site"]).is_empty():
            reserved[str(panel["site"])] = panel
    if reserved.size() != 8:
        _fail("lost one-piece facility floor panels")
        return
    var all_kinds: Dictionary = {}
    var all_accents: Dictionary = {}
    var total: int = 0
    for key in KEYS:
        var data: Array[Dictionary] = Props.props_for(key)
        if data.size() != (11 if key in ["NEXUS", "LABO"] else 9):
            _fail(key + " should have three unique accent details")
            return
        var near_old: int = 0
        var details: int = 0
        var occupied: Array[Rect2] = []
        var old_positions: Array[Vector2] = []
        for item in data:
            if not bool(item.get("accent", false)):
                old_positions.append(item["at"])
        var site_origin := Vector2.ZERO
        for site in sites:
            if str(site["id"]) == key:
                site_origin = site["at"]
                break
        var slab_info: Dictionary = reserved[key]
        var slab: Rect2 = Rect2(
            (slab_info["center"] as Vector2) - site_origin -
            (slab_info["size"] as Vector2) * 0.5, slab_info["size"])
        var protected: Rect2 = (
            Rect2(Vector2(-3.38, -2.85), Vector2(6.76, 6.60))
            if key == "NEXUS" else
            Rect2(Vector2(-2.18, -1.98), Vector2(4.36, 4.98))
            if key == "LABO" else
            Rect2(Vector2(-1.37, -1.37), Vector2(2.74, 2.86)))
        for item in data:
            var kind: String = str(item["kind"])
            var at: Vector2 = item["at"]
            var size: Vector2 = Props.bounds_for(kind) * float(item["scale"])
            var rect := Rect2(at - size * 0.5, size)
            if not slab.grow(-0.15).encloses(rect):
                _fail("detail crossed facility's one-piece slab: " + key + "/" + kind)
                return
            if _overlap(rect, protected):
                _fail("detail blocks machinery/entrance: " + key + "/" + kind)
                return
            for other in occupied:
                if _overlap(rect, other):
                    _fail("two separate prop footprints overlap: " + key + "/" + kind)
                    return
            occupied.append(rect)
            all_kinds[kind] = true
            if bool(item.get("accent", false)):
                details += 1
                if all_accents.has(kind):
                    _fail("duplicate new shape: " + kind)
                    return
                all_accents[kind] = true
                for older in old_positions:
                    if at.distance_to(older) < 1.25:
                        near_old += 1
                        break
        if details != 3 or near_old < 2:
            _fail("new elements must stay in clusters rather than fill the clear path")
            return
        var capture := Capture.new()
        Props.decorate(capture, key)
        var recorded: Array = capture.host.get_meta("clutter_props", []) as Array
        if recorded.size() != data.size():
            _fail("decorated scene lacks three accent props at " + key)
            return
        for item in data:
            if not bool(item.get("accent", false)):
                continue
            var prefix: String = "Yard_" + str(item["kind"]) + "_"
            var feature_count: int = 0
            for feature in capture.features:
                if feature.begins_with(prefix):
                    feature_count += 1
            if feature_count < 3:
                _fail("new unique ornament did not emit actual 3D details: " + prefix)
                return
        var live_model: Node3D = (
            nexus.get_node_or_null("NexusArchitecture") as Node3D
            if key == "NEXUS" else
            machines.get_node_or_null(key + "/IndustrialModel") as Node3D)
        if live_model == null or (
                (live_model.get_meta("clutter_props", []) as Array).size() != data.size()):
            _fail("new geometry not attached to active facility model: " + key)
            return
        total += data.size()
    if total != 76 or all_accents.size() != 24 or all_kinds.size() < 63:
        _fail("BASE ornament breadth/quantity below target")
        return
    print("SERA_BASE_COMPACT_PROP_VARIETY_RUNTIME_PASS total=", total,
        " new_unique=", all_accents.size(), " all_shapes=", all_kinds.size())
    quit(0)
