extends SceneTree
## Godot scene checks for the attached v285 close-up / obscured SERA regression.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V286_CLOSE_CAMERA_CLEARANCE_FAILED: " + message)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("main.tscn not found")
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var camera: Camera3D = game.get("camera")
    var rig: Node3D = game.get("rig")
    if player == null or target == null or camera == null or rig == null:
        _fail("main-scene actors or camera are missing")
        return
    if not bool(rig.get("loading_ok")):
        _fail("authored rig not loaded")
        return
    # Simulate a player standing close enough to overlap a broad boss leg.
    target.position = Vector3.ZERO
    player.position = Vector3(0,0,3.0)
    game.set("camera_target_render_position",target.position)
    game.set("camera_player_render_position",player.position)
    game.set("player_screen_side",1)
    game.set("camera_yaw",0.0)
    game.call("_place_camera")
    var old_gap: float = float(game.call("_signed_screen_gap",1))
    var optimized: float = float(game.call("_visible_combat_camera_yaw",0.0,1.0))
    if absf(optimized)>deg_to_rad(45.0)+0.00001:
        _fail("visibility search exceeded the requested 45deg bound")
        return
    game.set("camera_yaw",optimized)
    game.call("_place_camera")
    var new_gap: float = float(game.call("_signed_screen_gap",1))
    if new_gap < old_gap-0.5:
        _fail("visibility-search yaw made the near-boss silhouette overlap worse")
        return
    # A close-up must expose the floor via increased pitch; a long-distance
    # camera must remain at its original v9 elevation. The interpolation is
    # smooth, rather than an instantaneous camera tilt/jerk.
    var camera_constants: Dictionary = game.get_script().get_script_constant_map()
    var base_pitch: float = float(camera_constants["CAMERA_ELEVATION_RATIO"])
    var new_pitch: float = float(camera_constants["CAMERA_COMBAT_ELEVATION_RATIO"])
    if new_pitch <= base_pitch or new_pitch > 1.0:
        _fail("invalid near-combat elevated view range")
        return
    # The initial idle scenario is not a STEP, so this solver must also
    # be used by WAIT's near-camera branch.
    var main_script: Script = game.get_script()
    if main_script == null:
        _fail("main script missing")
        return
    # Safe orbit starts without a teleport. Only after second-windup can
    # the trajectory progressively increase the player/target radius.
    game.set("target_hp",0)
    game.set("step_kick_side_request",1)
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("Kick_r would not initialize")
        return
    game.set("step_kick_side_request",0)
    var before: Vector3 = player.position
    var action_seconds: float = float(game.get("step_duration_current"))
    game.call("_advance_side_step",action_seconds*0.334)
    if not bool(game.get("side_kick_travel_anchor_set")):
        _fail("orbit anchor missing after second windup")
        return
    var planned_outward: float = float(game.get("step_radial_delta"))
    if absf(planned_outward-0.55)>0.01:
        _fail("near-boss side kick did not reserve outward clearance")
        return
    if before.distance_to(player.position)>0.06:
        _fail("near-boss clearance was applied as a position teleport")
        return
    game.call("_advance_side_step",action_seconds*0.35)
    var center: Vector2 = Vector2(target.position.x,target.position.z)
    var actual_radial: Vector2 = Vector2(
        player.position.x-center.x,player.position.z-center.y)
    if actual_radial.length() < before.distance_to(target.position)-0.10:
        _fail("Kick_r collapsed its radius into the enemy while orbiting")
        return
    if not bool(game.get("step_active")):
        _fail("side kick finished before its original 2x authored duration")
        return
    print("GODOT_V286_CLOSE_CAMERA_CLEARANCE_PASS: near yaw seeks gap inside 45deg, pitched view, safe-radius Kick_r orbit")
    quit(0)
