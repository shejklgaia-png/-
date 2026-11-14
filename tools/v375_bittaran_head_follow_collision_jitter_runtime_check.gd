extends SceneTree
## v375: ignore brief collisions, never snap the HEAD away from the
## player, and progressively slow only sustained deep head/leg intrusion.
const DT: float = 1.0 / 60.0
const BOSS_SCRIPT = preload("res://scripts/bittaran_battle.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V375_BITTARAN_HEAD_STABILITY_FAIL: " + why)
    quit(1)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if boss == null or player == null or ik == null:
        _fail("scene initialization")
        return
    if absf(float(BOSS_SCRIPT.HEAD_LEG_ALLOWED_PENETRATION_METERS)
            - 0.30) > 0.00001:
        _fail("HEAD must permit exactly 30cm penetration")
        return
    # One frame of even severe-looking AABB contact MUST NOT change speed.
    battle.set("head_collision_filtered_excess", 0.0)
    var one_frame: float = float(battle.call(
        "_head_collision_motion_scale", 0.0, 0.20, DT))
    if absf(one_frame - 1.0) > 0.00001:
        _fail("one-frame collision slowed/flickered head")
        return
    # A non-worsening collision may never penalize the follow angle.
    for frame in range(100):
        var harmless: float = float(battle.call(
            "_head_collision_motion_scale", 0.16, 0.16, DT))
        if absf(harmless - 1.0) > 0.00001:
            _fail("unchanging overlap throttled tracking")
            return
    var persistent: float = 1.0
    for frame in range(80):
        persistent = float(battle.call(
            "_head_collision_motion_scale", 0.0, 0.25, DT))
        if persistent < 0.55 - 0.00001 or persistent > 1.00001:
            _fail("sustained collision stopped or accelerated head")
            return
    if persistent >= 0.70:
        _fail("sustained severe collision was never softened")
        return
    var escape: float = float(battle.call(
        "_head_collision_motion_scale", 0.3, 0.18, DT))
    if absf(escape - 1.0) > 0.00001:
        _fail("head was prevented from turning away from obstacle")
        return
    battle.set("head_collision_filtered_excess", 0.0)
    # Exercise the real post-break look-at while the four planted legs
    # move under the turning body.
    battle.set("locked_target_part_id", "leg_fl")
    var result: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(result.get("broken", false)):
        _fail("leg break did not start")
        return
    player.global_position = boss.global_position + Vector3(24.0, 0.0, 0.0)
    var saw_rise_head: bool = false
    var saw_full_turn: bool = false
    var max_stand_yaw: float = 0.0
    for frame in range(480):
        var before: float = float(battle.get("boss_head_yaw"))
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        var after: float = float(battle.get("boss_head_yaw"))
        var change: float = absf(after - before)
        var rise: bool = bool(ik.call("down_pose_active"))
        if rise and float(ik.call("standup_pose_fraction")) > 0.80:
            if after != 0.0:
                saw_rise_head = true
        if not rise:
            max_stand_yaw = maxf(max_stand_yaw, absf(after))
            if bool(ik.call("locomotion_ready")):
                saw_full_turn = true
        if change > deg_to_rad(140.0) * DT + 0.005:
            _fail("collision forced HEAD to jerk/snap: "
                + str([frame, rad_to_deg(change)]))
            return
    if not saw_rise_head or not saw_full_turn:
        _fail("real rise/normal tracking was not exercised")
        return
    print("GODOT_V375_BITTARAN_HEAD_STABILITY_PASS: no 1-frame "
        + "collision jitter, 55% minimum deep-overlap tracking speed, "
        + "no backwards collision snap during 480 real frames, max "
        + "post-rise head yaw=" + str(rad_to_deg(max_stand_yaw)) + "deg")
    quit(0)
