extends SceneTree
## Retain v287's non-overhead view while testing v288's rapid SERA pursuit.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V287_STABLE_LOW_CAMERA_FAILED: " + message)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene not found")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var camera: Camera3D = game.get("camera")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if camera == null or player == null or target == null or rig == null:
        _fail("scene or rig missing")
        return
    var cfg: Dictionary = game.get_script().get_script_constant_map()
    if absf(float(cfg["CAMERA_ELEVATION_RATIO"]) - 0.21)>0.00001:
        _fail("fixed low view is not preserved")
        return
    game.set("camera_radius",12.0)
    game.call("_place_camera")
    var follow: Vector2 = game.get("camera_focus_follow_xz")
    var focus_y: float = float(cfg["TARGET_BASE_HEIGHT"]) - float(cfg["CAMERA_FOCUS_DROP"])
    if absf(camera.position.y - focus_y - 12.0*0.21)>0.0001:
        _fail("v286 overhead view was restored")
        return
    if absf(camera.position.x-follow.x)>0.0001:
        _fail("camera position did not use SERA-follow X coordinate")
        return
    if not bool(rig.get("loading_ok")):
        _fail("authored clips did not load")
        return

    # A 90deg sudden turn must still retain at most 12deg of delay.
    game.set("camera_yaw",0.0)
    var wanted: float = deg_to_rad(90.0)
    var next: float = float(game.call("_stable_shoulder_camera_yaw",
        wanted+deg_to_rad(12.0),1.0/60.0))
    if absf(wrapf(wanted-next,-PI,PI)) > deg_to_rad(12.0)+0.00001:
        _fail("SERA turned more than 12deg away from camera")
        return
    # Small turns should still retain a little easing, without an
    # instantaneous hard lock on every micro-adjustment.
    game.set("camera_yaw",0.0)
    next=float(game.call("_stable_shoulder_camera_yaw",
        deg_to_rad(15.0),1.0/60.0))
    if next <= 0.0 or next >= deg_to_rad(3.0):
        _fail("short angular delay was lost")
        return

    # A fast physical move may leave 0.65m of lag, never more.
    target.position = Vector3.ZERO
    player.position = Vector3(0,0,9)
    game.set("camera_player_render_position",player.position)
    game.set("camera_target_render_position",target.position)
    game.set("camera_focus_follow_xz",game.call("_desired_camera_follow_focus_xz"))
    player.position += Vector3(5.0,0,0)
    game.set("camera_player_render_position",player.position)
    game.call("_advance_camera_follow_focus",1.0/60.0)
    var desired: Vector2 = game.call("_desired_camera_follow_focus_xz")
    var actual: Vector2 = game.get("camera_focus_follow_xz")
    if actual.distance_to(desired) > 0.65001:
        _fail("camera did not catch up to SERA beyond positional threshold")
        return
    game.set("camera_radius",12.0)
    game.call("_place_camera")
    var polar_x: float = sin(float(game.get("camera_yaw")))*12.0
    if absf(camera.position.x - (actual.x+polar_x)) > 0.0001:
        _fail("SERA-follow focus is not applied to actual camera transform")
        return
    print("GODOT_V287_STABLE_LOW_CAMERA_PASS: low fixed pitch, smooth small yaw and hard SERA pursuit")
    quit(0)
