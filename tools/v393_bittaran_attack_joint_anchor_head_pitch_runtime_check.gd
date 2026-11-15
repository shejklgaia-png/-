extends SceneTree
## v393: repeated world-space contact corrections must never alter the
## Blockbench parent-local joint origins in the NEXT physics animation.
## A pitched head may not freely rotate deeper into a real 20cm shin.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V393_BITTARAN_ANCHOR_HEAD_FAIL: " + reason)
    quit(1)

func _anchor_error(rig: Node3D) -> float:
    var error: float = 0.0
    var bones: Dictionary = rig.get("bones")
    var bind: Dictionary = rig.get("bind_positions")
    for key in bones:
        var node: Node3D = bones[key]
        if node.name == "Head":
            continue
        error = maxf(error, node.position.distance_to(bind[key]))
    return error

func _check_12_attack_pivots(battle: Node3D) -> bool:
    var rig: Node3D = battle.get("bittaran_rig")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var player: CharacterBody3D = battle.get("player")
    var boss: Node3D = battle.get("target")
    for cycle in range(2):
        for id in BRAIN.LEG_IDS:
            for kind in BRAIN.ATTACK_KINDS:
                battle.call("_reset_target_after_respawn")
                battle.set("target_move_enabled", true)
                if not bool(brain.call("force_start", id, kind)):
                    _fail("cannot start " + id + "/" + kind)
                    return false
                var saw_frame: bool = false
                for tick in range(235):
                    # Retreat outside every active strike hitbox after
                    # the windup. This is a joint-integrity regression,
                    # not an HP/KO test: a KO would cancel later rounds.
                    var dodge_tick: int = (76 if kind == "stomp" else 43)
                    var player_offset: Vector3 = (
                        Vector3(15.0, 0.0, 16.0) if tick >= dodge_tick
                        else Vector3(2.4 if tick < 35 else -3.2, 0, 7.0))
                    player.global_position = boss.global_position + player_offset
                    battle.call("_advance_target_motion", DT)
                    # This runs AFTER the base Idle clip has restored all
                    # joint positions, but BEFORE new IK makes a temporary
                    # one-frame end-effector adjustment.
                    var error: float = _anchor_error(rig)
                    if error > 0.00005:
                        _fail(id + "/" + kind + " cycle=" + str(cycle)
                            + " frame=" + str(tick)
                            + " local joint shifted by " + str(error))
                        return false
                    battle.call("_finalize_target_pose", DT)
                    if not (battle.get("bittaran_attack_frame") as Dictionary).is_empty():
                        saw_frame = true
                    if saw_frame and (
                            battle.get("bittaran_attack_frame") as Dictionary).is_empty():
                        break
                if not saw_frame:
                    _fail(id + "/" + kind + " never produced an attack frame")
                    return false
    # Recreate a previous-frame world translation directly: the next
    # sampled clip MUST restore the immutable local pivot exactly.
    var foot: Node3D = rig.find_child("FrontFoot_L", true, false)
    foot.global_position += Vector3(0.16, 0.21, -0.12)
    if _anchor_error(rig) < 0.05:
        _fail("synthetic prior-frame foot translation was not detected")
        return false
    rig.call("apply_pose", "Idle", 0.0)
    if _anchor_error(rig) > 0.00001:
        _fail("Idle clip did not restore source foot origin")
        return false
    return true

func _check_head_pitch_collision(battle: Node3D) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", false)
    var rig: Node3D = battle.get("bittaran_rig")
    var player: CharacterBody3D = battle.get("player")
    var head: Node3D = battle.get("bittaran_head")
    var parts: Node3D = battle.get("target_parts")
    # The new pitch limiter must work independently from YAW. Probe
    # possible head poses in the real scene, where some head/leg meshes
    # intentionally overlap at acute angles, rather than a mock sphere.
    battle.call("_advance_target_motion", DT)
    battle.call("_finalize_target_pose", DT)
    var base: Quaternion = battle.call("_head_level_local_base_pose")
    var original: Quaternion = head.quaternion
    var found_closing_pitch: bool = false
    for yaw_deg in [-75.0, -40.0, 0.0, 40.0, 75.0]:
        if found_closing_pitch:
            break
        for pitch_deg in [-65.0, -45.0, -25.0, 20.0, 35.0]:
            var yaw: float = deg_to_rad(yaw_deg)
            var prior_pitch: float = 0.0
            var proposed_pitch: float = deg_to_rad(pitch_deg)
            var before: float = float(battle.call(
                "_head_penetration_depth", base, yaw, prior_pitch))
            var intended: float = float(battle.call(
                "_head_penetration_depth", base, yaw, proposed_pitch))
            var limited: float = float(battle.call(
                "_head_limit_pitch_to_10cm", base, prior_pitch,
                proposed_pitch, yaw, before))
            var after: float = float(battle.call(
                "_head_penetration_depth", base, yaw, limited))
            if intended > before + 0.03:
                found_closing_pitch = true
                if after > maxf(before, 0.20) + 0.004:
                    _fail("pitch advanced into shin: "
                        + str([before, intended, after,
                            pitch_deg, rad_to_deg(limited)]))
                    return false
    head.quaternion = original
    if not found_closing_pitch:
        _fail("no closing head pitch angle was exercised")
        return false
    # The normal up/down follow must not accumulate global neck offsets
    # when no moving shin forces a collision clearance.
    var previous_local: Vector3 = head.position
    player.global_position = head.global_position + (
        -head.global_basis.z.normalized() * 5.0) + Vector3.DOWN * 2.0
    for tick in range(110):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if not head.position.is_finite():
            _fail("head neck position became non-finite")
            return false
        var right: Vector3 = head.global_basis.x.normalized()
        if absf(right.y) > 0.06:
            _fail("pitched head acquired unwanted roll")
            return false
    var depths: Dictionary = parts.call("get_head_leg_penetration_depths")
    var measured: float = 0.0
    for value in depths.values():
        measured = maxf(measured, float(value))
    if measured > 0.225:
        _fail("head buried through shin after pitch follow: "
            + str(measured))
        return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _check_12_attack_pivots(battle):
        return
    if not _check_head_pitch_collision(battle):
        return
    print("GODOT_V393_BITTARAN_ANCHOR_HEAD_PASS: 24 repeated authored "
        + "attacks preserve all 13 local pivots; rotated foot contact "
        + "does not drift; independent pitch-shin depth is limited and "
        + "head remains roll-free")
    quit(0)
