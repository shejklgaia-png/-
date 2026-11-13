extends SceneTree
## Exercise the real main scene with its live boss part and camera objects;
## validate extracted AUTO, MANUAL, facing and marker behavior independently.
const LOCK = preload("res://scripts/sera_lock_management.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_LOCK_MODULE_FAILED: " + message)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var parts: Node3D = game.get("target_parts")
    var player: CharacterBody3D = game.get("player")
    var boss: Node3D = game.get("target")
    var camera: Camera3D = game.get("camera")
    if parts == null or player == null or boss == null or camera == null:
        _fail("original scene lock dependencies missing")
        return

    var original: String = str(parts.call(
        "select_actor_parallel_lines_part", player.global_position,
        boss.global_position))
    var extracted: String = LOCK.select_auto_part(
        parts, player.global_position, boss.global_position)
    if original != extracted:
        _fail("AUTO line candidate changed")
        return
    game.call("_acquire_stable_camera_part", 0.25, false)
    if str(game.get("locked_target_part_id")) != extracted:
        _fail("AUTO wrapper candidate changed")
        return
    if not bool(game.get("auto_lock_initialized")):
        _fail("AUTO initialization flag missing")
        return

    for part_id in ["", "HEAD", "LEFT_FRONT_LEG", "RIGHT_REAR_LEG"]:
        var aim: Vector3 = boss.global_position
        if not part_id.is_empty():
            if not bool(parts.call("has_part", part_id)):
                continue
            aim = parts.call("get_part_aim_world", part_id)
        var direction: Vector3 = LOCK.target_facing_direction(
            player.global_position, boss.global_position, parts, part_id)
        var expected: Vector3 = Vector3(
            aim.x - player.global_position.x, 0.0,
            aim.z - player.global_position.z)
        if direction.distance_to(expected) > 0.00001:
            _fail("target facing/pitch changed: " + part_id)
            return

    var viewport: Vector2 = root.get_visible_rect().size
    var center: Vector3 = boss.global_position
    var inside: Dictionary = LOCK.reticle_projection(camera, center, viewport)
    if inside["visible"] != (not camera.is_position_behind(center)):
        _fail("marker visibility changed")
        return
    var behind: Dictionary = LOCK.reticle_projection(
        camera, camera.global_position + camera.global_basis.z * 3.0,
        viewport)
    if behind["visible"] or behind["offscreen"]:
        _fail("behind-camera marker became visible")
        return
    var invalid: Dictionary = LOCK.reticle_projection(camera, center, Vector2.ZERO)
    if invalid["visible"]:
        _fail("invalid viewport marker became visible")
        return
    # Force MANUAL mode; compare main's change with independent helper
    # selection, using the exact live boss hitbox and camera projection.
    game.set("auto_lock_enabled", false)
    game.set("manual_part_lock_active", true)
    game.set("locked_target_part_id", "")
    var hitbox: AABB = game.call("_target_hit_aabb")
    var expected_next: String = LOCK.manual_screen_neighbor(
        1, "", viewport, camera, parts, hitbox)
    if not expected_next.is_empty():
        game.call("_switch_lock_screen_direction", 1)
        if str(game.get("locked_target_part_id")) != expected_next:
            _fail("MANUAL right next/edge-wrap changed")
            return
        var previous: String = expected_next
        var expected_left: String = LOCK.manual_screen_neighbor(
            -1, previous, viewport, camera, parts, hitbox)
        game.call("_switch_lock_screen_direction", -1)
        if str(game.get("locked_target_part_id")) != expected_left:
            _fail("MANUAL left next/edge-wrap changed")
            return
    else:
        # No candidate is legitimate in a sparse/occluded live target;
        # the call must still preserve BODY and never create an invalid part.
        game.call("_switch_lock_screen_direction", 1)
        if not str(game.get("locked_target_part_id")).is_empty():
            _fail("MANUAL created nonexistent target")
            return
    print("SERA_LOCK_MODULE_RUNTIME_PASS: live AUTO, MANUAL, facing and reticle")
    quit(0)
