extends SceneTree
## Independent headless checks: base spawn, proximity, bounds and NEXUS routing.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_BASE_EXPLORATION_RUNTIME_FAIL: " + why)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/base_exploration.tscn")
    if packed == null:
        _fail("base scene missing")
        return
    var base: Node3D = packed.instantiate()
    root.add_child(base)
    await process_frame
    var actor: Node3D = base.get("player") as Node3D
    var cam: Camera3D = base.get("cam") as Camera3D
    if actor == null or cam == null or not cam.current:
        _fail("player or overview camera missing")
        return
    if base.get_node_or_null("CRATE") == null:
        _fail("maintenance partner absent")
        return
    var names: Dictionary = {}
    for station in base.get("STATIONS"):
        names[station["focus"]] = true
        var marker: Vector2 = station["at"]
        actor.position = Vector3(marker.x, 0.08, marker.y)
        var near: Dictionary = base.call("_nearest_station")
        if near.is_empty() or str(near["focus"]) != str(station["focus"]):
            _fail("station proximity mismatch: " + str(station["focus"]))
            return
    if names.size() != 5:
        _fail("not all five NEXUS actions reachable")
        return
    actor.position = Vector3(0.0, 0.08, 8.0)
    if not (base.call("_nearest_station") as Dictionary).is_empty():
        _fail("interact allowed outside stations")
        return
    base.call("_move_player", Vector2(1.0, 1.0), 50.0)
    if actor.position.x > 6.0 or actor.position.z > 10.0:
        _fail("base boundary escaped")
        return
    if actor.position.y != 0.08:
        _fail("player changed height during planar movement")
        return
    print("SERA_BASE_EXPLORATION_RUNTIME_PASS")
    quit(0)
