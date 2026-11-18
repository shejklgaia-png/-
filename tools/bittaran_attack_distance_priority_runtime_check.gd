extends SceneTree
## v453: prefer a grounded STOMP near SERA, and a front KICK only
## after meaningful separation; verify genuine 3-step AI decisions.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const AI = preload("res://scripts/bittaran_ai.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("BITTARAN_DISTANCE_PRIORITY_FAIL " + why)
    quit(1)

func _polar(distance: float, angle_deg: float) -> Vector3:
    return Vector3(
        sin(deg_to_rad(angle_deg)) * distance, 0.0,
        cos(deg_to_rad(angle_deg)) * distance)

func _verify_live_first(start_distance: float, expected: String) -> bool:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    scene.set("target_move_enabled", true)
    scene.set("player_hp", 99999.0)
    var boss: Node3D = scene.get("target")
    var player: CharacterBody3D = scene.get("player")
    var ik: RefCounted = scene.get("bittaran_foot_ik")
    if boss == null or player == null or ik == null:
        _fail("live battle unavailable")
        return false
    boss.rotation.y = 0.0
    player.global_position = boss.global_position + Vector3(
        0.0, 0.0, start_distance)
    var found: String = ""
    var found_steps: int = -1
    var at_distance: float = INF
    for tick in range(1700):
        scene.set("player_hp", 99999.0)
        scene.call("_advance_target_motion", DT)
        var frame: Dictionary = scene.get("bittaran_attack_frame")
        if not frame.is_empty() and str(frame.get("phase", "")) == "entry":
            found = str(frame.get("kind", ""))
            found_steps = int(ik.call("source_completed_walk_steps"))
            at_distance = Vector2(
                boss.global_position.x - player.global_position.x,
                boss.global_position.z - player.global_position.z).length()
            break
        scene.call("_finalize_target_pose", DT)
    scene.queue_free()
    print("DISTANCE_PRIORITY_LIVE start=", start_distance,
        " first=", found, " steps=", found_steps,
        " attack_range=", at_distance)
    if found != expected or found_steps < 3:
        _fail("real 3-step attack differed from distance policy " +
            str([start_distance, expected, found, found_steps, at_distance]))
        return false
    if expected == "stomp" and at_distance > ATTACKS.STOMP_RANGE_METERS + 0.001:
        _fail("STOMP launched outside close-range band")
        return false
    if expected == "kick" and (at_distance < ATTACKS.KICK_MIN_RANGE_METERS - 0.001
            or at_distance > ATTACKS.KICK_RANGE_METERS + 0.001):
        _fail("KICK launched outside separated midrange band")
        return false
    return true

func _run() -> void:
    if absf(ATTACKS.STOMP_RANGE_METERS - 3.0) > 0.0001 or (
            absf(ATTACKS.KICK_MIN_RANGE_METERS - 3.75) > 0.0001):
        _fail("attack distances diverged from the approved v453 bands")
        return
    var ai: RefCounted = AI.new()
    if ai == null:
        _fail("movement AI unavailable")
        return
    # A genuine gap keeps KICK from firing at point-blank range.
    for row in [
            [0.9, 0.0, "stomp"],
            [2.5, 0.0, "stomp"],
            [2.99, 34.0, "stomp"],
            [3.0, 0.0, "stomp"],
            [3.1, 0.0, "sweep"],
            [3.74, 0.0, "sweep"],
            [3.75, 0.0, "kick"],
            [4.35, 0.0, "kick"],
            [5.15, 35.0, "kick"],
            [4.35, 60.0, "sweep"],
            [4.35, 150.0, "sweep"],
            [4.35, 178.0, ""],
            [5.16, 0.0, "sweep"],
            [7.11, 0.0, ""]]:
        var got: String = ATTACKS.new().call(
            "_choose_kind", _polar(float(row[0]), float(row[1])),
            Vector3.ZERO, 0.0)
        if got != str(row[2]):
            _fail("distance/angle selector " + str([row, got]))
            return
    # Both cases must be produced by the autonomous battle director,
    # without force_start() or bypassing gait/stance/replant logic.
    if not _verify_live_first(2.50, "stomp"):
        return
    if not _verify_live_first(4.35, "kick"):
        return
    print("GODOT_BITTARAN_DISTANCE_PRIORITY_PASS ",
        "stomp_close=true kick_midrange_only=true ",
        "real_three_steps=true sector_boundaries=14")
    quit(0)
