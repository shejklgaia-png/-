extends SceneTree
## Real Godot validation of 2/3-tier placement, silhouettes and no new draw nodes.
const Props = preload("res://scripts/sera_base_clutter.gd")
const Deck = preload("res://scripts/sera_base_deck_layout.gd")
const KEYS := [
    "NEXUS", "LABO", "SMELTER", "RECYCLER",
    "SCRAP_COLLECTOR", "STORAGE", "GENERATOR", "BUILD_TERMINAL",
]

class RecordingBatch:
    extends RefCounted
    var host: Node3D
    var emitted: Array[Dictionary] = []
    func _init() -> void:
        host = Node3D.new()
    func box(feature: String, pos: Vector3, size: Vector3,
            tint: String = "armor", yaw: float = 0.0) -> void:
        emitted.append({"type": "box", "name": feature, "pos": pos, "size": size})
    func rod(feature: String, a: Vector3, b: Vector3, diameter: float,
            tint: String = "trim") -> void:
        emitted.append({"type": "rod", "name": feature, "pos": a, "size": Vector3.ONE})
    func ring(feature: String, pos: Vector3, radius: float,
            tint: String, axis: String = "y") -> void:
        emitted.append({"type": "ring", "name": feature, "pos": pos, "size": Vector3.ONE})
    func crate(pos: Vector3, size: Vector3, index: int = 0) -> void:
        emitted.append({"type": "crate", "name": "CargoBody", "pos": pos, "size": size})

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_BASE_PROP_STACKS_FAIL: " + why)
    quit(1)

func _overlap(a: Rect2, b: Rect2) -> bool:
    return a.position.x < b.end.x and a.end.x > b.position.x and (
        a.position.y < b.end.y and a.end.y > b.position.y)

func _run() -> void:
    var site_origin := Vector3(-9.53, 0, -14.55)
    var specs: Array = [
        {"id": "LABO", "at": Vector3(0, 0, -2.2), "size": Vector3(4.25, 4.1, 4.35)},
        {"id": "SMELTER", "at": Vector3(-10.19, 0, -4.55), "size": Vector3(2.4, 2.85, 2.4)},
        {"id": "RECYCLER", "at": Vector3(0.65, 0, -12.20), "size": Vector3(2.45, 2.55, 2.35)},
        {"id": "SCRAP_COLLECTOR", "at": Vector3(6.11, 0, 14.98), "size": Vector3(2.35, 2.55, 2.25)},
        {"id": "STORAGE", "at": Vector3(-2.94, 0, 5.54), "size": Vector3(2.45, 2.15, 2.30)},
        {"id": "GENERATOR", "at": Vector3(8.76, 0, -2.39), "size": Vector3(2.4, 3.10, 2.25)},
        {"id": "BUILD_TERMINAL", "at": Vector3(15.17, 0, 8.35), "size": Vector3(2.1, 2.55, 2.1)},
    ]
    var sites: Array[Dictionary] = Deck.facility_sites(site_origin, specs)
    var panels: Array[Dictionary] = Deck.generate(42, 3.0, sites)
    var reserved: Dictionary = {}
    for panel in panels:
        if not str(panel["site"]).is_empty():
            reserved[str(panel["site"])] = panel
    if reserved.size() != 8:
        _fail("not all site floor panels were reserved")
        return
    var triples: int = 0
    var doubles: int = 0
    var total: int = 0
    for key in KEYS:
        var authored: Array[Dictionary] = Props.props_for(key)
        var origin := Vector2.ZERO
        for site in sites:
            if site["id"] == key:
                origin = site["at"]
        var panel: Dictionary = reserved[key]
        var slab := Rect2((panel["center"] as Vector2) - origin -
            (panel["size"] as Vector2) * 0.5, panel["size"])
        var previous: Array[Rect2] = []
        var clear_zone: Rect2 = (
            Rect2(Vector2(-3.38, -2.85), Vector2(6.76, 6.60)) if key == "NEXUS" else
            Rect2(Vector2(-2.18, -1.98), Vector2(4.36, 4.98)) if key == "LABO" else
            Rect2(Vector2(-1.37, -1.37), Vector2(2.74, 2.86)))
        for item in authored:
            var kind: String = str(item["kind"])
            var at: Vector2 = item["at"]
            var factor: float = float(item["scale"])
            var stack_count: int = int(item.get("stack", 1))
            if stack_count < 1 or stack_count > 3:
                _fail("tier count out of range: " + kind)
                return
            if stack_count > 1 and Props.stack_pitch_for(kind) <= 0.0:
                _fail("unsafe non-stackable equipment: " + kind)
                return
            if stack_count == 2:
                doubles += 1
            elif stack_count == 3:
                triples += 1
            for layer in range(stack_count):
                var center: Vector2 = at + Props.layer_offset(layer) * factor
                var extent: Vector2 = Props.bounds_for(kind) * factor
                var rect := Rect2(center - extent * 0.5, extent)
                if not slab.grow(-0.15).encloses(rect):
                    _fail(key + " tier leaves its single dedicated floor panel: " + kind)
                    return
                if _overlap(rect, clear_zone):
                    _fail(key + " stacked tier blocks entrance or machinery: " + kind)
                    return
                for other in previous:
                    if _overlap(rect, other):
                        _fail(key + " stack intrudes into another prop cluster")
                        return
            previous.append(Rect2(at - Props.bounds_for(kind) * factor * 0.5,
                Props.bounds_for(kind) * factor))
        var capture := RecordingBatch.new()
        Props.decorate(capture, key)
        if (capture.host.get_meta("clutter_props", []) as Array).size() != authored.size():
            _fail("renderer did not attach authored stack metadata")
            return
        if capture.emitted.is_empty():
            _fail("nothing rendered for " + key)
            return
        if key == "STORAGE":
            var boxes: Array[Vector3] = []
            for part in capture.emitted:
                if part["type"] == "crate":
                    boxes.append(part["pos"])
            if boxes.size() != 3:
                _fail("warehouse cargo must contain precisely three real crate layers")
                return
            boxes.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
            var pitch: float = Props.stack_pitch_for("cargo_box")
            for layer in range(1, 3):
                if not is_equal_approx(boxes[layer].y - boxes[layer - 1].y, pitch):
                    _fail("crate stacks are not vertically separated in real geometry")
                    return
            var skids: int = 0
            for part in capture.emitted:
                if part["type"] == "box" and part["name"] == "Yard_cargo_box_skid":
                    skids += 1
            if skids != 1:
                _fail("upper crates must not have floating ground pallets")
                return
        total += authored.size()
    if doubles < 9 or triples < 4 or total < 48:
        _fail("base lacks enough two- and three-high cargo variation")
        return
    print("SERA_BASE_PROP_STACKS_RUNTIME_PASS groups=", total,
        " doubles=", doubles, " triples=", triples)
    quit(0)
