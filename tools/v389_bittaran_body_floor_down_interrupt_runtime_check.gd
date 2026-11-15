extends SceneTree
## SERA v389: BODY (not HEAD/limbs) may never dip below actual
## world floor across authored attack crouches AND physical down.
## v394: an active attack interruption preserves its displayed pose,
## then blends the striker and BODY into authored STOMP windup for 0.60s,
## before restoring the neutral down pose. HEAD stays controller-owned.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0
const EPS: float = 0.006

func _initialize() -> void:
    call_deferred("_run")


func _fail(problem: String) -> void:
    push_error("V389_BODY_FLOOR_DOWN_INTERRUPT_FAIL: " + problem)
    quit(1)


func _body_clear(ik: RefCounted, label: String) -> bool:
    var bottom: float = float(ik.call("chassis_mesh_lowest_world_y"))
    if not is_finite(bottom) or bottom < IK.FLOOR_Y + (
            IK.BODY_MESH_FLOOR_CLEARANCE_METERS) - EPS:
        _fail(label + ": actual BODY plate went through floor "
            + str(bottom))
        return false
    return true


func _run_case(battle: Node3D, id: String, kind: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var head: Node3D = rig.find_child("Head", true, false) as Node3D
    player.global_position = boss.global_position + Vector3(3.0, 0, 7.5)
    if not bool(brain.call("force_start", id, kind)):
        _fail("cannot force " + id + "/" + kind)
        return false
    var active_frames: int = 0
    for tick in range(220):
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            break
        battle.call("_finalize_target_pose", DT)
        if not _body_clear(ik, id + "/" + kind + " tick " + str(tick)):
            return false
        active_frames += 1
    if active_frames < 120:
        _fail(id + "/" + kind + " did not play real strike and recovery")
        return false

    # Restart the same attack and interrupt it while its authored
    # left-front animation is visibly active (even on mirrored legs).
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    player.global_position = boss.global_position + Vector3(3.0, 0, 7.5)
    if not bool(brain.call("force_start", id, kind)):
        _fail(id + "/" + kind + " failed to restart")
        return false
    for tick in range(52):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if not _body_clear(ik, id + "/" + kind
                + " pre-break tick " + str(tick)):
            return false
    if str(rig.get("active_authored_attack")) != kind:
        _fail(id + "/" + kind + " attack was not playing at break")
        return false
    var head_before: Quaternion = head.quaternion
    # Break the actual attacking shin; a valid down reaction must
    # supersede that animation even on the impact/windup boundary.
    battle.set("locked_target_part_id", id)
    var result: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(result.get("broken", false)):
        _fail(id + "/" + kind + " failed to enter physical down")
        return false
    if not str(rig.get("active_authored_attack")).is_empty() or not (
            battle.get("bittaran_attack_frame") as Dictionary).is_empty():
        _fail(id + "/" + kind + " authored attack remained active on down")
        return false
    if not (ik.get("attack_pose") as Dictionary).is_empty() or absf(
            float(ik.get("initial_attack_contact_height_world"))) > 0.000001:
        _fail(id + "/" + kind + " attack pose/height leaked into down")
        return false
    if not head.quaternion.is_equal_approx(head_before):
        _fail(id + "/" + kind + " attack cancel rewrote independent HEAD")
        return false
    # An active attack is NOT snapped to Wait on the damaging frame.
    # It must retain a source snapshot and perform the dedicated
    # 0.60-second transition instead of discarding its authored motion.
    if str(rig.get("down_stomp_leg_id")) != id or not bool(
            ik.call("attack_down_windup_active")):
        _fail(id + "/" + kind + " no STOMP preparation after interrupt")
        return false
    var before_body: Quaternion = (
        rig.find_child("Body", true, false) as Node3D).quaternion
    var names: Array[String] = [
        "Body", "FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L",
        "FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R",
        "RearLeg_L", "RearLowerLeg_L", "RearFoot_L",
        "RearLeg_R", "RearLowerLeg_R", "RearFoot_R"]
    if before_body.angle_to(
            rig.find_child("Body", true, false).quaternion) > 0.001:
        _fail("BODY snapped when attack was interrupted")
        return false
    # Simulate real fall, down and early recovery while checking the
    # entire BODY mesh, not just the root pivot or the head height.
    var went_down: bool = false
    var saw_chassis_clamp: bool = false
    var prepared: bool = false
    for tick in range(130):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if bool(ik.call("attack_down_windup_active")) and float(
                ik.get("windup_elapsed")) > 0.52:
            var body: Node3D = rig.find_child("Body", true, false)
            var raised: Quaternion = rig.call(
                "_authored_key_rotation", "踏みつけ", "Body", 1.25)
            if body.quaternion.angle_to(raised) > 0.16:
                _fail(id + "/" + kind
                    + ": did not reach STOMP raised BODY prepose")
                return false
            prepared = true
        if bool(ik.call("down_pose_active")):
            went_down = true
        if not _body_clear(ik, id + "/" + kind + " down tick " + str(tick)):
            return false
        if (battle.get("bittaran_attack_frame") as Dictionary).is_empty() == false:
            _fail(id + "/" + kind + " resumed strike while down")
            return false
    if not went_down or not prepared:
        _fail(id + "/" + kind
            + " did not complete STOMP windup before physical down")
        return false
    return true


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var count: int = 0
    for kind in BRAIN.ATTACK_KINDS:
        for id in BRAIN.LEG_IDS:
            if not _run_case(battle, id, kind):
                return
            count += 1
    if count != 12:
        _fail("did not verify all 12 attack/limb combinations")
        return
    print("GODOT_V389_BODY_FLOOR_DOWN_INTERRUPT_PASS: all 12 real "
        + "STOMP/KICK/SWEEP variants keep authored BODY mesh above "
        + "floor during strike/recovery and after interrupt, blend "
        + "BODY/active arm to STOMP prep before DOWN, keep independent "
        + "HEAD tracking and prevent strike restart")
    quit(0)
