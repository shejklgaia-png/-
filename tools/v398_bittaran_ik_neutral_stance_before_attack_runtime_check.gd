extends SceneTree
## v398: all 12 attacks must first replant BOTH diagonal IK pairs at
## their true Wait positions and world foot orientations. Nothing in
## this stage may advance the authored clip or enable a strike/hitbox.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V398_BITTARAN_ATTACK_STANCE_FAIL: " + why)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if brain == null or ik == null or rig == null or player == null:
        _fail("missing live boss / IK / attack director")
        return
    if IK.LEG_PAIRS.size() != 2 or (
            IK.LEG_PAIRS[0].size() != 2) or (
            IK.LEG_PAIRS[1].size() != 2):
        _fail("missing two independently planted IK diagonal pairs")
        return
    var total: int = 0
    var seen_prepared: int = 0
    for id in ATTACKS.LEG_IDS:
        for kind in ATTACKS.ATTACK_KINDS:
            battle.call("_reset_target_after_respawn")
            battle.set("target_move_enabled", true)
            player.global_position = boss.global_position + Vector3(
                12.0, 0.0, 10.0)
            # An intentionally offset/turned neutral foot position,
            # taken as ACTUAL world toe pose, exercises replant rather
            # than passing trivially from an already correct stance.
            var legs: Array = ik.get("legs")
            var targets: Array[Vector3] = []
            var target_rotations: Array[Quaternion] = []
            for i in range(legs.size()):
                var leg: Dictionary = legs[i]
                var target: Vector3 = ik.call("_home", leg, false)
                targets.append(target)
                var rotation: Quaternion = ik.call("_rotation_home", leg)
                target_rotations.append(rotation)
                leg["anchor"] = target + Vector3(
                    0.24 if i % 2 == 0 else -0.22,
                    0.0, 0.19 if i < 2 else -0.19)
                leg["anchor_rotation"] = (Quaternion(
                    Vector3.UP, deg_to_rad(12.0)) * rotation).normalized()
            rig.call("set_motion", "Idle", DT)
            ik.call("advance_ik", DT, "Idle")
            if not bool(brain.call("force_start_with_stance", id, kind)):
                _fail("unable to queue pre-attack stance: " + id + "/" + kind)
                return
            var stance_frames: int = 0
            var became_ready: bool = false
            var entered_authored: bool = false
            var original_supports: Array[Vector3] = []
            var support_pair: Array = IK.LEG_PAIRS[1]
            for i in support_pair:
                original_supports.append(legs[i]["anchor"])
            for tick in range(110):
                battle.call("_advance_target_motion", DT)
                var frame: Dictionary = battle.get("bittaran_attack_frame")
                var stance: bool = bool(frame.get("stance_prepare", false))
                var elapsed_before: float = float(brain.get("elapsed"))
                battle.call("_finalize_target_pose", DT)
                if stance:
                    if str(frame.get("phase", "")) != "stance" or (
                            bool(frame.get("hit_window", true))) or (
                            bool(frame.get("impact", true))) or (
                            elapsed_before > 0.0000001) or (
                            not str(rig.get("active_authored_attack")).is_empty()):
                        _fail(id + "/" + kind +
                            ": authored attack leaked into IK prep")
                        return
                    stance_frames += 1
                    # The second diagonal remains planted in the first
                    # 0.32s while the first diagonal turns/replants.
                    if stance_frames <= 13:
                        for slot in range(support_pair.size()):
                            var support: Dictionary = legs[support_pair[slot]]
                            if (support["anchor"] as Vector3).distance_to(
                                    original_supports[slot]) > 0.0001:
                                _fail(id + "/" + kind +
                                    ": planted diagonal moved early")
                                return
                    if bool(ik.call("attack_stance_is_ready")):
                        became_ready = true
                        for i in range(legs.size()):
                            var leg: Dictionary = legs[i]
                            if (leg["anchor"] as Vector3).distance_to(
                                    targets[i]) > 0.004:
                                _fail(id + "/" + kind +
                                    ": IK neutral toe target incorrect")
                                return
                            if (leg["anchor_rotation"] as Quaternion).angle_to(
                                    target_rotations[i]) > 0.004:
                                _fail(id + "/" + kind +
                                    ": neutral foot rotation incorrect")
                                return
                elif not frame.is_empty():
                    if stance_frames < 28 or not became_ready:
                        _fail(id + "/" + kind +
                            ": attack began before diagonal IK finished " +
                            str(stance_frames))
                        return
                    if float(frame.get("time", 0.0)) > DT + 0.002 or (
                            str(frame.get("phase", "")) != "windup") or (
                            bool(frame.get("hit_window", true))):
                        _fail(id + "/" + kind +
                            ": authored attack did not restart at t=0")
                        return
                    if str(rig.get("active_authored_attack")) != kind:
                        _fail(id + "/" + kind +
                            ": original authored animation not activated")
                        return
                    if bool(ik.get("attack_stance_active")):
                        _fail(id + "/" + kind +
                            ": IK stance metadata not cleared at handoff")
                        return
                    entered_authored = true
                    break
            if not entered_authored or stance_frames < 35:
                _fail(id + "/" + kind +
                    ": IK stance stage did not complete and hand off")
                return
            # Interrupt during the authored windup. A new preparation
            # may never inherit the previous stepping/target metadata.
            brain.call("cancel")
            ik.call("clear_attack_pose")
            if bool(ik.get("attack_stance_active")):
                _fail("stale IK stance after cancelling " + id)
                return
            seen_prepared += stance_frames
            total += 1
    if total != 12 or seen_prepared < 420:
        _fail("not all twelve attacks completed their IK stance stage")
        return
    print("GODOT_V398_BITTARAN_IK_STANCE_PASS: 12 attacks, two "
        + "diagonal IK stance replants each, orientation & contact "
        + "restored, planted supports fixed, original authored timer "
        + "starts strictly after preparation, cancellation cleared")
    quit(0)
