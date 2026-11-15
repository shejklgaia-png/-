extends SceneTree
## v395: the three non-front-left SWEEPs must reflect the entire
## authored left-front animation (including BODY roll), never apply
## its delta atop incompatible rear/right Wait rotations. HEAD return
## caps are enforced AFTER all look filters in every gait/attack state.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0
const RETURN_YAW_DEGREES: float = 25.0
const RETURN_PITCH_DEGREES: float = 12.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V395_SWEEP_HEAD_RETURN_FAIL: " + why)
    quit(1)

func _sample_authored_sweep(battle: Node3D, id: String,
        clip_time: float) -> Dictionary:
    var rig: Node3D = battle.get("bittaran_rig")
    rig.call("end_authored_attack")
    rig.call("apply_pose", "Wait", 0.0)
    rig.call("start_authored_attack", "sweep", id)
    var frame: Dictionary = {
        "kind": "sweep", "id": id,
        "time": 0.70 + clip_time,
        "authored_time": clip_time,
        "windup": 0.70, "strike": 2.06,
        "hold": 0.0, "recovery": 1.40
    }
    rig.call("apply_authored_attack_pose", frame)
    var body: Node3D = rig.find_child("Body", true, false)
    var upper_name: String = ""
    var foot_name: String = ""
    match id:
        "leg_fl":
            upper_name = "FrontLeg_L"
            foot_name = "FrontFoot_L"
        "leg_fr":
            upper_name = "FrontLeg_R"
            foot_name = "FrontFoot_R"
        "leg_rl":
            upper_name = "RearLeg_L"
            foot_name = "RearFoot_L"
        "leg_rr":
            upper_name = "RearLeg_R"
            foot_name = "RearFoot_R"
    var upper: Node3D = rig.find_child(upper_name, true, false)
    var foot: Node3D = rig.find_child(foot_name, true, false)
    return {
        "relative_foot": body.to_local(foot.global_position)
            - body.to_local(upper.global_position),
        "body": body.quaternion,
        "upper": upper.quaternion,
        "foot": foot.quaternion,
        "floor": (battle.get("bittaran_foot_ik") as RefCounted).call(
            "_foot_mesh_lowest_y", foot)
    }

func _check_sweep_retarg(battle: Node3D) -> bool:
    var rig: Node3D = battle.get("bittaran_rig")
    for source_time in [0.25, 0.50, 0.75, 1.0]:
        var source: Dictionary = _sample_authored_sweep(
            battle, "leg_fl", source_time)
        for id in ["leg_fr", "leg_rl", "leg_rr"]:
            var target: Dictionary = _sample_authored_sweep(
                battle, id, source_time)
            var mirrored: Vector3 = source["relative_foot"]
            if id.ends_with("r"):
                mirrored.x = -mirrored.x
            if id.begins_with("leg_r"):
                mirrored.z = -mirrored.z
            var displacement: float = mirrored.distance_to(
                target["relative_foot"])
            if displacement > 0.30:
                _fail(id + " sweep not a true mirrored ankle arc "
                    + str([source_time, displacement, mirrored,
                        target["relative_foot"]]))
                return false
            var vertical_error: float = absf(
                float(target["floor"]) - float(source["floor"]))
            if vertical_error > 0.32:
                _fail(id + " sweep contact height diverged "
                    + str([source_time, vertical_error,
                        source["floor"], target["floor"]]))
                return false
            var reflected_body: Quaternion = rig.call(
                "_mirror_author_delta", source["body"], id)
            if absf(reflected_body.dot(target["body"])) < 0.995:
                _fail(id + " sweep BODY tilt was not mirrored")
                return false
            var reflected_upper: Quaternion = rig.call(
                "_mirror_author_delta", source["upper"], id)
            if absf(reflected_upper.dot(target["upper"])) < 0.995:
                _fail(id + " sweep upper joint angle was not mirrored")
                return false
    return true

