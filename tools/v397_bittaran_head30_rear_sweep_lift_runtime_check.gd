extends SceneTree
## v397: the final HEAD pose never tracks beyond +/-30deg in any
## gameplay phase. Both rear SWEEP attacks lift the BODY's back during
## their authored swing, then lower it again without changing any
## source animation or touching the front attacking poses.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0
const HEAD_CAP: float = PI / 6.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V397_BITTARAN_HEAD_REAR_FAIL: " + why)
    quit(1)


func _check_head(battle: Node3D, context: String) -> bool:
    var yaw: float = float(battle.get("boss_head_yaw"))
    var desired: float = float(battle.get("head_look_filtered_yaw"))
    if not is_finite(yaw) or not is_finite(desired) or (
            absf(yaw) > HEAD_CAP + 0.0005) or (
            absf(desired) > HEAD_CAP + 0.0005):
        _fail(context + ": HEAD exceeded 30deg " +
            str([rad_to_deg(yaw), rad_to_deg(desired)]))
        return false
    return true


func _check_head_pose_hard_cap(battle: Node3D) -> bool:
    var constants: Dictionary = (
        battle.get_script() as GDScript).get_script_constant_map()
    if absf(float(constants["HEAD_TRACK_MAX_YAW_DEGREES"]) - 30.0) > 0.001:
        _fail("HEAD max yaw setting is not exactly 30deg")
        return false
    var forward: Quaternion = battle.call(
        "_head_oriented_local_pose", Quaternion.IDENTITY,
        deg_to_rad(85.0), 0.0)
    var expected := Quaternion(Vector3.UP, HEAD_CAP)
    if forward.angle_to(expected) > 0.0003:
        _fail("final HEAD quaternion ignored +30deg hard cap")
        return false
    var backward: Quaternion = battle.call(
        "_head_oriented_local_pose", Quaternion.IDENTITY,
        deg_to_rad(-85.0), 0.0)
    if backward.angle_to(Quaternion(Vector3.UP, -HEAD_CAP)) > 0.0003:
        _fail("final HEAD quaternion ignored -30deg hard cap")
        return false
    return true


func _rear_rise(battle: Node3D, id: String, t: float) -> float:
    battle.call("_reset_target_after_respawn")
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    rig.call("apply_pose", "Wait", 0.0)
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    var side: String = "R" if id.ends_with("r") else "L"
    var front: Node3D = rig.find_child(
        "FrontLeg_" + side, true, false) as Node3D
    var rear: Node3D = rig.find_child(
        "RearLeg_" + side, true, false) as Node3D
    if body == null or front == null or rear == null:
        _fail("missing BODY/front/rear shoulder geometry")
        return NAN
    body.quaternion = rig.call(
        "_authored_body_rotation_for_attack", "sweep", id, 0.5)
    var before: float = rear.global_position.y - front.global_position.y
    ik.set("attack_pose", {
        "kind": "sweep", "id": id, "time": t, "windup": 0.70,
        "strike": 2.06, "hold": 0.0, "recovery": 1.40,
        "body_yaw": 0.0, "authored": true
    })
    ik.set("initial_attack_contact_height_world", 0.0)
    ik.call("_apply_attack_chassis_pose")
    var lifted: float = (rear.global_position.y -
        front.global_position.y) - before
    ik.set("attack_pose", {})
    return lifted


func _check_rear_geometry(battle: Node3D) -> bool:
    if absf(IK.REAR_SWEEP_BODY_LIFT_DEGREES - 8.0) > 0.00001:
        _fail("unexpected rear torso lift angle")
        return false
    for id in IDS:
        var start: float = _rear_rise(battle, id, 0.0)
        var striking: float = _rear_rise(battle, id, 1.20)
        var recovered: float = _rear_rise(battle, id, 4.16)
        if not is_finite(start) or not is_finite(striking) or (
                not is_finite(recovered)):
            _fail(id + ": non-finite BODY motion")
            return false
        if absf(start) > 0.002 or absf(recovered) > 0.002:
            _fail(id + ": BODY rear lift snapped at start/recovery: " +
                str([start, recovered]))
            return false
        if id.begins_with("leg_r"):
            if striking < 0.18:
                _fail(id + ": rear torso was not raised enough: " +
                    str(striking))
                return false
        elif absf(striking) > 0.002:
            _fail(id + ": front SWEEP incorrectly lifted BODY rear " +
                str(striking))
            return false
    return true


func _check_live_states(battle: Node3D) -> bool:
    var player: CharacterBody3D = battle.get("player")
    var boss: Node3D = battle.get("target")
    var brain: RefCounted = battle.get("bittaran_attacks")
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", false)
    for side in [-1.0, 1.0]:
        player.global_position = boss.global_position + (
            boss.global_basis.x * 16.0 * side) + (
            boss.global_basis.z * 8.0)
        for tick in range(95):
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
            if not _check_head(battle, "Idle " + str(side) +
                    "/" + str(tick)):
                return false
    for id in IDS:
        battle.call("_reset_target_after_respawn")
        battle.set("target_move_enabled", true)
        var lateral: float = -1.0 if id.ends_with("r") else 1.0
        player.global_position = boss.global_position + Vector3(
            lateral * 15.0, 0.0, 12.0)
        if not bool(brain.call("force_start", id, "sweep")):
            _fail(id + ": cannot start live SWEEP")
            return false
        var saw_strike: bool = false
        for tick in range(175):
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
            if not _check_head(battle, id + " SWEEP " + str(tick)):
                return false
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if str(frame.get("phase", "")) == "strike":
                saw_strike = true
        if not saw_strike:
            _fail(id + ": SWEEP strike was never exercised")
            return false
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    battle.set("locked_target_part_id", "leg_fl")
    var broken: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(broken.get("broken", false)):
        _fail("cannot start physical down recovery")
        return false
    player.global_position = boss.global_position + Vector3(
        14.0, 0.0, -6.0)
    var saw_down: bool = false
    for tick in range(460):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if not _check_head(battle, "down/rise " + str(tick)):
            return false
        var ik: RefCounted = battle.get("bittaran_foot_ik")
        if bool(ik.call("down_pose_active")):
            saw_down = true
    if not saw_down:
        _fail("physical down was not exercised")
        return false
    return true


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _check_head_pose_hard_cap(battle):
        return
    if not _check_rear_geometry(battle):
        return
    if not _check_live_states(battle):
        return
    print("GODOT_V397_BITTARAN_HEAD_REAR_PASS: +/-30deg HEAD at "
        + "final pose in idle/4 attacks/down/standup, only rear "
        + "SWEEP raises chassis back smoothly by 8deg then releases")
    quit(0)
