extends SceneTree
## v358: A separate 0.60s heavy head throw and slightly lengthened forelegs
## precede (not consume) the original down duration; no unsupported hover
## is allowed through windup, collapse, and recovery.
const DT: float = 1.0 / 60.0
const EPS: float = 0.002

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V358_BITTARAN_FAIL: " + why)
    quit(1)

func _sole_height_acceptable(ik: RefCounted, label: String) -> bool:
    var planted: int = 0
    var lowest: float = INF
    for leg in ik.get("legs"):
        if bool(leg["stepping"]):
            continue
        planted += 1
        var position: Vector3 = (leg["foot"] as Node3D).to_global(
            leg["sole_local"])
        lowest = minf(lowest, position.y)
    if planted < 2 or lowest > 0.13 or lowest < -0.13:
        _fail(label + ": unsupported float/penetration, lowest="
            + str(lowest) + " planted=" + str(planted))
        return false
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    battle.set("target_move_enabled", false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var model: Node3D = battle.get("bittaran_rig")
    var parts: Node3D = battle.get("target_parts")
    var player: CharacterBody3D = battle.get("player")
    var head: Node3D = battle.get("bittaran_head")
    var normal: Quaternion = battle.get("boss_head_default_rotation")
    if ik == null or model == null or parts == null or head == null:
        _fail("missing articulated boss")
        return
    for i in range(90):
        model.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
        if not _sole_height_acceptable(ik, "rest pose frame " + str(i)):
            return

    # Turn the head before impact. Entering the actual DOWN phase must
    # completely discard this prior tracked orientation.
    player.global_position = battle.get("target").global_position + Vector3(4.0, 0, 8.0)
    for i in range(20):
        model.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
        battle.call("_aim_bittaran_head", DT)
    if absf(float(battle.get("boss_head_yaw"))) < deg_to_rad(1.0):
        _fail("setup failed to establish nonneutral head yaw")
        return

    var front_before: Dictionary = {}
    for leg in ik.get("legs"):
        if (leg["upper"] as Node3D).name.begins_with("Front"):
            front_before[(leg["upper"] as Node3D).name] = leg["anchor"]
    battle.set("locked_target_part_id", "leg_fl")
    var broken: Dictionary = battle.call("_apply_target_part_damage",
        "melee", 1, 240.0, 0.0, 0.0)
    if not bool(broken.get("broken", false)) or not bool(
            ik.call("windup_active")) or bool(ik.call("down_pose_active")):
        _fail("breaking blow did not start independent anticipation")
        return
    var starting_head_y: float = (
        parts.call("get_part_aim_world", "head") as Vector3).y
    var highest_head_y: float = starting_head_y
    var farthest_front_reach: float = 0.0
    var reached_down: bool = false
    for frame in range(220):
        model.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
        battle.call("_aim_bittaran_head", DT)
        parts.call("sync_bittaran_parts")
        if not _sole_height_acceptable(ik, "leg break " + str(frame)):
            return
        var y: float = (parts.call("get_part_aim_world", "head") as Vector3).y
        if frame < 36:
            highest_head_y = maxf(highest_head_y, y)
            for leg in ik.get("legs"):
                var name: String = (leg["upper"] as Node3D).name
                if front_before.has(name):
                    var distance: Vector3 = (leg["anchor"] as Vector3) - (
                        front_before[name] as Vector3)
                    distance.y = 0
                    farthest_front_reach = maxf(
                        farthest_front_reach, distance.length())
            if frame < 35 and bool(ik.call("down_pose_active")):
                _fail("down started before windup finished")
                return
        if bool(ik.call("down_pose_active")):
            reached_down = true
            var yaw: float = float(battle.get("boss_head_yaw"))
            # v363: neutral HEAD remains strict until 70% of the
            # actual stand-up. Above that it may smoothly reacquire SERA.
            if float(ik.call("standup_pose_fraction")) <= 0.70 and (
                    absf(yaw) > EPS
                    or head.quaternion.angle_to(normal) > EPS):
                _fail("head did not stay neutral before 70% of stand-up: "
                    + str(head.quaternion) + " yaw=" + str(yaw))
                return
        if frame >= 36 and bool(ik.call("windup_active")):
            _fail("0.6s windup continued into down pose")
            return
    if not reached_down:
        _fail("down phase never started after windup")
        return
    if highest_head_y < starting_head_y + 0.10:
        _fail("nose did not visibly kick upward in 0.6s windup: "
            + str(highest_head_y - starting_head_y))
        return
    if farthest_front_reach < 0.12:
        _fail("front limbs did not stretch while head threw backward: "
            + str(farthest_front_reach))
        return
    if bool(ik.call("break_reaction_active")):
        _fail("single-leg down exceeded 0.6s + 2.42s (1.25x rise)")
        return

    # Four broken legs keep the same 5.40s grounded hold, but shorten
    # just the physical rise to 0.48s (1.25x) after the 0.6s windup.
    battle.call("_reset_target_after_respawn")
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        battle.set("locked_target_part_id", id)
        var hit: Dictionary = battle.call("_apply_target_part_damage",
            "melee", 1, 240.0, 0.0, 0.0)
        if not bool(hit.get("broken", false)):
            _fail("failed to break " + id)
            return
    if absf(float(ik.get("break_duration")) - 5.88) > EPS:
        _fail("four-leg rise did not accelerate from 0.6s to 0.48s")
        return
    for frame in range(380):
        model.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
        battle.call("_aim_bittaran_head", DT)
        if not _sole_height_acceptable(ik, "four-leg down " + str(frame)):
            return
    if not bool(ik.call("break_reaction_active")):
        _fail("four-leg down ended before 0.6+5.88 seconds")
        return
    for frame in range(15):
        model.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
    if bool(ik.call("break_reaction_active")):
        _fail("four-leg down did not recover after 0.6+5.88 seconds")
        return
    print("GODOT_V358_BITTARAN_PASS: 0.6s heavy head rebound, front reach "
        + str(farthest_front_reach) + "m, neutral head on down, planted feet "
        + "through 2.42s and 5.88s reactions")
    quit(0)