func _check_realtime_sweep(battle: Node3D) -> bool:
    for id in ATTACKS.LEG_IDS:
        battle.call("_reset_target_after_respawn")
        battle.set("target_move_enabled", true)
        var boss: Node3D = battle.get("target")
        var player: CharacterBody3D = battle.get("player")
        var ik: RefCounted = battle.get("bittaran_foot_ik")
        var brain: RefCounted = battle.get("bittaran_attacks")
        if not bool(brain.call("force_start", id, "sweep")):
            _fail(id + " sweep not selectable")
            return false
        var seen_recovery: bool = false
        for tick in range(285):
            # Avoid damaging SERA during the attack probe.
            player.global_position = boss.global_position + Vector3(
                4.0, 0.0, 10.0)
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            battle.call("_finalize_target_pose", DT)
            var leg: Dictionary = ik.get("legs")[
                IK.LEG_PART_IDS.find(id)]
            var foot: Node3D = leg["foot"]
            var bottom: float = ik.call("_foot_mesh_lowest_y", foot)
            if bottom < IK.FLOOR_Y - 0.027:
                _fail(id + " SWEEP foot buried at time "
                    + str([frame.get("time", 0.0), bottom]))
                return false
            if str(frame.get("phase", "")) == "recovery":
                seen_recovery = true
                var cap: float = deg_to_rad(float(
                    battle.get("head_arm_return_yaw_limit_degrees")))
                var allowed: float = minf(cap,
                    deg_to_rad(RETURN_YAW_DEGREES))
                var yaw: float = absf(float(
                    battle.get("boss_head_yaw")))
                var return_elapsed: float = float(
                    frame.get("time", 0.0)) - (
                    float(frame.get("windup", 0.0))
                    + float(frame.get("strike", 0.0))
                    + float(frame.get("hold", 0.0)))
                # Angle checks alone can miss a returning shin passing
                # THROUGH the head with a neutral-facing yaw. Reject
                # actual rendered-mesh penetration beyond 12cm.
                if return_elapsed > 0.48:
                    var depths: Dictionary = (
                        battle.get("target_parts") as Node3D).call(
                        "get_head_leg_penetration_depths")
                    var worst: float = 0.0
                    for depth in depths.values():
                        worst = maxf(worst, float(depth))
                    if worst > 0.12:
                        _fail(id + " SWEEP returning leg obstructs HEAD "
                            + str([return_elapsed, worst, depths,
                                yaw, battle.get(
                                    "head_visual_clearance_lift_world")]))
                        return false
                if return_elapsed > 0.48 and yaw > allowed + 0.018:
                    _fail(id + " HEAD failed to clear returning sweep "
                        + str([yaw, allowed, return_elapsed,
                            battle.call("_head_return_clearance_active"),
                            battle.get("head_collision_blocked"),
                            battle.get("head_collision_filtered_depth"),
                            battle.get("head_visual_clearance_lift_world"),
                            ik.get("attack_pose")]))
                    return false
                # Narrow return clearance is approached smoothly,
                # while the absolute mechanical arm limit is immediate.
                if yaw > cap + 0.015:
                    _fail(id + " HEAD exceeded hard arm limit")
                    return false
        if not seen_recovery:
            _fail(id + " sweep recovery absent")
            return false
    return true

func _check_head_all_states(battle: Node3D) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", false)
    var player: CharacterBody3D = battle.get("player")
    var boss: Node3D = battle.get("target")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var head: Node3D = battle.get("bittaran_head")
    var max_limit: float = float(battle.get(
        "head_arm_return_yaw_limit_degrees"))
    var return_limit: float = RETURN_YAW_DEGREES
    for side in [-1.0, 1.0]:
        player.global_position = boss.global_position + Vector3(
            side * 15.0, 0.0, 2.0)
        for tick in range(95):
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
        var yaw: float = absf(rad_to_deg(float(
            battle.get("boss_head_yaw"))))
        if yaw > max_limit + 0.50:
            _fail("HEAD exceeded neutral arm envelope before return")
            return false
        # A newly replanted foot instantly makes the entire neutral
        # trajectory unsafe to enter: even the previously accumulated
        # yaw and point-blank yaw HOLD must obey the new bound.
        var legs: Array = ik.get("legs")
        legs[0]["stepping"] = true
        battle.set("boss_head_yaw", deg_to_rad(85.0 * side))
        battle.set("head_look_filtered_yaw", deg_to_rad(85.0 * side))
        battle.set("boss_head_pitch", deg_to_rad(-55.0))
        battle.call("_aim_bittaran_head", DT)
        yaw = absf(rad_to_deg(float(battle.get("boss_head_yaw"))))
        if yaw > max_limit + 0.50:
            _fail("HEAD crossed hard shoulder-return stop at replant")
            return false
        # Transition at the same angular speed as normal tracking:
        # no visible 40-degree snap on the first replanted step.
        for tick in range(36):
            battle.call("_aim_bittaran_head", DT)
        yaw = absf(rad_to_deg(float(battle.get("boss_head_yaw"))))
        var filtered: float = absf(rad_to_deg(float(
            battle.get("head_look_filtered_yaw"))))
        var pitch: float = absf(rad_to_deg(float(
            battle.get("boss_head_pitch"))))
        if yaw > return_limit + 1.0 or filtered > return_limit + 1.0 \
                or pitch > RETURN_PITCH_DEGREES + 1.0:
            _fail("HEAD did not smoothly clear returning-foot envelope "
                + str([yaw, filtered, pitch, return_limit]))
            return false
        if not head.quaternion.is_finite():
            _fail("HEAD quaternion invalid after return clamp")
            return false
        legs[0]["stepping"] = false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _check_sweep_retarg(battle):
        return
    if not _check_realtime_sweep(battle):
        return
    if not _check_head_all_states(battle):
        return
    print("GODOT_V395_SWEEP_HEAD_RETURN_PASS: four sweep limbs use "
        + "mirrored authored world-height arcs and body roll, "
        + "real attacks stay above floor, HEAD never violates "
        + "mechanical yaw stop and smooth return-foot clearance goals")
    quit(0)
