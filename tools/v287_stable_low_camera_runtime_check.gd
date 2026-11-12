extends SceneTree
## Camera should not tilt, yaw-jump or zoom in from strike-to-strike.
func _initialize() -> void:
    call_deferred("_run")


func _fail(s: String) -> void:
    push_error("V287_STABLE_LOW_CAMERA_FAILED: " + s)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("scene not found")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var camera: Camera3D = game.get("camera")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if camera == null or player == null or target == null or rig == null:
        _fail("main scene components missing")
        return
    var cfg: Dictionary = game.get_script().get_script_constant_map()
    if absf(float(cfg["CAMERA_ELEVATION_RATIO"]) - 0.21) > 0.0001:
        _fail("old low camera pitch not restored")
        return
    game.set("camera_radius", 12.0)
    game.set("camera_yaw", 0.0)
    game.call("_place_camera")
    var target_render: Vector3 = game.get("camera_target_render_position")
    var focus: Vector3 = target_render - Vector3.UP * float(cfg["CAMERA_FOCUS_DROP"])
    if absf(camera.position.y - focus.y - 12.0 * 0.21) > 0.0001:
        _fail("overhead elevation still active")
        return
    var proposed: float = float(game.call("_stable_shoulder_camera_yaw",
        deg_to_rad(90.0), 1.0 / 60.0))
    if proposed <= 0.0 or proposed > deg_to_rad(32.0/60.0) + 0.0001:
        _fail("camera recentering has a yaw snap")
        return

    # Simulate rapid successive attack states and a gap shorter than
    # the post-attack hold duration.
    game.set("target_hp", 0)
    game.set("combat_state", 1)  # MELEE_APPROACH
    game.set("camera_yaw", 0.0)
    game.set("camera_follow_radius", 13.0)
    game.call("_process", 0.016)
    if absf(float(game.get("camera_yaw"))) > 0.000001:
        _fail("camera turned during melee approach")
        return
    if float(game.get("camera_follow_radius")) < 13.0 - 0.000001:
        _fail("inward zoom activated during attack")
        return
    game.set("combat_state", 0) # Brief idle interval between strikes.
    game.call("_process", 0.10)
    if absf(float(game.get("camera_yaw"))) > 0.000001:
        _fail("camera yaw oscillated in a 100ms combo gap")
        return
    if float(game.get("camera_combat_hold_remaining")) <= 0.0:
        _fail("post-attack camera hold was lost")
        return
    game.set("combat_state", 3)  # STRIKE
    game.call("_process", 0.016)
    if absf(float(game.get("camera_yaw"))) > 0.000001:
        _fail("next strike reoriented the camera")
        return

    # Screen-left/right orbit from the target does not rotate SERA into a
    # 90deg side view when camera yaw remains stable.
    game.set("combat_state", 0)
    target.position = Vector3.ZERO
    player.position = Vector3(0,0,3.0)
    game.set("step_kick_side_request", 1)
    if not bool(game.call("_start_omni_step", Vector2.RIGHT)):
        _fail("right kick could not start")
        return
    game.set("step_kick_side_request", 0)
    game.call("_configure_side_kick_orbit")
    var radius: float = Vector2(player.position.x,player.position.z).length()
    if radius < 0.001:
        _fail("kick test radius missing")
        return
    var start_bearing: float = atan2(player.position.x,player.position.z)
    var end_bearing: float = wrapf(start_bearing + float(
        game.get("step_signed_angle")) - float(game.get("camera_yaw")), -PI, PI)
    if absf(end_bearing) > deg_to_rad(30.0)+0.001:
        _fail("kick places SERA more than 30deg sideways on screen")
        return
    print("GODOT_V287_STABLE_LOW_CAMERA_PASS: fixed low pitch, held attack yaw and zoom, limited lateral profile")
    quit(0)
