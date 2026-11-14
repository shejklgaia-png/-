extends SceneTree
## v366/v367: Turn and Approach still start on the FIRST rising tick.
## The body turns at full rate with world-planted soles. Once the torso
## is upright, IK starts catching up, retargeting touchdown to live stance.
const DT: float = 1.0 / 60.0
const ONE_LEG: Array[String] = ["leg_fl"]
const FOUR_LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V366_BITTARAN_LIVE_RISE_FAIL: " + why)
    quit(1)

func _case(battle: Node3D, legs_to_break: Array[String],
        motion: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)
    var ai: RefCounted = battle.get("bittaran_ai")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var actor: Node3D = battle.get("target")
    var rig: Node3D = battle.get("bittaran_rig")
    var player: CharacterBody3D = battle.get("player")
    if ai == null or ik == null or actor == null or rig == null or player == null:
        _fail("missing AI/IK/actor/rig/player")
        return false
    actor.rotation.y = 0.0
    var offset: Vector3 = (Vector3(26.0, 0.0, 0.0)
        if motion == "Turn" else Vector3(0.0, 0.0, 26.0))
    player.global_position = actor.global_position + offset
    battle.call("_advance_target_motion", DT)
    if str(battle.get("bittaran_motion")) != motion:
        _fail("baseline cannot select " + motion)
        return false
    for id in legs_to_break:
        battle.set("locked_target_part_id", id)
        var hit: Dictionary = battle.call(
            "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
        if not bool(hit.get("broken", false)):
            _fail("break not initiated: " + id)
            return false
    battle.set("stagger_remaining", 0.0)
    battle.set("part_break_remaining", 0.0)
    battle.set("down_remaining", 0.0)

    var hold_frames: int = 0
    var first_rise_frame: int = -1
    var rise_played_frames: int = 0
    var first_step_pair: int = -1
    var upright_first_step_frame: int = -1
    var rise_root_distance: float = 0.0
    var final_recovered: bool = false
    for frame in range(480):
        var elapsed: float = float(ik.get("break_elapsed"))
        var recover_start: float = float(ik.get("break_recover_start"))
        var down_active: bool = bool(ik.call("down_pose_active"))
        var rising: bool = bool(ik.call("standup_turn_enabled", DT))
        var first_rise: bool = down_active and (
            elapsed < recover_start and elapsed + DT >= recover_start)
        var old_pos: Vector3 = actor.position
        var old_yaw: float = actor.rotation.y
        battle.call("_advance_target_motion", DT)
        var chosen: String = str(battle.get("bittaran_motion"))
        var playing: String = str(rig.get("current_clip"))
        var distance_step: float = Vector2(actor.position.x - old_pos.x,
            actor.position.z - old_pos.z).length()
        if not rising:
            hold_frames += 1
            if chosen != "Idle" or playing != "Idle":
                _fail(motion + " played before rising on frame " + str(frame))
                return false
            if distance_step > 0.000001 or absf(wrapf(
                    actor.rotation.y - old_yaw, -PI, PI)) > 0.000001:
                _fail("boss moved during fully fallen/throw period")
                return false
        elif down_active:
            rise_played_frames += 1
            if chosen != motion or playing != motion:
                _fail("missing " + motion + " clip in rising frame "
                    + str(frame) + ": " + chosen + "/" + playing)
                return false
            if motion == "Approach":
                if distance_step < 0.000001:
                    _fail("Approach played but failed to move toward SERA")
                    return false
                rise_root_distance += distance_step
            else:
                if absf(wrapf(actor.rotation.y - old_yaw,
                        -PI, PI)) < deg_to_rad(0.15):
                    _fail("Turn played but failed to turn during rising")
                    return false
                if distance_step > 0.000001:
                    _fail("Turn erroneously advanced forward")
                    return false
        battle.call("_finalize_target_pose", DT)
        var stepping_pair: int = int(ik.get("stepping_pair"))
        if first_rise:
            first_rise_frame = frame
            if not bool(ik.call("down_pose_active")):
                _fail("rising body snapped upright on first motion frame")
                return false
            if float(ik.call("standup_pose_fraction")) <= 0.0:
                _fail("animation started before actual stand-up")
                return false
            if chosen != motion or playing != motion:
                _fail("first rise tick is still Idle, not " + motion)
                return false
            if stepping_pair >= 0:
                _fail("foot stepping before the chassis fully rose")
                return false
            var support_index: int = int(ik.get("head_support_leg_index"))
            if support_index >= 0:
                var leg_list: Array = ik.get("legs")
                var support: Dictionary = leg_list[support_index]
                if bool(support["stepping"]):
                    _fail("support leg lifted while still under HEAD")
                    return false
        if bool(ik.call("down_pose_active")) and stepping_pair >= 0:
            _fail("IK foot must remain planted while torso is rising")
            return false
        if stepping_pair >= 0 and first_step_pair < 0:
            if bool(ik.call("down_pose_active")):
                _fail("foot caught up before the torso was upright")
                return false
            first_step_pair = stepping_pair
            upright_first_step_frame = frame
        if not bool(ik.call("break_reaction_active")) and not final_recovered:
            final_recovered = true
            if chosen != motion:
                _fail("walk clip stopped at stand-up end")
                return false
        if final_recovered and bool(ik.call("locomotion_ready")):
            break
    if hold_frames < 100 or first_rise_frame < 0 or rise_played_frames < 12 \
            or first_step_pair < 0 or not final_recovered:
        _fail("insufficient real transition coverage: "
            + str([motion, legs_to_break.size(), hold_frames,
                first_rise_frame, rise_played_frames,
                first_step_pair, final_recovered]))
        return false
    if motion == "Approach" and rise_root_distance < 0.003:
        _fail("Approach translation during rise was too small")
        return false
    print("V366_LIVE_RISE_CASE_PASS: " + motion + " legs="
        + str(legs_to_break.size()) + " first rising frame="
        + str(first_rise_frame) + " first upright IK step="
        + str(upright_first_step_frame) + " pair=" + str(first_step_pair)
        + " during-rise distance=" + str(rise_root_distance))
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    for ids in [ONE_LEG, FOUR_LEGS]:
        for clip in ["Turn", "Approach"]:
            if not _case(battle, ids, clip):
                return
    print("GODOT_V366_BITTARAN_LIVE_RISE_PASS: Turn/Approach clips "
        + "and real body movement start with rise; IK steps only after "
        + "fully upright, original head/arm clearance and down durations")
    quit(0)
