extends SceneTree
## v407 regression: the KICK mirror blend must not whip the foot
## over the top of the body.
##
## Device report (v406): "sometimes the kick rotates and comes
## down from overhead like a whip". Reproduced with leg_rl kicking
## at a player 5.0m away on the front-right diagonal (boss facing
## the player): the v400 mirror blend slerps the shoulder/knee
## local rotations between the delta-mapped and world-mirrored
## chains over the strike's first 0.30s, and for the rear legs
## those chains are near-opposite (the two folds' soles sit 4.2m
## apart), so the shortest-path slerp throws the foot over the
## top: during strike/hold the foot peaked 1.96m ABOVE the hip.
##
## v407 blends the two chains in FOOT space during the ramp (the
## IK solves the leg to the straight sole lerp with the blended
## knee as its pole), so the foot travels low and direct. The
## remaining peak (~1.11m) is the authored rear fold's own height
## at strike start, continuous with the windup.
##
## Asserts: during strike/hold, foot_y - hip_y <= 1.35.
## Verified: FAILS pre-fix (1.96), passes post-fix.
const DT: float = 1.0 / 60.0
const MAX_OVER_HIP: float = 1.35


func _fail(message: String) -> void:
    push_error("V407_BITTARAN_KICK_WHIP_FAIL: " + message)


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
    var legs: Array = ik.get("legs")
    var part_ids: Array = ik.get("LEG_PART_IDS")
    var li: int = part_ids.find("leg_rl")
    var upper: Node3D = legs[li]["upper"]
    var foot: Node3D = legs[li]["foot"]
    boss.global_position = Vector3.ZERO
    var a: float = deg_to_rad(45.0)
    player.global_position = Vector3(
        sin(a) * 5.0, 0.0, -cos(a) * 5.0)
    boss.rotation.y = atan2(player.global_position.x,
        player.global_position.z)
    for i in range(45):
        battle.set("player_hp", 9999.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
    if not bool(brain.call(
            "force_start_with_stance", "leg_rl", "kick")):
        _fail("leg_rl kick did not start")
        quit(1)
        return
    var started: bool = false
    var saw_hold: bool = false
    var max_over: float = -99.0
    var ticks: int = 0
    while ticks < 60 * 10:
        ticks += 1
        battle.set("player_hp", 9999.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            if started:
                break
            continue
        started = true
        var phase: String = str(frame.get("phase", ""))
        if phase == "hold":
            saw_hold = true
        if phase == "strike" or phase == "hold":
            max_over = maxf(max_over, foot.global_position.y
                - upper.global_position.y)
    if not saw_hold:
        _fail("leg_rl kick never reached hold")
        quit(1)
        return
    if max_over > MAX_OVER_HIP:
        _fail("strike/hold foot peaked " + str(max_over)
            + "m above the hip (whip; v406 defect: 1.96)")
        quit(1)
        return
    print("GODOT_V407_BITTARAN_KICK_WHIP_PASS")
    quit(0)


func _initialize() -> void:
    call_deferred("_run")
