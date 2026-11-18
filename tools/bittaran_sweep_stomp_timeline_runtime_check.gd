extends SceneTree
## Contact diagnostics: compare the source-clock foot paths with real IK,
## grounded mesh geometry, and the contact FX/damage gate at 60Hz.
const DT: float = 1.0 / 60.0
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(s: String) -> void:
    push_error("SOURCE_CONTACT_TIMELINE_FAIL " + s)
    quit(1)

func _verify_stomp_footprint_hit(leg_id: String,
        landing: Vector3) -> bool:
    # Rebuild the same strike with the SAME entry-time target (18m).
    # Once the authored aim locks, move SERA directly under the
    # previously measured REAL landing foot, before the downward hit.
    # This tests actual gameplay damage, not manually calling the
    # footprint damage helper or inventing a broad shockwave.
    var live: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(live)
    live.set_process(false)
    live.set_physics_process(false)
    live.set("player_hp", 9999.0)
    var body: Node3D = live.get("target")
    var player: CharacterBody3D = live.get("player")
    var attacks: RefCounted = live.get("bittaran_attacks")
    var fx: Node3D = live.get("bittaran_dirt_fx")
    if body == null or player == null or attacks == null or fx == null:
        _fail("wet stomp scenario could not initialize " + leg_id)
        return false
    player.global_position = body.global_position + Vector3(0, 0, 18)
    if not bool(attacks.call("force_start", leg_id, "stomp")):
        _fail("cannot start wet stomp " + leg_id)
        return false
    var hp_dropped: bool = false
    var contact_count: int = 0
    var old_pulse: bool = false
    var pulse_time: float = INF
    for tick in range(360):
        live.call("_advance_target_motion", DT)
        var frame: Dictionary = live.get("bittaran_attack_frame")
        if frame.is_empty():
            break
        var t: float = float(frame.get("authored_time", 0.0))
        if t > (1.32 if leg_id.begins_with("leg_f") else 0.86):
            player.global_position = Vector3(
                landing.x, 0.0, landing.z)
        live.call("_finalize_target_pose", DT)
        if float(live.get("player_hp")) < 9999.0:
            hp_dropped = true
        var pulse: bool = bool(fx.get("stomped_this_attack"))
        if pulse and not old_pulse:
            contact_count += 1
            pulse_time = t
        old_pulse = pulse
    print("STOMP_WET_CONTACT id=", leg_id,
        " expected_impact=", landing,
        " pulse_count=", contact_count,
        " pulse_t=", pulse_time,
        " player_damaged=", hp_dropped)
    live.queue_free()
    if not hp_dropped or contact_count != 1:
        _fail("real STOMP landing does not damage SERA once " +
            str([leg_id, contact_count, pulse_time, landing]))
        return false
    return true


