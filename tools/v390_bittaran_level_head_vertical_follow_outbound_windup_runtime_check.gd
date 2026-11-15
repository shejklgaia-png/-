extends SceneTree
## v390 regression: real articulated BODY pitches while HEAD remains
## world-horizontal and SERA's Y motion moves HEAD (not pitches it).
## The authored outward swing spends its last 0.70 real seconds at 0.2x.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V390_HEAD_HEIGHT_SWEEP_WINDUP_FAIL: " + reason)
    quit(1)


func _is_level(head: Node3D, label: String) -> bool:
    var vertical: Vector3 = head.global_basis.y.normalized()
    if vertical.dot(Vector3.UP) < 0.9995:
        _fail(label + ": HEAD is tilted, global up=" + str(vertical))
        return false
    return true


func _check_head_height(battle: Node3D) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", false)
    var head: Node3D = battle.get("bittaran_head")
    var player: CharacterBody3D = battle.get("player")
    var parent: Node3D = head.get_parent()
    var home: Vector3 = battle.get("boss_head_rest_local_position")
    var original_y: float = float(battle.get("head_player_rest_world_y"))
    var base_world: Vector3 = parent.to_global(home)
    for t in range(35):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if not _is_level(head, "idle " + str(t)):
            return false
    var positions: Array[float] = []
    var targets: Array[float] = [0.45, -0.35, 0.0]
    for desired_height in targets:
        player.global_position.y = original_y + desired_height
        for i in range(95):
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
            if not _is_level(head, "vertical tracking " + str(i)):
                return false
        var offset: float = float(
            battle.get("head_vertical_offset_world"))
        if absf(offset - desired_height) > 0.025:
            _fail("head Y did not follow player, got " + str(offset)
                + " expected " + str(desired_height))
            return false
        var rest_world: Vector3 = parent.to_global(home)
        if absf(head.global_position.y - rest_world.y - offset) > 0.005:
            _fail("HEAD Y offset was not applied along WORLD UP")
            return false
        var delta: Vector3 = head.global_position - rest_world
        if Vector2(delta.x, delta.z).length() > 0.005:
            _fail("vertical tracking shifted HEAD horizontally")
            return false
        positions.append(offset)
    if not (positions[0] > 0.40 and positions[1] < -0.30 and
            absf(positions[2]) < 0.025):
        _fail("head did not follow up, down, return in order")
        return false
    # Check the independent head controller while the BODY is in a
    # low authored SWEEP pose and turns under the head.
    battle.set("target_move_enabled", true)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var torso: Node3D = battle.get("bittaran_rig").find_child(
        "Body", true, false) as Node3D
    if not bool(brain.call("force_start", "leg_fl", "sweep")):
        _fail("cannot start sweep for head-level collision test")
        return false
    var saw_body_pitch: bool = false
    var saw_head_yaw: bool = false
    for tick in range(145):
        player.global_position = battle.get("target").global_position + (
            Vector3(4.5 if tick < 55 else -4.5, original_y + 0.25, 7.0))
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if not _is_level(head, "sweep " + str(tick)):
            return false
        if absf(torso.global_basis.y.normalized().dot(Vector3.UP)) < 0.99:
            saw_body_pitch = true
        if absf(float(battle.get("boss_head_yaw"))) > 0.05:
            saw_head_yaw = true
    if not saw_body_pitch or not saw_head_yaw:
        _fail("did not exercise pitched BODY and live yaw during sweep")
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
    print("GODOT_V390_HEAD_HEIGHT_SWEEP_WINDUP_PASS: upright/low-pose "
        + "HEAD gravity-level, up/down ±0.45m SERA elevation follows "
        + "without horizontal drift, yaw independent during authored "
        + "sweep and outbound final 0.70s plays at 0.20x, source "
        + "turnaround t=0.50 reached at wall t=1.06")
    quit(0)
