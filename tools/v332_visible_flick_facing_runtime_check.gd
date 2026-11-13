extends SceneTree
## v333 supersedes v332 animated-head input heading. Keep real rig and
## controller display checks, now ensuring head motion cannot hijack lock.
const FLICK = preload("res://scripts/flick_direction_policy.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("V332_LOCKED_FLICK_FAILED: " + reason)
    quit(1)
func _run() -> void:
    var game: Node3D = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var player: CharacterBody3D = game.get("player")
    var cam: Camera3D = game.get("camera")
    var touch: Control = game.get("touch_ui")
    if rig == null or player == null or cam == null or touch == null \
            or not bool(rig.get("loading_ok")):
        _fail("scene or rig unavailable")
        return
    var head: Node3D = rig.call("get_visible_facing_pivot")
    if head == null:
        _fail("authored head pivot missing")
        return
    var original: Quaternion = head.quaternion
    game.set("locked_target_part_id", "")
    var base_axis: Vector2 = game.call("_projected_sera_facing")
    var base_expected: Vector2 = FLICK.projected_lock_forward(
        cam, player.global_position, game.call("_locked_target_facing_direction"))
    if base_axis.distance_to(base_expected) > 0.003:
        _fail("BODY lock axis not derived from SERA-to-target line")
        return
    for degrees in [75.0, 135.0, -90.0]:
        head.quaternion = (Quaternion(Vector3.UP, deg_to_rad(degrees)) * original).normalized()
        var facing: Vector2 = game.call("_projected_sera_facing")
        if facing.distance_to(base_axis) > 0.003:
            _fail("head-only yaw changed selected target front")
            return
        game.set("gesture_screen_forward", facing)
        touch.call("show_drag", Vector2(350.0, 920.0), Vector2.ZERO, 157.5)
        touch.call("set_flick_sector_forward", facing, 0.0, true)
        if (touch.call("flick_sector_direction", 0) as Vector2).distance_to(facing) > 0.003:
            _fail("red sector does not match combat axis")
            return
        var right: Vector2 = Vector2(-facing.y, facing.x)
        for sector in [[facing, 0], [right, 1], [-facing, 2], [-right, -1]]:
            if int(game.call("_combo_kick_side_for_flick", sector[0])) != int(sector[1]):
                _fail("four UI sectors disagree with attack classifier")
                return
        touch.call("hide_drag")
    head.quaternion = original
    # Live runner continues to animate the model; only the lock vector
    # decides its projected input.
    rig.call("set_moving", false)
    rig.call("set_moving", true, false, Vector2.RIGHT, false)
    rig.call("_process", 0.20)
    rig.call("_process", 0.16)
    var live: Vector2 = game.call("_projected_sera_facing")
    if live.distance_to(base_axis) > 0.003:
        _fail("run animation changed lock-based controller")
        return
    game.call("_begin_drag", Vector2(365.0, 950.0))
    if (game.get("gesture_screen_forward") as Vector2).distance_to(live) > 0.003:
        _fail("touch start did not capture locked axis")
        return
    if (touch.get("flick_sector_forward") as Vector2).distance_to(live) > 0.003:
        _fail("touch start guide differs from classified axis")
        return
    game.call("_end_drag", Vector2(365.0, 950.0))
    print("PASS v332/v333 visual bone independence and locked-front sectors")
    game.queue_free()
    await process_frame
    quit(0)
