extends SceneTree
## v318: collision-swept 0.3m launch/4m dodge and continuous camera profiles.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V318_STEP_CAMERA_FAILED: " + message)
    quit(1)


func _run() -> void:
    var math_code: GDScript = load("res://scripts/sera_camera_math.gd")
    if math_code == null:
        _fail("camera math module missing")
        return
    var hold: float = 0.06
    var total: float = 0.30
    if absf(math_code.step_recovery_response(0.04, hold, total)) > 0.00001:
        _fail("camera does not pause after dodge")
        return
    if absf(math_code.step_recovery_response(0.18, hold, total) - 0.5) > 0.00001:
        _fail("recovery middle is not smooth or correctly timed")
        return
    if absf(math_code.step_recovery_response(0.30, hold, total) - 1.0) > 0.00001:
        _fail("camera has not restored normal response after 0.30s")
        return
    var no_turn: float = math_code.follow_yaw_with_side_room(
        0.0, deg_to_rad(27.0), 1.0 / 60.0, 12.0, 10.0, 22.0, 300.0)
    var turn: float = math_code.follow_yaw_with_side_room(
        0.0, deg_to_rad(72.0), 1.0 / 60.0, 12.0, 10.0, 22.0, 300.0)
    if absf(no_turn) > 0.000001 or turn <= 0.0 or turn > deg_to_rad(5.0) + 0.00001:
        _fail("lateral room / bounded yaw turn invalid")
        return

    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("scene unavailable")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var rig: Node3D = game.get("rig")
    if player == null or target == null or rig == null or not bool(rig.get("loading_ok")):
        _fail("combat actors unavailable")
        return

    game.set("target_move_enabled", false)
    game.set("target_hp", 500)
    game.set("auto_lock_enabled", false)
    game.set("manual_part_lock_active", true)
    game.set("locked_target_part_id", "")
    player.position = target.position + Vector3(0.0, 0.0, 18.0)
    game.set("camera_yaw", 0.0)
    game.call("_place_camera")
    var travel: Vector3 = game.call("_screen_drag_to_ground", Vector2.RIGHT)
    var start: Vector3 = player.position
    game.set("energy", 100.0)
    game.set("energy_exhausted", false)
    if not bool(game.call("_start_omni_step", Vector2.RIGHT)):
        _fail("normal right dodge could not start")
        return
    var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/sera_active_specs.json"))
    var launch: Vector3 = player.position - start
    if absf(Vector2(launch.x, launch.z).length() - float(spec["ordinary_step"]["launch_warp_m"])) > 0.06:
        _fail("launch differs from approved active specification")
        return
    if absf(float(game.get("step_arc_length")) - 4.0) > 0.0001:
        _fail("dodge is not a total 4m")
        return
    var total_seconds: float = float(game.get("step_duration_current"))
    if absf(total_seconds - 4.0 / 15.0) > 0.0001:
        _fail("dodge speed / timeline changed")
        return
    game.call("_advance_side_step", total_seconds)
    var traveled: Vector3 = player.position - start
    var expected: Vector3 = travel.normalized() * 4.0
    if Vector2(traveled.x - expected.x, traveled.z - expected.z).length() > 0.07:
        _fail("dodge launch double-counted or failed to reach 4m")
        return
    if bool(game.get("step_active")):
        game.call("_finish_side_step", false)
    if not bool(game.get("camera_step_recovery_active")):
        _fail("post-step camera recovery not armed")
        return

    # A short full-speed reset would visibly snap yaw at the first render.
    game.set("direction_input", Vector2.ZERO)
    game.set("camera_yaw", 0.0)
    game.call("_advance_camera_response_profile", 0.03)
    var early_yaw: float = game.call("_adaptive_camera_yaw", deg_to_rad(92.0), 0.03)
    if absf(early_yaw) > 0.00001:
        _fail("camera moved during post-step beat")
        return
    game.call("_advance_camera_response_profile", 0.09)
    var middle_yaw: float = game.call("_adaptive_camera_yaw", deg_to_rad(92.0), 0.03)
    if middle_yaw <= 0.0 or middle_yaw >= deg_to_rad(5.0):
        _fail("camera recovery did not accelerate smoothly")
        return
    game.call("_advance_camera_response_profile", 0.18)
    if bool(game.get("camera_step_recovery_active")):
        _fail("post-step recovery exceeded 0.30s")
        return

    # A combo's IDLE link-window must not reset its camera acceleration.
    game.set("combat_state", 3) # STRIKE
    game.call("_advance_camera_response_profile", 0.325)
    var weight_first: float = float(game.get("camera_melee_follow_weight"))
    if absf(weight_first - 0.5) > 0.001:
        _fail("melee follow speed did not ramp up")
        return
    game.set("combat_state", 0) # IDLE, between linked strikes
    game.set("bash_followup_window_remaining", 0.4)
    game.call("_advance_camera_response_profile", 0.325)
    if absf(float(game.get("camera_melee_follow_weight")) - 1.0) > 0.001:
        _fail("combo camera lost speed in followup link")
        return
    game.set("bash_followup_window_remaining", 0.0)
    game.call("_advance_camera_response_profile", 0.09)
    if absf(float(game.get("camera_melee_follow_weight")) - 0.5) > 0.001:
        _fail("combo follow did not smoothly release")
        return
    game.call("_advance_camera_response_profile", 0.09)
    if absf(float(game.get("camera_melee_follow_weight"))) > 0.001:
        _fail("combo follow did not return to normal")
        return

    # Preserve the existing 0.65m camera focus leash in both modes.
    game.set("camera_player_render_position", Vector3(0.0, 0.0, 0.0))
    game.set("camera_target_render_position", Vector3(0.0, 0.0, -5.0))
    game.set("camera_focus_follow_xz", Vector2(0.0, -1.6))
    game.set("camera_melee_follow_weight", 0.0)
    game.call("_advance_camera_follow_focus", 1.0 / 60.0)
    var normal_delta: float = absf(float((game.get("camera_focus_follow_xz") as Vector2).y) + 1.6)
    game.set("camera_focus_follow_xz", Vector2(0.0, -1.6))
    game.set("camera_melee_follow_weight", 1.0)
    game.call("_advance_camera_follow_focus", 1.0 / 60.0)
    var melee_delta: float = absf(float((game.get("camera_focus_follow_xz") as Vector2).y) + 1.6)
    if melee_delta <= normal_delta or melee_delta >= 0.65:
        _fail("melee focus rate is not greater than normal")
        return

    game.call("_finish_side_step", false)
    print("GODOT_V318_STEP_CAMERA_PASS")
    quit(0)
