extends SceneTree
## Legacy v286: fixed 3m lock-centered kick + unobstructed lower LOCK UI.
## v287 deliberately removed v286's overhead and every-frame yaw search.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V286_CLOSE_CAMERA_CLEARANCE_FAILED: " + message)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    var cam: Camera3D = game.get("camera")
    if player == null or target == null or cam == null or rig == null:
        _fail("actors/camera missing")
        return
    for button_name in ["lock_switch_left_button",
            "lock_mode_button", "lock_switch_right_button"]:
        var btn: Button = game.get(button_name)
        if btn == null:
            _fail("LOCK button missing: " + button_name)
            return
        if absf(btn.anchor_top - 0.76) > 0.0001:
            _fail("LOCK button remains over central combat scene")
            return
        if btn.mouse_filter != Control.MOUSE_FILTER_IGNORE:
            _fail("LOCK button stole controller gestures")
            return
    var left: Button = game.get("lock_switch_left_button")
    var center: Button = game.get("lock_mode_button")
    var right: Button = game.get("lock_switch_right_button")
    # v328: all anchors are equal within the handed half; offsets order
    # the buttons. The cluster mirrors to the opposite half with handedness.
    for handed in [false, true]:
        game.set("left_handed", handed)
        game.call("_layout_lock_control_buttons")
        var half: float = 0.5 if handed else 0.0
        if absf(left.anchor_left - half) > 0.0001 or absf(
                center.anchor_left - half) > 0.0001 or absf(
                right.anchor_left - half) > 0.0001:
            _fail("LOCK cluster failed handedness mirroring")
            return
        if not (left.offset_right < center.offset_left
                and center.offset_right < right.offset_left):
            _fail("LOCK symbol button order/spacing changed")
            return
    var cfg: Dictionary = game.get_script().get_script_constant_map()
    var base_pitch: float = float(cfg["CAMERA_ELEVATION_RATIO"])
    if absf(base_pitch - 0.21) > 0.0001:
        _fail("original v56 camera elevation not restored")
        return
    game.set("camera_yaw", 0.0)
    game.set("camera_radius", 12.0)
    game.call("_place_camera")
    var follow_xz: Vector2 = game.get("camera_focus_follow_xz")
    var focus: Vector3 = Vector3(follow_xz.x,
        float(cfg["TARGET_BASE_HEIGHT"]) - float(cfg["CAMERA_FOCUS_DROP"]),
        follow_xz.y)
    if absf(cam.position.y - focus.y - 12.0 * 0.21) > 0.0005:
        _fail("fixed camera pitch changed to overhead")
        return
    target.position = Vector3.ZERO
    player.position = Vector3(0,0,3.0)
    game.set("target_hp",0)
    # KO is still attackable; isolate the pre-second-windup orbit by
    # disabling homing velocity in this camera/trajectory regression.
    var stats: Dictionary = game.get("part_stats")
    stats["melee_boost_speed"] = 0.0
    game.set("part_stats",stats)
    game.set("step_kick_side_request",1)
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("Kick_r could not start")
        return
    game.set("step_kick_side_request",0)
    var original: Vector3 = player.position
    var duration: float = float(game.get("step_duration_current"))
    game.call("_advance_side_step",duration*0.334)
    if not bool(game.get("side_kick_travel_anchor_set")):
        _fail("Kick_r orbit did not anchor at second windup")
        return
    # v300: the old outward radius inflation was removed. The kick now
    # budgets exactly 3m between the part-centered circular phase and the
    # straight tangent after hit 2, and never teleports the character root.
    var orbit_start: Vector2 = game.get("step_start_offset")
    var planned_arc: float = orbit_start.length() * absf(
        float(game.get("step_signed_angle")))
    var planned_line: float = float(game.get("side_kick_linear_distance"))
    if absf(planned_arc + planned_line - 3.0) > 0.001:
        _fail("new fixed 3m kick plan exceeded its orbit-plus-line budget")
        return
    if player.position.distance_to(original) > 0.05:
        _fail("kick snapped before authored second windup")
        return
    game.call("_advance_side_step", duration * 0.25)
    if not bool(game.get("side_kick_linear_active")):
        _fail("kick did not exit orbit after second contact")
        return
    if player.position.distance_to(original) > 3.1:
        _fail("kick exceeded its 3m boost budget or teleported")
        return
    print("GODOT_V286_CLOSE_CAMERA_CLEARANCE_PASS: low pitch, 3m fixed kick budget, lower LOCK buttons")
    quit(0)
