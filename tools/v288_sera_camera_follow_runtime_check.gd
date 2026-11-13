extends SceneTree
## Real Godot test: short smooth lag, hard positional/angular catch-up,
## and coherent player-follow placement without increasing camera pitch.
func _initialize() -> void:
    call_deferred("_run")


func _fail(s: String) -> void:
    push_error("V288_SERA_CAMERA_FOLLOW_FAILED: " + s)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("main scene missing")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var camera: Camera3D = game.get("camera")
    if player == null or target == null or camera == null:
        _fail("player, target or camera not available")
        return
    var cfg: Dictionary = game.get_script().get_script_constant_map()
    if absf(float(cfg["CAMERA_ELEVATION_RATIO"])-0.21)>0.00001:
        _fail("camera pitch changed to overhead")
        return

    game.set("camera_yaw",0.0)
    var small_yaw: float = float(game.call("_stable_shoulder_camera_yaw",
        deg_to_rad(16.0),1.0/60.0))
    if small_yaw <= 0.0 or small_yaw >= deg_to_rad(4.0):
        _fail("slight normal angular delay was not preserved")
        return
    game.set("camera_yaw",0.0)
    var big_yaw: float = float(game.call("_stable_shoulder_camera_yaw",
        deg_to_rad(142.0),1.0/60.0))
    if absf(wrapf(deg_to_rad(130.0)-big_yaw,-PI,PI))>deg_to_rad(12.0)+0.0001:
        _fail("camera fell more than 12deg behind during rapid turn")
        return

    # Near enough to SERA for smooth tracking, but not anchored to target.
    target.position = Vector3(0,0,-8)
    player.position = Vector3.ZERO
    game.set("camera_player_render_position",player.position)
    game.set("camera_target_render_position",target.position)
    var desired_start: Vector2 = game.call("_desired_camera_follow_focus_xz")
    if desired_start.distance_to(Vector2(0,-2))>0.0001:
        _fail("follow focus is not SERA-relative with 2m lead")
        return
    game.set("camera_focus_follow_xz",desired_start)
    player.position.x = 5.0
    game.set("camera_player_render_position",player.position)
    game.call("_advance_camera_follow_focus",1.0/60.0)
    var desired: Vector2 = game.call("_desired_camera_follow_focus_xz")
    var actual: Vector2 = game.get("camera_focus_follow_xz")
    if actual.distance_to(desired)<3.0 or actual.distance_to(desired)>5.0:
        _fail("focus teleported across a sudden SERA displacement")
        return
    if actual.x<=0.0 or actual.x>0.40:
        _fail("camera focus did not move smoothly with bounded per-frame speed")
        return
    # At steady, low speed the follow point eases instead of jittering.
    var before: Vector2=actual
    game.call("_advance_camera_follow_focus",1.0/60.0)
    actual=game.get("camera_focus_follow_xz")
    if actual.distance_to(desired)>before.distance_to(desired)+0.00001:
        _fail("focus overshot / oscillated around SERA")
        return

    game.set("camera_yaw",0.0)
    game.set("camera_radius",13.0)
    game.call("_place_camera")
    if absf(camera.position.x-actual.x)>0.0001:
        _fail("camera does not use interpolated SERA follow focus")
        return
    var focus_y:float=float(cfg["TARGET_BASE_HEIGHT"])-float(cfg["CAMERA_FOCUS_DROP"])
    if absf(camera.position.y-focus_y-13.0*0.21)>0.0001:
        _fail("camera pitch or vertical anchor changed")
        return
    # Boss Y bob should not physically bob the camera's central focus.
    var old_y:float=camera.position.y
    game.set("camera_target_render_position",Vector3(0,20,-8))
    game.call("_place_camera")
    if absf(camera.position.y-old_y)>0.0001:
        _fail("camera vertical anchor inherits enemy bob")
        return
    print("GODOT_V288_SERA_CAMERA_FOLLOW_PASS: bounded smooth focus, 12deg yaw leash, fixed pitch")
    quit(0)
