extends SceneTree
## v369: check the real combat leg-break path, 1.0/1.3s rise times,
## and a smooth nose-up BODY rotation that raises front shoulder pivots.
const DT: float = 1.0 / 60.0
const BACK_LEAN_DEGREES: float = 10.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V369_BITTARAN_STANDUP_FAIL: " + message)
    quit(1)

func _case(battle: Node3D, broken: Array[String],
        expected_rise: float, recovery_start: float) -> bool:
    battle.call("_reset_target_after_respawn")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    var front: Node3D = rig.find_child("FrontLeg_R", true, false) as Node3D
    var rear: Node3D = rig.find_child("RearLeg_R", true, false) as Node3D
    if body == null or front == null or rear == null:
        _fail("missing BODY/front/rear joints")
        return false
    if front.get_parent() != body or rear.get_parent() != body:
        _fail("shoulder pivots are not BODY children")
        return false
    for id in broken:
        battle.set("locked_target_part_id", id)
        var hit: Dictionary = battle.call(
            "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
        if not bool(hit.get("broken", false)):
            _fail("failed to break limb " + id)
            return false
    if not (absf(float(ik.get("break_recover_start")) - recovery_start) < 0.0001
            and absf(float(ik.get("break_duration")) -
            (recovery_start + expected_rise)) < 0.0001):
        _fail("wrong recovery timing " + str([ik.get("break_recover_start"),
            ik.get("break_duration"), expected_rise]))
        return false
    var frames_rising: int = 0
    var saw_hold: bool = false
    var finished: bool = false
    var greatest_front_lift: float = 0.0
    for frame in range(550):
        battle.call("_advance_target_motion", DT)
        var base_pose: Quaternion = body.quaternion
        battle.call("_finalize_target_pose", DT)
        var down: bool = bool(ik.call("down_pose_active"))
        var elapsed: float = float(ik.get("break_elapsed"))
        if down and elapsed >= 0.17 and elapsed < recovery_start:
            saw_hold = true
        if down and elapsed >= recovery_start:
            frames_rising += 1
            var t: float = clampf(
                (elapsed - recovery_start) / expected_rise, 0.0, 1.0)
            var backward: float = deg_to_rad(BACK_LEAN_DEGREES) * sin(PI * t)
            var nose_down: float = float(ik.get("break_chassis_pitch_radians"))
            var without_lean: Quaternion = (base_pose *
                Quaternion(Vector3.RIGHT, -nose_down)).normalized()
            var expected_pose: Quaternion = (base_pose *
                Quaternion(Vector3.RIGHT, backward) *
                Quaternion(Vector3.RIGHT, -nose_down)).normalized()
            if body.quaternion.angle_to(expected_pose) > 0.004:
                _fail("BODY back lean missing at rise fraction " + str(t))
                return false
            if t > 0.35 and t < 0.65:
                var fore_rise: float = (
                    (expected_pose * front.position).y -
                    (without_lean * front.position).y)
                var aft_rise: float = (
                    (expected_pose * rear.position).y -
                    (without_lean * rear.position).y)
                if fore_rise <= 0.0 or aft_rise >= 0.0:
                    _fail("rear lean did not raise front shoulder")
                    return false
                greatest_front_lift = maxf(greatest_front_lift, fore_rise)
            if int(ik.call("planted_foot_count")) != 4:
                _fail("foot swing began before chassis stood upright")
                return false
        elif frames_rising > 0 and not down:
            finished = true
            if body.quaternion.angle_to(base_pose) > 0.004:
                _fail("BODY tilt did not return to neutral")
                return false
            break
    if not (saw_hold and finished and greatest_front_lift >= 0.03
            and absf(float(frames_rising) - expected_rise / DT) <= 2.1):
        _fail("rise timing/shoulder lift invalid " +
            str([expected_rise, frames_rising, greatest_front_lift, finished]))
        return false
    print("V369_STANDUP_CASE_PASS: " + str(expected_rise) +
        "s, lifted front shoulder=" + str(greatest_front_lift))
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _case(battle, ["leg_fl"], 1.0, 2.10):
        return
    if not _case(battle, IDS, 1.3, 5.40):
        return
    print("GODOT_V369_BITTARAN_STANDUP_PASS: rise 1.0s / 1.3s, "
        + "10-degree rear lean lifting front shoulders")
    quit(0)
