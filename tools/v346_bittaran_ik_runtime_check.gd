extends SceneTree
## v346: an instantiated battle must preserve planted soles while Bittaran
## translates/turns, swap diagonal support and swing feet above the floor.
const BATTLE = preload("res://scenes/bittaran_battle.tscn")
const DELTA: float = 1.0 / 60.0
const MAX_ERROR_METERS: float = 0.12

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V346_BITTARAN_IK_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var boss: Node3D = BATTLE.instantiate()
    root.add_child(boss)
    var ik: RefCounted = boss.get("bittaran_foot_ik")
    var model: Node3D = boss.get("bittaran_rig")
    var target: Node3D = boss.get("target")
    if ik == null or model == null or target == null or not bool(ik.get("ready")):
        _fail("scene IK setup failed")
        return
    var legs: Array = ik.get("legs")
    if legs.size() != 4:
        _fail("required four IK limbs not loaded")
        return
    for leg in legs:
        var sole: Vector3 = (leg["foot"] as Node3D).to_global(leg["sole_local"])
        if absf(sole.y) > 0.12:
            _fail("initial pose sole is not grounded: " + str(sole))
            return
    # Move the *real* boss root and yaw as the AI does; every planted foot
    # must maintain its world-space anchor rather than follow the torso.
    var had_swing: bool = false
    var minimum_support: int = 4
    var maximum_ground_error: float = 0.0
    var swing_height: float = 0.0
    for frame in range(220):
        if frame < 145:
            target.position.z += 0.72 * DELTA
            model.call("set_motion", "Approach", DELTA)
            ik.call("advance_ik", DELTA, "Approach")
        else:
            target.rotation.y += deg_to_rad(34.0) * DELTA
            model.call("set_motion", "Turn", DELTA)
            ik.call("advance_ik", DELTA, "Turn")
        var planted: int = int(ik.call("planted_foot_count"))
        minimum_support = mini(minimum_support, planted)
        if planted < 4:
            had_swing = true
        maximum_ground_error = maxf(maximum_ground_error,
            float(ik.call("maximum_ground_error")))
        for leg in legs:
            if bool(leg["stepping"]):
                swing_height = maxf(swing_height, 
                    (leg["foot"] as Node3D).to_global(leg["sole_local"]).y)
            else:
                var foot_pos: Vector3 = (leg["foot"] as Node3D).to_global(
                    leg["sole_local"])
                var anchor: Vector3 = leg["anchor"]
                if foot_pos.distance_to(anchor) > MAX_ERROR_METERS:
                    _fail("planted foot slid " + str(foot_pos.distance_to(anchor))
                        + " during frame " + str(frame))
                    return
    if not had_swing or minimum_support < 2:
        _fail("diagonal leg alternation/support not activated")
        return
    if swing_height <= 0.05:
        _fail("swinging foot did not lift")
        return
    if maximum_ground_error > MAX_ERROR_METERS:
        _fail("standing sole error too large: " + str(maximum_ground_error))
        return
    # A new encounter must re-anchor instead of pulling old contact points.
    target.position = Vector3(0.0, 1.53, -8.0)
    target.rotation.y = 0.0
    model.call("apply_pose", "Wait", 0.0)
    ik.call("advance_ik", DELTA, "Idle")
    if float(ik.call("maximum_ground_error")) > MAX_ERROR_METERS:
        _fail("scene reset left IK anchored at previous location")
        return
    print("GODOT_V346_BITTARAN_IK_PASS: 4 legs, diagonal stance, foot locks, swing lift, reset, max_err="
        + str(maximum_ground_error) + " swing_y=" + str(swing_height))
    quit(0)
