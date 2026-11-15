extends SceneTree
## v406: a close-range KICK must shorten geometrically, not by
## blending the pose toward Wait. The v404 slerp rotated the
## extended leg down through the floor (authored leg-mesh lowest
## -2.4m at reach factor 0.5), and the IK's whole-limb floor lift
## then hoisted the attacking hip by that amount for the whole
## strike/hold (device report: hip 2.66 -> 4.35m, the leg dangling
## from above, foot sailing at head height). The IK now pulls the
## foot back along the hip->foot ray and solves the knee in the
## authored bend plane. This check pins the observable contract at
## the reported geometry (player 4.6m in front): during HOLD the
## floor lift stays near zero, the attacking hip stays at/below
## its rest height (the authored crouch), and the foot holds low
## near the player. A full-reach case guards against
## over-shortening.
const DT: float = 1.0 / 60.0
const MAX_HOLD_LIFT: float = 0.30
const MAX_HOLD_HIP_RISE: float = 0.35
const MAX_HOLD_FOOT_Y: float = 1.30


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V406_BITTARAN_KICK_REACH_SOLVE_FAIL: " + message)
    quit(1)


func _tick(battle: Node) -> void:
    battle.set("player_hp", 9999.0)
    battle.call("_advance_target_motion", DT)
    battle.call("_finalize_target_pose", DT)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    await process_frame
    await process_frame
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if brain == null or ik == null or boss == null or player == null:
        _fail("missing live boss / IK / director")
        return
    var legs: Array = ik.get("legs")
    var part_ids: Array = ik.get("LEG_PART_IDS")
    boss.global_position = Vector3.ZERO
    for leg_id in ["leg_fr", "leg_fl"]:
        var li: int = part_ids.find(leg_id)
        var leg: Dictionary = legs[li]
        var upper: Node3D = leg["upper"]
        var foot: Node3D = leg["foot"]
        player.global_position = Vector3(0.0, 0.0, -4.6)
        boss.rotation.y = atan2(0.0, -4.6)
        for frame in range(45):
            _tick(battle)
        var rest_hip_y: float = upper.global_position.y
        if not bool(brain.call(
                "force_start_with_stance", leg_id, "kick")):
            _fail("unable to start kick " + leg_id)
            return
        var started: bool = false
        var saw_hold: bool = false
        var ticks: int = 0
        while ticks < 60 * 8:
            ticks += 1
            _tick(battle)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                if started:
                    break
                continue
            started = true
            if str(frame.get("phase", "")) != "hold":
                continue
            saw_hold = true
            var lift: float = float(leg.get(
                "attack_exit_lift_world", 0.0))
            if lift > MAX_HOLD_LIFT:
                _fail(leg_id + " hold floor lift=" + str(lift)
                    + " (v404 defect: 2.49)")
                return
            var hip_y: float = upper.global_position.y
            if hip_y > rest_hip_y + MAX_HOLD_HIP_RISE:
                _fail(leg_id + " hold hip_y=" + str(hip_y)
                    + " vs rest " + str(rest_hip_y)
                    + " (v404 defect: +1.69)")
                return
            # The foot-height symptom was measured on leg_fr (the
            # reported leg): its authored crouch makes the fixed
            # hold low, while leg_fl's authored pose legitimately
            # holds higher (the boss rises on that side by design),
            # so this assertion is fr-only. Lift and hip rise above
            # discriminate on both legs (fl defect: lift 1.95,
            # hip +2.1).
            if leg_id == "leg_fr":
                var foot_y: float = foot.global_position.y
                if foot_y > MAX_HOLD_FOOT_Y:
                    _fail(leg_id + " hold foot_y=" + str(foot_y)
                        + " (v404 defect: 1.84, head height)")
                    return
        if not saw_hold:
            _fail(leg_id + " kick never reached hold")
            return
    # Full-reach guard: the constraint must not eat a long kick.
    var li_fr: int = part_ids.find("leg_fr")
    var foot_fr: Node3D = legs[li_fr]["foot"]
    var hip_fr: Vector3 = (legs[li_fr]["upper"] as Node3D
        ).global_position
    var outward: Vector3 = (hip_fr - boss.global_position)
    outward.y = 0.0
    outward = outward.normalized()
    player.global_position = boss.global_position + outward * 7.2
    var to_p: Vector3 = player.global_position - boss.global_position
    boss.rotation.y = atan2(to_p.x, to_p.z)
    for frame in range(45):
        _tick(battle)
    if not bool(brain.call(
            "force_start_with_stance", "leg_fr", "kick")):
        _fail("unable to start full-reach kick")
        return
    var started2: bool = false
    var min_dist: float = 999.0
    var ticks2: int = 0
    while ticks2 < 60 * 8:
        ticks2 += 1
        _tick(battle)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            if started2:
                break
            continue
        started2 = true
        min_dist = minf(min_dist, foot_fr.global_position.distance_to(
            player.global_position))
    # Measured 1.61 on BOTH the v404 and v406 builds at this
    # geometry (the foot passes the locked aim at height); the
    # guard only needs to catch a real over-shortening, which
    # would leave the foot metres away.
    if min_dist > 2.0:
        _fail("full-reach kick no longer arrives: min foot-player "
            + str(min_dist))
        return
    print("GODOT_V406_BITTARAN_KICK_REACH_SOLVE_PASS")
    quit(0)
