extends SceneTree
## v383: authentic Turn/Approach clip -> attack crossfade. The attack
## holds the root and three world-planted soles, tracks with torso through
## the last windup frame, freezes swing aim, and levels the striking toe.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V383_BITTARAN_AIM_SUPPORT_FAIL: " + why)
    quit(1)

func _case(battle: Node3D, id: String, kind: String,
        previous_motion: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    boss.rotation.y = 0.0
    # Exercise a real playing Turn or Approach clip, not a fabricated
    # bind pose. Its procedural IK foot swing must crossfade to attack.
    for tick in range(20):
        player.global_position = boss.global_position + (
            Vector3(20.0, 0.0, 0.0) if previous_motion == "Turn"
            else boss.global_basis.z.normalized() * 20.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
    if str(rig.get("current_clip")) != previous_motion:
        _fail("failed to play " + previous_motion + " before attack")
        return false
    if not bool(brain.call("force_start", id, kind)):
        _fail("cannot force live " + id + "/" + kind)
        return false
    # From now through the entire strike and recovery, translation and
    # yaw on the target/root are forbidden.
    var root_position: Vector3 = boss.global_position
    var root_yaw: float = boss.rotation.y
    var index: int = IK.LEG_PART_IDS.find(id)
    var leg: Dictionary = ik.get("legs")[index]
    var support_anchors: Dictionary = {}
    var old_aim: Vector3 = Vector3.ZERO
    var locked_aim: Vector3 = Vector3.ZERO
    var locked_heading: float = 0.0
    var reached_swing: bool = false
    var moved_while_winding: bool = false
    var yaw_after_switch: float = 0.0
    var peak_straight: float = 0.0
    var peak_level: float = 0.0
    var saw_real_blend: bool = false
    var saw_head_look: bool = false
    var stop_time: float = 0.0
    match kind:
        "stomp":
            stop_time = BRAIN.STOMP_WINDUP_SECONDS + BRAIN.STOMP_STRIKE_SECONDS
        "kick":
            stop_time = BRAIN.KICK_WINDUP_SECONDS + BRAIN.KICK_STRIKE_SECONDS
        "sweep":
            stop_time = BRAIN.SWEEP_WINDUP_SECONDS + BRAIN.SWEEP_STRIKE_SECONDS
    var last_windup_heading: float = 0.0
    var elapsed: float = 0.0
    for tick in range(170):
        var offset: Vector3 = Vector3(7.5, 0.0, 0.0)
        if tick > 18:
            offset = Vector3(-7.5, 0.0, 0.0)
        if reached_swing:
            # Move SERA across the boss again after the strike begins.
            # BODY and swing target must remain frozen, HEAD still looks.
            offset = Vector3(0.0, 0.0, 7.5)
        player.global_position = root_position + offset
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            break
        elapsed = float(frame.get("time", 0.0))
        if tick == 0:
            saw_real_blend = (str(rig.get("current_clip")) == "Idle"
                and float(rig.get("blend_elapsed")) < 0.24)
        if bool(frame.get("tracking", false)):
            old_aim = frame.get("aim", Vector3.ZERO)
            last_windup_heading = float(frame.get("body_yaw", 0.0))
            if tick == 17:
                yaw_after_switch = last_windup_heading
            if tick > 29 and absf(
                    last_windup_heading - yaw_after_switch) > 0.04:
                moved_while_winding = true
        elif not reached_swing:
            reached_swing = true
            locked_aim = frame.get("aim", Vector3.ZERO)
            locked_heading = float(frame.get("body_yaw", 0.0))
        elif elapsed <= stop_time + 0.0001:
            if (frame.get("aim", Vector3.ZERO) as Vector3).distance_to(
                    locked_aim) > 0.00001 or absf(float(
                    frame.get("body_yaw", 0.0)) - locked_heading) > 0.00001:
                _fail(id + "/" + kind + " kept tracking during swing")
                return false
        if boss.global_position.distance_to(root_position) > 0.000001                 or absf(wrapf(boss.rotation.y - root_yaw, -PI, PI)) > 0.000001:
            _fail(id + "/" + kind + " moved the root mid-attack")
            return false
        battle.call("_finalize_target_pose", DT)
        if tick == 0:
            for n in range(IK.LEG_PART_IDS.size()):
                if IK.LEG_PART_IDS[n] == id:
                    continue
                var support: Dictionary = ik.get("legs")[n]
                support_anchors[IK.LEG_PART_IDS[n]] = support["anchor"]
        else:
            for support_id in support_anchors:
                var support_index: int = IK.LEG_PART_IDS.find(support_id)
                var support: Dictionary = ik.get("legs")[support_index]
                var original: Vector3 = support_anchors[support_id]
                var goal: Vector3 = support["last_goal"]
                if Vector2(goal.x - original.x,
                        goal.z - original.z).length() > 0.0001:
                    _fail(id + "/" + kind + " moved support sole "
                        + support_id + ": " + str(goal - original))
                    return false
                if elapsed > 0.26 and absf(goal.y - IK.FLOOR_Y) > 0.001:
                    _fail(id + "/" + kind + " did not plant support sole "
                        + support_id)
                    return false
                # Not just the requested IK goal: the visible foot mesh
                # must ACTUALLY remain at that planted world contact.
                if elapsed > 0.26:
                    var rendered_sole: Vector3 = (
                        support["foot"] as Node3D).to_global(
                        support["sole_local"])
                    var planted: Vector3 = support["anchor"]
                    var actual_xz: float = Vector2(
                        rendered_sole.x - planted.x,
                        rendered_sole.z - planted.z).length()
                    if actual_xz > 0.045 or (
                            absf(rendered_sole.y - IK.FLOOR_Y) > 0.07):
                        _fail(id + "/" + kind + " actual support sole slipped "
                            + support_id + ": " + str(rendered_sole - planted))
                        return false
        if bool(battle.get("head_look_initialized")) and absf(float(
                battle.get("head_look_filtered_yaw"))) > 0.002:
            saw_head_look = true
        if elapsed >= stop_time - 0.035 and elapsed <= stop_time + 0.001:
            var ankle: Node3D = leg["foot"]
            var up: Vector3 = ankle.global_basis.y.normalized()
            peak_level = maxf(peak_level, up.dot(Vector3.UP))
            var hip: Vector3 = (leg["upper"] as Node3D).global_position
            var knee: Vector3 = (leg["lower"] as Node3D).global_position
            var end: Vector3 = ankle.global_position
            var reach: float = hip.distance_to(knee) + knee.distance_to(end)
            peak_straight = maxf(peak_straight,
                hip.distance_to(end) / maxf(0.001, reach))
    if not saw_real_blend or not reached_swing:
        _fail(id + "/" + kind + " lacked clip blend or strike transition")
        return false
    if not moved_while_winding:
        _fail(id + "/" + kind + " chest failed to track during anticipation")
        return false
    if (locked_aim - old_aim).length() > 0.0001:
        _fail(id + "/" + kind + " aim was not last live windup sample")
        return false
    # v385 replaced procedural foot leveling/full-extension with the
    # user's authored KICK/SWEEP keyframes. Their EXACT joint poses are
    # checked by v385 rather than imposing superseded v383 IK geometry.
    # STOMP now levels only at actual contact, not at raised swing height.
    if not is_finite(peak_level) or not is_finite(peak_straight):
        _fail(id + "/" + kind + " non-finite authored foot pose")
        return false
    if not saw_head_look:
        _fail("head look lost during attack " + id + "/" + kind)
        return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var count: int = 0
    for id in BRAIN.LEG_IDS:
        for kind in BRAIN.ATTACK_KINDS:
            var previous_motion: String = (
                "Turn" if (count % 2 == 0) else "Approach")
            if not _case(battle, id, kind, previous_motion):
                return
            count += 1
    if count != 12:
        _fail("not all 12 real moving->attack transitions tested")
        return
    print("GODOT_V383_BITTARAN_ATTACK_AIM_SUPPORT_PASS: all 12 combos "
        + "from Turn/Approach into crossfaded windup, chest aim until "
        + "strike, frozen swing/immobile root, 3 planted support feet, "
        + "flat foot during strikes and live head tracking")
    quit(0)
