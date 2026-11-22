extends SceneTree
## STOMP range selects real front soles through 3.7m; hit volume x1.8
## follows source foot; rear 3.0m/x1.5 and v541 KICK remain unchanged.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_FRONT_STOMP_V542_FAIL " + message)
    quit(1)

func _run() -> void:
    if absf(ATTACKS.FRONT_STOMP_RANGE_METERS - 3.70) > 0.0001 or (
            absf(ATTACKS.STOMP_RANGE_METERS - 3.00) > 0.0001):
        _fail("front/rear activation distances changed")
        return
    for id in ATTACKS.LEG_IDS:
        var front: bool = id.begins_with("leg_f")
        var expected_range: float = 3.7 if front else 3.0
        for d in [1.0, 2.99, 3.01, 3.69, 3.71, 4.0]:
            var distance: float = float(d)
            var expected: bool = distance <= expected_range
            var allowed: bool = ATTACKS._leg_can_reach(
                "stomp", id, Vector3(0, 0, distance),
                Vector3.ZERO, 0.0)
            if allowed != expected:
                _fail("stomp reach " + str([id, distance, allowed,
                    expected]))
                return
        # Selection must be based on the real foot, not the boss root.
        var solo: Dictionary = {}
        solo[id] = Vector3(100.0, 0.0, 100.0)
        var close: Vector3 = Vector3(100.0, 0.0, 103.50)
        var chosen: String = str(ATTACKS.new().call(
            "_choose_kind", close, solo, 0.0))
        if chosen != ("stomp" if front else "sweep"):
            _fail("wrong front/rear technique at 3.5m " + str([id, chosen]))
            return
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    for id in ATTACKS.LEG_IDS:
        var raw: AABB = scene.call("_bittaran_attack_foot_bounds", id)
        var box: AABB = scene.call("_bittaran_stomp_follow_box", id)
        var scale: float = 1.8 if id.begins_with("leg_f") else 1.5
        if not raw.has_volume() or not box.has_volume():
            _fail("real mesh/trigger missing " + id)
            return
        if absf(box.size.x - raw.size.x * scale) > 0.005 or (
                absf(box.size.z - raw.size.z * scale) > 0.005):
            _fail("wrong foot-follow width " + id)
            return
        if box.get_center().distance_to(raw.get_center()) > 0.09:
            _fail("stomp collider moved off rendered toe " + id)
            return
        if box.size.y < raw.size.y - 0.001:
            _fail("stomp y-height contracted " + id)
            return
    print("GODOT_BITTARAN_FRONT_STOMP_V542_PASS front=3.7m/1.8x rear=3.0m/1.5x")
    quit(0)
