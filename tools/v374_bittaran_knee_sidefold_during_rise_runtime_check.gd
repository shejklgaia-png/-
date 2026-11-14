extends SceneTree
## v374: chest turns from the first rising frame; knee-pole sidefold must
## work BEFORE the 70% head-follow gate while keeping all four soles planted.
const DT: float = 1.0 / 60.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const ONE: Array[String] = ["leg_fl"]
const MAX_BEND: float = 0.45

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V374_BITTARAN_KNEE_RISE_FAIL: " + why)
    quit(1)

func _case(battle: Node3D, broken: Array[String],
        expected_time: float) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if ik == null or boss == null or player == null:
        _fail("missing scene IK/player/boss")
        return false
    player.global_position = boss.global_position + Vector3(26.0, 0, 0)
    for id in broken:
        battle.set("locked_target_part_id", id)
        var hit: Dictionary = battle.call(
            "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
        if not bool(hit.get("broken", false)):
            _fail("failed to break " + id)
            return false
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    if absf(float(ik.get("break_duration")) -
            float(ik.get("break_recover_start")) - expected_time) > 0.0001:
        _fail("physical rise timing changed")
        return false
    var saw_hold: bool = false
    var saw_early_scan: bool = false
    var checked_sidebend: bool = false
    var saw_head_follow: bool = false
    var completed: bool = false
    var last_scan: float = 1000.0
    for frame in range(650):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        var down: bool = bool(ik.call("down_pose_active"))
        var rising: bool = bool(ik.call("standup_knee_enabled"))
        var pose: float = float(ik.call("standup_pose_fraction"))
        var weight: float = float(battle.call(
            "_head_recovery_follow_weight"))
        var anticipated: float = float(battle.call(
            "_head_knee_look_weight"))
        var scan: float = float(ik.get("head_knee_scan_elapsed"))
        if down and not rising:
            saw_hold = true
            if bool(ik.get("head_knee_active")) or weight > 0.000001:
                _fail("head/knee tracking active during fall/hold")
                return false
        if rising:
            if int(ik.call("planted_foot_count")) != 4:
                _fail("feet began swinging while chest rises")
                return false
            for leg in ik.get("legs"):
                if float(leg["head_knee_bend"]) > MAX_BEND + 0.00001:
                    _fail("minimal sidefold cap exceeded during rise")
                    return false
            if pose > 0.30 and pose < 0.68:
                if absf(weight) > 0.000001 or anticipated <= 0.001:
                    _fail("knee anticipation did not precede 70% HEAD gate")
                    return false
                if scan < last_scan - 0.025:
                    saw_early_scan = true
                if not checked_sidebend:
                    # A non-supporting planted leg must genuinely respond
                    # to an IK knee pole even while break_elapsed is active.
                    var support: int = int(ik.get("head_support_leg_index"))
                    for i in range(4):
                        if i == support:
                            continue
                        var leg: Dictionary = ik.get("legs")[i]
                        var anchor: Vector3 = leg["last_goal"]
                        var sole_rotation: Quaternion = leg["last_rotation"]
                        var saved: float = float(leg["head_knee_bend"])
                        leg["head_knee_bend"] = 0.0
                        var err_neutral: float = float(
                            ik.call("_solve", leg, anchor, sole_rotation))
                        var knee_neutral: Vector3 = (
                            leg["lower"] as Node3D).global_position
                        leg["head_knee_bend"] = MAX_BEND
                        var err_side: float = float(
                            ik.call("_solve", leg, anchor, sole_rotation))
                        var knee_side: Vector3 = (
                            leg["lower"] as Node3D).global_position
                        leg["head_knee_bend"] = saved
                        ik.call("_solve", leg, anchor, sole_rotation)
                        if err_side <= maxf(0.20, err_neutral + 0.015) \
                                and knee_side.distance_to(knee_neutral) > 0.008:
                            checked_sidebend = true
                            break
            if pose > 0.75 and weight > 0.0001:
                saw_head_follow = true
        elif saw_early_scan and not down:
            completed = true
            break
        last_scan = scan
    if not (saw_hold and saw_early_scan and checked_sidebend
            and saw_head_follow and completed):
        _fail("no active knee IK throughout physical rise: " + str([
            broken.size(), saw_hold, saw_early_scan,
            checked_sidebend, saw_head_follow, completed]))
        return false
    print("V374_KNEE_RISE_CASE_PASS: broken=" + str(broken.size())
        + " physical rise=" + str(expected_time) +
        "s, sidefold enabled ahead of 70% head follow")
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _case(battle, ONE, 1.0):
        return
    if not _case(battle, IDS, 1.3):
        return
    print("GODOT_V374_BITTARAN_KNEE_RISE_PASS: minimal knee folding "
        + "during stand-up, planted soles and early torso yaw preserved")
    quit(0)
