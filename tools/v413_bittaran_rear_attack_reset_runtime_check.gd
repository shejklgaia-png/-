extends SceneTree
## v413: every rear attack raises the tail, never the front; no
## attack-only height, twist, fitted sole, pole or pose state may leak
## into the following attack (including forced mid-attack restarts).
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const KINDS: Array[String] = ["kick", "stomp", "sweep"]


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V413_BITTARAN_REAR_ATTACK_RESET_FAIL: " + reason)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    var battle: Node = scene.instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if not _check_rear_posture(rig, ik):
        return
    if not _check_lifecycle(rig, ik):
        return
    print("GODOT_V413_BITTARAN_REAR_ATTACK_RESET_PASS")
    quit()


func _check_rear_posture(rig: Node3D, ik: RefCounted) -> bool:
    var chassis: Node3D = ik.get("chassis_bone")
    var actor: Node3D = ik.get("actor")
    var rear_angle: float = deg_to_rad(
        IK.REAR_ATTACK_BODY_LIFT_DEGREES)
    if absf(rear_angle - deg_to_rad(8.0)) > 0.00001:
        _fail("existing rear sweep 8-degree lift changed")
        return false
    for kind in KINDS:
        var windup: float = 1.25 if kind == "stomp" else 0.70
        var strike: float = 0.25 if kind == "stomp" else (
            1.0 if kind == "kick" else 2.06)
        var recovery: float = 0.55 if kind == "stomp" else (
            0.60 if kind == "kick" else 1.40)
        for id in LEGS:
            rig.call("apply_pose", "Wait", 0.0)
            actor.position.y = float(ik.get("rest_actor_local_y"))
            var before: Quaternion = chassis.quaternion
            # Avoid impact-height solver: this is the actual windup.
            var t: float = windup * 0.65
            ik.set("attack_pose", {
                "kind": kind, "id": id, "time": t,
                "windup": windup, "strike": strike,
                "hold": 0.0, "recovery": recovery,
                "body_yaw": 0.0, "stomp_aim": Vector3.INF
            })
            ik.call("_apply_attack_chassis_pose")
            var expected: Quaternion = before
            if id.begins_with("leg_r"):
                var rise: float = smoothstep(0.0, 1.0, t / windup)
                expected = (before * Quaternion(Vector3.RIGHT,
                    -rear_angle * rise)).normalized()
            var error: float = chassis.quaternion.angle_to(expected)
            if error > 0.0005:
                _fail(kind + " " + id + " rear-high posture mismatch: "
                    + str(rad_to_deg(error)) + " degrees")
                return false
    ik.call("clear_attack_pose")
    return true


func _check_lifecycle(rig: Node3D, ik: RefCounted) -> bool:
    var legs: Array = ik.get("legs")
    if legs.size() != 4:
        _fail("foot IK has no four-leg state")
        return false
    var first: Dictionary = legs[0]
    var saved_sole: Vector3 = first["sole_local"]
    var a: Dictionary = {
        "kind": "kick", "id": "leg_fl", "time": 0.42,
        "windup": 0.70, "strike": 1.0, "hold": 1.5,
        "recovery": 0.60
    }
    var b: Dictionary = a.duplicate()
    b["id"] = "leg_rr"
    b["time"] = 0.02
    ik.call("clear_attack_pose")
    ik.call("set_attack_pose", a)
    _inject_stale_state(ik, first, saved_sole)
    # An interrupted attack that directly restarts another leg.
    ik.call("set_attack_pose", b)
    if not _assert_clean(ik, first, saved_sole, false):
        return false
    _inject_stale_state(ik, first, saved_sole)
    # Natural completion takes precisely the same cleanup path.
    ik.call("set_attack_pose", {})
    if not _assert_clean(ik, first, saved_sole, true):
        return false
    rig.call("start_authored_attack", "kick", "leg_rl")
    rig.set("kick_mirror_weight", 0.9)
    rig.set("kick_reach_factor", 0.22)
    rig.call("end_authored_attack")
    if not str(rig.get("active_authored_attack")).is_empty() or (
            absf(float(rig.get("kick_mirror_weight"))) > 0.00001) or (
            absf(float(rig.get("kick_reach_factor")) - 1.0) > 0.00001):
        _fail("rig attack blending state survived end_authored_attack")
        return false
    return true


func _inject_stale_state(ik: RefCounted, leg: Dictionary,
        orig: Vector3) -> void:
    ik.set("initial_attack_contact_height_world", 0.75)
    ik.set("gait_sway_pitch", 0.16)
    leg["sole_local_saved"] = orig
    leg["sole_local"] = orig + Vector3.UP * 0.25
    leg["sole_local_traj"] = orig
    leg["attack_exit_lift_world"] = 0.51
    leg["plant_goal"] = Vector3(1, 2, 3)
    leg["authored_pole_active"] = true
    leg["spiral_twist"] = 0.8


func _assert_clean(ik: RefCounted, leg: Dictionary,
        saved: Vector3, expect_empty: bool) -> bool:
    var pose: Dictionary = ik.get("attack_pose")
    if (pose.is_empty() != expect_empty) or (
            absf(float(ik.get("initial_attack_contact_height_world")))
            > 0.00001):
        _fail("attack pose or contact height remained from previous attack")
        return false
    if (leg["sole_local"] as Vector3).distance_to(saved) > 0.00001:
        _fail("fitted sole was not restored")
        return false
    for key in ["sole_local_saved", "sole_local_traj",
            "attack_exit_lift_world", "plant_goal", "authored_pole_active"]:
        if leg.has(key):
            _fail("stale " + key + " survived attack cleanup")
            return false
    if absf(float(leg.get("spiral_twist", 0.0))) > 0.00001 or (
            absf(float(ik.get("gait_sway_pitch"))) > 0.00001):
        _fail("attack twist or sway survived cleanup")
        return false
    return true
