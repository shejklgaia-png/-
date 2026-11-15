extends SceneTree
## v390 tempo plus v392: HEAD pitches toward the player without side
## roll despite an independently pitched/rolled articulated BODY.
## The authored outward swing spends its last 0.70 real seconds at 0.2x.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V390_HEAD_HEIGHT_SWEEP_WINDUP_FAIL: " + reason)
    quit(1)


func _roll_free(head: Node3D, label: String) -> bool:
    # Pitch may now point DOWN, but the short-face left/right axis must
    # stay horizontal. Pitch/yaw are composed without any accidental roll.
    var right: Vector3 = head.global_basis.x.normalized()
    if absf(right.y) > 0.025:
        _fail(label + ": head acquired unwanted side roll: " + str(right))
        return false
    return true


func _check_head_height(battle: Node3D) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", false)
    var head: Node3D = battle.get("bittaran_head")
    var player: CharacterBody3D = battle.get("player")
    var parent: Node3D = head.get_parent()
    var home: Vector3 = battle.get("boss_head_rest_local_position")
    var base_world: Vector3 = parent.to_global(home)
    var forward: Vector3 = -parent.global_basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var offsets: Array[float] = []
    for y_offset in [2.0, -2.0, 0.0]:
        # These are neck-pivot-relative directions; player aim is at
        # character centre (player root + 0.9m).
        player.global_position = base_world + forward * 7.0 \
            + Vector3.UP * (y_offset - 0.9)
        for i in range(85):
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
            if not _roll_free(head, "head pitch " + str(i)):
                return false
        var pitch: float = float(battle.get("boss_head_pitch"))
        if absf(pitch - atan2(y_offset, 7.0)) > 0.18:
            _fail("HEAD did not look at vertical player position: "
                + str([y_offset, pitch]))
            return false
        if absf(float(battle.get("head_vertical_offset_world"))) > 0.025:
            _fail("HEAD translated instead of pitching toward player")
            return false
        var toward: Vector3 = (
            player.global_position + Vector3.UP * 0.9
            - head.global_position).normalized()
        var nose: Vector3 = -head.global_basis.z.normalized()
        if nose.dot(toward) < 0.70:
            _fail("short front face did not aim at player elevation")
            return false
        offsets.append(pitch)
    if not (offsets[0] > offsets[2] + 0.12 and
            offsets[1] < offsets[2] - 0.12):
        _fail("HEAD failed to pitch up/down distinctly " + str(offsets))
        return false
    # HEAD must remain roll-free during an authored SWEEP whose BODY
    # pitches/rolls independently, with normal live yaw still active.
    battle.set("target_move_enabled", true)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var torso: Node3D = battle.get("bittaran_rig").find_child(
        "Body", true, false) as Node3D
    if not bool(brain.call("force_start", "leg_fl", "sweep")):
        _fail("cannot start sweep for head roll test")
        return false
    var saw_body_pitch: bool = false
    var saw_head_yaw: bool = false
    for tick in range(145):
        player.global_position = battle.get("target").global_position + (
            Vector3(4.5 if tick < 55 else -4.5, 0.25, 7.0))
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if not _roll_free(head, "sweep " + str(tick)):
            return false
        if absf(torso.global_basis.y.normalized().dot(Vector3.UP)) < 0.99:
            saw_body_pitch = true
        if absf(float(battle.get("boss_head_yaw"))) > 0.05:
            saw_head_yaw = true
    if not saw_body_pitch or not saw_head_yaw:
        _fail("did not exercise pitched BODY and live HEAD yaw during sweep")
        return false
    return true

func _check_outbound_tempo() -> bool:
    if absf(BRAIN.SWEEP_SLOW_SPEED - 0.2) > 0.000001 or absf(
            BRAIN.SWEEP_SLOW_REAL_SECONDS - 0.70) > 0.000001:
        _fail("slow interval not 0.20x for 0.70 real seconds")
        return false
    if absf(BRAIN.SWEEP_STRIKE_SECONDS - 2.06) > 0.00001:
        _fail("wall strike not exactly 2.06 seconds")
        return false
    var samples: Array = [
        [0.00, 0.00, 1.0],
        [0.36, 0.36, 0.2],
        [0.71, 0.43, 0.2],
        [1.06, 0.50, 1.0],
        [1.56, 1.00, 1.0],
        [2.06, 1.50, 1.0]
    ]
    var brain: RefCounted = BRAIN.new()
    for row in samples:
        if not bool(brain.call("force_start", "leg_fl", "sweep")):
            _fail("cannot force sweep at " + str(row[0]))
            return false
        brain.set("elapsed", BRAIN.SWEEP_WINDUP_SECONDS + float(row[0]))
        var frame: Dictionary = brain.call(
            "advance", 0.0, Vector3.ZERO, {}, true)
        if frame.is_empty():
            _fail("empty sweep frame at " + str(row[0]))
            return false
        if absf(float(frame.get("authored_time")) - float(row[1])) > 0.0001:
            _fail("authored time mismatch at " + str(row[0]) + " "
                + str(frame.get("authored_time")) + " vs " + str(row[1]))
            return false
        if absf(float(frame.get("authored_playback_speed")) - float(
                row[2])) > 0.0001:
            _fail("speed mismatch at " + str(row[0]))
            return false
    return true


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _check_head_height(battle):
        return
    if not _check_outbound_tempo():
        return
    print("GODOT_V390_HEAD_HEIGHT_SWEEP_WINDUP_PASS: HEAD world yaw/pitch "
        + "follows SERA elevation without side roll or neck translation; "
        + "authored BODY roll and SWEEP final 0.70s at 0.20x; source "
        + "turnaround t=0.50 reached at wall t=1.06")
    quit(0)
