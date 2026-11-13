extends SceneTree
## Actor-local head yaw differs from collision target-facing; ensure both
## input capture and colored HUD sectors use the actual visual bone.
const FLICK = preload("res://scripts/flick_direction_policy.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("V332_VISIBLE_FLICK_FAILED: " + reason)
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
        _fail("visual head pivot missing")
        return
    var bones: Dictionary = rig.get("bones")
    if head != bones[rig.get_script().get_script_constant_map()["RUN_HEAD_BONE_UUID"]]:
        _fail("not using real head orientation")
        return
    var original: Quaternion = head.quaternion
    # Rotate only visible head: old collision-root policy would ignore this.
    # The camera stays fixed; visible front must rotate about the actual pivot.
    var old_axis: Vector2 = game.call("_projected_sera_facing")
    var different: bool = false
    for degrees in [75.0, 135.0, -90.0]:
        head.quaternion = (Quaternion(Vector3.UP, deg_to_rad(degrees)) * original).normalized()
        var facing: Vector2 = game.call("_projected_sera_facing")
        var expected: Vector3 = -head.global_transform.basis.z
        expected.y = 0.0
        expected = expected.normalized()
        var p0: Vector3 = head.global_position
        var p1: Vector3 = p0 + expected
        var display: Vector2 = (cam.unproject_position(p1) - cam.unproject_position(p0)).normalized()
        if facing.distance_to(display) > 0.003:
            _fail("projected visible head and input sector differ")
            return
        if facing.distance_to(old_axis) > 0.10:
            different = true
        # The same captured axis drives all four on-screen sectors.
        game.set("gesture_screen_forward", facing)
        touch.call("show_drag", Vector2(350.0, 920.0), Vector2.ZERO, 157.5)
        touch.call("set_flick_sector_forward", facing, 0.0, true)
        if (touch.call("flick_sector_direction", 0) as Vector2).distance_to(facing) > 0.003:
            _fail("red visual sector not aligned with visible SERA face")
            return
        var right: Vector2 = Vector2(-facing.y, facing.x)
        for sector in [[facing, 0], [right, 1], [-facing, 2], [-right, -1]]:
            if int(game.call("_combo_kick_side_for_flick", sector[0])) != int(sector[1]):
                _fail("visual sectors disagree with combat direction")
                return
        touch.call("hide_drag")
    if not different:
        _fail("axis still bound to collision body rather than animated head")
        return
    head.quaternion = original
    # Test actual RUN animation: displayed head pivot can follow independently
    # of collider; never use a stale cached or world axis.
    rig.call("set_moving", false)
    rig.call("set_moving", true, false, Vector2.RIGHT, false)
    rig.call("_process", 0.20)
    rig.call("_process", 0.16)
    var live: Vector2 = game.call("_projected_sera_facing")
    var visual: Vector2 = FLICK.projected_forward(cam, player,
        rig.call("get_visible_facing_pivot"))
    if live.distance_to(visual) > 0.003:
        _fail("RUN's live visual direction not reflected in input")
        return
    print("PASS v332 animated head projection, controller and combo sectors agree")
    game.queue_free()
    await process_frame
    quit(0)
