extends SceneTree
## Rebuilt attack pipeline, live 60 Hz scene check.
## All four quadrants and repeated attacks must use a single mirrored
## source pose, preserve rotation, start grounded and never accumulate
## extra BODY pitch or shin axial roll.
const DT: float = 1.0 / 60.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const KINDS: Array[String] = ["kick", "sweep"]
const MAX_TOE_ANGLE_ERROR_DEGREES: float = 0.15
const MAX_REAR_AXIS_ERROR_DEGREES: float = 0.35
const MAX_KNEE_WINDUP_STEP_METERS: float = 0.075
const MAX_FLOOR_ERROR_METERS: float = 0.12


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V420_REBUILT_ATTACK_FAIL: " + why)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var rig: Node3D = battle.get("bittaran_rig")
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    if ik == null or brain == null or rig == null or boss == null             or player == null:
        _fail("missing real battle nodes")
        return
    var checked: int = 0
    var toe_error: float = 0.0
    var axis_error: float = 0.0
    var knee_step: float = 0.0
    var floor_error: float = 0.0
    var geometric_failure: float = 0.0
    for id in IDS:
        for kind in KINDS:
            for rep in range(3):
                battle.call("_reset_target_after_respawn")
                battle.set("target_move_enabled", true)
                battle.set("player_hp", 9999.0)
                var side: float = -1.0 if id.ends_with("l") else 1.0
                var z: float = 6.0 if id.begins_with("leg_r") else -6.0
                player.global_position = boss.global_position + (
                    Vector3(side * (2.4 if rep == 0 else 3.6),
                        0.0, z))
                if not bool(brain.call("force_start_with_stance",
                        id, kind)):
                    _fail("cannot begin " + id + "/" + kind)
                    return
                var leg: Dictionary = ik.get("legs")[
                    ik.LEG_PART_IDS.find(id)]
                var foot: Node3D = leg["foot"]
                var knee: Node3D = leg["lower"]
                var upper: Node3D = leg["upper"]
                var previous_knee: Vector3 = Vector3.INF
                var started: bool = false
                var ended: bool = false
                var samples: int = 0
                for tick in range(700):
                    battle.set("player_hp", 9999.0)
                    battle.call("_advance_target_motion", DT)
                    battle.call("_finalize_target_pose", DT)
                    var frame: Dictionary = battle.get(
                        "bittaran_attack_frame")
                    if frame.is_empty():
                        if started and not bool(brain.call("is_active")):
                            ended = true
                            break
                        continue
                    if str(frame.get("phase", "")) == "stance":
                        continue
                    started = true
                    var phase: String = str(frame.get("phase", ""))
                    var t: float = float(frame.get("time", 0.0))
                    var windup: float = float(frame.get("windup", 0.7))
                    if phase == "windup":
                        if previous_knee != Vector3.INF:
                            knee_step = maxf(knee_step,
                                previous_knee.distance_to(
                                    knee.global_position))
                        previous_knee = knee.global_position
                        continue
                    previous_knee = Vector3.INF
                    if phase != "strike" and phase != "hold":
                        continue
                    if not bool(leg.get("unified_strike", false)):
                        _fail("missing rebuilt source IK on " + id)
                        return
                    var clip_t: float = float(
                        frame.get("authored_time", 0.0))
                    var sample_func: String = (
                        "sample_authored_kick_source" if kind == "kick"
                        else "sample_authored_sweep_source")
                    var source_sole: Vector3 = ik.get("legs")[0][
                        "source_sole_local"]
                    var source: Dictionary = rig.call(
                        sample_func, id, clip_t, source_sole)
                    if source.is_empty():
                        _fail("missing authored source " + id)
                        return
                    var aim: Quaternion = Quaternion(Vector3.UP,
                        float(rig.get("attack_leg_aim_yaw")))
                    var expected: Quaternion = (
                        aim * (source["rotation"] as Quaternion)
                        ).normalized()
                    var actual: Quaternion = foot.global_basis                         .get_rotation_quaternion()
                    var degrees: float = rad_to_deg(
                        expected.angle_to(actual))
                    var entry_window: float = (
                        0.25 if kind == "kick" else 0.36)
                    # During the entry crossfade the foot is
                    # intentionally rotated from the planted Wait
                    # orientation into the mirrored source.
                    if clip_t >= entry_window + 0.02:
                        toe_error = maxf(toe_error, degrees)
                    if kind == "kick" and clip_t > 0.32                             and clip_t < 0.62:
                        var bottom: float = float(
                            ik.call("_foot_mesh_lowest_y", foot))
                        floor_error = maxf(floor_error,
                            maxf(bottom - 0.012, 0.0))
                    geometric_failure = maxf(geometric_failure,
                        float(leg.get(
                            "unified_unreachable_vertical", 0.0)))
                    if id.begins_with("leg_r"):
                        var original: Dictionary = leg.get(
                            "rear_kick_axis_source", {})
                        if not original.is_empty():
                            var axis: Vector3 = (
                                foot.global_position
                                - knee.global_position)
                            var expect_lower: Quaternion = (
                                Quaternion(original[
                                    "lower_axis"] as Vector3,
                                    axis.normalized())
                                * (original[
                                    "lower_rotation"] as Quaternion)
                                ).normalized()
                            axis_error = maxf(axis_error, rad_to_deg(
                                expect_lower.angle_to(
                                    knee.global_basis
                                    .get_rotation_quaternion())))
                    samples += 1
                if not ended or samples < 10:
                    _fail(id + "/" + kind
                        + " did not complete source strike")
                    return
                checked += 1
    print("V420_REBUILT_DIAG: combos=" + str(checked)
        + " toe_deg=" + str(toe_error)
        + " axis_deg=" + str(axis_error)
        + " knee_windup_step=" + str(knee_step)
        + " floor_err=" + str(floor_error)
        + " unreachable_vertical=" + str(geometric_failure))
    if toe_error > MAX_TOE_ANGLE_ERROR_DEGREES:
        _fail("foot rotation differs from mirrored source")
        return
    if axis_error > MAX_REAR_AXIS_ERROR_DEGREES:
        _fail("shin acquired axial roll")
        return
    if knee_step > MAX_KNEE_WINDUP_STEP_METERS:
        _fail("anticipation knee snapped")
        return
    if floor_error > MAX_FLOOR_ERROR_METERS:
        _fail("strike foot lost source-relative ground")
        return
    if geometric_failure > 0.001:
        _fail("source floor goal vertically beyond physical reach")
        return
    print("GODOT_V420_REBUILT_ATTACK_PASS")
    quit(0)
