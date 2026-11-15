extends SceneTree
## SERA v388: SWEEP returns from authored t=0.50 with 0.60x
## sampling for 0.70 real seconds, then plays at 1.0x. Independently
## controlled HEAD must never be overwritten by ANY motion update.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")


func _fail(problem: String) -> void:
    push_error("V388_HEAD_SWEEP_TEMPO_FAIL: " + problem)
    quit(1)


func _expect_close(value: float, expected: float, label: String) -> bool:
    if absf(value - expected) > 0.0001:
        _fail(label + ": " + str(value) + " != " + str(expected))
        return false
    return true


func _check_sweep_timeline(battle: Node3D) -> bool:
    var brain: RefCounted = battle.get("bittaran_attacks")
    var rig: Node3D = battle.get("bittaran_rig")
    if not _expect_close(BRAIN.SWEEP_SOURCE_STRIKE_SECONDS, 1.50,
            "authored duration preserved"):
        return false
    if not _expect_close(BRAIN.SWEEP_STRIKE_SECONDS, 1.78,
            "time added by slowdown"):
        return false
    if not bool(brain.call("force_start", "leg_fl", "sweep")):
        _fail("unable to begin authored sweep")
        return false
    var times: Array = [0.20, 0.499, 0.50, 0.85, 1.199,
        1.20, 1.30, 1.78]
    var authored: Array = [0.20, 0.499, 0.50, 0.71, 0.9194,
        0.92, 1.02, 1.50]
    for i in range(times.size()):
        brain.set("elapsed", BRAIN.SWEEP_WINDUP_SECONDS + float(times[i]))
        var frame: Dictionary = brain.call("advance", 0.0,
            Vector3.ZERO, {}, true)
        if frame.is_empty():
            _fail("sweep stopped before its authored t=1.50")
            return false
        if not _expect_close(float(frame.get("authored_time", -1.0)),
                float(authored[i]), "time warp sample " + str(times[i])):
            return false
        var expected_rate: float = (0.60 if float(times[i]) >= 0.50 and
            float(times[i]) < 1.20 else 1.0)
        if not _expect_close(float(frame.get(
                "authored_playback_speed", -1.0)), expected_rate,
                "speed interval " + str(times[i])):
            return false
        if float(times[i]) > 0.499 and float(times[i]) < 1.78:
            # Verify real rig sampling, not only timeline math. The
            # source's front-left rotational keys do not use linear time
            # after t=0.50 because of the outbound/return slowdown.
            rig.call("apply_authored_attack_pose", frame)
            var upper: Node3D = rig.find_child(
                "FrontLeg_L", true, false) as Node3D
            var expected: Quaternion = rig.call(
                "_authored_rotation_for_leg", "sweep", "leg_fl", 0,
                float(authored[i]))
            if upper.quaternion.angle_to(expected) > 0.0003:
                _fail("rig ignored slowed authored clip time at " +
                    str(times[i]))
                return false
    # Original 1.50 authored seconds are played in 1.78 REAL seconds.
    # 0.70 of those real seconds are at exactly 60% speed.
    return true


func _check_head_ownership(battle: Node3D) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var rig: Node3D = battle.get("bittaran_rig")
    var player: CharacterBody3D = battle.get("player")
    var boss: Node3D = battle.get("target")
    var head: Node3D = rig.find_child("Head", true, false) as Node3D
    var initial: Quaternion = head.quaternion
    var saw_target_turn: bool = false
    # Let live tracked yaw establish a non-neutral pose.
    for tick in range(60):
        player.global_position = boss.global_position + Vector3(
            7.0 if tick < 25 else -7.0, 0.0, 10.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if head.quaternion.angle_to(initial) > 0.10:
            saw_target_turn = true
    if not saw_target_turn:
        _fail("live head yaw did not track moving SERA")
        return false
    # The HEAD must survive every regular clip and its incoming blend
    # with exactly its prior tracked orientation, even before _finalize.
    for name in ["Idle", "Turn", "Approach"]:
        var before: Quaternion = head.quaternion
        rig.call("set_motion", name, 0.07)
        if head.quaternion.angle_to(before) > 0.00003:
            _fail(name + " clip rewrote the tracked head pose")
            return false
        rig.call("apply_pose", name, 0.42)
        if head.quaternion.angle_to(before) > 0.00003:
            _fail(name + " keyframe overwrote procedural head rotation")
            return false
    for kind in BRAIN.ATTACK_KINDS:
        rig.call("end_authored_attack")
        var before: Quaternion = head.quaternion
        rig.call("start_authored_attack", kind, "leg_fl")
        rig.call("apply_authored_attack_pose", {
            "kind": kind,
            "id": "leg_fl",
            "time": 0.75,
            "windup": 0.70,
            "strike": 1.5,
            "hold": 0.0,
            "recovery": 0.5
        })
        if head.quaternion.angle_to(before) > 0.00003:
            _fail(kind + " animation wrote HEAD during playback")
            return false
    rig.call("end_authored_attack")
    # No head tracking while genuinely physically down. A part-break
    # pre-down windup is NOT down and must keep tracking.
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    ik.set("break_elapsed", 0.30)
    ik.set("windup_elapsed", -1.0)
    var last_yaw: float = float(battle.get("boss_head_yaw"))
    # A previously tracked neck must NOT snap to neutral as it falls.
    # Re-centering is rate-limited by the same 140deg/s look budget.
    for frame in range(30):
        battle.call("_aim_bittaran_head", DT)
        var current_yaw: float = float(battle.get("boss_head_yaw"))
        if absf(current_yaw - last_yaw) > (
                deg_to_rad(140.0) * DT + 0.0001):
            _fail("head snapped to neutral on first down frame")
            return false
        last_yaw = current_yaw
    var rest: Quaternion = battle.get("boss_head_default_rotation")
    if head.quaternion.angle_to(rest) > 0.00001:
        _fail("head failed to settle to neutral while lying down")
        return false
    ik.set("break_elapsed", -1.0)
    return true


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _check_sweep_timeline(battle):
        return
    if not _check_head_ownership(battle):
        return
    print("GODOT_V388_HEAD_SWEEP_TEMPO_PASS: authored sweep t=0.5 "
        + "turnaround, 0.6x for 0.7 real seconds, speed 1.0 afterward, "
        + "full source t=1.5 in 1.78 real seconds, rig actual source "
        + "joint playback, HEAD live continuity across 3 gait and 3 "
        + "attack clips, and neutral head only while physically down")
    quit(0)
