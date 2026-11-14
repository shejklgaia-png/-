extends SceneTree
## v381: exercise the ACTUAL four-leg rig and every attack trajectory.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V381_BITTARAN_ATTACKS_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var parts: Node3D = battle.get("target_parts")
    var ring: MeshInstance3D = battle.get("bittaran_shockwave")
    if rig == null or ik == null or brain == null or parts == null             or ring == null:
        _fail("real rig, attack controller, IK or shockwave missing")
        return
    if ATTACKS.STOMP_WINDUP_SECONDS != 1.0             or ATTACKS.KICK_WINDUP_SECONDS != 1.0:
        _fail("one-second stomp/kick anticipation changed")
        return
    if not bool(rig.get("loading_ok")) or not bool(ik.get("ready")):
        _fail("live source bones or IK failed to initialize")
        return
    var combinations: int = 0
    for id in ATTACKS.LEG_IDS:
        for kind in ATTACKS.ATTACK_KINDS:
            brain.call("reset")
            ik.call("reset")
            if not bool(brain.call("force_start", id, kind)):
                _fail("cannot start " + id + " " + kind)
                return
            var index: int = IK.LEG_PART_IDS.find(id)
            if index < 0:
                _fail("leg index mismatch")
                return
            var legs: Array = ik.get("legs")
            var leg: Dictionary = legs[index]
            var rest: Vector3 = leg["anchor"]
            var largest_shift: float = 0.0
            var raised: bool = false
            var kicked_out: bool = false
            var impact_count: int = 0
            var finished: bool = false
            var span: float = 0.0
            match kind:
                "stomp":
                    span = ATTACKS.STOMP_WINDUP_SECONDS                         + ATTACKS.STOMP_STRIKE_SECONDS                         + ATTACKS.STOMP_RECOVERY_SECONDS
                "kick":
                    span = ATTACKS.KICK_WINDUP_SECONDS                         + ATTACKS.KICK_STRIKE_SECONDS                         + ATTACKS.KICK_RECOVERY_SECONDS
                "sweep":
                    span = ATTACKS.SWEEP_WINDUP_SECONDS                         + ATTACKS.SWEEP_STRIKE_SECONDS                         + ATTACKS.SWEEP_RECOVERY_SECONDS
            var steps: int = ceili((span + 0.02) / DT)
            for _n in range(steps):
                var frame: Dictionary = brain.call(
                    "advance", DT, Vector3.ZERO, {}, true)
                ik.call("set_attack_pose", frame)
                rig.call("set_motion", "Idle", DT)
                ik.call("advance_ik", DT, "Idle")
                var foot: Vector3 = leg["last_goal"]
                if not is_finite(foot.x) or not is_finite(foot.y)                         or not is_finite(foot.z):
                    _fail("non-finite " + id + " " + kind)
                    return
                largest_shift = maxf(
                    largest_shift, Vector2(foot.x - rest.x,
                        foot.z - rest.z).length())
                if kind == "stomp" and foot.y > rest.y + 0.40:
                    raised = true
                if kind == "kick" and float(frame.get("time", 0.0)) < 0.90                         and foot.distance_to(rest) > 0.08:
                    _fail("kick preview slid a planted foot: " + id)
                    return
                if kind == "kick" and largest_shift > 0.20:
                    kicked_out = true
                if bool(frame.get("impact", false)):
                    impact_count += 1
                if not bool(brain.call("is_active")):
                    finished = true
            ik.call("clear_attack_pose")
            rig.call("set_motion", "Idle", DT)
            ik.call("advance_ik", DT, "Idle")
            if not finished:
                _fail("failed to recover: " + id + " " + kind)
                return
            if (leg["last_goal"] as Vector3).distance_to(rest) > 0.10:
                _fail("non-neutral sole after recovery: " + id + " " + kind)
                return
            if kind == "stomp" and (not raised or impact_count != 1):
                _fail("stomp lift/impact mismatch: " + id)
                return
            if kind == "kick" and not kicked_out:
                _fail("no outer-leg extension: " + id)
                return
            if kind == "sweep" and largest_shift <= 0.20:
                _fail("no lateral whip: " + id)
                return
            combinations += 1
    if combinations != 12:
        _fail("not all four legs received all three attacks")
        return
    var sample_shin: AABB = parts.call("get_part_aabb", "leg_fl")
    var half := Vector2(sample_shin.size.x * 0.75,
        sample_shin.size.z * 0.75)
    battle.call("_emit_bittaran_shockwave", Vector3.ZERO, half)
    if not ring.visible:
        _fail("impact shockwave not emitted")
        return
    battle.call("_tick_bittaran_shockwave", 0.32)
    if ring.visible:
        _fail("impact shockwave did not expire")
        return
    # Real combat integration: a planted SERA standing at the contact
    # point takes exactly one shockwave/foot damage event, not two hits.
    brain.call("reset")
    ik.call("reset")
    if not bool(brain.call("force_start", "leg_fr", "stomp")):
        _fail("cannot start live stomp hit regression")
        return
    var impact_seen: bool = false
    var hero: CharacterBody3D = battle.get("player")
    var hp_before: float = float(battle.get("player_hp"))
    for _tick in range(ceili(1.25 / DT)):
        var state: Dictionary = brain.call(
            "advance", DT, Vector3.ZERO, {}, true)
        ik.call("set_attack_pose", state)
        rig.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
        if bool(state.get("impact", false)):
            var contact: Vector3 = ik.call("attack_contact_world")
            hero.global_position = Vector3(contact.x, 0.0, contact.z)
            battle.set("bittaran_attack_frame", state)
            battle.call("_check_bittaran_attack_hit")
            var once: float = float(battle.get("player_hp"))
            battle.call("_check_bittaran_attack_hit")
            var twice: float = float(battle.get("player_hp"))
            if once >= hp_before or absf(once - twice) > 0.0001:
                _fail("stomp did not damage exactly once via player combat")
                return
            if not ring.visible:
                _fail("stomp damage tick did not create the ring effect")
                return
            impact_seen = true
    if not impact_seen:
        _fail("stomp did not reach the impact physics tick")
        return
    print("GODOT_V381_BITTARAN_ATTACKS_PASS: 12 distinct leg/attack "
        + "combinations, 1s planted previews, one stomp impact, "
        + "IK sole recovery, world-space shockwave lifetime")
    quit(0)
