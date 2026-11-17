extends SceneTree
## v426: front-only BODY leveling/height, post-attack ordering and zero drift.
const DT: float = 0.05
const IK = preload("res://scripts/bittaran_foot_ik.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V426_ATTACK_RETURN_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("missing scene")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var director: RefCounted = battle.get("bittaran_attacks")
    var actor: Node3D = rig
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if not bool(rig.get("loading_ok")) or ik == null:
        _fail("the v426 model/IK is not loaded")
        return
    var count: int = 0
    var first_result: Dictionary = {}
    for repeat in range(2):
        for id in ["leg_fl", "leg_fr"]:
            for kind in ["sweep", "kick", "stomp"]:
                # Intentionally do NOT reset the arena between repetitions.
                # Keep any previous plant history and recover using gameplay.
                player.global_position = (
                    target.global_position + Vector3(0.0, 0.0, 7.0))
                if not bool(director.call("force_start", id, kind)):
                    _fail("cannot select attack " + id + " " + kind)
                    return
                var had_attack: bool = false
                var had_return: bool = false
                var max_drop: float = 0.0
                var max_tilt_before: float = 0.0
                var max_tilt_after: float = 0.0
                var return_order_ok: bool = true
                var frame_count: int = 0
                for tick in range(155):
                    battle.call("_advance_target_motion", DT)
                    var frame: Dictionary = battle.get("bittaran_attack_frame")
                    # Only sample the original source before IK; this is the
                    # baseline for measuring body leveling.
                    var body: Node3D = rig.find_child("Body", true, false)
                    var wait: Quaternion = rig.call("_authored_key_rotation",
                        "Wait", "Body", 0.0)
                    battle.call("_finalize_target_pose", DT)
                    var drop: float = float(ik.get("front_attack_drop_world"))
                    var returning: bool = bool(ik.call(
                        "front_height_recovery_active"))
                    var return_elapsed: float = float(
                        ik.get("front_return_elapsed"))
                    if not frame.is_empty() and not bool(frame.get(
                            "stance_prepare", false)):
                        had_attack = true
                        if drop > 0.0001 or drop < -1.101:
                            _fail("attack BODY offset exceeded bounded range")
                            return
                        max_drop = maxf(max_drop, -drop)
                        # During the attack's strike interval, the BODY
                        # pose must be closer to its level Wait rotation.
                        if str(frame.get("phase", "")) == "strike":
                            var clip_name: String = (
                                "踏みつけ_L" if kind == "stomp" else
                                ("弾き" if kind == "kick" else "なぎ払い"))
                            if id == "leg_fr":
                                clip_name = (
                                    "踏みつけ_R" if kind == "stomp"
                                    else clip_name + "_R")
                            var original: Quaternion = rig.call(
                                "_authored_key_rotation", clip_name, "Body",
                                float(frame.get("authored_time", 0.0)))
                            var original_tilt: float = original.angle_to(wait)
                            var rendered_tilt: float = body.quaternion.angle_to(wait)
                            max_tilt_before = maxf(max_tilt_before, original_tilt)
                            max_tilt_after = maxf(max_tilt_after, rendered_tilt)
                            if rendered_tilt > original_tilt + 0.025:
                                _fail("BODY leveling rotated further from Wait")
                                return
                    if returning:
                        had_return = true
                        if return_elapsed < IK.FRONT_STANCE_RETURN_SECONDS - 0.01:
                            # BODY must remain at attack height until the
                            # attacking leg is home and has ceased toe clamping.
                            if not is_equal_approx(float(
                                    ik.get("front_attack_drop_world")), drop):
                                return_order_ok = false
                        if str(battle.get("bittaran_motion")) != "Idle":
                            _fail("walk/turn resumed before BODY height settled")
                            return
                    if had_return and not returning:
                        break
                    frame_count += 1
                if not had_attack or not had_return or not return_order_ok:
                    _fail("missing attack / return sequence: " + id
                        + "/" + kind)
                    return
                if bool(ik.call("front_height_recovery_active")):
                    _fail("return stage never cleared")
                    return
                if absf(float(ik.get("front_attack_drop_world"))) > 0.00001:
                    _fail("BODY height accumulated after attack")
                    return
                var foot_leg: Dictionary = (
                    ik.get("legs")[IK.LEG_PART_IDS.find(id)])
                if foot_leg.has("front_ground_sweep_pole") or foot_leg.has(
                        "front_ground_shin_roll") or foot_leg.has(
                        "front_ground_kick_shoulder_shift"):
                    _fail("old knee contact cache leaked into next attack")
                    return
                var metric: String = id + "/" + kind
                if repeat == 0:
                    first_result[metric] = max_drop
                elif absf(max_drop - float(first_result[metric])) > 0.10:
                    _fail("repeated attack body drop drifted: " + metric
                        + " " + str([first_result[metric], max_drop]))
                    return
                print("V426_ATTACK_RETURN_CASE: ", metric, " repeat=", repeat,
                    " frames=", frame_count, " max_drop=", max_drop,
                    " level_before=", max_tilt_before,
                    " level_after=", max_tilt_after)
                count += 1
    if count != 12:
        _fail("not all attacks repeated")
        return
    print("GODOT_V426_ATTACK_RETURN_PASS: six attack types x two cycles, BODY level/drop, leg first, no cached drift")
    quit(0)
