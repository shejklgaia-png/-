extends SceneTree
## Verify all four authored STOMPs track the rendered toe in 3D,
## can damage during the airborne windup, and land with FX once.
const DT: float = 1.0 / 60.0
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_STOMP_FOLLOW_FAIL " + message)
    quit(1)


func _run() -> void:
    for leg_id in LEG_IDS:
        var battle: Node3D = load(
            "res://scenes/bittaran_battle.tscn").instantiate()
        root.add_child(battle)
        battle.set_process(false)
        battle.set_physics_process(false)
        battle.set("player_hp", 100000.0)
        var player: CharacterBody3D = battle.get("player")
        var target: Node3D = battle.get("target")
        var attacks: RefCounted = battle.get("bittaran_attacks")
        var dirt: Node3D = battle.get("bittaran_dirt_fx")
        var follow: MeshInstance3D = battle.get(
            "bittaran_stomp_follow_fx") as MeshInstance3D
        if player == null or target == null or attacks == null \
                or dirt == null or follow == null:
            _fail("missing live STOMP nodes for " + leg_id)
            return
        player.global_position = target.global_position + Vector3(0, 0, 18)
        if not bool(attacks.call("force_start", leg_id, "stomp")):
            _fail("force_start denied " + leg_id)
            return
        var saw_airborne: bool = false
        var saw_moving_fx: bool = false
        var hit_before_ground: bool = false
        var contacted: bool = false
        var pulse_count: int = 0
        var previously_pulsed: bool = false
        var hp_after_first_hit: float = INF
        for tick in range(260):
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            var phase: String = str(frame.get("phase", ""))
            var source_time: float = float(
                frame.get("authored_time", 0.0))
            # _advance_target_motion resets the pre-IK source pose.
            # Sample the foot only AFTER _finalize_target_pose.
            battle.call("_finalize_target_pose", DT)
            var raw: AABB = battle.call(
                "_bittaran_attack_foot_bounds", leg_id)
            var box: AABB = battle.call(
                "_bittaran_stomp_follow_box", leg_id)
            if not raw.has_volume() or not box.has_volume():
                _fail("toe bounds missing " + leg_id)
                return
            var lift_end: float = (
                0.77 if leg_id.begins_with("leg_r") else 1.26)
            if phase == "strike" and source_time > 0.25 \
                    and source_time < lift_end and raw.position.y > 0.15:
                saw_airborne = true
                if not hit_before_ground:
                    # Insert SERA into the ACTUAL airborne volume, then
                    # rerun that frame's tracker after the teleport.
                    # This verifies the exact combat damage path without
                    # calling the hit helper or fabricating an FX pulse.
                    var c: Vector3 = box.get_center()
                    player.global_position = Vector3(c.x, c.y - 0.80, c.z)
                    battle.call("_update_bittaran_stomp_follow")
            if absf(box.size.x - raw.size.x * 1.5) > 0.005 \
                    or absf(box.size.z - raw.size.z * 1.5) > 0.005:
                _fail("not exactly 1.5x live toe width " + leg_id)
                return
            var landed: bool = bool(battle.get("stomp_follow_landed"))
            if not landed and (phase == "entry" or phase == "strike"):
                if not follow.visible:
                    _fail("moving volume invisible " + str([leg_id,phase]))
                    return
                if follow.global_position.distance_to(
                        box.get_center()) > 0.005 \
                        or follow.scale.distance_to(box.size) > 0.005:
                    _fail("visual volume detached from hitbox " + leg_id)
                    return
                saw_moving_fx = true
            if not hit_before_ground and not landed and saw_airborne \
                    and float(battle.get("player_hp")) < 100000.0:
                hit_before_ground = true
                hp_after_first_hit = float(battle.get("player_hp"))
                if not bool(attacks.get("hit_consumed")):
                    _fail("airborne hit did not consume attack " + leg_id)
                    return
            if hit_before_ground and float(
                    battle.get("player_hp")) < hp_after_first_hit - 0.001:
                _fail("repeated STOMP damage " + leg_id)
                return
            var pulsed: bool = bool(dirt.get("stomped_this_attack"))
            if pulsed and not previously_pulsed:
                pulse_count += 1
                if not bool(battle.call(
                        "_bittaran_striking_foot_grounded", leg_id)):
                    _fail("ground FX emitted in the air " + leg_id)
                    return
                contacted = true
                if follow.visible:
                    _fail("follower remains active after landing " + leg_id)
                    return
                var rim: MeshInstance3D = battle.get(
                    "bittaran_shockwave") as MeshInstance3D
                if rim == null or rim.scale.x <= 0.0 \
                        or rim.scale.z <= 0.0:
                    _fail("square impact rim missing " + leg_id)
                    return
                var half: Vector2 = battle.call(
                    "_bittaran_stomp_ground_half_extents", leg_id)
                if absf(rim.scale.x - half.x) > 0.005 \
                        or absf(rim.scale.z - half.y) > 0.005:
                    _fail("square rim does not match toe width " + leg_id)
                    return
            previously_pulsed = pulsed
        print("STOMP_FOLLOW_TRACE id=",leg_id,
            " airborne=",saw_airborne,
            " moving_fx=",saw_moving_fx,
            " airborne_hit=",hit_before_ground,
            " ground_pulses=",pulse_count,
            " contacted=",contacted)
        battle.queue_free()
        if not saw_airborne or not saw_moving_fx \
                or not hit_before_ground or pulse_count != 1 \
                or not contacted:
            _fail("incomplete live toe-follow test " + leg_id)
            return
    print("BITTARAN_STOMP_FOLLOW_PASS")
    quit(0)
