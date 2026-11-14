extends SceneTree
## v379: point-blank player crossings cannot flip HEAD yaw between
## +/-48 degrees; a new clip never blends last frame's procedural aim
## into the already authored HEAD quaternion; stop latch is stable.
const BOSS = preload("res://scripts/bittaran_battle.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V379_NEAR_HEAD_JITTER_FAIL: " + message)
    quit(1)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var head: Node3D = battle.get("bittaran_head")
    var player: CharacterBody3D = battle.get("player")
    var rig: Node3D = battle.get("bittaran_rig")
    if head == null or player == null or rig == null:
        _fail("missing HEAD, player or rig")
        return
    if BOSS.HEAD_AIM_MIN_FORWARD_METERS < 0.60 or (
            BOSS.HEAD_AIM_HOLD_RADIUS_METERS < 0.40):
        _fail("point-blank look-at discontinuity guard missing")
        return
    var parent: Node3D = head.get_parent() as Node3D
    if parent == null:
        _fail("no HEAD parent")
        return
    # First establish an off-center, nonzero target direction.
    player.global_position = parent.to_global(
        head.position + Vector3(1.2, 0.0, -3.0)) - Vector3.UP * 0.9
    battle.call("_update_head_look_target", DT)
    var base: float = float(battle.get("head_look_filtered_yaw"))
    var max_delta: float = 0.0
    # Rapidly alternate around the nose and even cross BEHIND its
    # local -Z half-plane. The head must not react to +/- centimetres.
    for frame in range(120):
        var lateral: float = (0.03 if frame % 2 == 0 else -0.03)
        player.global_position = parent.to_global(
            head.position + Vector3(lateral, 0.0, 0.06)) - Vector3.UP * 0.9
        battle.call("_update_head_look_target", DT)
        var actual: float = float(battle.get("head_look_filtered_yaw"))
        max_delta = maxf(max_delta, absf(actual - base))
    if max_delta > 0.0001:
        _fail("player crossing just below HEAD alternated look-at yaw")
        return
    # A nearby, but not directly underhead, target is followed using
    # temporal smoothing instead of an instant left/right sign flip.
    var previous: float = float(battle.get("head_look_filtered_yaw"))
    var peak_frame_step: float = 0.0
    for frame in range(120):
        var lateral: float = (0.65 if frame % 2 == 0 else -0.65)
        player.global_position = parent.to_global(
            head.position + Vector3(lateral, 0.0, 0.12)) - Vector3.UP * 0.9
        battle.call("_update_head_look_target", DT)
        var actual: float = float(battle.get("head_look_filtered_yaw"))
        peak_frame_step = maxf(peak_frame_step, absf(actual - previous))
        previous = actual
    if peak_frame_step > deg_to_rad(5.0):
        _fail("HEAD desired yaw flickered at nearby alternating target")
        return
    # Verify HEAD is not double rotated when authored Turn begins.
    rig.call("apply_pose", "Idle", 0.0)
    var clean: Quaternion = head.quaternion
    var additive: float = 0.52
    head.quaternion = (clean *
        Quaternion(Vector3.UP, additive)).normalized()
    rig.call("set_external_head_yaw", additive)
    rig.call("set_motion", "Turn", DT)
    var head_uid: String = ""
    var bones: Dictionary = rig.get("bones")
    for uid in bones:
        if (bones[uid] as Node3D) == head:
            head_uid = str(uid)
            break
    if head_uid.is_empty():
        _fail("Head is not tracked in the rig")
        return
    var captured: Quaternion = rig.get("blend_from")[head_uid]
    if captured.angle_to(clean) > 0.001:
        _fail("HEAD blend source contains a second procedural look yaw")
        return
    # Collision latch may NOT release on one frame of leg jitter.
    battle.set("head_collision_filtered_depth", 0.30)
    battle.set("head_collision_blocked", true)
    battle.set("head_collision_release_elapsed", 0.0)
    for depth in [0.296, 0.282, 0.294, 0.284, 0.296]:
        var speed: float = float(battle.call(
            "_head_collision_motion_scale", depth, depth, DT))
        if speed > 0.00001:
            _fail("collision latch flickered ON/OFF near 30cm")
            return
    var escaped: float = float(battle.call(
        "_head_collision_motion_scale", 0.34, 0.30, DT))
    if escaped < 0.39:
        _fail("the player cannot rotate HEAD out of collision")
        return
    if absf(BOSS.HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.30) > 0.00001:
        _fail("30cm stop rule was changed")
        return
    print("GODOT_V379_NEAR_HEAD_NO_JITTER_PASS: no near-HEAD atan2 "
        + "sign flip, stable desired yaw, authored blend excludes "
        + "procedural aim, no collision stop flicker")
    quit(0)
