extends SceneTree
## v420: Regression for the five original attack-pose defects.
## 60Hz real-scene checks: neutral windup knee continuity, mirrored
## KICK ground crawl, no repeated axial shin drift, no toe penetration,
## and reliable return to neutral after all four quadrants.
const DT: float = 1.0 / 60.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const KINDS: Array[String] = ["kick", "sweep"]
const REPEATS: int = 3
const MAX_WINDUP_KNEE_STEP: float = 0.075
const MAX_KICK_CRAWL_HEIGHT: float = 0.20
const MIN_KICK_CRAWL_FRACTION: float = 0.80
const MAX_SHIN_AXIS_ERROR_DEG: float = 0.35
const MIN_MESH_Y: float = -0.025


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V420_ATTACK_REBUILD_FAIL: " + why)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    if brain == null or ik == null or rig == null or boss == null             or player == null:
        _fail("missing runtime scene")
        return
    var largest_knee_step: float = 0.0
    var largest_axis_error: float = 0.0
    var largest_toe_gap: float = 0.0
    var total: int = 0
    for id in IDS:
        for kind in KINDS:
            for rep in range(REPEATS):
                battle.call("_reset_target_after_respawn")
                battle.set("target_move_enabled", true)
                battle.set("player_hp", 9999.0)
                var side: float = -1.0 if id.ends_with("l") else 1.0
                var forward: float = (
                    6.0 if id.begins_with("leg_r") else -6.0)
                player.global_position = boss.global_position                     + Vector3(side * (2.2 + float(rep) * 0.4),
                        0.0, forward)
                if not bool(brain.call(
                        "force_start_with_stance", id, kind)):
                    _fail(id + "/" + kind + " start failed")
                    return
                var leg: Dictionary = ik.get("legs")[
                    ik.LEG_PART_IDS.find(id)]
                var upper: Node3D = leg["upper"]
                var knee: Node3D = leg["lower"]
                var foot: Node3D = leg["foot"]
                var previous_knee: Vector3 = Vector3.INF
                var floor_checks: int = 0
                var crawl_checks: int = 0
                var began: bool = false
                var done: bool = false
                for tick in range(650):
                    battle.set("player_hp", 9999.0)
                    battle.call("_advance_target_motion", DT)
                    battle.call("_finalize_target_pose", DT)
                    var frame: Dictionary = battle.get(
                        "bittaran_attack_frame")
                    if frame.is_empty():
                        if began and not bool(brain.call("is_active")):
                            done = true
                            break
                        continue
                    var phase: String = str(frame.get("phase", ""))
                    if phase == "stance":
                        continue
                    began = true
                    if phase == "windup":
                        if previous_knee != Vector3.INF:
                            largest_knee_step = maxf(
                                largest_knee_step, knee.global_position
                                .distance_to(previous_knee))
                        previous_knee = knee.global_position
                    else:
                        previous_knee = Vector3.INF
                    if phase != "strike" and phase != "hold":
                        continue
                    var toe_low: float = float(ik.call(
                        "_foot_mesh_lowest_y", foot))
                    if toe_low < MIN_MESH_Y:
                        _fail(id + "/" + kind + " toe penetrated: "
                            + str(toe_low))
                        return
                    var source_t: float = float(
                        frame.get("authored_time", 0.0))
                    if kind == "kick" and source_t >= 0.35                             and source_t <= 0.60 and phase == "strike":
                        floor_checks += 1
                        if toe_low <= MAX_KICK_CRAWL_HEIGHT:
                            crawl_checks += 1
                        largest_toe_gap = maxf(largest_toe_gap,
                            toe_low)
                    if kind == "kick" and id.begins_with("leg_r")                             and source_t >= 0.32 and source_t <= 0.62:
                        var source: Dictionary = leg.get(
                            "rear_kick_axis_source", {})
                        if source.is_empty():
                            _fail(id + " lost authored shin-axis basis")
                            return
                        var to_ankle: Vector3 = (
                            foot.global_position - knee.global_position)
                        var transport: Quaternion = Quaternion(
                            source["lower_axis"] as Vector3,
                            to_ankle.normalized())
                        var expected: Quaternion = (
                            transport * (
                                source["lower_rotation"] as Quaternion)
                            ).normalized()
                        var err: float = rad_to_deg(
                            expected.angle_to(knee.global_basis
                                .get_rotation_quaternion()))
                        largest_axis_error = maxf(largest_axis_error,
                            err)
                if not done:
                    _fail(id + "/" + kind + " timeline not complete")
                    return
                if kind == "kick" and (
                        floor_checks < 7 or (
                        float(crawl_checks) / float(
                        maxi(1, floor_checks))) <
                        MIN_KICK_CRAWL_FRACTION):
                    _fail(id + "/kick failed grounded crawl: "
                        + str(crawl_checks) + "/" + str(floor_checks))
                    return
                total += 1
    print("V420_ATTACK_REBUILD_DIAG: cases=" + str(total)
        + " knee_step=" + str(largest_knee_step)
        + " axis_error_deg=" + str(largest_axis_error)
        + " max_kick_mesh_y=" + str(largest_toe_gap))
    if largest_knee_step > MAX_WINDUP_KNEE_STEP:
        _fail("anticipation knee snapped " + str(largest_knee_step))
        return
    if largest_axis_error > MAX_SHIN_AXIS_ERROR_DEG:
        _fail("rear shin axial roll drift "
            + str(largest_axis_error))
        return
    if total != 24:
        _fail("not all mirrored attack cases checked")
        return
    print("GODOT_V420_ATTACK_REBUILD_PASS")
    quit(0)
