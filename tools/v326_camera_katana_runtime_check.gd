extends SceneTree
## Exercise the real training scene: stable camera safety floor and both authored arcs.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V326_CAMERA_KATANA_FAILED: " + message)
    quit(1)

func _run() -> void:
    var game: Node3D = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    var player: Node3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    var trail: Node3D = game.get("sword_trail")
    if player == null or target == null or rig == null or trail == null:
        _fail("Scene setup missing")
        return
    var plane: MeshInstance3D = trail.get("source_plane")
    var effect: Node3D = trail.get("effect_root")
    if plane == null or effect == null:
        _fail("Swordeffect authored plane missing")
        return

    var cfg: Dictionary = game.get_script().get_script_constant_map()
    var base_height: float = cfg["TARGET_BASE_HEIGHT"]
    player.position = Vector3(0.0, 0.0, 4.5)
    target.position = Vector3(0.0, base_height, 0.0)
    player.reset_physics_interpolation()
    target.reset_physics_interpolation()
    game.set("camera_player_render_position", player.global_position)
    game.set("camera_target_render_position", target.global_position)
    game.set("camera_focus_follow_xz", game.call("_desired_camera_follow_focus_xz"))
    game.set("camera_yaw", 0.0)
    game.set("camera_follow_radius", 8.0)
    game.set("camera_fit_radius_floor", 0.0)
    game.set("camera_radius", 8.0)
    game.call("_place_camera")
    var previous: float = INF
    for i in range(180):
        game.call("_fit_full_frame")
        if not game.call("_full_frame_safe"):
            _fail("Frame fit cropped at iteration " + str(i))
            return
        var current: float = float(game.get("camera_radius"))
        var min_safe: float = float(game.call("_minimum_boost_camera_radius")) + float(cfg["CAMERA_FIT_RADIUS_RESERVE"])
        if current + 0.0001 < min_safe:
            _fail("Normal fit fell below analytic safety envelope")
            return
        if i > 1 and current > previous + 0.001:
            _fail("Stationary fit zoom oscillated out after release")
            return
        game.call("_relax_camera_fit_radius", 1.0 / 120.0)
        previous = current

    for clip in ["Melee_katana", "Melee_katana2"]:
        rig.call("start_strike", clip)
        rig.set("clip_time", 0.33333 if clip == "Melee_katana" else 0.25)
        rig.set("blending_for", rig.get("blend_duration"))
        rig.call("_apply_animation", 0.0)
        trail.call("begin_swing", 0.0, clip == "Melee_katana2")
        if not effect.transform.is_equal_approx(plane.transform):
            _fail(clip + " applied an extra local rotation")
            return
        if effect.global_transform.basis.y.normalized().dot(plane.global_transform.basis.y.normalized()) < 0.9999:
            _fail(clip + " changed the authored slash-plane normal")
            return
        trail.call("sample_swing", Vector3.ZERO, Vector3.ZERO, 0.35, 0.016)
        trail.call("advance", 0.016, false)
        if not effect.visible:
            _fail(clip + " arc did not display")
            return
        trail.call("stop_swing")
    print("PASS v326 stationary camera fit and authored Katana 1/2 planes")
    game.queue_free()
    await process_frame
    quit(0)
