extends SceneTree
## v293: AUTO camera orbit, intentional BODY lock, hysteresis, broken limb.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V293_AUTO_ORBIT_CORE_LOCK_FAILED: " + reason)
    quit(1)


func _place_camera(parts: Node3D, camera: Camera3D, angle_degrees: float) -> void:
    var angle: float = deg_to_rad(angle_degrees)
    camera.global_position = parts.to_global(Vector3(
        -sin(angle) * 15.0, 4.0, cos(angle) * 15.0))
    camera.look_at(parts.global_position, Vector3.UP)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("missing combat scene")
        return
    var game: Node3D = packed.instantiate()
    # Historic geometry test: place SERA at the sampled synthetic ray origin.
    # The camera may still aim the test ray, but AUTO reads only SERA.
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var parts: Node3D = game.get("target_parts")
    var camera: Camera3D = game.get("camera")
    if parts == null or camera == null:
        _fail("missing target parts or camera")
        return

    var expected: Array[String] = [
        "head", "", "leg_fl", "", "leg_rl", "",
        "leg_rr", "", "leg_fr", ""
    ]
    for i in range(expected.size()):
        _place_camera(parts, camera, float(i) * 36.0)
        var actual: String = str(parts.call("select_camera_orbit_part", camera))
        if actual != expected[i]:
            _fail("orbit sector %d: expected '%s', got '%s'" % [
                i, expected[i], actual])
            return
    _place_camera(parts, camera, 360.0)
    if str(parts.call("select_camera_orbit_part", camera)) != "head":
        _fail("full orbit did not return to HEAD")
        return

    # Historical orbit API still exists; AUTO now uses actual camera line
    # intersection against two parallel meshes, with stable BODY confirmation.
    var target: Node3D = game.get("target")
    if target == null:
        _fail("missing target center")
        return
    game.set("auto_lock_enabled", true)
    game.set("manual_part_lock_active", false)
    game.set("auto_lock_initialized", false)
    game.set("locked_target_part_id", "")
    camera.global_position = target.global_position + Vector3(0.0,-2.0,10.0)
    camera.look_at(target.global_position, Vector3.UP)
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part", 0.016, false)
    if not bool(game.get("auto_lock_initialized")) or str(game.get("locked_target_part_id")) != "head":
        _fail("initial visible HEAD was not acquired")
        return
    camera.global_position = target.global_position + Vector3(0.0,0.0,-12.0)
    camera.look_at(target.global_position, Vector3.UP)
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part", 0.016, false)
    if str(game.get("locked_target_part_id")) != "head":
        _fail("dual-ray loss switched HEAD immediately")
        return
    game.call("_acquire_stable_camera_part", 0.23, false)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("sustained BODY candidate did not replace off-ray HEAD")
        return
    camera.global_position = target.global_position + Vector3(0.0,-2.0,10.0)
    camera.look_at(target.global_position, Vector3.UP)
    var model: Dictionary = parts.get("parts")
    var head: Dictionary = model["head"]
    head["broken"] = true
    player.global_position = camera.global_position
    game.call("_acquire_stable_camera_part", 0.016, false)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("broken HEAD was reselected instead of BODY")
        return
    head["broken"] = false

    print("GODOT_V293_AUTO_ORBIT_CORE_LOCK_PASS")
    quit(0)
