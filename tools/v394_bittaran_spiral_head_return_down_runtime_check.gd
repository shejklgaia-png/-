extends SceneTree
## v394: winding spiral knees when BODY out-turns planted feet;
## HEAD constrained by RETURNING arm envelope even without intersection;
## attack interruption blends only BODY/striking limb into original STOMP
## prepose for precisely 0.60s, without overwriting the live HEAD look.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V394_SPIRAL_RETURN_DOWN_FAIL: " + why)
    quit(1)

func _check_spiral(battle: Node3D) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", false)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var legs: Array = ik.get("legs")
    var anchors: Array[Vector3] = []
    var lengths: Array[Vector2] = []
    for leg in legs:
        anchors.append(leg["anchor"])
        lengths.append(Vector2(
            (leg["upper"] as Node3D).global_position.distance_to(
                (leg["lower"] as Node3D).global_position),
            (leg["lower"] as Node3D).global_position.distance_to(
                (leg["foot"] as Node3D).global_position)))
    var seen_twist: float = 0.0
    for tick in range(62):
        # Intentionally turn torso while gait is PAUSED. This isolates
        # the exact failure mode of feet that lag behind the turning BODY.
        boss.rotation.y += 0.013
        rig.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
        for i in range(legs.size()):
            var leg: Dictionary = legs[i]
            seen_twist = maxf(seen_twist,
                absf(float(leg.get("spiral_twist", 0.0))))
            var foot: Node3D = leg["foot"]
            var actual: Vector3 = foot.to_global(
                leg["sole_local"] as Vector3)
            var xz: Vector2 = Vector2(
                actual.x - anchors[i].x, actual.z - anchors[i].z)
            if xz.length() > 0.015:
                _fail("twisted leg moved its planted sole " + str([i, xz]))
                return false
            var current: Vector2 = Vector2(
                (leg["upper"] as Node3D).global_position.distance_to(
                    (leg["lower"] as Node3D).global_position),
                (leg["lower"] as Node3D).global_position.distance_to(
                    foot.global_position))
            if current.distance_to(lengths[i]) > 0.02:
                _fail("spiral stretched a bone " + str([i, current, lengths[i]]))
                return false
    if seen_twist < deg_to_rad(10.0):
        _fail("lagging legs never formed a helical knee bend")
        return false
    # Bring chassis back to the previous planted reference; the helix
    # must naturally unwind, not leave a permanently rotated knee.
    for tick in range(90):
        boss.rotation.y = move_toward(boss.rotation.y, 0.0, 0.02)
        rig.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
    for leg in legs:
        if absf(float(leg.get("spiral_twist", 0.0))) > 0.025:
            _fail("spiral did not unwind when the body caught up")
            return false
    return true

func _check_head_arm_return(battle: Node3D) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", false)
    var limit: float = float(battle.get(
        "head_arm_return_yaw_limit_degrees"))
    if absf(limit - 30.0) > 0.05:
        _fail("head yaw must be mechanically limited to 30deg: " + str(limit))
        return false
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    for side in [-1.0, 1.0]:
        player.global_position = boss.global_position + Vector3(
            14.0 * side, 0.0, -5.0)
        for tick in range(100):
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
        var yaw: float = rad_to_deg(absf(float(
            battle.get("boss_head_yaw"))))
        var filtered: float = rad_to_deg(absf(float(
            battle.get("head_look_filtered_yaw"))))
        if yaw > 30.1 or filtered > 30.1:
            _fail("HEAD exceeded arm return envelope "
                + str([side, yaw, filtered, limit]))
            return false
    return true

func _check_interrupt(battle: Node3D, kind: String, id: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var head: Node3D = battle.get("bittaran_head")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    player.global_position = boss.global_position + Vector3(3.0, 0, 7.0)
    if not bool(brain.call("force_start", id, kind)):
        _fail(id + "/" + kind + " could not start")
        return false
    for frame in range(28):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
    var head_before: Quaternion = head.quaternion
    var body: Node3D = rig.find_child("Body", true, false)
    var body_before: Quaternion = body.quaternion
    battle.set("locked_target_part_id", id)
    var hit: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(hit.get("broken", false)):
        _fail(id + "/" + kind + " failed to break the shin")
        return false
    if not head.quaternion.is_equal_approx(head_before):
        _fail("HEAD snapped on attack interruption "
            + str([head_before, head.quaternion]))
        return false
    if not body.quaternion.is_equal_approx(body_before):
        _fail("BODY snapped before its 0.60s blend began")
        return false
    if str(rig.get("down_stomp_leg_id")) != id or not (
            ik.call("attack_down_windup_active")):
        _fail("interrupted attack did not enter STOMP anticipation")
        return false
    var samples: int = 0
    var saw_broken_down: bool = false
    var former: float = -1.0
    for tick in range(45):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if bool(ik.call("windup_active")):
            samples += 1
            var fraction: float = float(ik.call("windup_progress"))
            if fraction > 0.30 and fraction < 0.90:
                var origin: Quaternion = (
                    rig.get("down_stomp_entry_rotations") as Dictionary)[
                    rig.get("bone_uuid_by_name")["Body"]]
                var goal: Quaternion = rig.call(
                    "_authored_key_rotation", "踏みつけ", "Body", 1.25)
                var estimate: Quaternion = origin.slerp(
                    goal, smoothstep(0.0, 1.0,
                        clampf(fraction, 0.0, 1.0)))
                if body.quaternion.angle_to(estimate) > 0.17:
                    _fail("transition BODY not interpolating STOMP keys")
                    return false
            if former >= 0.0 and fraction < former:
                _fail("windup progress regressed")
                return false
            former = fraction
        if bool(ik.call("down_pose_active")):
            saw_broken_down = true
            if tick < 34:
                _fail("physical DOWN began before 0.60s preparation")
                return false
            break
    if not saw_broken_down or samples < 32:
        _fail(id + "/" + kind + " did not finish 0.60s STOMP transition")
        return false
    if not (battle.get("bittaran_attack_frame") as Dictionary).is_empty():
        _fail("interrupted swing resumed during down")
        return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _check_spiral(battle):
        return
    if not _check_head_arm_return(battle):
        return
    for kind in BRAIN.ATTACK_KINDS:
        if not _check_interrupt(battle, kind, "leg_fl"):
            return
    print("GODOT_V394_SPIRAL_RETURN_DOWN_PASS: planted spiral bends "
        + "preserve bone lengths, head never crosses returned arms, "
        + "three interrupted attacks blend 0.60s into authored "
        + "STOMP windup with unaffected HEAD look")
    quit(0)
