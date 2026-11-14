extends SceneTree
## v359: downed HEAD must be AUTO-targetable even when the BODY-height
## horizontal dual rays miss; all Bittaran input sectors must point from
## the center of SERA's physical capsule to the active lock target.
const DT: float = 1.0 / 60.0
const FLICK = preload("res://scripts/flick_direction_policy.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V359_BITTARAN_LOCK_AXIS_FAIL: " + message)
    quit(1)

func _axis_from_player(battle: Node3D, aim: Vector3) -> Vector2:
    var player: CharacterBody3D = battle.get("player")
    var view: Camera3D = battle.get("camera")
    var start: Vector3 = player.global_position + Vector3.UP * 0.925
    return FLICK.projected_target_line(view, start, aim,
        FLICK.projected_lock_forward(view, player.global_position,
            aim - start, Vector2.UP))

func _test_same_axis(battle: Node3D, label: String) -> bool:
    var view: Camera3D = battle.get("camera")
    var aim: Vector3 = battle.call("_current_lock_aim_world")
    if view.is_position_behind(aim):
        _fail("target marker behind camera: " + label)
        return false
    var expected: Vector2 = _axis_from_player(battle, aim)
    var first: Vector2 = battle.call(
        "_touch_to_lock_forward", Vector2(30.0, 800.0))
    var second: Vector2 = battle.call(
        "_touch_to_lock_forward", Vector2(650.0, 120.0))
    if first.distance_to(expected) > 0.001             or first.distance_to(second) > 0.001:
        _fail(label + " mismatched finger-independent SERA->target axis: "
            + str(first) + " / " + str(second) + " vs " + str(expected))
        return false
    if FLICK.sector_index(first * 115.0, first) != 0             or FLICK.sector_index(first.rotated(PI * 0.5) * 115.0, first) != 1:
        _fail(label + " flick sector disagrees with controller rotation")
        return false
    var touch: Control = battle.get("touch_ui")
    if touch == null:
        _fail("missing touch overlay")
        return false
    # Main's real finger-down path must copy the SAME axis to the visible
    # controller, not recompute it from the screen touch point.
    if bool(battle.get("gesture_active")):
        battle.set("gesture_active", false)
    battle.call("_begin_drag", Vector2(42.0, 833.0))
    if (touch.get("flick_sector_forward") as Vector2).distance_to(first) > 0.001             or (battle.get("gesture_screen_forward") as Vector2).distance_to(first) > 0.001:
        _fail(label + " visual compass was not aligned with gesture classifier")
        return false
    battle.set("gesture_active", false)
    touch.call("hide_drag")
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    battle.set("target_move_enabled", false)
    var parts: Node3D = battle.get("target_parts")
    var player: CharacterBody3D = battle.get("player")
    var model: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    if parts == null or player == null or model == null or ik == null:
        _fail("missing boss/player/IK")
        return

    # Standing: the compass must point toward the actual shin whether SERA
    # is on the front, back or lateral side of the lock, independently of
    # the thumb position where a gesture began.
    battle.set("locked_target_part_id", "leg_fr")
    var shin: Vector3 = parts.call("get_part_aim_world", "leg_fr")
    for offset in [Vector3(0.0, 0.0, 4.0),
            Vector3(0.0, 0.0, -4.0),
            Vector3(3.5, 0.0, 2.0)]:
        player.global_position = Vector3(shin.x, 0.0, shin.z) + offset
        if not _test_same_axis(battle, "standing offset " + str(offset)):
            return

    battle.set("locked_target_part_id", "leg_fr")
    var broken: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(broken.get("broken", false)):
        _fail("breaking shin failed")
        return
    if not bool(ik.call("windup_active")) or bool(ik.call("down_pose_active")):
        _fail("0.6s windup not preserved")
        return
    # The manual catalog must include the HEAD when the boss is collapsing.
    if not bool(parts.call("can_lock_boss_part", "head"))             or not (parts.call("get_visible_part_ids",
                player.global_position, battle.call("_target_hit_aabb")) as Array).has("head"):
        _fail("HEAD not available in down manual selection")
        return

    for frame in range(36):
        model.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
        parts.call("sync_bittaran_parts")
    if not bool(ik.call("down_pose_active")):
        _fail("boss never entered actual down after 0.6s")
        return
    battle.call("_update_bittaran_lock_permissions")
    battle.set("auto_lock_enabled", true)
    battle.set("manual_part_lock_active", false)
    battle.call("_acquire_stable_camera_part", DT, false)
    if str(battle.get("locked_target_part_id")) != "head":
        _fail("downed AUTO continued selecting BODY/SHIN instead of HEAD: "
            + str(battle.get("locked_target_part_id")))
        return

    # Reticle, current aim and both controls must remain on the downed
    # HEAD rather than using the overall BODY center or an old shin.
    var head_aim: Vector3 = parts.call("get_part_aim_world", "head")
    var locked_aim: Vector3 = battle.call("_current_lock_aim_world")
    if head_aim.distance_to(locked_aim) > 0.001:
        _fail("downed HEAD lock marker is not at physical head center")
        return
    for offset in [Vector3(0.0, 0.0, 4.0),
            Vector3(0.0, 0.0, -4.0),
            Vector3(3.5, 0.0, 2.0)]:
        player.global_position = Vector3(head_aim.x, 0.0, head_aim.z) + offset
        if not _test_same_axis(battle, "down HEAD offset " + str(offset)):
            return
        battle.call("_acquire_stable_camera_part", DT, false)
        if str(battle.get("locked_target_part_id")) != "head":
            _fail("HEAD lock did not persist at offset " + str(offset))
            return

    # Manual still honors another part; AUTO force must not hijack it.
    battle.set("auto_lock_enabled", false)
    battle.set("manual_part_lock_active", true)
    battle.set("locked_target_part_id", "body")
    battle.call("_update_bittaran_lock_permissions")
    if str(battle.get("locked_target_part_id")) != "body":
        _fail("down manual BODY target unexpectedly replaced")
        return

    print("GODOT_V359_BITTARAN_LOCK_AXIS_PASS: downed HEAD AUTO, manual "
        + "weakpoint access, consistent player-center compass and flick sectors")
    quit(0)
