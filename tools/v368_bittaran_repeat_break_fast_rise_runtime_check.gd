extends SceneTree
## v368: break four DIFFERENT limbs in the SAME live encounter,
## without boss respawn or artificial clearing of part-break stun.
## Each break must reproduce anticipation, fall, 1.25x rise duration, chest
## yaw / Approach, world-planted soles and post-upright foot catch-up.
const DT: float = 1.0 / 60.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const RISE_SINGLE: float = 0.50
const RISE_ALL: float = 0.75
const SMALL: float = 0.0002

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V368_REPEAT_BREAK_FAIL: " + message)
    quit(1)

func _check_break(battle: Node3D, id: String,
        index: int, requested: String) -> bool:
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var ai: RefCounted = battle.get("bittaran_ai")
    # Keep the same fight and same damage/part state. New player angle is
    # chosen relative to the boss's CURRENT orientation after prior rounds.
    player.global_position = boss.global_position + (
        boss.global_basis.x * 28.0 if requested == "Turn"
        else boss.global_basis.z * 27.0)
    battle.call("_advance_target_motion", DT)
    if str(battle.get("bittaran_motion")) != requested:
        _fail(id + ": AI cannot enter " + requested + " before break")
        return false
    battle.set("locked_target_part_id", id)
    var result: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(result.get("broken", false)) or int(
            result.get("broken_legs", 0)) != index + 1:
        _fail(id + ": broken-leg state not incremented: " + str(result))
        return false
    if float(battle.get("part_break_remaining")) > 0.0001:
        _fail(id + ": generic 1s/3.5s stun blocks later rising animation")
        return false
    if not bool(ik.call("windup_active")):
        _fail(id + ": fresh break did not restart 0.6s anticipation")
        return false
    if bool(ik.get("recovery_gait_started")) or int(ik.get(
            "recovery_catchup_pending_pair")) != -1:
        _fail(id + ": previous foot catch-up state leaked into new break")
        return false

    var expected_start: float = 5.4 if index == 3 else 2.1
    var expected_rise: float = RISE_ALL if index == 3 else RISE_SINGLE
    var expected_duration: float = expected_start + expected_rise
    if absf(float(ik.get("break_recover_start"))
            - expected_start) > 0.00001 or absf(float(
            ik.get("break_duration")) - expected_duration) > 0.0001:
        _fail(id + ": 1.25x rise duration changed hold or is incorrect: "
            + str([ik.get("break_recover_start"), ik.get("break_duration"),
                expected_start, expected_duration]))
        return false

    var elapsed_windup: float = 0.0
    var down_seen: bool = false
    var first_rise_seen: bool = false
    var first_rise_time: float = -1.0
    var rise_completed: bool = false
    var final_rise_time: float = -1.0
    var head_follow_started: bool = false
    var foot_started_after_rise: bool = false
    var max_step_lead: float = 0.0
    var no_early_step_frames: int = 0
    var active_rise_frames: int = 0
    var post_rise_frames: int = 0
    var initial_windup: bool = true
    var stepped_past_second_pair: bool = false
    var first_pair: int = -1
    for frame in range(620):
        var before_down: bool = bool(ik.call("down_pose_active"))
        var before_windup: bool = bool(ik.call("windup_active"))
        var will_rise: bool = bool(ik.call("standup_turn_enabled", DT))
        var was_rising: bool = before_down and will_rise
        var before_yaw: float = boss.rotation.y
        var before_pos: Vector3 = boss.position
        battle.call("_advance_target_motion", DT)
        var chosen: String = str(battle.get("bittaran_motion"))
        var playing: String = str(rig.get("current_clip"))
        var moved: float = Vector2(
            boss.position.x - before_pos.x,
            boss.position.z - before_pos.z).length()
        var yaw_change: float = absf(wrapf(
            boss.rotation.y - before_yaw, -PI, PI))
        if not will_rise and (before_down or before_windup):
            if chosen != "Idle" or playing != "Idle" or moved > SMALL \
                    or yaw_change > SMALL:
                _fail(id + ": not stationary while down/anticipating at "
                    + str(frame))
                return false
        elif was_rising:
            if chosen != requested or playing != requested:
                _fail(id + ": no " + requested + " clip on recurring rise "
                    + str(frame) + " state=" + chosen)
                return false
            if yaw_change > deg_to_rad(34.0) * DT + SMALL:
                _fail(id + ": chassis turned faster than the 34deg/s cap")
                return false
            if requested == "Approach" and moved <= 0.000001:
                _fail(id + ": Approach stopped on second/later destruction")
                return false
            active_rise_frames += 1
            if not first_rise_seen:
                first_rise_seen = true
                first_rise_time = float(ik.get("break_elapsed"))
        battle.call("_finalize_target_pose", DT)
        var down_now: bool = bool(ik.call("down_pose_active"))
        var after_windup: bool = bool(ik.call("windup_active"))
        if before_windup:
            elapsed_windup += DT
        if down_now:
            down_seen = true
            var pair: int = int(ik.get("stepping_pair"))
            if pair != -1:
                _fail(id + ": foot attempted catching up while still down")
                return false
            no_early_step_frames += 1
            var weight: float = float(battle.call(
                "_head_recovery_follow_weight"))
            if float(ik.call("standup_pose_fraction")) <= 0.70 \
                    and weight > SMALL:
                _fail(id + ": head followed before 70% recovery")
                return false
            if weight > 0.0:
                head_follow_started = true
        elif down_seen and not after_windup:
            if not rise_completed:
                rise_completed = true
                final_rise_time = float(ik.get("break_duration"))
                var elapsed_since_start: float = final_rise_time - expected_start
                if absf(elapsed_since_start - expected_rise) > SMALL:
                    _fail(id + ": changed 1.25x rise duration mid-encounter")
                    return false
            post_rise_frames += 1
            if int(ik.get("stepping_pair")) >= 0:
                foot_started_after_rise = true
                if first_pair < 0:
                    first_pair = int(ik.get("stepping_pair"))
                elif first_pair != int(ik.get("stepping_pair")):
                    stepped_past_second_pair = true
                for leg in ik.get("legs"):
                    if not bool(leg["stepping"]):
                        continue
                    var expected: Vector3 = ik.call(
                        "_home", leg, chosen == "Approach")
                    var touchdown: Vector3 = leg["swing_to"]
                    if expected.distance_to(touchdown) > 0.0002:
                        _fail(id + ": landing target stopped tracking chassis")
                        return false
            if post_rise_frames > 100:
                break
    if not down_seen or not first_rise_seen or not rise_completed \
            or not foot_started_after_rise or not stepped_past_second_pair \
            or not head_follow_started or no_early_step_frames < 80 \
            or active_rise_frames < 12 or absf(
            elapsed_windup - 0.60) > DT * 1.1:
        _fail(id + ": incomplete consecutive leg-break behavior: " +
            str([index, down_seen, first_rise_seen, rise_completed,
                foot_started_after_rise, stepped_past_second_pair,
                head_follow_started, no_early_step_frames,
                active_rise_frames, elapsed_windup]))
        return false
    print("V368_REPEAT_CASE_PASS: broken #" + str(index + 1)
        + " id=" + id + " clip=" + requested
        + " stand-up=" + str(expected_rise)
        + "s, planted frames=" + str(no_early_step_frames)
        + ", dynamic foot placement after rise")
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    battle.set("target_move_enabled", true)
    for i in range(IDS.size()):
        var wanted: String = "Turn" if i % 2 == 0 else "Approach"
        if not _check_break(battle, IDS[i], i, wanted):
            return
    print("GODOT_V368_REPEAT_BREAK_PASS: all four distinct limbs break "
        + "successively WITHOUT respawn, with the same rise/turn/approach "
        + "and delayed foot-placement logic every time; physical stand-up "
        + "takes 1.25x normal time, original fallen hold unchanged")
    quit(0)