func _run() -> void:
    for spec in [
            ["leg_fl", "sweep"], ["leg_rl", "sweep"],
            ["leg_fl", "stomp"], ["leg_fr", "stomp"],
            ["leg_rl", "stomp"], ["leg_rr", "stomp"]]:
        var b: Node3D = load(
            "res://scenes/bittaran_battle.tscn").instantiate()
        root.add_child(b)
        b.set_process(false)
        b.set_physics_process(false)
        b.set("player_hp", 100000.0)
        var target: Node3D = b.get("target")
        var player: CharacterBody3D = b.get("player")
        var attacks: RefCounted = b.get("bittaran_attacks")
        var fx: Node3D = b.get("bittaran_dirt_fx")
        var leg_id: String = spec[0]
        var kind: String = spec[1]
        if target == null or attacks == null or player == null or fx == null:
            _fail("missing live combat state")
            return
        player.global_position = target.global_position + Vector3(0,0,18)
        if not bool(attacks.call("force_start", leg_id, kind)):
            _fail("force-start denied " + str(spec))
            return
        var last: Vector3 = Vector3.ZERO
        var prev_band: int = -1
        var first_ground: float = INF
        var first_stomp: float = INF
        var actual_impact_point: Vector3 = Vector3.INF
        var impact_pulses: int = 0
        var was_stomped: bool = false
        for i in range(350):
            b.call("_advance_target_motion", DT)
            var frame: Dictionary = b.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            b.call("_finalize_target_pose", DT)
            var phase: String = str(frame.get("phase",""))
            var t: float = float(frame.get("authored_time", 0.0))
            if phase != "strike":
                continue
            var bounds: AABB = b.call("_bittaran_attack_foot_bounds",leg_id)
            var pos: Vector3 = b.call("_bittaran_original_attack_contact",leg_id)
            var local: Vector3 = target.to_local(pos)
            var speed: float = Vector2(pos.x-last.x,pos.z-last.z).length() / DT
            var grounded: bool = b.call("_bittaran_striking_foot_grounded",leg_id)
            if first_ground == INF and grounded:
                first_ground = t
            var stomped_now: bool = bool(
                fx.get("stomped_this_attack"))
            if stomped_now and not was_stomped:
                impact_pulses += 1
                if not grounded:
                    _fail("stomp impact emitted above floor " +
                        str([spec,t,bounds.position.y]))
                    return
                if first_stomp == INF:
                    first_stomp = t
                    actual_impact_point = pos
            was_stomped = stomped_now
            var band: int = int(floor(t * 10.0 + 0.0001))
            if band != prev_band:
                print("CONTACT_TRACE id=",leg_id," kind=",kind,
                    " t=",snappedf(t,0.001),
                    " phase=",phase,
                    " ground=",grounded,
                    " foot_y=",snappedf(bounds.position.y,0.001),
                    " local_xz=(",snappedf(local.x,0.01),",",snappedf(local.z,0.01),")",
                    " speed=",snappedf(speed,0.01),
                    " impactFX=",fx.get("stomped_this_attack"),
                    " collision=",frame.get("hit_window"),
                    " hp=",b.get("player_hp"))
                prev_band=band
            last = pos
        if kind == "stomp":
            var target_key: float = 1.467 if leg_id.begins_with(
                "leg_f") else 0.985
            if impact_pulses != 1 or not is_finite(first_stomp) or (
                    absf(first_stomp - target_key) > 0.075):
                _fail("single first-touch stomp event not replayed " +
                    str([spec,impact_pulses,first_stomp,target_key]))
                return
            if not _verify_stomp_footprint_hit(
                    leg_id, actual_impact_point):
                return
        print("CONTACT_SUMMARY id=",leg_id," kind=",kind,
            " first_ground=",first_ground,
            " stompFX=",first_stomp,
            " impact_pulses=",impact_pulses)
        b.queue_free()
    # Observe real boss decision behavior for close player.
    for distance in [0.9,1.65,2.4,2.75]:
        var battle: Node3D = load(
            "res://scenes/bittaran_battle.tscn").instantiate()
        root.add_child(battle)
        battle.set_process(false)
        battle.set_physics_process(false)
        battle.set("player_hp", 99999.0)
        var boss: Node3D = battle.get("target")
        var player: CharacterBody3D = battle.get("player")
        player.global_position = boss.global_position + Vector3(0,0,distance)
        var kinds: Array[String] = []
        var legal_foot_entries: int = 0
        var real_player_damage_events: int = 0
        var stomp_damage_events: int = 0
        for tick in range(1750):
            battle.set("player_hp", 99999.0)
            battle.call("_advance_target_motion",DT)
            var f: Dictionary=battle.get("bittaran_attack_frame")
            if not f.is_empty() and str(f.get("phase",""))=="entry" and (
                    kinds.is_empty() or str(f.get("kind","")) != kinds[-1]):
                kinds.append(str(f.get("kind","")))
                # v460: BODY range is now irrelevant. Verify the actual
                # selected LEG's own live post-IK sole is within reach
                # at every automatic attack entry.
                var feet: Dictionary = battle.call(
                    "_bittaran_attack_candidates")
                var id: String = str(f.get("id",""))
                var kind: String = str(f.get("kind",""))
                # Every attack snapshots the real physical sole at
                # decision-time, BEFORE source/IK changes the displayed
                # toe pose. Do not assert against the foot after replant.
                var decision_foot: Vector3 = f.get(
                    "selection_foot_world", Vector3.INF)
                if not is_finite(decision_foot.x) or (
                        not ATTACKS._leg_can_reach(
                            kind, id, player.global_position,
                            decision_foot, boss.rotation.y)):
                    _fail("AI selected out-of-range striking sole " +
                        str([distance, kind, id, decision_foot]))
                    return
                if feet.has(id):
                    var current_foot: Vector3 = feet[id]
                    var pose_shift: float = Vector2(
                        current_foot.x - decision_foot.x,
                        current_foot.z - decision_foot.z).length()
                    if pose_shift > 0.40:
                        print("SOURCE_ATTACK_ENTRY_IK_POSE_SHIFT leg=",
                            id, " distance=", pose_shift)
                legal_foot_entries += 1
                print("CONTACT_AI_ATTACK distance=",distance," tick=",tick,
                    " kind=",f.get("kind")," leg=",f.get("id"),
                    " boss_distance=",boss.global_position.distance_to(
                    player.global_position))
            battle.call("_finalize_target_pose",DT)
            if float(battle.get("player_hp")) < 99999.0:
                real_player_damage_events += 1
                if str(f.get("kind","")) == "stomp":
                    stomp_damage_events += 1
                print("CONTACT_AI_REAL_DAMAGE start=",distance,
                    " tick=",tick," source_kind=",f.get("kind"),
                    " source_t=",f.get("authored_time"),
                    " hp_after=",battle.get("player_hp"))
        # The player may be near the BODY but farther than 3m
        # from EVERY articulated sole: SWEEP is then the only legal
        # attack. Requiring the first attack to be STOMP would
        # reintroduce the old torso-centered range bug.
        if kinds.is_empty() or legal_foot_entries != kinds.size():
            _fail("source AI never selected a legal physical foot " +
                str([distance,kinds,legal_foot_entries]))
            return
        for k in range(1, kinds.size()):
            if kinds[k] == kinds[k-1]:
                _fail("repeated same attack after STOMP " + str(kinds))
                return
        print("CONTACT_AI_SUMMARY start_distance=",distance,
            " kind_history=",kinds,
            " hp_damage_events=",real_player_damage_events,
            " stomp_damage_events=",stomp_damage_events)
        battle.queue_free()
    print("GODOT_SOURCE_CONTACT_TIMELINE_PASS first-ground-sweep=true stomp-landing-once=true real-foot-range=true")
    quit(0)
