extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.set("camera_melee_follow_weight", 0.0)
    game.set("camera_lateral_follow_weight", 1.0)
    game.set("direction_input", Vector2.ZERO)
    game.set("camera_yaw", 0.0)
    var next: float = game.call("_adaptive_camera_yaw", deg_to_rad(32.0), 1.0/60.0)
    if next > deg_to_rad(0.2) or float(game.get("camera_lateral_follow_weight")) < 0.8:
        push_error("V325: stopping lateral movement snaps camera dead zone")
        quit(1)
        return
    for i in range(120):
        game.call("_adaptive_camera_yaw", deg_to_rad(32.0), 1.0/60.0)
    if float(game.get("camera_lateral_follow_weight")) > 0.001:
        push_error("V325: lateral dead zone never releases")
        quit(1)
        return
    var math_code = load("res://scripts/sera_camera_math.gd")
    var low: float = math_code.stable_near_bearing(0.0, 1.0, 2.199, 1.0/60.0)
    var high: float = math_code.stable_near_bearing(0.0, 1.0, 2.201, 1.0/60.0)
    if absf(low - high) > 0.001 or high > 0.2:
        push_error("V325: near-range bearing threshold discontinuity")
        quit(1)
        return
    print("PASS v325 camera transition continuity")
    game.queue_free()
    await process_frame
    quit(0)
