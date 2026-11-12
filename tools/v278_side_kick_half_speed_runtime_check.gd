extends SceneTree
## Actual main-scene and rig test: 50% playback, delayed travel, both hit keys.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V278_SLOW_KICK_RUNTIME_FAILED: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("cannot load main scene")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if player == null or target == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("actors or authored rig unavailable")
        return
    target.position = Vector3.ZERO
    player.position = Vector3(0.0, 0.0, 9.0)
    # Disable target damage to keep Bash auto-homing from altering displacement.
    # Hit-event mask still advances on original authored extension frames.
    game.set("target_hp", 0)
    # Use the same flick for a plain STEP and both kicks.
    if not bool(game.call("_start_omni_step", Vector2.RIGHT)):
        _fail("baseline STEP was not accepted")
        return
    var baseline_duration: float = float(game.get("step_duration_current"))
    var baseline_distance: float = float(game.get("step_arc_length"))
    var baseline_speed: float = float(game.get("step_speed_current"))
    game.call("_finish_side_step", false)
    for side in [1, -1]:
        player.position = Vector3(0.0, 0.0, 9.0)
        game.set("step_kick_side_request", side)
        if not bool(game.call("_start_omni_step", Vector2.RIGHT)):
            _fail("side kick was not accepted")
            return
        game.set("step_kick_side_request", 0)
        var clip: String = "Kick_r" if side > 0 else "Kick_l"
        if str(rig.get("current_clip")) != clip:
            _fail("incorrect clip for side " + str(side))
            return
        var duration: float = float(game.get("step_duration_current"))
        if absf(duration - 2.0 * baseline_duration) > 0.0001:
            _fail("kick action did not become 2x longer")
            return
        if absf(float(game.get("step_arc_length")) - baseline_distance) > 0.0001:
            _fail("kick changed step distance")
            return
        if absf(float(game.get("step_speed_current")) - baseline_speed) > 0.0001:
            _fail("kick changed step speed")
            return
        if absf(float(rig.get("side_kick_playback_scale")) - (1.0 / duration)) > 0.0001:
            _fail("authored 1s clip was not retimed to full 2x action")
            return
        var start: Vector3 = player.position
        var flat_path: Vector2 = game.get("step_linear_offset")
        var end: Vector3 = start + Vector3(flat_path.x, 0.0, flat_path.y)
        game.call("_advance_side_step", duration * 0.249)
        if player.position.distance_to(start) > 0.015:
            _fail("kick moved sideways before first impact")
            return
        if int(game.get("side_kick_hit_mask")) != 0:
            _fail("first foot hit before slow 25% key")
            return
        game.call("_advance_side_step", duration * 0.002)
        if int(game.get("side_kick_hit_mask")) != 1:
            _fail("first delayed kick key was skipped")
            return
        if player.position.distance_to(start) > 0.015:
            _fail("kick moved sideways during first strike")
            return
        game.call("_advance_side_step", duration * 0.249)
        if not bool(game.get("step_active")):
            _fail("the slowed kick stopped at old STEP finish")
            return
        var second_windup: float = 0.33333 if side > 0 else 0.41667
        var halfway_travel: float = (0.5 - second_windup) * 2.0
        var halfway_point: Vector3 = start + Vector3(flat_path.x, 0.0, flat_path.y) * halfway_travel
        if player.position.distance_to(halfway_point) > 0.035:
            _fail("lateral travel was not aligned with second windup")
            return
        # Realtime skeleton sampling follows the same normalized action time.
        rig.call("_process", duration * 0.5)
        if absf(float(rig.call("get_clip_time")) - 0.5) > 0.016:
            _fail("authored clip not at midpoint at half action duration")
            return
        game.call("_advance_side_step", duration * 0.085)
        if int(game.get("side_kick_hit_mask")) != 3:
            _fail("second foot contact did not align with slow 58.3% key")
            return
        var second_hit_travel: float = (0.585 - second_windup) * 2.0
        var second_hit_point: Vector3 = start + Vector3(flat_path.x, 0.0, flat_path.y) * second_hit_travel
        if player.position.distance_to(second_hit_point) > 0.035:
            _fail("second impact interrupted delayed lateral travel")
            return
        game.call("_advance_side_step", duration * 0.415)
        if bool(game.get("step_active")):
            _fail("kick did not finish at doubled duration")
            return
        if player.position.distance_to(end) > 0.035:
            _fail("kick did not finish full STEP distance after second windup")
            return
    print("GODOT_V278_SIDE_KICK_HALF_SPEED_PASS: Kick_l/r 2x, travel starts at second windup, keyed hits")
    quit(0)
