extends SceneTree
## v382: broken shins can still attack. KICK/SWEEP extend the actual
## hip-knee-ankle chain almost completely instead of grounding the sole.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V382_BROKEN_LEG_STRAIGHT_ATTACK_FAIL: " + reason)
    quit(1)

func _check_straight_strikes(battle: Node3D) -> bool:
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    for id in ATTACKS.LEG_IDS:
        for kind in ["kick", "sweep"]:
            rig.call("set_motion", "Idle", DT)
            brain.call("reset")
            ik.call("reset")
            if not bool(brain.call("force_start", id, kind)):
                _fail("attack did not start " + id + "/" + kind)
                return false
            var index: int = IK.LEG_PART_IDS.find(id)
            var leg: Dictionary = ik.get("legs")[index]
            var anchor: Vector3 = leg["anchor"]
            var end_time: float = (
                ATTACKS.KICK_WINDUP_SECONDS + ATTACKS.KICK_STRIKE_SECONDS
                if kind == "kick" else
                ATTACKS.SWEEP_WINDUP_SECONDS + ATTACKS.SWEEP_STRIKE_SECONDS)
            var best_ratio: float = 0.0
            var off_floor_at_peak: bool = false
            var peak_shift: float = 0.0
            var recovered: bool = false
            # The 1.5s KICK hold was introduced after this v382 test.
            # Keep the full straight-leg test, but allow the actual
            # current hold plus full recovery to complete.
            var hold: float = (ATTACKS.KICK_POST_HIT_HOLD_SECONDS
                if kind == "kick" else ATTACKS.SWEEP_POST_HIT_HOLD_SECONDS)
            var recovery: float = (ATTACKS.KICK_RECOVERY_SECONDS
                if kind == "kick" else ATTACKS.SWEEP_RECOVERY_SECONDS)
            for frame in range(ceili((end_time + hold + recovery + 0.08) / DT)):
                var state: Dictionary = brain.call(
                    "advance", DT, Vector3.ZERO, {}, true)
                ik.call("set_attack_pose", state)
                rig.call("set_motion", "Idle", DT)
                ik.call("advance_ik", DT, "Idle")
                var goal: Vector3 = leg["last_goal"]
                if not is_finite(goal.x) or not is_finite(goal.y) or (
                        not is_finite(goal.z)):
                    _fail("non-finite foot goal " + id + "/" + kind)
                    return false
                var upper: Node3D = leg["upper"]
                var lower: Node3D = leg["lower"]
                var foot: Node3D = leg["foot"]
                var hip: Vector3 = upper.global_position
                var knee: Vector3 = lower.global_position
                var ankle: Vector3 = foot.global_position
                var segments: float = hip.distance_to(knee) + knee.distance_to(ankle)
                var ratio: float = hip.distance_to(ankle) / maxf(segments, 0.001)
                var t: float = float(state.get("time", 0.0))
                if t >= end_time - 0.035 and t <= end_time + 0.025:
                    if ratio > best_ratio:
                        best_ratio = ratio
                        off_floor_at_peak = (
                            absf(goal.y - IK.FLOOR_Y) > 0.10
                            and absf(ankle.y - hip.y) < 0.10)
                    peak_shift = maxf(peak_shift, goal.distance_to(anchor))
                if not bool(brain.call("is_active")):
                    recovered = true
                    break
            ik.call("clear_attack_pose")
            rig.call("set_motion", "Idle", DT)
            ik.call("advance_ik", DT, "Idle")
            if best_ratio < 0.995:
                _fail(id + "/" + kind + " knee did not fully straighten: "
                    + str(best_ratio))
                return false
            if not off_floor_at_peak:
                _fail(id + "/" + kind
                    + " foot remained ground-clamped during full extension")
                return false
            if peak_shift < 0.30:
                _fail(id + "/" + kind + " attack foot failed to extend")
                return false
            if not recovered or (leg["last_goal"] as Vector3).distance_to(
                    anchor) > 0.10:
                _fail(id + "/" + kind + " did not recover neutral stance")
                return false
    return true

func _check_broken_legs_remain_armed(battle: Node3D) -> bool:
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var player: CharacterBody3D = battle.get("player")
    var boss: Node3D = battle.get("target")
    var parts: Node3D = battle.get("target_parts")
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    for id in ATTACKS.LEG_IDS:
        # Damage the real shin in a continuous fight. The original
        # windup, knockdown and stand-up remain the attack gate.
        battle.set("locked_target_part_id", id)
        var result: Dictionary = battle.call(
            "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
        if not bool(result.get("broken", false)):
            _fail("failed to break " + id + ": " + str(result))
            return false
        if float(parts.call("get_part_integrity", id)) > 0.0:
            _fail("part break gauge unexpectedly remains above zero " + id)
            return false
        var candidates: Dictionary = battle.call("_bittaran_attack_candidates")
        if not candidates.has(id):
            _fail("broken " + id + " was removed from attack candidates")
            return false
        var ready: bool = false
        for tick in range(560):
            player.global_position = boss.global_position + Vector3(0.0, 0.0, 28.0)
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
            if bool(ik.call("locomotion_ready")) and not bool(
                    ik.call("break_reaction_active")):
                ready = true
                break
        if not ready:
            _fail("boss never stood up after breaking " + id)
            return false
        # Drive the REAL AI selector rather than force_start. Isolate the
        # selected foot at zero horizontal distance, including broken ones.
        candidates = battle.call("_bittaran_attack_candidates")
        var sole: Vector3 = candidates[id]
        player.global_position = Vector3(sole.x, 0.0, sole.z)
        brain.set("next_leg_index", ATTACKS.LEG_IDS.find(id))
        brain.set("next_kind_index", 1)
        brain.set("cooldown", 0.0)
        battle.call("_advance_target_motion", DT)
        var current: Dictionary = battle.get("bittaran_attack_frame")
        if str(current.get("id", "")) != id or str(
                current.get("kind", "")) != "kick":
            _fail("broken " + id + " cannot initiate kick: " + str(current))
            return false
        battle.call("_finalize_target_pose", DT)
        brain.call("cancel")
        battle.set("bittaran_attack_frame", {})
        ik.call("clear_attack_pose")
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if ik == null or not bool(ik.get("ready")):
        _fail("real authored Bittaran IK not ready")
        return
    if not _check_straight_strikes(battle):
        return
    if not _check_broken_legs_remain_armed(battle):
        return
    print("GODOT_V382_BITTARAN_STRAIGHT_ATTACKS_PASS: all four kick/sweep "
        + "legs fully extended without floor clamp, recovered smoothly, "
        + "and every shin can automatically kick after real break/recovery")
    quit(0)
