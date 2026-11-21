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
    var counts: Dictionary = {}
    var container_groups: int = 0
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
        for item_index in range(authored.size()):
            var item: Dictionary = authored[item_index]
            var kind: String = str(item["kind"])
            var at: Vector2 = item["at"]
            var factor: float = float(item["scale"])
            var stack_count: int = int(item.get("stack", 1))
            if stack_count < 1 or stack_count > 4:
                _fail("stack count out of range: " + kind)
                return
            if not Props.is_stack_container(kind) and stack_count > 3:
                _fail("non-container has unsafe four-tier stack: " + kind)
                return
            if stack_count > 1 and Props.stack_pitch_for(kind) <= 0.0:
                _fail("unsafe non-stackable equipment: " + kind)
                return
            if stack_count > 1:
                counts[stack_count] = true
            if Props.is_stack_container(kind):
                container_groups += 1
                var plan: Array[Dictionary] = Props.container_plan_for(
                    key, kind, item_index)
                if plan.size() != stack_count:
                    _fail("authored container count mismatches its actual geometry")
                    return
                for tier in plan:
                    var offset: Vector2 = tier["at"]
                    var box_size: Vector3 = tier["size"]
                    var center: Vector2 = at + offset * factor
                    var extent := Vector2(box_size.x, box_size.z) * factor
                    var rect := Rect2(center - extent * 0.5, extent)
                    if not slab.grow(-0.15).encloses(rect):
                        _fail(key + " stack leaves dedicated floor slab: " + kind)
                        return
                    if _overlap(rect, clear_zone):
                        _fail(key + " stack blocks entrance or machinery: " + kind)
                        return
                    for other in previous:
                        if _overlap(rect, other):
                            _fail(key + " stack overlaps another prop cluster")
                            return
            else:
                for layer in range(stack_count):
                    var center: Vector2 = at + Props.layer_offset(layer) * factor
                    var extent: Vector2 = Props.bounds_for(kind) * factor
                    var rect := Rect2(center - extent * 0.5, extent)
                    if not slab.grow(-0.15).encloses(rect):
                        _fail(key + " prop tier leaves site panel: " + kind)
                        return
                    if _overlap(rect, clear_zone):
                        _fail(key + " tier blocks entrance: " + kind)
                        return
                    for other in previous:
                        if _overlap(rect, other):
                            _fail(key + " tier overlaps another prop cluster")
                            return
            previous.append(Rect2(at - Props.bounds_for(kind) * factor * 0.5,
                Props.bounds_for(kind) * factor))
        var capture := RecordingBatch.new()
        Props.decorate(capture, key)
        if (capture.host.get_meta("clutter_props", []) as Array).size() != authored.size():
            _fail("renderer did not attach randomized stack metadata")
            return
        if capture.emitted.is_empty():
            _fail("nothing rendered for " + key)
            return
        if key == "STORAGE":
            var boxes: Array[Vector3] = []
            for part in capture.emitted:
                if part["type"] == "crate":
                    boxes.append(part["pos"])
            var cargo_index: int = -1
            for i in range(authored.size()):
                if str(authored[i]["kind"]) == "cargo_box":
                    cargo_index = i
                    break
            if cargo_index < 0:
                _fail("warehouse cargo absent")
                return
            var source: Dictionary = authored[cargo_index]
            var cargo_plan: Array[Dictionary] = Props.container_plan_for(
                "STORAGE", "cargo_box", cargo_index)
            if boxes.size() != cargo_plan.size():
                _fail("number of rendered cargo crates differs from seeded count")
                return
            var at: Vector2 = source["at"]
            var scale: float = float(source["scale"])
            for i in range(cargo_plan.size()):
                var part: Dictionary = cargo_plan[i]
                var offset: Vector2 = part["at"]
                var size: Vector3 = part["size"]
                var expected := Vector3(at.x + offset.x * scale,
                    -0.03 + float(part["bottom"]) * scale + size.y * scale * 0.5,
                    at.y + offset.y * scale)
                if boxes[i].distance_to(expected) > 0.0001:
                    _fail("cargo mesh does not match the actual randomized plan")
                    return
            var skids: int = 0
            for part in capture.emitted:
                if part["type"] == "box" and part["name"] == "Yard_cargo_box_skid":
                    skids += 1
            if skids != 1:
                _fail("warehouse cargo must have exactly one floor skid")
                return
        total += authored.size()
    if container_groups < 7 or not counts.has(2) or not counts.has(3) or (
            not counts.has(4)) or total != 52:
        _fail("stack counts did not vary across the eight sites")
        return
    print("SERA_BASE_PROP_STACKS_RUNTIME_PASS groups=", total,
        " container_groups=", container_groups, " stack_counts=", counts)
    quit(0)
