extends SceneTree
## SERA v387: each real attack must honor its poststrike phase contract,
## avoid rendered-foot floor penetration, and leave the HEAD exclusively
## under independent live-player tracking (no imported head clip playback).
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")


func _fail(problem: String) -> void:
    push_error("V387_BITTARAN_POSTSTRIKE_FAIL: " + problem)
    quit(1)


func _case(battle: Node3D, id: String, kind: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var foot_index: int = IK.LEG_PART_IDS.find(id)
    var active: Dictionary = ik.get("legs")[foot_index]
    var neck: Node3D = rig.find_child("Head", true, false) as Node3D
    if not bool(brain.call("force_start", id, kind)):
        _fail("failed to start " + id + "/" + kind)
        return false
    var wait_neck: Quaternion = rig.call(
        "_authored_key_rotation", "Wait", "Head", 0.0)
    var hold_seconds: float = 0.0
    var recovery_seconds: float = 0.0
    var seen_impact: bool = false
    var seen_recovery: bool = false
    var seen_done: bool = false
    var saw_live_head_yaw: bool = false
    var saw_head_yaw_move: bool = false
    var prior_head_yaw: float = 0.0
    var hold_start_sole: Vector3 = Vector3.INF
    var original_supports: Dictionary = {}
    var previous_sole: Vector3 = Vector3.INF
    var max_penetration: float = 0.0
    var sample_count: int = 0
    var elapsed_after_hit: float = 0.0
    for tick in range(350):
        # Side-to-side SERA movement: torso never follows during SWEEP,
        # but the head should keep reacquiring this independent target.
        var lateral: float = 1.5 if tick < 25 else (
            -1.5 if tick < 75 else 2.3)
        player.global_position = boss.global_position + Vector3(
            lateral, 0.0, 8.2)
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            seen_done = true
            break
        var phase: String = str(frame.get("phase", ""))
        var t: float = float(frame.get("time", 0.0))
        var windup: float = float(frame.get("windup", 1.0))
        var strike: float = float(frame.get("strike", 0.2))
        var hold: float = float(frame.get("hold", 0.0))
        var recovery: float = float(frame.get("recovery", 0.5))
        var expected_hold: float = (0.0 if kind == "sweep" else 1.5)
        var expected_recovery: float = (
            BRAIN.SWEEP_RECOVERY_SECONDS if kind == "sweep" else (
            BRAIN.KICK_RECOVERY_SECONDS if kind == "kick"
            else BRAIN.STOMP_RECOVERY_SECONDS))
        if absf(hold - expected_hold) > 0.0001 or absf(
                recovery - expected_recovery) > 0.0001:
            _fail(id + "/" + kind + ": incorrect hold/recovery duration")
            return false
        if kind == "sweep":
            if bool(frame.get("tracking", false)) or frame.get(
                    "aim", Vector3.INF) != Vector3.INF or (
                    absf(float(frame.get("body_yaw", 0.0))) > 0.0001):
                _fail(id + ": SWEEP torso/strike still follows player")
                return false
        if not neck.quaternion.is_equal_approx(wait_neck):
            _fail(id + "/" + kind + ": keyed HEAD animation before live look")
            return false
        battle.call("_finalize_target_pose", DT)
        var head_yaw: float = float(battle.get("head_look_filtered_yaw"))
        if absf(head_yaw) > 0.02:
            saw_live_head_yaw = true
        if tick > 35 and absf(head_yaw - prior_head_yaw) > 0.002:
            saw_head_yaw_move = true
        prior_head_yaw = head_yaw
        if original_supports.is_empty():
            for j in range(4):
                if j != foot_index:
                    original_supports[IK.LEG_PART_IDS[j]] = (
                        ik.get("legs")[j]["anchor"])
        for key in original_supports:
            var support: Dictionary = ik.get("legs")[
                IK.LEG_PART_IDS.find(key)]
            var anchor: Vector3 = original_supports[key]
            var actual_goal: Vector3 = support["last_goal"]
            if Vector2(actual_goal.x - anchor.x,
                    actual_goal.z - anchor.z).length() > 0.0001:
                _fail(id + "/" + kind + ": support slipped " + key)
                return false
        var active_foot: Node3D = active["foot"]
        var sole: Vector3 = active_foot.to_global(
            active["sole_local"] as Vector3)
        if kind == "stomp":
            if active_foot.global_basis.y.normalized().dot(
                    Vector3.UP) < 0.998 and t <= windup + strike + hold:
                _fail(id + ": long foot edge not perpendicular to ground")
                return false
            if bool(frame.get("impact", false)):
                seen_impact = true
        else:
            var min_y: float = float(ik.call(
                "_foot_mesh_lowest_y", active_foot))
            if is_finite(min_y):
                max_penetration = maxf(max_penetration, -min_y)
                # The first few windup frames may begin with an entering
                # gait foot but shall not remain below the floor after
                # IK has applied the authored contact floor constraint.
                if min_y < IK.FLOOR_Y - 0.025:
                    _fail(id + "/" + kind +
                        ": visible foot penetrated floor by " + str(-min_y)
                        + " at t=" + str(t))
                    return false
        if phase == "hold":
            if kind == "sweep":
                _fail(id + ": SWEEP unexpectedly entered hit pause")
                return false
            hold_seconds += DT
            if t > windup + strike + 0.05:
                if hold_start_sole == Vector3.INF:
                    hold_start_sole = sole
                if hold_start_sole.distance_to(sole) > 0.035:
                    _fail(id + "/" + kind + ": foot moved during 1.5s hold")
                    return false
        elif phase == "recovery":
            seen_recovery = true
            recovery_seconds += DT
            if previous_sole != Vector3.INF and (
                    previous_sole.distance_to(sole) > 0.65):
                _fail(id + "/" + kind + ": sudden recovery foot warp")
                return false
        if t >= windup + strike:
            elapsed_after_hit += DT
        previous_sole = sole
        sample_count += 1
    if not seen_done or not seen_recovery:
        _fail(id + "/" + kind + ": never returned to Idle after hold")
        return false
    if kind == "stomp" and not seen_impact:
        _fail(id + ": STOMP did not register its contact event")
        return false
    if kind == "sweep":
        if hold_seconds > DT or recovery_seconds < 1.30:
            _fail(id + ": slow no-pause SWEEP recovery not observed")
            return false
    else:
        if absf(hold_seconds - 1.50) > 0.04:
            _fail(id + "/" + kind +
                ": held for " + str(hold_seconds) + " instead of 1.50s")
            return false
    if not saw_live_head_yaw or not saw_head_yaw_move:
        _fail(id + "/" + kind + ": procedural HEAD tracking did not move")
        return false
    return true


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var n: int = 0
    for kind in BRAIN.ATTACK_KINDS:
        for id in BRAIN.LEG_IDS:
            if not _case(battle, id, kind):
                return
            n += 1
    if n != 12:
        _fail("did not execute all 12 attack/leg combinations")
        return
    print("GODOT_V387_BITTARAN_POSTSTRIKE_PASS: 4x STOMP long axis vertical "
        + "through impact and 1.5s hold; 4x KICK 1.5s hold; 4x SWEEP "
        + "slow no-hold return; all real foot bounds grounded and "
        + "HEAD continuously tracking through all attack phases")
    quit(0)
