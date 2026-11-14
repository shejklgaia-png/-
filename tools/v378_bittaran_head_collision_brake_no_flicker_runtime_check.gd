extends SceneTree
## v378: head yaw slows smoothly with contact depth and cannot advance
## beyond 10cm; 1.8cm stop hysteresis rejects contact frame flicker.
## A synthetic head/leg depth probe checks the actual yaw limiter at
## known geometric threshold, independent of the battle staging.
const BOSS = preload("res://scripts/bittaran_battle.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

class DepthProbe extends Node3D:
    var observed_head: Node3D
    var base: Quaternion = Quaternion.IDENTITY

    func get_head_leg_penetration_depths() -> Dictionary:
        var relative: Quaternion = (base.inverse() *
            observed_head.quaternion).normalized()
        var yaw: float = absf(2.0 * atan2(relative.y, relative.w))
        return {
            "leg_fl": yaw * 0.50,
            "leg_fr": 0.0,
            "leg_rl": 0.0,
            "leg_rr": 0.0
        }


func _initialize() -> void:
    call_deferred("_run")

func _fail(text_value: String) -> void:
    push_error("V378_HEAD_BRAKE_FAIL: " + text_value)
    quit(1)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var actual_head: Node3D = battle.get("bittaran_head")
    var original_parts: Node3D = battle.get("target_parts")
    if actual_head == null or original_parts == null:
        _fail("missing real head or collision adapter")
        return
    if absf(BOSS.HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.10) > 0.00001:
        _fail("stop penetration must be 10cm")
        return
    var probe := DepthProbe.new()
    probe.observed_head = actual_head
    probe.base = actual_head.quaternion
    root.add_child(probe)
    battle.set("target_parts", probe)
    var limited: float = float(battle.call(
        "_head_limit_yaw_to_30cm", probe.base, 0.0, 1.0, 0.0))
    if limited < 0.192 or limited > 0.200:
        _fail("head yaw was not clamped at 10cm depth: " + str(limited))
        return
    # 60fps and low-FPS frames must never tunnel past the cap.
    for wanted in [0.22, 0.4, 0.8, 1.6]:
        var cap: float = float(battle.call(
            "_head_limit_yaw_to_30cm", probe.base, 0.0,
            float(wanted), 0.0))
        if cap < 0.0 or cap > 0.20:
            _fail("a large frame crossed the head depth cap")
            return
    # An already deep pose may rotate only OUT of the penetration.
    var block: float = float(battle.call(
        "_head_limit_yaw_to_30cm", probe.base, 0.70, 0.85, 0.35))
    if absf(block - 0.70) > 0.00001:
        _fail("overlapping HEAD advanced farther into leg")
        return
    var out: float = float(battle.call(
        "_head_limit_yaw_to_30cm", probe.base, 0.70, 0.50, 0.35))
    if absf(out - 0.50) > 0.00001:
        _fail("HEAD was trapped when trying to retreat")
        return
    battle.set("target_parts", original_parts)
    actual_head.quaternion = probe.base
    probe.queue_free()
    # Speed must be monotone across depth and reach exact zero at 10cm.
    battle.set("head_collision_filtered_depth", 0.0)
    battle.set("head_collision_blocked", false)
    var previous_speed: float = 2.0
    for depth in [0.0, 0.02, 0.04, 0.06, 0.08, 0.098]:
        for _frame in range(120):
            battle.call("_head_collision_motion_scale",
                float(depth), float(depth), DT)
        var speed: float = float(battle.call(
            "_head_collision_motion_scale", float(depth), float(depth), DT))
        if speed > previous_speed + 0.001 or speed < 0.0:
            _fail("head did not progressively decelerate with contact")
            return
        previous_speed = speed
    if previous_speed > 0.05:
        _fail("head yaw did not nearly stop just below 10cm")
        return
    var stopped: float = float(battle.call(
        "_head_collision_motion_scale", 0.10, 0.11, DT))
    if stopped != 0.0:
        _fail("head did not fully stop at 10cm")
        return
    for p in [0.099, 0.101, 0.088, 0.096, 0.085]:
        if float(battle.call("_head_collision_motion_scale",
                p, p + 0.003, DT)) != 0.0:
            _fail("tiny collision noise released head stop")
            return
    if float(battle.call("_head_collision_motion_scale",
            0.14, 0.09, DT)) < 0.39:
        _fail("retreat was trapped")
        return
    if absf(BOSS.HEAD_TRACK_STANDUP_START_FRACTION - 0.70) > 0.00001 \
            or absf(IK.HEAD_KNEE_MAX_BEND - 0.45) > 0.00001:
        _fail("head recovery or minimal knee IK changed")
        return
    print("GODOT_V378_HEAD_BRAKE_PASS: smooth depth brake, hard "
        + "10cm yaw cap, no stop flicker, unrestricted escape")
    quit(0)
