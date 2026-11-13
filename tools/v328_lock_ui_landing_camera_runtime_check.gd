extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("V328_FAILED: " + reason)
    quit(1)
func _run() -> void:
    var game: Node3D = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var boss: Node3D = game.get("target")
    var camera: Camera3D = game.get("camera")
    var rig: Node3D = game.get("rig")
    if player == null or boss == null or camera == null or rig == null:
        _fail("scene nodes missing")
        return
    var left: Button = game.get("lock_switch_left_button")
    var center: Button = game.get("lock_mode_button")
    var right: Button = game.get("lock_switch_right_button")
    if left.text != "◀" or center.text != "" or right.text != "▶":
        _fail("combat controls display text rather than icons")
        return
    for handed in [false, true]:
        game.set("left_handed", handed)
        game.call("_layout_lock_control_buttons")
        var baseline: float = 0.5 if handed else 0.0
        if absf(left.anchor_left - baseline) > 0.0001 or absf(
                center.anchor_left - baseline) > 0.0001 or absf(
                right.anchor_left - baseline) > 0.0001:
            _fail("handed side placement was not mirrored")
            return
        if not (left.offset_left < center.offset_left and center.offset_left < right.offset_left):
            _fail("lock buttons overlap")
            return
    game.set("left_handed", false)
    game.call("_layout_lock_control_buttons")
    game.set("camera_player_render_position", player.position)
    game.set("camera_target_render_position", boss.position)
    var wanted: Vector2 = game.call("_desired_camera_follow_focus_xz")
    if wanted.distance_to(Vector2(boss.position.x, boss.position.z)) > 0.0001:
        _fail("focus is still player-centered")
        return
    game.set("camera_focus_follow_xz", wanted)
    game.set("camera_yaw", deg_to_rad(-43.0))
    game.call("_place_camera")
    game.call("_fit_boost_frame_analytically", 1.0 / 60.0)
    if not game.call("_full_frame_safe"):
        _fail("target-centered composition clips actors")
        return
    var viewport_width: float = game.get_viewport().get_visible_rect().size.x
    var boss_x: float = camera.unproject_position(boss.position).x
    if absf(boss_x - viewport_width * 0.5) > viewport_width * 0.11:
        _fail("boss is not near horizontal screen center")
        return
    game.set("landing_active", true)
    game.set("landing_from_somersault", true)
    game.set("landing_elapsed", 0.11)
    rig.call("start_landing", true)
    game.set("energy", 100.0)
    game.set("energy_exhausted", false)
    var launched: bool = game.call("_start_omni_step", Vector2.RIGHT)
    if not launched or bool(game.get("landing_active")) or not bool(game.get("step_active")):
        _fail("mid-landing STEP did not cancel and launch")
        return
    if bool(rig.get("jump_playback")):
        _fail("landing Jump still owns animation after step")
        return
    game.call("_finish_side_step", false)
    game.set("landing_active", true)
    game.set("landing_elapsed", 0.07)
    game.set("energy", 0.0)
    game.set("energy_exhausted", true)
    if bool(game.call("_start_omni_step", Vector2.LEFT)) or not bool(game.get("landing_active")):
        _fail("unaffordable STEP cancelled landing")
        return
    print("PASS v328 handheld lock layout, boss focus/fit, full landing STEP cancellation")
    game.queue_free()
    await process_frame
    quit(0)
