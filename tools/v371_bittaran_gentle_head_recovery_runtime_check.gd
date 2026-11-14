extends SceneTree
## v371: weak, twice-smoothed head reacquisition begins at 70% upright
## and stays continuous through the final 0.24s post-rise settle.
const DT: float = 1.0 / 60.0
const MAX_RISE_WEIGHT: float = 0.60
const START: float = 0.70
const POST_SETTLE: float = 0.24

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V371_BITTARAN_GENTLE_HEAD_FAIL: " + why)
    quit(1)

func _pose_time(pose_fraction: float) -> float:
    # The IK's actual pose is cubic-smoothed elapsed time. Invert it
    # so the 70% gate is tested in POSE space, not elapsed-time space.
    var lo: float = 0.0
    var hi: float = 1.0
    for _i in range(32):
        var mid: float = (lo + hi) * 0.5
        var cubic: float = mid * mid * (3.0 - 2.0 * mid)
        if cubic < pose_fraction:
            lo = mid
        else:
            hi = mid
    return (lo + hi) * 0.5

func _check_rise(battle: Node3D, ik: RefCounted,
        rise_seconds: float) -> bool:
    var start: float = float(ik.get("break_recover_start"))
    var previous: float = -1.0
    for requested in [0.0, 0.45, 0.69, 0.70, 0.71, 0.78, 0.86, 0.94, 0.99, 1.0]:
        var pose: float = float(requested)
        ik.set("break_elapsed", start + rise_seconds * _pose_time(pose))
        var actual_pose: float = float(ik.call("standup_pose_fraction"))
        var weight: float = float(battle.call("_head_recovery_follow_weight"))
        if absf(actual_pose - pose) > 0.00002:
            _fail("pose-space sampling is incorrect " + str([actual_pose, pose]))
            return false
        if pose <= START and weight > 0.000001:
            _fail("head began tracking before 70% physical pose")
            return false
        if pose > START:
            var x: float = clampf((pose - START) / (1.0 - START), 0.0, 1.0)
            var quintic: float = x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
            var expected: float = MAX_RISE_WEIGHT * quintic * quintic
            var old_cubic: float = x * x * (3.0 - 2.0 * x)
            var old_weight: float = old_cubic * old_cubic
            if absf(weight - expected) > 0.00003:
                _fail("head follow does not match weak quintic curve")
                return false
            if weight > old_weight + 0.00001:
                _fail("new follow curve became stronger than old curve")
                return false
        if weight < previous - 0.00001:
            _fail("head follow strength went backward during rise")
            return false
        previous = weight
    if absf(previous - MAX_RISE_WEIGHT) > 0.00002:
        _fail("physical rise must end at 60% head tracking strength")
        return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if ik == null:
        _fail("missing Bittaran IK")
        return
    if absf(float(battle.call("_head_recovery_follow_weight")) - 1.0) > 0.00001:
        _fail("ordinary idle should have full head following")
        return
    for ids in [["leg_fl"], ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]]:
        battle.call("_reset_target_after_respawn")
        for id in ids:
            battle.set("locked_target_part_id", id)
            var hit: Dictionary = battle.call(
                "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
            if not bool(hit.get("broken", false)):
                _fail("cannot break limb " + id)
                return
        ik.set("windup_elapsed", -1.0)
        var rise: float = float(ik.get("break_duration")) - float(
            ik.get("break_recover_start"))
        var needed: float = 1.30 if ids.size() == 4 else 1.0
        if absf(rise - needed) > 0.0001:
            _fail("unexpected physical rise duration")
            return
        if not _check_rise(battle, ik, rise):
            return
        # Simulate the exact boundary where IK changes down_pose_active
        # to post_down_idle_remaining. Follow weight must stay continuous.
        ik.set("break_elapsed", -1.0)
        for remaining in [0.24, 0.18, 0.12, 0.06, 0.0]:
            ik.set("post_down_idle_remaining", float(remaining))
            var progress: float = 1.0 - float(remaining) / POST_SETTLE
            var eased: float = progress * progress * progress * (
                progress * (progress * 6.0 - 15.0) + 10.0)
            var follow: float = float(battle.call(
                "_head_recovery_follow_weight"))
            var speed: float = float(battle.call(
                "_head_recovery_turn_speed"))
            var expected_follow: float = lerpf(MAX_RISE_WEIGHT, 1.0, eased)
            var expected_speed: float = lerpf(48.0, 140.0, eased)
            if absf(follow - expected_follow) > 0.00002 or absf(
                    speed - expected_speed) > 0.00002:
                _fail("head follow/speed jumps at upright boundary: "
                    + str([remaining, follow, speed]))
                return
        battle.call("_reset_target_after_respawn")
        if absf(float(battle.call("_head_recovery_follow_weight"))
                - 1.0) > 0.00001:
            _fail("new encounter did not reset head follow state")
            return
    print("GODOT_V371_BITTARAN_GENTLE_HEAD_PASS: 70% pose gate, "
        + "weaker quintic-squared head follow (max 60% during rise), "
        + "continuous smooth 0.24s post-upright transition")
    quit(0)
