extends SceneTree
## Real scene, live part aim, combat state and CanvasItem readiness flags.
const POLICY = preload("res://scripts/flick_direction_policy.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(s: String) -> void:
    push_error("V333_COMBO_UI_FAILED: " + s)
    quit(1)
func _run() -> void:
    var game: Node3D = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    var player: CharacterBody3D = game.get("player")
    var boss: Node3D = game.get("target")
    var camera: Camera3D = game.get("camera")
    var overlay: Control = game.get("touch_ui")
    var rig: Node3D = game.get("rig")
    if player == null or boss == null or camera == null or overlay == null \
            or rig == null or not bool(rig.get("loading_ok")):
        _fail("real scene unavailable")
        return
    var main_script: Script = game.get_script()
    var states: Dictionary = main_script.get_script_constant_map()
    var state_enum: Dictionary = states.get("CombatState", {})
    var idle_state: int = int(state_enum.get("IDLE", 0))
    var strike_state: int = int(state_enum.get("STRIKE", 3))
    var bash_state: int = int(state_enum.get("BASH", 4))
    var old_head: Node3D = rig.call("get_visible_facing_pivot")
    game.set("locked_target_part_id", "")
    var front: Vector2 = game.call("_projected_sera_facing")
    var expected: Vector2 = POLICY.projected_lock_forward(camera,
        player.global_position, game.call("_locked_target_facing_direction"))
    if front.distance_to(expected) > 0.0001:
        _fail("flick front is not the SERA-to-BODY lock vector")
        return
    var original_rotation: Quaternion = old_head.quaternion
    old_head.quaternion = Quaternion(Vector3.UP, deg_to_rad(125.0)) * original_rotation
    if front.distance_to(game.call("_projected_sera_facing")) > 0.0001:
        _fail("Head animation incorrectly rotates lock-relative controller")
        return
    old_head.quaternion = original_rotation
    game.set("locked_target_part_id", "leg_fl")
    var leg_front: Vector2 = game.call("_projected_sera_facing")
    var leg_expected: Vector2 = POLICY.projected_lock_forward(camera,
        player.global_position, game.call("_locked_target_facing_direction"))
    if leg_front.distance_to(leg_expected) > 0.0001:
        _fail("front does not follow the locked leg pivot")
        return
    game.set("locked_target_part_id", "")
    game.call("_begin_drag", Vector2(405, 940))
    if (game.get("gesture_screen_forward") as Vector2).distance_to(front) > 0.001:
        _fail("touch did not freeze the locked-axis front")
        return
    var sid: int = int(state_enum.get("STRIKE", 3))
    game.set("combat_state", sid)
    game.set("strike_index", 0)
    if not game.call("_combo_normal_attack_ready") \
            or game.call("_combo_flick_attack_ready"):
        _fail("nonfinal strike readiness incorrect")
        return
    game.call("_update_controller_flick_guide", 1.0/60.0)
    if not bool(overlay.get("combo_visible")) or not bool(overlay.get("combo_normal_ready")):
        _fail("combo controller / sword not shown")
        return
    overlay.call("hide_drag")
    if not bool(overlay.get("combo_visible")):
        _fail("controller vanished between combo taps")
        return
    game.set("strike_index", 2)
    game.call("_update_controller_flick_guide", 1.0/60.0)
    if bool(overlay.get("combo_normal_ready")) or not bool(overlay.get("combo_flick_ready")):
        _fail("finisher failed to offer four direction icons")
        return
    game.set("combat_state", bash_state)
    game.call("_update_controller_flick_guide", 1.0/60.0)
    if not bool(overlay.get("combo_normal_ready")) or bool(overlay.get("combo_flick_ready")):
        _fail("Bash follow-up sword readiness incorrect")
        return
    overlay.call("acknowledge_combo_tap")
    if float(overlay.get("combo_tap_flash_remaining")) <= 0.0:
        _fail("accepted tap does not brighten the controller")
        return
    game.set("combat_state", idle_state)
    game.set("bash_followup_window_remaining", 0.0)
    game.set("bash_loop_window_remaining", 0.0)
    game.set("gesture_active", false)
    game.call("_update_controller_flick_guide", 1.0/60.0)
    if bool(overlay.get("combo_visible")):
        _fail("controller persisted after combo ended")
        return
    print("PASS v333 lock vector, gesture axis and persistent live combo icons")
    game.queue_free()
    await process_frame
    quit(0)
