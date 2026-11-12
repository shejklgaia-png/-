extends SceneTree
## Authored Kick_b must turn its Waist exactly once, around the original pivot.
## The v278 runtime test independently covers both kicks' delayed lateral STEP.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V280_KICK_MOTION_RUNTIME_FAILED: " + reason)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var rig: Node3D = game.get("rig")
    if player == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("rig missing")
        return
    game.set("locked_target_part_id", "")
    game.set("target_hp", 500)
    player.position = Vector3(0.0, 0.0, -5.5)
    if not bool(game.call("_start_back_somersault")):
        _fail("Kick_b failed to start")
        return
    if not bool(rig.call("back_somersault_uses_authored_clip")):
        _fail("authored Kick_b was not used")
        return
    var resting_y: float = float(game.get("back_somersault_original_rig_y"))
    var initial_collision_basis: Basis = player.transform.basis
    var waist: Node3D = (rig.get("bones") as Dictionary)[
        "67435cb7-b6af-23e4-10f1-3cd13d8429fa"]
    var source_keys: Array = ((rig.get("animations") as Dictionary)["Kick_b"]["tracks"][
        "67435cb7-b6af-23e4-10f1-3cd13d8429fa"] as Dictionary)["rotation"]
    # The Blockbench Waist itself turns through ~382 degrees. The visible
    # rig must remain unrotated so the same authored flip is never applied
    # twice. Check a frame inside the 125 -> 335 degree segment, where
    # naive shortest-path quaternion SLERP reverses instead of flipping.
    var previous_time: float = 0.0
    for progress in [0.25, 0.40, 0.50, 0.75, 1.0]:
        var wanted_time: float = 0.80 * progress
        game.call("_advance_back_somersault", wanted_time - previous_time)
        previous_time = wanted_time
        rig.call("_process", 0.06)
        var author_euler: Vector3 = rig.call("_value_at",
            source_keys, float(rig.call("get_clip_time")))
        var expected_q: Quaternion = rig.call("_blockbench_rotation", author_euler)
        if absf(waist.quaternion.dot(expected_q)) < 0.9999:
            _fail("Blockbench Waist full turn was lost at " + str(progress))
            return
        if absf(rig.rotation.x) > 0.0001:
            _fail("authored Kick_b was doubled by external rig rotation")
            return
        if absf(rig.position.y - resting_y) > 0.0001:
            _fail("obsolete external pivot correction shifted the authored rig")
            return
        if player.transform.basis.y.dot(initial_collision_basis.y) < 0.999:
            _fail("visual backflip rotated the player collision basis")
            return
    if not bool(game.get("back_somersault_active")):
        _fail("authored final pose was cut off")
        return
    if not bool(rig.call("back_somersault_final_pose_sampled")):
        _fail("authored final pose was not sampled")
        return
    game.call("_advance_back_somersault", 0.016)
    if not bool(game.get("landing_active")):
        _fail("landing did not follow completed flip")
        return
    game.call("_advance_landing", 0.20)
    if bool(game.get("landing_active")):
        _fail("0.2s landing duration changed")
        return
    # Cancel path must reset any fallback rotation without touching the
    # real Blockbench joint and must permit a new kick immediately.
    if not bool(game.call("_start_back_somersault")):
        _fail("Kick_b cannot restart after landing")
        return
    game.call("_advance_back_somersault", 0.20)
    game.call("_cancel_back_somersault")
    if bool(game.get("back_somersault_active")) or absf(rig.rotation.x) > 0.0001:
        _fail("cancel left visual root rotation active")
        return
    if absf(rig.position.y - resting_y) > 0.0001:
        _fail("cancel left root pivot offset active")
        return
    # The first strike may move toward the target, but delayed lateral STEP
    # must not snap that homing displacement back to its starting position.
    var target: Node3D = game.get("target")
    target.position = Vector3.ZERO
    player.position = Vector3(0.0, 0.0, 3.0)
    game.set("target_hp", 500)
    game.set("step_kick_side_request", 1)
    if not bool(game.call("_start_omni_step", Vector2.RIGHT)):
        _fail("Kick_r failed after somersault cancel")
        return
    game.set("step_kick_side_request", 0)
    var first_distance: float = player.position.distance_to(target.position)
    game.call("_advance_side_step", 0.04)
    var after_first_homing: float = player.position.distance_to(target.position)
    game.call("_advance_side_step", 0.04)
    var after_second_homing: float = player.position.distance_to(target.position)
    if after_first_homing >= first_distance - 0.01:
        _fail("first-strike Bash homing stopped before second windup")
        return
    if after_second_homing > after_first_homing + 0.03:
        _fail("delayed STEP anchor undid first-strike homing")
        return
    game.call("_finish_side_step", false)
    print("GODOT_V280_KICK_MOTION_PASS: delayed kick travel, preserved homing, continuous authored Waist turn without doubled rig rotation")
    quit(0)
