extends SceneTree
## v360: elevated head or camera plane crossing can make the raw 3D
## screen projection invert 180 degrees relative to the ground-facing
## direction; the HUD and gesture axis must never do so.
const AXIS = preload("res://scripts/bittaran_controller_axis.gd")
const FLICK = preload("res://scripts/flick_direction_policy.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V360_BITTARAN_AXIS_FAIL: " + message)
    quit(1)

func _basis_ground(view: Camera3D, actor: Vector3, aim: Vector3) -> Vector2:
    var move: Vector3 = Vector3(aim.x - actor.x, 0.0, aim.z - actor.z)
    return Vector2(
        move.dot(view.global_transform.basis.x),
        -move.dot(view.global_transform.basis.y)).normalized()

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    battle.set("target_move_enabled", false)
    var view: Camera3D = battle.get("camera")
    var player: CharacterBody3D = battle.get("player")
    var parts: Node3D = battle.get("target_parts")
    var ui: Control = battle.get("touch_ui")
    if view == null or player == null or parts == null or ui == null:
        _fail("missing camera/player/parts/controller")
        return

    # Synthetic reproduction of a boss HEAD projected high on screen.
    # SERA is BEYOND the lock on the ground (Z -3 vs Z 0): the ground
    # direction points DOWN, while the raw elevated 3D line points UP.
    view.global_position = Vector3(0.0, 5.0, 8.0)
    view.look_at(Vector3.ZERO, Vector3.UP)
    var actor: Vector3 = Vector3(0.0, 0.925, -3.0)
    var tall_head: Vector3 = Vector3(0.0, 6.0, 0.0)
    var ground: Vector2 = _basis_ground(view, actor, tall_head)
    var raw: Vector2 = FLICK.projected_target_line(
        view, actor, tall_head, Vector2.UP)
    if ground.y < 0.4 or raw.dot(ground) > -0.1:
        _fail("synthetic high-head/behind scenario did not reproduce inversion: "
            + str(raw) + " ground=" + str(ground))
        return
    var corrected: Vector2 = AXIS.heading(view, actor, tall_head, Vector2.UP)
    if corrected.dot(ground) < 0.95 or corrected.y < 0.5:
        _fail("far-side elevated lock still points 180 degrees UP: "
            + str(corrected) + " ground=" + str(ground))
        return

    # Sweep the near/far transition and all lock heights for incorrect
    # hemispheres. The corrected front must keep a valid magnitude and
    # be aligned with the true XZ target bearing.
    for height in [0.15, 1.4, 3.0, 6.0, 8.0]:
        for z in [-8.0, -4.0, -2.0, -0.9, 0.9, 2.0, 4.0, 8.0]:
            for x in [-3.0, -1.0, 0.0, 1.0, 3.0]:
                var center := Vector3(x, 0.925, z)
                var aim := Vector3(0.0, height, 0.0)
                var reference: Vector2 = _basis_ground(view, center, aim)
                if reference.length_squared() <= 0.1:
                    continue
                var axis: Vector2 = AXIS.heading(view, center, aim, Vector2.UP)
                if absf(axis.length() - 1.0) > 0.002 or axis.dot(reference) < 0.35:
                    _fail("swept axis not toward lock on ground: actor="
                        + str(center) + " target=" + str(aim)
                        + " computed=" + str(axis)
                        + " reference=" + str(reference))
                    return
                var repeat: Vector2 = AXIS.heading(
                    view, center, aim, Vector2.DOWN)
                if axis.distance_to(repeat) > 0.001:
                    _fail("nondegenerate controller depends on cached heading")
                    return

    # A near-plane/behind-camera fallback must use the actual world
    # direction instead of the previous Vector2.UP constant.
    var behind_view: Vector3 = (view.global_position
        + view.global_transform.basis.z * 1.2)
    var offscreen_aim: Vector3 = behind_view + Vector3(3.0, 1.0, 0.0)
    var behind_axis: Vector2 = AXIS.heading(
        view, behind_view, offscreen_aim, Vector2.UP)
    var behind_ground: Vector2 = _basis_ground(
        view, behind_view, offscreen_aim)
    if behind_axis.dot(behind_ground) < 0.999:
        _fail("near-plane fallback did not follow ground-world bearing")
        return

    # Test actual gameplay lock geometry and controller after returning
    # to a representative combat camera, including continuous input while
    # the boss moves under an otherwise stationary held finger.
    var target: Node3D = battle.get("target")
    var body: Vector3 = (
        parts.call("get_body_hit_aabb") as AABB).get_center()
    view.global_position = body + Vector3(0.0, 6.0, 10.0)
    view.look_at(body, Vector3.UP)
    battle.set("locked_target_part_id", "leg_fr")
    var shin: Vector3 = parts.call("get_part_aim_world", "leg_fr")
    player.global_position = Vector3(shin.x, 0.0, shin.z - 4.0)
    var first: Vector2 = battle.call("_touch_to_lock_forward",
        Vector2(40.0, 880.0))
    var second: Vector2 = battle.call("_touch_to_lock_forward",
        Vector2(630.0, 160.0))
    if first.distance_to(second) > 0.001:
        _fail("far-side compass depends on finger location")
        return
    var real_ground: Vector2 = _basis_ground(
        view, player.global_position + Vector3.UP * 0.925, shin)
    if first.dot(real_ground) < 0.35:
        _fail("actual Bittaran far-side controller reversed")
        return

    battle.call("_begin_drag", Vector2(40.0, 880.0))
    player.global_position = Vector3(shin.x + 3.0, 0.0, shin.z + 3.0)
    # Finger has not moved, but the boss/player heading changed in camera
    # space. Controller and the eventual flick classifier must follow.
    battle.call("_update_controller_flick_guide", DT)
    var updated: Vector2 = battle.call("_touch_to_lock_forward",
        Vector2(40.0, 880.0))
    if (ui.get("flick_sector_forward") as Vector2).distance_to(updated) > 0.001             or (battle.get("gesture_screen_forward") as Vector2).distance_to(
                updated) > 0.001:
        _fail("holding a stationary finger leaves stale 180-degree compass")
        return

    # Guard or an eligible buffered combo flick must NOT reorient in the
    # middle of a committed swipe, even though idle motion keeps up.
    var captured: Vector2 = battle.get("gesture_screen_forward")
    battle.set("side_kick_flick_candidate", true)
    player.global_position = Vector3(shin.x - 3.0, 0.0, shin.z - 4.0)
    battle.call("_update_controller_flick_guide", DT)
    if (battle.get("gesture_screen_forward") as Vector2).distance_to(
            captured) > 0.001:
        _fail("committed combo axis rotated mid-swipe")
        return
    battle.set("gesture_active", false)
    ui.call("hide_drag")
    print("GODOT_V360_BITTARAN_AXIS_PASS: far-side head 180-degree inversion "
        + "eliminated, near-plane fallback directional, live idle touch "
        + "aligned with input, committed combos frozen")
    quit(0)
