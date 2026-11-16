extends SceneTree
## v417 real-scene axial-roll contract: rear KICK IK must preserve the
## Blockbench thigh/shin orientations around each bone's LONG axis.
## Unlike v415/416 toe tests, this compares the actual shoulder and
## shin WORLD bases against minimal-swing transports of THIS FRAME'S
## authored source bases, after repeated IK floor/reach solves.
const DT: float = 1.0 / 60.0
const LEGS: Array[String] = ["leg_rl", "leg_rr"]
const REPEATS: int = 4
const MAX_ROLL_DIFF_DEGREES: float = 0.35
const MAX_CRAWL_HEIGHT: float = 0.20


func _initialize() -> void:
    call_deferred("_run")


func _fail(msg: String) -> void:
    push_error("V417_REAR_KICK_AXIAL_ROLL_FAIL: " + msg)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    if brain == null or ik == null or boss == null or player == null:
        _fail("missing real battle / IK")
        return
    var checks: int = 0
    var worst: float = 0.0
    for id in LEGS:
        for target_case in range(2):
            battle.call("_reset_target_after_respawn")
            battle.set("target_move_enabled", true)
            var fixed_root: Transform3D = boss.global_transform
            var side: float = -1.0 if id.ends_with("l") else 1.0
            var target_pos: Vector3 = (
                boss.global_position + Vector3(
                    side * (1.5 if target_case == 0 else 2.6),
                    0.0, 6.0 if target_case == 0 else 6.8))
            var leg: Dictionary = ik.get("legs")[
                ik.LEG_PART_IDS.find(id)]
            var upper: Node3D = leg["upper"]
            var lower: Node3D = leg["lower"]
            var foot: Node3D = leg["foot"]
            for rep in range(REPEATS):
                boss.global_transform = fixed_root
                player.global_position = target_pos
                if not bool(brain.call(
                        "force_start_with_stance", id, "kick")):
                    _fail(id + " could not start repeat " + str(rep))
                    return
                var started: bool = false
                var ended: bool = false
                var frames: int = 0
                var crawl: int = 0
                for tick in range(520):
                    battle.set("player_hp", 9999.0)
                    battle.call("_advance_target_motion", DT)
                    battle.call("_finalize_target_pose", DT)
                    var frame: Dictionary = battle.get(
                        "bittaran_attack_frame")
                    if frame.is_empty():
                        if started and not bool(
                                brain.call("is_active")):
                            ended = true
                            break
                        continue
                    if str(frame.get("phase", "")) == "stance":
                        continue
                    started = true
                    if str(frame.get("phase", "")) != "strike":
                        continue
                    var clip_t: float = float(frame.get(
                        "authored_time", -100.0))
                    if clip_t < 0.32 or clip_t > 0.62:
                        continue
                    if not bool(leg.get(
                            "rear_kick_axis_solved", false)):
                        _fail(id + " missing source-based solve at "
                            + str(clip_t))
                        return
                    var source: Dictionary = leg.get(
                        "rear_kick_axis_source", {})
                    if source.is_empty():
                        _fail(id + " missing source axes")
                        return
                    var current_upper_axis: Vector3 = (
                        lower.global_position - upper.global_position)
                    var current_lower_axis: Vector3 = (
                        foot.global_position - lower.global_position)
                    if current_upper_axis.length() < 0.01 or (
                            current_lower_axis.length() < 0.01):
                        _fail(id + " collapsed physical limb")
                        return
                    var upper_expected: Quaternion = (
                        Quaternion(source["upper_axis"] as Vector3,
                            current_upper_axis.normalized())
                        * (source["upper_rotation"] as Quaternion)
                        ).normalized()
                    var lower_expected: Quaternion = (
                        Quaternion(source["lower_axis"] as Vector3,
                            current_lower_axis.normalized())
                        * (source["lower_rotation"] as Quaternion)
                        ).normalized()
                    var actual_upper: Quaternion = (
                        upper.global_basis.get_rotation_quaternion())
                    var actual_lower: Quaternion = (
                        lower.global_basis.get_rotation_quaternion())
                    var upper_error: float = rad_to_deg(
                        upper_expected.angle_to(actual_upper))
                    var lower_error: float = rad_to_deg(
                        lower_expected.angle_to(actual_lower))
                    worst = maxf(worst, maxf(
                        upper_error, lower_error))
                    if upper_error > MAX_ROLL_DIFF_DEGREES or (
                            lower_error > MAX_ROLL_DIFF_DEGREES):
                        _fail(id + " target-case=" + str(target_case)
                            + " repeat=" + str(rep)
                            + " source clip=" + str(clip_t)
                            + " upper/shin rotation deviated "
                            + str(upper_error) + " / "
                            + str(lower_error) + " degrees")
                        return
                    var gap: float = float(ik.call(
                        "_foot_mesh_lowest_y", foot))
                    if gap <= MAX_CRAWL_HEIGHT and gap >= -0.025:
                        crawl += 1
                    frames += 1
                    checks += 1
                if not ended:
                    _fail(id + " repeat did not finish")
                    return
                if frames < 10 or float(crawl) / float(
                        maxi(frames, 1)) < 0.80:
                    _fail(id + " rep=" + str(rep)
                        + " lost grounded crawl: "
                        + str(crawl) + "/" + str(frames))
                    return
    if checks < 150:
        _fail("insufficient live source frame checks "
            + str(checks))
        return
    print("GODOT_V417_REAR_KICK_AXIAL_ROLL_PASS: "
        + str(checks) + " actual IK frames, 2 rear legs x "
        + "2 target bearings x 4 repeats; max relative bone-"
        + "axis twist " + str(worst) + " degrees")
    quit(0)
