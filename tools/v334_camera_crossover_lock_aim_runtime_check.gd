extends SceneTree
## Real scene: screen-relative crossing, mirror interpolation and exact 3D
## marker->torso input heading for BODY, HEAD and low leg parts.
const CAM_MATH = preload("res://scripts/sera_camera_math.gd")
const FLICK = preload("res://scripts/flick_direction_policy.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("V334_CROSSING_FAILED: " + message)
    quit(1)
func _run() -> void:
    var game: Node3D = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var boss: Node3D = game.get("target")
    var cam: Camera3D = game.get("camera")
    var ui: Control = game.get("touch_ui")
    if player == null or boss == null or cam == null or ui == null:
        _fail("real camera, target, player and controller unavailable")
        return
    var screen_width: float = game.get_viewport().get_visible_rect().size.x
    var dead: float = screen_width * 0.025
    if CAM_MATH.screen_side_after_crossing(1, 330.0, 320.0, dead) != 1 \
            or CAM_MATH.screen_side_after_crossing(1, 290.0, 320.0, dead) != -1 \
            or CAM_MATH.screen_side_after_crossing(-1, 320.0, 315.0, dead) != -1 \
            or CAM_MATH.screen_side_after_crossing(-1, 355.0, 320.0, dead) != 1:
        _fail("side crossing hysteresis does not compare with target X")
        return
    var mirror: float = 1.0
    var previous: float = mirror
    for frame in range(30):
        mirror = CAM_MATH.smooth_shoulder_mirror(mirror, -1, 1.0/60.0, 7.0)
        if mirror >= previous or mirror < -1.00001:
            _fail("mirror did not transition continuously toward left")
            return
        previous = mirror
    if mirror >= -0.90:
        _fail("shoulder mirror does not converge")
        return
    # Validate crossing with real 3D scene projection, not only pure math.
    game.set("camera_yaw", 0.0)
    game.set("camera_radius", 14.0)
    game.set("camera_focus_follow_xz", Vector2.ZERO)
    game.set("camera_target_render_position", Vector3(0.0, 1.53, 0.0))
    game.call("_place_camera")
    var initial_player_render: Vector3 = game.get("camera_player_render_position")
    for spec in [[Vector3(4.0, 0.0, 0.0), 1],
            [Vector3(-4.0, 0.0, 0.0), -1],
            [Vector3(4.0, 0.0, 0.0), 1]]:
        game.set("camera_player_render_position", spec[0])
        game.call("_update_side_from_screen")
        if int(game.get("player_screen_side")) != int(spec[1]):
            _fail("real camera crossing did not mirror player screen side")
            return
    game.set("camera_yaw", 0.0)
    game.set("camera_shoulder_mirror", -1.0)
    var left_yaw: float = game.call("_adaptive_camera_yaw", 0.0, 0.10)
    game.set("camera_shoulder_mirror", 1.0)
    var right_yaw: float = game.call("_adaptive_camera_yaw", 0.0, 0.10)
    if left_yaw <= 0.0 or right_yaw >= 0.0:
        _fail("left/right shoulder correction did not reverse yaw")
        return
    game.set("camera_player_render_position", initial_player_render)
    game.set("camera_target_render_position", boss.global_position)
    for id in ["", "head", "leg_fl"]:
        game.set("locked_target_part_id", id)
        var from: Vector3 = game.get("camera_player_render_position") + Vector3.UP * 1.05
        var to: Vector3 = game.call("_current_lock_aim_world")
        var expected: Vector2 = FLICK.projected_target_line(cam, from, to)
        var actual: Vector2 = game.call("_projected_sera_facing")
        if actual.distance_to(expected) > 0.0001:
            _fail("lock marker differs from visible guide front for " + id)
            return
        game.call("_update_target_marker_projection")
        var shown: Vector2 = ui.get("target_marker_position")
        if not cam.is_position_behind(to):
            var raw: Vector2 = cam.unproject_position(to)
            if raw.x >= 42.0 and raw.x <= screen_width - 42.0 \
                    and shown.distance_to(raw) > 0.5:
                _fail("lock reticle is not projected from SAME target aim")
                return
        game.call("_begin_drag", Vector2(400.0, 930.0))
        var frozen: Vector2 = game.get("gesture_screen_forward")
        if frozen.distance_to(actual) > 0.0001:
            _fail("flick capture disagrees with current reticle")
            return
        game.call("_update_controller_flick_guide", 1.0/60.0)
        if (ui.get("flick_sector_forward") as Vector2).distance_to(actual) > 0.0001:
            _fail("red area disagrees with attack direction")
            return
        game.call("_end_drag", Vector2(400.0, 930.0))
    print("PASS v334 camera side mirror and reticle-flick/guide projection")
    game.queue_free()
    await process_frame
    quit(0)
