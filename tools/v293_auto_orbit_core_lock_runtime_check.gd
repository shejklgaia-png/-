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
    root.add_child(game)
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

    # First acquisition is immediate; ordinary sector transitions require
    # continuous candidate selection for at least 0.22 seconds.
    game.set("auto_lock_enabled", true)
    game.set("manual_part_lock_active", false)
    game.set("auto_lock_initialized", false)
    game.set("locked_target_part_id", "")
    _place_camera(parts, camera, 0.0)
    game.call("_acquire_stable_camera_part", 0.016, false)
    if not bool(game.get("auto_lock_initialized")) or str(game.get("locked_target_part_id")) != "head":
        _fail("initial AUTO head acquisition failed")
        return
    _place_camera(parts, camera, 36.0)
    game.call("_acquire_stable_camera_part", 0.016, false)
    game.call("_acquire_stable_camera_part", 0.10, false)
    if str(game.get("locked_target_part_id")) != "head":
        _fail("HEAD switched prematurely to BODY")
        return
    game.call("_acquire_stable_camera_part", 0.13, false)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("AUTO cannot transition into BODY")
        return
    _place_camera(parts, camera, 72.0)
    game.call("_acquire_stable_camera_part", 0.016, false)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("BODY bypassed hysteresis as an uninitialized lock")
        return
    game.call("_acquire_stable_camera_part", 0.23, false)
    if str(game.get("locked_target_part_id")) != "leg_fl":
        _fail("BODY cannot switch to FRONT LEFT after confirmation")
        return

    var model: Dictionary = parts.get("parts")
    var front_left: Dictionary = model["leg_fl"]
    front_left["broken"] = true
    _place_camera(parts, camera, 72.0)
    if not str(parts.call("select_camera_orbit_part", camera)).is_empty():
        _fail("broken FRONT LEFT did not fall back to BODY")
        return
    game.call("_acquire_stable_camera_part", 0.016, true)
    if not str(game.get("locked_target_part_id")).is_empty():
        _fail("broken target did not immediately recover to BODY")
        return
    print("GODOT_V293_AUTO_ORBIT_CORE_LOCK_PASS")
    quit(0)
