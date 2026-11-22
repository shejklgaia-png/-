extends SceneTree
## Four-leg end-to-end STOMP check: front x1.8/rear x1.5 toe volume starts
## ONLY after the real apex, damages once, then releases ground dust.
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
        if player == null or target == null or attacks == null \
                or dirt == null:
            _fail("missing live STOMP nodes " + leg_id)
            return
        player.global_position = target.global_position + Vector3(0, 0, 18)
        if not bool(attacks.call("force_start", leg_id, "stomp")):
            _fail("force_start denied " + leg_id)
            return

        var pre_apex_overlap: bool = false
        var post_apex_overlap: bool = false
        var post_apex_hit: bool = false
        var contacted: bool = false
        var first_apex_time: float = INF
        var first_hit_time: float = INF
        var ground_pulses: int = 0
        var was_pulsed: bool = false
        var hp_at_hit: float = INF
        for tick in range(260):
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            var phase: String = str(frame.get("phase", ""))
            var clip_t: float = float(frame.get("authored_time", 0.0))
            battle.call("_finalize_target_pose", DT)
            var raw: AABB = battle.call(
                "_bittaran_attack_foot_bounds", leg_id)
            var box: AABB = battle.call(
                "_bittaran_stomp_follow_box", leg_id)
            if not raw.has_volume() or not box.has_volume():
                _fail("toe bounds missing " + leg_id)
                return
            var expected_width: float = (
                1.80 if leg_id.begins_with("leg_f") else 1.50)
            if absf(box.size.x - raw.size.x * expected_width) > 0.005 \
                    or absf(box.size.z - raw.size.z * expected_width) > 0.005:
                _fail("incorrect front/rear toe mesh width " + leg_id)
                return
            if battle.get("bittaran_stomp_follow_fx") != null \
                    or battle.get("bittaran_shockwave") != null:
                _fail("square stomp effect has not been removed " + leg_id)
                return

            var armed: bool = bool(battle.get("stomp_follow_apex_passed"))
            var landed: bool = bool(battle.get("stomp_follow_landed"))
            if armed and first_apex_time == INF:
                first_apex_time = clip_t
                var peak_y: float = float(
                    battle.get("stomp_follow_apex_y"))
                if peak_y - raw.position.y < 0.059:
                    _fail("armed before the actual upward peak " + leg_id)
                    return
            if phase == "strike" and not landed and raw.position.y > 0.20:
                # Force SERA to occupy the real 3D foot volume. Check
                # that this cannot damage while still raising the limb.
                var center: Vector3 = box.get_center()
                player.global_position = Vector3(
                    center.x, center.y - 0.8, center.z)
                battle.call("_update_bittaran_stomp_follow")
                if not armed:
                    pre_apex_overlap = true
                    if bool(attacks.get("hit_consumed")) or (
                            float(battle.get("player_hp")) < 100000.0):
                        _fail("stomp damaged during windup ascent " + leg_id)
                        return
                elif not post_apex_hit:
                    post_apex_overlap = true
                    if float(battle.get("player_hp")) < 100000.0:
                        post_apex_hit = true
                        first_hit_time = clip_t
                        hp_at_hit = float(battle.get("player_hp"))
                        if not bool(attacks.get("hit_consumed")):
                            _fail("hit did not consume attack " + leg_id)
                            return
            if post_apex_hit and float(
                    battle.get("player_hp")) < hp_at_hit - 0.001:
                _fail("duplicate stomp damage " + leg_id)
                return
            var pulsed: bool = bool(dirt.get("stomped_this_attack"))
            if pulsed and not was_pulsed:
                ground_pulses += 1
                if not bool(battle.call(
                        "_bittaran_striking_foot_grounded", leg_id)):
                    _fail("contact dust emitted in air " + leg_id)
                    return
                contacted = true
            was_pulsed = pulsed
        print("STOMP_APEX_TRACE id=", leg_id,
            " apex_t=", first_apex_time,
            " hit_t=", first_hit_time,
            " pre_apex_safe=", pre_apex_overlap,
            " hit_after_apex=", post_apex_hit,
            " ground_fx=", ground_pulses)
        battle.queue_free()
        if not pre_apex_overlap or not post_apex_overlap \
                or not post_apex_hit or first_apex_time == INF \
                or first_hit_time < first_apex_time \
                or ground_pulses != 1 or not contacted:
            _fail("incomplete apex-gated stomp " + leg_id)
            return
    print("BITTARAN_STOMP_FOLLOW_PASS")
    quit(0)
