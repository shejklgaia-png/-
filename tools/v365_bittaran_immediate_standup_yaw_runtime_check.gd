extends SceneTree
## v365: the boss must neither turn during the fallen hold nor ease yaw
## speed into stand-up. Root yaw starts on the exact frame the physical
## IK chassis begins rising, already at ordinary 34 deg/s.
const DT: float = 1.0 / 60.0
const NORMAL_YAW_STEP: float = deg_to_rad(34.0) * DT
const ONE_LEG: Array[String] = ["leg_fl"]
const FOUR_LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V365_BITTARAN_YAW_START_FAIL: " + reason)
    quit(1)

func _run_case(battle: Node3D, ids: Array[String], label: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var actor: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if ik == null or rig == null or actor == null or player == null:
        _fail(label + ": missing IK/rig/actor/player")
        return false
    actor.rotation.y = 0.0
    player.global_position = actor.global_position + Vector3(26.0, 0.0, 0.0)
    battle.call("_advance_target_motion", DT)
    if str(battle.get("bittaran_motion")) != "Turn":
        _fail(label + ": missing normal baseline turn")
        return false
    for id in ids:
        battle.set("locked_target_part_id", id)
        var hit: Dictionary = battle.call(
            "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
        if not bool(hit.get("broken", false)):
            _fail(label + ": could not break leg " + id)
            return false
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)

    var pre_rise_frames: int = 0
    var first_rise_frame: int = -1
    var post_rise_frames: int = 0
    var yaw_at_first_rise: float = -1.0
    var finished: bool = false
    for frame in range(490):
        var elapsed: float = float(ik.get("break_elapsed"))
        var recovery_start: float = float(ik.get("break_recover_start"))
        var down_active: bool = bool(ik.call("down_pose_active"))
        var in_windup: bool = bool(ik.call("windup_active"))
        var ready_to_move: bool = bool(ik.call("locomotion_ready"))
        var allowed_turn: bool = bool(ik.call("standup_turn_enabled", DT))
        var before_yaw: float = actor.rotation.y
        var before_position: Vector3 = actor.position
        battle.call("_advance_target_motion", DT)
        var actual_step: float = absf(wrapf(
            actor.rotation.y - before_yaw, -PI, PI))
        if not ready_to_move:
            var expected_clip: String = ("Turn" if allowed_turn else "Idle")
            if str(battle.get("bittaran_motion")) != expected_clip or str(
                    rig.get("current_clip")) != expected_clip:
                _fail(label + ": wrong clip before/at stand-up: "
                    + str(battle.get("bittaran_motion"))
                    + " expected=" + expected_clip)
                return false
            if not allowed_turn and Vector2(
                    actor.position.x - before_position.x,
                    actor.position.z - before_position.z).length() > 0.00001:
                _fail(label + ": root moved before stand-up")
                return false

        # Movement is updated before IK each tick, so the gate must use
        # elapsed+DT to begin turning in the SAME frame the rise begins.
        var first_physical_rise: bool = down_active and (
            elapsed < recovery_start and elapsed + DT >= recovery_start)
        if in_windup or (down_active and elapsed + DT
                < recovery_start - 0.00001):
            pre_rise_frames += 1
            if allowed_turn or actual_step > 0.000001:
                _fail(label + ": turned too early on frame " + str(frame)
                    + " elapsed=" + str(elapsed))
                return false
        if first_physical_rise:
            if first_rise_frame >= 0:
                _fail(label + ": rise started twice")
                return false
            first_rise_frame = frame
            yaw_at_first_rise = actual_step
            if not allowed_turn or absf(
                    actual_step - NORMAL_YAW_STEP) > 0.00007:
                _fail(label + ": first physical rise tick was not full-speed "
                    + "turn: " + str(rad_to_deg(actual_step)) + "deg; expected "
                    + str(rad_to_deg(NORMAL_YAW_STEP)) + "deg")
                return false
        if down_active and elapsed > recovery_start + 0.04:
            post_rise_frames += 1
            if not allowed_turn or absf(
                    actual_step - NORMAL_YAW_STEP) > 0.00007:
                _fail(label + ": turn speed changed after starting to rise "
                    + str(rad_to_deg(actual_step)))
                return false
        battle.call("_finalize_target_pose", DT)
        if first_physical_rise and float(ik.call(
                "standup_pose_fraction")) <= 0.0:
            _fail(label + ": yaw began without a physical upward pose change")
            return false
        if ready_to_move:
            if str(battle.get("bittaran_motion")) != "Turn":
                _fail(label + ": normal Turn did not resume after stand-up")
                return false
            finished = true
            break
    if not finished or first_rise_frame < 0 or pre_rise_frames < 100 \
            or post_rise_frames < 12:
        _fail(label + ": incomplete windup/rise/release frame coverage: "
            + str([finished, first_rise_frame,
                pre_rise_frames, post_rise_frames]))
        return false
    print("V365_YAW_CASE_PASS: " + label + " still until frame "
        + str(first_rise_frame) + ", then immediate "
        + str(rad_to_deg(yaw_at_first_rise))
        + "deg/60Hz turn with no speed ramp and active Turn clip")
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    if not _run_case(battle, ONE_LEG, "single-leg 2.5s"):
        return
    if not _run_case(battle, FOUR_LEGS, "four-leg 6.0s"):
        return
    print("GODOT_V365_BITTARAN_YAW_START_PASS: Turn clip starts exactly "
        + "with chassis stand-up at full 34deg/s, no interpolation")
    quit(0)
