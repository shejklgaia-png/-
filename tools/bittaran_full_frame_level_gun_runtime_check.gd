extends SceneTree
## Verify camera frames the actual 18 moving boss meshes (not dummy bounds)
## and the Body may pitch/roll without introducing railgun roll.
const DT: float = 1.0 / 60.0
const GUN = preload("res://scripts/bittaran_railgun.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("BITTARAN_V464_FRAME_LEVEL_FAIL " + reason)
    quit(1)

func _run() -> void:
    var scene: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var rig: Node3D = scene.get("bittaran_rig")
    var gun: Node3D = scene.get("bittaran_railgun")
    var camera: Camera3D = scene.get("camera")
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    if rig == null or gun == null or camera == null or body == null:
        _fail("missing boss camera, rig, gun or Body")
        return
    if not bool(rig.get("loading_ok")) or gun.get_script() != GUN:
        _fail("boss source data did not load")
        return
    if (rig.get("mesh_nodes_by_uuid") as Dictionary).size() != 18:
        _fail("authored 18-mesh Bittaran source changed")
        return
    var bounds: AABB = scene.call("_bittaran_model_world_bounds")
    if not bounds.has_volume() or bounds.size.x < 5.0 or (
            bounds.size.y < 2.0):
        _fail("camera must measure the real broad articulated model")
        return
    # Same picture constraints must hold from both sides and diagonally,
    # even when the player stands near the boss. The far-field independent
    # projectile must NEVER enter the fit bounds.
    for facing in [0.0, PI * 0.5, PI, -PI * 0.7]:
        scene.set("camera_yaw", facing)
        scene.set("camera_fit_radius_floor", 0.0)
        scene.set("camera_follow_radius", 6.0)
        scene.set("camera_radius", 6.0)
        scene.call("_place_camera")
        var analytical: float = scene.call("_minimum_boost_camera_radius")
        if analytical <= 6.0:
            _fail("camera still using undersized dummy fit " + str(analytical))
            return
        scene.call("_fit_full_frame")
        scene.call("_place_camera")
        if not bool(scene.call("_target_fully_in_frame")):
            _fail("boss clips during fitted camera orbit yaw=" + str(facing))
            return
        var points: Array = scene.call("_bittaran_camera_bounds_corners")
        if points.size() != 8:
            _fail("missing complete visible envelope")
            return
        var viewport_size: Vector2 = scene.get_viewport().get_visible_rect().size
        for raw in points:
            var screen: Vector2 = camera.unproject_position(raw)
            if screen.x < viewport_size.x * 0.02 or (
                    screen.x > viewport_size.x * 0.98) or (
                    screen.y < viewport_size.y * 0.14) or (
                    screen.y > viewport_size.y * 0.76):
                _fail("live mesh bounds escaped full-frame projection")
                return
    # The parent Body is allowed to roll and pitch in original animations,
    # but the mechanical turret may only yaw in horizontal world plane
    # and pitch around its independent horizontal right axis.
    var saved_body_pose: Quaternion = body.quaternion
    var elevation: Node3D = gun.get_node("RailgunElevation") as Node3D
    for lean in [Vector2(15.0, -20.0), Vector2(-12.0, 18.0)]:
        body.quaternion = (
            Quaternion(Vector3.RIGHT, deg_to_rad(lean.x))
            * Quaternion(Vector3.FORWARD, deg_to_rad(lean.y))
            * saved_body_pose).normalized()
        gun.call("reset")
        # v465 only allows aim once all three charge bars are full.
        gun.set("elapsed", GUN.TRACK_START_SECONDS)
        var side: Vector3 = (
            gun.global_position + Vector3(6.0, 2.0, -6.0))
        for i in range(120):
            gun.call("advance", DT, side, true)
        var level_up: Vector3 = gun.global_basis.y.normalized()
        if level_up.distance_to(Vector3.UP) > 0.0001:
            _fail("dorsal turret inherited body lean: " + str(level_up))
            return
        var barrel_right: Vector3 = elevation.global_basis.x.normalized()
        if absf(barrel_right.dot(Vector3.UP)) > 0.0001:
            _fail("gun gained forbidden roll while aiming up/down")
            return
        var pitch: float = elevation.rotation.x
        if absf(pitch) < deg_to_rad(1.0):
            _fail("barrel pitch not controlled by target elevation")
            return
        if absf(float(gun.get("aim_yaw"))) < deg_to_rad(1.0):
            _fail("world-space horizontal target tracking stopped")
            return
        gun.set("elapsed", GUN.BEAM_SECONDS + 0.45)
        gun.call("advance", 0.01, side, true)
        if gun.global_basis.y.normalized().distance_to(
                Vector3.UP) > 0.0001:
            _fail("returning to neutral reintroduced tilt")
            return
    body.quaternion = saved_body_pose
    gun.call("reset")
    print("GODOT_BITTARAN_V464_FRAME_LEVEL_PASS ",
        "all_18_meshes_fitted=true player_frame_safe=true ",
        "cannon_body_lean_isolated=true world_yaw_pitch_only=true")
    quit(0)
