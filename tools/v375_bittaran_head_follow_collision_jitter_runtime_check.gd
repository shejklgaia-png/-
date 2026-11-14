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
            - 0.10) > 0.00001:
        _fail("HEAD must permit exactly 10cm penetration")
        return
    # One noisy contact may slightly slow, but cannot stop or jerk yaw.
    battle.set("head_collision_filtered_depth", 0.0)
    battle.set("head_collision_blocked", false)
    var one_frame: float = float(battle.call(
        "_head_collision_motion_scale", 0.0, 0.03, DT))
    if one_frame < 0.97 or one_frame > 1.00001:
        _fail("one-frame contact caused sudden head braking")
        return
    # Persistent deeper contact should slow smoothly towards zero.
    battle.set("head_collision_filtered_depth", 0.0)
    var speeds: Array[float] = []
    for depth in [0.0, 0.03, 0.06, 0.09]:
        for _frame in range(120):
            var speed: float = float(battle.call(
                "_head_collision_motion_scale", depth, depth, DT))
            if speed < 0.0 or speed > 1.00001:
                _fail("head collision speed escaped [0,1]")
                return
        speeds.append(float(battle.call(
            "_head_collision_motion_scale", depth, depth, DT)))
    for i in range(1, speeds.size()):
        if speeds[i] >= speeds[i - 1] - 0.01:
            _fail("head must slow progressively from first overlap")
            return
    # Hard stop at 10cm in the worsening direction; no jitter on
    # barely moving knee boxes until penetration falls under 27.5cm.
    var stopped: float = float(battle.call(
        "_head_collision_motion_scale", 0.10, 0.11, DT))
    if stopped != 0.0:
        _fail("head kept rotating deeper at 10cm")
        return
    for depth in [0.099, 0.101, 0.091, 0.088]:
        var held: float = float(battle.call(
            "_head_collision_motion_scale", depth, depth + 0.004, DT))
        if held != 0.0:
            _fail("contact jitter caused stop/start flicker")
            return
    var escape: float = float(battle.call(
        "_head_collision_motion_scale", 0.14, 0.10, DT))
    if escape < 0.39 or escape > 1.00001:
        _fail("head was prevented from gradually escaping overlap")
        return
    battle.set("head_collision_filtered_depth", 0.0)
    battle.set("head_collision_blocked", false)
    battle.set("head_collision_release_elapsed", 0.0)
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
    print("GODOT_V375_BITTARAN_HEAD_STABILITY_PASS: progressive "
        + "0-10cm slowdown, hard stop at 10cm, no contact flicker, "
        + "smooth escape and no head snap during 480 frames, max "
        + "post-rise head yaw=" + str(rad_to_deg(max_stand_yaw)) + "deg")
    quit(0)
