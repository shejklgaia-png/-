extends SceneTree
## v488: headless validation of both separate modes and the 3D NEXUS tap target.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_BASE_HUB_RUNTIME_FAIL: " + why)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/base_exploration.tscn")
    if packed == null:
        _fail("overworld scene missing")
        return
    var hub: Node3D = packed.instantiate()
    root.add_child(hub)
    await process_frame
    var sera: Node3D = hub.get("player") as Node3D
    var cam: Camera3D = hub.get("cam") as Camera3D
    var crate: Node3D = hub.get_node_or_null("CRATE") as Node3D
    var building: Node3D = hub.get_node_or_null("NEXUSBuilding") as Node3D
    if sera == null or cam == null or crate == null or building == null or not cam.current:
        _fail("overworld actor, roaming CRATE, building, or camera missing")
        return
    var spot: Vector2 = cam.unproject_position(building.global_position + Vector3(0, 2.5, 0))
    if not bool(hub.call("_nexus_hit", spot)):
        _fail("tap on projected NEXUS building not recognized")
        return
    if bool(hub.call("_nexus_hit", Vector2(-1000, -1000))):
        _fail("tap outside building incorrectly recognized")
        return
    var start: Vector3 = crate.position
    hub.call("_update_crate", 6.0)
    if crate.position.distance_to(start) < 0.2:
        _fail("CRATE is still stationary")
        return
    if absf(crate.position.y - 0.06) > 0.00001:
        _fail("CRATE left its planar travel height")
        return
    sera.position = Vector3(0, 0.08, 8)
    hub.call("_move_player", Vector2(1, 1), 50.0)
    if sera.position.x > 6.0 or sera.position.z > 10.0:
        _fail("overworld SERA escaped floor bounds")
        return
    if absf(sera.position.y - 0.08) > 0.00001:
        _fail("SERA left planar travel height")
        return
    print("SERA_BASE_HUB_RUNTIME_PASS")
    quit(0)
